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

      @[JSON::Field(key: "auth-provider")]
      @[YAML::Field(key: "auth-provider")]
      property auth_provider : AuthProvider? = nil

      def initialize(@client_certificate = nil, @client_key = nil, @password = nil, @username = nil,
                     @client_certificate_data = nil, @client_key_data = nil, @ca_crt = nil,
                     @token = nil, @exec = nil, @auth_provider = nil); end

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

      class AuthProvider
        include Kube::Config::Var

        property name : String
        property config : AuthProvider::Config

        def initialize(@name, @config); end

        class Config
          include Kube::Config::Var

          @[JSON::Field(key: "access-token")]
          @[YAML::Field(key: "access-token")]
          property access_token : String? = nil
          @[JSON::Field(key: "access-token-file")]
          @[YAML::Field(key: "access-token-file")]
          property access_token_file : String? = nil
          @[JSON::Field(key: "cmd-args")]
          @[YAML::Field(key: "cmd-args")]
          property cmd_args : Array(String) = Array(String).new
          @[JSON::Field(key: "cmd-path")]
          @[YAML::Field(key: "cmd-path")]
          property cmd_path : String
          property expiry : String? = nil
          @[JSON::Field(key: "expiry-key")]
          @[YAML::Field(key: "expiry-key")]
          property expiry_key : String? = nil
          @[JSON::Field(key: "token-key")]
          @[YAML::Field(key: "token-key")]
          property token_key : String? = nil

          def initialize(@access_token, @access_token_file, @cmd_args, @cmd_path, @expiry, @expiry_key, @token_key); end
        end
      end
    end
  end
end
