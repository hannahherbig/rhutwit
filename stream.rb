# a lot of this code was shamelessly stolen from rhuidean

require 'net/http'
require 'uri'
require 'logger'
require 'base64'
require 'json'
require 'yaml'
require 'openssl'

require 'hashie'

class Stream
    attr_reader :socket

    def initialize(config, &block)
        if config.kind_of? String
            config = Hashie::Mash.new(YAML.load_file(config))
        elsif config.kind_of? Hash
            config = Hashie::Mash.new(config)
        end

        @logger    = Logger.new($stderr)
        log.level  = Logger::DEBUG

        @sendq     = []
        @recvq     = []

        @config    = config

        @block     = block

        @connected = false
    end

    def connected?
        @connected
    end

    def log
        @logger
    end

    def parse
        while line = @recvq.shift
            line.chomp!

            log.debug("<- #{line.chomp}")

            if line[0] == "{" && line[-1] == "}"
                @block.call(Hashie::Mash.new(JSON(line)))
            end
        end
    end

    def io_loop
        uri = URI.parse("https://stream.twitter.com/1/statuses/filter.json")
        post_body = "follow=#{@config.users.join(',')}"

        http = Net::HTTP.new uri.host, uri.port
        http.use_ssl = true

        http.start do |http|
            req = Net::HTTP::Post.new(uri.path)
            req.basic_auth @config.username, @config.password
            http.request(req, post_body) do |res|
                res.read_body do |seg|
                    # This passes every "line" to our block, including the "\n".
                    seg.scan(/(.+\n?)/) do |line|
                        line = line[0]

                        # If the last line had no \n, add this one onto it.
                        if @recvq[-1] and @recvq[-1][-1].chr != "\n"
                            @recvq[-1] += line
                        else
                            @recvq << line
                        end
                    end

                    if @recvq[-1] and @recvq[-1][-1].chr == "\n"
                        parse
                    end
                end
            end
        end
    end
end
