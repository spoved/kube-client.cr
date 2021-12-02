require "../spec_helper"

describe Kube::Transport, focus: true do
  it "#config" do
    config = Kube::Config.from_yaml(File.read(EXAMPLE_CONFIG_PATH))
    trans = Kube::Transport.config(config)
    trans.should be_a(Kube::Transport)
    trans.version.should be_a(K8S::Apimachinery::Version::Info)
  end
end
