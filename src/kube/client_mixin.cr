module Kube
  module ClientMixin
    ENTITY_METHODS = %w[get watch delete create update patch json_patch merge_patch]

    DEFAULT_HEADERS = {
      "Content-Type" => "application/json",
      "Accept"       => "application/json",
    }

    DEFAULT_HTTP_PROXY_URI     = nil
    DEFAULT_HTTP_MAX_REDIRECTS = 10

    SEARCH_ARGUMENTS = {
      "labelSelector" => :label_selector,
      "fieldSelector" => :field_selector,
      "limit"         => :limit,
      "continue"      => :continue,
    }

    WATCH_ARGUMENTS = {
      "labelSelector"   => :label_selector,
      "fieldSelector"   => :field_selector,
      "resourceVersion" => :resource_version,
    }
  end
end
