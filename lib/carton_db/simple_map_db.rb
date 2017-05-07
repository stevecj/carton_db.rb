require 'forwardable'

module CartonDb

  # A map with strings as keys and values that can each be either
  # a string or nil.
  #
  # Data storage is in the same form as ListMapDb, but string
  # values are stored as single-element lists and nil values are
  # stored as empty lists. Only the first element in an entry's
  # content is significant when retrieving a value from a
  # multi-element underlying entry.
  #
  # See the documentation for CartonDb::ListMapDb for additional
  # details.
  class SimpleMapDb
    extend Forwardable
    include Enumerable

    # Initializes an instance that interacts with the database
    # identified by the given name, which is the full path to a
    # directory in the filesystem.
    #
    # See the documentation for CartonDb::ListMapDb#initialize
    # for additional details.
    #
    # @param name [String] The full path of the directory in the
    #   filesystem in which the data is stored or will be stored.
    def initialize(name)
      self.list_map_db = CartonDb::ListMapDb.new(name)
    end

    # Creates a new entry or replaces the contents of the
    # existing entry identified by the given key.
    #
    # See the documentation for CartonDb::ListMapDb#initialize
    # for performance characteristics.
    #
    # @param key [String] The key identifying the entry.
    # @param value [String, nil] The value to be stored.
    def []=(key, value)
      content = value.nil? ? [] : [value.to_s]
      list_map_db[key] = content
    end

    # Returns the content of the entry identified by the given
    # key or nil if no such entry exists.
    #
    # See the documentation for CartonDb::ListMapDb#initialize
    # for performance characteristics.
    #
    # @param key [String] The key identifying the entry.
    # @return [String, nil] if a matching entry exists.
    # @return [nil] if no matching entry exists.
    def [](key)
      content = list_map_db[key]
      content&.first
    end

    # See CartonDb::ListMapDb#empty?
    def_delegator :list_map_db, :empty?

    # See CartonDb::ListMapDb#count
    def_delegator :list_map_db, :count

    # See CartonDb::ListMapDb#Key?
    def_delegator :list_map_db, :key?

    # See CartonDb::ListMapDb#delete
    def_delegator :list_map_db, :delete

    # Creates an entry with a nil value if no entry exists for
    # the given key. Has no effect on the value of the entry if
    # it already exists.
    #
    # See the documentation for CartonDb::ListMapDb#touch for
    # performance characteristics.
    #
    # @param key [String] The key identifying the entry.
    # @param optimization[:small, :fast] The optimization mode.
    def_delegator :list_map_db, :touch

    # See CartonDb::ListMapDb#clear
    def_delegator :list_map_db, :clear

    # Yields each entry in the database as a key/value pair.
    #
    # See the documentation for CartonDb::ListMapDb#yield for
    # performance characteristics.
    #
    # @yieldparam key [String] The key of the entry.
    # @yeildparam array [Array<String>] The elements of the list
    #   entry's content.
    def_delegator :list_map_db, :each_first_element, :each

    private

    attr_accessor :list_map_db

  end

end
