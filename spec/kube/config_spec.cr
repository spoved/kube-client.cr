require "../spec_helper"

HASH_CONFIG = {
  "api_version" => "v1", "kind" => "Config", "clusters" => [
    {
      "cluster" => {
        "certificate_authority"    => nil,
        "server"                   => "https://0.0.0.0:52827",
        "insecure_skip_tls_verify" => false,
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
  "preferences" => Hash(String, String).new,
  "users" => [
    {
      "name" => "admin@hash-test",
      "user" => {
        "client_certificate" => nil,
        "client_key" => nil,
        "password" => nil,
        "username" => nil,
        "client_certificate_data" => "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJrakNDQVRlZ0F3SUJBZ0lJUFVjMDZ0dS80U1l3Q2dZSUtvWkl6ajBFQXdJd0l6RWhNQjhHQTFVRUF3d1kKYXpOekxXTnNhV1Z1ZEMxallVQXhOak0yTkRnMU16VTFNQjRYRFRJeE1URXdPVEU1TVRVMU5Wb1hEVEl5TVRFdwpPVEU1TVRVMU5Wb3dNREVYTUJVR0ExVUVDaE1PYzNsemRHVnRPbTFoYzNSbGNuTXhGVEFUQmdOVkJBTVRESE41CmMzUmxiVHBoWkcxcGJqQlpNQk1HQnlxR1NNNDlBZ0VHQ0NxR1NNNDlBd0VIQTBJQUJGNzN6dUZGandWRytwS0gKbHd5MVkrS2ljeUd2WnB3NGliSmdIcytPU0VxUjhWRFR5SWVuN3ROUXVBUGZDZjd3c2FCWlJrbnZrUnpNamRqWQpvWUdBUW5xalNEQkdNQTRHQTFVZER3RUIvd1FFQXdJRm9EQVRCZ05WSFNVRUREQUtCZ2dyQmdFRkJRY0RBakFmCkJnTlZIU01FR0RBV2dCUUpjdmdGVk9BUkxIZ29Ud0VRWXBaMSt1ellyakFLQmdncWhrak9QUVFEQWdOSkFEQkcKQWlFQS9XTVFlVjlhWFRiOC9ra1E1czdqK09kSHEyZFlqMlNOYWkzSENkeFBpUzhDSVFEQ2NRK25WakNCQmg2NQpOUWNwQzVHRStjT09oMGNaTHdTVEJOdkpMczRoTkE9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCi0tLS0tQkVHSU4gQ0VSVElGSUNBVEUtLS0tLQpNSUlCZGpDQ0FSMmdBd0lCQWdJQkFEQUtCZ2dxaGtqT1BRUURBakFqTVNFd0h3WURWUVFEREJock0zTXRZMnhwClpXNTBMV05oUURFMk16WTBPRFV6TlRVd0hoY05NakV4TVRBNU1Ua3hOVFUxV2hjTk16RXhNVEEzTVRreE5UVTEKV2pBak1TRXdId1lEVlFRRERCaHJNM010WTJ4cFpXNTBMV05oUURFMk16WTBPRFV6TlRVd1dUQVRCZ2NxaGtqTwpQUUlCQmdncWhrak9QUU1CQndOQ0FBVE9SelZwT25GWjFZeTB6NEVJZFc1d1NZcUR6dzhmWEdORFBSWlFOM2h0CkU0L2FlcGM1RU4zdFBzMGdnOUgwYUlZQURXY1d3c3JJQ2srdllGWmVKTmhybzBJd1FEQU9CZ05WSFE4QkFmOEUKQkFNQ0FxUXdEd1lEVlIwVEFRSC9CQVV3QXdFQi96QWRCZ05WSFE0RUZnUVVDWEw0QlZUZ0VTeDRLRThCRUdLVwpkZnJzMks0d0NnWUlLb1pJemowRUF3SURSd0F3UkFJZ2FXdUtoOWxlWmdCUDJwQUhmZkVkRThmamk5TzVrQ0RJCkx4MnN4N2k4TjUwQ0lCNlE1Q3JHanEycGxOZjdMcU5jMjJpa3dtZ0pRT1kyNjE2QW5xQTBUaGcrCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K", "client_key_data" => "LS0tLS1CRUdJTiBFQyBQUklWQVRFIEtFWS0tLS0tCk1IY0NBUUVFSU9mRnZSeHY4Ujltd2d0K0NPc2dGZDlWZFJFSjJxekdmWDg2SXN1SGlId1dvQW9HQ0NxR1NNNDkKQXdFSG9VUURRZ0FFWHZmTzRVV1BCVWI2a29lWERMVmo0cUp6SWE5bW5EaUpzbUFlejQ1SVNwSHhVTlBJaDZmdQowMUM0QTk4Si92Q3hvRmxHU2UrUkhNeU4yTmloZ1lCQ2VnPT0KLS0tLS1FTkQgRUMgUFJJVkFURSBLRVktLS0tLQo=", "ca_crt" => nil, "token" => nil, "exec" => nil,
      },
    },
  ],
}

EXAMPLE_CONFIG_PATH = File.expand_path("../../files/kube_config_test.yml", __FILE__)

describe Kube::Config do
  it "#from_yaml" do
    config = Kube::Config.from_yaml(File.read(EXAMPLE_CONFIG_PATH))
    config.clusters.size.should eq 1
    config.context.should_not be_nil
    config.context.name.should eq config.current_context
    config.cluster.should be_a Kube::Config::Cluster
    config.user.should be_a Kube::Config::User
  end

  it "#from_hash" do
    Kube::Config.from_hash(HASH_CONFIG).to_h.should eq HASH_CONFIG
  end

  it "#merge" do
    conf1 = Kube::Config.from_yaml(File.read(EXAMPLE_CONFIG_PATH))
    conf2 = Kube::Config.from_hash(HASH_CONFIG)
    config = conf1.merge(conf2)
    config.contexts.size.should eq 2
    config.clusters.size.should eq 2
    config.users.size.should eq 2
  end

  describe "#from_kubeconfig_env" do
    it "loads a single path" do
      ENV["KUBECONFIG"] = EXAMPLE_CONFIG_PATH
      config = Kube::Config.from_kubeconfig_env
      config.should be_a Kube::Config
      config.clusters.size.should eq 1
      config.contexts.size.should eq 1
      config.users.size.should eq 1
    end

    it "loads multiple paths" do
      tmp_file = File.tempfile(suffix: ".yaml")
      begin
        File.write(tmp_file.path, Kube::Config.from_hash(HASH_CONFIG).to_yaml)

        ENV["KUBECONFIG"] = EXAMPLE_CONFIG_PATH + ":" + tmp_file.path
        config = Kube::Config.from_kubeconfig_env
        config.should be_a Kube::Config
        config.clusters.size.should eq 2
        config.contexts.size.should eq 2
        config.users.size.should eq 2
      ensure
        tmp_file.delete
      end
    end

    describe "with missing file" do
      it "raises an error" do
        ENV["KUBECONFIG"] = "does-not-exist"
        expect_raises(Kube::Config::Error) do
          Kube::Config.from_kubeconfig_env
        end
      end
    end
  end
end
