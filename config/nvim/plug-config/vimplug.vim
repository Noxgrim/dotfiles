" Install vim-plug if not found
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

call plug#begin('~/.vim/plugged')

Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'joshdick/onedark.vim'
Plug 'justinmk/vim-sneak'

if ! exists('g:is_manpage') || ! g:is_manpage
    "Plug 'jaxbot/browserlink.vim', { 'for': ['html', 'javascript', 'css']  }
    "Plug 'jiangmiao/auto-pairs'
    "Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    "Plug 'junegunn/fzf.vim'
    "Plug 'junegunn/limelight.vim'
    "Plug 'junegunn/vim-peekaboo'
    "Plug 'scrooloose/syntastic'
    "Plug 'sunaku/vim-shortcut'
    "Plug 'whatyouhide/vim-gotham'
    "Plug 'whatyouhide/vim-lengthmatters'
    "Plug 'altercation/vim-colors-solarized'
    "Plug 'wsdjeg/vim-chapel'
    "Plug 'neovimhaskell/haskell-vim'
    "Plug 'whonore/Coqtail'
    "Plug 'junegunn/rainbow_parentheses.vim'
    Plug 'Valloric/MatchTagAlways', { 'for': ['html', 'xml', 'java']  }
    Plug 'airblade/vim-gitgutter'
    Plug 'alvan/vim-closetag'
    Plug 'b4winckler/vim-angry'
    Plug 'chaimleib/vim-renpy'
    Plug 'christoomey/vim-titlecase'
    Plug 'cohama/lexima.vim'
    Plug 'easymotion/vim-easymotion'
    Plug 'haya14busa/vim-easyoperator-line'
    Plug 'haya14busa/vim-easyoperator-phrase'
    Plug 'honza/vim-snippets'
    Plug 'junegunn/gv.vim'
    Plug 'junegunn/vim-easy-align'
    Plug 'lervag/vimtex'
    Plug 'liuchengxu/vim-which-key'
    Plug 'mbbill/undotree'
    Plug 'neoclide/coc.nvim', {'branch': 'release'}
    Plug 'rhysd/vim-grammarous'
    Plug 'scrooloose/nerdtree'
    Plug 'sheerun/vim-polyglot'
    Plug 'tpope/vim-commentary'
    Plug 'tpope/vim-fugitive'
    Plug 'tpope/vim-repeat'
    Plug 'tpope/vim-surround'
    Plug 'tpope/vim-unimpaired'
    Plug 'vim-scripts/gnupg.vim'
    Plug 'w0rp/ale'
    Plug 'godlygeek/tabular'
    Plug 'plasticboy/vim-markdown'
    Plug 'junegunn/vim-emoji'
    Plug 'vim-utilities/emoji-syntax'
    Plug 'petrisch/vim-ifc'
endif
call plug#end()


" Run PlugInstall if there are missing plugins
if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

