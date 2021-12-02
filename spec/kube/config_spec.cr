require "../spec_helper"

describe Kube::Config do
  it "#from_yaml" do
    config = Kube::Config.from_yaml(File.read(EXAMPLE_CONFIG_PATH))
    config.clusters.size.should eq 1
    config.context.should_not be_nil
    config.context.name.should eq config.current_context
    config.cluster.should be_a Kube::Config::Cluster
    config.user.should be_a Kube::Config::User
  end

  it "#from_hash" do
    Kube::Config.from_hash(HASH_CONFIG).to_h.should eq HASH_CONFIG
  end

  it "#merge" do
    conf1 = Kube::Config.from_yaml(File.read(EXAMPLE_CONFIG_PATH))
    conf2 = Kube::Config.from_hash(HASH_CONFIG)
    config = conf1.merge(conf2)
    config.contexts.size.should eq 2
    config.clusters.size.should eq 2
    config.users.size.should eq 2
  end

  describe "#from_kubeconfig_env" do
    it "loads a single path" do
      ENV["KUBECONFIG"] = EXAMPLE_CONFIG_PATH
      config = Kube::Config.from_kubeconfig_env
      config.should be_a Kube::Config
      config.clusters.size.should eq 1
      config.contexts.size.should eq 1
      config.users.size.should eq 1
    end

    it "loads multiple paths" do
      tmp_file = File.tempfile(suffix: ".yaml")
      begin
        File.write(tmp_file.path, Kube::Config.from_hash(HASH_CONFIG).to_yaml)

        ENV["KUBECONFIG"] = EXAMPLE_CONFIG_PATH + ":" + tmp_file.path
        config = Kube::Config.from_kubeconfig_env
        config.should be_a Kube::Config
        config.clusters.size.should eq 2
        config.contexts.size.should eq 2
        config.users.size.should eq 2
      ensure
        tmp_file.delete
      end
    end

    describe "with missing file" do
      it "raises an error" do
        ENV["KUBECONFIG"] = "does-not-exist"
        expect_raises(Kube::Config::Error) do
          Kube::Config.from_kubeconfig_env
        end
      end
    end
  end
end
