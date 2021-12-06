require "../spec_helper"

describe Kube::ApiClient do
  it "should be able to create a new client" do
    client = Kube::ApiClient.new(new_transport, "v1")
    client.should be_a(Kube::ApiClient)
  end

  describe "for the v1 API" do
    client = Kube::ApiClient.new(new_transport, "v1")

    it "#api_resources" do
      client.api_resources.should be_a(Array(K8S::Apimachinery::Apis::Meta::V1::APIResource))
    end

    it "#list_resources", focus: true do
      resources = client.list_resources
      resources.should_not be_empty
    end

    describe "#self.path" do
      it "returns the correct path" do
        Kube::ApiClient.path("v1").should eq "/api/v1"
      end
    end

    describe "#path" do
      it "returns the correct root path" do
        client.path.should eq "/api/v1"
      end

      it "returns the correct resource path" do
        client.path("tests").should eq "/api/v1/tests"
      end
    end

    describe "for URIs with a path prefix" do
      prefix_client = Kube::ApiClient.new(Kube::Transport.new("http://localhost:8080/k8s/clusters/c-dnmgm"), "v1")

      describe "#path" do
        it "returns the correct root path" do
          prefix_client.path.should eq "/k8s/clusters/c-dnmgm/api/v1"
        end

        it "returns the correct resource path" do
          prefix_client.path("tests").should eq "/k8s/clusters/c-dnmgm/api/v1/tests"
        end
      end
    end

    describe "#api_resources" do
      it "returns array of APIResource" do
        resources = client.api_resources
        resources.should be_a(Array(K8S::Apimachinery::Apis::Meta::V1::APIResource))
        resources.map(&.name).sort!.should eq ["bindings",
                                               "componentstatuses",
                                               "configmaps",
                                               "endpoints",
                                               "events",
                                               "limitranges",
                                               "namespaces",
                                               "namespaces/finalize",
                                               "namespaces/status",
                                               "nodes",
                                               "nodes/proxy",
                                               "nodes/status",
                                               "persistentvolumeclaims",
                                               "persistentvolumeclaims/status",
                                               "persistentvolumes",
                                               "persistentvolumes/status",
                                               "pods",
                                               "pods/attach",
                                               "pods/binding",
                                               "pods/eviction",
                                               "pods/exec",
                                               "pods/log",
                                               "pods/portforward",
                                               "pods/proxy",
                                               "pods/status",
                                               "podtemplates",
                                               "replicationcontrollers",
                                               "replicationcontrollers/scale",
                                               "replicationcontrollers/status",
                                               "resourcequotas",
                                               "resourcequotas/status",
                                               "secrets",
                                               "serviceaccounts",
                                               "serviceaccounts/token",
                                               "services",
                                               "services/proxy",
                                               "services/status"].sort
      end
    end

    describe "#resource" do
      it "raises error for non-existing resource" do
        expect_raises Kube::Error::UndefinedResource, "Unknown resource wtfs for v1" do
          client.resource("wtfs")
        end
      end

      it "returns client for resource name" do
        client.resource("pods").resource.should eq "pods"
      end
    end

    describe "#client_for_resource" do
      describe "for an invalid resource apiVersion" do
        resource = K8S::Resource.new(
          api_version: "test/v1",
          kind: "Test",
        )

        it "raises error" do
          expect_raises Kube::Error::UndefinedResource, "Invalid apiVersion=test/v1 for v1 client" do
            client.client_for_resource(resource)
          end
        end
      end

      describe "for an invalid resource kind" do
        resource = K8S::Resource.new(
          api_version: "v1",
          kind: "Wtf",
        )

        it "raises error" do
          expect_raises Kube::Error::UndefinedResource, "Unknown resource kind=Wtf for v1" do
            client.client_for_resource(resource)
          end
        end
      end
    end

    describe "#resources" do
      it "returns array of clients" do
        resources = client.resources
        resources.is_a?(Array).should be_true
        client.resources.each do |resource|
          resource.is_a?(Kube::ResourceClient).should be_true
        end
      end
    end
  end
end
