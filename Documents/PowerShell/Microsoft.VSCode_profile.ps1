if ((Get-ChildItem $psEditor.Workspace.Path).Name -notcontains 'build.psake.ps1') {
    Set-Alias task Invoke-Build
}
