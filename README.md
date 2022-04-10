# SeeminglyScience's dot files

This repo holds my PowerShell profile and various other configuration files. Some of these things I use every day, others may be unfinished or straight up broken. This isn't intended to be a supported product.

Managed with [chezmoi](https://www.chezmoi.io/)

This snippet is mainly for me:

```powershell
(iwr -useb https://seemingly.dev/install-dots).Content | iex
```

You'd need to (but probably shouldn't, just use this as reference) do:

```powershell
$env:NO_SECRETS = 1;(iwr -useb https://seemingly.dev/install-dots).Content | iex
```

### PowerShell

- [All profile files](./Documents/PowerShell)
- [`Utility.psm1`](./Documents/PowerShell/Utility.psm1) (All the functions I use interactively that don't fit into something publishable)
- [Module installs](./run_once_before_main.ps1#L58)

### VSCode

VSCode settings are handled with settings sync, but a snapshot is included here for reference.

- [`settings.json`](./VSCode/settings.json)
- [`keybindings.json`](./VSCode/keybindings.json)

Also here are my current extensions:

- alefragnani.project-manager
- bungcip.better-toml
- DavidAnson.vscode-markdownlint
- eamodio.gitlens
- EditorConfig.EditorConfig
- Fudge.auto-using
- GitHub.vscode-pull-request-github
- josefpihrt-vscode.roslynator
- ms-azure-devops.azure-pipelines
- ms-dotnettools.csharp
- ms-vscode-remote.remote-containers
- ms-vscode.azure-account
- ms-vscode.cpptools
- ms-vscode.hexeditor
- ms-vscode.powershell-preview
- ms-vscode.vscode-typescript-tslint-plugin
- pascalsenn.keyboard-quickfix
- redhat.vscode-xml
- twxs.cmake
- TylerLeonhardt.vscode-inline-values-powershell
- usernamehw.errorlens
- vitaliymaz.vscode-svg-previewer
- vscodevim.vim
- wwm.better-align
- XadillaX.viml

### Vim

The neovim [`init.vim`](./AppData/Local/nvim/init.vim) just points to `.vimrc` below.

- [`.vimrc`](./dot_vimfiles/dot_vimrc)
- [`plugins.vim`](./dot_vimfiles/plugins.vim)
- [`theme.vim`](./dot_vimfiles/theme.vim)
- [`settings.vim`](./dot_vimfiles/settings.vim)
- [`maps.vim`](./dot_vimfiles/maps.vim)
- [`auto.vim`](./dot_vimfiles/auto.vim)
- [`coc-settings.json`](./AppData/Local/nvim/coc-settings.json)

Only thing that isn't handled by chezmoi:

- Install coc extensions with `:CocInstall extensionname`
    - coc-powershell
    - coc-marketplace
    - coc-omnisharp
    - coc-json

### Windows Terminal

- [`settings.json`](./AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json)

### Git

- [`.gitconfig`](./dot_gitconfig.tmpl)

### Apex Legends

For apex to execute a config it actually needs to be in `ApexInstallDir/cfg` but you can't really manage that well with chezmoi so I have a script to copy it.

- [`autoexec.cfg`](./AppData/Roaming/apex-config/autoexec.cfg)
- [`apex-config.cfg`](./AppData/Roaming/apex-config/apex-config.cfg)
- [`CopyConfigs.ps1`](./AppData/Roaming/apex-config/CopyConfigs.ps1)
- [Command line options](./AppData/Roaming/apex-config/apex-config.cfg#L14)

## Future

In the future I'd like to:

- Document the profile functions
- Remove what doesn't work
