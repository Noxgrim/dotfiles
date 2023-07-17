" Escape for the {string} in a 'substitute' command or function. ',' will also
" be escaped for string.
" @str the string to escape
function s:escape_re(str) abort
    return escape(a:str, ' \,' . (&magic ? '&~' : ''))
endfunction

" Implement own function to save files as super user
" to allow no or one argument.
" @file the file to open (defaults to % if empty)
function! s:noxgrim_sudo_write(file)
    if len(a:file)
        execute "w !sudo tee > /dev/null " . fnameescape(a:file)
    else
        w !sudo tee > /dev/null %
    endif
endfunction

" Try to focus a floating window in Neovim or popup in Vim
" @num the number of floating window or popup to fucus (defaults to 1 if
"      empty)
function! <SID>noxgrim_focus_floating(num)
    if len(a:num)
        let l:num = a:num
    else
        let l:num = 1
    endif
    let l:win_num = 1

    if has('nvim')
        let l:windows = nvim_tabpage_list_wins(nvim_get_current_tabpage())
    else
        let l:windows = popup_list()
    endif

    for l:window in l:windows
        if has('nvim')
            let l:win_config = nvim_win_get_config(l:window)
        endif

        if !has('nvim') ||  l:win_config.relative != '' && !l:win_config.external
            if l:win_num == l:num
                call win_gotoid(l:window)
                return
            else
                let l:win_num += 1
            endif
        endif
    endfor

    echohl WarningMsg
    echomsg "Could not find " .
                \ ( has('nvim') ? "floating" : "popup" ) .
                \ " window number " . l:num . "!"
    echohl None
endfunction

" Surround the given range with comments intended for marked folding, This
" function will try to respect the b:commentary_format (from 'commenary') and
" if that's not set &commentstring. The function will close the created fold
" if the &foldmethod = merker.
"
" @name the name to give to the fold. If empty the function will query it and
"       only continue if it is non-empty.
function! Nfold(name) range
    let l:foldname = a:name

    if empty(l:foldname)
        let l:foldname = input('Fold name: ')
    endif
    if empty(l:foldname)
        return
    endif
    let l:folds = split(&foldmarker, ',')
    if exists("b:commentary_format")
        let l:form = b:commentary_format
    elseif &commentstring =~? '%s'
        let l:form = &commentstring
    else
        let l:form = '# %s'
    endif
    exe a:lastline  . 's,$,\r' . s:escape_re(substitute(l:form, '%s', s:escape_re('/' . l:foldname . ' ' . folds[1]), ''))
    exe a:firstline . 's,^,'   . s:escape_re(substitute(l:form, '%s', s:escape_re(' ' . l:foldname . ' ' . folds[0]), '')) . '\r'
    if &foldmethod ==# "marker"
        exe (a:lastline + 1) . "norm! zc"
        return
    endif
endfunction

vnoremap <leader>z :call Nfold("")<CR>

command! -nargs=? -complete=file Swrite call <SID>noxgrim_sudo_write('<args>')

command! -nargs=? -complete=file FocusFloating call <SID>noxgrim_focus_floating('<args>')
nnoremap <silent> <leader>F :<C-U>call <SID>noxgrim_focus_floating(v:count1)<CR>
