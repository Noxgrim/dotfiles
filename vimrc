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
 function! SudoWrite(args)
     if len(a:args)
         execute "w !sudo tee > /dev/null ".a:args
     else
         w !sudo tee > /dev/null %
     endif
 endfunction
 command! -nargs=? -complete=file W call SudoWrite('<args>')

 call plug#begin('~/.vim/plugged')

" Sourround.vim
  Plug 'tpope/vim-surround'
  Plug 'tpope/vim-repeat'
  Plug 'tpope/vim-fugitive'
  Plug 'junegunn/gv.vim'
  Plug 'jiangmiao/auto-pairs'
  Plug 'vim-airline/vim-airline'
  let  g:airline_powerline_fonts = 1 " Activate powerline power
  Plug 'vim-airline/vim-airline-themes'
  let  g:airline_theme='base16'
 "Plug 'scrooloose/syntastic'
  Plug 'altercation/vim-colors-solarized'
  Plug 'b4winckler/vim-angry'
  Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
  Plug 'junegunn/fzf.vim'
 "Plug 'sunaku/vim-shortcut'
  Plug 'scrooloose/nerdtree'
  Plug 'alvan/vim-closetag', { 'for': ['html', 'xml', 'java']  }
  Plug 'Valloric/MatchTagAlways', { 'for': ['html', 'xml', 'java']  }
  Plug 'junegunn/vim-easy-align'
 "Plug 'junegunn/limelight.vim'
  Plug 'junegunn/vim-peekaboo'
  Plug 'junegunn/rainbow_parentheses.vim'
  Plug 'whatyouhide/vim-lengthmatters'
 "Plug 'whatyouhide/vim-gotham'

  call plug#end()

" Start interactive EasyAlign in visual mode (e.g. vipga)
  xmap ga <Plug>(EasyAlign)
 
" Start interactive EasyAlign for a motion/text object (e.g. gaip)
  nmap ga <Plug>(EasyAlign)


 filetype plugin indent on    " required

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
 set t_Co=256

 inoremap <C-H> <NOP>
 inoremap <C-J> <Down>
 inoremap <C-K> <Up>
 inoremap <C-H> <Left>
 inoremap <C-L> <Right>

 if has('nvim')
     tnoremap <C-e><C-e> <C-\><C-n>
     autocmd! TermOpen * setlocal listchars=tab:▸\ ,trail:\ ,precedes:↤,extends:↦
     highlight TermCursor ctermfg=darkgreen guifg=darkgreen
     highlight TermCursorNC ctermfg=lightgreen guifg=darkgreen
 endif
" Use 256 colours (Use this setting only if your terminal supports 256 colours)
