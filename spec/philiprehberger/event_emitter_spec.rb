# frozen_string_literal: true

require "spec_helper"

RSpec.describe Philiprehberger::EventEmitter do
  describe "VERSION" do
    it "has a version number" do
      expect(Philiprehberger::EventEmitter::VERSION).to eq("0.1.0")
    end
  end

  describe ".new" do
    it "returns an Emitter instance" do
      expect(described_class.new).to be_a(Philiprehberger::EventEmitter::Emitter)
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
  end
end
