module Neo4j
  module Server
    class CypherRelationship < Neo4j::Relationship
      include Neo4j::Server::Resource
      include Neo4j::Core::ActiveEntity

      MARSHAL_INSTANCE_VARIABLES = [:@rel_type, :@props, :@start_node_neo_id, :@end_node_neo_id, :@id]

      def initialize(session, value)
        @session = session
        @response_hash = value
        @rel_type = @response_hash[:type]
        @props = @response_hash[:data]
        @start_node_neo_id = neo_id_integer(@response_hash[:start])
        @end_node_neo_id = neo_id_integer(@response_hash[:end])
        @id = @response_hash[:id]
      end

      def ==(other)
        other.class == self.class && other.neo_id == neo_id
      end
      alias eql? ==

      attr_reader :id

      def neo_id
        id
      end

      def inspect
        "CypherRelationship #{neo_id}"
      end

      def load_resource
        return if resource_data_present?

        @resource_data = @session._query_or_fail("#{match_start} RETURN n", true, match_params) # r.first_data
      end

      attr_reader :start_node_neo_id

      attr_reader :end_node_neo_id

      def _start_node_id
        @start_node_neo_id ||= get_node_id(:start)
      end

      def _end_node_id
        @end_node_neo_id ||= get_node_id(:end)
      end

      def _start_node
        @_start_node ||= Neo4j::Node._load(start_node_neo_id)
      end

      def _end_node
        load_resource
        @_end_node ||= Neo4j::Node._load(end_node_neo_id)
      end

      def get_node_id(direction)
        load_resource
        resource_url_id(resource_url(direction))
      end

      def get_property(key)
        @session._query_or_fail("#{match_start} RETURN n.`#{key}`", true, match_params)
      end

      def set_property(key, value)
        params = match_params
        params[:value] = value
        @session._query_or_fail("#{match_start} SET n.`#{key}` = {value}", false, params)
      end

      def remove_property(key)
        @session._query_or_fail("#{match_start} REMOVE n.`#{key}`", false, match_params)
      end

      # (see Neo4j::Relationship#props)
      def props
        if @props
          @props
        else
          hash = @session._query_entity_data("#{match_start} RETURN n", nil, match_params)
          @props = Hash[hash[:data].map { |k, v| [k, v] }]
        end
      end

      # (see Neo4j::Relationship#props=)
      def props=(properties)
        params = match_params
        params[:props] = properties
        @session._query_or_fail("#{match_start} SET n = { props }", false, params)
        properties
      end

      # (see Neo4j::Relationship#update_props)
      def update_props(properties)
        return if properties.empty?

        params = {}
        q = "#{match_start} SET " + properties.keys.each_with_index.map do |k, _i|
          param = k.to_s.tr_s('^a-zA-Z0-9', '_').gsub(/^_+|_+$/, '')
          params[param] = properties[k]

          "n.`#{k}`= {#{param}}"
        end.join(',')

        params.update! match_params
        @session._query_or_fail(q, false, params)

        properties
      end

      def rel_type
        @rel_type.to_sym
      end

      def del
        @session._query("#{match_start} DELETE n", neo_id: neo_id)
      end
      alias delete del
      alias destroy del

      def exist?
        response = @session._query("#{match_start} RETURN n", neo_id: neo_id)
        # binding.pry
        (response.data.nil? || response.data.empty?) ? false : true
      end

      private

      def match_start(identifier = 'n')
        "MATCH (node)-[#{identifier}]-() WHERE (ID(#{identifier}) = {neo_id}) AND (ID(node) = {start_node_neo_id})"
      end

      def match_params
        {neo_id: neo_id, start_node_neo_id: start_node_neo_id}
      end

      def resource_data_present?
        !resource_data.nil? && !resource_data.empty?
      end

      def neo_id_integer(id_or_url)
        id_or_url.is_a?(Integer) ? id_or_url : id_or_url.split('/').last.to_i
      end
    end
  end
end
