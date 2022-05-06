module Kube
  class Client
    VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
  end
end
