# a lot of this code was shamelessly stolen from rhuidean

require 'socket'
require 'logger'
require 'base64'
require 'json'
require 'yaml'

require 'hashie'

class Stream
    attr_reader :socket

    def initialize(config, users, &block)
        @logger    = Logger.new($stderr)
        log.level  = Logger::DEBUG

        @sendq     = []

        @config    = Hashie::Mash.new(YAML.load_file(config))

        @users     = users

        @block     = block

        @headed    = true # whether or not we're receiving http headers
        @connected = false

        @auth      = Base64.encode64("#{@config.username}:#{@config.password}").chomp
    end

    def connected?
        @connected
    end

    def log
        @logger
    end

    def read
        line = readline.chomp

        if @headed
            if line.empty?
                @headed = false
            end
        elsif line[0] == "{"
            @block.call(Hashie::Mash.new(JSON(line)))
        end

        self
    end

    def readline
        line = ''
        line << @socket.recv(1) until line[-1] == "\n"

        log.debug("<- #{line.chomp}")

        line
    end

    def write
        # Use shift because we need it to fall off immediately.
        while line = @sendq.shift
            log.debug("-> #{line}")
            line += "\r\n"
            @socket.write(line)
        end
    end

    def io_loop
        loop do
            unless connected?
                connect

                @connected = true
            end

            writefd = [@socket] unless @sendq.empty?

            ret = IO.select([@socket], writefd)

            next unless ret

            read  unless ret[0].empty?
            write unless ret[1].empty?
        end
    end

    def raw(line = "")
        @sendq << line
    end

    def connect
        url = "http://stream.twitter.com/1/statuses/filter.json"
        @socket = TCPSocket.new("stream.twitter.com", 80)

        post_content = "delimited=length&follow=#{@users.join(',')}"
        #auth = SimpleOAuth::Header.new(:POST, url, @oauth)

        raw "POST /1/statuses/filter.json HTTP/1.1"
        raw "Host: stream.twitter.com"
        raw "Authorization: Basic #{@auth}"
        raw "Content-Type: application/x-www-form-urlencoded"
        raw "Content-Length: #{post_content.length}"
        raw
        raw post_content
        raw

        self
    end
end
