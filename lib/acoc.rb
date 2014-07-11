
require 'English'
require 'fileutils'
require 'logger'
require 'shellwords'

require 'acoc/version'
require 'acoc/program'
require 'acoc/config'
require 'acoc/rule'
require 'acoc/parser'
require 'acoc/painter'

begin
  require 'tpty'
  $has_tpty = true
rescue LoadError
  require 'pty'
  $has_tpty = false
end

  module ACOC
    module_function

    # Signal name from number.
    def signame(signo)
      # Do not use signame:
      # - ruby 1.8 does not have it
      # - it will not work with an unknown signal number (e.g. 42)
      Signal.list.invert[signo] || '???'
    end

    # Get pseudo terminal.
    def getpty
      if $has_tpty
        pty = TPty.new()
        [pty.master, pty.slave]
      else
        # Ruby >=1.9 has PTY.open.
        unless PTY.respond_to?(:open)
          $stderr.puts "acoc: warning: no pseudo terminal support available (for Ruby 1.8, install tpty)"
          IO.pipe()
        else
          PTY.open()
        end
      end
    end

    # All options from the configuration file, in a Hash
    def cmd
      @@cmd ||= Config.new
    end

    # External interface to log things.
    #
    # @note The _actual_ way to use it is passing a message block
    #       (like this):
    #           ACOC.logger.debug do "message" end
    #       That's because the string concatenations are only
    #       processed if the debug mode is active.
    #
    def logger
      if not defined? @@logger
        @@logger = Logger.new(STDERR)

        # Default level is WARN and above.
        # DEBUG < INFO < WARN < ERROR < FATAL < UNKNOWN
        @@logger.level = Logger::WARN
        @@logger.level = Logger::DEBUG if $DEBUG

        @@logger.formatter = Kernel.proc do |severity, datetime, progname, msg|
          "#{datetime} #{severity}: #{msg}\n"
        end
      end
      @@logger
    end

    # Set things up, making sure to parse the configuration
    # files.
    #
    def initialise

      # The default configuration files, in order of reading
      # Note that the last file will override the preferences
      # of the first.
      config_files = []
      config_files << File.expand_path(File.dirname(__FILE__) + '/../acoc.conf')
      config_files += %w(/etc/acoc.conf /usr/local/etc/acoc.conf)
      config_files << ENV['HOME'] + "/.acoc.conf"
      config_files << ENV['ACOCRC'] if ENV['ACOCRC']

      # No configuration files parsed?
      # It returns the number of files read.
      if (Parser.parse_config(*config_files) == 0)
        $stderr.puts "No readable config files found."
        exit 1
      end
    end

    def trap_signal(signals)
      signals.each { |signal| trap(signal) {} }
    end

    # Runs a program.
    #
    # @param args The full command (with arguments) to be executed on the terminal.
    #
    # @warning It WILL replace ACOC; in other words, ACOC's execution
    #          will be interrupted and the command will run and
    #          finish as if it ran itself on the first place.
    #
    # @note If you want to run this command along with ACOC, you should
    #       `fork()` or something.
    #
    def execute_program(args)

      Kernel.exec(*args)

    rescue Errno::ENOENT => reason

      # Can't find the program we're supposed to run
      $stderr.puts "acoc: #{args[0]}: command not found"

      exit Errno::ENOENT::Errno
    end

    # Process program output, one line at a time.
    #
    # @param section    acoc section on the config file, specifying colors
    # @param cmd_line   The full command to be executed, with arguments.
    #
    def paint_output(section, *cmd_line)

      # We're creating a Proc - meaning we are saving
      # the following block to be executed only when
      # we want it to.
      #
      # When called, this block will run the program
      # and paint it's output.
      #
      # That `io` is the input-output of the program
      # being executed.
      #
      block = Kernel.proc do |io|
        while true

          line = begin
                   io.gets
                 rescue Errno::EIO # GNU/Linux raises EIO on EOF when using PTY.
                   nil
                 end
          break unless line

          colored_line = Painter.color_line(section, line)

          begin
            print colored_line

          rescue Errno::EPIPE => reason   # catch broken pipes
            $stderr.puts reason
            exit Errno::EPIPE::Errno
          end
        end
      end

      # Make sure we don't buffer
      # output when stdout is connected to a pipe
      STDOUT.sync = true

      # Install signal handler
      trap_signal(%w(HUP INT QUIT))

      if @@cmd[section].flags.include?('p')
        pipe = getpty()
      else
        pipe = IO.pipe()
      end

      child = fork do
        if @@cmd[section].flags.include? 'p'
          lines, cols = `stty size 2>/dev/null`.split()
          if 0 == $?
            ENV['LINES'] = lines
            ENV['COLUMNS'] = cols
          end
        end
        STDOUT.reopen(pipe[1])
        STDERR.reopen(pipe[1]) if @@cmd[section].flags.include? 'e'
        pipe[0].close()
        pipe[1].close()
        execute_program(cmd_line)
      end

      pipe[1].close()

      # This will run the `Proc` defined at the
      # beginning of this function, running
      # the program and painting it's output.
      block.call(pipe[0])

      # reap the child and collect its exit status
      # WNOHANG is needed to prevent hang when pty is used
      begin
        Process.waitpid(child)
      rescue Errno::ECHILD # Errno::ECHILD can occur in waitpid
      end

      # make sure terminal is never left in a coloured state
      begin
        print reset
      rescue Errno::EPIPE # Errno::EPIPE can occur when we're being piped
      end

      if $?.signaled?
        case signame($?.termsig)
        when 'ABRT'  ; reason = "abort"
        when 'ALRM'  ; reason = "alarm"
        when 'BUS'   ; reason = "bus error"
        when 'FPE'   ; reason = "floating point exception"
        when 'HUP'   ; reason = "hangup"
        when 'ILL'   ; reason = "illegal hardware instruction"
        when 'INT'   ; reason = "interrupt"
        when 'KILL'  ; reason = "killed"
        when 'QUIT'  ; reason = "quit"
        when 'SEGV'  ; reason = "segmentation fault"
        when 'TERM'  ; reason = "terminated"
        when 'TRAP'  ; reason = "trace trap"
        else         ; reason = "signal #{$?.termsig} (#{signame($?.termsig)})"
        end
        reason << ' (cored dumped)' if $?.coredump?
        STDERR.puts "acoc: #{reason}: #{Shellwords.join(cmd_line)}"
        status = 128 + $?.termsig
      else
        status = $? >> 8
      end

      return status

    end

  end

