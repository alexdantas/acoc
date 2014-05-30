
module ACOC

  # Single color rule for a program.
  class Rule
    attr_reader :regex, :flags, :colours

    def initialize(regex, flags, colours)
      @regex   = regex
      @flags   = flags
      @colours = colours
    end
  end
end

