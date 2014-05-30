
require 'term/ansicolor'
include Term::ANSIColor

module ACOC

  # Responsible for adding colors to the output
  module Painter
    module_function

    # Tells if #color is supported.
    #
    # @param color Color String.
    #
    def valid_color? color
        Term::ANSIColor::attributes.collect { |a| a.to_s }.include? color
    end

    # match and color an individual line
    #
    def color_line(prog, line)
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
              index = [matches, spec.colors.size - 1].min
              spec.colors[index].split(/[+\s]+/).each do |color|
                match = match.send(color)
              end
              matches += 1
              match
            end

          else  # color each match separately
            # work from right to left, bracketing each match
            (r.size - 1).downto(1) do |i|
              start  = r.begin(i)
              length = r.end(i) - start
              index  = [i - 1, spec.colors.size - 1].min
              ansi_offset = 0
              spec.colors[index].split(/[+\s]+/).each do |color|
                line[start + ansi_offset, length] =
                  line[start + ansi_offset, length].send(color)
                # when applying multiple colors, we apply them one at a
                # time, so we need to compensate for the start of the string
                # moving to the right as the color codes are applied
                ansi_offset += send(color).length
              end
            end
          end
        end
      end

      line
    end

  end
end

