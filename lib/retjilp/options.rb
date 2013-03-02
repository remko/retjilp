require 'optparse'
require 'logger'

module Retjilp
	class Options
		attr_reader :log_level

		def initialize(argv)
			@log_level = Logger::WARN
			OptionParser.new do |opts|
				opts.banner = "Usage: retjilp [ --help ] [ --verbose | --debug ]"
				opts.on("--verbose", "Run with verbose output") { @log_level = Logger::INFO }
				opts.on("--debug", "Run with debug output") { @log_level = Logger::DEBUG }
				opts.on_tail("-h", "--help", "Show this help") { puts opts ; exit }
				begin
					opts.parse!(argv)
				rescue => e
					STDERR.puts e.message, "\n", opts
					exit(-1)
				end
			end.parse!(argv)
		end
	end
end
