require "../client"

module Kube
  class Client
    module ServiceAccount
      NAMESPACE_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/namespace"
      TOKEN_PATH     = "/var/run/secrets/kubernetes.io/serviceaccount/token"

      def service_account
        namespace = File.read(NAMESPACE_PATH).chomp
        token = File.read(TOKEN_PATH).chomp
        kube_host = "https://kubernetes.#{namespace}.svc"

        conf_file = File.tempfile("config") do |file|
          conf = {
            "apiVersion"      => "v1",
            "kind"            => "Config",
            "current-context" => "default",
            "clusters"        => [
              {
                "name"    => "default",
                "cluster" => {
                  "api-version" => "v1",
                  "server"      => kube_host,
                },
              },
            ],
            "contexts" => [
              {
                "context" => {
                  "cluster" => "default",
                  "user"    => "default",
                },
                "name"      => "default",
                "namespace" => namespace,
              },
            ],
            "users" => [
              {
                "name" => "default",
                "user" => {
                  "token" => token,
                },
              },
            ],
          }
          file << conf.to_yaml
        end

        instance = Client.allocate
        instance.initialize(conf_file.path)
        instance
      end
    end
  end
end
