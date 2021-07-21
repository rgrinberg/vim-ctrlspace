let s:config = ctrlspace#context#Configuration()
let s:modes  = ctrlspace#modes#Modes()

function! s:CompleteTypeOption(optlead, cmdline, cursorpos)
    return filter(['buffer', 'workspace', 'tab', 'bookmark', 'file'],
                \ 'a:optlead == "" ? 1 : (v:val =~# a:optlead)')
endfunction

function! CompleteCtrlSpace(arglead, cmdline, cursorpos)
    return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

function! s:run(options) abort
    let args = {}

    let positional_args = a:options["__unknown_args__"]
    if !empty(positional_args)
        let mode = positional_args[0]
        let args["mode"] = toupper(mode[0]) . strpart(mode, 1)
    endif

    if has_key(a:options, "input")
        let args["input"] = a:options.input
    endif

    if has_key(a:options, "insert")
        let args["insert"] = a:options.insert
    endif

    call ctrlspace#window#run(args)
endfunction

function! ctrlspace#init#Init() abort
    augroup CtrlSpaceInit
        autocmd!
    augroup END

    if s:config.UseTabline
        set tabline=%!ctrlspace#api#Tabline()

        if has('gui_running') && (&guioptions =~# 'e')
            set guitablabel=%{ctrlspace#api#Guitablabel()}

            " Fix MacVim issues:
            " http://stackoverflow.com/questions/11595301/controlling-tab-names-in-vim
            if has('gui_macvim')
                autocmd CtrlSpaceInit BufWinEnter * set guitablabel=%{ctrlspace#api#Guitablabel()}
            endif
        endif
    endif

    let s:V = vital#ctrlspace#new()
    let s:O = s:V.import('OptionParser')
    let s:parser = s:O.new()
    call s:parser.on('--input=VALUE', 'initial input')
    call s:parser.on('--insert', 'open in insert(search) mode')


    let s:parser.unknown_options_completion = function("s:CompleteTypeOption")

    command! -nargs=* -count -bang -complete=customlist,CompleteCtrlSpace
                \ CtrlSpaceNew :call s:run(s:parser.parse(<q-args>, <count>, <q-bang>))

    command! -nargs=* -range CtrlSpace :call ctrlspace#window#run({"mode" : "buffer"}) | :call feedkeys(<q-args>)
    command! -nargs=0 -range CtrlSpaceGoUp :call ctrlspace#window#GoToBufferListPosition("up")
    command! -nargs=0 -range CtrlSpaceGoDown :call ctrlspace#window#GoToBufferListPosition("down")
    command! -nargs=0 -range CtrlSpaceTabLabel :call ctrlspace#tabs#NewTabLabel(0)
    command! -nargs=0 -range CtrlSpaceClearTabLabel :call ctrlspace#tabs#RemoveTabLabel(0)
    command! -nargs=* -range CtrlSpaceSaveWorkspace :call ctrlspace#workspaces#SaveWorkspace(<q-args>)
    command! -nargs=0 -range CtrlSpaceNewWorkspace :call ctrlspace#workspaces#NewWorkspace()
    command! -nargs=* -range -bang CtrlSpaceLoadWorkspace :call ctrlspace#workspaces#LoadWorkspace(<bang>0, <q-args>)
    command! -nargs=* -range -complete=dir CtrlSpaceAddProjectRoot :call ctrlspace#roots#AddProjectRoot(<q-args>)
    command! -nargs=* -range -complete=dir CtrlSpaceRemoveProjectRoot :call ctrlspace#roots#RemoveProjectRoot(<q-args>)

    hi def link CtrlSpaceNormal   PMenu
    hi def link CtrlSpaceSelected PMenuSel
    hi def link CtrlSpaceSearch   Search
    hi def link CtrlSpaceStatus   StatusLine

    if s:config.SetDefaultMapping
        call ctrlspace#keys#SetDefaultMapping(s:config.DefaultMappingKey, ":CtrlSpace<CR>")
    endif

    call ctrlspace#db#latest()
    call ctrlspace#keys#Init()

    if argc() > 1
        let curaltBuff=bufnr('#')
        let currBuff=bufnr('%')

        silent argdo call ctrlspace#buffers#AddBuffer()
        
        if curaltBuff >= 0 
            execute 'buffer ' . curaltBuff
        endif
        execute 'buffer ' . currBuff
    endif

    autocmd CtrlSpaceInit BufEnter * call ctrlspace#buffers#AddBuffer()
    autocmd CtrlSpaceInit VimEnter * call ctrlspace#buffers#Init()
    autocmd CtrlSpaceInit TabEnter * let t:CtrlSpaceTabJumpCounter = ctrlspace#jumps#IncrementJumpCounter()

    if s:config.SaveWorkspaceOnExit
        autocmd CtrlSpaceInit VimLeavePre * if ctrlspace#workspaces#ActiveWorkspace().Status | call ctrlspace#workspaces#SaveWorkspace("") | endif
    endif

    if s:config.LoadLastWorkspaceOnStart
        autocmd CtrlSpaceInit VimEnter * nested if (argc() == 0) && !empty(ctrlspace#roots#FindProjectRoot()) | call ctrlspace#workspaces#LoadWorkspace(0, "") | endif
    endif
endfunction
