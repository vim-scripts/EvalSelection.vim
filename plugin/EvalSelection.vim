" EvalSelection.vim -- evaluate selected vim/ruby/... code
" @Author:      Thomas Link (samul AT web.de)
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     29-Jän-2004.
" @Last Change: 03-Mai-2004.
" @Revision:    0.7.50
" 
" TODO:
" - find & fix compilation errors
"

""" Basic Functionality {{{1

if &cp || exists("s:loaded_evalselection")
    finish
endif
let s:loaded_evalselection = 1

" Parameters {{{2
if !exists("g:evalSelectionLeader")
    let g:evalSelectionLeader = '<Leader>e'
endif

if !exists("g:evalSelectionRegisterLeader")
    let g:evalSelectionRegisterLeader = '<Leader>E'
endif

if !exists("g:evalSelectionAutoLeader")
    let g:evalSelectionAutoLeader = '<Leader>x'
endif

if !exists("g:evalSelectionLogCommands")
    " let g:evalSelectionLogCommands = 1
    let g:evalSelectionLogCommands = 0
endif

if !exists("g:evalSelectionSeparatedLog")
    " let g:evalSelectionSeparatedLog = 0
    let g:evalSelectionSeparatedLog = 1
endif

let s:evalSelLogBufNr  = -1
let s:evalSelModes     = "xeparl"
let g:evalSelLastCmd   = ""
let g:evalSelLastCmdId = ""

" EvalSelection(id, proc, cmd, ?pre, ?post, ?newsep, ?recsep, ?postprocess)
fun! EvalSelection(id, proc, cmd, ...) "{{{2
    let pre     = a:0 >= 1 ? a:1 : ""
    let post    = a:0 >= 2 ? a:2 : ""
    let newsep  = a:0 >= 3 ? a:3 : "\n"
    let recsep  = a:0 >= 4 ? (a:4 == ""? "\n" : a:4) : "\n"
    let process = a:0 >= 5 ? a:4 : ""
    let e = substitute(@e, '\('. recsep .'\)\+$', "", "g")
    if newsep != "" && newsep != recsep
        let e = substitute(e, recsep, newsep, "g")
    endif
    if exists("g:evalSelectionPRE".a:id)
        exe "let pre = g:evalSelectionPRE".a:id.".'".newsep.pre."'"
    endif
    if exists("g:evalSelectionPOST".a:id)
        exe "let post = g:evalSelectionPOST".a:id.".'".newsep.post."'"
    endif
    let e = pre .e. post
    " echomsg "DBG: ". a:cmd ." ". e
    redir @e
    " exe a:cmd ." ". e
    silent exe a:cmd ." ". e
    redir END
    if process != ""
        exec "let @e = ". escape(process, '"\')
    endif
    if a:proc != ""
        let g:evalSelLastCmdId = a:id
        exe a:proc . ' "' . escape(strpart(@e, 1), '"\') . '"'
    endif
endfun

fun! EvalSelectionSystem(txt) "{{{2
    let rv=system(a:txt)
    return substitute(rv, "\n\\+$", "", "")
endfun

fun! <SID>EvalSelectionLogAppend(txt, ...)  "{{{2
    " If we search for ^@ right away, we will get a *corrupted* viminfo-file 
    " -- at least with the version of vim, I use.
    call append(0, substitute(a:txt, "\<c-j>", "\<c-m>", "g"))
    exe "1,.s/\<c-m>/\<cr>/ge"
endfun

fun! EvalSelectionLog(txt) "{{{2
    let currWin = winnr()
    exe "let txt = ".a:txt
    if g:evalSelectionSeparatedLog
        let logID = g:evalSelLastCmdId
    else
        let logID = ""
    endif
    "Adapted from Yegappan Lakshmanan's scratch.vim
    if !exists("s:evalSelLog{logID}_BufNr") || 
                \ s:evalSelLog{logID}_BufNr == -1 || 
                \ bufnr(s:evalSelLog{logID}_BufNr) == -1
        if logID == ""
            split _EvalSelectionLog_
        else
            echomsg "split _EvalSelection_".logID."_"
            exec "split _EvalSelection_".logID."_"
        endif
        let s:evalSelLog{logID}_BufNr = bufnr("%")
    else
        let bwn = bufwinnr(s:evalSelLog{logID}_BufNr)
        if bwn > -1
            exe bwn . "wincmd w"
        else
            exe "sbuffer ".s:evalSelLog{logID}_BufNr
        endif
    endif

    setlocal buftype=nofile
    " setlocal bufhidden=delete
    setlocal bufhidden=hide
    setlocal noswapfile
    " setlocal buflisted
    call <SID>EvalSelectionLogAppend("")
    go 1
    if g:evalSelectionLogCommands && g:evalSelLastCmd != ""
        if MvNumberOfElements(g:evalSelLastCmd, "\n") == 1 && MvNumberOfElements(txt, "\n") == 1
            call <SID>EvalSelectionLogAppend(g:evalSelLastCmd ." -> ". txt, 1)
        else
            call <SID>EvalSelectionLogAppend(txt, 1)
            call <SID>EvalSelectionLogAppend(" -> ")
            call <SID>EvalSelectionLogAppend(g:evalSelLastCmd, 1)
        endif
    else
        call <SID>EvalSelectionLogAppend(txt, 1)
    endif
    let t = "-----".strftime("%c")."-----"
    if !g:evalSelectionSeparatedLog
        let t = t. g:evalSelLastCmdId
    endif
    call <SID>EvalSelectionLogAppend(t)
    go 1
    let g:evalSelLastCmd   = ""
    let g:evalSelLastCmdId = ""
    exe currWin . "wincmd w"
    redraw!
endfun
command! -nargs=* EvalSelectionLog call EvalSelectionLog(<q-args>)

fun! EvalSelectionCmdLine(lang) "{{{2
    let lang = tolower(a:lang)
    while 1
        let @e = input(a:lang." (exit with ^D+Enter):\n")
        if @e == ""
            break
        else
            call EvalSelection_{lang}("EvalSelectionLog")
        endif
    endwh
    echo
endfun
command! -nargs=1 EvalSelectionCmdLine call EvalSelectionCmdLine(<q-args>)


fun! EvalSelectionGenerateBindingsHelper(mapmode, mapleader, lang, modes, eyank, edelete) "{{{2
    let es   = "call EvalSelection_". a:lang
    let eslc = ':let g:evalSelLastCmd = substitute(@e, "\n$", "", "")<CR>'
    if a:modes =~# "x"
        exe a:mapmode .'noremap <silent> '. a:mapleader ."x ".
                    \ a:eyank . eslc.':'.es.'("")<CR>'
    endif
    if a:modes =~# "e"
        exe a:mapmode .'noremap <silent> '. a:mapleader ."e ".
                    \ a:eyank . eslc.':silent '.es.'("")<CR>'
    endif
    if a:modes =~# "p"
        exe a:mapmode .'noremap <silent> '. a:mapleader ."p ".
                    \ a:eyank . eslc.':'.es.'("echomsg")<CR>'
    endif
    if a:modes =~# "a"
        exe a:mapmode .'noremap <silent> '. a:mapleader ."a ".
                    \ a:eyank .' `>'.eslc.':silent '.es. "('exe \"norm! a\".')<CR>"
    endif
    if a:modes =~# "r"
        exe a:mapmode .'noremap <silent> '. a:mapleader ."r ".
                    \ a:edelete .eslc.':silent '.es. "('exe \"norm! i\".')<CR>"
    endif
    if a:modes =~# "l"
        exe a:mapmode .'noremap <silent> '. a:mapleader ."l ".
                    \ a:eyank . eslc.':silent '.es. "('EvalSelectionLog')<CR>"
    endif
endfun

fun! EvalSelectionGenerateBindings(shortcut, lang, ...) "{{{2
    let modes = a:0 >= 1 ? a:1 : s:evalSelModes
    call EvalSelectionGenerateBindingsHelper("v", g:evalSelectionLeader . a:shortcut, a:lang, modes,
                \ '"ey', '"ed')
    call EvalSelectionGenerateBindingsHelper("", g:evalSelectionRegisterLeader . a:shortcut, a:lang, modes,
                \ "", "")
endfun
call EvalSelectionGenerateBindingsHelper("v", g:evalSelectionAutoLeader, "{&ft}", s:evalSelModes,
                \ '"ey', '"ed')

fun! EvalSelection_vim(cmd) "{{{2
    let @e = substitute(@e, '\_^".*\_$', "", "g")
    let @e = substitute(@e, "^\\(\n*\\s\\+\\)\\+\\|\\(\\s\\+\n*\\)\\+$", "", "g")
    let @e = substitute(@e, "\n\\s\\+\\\\", " ", "g")
    let @e = substitute(@e, "\n\\s\\+", "\n", "g")
    call EvalSelection("vim", a:cmd, "normal", ":", "\n", "\n:")
endfun
if !hasmapto("EvalSelection_vim(")
    call EvalSelectionGenerateBindings("v", "vim")
endif

if has("ruby")
    fun! EvalSelection_ruby(cmd) "{{{2
        let @e = substitute(@e, '\_^#.*\_$', "", "g")
        call EvalSelection("ruby", a:cmd, "ruby")
    endfun
    if !hasmapto("EvalSelection_ruby(")
        call EvalSelectionGenerateBindings("r", "ruby")
    endif
endif

if has("python")
    fun! EvalSelection_python(cmd) "{{{2
        call EvalSelection("python", a:cmd, "python")
    endfun
    if !hasmapto("EvalSelection_python(")
        call EvalSelectionGenerateBindings("y", "python")
    endif
endif

if has("perl")
    fun! EvalSelection_perl(cmd) "{{{2
        call EvalSelection("perl", a:cmd, "perl")
    endfun
    if !hasmapto("EvalSelection_perl(")
        call EvalSelectionGenerateBindings("p", "perl")
    endif
endif

if has("tcl")
    fun! EvalSelection_tcl(cmd) "{{{2
        call EvalSelection("tcl", a:cmd, "call", "EvalSelection_tcl_helper('", "')")
    endfun
    fun! EvalSelection_tcl_helper(text) "{{{2
        redir @e
        exe "tcl ". a:text
        redir END
        let @e = substitute(@e, '\^M$', '', '')
    endfun
    if !hasmapto("EvalSelection_tcl(")
        call EvalSelectionGenerateBindings("t", "tcl")
    endif
endif

fun! EvalSelection_sh(cmd) "{{{2
    let @e = substitute(@e, '\_^#.*\_$', "", "g")
    let @e = substitute(@e, "\\_^\\s*\\|\\s*\\_$\\|\n$", "", "g")
    let @e = substitute(@e, "\n\\+", "; ", "g")
    call EvalSelection("sh", a:cmd, "", "echo EvalSelectionSystem('", "')", "; ")
endfun
if !hasmapto("EvalSelection_sh(")
    call EvalSelectionGenerateBindings("s", "sh")
endif

" vim: ff=unix
