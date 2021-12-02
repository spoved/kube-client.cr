module Kube
  class Transport
    DELETE_OPTS_BODY_VERSION_MIN = SemanticVersion.parse("1.11.0")
    @need_delete_body : Bool = ::K8S::Kubernetes::VERSION < DELETE_OPTS_BODY_VERSION_MIN
    @version : K8S::Apimachinery::Version::Info? = nil

    def request_options(request_object = nil, content_type = "application/json", **options)
      headers = HTTP::Headers{
        "Content-Type" => content_type,
        "Accept"       => "application/json",
        "User-Agent"   => "kube-client.cr/#{Kube::Client::VERSION}",
      }

      if @auth_token
        headers["Authorization"] = "Bearer #{@auth_token}"
      elsif @auth_username && @auth_password
        headers["Authorization"] = "Basic #{Base64.strict_encode("#{@auth_username}:#{@auth_password}")}"
      end

      if request_object
        options.merge(
          headers: headers,
          body: request_object.to_json
        )
      else
        options.merge(
          headers: headers,
        )
      end
    end

    # @param options [Hash] as passed to Excon#request
    # @return [String]
    def format_request(options)
      method = options[:method]
      path = options[:path]
      body = nil

      # if options[:query]
      #   path += Excon::Utils.query_string(options)
      # end

      if obj = options[:request_object]?
        body = "<#{obj.class.name}>"
      end

      [method, path, body].compact.join " "
    end

    def parse_response(response, options, response_class = K8S::Kubernetes::Resource)
      method = options[:method]
      path = options[:path]
      content_type = response.headers["Content-Type"].split(';', 2).first

      if response.success?
        case content_type
        when "application/json"
          response_class.from_json(response.body)
        when "application/yaml"
          response_class.from_yaml(response.body)
        when "text/plain"
          response.body
        else
          raise Kube::Error::API.new(method, path, response.status, "Invalid response Content-Type: #{response.headers["Content-Type"]}")
        end
      else
        response_data = case content_type
                        when "application/json"
                          JSON.parse(response.body)
                        when "application/yaml"
                          YAML.parse(response.body)
                        when "text/plain"
                          response.body
                        else
                          raise Kube::Error::API.new(method, path, response.status, "Invalid response Content-Type: #{response.headers["Content-Type"]}")
                        end

        if (response_data.is_a?(JSON::Any) || response_data.is_a?(YAML::Any)) && response_data["kind"]? == "Status"
          raise Kube::Error::API.new(method, path, response.status, K8S::Apimachinery::Apis::Meta::V1::Status.from_json(response.body))
        else
          raise Kube::Error::API.new(method, path, response.status, response.body)
        end
      end
    end

    private def _request(options, req_options)
      using_connection do |client|
        client.exec(
          method: options[:method],
          path: options[:path],
          headers: req_options[:headers]?,
          body: req_options[:body]?,
        )
      end
    end

    def request(response_class = K8S::Kubernetes::Resource, **options)
      opts = options.to_h
      req_options = if opts[:method]? == "DELETE" && need_delete_body?
                      request_options(**options.merge({
                        request_object: opts.reject(:query),
                      }))
                    else
                      request_options(**options)
                    end

      t1 = Time.monotonic
      response = _request(options, req_options)
      # response = using_connection do |client|
      #   client.exec(
      #     method: options[:method],
      #     path: options[:path],
      #     headers: req_options[:headers]?,
      #     body: req_options[:body]?,
      #   )
      # end
      t = Time.monotonic - t1
      obj = parse_response(response, options, response_class: response_class)
    rescue ex
      logger.warn { "#{format_request(options)} => HTTP #{ex} in #{t}s" }
      logger.debug { "Request: #{options[:body]?}" } if options[:body]?
      logger.debug { "Response: #{response.body}" } unless response.nil?
      raise ex
    else
      logger.info { "#{format_request(options)} => HTTP #{response.status}: #{obj.inspect} in #{t}s" }
      logger.debug { "Request: #{options[:body]?}" } if options[:body]?
      logger.debug { "Response: #{response.body}" }
      obj
    end

    # Returns true if delete options should be sent as bode of the DELETE request
    def need_delete_body?
      @need_delete_body ||= ::K8S::Kubernetes::VERSION < DELETE_OPTS_BODY_VERSION_MIN
    end

    # @return [K8s::Resource]
    def version
      @version ||= get("/version", response_class: K8S::Apimachinery::Version::Info).as(K8S::Apimachinery::Version::Info)
    end

    def get(*path, **options)
      request(
        **options.merge({
          method: "GET",
          path:   self.path(*path),
        })
      )
    end

    def gets(*paths, **options)
      paths.map { |path| get(path, **options) }
    end

    def path(*path)
      if path.first == path_prefix
        File.join(path)
      else
        File.join(path_prefix, *path)
      end.gsub(%r{//}, "/")
    end
  end
end
