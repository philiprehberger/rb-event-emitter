# frozen_string_literal: true

require_relative 'lib/philiprehberger/event_emitter/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-event_emitter'
  spec.version = Philiprehberger::EventEmitter::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']

  spec.summary = 'Type-safe event emitter with sync and async listeners'
  spec.description = 'A thread-safe event emitter for Ruby with sync and async listeners, ' \
                     'wildcard event matching, listener priorities, event history with replay, ' \
                     'event metadata, blocking wait, one-time listeners, and a mixin module.'
  spec.homepage = 'https://philiprehberger.com/open-source-packages/ruby/philiprehberger-event_emitter'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/philiprehberger/rb-event-emitter'
  spec.metadata['changelog_uri'] = 'https://github.com/philiprehberger/rb-event-emitter/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/philiprehberger/rb-event-emitter/issues'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']

  spec.require_paths = ['lib']
end
