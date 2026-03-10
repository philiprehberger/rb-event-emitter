# philiprehberger-event_emitter

[![Gem Version](https://badge.fury.io/rb/philiprehberger-event_emitter.svg)](https://badge.fury.io/rb/philiprehberger-event_emitter)
[![CI](https://github.com/philiprehberger/rb-event-emitter/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-event-emitter/actions/workflows/ci.yml)

Type-safe event emitter with sync and async listeners for Ruby. Thread-safe, zero dependencies.

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

## Development

```sh
bundle install
bundle exec rspec       # Run tests
bundle exec rubocop     # Run linter
bundle exec rake        # Run both
```

## License

MIT - see [LICENSE](LICENSE).
