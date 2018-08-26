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
        pattern.is_a?(String) && pattern.include?("*")
      end

      # Match an event name against a glob-style pattern.
      #
      # @param pattern [String] the glob pattern (e.g. "user.*" or "app.**")
      # @param event_name [String] the actual event name (e.g. "user.created")
      # @return [Boolean]
      def match?(pattern, event_name)
        pattern_segments = pattern.to_s.split(".")
        event_segments = event_name.to_s.split(".")
        segments_match?(pattern_segments, 0, event_segments, 0)
      end

      def segments_match?(pat, pat_idx, evt, evt_idx)
        return true if pat_idx == pat.size && evt_idx == evt.size
        return false if pat_idx == pat.size

        seg = pat[pat_idx]
        case seg
        when "**" then match_globstar?(pat, pat_idx, evt, evt_idx)
        when "*" then match_star?(pat, pat_idx, evt, evt_idx)
        else match_literal?(pat, pat_idx, evt, evt_idx, seg)
        end
      end

      def match_globstar?(pat, pat_idx, evt, evt_idx)
        return true if segments_match?(pat, pat_idx + 1, evt, evt_idx)
        return false if evt_idx == evt.size

        segments_match?(pat, pat_idx, evt, evt_idx + 1)
      end

      def match_star?(pat, pat_idx, evt, evt_idx)
        return false if evt_idx == evt.size

        segments_match?(pat, pat_idx + 1, evt, evt_idx + 1)
      end

      def match_literal?(pat, pat_idx, evt, evt_idx, seg)
        return false if evt_idx == evt.size
        return false unless seg == evt[evt_idx]

        segments_match?(pat, pat_idx + 1, evt, evt_idx + 1)
      end

      private_class_method :segments_match?, :match_globstar?, :match_star?, :match_literal?
    end
  end
end
