let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

function! ctrlspace#tabs#SetTabLabel(tabnr, label, auto) abort
  let F = luaeval('require("ctrlspace").tabs.set_label')
  call F(a:tabnr, a:label, a:auto)
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
    if empty(ctrlspace#util#Gettabvar(a:tabnr, "CtrlSpaceLabel"))
        return 0
    endif

    call ctrlspace#tabs#SetTabLabel(a:tabnr, "", 0)
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
  call luaeval('require("ctrlspace").tabs.collect_unsaved()')
endfunction

function! ctrlspace#tabs#CollectForeignBuffers() abort
  call luaeval('require("ctrlspace").tabs.collect_foreign()')
endfunction
