# frozen_string_literal: true

module Philiprehberger
  module EventEmitter
    class Emitter
      include ListenerStore
      include Invoker
      include History

      attr_accessor :max_listeners
      attr_writer :on_error

      def initialize(history_size: 0)
        @listeners = {}
        @wildcard_listeners = []
        @mutex = Mutex.new
        @on_error = nil
        @max_listeners = 10
        @history_size = history_size
        @history = []
      end

      def on(event, priority: 0, replay: false, metadata: false, &block)
        raise ArgumentError, "block required" unless block

        entry = { block: block, once: false, priority: priority, metadata: metadata }
        register_listener(event, entry)
        replay_history(event, entry) if replay
        self
      end

      def once(event, priority: 0, replay: false, metadata: false, &block)
        raise ArgumentError, "block required" unless block

        entry = { block: block, once: true, priority: priority, metadata: metadata }
        register_listener(event, entry, check_max: false)
        replay_history(event, entry) if replay
        self
      end

      def emit(event, *args, **kwargs)
        timestamp = Time.now
        record_history(event, args, kwargs, timestamp)
        all_entries = collect_entries(event)
        return false if all_entries.empty?

        meta = EventMetadata.new(event_name: event, timestamp: timestamp)
        invoke_entries(all_entries, args, kwargs, event, meta)
        true
      end

      def emit_async(event, *args, **kwargs)
        timestamp = Time.now
        record_history(event, args, kwargs, timestamp)
        all_entries = collect_entries(event)
        return [] if all_entries.empty?

        meta = EventMetadata.new(event_name: event, timestamp: timestamp)
        spawn_listener_threads(all_entries, args, kwargs, event, meta)
      end

      def off(event, &block)
        @mutex.synchronize do
          if Pattern.wildcard?(event.to_s)
            remove_wildcard_listener(event, block)
          else
            remove_exact_listener(event, block)
          end
        end
        self
      end

      def listeners(event)
        @mutex.synchronize do
          (@listeners[event] || []).map { |entry| entry[:block] }
        end
      end

      def listener_count(event)
        @mutex.synchronize { (@listeners[event] || []).size }
      end

      def remove_all_listeners(event = nil)
        @mutex.synchronize { clear_listeners(event) }
        self
      end

      def event_names
        @mutex.synchronize { @listeners.keys }
      end

      private

      def clear_listeners(event)
        return clear_all if event.nil?

        Pattern.wildcard?(event.to_s) ? clear_wildcard(event) : @listeners.delete(event)
      end

      def clear_all
        @listeners.clear
        @wildcard_listeners.clear
      end

      def clear_wildcard(event)
        @wildcard_listeners.reject! { |e| e[:pattern] == event.to_s }
      end
    end
  end
end
