" EvalSelectionEtc.vim
" @Author:      Thomas Link (samul AT web.de)
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     03-Mai-2004.
" @Last Change: 03-Mai-2004.
" @Revision:    0.1.14
" 
" Description:
" This is an add-on for EvalSelection.vim that requires +ruby support to be 
" compiled in. If this isn't the case, remove this file.
" 

if &cp || !has("ruby") || exists("s:loaded_EvalSelectionRuby")
    finish
endif
let s:loaded_EvalSelectionRuby = 1


""" Parameters {{{1
if !exists("g:evalSelectionRubyDir")
    if has("win32")
        let g:evalSelectionRubyDir = $VIM."/vimfiles/ruby/"
    else
        let g:evalSelectionRubyDir = "~/.vim/ruby/"
    end
endif


""" Interaction with an interpreter {{{1

command! -nargs=1 EvalSelectionSayQuit ruby EvalSelectionSayQuit(<q-args>)
    
fun! EvalSelectionTalk(id, body) "{{{2
    ruby EvalSelectionTalk(VIM::evaluate("a:id"), VIM::evaluate("a:body"))
endfun

exec "rubyfile ".g:evalSelectionRubyDir."EvalSelection.rb"
ruby include EvalSelection


if exists("g:evalSelectionRInterpreter") "{{{2
    if !exists("g:evalSelectionRCmdLine")
        if has("win32")
            let g:evalSelectionRCmdLine = 'Rterm.exe --no-save'
        else
            let g:evalSelectionRCmdLine = 'R --no-save'
        endif
    endif

    command! EvalSelectionSetupR ruby EvalSelectionSetup(EvalSelectionR)

    fun! EvalSelection_r(cmd) "{{{2
        call EvalSelection("r", a:cmd, "", 
                    \ "call EvalSelectionTalk(g:evalSelectionRInterpreter, '", "')")
    endfun

    if !hasmapto("EvalSelection_r(") "{{{2
        call EvalSelectionGenerateBindings("R", "r")
    endif

    ruby << EOR
    class EvalSelectionR < EvalSelectionInterpreter
        def setup
            @iid            = VIM::evaluate("g:evalSelectionRInterpreter")
            @interpreter    = VIM::evaluate("g:evalSelectionRCmdLine")
            @printFn        = "%{BODY}"
            @quitFn         = "q()"
            @recPromptRx    = "\n\\> "
            @markFn         = "\n"     # just press enter
            @recMarkRx      = "\n\\> "
            @bannerEndRx    = "\n"
            if VIM::evaluate("g:evalSelectionRInterpreter") == "RClean"
                @postProcess    = proc {|s| s.sub(/^.*\n(\[\d\]) /m, "")}
            else
                @postProcess    = proc {|s| s.sub(/^.*\n(\[\d\]) /m, '\1')}
            end
        end
    end
EOR
endif


" OCaml
if exists("g:evalSelectionOCamlInterpreter") "{{{2
    if !exists("g:evalSelectionOCamlCmdLine")
        let g:evalSelectionOCamlCmdLine = 'ocaml'
    endif

    fun! EvalSelection_ocaml(cmd) "{{{2
        call EvalSelection("ocaml", a:cmd, "",  
                    \ "call EvalSelectionTalk(g:evalSelectionOCamlInterpreter, '", "')")
    endfun
    if !hasmapto("EvalSelection_ocaml(") "{{{2
        call EvalSelectionGenerateBindings("o", "ocaml")
    endif

    command! EvalSelectionSetupOCaml ruby EvalSelectionSetup(EvalSelectionOCaml)

    ruby << EOR
    class EvalSelectionOCaml < EvalSelectionInterpreter
        def setup
            @iid            = VIM::evaluate("g:evalSelectionOCamlInterpreter")
            @interpreter    = VIM::evaluate("g:evalSelectionOCamlCmdLine")
            @printFn        = "%{BODY};;"
            @quitFn         = "exit 0;;"
            @recPromptRx    = "\n# "
            @markFn         = "745287134.536216736;;" 
            @recMarkRx      = "\n# - : float = 745287134.536216736"
            @bannerEndRx    = "\n"
            if VIM::evaluate("g:evalSelectionOCamlInterpreter") == "OCamlClean"
                @postProcess    = proc {|s| s.sub(/^\s*- : .+? = /, "")}
            end
        end
    end
EOR
endif


if exists("g:evalSelectionSchemeInterpreter")
    if g:evalSelectionSchemeInterpreter ==? 'Gauche' "{{{2
        if !exists("g:evalSelectionSchemeCmdLine")
            let s:evalSelectionSchemeCmdLine = 'gosh'
        endif
        let s:evalSelectionSchemePrint = '(display %{BODY}) (display #\escape) (flush)'
    elseif g:evalSelectionSchemeInterpreter ==? 'Chicken' "{{{2
        if !exists("g:evalSelectionSchemeCmdLine")
            let g:evalSelectionSchemeCmdLine = 'csi -quiet'
        endif
        let s:evalSelectionSchemePrint = 
                    \ '(display %{BODY}) (display (integer->char 27)) (flush-output)'
    endif

    fun! EvalSelection_scheme(cmd) "{{{2
        call EvalSelection("scheme", a:cmd, "", 
                    \ "call EvalSelectionTalk(g:evalSelectionSchemeInterpreter, '", "')")
    endfun
    
    if !hasmapto("EvalSelection_scheme(") "{{{2
        call EvalSelectionGenerateBindings("c", "scheme")
    endif

    command! EvalSelectionSetupScheme ruby EvalSelectionSetup(EvalSelectionScheme)

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
    if g:evalSelectionLispInterpreter ==? "CLisp" "{{{2
        if !exists("g:evalSelectionLispCmdLine")
            let g:evalSelectionLispCmdLine = 'clisp --quiet'
        endif
    
        ruby << EOR
        class EvalSelectionLisp < EvalSelectionInterpreter
            def setup
                @iid            = VIM::evaluate("g:evalSelectionLispInterpreter")
                @interpreter    = VIM::evaluate("g:evalSelectionLispCmdLine")
                @printFn        = ":q(let ((rv (list (ignore-errors %{BODY})))) \
                (if (= (length rv) 1) (car rv) rv))"
                @quitFn         = "(quit)"
                @recPromptRx    = "\n(Break \\d\\+ )?\\[\\d+\\]\\> "
                @postProcess    = proc {|s| s.sub(/^\n/, "")}
                @recSkip        = 1
                @useNthRec      = 1
            end
        end
EOR
    endif

    fun! EvalSelection_lisp(cmd) "{{{2
        call EvalSelection("lisp", a:cmd, "",  
                    \ "call EvalSelectionTalk(g:evalSelectionLispInterpreter, '", "')")
    endfun
    
    if !hasmapto("EvalSelection_lisp(") "{{{2
        call EvalSelectionGenerateBindings("l", "lisp")
    endif
    
    command! EvalSelectionSetupLisp ruby EvalSelectionSetup(EvalSelectionLisp)
endif


" vim: ff=unix
