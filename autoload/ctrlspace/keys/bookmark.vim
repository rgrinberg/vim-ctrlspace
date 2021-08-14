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
    let curline = line(".")
    let nr = ctrlspace#window#SelectedIndex()

    let newbookmark = ctrlspace#bookmarks#bookmarks()[:nr]
    call ctrlspace#util#chdir(newbookmark.directory)
    call ctrlspace#roots#setcurrentprojectroot(newbookmark.directory)
    call ctrlspace#ui#delayedmsg("cwd is now: " . newbookmark.directory)

    call luaeval('require("ctrlspace").files.clear()')
    call ctrlspace#window#refresh()
    call ctrlspace#window#MoveSelectionBar(curline)
endfunction

function! ctrlspace#keys#bookmark#Rename(k) abort
    let curline = line(".")
    let nr = ctrlspace#window#SelectedIndex()

    let bookmark = ctrlspace#bookmarks#Bookmarks()[nr]
    let newName = ctrlspace#ui#GetInput("New bookmark name: ", bookmark.Name)

    if !empty(newName)
        call ctrlspace#bookmarks#AddToBookmarks(bookmark.Directory, newName)
        call ctrlspace#ui#DelayedMsg("Bookmark '" . bookmark.Name . "' has been renamed to '" . newName . "'.")
    endif

    call ctrlspace#window#refresh()
    call ctrlspace#window#MoveSelectionBar(curline)
    call ctrlspace#ui#DelayedMsg()
endfunction

function! ctrlspace#keys#bookmark#Edit(k) abort
    let curline = line(".")
    let nr = ctrlspace#window#SelectedIndex()

    if ctrlspace#bookmarks#ChangeBookmarkDirectory(nr)
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
        call s:modes.Bookmark.Enable()
        call ctrlspace#window#Toggle(1)
        call ctrlspace#ui#DelayedMsg()
    endif
endfunction

function! ctrlspace#keys#bookmark#Delete(k) abort
    let nr = ctrlspace#window#SelectedIndex()

    let bookmark = ctrlspace#bookmarks#Bookmarks()[a:nr]
    let name = bookmark.Name

    if !ctrlspace#ui#Confirmed("Delete bookmark '" . name . "'?")
        return
    endif

    let F = luaeval('require("ctrlspace").db.remove_bookmark')
    call F(a:nr)
    call ctrlspace#ui#DelayedMsg("Bookmark '" . name . "' has been deleted.")

    call s:modes.Bookmark.Enable()
    call ctrlspace#window#Toggle(1)
    call ctrlspace#ui#DelayedMsg()
endfunction
