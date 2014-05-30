
require 'English'
require 'fileutils'
require 'acoc/version'
require 'acoc/program'
require 'acoc/config'
require 'acoc/rule'
require 'acoc/parser'
require 'acoc/painter'

# Optionally requiring Ruby/TPty
# TODO: How to do it cleanly on `gemspec`,
#       since it's not a gem.
begin
  require 'tpty'
rescue LoadError


  module ACOC
    module_function

    # All options from the configuration file, in a Hash
    def cmd
      @@cmd = Config.new unless defined? @@cmd
      @@cmd
    end

    # set things up
    #
    def initialise

      # Queen's or Dubya's English?
      if ENV['LANG'] == "en_US" || ENV['LC_ALL'] == "en_US"
        @@colour = "color"
      else
        @@colour = "colour"
      end

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
      signals.each do |signal|
        trap(signal) do
          # make sure terminal is never left in a coloured state
          begin
            print reset
          rescue Errno::EPIPE  # Errno::EPIPE can occur when we're being piped
          end

          # reap the child and collect its exit status
          # WNOHANG is needed to prevent hang when pty is used
          begin
            pid, status = Process.waitpid2(-1, Process::WNOHANG)

          rescue Errno::ECHILD  # Errno::ECHILD can occur in waitpid2

          ensure
            # exit must be wrapped in at_exit to make sure all output buffers
            # are flushed. Shift 8 bits to convert exit/signal to just exit status
            at_exit { exit status.nil? ? 0 : status >> 8 }
          end
        end
      end
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

    # process program output, one line at a time
    #
    def paint_output(prog, *cmd_line)
      block = proc do |f|
        while ! f.eof?
          begin
            line = f.gets
          rescue  # why do we need rescue here?
            exit  # why the Errno::EIO when running ls(1)?
          end

          coloured_line = Painter.colour_line(prog, line)

          begin
            print coloured_line
          rescue Errno::EPIPE => reason   # catch broken pipes
            $stderr.puts reason
            exit Errno::EPIPE::Errno
          end

        end
      end

      # take care of any embedded single quotes in args expanded from globs
      cmd_line.map! { |arg| arg.gsub(/'/, %q('"'"')) }

      # prepare command line: requote each argument for the shell
      cmd_line = "'" << cmd_line.join(%q(' ')) << "'"

      # redirect stderr to stdout if /e flag given
      cmd_line << " 2>&1" if @@cmd[prog].flags.include? 'e'

      # make sure we don't buffer output when stdout is connected to a pipe
      $stdout.sync = true

      # install signal handler
      trap_signal(%w(HUP INT QUIT CLD))

      if @@cmd[prog].flags.include?('p') && $LOADED_FEATURES.include?('tpty.so')
        # allocate program a pseudo-terminal and run through that
        pty = TPty.new do |s,|
          fork do
            # redirect child streams to slave
            STDIN.reopen(s)
            STDOUT.reopen(s)
            #STDERR.reopen(s)
            s.close
            execute_program(cmd_line)
          end
        end

        # no buffering on pty
        # pty.master.sync = true
        block.call(pty.master)
      else
        # execute command
        IO.popen(cmd_line) { |f| block.call(f) }
      end
    end

  end
end

