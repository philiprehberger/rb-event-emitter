# frozen_string_literal: true

module Philiprehberger
  module EventEmitter
    class Emitter
      # Maximum listener count before emitting a warning. Set to `nil` to disable.
      # @return [Integer, nil]
      attr_accessor :max_listeners

      def initialize
        @listeners = {}
        @mutex = Mutex.new
        @on_error = nil
        @max_listeners = 10
      end

      # Register a sync listener for an event.
      #
      # @param event [Symbol, String] the event name
      # @yield the block to call when the event is emitted
      # @return [self]
      def on(event, &block)
        raise ArgumentError, "block required" unless block

        @mutex.synchronize do
          (@listeners[event] ||= []) << { block: block, once: false }
          check_max_listeners(event)
        end

        self
      end

      # Register a listener that fires only once.
      #
      # @param event [Symbol, String] the event name
      # @yield the block to call when the event is emitted
      # @return [self]
      def once(event, &block)
        raise ArgumentError, "block required" unless block

        @mutex.synchronize do
          (@listeners[event] ||= []) << { block: block, once: true }
        end

        self
      end

      # Emit an event, calling all registered listeners with the given arguments.
      #
      # @param event [Symbol, String] the event name
      # @param args positional arguments forwarded to listeners
      # @param kwargs keyword arguments forwarded to listeners
      # @return [Boolean] true if any listeners were called
      def emit(event, *args, **kwargs)
        entries = snapshot_and_prune(event)
        return false unless entries

        invoke_entries(entries, args, kwargs)
        true
      end

      # Remove a specific listener or all listeners for an event.
      #
      # @param event [Symbol, String] the event name
      # @yield (optional) the specific block to remove
      # @return [self]
      def off(event, &block)
        @mutex.synchronize do
          if block
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
            @listeners.delete(event)
          else
            @listeners.clear
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

      def invoke_entries(entries, args, kwargs)
        entries.each do |entry|
          invoke_single(entry, args, kwargs)
        rescue StandardError => e
          raise unless @on_error

          @on_error.call(e)
        end
      end

      def invoke_single(entry, args, kwargs)
        if kwargs.empty?
          entry[:block].call(*args)
        else
          entry[:block].call(*args, **kwargs)
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
