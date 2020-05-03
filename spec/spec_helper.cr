require "dotenv"
Dotenv.load(".env_test")

require "spec"
require "vcr"

require "../src/kube-client"

# Spoved.logger.level = Logger::DEBUG

TEST_KUBE_CONFIG_TEMPLATE = "./spec/files/kube_config_template.yml"
TEST_KUBE_CONFIG_FILE     = "./spec/files/kube_config_test.yml"

def gen_kube_config_file
  unless ENV["KUBE_TOKEN"]?
    ENV["KUBE_TOKEN"] = "eyJhbGciOiJSUzI1NiIsImtpZCI6Ik1YYkdlT3BOckFJNTB2U240MFUtZzdKUnVzaWY4Yy1YRG53TzAtZUdfRFEifQ" \
                        ".eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uY" \
                        "W1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJ" \
                        "kZWZhdWx0LXRva2VuLThzcmI3Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQub" \
                        "mFtZSI6ImRlZmF1bHQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJ" \
                        "mYmEyYzM0NC0zYzExLTQ4MGUtYmFkMS1jYmM2M2I3ZTQ3ZGMiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a" \
                        "3ViZS1zeXN0ZW06ZGVmYXVsdCJ9.qZNlSnERXx4sAP9-5GF1glGprtrocTIhCRsNi-EX3qvwGIqnWVJV87U3OsQnkg" \
                        "7cajVDOg0gpFiTW56lOFDhI8tJdwzfENqs51h_Zg_uO1c4A7QD8POKJP11yWFxWXsP3bAI-9XckKi5G8u1d5_4-cVn" \
                        "H2RTa9FpM9yPBNoRDKEGJZ3Lwtkr-tSw-CjknhbsYvFs2BV8gsUKQCOyQop4U7HZLrKZjYqcdWG-_2n7oW97jEicVp" \
                        "BZRAamuihbldfRTH8auhoaje76eg-pWfJTnm_WpriDCgO9ZvmKClz5JjOIMxM_BSzPXDvKLRQFqvJJiDK3BQxjOqVd" \
                        "2m-40xZIlQ"
  end

  ENV["KUBE_API_SERVER"] = "https://192.168.64.4:8443" unless ENV["KUBE_API_SERVER"]?

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

class HelperTest
  include Kube::Helper

  def initialize
    @client = TEST_CLIENT
  end
end

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
