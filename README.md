# philiprehberger-event_emitter

[![Gem Version](https://badge.fury.io/rb/philiprehberger-event_emitter.svg)](https://badge.fury.io/rb/philiprehberger-event_emitter)
[![CI](https://github.com/philiprehberger/rb-event-emitter/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-event-emitter/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/philiprehberger/rb-event-emitter)](LICENSE)

Type-safe event emitter with sync listeners for Ruby. Thread-safe, zero dependencies.

## Requirements

- Ruby >= 3.1

## Installation

Add this line to your application's Gemfile:

```ruby
gem "philiprehberger-event_emitter"
```

Or install directly:

```sh
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
| `on(event, &block)` | Register a sync listener for an event |
| `once(event, &block)` | Register a listener that fires only once |
| `emit(event, *args, **kwargs)` | Emit an event to all registered listeners |
| `off(event, &block)` | Remove a specific listener |
| `off(event)` | Remove all listeners for an event |
| `listeners(event)` | Return an array of listener blocks for an event |
| `listener_count(event)` | Return the number of listeners for an event |
| `remove_all_listeners(event = nil)` | Remove all listeners (optionally for a specific event) |
| `event_names` | Return an array of registered event names |
| `on_error=(handler)` | Set an error handler for listener exceptions |
| `max_listeners=(n)` | Set max listener warning threshold (default: 10, nil to disable) |

## Development

```sh
bundle install
bundle exec rspec       # Run tests
bundle exec rubocop     # Run linter
bundle exec rake        # Run both
```

## License

MIT - see [LICENSE](LICENSE).
