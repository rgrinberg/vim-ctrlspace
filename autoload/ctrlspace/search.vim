let s:modes               = ctrlspace#modes#Modes()
let s:updateSearchResults = 0

function! ctrlspace#search#UpdateSearchResults() abort
    if s:updateSearchResults
        let s:updateSearchResults = 0
        call ctrlspace#window#refresh()
    endif
endfunction

function! ctrlspace#search#ClearSearchMode() abort
    call s:modes.Search.Disable()
    call s:modes.Search.SetData("Letters", [])

    call s:modes.Search.SetData("HistoryIndex", -1)
    call s:modes.Search.RemoveData("LastSearchedDirectory")

    call ctrlspace#window#refresh()
endfunction

function! ctrlspace#search#AddSearchLetter(letter) abort
    call add(s:modes.Search.Data.Letters, a:letter)
    call s:modes.Search.SetData("NewSearchPerformed", 1)

    let s:updateSearchResults = 1

    call s:modes.Search.RemoveData("LastSearchedDirectory")

    call ctrlspace#util#SetStatusline()
    redraws
endfunction

function! ctrlspace#search#RemoveSearchLetter() abort
    call remove(s:modes.Search.Data.Letters, -1)
    call s:modes.Search.SetData("NewSearchPerformed", 1)

    let s:updateSearchResults = 1

    call s:modes.Search.RemoveData("LastSearchedDirectory")

    call ctrlspace#util#SetStatusline()
    redraws
endfunction

function! ctrlspace#search#ClearSearchLetters() abort
    if !empty(s:modes.Search.Data.Letters)
        call s:modes.Search.SetData("Letters", [])
        call s:modes.Search.SetData("NewSearchPerformed", 1)

        let s:updateSearchResults = 1

        call s:modes.Search.RemoveData("LastSearchedDirectory")

        call ctrlspace#util#SetStatusline()
        redraws
    endif
endfunction

function! ctrlspace#search#SwitchSearchMode(switch) abort
    if (a:switch == 0) && !empty(s:modes.Search.Data.Letters)
        call ctrlspace#search#AppendToSearchHistory()
    endif

    if a:switch
        call s:modes.Search.Enable()
    else
        call s:modes.Search.Disable()
    endif

    let s:updateSearchResults = 1
    call ctrlspace#search#UpdateSearchResults()
endfunction

function! ctrlspace#search#InsertSearchText(text) abort
    let letters = []

    for i in range(strlen(a:text))
        if a:text[i] =~? "^[A-Z0-9]$"
            call add(letters, a:text[i])
        endif
    endfor

    if !empty(letters)
        call s:modes.Search.SetData("Letters", letters)
        call ctrlspace#search#AppendToSearchHistory()
        call s:modes.Search.SetData("HistoryIndex", 0)
        let s:updateSearchResults = 1
        call ctrlspace#search#UpdateSearchResults()
    endif
endfunction

function! ctrlspace#search#SearchHistoryIndex() abort
    if !s:modes.Search.HasData("HistoryIndex")
        call s:modes.Search.SetData("HistoryIndex", -1)
    endif

    return s:modes.Search.Data.HistoryIndex
endfunction

function! ctrlspace#search#AppendToSearchHistory() abort
    if empty(s:modes.Search.Data.Letters)
        return
    endif

    if !s:modes.Search.HasData("History")
        call s:modes.Search.SetData("History", {})
    endif

    let s:modes.Search.Data.History[join(s:modes.Search.Data.Letters)] = ctrlspace#jumps#IncrementJumpCounter()
endfunction

function! ctrlspace#search#RestoreSearchLetters(direction) abort
    if !s:modes.Search.HasData("History") || empty(s:modes.Search.Data.History)
        return
    endif

    let historyEntries = []

    for [letters, counter] in items(s:modes.Search.Data.History)
        call add(historyEntries, { "letters": letters, "counter": counter })
    endfor

    call sort(historyEntries, function("s:compareEntries"))

    let historyIndex = ctrlspace#search#SearchHistoryIndex()

    if a:direction == "previous"
        let historyIndex += 1

        if historyIndex == len(historyEntries)
            let historyIndex = len(historyEntries) - 1
        endif
    elseif a:direction == "next"
        let historyIndex -= 1

        if historyIndex < -1
            let historyIndex = -1
        endif
    endif

    if historyIndex < 0
        call s:modes.Search.SetData("Letters", [])
    else
        call s:modes.Search.SetData("Letters", split(historyEntries[historyIndex]["letters"]))
        call s:modes.Search.SetData("Restored", 1)
    endif

    call s:modes.Search.SetData("HistoryIndex", historyIndex)

    call ctrlspace#window#refresh()
endfunction

function! s:compareEntries(a, b) abort
    if a:a.counter > a:b.counter
        return -1
    elseif a:a.counter < a:b.counter
        return 1
    else
        return 0
    endif
endfunction

function! s:getSelectedDirectory() abort
    if s:modes.File.Enabled
        let name = luaeval('require("ctrlspace").drawer.selected_file_path()')
    elseif s:modes.Buffer.Enabled
        let name = s:modes.Buffer.Enabled ? bufname(ctrlspace#window#SelectedIndex()) : ""
    else
        return ""
    endif

    return fnamemodify(name, ":h")
endfunction

function! ctrlspace#search#SearchParentDirectoryCycle() abort
    let candidate = s:getSelectedDirectory()

    if empty(candidate)
        return
    endif

    if !s:modes.Search.HasData("LastSearchedDirectory") || s:modes.Search.Data.LastSearchedDirectory !=# candidate
        call s:modes.Search.SetData("LastSearchedDirectory", candidate)
    else
        call s:modes.Search.SetData("LastSearchedDirectory", fnamemodify(s:modes.Search.Data.LastSearchedDirectory, ":h"))
    endif

    call ctrlspace#search#InsertSearchText(s:modes.Search.Data.LastSearchedDirectory)
endfunction
