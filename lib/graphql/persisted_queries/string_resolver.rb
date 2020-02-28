# frozen_string_literal: true

module GraphQL
  module PersistedQueries
    # Fetches or stores query string in the storage
    class StringResolver
      def initialize(query_params, extensions, schema)
        @query_params = query_params
        @extensions = extensions
        @schema = schema
      end

      def resolve
        return @query_params if hash.nil?

        resolved = {}

        if query_str
          persist_query(query_str)
        else
          resolved[:query] = with_error_handling { @schema.persisted_query_store.fetch_query(hash) }
          raise NotFound unless resolved[:query]
        end

        @query_params.merge(resolved)
      end

      private

      def with_error_handling
        yield
      rescue StandardError => e
        @schema.persisted_query_error_handler.call(e)
      end

      def persist_query(query_str)
        raise WrongHash if @schema.hash_generator_proc.call(query_str) != hash

        with_error_handling { @schema.persisted_query_store.save_query(hash, query_str) }
      end

      def hash
        @hash ||= @extensions.dig("persistedQuery", "sha256Hash")
      end

      def query_str
        @query_params[:query]
      end
    end
  end
end
