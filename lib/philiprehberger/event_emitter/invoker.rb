# frozen_string_literal: true

module Philiprehberger
  module EventEmitter
    module Invoker
      private

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
        call_args << event if entry[:wildcard]
        call_args.concat(args)
        call_args << meta if entry[:metadata]
        call_args
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
    end
  end
end
