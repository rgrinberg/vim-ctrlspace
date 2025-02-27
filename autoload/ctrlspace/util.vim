function! ctrlspace#util#system(cmd, ...) abort
    if has('win32') && &shell !~? 'cmd'
        let saved_shell = [
            \ &shell,
            \ &shellcmdflag,
            \ &shellxquote,
            \ &shellxescape,
            \ &shellquote,
            \ &shellpipe,
            \ &shellredir,
            \ &shellslash
            \]
        set shell& shellcmdflag& shellxquote& shellxescape&
        set shellquote& shellpipe& shellredir& shellslash&
    endif

    let output = a:0 > 0 ? system(a:cmd, a:1) : system(a:cmd)

    if exists('saved_shell')
        let [ &shell,
            \ &shellcmdflag,
            \ &shellxquote,
            \ &shellxescape,
            \ &shellquote,
            \ &shellpipe,
            \ &shellredir,
            \ &shellslash ] = saved_shell
    endif

    return has('win32') ? substitute(output, "\r", '', 'g') : output
endfunction

function! ctrlspace#util#NormalizeDirectory(directory) abort
  let F = luaeval('require("ctrlspace").util.normalize_dir')
  return F(a:directory)
endfunction

function! ctrlspace#util#HandleVimSettings(switch) abort
    call s:handleSwitchbuf(a:switch)
    call s:handleAutochdir(a:switch)
endfunction

function! s:handleSwitchbuf(switch) abort
    if (a:switch ==# "start") && !empty(&swb)
        let s:swbSave = &swb
        set swb=
    elseif (a:switch ==# "stop") && exists("s:swbSave")
        let &swb = s:swbSave
        unlet s:swbSave
    endif
endfunction

function! s:handleAutochdir(switch) abort
    if (a:switch ==# "start") && &acd
        let s:acdWasOn = 1
        set noacd
    elseif (a:switch ==# "stop") && exists("s:acdWasOn")
        set acd
        unlet s:acdWasOn
    endif
endfunction

function! ctrlspace#util#ChDir(dir) abort
    let F = luaeval('require("ctrlspace").util.chdir')
    call F(a:dir)
endfunction

function ctrlspace#util#projectLocalFile(name) abort
    let F = luaeval('require("ctrlspace").util.project_local_file')
    return F(a:name)
endfunction

function! ctrlspace#util#GetbufvarWithDefault(nr, name, default) abort
    let value = getbufvar(a:nr, a:name)
    return type(value) == 1 && empty(value) ? a:default : value
endfunction

function! ctrlspace#util#SetStatusline() abort
    let config = ctrlspace#context#Configuration()
    silent! exe "let &l:statusline = " . config.StatuslineFunction
endfunction
