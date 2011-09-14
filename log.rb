require 'logger'
require 'rhuidean/loggable'

class Log
    include Loggable

    def initialize
        $logger ||= Logger.new($stdout)
        @logger = $logger
    end

    def method_missing(name, string)
        log(name, string) if Logger.instance_methods.include?(name)
    end
end

def log
    $log ||= Log.new
end

def logger
    $logger ||= Logger.new($stdout)
end
