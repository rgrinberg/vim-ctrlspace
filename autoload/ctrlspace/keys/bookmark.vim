let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

function! ctrlspace#keys#bookmark#Init() abort
    call ctrlspace#keys#AddMapping("ctrlspace#keys#bookmark#GoToBookmark", "Bookmark", ["Tab", "CR", "Space"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#bookmark#Rename", "Bookmark", ["=", "m"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#bookmark#Edit", "Bookmark", ["e"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#bookmark#Add", "Bookmark", ["a", "A"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#bookmark#Delete", "Bookmark", ["d"])
endfunction

function! ctrlspace#keys#bookmark#GoToBookmark(k) abort
    let nr = ctrlspace#window#SelectedIndex()

    call ctrlspace#window#Kill(1)
    call ctrlspace#bookmarks#GoToBookmark(nr)

    if a:k ==# "CR"
        call ctrlspace#window#Toggle(0)
    elseif a:k ==# "Space"
        call ctrlspace#window#Toggle(0)
        call ctrlspace#window#Kill(0)
        call s:modes.Bookmark.Enable()
        call ctrlspace#window#Toggle(1)
    endif

    call ctrlspace#ui#DelayedMsg()
endfunction

function! ctrlspace#keys#bookmark#Rename(k) abort
    let curline = line(".")
    let nr = ctrlspace#window#SelectedIndex()
    call ctrlspace#bookmarks#ChangeBookmarkName(nr)
    call ctrlspace#window#Kill(0)
    call ctrlspace#window#Toggle(1)
    call ctrlspace#window#MoveSelectionBar(curline)
    call ctrlspace#ui#DelayedMsg()
endfunction

function! ctrlspace#keys#bookmark#Edit(k) abort
    let curline = line(".")
    let nr = ctrlspace#window#SelectedIndex()

    if ctrlspace#bookmarks#ChangeBookmarkDirectory(nr)
        call ctrlspace#window#Kill(1)
        call ctrlspace#window#Toggle(0)
        call ctrlspace#window#Kill(0)
        call s:modes.Bookmark.Enable()
        call ctrlspace#window#Toggle(1)
        call ctrlspace#window#MoveSelectionBar(curline)
        call ctrlspace#ui#DelayedMsg()
    endif
endfunction

function! ctrlspace#keys#bookmark#Add(k) abort
    if a:k ==# "a"
        let result = ctrlspace#bookmarks#AddNewBookmark(ctrlspace#window#SelectedIndex())
    else
        let result = ctrlspace#bookmarks#AddNewBookmark()
    endif

    if result
        call ctrlspace#window#Kill(1)
        call ctrlspace#window#Toggle(0)
        call ctrlspace#window#Kill(0)
        call s:modes.Bookmark.Enable()
        call ctrlspace#window#Toggle(1)
        call ctrlspace#ui#DelayedMsg()
    endif
endfunction

function! ctrlspace#keys#bookmark#Delete(k) abort
    let nr = ctrlspace#window#SelectedIndex()
    call ctrlspace#bookmarks#RemoveBookmark(nr)
    call ctrlspace#window#Kill(1)
    call ctrlspace#window#Toggle(0)
    call ctrlspace#window#Kill(0)
    call s:modes.Bookmark.Enable()
    call ctrlspace#window#Toggle(1)
    call ctrlspace#ui#DelayedMsg()
endfunction
