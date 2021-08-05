let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

function! ctrlspace#ui#Msg(message) abort
    echo s:config.Symbols.CS . "  " . a:message
endfunction

function! ctrlspace#ui#DelayedMsg(...) abort
    if !empty(a:000)
        let s:delayedMessage = a:1
    elseif exists("s:delayedMessage") && !empty(s:delayedMessage)
        redraw
        call ctrlspace#ui#Msg(s:delayedMessage)
        unlet s:delayedMessage
    endif
endfunction

function! ctrlspace#ui#GetInput(msg, ...) abort
    let F = luaeval('require("ctrlspace").ui.input')
    return F(a:msg, a:1, a:2)
endfunction

function! ctrlspace#ui#Confirmed(msg) abort
    let F = luaeval('require("ctrlspace").ui.confirmed')
    return F(a:msg)
endfunction

function! ctrlspace#ui#ProceedIfModified() abort
    return luaeval('require("ctrlspace").ui.confirm_if_modified()')
endfunction
