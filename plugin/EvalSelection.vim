" EvalSelection.vim -- evaluate selected vim/ruby/... code
" @Author:      Thomas Link (samul AT web.de)
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     29-Jän-2004.
" @Last Change: 12-Feb-2005.
" @Revision:    0.9.0.184
" 
" vimscript #889
" 
" TODO:
" - find & fix compilation errors
" - fix interaction errors
"

""" Basic Functionality {{{1

if &cp || exists("s:loaded_evalselection")
    finish
endif
let s:loaded_evalselection = 9

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

if !exists("g:evalSelectionDebugLog")
    let g:evalSelectionDebugLog = 0
    " let g:evalSelectionDebugLog = 1
endif

let s:evalSelLogBufNr  = -1
let s:evalSelModes     = "xeparl"
let g:evalSelLastCmd   = ""
let g:evalSelLastCmdId = ""

" EvalSelection(id, proc, cmd, ?pre, ?post, ?newsep, ?recsep, ?postprocess)
fun! EvalSelection(id, proc, cmd, ...)
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
    silent exec a:cmd ." ". e
    redir END
    if process != ""
        exec "let @e = ". escape(process, '"\')
    endif
    if a:proc != ""
        let g:evalSelLastCmdId = a:id
        exe a:proc . ' "' . escape(strpart(@e, 1), '"\') . '"'
    endif
endf

fun! EvalSelectionSystem(txt)
    let rv=system(a:txt)
    return substitute(rv, "\n\\+$", "", "")
endf

fun! <SID>EvalSelectionLogAppend(txt, ...)
    " If we search for ^@ right away, we will get a *corrupted* viminfo-file 
    " -- at least with the version of vim, I use.
    call append(0, substitute(a:txt, "\<c-j>", "\<c-m>", "g"))
    exe "1,.s/\<c-m>/\<cr>/ge"
endf

fun! EvalSelectionLog(txt, ...)
    let currWin = winnr()
    let dbg     = a:0 >= 1 ? a:1 : 0
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

    if dbg
        let @d = txt
        exe 'norm! $"dp'
    else
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
        redraw!
    endif
    exe currWin . "wincmd w"
endf
command! -nargs=* EvalSelectionLog call EvalSelectionLog(<q-args>)

fun! EvalSelectionCmdLine(lang)
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
endf
command! -nargs=1 EvalSelectionCmdLine call EvalSelectionCmdLine(<q-args>)


fun! EvalSelectionGenerateBindingsHelper(mapmode, mapleader, lang, modes, eyank, edelete)
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
endf

fun! EvalSelectionGenerateBindings(shortcut, lang, ...)
    let modes = a:0 >= 1 ? a:1 : s:evalSelModes
    call EvalSelectionGenerateBindingsHelper("v", g:evalSelectionLeader . a:shortcut, a:lang, modes,
                \ '"ey', '"ed')
    call EvalSelectionGenerateBindingsHelper("", g:evalSelectionRegisterLeader . a:shortcut, a:lang, modes,
                \ "", "")
endf
call EvalSelectionGenerateBindingsHelper("v", g:evalSelectionAutoLeader, "{&ft}", s:evalSelModes,
                \ '"ey', '"ed')

fun! EvalSelection_vim(cmd)
    let @e = substitute("\n". @e ."\n", '\n\s*".\{-}\ze\n', "", "g")
    " let @e = substitute(@e, "^\\(\n*\\s\\+\\)\\+\\|\\(\\s\\+\n*\\)\\+$", "", "g")
    let @e = substitute(@e, "\n\\s\\+\\\\", " ", "g")
    " let @e = substitute(@e, "\n\\s\\+", "\n", "g")
    call EvalSelection("vim", a:cmd, "normal", ":", "\n", "\n:")
    " call EvalSelection("vim", a:cmd, "")
endf
if !hasmapto("EvalSelection_vim(")
    call EvalSelectionGenerateBindings("v", "vim")
endif

if has("ruby")
    if !exists("*EvalSelectionCalculate")
        fun! EvalSelectionCalculate(formula)
            exec "ruby p ". a:formula
        endf
    endif
    fun! EvalSelection_ruby(cmd)
        let @e = substitute(@e, '\_^#.*\_$', "", "g")
        call EvalSelection("ruby", a:cmd, "ruby")
    endf
    if !hasmapto("EvalSelection_ruby(")
        call EvalSelectionGenerateBindings("r", "ruby")
    endif
endif

if has("python")
    if !exists("*EvalSelectionCalculate")
        fun! EvalSelectionCalculate(formula)
            exec "python print ". a:formula
        endf
    endif
    fun! EvalSelection_python(cmd)
        call EvalSelection("python", a:cmd, "python")
    endf
    if !hasmapto("EvalSelection_python(")
        call EvalSelectionGenerateBindings("y", "python")
    endif
endif

if has("perl")
    if !exists("*EvalSelectionCalculate")
        fun! EvalSelectionCalculate(formula)
            exec "perl VIM::Msg(". a:formula .")"
        endf
    endif
    fun! EvalSelection_perl(cmd)
        call EvalSelection("perl", a:cmd, "perl")
    endf
    if !hasmapto("EvalSelection_perl(")
        call EvalSelectionGenerateBindings("p", "perl")
    endif
endif

if has("tcl")
    if !exists("*EvalSelectionCalculate")
        fun! EvalSelectionCalculate(formula)
            redir @e
            exec "tcl puts [expr ". a:formula ."]"
            redir END
            let @e = substitute(@e, '\^M$', '', '')
        endf
    endif
    fun! EvalSelection_tcl(cmd)
        call EvalSelection("tcl", a:cmd, "call", "EvalSelection_tcl_helper('", "')")
    endf
    fun! EvalSelection_tcl_helper(text)
        redir @e
        exe "tcl ". a:text
        redir END
        let @e = substitute(@e, '\^M$', '', '')
    endf
    if !hasmapto("EvalSelection_tcl(")
        call EvalSelectionGenerateBindings("t", "tcl")
    endif
endif

fun! EvalSelection_sh(cmd)
    let @e = substitute(@e, '\_^#.*\_$', "", "g")
    let @e = substitute(@e, "\\_^\\s*\\|\\s*\\_$\\|\n$", "", "g")
    let @e = substitute(@e, "\n\\+", "; ", "g")
    call EvalSelection("sh", a:cmd, "", "echo EvalSelectionSystem('", "')", "; ")
endf
if !hasmapto("EvalSelection_sh(")
    call EvalSelectionGenerateBindings("s", "sh")
endif


if !exists("*EvalSelectionCalculate")
    fun! EvalSelectionCalculate(formula)
        exec "echo ". a:formula
    endf    
endif
fun! EvalSelection_calculate(cmd)
    if @e =~ '\s*=\s*$'
        let @e = substitute(@e, '\s*=\s*$', '', '')
    endif
    call EvalSelection("calculate", a:cmd, "", "call EvalSelectionCalculate('", "')")
endf
if !hasmapto("EvalSelection_calculate(")
    call EvalSelectionGenerateBindings("e", "calculate")
endif



""" Interaction with an interpreter {{{1

if !has("ruby")
    finish
endif


""" Parameters {{{1
if !exists("g:evalSelectionRubyDir")
    if has("win32")
        let g:evalSelectionRubyDir = $VIM."/vimfiles/ruby/"
    else
        let g:evalSelectionRubyDir = "~/.vim/ruby/"
    end
endif


""" Code {{{1

command! -nargs=1 EvalSelectionQuit ruby EvalSelection.tear_down(<q-args>)

fun! EvalSelectionTalk(id, body)
    ruby EvalSelection.talk(VIM::evaluate("a:id"), VIM::evaluate("a:body"))
endf

exec "rubyfile ".g:evalSelectionRubyDir."EvalSelection.rb"


if exists("g:evalSelectionRInterpreter")
    if !exists("g:evalSelectionRCmdLine")
        if has("win32")
            let g:evalSelectionRCmdLine = 'Rterm.exe --no-save --vanilla --ess'
        else
            let g:evalSelectionRCmdLine = 'R --no-save --vanilla --ess'
        endif
    endif

    command! EvalSelectionSetupR   ruby EvalSelection.setup(EvalSelectionR)
    command! EvalSelectionQuitR    ruby EvalSelection.tear_down("R")
    command! EvalSelectionCmdLineR call EvalSelectionCmdLine("r")

    fun! EvalSelection_r(cmd)
        let @e = escape(@e, '\"')
        call EvalSelection("r", a:cmd, "", 'call EvalSelectionTalk("R", "', '")')
    endf

    if !hasmapto("EvalSelection_r(")
        call EvalSelectionGenerateBindings("R", "r")
    endif

    ruby <<EOR
    module EvalSelectionRExtra
        if VIM::evaluate("g:evalSelectionRInterpreter") == "RClean"
            def postprocess(text)
                text.sub(/^.*?\n([>+] .*?\n)*(\[\d\] )?/m, "")
            end
        else
            def postprocess(text)
                text.sub(/^.*?\n([>+] .*?\n)*/m, '')
            end
        end
    end
EOR
    if g:evalSelectionRInterpreter == 'RDCOM'
        ruby << EOR
        require 'win32ole'
        require 'tmpdir'
        class EvalSelectionR < EvalSelectionOLE
            def setup
                @iid         = "R"
                @interpreter = "rdcom"
                @filename    = File.join(Dir.tmpdir, "EvalSelection.Rout")
            end

            def ole_setup
                @ole_server = WIN32OLE.new("StatConnectorSrv.StatConnector")
                @ole_server.Init("R")
                # these have no consequence
                @ole_server.EvaluateNoReturn(%{options(chmhelp=TRUE)})
                @ole_server.EvaluateNoReturn(%{library(Rcmdr)})
                # @ole_server.EvaluateNoReturn(%{options(pager="console")})
            end

            def ole_tear_down
                begin
                    @ole_server.EvaluateNoReturn(%{q()})
                rescue
                end
                # @ole_server.Close
            end

            def ole_evaluate(text)
                #0
                # @ole_server.Evaluate(text)
                #1
                # @ole_server.Evaluate(%{capture.output(#{text})}).join("\n")
                #2
                # @ole_server.EvaluateNoReturn(%{sink("#@filename")})
                # @ole_server.EvaluateNoReturn(text)
                # @ole_server.EvaluateNoReturn(%{sink(NULL)})
                # rv = File.open(@filename) {|io| io.read}
                # rv
                #3
                # @ole_server.Evaluate(%{evalSelection.textConnection <- textConnection("evalSelection", "w")})
                # @ole_server.Evaluate(%{sink(evalSelection.textConnection)})
                # @ole_server.Evaluate(text)
                # @ole_server.Evaluate(%{sink()})
                # @ole_server.Evaluate(%{close(evalSelection.textConnection)})
                # @ole_server.Evaluate(%{cat(evalSelection, sep = "\n")})
                #4
                @ole_server.Evaluate(%{doItAndPrint("#{text.gsub(/"/, '\\\\"')}")})
            end
        end
EOR
    elseif g:evalSelectionRInterpreter =~ '^RFO'
        ruby << EOR
        require "tmpdir"
        class EvalSelectionR < EvalSelectionStdInFileOut
            include EvalSelectionRExtra
            def setup
                @iid            = "R"
                @interpreter    = VIM::evaluate("g:evalSelectionRCmdLine")
                @outfile        = File.join(Dir.tmpdir, "EvalSelection.Rout")
                @printFn        = <<EOFN
sink('#@outfile');
%{BODY};
sink();
EOFN
                @quitFn         = "q()"
            end
        end
EOR
    else
        ruby << EOR
        class EvalSelectionR < EvalSelectionInterpreter
            include EvalSelectionRExtra
            def setup
                @iid            = "R"
                @interpreter    = VIM::evaluate("g:evalSelectionRCmdLine")
                @printFn        = "%{BODY}"
                @quitFn         = "q()"
                @bannerEndRx    = "\n"
                @markFn         = "\nc(31983689, 32682634, 23682638)" 
                @recMarkRx      = "\n?\\> \\[1\\] 31983689 32682634 23682638"
                @recPromptRx    = "\n\\> "
            end
            
        end
EOR
    endif

endif


if exists("g:evalSelectionSpssInterpreter")
    command! EvalSelectionSetupSPSS   ruby EvalSelection.setup(EvalSelectionSPSS)
    command! EvalSelectionQuitSPSS    ruby EvalSelection.tear_down("SPSS")
    command! EvalSelectionCmdLineSPSS call EvalSelectionCmdLine("sps")

    fun! EvalSelection_sps(cmd)
        let @e = escape(@e, '\"')
        call EvalSelection("sps", a:cmd, "", 
                    \ 'call EvalSelectionTalk(g:evalSelectionSpssInterpreter, "', '")')
    endf

    if !hasmapto("EvalSelection_sps(")
        call EvalSelectionGenerateBindings("S", "sps")
    endif

    if !exists("g:evalSelectionSpssCmdLine")
        ruby << EOR
        require 'win32ole'
        class EvalSelectionSPSS < EvalSelectionOLE
            def setup
                @iid         = VIM::evaluate("g:evalSelectionSpssInterpreter")
                @interpreter = "ole"
            end

            def ole_setup
                @ole_server = WIN32OLE.new("spss.application")
                @output     = @ole_server.NewOutputDoc
                @output.visible = true
            end

            def ole_tear_down
                @ole_server.Quit
            end

            def ole_evaluate(text)
                @ole_server.ExecuteCommands(text, true)
            end
        end
EOR
    endif
endif


" OCaml
if exists("g:evalSelectionOCamlInterpreter")
    if !exists("g:evalSelectionOCamlCmdLine")
        let g:evalSelectionOCamlCmdLine = 'ocaml'
    endif

    fun! EvalSelection_ocaml(cmd)
        let @e = escape(@e, '\"')
        call EvalSelection("ocaml", a:cmd, "",  
                    \ 'call EvalSelectionTalk(g:evalSelectionOCamlInterpreter, "', '")')
    endf
    if !hasmapto("EvalSelection_ocaml(")
        call EvalSelectionGenerateBindings("o", "ocaml")
    endif

    command! EvalSelectionSetupOCaml   ruby EvalSelection.setup(EvalSelectionOCaml)
    command! EvalSelectionQuitOCaml    ruby EvalSelection.tear_down("OCaml")
    command! EvalSelectionCmdLineOCaml call EvalSelectionCmdLine("ocaml")

    ruby << EOR
    class EvalSelectionOCaml < EvalSelectionInterpreter
        def setup
            @iid            = VIM::evaluate("g:evalSelectionOCamlInterpreter")
            @interpreter    = VIM::evaluate("g:evalSelectionOCamlCmdLine")
            @printFn        = "%{BODY}"
            @quitFn         = "exit 0;;"
            @bannerEndRx    = "\n"
            @markFn         = "\n745287134.536216736;;"
            @recMarkRx      = "\n# - : float = 745287134\\.536216736"
            @recPromptRx    = "\n# "
        end
        
        if VIM::evaluate("g:evalSelectionOCamlInterpreter") == "OCamlClean"
            def postprocess(text)
                text.sub(/^\s*- : .+? = /, "")
            end
        end
    end
EOR
endif


if exists("g:evalSelectionSchemeInterpreter")
    if g:evalSelectionSchemeInterpreter ==? 'Gauche'
        if !exists("g:evalSelectionSchemeCmdLine")
            let s:evalSelectionSchemeCmdLine = 'gosh'
        endif
        let s:evalSelectionSchemePrint = '(display (begin %{BODY})) (display #\escape) (flush)'
    elseif g:evalSelectionSchemeInterpreter ==? 'Chicken'
        if !exists("g:evalSelectionSchemeCmdLine")
            let g:evalSelectionSchemeCmdLine = 'csi -quiet'
        endif
        let s:evalSelectionSchemePrint = 
                    \ '(display (begin %{BODY})) (display (integer->char 27)) (flush-output)'
    endif

    fun! EvalSelection_scheme(cmd)
        let @e = escape(@e, '\"')
        call EvalSelection("scheme", a:cmd, "", 
                    \ 'call EvalSelectionTalk(g:evalSelectionSchemeInterpreter, "', '")')
    endf
    
    if !hasmapto("EvalSelection_scheme(")
        call EvalSelectionGenerateBindings("c", "scheme")
    endif

    command! EvalSelectionSetupScheme   ruby EvalSelection.setup(EvalSelectionScheme)
    command! EvalSelectionQuitScheme    ruby EvalSelection.tear_down(VIM::evaluate("g:evalSelectionSchemeInterpreter"))
    command! EvalSelectionCmdLineScheme call EvalSelectionCmdLine("scheme")

    ruby << EOR
    class EvalSelectionScheme < EvalSelectionInterpreter
        def setup
            @iid            = VIM::evaluate("g:evalSelectionSchemeInterpreter")
            @interpreter    = VIM::evaluate("g:evalSelectionSchemeCmdLine")
            @printFn        = VIM::evaluate("s:evalSelectionSchemePrint")
            @quitFn         = "(exit)"
            @recEndChar     = 27
        end
    end
EOR
endif


"Lisp
if exists("g:evalSelectionLispInterpreter")
    if g:evalSelectionLispInterpreter ==? "CLisp"
        if !exists("g:evalSelectionLispCmdLine")
            let g:evalSelectionLispCmdLine = 'clisp --quiet'
        endif
    
        ruby << EOR
        class EvalSelectionLisp < EvalSelectionInterpreter
            def setup
                @iid            = VIM::evaluate("g:evalSelectionLispInterpreter")
                @interpreter    = VIM::evaluate("g:evalSelectionLispCmdLine")
                @printFn        = ":q(let ((rv (list (ignore-errors %{BODY})))) (if (= (length rv) 1) (car rv) rv))"
                @quitFn         = "(quit)"
                @recPromptRx    = "\n(Break \\d\\+ )?\\[\\d+\\]\\> "
                @recSkip        = 1
                @useNthRec      = 1
            end

            def postprocess(text)
                text.sub(/^\n/, "")
            end
        end
EOR
    endif

    fun! EvalSelection_lisp(cmd)
        let @e = escape(@e, '\"')
        call EvalSelection("lisp", a:cmd, "",  
                    \ 'call EvalSelectionTalk(g:evalSelectionLispInterpreter, "', '")')
    endf
    
    if !hasmapto("EvalSelection_lisp(")
        call EvalSelectionGenerateBindings("l", "lisp")
    endif
    
    command! EvalSelectionSetupLisp ruby EvalSelection.setup(EvalSelectionLisp)
    command! EvalSelectionQuitLisp  ruby EvalSelection.tear_down(VIM::evaluate("g:evalSelectionLispInterpreter"))
    command! EvalSelectionCmdLineScheme call EvalSelectionCmdLine("lisp")
endif


" vim: ff=unix
