
require 'English'
require 'fileutils'
require 'logger'

require 'acoc/version'
require 'acoc/program'
require 'acoc/config'
require 'acoc/rule'
require 'acoc/parser'
require 'acoc/painter'

  module ACOC
    module_function

    # All options from the configuration file, in a Hash
    def cmd
      @@cmd = Config.new unless defined? @@cmd
      @@cmd
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
      config_files = %w(/etc/acoc.conf /usr/local/etc/acoc.conf)
      config_files << ENV['HOME'] + "/.acoc.conf"
      config_files << ENV['ACOCRC'] if ENV['ACOCRC']

      # If there's no config file on user's home directory,
      # we'll place our default one there.
      #
      # The default one lies on the same directory as the
      # rest of the source code.
      # Since __FILE__ is inside lib/, we'll need to jump
      # above.
      #
      if not File.exist? File.expand_path '~/.acoc.conf'
        fixed_config = File.expand_path(File.dirname(__FILE__) + '/../acoc.conf')

        FileUtils.cp(fixed_config, File.expand_path('~/.acoc.conf'))
      end

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

          line = io.gets
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

      pipe = IO.pipe()

      child = fork do
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

      return $?.signaled? ? (128 + $?.termsig) : ($? >> 8)

    end

  end

