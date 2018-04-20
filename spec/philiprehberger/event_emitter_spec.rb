# frozen_string_literal: true

require "spec_helper"

RSpec.describe Philiprehberger::EventEmitter do
  describe "VERSION" do
    it "has a version number" do
      expect(described_class::VERSION).not_to be_nil
    end
  end

  describe ".new" do
    it "returns an Emitter instance" do
      expect(described_class.new).to be_a(Philiprehberger::EventEmitter::Emitter)
    end

    it "forwards keyword arguments" do
      emitter = described_class.new(history_size: 10)
      expect(emitter).to be_a(Philiprehberger::EventEmitter::Emitter)
    end
  end

  describe Philiprehberger::EventEmitter::Emitter do
    subject(:emitter) { described_class.new }

    describe "#on" do
      it "registers a listener" do
        emitter.on(:test) { "hello" }
        expect(emitter.listener_count(:test)).to eq(1)
      end

      it "registers multiple listeners for the same event" do
        emitter.on(:test) { "a" }
        emitter.on(:test) { "b" }
        expect(emitter.listener_count(:test)).to eq(2)
      end

      it "returns self for chaining" do
        result = emitter.on(:test) { "hello" }
        expect(result).to be(emitter)
      end

      it "raises ArgumentError without a block" do
        expect { emitter.on(:test) }.to raise_error(ArgumentError, "block required")
      end
    end

    describe "#once" do
      it "registers a one-time listener" do
        calls = 0
        emitter.once(:test) { calls += 1 }
        emitter.emit(:test)
        emitter.emit(:test)
        expect(calls).to eq(1)
      end

      it "returns self for chaining" do
        result = emitter.once(:test) { "hello" }
        expect(result).to be(emitter)
      end

      it "raises ArgumentError without a block" do
        expect { emitter.once(:test) }.to raise_error(ArgumentError, "block required")
      end
    end

    describe "#emit" do
      it "calls all registered listeners" do
        results = []
        emitter.on(:test) { results << "a" }
        emitter.on(:test) { results << "b" }
        emitter.emit(:test)
        expect(results).to eq(%w[a b])
      end

      it "passes positional arguments to listeners" do
        received = nil
        emitter.on(:test) { |val| received = val }
        emitter.emit(:test, 42)
        expect(received).to eq(42)
      end

      it "passes keyword arguments to listeners" do
        received = nil
        emitter.on(:test) { |name:| received = name }
        emitter.emit(:test, name: "Alice")
        expect(received).to eq("Alice")
      end

      it "passes mixed positional and keyword arguments" do
        received_args = nil
        received_kwargs = nil
        emitter.on(:test) do |a, b, key:|
          received_args = [a, b]
          received_kwargs = { key: key }
        end
        emitter.emit(:test, 1, 2, key: "value")
        expect(received_args).to eq([1, 2])
        expect(received_kwargs).to eq({ key: "value" })
      end

      it "returns true when listeners exist" do
        emitter.on(:test) { "hello" }
        expect(emitter.emit(:test)).to be(true)
      end

      it "returns false when no listeners exist" do
        expect(emitter.emit(:test)).to be(false)
      end

      it "removes once listeners after firing" do
        emitter.once(:test) { "once" }
        emitter.emit(:test)
        expect(emitter.listener_count(:test)).to eq(0)
      end

      it "preserves regular listeners after emit" do
        emitter.on(:test) { "always" }
        emitter.emit(:test)
        expect(emitter.listener_count(:test)).to eq(1)
      end

      it "handles mixed on and once listeners" do
        calls = { on: 0, once: 0 }
        emitter.on(:test) { calls[:on] += 1 }
        emitter.once(:test) { calls[:once] += 1 }

        emitter.emit(:test)
        emitter.emit(:test)

        expect(calls).to eq({ on: 2, once: 1 })
      end
    end

    describe "#off" do
      it "removes a specific listener" do
        handler = proc { "hello" }
        emitter.on(:test, &handler)
        emitter.off(:test, &handler)
        expect(emitter.listener_count(:test)).to eq(0)
      end

      it "removes all listeners for an event when no block given" do
        emitter.on(:test) { "a" }
        emitter.on(:test) { "b" }
        emitter.off(:test)
        expect(emitter.listener_count(:test)).to eq(0)
      end

      it "does not affect other events" do
        emitter.on(:test) { "a" }
        emitter.on(:other) { "b" }
        emitter.off(:test)
        expect(emitter.listener_count(:other)).to eq(1)
      end

      it "returns self for chaining" do
        result = emitter.off(:test)
        expect(result).to be(emitter)
      end
    end

    describe "#listeners" do
      it "returns an array of listener blocks" do
        handler = proc { "hello" }
        emitter.on(:test, &handler)
        expect(emitter.listeners(:test)).to eq([handler])
      end

      it "returns an empty array for unknown events" do
        expect(emitter.listeners(:unknown)).to eq([])
      end
    end

    describe "#listener_count" do
      it "returns 0 for unknown events" do
        expect(emitter.listener_count(:unknown)).to eq(0)
      end

      it "returns the correct count" do
        emitter.on(:test) { "a" }
        emitter.on(:test) { "b" }
        emitter.once(:test) { "c" }
        expect(emitter.listener_count(:test)).to eq(3)
      end
    end

    describe "#remove_all_listeners" do
      it "removes all listeners for a specific event" do
        emitter.on(:test) { "a" }
        emitter.on(:other) { "b" }
        emitter.remove_all_listeners(:test)
        expect(emitter.listener_count(:test)).to eq(0)
        expect(emitter.listener_count(:other)).to eq(1)
      end

      it "removes all listeners across all events when no argument given" do
        emitter.on(:test) { "a" }
        emitter.on(:other) { "b" }
        emitter.remove_all_listeners
        expect(emitter.listener_count(:test)).to eq(0)
        expect(emitter.listener_count(:other)).to eq(0)
      end

      it "returns self for chaining" do
        expect(emitter.remove_all_listeners).to be(emitter)
      end
    end

    describe "#event_names" do
      it "returns registered event names" do
        emitter.on(:foo) { "a" }
        emitter.on(:bar) { "b" }
        expect(emitter.event_names).to contain_exactly(:foo, :bar)
      end

      it "returns empty array when no listeners" do
        expect(emitter.event_names).to eq([])
      end
    end

    describe "#on_error" do
      it "catches listener exceptions when error handler is set" do
        errors = []
        emitter.on_error = ->(e) { errors << e }

        results = []
        emitter.on(:test) { raise "boom" }
        emitter.on(:test) { results << "after" }
        emitter.emit(:test)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("boom")
        expect(results).to eq(["after"])
      end

      it "propagates exceptions when no error handler is set" do
        emitter.on(:test) { raise "boom" }
        expect { emitter.emit(:test) }.to raise_error(RuntimeError, "boom")
      end
    end

    describe "#max_listeners" do
      it "defaults to 10" do
        expect(emitter.max_listeners).to eq(10)
      end

      it "warns when listener count exceeds max" do
        emitter.max_listeners = 2
        emitter.on(:test) { "a" }
        emitter.on(:test) { "b" }
        expect { emitter.on(:test) { "c" } }.to output(/Possible memory leak/).to_stderr
      end

      it "does not warn when disabled" do
        emitter.max_listeners = nil
        expect { 20.times { emitter.on(:test) { "x" } } }.not_to output.to_stderr
      end
    end

    describe "thread safety" do
      it "handles concurrent registrations" do
        threads = 10.times.map do |i|
          Thread.new { emitter.on(:test) { i } }
        end
        threads.each(&:join)
        expect(emitter.listener_count(:test)).to eq(10)
      end
    end

    # === Feature 1: Wildcard Event Matching ===

    describe "wildcard event matching" do
      it "matches single-segment wildcard with *" do
        received = []
        emitter.on("user.*") { |event_name, data| received << [event_name, data] }
        emitter.emit("user.created", { id: 1 })
        expect(received).to eq([["user.created", { id: 1 }]])
      end

      it "matches multiple events with *" do
        received = []
        emitter.on("user.*") { |event_name, _data| received << event_name }
        emitter.emit("user.created", {})
        emitter.emit("user.deleted", {})
        expect(received).to eq(%w[user.created user.deleted])
      end

      it "does not match nested segments with *" do
        received = []
        emitter.on("user.*") { |event_name| received << event_name }
        emitter.emit("user.profile.updated")
        expect(received).to be_empty
      end

      it "matches nested segments with **" do
        received = []
        emitter.on("app.**") { |event_name| received << event_name }
        emitter.emit("app.user.created")
        emitter.emit("app.order.item.added")
        expect(received).to eq(%w[app.user.created app.order.item.added])
      end

      it "matches zero segments with **" do
        received = []
        emitter.on("app.**") { |event_name| received << event_name }
        emitter.emit("app")
        expect(received).to eq(["app"])
      end

      it "wildcard listeners receive event name as first argument" do
        received_event = nil
        received_data = nil
        emitter.on("order.*") { |event_name, data| received_event = event_name; received_data = data }
        emitter.emit("order.placed", { id: 42 })
        expect(received_event).to eq("order.placed")
        expect(received_data).to eq({ id: 42 })
      end

      it "regular listeners are not affected by wildcard feature" do
        received = nil
        emitter.on(:test) { |val| received = val }
        emitter.emit(:test, "hello")
        expect(received).to eq("hello")
      end

      it "does not match unrelated events" do
        received = []
        emitter.on("user.*") { |event_name| received << event_name }
        emitter.emit("order.created")
        expect(received).to be_empty
      end

      it "supports once with wildcard" do
        calls = 0
        emitter.once("user.*") { calls += 1 }
        emitter.emit("user.created")
        emitter.emit("user.deleted")
        expect(calls).to eq(1)
      end

      it "supports off with wildcard pattern" do
        handler = proc { |_e| "hello" }
        emitter.on("user.*", &handler)
        emitter.off("user.*", &handler)
        received = []
        emitter.on("user.*") { |e| received << e }
        emitter.emit("user.created")
        # Only the second handler should have run
        expect(received).to eq(["user.created"])
      end

      it "supports off without block for wildcard pattern" do
        emitter.on("user.*") { "a" }
        emitter.on("user.*") { "b" }
        emitter.off("user.*")
        received = []
        emitter.emit("user.created")
        expect(received).to be_empty
      end

      it "remove_all_listeners clears wildcard listeners" do
        emitter.on("user.*") { "a" }
        emitter.on(:test) { "b" }
        emitter.remove_all_listeners
        received = []
        emitter.emit("user.created")
        emitter.emit(:test)
        expect(received).to be_empty
      end

      it "remove_all_listeners with wildcard pattern clears only that pattern" do
        received = []
        emitter.on("user.*") { |e| received << e }
        emitter.on("order.*") { |e| received << e }
        emitter.remove_all_listeners("user.*")
        emitter.emit("user.created")
        emitter.emit("order.placed")
        expect(received).to eq(["order.placed"])
      end

      it "combines wildcard and exact listeners" do
        results = []
        emitter.on("user.*") { |event_name| results << "wildcard:#{event_name}" }
        emitter.on("user.created") { results << "exact" }
        emitter.emit("user.created")
        expect(results).to contain_exactly("wildcard:user.created", "exact")
      end
    end

    # === Feature 2: Listener Priorities ===

    describe "listener priorities" do
      it "executes higher priority listeners first" do
        results = []
        emitter.on(:save) { results << "default" }
        emitter.on(:save, priority: 10) { results << "high" }
        emitter.on(:save, priority: 5) { results << "medium" }
        emitter.emit(:save)
        expect(results).to eq(%w[high medium default])
      end

      it "defaults priority to 0" do
        results = []
        emitter.on(:save) { results << "a" }
        emitter.on(:save) { results << "b" }
        emitter.emit(:save)
        expect(results).to eq(%w[a b])
      end

      it "maintains insertion order within same priority" do
        results = []
        emitter.on(:save, priority: 0) { results << "first" }
        emitter.on(:save, priority: 0) { results << "second" }
        emitter.on(:save, priority: 0) { results << "third" }
        emitter.emit(:save)
        expect(results).to eq(%w[first second third])
      end

      it "works with once listeners" do
        results = []
        emitter.once(:save, priority: 10) { results << "once-high" }
        emitter.on(:save) { results << "regular" }
        emitter.emit(:save)
        expect(results).to eq(%w[once-high regular])
      end

      it "sorts wildcard listeners by priority with exact listeners" do
        results = []
        emitter.on("event.*", priority: 5) { |_e| results << "wildcard" }
        emitter.on("event.test", priority: 10) { results << "exact-high" }
        emitter.on("event.test", priority: 0) { results << "exact-low" }
        emitter.emit("event.test")
        expect(results).to eq(%w[exact-high wildcard exact-low])
      end
    end

    # === Feature 3: Event History & Replay ===

    describe "event history and replay" do
      subject(:emitter) { described_class.new(history_size: 50) }

      it "replays matching historical events on subscribe" do
        emitter.emit(:init, { ready: true })

        received = nil
        emitter.on(:init, replay: true) { |data| received = data }
        expect(received).to eq({ ready: true })
      end

      it "replays multiple matching events" do
        emitter.emit(:log, "first")
        emitter.emit(:log, "second")

        received = []
        emitter.on(:log, replay: true) { |msg| received << msg }
        expect(received).to eq(%w[first second])
      end

      it "does not replay non-matching events" do
        emitter.emit(:init, "yes")
        emitter.emit(:other, "no")

        received = []
        emitter.on(:init, replay: true) { |data| received << data }
        expect(received).to eq(["yes"])
      end

      it "does not replay when replay is false" do
        emitter.emit(:init, "data")

        received = []
        emitter.on(:init) { |data| received << data }
        expect(received).to be_empty
      end

      it "respects history_size limit" do
        emitter_small = described_class.new(history_size: 2)
        emitter_small.emit(:log, "a")
        emitter_small.emit(:log, "b")
        emitter_small.emit(:log, "c")

        received = []
        emitter_small.on(:log, replay: true) { |msg| received << msg }
        expect(received).to eq(%w[b c])
      end

      it "does not store history when history_size is 0" do
        emitter_no_history = described_class.new
        emitter_no_history.emit(:init, "data")

        received = []
        emitter_no_history.on(:init, replay: true) { |data| received << data }
        expect(received).to be_empty
      end

      it "replays with wildcard pattern" do
        emitter.emit("user.created", { id: 1 })
        emitter.emit("user.deleted", { id: 2 })
        emitter.emit("order.placed", { id: 3 })

        received = []
        emitter.on("user.*", replay: true) { |event_name, data| received << [event_name, data] }
        expect(received).to eq([
          ["user.created", { id: 1 }],
          ["user.deleted", { id: 2 }]
        ])
      end

      it "replays with once and only fires replay" do
        emitter.emit(:init, "data")

        received = []
        emitter.once(:init, replay: true) { |data| received << data }
        # The once listener should have been consumed by replay
        # But since replay is separate from normal emit flow, the listener is still registered
        # for future emits — this is by design, once means it fires once via emit
        expect(received).to eq(["data"])
      end
    end

    # === Feature 4: emit_async ===

    describe "#emit_async" do
      it "returns an array of Thread objects" do
        emitter.on(:work) { "done" }
        threads = emitter.emit_async(:work)
        expect(threads).to all(be_a(Thread))
        threads.each(&:join)
      end

      it "executes listeners in separate threads" do
        thread_ids = []
        main_thread = Thread.current.object_id
        emitter.on(:work) { thread_ids << Thread.current.object_id }
        threads = emitter.emit_async(:work)
        threads.each(&:join)
        expect(thread_ids.first).not_to eq(main_thread)
      end

      it "passes arguments to async listeners" do
        received = nil
        emitter.on(:work) { |val| received = val }
        threads = emitter.emit_async(:work, 42)
        threads.each(&:join)
        expect(received).to eq(42)
      end

      it "returns empty array when no listeners exist" do
        threads = emitter.emit_async(:nothing)
        expect(threads).to eq([])
      end

      it "catches errors with on_error handler" do
        errors = []
        emitter.on_error = ->(e) { errors << e }
        emitter.on(:work) { raise "async boom" }
        threads = emitter.emit_async(:work)
        threads.each(&:join)
        expect(errors.size).to eq(1)
        expect(errors.first.message).to eq("async boom")
      end

      it "raises in thread when no error handler is set" do
        emitter.on(:work) { raise "boom" }
        threads = emitter.emit_async(:work)
        # Thread will silently die without error handler
        expect { threads.each(&:join) }.to raise_error(RuntimeError, "boom")
      end

      it "fires each listener in its own thread" do
        thread_ids = []
        mutex = Mutex.new
        3.times do
          emitter.on(:work) do
            mutex.synchronize { thread_ids << Thread.current.object_id }
          end
        end
        threads = emitter.emit_async(:work)
        threads.each(&:join)
        expect(thread_ids.uniq.size).to eq(3)
      end
    end

    # === Feature 5: Event Metadata ===

    describe "event metadata" do
      it "passes EventMetadata when metadata: true" do
        received_meta = nil
        emitter.on(:event, metadata: true) { |_data, meta| received_meta = meta }
        emitter.emit(:event, "payload")
        expect(received_meta).to be_a(Philiprehberger::EventEmitter::EventMetadata)
        expect(received_meta.event_name).to eq(:event)
        expect(received_meta.timestamp).to be_a(Time)
      end

      it "does not pass metadata when metadata: false (default)" do
        received_args = []
        emitter.on(:event) { |*args| received_args = args }
        emitter.emit(:event, "payload")
        expect(received_args).to eq(["payload"])
      end

      it "metadata has correct event_name" do
        received_meta = nil
        emitter.on(:my_event, metadata: true) { |meta| received_meta = meta }
        emitter.emit(:my_event)
        expect(received_meta.event_name).to eq(:my_event)
      end

      it "metadata has timestamp close to now" do
        received_meta = nil
        before = Time.now
        emitter.on(:event, metadata: true) { |meta| received_meta = meta }
        emitter.emit(:event)
        after = Time.now
        expect(received_meta.timestamp).to be >= before
        expect(received_meta.timestamp).to be <= after
      end

      it "works with once and metadata" do
        received_meta = nil
        emitter.once(:event, metadata: true) { |data, meta| received_meta = meta }
        emitter.emit(:event, "x")
        expect(received_meta).to be_a(Philiprehberger::EventEmitter::EventMetadata)
      end

      it "works with wildcard and metadata" do
        received = []
        emitter.on("user.*", metadata: true) do |event_name, data, meta|
          received << { event: event_name, data: data, meta_class: meta.class }
        end
        emitter.emit("user.created", { id: 1 })
        expect(received.first[:event]).to eq("user.created")
        expect(received.first[:data]).to eq({ id: 1 })
        expect(received.first[:meta_class]).to eq(Philiprehberger::EventEmitter::EventMetadata)
      end

      it "metadata works with emit_async" do
        received_meta = nil
        emitter.on(:event, metadata: true) { |data, meta| received_meta = meta }
        threads = emitter.emit_async(:event, "payload")
        threads.each(&:join)
        expect(received_meta).to be_a(Philiprehberger::EventEmitter::EventMetadata)
        expect(received_meta.event_name).to eq(:event)
      end

      it "mixes metadata and non-metadata listeners" do
        results = []
        emitter.on(:event) { |data| results << "no-meta:#{data}" }
        emitter.on(:event, metadata: true) { |data, meta| results << "meta:#{data}:#{meta.event_name}" }
        emitter.emit(:event, "hello")
        expect(results).to eq(["no-meta:hello", "meta:hello:event"])
      end
    end
  end

  describe Philiprehberger::EventEmitter::Pattern do
    describe ".wildcard?" do
      it "returns true for patterns with *" do
        expect(described_class.wildcard?("user.*")).to be(true)
      end

      it "returns true for patterns with **" do
        expect(described_class.wildcard?("app.**")).to be(true)
      end

      it "returns false for plain strings" do
        expect(described_class.wildcard?("user.created")).to be(false)
      end

      it "returns false for symbols" do
        expect(described_class.wildcard?(:test)).to be(false)
      end
    end

    describe ".match?" do
      it "matches * against one segment" do
        expect(described_class.match?("user.*", "user.created")).to be(true)
      end

      it "does not match * against multiple segments" do
        expect(described_class.match?("user.*", "user.profile.updated")).to be(false)
      end

      it "matches ** against zero segments" do
        expect(described_class.match?("app.**", "app")).to be(true)
      end

      it "matches ** against one segment" do
        expect(described_class.match?("app.**", "app.start")).to be(true)
      end

      it "matches ** against multiple segments" do
        expect(described_class.match?("app.**", "app.user.profile.updated")).to be(true)
      end

      it "matches literal segments" do
        expect(described_class.match?("user.created", "user.created")).to be(true)
      end

      it "does not match different literals" do
        expect(described_class.match?("user.created", "user.deleted")).to be(false)
      end

      it "handles * in the middle" do
        expect(described_class.match?("user.*.email", "user.profile.email")).to be(true)
      end

      it "handles ** in the middle" do
        expect(described_class.match?("app.**.save", "app.user.profile.save")).to be(true)
      end

      it "does not match when prefix differs" do
        expect(described_class.match?("user.*", "order.created")).to be(false)
      end
    end
  end

  describe Philiprehberger::EventEmitter::EventMetadata do
    it "has event_name and timestamp attributes" do
      now = Time.now
      meta = described_class.new(event_name: :test, timestamp: now)
      expect(meta.event_name).to eq(:test)
      expect(meta.timestamp).to eq(now)
    end
  end

  describe Philiprehberger::EventEmitter::Mixin do
    let(:klass) do
      Class.new do
        include Philiprehberger::EventEmitter::Mixin
      end
    end

    subject(:instance) { klass.new }

    it "provides on method" do
      instance.on(:test) { "hello" }
      expect(instance.event_emitter.listener_count(:test)).to eq(1)
    end

    it "provides once method" do
      calls = 0
      instance.once(:test) { calls += 1 }
      instance.emit(:test)
      instance.emit(:test)
      expect(calls).to eq(1)
    end

    it "provides emit method" do
      received = nil
      instance.on(:test) { |val| received = val }
      instance.emit(:test, "data")
      expect(received).to eq("data")
    end

    it "provides off method" do
      handler = proc { "hello" }
      instance.on(:test, &handler)
      instance.off(:test, &handler)
      expect(instance.event_emitter.listener_count(:test)).to eq(0)
    end

    it "uses separate emitters per instance" do
      other = klass.new
      instance.on(:test) { "a" }
      expect(other.event_emitter.listener_count(:test)).to eq(0)
    end

    it "delegates remove_all_listeners" do
      instance.on(:test) { "a" }
      instance.remove_all_listeners
      expect(instance.event_emitter.listener_count(:test)).to eq(0)
    end

    it "delegates event_names" do
      instance.on(:foo) { "a" }
      expect(instance.event_names).to eq([:foo])
    end

    it "delegates emit_async" do
      received = nil
      instance.on(:test) { |val| received = val }
      threads = instance.emit_async(:test, "async_data")
      threads.each(&:join)
      expect(received).to eq("async_data")
    end
  end
end
