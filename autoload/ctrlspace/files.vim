let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

function! s:get_selected_file(...) abort
    let idx = ctrlspace#window#SelectedIndex()
    let file = ctrlspace#files#CollectFiles()[idx].text
    return a:0 == 0 ? file : fnamemodify(file, a:1)
endfunction

function! s:get_selected_file_or_buff(mod) abort
    let target = s:modes.File.Enabled ? s:get_selected_file(':p') : resolve(bufname(ctrlspace#window#SelectedIndex()))
    return fnamemodify(target, a:mod)
endfunction

function! ctrlspace#files#ClearAll() abort
    return luaeval('require("ctrlspace").files.clear()')
endfunction

function! ctrlspace#files#SelectedFileName() abort
    return s:modes.File.Enabled ? s:File.raw_fname() : ""
endfunction

function! ctrlspace#files#CollectFiles() abort
    return luaeval('require("ctrlspace").files.collect()')
endfunction

function! ctrlspace#files#LoadFile(commands) abort
    let file = s:get_selected_file(":p")
    call ctrlspace#window#Kill(1)

    for command in a:commands
        exec ":" . command
    endfor

    let F = luaeval('require("ctrlspace").files.load_file_or_buffer')
    call F(file)
endfunction

function! ctrlspace#files#LoadManyFiles(preCommands, postCommands) abort
    let file = fnamemodify(ctrlspace#files#SelectedFileName(), ":p")
    let curln = line(".")

    call ctrlspace#window#Kill(0)
    call ctrlspace#window#GoToStartWindow()

    for command in a:preCommands
        exec ":" . command
    endfor

    let F = luaeval('require("ctrlspace").files.load_file_or_buffer')
    call F(file)

    normal! zb

    for command in a:postCommands
        silent! exe ":" . command
    endfor

    call ctrlspace#window#Toggle(1)
    call ctrlspace#window#MoveSelectionBar(curln)
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
        let path = s:get_selected_file_or_buff(":p")
    endif

    let oldBufferSubMode = s:modes.Buffer.Data.SubMode
    let directory        = ctrlspace#util#NormalizeDirectory(fnamemodify(path, ":p:h"))

    if !isdirectory(directory)
        return
    endif

    call ctrlspace#window#Kill(1)

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

    call ctrlspace#window#Toggle(0)
    call ctrlspace#window#Kill(0)

    call s:modes.Buffer.SetData("SubMode", oldBufferSubMode)

    call ctrlspace#window#Toggle(1)
    call ctrlspace#ui#DelayedMsg()
endfunction

function! ctrlspace#files#ExploreDirectory() abort
    let path = s:get_selected_file_or_buff(":p:h")
    if !isdirectory(path)
        return
    endif

    call ctrlspace#window#Kill(1)
    silent! exe "e " . fnameescape(path)
endfunction

function! ctrlspace#files#EditFile() abort
    let path = s:get_selected_file_or_buff(":p:h")
    if !isdirectory(path)
        return
    endif

    let newFile = ctrlspace#ui#GetInput("Edit a new file: ", path . '/', "file")

    if empty(newFile)
        return
    endif

    let newFile = expand(newFile)

    if isdirectory(newFile)
        call ctrlspace#window#Kill(1)
        enew
        return
    endif

    if !s:ensurePath(newFile)
        return
    endif

    let newFile = fnamemodify(newFile, ":p")

    call ctrlspace#window#Kill(1)
    silent! exe "e " . fnameescape(newFile)
endfunction

function! s:loadFileOrBuffer(file) abort
    if buflisted(a:file)
        silent! exe ":b " . bufnr(a:file)
    else
        exec ":e " . fnameescape(a:file)
    endif
endfunction

function! s:updateFileList(path, newPath) abort
    return luaeval('require("ctrlspace").files.clear()')
endfunction

function! s:ensurePath(file) abort
    let directory = fnamemodify(a:file, ":.:h")

    if isdirectory(directory)
        return 1
    endif

    if !ctrlspace#ui#Confirmed("Directory '" . directory . "' will be created. Continue?")
        return 0
    endif

    call mkdir(fnamemodify(directory, ":p"), "p")
    return 1
endfunction
