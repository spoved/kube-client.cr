module Kube::AuthProvider::GCP
  extend self

  def get_token(config)
    cmd = config["cmd-path"].as_s + " " + config["cmd-args"].as_s
    JSON.parse(`#{cmd}`)["credential"]["access_token"].as_s
  end
end
