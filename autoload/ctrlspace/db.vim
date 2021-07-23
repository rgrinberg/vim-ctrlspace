let s:empty = { "bookmarks": [], "roots": {} }
let s:latest = v:null

let s:cacheDir = stdpath("cache") . "/ctrlspace.json"
let s:initCacheDir = v:false

function! s:cacheFile() abort
    if !s:initCacheDir
        call mkdir(s:cacheDir, "p")
        let s:initCacheDir = v:true
    endif

    return s:cacheDir . "/.cs_cache"
endfunction


function! ctrlspace#db#latest() abort
    if type(s:latest) == type(v:null)
        let s:latest = ctrlspace#db#load()
    endif
    return s:latest
endfunction

function! ctrlspace#db#load() abort
    let cacheFile = s:cacheFile()
    if filereadable(cacheFile)
        return json_decode(readfile(cacheFile))
    else
        return s:empty
    endif
endfunction

function! ctrlspace#db#save(data) abort
    let cacheFile = s:cacheFile()
    call writefile([json_encode(a:data)], cacheFile)
    let s:latest = a:data
endfunction

function! ctrlspace#db#add_bookmark(data, bm) abort
    call add(a:data.bookmarks, a:bm)
    call ctrlspace#db#save(a:data)
endfunction

function! ctrlspace#db#remove_bookmark(data, idx) abort
    call remove(a:data.bookmarks, a:idx)
    call ctrlspace#db#save(a:data)
endfunction

function! ctrlspace#db#add_root(data, root) abort
    let a:data.roots[root] = 1
    call ctrlspace#db#save(a:data)
endfunction

function! ctrlspace#db#remove_root(data, root) abort
    unlet data.roots[root]
    call remove(a:data.roots, a:idx)
    call ctrlspace#db#save(a:data)
endfunction
