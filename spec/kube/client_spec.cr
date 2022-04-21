require "../spec_helper"

Spectator.describe Kube::Client do
  it "should be able to create a new client" do
    client = Kube::Client.new(new_transport)
    expect(client).to be_a Kube::Client
  end

  it "#api_groups" do
    client = Kube::Client.new(new_transport)
    groups = client.api_groups
    expect(groups).to_not be_nil
    expect(groups).to_not be_empty
    expect(groups).to contain("apps/v1")
  end

  it "#resources" do
    client = Kube::Client.new(new_transport)
    resources = client.resources
    expect(resources).to_not be_empty
  end

  it "#list_resources" do
    client = Kube::Client.new(new_transport)
    resources = client.list_resources
    expect(resources).to_not be_empty
    # expect(resources).to be_a Array(K8S::Kubernetes::Resource)
  end
end
