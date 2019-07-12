# kube-client [![Build Status](https://travis-ci.org/spoved/kube-client.cr.svg?branch=master)](https://travis-ci.org/spoved/kube-client.cr)

A very basic lib to communicate with kubernetes API.

Currently only supports very few resource types.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     kube-client:
       github: spoved/kube-client.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "kube-client"

client = Kube::Client.new
```

Can gather pods

```crystal
client.pods

client.pods(label_selector: {"component" => "helper"})
```

## Contributing

1. Fork it (<https://github.com/spoved/kube-client.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Holden Omans](https://github.com/kalinon) - creator and maintainer
