let s:config     = ctrlspace#context#Configuration()
let s:modes      = ctrlspace#modes#Modes()

function! s:emptyWorkspaces()
    return { "workspaces": {} }
endfunction

let s:db = s:emptyWorkspaces()

function! s:workspaceFile() abort
    return ctrlspace#util#projectLocalFile("cs_workspaces.json")
endfunction

function! ctrlspace#workspaces#Workspaces() abort
    let names = keys(s:db.workspaces)
    call sort(names)
    return names
endfunction

let s:emptyKey = "<unnamed>"

function! s:loadWorkspaces() abort
    let file = s:workspaceFile()
    if filereadable(file)
        let s:db = json_decode(readfile(file))
        if has_key(s:db.workspaces, s:emptyKey)
            let s:db.workspaces[""] = s:db.workspaces[s:emptyKey]
            unlet s:db.workspaces[s:emptyKey]
        endif
    else
        let s:db = s:emptyWorkspaces()
    endif
endfunction

function! s:saveWorkspaces() abort
    let file = s:workspaceFile()
    let data = deepcopy(s:db)
    if has_key(data.workspaces, "")
        data.workspaces[s:emptyKey] = data[""]
    endif
    call writefile([json_encode(data)], file)
endfunction

function! ctrlspace#workspaces#SetWorkspaceNames() abort
    call s:modes.Workspace.SetData("LastActive", "")
    call s:loadWorkspaces()

    if has_key(s:db.workspaces, "LastActive")
        call s:modes.Workspace.SetData("LastActive", s:db.LastActive)
    endif
endfunction

function! s:setActiveWorkspaceName(name, digest) abort
    call s:modes.Workspace.SetData("Active", { "Name": a:name, "Digest": a:digest, "Root": ctrlspace#roots#CurrentProjectRoot() })
    call s:modes.Workspace.SetData("LastActive", a:name)

    let s:db.LastActive = a:name
    call s:saveWorkspaces()
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
    return s:modes.Workspace.Enabled ? ctrlspace#workspaces#Workspaces()[ctrlspace#window#SelectedIndex()] : ""
endfunction

function! ctrlspace#workspaces#RenameWorkspace(name) abort
    let newName = ctrlspace#ui#GetInput("Rename workspace '" . a:name . "' to: ", a:name)

    if empty(newName)
        return
    endif

    if has_key(s:db.workspaces, newName)
        call ctrlspace#ui#Msg("Workspace '" . newName . "' already exists.")
        return
    endif

    let s:db.LastActive = a:name

    let s:db.workspaces[newName] = s:db.workspaces[a:name]
    unlet s:db.workspaces[a:name]
    call s:saveWorkspaces()

    if s:modes.Workspace.Data.Active.Name ==# a:name && s:modes.Workspace.Data.Active.Root ==# ctrlspace#roots#CurrentProjectRoot()
        call s:setActiveWorkspaceName(newName, s:modes.Workspace.Data.Active.Digest)
    endif

    call ctrlspace#workspaces#SetWorkspaceNames()
    call ctrlspace#window#Kill(0)
    call ctrlspace#window#Toggle(1)

    call ctrlspace#ui#DelayedMsg("Workspace '" . a:name . "' has been renamed to '" . newName . "'.")
endfunction

function! ctrlspace#workspaces#DeleteWorkspace(name) abort
    if !ctrlspace#ui#Confirmed("Delete workspace '" . a:name . "'?")
        return
    endif

    let inWorkspace = 0

    unlet s:db.workspaces[a:name]
    call s:saveWorkspaces()

    if s:modes.Workspace.Data.Active.Name ==# a:name && s:modes.Workspace.Data.Active.Root ==# ctrlspace#roots#CurrentProjectRoot()
        call s:setActiveWorkspaceName(a:name, "")
    endif

    call ctrlspace#workspaces#SetWorkspaceNames()
    call ctrlspace#window#refresh()
    call ctrlspace#ui#DelayedMsg("Workspace '" . a:name . "' has been deleted.")
endfunction

" bang == 0) load
" bang == 1) append
function! ctrlspace#workspaces#LoadWorkspace(bang, name) abort
    if !ctrlspace#roots#ProjectRootFound()
        return 0
    endif

    call ctrlspace#util#HandleVimSettings("start")

    if !has_key(s:db.workspaces, a:name)
        call ctrlspace#ui#Msg("Workspace '" . a:name . "' not found")
        return 0
    endif

    let cwdSave = fnamemodify(".", ":p:h")
    silent! exe "cd " . fnameescape(ctrlspace#roots#CurrentProjectRoot())

    let workspace = s:db.workspaces[a:name]
    call s:execWorkspaceCommands(a:bang, workspace)

    if a:bang
        let s:modes.Workspace.Data.Active.Digest = ""
        let msg = "Workspace '" . a:name . "' has been appended."
    else
        let s:modes.Workspace.Data.Active.Digest = ctrlspace#workspaces#CreateDigest()
        let msg = "Workspace '" . a:name . "' has been loaded."
    endif

    call ctrlspace#ui#Msg(msg)
    call ctrlspace#ui#DelayedMsg(msg)

    silent! exe "cd " . fnameescape(cwdSave)

    call ctrlspace#util#HandleVimSettings("stop")

    return 1
endfunction

function! s:execWorkspaceCommands(bang, workspace) abort
    let commands = ["tabe"]

    if a:bang
        let curTab = tabpagenr()
        call ctrlspace#ui#Msg("Appending workspace '" . a:workspace.Name . "'...")
    else
        call ctrlspace#ui#Msg("Loading workspace '" . a:workspace.Name . "'...")
        call add(commands, "tabo!")
        call add(commands, "call ctrlspace#buffers#DeleteHiddenNonameBuffers(1)")
        call add(commands, "call ctrlspace#buffers#DeleteForeignBuffers(1)")
        call s:setActiveWorkspaceName(a:workspace.Name, s:modes.Workspace.Data.Active.Digest)
    endif

    call writefile(a:workspace.commands, "CS_SESSION")

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

    if empty(a:name)
        if !empty(s:modes.Workspace.Data.Active.Name) && s:modes.Workspace.Data.Active.Root ==# root
            let name = s:modes.Workspace.Data.Active.Name
        else
            call ctrlspace#ui#Msg("Nothing to save.")
            return 0
        endif
    else
        let name = a:name
    endif

    call ctrlspace#util#HandleVimSettings("start")

    let cwdSave = fnamemodify(".", ":p:h")
    let root    = ctrlspace#roots#CurrentProjectRoot()

    silent! exe "cd " . fnameescape(root)

    let filename = s:workspaceFile()
    let lastTab  = tabpagenr("$")

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

        for [nr, bufname] in items(ctrlspaceList)
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
    let lines = []

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
        \ || (cmd ==# 'tabnext')
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

    call delete("CS_SESSION")
    let newWs = { "commands" : lines, "Name": a:name }
    let s:db.workspaces[a:name] = newWs
    call s:saveWorkspaces()

    call s:setActiveWorkspaceName(name, ctrlspace#workspaces#CreateDigest())
    " TODO why do we need this reload?
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
