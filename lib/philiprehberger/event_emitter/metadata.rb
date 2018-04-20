# frozen_string_literal: true

module Philiprehberger
  module EventEmitter
    # Metadata object passed to listeners that opt in with `metadata: true`.
    class EventMetadata
      # @return [Symbol, String] the event name
      attr_reader :event_name

      # @return [Time] the timestamp when the event was emitted
      attr_reader :timestamp

      # @param event_name [Symbol, String] the event name
      # @param timestamp [Time] the timestamp
      def initialize(event_name:, timestamp:)
        @event_name = event_name
        @timestamp = timestamp
      end
    end
  end
end
