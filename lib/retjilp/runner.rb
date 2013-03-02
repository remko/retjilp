require_relative 'options'
require_relative 'retweeter'

module Retjilp
	class Runner
		def initialize(argv)
			@options = Options.new(argv)
		end

		def run
			Retweeter.new(@options).run
		end
	end
end
