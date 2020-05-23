# philiprehberger-event_emitter

[![Tests](https://github.com/philiprehberger/rb-event-emitter/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-event-emitter/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-event_emitter.svg)](https://rubygems.org/gems/philiprehberger-event_emitter)
[![License](https://img.shields.io/github/license/philiprehberger/rb-event-emitter)](LICENSE)

Type-safe event emitter with sync/async listeners, wildcards, priorities, and history replay for Ruby

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-event_emitter"
```

Or install directly:

```bash
gem install philiprehberger-event_emitter
```

## Usage

### Standalone emitter

```ruby
require "philiprehberger/event_emitter"

emitter = Philiprehberger::EventEmitter.new

emitter.on(:user_created) do |user|
  puts "Welcome, #{user[:name]}!"
end

emitter.once(:user_created) do |user|
  puts "First user created (fires only once)"
end

emitter.emit(:user_created, { name: "Alice" })
# => Welcome, Alice!
# => First user created (fires only once)

emitter.emit(:user_created, { name: "Bob" })
# => Welcome, Bob!
```

### Mixin module

Include `Philiprehberger::EventEmitter::Mixin` to add event capabilities to any class:

```ruby
class OrderService
  include Philiprehberger::EventEmitter::Mixin

  def place_order(order)
    # ... process order ...
    emit(:order_placed, order)
  end
end

service = OrderService.new
service.on(:order_placed) { |order| puts "Order #{order[:id]} placed" }
service.place_order({ id: 42 })
```

### Error Handling

By default, if a listener raises an exception, it propagates normally. Set an error handler to catch exceptions and allow remaining listeners to fire:

```ruby
emitter = Philiprehberger::EventEmitter.new

emitter.on_error = ->(error) { puts "Listener error: #{error.message}" }

emitter.on(:test) { raise "boom" }
emitter.on(:test) { puts "still runs" }

emitter.emit(:test)
# => Listener error: boom
# => still runs
```

### Max Listeners Warning

A warning is printed when more than 10 listeners are added to a single event (possible memory leak). Configure the threshold:

```ruby
emitter.max_listeners = 20    # raise threshold
emitter.max_listeners = nil   # disable warning
```

### Wildcard Event Matching

Subscribe to multiple events using glob-style patterns. Segments are separated by `.`.

```ruby
emitter = Philiprehberger::EventEmitter.new

# * matches exactly one segment
emitter.on("user.*") do |event_name, data|
  puts "#{event_name}: #{data}"
end

emitter.emit("user.created", { id: 1 })  # triggers wildcard listener
emitter.emit("user.deleted", { id: 2 })  # also triggers it

# ** matches any number of segments (including zero)
emitter.on("app.**") do |event_name|
  puts "App event: #{event_name}"
end

emitter.emit("app.user.profile.updated")  # triggers ** listener
```

Wildcard listeners receive the actual event name as the first argument, followed by the emitted data.

### Listener Priorities

Control the execution order of listeners with `priority:`. Higher values run first. Default priority is 0.

```ruby
emitter.on(:save, priority: 10) { puts "runs first (validation)" }
emitter.on(:save, priority: 5)  { puts "runs second (transform)" }
emitter.on(:save)               { puts "runs last (default priority 0)" }
```

Within the same priority, listeners execute in registration order (FIFO).

### Event History & Replay

Store recent events and let late-binding listeners replay them:

```ruby
emitter = Philiprehberger::EventEmitter.new(history_size: 50)
emitter.emit(:init, { ready: true })

# Later, a new listener can catch up on missed events
emitter.on(:init, replay: true) { |data| puts data }
# => { ready: true }  (fires immediately with the stored event)
```

- `history_size:` controls the maximum number of events stored (default: `0`, meaning disabled)
- `replay: true` on `on()` or `once()` replays matching historical events immediately upon subscription

### Async Emission

Fire-and-forget listener execution in threads:

```ruby
emitter.on(:heavy_work) { |data| process(data) }

threads = emitter.emit_async(:heavy_work, payload)
# Each listener runs in its own Thread
# Returns an array of Thread objects for optional joining
threads.each(&:join)
```

The `on_error` handler catches exceptions from async listeners just as it does for sync ones.

### Event Metadata

Opt in to receive an `EventMetadata` object with event context:

```ruby
emitter.on(:order_placed, metadata: true) do |data, meta|
  puts meta.event_name   # :order_placed
  puts meta.timestamp     # Time when emitted
end

emitter.emit(:order_placed, { id: 42 })
```

Listeners without `metadata: true` are unaffected and receive only the emitted data.

### Removing listeners

```ruby
emitter = Philiprehberger::EventEmitter.new

handler = proc { |msg| puts msg }
emitter.on(:message, &handler)

# Remove a specific listener
emitter.off(:message, &handler)

# Remove all listeners for an event
emitter.off(:message)
```

## API

| Method | Description |
|---|---|
| `on(event, priority: 0, replay: false, metadata: false, &block)` | Register a listener (supports wildcards, priorities, replay, metadata) |
| `once(event, priority: 0, replay: false, metadata: false, &block)` | Register a one-time listener |
| `emit(event, *args, **kwargs)` | Emit an event synchronously to all matching listeners |
| `emit_async(event, *args, **kwargs)` | Emit an event asynchronously, each listener in its own Thread |
| `off(event, &block)` | Remove a specific listener (or all for that event/pattern) |
| `listeners(event)` | Return an array of listener blocks for an event |
| `listener_count(event)` | Return the number of listeners for an event |
| `remove_all_listeners(event = nil)` | Remove all listeners (optionally for a specific event/pattern) |
| `event_names` | Return an array of registered event names |
| `on_error=(handler)` | Set an error handler for listener exceptions |
| `max_listeners=(n)` | Set max listener warning threshold (default: 10, nil to disable) |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
