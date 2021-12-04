require "../spec_helper"

describe Kube::Client do
  it "should be able to create a new client" do
    client = Kube::Client.new(new_transport)
    client.should be_a(Kube::Client)
  end

  it "#api_groups" do
    client = Kube::Client.new(new_transport)
    groups = client.api_groups
    groups.should_not be_nil
    groups.should_not be_empty
    groups.includes?("apps/v1").should be_true
  end

  it "#resources" do
    client = Kube::Client.new(new_transport)
    resources = client.resources
    resources.should_not be_empty
  end
end
