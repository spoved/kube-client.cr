require "json"
require "yaml"

module Kube
  class Config
    class User
      include Kube::Config::Var

      property name : String
      property user : UserDef
      forward_missing_to @user

      def initialize(@name, @user); end
    end

    class UserDef
      include Kube::Config::Var

      @[JSON::Field(key: "client-certificate")]
      @[YAML::Field(key: "client-certificate")]
      property client_certificate : String? = nil
      @[JSON::Field(key: "client-key")]
      @[YAML::Field(key: "client-key")]
      property client_key : String? = nil
      property password : String? = nil
      property username : String? = nil

      @[JSON::Field(key: "client-certificate-data")]
      @[YAML::Field(key: "client-certificate-data")]
      property client_certificate_data : String? = nil
      @[JSON::Field(key: "client-key-data")]
      @[YAML::Field(key: "client-key-data")]
      property client_key_data : String? = nil
      @[JSON::Field(key: "ca.crt")]
      @[YAML::Field(key: "ca.crt")]
      property ca_crt : String? = nil

      property token : String? = nil
      property exec : Exec? = nil

      def initialize(@client_certificate, @client_key, @password, @username, @client_certificate_data, @client_key_data, @ca_crt, @token, @exec); end

      class Exec
        include Kube::Config::Var

        @[JSON::Field(key: "apiVersion")]
        @[YAML::Field(key: "apiVersion")]
        property api_version : String
        property args : Array(String) = Array(String).new
        property command : String
        property env : Array(Env) = Array(Env).new
        @[JSON::Field(key: "provideClusterInfo")]
        @[YAML::Field(key: "provideClusterInfo")]
        property provide_cluster_info : Bool = false

        def initialize(@api_version, @args, @command, @env, @provide_cluster_info); end
      end

      class Env
        include Kube::Config::Var

        property name : String
        property value : String

        def initialize(@name, @value); end
      end
    end
  end
end
