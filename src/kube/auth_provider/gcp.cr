require "../client"

module Kube::AuthProvider::GCP
  extend self

  spoved_logger
  include Spoved::SystemCmd

  def get_token(config : Kube::Config::UserDef::AuthProvider::Config)
    result = system_cmd(config.cmd_path, config.cmd_args)

    if result[:status]
      JSON.parse(result[:output])["credential"]["access_token"].as_s
    else
      logger.error { "Failed to get token from GCP with error: #{result[:error]}" }
      raise Kube::Error::ExecutionError.new(result[:error], result[:status])
    end
  end
end
