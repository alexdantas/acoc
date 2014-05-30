
module ACOC

  # Single program, that can have multiple color Rules.
  class Program
    attr_accessor :flags, :specs

    def initialize(flags)
      @flags = flags || ""
      @specs = Array.new
    end
  end
end

