# frozen_string_literal: true

RSpec.shared_examples "when the store fails during resolution" do
  let(:error_handler) do
    handler = double("TestErrorHandler")
    allow(handler).to receive(:call)
    handler
  end
  let(:error) { StandardError.new }

  context "while fetching the query" do
    let(:query_str) { nil }
    let(:store) do
      store = double("TestStore")
      allow(store).to receive(:save_query)
      allow(store).to receive(:fetch_query).and_raise(error)
      store
    end

    it "passes the error to the error handler" do
      # rubocop: disable Lint/HandleExceptions
      begin
        subject
      rescue GraphQL::PersistedQueries::NotFound
        # Ignore the expected error
      end
      # rubocop: enable Lint/HandleExceptions

      expect(error_handler).to have_received(:call).with(error)
    end
  end

  context "while saving the query" do
    let(:store) do
      store = double("TestStore")
      allow(store).to receive(:save_query).and_raise(error)
      allow(store).to receive(:fetch_query)
      store
    end

    it "passes the error to the error handler" do
      subject
      expect(error_handler).to have_received(:call).with(error)
    end
  end
end
