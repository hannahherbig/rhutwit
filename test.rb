$: << '.'

require 'yaml'
require 'hashie'
require 'stream'

config = Hashie::Mash.new(YAML.load_file('config.yml'))

stream = Stream.new(config.twitter) do |o|
  p o
end

stream.io_loop
