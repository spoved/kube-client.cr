struct Kube::WatchChannel(T)
  @transport : Kube::Transport
  getter channel : Channel(::K8S::Kubernetes::WatchEvent(T) | Kube::Error::API)

  def initialize(@transport)
    @channel = Channel(::K8S::Kubernetes::WatchEvent(T) | Kube::Error::API).new
  end

  delegate :close, :closed?, :receive, :receive?, to: :channel
end
