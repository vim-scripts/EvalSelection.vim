" EvalSelection.vim -- evaluate selected vim/ruby/... code
" @Author:      Thomas Link (samul AT web.de)
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     29-Jän-2004.
" @Last Change: 09-Mär-2004.
" @Revision:    0.6.613
" 
" Requirements:
" - multvals.vim
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

" <SID>EvalSelection(id, proc, cmd, ?pre, ?post, ?newsep, ?recsep)
fun! <SID>EvalSelection(id, proc, cmd, ...) "{{{2
    let pre     = a:0 >= 1 ? a:1 : ""
    let post    = a:0 >= 2 ? a:2 : ""
    let newsep  = a:0 >= 3 ? a:3 : "\n"
    let recsep  = a:0 >= 4 ? (a:4 == ""? "\n" : a:4) : "\n"
    let e = substitute(@e, '\('. recsep .'\)\+$', "", "g")
    if newsep != ""
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
    silent exe a:cmd ." ". e
    redir END
    if a:proc != ""
        let g:evalSelLastCmdId = a:id
        exe a:proc . ' "' . escape(strpart(@e, 1), '"') . '"'
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
    let t = strftime("%c")
    "exe "norm ". (winwidth(0) - &foldcolumn - strlen(t) - 3) ."I-\<esc>a ".t
    call <SID>EvalSelectionLogAppend("-----".t."-----". g:evalSelLastCmdId)
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
        let @e = input(a:lang."> ")
        if @e == ""
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
    call <SID>EvalSelection("vim", a:cmd, "normal", ":", "\n", "\n:")
endfun
if !hasmapto("EvalSelection_vim(")
    call EvalSelectionGenerateBindings("v", "vim")
endif

if has("ruby")
    fun! EvalSelection_ruby(cmd) "{{{2
        let @e = substitute(@e, '\_^#.*\_$', "", "g")
        call <SID>EvalSelection("ruby", a:cmd, "ruby")
    endfun
    if !hasmapto("EvalSelection_ruby(")
        call EvalSelectionGenerateBindings("r", "ruby")
    endif
endif

fun! EvalSelection_sh(cmd) "{{{2
    let @e = substitute(@e, '\_^#.*\_$', "", "g")
    let @e = substitute(@e, "\\_^\\s*\\|\\s*\\_$\\|\n$", "", "g")
    let @e = substitute(@e, "\n\\+", "; ", "g")
    call <SID>EvalSelection("sh", a:cmd, "", "echo EvalSelectionSystem('", "')", "; ")
endfun
if !hasmapto("EvalSelection_sh(")
    call EvalSelectionGenerateBindings("s", "sh")
endif



""" Interaction with an interpreter {{{1
if has("ruby")
" Global Data {{{2
ruby $EvalSelectionTalkDef = Hash.new
ruby $EvalSelectionInterpreter = Struct.new("EvalSelectionInterpreter", 
            \ :io, :print, :quit, :recMark, :recMarkRx, :recMarkSpecial, :nthRec)

fun! EvalSelectionSetupTalk(id, interpreter, printFn, quitFn, ...) "{{{2
    " id             ... The ID for a specific interpreter
    " interpreter    ... The command-line to start the interpreter (take care that it 
    "                    doesn't show any banner or so
    " printFn        ... The function that prints %{BODY}'s result and a record marker (=ESCAPE)
    " quitFn         ... The function that quits the interpreter
    " OPTIONAL:
    " recMark        ... A character end of record mark (default=ESCAPE)
    " recMarkRx      ... A ruby patter marking the end of record
    " recMarkSpecial ... A special string that marks the end of command output
    " ignNRecs       ... Ignore the N first records (for overly self-aware interpreters)
    " useNthRec      ... Use every Nth record

    ruby << EOR
    id = VIM::evaluate("a:id")
    if ! $EvalSelectionTalkDef[id]
        interpreter = VIM::evaluate("a:interpreter")
        io          = IO.popen(interpreter, File::RDWR)
        io.sync     = true
        pr          = VIM::evaluate("a:printFn")
        qu          = VIM::evaluate("a:quitFn")
        rm          = VIM::evaluate("a:0 >= 1 ? a:1 : 27").to_i
        rmRx        = VIM::evaluate("a:0 >= 2 ? a:2 : ''")
        rmSpcl      = VIM::evaluate("a:0 >= 3 ? a:3 : ''")
        ign         = VIM::evaluate("a:0 >= 4 ? a:4 : 0").to_i
        nthRec      = VIM::evaluate("a:0 >= 5 ? a:5 : ''").to_i
        df          = $EvalSelectionInterpreter.new(io, pr, qu, rm, rmRx, rmSpcl, nthRec)
        $EvalSelectionTalkDef[id] = df
        if ign > 0
            EvalSelectionListen(df, ign - 1)
        end
    end
EOR
endfun

fun! EvalSelectionSayQuit(id) "{{{2
    ruby << EOR
    id = VIM::evaluate("a:id")
    df = $EvalSelectionTalkDef[id]
    if df
        io = df[:io]
        qu = df[:quit]
        io.print(qu)
        io.close
        $EvalSelectionTalkDef[id] = nil
    end
EOR
endfun

command! -nargs=1 EvalSelectionSayQuit call EvalSelectionSayQuit(<q-args>)


ruby << EOR
def EvalSelectionSay(df, body) #{{{2
    io = df[:io]
    #+++ use look back rx
    pr = df[:print].gsub(/(^|[^%])%\{BODY\}/, "\\1#{body}")
    pr.gsub!(/%%/, "%")
    #p "DBG: #{pr}"
    io.puts(pr)
end

def EvalSelectionListen(df, ignore=-1) #{{{2
    if ignore >= 0
        ign = ignore
        recMarkSc = ""
    else ignore < 0
        ign = df[:nthRec]
        recMarkSc = df[:recMarkSpecial]
    end
    io        = df[:io]
    recMark   = df[:recMark]
    recMarkRx = df[:recMarkRx]
    markRx    = /#{recMarkRx + recMarkSc}$/
    # VIM::command(%Q{echomsg "DBG: recMark:#{recMark} recMarkRx:#{recMarkRx}"})
    # This doesn't work reliable. Alternatives would be:
    # - io.nonblock
    # - timeout
    # - subprocesses
    # - a more mature expect package
    # - ...
    while ign >= 0
        ign -= 1
        l = ""
        while !io.eof
            c = io.getc()
            if recMark >= 0 && c == recMark
                break
            else
                l << c
                if recMarkRx != "''" && l =~ markRx
                    l.sub!(markRx, "")
                    break
                end
            end
            # p "DBG: #{l}"
        end
    end
    return l
end
EOR

fun! EvalSelectionTalk(id, body) "{{{2
    " uses @e
    ruby << EOR
    id  = VIM::evaluate("a:id")
    bd  = VIM::evaluate("a:body")
    if !$EvalSelectionTalkDef[id]
        VIM::command(%Q{throw "EvalSelectionTalk: Set up interaction with #{id} first!"})
    else
        df = $EvalSelectionTalkDef[id]
        EvalSelectionSay(df, bd)
        VIM::command(%Q{let g:evalSelLastCmd   = "#{bd}"})
        VIM::command(%Q{let g:evalSelLastCmdId = "#{id}"})
        p EvalSelectionListen(df)
    end
EOR
endfun

fun! EvalSelectionLogTalk(id, body) "{{{2
    call EvalSelectionTalk(a:id, a:body)
    call EvalSelectectionLog(@e)
endfun


" Example Setups:

" Scheme
if exists("g:evalSelectionSchemeInterpreter")
    if g:evalSelectionSchemeInterpreter == 'Gauche' "{{{2
        if !exists("g:evalSelectionSchemeCmdLine")
            let s:evalSelectionSchemeCmdLine = 'gosh'
        endif
        if !exists("g:evalSelectionSchemePrint")
            let g:evalSelectionSchemePrint = '(display %{BODY}) (display #\escape) (flush)'
        endif
        if !exists("g:evalSelectionSchemeQuit")
            let g:evalSelectionSchemeQuit = '(exit)'
        endif
        command! EvalSelectionSetupScheme call EvalSelectionSetupTalk(g:evalSelectionSchemeInterpreter, 
                    \ g:evalSelectionSchemeCmdLine, 
                    \ g:evalSelectionSchemePrint,
                    \ g:evalSelectionSchemeQuit,
                    \ 27, "\ngosh> ")
    elseif g:evalSelectionSchemeInterpreter == 'Chicken' "{{{2
        if !exists("g:evalSelectionSchemeCmdLine")
            let g:evalSelectionSchemeCmdLine = 'csi -quiet'
        endif
        if !exists("g:evalSelectionSchemePrint")
            let g:evalSelectionSchemePrint = 
                        \ '(display %{BODY}) (display (integer->char 27)) (flush-output)'
        endif
        if !exists("g:evalSelectionSchemeQuit")
            let g:evalSelectionSchemeQuit = '(exit)'
        endif
        command! EvalSelectionSetupScheme call EvalSelectionSetupTalk(g:evalSelectionSchemeInterpreter, 
                    \ g:evalSelectionSchemeCmdLine, 
                    \ g:evalSelectionSchemePrint,
                    \ g:evalSelectionSchemeQuit)
    endif

    fun! EvalSelection_scheme(cmd) "{{{2
        call <SID>EvalSelection("scheme", a:cmd, "", 
                    \ "call EvalSelectionTalk(g:evalSelectionSchemeInterpreter, '", "')")
    endfun
    if !hasmapto("EvalSelection_scheme(") "{{{2
        call EvalSelectionGenerateBindings("c", "scheme")
    endif
endif


"Lisp
if exists("g:evalSelectionLispInterpreter") && g:evalSelectionLispInterpreter == "Lisp" "{{{2
    if !exists("g:evalSelectionLispCmdLine")
        let g:evalSelectionLispCmdLine = 'clisp --quiet'
    endif
    if !exists("g:evalSelectionLispPrint")
        "try to reset to the toplevel, in case we are in a debug loop
        let g:evalSelectionLispPrint = ":q\n%{BODY}"
    endif
    if !exists("g:evalSelectionLispQuit")
        let g:evalSelectionLispQuit = '(quit)'
    endif

    command! EvalSelectionSetupLisp call EvalSelectionSetupTalk(g:evalSelectionLispInterpreter, 
                \ g:evalSelectionLispCmdLine, 
                \ g:evalSelectionLispPrint,
                \ g:evalSelectionLispQuit,
                \ -1, "\n(Break \\d\\+ )?\\[\\d+\\]\\> ", "", 1, 1)
    
    fun! EvalSelection_lisp(cmd) "{{{2
        call <SID>EvalSelection("lisp", a:cmd, "",  
                    \ "call EvalSelectionTalk(g:evalSelectionLispInterpreter, '", "')")
    endfun
    if !hasmapto("EvalSelection_lisp(") "{{{2
        call EvalSelectionGenerateBindings("l", "lisp")
    endif
endif


" OCaml
if exists("g:evalSelectionOCamlInterpreter") && g:evalSelectionOCamlInterpreter == "OCaml" "{{{2
    if !exists("g:evalSelectionOCamlCmdLine")
        let g:evalSelectionOCamlCmdLine = 'ocaml'
    endif
    if !exists("g:evalSelectionOCamlPrint")
        " let g:evalSelectionOCamlPrint = "%{BODY};; flush_all ();;"
        let g:evalSelectionOCamlPrint = '%{BODY};;'
    endif
    if !exists("g:evalSelectionOCamlQuit")
        let g:evalSelectionOCamlQuit = 'exit 0;;'
    endif

    " the ocaml toplevel doesn't print escape characters, which is why we rely 
    " on end pattern matching
    command! EvalSelectionSetupOCaml call EvalSelectionSetupTalk(g:evalSelectionOCamlInterpreter, 
                \ g:evalSelectionOCamlCmdLine, 
                \ g:evalSelectionOCamlPrint,
                \ g:evalSelectionOCamlQuit,
                \ -1, "\n# ", "", 1)
    
    fun! EvalSelection_ocaml(cmd) "{{{2
        call <SID>EvalSelection("ocaml", a:cmd, "",  
                    \ "call EvalSelectionTalk(g:evalSelectionOCamlInterpreter, '", "')")
    endfun
    if !hasmapto("EvalSelection_ocaml(") "{{{2
        call EvalSelectionGenerateBindings("o", "ocaml")
    endif
endif

if exists("g:evalSelectionRInterpreter") && g:evalSelectionRInterpreter == "R" "{{{2
    if !exists("g:evalSelectionRCmdLine")
        if has("win32")
            let g:evalSelectionRCmdLine = 'Rterm.exe'
        else
            let g:evalSelectionRCmdLine = 'R'
        endif
    endif
    if !exists("g:evalSelectionRPrint")
        let g:evalSelectionRPrint = "%{BODY}"
    endif
    if !exists("g:evalSelectionRQuit")
        let g:evalSelectionRQuit = "q()"
    endif

    command! EvalSelectionSetupR call EvalSelectionSetupTalk(g:evalSelectionRInterpreter, 
                \ g:evalSelectionRCmdLine, 
                \ g:evalSelectionRPrint,
                \ g:evalSelectionRQuit,
                \ -1, "\n> ", "", 1)
    
    fun! EvalSelection_r(cmd) "{{{2
        let @e = substitute(@e, "\n\\s*", " ", "g")
        call <SID>EvalSelection("r", a:cmd, "",  
                    \ "call EvalSelectionTalk(g:evalSelectionRInterpreter, '", "')")
    endfun
    if !hasmapto("EvalSelection_r(") "{{{2
        call EvalSelectionGenerateBindings("R", "r")
    endif
endif



endif "has("ruby")


finish "{{{1

* Description

Evaluate source code selected in a visual region. This is useful for 
performing small text manipulation tasks or calculations that aren't worth the 
trouble of creating a new file or switching to a different program, but which 
are too big for being handled in the command line.

The key bindings follow this scheme:
    <Leader>e{LANGUAGE}{MODE} :: work on the visual region
    <Leader>E{LANGUAGE}{MODE} :: work on the contents of the e-register
    <Leader>x{MODE}           :: work on the visual region (LANGUAGE = 'filetype')

NOTE: In the third form LANGUAGE is replaced with &filetype, which requires 
the function EvalSelection_{&filetype}(cmd) to be defined. a:cmd is a editor 
command that processes the result that is put in the e-register.
    
LANGUAGE being one of:
    v :: vim
    r :: ruby (requires compiled-in ruby support)
    s :: sh (using system())

*experimental feature*
If ruby-support is compiled in, the following  languages are available too 
(but see |EvalSelection-Interaction| below):
    
    c :: scheme (only if g:evalSelectionSchemeInterpreter is "Gauche" or 
         "Chicken")
    l :: lisp (the default interpreter is "clisp"; only if 
         g:evalSelectionLispInterpreter is "Lisp")
    o :: ocaml (only if g:evalSelectionOCamlInterpreter is "OCaml")
    R :: R (only if g:evalSelectionRInterpreter is "R")

In order to enable the interaction with an interpreter, you usually have to 
set the variable g:evalSelection{LANG}Interpreter to the appropriate value and make 
g:evalSelection{LANG}CmdLine point to the right location.

MODE being one of:
    x :: just evaluate
    e :: save the result in the e-register
    p :: echo/print the result
    a :: append the result to visual region
    r :: replace visual region with the result
    l :: insert the result in a temporary interaction log

Hardly tested! Don't expect this to work without some fine tuning.

Define g:evalSelectionLeader, g:evalSelectionRegisterLeader, and 
g:evalSelectionAutoLeader for using different mapping prefixes.


** Commands

    EvalSelectionCmdLine LANG :: Simulate a command line for LANG (quit with     
    empty input); this is a one way "interaction"; no user input is possible; 
    all output is redirected to the log

    EvalSelectionSetup{LANG}  :: Set up interaction with external interpreter 
    (but see below)

    EvalSelectionSayQuit LANG :: Quit interaction with an external interpreter


** Variables

    - g:evalSelectionLogCommands (default: 0)  
    If true, also log the command -- otherwise log the results only.

    - g:evalSelectionSeparatedLog (default: 1)
    Keep logs separated for each language/interpreter.
   
    - g:evalSelectionPRE{LANGUAGE}, g:evalSelectionPOST{LANGUAGE}
    *EXPERIMENTAL*, don't expect it to work in all cases
    Define a standard prolog/epilog for LANGUAGE.
    

** Caveats

    - When in selection mode, remember to switch to visual mode first (<c-g>).
    - The e-register is overwritten.


    												*EvalSelection-Interaction*
* Interaction With An External Interpreter

Don't expect this to work reliable and without some finetuning.

Before you can interact with an interpreter you have to call 
EvalSelectionSetupTalk with the following arguments:

     id          :: The ID for a specific interpreter
     interpreter :: The command-line to start the interpreter
     printFn     :: The function that prints %{BODY}'s result and a record marker (=ESCAPE)
     quitFn      :: The function that quits the interpreter
     
Optional Arguments:

     recMark     :: A character end of record mark (default=ESCAPE)
     recMarkRx   :: A ruby patter marking the end of record
     ignNRecs    :: Ignore the N first records (for overly self-aware interpreters)
     useNthRec   :: Use every Nth record

For scheme, lisp, and ocaml the commands EvalSelectionSetup{LANGUAGE} are 
predefined.

You can exit the interpreter by calling the command or function 
EvalSelectionSayQuit, which takes the interpreter ID (currently Gauche, 
Chicken, or OCaml) as argument.

Under ruby =< 1.8.1@Windows, there is no io.nonblock and subprocesses don't 
work -- correct me if I'm wrong. We thus have to rely on the following two 
methods for determining when the interpreter's output has finished:

 1. Send an record-end-character (default=ESCAPE). This works well unless you 
    want to actually output this particular character or unless the interpreter 
    has slight problems printing such a character.

 2. Match the output with some regular expression. This means that regular 
    output mustn't match this particular expression. Anyway, by adding a 
    command, which prints some weird string after having processed the 
    argument, to g:evalSelection{LANGUAGE}Print, one can minimize risks.

If you know of a better solution that is easy to implement, please let me 
know.


* Tests

Switch to normal mode, mark some code as a visual region, and type the
appropriate shortcuts.


** Vim

 1. fun! TwoTimes(a)
        return a:a * 2
    endfun
    echo TwoTimes(2)

 2. let a = 2
    echo a * 2

 3. fun! TwoTimes(a)
        call inputdialog(a:a ." * 2 =", a:a * 2)
    endfun
    call TwoTimes(2)

 4. echo 1 + 1
 
    
** Ruby

 1. def TwoTimes(a)
        return a*2
    end
    p TwoTimes(2)

 2. b="B"
    p "a#{b}c"

 3. with: let g:evalSelectionPREruby = "factor=10"
    p factor * 20
    
    
** Bash

 1. export x=/tmp; ls $x 
 2. export x=/tmp
    ls $x


** OCaml

 1. 1 + 1
 2. let a = 1 in
    a + 2

    
** Scheme

 1. (+ 1 1)
 2. (let ((a 2))
      (* a 2))


** Lisp

 1. (+ 1 1)
 2. (let ((a 2))
      (* a 2))

** R

 1. 1 + 1

 2. for (x in 25:30) 
      print(x * 2)

 3. x = c(1,2,3,4);
    x = factor(x);
    x
 !!! multiple commands have to be separated by a semicolon !!!


* Version History

 0.6 :: Interaction with interpreters; separated logs; use of redir; 
   EvalSelectionCmdLine (CLI like interaction)
 0.5 :: Initial Release

 vim: fdl=1
