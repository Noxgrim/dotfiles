let g:surround_{char2nr("“")} = "“\r”"
let g:surround_{char2nr("‘")} = "‘\r’"
let g:surround_{char2nr("„")} = "„\r“"
let g:surround_{char2nr("‚")} = "‚\r‘"
let g:surround_{char2nr("»")} = "»\r«"
let g:surround_{char2nr("›")} = "›\r‹"
let g:surround_{char2nr("«")} = "«\r»"
let g:surround_{char2nr("‹")} = "‹\r›"
let g:surround_custom_target_pairs = {
            \ '“': '“”',
            \ '‘': '‘’',
            \ '„': '„“',
            \ '‚': '‚‘',
            \ '»': '»«',
            \ '›': '›‹',
            \ '«': '«»',
            \ '‹': '‹›'
            \ }
