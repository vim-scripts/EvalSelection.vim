#!/usr/bin/env ruby
# EvalSelection.rb -- Evaluate text using an external interpreter
# @Author:      Thomas Link (samul AT web.de)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     11-Mär-2004.
# @Last Change: 02-Mai-2004.
# @Revision:    0.38


$EvalSelectionTalkers = Hash.new

class EvalSelectionInterpreter # {{{2    
    attr :iid
    
    def initialize
        @io          = nil
        @iid         = ""
        @interpreter = nil # The command-line to start the interpreter
        @printFn     = nil # The function that prints %{BODY}'s result and a record marker
        @quitFn      = nil # The function that quits the interpreter
        @recEndChar  = nil # A character end of record mark (default=ESCAPE)
        @recPromptRx = nil # A ruby pattern marking an empty prompt line
        @markFn      = nil # Mark end of output
        @recMarkRx   = nil # Match end of output
        @bannerEndRx = nil # skip banner until this regexp matches
        @recSkip     = 0   # skip first N records
        @useNthRec   = 0   # Use every Nth+1 record
        @postProcess = nil # A block that post-processes the resulting string 
                           # and returns the real result
        setup
        if !(@recEndChar || @recPromptRx)
            raise "Either @recEndChar or @recPromptRx must be non-nil!"
        end
    end
    
    def setup #{{{3
        raise "EvalSelectionInterpreter#setup must be overridden!"
    end

    def sayHi #{{{3
        if !@io
            @io      = IO.popen(@interpreter, File::RDWR)
            @io.sync = true
            if @bannerEndRx || @recSkip > 0
                listen(true)
            end
            return @io != nil
        end
    end
    
    def sayBye #{{{3
        if @io
            @io.puts(@quitFn)
            @io.close
            @io = nil
        end
    end
    
    def say(body) #{{{3
        #+++ use look back rx
        pr = @printFn.gsub(/(^|[^%])%\{BODY\}/, "\\1#{body}")
        pr.gsub!(/%%/, "%")
        @io.puts(pr)
        if @markFn
            @io.puts(@markFn)
        end
    end

    def listen(atStartup=false) #{{{3
        if atStartup
            if @bannerEndRx
                recMarkRx = @bannerEndRx
                ign       = 0
            elsif @recSkip > 0
                recMarkRx = nil
                ign       = @recSkip - 1
            else
                return ""
            end
        else
            ign       = @useNthRec
            recMarkRx = @recMarkRx
        end
        if @recPromptRx || recMarkRx
            markRx = /#{(recMarkRx || "") + (@recPromptRx || "")}$/
        else
            markRx = nil
        end
        if ign < 0
            return ""
        else
            while ign >= 0
                ign -= 1
                l    = ""
                while !@io.eof
                    c = @io.getc()
                    if @recEndChar && c == @recEndChar
                        break
                    else
                        l << c
                        if markRx && l =~ markRx
                            l.sub!(markRx, "")
                            break
                        end
                    end
                end
            end
            if @postProcess
                return @postProcess.call(l)
            else
                return l
            end
        end
    end

    def talk(blabla) #{{{3
        say(blabla)
        # not correct but ...
        blabber = blabla.gsub(/(["])/, '\\\\\1')
        VIM::command(%Q{let g:evalSelLastCmd   = "#{blabber}"})
        VIM::command(%Q{let g:evalSelLastCmdId = "#{@iid}"})
        # p listen().gsub(/(["])/, "'")
        print listen()
    end
end

module EvalSelection
    def EvalSelectionSetup(interpreterClass) # {{{2
        i = $EvalSelectionTalkers[id] || interpreterClass.new
        ok = i.sayHi
        if ok
            $EvalSelectionTalkers[i.iid] = i
        end
        return ok
    end

    def EvalSelectionWithId(id, *args) # {{{2
        i = $EvalSelectionTalkers[id]
        if i
            i.send(*args)
        else
            VIM::command(%Q{throw "EvalSelectionTalk: Set up interaction with #{@iid} first!"})
        end
    end

    def EvalSelectionSayQuit(id) # {{{2
        EvalSelectionWithId(id, :sayBye)
    end

    def EvalSelectionTalk(id, blabla) # {{{2
        EvalSelectionWithId(id, :talk, blabla)
    end
end

# vim: ff=unix
