" Implement own function to save files as super user
" to allow no or one argument.
" @file the file to open (defaults to % if empty)
function! <SID>noxgrim_sudo_write(file)
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

command! -nargs=? -complete=file Swrite call <SID>noxgrim_sudo_write('<args>')

command! -nargs=? -complete=file FocusFloating call <SID>noxgrim_focus_floating('<args>')
nnoremap <silent> <leader>F :<C-U>call <SID>noxgrim_focus_floating(v:count1)<CR>
