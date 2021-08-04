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
