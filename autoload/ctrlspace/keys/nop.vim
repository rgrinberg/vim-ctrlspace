let s:modes  = ctrlspace#modes#Modes()

function! ctrlspace#keys#nop#Init() abort
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#ToggleHelp",                   "Nop", ["?"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#BackOrClearSearch",            "Nop", ["BS", 'C-h'])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#EnterSearchMode",              "Nop", ["/"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#ToggleFileMode",               "Nop", ["o"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#ToggleFileModeAndSearch",      "Nop", ["O"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#ToggleBufferMode",             "Nop", ["h"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#ToggleBufferModeAndSearch",    "Nop", ["H"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#ToggleWorkspaceMode",          "Nop", ["w"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#ToggleWorkspaceModeAndSearch", "Nop", ["W"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#ToggleTabMode",                "Nop", ["l"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#ToggleTabModeAndSearch",       "Nop", ["L"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#ToggleBookmarkMode",           "Nop", ["b"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#ToggleBookmarkModeAndSearch",  "Nop", ["B"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#Close",                        "Nop", ["q", "Esc", 'C-c'])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#RestorePreviousSearch",        "Nop", ['C-p'])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#common#RestoreNextSearch",            "Nop", ['C-n'])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#buffer#NewWorkspace",                 "Nop", ["N"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#nop#ToggleAllMode",                   "Nop", ["a"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#nop#ToggleAllModeAndSearch",          "Nop", ["A"])
endfunction

function! ctrlspace#keys#nop#ToggleAllMode(k) abort
    if s:modes.Buffer.Enabled
        call ctrlspace#keys#buffer#ToggleAllMode(a:k)
    endif
endfunction

function! ctrlspace#keys#nop#ToggleAllModeAndSearch(k) abort
    if s:modes.Buffer.Enabled
        call ctrlspace#keys#buffer#ToggleAllModeAndSearch(a:k)
    endif
endfunction


" -----------------------------
" Dbmdex: DouBle MoDe EXception
" -----------------------------

" Define keymappings for combined NOP+<Mode> mode inside the following Initiator,
" where <Mode> is a ListView mode such as BUFFER, FILE, BOOKMARK, etc.
function! ctrlspace#keys#nop#DbmdexInit() abort abort
    call s:AddDbmdexMapping("ctrlspace#keys#buffer#MoveTab",       "Buffer", ["+", "-"])
    call s:AddDbmdexMapping("ctrlspace#keys#buffer#SwitchTab",     "Buffer", ["[", "]"])
    call s:AddDbmdexMapping("ctrlspace#keys#file#Refresh",         "File",   ["r"])
endfunction

" Function used to add these Dbmdex mappings
" Its signature is the same as that of ctrlspace#keys#AddMapping
function! s:AddDbmdexMapping(actionName, excpMode, keys) abort abort
    call ctrlspace#keys#AddMapping(function('ctrlspace#keys#nop#_ExecDbmdexAction', 
                                           \ [a:excpMode, a:actionName]), 
                                  \ "Nop", a:keys)
endfunction

" Function that wraps the action normally available in <Mode>, and makes it
" available when CtrlSpace is in the double-mode enabled state of NOP + <Mode>
function! ctrlspace#keys#nop#_ExecDbmdexAction(excpMode, actionName, k) abort abort
    if s:modes[a:excpMode].Enabled
        call function(a:actionName)(a:k)
    else
        call ctrlspace#keys#Undefined(a:k)
    endif
endfunction
