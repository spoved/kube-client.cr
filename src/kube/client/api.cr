require "spoved/api/client"

module Kube
  class Client
    class Api < Spoved::Api::Client
      def initialize(
        @host : String, @port : Int32? = nil,
        @user : String? = nil, @pass : String? = nil,
        logger : Logger? = nil,
        @scheme = "https", @api_path = "api/v1",
        tls_verify_mode = OpenSSL::SSL::VerifyMode::NONE
      )
        @tls_client = OpenSSL::SSL::Context::Client.new
        @tls_client.verify_mode = tls_verify_mode
        if logger
          self.logger = logger
        end
      end
    end
  end
end
