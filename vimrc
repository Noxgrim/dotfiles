" Line numbers
 set number
 set relativenumber
 noremap <C-N><C-N> :set invnumber<CR>
 noremap <C-N><C-R> :set invrelativenumber<CR>

" Search
 set hlsearch
 set smartcase

" Settings for Eclim
 set nocompatible
 filetype plugin indent on

" Wild menuset colorcolumn=81
 set wildmode=longest,list,full
 set wildmenu

" Highlight specific chars
 set list
 set listchars=tab:▸\ ,eol:¬,trail:\ ,precedes:↤,extends:↦

" Set visual mark after 80 characters
 set colorcolumn=81

" Toggle paste mode
 set pastetoggle=<F10>

 map <silent> <C-S-c> :nohlsearch<CR>
 map <silent> <C-S-r> :let @/=""<CR>

" create backups and swap files in the .vim directory (the double slashes
" mean, VIM uses the full path)
 set backupdir=~/.vim/backup//
 set directory=~/.vim/swp//

" Open lines without entering insert mode
 noremap <C-j> o<ESC>
 noremap <C-k> O<ESC>
 noremap <A-j> o<ESC>k
 noremap <A-k> O<ESC>j

" Indent
 set smartindent
 set expandtab
 set shiftwidth=4
 set softtabstop=4
" Show command in the staus bar.
 set showcmd
 set showmode
 set laststatus=2

" Implement own function to save files as super user
" to allow no or one argument.
 function SudoWrite(args)
     if len(a:args)
         execute "w !sudo tee > /dev/null ".a:args
     else
         w !sudo tee > /dev/null %
     endif
 endfunction
 command -nargs=? -complete=file W call SudoWrite('<args>')

 filetype off                  " required

" set the runtime path to include Vundle and initialize
 set rtp+=~/.vim/bundle/Vundle.vim
 call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
 Plugin 'VundleVim/Vundle.vim'

" Sourround.vim
  Plugin 'tpope/vim-surround'
  Plugin 'tpope/vim-repeat'
  Plugin 'tpope/vim-fugitive'
  Plugin 'jiangmiao/auto-pairs'
  Plugin 'vim-airline/vim-airline'
  let g:airline_powerline_fonts = 1 " Activate powerline power
  Plugin 'vim-airline/vim-airline-themes'
  let g:airline_theme='base16'
 "Plugin 'scrooloose/syntastic'
  Plugin 'altercation/vim-colors-solarized'
 "Plugin 'b4winckler/vim-angry'


" All of your Plugins must be added before the following line
 call vundle#end()            " required
 filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line

 syntax enable
" enable spell checking for certain file types
 autocmd FileType gitcommit setlocal spell
 autocmd FileType markdown setlocal spell
 set background=dark
 colorscheme solarized

"set rtp+=$HOME/.local/lib/python2.7/site-packages/powerline/bindings/vim/

" Always show statusline
 set laststatus=2
 if has('mouse')
     set mouse=a
 endif

" Use 256 colours (Use this setting only if your terminal supports 256 colours)
"set t_Co=256
