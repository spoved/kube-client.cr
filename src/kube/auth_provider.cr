require "./auth_provider/*"

module Kube
  module AuthProvider
    extend self

    def get_token(name, config) : String
      # key_path = config["token-key"].as_s

      case name
      when "gcp"
        Kube::AuthProvider::GCP.get_token(config)
      else
        raise "Unsupported auth provider: #{name}"
      end
    end
  end
end
