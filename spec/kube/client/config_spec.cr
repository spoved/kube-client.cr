require "../../spec_helper"

describe Kube::Client::Config do
  config = Kube::Client::Config.read(TEST_KUBE_CONFIG_FILE)

  it "can be initialized from file" do
    config.should_not be_nil
    config.should be_a(Kube::Client::Config)
  end

  it "returns available contexts" do
    contexts = config.contexts
    contexts.should be_a(Array(String))
    contexts.empty?.should be_false
    contexts[0].should eq "mysql-test"
  end

  it "returns absolute file path" do
    dir = File.dirname(File.expand_path(TEST_KUBE_CONFIG_FILE))
    full_path = config._ext_file_path("test.file")
    full_path.should eq File.join(dir, "test.file")
  end

  it "returns absolute command path" do
    dir = File.expand_path("./")
    full_path = config._ext_command_path("curl")
    full_path.should eq File.join(dir, "curl")
  end

  it "fetches specific context" do
    res = config._fetch_context("mysql-test")
    res[:namespace].should be_nil
    res[:cluster].should_not be_nil
    res[:user].should_not be_nil

    res = config._fetch_context("token-test")
    res[:namespace].should_not be_nil
    res[:namespace].should eq "default"
    res[:cluster].should_not be_nil
    res[:user].should_not be_nil
  end

  it "fetches cluster ca data" do
    res = config._fetch_context("mysql-test")
    res[:cluster].should_not be_nil
    data = config._fetch_cluster_ca_data(res[:cluster].as(YAML::Any))
    data.should eq CA_DATA
  end

  it "fetches user cert data" do
    res = config._fetch_context("mysql-test")
    res[:user].should_not be_nil
    data = config._fetch_user_cert_data(res[:user].as(YAML::Any))
    data.should eq USER_CERT_DATA
  end

  it "fetches user key data" do
    res = config._fetch_context("mysql-test")
    res[:user].should_not be_nil
    data = config._fetch_user_key_data(res[:user].as(YAML::Any))
    data.should eq USER_KEY_DATA
  end

  it "returns namespace of context" do
    res = config._fetch_context("mysql-helper")
    res[:namespace].should eq "default"
  end
end
