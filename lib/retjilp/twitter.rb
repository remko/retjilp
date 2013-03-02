require_relative 'log'

module Retjilp
	class Twitter
		TWITTER_URI = "http://api.twitter.com"
		API_VERSION = "1.1"
		ACCESS_TOKEN_FILENAME = File.join(File.expand_path("~/.retjilp"), "access_token")

		def initialize(consumer_key, consumer_secret)
			@consumer_key = consumer_key
			@consumer_secret = consumer_secret
		end

		def user_timeline
			Retjilp::log.info("Fetching own tweets")
			get "/statuses/user_timeline.json?trim_user=true&include_rts=true"
		end

		def list_statuses(list, options)
			Retjilp::log.info("Fetching list tweets of #{list}")
			since_id = options[:since_id] ? "&since_id=#{options[:since_id]}" : ""
			get "/lists/statuses.json?slug=#{list}&owner_screen_name=#{@user_info['screen_name']}&include_rts=true" + since_id
		end

		def home_timeline(options)
			since_id = options[:since_id] ? "&since_id=#{options[:since_id]}" : ""
			get "/statuses/home_timeline.json?trim_user=true" + since_id
		end

		def retweet(id)
			result = @access_token.post("/#{API_VERSION}/statuses/retweet/#{id}.json")
			result.class == Net::HTTPOK or Retjilp::log.error("Error retweeting #{result.body}")
		end

		def login
			# Request the token if the cached access token does not exist
			@access_token, @user_info = cached_access_token
			unless @access_token
				STDIN.tty? or raise "This script must be run interactively the first time to be able to authenticate."
				Retjilp::log.info("Requesting new access token")
				consumer = OAuth::Consumer.new(
					@consumer_key,
					@consumer_secret,
					:site => TWITTER_URI,
					:scheme => :header,
					:request_token_path => "/oauth/request_token",
					:authorize_path => "/oauth/authorize",
					:@access_token_path => "/oauth/@access_token",
					:http_method => :post)
				request_token = consumer.get_request_token(:oauth_callback => "oob")

				puts "Please open #{request_token.authorize_url} in your browser, authorize Retjilp, and enter the PIN code below:"
				verifier = STDIN.gets.chomp 

				begin
					@access_token = request_token.get_access_token(:oauth_verifier => verifier)
				rescue OAuth::Unauthorized
					raise "Invalid PIN verification!"
				end
				@user_info = verify_token(@access_token) or raise "Access token not authorized!"
				cached_access_token = @access_token
			end
			Retjilp::log.info("Logged in as #{@user_info["screen_name"]}")
		end

		protected
			def cached_access_token
				access_token = nil
				user_info = nil
				if File.exist?(ACCESS_TOKEN_FILENAME)
					Retjilp::log.info("Loading cached access token from #{ACCESS_TOKEN_FILENAME}")
					File.open(ACCESS_TOKEN_FILENAME) do |f|  
						begin 
							access_token_data = JSON.load(f)
							consumer = OAuth::Consumer.new(@consumer_key, @consumer_secret, { :site => TWITTER_URI })
							access_token = OAuth::AccessToken.new(consumer, access_token_data["token"], access_token_data["secret"])
							unless user_info = verify_token(access_token)
								Retjilp::log.warn("Cached token not authorized")
								access_token = nil
							end
						rescue JSON::ParserError 
							Retjilp::log.warn("Cached token does not parse")
						end
					end 
				end
				[access_token, user_info]
			end

			def cached_access_token=(access_token)
				Retjilp::log.info("Caching token in #{ACCESS_TOKEN_FILENAME}")
				File.open(ACCESS_TOKEN_FILENAME, 'w+') do |f|  
					access_token_data = { 
							"token" => access_token.token, 
							"secret" => access_token.secret 
					}
					JSON.dump(access_token_data, f)
				end
			end

		private
			# Helper method to verify the validity of an access token.
			# Returns the user info if the token verified correctly.
			def verify_token(token) 
				response = token.get("/#{API_VERSION}/account/verify_credentials.json")
				response.class == Net::HTTPOK ? JSON.parse(response.body) : nil
			end

		private 
			def get(url)
				full_url = "/#{API_VERSION}#{url}"
				Retjilp::log.debug("-> " + full_url)
				result = JSON.parse(@access_token.get("/#{API_VERSION}/#{url}").body)
				Retjilp::log.debug("<- " + JSON.pretty_generate(result))
				raise "Error fetching result: #{result.to_s}" if result.include? "errors"
				result
			end
	end
end
