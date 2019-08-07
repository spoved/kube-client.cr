require "../spec_helper"

private def new_helper
  HelperTest.new
end

load_cassette("Kube::Client") do
  describe Kube::Helper do
    it "has a client" do
      helper = new_helper

      helper.client.pods["items"].as_a.each do |pod|
        pod.should_not be_nil
      end
    end

    it "should be a Kube::Helper" do
      new_helper.should be_a(Kube::Helper)
    end
  end
end
