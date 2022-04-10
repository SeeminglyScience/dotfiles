if !exists('g:vscode')

syntax enable
syntax on
try
    colorscheme codedark
catch
endtry

highlight All term=bold

set termguicolors
set t_Co=256
set t_ui=
set background=dark
highlight Normal guibg=NONE
highlight NonText guibg=NONE

endif
