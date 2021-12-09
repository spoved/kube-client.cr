require "./error"
require "./auth_provider/*"
require "./transport/*"
require "db/pool"
require "http"

module Kube
  class Transport
    spoved_logger

    class Error::ConnectionLost < ::DB::PoolResourceLost(HTTP::Client); end

    record PoolOptions, pool_capacity = 200, initial_pool_size = 20, pool_timeout = 0.1, sleep_time = 0.1

    alias Options = NamedTuple(
      client_cert: String?,
      client_key: String?,
      ssl_ca_file: String?,
      verify_ssl: OpenSSL::SSL::VerifyMode,
      auth_username: String?,
      auth_password: String?,
      auth_token: String?,
      auth_token_file: String?,
    )

    include Spoved::SystemCmd

    DEFAULT_SSL_OPTIONS = {
      client_cert: nil,
      client_key:  nil,
      ssl_ca_file: nil,
      verify_ssl:  OpenSSL::SSL::VerifyMode::PEER,
    }

    DEFAULT_AUTH_OPTIONS = {
      auth_username:   nil,
      auth_password:   nil,
      auth_token:      nil,
      auth_token_file: nil,
    }

    DEFAULT_SOCKET_OPTIONS = {
      socket_class:     nil,
      ssl_socket_class: nil,
    }

    DEFAULT_TIMEOUTS = {
      # These do NOT affect watch, watching never times out.
      open: nil,
      read: nil,
    }

    # Default request headers
    REQUEST_HEADERS = {
      "Accept" => "application/json",
    }

    property server : URI
    private property auth_token : String? = nil
    private property auth_username : String? = nil
    private property auth_password : String? = nil
    property options : Options = Options.new(**DEFAULT_AUTH_OPTIONS.merge(DEFAULT_SSL_OPTIONS))
    private getter ssl_contxt : OpenSSL::SSL::Context::Client
    private getter pool : DB::Pool(HTTP::Client)
    getter path_prefix : String

    def initialize(server : String, @auth_token : String? = nil, @auth_username : String? = nil, @auth_password : String? = nil, pool_options : PoolOptions = PoolOptions.new, **options)
      uri = URI.parse(server)
      @server = uri
      @path_prefix = File.join("/", uri.path, "/") # add leading and/or trailing slashes
      @options = Options.new(**DEFAULT_AUTH_OPTIONS.merge(DEFAULT_SSL_OPTIONS).merge(options))

      @ssl_contxt = OpenSSL::SSL::Context::Client.new
      @ssl_contxt.verify_mode = @options[:verify_ssl]
      @ssl_contxt.private_key = @options[:client_key].not_nil! unless @options[:client_key].nil?
      @ssl_contxt.certificate_chain = @options[:client_cert].not_nil! unless @options[:client_cert].nil?
      @ssl_contxt.ca_certificates = @options[:ssl_ca_file].not_nil! unless @options[:ssl_ca_file].nil?

      @pool = DB::Pool(HTTP::Client).new(max_pool_size: pool_options.pool_capacity, initial_pool_size: pool_options.initial_pool_size, checkout_timeout: pool_options.pool_timeout) do
        if @server.scheme == "https"
          HTTP::Client.new(uri: @server, tls: @ssl_contxt)
        else
          HTTP::Client.new(uri: @server)
        end
      end
    end

    private def using_connection
      self.pool.retry do
        self.pool.checkout do |conn|
          yield conn
        rescue ex : IO::Error | IO::TimeoutError
          logger.error { ex.message }
          logger.trace(exception: ex) { ex.message }
          raise Error::ConnectionLost.new(conn)
        end
      end
    end

    module ClassMethods
      include Spoved::SystemCmd

      def token_from_auth_provider(auth_provider : Kube::Config::UserDef::AuthProvider) : String
        case auth_provider.name
        when "gcp"
          Kube::AuthProvider::GCP.get_token(auth_provider.config)
        else
          raise "Unknown auth provider type: #{auth_provider.name}"
        end
      end

      # @raise [Kube::Error::ExecutionError] if the request fails
      def token_from_exec(conf : Kube::Config::UserDef::Exec) : String
        logger.debug { "Executing #{conf.command} #{conf.args.join(" ")}" }

        env = conf.env.to_h { |e| {e.name, e.value} }
        result = system_cmd(conf.command, conf.args, env)

        if result[:status]
          logger.debug { "Executed #{conf.command} #{conf.args.join(" ")} successfully" }
          token = JSON.parse(result[:output]).dig?("status", "token").try &.as_s

          if token.nil?
            raise Kube::Error::ExecutionError.new "Failed to get token from #{conf.command} #{conf.args.join(" ")}: #{result[:output]}", result[:status]
          end
          token
        else
          logger.error { "Executed #{conf.command} #{conf.args.join(" ")} with error #{result[:error]}" }
          raise Kube::Error::ExecutionError.new(result[:error], result[:status])
        end
      end

      # In-cluster config within a kube pod, using the kubernetes service envs and serviceaccount secrets
      # @raise [Kube::Error::MissingEnv] if the required env vars are not set
      def in_cluster_config(**options) : Kube::Transport
        host = ENV.fetch("KUBERNETES_SERVICE_HOST", "")
        raise Kube::Error::MissingEnv.new("KUBERNETES_SERVICE_HOST") if host.empty?
        port = ENV.fetch("KUBERNETES_SERVICE_PORT_HTTPS", "")
        raise Kube::Error::MissingEnv.new("KUBERNETES_SERVICE_PORT_HTTPS") if port.empty?

        new(
          "https://#{host}:#{port}",
          **options.merge({
            verify_ssl:  OpenSSL::SSL::VerifyMode::PEER,
            ssl_ca_file: File.join(ENV.fetch("TELEPRESENCE_ROOT", "/"), "var/run/secrets/kubernetes.io/serviceaccount/ca.crt"),
            auth_token:  File.read(File.join(ENV.fetch("TELEPRESENCE_ROOT", "/"), "var/run/secrets/kubernetes.io/serviceaccount/token")),
          }),
        )
      end

      # ameba:disable Metrics/CyclomaticComplexity
      def config(conf : Kube::Config, server : String? = nil, **overrides) : Kube::Transport
        server ||= conf.cluster.server
        raise Kube::Error::MissingConfig.new("server") if server.nil?

        options : Hash(Symbol, String | OpenSSL::SSL::VerifyMode | Nil) = Options.new(
          client_cert: nil,
          client_key: nil,
          ssl_ca_file: nil,
          verify_ssl: OpenSSL::SSL::VerifyMode::PEER,
          auth_username: nil,
          auth_password: nil,
          auth_token: nil,
          auth_token_file: nil,
        ).to_h

        if conf.cluster.insecure_skip_tls_verify
          logger.debug { "Using config with .cluster.insecure_skip_tls_verify" }
          options[:verify_ssl] = OpenSSL::SSL::VerifyMode::NONE
        end

        if path = conf.cluster.certificate_authority
          logger.debug { "Using config with .cluster.certificate_authority" }

          options[:ssl_ca_file] = path
        end

        if data = conf.cluster.certificate_authority_data
          logger.debug { "Using config with .cluster.certificate_authority_data" }
          tmpfile = File.tempfile("kube-client-ca")
          File.write(tmpfile.path, Base64.decode_string(data))
          options[:ssl_ca_file] = tmpfile.path
          at_exit { tmpfile.delete }
        end

        if (cert = conf.user.client_certificate) && (key = conf.user.client_key)
          logger.debug { "Using config with .user.client_certificate/client_key" }

          options[:client_cert] = cert
          options[:client_key] = key
        end

        if (cert_data = conf.user.client_certificate_data) && (key_data = conf.user.client_key_data)
          logger.debug { "Using config with .user.client_certificate_data/client_key_data" }

          crtfile = File.tempfile("kube-client-crt")
          File.write(crtfile.path, Base64.decode_string(cert_data))
          options[:client_cert] = crtfile.path
          at_exit { crtfile.delete }

          keyfile = File.tempfile("kube-client-crt")
          File.write(keyfile.path, Base64.decode_string(key_data))
          options[:client_key] = keyfile.path
          at_exit { keyfile.delete }
        end

        if token = conf.user.token
          logger.debug { "Using config with .user.token=..." }
          options[:auth_token] = token
        elsif conf.user.auth_provider && conf.user.auth_provider.not_nil!.config
          auth_provider = conf.user.auth_provider.not_nil!
          logger.debug { "Using config with .user.auth-provider.name=#{auth_provider.name}" }
          options[:auth_token] = token_from_auth_provider(auth_provider)
        elsif exec_conf = conf.user.exec
          logger.debug { "Using config with .user.exec.command=#{exec_conf.command}" }
          options[:auth_token] = token_from_exec(exec_conf)
        elsif conf.user.username && conf.user.password
          logger.debug { "Using config with .user.password=..." }

          options[:auth_username] = conf.user.username.not_nil!
          options[:auth_password] = conf.user.password.not_nil!
        end

        logger.info { "Using config with server=#{server}" }

        opts = Options.from(options).merge(overrides)

        new(server, **opts)
      end
    end

    extend ClassMethods
  end
end
