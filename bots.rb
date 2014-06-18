#!/usr/bin/env ruby

require 'twitter_ebooks'
require 'parseconfig'

config_file_name = "bots.conf"

unless File.exist? config_file_name then
  config_file = File.open(config_file_name, "w")
  config_file.write <<-END.gsub(/^[ \t]*/, "")
    [danielcasebooks]

    # These details come from registering an app at https://dev.twitter.com/

    # Your app consumer key
    #consumer_key = ""

    # Your app consumer secret
    #consumer_secret = ""

    # Token connecting the app to this account
    #oauth_token = ""

    # Secret connecting the app to this account
    #oauth_token_secret = ""
  END
  config_file.close

  $stderr.puts "Created a new configuration file " << config_file_name << "."
  $stderr.puts "Edit " << config_file_name << " and try again."
  exit 1
end

begin
  config = ParseConfig.new(config_file_name)
rescue
  $stderr.puts "Invalid configuration file " << config_file_name << "."
  $stderr.puts "Edit " << config_file_name << " and try again."
  exit 2
end


Ebooks::Bot.new("danielcasebooks") do |bot|
  bot.consumer_key = config["danielcasebooks"]["consumer_key"]
  bot.consumer_secret = config["danielcasebooks"]["consumer_secret"]
  bot.oauth_token = config["danielcasebooks"]["oauth_token"]
  bot.oauth_token_secret = config["danielcasebooks"]["oauth_token_secret"]
  
  raise "Invalid consumer_key" unless bot.consumer_key
  raise "Invalid consumer_secret" unless bot.consumer_secret
  raise "Invalid oauth_token" unless bot.oauth_token
  raise "Invalid oauth_token_secret" unless bot.oauth_token_secret
  
  model = nil

  bot.on_startup do
    model = Model.load("model/danielcassidy.model")
  end

  bot.on_follow do |user|
    bot.follow user.screen_name
  end

  bot.on_mention do |tweet, meta|
    # Reply to a mention
    # bot.reply(tweet, meta[:reply_prefix] + "oh hullo")
  end

  bot.on_timeline do |tweet, meta|
    # Reply to a tweet in the bot's timeline
    # bot.reply(tweet, meta[:reply_prefix] + "nice tweet")
  end

  bot.scheduler.every '1h' do
    # 1/3 chance of tweeting up to three times per hour.
    num_tweets = rand(9) - 5
    
    bot.delay(rand(3600)) do
      num_tweets.times do
        bot.delay(rand(180)) do
          bot.tweet model.make_statement
        end
      end
    end
  end
end
