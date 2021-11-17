module Kube
  class Config
    module Var
      macro def_from_hash(hash)
        raise "Not a hash" unless {{hash}}.is_a?(Hash)
        new(
          {% for t in @type.resolve.instance_vars %}
            {% typ = t.type.union_types.reject(&.==(Nil)).first %}
            {% if typ <= Hash && typ.type_vars.find(&.<=(Kube::Config::Var)) %}
              {% if t.type.nilable? %}
                {{t.name}}: ({{hash}}[{{t.name.stringify}}]?.nil? ? nil : {{typ}}.from_hash({{hash}}[{{t.name.stringify}}])),
              {% else %}
                {{t.name}}: {{typ}}.from_hash({{hash}}[{{t.name.stringify}}]),
              {% end %}
            {% elsif typ <= Array && typ.type_vars.find(&.<=(Kube::Config::Var)) %}
              {% if t.type.nilable? %}
                {{t.name}}: ({{hash}}[{{t.name.stringify}}]?.nil? ? nil : {{hash}}[{{t.name.stringify}}].as(Array).map {|v| {{typ.type_vars.find(&.<=(Kube::Config::Var))}}.from_hash(v) }.as({{typ}})),
              {% else %}
                {{t.name}}: {{hash}}[{{t.name.stringify}}].as(Array).map {|v| {{typ.type_vars.find(&.<=(Kube::Config::Var))}}.from_hash(v) }.as({{typ}}),
              {% end %}
            {% elsif typ <= Kube::Config::Var %}
              {% if t.type.nilable? %}
                {{t.name}}: ({{hash}}[{{t.name.stringify}}]?.nil? ? nil : {{typ}}.from_hash({{hash}}[{{t.name.stringify}}])),
              {% else %}
                {{t.name}}: {{typ}}.from_hash({{hash}}[{{t.name.stringify}}]),
              {% end %}
            {% else %}
              {% if t.type.nilable? %}
                {{t.name}}: ({{hash}}[{{t.name.stringify}}]?.nil? ? nil : {{hash}}[{{t.name.stringify}}].as({{t.type}})),
              {% else %}
                {{t.name}}: {{hash}}[{{t.name.stringify}}].as({{t.type}}),
              {% end %}
            {% end %}
          {% end %}
        )
      end

      macro def_to_hash
        {
          {% for t in @type.resolve.instance_vars %}
            {% typ = t.type.union_types.reject(&.==(Nil)).first %}
            {% if typ <= Hash && typ.type_vars.find(&.<=(Kube::Config::Var)) %}
              {{t.name.stringify}} => {{t.name}}.map_values(&.to_h)
            {% elsif typ <= Array && typ.type_vars.find(&.<=(Kube::Config::Var)) %}
              {{t.name.stringify}} => {{t.name}}.map(&.to_h),
            {% elsif typ.union_types.reject(&.==(Nil)).first <= Kube::Config::Var %}
              {{t.name.stringify}} => {{t.name}}.nil? ? nil : {{t.name}}.not_nil!.to_h,
            {% else %}
              {{t.name.stringify}} => {{t.name}},
            {% end %}
          {% end %}
        }
      end

      macro included
        include JSON::Serializable
        include YAML::Serializable

        def self.from_hash(data)
          def_from_hash(data)
        end
      end

      def to_h
        def_to_hash
      end
    end
  end
end
