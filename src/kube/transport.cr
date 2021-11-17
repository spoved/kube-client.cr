module Kube
  class Transport
    spoved_logger

    DEFAULT_SSL_OPTIONS = {
      :client_cert => nil,
      :client_key  => nil,
      :ca_file     => nil,
      :cert_store  => nil,
      :verify_ssl  => OpenSSL::SSL::VerifyMode::PEER,
    }

    DEFAULT_AUTH_OPTIONS = {
      :username          => nil,
      :password          => nil,
      :bearer_token      => nil,
      :bearer_token_file => nil,
    }

    DEFAULT_SOCKET_OPTIONS = {
      :socket_class     => nil,
      :ssl_socket_class => nil,
    }

    DEFAULT_TIMEOUTS = {
      # These do NOT affect watch, watching never times out.
      :open => HTTP::Client.new("127.0.0.1").open_timeout,
      :read => HTTP::Client.new("127.0.0.1").read_timeout,
    }

    # Default request headers
    REQUEST_HEADERS = {
      "Accept" => "application/json",
    }

    def self.token_from_auth_provider(user : Kube::Config::UserDef)
    end
  end
end
