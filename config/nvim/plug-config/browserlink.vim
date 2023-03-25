augroup noxgrim_htmlupdater
    au!
    au TextChanged *.html,*.js,*.css,*.md :write
    au TextChanged *.html,*.js,*.css,*.md :BLReloadPage
    au FileType html,css,javascript,markdown inoremap <buffer> <silent> <ESC> <ESC>:write<CR>:BLReloadPage<CR>
   "au FileType html,xlm inoremap <silent> > ><C-o>:noautocmd normal F<"tyf>f>"tpF<a/hi<CR>
augroup END
