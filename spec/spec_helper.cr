require "spec"
require "../src/kube-client"

TEST_KUBE_CONFIG_TEMPLATE = "./spec/files/kube_config_template.yml"
TEST_KUBE_CONFIG_FILE     = "./spec/files/kube_config_test.yml"

def gen_kube_config_file
  temp = YAML.parse(File.read(TEST_KUBE_CONFIG_TEMPLATE))
  temp["clusters"].as_a[0]["cluster"].as_h[YAML::Any.new("server")] = YAML::Any.new(ENV["KUBE_API_SERVER"])
  temp["users"].as_a.each do |user|
    user["user"].as_h[YAML::Any.new("token")] = YAML::Any.new(Base64.strict_encode(ENV["KUBE_TOKEN"]))
  end
  File.open(TEST_KUBE_CONFIG_FILE, "w+") do |file|
    file.puts temp.to_yaml
  end
end

gen_kube_config_file

CA_DATA        = Base64.decode_string(CONFIGURE_YAML["clusters"].as_a[0]["cluster"]["certificate-authority-data"].as_s)
USER_CERT_DATA = Base64.decode_string(CONFIGURE_YAML["users"].as_a[2]["user"]["client-certificate-data"].as_s)
USER_KEY_DATA  = Base64.decode_string(CONFIGURE_YAML["users"].as_a[2]["user"]["client-key-data"].as_s)

CONFIGURE_YAML = YAML.parse(File.read(TEST_KUBE_CONFIG_FILE))
TEST_CLIENT    = Kube::Client.new(TEST_KUBE_CONFIG_FILE)

module Kube
  class Client
    class Config
      def _fetch_context(context_name)
        self.fetch_context(context_name)
      end

      def _ext_file_path(path)
        self.ext_file_path(path)
      end

      def _ext_command_path(path)
        self.ext_command_path(path)
      end

      def _fetch_cluster_ca_data(cluster)
        self.fetch_cluster_ca_data(cluster)
      end

      def _fetch_user_cert_data(user)
        self.fetch_user_cert_data(user)
      end

      def _fetch_user_key_data(user)
        self.fetch_user_key_data(user)
      end
    end
  end
end

def client
  TEST_CLIENT
end
