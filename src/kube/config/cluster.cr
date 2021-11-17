require "json"
require "yaml"

module Kube
  class Config
    class Cluster
      include Kube::Config::Var

      property cluster : ClusterDef
      property name : String
      forward_missing_to @cluster

      def initialize(@cluster, @name); end
    end

    class ClusterDef
      include Kube::Config::Var

      @[JSON::Field(key: "certificate-authority")]
      @[YAML::Field(key: "certificate-authority")]
      property certificate_authority : String? = nil
      property server : String
      @[JSON::Field(key: "insecure-skip-tls-verify")]
      @[YAML::Field(key: "insecure-skip-tls-verify")]
      property insecure_skip_tls_verify : Bool = false

      def initialize(@certificate_authority, @server, @insecure_skip_tls_verify); end
    end
  end
end
