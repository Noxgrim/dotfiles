" “”
call lexima#add_rule({'char': '“', 'input_after': '”'})
call lexima#add_rule({'char': '”', 'at': '\%#”', 'leave': 1})
call lexima#add_rule({'char': '<BS>', 'at': '“\%#”', 'delete': 1})

" ‘’
call lexima#add_rule({'char': '‘', 'input_after': '’'})
call lexima#add_rule({'char': '’', 'at': '\%#’', 'leave': 1})
call lexima#add_rule({'char': '<BS>', 'at': '‘\%#’', 'delete': 1})

" „“
call lexima#add_rule({'char': '„', 'input_after': '“'})
call lexima#add_rule({'char': '“', 'at': '\%#“', 'leave': 1, 'priority': 1})
call lexima#add_rule({'char': '<BS>', 'at': '„\%#“', 'delete': 1})

" ‚‘
call lexima#add_rule({'char': '‚', 'input_after': '‘'})
call lexima#add_rule({'char': '‘', 'at': '\%#‘', 'leave': 1, 'priority': 1})
call lexima#add_rule({'char': '<BS>', 'at': '‚\%#‘', 'delete': 1})

" »«
call lexima#add_rule({'char': '»', 'input_after': '«'})
call lexima#add_rule({'char': '«', 'at': '\%#«', 'leave': 1})
call lexima#add_rule({'char': '<BS>', 'at': '»\%#«', 'delete': 1})

" ›‹
call lexima#add_rule({'char': '›', 'input_after': '‹'})
call lexima#add_rule({'char': '‹', 'at': '\%#‹', 'leave': 1})
call lexima#add_rule({'char': '<BS>', 'at': '›\%#‹', 'delete': 1})

" Extension to ``` rule for markdown
call lexima#add_rule({'char': '<CR>', 'at': '```\w*\%#```', 'input_after': '<CR>'})
call lexima#add_rule({'char': '<CR>', 'at': '```\w*\%#$', 'input_after': '<CR>```', 'except': '\C\v^(\s*)\S.*%#\n%(%(\s*|\1.+)\n)*\1```'})
