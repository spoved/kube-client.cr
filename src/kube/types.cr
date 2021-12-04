module Kube
  # NamespacedName comprises a resource name, with a mandatory namespace,
  # rendered as "<namespace>/<name>".  Being a type captures intent and
  # helps make sure that UIDs, namespaced names and non-namespaced names
  # do not get conflated in code.  For most use cases, namespace and name
  # will already have been format validated at the API entry point, so we
  # don't do that here.
  struct NamespacedName
    property namespace : String
    property name : String

    def initialize(namespace, name)
      @namespace = namespace
      @name = name
    end

    def new(namespace_name : String)
      namespace, name = namespace_name.split('/', 2)
      self.class.new(namespace, name)
    end

    def to_s(io)
      io << namespace << '/' << name
    end
  end

  # These are constants to support HTTP PATCH utilized by
  # both the client and server that didn't make sense for a whole package to be
  # dedicated to.
  enum PatchType
    JSON
    Merge
    StrategicMerge
    Apply

    def self.to_s(io)
      case self
      when JSON
        io << "application/json"
      when Merge
        io << "application/merge-patch+json"
      when StrategicMerge
        io << "application/strategic-merge-patch+json"
      when Apply
        io << "application/apply-patch+yaml"
      end
    end
  end

  # UID is a type that holds unique ID values, including UUIDs.  Because we
  # don't ONLY use UUIDs, this is an alias to string.  Being a type captures
  # intent and helps make sure that UIDs and names do not get conflated.
  struct UID
    property value : String
    forward_missing_to @value

    def initialize(@value); end
  end

  # NodeName is a type that holds a api.Node's Name identifier.
  # Being a type captures intent and helps make sure that the node name
  # is not confused with similar concepts (the hostname, the cloud provider id,
  # the cloud provider name etc)
  #
  # To clarify the various types:
  #
  # * Node.Name is the Name field of the Node in the API.  This should be stored in a NodeName.
  #   Unfortunately, because Name is part of ObjectMeta, we can't store it as a NodeName at the API level.
  #
  # * Hostname is the hostname of the local machine (from uname -n).
  #   However, some components allow the user to pass in a --hostname-override flag,
  #   which will override this in most places. In the absence of anything more meaningful,
  #   kubelet will use Hostname as the Node.Name when it creates the Node.
  #
  # * The cloudproviders have the own names: GCE has InstanceName, AWS has InstanceId.
  #
  #   For GCE, InstanceName is the Name of an Instance object in the GCE API.  On GCE, Instance.Name becomes the
  #   Hostname, and thus it makes sense also to use it as the Node.Name.  But that is GCE specific, and it is up
  #   to the cloudprovider how to do this mapping.
  #
  #   For AWS, the InstanceID is not yet suitable for use as a Node.Name, so we actually use the
  #   PrivateDnsName for the Node.Name.  And this is _not_ always the same as the hostname: if
  #   we are using a custom DHCP domain it won't be.
  struct NodeName
    property value : String
    forward_missing_to @value

    def initialize(@value); end
  end
end
