# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this gem adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.1] - 2026-03-20

### Fixed
- Standardize README Development section
- Fix CHANGELOG header wording

## [0.3.0] - 2026-03-17

### Added

- Wildcard event matching: `*` matches one segment, `**` matches any number of segments (e.g. `emitter.on("user.*")`)
- Listener priorities: `on(:event, priority: 10)` — higher priority executes first, FIFO within same priority
- Event history and replay: `Emitter.new(history_size: 50)` stores recent events; `on(:event, replay: true)` replays them
- `emit_async`: fire-and-forget listener execution in threads, returns array of Thread objects
- Event metadata: `on(:event, metadata: true)` passes `EventMetadata` with `event_name` and `timestamp` to listener

## [0.2.3] - 2026-03-16

### Fixed
- Fix CI: version test and rubocop compliance

## [0.2.2] - 2026-03-16

### Changed
- Add License badge to README
- Add bug_tracker_uri to gemspec
- Add Requirements section to README

## [0.2.1] - 2026-03-12

### Fixed
- Re-release with no code changes (RubyGems publish fix)

## [0.2.0] - 2026-03-12

### Added

- Error handling in `emit`: listeners that raise are caught when `on_error` callback is set
- `remove_all_listeners` method to clear all or per-event listeners
- `event_names` method to list registered event names
- `max_listeners` warning threshold (default 10) to detect potential memory leaks

### Fixed

- Removed false "async" claim from README description

## [0.1.0] - 2026-03-10

### Added

- Initial release
- `Emitter` class with `on`, `once`, `emit`, `off`, `listeners`, and `listener_count` methods
- Thread-safe implementation with Mutex
- `Mixin` module for including event emitter capabilities in any class
- Convenience `Philiprehberger::EventEmitter.new` constructor

[0.1.0]: https://github.com/philiprehberger/rb-event-emitter/releases/tag/v0.1.0
