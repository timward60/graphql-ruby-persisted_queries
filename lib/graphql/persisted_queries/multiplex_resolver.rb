# frozen_string_literal: true

module GraphQL
  module PersistedQueries
    # Resolves multiplex query
    class MultiplexResolver
      def initialize(schema, queries, kwargs)
        @schema = schema
        @queries = queries
        @kwargs = kwargs
      end

      def resolve
        resolve_persisted_queries
        perform_multiplex
        results
      end

      private

      def results
        @results ||= Array.new(@queries.count)
      end

      def resolve_persisted_queries
        @queries.each_with_index do |query_params, i|
          resolve_persisted_query(query_params, i)
        end
      end

      def resolve_persisted_query(query_params, pos)
        extensions = query_params.delete(:extensions)
        return unless extensions

        query_params.merge!(resolver.new(query_params, extensions, @schema).resolve)
      rescue NotFound, WrongHash => e
        results[pos] = { "errors" => [{ "message" => e.message }] }
      rescue GraphQL::ParseError => e
        results[pos] = { "errors" => [ e.to_h ]}
      end

      def perform_multiplex
        resolve_idx = (0...@queries.count).select { |i| results[i].nil? }
        multiplex_result = @schema.multiplex_original(
          resolve_idx.map { |i| @queries.at(i) }, @kwargs
        )
        resolve_idx.each_with_index { |res_i, mult_i| results[res_i] = multiplex_result[mult_i] }
      end

      def resolver
        @schema.persisted_query_resolver_class
      end
    end
  end
end
