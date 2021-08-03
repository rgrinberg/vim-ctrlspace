let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

function! ctrlspace#tabs#SetTabLabel(tabnr, label, auto) abort
  let F = luaeval('require("ctrlspace").tabs.set_label')
  call F(a:tabnr, a:label, a:auto)
endfunction

function! ctrlspace#tabs#NewTabLabel(tabnr) abort
    let F = luaeval('require("ctrlspace").tabs.new_label')
    return F(a:tabnr)
endfunction

function! ctrlspace#tabs#RemoveTabLabel(tabnr) abort
    let F = luaeval('require("ctrlspace").tabs.remove_label')
    return F(a:tabnr)
endfunction

function! ctrlspace#tabs#CloseTab() abort
  call luaeval('require("ctrlspace").tabs.close()')
endfunction

function! ctrlspace#tabs#CollectUnsavedBuffers() abort
  call luaeval('require("ctrlspace").tabs.collect_unsaved()')
endfunction

function! ctrlspace#tabs#CollectForeignBuffers() abort
  call luaeval('require("ctrlspace").tabs.collect_foreign()')
endfunction
