module Kube
  class Client
    class Config
      module AuthProvider
        def self.get_token(name, config)
          cmd = config["cmd-path"].as_s + " " + config["cmd-args"].as_s
          key_path = config["token-key"].as_s
          case name
          when "gcp"
            JSON.parse(`cmd`)["credential"]["access_token"].as_s
          else
            raise "Unsupported auth provider: #{name}"
          end
        end
      end
    end
  end
end
