$: << '.'

require 'logger'
require 'rhuidean'
require 'stream'

$client = IRC::Client.new do |c|
    c.server   = "127.0.0.1"
    c.port     = 6667

    # I can put the password here because you have to be on my vps to be able to
    # connect like this, and it doesn't give you anything awesome besides a
    # spoof anyways.
    c.password = 'twitter'

    c.nickname = c.username = c.realname = "twitter"

    c.logger       = Logger.new($stdout)
    c.log_level    = :debug
end

$users = [
    258302339, # fuckingterms - andrew's test account
    11724792,  # andrew12_
    14470078,  # rakaur
    14564948,  # sycobuny
    1361291,   # jufineath
    15278232,  # rintaun
    58240144,  # netz
    25096541,  # coreag (naki)
]

$client.on(IRC::Numeric::RPL_ENDOFMOTD) { $client.join("#malkier") }

$client.thread = Thread.new { $client.io_loop }

# I put the user/pass in a separate file so I could share the code easily.
stream = Stream.new("config.yml", $users) do |o|
    # get rid of all the possibilities
    next unless o.user && o.text
    next unless $users.include? o.user.id
    unless o.in_reply_to_user_id.nil?
        next unless $users.include? o.in_reply_to_user_id
    end

    # special case for retweets so that if the o.text's longer than 140
    # characters, we get the entire RT rather than it getting cut off.
    unless o.retweeted_status.nil?
        rt = o.retweeted_status
        $client.instance_eval do
            str =  "@#{o.user.screen_name}: RT @#{rt.user.screen_name}: "
            str += rt.text.gsub(/\s+/, ' ')
            privmsg "#malkier", str
            write
        end
        next
    end

    # we're still here, go ahead and send it.
    $client.instance_eval do
        privmsg "#malkier", "@#{o.user.screen_name}: #{o.text.gsub(/\s+/, ' ')}"
        write
    end
end

stream.io_loop
