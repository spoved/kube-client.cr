require "halite"
require "spoved/logger"
require "spoved/system_cmd"
require "../ext/*"
require "./transport"
require "./config"

# require "./client/*"

# TODO: Write documentation for `Kube::Client`
module Kube
  spoved_logger

  def self.client(**options) : Kube::Client
    Client.new(Transport.new(**options))
  end

  class Client
    spoved_logger
    private getter transport : Transport

    def initialize(@transport : Transport)
    end
  end
end
