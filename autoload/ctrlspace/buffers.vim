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

function! ctrlspace#buffers#DeleteHiddenNonameBuffers() abort
    call luaeval('require("ctrlspace").buffers.delete_hidden_noname()')
endfunction

" deletes all foreign buffers
" TODO remove this 'internal' parameter
function! ctrlspace#buffers#DeleteForeignBuffers() abort
    call luaeval('require("ctrlspace").buffers.delete_foreign()')
endfunction
