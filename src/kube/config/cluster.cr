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
      @[JSON::Field(key: "certificate-authority-data")]
      @[YAML::Field(key: "certificate-authority-data")]
      property certificate_authority_data : String? = nil

      property server : String
      @[JSON::Field(key: "insecure-skip-tls-verify")]
      @[YAML::Field(key: "insecure-skip-tls-verify")]
      property insecure_skip_tls_verify : Bool = false

      def initialize(@server, @certificate_authority = nil, @certificate_authority_data = nil, @insecure_skip_tls_verify = false); end
    end
  end
end
