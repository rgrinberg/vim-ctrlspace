let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

function! ctrlspace#tabs#SetTabLabel(tabnr, label, auto) abort
    call settabvar(a:tabnr, "CtrlSpaceLabel", a:label)
    call settabvar(a:tabnr, "CtrlSpaceAutotab", a:auto)
    if get(g:, 'loaded_airline', 0)
        " Force Update of tabline in airline
        call airline#extensions#tabline#ctrlspace#invalidate()
        sil doautocmd <nomodeline> TabEnter
    endif
endfunction

function! ctrlspace#tabs#NewTabLabel(tabnr) abort
    let tabnr = a:tabnr > 0 ? a:tabnr : tabpagenr()
    let label = ctrlspace#ui#GetInput("Label for tab " . tabnr . ": ", ctrlspace#util#Gettabvar(tabnr, "CtrlSpaceLabel"))
    if empty(label)
        return 0
    endif

    call ctrlspace#tabs#SetTabLabel(tabnr, label, 0)
    return 1
endfunction

function! ctrlspace#tabs#RemoveTabLabel(tabnr) abort
    let tabnr = a:tabnr > 0 ? a:tabnr : tabpagenr()

    if empty(ctrlspace#util#Gettabvar(tabnr, "CtrlSpaceLabel"))
        return 0
    endif

    call ctrlspace#tabs#SetTabLabel(tabnr, "", 0)
    return 1
endfunction

function! ctrlspace#tabs#CloseTab() abort
    if tabpagenr("$") == 1
        return
    endif

    if exists("t:CtrlSpaceAutotab") && (t:CtrlSpaceAutotab != 0)
        " do nothing
    elseif exists("t:CtrlSpaceLabel") && !empty(t:CtrlSpaceLabel)
        let bufCount = len(ctrlspace#buffers#TabBuffers(tabpagenr()))

        if (bufCount > 1) && !ctrlspace#ui#Confirmed("Close tab named '" . t:CtrlSpaceLabel . "' with " . bufCount . " buffers?")
            return
        endif
    endif

    call ctrlspace#window#kill()

    tabclose

    call ctrlspace#buffers#DeleteHiddenNonameBuffers(1)
    call ctrlspace#buffers#DeleteForeignBuffers(1)

    call ctrlspace#window#revive()
endfunction

function! ctrlspace#tabs#CollectUnsavedBuffers() abort
    let buffers = luaeval('require("ctrlspace").buffers.unsaved()')

    if empty(buffers)
        call ctrlspace#ui#Msg("There are no unsaved buffers.")
    endif

    call ctrlspace#window#revive()

    tabnew

    call ctrlspace#tabs#SetTabLabel(tabpagenr(), "Unsaved Buffers", 1)

    for b in buffers
        silent! exe ":b " . b
    endfor

    call s:modes.Tab.Enable()
    call ctrlspace#window#revive()
endfunction

function! ctrlspace#tabs#CollectForeignBuffers() abort
    let foreignBuffers = luaeval('require("ctrlspace").buffers.foreign()')

    if empty(foreignBuffers)
        call ctrlspace#ui#Msg("There are no foreign buffers.")
    endif

    call ctrlspace#window#kill()

    tabnew

    call ctrlspace#tabs#SetTabLabel(tabpagenr(), "Foreign Buffers", 1)

    for fb in foreignBuffers
        silent! exe ":b " . fb
    endfor

    call s:modes.Tab.Enable()
    call ctrlspace#window#revive()
endfunction
