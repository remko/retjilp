#!/usr/bin/env ruby

#
# Retjilp -- A Native Auto-retweet bot 
#
# Webpage: http://el-tramo.be/blog/retjilp
# Author: Remko Tronçon (http://el-tramo.be)
# License: BSD (see COPYING file)
#
# Usage: retjilp.rb [ --help ] [ --verbose | --debug ]
#
# See README for detailed usage instructions.
# 

require 'rubygems'
require 'oauth'
require 'json/pure'
require 'logger'

# Constants
TWITTER_URI = "http://api.twitter.com"

# Helper method to verify the validity of an access token
def verify_token(token) 
	response = token.get("/account/verify_credentials.json")
	response.class == Net::HTTPOK ? JSON.parse(response.body) : nil
end

# Initialize logger
log = Logger.new(STDERR)
log.level = Logger::WARN

# Parse arguments
ARGV.each do |a|
	if a == "-h" or a == "--help" 
		puts "Usage: retjilp.rb [ --help ] [ --verbose | --debug ]"
		exit 0
	elsif a == "--verbose"
		log.level = Logger::INFO
	elsif a == "--debug"
		log.level = Logger::DEBUG
	end
end

# Initialize data dir
log.info("Reading configuration file")
data_dir = File.expand_path("~/.retjilp")
config_filename = File.join(data_dir, "config")
access_token_filename = File.join(data_dir, "access_token")

# Read configuration file
begin
	config = File.open(config_filename) { |f| JSON.load(f) }
rescue JSON::ParserError => e
	log.fatal("Error parsing configuration file #{config_filename}: #{e}")
	exit -1
rescue
	log.fatal("Error loading configuration file #{config_filename}")
	exit -1
end

# Initialize the access token
access_token = nil
user_info = nil
if File.exist?(access_token_filename)
	# Try using the cached token
	log.info("Loading cached access token from #{access_token_filename}")
	File.open(access_token_filename) do |f|  
		begin 
			access_token_data = JSON.load(f)
			consumer = OAuth::Consumer.new(config["consumer_key"], config["consumer_secret"], { :site => TWITTER_URI })
			access_token = OAuth::AccessToken.new(consumer, access_token_data["token"], access_token_data["secret"])
			unless user_info = verify_token(access_token)
				log.warn("Cached token not authorized")
				access_token = nil
			end
		rescue JSON::ParserError 
			log.warn("Cached token does not parse")
		end
	end 
end

# Request the token if the cached access token does not exist
unless access_token
	if not STDIN.tty? 
		log.fatal("This script must be run interactively the first time to be able to authenticate.")
		exit -1
	end
	log.info("Requesting new access token")
	consumer = OAuth::Consumer.new(
		config["consumer_key"],
		config["consumer_secret"],
		:site => TWITTER_URI,
		:scheme => :header,
		:request_token_path => "/oauth/request_token",
		:authorize_path => "/oauth/authorize",
		:access_token_path => "/oauth/access_token",
		:http_method => :post)
	request_token = consumer.get_request_token(:oauth_callback => "oob")

	puts "Please open #{request_token.authorize_url} in your browser, authorize Retjilp, and enter the PIN code below:"
	verifier = STDIN.gets.chomp 

	begin
		access_token = request_token.get_access_token(:oauth_verifier => verifier)
	rescue OAuth::Unauthorized
		log.fatal("Invalid PIN verification!")
		exit -1
	end
	if user_info = verify_token(access_token)
		log.info("Caching token in #{access_token_filename}")
		File.open(access_token_filename, 'w+') do |f|  
			access_token_data = { 
					"token" => access_token.token, 
					"secret" => access_token.secret 
			}
			JSON.dump(access_token_data, f)
		end 
	else
		log.fatal("Access token not authorized!")
		exit -1
	end
end

log.info("Logged in as #{user_info["screen_name"]}")

# Get a list of retweeted ids
log.info("Fetching retweets")
retweets = JSON.parse(access_token.get("/statuses/retweeted_by_me.json?trim_user=true").body)
log.debug(JSON.pretty_generate(retweets))
if retweets.include? "error" :
	log.fatal("Error fetching retweets: #{retweets}")
	exit -1
end

retweeted_ids = retweets.map { |retweet| retweet["retweeted_status"]["id"] }.sort!

# Fetch the statuses
log.info("Fetching friends statuses")
if config["retweet_from_list"]
	status_uri = "/1/lists/statuses.json?slug=#{config["retweet_from_list"]}&owner_screen_name=#{user_info["screen_name"]}&include_rts=true"
else
	status_uri = "/statuses/home_timeline.json?trim_user=true"
end
status_uri += "&since_id=#{retweeted_ids[0]}" unless retweeted_ids.empty?
statuses = JSON.parse(access_token.get(status_uri).body)
log.debug(JSON.pretty_generate(statuses))
if statuses.include? "error" :
	log.fatal("Error fetching statuses: #{statuses.to_s}")
	exit -1
end

# Retweet statuses
statuses.each do |status|
	should_retweet = (config["match"].empty? or config["match"].any? { |match| 
		status["text"].downcase.include? match.downcase 
	})
	if should_retweet
		id_to_retweet = status.has_key?("retweeted_status") ? status["retweeted_status"]["id"] : status["id"]
		if retweeted_ids.include? id_to_retweet
			log.debug("Already retweeted: #{status["text"]}")
		else
			log.info("Retweeting: #{status["text"]}")
			result = access_token.post("/statuses/retweet/#{id_to_retweet}.json")
			result.class == Net::HTTPOK or log.error("Error retweeting #{result.body}")
		end
	end
end
