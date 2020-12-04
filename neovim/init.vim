set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath

source $HOME/.config/nvim/config/settings.vim
source $HOME/.config/nvim/config/mappings.vim
source $HOME/.config/nvim/config/functions.vim


source $HOME/.config/nvim/plug-config/vimplug.vim
let g:noxgrim_coc_extensions = [
            \ 'coc-clangd', 'coc-git', 'coc-java', 'coc-python', 'coc-json',
            \ 'coc-rls', 'coc-sh', 'coc-snippets', 'coc-tsserver', 'coc-vimlsp',
            \ 'coc-vimtex', 'coc-yank', 'coc-julia' ]

source $HOME/.config/nvim/plug-config/vim-airline.vim

source $HOME/.config/nvim/plug-config/vim-sneak.vim
if ! exists('g:is_manpage') || ! g:is_manpage
    source $HOME/.config/nvim/plug-config/coc.vim
    source $HOME/.config/nvim/plug-config/coc-snippets.vim
    source $HOME/.config/nvim/plug-config/vimtex.vim
    source $HOME/.config/nvim/plug-config/vim-easy-align.vim
    source $HOME/.config/nvim/plug-config/vim-titlecase.vim
    source $HOME/.config/nvim/plug-config/vim-closetag.vim
    source $HOME/.config/nvim/plug-config/vim-which-key.vim
endif
" source $HOME/.config/nvim/plug-config/browserlink.vim



function! s:PostLoad()
    if ! exists('g:is_manpage') || ! g:is_manpage
        "source $HOME/.config/nvim/plug-config/auto-pairs.post-load.vim
        source $HOME/.config/nvim/plug-config/lexima.post-load.vim
        source $HOME/.config/nvim/plug-config/vim-which-key.post-load.vim
        source $HOME/.config/nvim/plug-config/coc.post-load.vim
    endif
endfunction
augroup noxgrim_setting_post_load_plugins
    autocmd!
    autocmd VimEnter * :call s:PostLoad()
augroup END

" Themes
set background=dark
colorscheme onedark
