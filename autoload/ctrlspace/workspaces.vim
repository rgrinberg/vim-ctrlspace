let s:config     = ctrlspace#context#Configuration()
let s:modes      = ctrlspace#modes#Modes()
let s:workspaces = []

function! s:workspaceFile() abort
    return ctrlspace#util#projectLocalFile("cs_workspaces")
endfunction

function! ctrlspace#workspaces#Workspaces() abort
    return s:workspaces
endfunction

function! ctrlspace#workspaces#SetWorkspaceNames() abort
    let filename     = s:workspaceFile()
    let s:workspaces = []

    call s:modes.Workspace.SetData("LastActive", "")

    if filereadable(filename)
        for line in readfile(filename)
            if line =~? "CS_WORKSPACE_BEGIN: "
                call add(s:workspaces, line[20:])
            elseif line =~? "CS_LAST_WORKSPACE: "
                call s:modes.Workspace.SetData("LastActive", line[19:])
            endif
        endfor
    endif
endfunction

function! ctrlspace#workspaces#SetActiveWorkspaceName(name, ...) abort
    if a:0 > 0
        let digest = a:1
    else
        let digest = s:modes.Workspace.Data.Active.Digest
    end

    call s:modes.Workspace.SetData("Active", { "Name": a:name, "Digest": digest, "Root": ctrlspace#roots#CurrentProjectRoot() })
    call s:modes.Workspace.SetData("LastActive", a:name)

    let filename     = s:workspaceFile()
    let lines    = []

    if filereadable(filename)
        for line in readfile(filename)
            if !(line =~? "CS_LAST_WORKSPACE: ")
                call add(lines, line)
            endif
        endfor
    endif

    if !empty(a:name)
        call insert(lines, "CS_LAST_WORKSPACE: " . a:name)
    endif

    call writefile(lines, filename)
endfunction

function! ctrlspace#workspaces#ActiveWorkspace() abort
    let aw = s:modes.Workspace.Data.Active
    let aw.Status = 0

    if !empty(aw.Name) && aw.Root ==# ctrlspace#roots#CurrentProjectRoot()
        let aw.Status = 1

        if aw.Digest !=# ctrlspace#workspaces#CreateDigest()
            let aw.Status = 2
        endif
    endif

    return aw
endfunction

function! ctrlspace#workspaces#NewWorkspace() abort
    tabe
    tabo!
    call ctrlspace#buffers#DeleteHiddenNonameBuffers(1)
    call ctrlspace#buffers#DeleteForeignBuffers(1)
    call s:modes.Workspace.SetData("Active", { "Name": "", "Digest": "", "Root": "" })
endfunction

function! ctrlspace#workspaces#SelectedWorkspaceName() abort
    return s:modes.Workspace.Enabled ? s:workspaces[ctrlspace#window#SelectedIndex()] : ""
endfunction

function! ctrlspace#workspaces#RenameWorkspace(name) abort
    let newName = ctrlspace#ui#GetInput("Rename workspace '" . a:name . "' to: ", a:name)

    if empty(newName)
        return 0
    endif

    for existingName in s:workspaces
        if newName ==# existingName
            call ctrlspace#ui#Msg("Workspace '" . newName . "' already exists.")
            return 0
        endif
    endfor

    let filename = s:workspaceFile()
    let lines    = []

    let workspaceStartMarker = "CS_WORKSPACE_BEGIN: " . a:name
    let workspaceEndMarker   = "CS_WORKSPACE_END: " . a:name
    let lastWorkspaceMarker  = "CS_LAST_WORKSPACE: " . a:name

    if filereadable(filename)
        for line in readfile(filename)
            if line ==# workspaceStartMarker
                let line = "CS_WORKSPACE_BEGIN: " . newName
            elseif line ==# workspaceEndMarker
                let line = "CS_WORKSPACE_END: " . newName
            elseif line ==# lastWorkspaceMarker
                let line = "CS_LAST_WORKSPACE: " . newName
            endif

            call add(lines, line)
        endfor
    endif

    call writefile(lines, filename)

    if s:modes.Workspace.Data.Active.Name ==# a:name && s:modes.Workspace.Data.Active.Root ==# ctrlspace#roots#CurrentProjectRoot()
        call ctrlspace#workspaces#SetActiveWorkspaceName(newName)
    endif

    call ctrlspace#workspaces#SetWorkspaceNames()
    call ctrlspace#window#Kill(0)
    call ctrlspace#window#Toggle(1)

    call ctrlspace#ui#DelayedMsg("Workspace '" . a:name . "' has been renamed to '" . newName . "'.")
    return 1
endfunction

function! ctrlspace#workspaces#DeleteWorkspace(name) abort
    if !ctrlspace#ui#Confirmed("Delete workspace '" . a:name . "'?")
        return 0
    endif

    let filename = s:workspaceFile()
    let lines       = []
    let inWorkspace = 0

    let workspaceStartMarker = "CS_WORKSPACE_BEGIN: " . a:name
    let workspaceEndMarker   = "CS_WORKSPACE_END: " . a:name

    if filereadable(filename)
        for oldLine in readfile(filename)
            if oldLine ==# workspaceStartMarker
                let inWorkspace = 1
            endif

            if !inWorkspace
                call add(lines, oldLine)
            endif

            if oldLine ==# workspaceEndMarker
                let inWorkspace = 0
            endif
        endfor
    endif

    call writefile(lines, filename)

    if s:modes.Workspace.Data.Active.Name ==# a:name && s:modes.Workspace.Data.Active.Root ==# ctrlspace#roots#CurrentProjectRoot()
        call ctrlspace#workspaces#SetActiveWorkspaceName(a:name, "")
    endif

    call ctrlspace#workspaces#SetWorkspaceNames()

    if empty(s:workspaces)
        call ctrlspace#window#Kill(1)
    else
        call ctrlspace#window#Kill(0)
        call ctrlspace#window#Toggle(1)
    endif

    call ctrlspace#ui#DelayedMsg("Workspace '" . a:name . "' has been deleted.")

    return 1
endfunction

" bang == 0) load
" bang == 1) append
function! ctrlspace#workspaces#LoadWorkspace(bang, name) abort
    if !ctrlspace#roots#ProjectRootFound()
        return 0
    endif

    call ctrlspace#util#HandleVimSettings("start")

    let cwdSave = fnamemodify(".", ":p:h")
    silent! exe "cd " . fnameescape(ctrlspace#roots#CurrentProjectRoot())

    let filename = s:workspaceFile()

    if !filereadable(filename)
        silent! exe "cd " . fnameescape(cwdSave)
        return 0
    endif

    let oldLines = readfile(filename)

    if empty(a:name)
        let name = ""

        for line in oldLines
            if line =~? "CS_LAST_WORKSPACE: "
                let name = line[19:]
                break
            endif
        endfor

        if empty(name)
            silent! exe "cd " . fnameescape(cwdSave)
            return 0
        endif
    else
        let name = a:name
    endif

    let startMarker = "CS_WORKSPACE_BEGIN: " . name
    let endMarker   = "CS_WORKSPACE_END: " . name

    let lines       = []
    let inWorkspace = 0

    for ol in oldLines
        if ol ==# startMarker
            let inWorkspace = 1
        elseif ol ==# endMarker
            let inWorkspace = 0
        elseif inWorkspace
            call add(lines, ol)
        endif
    endfor

    if empty(lines)
        call ctrlspace#ui#Msg("Workspace '" . name . "' not found in file '" . filename . "'.")
        call ctrlspace#workspaces#SetWorkspaceNames()
        silent! exe "cd " . fnameescape(cwdSave)
        return 0
    endif

    call s:execWorkspaceCommands(a:bang, name, lines)

    if a:bang
        let s:modes.Workspace.Data.Active.Digest = ""
        let msg = "Workspace '" . name . "' has been appended."
    else
        let s:modes.Workspace.Data.Active.Digest = ctrlspace#workspaces#CreateDigest()
        let msg = "Workspace '" . name . "' has been loaded."
    endif

    call ctrlspace#ui#Msg(msg)
    call ctrlspace#ui#DelayedMsg(msg)

    silent! exe "cd " . fnameescape(cwdSave)

    call ctrlspace#util#HandleVimSettings("stop")

    return 1
endfunction

function! s:execWorkspaceCommands(bang, name, lines) abort
    let commands = []

    if a:bang
        let curTab = tabpagenr()
        call ctrlspace#ui#Msg("Appending workspace '" . a:name . "'...")
        call add(commands, "tabe")
    else
        call ctrlspace#ui#Msg("Loading workspace '" . a:name . "'...")
        call add(commands, "tabe")
        call add(commands, "tabo!")
        call add(commands, "call ctrlspace#buffers#DeleteHiddenNonameBuffers(1)")
        call add(commands, "call ctrlspace#buffers#DeleteForeignBuffers(1)")
        call ctrlspace#workspaces#SetActiveWorkspaceName(a:name)
    endif

    call writefile(a:lines, "CS_SESSION")

    call add(commands, "source CS_SESSION")
    call add(commands, "redraw!")

    if a:bang
        call add(commands, "normal! " . curTab . "gt")
    endif

    for c in commands
        silent exe c
    endfor

    call delete("CS_SESSION")
endfunction

function! ctrlspace#workspaces#SaveWorkspace(name) abort
    if !ctrlspace#roots#ProjectRootFound()
        return 0
    endif

    call ctrlspace#util#HandleVimSettings("start")

    let cwdSave = fnamemodify(".", ":p:h")
    let root    = ctrlspace#roots#CurrentProjectRoot()

    silent! exe "cd " . fnameescape(root)

    if empty(a:name)
        if !empty(s:modes.Workspace.Data.Active.Name) && s:modes.Workspace.Data.Active.Root ==# root
            let name = s:modes.Workspace.Data.Active.Name
        else
            silent! exe "cd " . fnameescape(cwdSave)
            call ctrlspace#util#HandleVimSettings("stop")
            call ctrlspace#ui#Msg("Nothing to save.")
            return 0
        endif
    else
        let name = a:name
    endif

    let filename = s:workspaceFile()
    let lastTab  = tabpagenr("$")

    let lines       = []
    let inWorkspace = 0

    let startMarker = "CS_WORKSPACE_BEGIN: " . name
    let endMarker   = "CS_WORKSPACE_END: " . name

    if filereadable(filename)
        for oldLine in readfile(filename)
            if oldLine ==# startMarker
                let inWorkspace = 1
            endif

            if !inWorkspace
                call add(lines, oldLine)
            endif

            if oldLine ==# endMarker
                let inWorkspace = 0
            endif
        endfor
    endif

    call add(lines, startMarker)

    let ssopSave = &ssop
    set ssop=winsize,tabpages,buffers,sesdir

    let tabData = []

    for t in range(1, lastTab)
        let data = {
                    \ "label": ctrlspace#util#Gettabvar(t, "CtrlSpaceLabel"),
                    \ "autotab": ctrlspace#util#GettabvarWithDefault(t, "CtrlSpaceAutotab", 0)
                    \ }

        let ctrlspaceList = ctrlspace#api#Buffers(t)

        let bufs = []

        for [nr, bname] in items(ctrlspaceList)
            let bufname = fnamemodify(bname, ":.")

            if !filereadable(bufname)
                continue
            endif

            call add(bufs, bufname)
        endfor

        let data.bufs = bufs
        call add(tabData, data)
    endfor

    silent! exe "mksession! CS_SESSION"

    if !filereadable("CS_SESSION")
        silent! exe "cd " . fnameescape(cwdSave)
        silent! exe "set ssop=" . ssopSave

        call ctrlspace#util#HandleVimSettings("stop")
        call ctrlspace#ui#Msg("Workspace '" . name . "' cannot be saved at this moment.")
        return 0
    endif

    let tabIndex = 0

    for cmd in readfile("CS_SESSION")
        if cmd =~# "^lcd "
            continue
        elseif cmd =~# "^badd\>"
            let baddList = matchlist(cmd, '\v^badd \+\d+ (\f+)$')
            if exists("baddList[1]") && filereadable(baddList[1])
                call add(lines, cmd)
            endif
        elseif
        \    ((cmd =~# '^edit \f\+') && (tabIndex == 0))
        \ || ( (has('patch-8.1.149') || has('nvim-0.5')) && cmd ==# 'tabnext')
        \ || (!(has('patch-8.1.149') || has('nvim-0.5')) && cmd =~# '^tabedit \f\+')
        " NB: check patch-8.1.149 for backend vim mksession change
        " NB: check nvim-0.5 for port of patch-8.1.149 from Vim to Nvim
            let data = tabData[tabIndex]

            if cmd =~# '^tabedit \f\+'
                call add(lines, 'tabedit')
            elseif cmd ==# 'tabnext'
                call add(lines, cmd)
            endif

            for b in data.bufs
                call add(lines, 'edit ' . fnameescape(b))
            endfor

            if cmd =~# '^tabedit \f\+'
                " turn 'tabedit ...' into 'edit ...'
                call add(lines, cmd[3:])
            endif

            if !empty(data.label)
                call add(lines, "let t:CtrlSpaceLabel = '" . substitute(data.label, "'", "''","g") . "'")
            endif
            if !empty(data.autotab)
                call add(lines, "let t:CtrlSpaceAutotab = " . data.autotab)
            endif

            let tabIndex += 1
        else
            call add(lines, cmd)
        endif
    endfor

    call add(lines, endMarker)

    call writefile(lines, filename)
    call delete("CS_SESSION")

    call ctrlspace#workspaces#SetActiveWorkspaceName(name, ctrlspace#workspaces#CreateDigest())
    call ctrlspace#workspaces#SetWorkspaceNames()

    silent! exe "cd " . fnameescape(cwdSave)
    silent! exe "set ssop=" . ssopSave

    call ctrlspace#util#HandleVimSettings("stop")

    let msg = "Workspace '" . name . "' has been saved."
    call ctrlspace#ui#Msg(msg)
    call ctrlspace#ui#DelayedMsg(msg)

    return 1
endfunction

function! ctrlspace#workspaces#CreateDigest() abort
    let useNossl = exists("b:nosslSave") && b:nosslSave

    if useNossl
        set nossl
    endif

    let cpoSave = &cpo

    set cpo&vim

    let lines = []

    for t in range(1, tabpagenr("$"))
        let line     = [t, ctrlspace#util#Gettabvar(t, "CtrlSpaceLabel")]
        let bufs     = []
        let visibles = []

        let tabBuffers = ctrlspace#api#Buffers(t)

        for bname in values(tabBuffers)
            let bufname = fnamemodify(bname, ":p")

            if !filereadable(bufname)
                continue
            endif

            call add(bufs, bufname)
        endfor

        for visibleBuf in tabpagebuflist(t)
            if exists("tabBuffers[visibleBuf]")
                let bufname = fnamemodify(tabBuffers[visibleBuf], ":p")

                if !filereadable(bufname)
                    continue
                endif

                call add(visibles, bufname)
            endif
        endfor

        call add(line, join(bufs, "|"))
        call add(line, join(visibles, "|"))
        call add(lines, join(line, ","))
    endfor

    let digest = join(lines, "&&&")

    if useNossl
        set ssl
    endif

    let &cpo = cpoSave

    return digest
endfunction
