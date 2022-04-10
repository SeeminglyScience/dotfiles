using namespace System
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Reflection

<#
    SYNOPSIS
        Forcefully repopulates type tab completion cache. Useful when loading
        assemblies that cause Assembly.GetTypes() to throw in PowerShell 5.1.
#>
function global:Set-TypeCompletionCache {
    param()
    end {
        Import-Module PSLambda
        $types = [type[]] (& {
            Find-Type -Force TypeCompletionMapping
            Find-Type -Force TypeCompletion
            Find-Type -Force TypeAccelerators
            Find-Type -Force TypeCompletionBase
            Find-Type -Force TypeCompletionInStringFormat
            Find-Type -Force ClrFacade
            Find-Type -Force TypeResolver -Namespace System.Management.Automation.Language
        })

        Invoke-PSLambda -EnablePrivateBinding -ResolvablePrivateTypes $types {
            $entries = [Dictionary[string,TypeCompletionMapping]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($type in [TypeAccelerators]::Get) {
                $entry = default([TypeCompletionMapping])
                $instance = [TypeCompletion]::new()
                $instance.Type = $type.Value

                if ($entries.TryGetValue($type.Key, $entry)) {
                    $acceleratorType = $type.Value
                    $alreadyIncluded = $entry.Completions.Any{ $item => {
                        return $item -is [TypeCompletion] -and ([TypeCompletion]$item).Type -eq $acceleratorType
                    }}

                    if ($alreadyIncluded) {
                        continue
                    }

                    $entry.Completions.Add($instance)
                } else {
                    $entry = [TypeCompletionMapping]::new()
                    $entry.Key = $type.Key
                    $entry.Completions = [List[TypeCompletionBase]]::new()
                    $entry.Completions.Add($instance)
                    $entries.Add($type.Key, $entry)
                }

                $fullTypeName = $type.Value.FullName
                if ($entries.ContainsKey($fullTypeName)) {
                    continue
                }

                $mapping = [TypeCompletionMapping]::new()
                $mapping.Key = $fullTypeName
                $mapping.Completions = [List[TypeCompletionBase]]::new()
                $mapping.Completions.Add($instance)
                $entries.Add($fullTypeName, $mapping)

                $shortTypeName = $type.Value.Name
                if ($type.Key.Equals($shortTypeName, [StringComparison]::OrdinalIgnoreCase)) {
                    continue
                }

                if (-not $entries.TryGetValue($shortTypeName, $entry)) {
                    $entry = [TypeCompletionMapping]::new()
                    $entry.Key = $shortTypeName
                    $entries.Add($shortTypeName, $entry)
                }

                $entry.Completions.Add($instance)
            }

            $availableTypes = [List[type]]::new()
            foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
                $types = [type]::EmptyTypes
                try {
                    $types = $assembly.GetTypes()
                } catch {
                    continue
                }

                $availableTypes.AddRange($types)
            }

            foreach ($type in $availableTypes) {
                try {
                    if (-not [TypeResolver]::IsPublic($type)) {
                        continue
                    }

                    [CompletionCompleters]::HandleNamespace($entries, $type.Namespace)
                    [CompletionCompleters]::HandleType($entries, $type.FullName, $type.Name, $type)
                } catch {
                    continue
                }
            }

            $grouping = ([TypeCompletionMapping[]]$entries.Values).
                GroupBy{ $t => $t.Key.ToCharArray().Count{ $c => ($c -eq '.'[0]) }}.
                OrderBy{ $g => $g.Key }.
                ToArray()

            $localTypeCache = [TypeCompletionMapping[][]]::new($grouping.Last().Key + 1)
            foreach ($group in $grouping) {
                $localTypeCache.SetValue([TypeCompletionMapping[]]$group, $group.Key)
            }

            $cacheField = default([FieldInfo])
            $bindingFlags = [BindingFlags]'NonPublic, Static'
            if (([Version]$PSVersionTable['PSVersion']).Major -gt 5) {
                $cacheField = [CompletionCompleters].GetField('s_typeCache', $bindingFlags)
            } else {
                $cacheField = [CompletionCompleters].GetField('typeCache', $bindingFlags)
            }

            $cacheField.SetValue($null, $localTypeCache)
        }
    }
}
