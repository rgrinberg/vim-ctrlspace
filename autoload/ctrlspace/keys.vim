let s:config         = ctrlspace#context#Configuration()
let s:modes          = ctrlspace#modes#Modes()
let s:keyNames       = []
let s:keyMap         = {}
let s:characters     = {}
let s:keyEscSequence = 0

function! ctrlspace#keys#KeyNames() abort
    return s:keyNames
endfunction

function! ctrlspace#keys#CharacterClasses() abort
    return s:characters
endfunction

function! ctrlspace#keys#KeyMap() abort
    return s:keyMap
endfunction

function! ctrlspace#keys#MarkKeyEscSequence() abort
    let s:keyEscSequence = 1
endfunction

function! ctrlspace#keys#Init() abort
    call s:initKeyNames()
    call s:initKeyMap()
    call ctrlspace#keys#common#Init()
    call ctrlspace#keys#help#Init()
    call ctrlspace#keys#nop#Init()
    call ctrlspace#keys#search#Init()
    call ctrlspace#keys#buffer#Init()
    call ctrlspace#keys#file#Init()
    call ctrlspace#keys#tab#Init()
    call ctrlspace#keys#workspace#Init()
    call ctrlspace#keys#bookmark#Init()
    call s:initCustomMappings()
    call ctrlspace#keys#nop#DbmdexInit()
endfunction

function! s:initCustomMappings() abort
    for m in ["Search", "Help", "Nop", "Buffer", "File", "Tab", "Workspace", "Bookmark"]
        if has_key(s:config.Keys, m)
            for [k, fn] in items(s:config.Keys[m])
                " normalize synomymous keynames Enter, Return and CR all to CR
                let k = (k ==? 'return' || k ==? 'enter' ? 'CR' : k)
                call ctrlspace#keys#AddMapping(fn, m, [k])
            endfor
        endif
    endfor
endfunction

function! s:initKeyNames() abort
    let lowercase = "q w e r t y u i o p a s d f g h j k l z x c v b n m"
    let uppercase = toupper(lowercase)

    let controlList = []

    for l in split(lowercase, " ")
        call add(controlList, "C-" . l)
    endfor

    call add(controlList, "C-^")
    call add(controlList, "C-]")

    let controls = join(controlList, " ")

    let numbers  = "1 2 3 4 5 6 7 8 9 0"
    let punctuation = "; : , . < > [ ] { } ( ) ' ` ~ + - _ = ! @ # $ % ^ & * / \ " . 
                \ '"'
    let specials = "Space CR BS Tab S-Tab / ? C-f C-b C-u C-d C-h C-w " .
                 \ "Bar BSlash MouseDown MouseUp LeftDrag LeftRelease 2-LeftMouse " .
                 \ "Down Up Home End Left Right PageUp PageDown " .
                 \ "F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12"

    if !s:config.UseMouseAndArrowsInTerm || has("gui_running")
        let specials .= " Esc"
    endif

    let specials .= (has("gui_running") || has("win32")) ? " C-Space" : " Nul"

    let keyNames = split(join([lowercase, uppercase, controls, numbers, punctuation, specials], " "), " ")

    " won't work with leader mappings
    if ctrlspace#keys#IsDefaultKey()
        for i in range(len(keyNames))
            let fullKeyName = (strlen(keyNames[i]) > 1) ? ("<" . keyNames[i] . ">") : keyNames[i]

            if fullKeyName ==# ctrlspace#keys#DefaultKey()
                call remove(keyNames, i)
                break
            endif
        endfor
    endif

    let s:keyNames             = keyNames
    let s:characters.lowercase = split(lowercase, " ")
    let s:characters.uppercase = split(uppercase, " ")
    let s:characters.controls  = split(controls, " ")
    let s:characters.numbers   = split(numbers, " ")
    let s:characters.punctuation   = split(punctuation, " ")
    let s:characters.specials  = split(specials, " ")
endfunction

function! ctrlspace#keys#Undefined(k) abort
    call ctrlspace#ui#Msg("Key '" . a:k . "' doesn't work in this view.")
endfunction

function! s:initKeyMap() abort
    let Undefined = function("ctrlspace#keys#Undefined")
    let blankMap    = {}

    for k in s:keyNames
        let blankMap[k] = Undefined
    endfor

    for m in ["Search", "Help", "Nop", "Buffer", "File", "Tab", "Workspace", "Bookmark"]
        let s:keyMap[m] = copy(blankMap)
    endfor
endfunction

function! ctrlspace#keys#AddMapping(funcName, mapName, keys) abort
    let keys = []

    for entry in a:keys
        if has_key(s:characters, entry)
            call extend(keys, s:characters[entry])
        else
            call add(keys, entry)
        endif

        call ctrlspace#help#AddMapping(a:funcName, a:mapName, entry)
    endfor

    let FuncRef = function(a:funcName)

    for k in keys
        let s:keyMap[a:mapName][k] = FuncRef
    endfor
endfunction

function! ctrlspace#keys#Keypressed(key) abort
    let key = (s:keyEscSequence && (a:key ==# "Z")) ? "S-Tab" : a:key
    let s:keyEscSequence = 0

    if s:modes.Help.Enabled
        let mapName = "Help"
    elseif s:modes.Search.Enabled
        let mapName = "Search"
    elseif s:modes.Nop.Enabled
        let mapName = "Nop"
    else
        let mapName = ctrlspace#modes#CurrentListView().Name
    endif

    call s:keyMap[mapName][key](key)
endfunction

function! ctrlspace#keys#SetDefaultMapping(key, action) abort
    let s:defaultKey = a:key
    if empty(s:defaultKey)
        return
    endif

    if s:defaultKey ==? "<C-Space>" && !has("gui_running") && !has("win32")
        let s:defaultKey = "<Nul>"
    endif

    silent! exe 'nnoremap <unique><silent>' . s:defaultKey . ' ' . a:action
endfunction

function! ctrlspace#keys#IsDefaultKey() abort
    return exists("s:defaultKey")
endfunction

function! ctrlspace#keys#DefaultKey() abort
    return s:defaultKey
endfunction
