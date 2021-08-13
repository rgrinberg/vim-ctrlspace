let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

let s:lastProjectRoot    = ""
let s:currentProjectRoot = ""

function! ctrlspace#roots#ProjectRoots() abort
    let db = luaeval('require("ctrlspace").db.latest()')
    return db.roots
endfunction

function! ctrlspace#roots#CurrentProjectRoot() abort
    return s:currentProjectRoot
endfunction

function! ctrlspace#roots#SetCurrentProjectRoot(value) abort
    let s:currentProjectRoot = a:value
endfunction

function! ctrlspace#roots#LastProjectRoot() abort
    return s:lastProjectRoot
endfunction

function! ctrlspace#roots#SetLastProjectRoot(value) abort
    let s:lastProjectRoot = a:value
endfunction

function! ctrlspace#roots#AddProjectRoot(directory) abort
    let directory = ctrlspace#util#NormalizeDirectory(fnamemodify(empty(a:directory) ? getcwd() : a:directory, ":p"))

    if !isdirectory(directory)
        call ctrlspace#ui#Msg("Invalid directory: '" . directory . "'")
        return
    endif

    let roots = copy(ctrlspace#roots#ProjectRoots())

    for bm in ctrlspace#bookmarks#Bookmarks()
        let roots[bm.Directory] = 1
    endfor

    if exists("roots[directory]")
        call ctrlspace#ui#Msg("Directory '" . directory . "' is already a permanent project root!")
        return
    endif

    call s:addProjectRoot(directory)
    call ctrlspace#ui#Msg("Directory '" . directory . "' has been added as a permanent project root.")
endfunction

function! ctrlspace#roots#RemoveProjectRoot(directory) abort
    let directory = ctrlspace#util#NormalizeDirectory(fnamemodify(empty(a:directory) ? getcwd() : a:directory, ":p"))

    let projectRoots = ctrlspace#roots#ProjectRoots()
    if !exists(projectRoots, directory)
        call ctrlspace#ui#Msg("Directory '" . directory . "' is not a permanent project root!" )
        return
    endif

    call s:removeProjectRoot(directory)
    call ctrlspace#ui#Msg("Project root '" . directory . "' has been removed.")
endfunction

function! s:removeProjectRoot(directory) abort
    let directory = ctrlspace#util#NormalizeDirectory(a:directory)
    let F = luaeval('require("ctrlspace").db.remove_root')
    call F(directory)
endfunction

function! s:addProjectRoot(directory) abort
    let directory = ctrlspace#util#NormalizeDirectory(a:directory)
    let F = luaeval('require("ctrlspace").db.add_root')
    call F(directory)
endfunction

function! ctrlspace#roots#FindProjectRoot() abort
    let projectRoot = fnamemodify(".", ":p:h")

    if empty(s:config.ProjectRootMarkers)
        return projectRoot
    endif

    let rootFound     = 0
    let candidate     = fnamemodify(projectRoot, ":p:h")
    let lastCandidate = ""

    while candidate != lastCandidate
        for marker in s:config.ProjectRootMarkers
            let markerPath = candidate . "/" . marker
            if filereadable(markerPath) || isdirectory(markerPath)
                let rootFound = 1
                break
            endif
        endfor

        if !rootFound
            let rootFound = has_key(ctrlspace#roots#ProjectRoots(), candidate)
        endif

        if rootFound
            let projectRoot = candidate
            break
        endif

        let lastCandidate = candidate
        let candidate = fnamemodify(candidate, ":p:h:h")
    endwhile

    return rootFound ? projectRoot : ""
endfunction

function! ctrlspace#roots#ProjectRootFound() abort
    if !empty(s:currentProjectRoot)
        return 1
    endif

    let s:currentProjectRoot = ctrlspace#roots#FindProjectRoot()
    if !empty(s:currentProjectRoot)
        return 1
    endif

    let projectRoot = ctrlspace#ui#GetInput("No project root found. Set the project root: ", fnamemodify(".", ":p:h"), "dir")

    if !empty(projectRoot) && isdirectory(projectRoot)
        call luaeval('require("ctrlspace").files.clear()')
        call s:addProjectRoot(projectRoot)
        let s:currentProjectRoot = projectRoot
        return 1
    else
        call ctrlspace#ui#Msg("Cannot continue with the project root not set.")
        return 0
    endif
endfunction
