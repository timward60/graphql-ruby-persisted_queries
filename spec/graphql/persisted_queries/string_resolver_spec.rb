# frozen_string_literal: true

require "spec_helper"

require "digest"

RSpec.describe GraphQL::PersistedQueries::StringResolver do
  describe "#resolve" do
    let(:extensions) { {} }
    let(:store) do
      double("TestStore").tap do |store|
        allow(store).to receive(:save_query)
        allow(store).to receive(:fetch_query).and_return(query)
      end
    end
    let(:query) { "query { user }" }
    let(:query_str) { query }
    let(:query_params) { { query: query_str } }
    let(:hash_generator_proc) { proc { |value| Digest::SHA256.hexdigest(value) } }
    let(:hash) { hash_generator_proc.call(query) }
    let(:error_handler) { GraphQL::PersistedQueries::ErrorHandlers::DefaultErrorHandler.new({}) }

    let(:schema) do
      double("TestSchema").tap do |schema|
        allow(schema).to receive(:persisted_query_store).and_return(store)
        allow(schema).to receive(:hash_generator_proc).and_return(hash_generator_proc)
        allow(schema).to receive(:persisted_query_error_handler).and_return(error_handler)
      end
    end

    subject do
      described_class.new(query_params, extensions, schema).resolve
    end

    context "when extensions hash is empty" do
      it { is_expected.to eq(query: query) }
    end

    context "when extensions hash is passed" do
      let(:extensions) do
        { "persistedQuery" => { "sha256Hash" => hash } }
      end

      context "when query_str is provided" do
        it { is_expected.to eq(query: query) }

        it "saves query to store" do
          subject
          expect(store).to have_received(:save_query).with(hash, query)
        end

        context "when hash is incorrect" do
          let(:hash) { "wrong" }

          it "raises exception" do
            expect { subject }.to raise_error(
              GraphQL::PersistedQueries::WrongHash
            )
          end
        end
      end

      context "when query_str is not provided" do
        let(:query_str) { nil }

        it { is_expected.to eq(query: query) }

        it "fetches query from store" do
          subject
          expect(store).to have_received(:fetch_query).with(hash)
        end
      end

      include_examples "when the store fails during resolution"
    end
  end
end
