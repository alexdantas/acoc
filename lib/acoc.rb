
require 'English'
require 'fileutils'
require 'acoc/version'
require 'acoc/program'
require 'acoc/config'
require 'acoc/rule'

require 'term/ansicolor'
include Term::ANSIColor

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

    if parse_config(*config_files) == 0
      $stderr.puts "No readable config files found."
      exit 1
    end
  end

  # Displays usage message and exit
  #
  def usage(code = 0)
    $stderr.puts <<EOF
Usage: acoc command [arg1 .. argN]
       acoc [-h|--help|-v|--version]
EOF

    exit code
  end

  # Displays version and copyright message, then exit.
  #
  def version
    $stderr.puts <<EOF
acoc #{ACOC::VERSION}

Copyright 2003-2005 Ian Macdonald <ian@caliban.org>
This is free software; see the source for copying conditions.
There is NO warranty; not even for MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE, to the extent permitted by law.
EOF

    exit
  end

  # Parses data inside configuration files.
  #
  # @param  files An array of filenames to parse.
  # @return The amount of files parsed
  #
  def parse_config(*files)
    @@cmd = Config.new
    parsed_count = 0

    files.each do |file|
      $stderr.printf("Attempting to read config file: %s\n", file) if $DEBUG
      next unless file && FileTest::file?(file) && FileTest::readable?(file)

      begin
        File.open(file) do |f|
          while line = f.gets do
            next if line =~ /^(#|$)/     # skip blank lines and comments

            if line =~ /^[@\[]([^\]]+)[@\]]$/  # start of program section
              # get program invocation
              progs = $1.split(/\s*,\s*/)
              progs.each do |prog|
                invocation, flags = prog.split(%r(/))

                if ! flags.nil? && flags.include?('r')
                  # remove matching entries for this program
                  program = invocation.sub(/\s.*$/, '')
                  @@cmd.each_key do |key|
                    @@cmd.delete(key) if key =~ /^#{program}\b/
                  end
                  flags.delete 'r'
                end

                # create entry for this program
                if @@cmd.has_key?(invocation)
                  @@cmd[invocation].flags += flags unless flags.nil?
                else
                  @@cmd[invocation] = Program.new(flags)
                end
                prog.sub!(%r(/\w+), '')
              end
              next
            end

            begin
              regex, flags, colours =
                /^(.)([^\1]*)\1(g?)\s+(.*)/.match(line)[2..4]
            rescue
              $stderr.puts "Ignoring bad config line #{$NR}: #{line}"
            end

            colours = colours.split(/\s*,\s*/)
            colours.join(' ').split(/[+\s]+/).each do |colour|
              raise "#{@@colour} is not a supported #{@@colour}" \
              unless Term::ANSIColor::attributes.collect { |a| a.to_s }.include? colour
              end

              progs.each do |prog|
                @@cmd[prog].specs << Rule.new(Regexp.new(regex), flags, colours)
              end
            end
          end
        rescue Errno::ENOENT
          $stderr.puts "Failed to open config file: #{$ERROR_INFO}"
          exit 1
        rescue
          $stderr.puts "Error while parsing config file #{file} @ line #{$NR}: #{$ERROR_INFO}"
          exit 2
        end

        parsed_count += 1
      end

      $stderr.printf("Action data: %s\n", @@cmd.inspect) if $DEBUG

      parsed_count
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

    def run(args)
      exec(*args)
    rescue Errno::ENOENT => reason
      # can't find the program we're supposed to run
      $stderr.puts reason
      exit Errno::ENOENT::Errno
    end

    # match and colour an individual line
    #
    def colour_line(prog, line)
      matched = false

      # act on only the first match unless the /a flag was given
      return if matched && ! @@cmd[prog].flags.include?('a')

      # get a pattern and attribute set pairing for this command
      @@cmd[prog].specs.each do |spec|

        if r = spec.regex.match(line)  # line matches this regex
          matched = true
          if spec.flags.include? 'g'   # global flag
            matches = 0

            # perform global substitution
            line.gsub!(spec.regex) do |match|
              index = [matches, spec.colours.size - 1].min
              spec.colours[index].split(/[+\s]+/).each do |colour|
                match = match.send(colour)
              end
              matches += 1
              match
            end

          else  # colour each match separately
            # work from right to left, bracketing each match
            (r.size - 1).downto(1) do |i|
              start  = r.begin(i)
              length = r.end(i) - start
              index  = [i - 1, spec.colours.size - 1].min
              ansi_offset = 0
              spec.colours[index].split(/[+\s]+/).each do |colour|
                line[start + ansi_offset, length] =
                  line[start + ansi_offset, length].send(colour)
                # when applying multiple colours, we apply them one at a
                # time, so we need to compensate for the start of the string
                # moving to the right as the colour codes are applied
                ansi_offset += send(colour).length
              end
            end
          end
        end
      end

      line
    end

    # process program output, one line at a time
    #
    def colour(prog, *cmd_line)
      block = proc do |f|
        while ! f.eof?
          begin
            line = f.gets
          rescue  # why do we need rescue here?
            exit  # why the Errno::EIO when running ls(1)?
          end

          coloured_line = colour_line(prog, line)

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
            run(cmd_line)
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

