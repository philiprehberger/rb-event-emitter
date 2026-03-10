# frozen_string_literal: true

require_relative "lib/philiprehberger/event_emitter/version"

Gem::Specification.new do |spec|
  spec.name = "philiprehberger-event_emitter"
  spec.version = Philiprehberger::EventEmitter::VERSION
  spec.authors = ["Philip Rehberger"]
  spec.email = ["me@philiprehberger.com"]

  spec.summary = "Type-safe event emitter with sync and async listeners"
  spec.description = "A thread-safe event emitter for Ruby with support for sync listeners, " \
    "one-time listeners, and a convenient mixin module."
  spec.homepage = "https://github.com/philiprehberger/rb-event-emitter"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[spec/ .git .github Gemfile Rakefile .rubocop])
    end
  end

  spec.require_paths = ["lib"]
end
