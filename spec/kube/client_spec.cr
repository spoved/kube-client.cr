require "../spec_helper"
require "vcr"

load_cassette("Kube::Client") do
  describe Kube::Client do
    it "can load kubeconfig from env" do
      ENV["KUBECONFIG"] = TEST_KUBE_CONFIG_FILE
      c = Kube::Client.new
      c.should_not be_nil
      c.should be_a(Kube::Client)
      c.config.should be_a(Kube::Client::Config)
      c.context[:name].should eq "mysql-test"
      ENV["KUBECONFIG"] = nil
    end

    it "can load kubeconfig from file" do
      client.should_not be_nil
      client.should be_a(Kube::Client)
      client.config.should be_a(Kube::Client::Config)
      client.context.should_not be_nil
      client.context[:name].should eq "mysql-test"
    end

    it "can change contexts" do
      client.context[:name].should eq "mysql-test"
      client.change_context("mysql-helper")
      client.context[:name].should eq "mysql-helper"
    end

    it "gathers pods" do
      # client.change_context("mysql-helper")
      (client.pods["items"].as_a.size > 0).should be_truthy
    end

    it "selects pods based on label filter" do
      consul_pod = client.pods["items"].as_a.find { |i| i["metadata"]["name"].to_s =~ /consul/ }
      consul_pod.should_not be_nil

      consul_pod = client.pods(label_selector: {"app" => "mysqlha"})["items"].as_a.find { |i| i["metadata"]["name"].to_s =~ /consul/ }
      consul_pod.should be_nil
    end

    it "selects pods based on a complex label filter" do
      resp = client.pods(label_selector: {"app" => "mysqlha", "component" => "server"})
      resp["items"].as_a.size.should eq 3

      resp = client.pods(label_selector: {"app" => "mysqlha", "component" => "helper"})
      resp["items"].as_a.size.should eq 1
    end

    it "selects pods based on status" do
      resp = client.select_pods(status: "Running")
      resp.size.should eq 26
      resp = client.select_pods(status: "Terminating")
      resp.size.should eq 0
    end

    it "gathers nodes" do
      client.nodes["items"].as_a.size.should eq 3
    end
  end
end
