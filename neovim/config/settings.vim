set nocompatible

" Line numbers
set number
set relativenumber

" Search
set hlsearch
set ignorecase smartcase
set incsearch
if has('nvim')
    set inccommand=nosplit
endif

" Settings for Eclim
filetype plugin indent on

" Allow more tabs
set tabpagemax=100

" Wild menu
set wildmode=longest:full,full
set wildmenu
set wildignorecase

" Highlight specific chars
set list
set listchars=tab:▸\ ,eol:¬,trail:\ ,precedes:↤,extends:↦

" Set visual mark after 80 characters
set colorcolumn=81
set cursorline "cursorcolumn

" Toggle paste mode
set pastetoggle=<F10>

" Do not redraw when executing macros etc.
set lazyredraw

" Change weird behaviour with emoj
set noemoji

" create backups and swap files in the .vim directory (the double slashes
" mean, VIM uses the full path)
set backupdir=~/.vim/backup//
set directory=~/.vim/swp//
set undodir=~/.vim/undo//
set viewdir=~/.vim/view//

" Indent
set smartindent
set expandtab
set shiftwidth=4
set softtabstop=4
set ts=4

" Show command in the staus bar.
set showcmd
set showmode
set laststatus=2

" Undo file
set undofile
augroup noxgrim_setting_undofile
    autocmd!

    autocmd BufWinLeave ?* mkview
    autocmd BufWinEnter ?* silent! loadview
augroup END

"set rtp+=$HOME/.local/lib/python2.7/site-packages/powerline/bindings/vim/

filetype plugin indent on    " required

syntax enable
augroup noxgrim_setting_spell
    autocmd!

    " enable spell checking for certain file types
    autocmd FileType gitcommit setlocal spell
    autocmd FileType markdown setlocal spell
    autocmd FileType text setlocal spell textwidth=80
    autocmd FileType tex setlocal spell
    autocmd FileType plaintex setlocal spell
augroup END

" Always show statusline
set laststatus=2
if has('mouse')
    set mouse=a
endif


" Terminal settings
set t_Co=256 " Use 256 colours (Use this setting only if your terminal supports 256 colours)
if has('nvim')
    autocmd! TermOpen * setlocal listchars=tab:▸\ ,trail:\ ,precedes:↤,extends:↦
    highlight TermCursor ctermfg=darkgreen guifg=darkgreen
    highlight TermCursorNC ctermfg=lightgreen guifg=darkgreen

    set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50
      \,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor
      \,sm:block-blinkwait175-blinkoff150-blinkon175
endif


" display unnecessary whitespace (stolen from
" http://vim.wikia.com/wiki/Highlight_unwanted_spaces)
highlight ExtraWhitespace ctermbg=darkred guibg=darkred
augroup noxgrim_setting_extra_whitespace
    autocmd!

    autocmd ColorScheme * highlight ExtraWhitespace ctermbg=darkred guibg=darkred
    autocmd Syntax * syntax match ExtraWhitespace /\s\+\%#\@<!$\| \+\ze\t/ containedin=ALL
augroup END

" Set python providers
let g:python_host_prog  = '/usr/sbin/python2'
let g:python3_host_prog = '/usr/sbin/python3'
