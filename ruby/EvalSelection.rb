#!/usr/bin/env ruby
# EvalSelection.rb -- Evaluate text using an external interpreter
# @Author:      Thomas Link (samul AT web.de)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     11-Mär-2004.
# @Last Change: 05-Mai-2004.
# @Revision:    0.95

# require "open3"

$EvalSelectionTalkers = Hash.new

class EvalSelectionInterpreter # {{{2    
    attr :iid
    
    def initialize
        @ioIn        = nil
        @ioOut       = nil
        @ioErr       = nil
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
        raise "Either @recEndChar or @recPromptRx must be non-nil!" unless (@recEndChar || @recPromptRx)
    end
    
    def setup #{{{3
        raise "EvalSelectionInterpreter#setup must be overridden!"
    end

    def sayHi #{{{3
        unless @ioIn
            # there is no popen3 under Windows
            # @ioIn, @ioOut, @ioErr = Open3.popen3(@interpreter)
            @ioIn = @ioOut = IO.popen(@interpreter, File::RDWR)
            listen(true) if @bannerEndRx or @recSkip > 0
            return @ioIn != nil
        end
    end
    
    def sayBye #{{{3
        if @ioOut
            @ioOut.puts(@quitFn)
            @ioOut.close
            @ioIn = @ioOut = @ioErr = nil
        end
    end
    
    def say(body) #{{{3
        #+++ use look back rx
        pr = @printFn.gsub(/(^|[^%])%\{BODY\}/, "\\1#{body}")
        pr.gsub!(/%%/, "%")
        pr += @markFn if @markFn
        @ioOut.puts(pr)
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
        if @recPromptRx or recMarkRx
            markRx = /#{(recMarkRx || "") + (@recPromptRx || "")}$/
        else
            markRx = nil
        end
        if ign < 0
            return ""
        else
            # VIM::command(%{echomsg "#{markRx.inspect}"})
            while ign >= 0
                ign -= 1
                l    = ""
                until @ioIn.eof
                    c = @ioIn.getc()
                    if @recEndChar and c == @recEndChar
                        break
                    else
                        l << c
                        # VIM::command(%{echomsg "#{l}"})
                        if markRx and l =~ markRx
                            l.sub!(markRx, "")
                            break
                        end
                    end
                end
            end
            l = @postProcess.call(l) if @postProcess
            return l
        end
    end

    def talk(blabla) #{{{3
        say(blabla)
        # not correct but ...
        blabber = blabla.gsub(/(["])/, '\\\\\1')
        VIM::command(%Q{let g:evalSelLastCmd   = "#{blabber}"})
        VIM::command(%Q{let g:evalSelLastCmdId = "#{@iid}"})
        # p listen().gsub(/(["])/, "'")
        for i in listen()
            puts i
        end
    end
end

module EvalSelection
    def withId(id, *args) # {{{2
        i = $EvalSelectionTalkers[id]
        if i
            i.send(*args)
        else
            VIM::command(%Q{throw "EvalSelectionTalk: Set up interaction with #{@iid} first!"})
        end
    end
    module_function :withId
    
    def setup(interpreterClass) # {{{2
        i  = $EvalSelectionTalkers[id] || interpreterClass.new
        ok = i.sayHi
        $EvalSelectionTalkers[i.iid] = i if ok
        return ok
    end
    module_function :setup

    def sayQuit(id) # {{{2
        withId(id, :sayBye)
    end
    module_function :sayQuit

    def talk(id, blabla) # {{{2
        withId(id, :talk, blabla)
    end
    module_function :talk
end

# vim: ff=unix
