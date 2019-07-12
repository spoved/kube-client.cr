module Kube
  class Client
    class Error < Exception
    end

    class Api
      class Error < Kube::Client::Error
      end
    end

    class Config
      class Error < Kube::Client::Error
      end

      class KeyError < Kube::Client::Config::Error
      end
    end
  end
end
