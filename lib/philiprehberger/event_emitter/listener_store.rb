# frozen_string_literal: true

module Philiprehberger
  module EventEmitter
    # Manages listener registration, removal, and snapshot operations.
    module ListenerStore
      private

      def register_listener(event, entry, check_max: true)
        @mutex.synchronize do
          if Pattern.wildcard?(event.to_s)
            @wildcard_listeners << entry.merge(pattern: event.to_s)
            @wildcard_listeners.sort_by! { |e| -e[:priority] }
          else
            (@listeners[event] ||= []) << entry
            @listeners[event].sort_by! { |e| -e[:priority] }
            check_max_listeners(event) if check_max
          end
        end
      end

      def collect_entries(event)
        entries = snapshot_and_prune(event)
        wildcard_entries = snapshot_wildcard_matches(event)
        all = (entries || []) + (wildcard_entries || [])
        all.each_with_index.sort_by { |entry, idx| [-entry[:priority], idx] }.map(&:first)
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

      def check_max_listeners(event)
        return unless @max_listeners
        return unless @listeners[event].size > @max_listeners

        warn "EventEmitter: #{@listeners[event].size} listeners added for #{event.inspect}, " \
             "max is #{@max_listeners}. Possible memory leak."
      end
    end
  end
end
