scriptencoding utf-8

let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

function! ctrlspace#api#Buffers(tabnr) abort
    let F = luaeval('require("ctrlspace").buffers.api.in_tab')
    return F(a:tabnr)
endfunction

function! ctrlspace#api#TabModified(tabnr) abort
    let F = luaeval('require("ctrlspace").tabs.modified')
    return F(a:tabnr)
endfunction

function! ctrlspace#api#Statusline() abort
    hi def link User1 CtrlSpaceStatus

    let statusline = "%1*" . s:config.Symbols.CS . "    " . ctrlspace#api#StatuslineModeSegment("    ")

    if !&showtabline
        let statusline .= " %=%1* %<" . ctrlspace#api#StatuslineTabSegment()
    endif

    return statusline
endfunction

function! ctrlspace#api#StatuslineTabSegment() abort
    let currentTab = tabpagenr()
    let bufsNumber = ctrlspace#api#TabBuffersNumber(currentTab)
    let title      = ctrlspace#api#TabTitle(currentTab)

    if !s:config.UseUnicode && !empty(bufsNumber)
        let bufsNumber = ":" . bufsNumber
    end

    let tabinfo = string(currentTab) . bufsNumber . " "

    if ctrlspace#api#TabModified(currentTab)
        let tabinfo .= "+ "
    endif

    let tabinfo .= title

    return tabinfo
endfunction

function! s:createStatusTabline() abort
    let current = tabpagenr()
    let line    = ""

    for i in range(1, tabpagenr("$"))
        let line .= (current == i ? s:config.Symbols.CTab : s:config.Symbols.Tabs)
    endfor

    return line
endfunction

function! ctrlspace#api#StatuslineModeSegment(...) abort
    let statuslineElements = []

    let clv = ctrlspace#modes#CurrentListView()

    if clv.Name ==# "Workspace"
        if clv.Data.SubMode ==# "load"
            call add(statuslineElements, s:config.Symbols.WLoad)
        elseif clv.Data.SubMode ==# "save"
            call add(statuslineElements, s:config.Symbols.WSave)
        endif
    elseif clv.Name ==# "Tab"
        call add(statuslineElements, s:createStatusTabline())
    elseif clv.Name ==# "Bookmark"
        call add(statuslineElements, s:config.Symbols.BM)
    else
        if clv.Name ==# "File"
            let symbol = s:config.Symbols.File
        elseif clv.Name ==# "Buffer"
            if clv.Data.SubMode ==? "visible"
                let symbol = s:config.Symbols.Vis
            elseif clv.Data.SubMode ==? "single"
                let symbol = s:config.Symbols.Sin
            elseif clv.Data.SubMode ==? "all"
                let symbol = s:config.Symbols.All
            endif
        endif

        if s:modes.NextTab.Enabled
            let symbol .= " " . s:config.Symbols.NTM . ctrlspace#api#TabBuffersNumber(tabpagenr() + 1)
        endif

        call add(statuslineElements, symbol)
    endif

    if !empty(s:modes.Search.Data.Letters) || s:modes.Search.Enabled
        let searchElement = s:config.Symbols.SLeft . join(s:modes.Search.Data.Letters, "")

        if s:modes.Search.Enabled
            let searchElement .= "_"
        endif

        let searchElement .= s:config.Symbols.SRight

        call add(statuslineElements, searchElement)
    endif

    if s:modes.Help.Enabled
        call add(statuslineElements, s:config.Symbols.Help)
    endif

    let separator = (a:0 > 0) ? a:1 : "  "

    return join(statuslineElements, separator)
endfunction

function! ctrlspace#api#TabBuffersNumber(tabnr) abort
    let Bn = luaeval('require("ctrlspace").tabs.buffers_number')
    return Bn(a:tabnr)
endfunction

function! ctrlspace#api#TabTitle(tabnr) abort
    let winnr   = tabpagewinnr(a:tabnr)
    let buflist = tabpagebuflist(a:tabnr)
    let bufnr   = buflist[winnr - 1]
    let bufname = bufname(bufnr)
    let title   = ctrlspace#util#Gettabvar(a:tabnr, "CtrlSpaceLabel")

    if !empty(title)
        return title
    endif

    if getbufvar(bufnr, "&ft") == "ctrlspace"
        let bufnr = winbufnr(t:CtrlSpaceStartWindow)
        let bufname = bufname(bufnr)
    endif

    if empty(bufname)
        let title = "[" . bufnr . "*No Name]"
    else
        let title = "[" . substitute(fnamemodify(bufname, ':t'), '%', '%%', 'g') . "]"
    endif
    return title
endfunction

function! ctrlspace#api#Guitablabel() abort
    let title      = ctrlspace#api#TabTitle(v:lnum)
    let bufsNumber = ctrlspace#api#TabBuffersNumber(v:lnum)

    if !s:config.UseUnicode && !empty(bufsNumber)
        let bufsNumber = ":" . bufsNumber
    end

    let label = '' . v:lnum . bufsNumber . ' '

    if ctrlspace#api#TabModified(v:lnum)
        let label .= '+ '
    endif

    let label .= title . ' '

    return label
endfunction

function! ctrlspace#api#Tabline() abort
    let lastTab    = tabpagenr("$")
    let currentTab = tabpagenr()
    let tabline    = ''

    for t in range(1, lastTab)
        let bufsNumber = ctrlspace#api#TabBuffersNumber(t)
        let title      = ctrlspace#api#TabTitle(t)

        if !s:config.UseUnicode && !empty(bufsNumber)
            let bufsNumber = ":" . bufsNumber
        end

        let tabline .= '%' . t . 'T'
        let tabline .= (t == currentTab ? '%#TabLineSel#' : '%#TabLine#')
        let tabline .= ' ' . t . bufsNumber . ' '

        if ctrlspace#api#TabModified(t)
            let tabline .= '+ '
        endif

        let tabline .= title . ' '
    endfor

    let tabline .= '%#TabLineFill#%T'

    if lastTab > 1
        let tabline .= '%='
        let tabline .= '%#TabLine#%999XX'
    endif

    return tabline
endfunction
