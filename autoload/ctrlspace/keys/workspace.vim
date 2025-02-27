let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

function! ctrlspace#keys#workspace#Init() abort
    call ctrlspace#keys#AddMapping("ctrlspace#keys#workspace#Load",         "Workspace", ["Tab", "CR", "Space"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#workspace#Append",       "Workspace", ["a"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#workspace#NewWorkspace", "Workspace", ["N"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#workspace#Save",         "Workspace", ["s"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#workspace#Delete",       "Workspace", ["d"])
    call ctrlspace#keys#AddMapping("ctrlspace#keys#workspace#Rename",       "Workspace", ["=", "m"])
endfunction

function! ctrlspace#keys#workspace#Delete(k) abort
    let name = ctrlspace#workspaces#SelectedWorkspaceName()
    if !ctrlspace#ui#Confirmed("Delete workspace '" . name . "'?")
        return
    endif

    let inWorkspace = 0

    unlet s:db.workspaces[name]
    call s:saveWorkspaces()

    if s:modes.Workspace.Data.Active.Name ==# name && s:modes.Workspace.Data.Active.Root ==# ctrlspace#roots#CurrentProjectRoot()
        call s:setActiveWorkspaceName(name, "")
    endif

    call ctrlspace#workspaces#SetWorkspaceNames()
    call ctrlspace#window#refresh()
    call ctrlspace#ui#DelayedMsg("Workspace '" . name . "' has been deleted.")
endfunction

function! ctrlspace#keys#workspace#Rename(k) abort
    let name = ctrlspace#workspaces#SelectedWorkspaceName()
    let newName = ctrlspace#ui#GetInput("Rename workspace '" . name . "' to: ", name)

    if empty(newName)
        return
    endif

    if has_key(s:db.workspaces, newName)
        call ctrlspace#ui#Msg("Workspace '" . newName . "' already exists.")
        return
    endif

    let s:db.LastActive = name

    let s:db.workspaces[newName] = s:db.workspaces[name]
    unlet s:db.workspaces[name]
    call s:saveWorkspaces()

    if s:modes.Workspace.Data.Active.Name ==# name && s:modes.Workspace.Data.Active.Root ==# ctrlspace#roots#CurrentProjectRoot()
        call s:setActiveWorkspaceName(newName, s:modes.Workspace.Data.Active.Digest)
    endif

    call ctrlspace#workspaces#SetWorkspaceNames()
    call ctrlspace#window#refresh()

    call ctrlspace#ui#DelayedMsg("Workspace '" . name . "' has been renamed to '" . newName . "'.")
    call ctrlspace#ui#DelayedMsg()
endfunction

function! ctrlspace#keys#workspace#Load(k) abort
    if !s:loadWorkspace(0, ctrlspace#workspaces#SelectedWorkspaceName())
        return
    endif

    call s:modes.Workspace.Enable()
    call ctrlspace#window#restore()
    call ctrlspace#ui#DelayedMsg()
endfunction

function! ctrlspace#keys#workspace#Save(k) abort
    if !s:saveWorkspace(ctrlspace#workspaces#SelectedWorkspaceName())
        return
    endif

    call s:modes.Workspace.Enable()
    call ctrlspace#window#restore()
    call ctrlspace#ui#DelayedMsg()
endfunction

function! ctrlspace#keys#workspace#Append(k) abort
    call s:loadWorkspace(1, ctrlspace#workspaces#SelectedWorkspaceName())
    call ctrlspace#ui#DelayedMsg()
endfunction

function! ctrlspace#keys#workspace#NewWorkspace(k) abort
    if !ctrlspace#keys#buffer#NewWorkspace(a:k)
        return
    endif

    call s:modes.Workspace.Enable()
    call ctrlspace#window#refresh()
endfunction

function! s:saveWorkspace(name) abort
    let name = ctrlspace#ui#GetInput("Save current workspace as: ", a:name)

    if empty(name)
        return 0
    endif

    call ctrlspace#window#Kill(1)
    return ctrlspace#workspaces#SaveWorkspace(name)
endfunction

function! s:loadWorkspace(bang, name) abort
    let saveWorkspaceBefore = 0
    let active = ctrlspace#workspaces#ActiveWorkspace()

    if active.Status && !a:bang
        let msg = ""

        if a:name ==# active.Name
            let msg = "Reload current workspace: '" . a:name . "'?"
        elseif active.Status == 2
            if s:config.SaveWorkspaceOnSwitch
                let saveWorkspaceBefore = 1
            else
                let msg = "Current workspace ('" . active.Name . "') not saved. Proceed anyway?"
            endif
        endif

        if !empty(msg) && !ctrlspace#ui#Confirmed(msg)
            return 0
        endif
    endif

    if !a:bang && !ctrlspace#ui#ProceedIfModified()
        return 0
    endif

    call ctrlspace#window#Kill(1)

    if saveWorkspaceBefore && !ctrlspace#workspaces#SaveWorkspace("")
        return 0
    endif

    if !ctrlspace#workspaces#LoadWorkspace(a:bang, a:name)
        return 0
    endif

    if a:bang
        " XXX Why are we doing this? The callers can just do it themselves
        call s:modes.Workspace.Enable()
        call ctrlspace#window#Kill(0)
        call ctrlspace#window#Toggle(1)
    endif

    return 1
endfunction
