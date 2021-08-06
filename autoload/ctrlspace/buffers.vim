let s:modes      = ctrlspace#modes#Modes()

function! ctrlspace#buffers#Init() abort
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

function! ctrlspace#buffers#CopyBufferToTab(tab) abort
    let F = luaeval('require("ctrlspace").copy_or_move_selected_buffer')
    call F(tab, "copy")
endfunction

function! ctrlspace#buffers#MoveBufferToTab(tab) abort
    let F = luaeval('require("ctrlspace").copy_or_move_selected_buffer')
    call F(tab, "move")
endfunction

function! ctrlspace#buffers#GoToBufferOrFile(direction) abort
    let direction = a:direction == "next" ? 1 : -1
    let F = luaeval('require("ctrlspace").drawer.go_to_buffer_or_file')
    call F(direction)
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

    if a:move
        call luaeval('require("ctrlspace").buffers.detach()')
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
