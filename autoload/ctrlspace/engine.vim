let s:config     = ctrlspace#context#Configuration()
let s:modes      = ctrlspace#modes#Modes()

call luaeval('require("ctrlspace")')

" returns [patterns, indices, size, text]
function! ctrlspace#engine#Content() abort
    let items = s:contentSource()
    let absoluteMax = 500

    if empty(s:modes.Search.Data.Letters)
        if len(items) > absoluteMax
            let items = items[0:absoluteMax - 1]
        endif
    else
        let max = s:modes.Search.Enabled ? ctrlspace#window#MaxHeight() : absoluteMax
        let items = v:lua.ctrlspace_filter(items, join(s:modes.Search.Data.Letters, ''), max)
    endif

    return s:prepareContent(items)
endfunction

function! s:contentSource() abort
    let clv = ctrlspace#modes#CurrentListView()

    if clv.Name ==# "Buffer"
        return s:bufferListContent(clv)
    elseif clv.Name ==# "File"
        return ctrlspace#files#CollectFiles()
    elseif clv.Name ==# "Tab"
        return s:tabContent(clv)
    elseif clv.Name ==# "Workspace"
        return s:workspaceListContent(clv)
    elseif clv.Name ==# "Bookmark"
        return s:bookmarkListContent(clv)
    endif
endfunction

function! s:bookmarkListContent(clv) abort
    let content   = []
    let bookmarks = ctrlspace#bookmarks#Bookmarks()

    for i in range(len(bookmarks))
        let indicators = ""

        if !empty(a:clv.Data.Active) && (bookmarks[i].Directory ==# a:clv.Data.Active.Directory)
            let indicators .= s:config.Symbols.IA
        endif

        call add(content, { "index": i, "text": bookmarks[i].Name, "indicators": indicators })
    endfor

    return content
endfunction

function! s:workspaceListContent(clv) abort
    let content    = []
    let workspaces = ctrlspace#workspaces#Workspaces()
    let active     = ctrlspace#workspaces#ActiveWorkspace()

    for i in range(len(workspaces))
        let name = workspaces[i]
        let indicators = ""

        if name ==# active.Name && active.Status
            if active.Status == 2
                let indicators .= s:config.Symbols.IM
            endif

            let indicators .= s:config.Symbols.IA
        elseif name ==# a:clv.Data.LastActive
            let indicators .= s:config.Symbols.IV
        endif

        call add(content, { "index": i, "text": name, "indicators": indicators })
    endfor

    return content
endfunction

function! s:tabContent(clv) abort
    let content    = []
    let currentTab = tabpagenr()

    for i in range(1, tabpagenr("$"))
        let tabBufsNumber = ctrlspace#api#TabBuffersNumber(i)
        let title         = ctrlspace#api#TabTitle(i)

        if !s:config.UseUnicode && !empty(tabBufsNumber)
            let tabBufsNumber = ":" . tabBufsNumber
        endif

        let indicators = ""

        if ctrlspace#api#TabModified(i)
            let indicators .= s:config.Symbols.IM
        endif

        if i == currentTab
            let indicators .= s:config.Symbols.IA
        endif

        call add(content, { "index": i, "text": string(i) . tabBufsNumber . " " . title, "indicators": indicators })
    endfor

    return content
endfunction

function! s:bufferListContent(clv) abort
    let content = []

    if a:clv.Data.SubMode ==# "single"
        let buffers = map(keys(ctrlspace#buffers#Buffers(tabpagenr())), "str2nr(v:val)")
    elseif a:clv.Data.SubMode ==# "all"
        let buffers = map(keys(ctrlspace#buffers#Buffers(0)), "str2nr(v:val)")
    elseif a:clv.Data.SubMode ==# "visible"
        let buffers = filter(map(keys(ctrlspace#buffers#Buffers(tabpagenr())), "str2nr(v:val)"), "bufwinnr(v:val) != -1")
    endif

    for i in buffers
        let entry = s:bufferEntry(i)
        if !empty(entry)
            call add(content, entry)
        endif
    endfor

    return content
endfunction

function! s:bufferEntry(bufnr) abort
    let bufname  = fnamemodify(bufname(a:bufnr), ":.")
    let modified = getbufvar(a:bufnr, "&modified")
    let winnr    = bufwinnr(a:bufnr)

    if !strlen(bufname) && (modified || (winnr != -1))
        let bufname = "[" . a:bufnr . "*No Name]"
    endif

    if strlen(bufname)
        let indicators = ""

        if modified
            let indicators .= s:config.Symbols.IM
        endif

        if winnr == t:CtrlSpaceStartWindow
            let indicators .= s:config.Symbols.IA
        elseif winnr != -1
            let indicators .= s:config.Symbols.IV
        endif

        return { "index": a:bufnr, "text": bufname, "indicators": indicators }
    else
        return {}
    endif
endfunction

function! s:prepareContent(items) abort
    let sizes = ctrlspace#context#SymbolSizes()

    if s:modes.File.Enabled
        let itemSpace = 5
    elseif s:modes.Bookmark.Enabled
        let itemSpace = 5 + sizes.IAV
    else
        let itemSpace = 5 + sizes.IAV + sizes.IM
    endif

    let content  = ""
    let indices  = []

    for item in a:items
        let line = item.text

        if strwidth(line) + itemSpace > &columns
            let line = s:config.Symbols.Dots . strpart(line, strwidth(line) - &columns + itemSpace + sizes.Dots)
        endif

        if !empty(item.indicators)
            let line .= " " . item.indicators
        endif

        let content .= "  " . line . "\n"

        call add(indices, item.index)
    endfor

    return [a:items, indices, content]
endfunction
