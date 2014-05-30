
require 'term/ansicolor'
include Term::ANSIColor

module ACOC

  # Responsible for adding colors to the output
  module Painter
    module_function

    # match and colour an individual line
    #
    def colour_line(prog, line)
      matched = false

      # act on only the first match unless the /a flag was given
      return if matched && ! ACOC.cmd[prog].flags.include?('a')

      # get a pattern and attribute set pairing for this command
      ACOC.cmd[prog].specs.each do |spec|

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


  end
end

