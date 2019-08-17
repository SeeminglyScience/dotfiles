source $HOME\.vimfiles\.vimrc

" call plug#begin('~/AppData/Local/nvim/plugged')
" Plug 'tomasiser/vim-code-dark'
" Plug 'vim-airline/vim-airline'
" Plug 'vim-airline/vim-airline-themes'
" Plug 'neoclide/coc.nvim', {'branch': 'release'}
" Plug 'sheerun/vim-polyglot'
" Plug 'tpope/vim-commentary'
" Plug 'scrooloose/nerdtree'
" Plug 'Xuyuanp/nerdtree-git-plugin'
" Plug 'junegunn/rainbow_parentheses.vim'
" Plug 'ryanoasis/vim-devicons'
" Plug 'tpope/vim-fugitive'
" Plug 'tpope/vim-sensible'
" Plug 'tpope/vim-surround'
" Plug 'junegunn/vim-easy-align'
" Plug 'alvan/vim-closetag'
" Plug 'Yggdroot/indentLine'
" Plug 'chrisbra/Colorizer'
" Plug 'dkarter/bullets.vim'
" Plug 'Raimondi/delimitMate'
" Plug 'terryma/vim-multiple-cursors'
" call plug#end()

" let g:python_host_prog = 'C:\Python27\python.exe'
" let g:python3_host_prog = 'C:\Program Files (x86)\Python37-32\python.exe'

" syntax enable
" syntax on
" try
"     colorscheme codedark
" catch
" endtry

" highlight All term=bold

" set termguicolors
" set t_Co=256
" set t_ui=
" set background=dark
" highlight Normal guibg=NONE
" highlight NonText guibg=NONE

" filetype plugin on
" filetype indent on
" set tabstop=4 softtabstop=4 shiftwidth=4 expandtab smarttab autoindent
" set incsearch ignorecase smartcase hlsearch
" set ruler laststatus=2 showcmd showmode
" set list listchars=trail:»,tab:»-
" set fillchars+=vert:\
" set wrap breakindent
" set encoding=utf-8
" set ffs=unix,dos,mac
" set number
" set title
" set rtp+=C:\ProgramData\chocolatey\lib\fzf\tools\fzf.exe
" set completeopt=longest,menuone,preview
" set previewheight=5
" set dir=$TEMP
" set autoread
" set so=7
" set wildmenu
" set wildmode=longest:full,full
" set backspace=eol,start,indent
" set whichwrap+=<,>,h,l
" set lazyredraw
" set magic
" set showmatch
" set mat=2
" set noerrorbells
" set novisualbell
" set tm=500
" set foldcolumn=1
" set ai
" set si

" set t_vb=

" " if hidden is not set, TextEdit might fail.
" set hidden

" " Some servers have issues with backup files, see #649
" set nobackup
" set nowritebackup

" " Better display for messages
" set cmdheight=2

" " You will have bad experience for diagnostic messages when it's default 4000.
" set updatetime=300

" " don't give |ins-completion-menu| messages.
" set shortmess+=c

" " always show signcolumns
" set signcolumn=yes

" autocmd FileType html setlocal shiftwidth=2 tabstop=2 softtabstop=2
" autocmd FileType js setlocal shiftwidth=2 tabstop=2 softtabstop=2
" autocmd FileType jsx setlocal shiftwidth=2 tabstop=2 softtabstop=2
" autocmd FileType ts setlocal shiftwidth=2 tabstop=2 softtabstop=2
" autocmd FileType tsx setlocal shiftwidth=2 tabstop=2 softtabstop=2
" autocmd FileType json setlocal shiftwidth=2 tabstop=2 softtabstop=2
" autocmd FileType jsonc setlocal shiftwidth=2 tabstop=2 softtabstop=2

" autocmd FileType cs setlocal commentstring=//\ %s

" let NERDTreeShowHidden = 1
" let g:NERDTreeDirArrowExpandable = ''
" let g:NERDTreeDirArrowCollapsible = ''
" let g:NERDTreeWinSize = 35
" let g:NERDTreeWinPos = 'right'
" let mapleader = ','

" let g:airline_powerline_fonts = 1

" if !exists('g:airline_symbols')
"     let g:airline_symbols = {}
" endif

" let g:airline_theme = 'codedark'
" let g:airline#extensions#tabline#enabled = 1

" " unicode symbols
" let g:airline_left_sep = '»'
" let g:airline_left_sep = '▶'
" let g:airline_right_sep = '«'
" let g:airline_right_sep = '◀'
" let g:airline_symbols.branch = ''
" let g:airline_symbols.paste = ''
" let g:airline_symbols.whitespace = ''
" let g:airline_symbols.branch = ''
" let g:airline_symbols.readonly = ''
" let g:airline_symbols.linenr = ''

" " airline symbols
" " let g:airline_left_sep = ''
" " let g:airline_left_alt_sep = ''
" " let g:airline_right_sep = ''
" " let g:airline_right_alt_sep = ''

" " highlight Normal ctermbg=none
" " highlight ctermbg=none


" " Use tab for trigger completion with characters ahead and navigate.
" " Use command ':verbose imap <tab>' to make sure tab is not mapped by other plugin.
" inoremap <silent><expr> <TAB>
"       \ pumvisible() ? "\<C-n>" :
"       \ <SID>check_back_space() ? "\<TAB>" :
"       \ coc#refresh()
" inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

" function! s:check_back_space() abort
"   let col = col('.') - 1
"   return !col || getline('.')[col - 1]  =~# '\s'
" endfunction

" " Use <c-space> to trigger completion.
" inoremap <silent><expr> <c-space> coc#refresh()
" inoremap <silent><expr> <C-b> coc#refresh()

" " Use <cr> to confirm completion, `<C-g>u` means break undo chain at current position.
" " Coc only does snippet and additional edit on confirm.
" inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"

" " Use `[c` and `]c` to navigate diagnostics
" nmap <silent> [c <Plug>(coc-diagnostic-prev)
" nmap <silent> ]c <Plug>(coc-diagnostic-next)

" " Remap keys for gotos
" nmap <silent> gd <Plug>(coc-definition)
" nmap <silent> gy <Plug>(coc-type-definition)
" nmap <silent> gi <Plug>(coc-implementation)
" nmap <silent> gr <Plug>(coc-references)

" " Use K to show documentation in preview window
" nnoremap <silent> K :call <SID>show_documentation()<CR>

" function! s:show_documentation()
"   if (index(['vim','help'], &filetype) >= 0)
"     execute 'h '.expand('<cword>')
"   else
"     call CocAction('doHover')
"   endif
" endfunction

" " Highlight symbol under cursor on CursorHold
" autocmd CursorHold * silent call CocActionAsync('highlight')

" " Remap for rename current word
" nmap <leader>rn <Plug>(coc-rename)

" " Remap for format selected region
" xmap <leader>f  <Plug>(coc-format-selected)
" nmap <leader>f  <Plug>(coc-format-selected)

" augroup mygroup
"   autocmd!
"   " Setup formatexpr specified filetype(s).
"   autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
"   " Update signature help on jump placeholder
"   autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
" augroup end

" " Remap for do codeAction of selected region, ex: `<leader>aap` for current paragraph
" xmap <leader>a  <Plug>(coc-codeaction-selected)
" nmap <leader>a  <Plug>(coc-codeaction-selected)

" " Remap for do codeAction of current line
" nmap <leader>ac  <Plug>(coc-codeaction)
" " Fix autofix problem of current line
" nmap <leader>qf  <Plug>(coc-fix-current)

" " Use <tab> for select selections ranges, needs server support, like: coc-tsserver, coc-python
" nmap <silent> <TAB> <Plug>(coc-range-select)
" xmap <silent> <TAB> <Plug>(coc-range-select)
" xmap <silent> <S-TAB> <Plug>(coc-range-select-backword)

" " Use `:Format` to format current buffer
" command! -nargs=0 Format :call CocAction('format')

" " Use `:Fold` to fold current buffer
" command! -nargs=? Fold :call     CocAction('fold', <f-args>)

" " use `:OR` for organize import of current buffer
" command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')

" " Add status line support, for integration with other plugin, checkout `:h coc-status`
" set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

" " Using CocList
" " Show all diagnostics
" nnoremap <silent> <space>a  :<C-u>CocList diagnostics<cr>

" " Manage extensions
" nnoremap <silent> <space>e  :<C-u>CocList extensions<cr>
" " Show commands
" nnoremap <silent> <space>c  :<C-u>CocList commands<cr>
" " Find symbol of current document
" nnoremap <silent> <space>o  :<C-u>CocList outline<cr>
" " Search workspace symbols
" nnoremap <silent> <space>s  :<C-u>CocList -I symbols<cr>
" " Do default action for next item.
" nnoremap <silent> <space>j  :<C-u>CocNext<CR>
" " Do default action for previous item.
" nnoremap <silent> <space>k  :<C-u>CocPrev<CR>
" " Resume latest coc list
" nnoremap <silent> <space>p  :<C-u>CocListResume<CR>

" nmap <silent> <buffer> <C-S-P> :CocCommand<CR>
" xmap <silent> <buffer> <C-S-P> :CocCommand<CR>

" " Start interactive EasyAlign in visual mode (e.g. vipga)
" xmap ga <Plug>(EasyAlign)

" " Start interactive EasyAlign for a motion/text object (e.g. gaip)
" nmap ga <Plug>(EasyAlign)

" imap jj <Esc>

" " Move between windows
" map <C-j> <C-W>j
" map <C-k> <C-W>k
" map <C-h> <C-W>h
" map <C-l> <C-W>l

" " Return to last edit position when opening files
" au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" " Remap VIM 0 to first non-blank character
" map 0 ^

" " Move a line of text using ALT+[jk] or Command+[jk] on mac
" nmap <M-j> mz:m+<cr>`z
" nmap <M-k> mz:m-2<cr>`z
" vmap <M-j> :m'>+<cr>`<my`>mzgv`yo`z
" vmap <M-k> :m'<-2<cr>`>my`<mzgv`yo`z

" " Delete trailing whitespace on save
" fun! CleanExtraSpaces()
"     let save_cursor = getpos(".")
"     let old_query = getreg('/')
"     silent! %s/\s\+$//e
"     call setpos('.', save_cursor)
"     call setreg('/', old_query)
" endfun

" if has("autocmd")
"     autocmd BufWritePre *.ps1,*.psd1,*.psm1,*.ps1xml,*.js,*.jsx,*.ts,*.tsx,*.cs,*.csproj,*.xml,*.json,*.jsonc :call CleanExtraSpaces()
" endif

" " Fast editing and reloading of vimrc configs
" map <leader>e :e! $MYVIMRC
" autocmd! BufWritePost $MYVIMRC source $MYVIMRC

" let g:multi_cursor_use_default_mapping=0
" let g:multi_cursor_start_word_key      = '<C-n>'
" let g:multi_cursor_select_all_word_key = '<A-n>'
" let g:multi_cursor_start_key           = 'g<C-n>'
" let g:multi_cursor_select_all_key      = 'g<A-n>'
" let g:multi_cursor_next_key            = '<C-n>'
" let g:multi_cursor_prev_key            = '<C-p>'
" let g:multi_cursor_skip_key            = '<C-x>'
" let g:multi_cursor_quit_key            = '<Esc>'

" map <leader>nn :NERDTreeToggle<cr>
" map <leader>nb :NERDTreeFromBookmark<Space>
" map <leader>nf :NERDTreeFind<cr>
