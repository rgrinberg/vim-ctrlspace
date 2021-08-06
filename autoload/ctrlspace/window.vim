let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

function! ctrlspace#window#MaxHeight() abort
    return luaeval('require("ctrlspace").drawer.max_height()')
endfunction

function! ctrlspace#window#run(...) abort
    let default = {
                \ "insert": v:false,
                \ "input": "" ,
                \ "mode": "Buffer",
                \ }

    if a:0 > 0
        let args = a:1
    else
        let args = {}
    endif

    let options = extend(default, args)

    let mode = toupper(options.mode[0]) . strpart(options.mode, 1)
    let modes = ctrlspace#modes#Modes()
    let mode = modes[mode]

    call mode.Enable()

    call s:modes.Search.SetData("Letters", split(options.input, '\zs'))
    call luaeval('require("ctrlspace").files.clear()')

    if options.insert
        call modes.Search.Enable()
    else
        call modes.Search.Disable()
    endif

    call ctrlspace#window#revive()
endfunction

" should be called when the contents of the window changes
function! ctrlspace#window#refresh() abort
    call luaeval('require("ctrlspace").drawer.refresh()')
endfunction

function! ctrlspace#window#kill() abort
    call ctrlspace#window#Kill(1)
endfunction

function! ctrlspace#window#revive() abort
    call ctrlspace#window#restore()
endfunction

" restore the ctrlspace window and buffer to the previous invocation
function! ctrlspace#window#restore() abort
    call luaeval('require("ctrlspace").drawer.restore()')
endfunction

function! ctrlspace#window#Toggle(internal) abort
  let F = luaeval('require("ctrlspace").drawer.toggle')
  let arg = a:internal == 0 ? v:false : v:true
  F(arg)
endfunction

function! ctrlspace#window#GoToStartWindow() abort
  call luaeval('require("ctrlspace").drawer.go_start_window()')
endfunction

function! ctrlspace#window#Kill(final) abort
  let arg = a:final ? v:true : v:false
  let F = luaeval('require("ctrlspace").drawer.kill')
  return F(arg)
endfunction

function! ctrlspace#window#QuitVim() abort
    if !s:config.SaveWorkspaceOnExit
        let aw = ctrlspace#workspaces#ActiveWorkspace()

        if aw.Status == 2 && !ctrlspace#ui#Confirmed("Current workspace ('" . aw.Name . "') not saved. Proceed anyway?")
            return
        endif
    endif

    if !ctrlspace#ui#ProceedIfModified()
        return
    endif

    call ctrlspace#window#Kill(1)
    qa!
endfunction

function! ctrlspace#window#MoveSelectionBar(where) abort
  let F = luaeval('require("ctrlspace").drawer.move_selection_and_remember')
  call F(a:where)
endfunction

function! ctrlspace#window#MoveCursor(where) abort
  let F = luaeval('require("ctrlspace").drawer.move_selection')
  call F(a:where)
endfunction

function! ctrlspace#window#SelectedIndex() abort
  return luaeval('require("ctrlspace").drawer.last_selected_index()')
endfunction

function! ctrlspace#window#GoToWindow() abort
    return luaeval('require("ctrlspace").drawer.go_to_window()')
endfunction

function! ctrlspace#window#setActiveLine() abort
    if !empty(s:modes.Search.Data.Letters) && s:modes.Search.Data.NewSearchPerformed
        call ctrlspace#window#MoveSelectionBar(line("$"))

        if !s:modes.Search.Enabled
            call s:modes.Search.SetData("NewSearchPerformed", 0)
        endif
    else
        let clv = ctrlspace#modes#CurrentListView()

        if clv.Name ==# "Workspace"
            if clv.Data.LastBrowsed
                let activeLine = clv.Data.LastBrowsed
            else
                let activeLine = 1
                let aw         = ctrlspace#workspaces#ActiveWorkspace()

                if aw.Status
                    let currWsp = aw.Name
                elseif !empty(clv.Data.LastActive)
                    let currWsp = clv.Data.LastActive
                else
                    let currWsp = ""
                endif

                if !empty(currWsp)
                    let workspaces = ctrlspace#workspaces#Workspaces()

                    for i in range(b:size)
                        if currWsp ==# workspaces[b:items[i].index]
                            let activeLine = i + 1
                            break
                        endif
                    endfor
                endif
            endif
        elseif clv.Name ==# "Tab"
            let activeLine = tabpagenr()
        elseif clv.Name ==# "Bookmark"
            let activeLine = 1

            if !empty(clv.Data.Active)
                let bookmarks = ctrlspace#bookmarks#Bookmarks()

                for i in range(b:size)
                    if clv.Data.Active.Name ==# bookmarks[b:items[i].index].Name
                        let activeLine = i + 1
                        break
                    endif
                endfor
            endif
        elseif clv.Name ==# "File"
            let activeLine = line("$")
        else
            let activeLine = 0
            let maxCounter = 0
            let lastLine   = 0

            for i in range(b:size)
                if b:items[i].index == t:CtrlSpaceActivebuf
                    let activeLine = i + 1
                    break
                endif

                let currentJumpCounter = ctrlspace#util#GetbufvarWithDefault(b:items[i].index, "CtrlSpaceJumpCounter", 0)

                if currentJumpCounter > maxCounter
                    let maxCounter = currentJumpCounter
                    let lastLine = i + 1
                endif
            endfor

            if !activeLine
                let activeLine = (lastLine > 0) ? lastLine : b:size - 1
            endif
        endif

        call ctrlspace#window#MoveSelectionBar(activeLine)
    endif
endfunction
