# frozen_string_literal: true

module GraphQL
  module PersistedQueries
    # Fetches or stores query string in the storage
    class DocumentResolver
      NAMESPACE = "document-#{GraphQL::VERSION}"
      MARSHAL_SIGNATURE = Marshal.dump("")[0..1]

      def initialize(query_params, extensions, schema)
        @query_params = query_params
        @extensions = extensions
        @schema = schema
      end

      def resolve
        return @query_params if hash.nil?

        result = { query: nil }

        if query_str
          result[:document] = persist_query(query_str)
        else
          result[:document] = should_marshal? ? fetch_marshaled_object : fetch_object
          raise NotFound unless result[:document]
        end

        @query_params.merge(result)
      end

      private

      def with_error_handling
        yield
      rescue StandardError => e
        @schema.persisted_query_error_handler.call(e)
      end

      def fetch_object
        with_error_handling { @schema.persisted_query_store.fetch_query(key) }
      end

      def fetch_marshaled_object
        cached = fetch_object
        begin
          Marshal.load(cached) if cached # rubocop:disable Security/MarshalLoad
        rescue TypeError
          # If unmarshaling fails, we'll just drop the invalid object out of
          # cache and act like a cache miss
          with_error_handling { @schema.persisted_query_store.delete_query(key) }
          nil
        end
      end

      def persist_query(query_str)
        raise WrongHash if @schema.hash_generator_proc.call(query_str) != hash

        GraphQL.parse(query_str).tap do |document|
          with_error_handling do
            cachable_object = should_marshal? ? Marshal.dump(document) : document
            @schema.persisted_query_store.save_query(key, cachable_object)
          end
        end
      end

      def hash
        @hash ||= @extensions.dig("persistedQuery", "sha256Hash")
      end

      def key
        "#{NAMESPACE}:#{hash}"
      end

      def query_str
        @query_params[:query]
      end

      def should_marshal?
        @schema.persisted_query_store.requires_marshaling?
      end
    end
  end
end
