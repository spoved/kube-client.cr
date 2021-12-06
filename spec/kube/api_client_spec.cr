require "../spec_helper"

Spectator.describe Kube::ApiClient do
  let(client) { Kube::ApiClient.new(new_transport, "v1") }

  it "should be able to create a new client" do
    expect(client).to be_a(Kube::ApiClient)
  end

  context "for the v1 API" do
    it "#api_resources" do
      expect(client.api_resources).to be_a(Array(::K8S::APIResource))
    end

    it "#list_resources" do
      resources = client.list_resources
      expect(resources).to_not be_empty
    end

    describe "#self.path" do
      it "returns the correct path" do
        expect(Kube::ApiClient.path("v1")).to eq "/api/v1"
      end
    end

    describe "#path" do
      it "returns the correct root path" do
        expect(client.path).to eq "/api/v1"
      end

      it "returns the correct resource path" do
        expect(client.path("tests")).to eq "/api/v1/tests"
      end
    end

    context "for URIs with a path prefix" do
      let(prefix_client) { Kube::ApiClient.new(Kube::Transport.new("http://localhost:8080/k8s/clusters/c-dnmgm"), "v1") }

      describe "#path" do
        it "returns the correct root path" do
          expect(prefix_client.path).to eq "/k8s/clusters/c-dnmgm/api/v1"
        end

        it "returns the correct resource path" do
          expect(prefix_client.path("tests")).to eq "/k8s/clusters/c-dnmgm/api/v1/tests"
        end
      end
    end

    describe "#api_resources" do
      it "returns array of APIResource" do
        resources = client.api_resources
        expect(resources).to be_a(Array(::K8S::APIResource))
        expect(resources.map(&.name).sort!).to eq ["bindings",
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
        expect(client.resource("pods").resource).to eq "pods"
      end
    end

    describe "#client_for_resource" do
      describe "for an invalid resource apiVersion" do
        # let(resource) { K8S::Resource.new(
        #   api_version: "test/v1",
        #   kind: "Test",
        # ) }

        it "raises error" do
          expect_raises Kube::Error::UndefinedResource, "Invalid apiVersion=test/v1 for v1 client" do
            client.client_for_resource(api_version: "test/v1", kind: "Test")
          end
        end
      end

      describe "for an invalid resource kind" do
        # let(resource) { K8S::Resource.new(
        #   api_version: "v1",
        #   kind: "Wtf",
        # ) }

        it "raises error" do
          expect_raises Kube::Error::UndefinedResource, "Unknown resource kind=Wtf for v1" do
            client.client_for_resource(api_version: "v1", kind: "Wtf")
          end
        end
      end
    end

    describe "#resources" do
      it "returns array of clients" do
        resources = client.resources
        expect(resources.is_a?(Array)).to be_true
        client.resources.each do |resource|
          expect(resource.is_a?(Kube::ResourceClient)).to be_true
        end
      end
    end
  end
end
