# frozen_string_literal: true

require "spec_helper"

require "digest"

RSpec.describe GraphQL::PersistedQueries::DocumentResolver do
  describe "#resolve" do
    let(:extensions) { {} }
    let(:store) do
      double("TestStore").tap do |store|
        allow(store).to receive(:save_query)
        allow(store).to receive(:fetch_query).and_return(marshaled_query)
        allow(store).to receive(:requires_marshaling?).and_return(true)
        allow(store).to receive(:delete_query).and_return("unmarshalable")
      end
    end
    let(:query) { "query { user }" }
    let(:query_str) { query }
    let(:parsed_query) { GraphQL.parse(query) }
    let(:marshaled_query) { Marshal.dump(parsed_query) }
    let(:query_params) { { query: query_str } }
    let(:hash_generator_proc) { proc { |value| Digest::SHA256.hexdigest(value) } }
    let(:hash) { hash_generator_proc.call(query) }
    let(:key) { "document-#{GraphQL::VERSION}:#{hash}" }
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
        it { is_expected.to include(document: be_a(GraphQL::Language::Nodes::Document)) }

        it "saves document to store" do
          subject
          expect(store).to have_received(:save_query).with(key, marshaled_query)
        end

        context "when hash is incorrect" do
          let(:hash) { "wrong" }

          it "raises exception" do
            expect { subject }.to raise_error(
              GraphQL::PersistedQueries::WrongHash
            )
          end
        end

        context "when the store doesn't require marshaling" do
          before { allow(store).to receive(:requires_marshaling?).and_return(false) }

          it "saves the object without marshaling" do
            subject
            expect(store).to have_received(:save_query).with(
              key,
              be_a(GraphQL::Language::Nodes::Document)
            )
          end
        end
      end

      context "when query_str is not provided" do
        let(:query_str) { nil }

        it { is_expected.to include(document: be_a(GraphQL::Language::Nodes::Document)) }

        it "fetches query from store" do
          subject
          expect(store).to have_received(:fetch_query).with(key)
        end

        context "when the fetched object isn't unmarshalable" do
          before do
            allow(store).to receive(:fetch_query).and_return("unmarshalable")
          end

          it "acts as a cache miss" do
            expect { subject }.to raise_error(
              GraphQL::PersistedQueries::NotFound
            )
          end

          it "deletes the invalid object" do
            begin
              subject
            rescue GraphQL::PersistedQueries::NotFound # rubocop: disable Lint/HandleExceptions
              # Ignore the expected error
            end

            expect(store).to have_received(:delete_query).with(key)
          end
        end

        context "when the store doesn't require marshaling" do
          before { allow(store).to receive(:requires_marshaling?).and_return(false) }

          it "handles objects returned from the store" do
            allow(store).to receive(:fetch_query).and_return(parsed_query)
            subject
          end
        end
      end

      include_examples "when the store fails during resolution"
    end
  end
end
