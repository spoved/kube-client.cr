require "spec"
require "../src/kube-client"

Spoved.logger.level = Logger::DEBUG

TEST_KUBE_CONFIG_TEMPLATE = "./spec/files/kube_config_template.yml"
TEST_KUBE_CONFIG_FILE     = "./spec/files/kube_config_test.yml"

def gen_kube_config_file
  unless ENV["KUBE_TOKEN"]?
    ENV["KUBE_TOKEN"] = "eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRl" \
                        "cy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY" \
                        "291bnQvc2VjcmV0Lm5hbWUiOiJkZWZhdWx0LXRva2VuLThjZ2NiIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC" \
                        "9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImRlZmF1bHQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2U" \
                        "tYWNjb3VudC51aWQiOiIwZTA5YjliMS05NmI1LTExZTktOGY5My0wODAwMjc2MTJmYzgiLCJzdWIiOiJzeXN0ZW06c2Vy" \
                        "dmljZWFjY291bnQ6a3ViZS1zeXN0ZW06ZGVmYXVsdCJ9.BIp8V62G2sZJ8AnPUaJ22npfbkJSufimcK9DWqjEp_VtNut3" \
                        "1RQlK15VI7C4QPv2uwS65_GyLfIS5DI8E9kikHkM_nglvNkSTr63hSzJuyPZlDNopVC4NGi3BVJLMQUrcGU4ihjLiqeAS" \
                        "TvqQkiTb8CIfCbKLf4hyBsjBzf6tfQP4wdNRSjJrKUtuGzqKtwnyZQrqiYA-GA0GVifyhNYI9rTen_SRQJrv-S__aXVwO" \
                        "R7p263-n86iKnr7ZLxiJ_TlBVEW2BEs8bOQb1GjAH0doKoKEhWDWAhX19MRVebA9i47PvhBWbuRoxGXxCoKgeWkS901a4" \
                        "7SzfrTR7I8UQXDA"
  end

  ENV["KUBE_API_SERVER"] = "https://192.168.99.104:8443" unless ENV["KUBE_API_SERVER"]?

  temp = YAML.parse(File.read(TEST_KUBE_CONFIG_TEMPLATE))
  temp["clusters"].as_a[0]["cluster"].as_h[YAML::Any.new("server")] = YAML::Any.new(ENV["KUBE_API_SERVER"])
  temp["users"].as_a.each do |user|
    # user["user"].as_h[YAML::Any.new("token")] = YAML::Any.new(Base64.strict_encode(ENV["KUBE_TOKEN"]))
    user["user"].as_h[YAML::Any.new("token")] = YAML::Any.new(ENV["KUBE_TOKEN"])
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
