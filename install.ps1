function ConfirmInstallScript {
    [CmdletBinding()]
    param([string] $Name, [string] $Script)
    end {
        $bat = Get-Command bat -CommandType Application -ErrorAction Ignore
        $batArgs = @('-l', 'powershell')
        if (-not $bat) {
            $bat = 'more'
            $batArgs = @()
        }

        $Script | & $bat @batArgs
        if (-not $PSCmdlet.ShouldContinue('Or is it bad now :o', "Install ${Name}?")) {
            throw 'it''s bad now :o'
        }

        & ([scriptblock]::Create($Script))
    }
}

# This script will likely be iex'd. So usually this in a script doesn't
# make any sense, but it does here.
try { Set-ExecutionPolicy -Scope CurrentUser Unrestricted } catch { }

if (-not (Get-Command scoop -CommandType Application -ErrorAction Ignore)) {
    $scoopInstall = (Invoke-WebRequest -UseBasicParsing get.scoop.sh).Content
    ConfirmInstallScript scoop $scoopInstall
}

scoop install git chezmoi
if (-not $env:NO_SECRETS) {
    scoop install bitwarden-cli

    $status = $null
    do
    {
        if ($status) {
            Write-Error 'Login failed, try again'
        }

        $status = bw status | ConvertFrom-Json
        if ($status.userEmail) {
            $env:BW_SESSION = bw unlock --raw
        } else {
            $env:BW_SESSION = bw login --raw
        }
    } while (-not $env:BW_SESSION)
}

chezmoi init SeeminglyScience
chezmoi apply -v
