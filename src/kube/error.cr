module Kube
  class Error < Exception
    class ExecutionError < Error
      def initialize(command, status)
        super("Command '#{command}' exited with status #{status}")
      end
    end

    class MissingEnv < Error
      def initialize(env)
        super("Environment variable #{env} is not set")
      end
    end

    class MissingConfig < Error
      def initialize(config)
        super("Configuration #{config} is not set")
      end
    end

    class API < Error
      @method : String
      @path : String
      @code : Int32
      @reason : String
      @status : K8S::Apimachinery::Apis::Meta::V1::Status?

      def self.new(method, path, code : HTTP::Status, status : K8S::Apimachinery::Apis::Meta::V1::Status)
        new(method, path, code, nil, status)
      end

      def initialize(@method, @path, code : HTTP::Status, reason : String?, @status = nil)
        @reason = reason || code.description || "Unknown"
        @code = code.code
        if @status
          super("#{@method} #{@path} => HTTP #{@code} #{@reason}: #{@status.not_nil!.message}")
        else
          super("#{@method} #{@path} => HTTP #{@code} #{@reason}")
        end
      end
    end
  end
end
