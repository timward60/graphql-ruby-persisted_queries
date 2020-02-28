# frozen_string_literal: true

require "graphql/persisted_queries/error_handlers/base_error_handler"
require "graphql/persisted_queries/error_handlers/default_error_handler"

module GraphQL
  module PersistedQueries
    # Contains factory methods for error handlers
    module Resolvers
      def self.build(resolver)
        if resolver.is_a?(Class)
          resolver
        else
          build_by_name(resolver)
        end
      end

      def self.build_by_name(name)
        GraphQL::PersistedQueries.const_get("#{BuilderHelpers.camelize(name)}Resolver")
      rescue NameError => e
        raise e.class, "Persisted query resolver for :#{name} haven't been found", e.backtrace
      end
    end
  end
end
