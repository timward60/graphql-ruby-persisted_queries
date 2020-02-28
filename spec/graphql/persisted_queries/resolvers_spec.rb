# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraphQL::PersistedQueries::Resolvers do
  describe ".build" do
    subject { described_class.build(resolver) }

    context "when class is passed" do
      let(:resolver) do
        GraphQL::PersistedQueries::DocumentResolver
      end

      it { is_expected.to be(resolver) }
    end

    context "when name is passed" do
      let(:resolver) { :string }

      it { is_expected.to be(GraphQL::PersistedQueries::StringResolver) }

      context "when resolver is not found" do
        let(:resolver) { :unknown }

        it "raises error" do
          expect { subject }.to raise_error(
            NameError,
            "Persisted query resolver for :#{resolver} haven't been found"
          )
        end
      end
    end
  end
end
