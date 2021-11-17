require "json"
require "yaml"

module Kube
  class Config
    class Context
      include Kube::Config::Var

      property name : String
      property context : ContextDef
      forward_missing_to @context

      def initialize(@name, @context); end
    end

    class ContextDef
      include Kube::Config::Var

      property cluster : String
      property user : String
      property namespace : String? = nil

      def initialize(@cluster, @user, @namespace); end
    end
  end
end
