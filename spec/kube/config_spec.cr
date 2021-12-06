require "../spec_helper"

Spectator.describe Kube::Config do
  subject { Kube::Config }

  let(config) { subject.from_yaml(File.read(EXAMPLE_CONFIG_PATH)) }

  it "#from_yaml" do
    expect(config.clusters.size).to eq 1
    expect(config.context).to_not be_nil
    expect(config.context.name).to eq config.current_context
    expect(config.cluster).to be_a Kube::Config::Cluster
    expect(config.user).to be_a Kube::Config::User
  end

  it "#from_hash" do
    expect(Kube::Config.from_hash(HASH_CONFIG).to_h).to eq HASH_CONFIG
  end

  it "#merge" do
    conf1 = Kube::Config.from_yaml(File.read(EXAMPLE_CONFIG_PATH))
    conf2 = Kube::Config.from_hash(HASH_CONFIG)
    config = conf1.merge(conf2)
    expect(config.contexts.size).to eq 2
    expect(config.clusters.size).to eq 2
    expect(config.users.size).to eq 2
  end

  describe "#from_kubeconfig_env" do
    it "loads a single path" do
      ENV["KUBECONFIG"] = EXAMPLE_CONFIG_PATH
      config = Kube::Config.from_kubeconfig_env
      expect(config).to be_a Kube::Config
      expect(config.clusters.size).to eq 1
      expect(config.contexts.size).to eq 1
      expect(config.users.size).to eq 1
    end

    it "loads multiple paths" do
      tmp_file = File.tempfile(suffix: ".yaml")
      begin
        File.write(tmp_file.path, Kube::Config.from_hash(HASH_CONFIG).to_yaml)

        ENV["KUBECONFIG"] = EXAMPLE_CONFIG_PATH + ":" + tmp_file.path
        config = Kube::Config.from_kubeconfig_env
        expect(config).to be_a Kube::Config
        expect(config.clusters.size).to eq 2
        expect(config.contexts.size).to eq 2
        expect(config.users.size).to eq 2
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
