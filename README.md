# SeeminglyScience's dot files

This repo holds my PowerShell profile and configuration files for other applications like VSCode and
vim. Some of these things I use every day, others may be unfinished or otherwise broken. This isn't
intended to be a supported product.

## PowerShell theme

![PS-theme-example](https://user-images.githubusercontent.com/24977523/63215491-3037e200-c0f5-11e9-96a6-80a893295dbe.png)

## Requirements and/or recommendations

My profile expects a lot of things to be here, and may or may not break without them.

### Applications

Often these will need to be in your `PATH`. Some aren't needed at all and I just recommend them,
some are only required for specific profile functions.

1. [VSCode](https://code.visualstudio.com/)
2. [Neovim](https://chocolatey.org/packages/neovim)
3. [bat](https://github.com/sharkdp/bat)
4. [dnSpy](https://github.com/0xd4d/dnSpy)
5. [dotnet](https://dotnet.microsoft.com/)
6. [python](https://www.python.org/)
7. [nodejs](https://nodejs.org/en/)
8. [go](https://golang.org/)
9. [rust](https://www.rust-lang.org/)
10. [Visual Studio](https://visualstudio.microsoft.com/vs/community/) (Mostly for building projects that require it. I personally only use it when working with WPF)

### PowerShell modules

1. [ClassExplorer](https://github.com/SeeminglyScience/ClassExplorer)
2. [EditorServicesCommandSuite](https://github.com/SeeminglyScience/EditorServicesCommandSuite)
3. [ImpliedReflection](https://github.com/SeeminglyScience/ImpliedReflection)
4. [PSLambda](https://github.com/SeeminglyScience/PSLambda)
5. [PSWriteline](https://github.com/SeeminglyScience/PSWriteline)
6. [InvokeBuild](https://github.com/nightroman/Invoke-Build)
7. The latest prerelease of [PSReadLine](https://github.com/PowerShell/PSReadLine)

### VSCode extensions

1. alefragnani.project-manager
2. christian-kohler.npm-intellisense
3. cmstead.jsrefactor
4. CoenraadS.bracket-pair-colorizer
5. DavidAnson.vscode-markdownlint
6. dbaeumer.jshint
7. dbaeumer.vscode-eslint
8. eamodio.gitlens
9. EditorConfig.EditorConfig
10. eg2.vscode-npm-script
11. ephoton.indent-switcher
12. IBM.XMLLanguageSupport
13. jchannon.csharpextensions
14. k--kato.docomment
15. mrmlnc.vscode-scss
16. ms-vscode-remote.remote-wsl
17. ms-vscode.cpptools
18. ms-vscode.csharp
19. ms-vscode.powershell-preview
20. ms-vscode.vscode-typescript-tslint-plugin
21. ms-vsliveshare.vsliveshare
22. msjsdiag.debugger-for-chrome
23. pflannery.vscode-versionlens
24. redhat.java
25. redhat.vscode-xml
26. SeeminglyScience.terminal-input
27. steve8708.Align
28. teabyii.ayu
29. twxs.cmake
30. vscodevim.vim
31. yzhang.markdown-all-in-one

### Misc

1. [NerdFonts patched FiraCode](https://github.com/ryanoasis/nerd-fonts/blob/master/patched-fonts/FiraCode/Regular/complete/Fira%20Code%20Regular%20Nerd%20Font%20Complete%20Mono%20Windows%20Compatible.ttf)
2. [Maybe these console settings](https://gist.github.com/SeeminglyScience/577cc1155db08c254b33710406a931b1)
3. Windows 10 1903 or *maybe* Windows 7 with some terminal emulator that supports a lot of ANSI escape sequences. Also should *mostly* work on Linux/MacOS.

### VIM

1. [Install plug](https://github.com/junegunn/vim-plug#windows-powershell-1)
2. Put `coc-settings.json` and `init.vim` in `~\AppData\Local\nvim` (*nix: `~\.config\nvim`)
3. Put `.vimfiles` in `~`
4. Open vim and run `:PlugInstall`
5. Install desired coc extensions with `:CocInstall extensionname`
    1. coc-powershell (surprisingly excellent support)
    2. coc-marketplace
    3. coc-eslint
    4. coc-pairs
    5. coc-yank
    6. coc-lists
    7. coc-git
    8. coc-snippets
    9. coc-highlight
    10. coc-xml
    11. coc-ccls
    12. coc-tslint
    13. coc-svg
    14. coc-rls
    15. coc-html
    16. coc-tsserver
    17. coc-omnisharp (doesn't seem to work yet though)
    18. coc-json

### Roslynator

I still have Roslynator in VSCode set up the old hacky way (downloading the nuget, extracting
specific dlls, and putting them in `~\.omnisharp`). Instead of that, they now have a [Roslynator](https://marketplace.visualstudio.com/items?itemName=josefpihrt-vscode.roslynator) extension on the marketplace. If you use
that method (and you should), take the roslynator paths out of `omnisharp.json`.

If you instead set it up how I have it, change the roslynator paths in `omnisharp.json` to reflect where
it is on your machine.

## Future

In the future I'd like to:

1. Document the profile functions
2. Remove what doesn't work
3. Create a bootstrap script
