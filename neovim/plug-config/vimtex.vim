"let $success_cmd = 'latexmk -c;'
let g:tex_flavor = "latex"
let g:vimtex_view_method = 'zathura'
if has('nvim')
  let g:vimtex_compiler_progname = "nvr"
endif

augroup noxgrim_vimtext_close_hook
  autocmd!
  autocmd User VimtexEventQuit     call vimtex#compiler#clean(0)
  autocmd User VimtexEventInitPost call vimtex#compiler#compile()
augroup END
