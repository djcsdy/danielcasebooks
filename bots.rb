#!/usr/bin/env ruby

require 'twitter_ebooks'
require 'parseconfig'

config_file_name = "bots.conf"

unless File.exist? config_file_name then
  config_file = File.open(config_file_name, "w")
  config_file.write <<-END.gsub(/^[ \t]*/, "")
    [danielcasebooks]

    # Consumer details come from registering an app at https://dev.twitter.com/
    # OAuth details can be fetched with https://github.com/marcel/twurl

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
  
  interesting_tokens = nil
  
  bot.on_startup do
    model = Ebooks::Model.load("model/danielcassidy.model")
    
    interesting_tokens = model.keywords.
        top(100).
        map {|token| {text: token.text.downcase, score: token.percent}}.
        map {|token| {token[:text] => token}}.
        reduce({}) {|h,p| h.merge p}
  end

  bot.on_follow do |user|
    bot.follow user[:screen_name]
  end

  bot.on_mention do |tweet, meta|
    interestingness = compute_interestingness.call tweet
    
    if interestingness * rand > 1 then
      favorite(tweet)
    end
    
    # Avoid infinite reply chains.
    next if rand < 0.05
    
    reply(tweet, meta)
  end

  bot.on_timeline do |tweet, meta|
    # Reply to a tweet in the bot's timeline
    # bot.reply(tweet, meta[:reply_prefix] + "nice tweet")
  end

  bot.scheduler.every '1h' do
    # 1/6 chance of tweeting every hour
    if rand > (1.0/6.0) then
      bot.log "Decided not to tweet this hour."
    else
      bot.log "Will tweet some time this hour."
      
      # Tweet at a random moment during the hour
      bot.delay(rand(3600)) do
        text = model.make_statement
        bot.tweet text
        
        # 10% chance of tweeting a follow-on thought
        next if rand > 0.1
        
        bot.delay(rand(60)) do
          text = model.make_response text
          bot.tweet text
          
          # 10% chance of tweeting another follow-on thought
          next if rand > 0.1
          
          bot.delay(rand(60)) do
            text = model.make_response text
            bot.tweet text
          end
        end
      end
    end
  end
  
  compute_interestingness = Proc.new do |tweet|
    tokens = Ebooks::NLP.tokenize tweet[:text]
    tokens.
        select {|token| interesting_tokens[token]}.
        reduce(0) {|score, token| score + interesting_tokens[token][:score]}
  end

  def favorite(tweet)
    bot.log "Favoriting @#{tweet[:user][:screen_name]}: #{tweet[:text]}"
    
    bot.delay(4..30) do
      bot.twitter.favorite tweet[:id]
    end
  end
  
  def reply(tweet, meta)
    bot.delay(15..180) do
      response_text = model.make_response(meta[:mentionless], meta[:limit])
      bot.reply(tweet, meta[:reply_prefix] << response_text)
    end
  end
end
