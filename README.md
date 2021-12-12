# kube-client

Crystal client library for the Kubernetes (1.11+) API

[![.github/workflows/ci.yml](https://github.com/spoved/kube-client.cr/actions/workflows/ci.yml/badge.svg)](https://github.com/spoved/kube-client.cr/actions/workflows/ci.yml) [![.github/workflows/docs.yml](https://github.com/spoved/kube-client.cr/actions/workflows/docs.yml/badge.svg)](https://github.com/spoved/kube-client.cr/actions/workflows/docs.yml) [![GitHub release](https://img.shields.io/github/release/spoved/kube-client.cr.svg)](https://github.com/spoved/kube-client.cr/releases) [![Chat on Telegram](https://img.shields.io/badge/chat-telegram-blue)](https://t.me/k8s_cr)

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     kube-client:
       github: spoved/kube-client.cr
   ```

2. Run `shards install`

## Usage

Specify the kubernetes api version of the client to use:

```crystal
require "kube-client/v1.20"

client = Kube::Client.autoconfig
```

Or you can specify the kubernetes api version at compile time via the `-Dk8s_v{major}.{minor}` flag:

```crystal
require "kube-client"

client = Kube::Client.autoconfig
```

```shell
$ crystal build -Dk8s_v1.20 kube-client.cr
```

### Overview

The top-level `Kube::Client` provides access to separate `APIClient` instances for each Kubernetes API Group (`v1`, `apps/v1`, etc.), which in turns provides access to separate `ResourceClient` instances for each API resource type (`nodes`, `pods`, `deployments`, etc.).

Individual resources are returned as `K8S::Resource` instances, which provide attribute access (`resource.metadata.name`). The resource instances are returned by methods such as `client.api("v1").resource("nodes").get("foo")`, and passed as arguments for `client.api("v1").resource("nodes").create_resource(res)`. Resources can also be loaded from disk using `Kube::Resource.from_files(path)`, and passed to the top-level methods such as `client.create_resource(res)`, which lookup the correct API/Resource client from the resource `apiVersion` and `kind`.

The different `Kube::Error::API` subclasses represent different HTTP response codes, such as `Kube::Error::NotFound` or `Kube::Error::Conflict`.

### Creating a client

#### Unauthenticated client

```crystal
client = Kube.client("https://localhost:6443", ssl_verify_peer: false)
```

The keyword options are [Kube::Transport::Options](src/kube/transport.cr) options.

#### Client from kubeconfig

```crystal
client = Kube::Client.config(
  Kube::Config.load_file(
    File.expand_path "~/.kube/config"
  )
)
```

#### Supported kubeconfig options

Not all kubeconfig options are supported, only the following kubeconfig options work:

- `current-context`
- `context.cluster`
- `context.user`
- `cluster.server`
- `cluster.insecure_skip_tls_verify`
- `cluster.certificate_authority`
- `cluster.certificate_authority_data`
- `user.client_certificate` + `user.client_key`
- `user.client_certificate_data` + `user.client_key_data`
- `user.token`

##### With overrides

```crystal
client = Kube::Client.config(Kube::Config.load_file("~/.kube/config"),
  server: "http://localhost:8001",
)
```

#### In-cluster client from pod envs/secrets

```crystal
client = Kube::Client.in_cluster_config
```

### API Resources

Resources are a sub class of `::K8S::Kubernetes::Resource`, which is generated and defined in the [k8s.cr](https://github.com/spoved/k8s.cr) sub-shard.

Please note that custom resources are not supported at this time.

### Prefetching API resources

Operations like mapping a resource `kind` to an API resource URL require knowledge of the API resource lists for the API group. Mapping resources for multiple API groups would require fetching the API resource lists for each API group in turn, leading to additional request latency. This can be optimized using resource prefetching:

```crystal
client.apis(prefetch_resources: true)
```

This will fetch the API resource lists for all API groups in a single pipelined request.

### Listing resources

```crystal
client.api("v1").resource("pods", namespace: "default").list(label_selector: {"role" => "test"}).each do |pod|
  pod = pod.as(K8S::Api::Core::V1::Pod)
  puts "namespace=#{pod.metadata!.namespace} pod: #{pod.metadata!.name} node=#{pod.spec.try &.node_name}"
end
```

### Updating resources

```crystal
node = client.api("v1").resource("nodes").get("test-node")
node.as(K8S::Api::Core::V1::Node).spec.not_nil!.unschedulable = true
client.api("v1").resource("nodes").update_resource(node)
```

### Deleting resources

```crystal
pod = client.api("v1").resource("pods", namespace: "default").delete("test-pod")
```

```crystal
pods = client.api("v1").resource("pods", namespace: "default").delete_collection(label_selector: {"role" => "test"})
```

### Creating resources

#### Programmatically defined resources

```crystal
pod = K8S::Api::Core::V1::Pod.new(
  metadata: ::K8S::ObjectMeta.new(
    name: name.nil? ? random_string(10) : name,
    namespace: "default",
    labels: {
      "app" => "kube-client-test",
    },
  ),
  spec: K8S::Api::Core::V1::PodSpec.new(
    containers: [
      K8S::Api::Core::V1::Container.new(
        name: "test",
        image: "test",
      ),
    ],
  )
)

logger.info "Create pod=#{pod.metadata!.name} in namespace=#{pod.metadata!.namespace}"

pod = client.api("v1").resource("pods").create_resource(pod)
```

#### From file(s)

```crystal
resources = K8S::Resource.from_file("./test.yaml")

resources = client.create_resource(resource)
```

### Patching resources

```crystal
client.api("apps/v1").resource("deployments", namespace: "default").merge_patch("test", {
    spec: { replicas: 3 },
})
```

### Watching resources

Watching resources is currently not supported.

## Contributing

1. Fork it (<https://github.com/spoved/kube-client.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am "Add some feature"`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Holden Omans](https://github.com/kalinon) - creator and maintainer
- [k8s-client](https://github.com/kontena/k8s-client) - Ruby client this was heavily sourced from
