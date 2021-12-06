require "dotenv"
Dotenv.load(".env_test")

require "spectator"
require "../src/kube-client/v1.20"

Spectator.configure do |config|
  config.before_suite {
  # spoved_logger :trace, bind: true, clear: true
  }

  config.before_all do
    ENV["KUBECONFIG"] = ""
  end
end

TEST_KUBE_CONFIG_TEMPLATE = "./spec/files/kube_config_template.yml"
TEST_KUBE_CONFIG_FILE     = "./spec/files/kube_config_test.yml"

CA_DATA        = Base64.decode_string(CONFIGURE_YAML["clusters"].as_a[0]["cluster"]["certificate-authority-data"].as_s)
USER_CERT_DATA = Base64.decode_string(CONFIGURE_YAML["users"].as_a[0]["user"]["client-certificate-data"].as_s)
USER_KEY_DATA  = Base64.decode_string(CONFIGURE_YAML["users"].as_a[0]["user"]["client-key-data"].as_s)

CONFIGURE_YAML = YAML.parse(File.read(TEST_KUBE_CONFIG_FILE))

HASH_CONFIG = {
  "api_version" => "v1",
  "kind"        => "Config",
  "clusters"    => [
    {
      "cluster" => {
        "certificate_authority"      => nil,
        "certificate_authority_data" => nil,
        "server"                     => "https://0.0.0.0:52827",
        "insecure_skip_tls_verify"   => false,
      },
      "name" => "hash-test",
    },
  ],
  "contexts" => [
    {
      "name"    => "hash-test",
      "context" => {
        "cluster" => "hash-test",
        "user" => "admin@hash-test", "namespace" => nil,
      },
    },
  ],
  "current_context" => "hash-test",
  "preferences"     => Hash(String, String).new,
  "users"           => [
    {
      "name" => "admin@hash-test",
      "user" => {
        "client_certificate"      => nil,
        "client_key"              => nil,
        "password"                => nil,
        "username"                => nil,
        "client_certificate_data" => "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJrakNDQVRlZ0F3SUJBZ0lJUFVjMDZ0dS80U1l3Q2dZSUtvWkl6ajBFQXdJd0l6RWhNQjhHQTFVRUF3d1kKYXpOekxXTnNhV1Z1ZEMxallVQXhOak0yTkRnMU16VTFNQjRYRFRJeE1URXdPVEU1TVRVMU5Wb1hEVEl5TVRFdwpPVEU1TVRVMU5Wb3dNREVYTUJVR0ExVUVDaE1PYzNsemRHVnRPbTFoYzNSbGNuTXhGVEFUQmdOVkJBTVRESE41CmMzUmxiVHBoWkcxcGJqQlpNQk1HQnlxR1NNNDlBZ0VHQ0NxR1NNNDlBd0VIQTBJQUJGNzN6dUZGandWRytwS0gKbHd5MVkrS2ljeUd2WnB3NGliSmdIcytPU0VxUjhWRFR5SWVuN3ROUXVBUGZDZjd3c2FCWlJrbnZrUnpNamRqWQpvWUdBUW5xalNEQkdNQTRHQTFVZER3RUIvd1FFQXdJRm9EQVRCZ05WSFNVRUREQUtCZ2dyQmdFRkJRY0RBakFmCkJnTlZIU01FR0RBV2dCUUpjdmdGVk9BUkxIZ29Ud0VRWXBaMSt1ellyakFLQmdncWhrak9QUVFEQWdOSkFEQkcKQWlFQS9XTVFlVjlhWFRiOC9ra1E1czdqK09kSHEyZFlqMlNOYWkzSENkeFBpUzhDSVFEQ2NRK25WakNCQmg2NQpOUWNwQzVHRStjT09oMGNaTHdTVEJOdkpMczRoTkE9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCi0tLS0tQkVHSU4gQ0VSVElGSUNBVEUtLS0tLQpNSUlCZGpDQ0FSMmdBd0lCQWdJQkFEQUtCZ2dxaGtqT1BRUURBakFqTVNFd0h3WURWUVFEREJock0zTXRZMnhwClpXNTBMV05oUURFMk16WTBPRFV6TlRVd0hoY05NakV4TVRBNU1Ua3hOVFUxV2hjTk16RXhNVEEzTVRreE5UVTEKV2pBak1TRXdId1lEVlFRRERCaHJNM010WTJ4cFpXNTBMV05oUURFMk16WTBPRFV6TlRVd1dUQVRCZ2NxaGtqTwpQUUlCQmdncWhrak9QUU1CQndOQ0FBVE9SelZwT25GWjFZeTB6NEVJZFc1d1NZcUR6dzhmWEdORFBSWlFOM2h0CkU0L2FlcGM1RU4zdFBzMGdnOUgwYUlZQURXY1d3c3JJQ2srdllGWmVKTmhybzBJd1FEQU9CZ05WSFE4QkFmOEUKQkFNQ0FxUXdEd1lEVlIwVEFRSC9CQVV3QXdFQi96QWRCZ05WSFE0RUZnUVVDWEw0QlZUZ0VTeDRLRThCRUdLVwpkZnJzMks0d0NnWUlLb1pJemowRUF3SURSd0F3UkFJZ2FXdUtoOWxlWmdCUDJwQUhmZkVkRThmamk5TzVrQ0RJCkx4MnN4N2k4TjUwQ0lCNlE1Q3JHanEycGxOZjdMcU5jMjJpa3dtZ0pRT1kyNjE2QW5xQTBUaGcrCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K",
        "client_key_data"         => "LS0tLS1CRUdJTiBFQyBQUklWQVRFIEtFWS0tLS0tCk1IY0NBUUVFSU9mRnZSeHY4Ujltd2d0K0NPc2dGZDlWZFJFSjJxekdmWDg2SXN1SGlId1dvQW9HQ0NxR1NNNDkKQXdFSG9VUURRZ0FFWHZmTzRVV1BCVWI2a29lWERMVmo0cUp6SWE5bW5EaUpzbUFlejQ1SVNwSHhVTlBJaDZmdQowMUM0QTk4Si92Q3hvRmxHU2UrUkhNeU4yTmloZ1lCQ2VnPT0KLS0tLS1FTkQgRUMgUFJJVkFURSBLRVktLS0tLQo=",
        "ca_crt"                  => nil,
        "token"                   => nil,
        "exec"                    => nil,
        "auth_provider"           => nil,
      },
    },
  ],
}

EXAMPLE_CONFIG_PATH = File.expand_path("../files/kube_config_test.yml", __FILE__)

def new_transport(config : Kube::Config? = nil) : Kube::Transport
  config = config || Kube::Config.from_yaml(File.read(EXAMPLE_CONFIG_PATH))
  Kube::Transport.config(config)
end
