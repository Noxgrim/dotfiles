" Plugin specific mappings can be found in the pugin configurations

" Map leader
let mapleader      = "\<Space>"
let maplocalleader = "_"

" Line numbers
noremap <C-N><C-N> :set invnumber<CR>
noremap <C-N><C-R> :set invrelativenumber<CR>

" Reset and re-draw
nnoremap <silent> <C-l> :nohlsearch<CR>:syntax sync fromstart<CR><c-l>

" Open lines without entering insert mode
nnoremap <leader>Lj o<ESC>
nnoremap <leader>Lk O<ESC>
if has('nvim') " This is currently used by tmux
    nnoremap <A-j> o<ESC>k
    nnoremap <A-k> O<ESC>j
endif

" Do not move hands in insert mode
inoremap <C-G><BS>  <Left>
inoremap <C-G>h     <Left>
inoremap <C-G><C-L> <Right>
inoremap <C-G>l     <Right>

" Mapping to escape
if has('nvim')
    tnoremap <C-e><C-e> <C-\><C-n>
endif

" save from insert mode
inoremap <silent> <C-s> <Esc>:update<CR>a
nnoremap <silent> <C-s> :update<CR>

nnoremap n nzz
nnoremap N Nzz
