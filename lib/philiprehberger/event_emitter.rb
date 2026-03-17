# frozen_string_literal: true

require_relative "event_emitter/version"
require_relative "event_emitter/pattern"
require_relative "event_emitter/metadata"
require_relative "event_emitter/listener_store"
require_relative "event_emitter/invoker"
require_relative "event_emitter/history"
require_relative "event_emitter/emitter"

module Philiprehberger
  module EventEmitter
    class Error < StandardError; end

    # Convenience constructor.
    #
    # @return [Emitter]
    def self.new(**kwargs)
      Emitter.new(**kwargs)
    end

    # Mixin module — `include Philiprehberger::EventEmitter::Mixin`
    # to add event emitter capabilities to any class.
    module Mixin
      def event_emitter
        @event_emitter ||= Emitter.new
      end

      def on(...) = event_emitter.on(...)
      def once(...) = event_emitter.once(...)
      def emit(...) = event_emitter.emit(...)
      def emit_async(...) = event_emitter.emit_async(...)
      def off(...) = event_emitter.off(...)
      def remove_all_listeners(...) = event_emitter.remove_all_listeners(...)
      def event_names = event_emitter.event_names
    end
  end
end
