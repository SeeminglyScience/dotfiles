if !exists('g:vscode')

if has("autocmd")
    autocmd BufWritePre *.ps1,*.psd1,*.psm1,*.ps1xml,*.js,*.jsx,*.ts,*.tsx,*.cs,*.csproj,*.xml,*.json,*.jsonc :call CleanExtraSpaces()
endif

" Fast editing and reloading of vimrc configs
autocmd! BufWritePost MYVIMRC source MYVIMRC

" Return to last edit position when opening files
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

autocmd FileType html setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType js setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType jsx setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType ts setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType tsx setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType json setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType jsonc setlocal shiftwidth=2 tabstop=2 softtabstop=2

autocmd FileType cs setlocal commentstring=//\ %s

endif
