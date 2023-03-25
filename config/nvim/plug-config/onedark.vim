if (has("nvim"))
    "For Neovim 0.1.3 and 0.1.4 < https://github.com/neovim/neovim/pull/2198 >
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
endif
let g:onedark_terminal_italics = 1
if (has("termguicolors"))
    set termguicolors
endif
