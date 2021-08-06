scriptencoding utf-8

let s:pluginBuffer = -1

let s:configuration = {
                    \ "defaultSymbols": {
                    \     "unicode": {
                    \         "CS":     "⌗",
                    \         "Sin":    "•",
                    \         "All":    "፨",
                    \         "Vis":    "★",
                    \         "File":   "○",
                    \         "Tabs":   "▫",
                    \         "CTab":   "▪",
                    \         "NTM":    "⁺",
                    \         "WLoad":  "⬆",
                    \         "WSave":  "⬇",
                    \         "Zoom":   "⌕",
                    \         "SLeft":  "›",
                    \         "SRight": "‹",
                    \         "BM":     "♥",
                    \         "Help":   "?",
                    \         "IV":     "☆",
                    \         "IA":     "★",
                    \         "IM":     "+",
                    \         "Dots":   "…"
                    \     },
                    \     "ascii": {
                    \         "CS":     "#",
                    \         "Sin":    "SIN",
                    \         "All":    "ALL",
                    \         "Vis":    "VIS",
                    \         "File":   "FILE",
                    \         "Tabs":   "-",
                    \         "CTab":   "+",
                    \         "NTM":    "+",
                    \         "WLoad":  "|*|",
                    \         "WSave":  "[*]",
                    \         "Zoom":   "*",
                    \         "SLeft":  "[",
                    \         "SRight": "]",
                    \         "BM":     "BM",
                    \         "Help":   "?",
                    \         "IV":     "-",
                    \         "IA":     "*",
                    \         "IM":     "+",
                    \         "Dots":   "..."
                    \     }
                    \ },
                    \ "Height":                    1,
                    \ "MaxHeight":                 0,
                    \ "SetDefaultMapping":         1,
                    \ "DefaultMappingKey":         "<C-Space>",
                    \ "Keys":                      {},
                    \ "Help":                      {},
                    \ "SortHelp":                  0,
                    \ "GlobCommand":               "",
                    \ "EnableFilesCache":          1,
                    \ "UseTabline":                1,
                    \ "UseArrowsInTerm":           0,
                    \ "UseMouseAndArrowsInTerm":   0,
                    \ "StatuslineFunction":        "ctrlspace#api#Statusline()",
                    \ "SaveWorkspaceOnExit":       0,
                    \ "SaveWorkspaceOnSwitch":     0,
                    \ "LoadLastWorkspaceOnStart":  0,
                    \ "EnableBufferTabWrapAround": 1,
                    \ "ProjectRootMarkers":        [".git", ".hg", ".svn", ".bzr", "_darcs", "CVS"],
                    \ "UseUnicode":                1,
                    \ "SearchTiming":              60,
                    \ }

function! s:init() abort
    let s:conf = copy(s:configuration)

    for name in keys(s:conf)
        if exists("g:CtrlSpace" . name)
            let s:conf[name] = g:{"CtrlSpace" . name}
        endif
    endfor

    let s:conf.Symbols = copy(s:conf.UseUnicode ? s:conf.defaultSymbols.unicode : s:conf.defaultSymbols.ascii)

    if exists("g:CtrlSpaceSymbols")
        call extend(s:conf.Symbols, g:CtrlSpaceSymbols)
    endif

    let s:symbolSizes = {
                      \ "IAV":  max([strwidth(s:conf.Symbols.IV), strwidth(s:conf.Symbols.IA)]),
                      \ "IM":   strwidth(s:conf.Symbols.IM),
                      \ "Dots": strwidth(s:conf.Symbols.Dots)
                      \ }
endfunction

call s:init()

function! ctrlspace#context#SymbolSizes() abort
    return s:symbolSizes
endfunction

function! ctrlspace#context#Configuration() abort
    return s:conf
endfunction
