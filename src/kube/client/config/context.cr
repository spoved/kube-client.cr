module Kube
  class Client
    class Config
      # Kubernetes client configuration context class
      class Context
        getter api_endpoint : String
        getter api_version : String
        getter ssl_options : String
        getter auth_options : String
        getter namespace : String

        def initialize(@api_endpoint, @api_version, @ssl_options, @auth_options, @namespace)
        end
      end
    end
  end
end
