" EvalSelection.vim -- evaluate selected vim/ruby/... code
" @Author:      Thomas Link (samul AT web.de)
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     29-Jän-2004.
" @Last Change: 31-Jän-2004.
" @Revision:    0.382
" 
" Requirements:
" - multvals.vim
" 

if &cp || exists("s:loaded_evalselection")
    finish
endif
let s:loaded_evalselection = 1

if !exists("g:evalSelectionLeader")
    let g:evalSelectionLeader = '<Leader>e'
endif

" if !exists("g:evalSelectionLogCommands")
    " let g:evalSelectionLogCommands = 0
" endif

let s:evalSelLogBufNr = -1
let s:evalSelLogSep = "------"

" <SID>EvalSelection(proc, cmd, setter, ?pre, ?post, ?newsep, ?recsep)
fun! <SID>EvalSelection(proc, cmd, setter, ...)
    let pre    = a:0 >= 1 ? a:1 : ""
    let post   = a:0 >= 2 ? a:2 : ""
    let newsep = a:0 >= 3 ? a:3 : "\n"
    let recsep = a:0 >= 4 ? (a:4 == ""? "\n" : a:4) : "\n"
    if a:setter != ""
        let last  = MvLastElement(@e, recsep)
        let e     = MvReplaceElementAt(@e, recsep, a:setter.last, MvNumberOfElements(@e, recsep) - 1)
    else
        let e     = @e
    endif
    let e = substitute(e, '\('. recsep .'\)\+$', "", "g")
    if newsep != ""
        let e = substitute(e, recsep, newsep, "g")
    endif
    let e = pre .e. post
    let @e = "<ERROR>"
    " echomsg "DBG: ". a:cmd ." ". e
    exe a:cmd ." ". e
    if a:proc != ""
        if @e != "<ERROR>"
            exe a:proc . ' "' . @e . '"'
        else
            throw "EvalSelection: Error"
        endif
    else
        let @e=""
    endif
endfun

fun! EvalSelectionSystem(txt)
    let rv=system(a:txt)
    return substitute(rv, "\n\\+$", "", "")
endfun

fun! EvalSelectionLog(txt)
    let currWin = winnr()
    if s:evalSelLogBufNr == -1 || bufnr(s:evalSelLogBufNr) == -1
        "Adapted from Yegappan Lakshmanan's scratch.vim
        new "*Eval Selection: Interaction Log*"
        setlocal buftype=nofile
        setlocal bufhidden=hide
        setlocal noswapfile
        setlocal buflisted
        let s:evalSelLogBufNr = bufnr("%")
    else
        let bwn = bufwinnr(s:evalSelLogBufNr)
        if bwn > -1
            exe bwn . "wincmd w"
        else
            exe "buffer ".s:evalSelLogBufNr
        endif
    endif
    call append(0, "")
    call append(0, s:evalSelLogSep)
    call append(0, "")
    call append(0, a:txt)
    call append(0, strftime("%c"))
    go 1
    exe currWin . "wincmd w"
endfun
command! -nargs=* EvalSelectionLog call EvalSelectionLog(<q-args>)

fun! <SID>GenerateBindings(shortcut, lang, ...)
    let x = a:0 >= 1 ? a:1 : "xeparl"
    if x =~# "x"
        exe 'vnoremap '. g:evalSelectionLeader . a:shortcut ."x"
                    \ .' "ey:call EvalSelection'. a:lang .'("", "")<CR>'
    endif
    if x =~# "e"
        exe 'vnoremap '. g:evalSelectionLeader . a:shortcut ."e"
                    \ .' "ey:silent call EvalSelection'. a:lang .'("", "let @e=")<CR>'
    endif
    if x =~# "p"
        exe 'vnoremap '. g:evalSelectionLeader . a:shortcut ."p"
                    \ .' "ey:call EvalSelection'. a:lang .'("echomsg", "let @e=")<CR>'
    endif
    if x =~# "a"
        exe 'vnoremap '. g:evalSelectionLeader . a:shortcut ."a"
                    \ .' "ey`>:silent call EvalSelection'. a:lang ."('exe \"norm! a\".', 'let @e=')<CR>"
    endif
    if x =~# "r"
        exe 'vnoremap '. g:evalSelectionLeader . a:shortcut ."r"
                    \.' "ed:silent call EvalSelection'. a:lang ."('exe \"norm! i\".', 'let @e=')<CR>"
    endif
    if x =~# "l"
        exe 'vnoremap '. g:evalSelectionLeader . a:shortcut ."l"
                    \.' "ey:silent call EvalSelection'. a:lang ."('EvalSelectionLog', 'let @e=')<CR>"
    endif
endfun

fun! EvalSelectionVim(cmd, setter)
    let @e = substitute(@e, "^\\(\n*\\s\\+\\)\\+\\|\\(\\s\\+\n*\\)\\+$", "", "g")
    let @e = substitute(@e, "\n\\s\\+", "\n", "g")
    call <SID>EvalSelection(a:cmd, "normal", a:setter, ":", "\n", "\n:")
endfun
if !hasmapto("EvalSelectionVim")
    call <SID>GenerateBindings("v", "Vim")
endif

fun! EvalSelectionRuby(cmd, setter)
    call <SID>EvalSelection(a:cmd, "ruby", "", 'VIM.command("'.a:setter.'\"#{(proc {', '}).call}\"")')
endfun
if !hasmapto("EvalSelectionRuby")
    call <SID>GenerateBindings("r", "Ruby")
endif

fun! EvalSelectionBc(cmd, setter)
    " adapted from bccalc.vim
    let @e = substitute(@e, "\n", "", "g")
    let @e = escape(@e, '*();&><|')
    call <SID>EvalSelection(a:cmd, "", "", a:setter."EvalSelectionSystem('echo ", " \| bc -l')")
endfun
if !hasmapto("EvalSelectionBc")
    call <SID>GenerateBindings("b", "Bc")
endif

fun! EvalSelectionShell(cmd, setter)
    let @e = substitute(@e, "\\_^\\s*\\|\\s*\\_$\\|\n$", "", "g")
    let @e = substitute(@e, "\n\\+", "; ", "g")
    call <SID>EvalSelection(a:cmd, "", "", a:setter."EvalSelectionSystem('", "')")
endfun
if !hasmapto("EvalSelectionShell")
    call <SID>GenerateBindings("s", "Shell")
endif


finish

Description:

Evaluate the code selected in a visual region. This is useful for performing
small text manipulation tasks or calculations that aren't worth the trouble of
creating a new file or switching to a different program, but which are too big
for being handled in the command line.

Some aspects were inspired by Scott Urban's bccalc.vim (vimscript #219).

The key bindings follow this scheme:
    <Leader>e{LANGUAGE}{MODE} 

LANGUAGE being one of:
    v ... Vim
    r ... Ruby (requires compiled-in ruby support)
    b ... Bc
    s ... Shell (using system())

MODE being one of:
    x ... just evaluate
    e ... save the result in the e-register
    p ... echo/print the result
    a ... append the result to visual region
    r ... replace visual region with the result
    l ... insert the result in a temporary interaction log

Caveats:
- When in selection mode, remember to switch to normal/visual mode first
(<c-g>) -- not insert/visual.
- The e-register is overwritten.


Tests: Switch to normal mode, mark some code as a visual region, and type the
appropriate shortcuts.

VIM:
1. For MODE being one of "epar", the last line has to be an expression or
   a function, not a command!
    fun! TwoTimes(a)
        return a:a * 2
    endfun
    TwoTimes(2)

2.
    let a = 2
    a * 2

3. When invoked via <Leader>evx, the last line has to be a command. There is
   no return value, you could reuse.
    fun! TwoTimes(a)
        call inputdialog(a:a ." * 2 =", a:a * 2)
    endfun
    call TwoTimes(2)

4.
    1 + 1
    
RUBY:
1.
    def TwoTimes(a)
        return a*2
    end
    TwoTimes(2)

2.
    b="B"
    "a#{b}c"

    
BC:
Examples from the bc manual:
1.
    scale=10; 4*a(1)
2.
    define f (x) {
        if (x <= 1) return (1);
        return (f(x-1) * x);
    }
    f(10)
    

BASH:
1.
    export x=/tmp; ls $x

2.
    export x=/tmp
    ls $x

