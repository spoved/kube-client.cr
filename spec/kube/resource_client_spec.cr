require "../spec_helper"

Spectator.describe Kube::ResourceClient do
  def random_string(length)
    chars = ('a'..'z').to_a
    String.build(length) do |builder|
      length.times { builder << chars.sample }
    end
  end

  def pod_resource(name : String? = nil)
    K8S::Api::Core::V1::Pod.new(
      metadata: ::K8S::ObjectMeta.new(
        name: name.nil? ? random_string(10) : name,
        namespace: "default",
        labels: {
          "app" => "kube-client-test",
        },
      ),
      spec: K8S::Api::Core::V1::PodSpec.new(
        containers: [
          K8S::Api::Core::V1::Container.new(
            name: "test",
            image: "test",
          ),
        ],
      )
    )
  end

  let(transport) { new_transport }
  let(node_name) { "k3d-k3d-cluster-test-server-0" }

  context "for the nodes API" do
    let(api_client) { Kube::ApiClient.new(transport, "v1") }
    let(api_node) { ::K8S::APIResource.new(
      name: "nodes",
      singular_name: "",
      namespaced: false,
      kind: "Node",
      verbs: [
        "create",
        "delete",
        "deletecollection",
        "get",
        "list",
        "patch",
        "update",
        "watch",
      ],
      short_names: [
        "no",
      ]
    ) }
    subject { Kube::ResourceClient.new(transport, api_client, api_node).as(Kube::ResourceClient(K8S::Api::Core::V1::Node)) }

    describe "#path" do
      it "returns root path" do
        expect(subject.path(namespace: nil)).to eq "/api/v1/nodes"
      end

      it "returns a path to node" do
        expect(subject.path("testNode")).to eq "/api/v1/nodes/testNode"
      end

      it "returns a path to node subresource" do
        expect(subject.path("testNode", subresource: "proxy")).to eq "/api/v1/nodes/testNode/proxy"
      end
    end

    context "GET /api/v1/nodes" do
      describe "#list" do
        it "returns an array of resources" do
          list = subject.list

          expect(list).to be_a Indexable(K8S::Api::Core::V1::Node)
          expect(list).to be_a K8S::Kubernetes::Resource::ListWrapper(K8S::Api::Core::V1::Node)
          list.each do |node|
            expect(node).to be_a K8S::Api::Core::V1::Node
          end
          expect(list.map { |item| {
            kind:      item.kind,
            namespace: item.metadata!.namespace,
            name:      item.metadata!.name,
          } }).to match [
            {kind: "Node", namespace: nil, name: node_name},
          ]
        end
      end
    end

    context "GET /api/v1/nodes/*" do
      describe "#get" do
        it "returns a resource" do
          obj = subject.get(node_name)
          expect(obj).to be_a K8S::Kubernetes::Resource
          expect(obj).to be_a K8S::Api::Core::V1::Node
          expect(obj.kind).to eq "Node"
          expect(obj.metadata!.namespace).to be nil
          expect(obj.metadata!.name).to eq node_name
        end
      end
    end

    context "PATCH /api/v1/nodes/*" do
      after_each do
        subject.merge_patch(node_name, {spec: {unschedulable: false}})
      end

      let(resource) { K8S::Api::Core::V1::Node.new(
        metadata: ::K8S::ObjectMeta.new(
          name: node_name,
        ),
        spec: K8S::Api::Core::V1::NodeSpec.new(
          unschedulable: true,
        ),
      ) }

      describe "#merge_patch" do
        it "returns a resource" do
          expect(subject.patch?).to be_true
          obj = subject.merge_patch(node_name, {spec: {unschedulable: true}})
          expect(obj).to match K8S::Kubernetes::Resource
          expect(obj.kind).to eq "Node"
          expect(obj.metadata!.name).to eq node_name
          expect(obj.spec.try(&.unschedulable)).to be true
        end
      end
    end
  end

  context "for the nodes status API" do
    let(api_client) { Kube::ApiClient.new(transport, "v1") }
    let(api_node) { ::K8S::APIResource.new(
      name: "nodes/status",
      singular_name: "",
      namespaced: false,
      kind: "Node",
      verbs: [
        "get",
        "patch",
        "update",
      ],
    ) }
    subject { Kube::ResourceClient.new(transport, api_client, api_node).as(Kube::ResourceClient(K8S::Api::Core::V1::Node)) }

    describe "#path" do
      it "returns a path to node subresource" do
        expect(subject.path(node_name)).to eq "/api/v1/nodes/#{node_name}/status"
      end
    end

    # context "PUT /api/v1/nodes/*/status" do
    #   let(:resource) { K8S::Api::Core::V1::Node.new(
    #     kind: "Node",
    #     metadata: ::K8S::ObjectMeta.new(name: node_name),
    #     status: K8S::Api::Core::V1::NodeStatus.new(foo: "bar"),
    #   ) }

    #   describe "#update_resource" do
    #     it "returns a resource" do
    #       obj = subject.update_resource(resource)

    #       expect(obj).to match K8s::Resource
    #       expect(obj.kind).to eq "Node"
    #       expect(obj.metadata.name).to eq "test"
    #     end
    #   end
    # end
  end

  context "for the pods API" do
    let(api_client) { Kube::ApiClient.new(transport, "v1") }
    let(api_resource) { ::K8S::APIResource.new(
      name: "pods",
      singular_name: "",
      namespaced: true,
      kind: "Pod",
      verbs: [
        "create",
        "delete",
        "deletecollection",
        "get",
        "list",
        "patch",
        "update",
        "watch",
      ],
      short_names: [
        "po",
      ],
      categories: [
        "all",
      ]
    ) }

    subject { Kube::ResourceClient.new(transport, api_client, api_resource).as(Kube::ResourceClient(K8S::Api::Core::V1::Pod)) }

    before_each do
      begin
        subject.delete_collection(namespace: "default", label_selector: "app=kube-client-test")
      rescue Kube::Error::NotFound
      end
      sleep(0.2)
    end

    let(resource) { pod_resource }
    let(resource_list) { K8S::Kubernetes::ResourceList(K8S::Api::Core::V1::Pod).new(metadata: K8S::ListMeta.new, items: [resource]) }

    context "POST /api/v1/pods/namespaces/default/pods" do
      describe "#create_resource" do
        it "returns a resource" do
          r = pod_resource
          obj = subject.create_resource(r)

          expect(obj).to match K8S::Api::Core::V1::Pod
          expect(obj.kind).to eq "Pod"
          expect(obj.metadata!.namespace).to eq "default"
          expect(obj.metadata!.name).to eq r.metadata!.name
        end
      end
    end

    context "PATCH /api/v1/pods/namespaces/default/pods/test" do
      describe "#merge_patch" do
        it "returns a resource" do
          r = pod_resource
          subject.create_resource(r)
          sleep(0.2)
          obj = subject.merge_patch(r.metadata!.name, {spec: {activeDeadlineSeconds: 10}}, namespace: "default")

          expect(obj).to match K8S::Api::Core::V1::Pod
          expect(obj.kind).to eq "Pod"
          expect(obj.metadata!.namespace).to eq "default"
          expect(obj.metadata!.name).to eq r.metadata!.name
        end
      end
    end

    context "DELETE /api/v1/pods/*" do
      describe "#delete" do
        it "deletes a resource and returns it" do
          r = pod_resource
          subject.create_resource(r)
          sleep(0.2)
          obj = subject.delete(r.metadata!.name, namespace: "default")

          expect(obj).to match K8S::Api::Core::V1::Pod
          expect(obj.kind).to eq "Pod"
          expect(obj.metadata!.name).to eq r.metadata!.name
        end
      end

      describe "#delete_collection" do
        it "deletes resources and returns them" do
          r = pod_resource
          subject.create_resource(r)
          sleep(0.2)
          items = subject.delete_collection(namespace: "default", label_selector: "app=kube-client-test")

          expect(items).to match Indexable(K8S::Api::Core::V1::Pod)
          expect(items.map(&.kind)).to all eq "Pod"
          expect(items.map(&.metadata!.name)).to have r.metadata!.name
        end
      end
    end
  end
end
