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
    let s:V = vital#ctrlspace#new()
    let s:O = s:V.import('OptionParser')
    let s:parser = s:O.new()
    call s:parser.on('--input=VALUE', 'initial input')
    call s:parser.on('--insert', 'open in insert(search) mode')


    let s:parser.unknown_options_completion = function("s:CompleteTypeOption")

    command! -nargs=* -count -bang -complete=customlist,CompleteCtrlSpace
                \ CtrlSpace :call s:run(s:parser.parse(<q-args>, <count>, <q-bang>))
    command! -nargs=* -range CtrlSpaceSaveWorkspace :call ctrlspace#workspaces#SaveWorkspace(<q-args>)
    command! -nargs=0 -range CtrlSpaceNewWorkspace :call ctrlspace#workspaces#NewWorkspace()
    command! -nargs=* -range -bang CtrlSpaceLoadWorkspace :call ctrlspace#workspaces#LoadWorkspace(<bang>0, <q-args>)
    command! -nargs=* -range -complete=dir CtrlSpaceAddProjectRoot :lua require('ctrlspace').roots.add(<q-args>)
    command! -nargs=* -range -complete=dir CtrlSpaceRemoveProjectRoot :lua require('ctrlspace').roots.remove(<q-args>)

    hi def link CtrlSpaceNormal   PMenu
    hi def link CtrlSpaceSelected PMenuSel
    hi def link CtrlSpaceSearch   Search
    hi def link CtrlSpaceStatus   StatusLine

    if s:config.SetDefaultMapping
        call ctrlspace#keys#SetDefaultMapping(s:config.DefaultMappingKey, ":CtrlSpace<CR>")
    endif

    call luaeval('require("ctrlspace").db.latest()')
    call ctrlspace#keys#Init()

    if argc() > 1
        let curaltBuff=bufnr('#')
        let currBuff=bufnr('%')

        silent argdo call luaeval('require("ctrlspace").buffers.add_current()')
        
        if curaltBuff >= 0 
            execute 'buffer ' . curaltBuff
        endif
        execute 'buffer ' . currBuff
    endif

    augroup CtrlSpaceInit
        autocmd!
        autocmd BufEnter * call luaeval('require("ctrlspace").buffers.add_current()')
        autocmd BufUnload * let F = luaeval('require("ctrlspace").buffers.remove') | call F(expand('<abuf>'))
        autocmd VimEnter * call ctrlspace#buffers#Init()
        autocmd TabEnter * let t:CtrlSpaceTabJumpCounter = ctrlspace#jumps#IncrementJumpCounter()

        autocmd CmdlineChanged @ call luaeval('require("ctrlspace").search.on_cmdline_change()')
        autocmd CmdlineEnter @ call luaeval('require("ctrlspace").search.on_cmd_enter()')

        if s:config.SaveWorkspaceOnExit
            autocmd VimLeavePre * if ctrlspace#workspaces#ActiveWorkspace().Status | call ctrlspace#workspaces#SaveWorkspace("") | endif
        endif

        if s:config.LoadLastWorkspaceOnStart
            autocmd VimEnter * nested if (argc() == 0) && !empty(ctrlspace#roots#FindProjectRoot()) | call ctrlspace#workspaces#SetWorkspaceNames() | call ctrlspace#workspaces#LoadWorkspace(0, "") | endif
        endif

        if s:config.UseTabline
            set tabline=%!ctrlspace#api#Tabline()

            if has('gui_running') && (&guioptions =~# 'e')
                set guitablabel=%{ctrlspace#api#Guitablabel()}

                " Fix MacVim issues:
                " http://stackoverflow.com/questions/11595301/controlling-tab-names-in-vim
                if has('gui_macvim')
                    autocmd BufWinEnter * set guitablabel=%{ctrlspace#api#Guitablabel()}
                endif
            endif
        endif
    augroup END
endfunction
