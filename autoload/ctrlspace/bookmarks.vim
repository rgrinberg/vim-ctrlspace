let s:modes = ctrlspace#modes#Modes()

function! ctrlspace#bookmarks#Bookmarks() abort
    let db = luaeval('require("ctrlspace").db.latest()')
    return db.bookmarks
endfunction

function! ctrlspace#bookmarks#GoToBookmark(nr) abort
    let newBookmark = ctrlspace#bookmarks#Bookmarks()[a:nr]
    call ctrlspace#util#ChDir(newBookmark.Directory)
    call ctrlspace#roots#SetCurrentProjectRoot(newBookmark.Directory)
    call ctrlspace#ui#DelayedMsg("CWD is now: " . newBookmark.Directory)
endfunction

function! ctrlspace#bookmarks#ChangeBookmarkName(nr) abort
    let bookmark = ctrlspace#bookmarks#Bookmarks()[a:nr]
    let newName = ctrlspace#ui#GetInput("New bookmark name: ", bookmark.Name)

    if !empty(newName)
        call ctrlspace#bookmarks#AddToBookmarks(bookmark.Directory, newName)
        call ctrlspace#ui#DelayedMsg("Bookmark '" . bookmark.Name . "' has been renamed to '" . newName . "'.")
    endif
endfunction

function! ctrlspace#bookmarks#ChangeBookmarkDirectory(nr) abort
    let bookmarks = ctrlspace#bookmarks#Bookmarks()
    let bookmark = bookmarks[a:nr]
    let current   = bookmark.Directory
    let name      = bookmark.Name
    let directory = ctrlspace#ui#GetInput("Edit directory for bookmark '" . name . "': ", current, "dir")

    if empty(directory)
        return 0
    endif

    let directory = ctrlspace#util#NormalizeDirectory(directory)

    if !isdirectory(directory)
        call ctrlspace#ui#Msg("Directory incorrect.")
        return 0
    endif

    for bookmark in bookmarks
        if bookmark.Directory ==# directory
            call ctrlspace#ui#Msg("This directory has been already bookmarked under name '" . name . "'.")
            return 0
        endif
    endfor

    call ctrlspace#bookmarks#AddToBookmarks(directory, name)
    call ctrlspace#ui#DelayedMsg("Directory '" . directory . "' has been bookmarked under name '" . name . "'.")

    return 1
endfunction

function! ctrlspace#bookmarks#AddNewBookmark(...) abort
    let bookmarks = ctrlspace#bookmarks#Bookmarks()
    if a:0
        let current = bookmarks[a:1].Directory
    else
        let root    = ctrlspace#roots#CurrentProjectRoot()
        let current = empty(root) ? fnamemodify(".", ":p:h") : root
    endif

    let F = luaeval('require("ctrlspace").bookmarks.add_new')
    call F(current)
endfunction

function! ctrlspace#bookmarks#AddToBookmarks(directory, name) abort
    let directory   = ctrlspace#util#NormalizeDirectory(a:directory)
    let jumpCounter = 0
    let bookmarks = ctrlspace#bookmarks#Bookmarks()

    for i in range(len(bookmarks))
        if bookmarks[i].Directory == directory
            let jumpCounter = bookmarks[i].JumpCounter
            call remove(bookmarks, i)
            break
        endif
    endfor

    let bookmark = { "Name": a:name, "Directory": directory, "JumpCounter": jumpCounter }

    let F = luaeval('require("ctrlspace").db.add_bookmark')
    call F(bookmark)
    return bookmark
endfunction

function! ctrlspace#bookmarks#FindActiveBookmark() abort
    let root = ctrlspace#roots#CurrentProjectRoot()
    let bookmarks = ctrlspace#bookmarks#Bookmarks()

    if empty(root)
        let root = fnamemodify(".", ":p:h")
    endif

    let root = ctrlspace#util#NormalizeDirectory(root)

    for bm in bookmarks
        if ctrlspace#util#NormalizeDirectory(bm.Directory) == root
            let bm.JumpCounter = ctrlspace#jumps#IncrementJumpCounter()
            return bm
        endif
    endfor

    return {}
endfunction
