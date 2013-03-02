require 'json/pure'
require 'optparse'

require_relative 'log'
require_relative 'retweeter'
require_relative 'twitter'

module Retjilp
	DATA_DIR = File.expand_path("~/.retjilp")

	class Runner
		def initialize(argv)
			# Parse command-line options
			OptionParser.new do |opts|
				opts.banner = "Usage: retjilp [ --help ] [ --verbose | --debug ]"
				opts.on("--verbose", "Run with verbose output") { Retjilp::log.level = Logger::INFO }
				opts.on("--debug", "Run with debug output") { Retjilp::log.level = Logger::DEBUG }
				opts.on_tail("-h", "--help", "Show this help") { puts opts ; exit }
				begin
					opts.parse!(argv)
				rescue => e
					fatal_error("Invalid option(s): #{e.message}\n" + opts.to_s)
				end
			end

			# Parse config file
			config_filename = File.join(DATA_DIR, "config")
			begin
				@options = File.open(config_filename) { |f| JSON.load(f) }
			rescue => e
				fatal_error("Error parsing configuration file #{config_filename}: #{e.message}")
			end

			# Convert keys to symbols
			@options = @options.inject({}){|m,(k,v)| m[k.to_sym] = v; m}
		end

		def run
			consumer_key = (@options[:consumer_key] or fatal_error("Consumer key missing"))
			consumer_secret = (@options[:consumer_secret] or fatal_error("Consumer secret missing"))
			twitter = Twitter.new(@options[:consumer_key], @options[:consumer_secret])
			Retweeter.new(twitter, @options).run
		end

		private
			def fatal_error(msg)
				STDERR.puts msg
				exit(-1)
			end
	end
end
