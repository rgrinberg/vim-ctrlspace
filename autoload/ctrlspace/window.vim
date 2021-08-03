let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

function! ctrlspace#window#MaxHeight() abort
    return luaeval('require("ctrlspace").drawer.max_height()')
endfunction

function! ctrlspace#window#run(...) abort
    let default = {
                \ "insert": v:false,
                \ "input": "" ,
                \ "mode": "Buffer",
                \ }

    if a:0 > 0
        let args = a:1
    else
        let args = {}
    endif

    let options = extend(default, args)

    let mode = toupper(options.mode[0]) . strpart(options.mode, 1)
    let modes = ctrlspace#modes#Modes()
    let mode = modes[mode]

    call mode.Enable()

    call s:modes.Search.SetData("Letters", split(options.input, '\zs'))
    call ctrlspace#files#ClearAll()

    if options.insert
        call modes.Search.Enable()
    else
        call modes.Search.Disable()
    endif

    call ctrlspace#window#revive()
endfunction

function! s:insertContent() abort
    call luaeval('require("ctrlspace").drawer.insert_content()')
endfunction

" should be called when the contents of the window changes
function! ctrlspace#window#refresh() abort
    call luaeval('require("ctrlspace").drawer.refresh()')
endfunction

" this is necessary to restore the user's original configuration when
" ctrlspace is turned off
function! s:saveTabConfig() abort
    let t:CtrlSpaceStartWindow = winnr()
    let t:CtrlSpaceWinrestcmd  = winrestcmd()
    let t:CtrlSpaceActivebuf   = bufnr("")
endfunction

" using this function still closes the buffer. because bufhidden=delete for
" the ctrlspace buffer
function! ctrlspace#window#hide() abort
    silent! exe "noautocmd winc c"
endfunction

function! ctrlspace#window#show() abort
    call luaeval('require("ctrlspace").drawer.show()')
endfunction

function! ctrlspace#window#kill() abort
    call ctrlspace#window#Kill(1)
endfunction

function! ctrlspace#window#revive() abort
    call ctrlspace#window#restore()
endfunction

" restore the ctrlspace window and buffer to the previous invocation
function! ctrlspace#window#restore() abort
    let pbuf = ctrlspace#context#PluginBuffer()
    " silent! exe "pclose"
    if bufexists(pbuf)
        throw "ctrlspace buffer already exists"
    endif
    call ctrlspace#window#show()
    call s:setUpBuffer()
    call s:insertContent()
endfunction

function! ctrlspace#window#Toggle(internal) abort
    if !a:internal
        call s:resetWindow()
    endif

    " if we get called and the list is open --> close it
    let pbuf = ctrlspace#context#PluginBuffer()

    if bufexists(pbuf)
        if bufwinnr(pbuf) == -1
            call ctrlspace#window#Kill(0)
            if !a:internal
                call s:saveTabConfig()
            endif
        else
            call ctrlspace#window#Kill(1)
            return
        endif
    elseif !a:internal
        " make sure zoom window is closed
        silent! exe "pclose"
        call s:saveTabConfig()
    endif

    " create the buffer first & set it up
    call ctrlspace#window#show()

    call s:setUpBuffer()
    call s:insertContent()
endfunction

function! ctrlspace#window#GoToStartWindow() abort
    silent! exe t:CtrlSpaceStartWindow . "wincmd w"

    if winrestcmd() != t:CtrlSpaceWinrestcmd
        silent! exe t:CtrlSpaceWinrestcmd

        if winrestcmd() != t:CtrlSpaceWinrestcmd
            wincmd =
        endif
    endif
endfunction

function! ctrlspace#window#Kill(final) abort
    " added workaround for strange Vim behavior when, when kill starts with some delay
    " (in a wrong buffer). This happens in some Nop modes (in a File List view).
    if (exists("s:killingNow") && s:killingNow) || &ft != "ctrlspace"
        return
    endif

    let s:killingNow = 1

    if exists("b:updatetimeSave")
        silent! exe "set updatetime=" . b:updatetimeSave
    endif

    if exists("b:timeoutlenSave")
        silent! exe "set timeoutlen=" . b:timeoutlenSave
    endif

    if exists("b:mouseSave")
        silent! exe "set mouse=" . b:mouseSave
    endif

    " shellslash support for win32
    if exists("b:nosslSave") && b:nosslSave
        set nossl
    endif

    bwipeout

    if a:final
        call ctrlspace#util#HandleVimSettings("stop")

        if s:modes.Search.Data.Restored
            call ctrlspace#search#AppendToSearchHistory()
        endif

        call ctrlspace#window#GoToStartWindow()

        set guicursor-=n:block-CtrlSpaceSelected-blinkon0
    endif

    unlet s:killingNow
endfunction

function! ctrlspace#window#QuitVim() abort
    if !s:config.SaveWorkspaceOnExit
        let aw = ctrlspace#workspaces#ActiveWorkspace()

        if aw.Status == 2 && !ctrlspace#ui#Confirmed("Current workspace ('" . aw.Name . "') not saved. Proceed anyway?")
            return
        endif
    endif

    if !ctrlspace#ui#ProceedIfModified()
        return
    endif

    call ctrlspace#window#Kill(1)
    qa!
endfunction

function! ctrlspace#window#MoveSelectionBar(where) abort
    if b:size < 1
        return
    endif

    let newpos = 0

    if !exists("b:lastline")
        let b:lastline = 0
    endif

    " the mouse was pressed: remember which line
    " and go back to the original location for now
    if a:where == "mouse"
        let newpos = line(".")
        call s:goto(b:lastline)
    endif


    " go where the user want's us to go
    if a:where == "up"
        call s:goto(line(".") - 1)
    elseif a:where == "down"
        call s:goto(line(".") + 1)
    elseif a:where == "mouse"
        call s:goto(newpos)
    elseif a:where == "pgup"
        let newpos = line(".") - winheight(0)
        if newpos < 1
            let newpos = 1
        endif
        call s:goto(newpos)
    elseif a:where == "pgdown"
        let newpos = line(".") + winheight(0)
        if newpos > line("$")
            let newpos = line("$")
        endif
        call s:goto(newpos)
    elseif a:where == "half_pgup"
        let newpos = line(".") - winheight(0) / 2
        if newpos < 1
            let newpos = 1
        endif
        call s:goto(newpos)
    elseif a:where == "half_pgdown"
        let newpos = line(".") + winheight(0) / 2
        if newpos > line("$")
            let newpos = line("$")
        endif
        call s:goto(newpos)
    else
        call s:goto(a:where)
    endif


    " remember this line, in case the mouse is clicked
    " (which automatically moves the cursor there)
    let b:lastline = line(".")
endfunction

function! ctrlspace#window#MoveCursor(where) abort
    if a:where == "up"
        call s:goto(line(".") - 1)
    elseif a:where == "down"
        call s:goto(line(".") + 1)
    elseif a:where == "mouse"
        call s:goto(line("."))
    elseif a:where == "pgup"
        let newpos = line(".") - winheight(0)
        if newpos < 1
            let newpos = 1
        endif
        call s:goto(newpos)
    elseif a:where == "pgdown"
        let newpos = line(".") + winheight(0)
        if newpos > line("$")
            let newpos = line("$")
        endif
        call s:goto(newpos)
    elseif a:where == "half_pgup"
        let newpos = line(".") - winheight(0) / 2
        if newpos < 1
            let newpos = 1
        endif
        call s:goto(newpos)
    elseif a:where == "half_pgdown"
        let newpos = line(".") + winheight(0) / 2
        if newpos > line("$")
            let newpos = line("$")
        endif
        call s:goto(newpos)
    else
        call s:goto(a:where)
    endif
endfunction

function! ctrlspace#window#SelectedIndex() abort
    let pbuf = ctrlspace#context#PluginBuffer()
    if !bufexists(pbuf)
        throw "ctrlspace plugin buffer does not exist"
    endif
    let items = getbufvar(pbuf, "items")
    " idiotic hackery to make sure this function works correctly from all
    " buffers
    if bufnr() == pbuf
        let idx = line(".") - 1
    elseif
        let selected = getbufinfo(pbuf)[0].lnum
    end
    let selected = items[idx]
    return str2nr(selected.index)
endfunction

function! ctrlspace#window#GoToWindow() abort
    let nr = ctrlspace#window#SelectedIndex()

    if bufwinnr(nr) == -1
        return 0
    endif

    call ctrlspace#window#kill()
    silent! exe bufwinnr(nr) . "wincmd w"
    return 1
endfunction

" tries to set the cursor to a line of the buffer list
function! s:goto(line) abort
    if b:size < 1
        return
    endif

    if a:line < 1
        call s:goto(b:size - a:line)
    elseif a:line > b:size
        call s:goto(a:line - b:size)
    else
        call cursor(a:line, 1)
    endif
endfunction

function! s:resetWindow() abort
    call s:modes.Help.Disable()
    call s:modes.Nop.Disable()
    call s:modes.Search.Disable()
    call s:modes.NextTab.Disable()

    call s:modes.Buffer.Enable()
    call s:modes.Buffer.SetData("SubMode", "single")

    call s:modes.Search.SetData("NewSearchPerformed", 0)
    call s:modes.Search.SetData("Restored", 0)
    call s:modes.Search.SetData("Letters", [])
    call s:modes.Search.SetData("HistoryIndex", -1)

    call s:modes.Workspace.SetData("LastBrowsed", 0)

    call ctrlspace#roots#SetCurrentProjectRoot(ctrlspace#roots#FindProjectRoot())
    call s:modes.Bookmark.SetData("Active", ctrlspace#bookmarks#FindActiveBookmark())

    call s:modes.Search.RemoveData("LastSearchedDirectory")

    if ctrlspace#roots#LastProjectRoot() != ctrlspace#roots#CurrentProjectRoot()
        call ctrlspace#files#ClearAll()
        call ctrlspace#roots#SetLastProjectRoot(ctrlspace#roots#CurrentProjectRoot())
        call ctrlspace#workspaces#SetWorkspaceNames()
    endif

    set guicursor+=n:block-CtrlSpaceSelected-blinkon0

    call ctrlspace#util#HandleVimSettings("start")
endfunction

function! s:setUpBuffer() abort
    setlocal noswapfile
    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal nowrap
    setlocal nonumber
    setlocal norelativenumber
    setlocal nocursorcolumn
    setlocal nocursorline
    setlocal nospell
    setlocal nolist
    setlocal cc=
    setlocal filetype=ctrlspace
    setlocal foldmethod=manual

    let root = ctrlspace#roots#CurrentProjectRoot()

    if !empty(root)
        silent! exe "lcd " . fnameescape(root)
    endif

    if &timeout
        let b:timeoutlenSave = &timeoutlen
        set timeoutlen=10
    endif

    let b:updatetimeSave = &updatetime

    " shellslash support for win32
    if has("win32") && !&ssl
        let b:nosslSave = 1
        set ssl
    endif

    augroup CtrlSpaceUpdateSearch
        au!
        au CursorHold <buffer> call ctrlspace#search#UpdateSearchResults()
    augroup END

    augroup CtrlSpaceLeave
        au!
        au BufLeave <buffer> call ctrlspace#window#Kill(1)
    augroup END

    if !s:config.UseMouseAndArrowsInTerm && !has("gui_running")
        " Block unnecessary escape sequences!
        noremap <silent><buffer><esc>[ :call ctrlspace#keys#MarkKeyEscSequence()<CR>
        let b:mouseSave = &mouse
        set mouse=
    endif

    for k in ctrlspace#keys#KeyNames()
        let key = strlen(k) > 1 ? ("<" . k . ">") : k

        if k == '"'
            let k = '\' . k
        endif

        silent! exe "nnoremap <silent><buffer> " . key . " :call ctrlspace#keys#Keypressed(\"" . k . "\")<CR>"
    endfor
endfunction

function! ctrlspace#window#setActiveLine() abort
    if !empty(s:modes.Search.Data.Letters) && s:modes.Search.Data.NewSearchPerformed
        call ctrlspace#window#MoveSelectionBar(line("$"))

        if !s:modes.Search.Enabled
            call s:modes.Search.SetData("NewSearchPerformed", 0)
        endif
    else
        let clv = ctrlspace#modes#CurrentListView()

        if clv.Name ==# "Workspace"
            if clv.Data.LastBrowsed
                let activeLine = clv.Data.LastBrowsed
            else
                let activeLine = 1
                let aw         = ctrlspace#workspaces#ActiveWorkspace()

                if aw.Status
                    let currWsp = aw.Name
                elseif !empty(clv.Data.LastActive)
                    let currWsp = clv.Data.LastActive
                else
                    let currWsp = ""
                endif

                if !empty(currWsp)
                    let workspaces = ctrlspace#workspaces#Workspaces()

                    for i in range(b:size)
                        if currWsp ==# workspaces[b:items[i].index]
                            let activeLine = i + 1
                            break
                        endif
                    endfor
                endif
            endif
        elseif clv.Name ==# "Tab"
            let activeLine = tabpagenr()
        elseif clv.Name ==# "Bookmark"
            let activeLine = 1

            if !empty(clv.Data.Active)
                let bookmarks = ctrlspace#bookmarks#Bookmarks()

                for i in range(b:size)
                    if clv.Data.Active.Name ==# bookmarks[b:items[i].index].Name
                        let activeLine = i + 1
                        break
                    endif
                endfor
            endif
        elseif clv.Name ==# "File"
            let activeLine = line("$")
        else
            let activeLine = 0
            let maxCounter = 0
            let lastLine   = 0

            for i in range(b:size)
                if b:items[i].index == t:CtrlSpaceActivebuf
                    let activeLine = i + 1
                    break
                endif

                let currentJumpCounter = ctrlspace#util#GetbufvarWithDefault(b:items[i].index, "CtrlSpaceJumpCounter", 0)

                if currentJumpCounter > maxCounter
                    let maxCounter = currentJumpCounter
                    let lastLine = i + 1
                endif
            endfor

            if !activeLine
                let activeLine = (lastLine > 0) ? lastLine : b:size - 1
            endif
        endif

        call ctrlspace#window#MoveSelectionBar(activeLine)
    endif
endfunction
