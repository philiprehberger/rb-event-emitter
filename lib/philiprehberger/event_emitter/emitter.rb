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
      #
      # @param event [Symbol, String] the event name or wildcard pattern
      # @param priority [Integer] execution priority (higher runs first, default 0)
      # @param replay [Boolean] replay matching historical events immediately
      # @param metadata [Boolean] receive EventMetadata as extra argument
      # @yield the block to call when the event is emitted
      # @return [self]
      def on(event, priority: 0, replay: false, metadata: false, &block)
        raise ArgumentError, "block required" unless block

        entry = { block: block, once: false, priority: priority, metadata: metadata }

        @mutex.synchronize do
          if Pattern.wildcard?(event.to_s)
            @wildcard_listeners << entry.merge(pattern: event.to_s)
            @wildcard_listeners.sort_by! { |e| -e[:priority] }
          else
            (@listeners[event] ||= []) << entry
            @listeners[event].sort_by! { |e| -e[:priority] }
            check_max_listeners(event)
          end
        end

        replay_history(event, entry) if replay

        self
      end

      # Register a listener that fires only once.
      #
      # @param event [Symbol, String] the event name or wildcard pattern
      # @param priority [Integer] execution priority (higher runs first, default 0)
      # @param replay [Boolean] replay matching historical events immediately
      # @param metadata [Boolean] receive EventMetadata as extra argument
      # @yield the block to call when the event is emitted
      # @return [self]
      def once(event, priority: 0, replay: false, metadata: false, &block)
        raise ArgumentError, "block required" unless block

        entry = { block: block, once: true, priority: priority, metadata: metadata }

        @mutex.synchronize do
          if Pattern.wildcard?(event.to_s)
            @wildcard_listeners << entry.merge(pattern: event.to_s)
            @wildcard_listeners.sort_by! { |e| -e[:priority] }
          else
            (@listeners[event] ||= []) << entry
            @listeners[event].sort_by! { |e| -e[:priority] }
          end
        end

        replay_history(event, entry) if replay

        self
      end

      # Emit an event, calling all registered listeners with the given arguments.
      #
      # @param event [Symbol, String] the event name
      # @param args positional arguments forwarded to listeners
      # @param kwargs keyword arguments forwarded to listeners
      # @return [Boolean] true if any listeners were called
      def emit(event, *args, **kwargs)
        timestamp = Time.now
        record_history(event, args, kwargs, timestamp)

        entries = snapshot_and_prune(event)
        wildcard_entries = snapshot_wildcard_matches(event)

        all_entries = merge_by_priority(entries, wildcard_entries)
        return false if all_entries.empty?

        meta = EventMetadata.new(event_name: event, timestamp: timestamp)
        invoke_entries(all_entries, args, kwargs, event, meta)
        true
      end

      # Emit an event asynchronously. Each listener runs in its own Thread.
      #
      # @param event [Symbol, String] the event name
      # @param args positional arguments forwarded to listeners
      # @param kwargs keyword arguments forwarded to listeners
      # @return [Array<Thread>] threads for optional joining
      def emit_async(event, *args, **kwargs)
        timestamp = Time.now
        record_history(event, args, kwargs, timestamp)

        entries = snapshot_and_prune(event)
        wildcard_entries = snapshot_wildcard_matches(event)

        all_entries = merge_by_priority(entries, wildcard_entries)
        return [] if all_entries.empty?

        meta = EventMetadata.new(event_name: event, timestamp: timestamp)
        all_entries.map do |entry|
          Thread.new do
            invoke_single(entry, args, kwargs, event, meta)
          rescue StandardError => e
            raise unless @on_error

            @on_error.call(e)
          end
        end
      end

      # Remove a specific listener or all listeners for an event.
      #
      # @param event [Symbol, String] the event name
      # @yield (optional) the specific block to remove
      # @return [self]
      def off(event, &block)
        @mutex.synchronize do
          if Pattern.wildcard?(event.to_s)
            if block
              @wildcard_listeners.reject! { |entry| entry[:pattern] == event.to_s && entry[:block] == block }
            else
              @wildcard_listeners.reject! { |entry| entry[:pattern] == event.to_s }
            end
          elsif block
            @listeners[event]&.reject! { |entry| entry[:block] == block }
            @listeners.delete(event) if @listeners[event]&.empty? # rubocop:disable Lint/SafeNavigationWithEmpty
          else
            @listeners.delete(event)
          end
        end

        self
      end

      # List all listener blocks for an event.
      #
      # @param event [Symbol, String] the event name
      # @return [Array<Proc>] the registered listener blocks
      def listeners(event)
        @mutex.synchronize do
          (@listeners[event] || []).map { |entry| entry[:block] }
        end
      end

      # Count listeners for an event.
      #
      # @param event [Symbol, String] the event name
      # @return [Integer]
      def listener_count(event)
        @mutex.synchronize do
          (@listeners[event] || []).size
        end
      end

      # Set an error handler for listener exceptions.
      # When set, exceptions in listeners are caught and forwarded here,
      # allowing remaining listeners to still execute.
      # When nil (default), exceptions propagate normally.
      #
      # @param handler [Proc, nil] the error handler
      attr_writer :on_error

      # Remove all listeners, optionally for a specific event.
      #
      # @param event [Symbol, String, nil] if provided, remove only for that event
      # @return [self]
      def remove_all_listeners(event = nil)
        @mutex.synchronize do
          if event
            if Pattern.wildcard?(event.to_s)
              @wildcard_listeners.reject! { |entry| entry[:pattern] == event.to_s }
            else
              @listeners.delete(event)
            end
          else
            @listeners.clear
            @wildcard_listeners.clear
          end
        end
        self
      end

      # List all registered event names.
      #
      # @return [Array<Symbol, String>]
      def event_names
        @mutex.synchronize { @listeners.keys }
      end

      private

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
          matched = @wildcard_listeners.select { |entry| Pattern.match?(entry[:pattern], event.to_s) }
          @wildcard_listeners.reject! { |entry| entry[:once] && Pattern.match?(entry[:pattern], event.to_s) }
          matched.map { |entry| entry.merge(wildcard: true) }
        end
      end

      def merge_by_priority(entries, wildcard_entries)
        all = (entries || []) + (wildcard_entries || [])
        # Stable sort: sort by -priority, preserving insertion order within same priority
        # Ruby's sort_by is stable in MRI, but to be safe we use sort_by with index
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
        # Wildcard listeners receive the actual event name as the first argument
        call_args << event if entry[:wildcard]
        call_args.concat(args)
        # Metadata listeners receive an EventMetadata as the last positional argument
        call_args << meta if entry[:metadata]
        call_args
      end

      def record_history(event, args, kwargs, timestamp)
        return unless @history_size.positive?

        @mutex.synchronize do
          @history << { event: event, args: args, kwargs: kwargs, timestamp: timestamp }
          @history.shift if @history.size > @history_size
        end
      end

      def replay_history(event, entry)
        matching = @mutex.synchronize do
          if Pattern.wildcard?(event.to_s)
            @history.select { |h| Pattern.match?(event.to_s, h[:event].to_s) }
          else
            @history.select { |h| h[:event] == event }
          end
        end

        matching.each do |record|
          meta = EventMetadata.new(event_name: record[:event], timestamp: record[:timestamp])
          replay_entry = entry.merge(wildcard: Pattern.wildcard?(event.to_s))
          invoke_single(replay_entry, record[:args], record[:kwargs], record[:event], meta)
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
