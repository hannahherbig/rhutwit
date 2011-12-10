VERSION = "0.3.0"

require 'logger'
require 'yaml'

require 'rhuidean'
require 'hashie'
require 'tweetstream'

def decode_text(str)
  {
    /\s+/ => ' ',
    '&' => '&amp;',
    '"' => '&quot;',
    "'" => '&apos;',
    '<' => '&lt;',
    '>' => '&gt;'
  }.each { |k, v| str.gsub!(k, v) }

  str
end

config = Hashie::Mash.new(YAML.load_file('config.yml'))

### IRC ###

client = IRC::Client.new do |c|
  c.server    = config.irc.server
  c.port      = config.irc.port
  c.password  = config.irc.password
  c.nickname  = config.irc.nickname
  c.username  = config.irc.username
  c.realname  = config.irc.realname

  c.logger    = Logger.new($stdout)
  c.log_level = :debug
end

client.on(IRC::Numeric::RPL_ENDOFMOTD) { client.join(config.irc.channel) }

client.thread = Thread.new { client.io_loop }

### twitter

TweetStream.configure do |c|
  c.consumer_key       = config.twitter.consumer_key
  c.consumer_secret    = config.twitter.consumer_secret
  c.oauth_token        = config.twitter.oauth_token
  c.oauth_token_secret = config.twitter.oauth_token_secret
  c.auth_method        = :oauth
  c.parser             = :yajl
end

stream = TweetStream.new

stream.follow(*config.twitter.users) do |o|
  p o

  o = Hashie::Mash.new(o)

  # get rid of all the possibilities
  next if o.entities.hashtags.map(&:text).map(&:downcase).include?("noirc")
  next unless o.user && o.text
  next unless config.twitter.users.include? o.user.id
  unless o.in_reply_to_user_id.nil?
    next unless config.twitter.users.include? o.in_reply_to_user_id
  end

  # special case for retweets
  unless o.retweeted_status.nil?
    rt = o.retweeted_status
    client.instance_eval do
      str  = "@#{o.user.screen_name}: RT @#{rt.user.screen_name}: "
      str += decode_text(rt.text)
      privmsg config.irc.channel, str
      write
    end
    next
  end

  # we're still here, go ahead and send it.
  client.instance_eval do
    str = "@#{o.user.screen_name}: #{decode_text(o.text)}"
    privmsg config.irc.channel, str
    write
  end
end

client.thread.join

