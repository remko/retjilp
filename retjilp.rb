#!/usr/bin/env ruby

require 'rubygems'
require 'oauth'
require 'json/pure'
require 'logger'

# Constants
twitter_uri = "http://api.twitter.com"

# Helper method
def verify_token(token) 
	return token.get("/account/verify_credentials.json").class == Net::HTTPOK
end

# Initialize logger
log = Logger.new(STDOUT)
log.level = Logger::WARN
ARGV.each do |a|
	if a == "-h" or a == "--help" 
		puts "Usage: retjilp.rb [ --verbose | --debug ]"
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
config_filename = data_dir + "/config"
access_token_filename = data_dir + "/access_token"

# Read configuration file
config = nil
begin
	File.open(config_filename) do |f|  
		config = JSON.load(f)
	end
rescue JSON::ParserError => e
	log.fatal("Error parsing configuration file " + config_filename + ": " + e)
	exit -1
rescue
	log.fatal("Error loading configuration file " + config_filename)
	exit -1
end

# Initialize the access token
access_token = nil
if File.exist?(access_token_filename) :
	# Try using the cached token
	log.info("Loading cached access token from " + access_token_filename)
	File.open(access_token_filename) do |f|  
		begin 
			access_token_data = JSON.load(f)
			consumer = OAuth::Consumer.new(config["consumer_key"], config["consumer_secret"], { :site => twitter_uri })
			access_token = OAuth::AccessToken.new(consumer, access_token_data["token"], access_token_data["secret"])
			if not verify_token(access_token)
				log.warn("Cached token not authorized")
				access_token = nil
			end
		rescue JSON::ParserError 
			log.warn("Cached token does not parse")
		end
	end 
end

# Request the token if the cached access token does not exist
if not access_token
	log.info("Requesting new access token")
	consumer = OAuth::Consumer.new(
		config["consumer_key"],
		config["consumer_secret"],
		:site => twitter_uri,
		:scheme => :header,
		:request_token_path => "/oauth/request_token",
		:authorize_path => "/oauth/authorize",
		:access_token_path => "/oauth/access_token",
		:http_method => :post)
	request_token = consumer.get_request_token(:oauth_callback => "oob")

	puts 'Please open ' + request_token.authorize_url + ' in your browser, authorize Retjilp, and enter the PIN code below:'
	verifier = gets.chomp 

	access_token = request_token.get_access_token(:oauth_verifier => verifier)
	if verify_token(access_token)
		log.info("Caching token in " + access_token_filename)
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

# Get a list of retweeted ids
log.info("Fetching retweets")
retweets = JSON.parse(access_token.get("/statuses/retweeted_by_me.json?trim_user=true").body)
log.debug(JSON.pretty_generate(retweets))
if retweets.include? "error" :
	log.fatal("Error fetching retweets: " + retweets)
	exit -1
end

retweeted_ids = Array.new
retweets.each { |retweet| 
	retweeted_ids.push(retweet["retweeted_status"]["id"])
}
retweeted_ids.sort!

# Fetch the statuses
log.info("Fetching friends statuses ...")
status_uri = "/statuses/friends_timeline.json?trim_user=true&include_rts=true"
if not retweeted_ids.empty? 
	status_uri += "&since_id=" + retweeted_ids[0].to_s
end 
statuses = JSON.parse(access_token.get(status_uri).body)
log.debug(JSON.pretty_generate(statuses))
if statuses.include? "error" :
	log.fatal("Error fetching statuses: " + statuses)
	exit -1
end

# Retweet statuses
statuses.each { |status|
	should_retweet = false
	config["match"].each { |match| 
		if status["text"].downcase.include? match.downcase
			should_retweet = true
		end
	}
	if should_retweet
		if retweeted_ids.include? status["id"]
			log.info("Already retweeted: " + status["text"])
		else
			log.info("Retweeting: " + status["text"])
			result = access_token.post("/statuses/retweet/" + status["id"].to_s + ".json")
			if result.class != Net::HTTPOK :
				log.error("Error retweeting" + result.body)
			end
		end
	end
}
