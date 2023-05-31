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

    class UndefinedResource < Error; end

    class ArgumentError < Error; end

    HTTP_STATUS_ERRORS = {
      400 => BadRequest,
      401 => Unauthorized,
      403 => Forbidden,
      404 => NotFound,
      405 => MethodNotAllowed,
      409 => Conflict,
      422 => Invalid,
      429 => Timeout,
      500 => InternalError,
      503 => ServiceUnavailable,
      504 => ServerTimeout,
    }

    class API < Error
      getter method : String
      getter path : String
      getter code : Int32
      getter reason : String
      getter status : K8S::Apimachinery::Apis::Meta::V1::Status?

      private macro create_subclass
        case code.code
        {% for code, name in HTTP_STATUS_ERRORS %}
        when {{code}}, "{{code}}"
          {{name}}.new(method, path, code, nil, status)
        {% end %}
        else
          new(method, path, code, nil, status)
        end
      end

      def self.new(method, path, code : HTTP::Status, status : K8S::Apimachinery::Apis::Meta::V1::Status)
        create_subclass
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

    class WatchClosed < API
      getter resource_version : String?

      def initialize(method, path, code : HTTP::Status, reason : String?, status = nil, @resource_version : String? = nil)
        super(method, path, code, reason, status)
      end
    end

    macro define_api_errors
      {% for code, name in HTTP_STATUS_ERRORS %}
      class {{name}} < API
        def initialize(method, path, code, reason, status)
          super(method, path, code, reason, status)
        end
      end
      {% end %}
    end

    define_api_errors
  end
end
