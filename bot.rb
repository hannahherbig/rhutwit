VERSION = "0.2.4"

$: << '.'

require 'logger'
require 'yaml'
require 'abbrev'

require 'rhuidean'
require 'hashie'

require 'stream'
require 'log'

# There's only one config file now, config.yml. Rename example.yml to config.yml
# and then configure your bot.
config = Hashie::Mash.new(YAML.load_file('config.yml'))

client = IRC::Client.new do |c|
    c.server   = config.irc.server
    c.port     = config.irc.port
    c.password = config.irc.password
    c.nickname = config.irc.nickname
    c.username = config.irc.username
    c.realname = config.irc.realname

    c.logger       = logger
    c.log_level    = :debug
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
            str =  "@#{o.user.screen_name}: RT @#{rt.user.screen_name}: "
            str += rt.text.gsub(/\s+/, ' ')
            privmsg config.irc.channel, str
            write
        end
        next
    end

    # we're still here, go ahead and send it.
    client.instance_eval do
        privmsg config.irc.channel, "@#{o.user.screen_name}: #{o.text.gsub(/\s+/, ' ')}"
        write
    end
end

stream.io_loop
