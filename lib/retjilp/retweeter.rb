require 'rubygems'
require 'oauth'
require 'json/pure'

require 'retjilp/log'

module Retjilp
	class Retweeter
		def initialize(twitter, options)
			@twitter = twitter
			@retweet_from_list = options[:retweet_from_list]
			@match = options[:match]
		end

		def run
			@twitter.login

			# Fetch own tweets
			user_timeline = @twitter.user_timeline.select {|x| x.has_key? 'retweeted_status'}
			retweeted_ids = user_timeline.map { |status| status['retweeted_status']['id'] }.sort

			# Fetch timeline tweets
			statuses_options = {}
			statuses_options[:since_id] = retweeted_ids[0] unless retweeted_ids.empty?
			if @retweet_from_list
				statuses = @twitter.list_statuses(@retweet_from_list, statuses_options)
			else
				statuses = @twitter.home_timeline(statuses_options)
			end

			# Retweet statuses
			statuses.each do |status|
				if should_retweet? status['text']
					id_to_retweet = status.has_key?('retweeted_status') ? status['retweeted_status']['id'] : status['id']
					if retweeted_ids.include? id_to_retweet
						Retjilp::log.debug("Already retweeted: #{status['text']}")
					else
						Retjilp::log.info("Retweeting: #{status['text']}")
						@twitter.retweet id_to_retweet
					end
				end
			end
		end

		private
			def should_retweet?(tweet)
				@match.empty? or @match.any? { |match| tweet.downcase.include? match.downcase  }
			end
	end
end
