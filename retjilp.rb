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
require 'optparse'

# Constants
TWITTER_URI = "http://api.twitter.com"
API_VERSION = "1.1"

# Helper method to verify the validity of an access token.
# Returns the user info if the token verified correctly.
def verify_token(token) 
	response = token.get("/#{API_VERSION}/account/verify_credentials.json")
	response.class == Net::HTTPOK ? JSON.parse(response.body) : nil
end

# Initialize logger
class Logger
	def fatal_exit(msg)
		fatal(msg)
		exit -1
	end
end
log = Logger.new(STDERR)
log.formatter = proc { |severity, time, prog, msg| "#{severity}: #{msg}\n" }
log.level = Logger::WARN

# Parse arguments
begin
	OptionParser.new do |opts|
		opts.banner = "Usage: retjilp.rb [ --help ] [ --verbose | --debug ]"
		opts.on("--verbose", "Run with verbose output") { log.level = Logger::INFO }
		opts.on("--debug", "Run with debug output") { log.level = Logger::DEBUG }
		opts.on_tail("-h", "--help", "Show this help") { puts opts ; exit }
	end.parse!
rescue => e
	log.fatal_exit(e.message)
end

# Initialize data dir
log.info("Reading configuration file")
data_dir = File.expand_path("~/.retjilp")
config_filename = File.join(data_dir, "config")
access_token_filename = File.join(data_dir, "access_token")

# Read configuration file
begin
	config = File.open(config_filename) { |f| JSON.load(f) }
rescue => e
	log.fatal_exit("Error parsing configuration file #{config_filename}: #{e.message}")
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
	STDIN.tty? or log.fatal_exit("This script must be run interactively the first time to be able to authenticate.")
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
		log.fatal_exit("Invalid PIN verification!")
	end
	user_info = verify_token(access_token) or log.fatal_exit("Access token not authorized!")
	log.info("Caching token in #{access_token_filename}")
	File.open(access_token_filename, 'w+') do |f|  
		access_token_data = { 
				"token" => access_token.token, 
				"secret" => access_token.secret 
		}
		JSON.dump(access_token_data, f)
	end
end

log.info("Logged in as #{user_info["screen_name"]}")

# Get a list of retweeted ids
log.info("Fetching retweets")
retweets = JSON.parse(access_token.get("/#{API_VERSION}/statuses/user_timeline.json?trim_user=true&include_rts=true").body)
log.debug(JSON.pretty_generate(retweets))
not retweets.include? "error" or log.fatal_exit("Error fetching retweets: #{retweets}")

retweeted_ids = retweets.map { |retweet| retweet["retweeted_status"]["id"] }.sort!

# Fetch the statuses
log.info("Fetching friends statuses")
if config["retweet_from_list"]
	status_uri = "/#{API_VERSION}/lists/statuses.json?slug=#{config["retweet_from_list"]}&owner_screen_name=#{user_info["screen_name"]}&include_rts=true"
else
	status_uri = "/#{API_VERSION}/statuses/home_timeline.json?trim_user=true"
end
status_uri += "&since_id=#{retweeted_ids[0]}" unless retweeted_ids.empty?
statuses = JSON.parse(access_token.get(status_uri).body)
log.debug(JSON.pretty_generate(statuses))
not statuses.include? "error" or log.fatal_exit("Error fetching statuses: #{statuses.to_s}")

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
			result = access_token.post("/#{API_VERSION}/statuses/retweet/#{id_to_retweet}.json")
			result.class == Net::HTTPOK or log.error("Error retweeting #{result.body}")
		end
	end
end
