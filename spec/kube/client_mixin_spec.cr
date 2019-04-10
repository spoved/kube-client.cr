require "../spec_helper"

describe Kube::ClientMixin do
  # TODO: Write tests

  it "has entity methods" do
    Kube::ClientMixin::ENTITY_METHODS.should_not be_nil
    Kube::ClientMixin::ENTITY_METHODS.should be_a(Array(String))
  end
end
