require "spoved/api/client"
require "log"

module Kube
  class Client
    class Api < Spoved::Api::Client
      Log = ::Log.for(self)

      def initialize(
        @host : String, @port : Int32? = nil,
        @user : String? = nil, @pass : String? = nil,
        @scheme = "https", @api_path = "api/v1",
        tls_verify_mode = OpenSSL::SSL::VerifyMode::NONE
      )
        @tls_client = OpenSSL::SSL::Context::Client.new
        @tls_client.verify_mode = tls_verify_mode
      end
    end
  end
end
