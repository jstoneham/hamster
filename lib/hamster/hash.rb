require "forwardable"

require "hamster/immutable"
require "hamster/undefined"
require "hamster/trie"
require "hamster/list"

module Hamster
  def self.hash(pairs = {}, &block)
    Hash.new(pairs, &block)
  end

  class Hash
    extend Forwardable
    include Immutable

    class << self
      def new(pairs = {}, &block)
        @empty ||= super()
        pairs.reduce(block_given? ? super(&block) : @empty) { |hash, pair| hash.put(pair.first, pair.last) }
      end

      attr_reader :empty
    end

    def initialize(&block)
      @trie = EmptyTrie
      @default = block
    end

    def size
      @trie.size
    end
    def_delegator :self, :size, :length

    def empty?
      @trie.empty?
    end
    def_delegator :self, :empty?, :null?

    def key?(key)
      @trie.key?(key)
    end
    def_delegator :self, :key?, :has_key?
    def_delegator :self, :key?, :include?
    def_delegator :self, :key?, :member?

    def get(key)
      entry = @trie.get(key)
      if entry
        entry.value
      elsif @default
        @default.call(key)
      end
    end
    def_delegator :self, :get, :[]

    def fetch(key, default = Undefined)
      entry = @trie.get(key)
      if entry
        entry.value
      elsif default != Undefined
        default
      elsif block_given?
        yield
      else
        raise KeyError, "key not found: #{key.inspect}"
      end
    end

    def put(key, value = Undefined)
      return put(key, yield(get(key))) if value.equal?(Undefined)
      transform { @trie = @trie.put(key, value) }
    end

    def delete(key)
      trie = @trie.delete(key)
      transform_unless(trie.equal?(@trie)) { @trie = trie }
    end

    def each(&block)
      return self unless block_given?
      if block.arity > 1
        @trie.each { |entry| yield(entry.key, entry.value) }
      else
        @trie.each { |entry| yield([entry.key, entry.value]) }
      end
    end
    def_delegator :self, :each, :foreach

    def map(&block)
      return self unless block_given?
      return self if empty?
      if block.arity > 1
        transform { @trie = @trie.reduce(EmptyTrie) { |trie, entry| trie.put(*yield(entry.key, entry.value)) } }
      else
        transform { @trie = @trie.reduce(EmptyTrie) { |trie, entry| trie.put(*yield([entry.key, entry.value])) } }
      end
    end
    def_delegator :self, :map, :collect

    def reduce(memoization, &block)
      return memoization unless block_given?
      if block.arity > 2
        @trie.reduce(memoization) { |memo, entry| yield(memo, entry.key, entry.value) }
      else
        @trie.reduce(memoization) { |memo, entry| yield(memo, [entry.key, entry.value]) }
      end
    end
    def_delegator :self, :reduce, :inject
    def_delegator :self, :reduce, :fold
    def_delegator :self, :reduce, :foldr

    def filter(&block)
      return self unless block_given?
      if block.arity > 1
        trie = @trie.filter { |entry| yield(entry.key, entry.value) }
      else
        trie = @trie.filter { |entry| yield([entry.key, entry.value]) }
      end
      return self.class.empty if trie.empty?
      transform_unless(trie.equal?(@trie)) { @trie = trie }
    end
    def_delegator :self, :filter, :select
    def_delegator :self, :filter, :find_all

    def remove(&block)
      return self unless block_given?
      if block.arity > 1
        filter { |key, value| !yield(key, value) }
      else
        filter { |key, value| !yield([key, value]) }
      end
    end
    def_delegator :self, :remove, :reject
    def_delegator :self, :remove, :delete_if

    def any?(&block)
      return !empty? unless block_given?
      if block.arity > 1
        each { |key, value| return true if yield(key, value) }
      else
        each { |key, value| return true if yield([key, value]) }
      end
      false
    end
    def_delegator :self, :any?, :exist?
    def_delegator :self, :any?, :exists?

    def all?(&block)
      if block_given?
        if block.arity > 1
          each { |key, value| return false unless yield(key, value) } if block_given?
        else
          each { |key, value| return false unless yield([key, value]) } if block_given?
        end
      end
      true
    end
    def_delegator :self, :all?, :forall?

    def none?(&block)
      return empty? unless block_given?
      if block.arity > 1
        each { |key, value| return false if yield(key, value) }
      else
        each { |key, value| return false if yield([key, value]) }
      end
      true
    end

    def find(&block)
      return nil unless block_given?
      if block.arity > 1
        each { |key, value| return Tuple.new(key, value) if yield(key, value) }
      else
        each { |key, value| return Tuple.new(key, value) if yield([key, value]) }
      end
      nil
    end
    def_delegator :self, :find, :detect

    def merge(other)
      # reduce with two-arg block to support ::Hash as well as Hamster::Hash,
      # as ::Hash always reduces with one arg for the pair
      transform { @trie = other.reduce(@trie) {|a, (k, v)| a.put(k, v) } }
    end
    def_delegator :self, :merge, :+

    def except(*keys)
      keys.reduce(self) { |hash, key| hash.delete(key) }
    end

    def slice(*wanted)
      except(*keys - wanted)
    end

    def keys
      reduce(Hamster.set) { |keys, key, value| keys.add(key) }
    end

    def values
      reduce(Hamster.list) { |values, key, value| values.cons(value) }
    end

    def clear
      self.class.empty
    end

    def eql?(other)
      instance_of?(other.class) && @trie.eql?(other.instance_variable_get(:@trie))
    end
    def_delegator :self, :eql?, :==

    def hash
      keys.sort.reduce(0) do |hash, key|
        (hash << 32) - hash + key.hash + get(key).hash
      end
    end

    def_delegator :self, :dup, :uniq
    def_delegator :self, :dup, :nub
    def_delegator :self, :dup, :remove_duplicates

    def inspect
      "{#{reduce([]) { |memo, key, value| memo << "#{key.inspect} => #{value.inspect}" }.join(", ")}}"
    end

    def marshal_dump
      output = {}
      each do |key, value|
        output[key] = value
      end
      output
    end

    def marshal_load(dictionary)
      @trie = dictionary.reduce EmptyTrie do |trie, key_value|
        trie.put(key_value.first, key_value.last)
      end
    end
  end

  EmptyHash = Hamster::Hash.new
end
