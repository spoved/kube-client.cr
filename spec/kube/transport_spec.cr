require "../spec_helper"

Spectator.describe Kube::Transport do
  it "#config" do
    config = Kube::Config.from_yaml(File.read(EXAMPLE_CONFIG_PATH))
    trans = Kube::Transport.config(config)
    expect(trans).to be_a(Kube::Transport)
  end

  it "#version" do
    trans = new_transport
    expect(trans.version).to be_a(K8S::Apimachinery::Version::Info)
  end

  it "#get" do
    path = "api/v1/namespaces/default"
    trans = new_transport
    resp = trans.get(path)
    expect(resp).to_not be_nil
    expect(resp).to be_a(K8S::Api::Core::V1::Namespace)
  end

  it "#get list" do
    path = "api/v1/namespaces"
    trans = new_transport
    resp = trans.get(path)
    expect(resp).to_not be_nil
    expect(resp).to be_a(K8S::Api::Core::V1::NamespaceList)
    expect(resp.as(K8S::Api::Core::V1::NamespaceList).items).to be_a(Indexable(K8S::Api::Core::V1::Namespace))
  end

  it "#gets" do
    path = "api/v1/namespaces/default"
    trans = new_transport
    resp = trans.gets(path, path)
    expect(resp.size).to eq 2
    expect(resp).to all(be_a(K8S::Api::Core::V1::Namespace))
  end
end
