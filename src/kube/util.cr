# frozen_string_literal: true

module Kube
  # Miscellaneous helpers
  module Util
    PATH_TR_MAP = {'~' => "~0", '/' => "~1"}
    PATH_REGEX  = %r{(/|~(?!1))}
  end
end
