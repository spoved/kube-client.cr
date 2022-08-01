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

      if request_object.is_a?(::JSON::Serializable) || request_object.is_a?(NamedTuple) || request_object.is_a?(Hash) || request_object.is_a?(K8S::Kubernetes::Object)
        options.merge(
          headers: headers,
          body: request_object.to_json,
          query: options[:query]?,
        )
      else
        options.merge(
          headers: headers,
          query: options[:query]?,
        )
      end
    end

    def format_request(options)
      method = options[:method]
      path = options[:path]
      body = nil

      if obj = options[:request_object]?
        body = "<#{obj.class.name}>"
      end

      [method, path, body].compact.join " "
    end

    private def _parse_resp(method, path, response, content_type, response_class : T.class | Nil = nil) forall T
      case content_type
      when "application/json"
        if response_class
          response_class.from_json(response.body)
        else
          K8S::Kubernetes::Resource.from_json(response.body)
        end
      when "application/yaml"
        if response_class
          response_class.from_yaml(response.body)
        else
          K8S::Kubernetes::Resource.from_yaml(response.body)
          # YAML.parse(response.body)
        end
      when "text/plain"
        response.body
      else
        raise Kube::Error::API.new(method, path, response.status, "Invalid response Content-Type: #{content_type}")
      end
    rescue ex : JSON::SerializableError
      Log.error { "Invalid response: #{ex.message}" }
      Log.error { "Response: #{response.body}" }
      raise ex
    end

    def parse_response(response : HTTP::Client::Response, method : String, path : String, response_class : T.class | Nil = nil, **options) forall T
      content_type = response.headers["Content-Type"].split(';', 2).first

      if response.success?
        _parse_resp(method, path, response, content_type, response_class)
      else
        response_data = _parse_resp(method, path, response, content_type)

        if response_data.is_a?(K8S::Apimachinery::Apis::Meta::V1::Status)
          raise Kube::Error::API.new(method, path, response.status, response_data)
        elsif (response_data.is_a?(JSON::Any) || response_data.is_a?(YAML::Any)) &&
              (response_data["kind"]? == "Status" && response_data["apiVersion"]? == "v1")
          raise Kube::Error::API.new(method, path, response.status, K8S::Apimachinery::Apis::Meta::V1::Status.from_json(response.body))
        else
          raise Kube::Error::API.new(method, path, response.status, response.body)
        end
      end
    end

    # Format request path with query params
    private def _request_path(options, query : Hash(String, String | Array(String))? = nil) : String
      path = options[:path]

      unless query.nil?
        path += "?#{URI::Params.encode(query.as(Hash(String, String | Array(String))))}"
      end
      path
    end

    private def _request(options, req_options)
      using_connection do |client|
        logger.trace &.emit "#{format_request(options)}", options: options.inspect, req_options: req_options.inspect

        client.exec(
          method: options[:method],
          path: _request_path(options, req_options[:query]?),
          headers: req_options[:headers]?,
          body: req_options[:body]?,
        )
      end
    end

    def request(**options)
      request(**options, response_class: K8S::Kubernetes::Resource)
    end

    def watch_request(response_class : T, response_channel, **options) forall T
      req_options = request_options(**options)
      path = _request_path(options, req_options[:query]?)
      spawn _watch_request(response_class, response_channel, path, req_options)
    end

    def _watch_request(response_class : T, response_channel, path, req_options) forall T
      using_connection do |client|
        client.exec(method: "GET", path: path, headers: req_options[:headers]?) do |response|
          if response.success?
            io = response.body_io
            while !io.closed?
              raw_event = io.gets
              if raw_event
                event = response_class.from_json(raw_event)

                if response_channel.closed?
                  io.close
                  break
                end

                begin
                  response_channel.send(event)
                rescue ex : Channel::ClosedError
                  io.close unless io.closed?
                  break
                end
              end
            end
          else
            raise Kube::Error::API.new("GET", path, response.status, response.body)
          end
        end
      end
    rescue ex : Kube::Error::API
      response_channel.send(ex)
      response_channel.close
    rescue ex
      response_channel.close
      raise ex
    end

    def request(response_class : T.class, response_block : Proc? = nil, **options) forall T
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
      t = Time.monotonic - t1
      obj = parse_response(**options, response: response, response_class: response_class)
    rescue ex : K8S::Error::UnknownResource
      logger.warn { "#{format_request(options)} => HTTP #{ex} in #{t}s" }
      logger.debug { "Request: #{req_options}" } unless req_options.nil?
      logger.debug { "Response: #{response.body}" } unless response.nil?
      nil
    rescue ex
      logger.warn { "#{format_request(options)} => HTTP #{ex} in #{t}s" }
      logger.debug { "Request: #{req_options}" } unless req_options.nil?
      logger.debug { "Response: #{response.body}" } unless response.nil?
      raise ex
    else
      logger.debug { "Request: #{req_options}" } unless req_options.nil?
      logger.debug { "Response: #{response.body}" }
      logger.info { "#{format_request(options)} => HTTP #{response.status} in #{t}s" }
      logger.debug { "Response object: #{obj.inspect}" }
      obj
    end

    def requests(*options, skip_missing = false, skip_forbidden = false, retry_errors = true, skip_unknown = true, **common_options)
      requests(options, skip_missing, skip_forbidden, retry_errors, skip_unknown, **common_options)
    end

    def requests(options : Enumerable(W), skip_missing = false, skip_forbidden = false, retry_errors = true, skip_unknown = true,
                 **common_options) forall W
      t1 = Time.monotonic
      req_options = request_options(**common_options)
      responses = options.map { |opts| _request(opts, req_options) }

      t = Time.monotonic - t1

      objects = responses.zip(options).map do |response, request_options|
        begin
          parse_response(**request_options.merge({response: response}))
        rescue e : Kube::Error::UndefinedResource | K8S::Error::UnknownResource
          raise e unless skip_unknown
          nil
        rescue e : Kube::Error::NotFound
          raise e unless skip_missing
          nil
        rescue e : Kube::Error::Forbidden
          raise e unless skip_forbidden
          nil
        rescue e : Kube::Error::ServiceUnavailable
          raise e unless retry_errors
          logger.warn { "Retry #{format_request(request_options)} => HTTP #{e.code} #{e.reason} in #{t}" }
          # only retry the failed request, not the entire pipeline
          request(**common_options.merge(request_options))
        end
      end
    rescue e : Kube::Error::API
      logger.warn { "[#{options.map { |o| format_request(o) }.join ", "}] => HTTP #{e.code} #{e.reason} in #{t}" }
      raise e
    else
      logger.info { "[#{options.map { |o| format_request(o) }.join ", "}] => HTTP [#{responses.map(&.status).join ", "}] in #{t}" }
      objects
    end

    # Returns true if delete options should be sent as bode of the DELETE request
    def need_delete_body? : Bool
      @need_delete_body ||= ::K8S::Kubernetes::VERSION < DELETE_OPTS_BODY_VERSION_MIN
    end

    def version : K8S::Apimachinery::Version::Info
      @version ||= get("/version", response_class: K8S::Apimachinery::Version::Info).as(K8S::Apimachinery::Version::Info)
    end

    def get(*path)
      get(*path, response_class: K8S::Kubernetes::Resource)
    end

    def get(*path, response_class : T.class, **options) forall T
      request(
        **options.merge({
          method:         "GET",
          path:           self.path(*path),
          response_class: response_class,
        })
      )
    end

    def gets(paths : Array(String), response_class : T.class, **options) forall T
      requests(
        paths.map { |path|
          {
            method: "GET",
            path:   self.path(path),
          }
        },
        **options.merge({
          response_class: response_class,
        })
      )
    end

    def gets(*paths)
      gets(*paths, response_class: K8S::Kubernetes::Resource)
    end

    def gets(*paths, response_class : T.class, **options) forall T
      requests(
        *paths.map { |path|
          options.merge({
            method: "GET",
            path:   self.path(path),
          })
        },
        **options.merge({
          response_class: response_class,
        })
      )
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
