VERSION = "0.2.4"

$: << '.'

require 'logger'
require 'yaml'
require 'abbrev'

require 'rhuidean'
require 'hashie'

require 'stream'
require 'log'

module NotCGI
  TABLE = {
    '&' => '&amp;', # first so the rest aren't escaped
    '"' => '&quot;',
    "'" => '&apos;',
    '<' => '&lt;',
    '>' => '&gt;'
  }

  def escape(string)
  string = string.dup

  TABLE.each do |k, v|
    string.gsub!(k, v)
  end

  string
  end

  def unescape(string)
  string = string.dup

  TABLE.each do |k, v|
    string.gsub!(v, k)
  end

  string
  end

  extend self
end

def decode_text(str)
  str.gsub!(/\s+/, ' ') # compress the whitespaces
  NotCGI.unescape(str)
end

# There's only one config file now, config.yml. Rename example.yml to config.yml
# and then configure your bot.
config = Hashie::Mash.new(YAML.load_file('config.yml'))

client = IRC::Client.new do |c|
  c.server    = config.irc.server
  c.port      = config.irc.port
  c.password  = config.irc.password
  c.nickname  = config.irc.nickname
  c.username  = config.irc.username
  c.realname  = config.irc.realname

  c.logger    = logger
  c.log_level = :debug
end

client.on(IRC::Numeric::RPL_ENDOFMOTD) { client.join(config.irc.channel) }

client.thread = Thread.new { client.io_loop }

stream = Stream.new(config.twitter) do |o|
  # get rid of all the possibilities
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

stream.io_loop
