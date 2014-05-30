
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
        ACOC.logger.debug do "Attempting to read config file: '#{file}'" end

        next unless file && FileTest::file?(file) && FileTest::readable?(file)

        begin
          File.open(file) do |f|
            while line = f.gets do
              parse_line line
            end
          end

        rescue Errno::ENOENT
          $stderr.puts "acoc: Failed to open config file '#{$ERROR_INFO}'"
          exit 1

        rescue
          $stderr.puts "acoc: Error on config file '#{file}' at line #{$NR}: #{$ERROR_INFO}"
          exit 2
        end
        parsed_count += 1

        ACOC.logger.debug do "Action data: #{ACOC.cmd.inspect}" end
      end

      parsed_count
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
        regex, flags, colors = /^(.)([^\1]*)\1(g?)\s+(.*)/.match(line)[2..4]
      rescue
        $stderr.puts "acoc: Ignoring bad config line #{$NR}: '#{line}'"
      end

      colors = colors.split(/\s*,\s*/)
      colors.join(' ').split(/[+\s]+/).each do |color|

        # Let's quit if the user provided an invalid color
        if not Painter.valid_color? color
          raise "'#{color}' is not a supported color"
        end

        @@progs.each do |prog|
          ACOC.cmd[prog].specs << Rule.new(Regexp.new(regex), flags, colors)
        end
      end
    end

  end
end

