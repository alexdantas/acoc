
module ACOC

  # Parses configuration files and builds configurations
  # on the main ACOC module.
  #
  module Parser
    module_function

    # Parses data inside configuration files.
    #
    # @param  files An array of filenames to parse.
    # @return The amount of files parsed
    #
    def parse_config(*files)
      parsed_count = 0

      files.each do |file|
        $stderr.printf("Attempting to read config file: %s\n", file) if $DEBUG
        next unless file && FileTest::file?(file) && FileTest::readable?(file)

        begin
          File.open(file) do |f|
            while line = f.gets do
              parse_line line
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

        $stderr.printf("Action data: %s\n", ACOC.cmd.inspect) if $DEBUG

        parsed_count
      end
    end

    def parse_line(line)

      # Skipping blank lines and comments
      return if line =~ /^(#|$)/

      # Are we're at the start of program section?
      #
      #     [program]
      #
      section = /^[@\[]([^\]]+)[@\]]$/.match(line)
      if section

        # Get program invocations and flags
        #
        #     [invocation1/flags1,invocation2/flags2,...]
        #
        @@progs = section[0].split(/\s*,\s*/)

        @@progs.each do |prog|

          invocation, flags = prog.split(%r(/))

          # The 'r' flag removes any previous matching entries
          # for the current command.
          if ! flags.nil? && flags.include?('r')

            program = invocation.sub(/\s.*$/, '')

            ACOC.cmd.each_key do |key|
              ACOC.cmd.delete(key) if key =~ /^#{program}\b/
            end

            flags.delete 'r'
          end

          # Create entry for this program
          if ACOC.cmd.has_key?(invocation)
            ACOC.cmd[invocation].flags += flags unless flags.nil?
          else
            ACOC.cmd[invocation] = Program.new(flags)
          end
          prog.sub!(%r(/\w+), '')
        end
        return
      end

      # If not then it's a rule line
      #
      #     /regexp/    color1,color2,...
      #
      begin
        regex, flags, colours = /^(.)([^\1]*)\1(g?)\s+(.*)/.match(line)[2..4]
      rescue
        $stderr.puts "Ignoring bad config line #{$NR}: #{line}"
      end

      colours = colours.split(/\s*,\s*/)
      colours.join(' ').split(/[+\s]+/).each do |colour|
        raise "#{@@colour} is not a supported #{@@colour}" \
        unless Term::ANSIColor::attributes.collect { |a| a.to_s }.include? colour
        end

        @@progs.each do |prog|
          ACOC.cmd[prog].specs << Rule.new(Regexp.new(regex), flags, colours)
        end
      end
    end
  end


