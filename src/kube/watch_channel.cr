struct Kube::WatchChannel(T)
  @transport : Kube::Transport
  getter channel : Channel(::K8S::Kubernetes::WatchEvent(T) | Kube::Error::API)
  property resource_version : String?

  def initialize(@transport, @resource_version = nil)
    @channel = Channel(::K8S::Kubernetes::WatchEvent(T) | Kube::Error::API).new
  end

  delegate :close, :closed?, :receive, :receive?, :send, to: :channel
end
