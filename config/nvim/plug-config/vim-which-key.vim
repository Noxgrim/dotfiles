" Stolen from
" https://github.com/ChristianChiarulli/nvim/blob/master/keys/which-key.vim

" Define a separator
let g:which_key_sep = '→'
" set timeoutlen=100

" Coc Search & refactor
" Not a fan of floating windows for this
let g:which_key_use_floating_win = 0

" Change the colors if you want
highlight default link WhichKey          Operator
highlight default link WhichKeySeperator DiffAdded
highlight default link WhichKeyGroup     Identifier
highlight default link WhichKeyDesc      Function

" Hide status line

" Store previous state and syntax highlighting and set setting for the line
" as well as highlighting of trailing white space
function s:EnterWhichKeyBuffer()
    redir => s:pre_vwk_hl_settings
        highlight ExtraWhitespace
    redir END
    let s:pre_vwk_laststaus = &laststatus
    let s:pre_vwk_showmode = &showmode
    let s:pre_vwk_ruler = &ruler

    highlight ExtraWhitespace NONE
    setlocal laststatus=0 noshowmode noruler

    autocmd BufLeave <buffer> :call s:LeaveWhichKeyBuffer()
endfunction
"
" Restore previous state and syntax highlighting
function s:LeaveWhichKeyBuffer()
    let &laststatus = s:pre_vwk_laststaus
    let &showmode = s:pre_vwk_showmode
    let &ruler = s:pre_vwk_ruler
    execute 'highlight ' . substitute(s:pre_vwk_hl_settings, "xxx \\|\n", "", "g")
endfunction

augroup noxgrim_setting_vim_which_key
    autocmd!

    autocmd FileType which_key :call s:EnterWhichKeyBuffer()
augroup END
