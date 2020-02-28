# frozen_string_literal: true

require "spec_helper"

require "digest"

RSpec.describe GraphQL::PersistedQueries do
  let(:options) { {} }
  subject { build_test_schema(options) }

  describe ".use" do
    it "defaults to using a query string resolver" do
      expected_resolver = GraphQL::PersistedQueries::StringResolver
      expect(subject.persisted_query_resolver_class).to eq(expected_resolver)
    end
  end
end
