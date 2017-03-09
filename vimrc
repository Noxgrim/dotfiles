" Line numbers
 set number
 set relativenumber
 noremap <C-N><C-N> :set invnumber<CR>
 noremap <C-N><C-R> :set invrelativenumber<CR>

" Search
 set hlsearch
 set ignorecase smartcase

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
 set cursorline "cursorcolumn

" Toggle paste mode
 set pastetoggle=<F10>

 if has('nvim')
     nnoremap <silent> <M-c>   :nohlsearch<CR>
     nnoremap <silent> <M-S-c> :let @/=""<CR>
 else
     nnoremap <silent> <C-c>   :nohlsearch<CR>
 endif

" create backups and swap files in the .vim directory (the double slashes
" mean, VIM uses the full path)
 set backupdir=~/.vim/backup//
 set directory=~/.vim/swp//

" Open lines without entering insert mode
 nnoremap <C-j> o<ESC>
 nnoremap <C-k> O<ESC>
 if has('nvim')
     nnoremap <A-j> o<ESC>k
     nnoremap <A-k> O<ESC>j
 endif

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
 "Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
 "Plug 'junegunn/fzf.vim'
 "Plug 'sunaku/vim-shortcut'
  Plug 'scrooloose/nerdtree'
  Plug 'alvan/vim-closetag'
  Plug 'Valloric/MatchTagAlways', { 'for': ['html', 'xml', 'java']  }
  let g:closetag_filenames = "*.html,*.xhtml,*.phtml"
  Plug 'junegunn/vim-easy-align'
 "Plug 'junegunn/limelight.vim'
 "Plug 'junegunn/vim-peekaboo'
  Plug 'junegunn/rainbow_parentheses.vim'
 "Plug 'whatyouhide/vim-lengthmatters'
 "Plug 'whatyouhide/vim-gotham'
 "Plug 'jaxbot/browserlink.vim', { 'for': ['html', 'javascript', 'css']  }
  Plug 'christoomey/vim-titlecase'
  let g:titlecase_map_keys = 0
  nmap <leader>gt <Plug>Titlecase
  vmap <leader>gt <Plug>Titlecase
  nmap <leader>gT <Plug>TitlecaseLine

 "augroup htmlupdater
 "    au!
 "    au TextChanged *.html,*.js,*.css,*.md :write
 "    au TextChanged *.html,*.js,*.css,*.md :BLReloadPage
 "    au FileType html,css,javascript,markdown inoremap <buffer> <silent> <ESC> <ESC>:write<CR>:BLReloadPage<CR>
 "   "au FileType html,xlm inoremap <silent> > ><C-o>:noautocmd normal F<"tyf>f>"tpF<a/hi<CR>
 "augroup END

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

 inoremap <C-G><BS> <Left>
 inoremap <C-G>h     <Left>
 inoremap <C-G><C-L> <Right>
 inoremap <C-G>l     <Right>

 if has('nvim')
     tnoremap <C-e><C-e> <C-\><C-n>
     autocmd! TermOpen * setlocal listchars=tab:▸\ ,trail:\ ,precedes:↤,extends:↦
     highlight TermCursor ctermfg=darkgreen guifg=darkgreen
     highlight TermCursorNC ctermfg=lightgreen guifg=darkgreen
 endif
" Use 256 colours (Use this setting only if your terminal supports 256 colours)
