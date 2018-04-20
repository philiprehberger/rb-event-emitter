# frozen_string_literal: true

module Philiprehberger
  module EventEmitter
    # Glob-style pattern matcher for wildcard event subscriptions.
    # Segments are separated by `.`.
    # `*` matches exactly one segment.
    # `**` matches zero or more segments.
    module Pattern
      module_function

      # Check if a string contains wildcard characters.
      #
      # @param pattern [String] the pattern to check
      # @return [Boolean]
      def wildcard?(pattern)
        pattern.is_a?(String) && (pattern.include?("*") || pattern.include?("**"))
      end

      # Match an event name against a glob-style pattern.
      #
      # @param pattern [String] the glob pattern (e.g. "user.*" or "app.**")
      # @param event_name [String] the actual event name (e.g. "user.created")
      # @return [Boolean]
      def match?(pattern, event_name)
        pattern_segments = pattern.to_s.split(".")
        event_segments = event_name.to_s.split(".")

        do_match(pattern_segments, 0, event_segments, 0)
      end

      # @api private
      def do_match(pattern_segs, pi, event_segs, ei)
        # Both exhausted — match
        return true if pi == pattern_segs.size && ei == event_segs.size

        # Pattern exhausted but event segments remain — no match
        return false if pi == pattern_segs.size

        seg = pattern_segs[pi]

        if seg == "**"
          # ** can match zero or more segments
          # Try matching zero segments (skip **)
          return true if do_match(pattern_segs, pi + 1, event_segs, ei)

          # Try matching one or more segments (consume one event segment, keep **)
          return false if ei == event_segs.size

          do_match(pattern_segs, pi, event_segs, ei + 1)
        elsif seg == "*"
          # * matches exactly one segment
          return false if ei == event_segs.size

          do_match(pattern_segs, pi + 1, event_segs, ei + 1)
        else
          # Literal match
          return false if ei == event_segs.size
          return false unless seg == event_segs[ei]

          do_match(pattern_segs, pi + 1, event_segs, ei + 1)
        end
      end

      private_class_method :do_match
    end
  end
end
