function! ctrlspace#roots#CurrentProjectRoot() abort
    let root = luaeval('require("ctrlspace").roots.current()')
    return root || ""
endfunction

function! ctrlspace#roots#SetCurrentProjectRoot(value) abort
    echomsg "setting root to " . a:value
    let F = luaeval('require("ctrlspace").roots.set')
    call F(a:value)
endfunction

function! ctrlspace#roots#ProjectRootFound() abort
    return luaeval('require("ctrlspace").roots.ask_if_unset()') ? 1 : 0
endfunction
