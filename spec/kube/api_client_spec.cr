require "../spec_helper"

describe Kube::ApiClient do
  it "should be able to create a new client" do
    client = Kube::ApiClient.new(new_transport, "v1")
    client.should be_a(Kube::ApiClient)
  end

  it "#api_resources" do
    client = Kube::ApiClient.new(new_transport, "v1")
    client.api_resources.should be_a(Array(K8S::Apimachinery::Apis::Meta::V1::APIResource))
  end
end
