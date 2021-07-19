let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

function! ctrlspace#window#MaxHeight() abort
    let maxFromConfig = s:config.MaxHeight

    if maxFromConfig
        return maxFromConfig
    else
        return &lines / 3
    endif
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
    let mode = ctrlspace#modes#Modes()[mode]

    call mode.Enable()

    call s:modes.Search.SetData("Letters", split(options.input, '\zs'))

    if options.insert
        call ctrlspace#search#SwitchSearchMode(1)
    endif

    call ctrlspace#files#ClearAll()
    call ctrlspace#window#Toggle(0)
endfunction

function! s:insertContent() abort
    silent! exe "resize" s:config.Height
    call s:setUpBuffer()

    if s:modes.Help.Enabled
        call ctrlspace#help#DisplayHelp(s:filler())
        call ctrlspace#util#SetStatusline()
        return
    endif

    let [b:items, b:indices, b:text] = ctrlspace#engine#Content()
    let b:size = len(b:items)

    " set up window height
    if b:size > s:config.Height
        let maxHeight = ctrlspace#window#MaxHeight()
        silent! exe "resize " . (b:size < maxHeight ? b:size : maxHeight)
    endif

    silent! exe "set updatetime=" . s:config.SearchTiming

    call s:displayContent()
    call ctrlspace#util#SetStatusline()

    call s:setActiveLine()

    normal! zb
endfunction

function! ctrlspace#window#refresh() abort
    setlocal modifiable
    call nvim_buf_set_lines(0, 0, line("$"), 0, [])
    setlocal nomodifiable
    call s:insertContent()
endfunction

" this is necessary to restore the user's original configuration when
" ctrlspace is turned off
function! s:saveTabConfig() abort
    let t:CtrlSpaceStartWindow = winnr()
    let t:CtrlSpaceWinrestcmd  = winrestcmd()
    let t:CtrlSpaceActivebuf   = bufnr("")
endfunction

function! ctrlspace#window#hide() abort
    winc c
endfunction

function! ctrlspace#window#restore() abort
    call s:saveTabConfig()
    silent! exe "noautocmd botright pedit CtrlSpace"
    silent! exe "noautocmd wincmd P"
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

    if s:modes.Zoom.Enabled
        let t:CtrlSpaceActivebuf = bufnr("")
    endif

    " create the buffer first & set it up
    call ctrlspace#window#restore()

    " zoom start window in Zoom Mode
    if s:modes.Zoom.Enabled
        silent! exe t:CtrlSpaceStartWindow . "wincmd w"
        vert resize | resize
        silent! exe "noautocmd wincmd P"
    endif

    call s:insertContent()
endfunction

function! ctrlspace#window#GoToBufferListPosition(direction) abort
    let bufferList    = ctrlspace#api#BufferList(tabpagenr())
    let currentBuffer = bufnr("%")
    let currentIndex  = -1
    let bufferListLen = len(bufferList)

    for index in range(bufferListLen)
        if bufferList[index]["index"] == currentBuffer
            let currentIndex = index
            break
        endif
    endfor

    if currentIndex == -1
        return
    endif

    if a:direction == "down"
        let targetIndex = currentIndex + 1

        if targetIndex == bufferListLen
            let targetIndex = 0
        endif
    else
        let targetIndex = currentIndex - 1

        if targetIndex < 0
            let targetIndex = bufferListLen - 1
        endif
    endif

    silent! exe ":b " . bufferList[targetIndex]["index"]
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

        if s:modes.Zoom.Enabled
            exec ":b " . s:modes.Zoom.Data.Buffer
            call s:modes.Zoom.SetData("Buffer", 0)
            call s:modes.Zoom.Disable()
            call ctrlspace#buffers#DeleteForeignBuffers(1)
            call ctrlspace#buffers#DeleteHiddenNonameBuffers(1)
        endif

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
    let indices = getbufvar(pbuf, "indices")
    return indices[line(".") - 1]
endfunction

function! ctrlspace#window#GoToWindow() abort
    let nr = ctrlspace#window#SelectedIndex()

    if bufwinnr(nr) == -1
        return 0
    endif

    call ctrlspace#window#Kill(1)
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
    call s:modes.Workspace.SetData("SubMode", "load")

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
    if exists('+relativenumber')
        setlocal norelativenumber
    endif
    setlocal nocursorcolumn
    setlocal nocursorline
    setlocal nospell
    setlocal nolist
    setlocal cc=
    setlocal filetype=ctrlspace
    setlocal foldmethod=manual

    call ctrlspace#context#SetPluginBuffer(bufnr("%"))

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

function! s:setActiveLine() abort
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
                        if currWsp ==# workspaces[b:indices[i]]
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
                    if clv.Data.Active.Name ==# bookmarks[b:indices[i]].Name
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
                if b:indices[i] == t:CtrlSpaceActivebuf
                    let activeLine = i + 1
                    break
                endif

                let currentJumpCounter = ctrlspace#util#GetbufvarWithDefault(b:indices[i], "CtrlSpaceJumpCounter", 0)

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

function! s:filler() abort
    " generate a variable to fill the buffer afterwards
    " (we need this for "full window" color :)
    if !exists("s:filler['" . &columns . "']")
        let fill = "\n"
        let i    = 0

        while i < &columns
            let i += 1
            let fill = ' ' . fill
        endwhile

        if !exists("s:filler")
            let s:filler = {}
        endif

        let s:filler[string(&columns)] = fill
    endif

    return s:filler[string(&columns)]
endfunction

function! s:displayContent() abort
    setlocal modifiable

    if b:size > 0
        silent! put! =b:text

        let lineNumber = 0
        for item in b:items
            if has_key(item, "positions")
                for highlightLetter in item.positions
                    call nvim_buf_add_highlight(0, -1, "CtrlSpaceSearch", lineNumber, highlightLetter + 1, highlightLetter + 2)
                endfor
            endif
            let lineNumber = lineNumber + 1
        endfor

        normal! GkJ
        call s:modes.Nop.Disable()
    else
        let emptyListMessage = "  List empty"

        let sizes = ctrlspace#context#SymbolSizes()

        if &columns < (strwidth(emptyListMessage) + 2)
            let emptyListMessage = strpart(emptyListMessage, 0, &columns - 2 - sizes.Dots) . s:config.Symbols.Dots
        endif

        silent! put! =emptyListMessage
        normal! GkJ

        normal! 0

        call s:modes.Nop.Enable()
    endif

    setlocal nomodifiable
endfunction
