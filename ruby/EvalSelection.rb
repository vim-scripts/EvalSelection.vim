#!/usr/bin/env ruby
# EvalSelection.rb -- Evaluate text using an external interpreter
# @Author:      Thomas Link (samul AT web.de)
# @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
# @Created:     11-Mär-2004.
# @Last Change: 16-Feb-2005.
# @Revision:    0.259

# require "open3"

$EvalSelectionTalkers = Hash.new

class EvalSelectionAbstractInterpreter
    attr :iid
    attr_accessor :active
    
    def initialize
        @iid    = ""
        setup
        @active = initialize_communication
    end

    def setup 
        raise "#setup must be overwritten!"
    end

    def build_interpreter_menu
        build_menu
        @menu = true
    end

    def build_menu
    end

    def remove_interpreter_menu
        if @menu
            remove_menu
            @menu = false
        end
    end
    
    def remove_menu
    end
    
    def initialize_communication
        raise "#initialize_communication must be overwritten!"
    end
    
    def tear_down
        raise "#tear_down must be overwritten!"
    end

    def interact(text)
        raise "#talk must be overwritten!"
    end
    
    def talk(text)
        blabber = text.gsub(/(["])/, '\\\\\1')
        VIM::command(%Q{let g:evalSelLastCmd   = "#{blabber}"})
        VIM::command(%Q{let g:evalSelLastCmdId = "#{@iid}"})
        # puts interact(text)
        rv = interact(text)
        if rv
            for i in rv
                puts i
            end
        end
    end

    def postprocess(text)
        text
    end
end

class EvalSelectionInterpreter < EvalSelectionAbstractInterpreter
    def initialize
        @ioIn        = nil
        @ioOut       = nil
        @ioErr       = nil
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
        super
    end
    
    def initialize_communication
        unless @ioIn
            # there is no popen3 under Windows
            # @ioIn, @ioOut, @ioErr = Open3.popen3(@interpreter)
            @ioIn = @ioOut = IO.popen(@interpreter, File::RDWR)
            listen(true) if @bannerEndRx or @recSkip > 0
            return @ioIn != nil
        end
    end
    
    def tear_down 
        if @ioOut
            @ioOut.puts(@quitFn)
            @ioOut.close
            @ioIn = @ioOut = @ioErr = nil
        end
        return @ioOut
    end
    
    def interact(text)
        say(text)
        # listen().gsub(/(["])/, "'")
        listen()
    end
    
    def say(body) 
        #+++ use look back rx
        pr = @printFn.gsub(/(^|[^%])%\{BODY\}/, "\\1#{body}")
        pr.gsub!(/%%/, "%")
        pr += @markFn if @markFn
        @ioOut.puts(pr)
    end

    def listen(atStartup=false)
        unless (@recEndChar || @recPromptRx)
            raise "Either @recEndChar or @recPromptRx must be non-nil!"
        end
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
            # VIM::message(markRx.inspect)
            if VIM::evaluate("g:evalSelectionDebugLog") != "0"
                VIM::evaluate(%{EvalSelectionLog("'DBG:'")})
            end
            while ign >= 0
                ign -= 1
                l    = ""
                until @ioIn.eof
                    c = @ioIn.getc()
                    if @recEndChar and c == @recEndChar
                        break
                    else
                        if VIM::evaluate("g:evalSelectionDebugLog") != "0"
                            VIM::evaluate(%{EvalSelectionLog("#{("\"%c\"" % c).gsub(/"/, '\\\\"').gsub(/^\s*$/, "")}", 1)})
                        end
                        l << c
                        # VIM::message(l)
                        if markRx and l =~ markRx
                            l.sub!(markRx, "")
                            break
                        end
                    end
                end
            end
            l = postprocess(l)
            return l
        end
    end
end

class EvalSelectionStdInFileOut < EvalSelectionInterpreter
    def initialize
        @outfile = nil
        super
        unless @outfile
            raise "@outfile must be defined!"
        end
    end
    
    def listen(atStartup=false)
        # rv = File.open(@outfile) {|io| io.read}
        # # VIM::command(%{echom "#{rv}"})
        # rv
        File.open(@outfile) {|io| io.read}
    end
end

class EvalSelectionOLE < EvalSelectionAbstractInterpreter
    attr :ole_server

    def initialize
        @ole_server = nil
        super
    end

    def initialize_communication
        ole_setup unless @ole_server
        return @ole_server != nil
    end
    
    def interact(text)
        m = /^#(\w+)(\s.*)?$/.match(text)
        if m
            args = [m[1]]
            text = m[2]
            while (m = /^(\s+("(\\"|[^"])*"|\S+))/.match(text))
                args << m[2]
                text = m.post_match
            end
            if text.nil? or text.empty?
                rv = @ole_server.send(*args)
            else
                raise "EvalSelection: Parse error: #{text}"
            end
        else
            rv = postprocess(ole_evaluate(text))
        end
        if rv.kind_of?(Array)
            rv.shift if rv.first == ""
            rv.pop if rv.last == ""
            rv.collect {|e| "%s" % e}.join("\n")
        elsif rv.nil?
            rv
        else
            "%s" % rv
        end
    end

    def tear_down
        if @ole_server
            ole_tear_down
        else
            true
        end
    end
    
    def ole_setup
        raise "#setup must be overwritten!"
    end

    def ole_tear_down
        raise "#setup must be overwritten!"
    end

    def ole_evaluate(text)
        raise "#setup must be overwritten!"
    end

    alias :ole_evaluate_no_return :ole_evaluate
end

module EvalSelection
    def withId(id, *args)
        i = $EvalSelectionTalkers[id]
        if i
            i.send(*args)
        else
            VIM::command(%Q{throw "EvalSelectionTalk: Set up interaction with #{id} first!"})
        end
    end
    module_function :withId
    
    def setup(name, interpreterClass, quiet=false)
        i = $EvalSelectionTalkers[name]
        if !i
            i = interpreterClass.new
            if i
                $EvalSelectionTalkers[i.iid] = i
                i.build_interpreter_menu
            end
        elsif !quiet
            VIM::command(%Q{echom "EvalSelection: Interaction with #{name} already set up!"})
        end
        return i
    end
    module_function :setup

    def talk(id, text) 
        withId(id, :talk, text)
    end
    module_function :talk
   
    def remove_menu(id)
        begin
            withId(id, :remove_interpreter_menu)
        rescue Exception => e
            VIM::command(%{echom "Error when removing the menu for #{id}"})
        end
    end
    module_function :remove_menu
    
    def tear_down(id)
        remove_menu(id)
        if withId(id, :tear_down)
            $EvalSelectionTalkers[id] = nil
        else
            VIM::command(%Q{throw "EvalSelection: Can't stop #{id}!"})
        end
    end
    module_function :tear_down

    def tear_down_all
        $EvalSelectionTalkers.each do |id, interp|
            begin
                if interp and interp.tear_down
                    $EvalSelectionTalkers[id] = nil
                end
            rescue Exception => e
                VIM::command(%{echom "Error when shutting down #{id}"})
            end
        end
    end
    module_function :tear_down_all
end

# vim: ff=unix
