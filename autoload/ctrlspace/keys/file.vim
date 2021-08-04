let s:modes  = ctrlspace#modes#Modes()

function! ctrlspace#keys#file#Init() abort
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#SearchParentDirectory",   "File", ["BSlash", "Bar"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#LoadFile",                "File", ["CR"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#LoadManyFiles",           "File", ["Space"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#LoadFileVS",              "File", ["v"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#LoadManyFilesVS",         "File", ["V"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#LoadFileSP",              "File", ["s"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#LoadManyFilesSP",         "File", ["S"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#LoadFileT",               "File", ["t"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#LoadManyFilesT",          "File", ["T"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#LoadManyFilesCT",         "File", ["C-t"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#buffer#NewTabLabel",           "File", ["="])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#buffer#RemoveTabLabel",        "File", ["_"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#buffer#MoveTab",               "File", ["+", "-"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#buffer#SwitchTab",             "File", ["[", "]"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#Refresh",                 "File", ["r"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#buffer#CloseTab",              "File", ["C"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#EditFile",                "File", ["e"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#ExploreDirectory",        "File", ["E"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#file#GoToDirectory",           "File", ["i", "I"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#buffer#GoToBufferOrFile",      "File", ["g", "G"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#buffer#CollectUnsavedBuffers", "File", ["U"])
endfunction

function! ctrlspace#keys#file#SearchParentDirectory(k) abort
    call ctrlspace#search#SearchParentDirectoryCycle()
endfunction

function! ctrlspace#keys#file#LoadFile(k) abort
    call ctrlspace#files#LoadFile([])
endfunction

function! ctrlspace#keys#file#LoadManyFiles(k) abort
    call ctrlspace#files#LoadManyFiles([], [])
endfunction

function! ctrlspace#keys#file#LoadFileVS(k) abort
    call ctrlspace#files#LoadFile(["vs"])
endfunction

function! ctrlspace#keys#file#LoadManyFilesVS(k) abort
    call ctrlspace#files#LoadManyFiles(["vs"], [])
endfunction

function! ctrlspace#keys#file#LoadFileSP(k) abort
    call ctrlspace#files#LoadFile(["sp"])
endfunction

function! ctrlspace#keys#file#LoadManyFilesSP(k) abort
    call ctrlspace#files#LoadManyFiles(["sp"], [])
endfunction

function! ctrlspace#keys#file#LoadFileT(k) abort
    call ctrlspace#files#LoadFile(["tabnew"])
endfunction

function! ctrlspace#keys#file#LoadManyFilesT(k) abort
    if s:modes.NextTab.Enabled
        call ctrlspace#files#LoadManyFiles(["tabnext"], ["tabprevious"])
    else
        call s:modes.NextTab.Enable()
        call ctrlspace#files#LoadManyFiles(["tabnew"], ["tabprevious"])
    endif
endfunction

function! ctrlspace#keys#file#LoadManyFilesCT(k) abort
    call s:modes.NextTab.Enable()
    call ctrlspace#files#LoadManyFiles(["tabnew"], ["tabprevious"])
endfunction

function! ctrlspace#keys#file#Refresh(k) abort
    call luaeval('require("ctrlspace").files.clear()')
    call ctrlspace#window#refresh()
endfunction

function! ctrlspace#keys#file#EditFile(k) abort
    call luaeval('require("ctrlspace").files.edit()')
endfunction

function! ctrlspace#keys#file#ExploreDirectory(k) abort
    call luaeval('require("ctrlspace").files.edit_dir()')
endfunction

function! ctrlspace#keys#file#GoToDirectory(k) abort
    call ctrlspace#files#GoToDirectory(a:k ==# "I")
endfunction
