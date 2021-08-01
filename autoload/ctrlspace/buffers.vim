let s:modes      = ctrlspace#modes#Modes()

function! ctrlspace#buffers#SelectedBufferName() abort
    return s:modes.Buffer.Enabled ? bufname(ctrlspace#window#SelectedIndex()) : ""
endfunction

function! ctrlspace#buffers#Init() abort
endfunction

function! ctrlspace#buffers#AddBuffer() abort
    call luaeval('require("ctrlspace").buffers.add_current()')
endfunction

function! ctrlspace#buffers#Buffers() abort
    return luaeval('require("ctrlspace").buffers.all()')
endfunction

function! ctrlspace#buffers#TabBuffers(tabnr) abort
    let In_tab = luaeval('require("ctrlspace").buffers.in_tab')
    let foo = In_tab(a:tabnr)
    return foo
endfunction

function! ctrlspace#buffers#LoadBuffer(cmds) abort
    let F = luaeval('require("ctrlspace").buffers.load')
    call F(a:cmds)
endfunction

function! ctrlspace#buffers#LoadManyBuffers(pre, post) abort
    let F = luaeval('require("ctrlspace").buffers.load_keep')
    call F(a:pre, a:post)
endfunction

function! ctrlspace#buffers#ZoomBuffer(nr, ...) abort
    if !s:modes.Zoom.Enabled
        call s:modes.Zoom.Enable()
        call s:modes.Zoom.SetData("Buffer", winbufnr(t:CtrlSpaceStartWindow))
        call s:modes.Zoom.SetData("Mode", "Buffer")
        call s:modes.Zoom.SetData("SubMode", s:modes.Buffer.Data.SubMode)
        call s:modes.Zoom.SetData("Line", line("."))
        call s:modes.Zoom.SetData("Letters", copy(s:modes.Search.Data.Letters))
    endif

    let nr = a:nr ? a:nr : ctrlspace#window#SelectedIndex()

    call ctrlspace#window#hide()
    call ctrlspace#window#GoToStartWindow()

    silent! exe ":b " . nr

    let customCommands = !empty(a:000) ? a:1 : ["normal! zb"]

    for c in customCommands
        silent! exe c
    endfor

    call ctrlspace#window#show()
    call ctrlspace#window#refresh()
endfunction

function! ctrlspace#buffers#CopyBufferToTab(tab) abort
    return s:copyOrMoveSelectedBufferIntoTab(a:tab, 0)
endfunction

function! ctrlspace#buffers#MoveBufferToTab(tab) abort
    return s:copyOrMoveSelectedBufferIntoTab(a:tab, 1)
endfunction

" Detach a buffer if it belongs to other tabs or delete it otherwise.
" It means, this function doesn't leave buffers without tabs.
function! ctrlspace#buffers#CloseBuffer() abort
    let nr = ctrlspace#window#SelectedIndex()
    let F = luaeval('require("ctrlspace").tabs.buffer_present_count')
    let foundTabs = F(nr)

    if foundTabs > 1
        call ctrlspace#buffers#DetachBuffer()
    else
        call ctrlspace#buffers#DeleteBuffer()
    endif
endfunction

function! ctrlspace#buffers#DeleteBuffer() abort
  call luaeval('require("ctrlspace").buffers.delete()')
endfunction

function! ctrlspace#buffers#DetachBuffer() abort
    let nr = ctrlspace#window#SelectedIndex()

    if exists("t:CtrlSpaceList[nr]")
        let selBufWin = bufwinnr(nr)
        let curln     = line(".")

        if selBufWin == -1
            call ctrlspace#window#Kill(0)
        else
            call ctrlspace#window#MoveSelectionBar("down")
            if ctrlspace#window#SelectedIndex() == nr
                call ctrlspace#window#MoveSelectionBar("up")

                if ctrlspace#window#SelectedIndex() == nr
                    if bufexists(nr) && (!empty(getbufvar(nr, "&buftype")) || filereadable(bufname(nr)))
                        let curln = line(".")
                        call ctrlspace#window#Kill(0)
                        silent! exe selBufWin . "wincmd w"
                        enew
                    else
                        return
                    endif
                else
                    call s:loadBufferIntoWindow(selBufWin)
                endif
            else
                call s:loadBufferIntoWindow(selBufWin)
            endif
        endif
        call remove(t:CtrlSpaceList, nr)
        call ctrlspace#window#Toggle(1)
        call ctrlspace#window#MoveSelectionBar(curln)
    endif
endfunction

function! ctrlspace#buffers#GoToBufferOrFile(direction) abort
    let nr      = ctrlspace#window#SelectedIndex()
    let curTab  = tabpagenr()
    let lastTab = tabpagenr("$")

    let targetTab = 0
    let targetBuf = 0

    if lastTab == 1
        let tabsToCheck = [1]
    elseif curTab == 1
        if a:direction == "next"
            let tabsToCheck = range(2, lastTab) + [1]
        else
            let tabsToCheck = range(lastTab, curTab, -1)
        endif
    elseif curTab == lastTab
        if a:direction == "next"
            let tabsToCheck = range(1, lastTab)
        else
            let tabsToCheck = range(lastTab - 1, 1, -1) + [lastTab]
        endif
    else
        if a:direction == "next"
            let tabsToCheck = range(curTab + 1, lastTab) + range(1, curTab - 1) + [curTab]
        else
            let tabsToCheck = range(curTab - 1, 1, -1) + range(lastTab, curTab + 1, -1) + [curTab]
        endif
    endif

    if s:modes.File.Enabled
        let file = fnamemodify(ctrlspace#files#SelectedFileName(), ":p")
    endif

    for t in tabsToCheck
        for [bufnr, name] in items(ctrlspace#api#Buffers(t))
            if s:modes.File.Enabled
                if fnamemodify(name, ":p") !=# file
                    continue
                endif
            elseif str2nr(bufnr) != nr
                continue
            endif

            let targetTab = t
            let targetBuf = str2nr(bufnr)
            break
        endfor

        if targetTab > 0
            break
        endif
    endfor

    if (targetTab > 0) && (targetBuf > 0)
        call ctrlspace#window#Kill(1)
        silent! exe "normal! " . targetTab . "gt"
        call ctrlspace#window#Toggle(0)
        for i in range(b:size)
            if b:items[i].index == targetBuf
                call ctrlspace#window#MoveSelectionBar(i + 1)
                break
            endif
        endfor
    else
        call ctrlspace#ui#Msg("Cannot find a tab containing selected " . (s:modes.File.Enabled ? "file." : "buffer."))
    endif
endfunction

function! ctrlspace#buffers#DeleteHiddenNonameBuffers(internal) abort
    if !a:internal
        call ctrlspace#window#Kill(0)
    endif

    call luaeval('require("ctrlspace").buffers.delete_hidden_noname()')

    if !a:internal
        call ctrlspace#window#Toggle(1)
        call ctrlspace#ui#DelayedMsg("Hidden unnamed buffers removed.")
    endif
endfunction

" deletes all foreign buffers
" TODO remove this 'internal' parameter
function! ctrlspace#buffers#DeleteForeignBuffers(internal) abort
    if !a:internal
        call ctrlspace#window#Kill(0)
    endif

    call luaeval('require("ctrlspace").buffers.delete_foreign()')

    if !a:internal
        call ctrlspace#window#Toggle(1)
        call ctrlspace#ui#DelayedMsg("Foreign buffers removed.")
    endif
endfunction

function! s:copyOrMoveSelectedBufferIntoTab(tab, move) abort
    let nr = ctrlspace#window#SelectedIndex()
    let bname = bufname(nr)

    if !getbufvar(nr, "&buflisted") || empty(bname)
        return
    endif

    let map = ctrlspace#util#GettabvarWithDefault(a:tab, "CtrlSpaceList", {})

    if a:move
        call ctrlspace#buffers#DetachBuffer()
    endif

    let AddBuffer = luaeval('require("ctrlspace").tabs.add_buffer')
    call AddBuffer(a:tab, nr)

    call ctrlspace#window#kill()

    silent! exe "normal! " . a:tab . "gt"

    call ctrlspace#window#restore()

    for i in range(b:size)
        if bufname(b:items[i].index) ==# bname
            call ctrlspace#window#MoveSelectionBar(i + 1)
            call ctrlspace#buffers#LoadManyBuffers()
            break
        endif
    endfor
endfunction

function! s:loadBufferIntoWindow(winnr) abort
    let old = t:CtrlSpaceStartWindow
    let t:CtrlSpaceStartWindow = a:winnr
    call ctrlspace#buffers#LoadBuffer([])
    let t:CtrlSpaceStartWindow = old
endfunction
