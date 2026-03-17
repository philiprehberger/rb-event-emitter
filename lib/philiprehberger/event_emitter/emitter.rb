# frozen_string_literal: true

module Philiprehberger
  module EventEmitter
    class Emitter
      # Maximum listener count before emitting a warning. Set to `nil` to disable.
      # @return [Integer, nil]
      attr_accessor :max_listeners

      # @param history_size [Integer] max events to store for replay (0 = disabled)
      def initialize(history_size: 0)
        @listeners = {}
        @wildcard_listeners = []
        @mutex = Mutex.new
        @on_error = nil
        @max_listeners = 10
        @history_size = history_size
        @history = []
      end

      # Register a sync listener for an event.
      def on(event, priority: 0, replay: false, metadata: false, &block)
        raise ArgumentError, "block required" unless block

        entry = { block: block, once: false, priority: priority, metadata: metadata }
        register_listener(event, entry)
        replay_history(event, entry) if replay
        self
      end

      # Register a listener that fires only once.
      def once(event, priority: 0, replay: false, metadata: false, &block)
        raise ArgumentError, "block required" unless block

        entry = { block: block, once: true, priority: priority, metadata: metadata }
        register_listener(event, entry, check_max: false)
        replay_history(event, entry) if replay
        self
      end

      # Emit an event, calling all registered listeners.
      def emit(event, *args, **kwargs)
        timestamp = Time.now
        record_history(event, args, kwargs, timestamp)
        all_entries = collect_entries(event)
        return false if all_entries.empty?

        meta = EventMetadata.new(event_name: event, timestamp: timestamp)
        invoke_entries(all_entries, args, kwargs, event, meta)
        true
      end

      # Emit an event asynchronously. Each listener runs in its own Thread.
      def emit_async(event, *args, **kwargs)
        timestamp = Time.now
        record_history(event, args, kwargs, timestamp)
        all_entries = collect_entries(event)
        return [] if all_entries.empty?

        meta = EventMetadata.new(event_name: event, timestamp: timestamp)
        spawn_listener_threads(all_entries, args, kwargs, event, meta)
      end

      # Remove a specific listener or all listeners for an event.
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

      # List all listener blocks for an event.
      def listeners(event)
        @mutex.synchronize do
          (@listeners[event] || []).map { |entry| entry[:block] }
        end
      end

      # Count listeners for an event.
      def listener_count(event)
        @mutex.synchronize { (@listeners[event] || []).size }
      end

      # Set an error handler for listener exceptions.
      attr_writer :on_error

      # Remove all listeners, optionally for a specific event.
      def remove_all_listeners(event = nil)
        @mutex.synchronize do
          if event.nil?
            @listeners.clear
            @wildcard_listeners.clear
          elsif Pattern.wildcard?(event.to_s)
            @wildcard_listeners.reject! { |e| e[:pattern] == event.to_s }
          else
            @listeners.delete(event)
          end
        end
        self
      end

      # List all registered event names.
      def event_names
        @mutex.synchronize { @listeners.keys }
      end

      private

      def register_listener(event, entry, check_max: true)
        @mutex.synchronize do
          if Pattern.wildcard?(event.to_s)
            @wildcard_listeners << entry.merge(pattern: event.to_s)
            sort_by_priority!(@wildcard_listeners)
          else
            (@listeners[event] ||= []) << entry
            sort_by_priority!(@listeners[event])
            check_max_listeners(event) if check_max
          end
        end
      end

      def sort_by_priority!(list)
        list.sort_by! { |e| -e[:priority] }
      end

      def collect_entries(event)
        entries = snapshot_and_prune(event)
        wildcard_entries = snapshot_wildcard_matches(event)
        merge_by_priority(entries, wildcard_entries)
      end

      def snapshot_and_prune(event)
        @mutex.synchronize do
          return nil unless @listeners.key?(event)

          current = @listeners[event].dup
          @listeners[event].reject! { |entry| entry[:once] }
          @listeners.delete(event) if @listeners[event].empty?
          current
        end
      end

      def snapshot_wildcard_matches(event)
        @mutex.synchronize do
          matched = @wildcard_listeners.select { |e| Pattern.match?(e[:pattern], event.to_s) }
          @wildcard_listeners.reject! { |e| e[:once] && Pattern.match?(e[:pattern], event.to_s) }
          matched.map { |e| e.merge(wildcard: true) }
        end
      end

      def merge_by_priority(entries, wildcard_entries)
        all = (entries || []) + (wildcard_entries || [])
        all.each_with_index.sort_by { |entry, idx| [-entry[:priority], idx] }.map(&:first)
      end

      def invoke_entries(entries, args, kwargs, event, meta)
        entries.each do |entry|
          invoke_single(entry, args, kwargs, event, meta)
        rescue StandardError => e
          raise unless @on_error

          @on_error.call(e)
        end
      end

      def spawn_listener_threads(entries, args, kwargs, event, meta)
        entries.map do |entry|
          Thread.new do
            invoke_single(entry, args, kwargs, event, meta)
          rescue StandardError => e
            raise unless @on_error

            @on_error.call(e)
          end
        end
      end

      def invoke_single(entry, args, kwargs, event, meta)
        call_args = build_call_args(entry, args, event, meta)

        if kwargs.empty?
          entry[:block].call(*call_args)
        else
          entry[:block].call(*call_args, **kwargs)
        end
      end

      def build_call_args(entry, args, event, meta)
        call_args = []
        call_args << event if entry[:wildcard]
        call_args.concat(args)
        call_args << meta if entry[:metadata]
        call_args
      end

      def remove_wildcard_listener(event, block)
        if block
          @wildcard_listeners.reject! { |e| e[:pattern] == event.to_s && e[:block] == block }
        else
          @wildcard_listeners.reject! { |e| e[:pattern] == event.to_s }
        end
      end

      def remove_exact_listener(event, block)
        if block
          @listeners[event]&.reject! { |e| e[:block] == block }
          @listeners.delete(event) if @listeners[event]&.empty? # rubocop:disable Lint/SafeNavigationWithEmpty
        else
          @listeners.delete(event)
        end
      end

      def record_history(event, args, kwargs, timestamp)
        return unless @history_size.positive?

        @mutex.synchronize do
          @history << { event: event, args: args, kwargs: kwargs, timestamp: timestamp }
          @history.shift if @history.size > @history_size
        end
      end

      def replay_history(event, entry)
        matching = find_matching_history(event)
        matching.each do |record|
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

      def check_max_listeners(event)
        return unless @max_listeners
        return unless @listeners[event].size > @max_listeners

        warn "EventEmitter: #{@listeners[event].size} listeners added for #{event.inspect}, " \
             "max is #{@max_listeners}. Possible memory leak."
      end
    end
  end
end
