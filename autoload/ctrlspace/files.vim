let s:modes  = ctrlspace#modes#Modes()

function! ctrlspace#files#LoadFile(commands) abort
    let F = luaeval('require("ctrlspace").files.load_file')
    call F(a:commands)
endfunction

function! ctrlspace#files#LoadManyFiles(pre, post) abort
  let F = luaeval('require("ctrlspace").files.load_many_files')
  call F(a:pre, a:post)
endfunction

function! ctrlspace#files#GoToDirectory(back) abort
    if !exists("s:goToDirectorySave")
        let s:goToDirectorySave = []
    endif

    if a:back
        if empty(s:goToDirectorySave)
            return
        else
            let path = s:goToDirectorySave[-1]
        endif
    else
        let path = fnamemdify(luaeval('require("ctrlspace").selected_file_path()'), ":p")
    endif

    let oldBufferSubMode = s:modes.Buffer.Data.SubMode
    let directory        = ctrlspace#util#NormalizeDirectory(fnamemodify(path, ":p:h"))

    if !isdirectory(directory)
        return
    endif

    call ctrlspace#window#kill()

    let cwd = ctrlspace#util#NormalizeDirectory(fnamemodify(getcwd(), ":p:h"))

    if cwd !=# directory
        if a:back
            call remove(s:goToDirectorySave, -1)
        else
            call add(s:goToDirectorySave, cwd)
        endif
    endif

    call ctrlspace#util#ChDir(directory)
    call ctrlspace#ui#DelayedMsg("CWD is now: " . directory)
    call s:modes.Buffer.SetData("SubMode", oldBufferSubMode)

    call ctrlspace#window#restore()
    call ctrlspace#ui#DelayedMsg()
endfunction
