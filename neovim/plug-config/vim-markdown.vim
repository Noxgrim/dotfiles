let g:vim_markdown_conceal = 2
let g:vim_markdown_conceal_code_blocks = 1
let g:vim_markdown_math = 1
let g:vim_markdown_toml_frontmatter = 1
let g:vim_markdown_frontmatter = 1
let g:vim_markdown_strikethrough = 1
let g:vim_markdown_autowrite = 1
let g:vim_markdown_edit_url_in = 'tab'
let g:vim_markdown_follow_anchor = 1
let g:vim_markdown_folding_disabled = 1

augroup noxgrim_markdown_settings
    autocmd!

    autocmd FileType markdown set conceallevel=2 concealcursor=cv
    autocmd FileType markdown set shiftwidth=2 tabstop=2 softtabstop=2
    autocmd FileType markdown set textwidth=80
augroup END
