let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

function! s:file_obj_init() abort
    let s:File = {}
    let s:File.raw_fname = function('s:get_selected_file')          " filename from Cache's files list
    let s:File.abs_fpath = function('s:get_selected_file', [':p'])  " absolute filepath
    let s:File.rel_fpath = function('s:get_selected_file', [':.'])  " relative filepath
    let s:File.abs_fob_p = function('s:get_selected_file_or_buff', [':p'])   " absolute filepath of selected file or buffer
    let s:File.rel_fob_p = function('s:get_selected_file_or_buff', [':.'])   " relative filepath of selected file or buffer
    let s:File.abs_fob_d = function('s:get_selected_file_or_buff', [':p:h']) " absolute path of directory containing file or buffer
    let s:File.rel_fob_d = function('s:get_selected_file_or_buff', [':.:h']) " relative path of directory containing file or buffer
    return s:File
endfunction

function! s:get_selected_file(...) abort
    let idx = ctrlspace#window#SelectedIndex()
    let file = ctrlspace#files#CollectFiles()[idx].text
    return a:0 == 0 ? file : fnamemodify(file, a:1)
endfunction

function! s:get_selected_file_or_buff(mod) abort
    let target = s:modes.File.Enabled ? s:get_selected_file(':p') : resolve(bufname(ctrlspace#window#SelectedIndex()))
    return fnamemodify(target, a:mod)
endfunction

let s:File = s:file_obj_init()

" comparison check helper
function! s:isValidFilePath(path) abort
    return !(empty(a:path) || !filereadable(a:path) || isdirectory(a:path))
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
    let file = s:File.abs_fpath()
    call ctrlspace#window#Kill(1)

    for command in a:commands
        exec ":" . command
    endfor

    call s:loadFileOrBuffer(file)
endfunction

function! ctrlspace#files#LoadManyFiles(preCommands, postCommands) abort
    let file = s:File.abs_fpath()
    let curln = line(".")

    call ctrlspace#window#Kill(0)
    call ctrlspace#window#GoToStartWindow()

    for command in a:preCommands
        exec ":" . command
    endfor

    call s:loadFileOrBuffer(file)
    normal! zb

    for command in a:postCommands
        silent! exe ":" . command
    endfor

    call ctrlspace#window#Toggle(1)
    call ctrlspace#window#MoveSelectionBar(curln)
endfunction

function! ctrlspace#files#RefreshFiles() abort
    return luaeval('require("ctrlspace").files.clear()')
    call ctrlspace#window#refresh()
endfunction

function! ctrlspace#files#RemoveFile() abort
    let path = s:File.rel_fob_p()
    if !s:isValidFilePath(path)
        return
    endif

    if !ctrlspace#ui#Confirmed("Remove file '" . path . "'?")
        return
    endif

    call ctrlspace#buffers#DeleteBuffer()
    call s:updateFileList(path, "")
    call delete(resolve(expand(path)))

    call ctrlspace#window#Kill(0)
    call ctrlspace#window#Toggle(1)
endfunction


function! ctrlspace#files#CopyFileOrBuffer() abort
    let root = ctrlspace#roots#CurrentProjectRoot()

    if !empty(root)
        call ctrlspace#util#ChDir(root)
    endif

    let path = s:File.rel_fob_p()

    let bufOnly = !filereadable(path) && !s:modes.File.Enabled

    if !(filereadable(path) || bufOnly) || isdirectory(path)
        return
    endif

    let newFile = ctrlspace#ui#GetInput((bufOnly ? "Copy buffer as: " : "Copy file to: "), path, "file")

    if empty(newFile) || isdirectory(newFile) || !s:ensurePath(newFile)
        return
    endif

    if bufOnly
        call ctrlspace#buffers#ZoomBuffer(str2nr(nr), ['normal! G""ygg'])
        call ctrlspace#window#Kill(1)
        silent! exe "e " . fnameescape(newFile)
        silent! exe 'normal! ""pgg"_dd'
    else
        let newFile = fnamemodify(newFile, ":p")

        let lines = readfile(path, "b")
        call writefile(lines, newFile, "b")

        call s:updateFileList("", newFile)

        call ctrlspace#window#Kill(1)

        if !s:modes.File.Enabled
            silent! exe "e " . fnameescape(newFile)
        endif
    endif

    call ctrlspace#window#Toggle(1)

    if !s:modes.File.Enabled
        if !bufOnly
            let newFile = fnamemodify(newFile, ":.")
        endif

        let names = ctrlspace#api#Buffers(tabpagenr())

        for i in range(b:size)
            if names[b:items[i].index] ==# newFile
                call ctrlspace#window#MoveSelectionBar(i + 1)
                break
            endif
        endfor
    endif
endfunction

function! ctrlspace#files#RenameFileOrBuffer() abort
    let root = ctrlspace#roots#CurrentProjectRoot()

    if !empty(root)
        call ctrlspace#util#ChDir(root)
    endif

    let path = s:File.rel_fob_p()

    let bufOnly = !filereadable(path) && !s:modes.File.Enabled

    if !(filereadable(path) || bufOnly) || isdirectory(path)
        return
    endif

    let newFile = ctrlspace#ui#GetInput((bufOnly ? "New buffer name: " : "Move file to: "), path, "file")

    if empty(newFile) || !s:ensurePath(newFile)
        return
    endif

    if isdirectory(newFile)
        if newFile !~ "/$"
            let newFile .= "/"
        endif

        let newFile .= fnamemodify(path, ":t")
    endif

    let bufNames = {}

    " must be collected BEFORE actual file renaming
    for b in range(1, bufnr("$"))
        let bufNames[b] = fnamemodify(resolve(bufname(b)), ":.")
    endfor

    if !bufOnly
        call rename(resolve(expand(path)), resolve(expand(newFile)))
    endif

    for [b, name] in items(bufNames)
        if name == path
            let commands = ["f " . fnameescape(newFile)]

            if !bufOnly
                call add(commands, "w!")
            elseif !getbufvar(b, "&modified")
                call add(commands, "e") "reload filetype and syntax
            endif

            call ctrlspace#buffers#ZoomBuffer(str2nr(b), commands)
        endif
    endfor

    if !bufOnly
        call s:updateFileList(path, newFile)
    endif

    call ctrlspace#window#Kill(1)
    call ctrlspace#window#Toggle(1)
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
        let path = s:File.abs_fob_p()
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
    let path = s:File.abs_fob_d()
    if !isdirectory(path)
        return
    endif

    call ctrlspace#window#Kill(1)
    silent! exe "e " . fnameescape(path)
endfunction

function! ctrlspace#files#EditFile() abort
    let path = s:File.rel_fob_d()
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
