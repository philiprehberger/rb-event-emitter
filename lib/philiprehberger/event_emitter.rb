# frozen_string_literal: true

require_relative "event_emitter/version"
require_relative "event_emitter/emitter"

module Philiprehberger
  module EventEmitter
    class Error < StandardError; end

    # Convenience constructor.
    #
    # @return [Emitter]
    def self.new
      Emitter.new
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
      def off(...) = event_emitter.off(...)
    end
  end
end
