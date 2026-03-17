# frozen_string_literal: true

module Philiprehberger
  module EventEmitter
    module History
      private

      def record_history(event, args, kwargs, timestamp)
        return unless @history_size.positive?

        @mutex.synchronize do
          @history << { event: event, args: args, kwargs: kwargs, timestamp: timestamp }
          @history.shift if @history.size > @history_size
        end
      end

      def replay_history(event, entry)
        find_matching_history(event).each do |record|
          meta = EventMetadata.new(event_name: record[:event], timestamp: record[:timestamp])
          replay_entry = entry.merge(wildcard: Pattern.wildcard?(event.to_s))
          invoke_single(replay_entry, record[:args], record[:kwargs], record[:event], meta)
        end
      end

      def find_matching_history(event)
        @mutex.synchronize do
          if Pattern.wildcard?(event.to_s)
            @history.select { |h| Pattern.match?(event.to_s, h[:event].to_s) }
          else
            @history.select { |h| h[:event] == event }
          end
        end
      end
    end
  end
end
