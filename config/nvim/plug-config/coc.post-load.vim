" Install all extensions that are not found in the directory for CoC
let s:command = ''
let s:extension_directories = map(globpath(
            \ '~/.config/coc/extensions/node_modules', "*/", v:false, v:true),
            \ {_, v -> fnamemodify(v, ":p:h:t")})
for s:extension in g:noxgrim_coc_extensions
    if index(s:extension_directories, s:extension) == -1
        let s:command .= ' ' . s:extension
    endif
endfor

if !empty(s:command)
    execute 'CocInstall ' . s:command
endif
" make sure that this has precedence
" inoremap <expr> <CR> coc#pum#visible() ? coc#_select_confirm() : lexima#expand('<CR>', 'i')
