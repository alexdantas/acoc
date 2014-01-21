
module ACOC
  class Program
    attr_accessor :flags, :specs

    def initialize(flags)
      @flags = flags || ""
      @specs = Array.new
    end
  end
end

