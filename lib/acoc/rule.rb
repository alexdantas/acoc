
module ACOC

  # Single color rule for a program.
  class Rule
    attr_reader :regex, :flags, :colors

    def initialize(regex, flags, colors)
      @regex   = regex
      @flags   = flags
      @colors = colors
    end
  end
end

