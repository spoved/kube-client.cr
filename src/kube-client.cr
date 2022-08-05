{% begin %}
  {% flag_provided = false %}
  {% for ver in (11..24) %}
    {% flag = :k8s_v1 + "." + "#{ver}" %}
    {% if flag?(flag) %}
      {% flag_provided = true %}
      require "./kube-client/v1.{{ver}}"
    {% end %}
  {% end %}
  {% unless flag_provided %}
    {% raise "No Kubernetes version flag provided. Provide flag or require a specific version: kube-client/{kube-api-version}" %}
  {% end %}
{% end %}
