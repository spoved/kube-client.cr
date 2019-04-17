require "../client"

module Kube
  class Client
    module ServiceAccount
      NAMESPACE_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/namespace"
      TOKEN_PATH     = "/var/run/secrets/kubernetes.io/serviceaccount/token"

      # Will read the contents of the {NAMESPACE_PATH} file
      # @return [String] the namespace of the service account
      def read_namespace : String
        File.read(NAMESPACE_PATH).chomp
      rescue
        "default"
      end

      # Will read the contents of the {TOKEN_PATH} file
      # @return [String] the token for the service account
      def read_token : String
        File.read(TOKEN_PATH).chomp
      end

      # Will return the address for the kubernetes api
      # @return [String] the token for the service account
      def kube_address : String
        "https://kubernetes.#{read_namespace}.svc"
      end

      def service_account
        namespace = read_namespace
        token = read_token
        kube_host = kube_address

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
