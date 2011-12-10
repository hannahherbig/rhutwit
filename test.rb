require 'yaml'

require 'hashie'
require 'tweetstream'

config = Hashie::Mash.new(YAML.load_file('config.yml'))

p config

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
end
