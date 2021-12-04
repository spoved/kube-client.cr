require "../spec_helper"

describe Kube::Transport do
  it "#config" do
    config = Kube::Config.from_yaml(File.read(EXAMPLE_CONFIG_PATH))
    trans = Kube::Transport.config(config)
    trans.should be_a(Kube::Transport)
  end

  it "#version" do
    trans = new_transport
    trans.version.should be_a(K8S::Apimachinery::Version::Info)
  end

  it "#get" do
    path = "api/v1/namespaces/default"
    trans = new_transport
    resp = trans.get(path)
    resp.should_not be_nil
    resp.should be_a(K8S::Api::Core::V1::Namespace)
  end

  it "#get list" do
    path = "api/v1/namespaces"
    trans = new_transport
    resp = trans.get(path)
    resp.should_not be_nil
    resp.should be_a(K8S::Api::Core::V1::NamespaceList)
    resp.as(K8S::Api::Core::V1::NamespaceList).items.should be_a(Array(K8S::Api::Core::V1::Namespace))
  end

  it "#gets" do
    path = "api/v1/namespaces/default"
    trans = new_transport
    resp = trans.gets(path, path)
    resp.size.should eq 2
    resp.each &.should(be_a(K8S::Api::Core::V1::Namespace))
  end
end
