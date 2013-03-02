require 'logger'

module Retjilp
	@@log = nil

	def Retjilp.log
		unless @@log
			@@log = Logger.new(STDERR)
			@@log.formatter = proc { |severity, time, prog, msg| "#{severity}: #{msg}\n" }
			@@log.level = Logger::WARN
		end
		@@log
	end
end
