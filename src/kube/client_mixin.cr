module Kube
  module ClientMixin
    ENTITY_METHODS = %w[get watch delete create update patch json_patch merge_patch]

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

    DEFAULT_HEADERS = {
      "Content-Type" => "application/json",
      "Accept"       => "application/json",
    }

    DEFAULT_HTTP_PROXY_URI     = nil
    DEFAULT_HTTP_MAX_REDIRECTS = 10

    SEARCH_ARGUMENTS = {
      "labelSelector" => :label_selector,
      "fieldSelector" => :field_selector,
      "limit"         => :limit,
      "continue"      => :continue,
    }

    WATCH_ARGUMENTS = {
      "labelSelector"   => :label_selector,
      "fieldSelector"   => :field_selector,
      "resourceVersion" => :resource_version,
    }
  end
end
