" Ilargi for Vim

set background=dark
hi clear
if exists('syntax_on') | syntax reset | endif
let g:colors_name = 'ilargi'

let s:c = {
      \ 'bg':    '#0c0e0f',  'bg1': '#101213',  'bg2': '#161819',
      \ 'bg3':   '#1b1d1e',    'bg4': '#27292a',    'grey': '#343637',
      \ 'muted': '#484a4b', 'faint': '#6c6e6f', 'dim': '#a9abac',
      \ 'fg':    '#edeff0',
      \ 'red':   '#df5b61',    'pink': '#e8646a',  'peach': '#de8f78',
      \ 'sun':   '#ecd28b',    'green': '#78b892', 'cyan': '#67afc1',
      \ 'blue':  '#6791c9',   'blue2': '#709ad2', 'magenta': '#bc83e3',
      \ }

function! s:hi(group, fg, bg, ...) abort
  let l:attr = a:0 ? a:1 : 'NONE'
  let l:fg = a:fg ==# 'NONE' ? 'NONE' : s:c[a:fg]
  let l:bg = a:bg ==# 'NONE' ? 'NONE' : s:c[a:bg]
  exec 'hi ' . a:group . ' guifg=' . l:fg . ' guibg=' . l:bg . ' gui=' . l:attr . ' cterm=' . l:attr
endfunction

call s:hi('Normal',       'fg',    'NONE')
call s:hi('NormalNC',     'fg',    'NONE')
call s:hi('LineNr',       'muted', 'NONE')
call s:hi('CursorLineNr', 'blue',  'NONE', 'bold')
call s:hi('CursorLine',   'NONE',  'bg1')
call s:hi('CursorColumn', 'NONE',  'bg1')
call s:hi('ColorColumn',  'NONE',  'bg1')
call s:hi('SignColumn',   'NONE',  'NONE')
call s:hi('FoldColumn',   'muted', 'NONE')
call s:hi('Folded',       'dim',   'bg2')
call s:hi('NonText',      'grey',  'NONE')
call s:hi('EndOfBuffer',  'grey',  'NONE')
call s:hi('SpecialKey',   'grey',  'NONE')
call s:hi('Whitespace',   'grey',  'NONE')
call s:hi('Conceal',      'muted', 'NONE')
call s:hi('VertSplit',    'bg4',   'NONE')
call s:hi('WinSeparator', 'bg4',   'NONE')
call s:hi('Visual',       'NONE',  'bg4')
call s:hi('VisualNOS',    'NONE',  'bg4')
call s:hi('MatchParen',   'sun',   'bg4', 'bold')
call s:hi('Search',       'bg',    'sun')
call s:hi('IncSearch',    'bg',    'blue', 'bold')
call s:hi('CurSearch',    'bg',    'blue', 'bold')
call s:hi('Substitute',   'bg',    'peach')
call s:hi('Cursor',       'bg',    'fg')
call s:hi('Directory',    'blue',  'NONE')
call s:hi('Title',        'blue',  'NONE', 'bold')
call s:hi('Question',     'green', 'NONE')
call s:hi('MoreMsg',      'green', 'NONE')
call s:hi('ModeMsg',      'blue',  'NONE', 'bold')
call s:hi('WarningMsg',   'peach', 'NONE')
call s:hi('ErrorMsg',     'red',   'NONE', 'bold')

call s:hi('StatusLine',       'fg',    'bg3')
call s:hi('StatusLineNC',     'dim',   'bg2')
call s:hi('StatusLineTerm',   'fg',    'bg3')
call s:hi('StatusLineTermNC', 'dim',   'bg2')
call s:hi('TabLine',          'dim',   'bg2')
call s:hi('TabLineFill',      'NONE',  'NONE')
call s:hi('TabLineSel',       'bg',    'blue', 'bold')
call s:hi('WildMenu',         'bg',    'blue', 'bold')
call s:hi('Pmenu',            'fg',    'bg2')
call s:hi('PmenuSel',         'bg',    'blue', 'bold')
call s:hi('PmenuSbar',        'NONE',  'bg3')
call s:hi('PmenuThumb',       'NONE',  'bg4')
call s:hi('PmenuKind',        'magenta', 'bg2')
call s:hi('PmenuExtra',       'dim',   'bg2')
call s:hi('QuickFixLine',     'NONE',  'bg3', 'bold')

call s:hi('DiffAdd',    'green', 'bg2')
call s:hi('DiffChange', 'peach', 'bg2')
call s:hi('DiffDelete', 'red',   'bg2')
call s:hi('DiffText',   'bg',    'peach')
call s:hi('Added',      'green', 'NONE')
call s:hi('Changed',    'peach', 'NONE')
call s:hi('Removed',    'red',   'NONE')
exec 'hi SpellBad   gui=undercurl guisp=' . s:c.red    . ' cterm=underline'
exec 'hi SpellCap   gui=undercurl guisp=' . s:c.blue   . ' cterm=underline'
exec 'hi SpellRare  gui=undercurl guisp=' . s:c.magenta . ' cterm=underline'
exec 'hi SpellLocal gui=undercurl guisp=' . s:c.cyan   . ' cterm=underline'

call s:hi('Comment',     'faint',   'NONE', 'italic')
call s:hi('Constant',    'peach',   'NONE')
call s:hi('String',      'green',   'NONE')
call s:hi('Character',   'green',   'NONE')
call s:hi('Number',      'peach',   'NONE')
call s:hi('Boolean',     'peach',   'NONE')
call s:hi('Float',       'peach',   'NONE')
call s:hi('Identifier',  'fg',      'NONE')
call s:hi('Function',    'blue',    'NONE')
call s:hi('Statement',   'magenta', 'NONE')
call s:hi('Conditional', 'magenta', 'NONE')
call s:hi('Repeat',      'magenta', 'NONE')
call s:hi('Label',       'magenta', 'NONE')
call s:hi('Operator',    'cyan',    'NONE')
call s:hi('Keyword',     'magenta', 'NONE')
call s:hi('Exception',   'red',     'NONE')
call s:hi('PreProc',     'cyan',    'NONE')
call s:hi('Include',     'magenta', 'NONE')
call s:hi('Define',      'magenta', 'NONE')
call s:hi('Macro',       'cyan',    'NONE')
call s:hi('PreCondit',   'cyan',    'NONE')
call s:hi('Type',        'sun',     'NONE')
call s:hi('StorageClass','magenta', 'NONE')
call s:hi('Structure',   'sun',     'NONE')
call s:hi('Typedef',     'sun',     'NONE')
call s:hi('Special',     'cyan',    'NONE')
call s:hi('SpecialChar', 'pink',    'NONE')
call s:hi('Tag',         'blue',    'NONE')
call s:hi('Delimiter',   'dim',     'NONE')
call s:hi('SpecialComment', 'faint', 'NONE', 'bold')
call s:hi('Debug',       'red',     'NONE')
call s:hi('Underlined',  'blue2',   'NONE', 'underline')
call s:hi('Ignore',      'grey',    'NONE')
call s:hi('Error',       'red',     'NONE', 'bold')
call s:hi('Todo',        'bg',      'sun',  'bold')

call s:hi('markdownH1',       'red',     'NONE', 'bold')
call s:hi('markdownH2',       'peach',   'NONE', 'bold')
call s:hi('markdownH3',       'sun',     'NONE', 'bold')
call s:hi('markdownH4',       'green',   'NONE', 'bold')
call s:hi('markdownH5',       'blue',    'NONE', 'bold')
call s:hi('markdownH6',       'magenta', 'NONE', 'bold')
call s:hi('markdownCode',     'blue2',   'NONE')
call s:hi('markdownCodeBlock','green',   'NONE')
call s:hi('markdownLinkText', 'blue2',   'NONE', 'underline')
call s:hi('markdownUrl',      'faint',   'NONE')
call s:hi('shDerefSimple',    'cyan',    'NONE')
call s:hi('shVariable',       'fg',      'NONE')
call s:hi('pythonBuiltin',    'cyan',    'NONE')
call s:hi('pythonDecorator',  'pink',    'NONE')
call s:hi('jsonKeyword',      'blue',    'NONE')
call s:hi('yamlKey',          'blue',    'NONE')
call s:hi('htmlTag',          'dim',     'NONE')
call s:hi('htmlTagName',      'blue',    'NONE')
call s:hi('htmlArg',          'sun',     'NONE')
