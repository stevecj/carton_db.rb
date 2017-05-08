require 'set'
require 'forwardable'

module CartonDb

  class SetMapDb
    extend Forwardable

    def initialize(name)
      self.list_map_db = CartonDb::ListMapDb.new(name)
    end

    # Creates a new entry or replaces the contents of the
    # existing entry identified by the given key.
    #
    # The is a fairly fast operation, but can be somewhat
    # slower in a large database.
    #
    # @param key [String] The key identifying the entry.
    # @param content [Set<String>] A set or other enumerable
    #   collection of 0 or more list element string values to be
    #   stored.
    def []=(key, content)
      content = Set.new(content) unless content.is_a?(Set)
      list_map_db[key] = content
    end

    # Returns the content of the entry identified by the given
    # key or nil if no such entry exists.
    #
    # This operation is fast, but may be slower for a larger
    # database.
    #
    # @param key [String] The key identifying the entry.
    # @return [Set<String>] if a matching entry exists.
    # @return [nil] if no matching entry exists.
    def [](key)
      list = list_map_db[key]
      list && Set.new(list)
    end

    # See CartonDb::ListMapDb#empty?
    def_delegator :list_map_db, :empty?

    # see cartondb::listmapdb#count
    def_delegator :list_map_db, :count

    # See CartonDb::ListMapDb#Key?
    def_delegator :list_map_db, :key?

    # See CartonDb::ListMapDb#touch_element
    def_delegator :list_map_db, :touch_element

    # See CartonDb::ListMapDb#delete
    def_delegator :list_map_db, :delete

    # Creates an entry with an empty set as its content if no
    # entry exists for the given key. Has no effect on the content
    # of the entry if it already exists.
    #
    # See the documentation for CartonDb::ListMapDb#touch for
    # performance characteristics.
    #
    # @param key [String] The key identifying the entry.
    # @param optimization[:small, :fast] The optimization mode.
    def_delegator :list_map_db, :touch

    # See CartonDb::ListMapDb#clear
    def_delegator :list_map_db, :clear

    # Performs a set-wise merge of the given elements with the
    # content of an entry. Adds whatever elements are necessary
    # so the content has an element corresponding to unique
    # given element.
    #
    # See the documentation for
    # CartonDb::ListMapDb#merge_elements for performance
    # characteristics.
    #
    # @param key [String] The key identifying the entry.
    # @param elements [Set<String>] A set or other enumerable
    #   collection of elements to be added as applicable.
    def merge_elements(key, elements)
      elements = Set.new(content) unless elements.is_a?(Set)
      list_map_db.merge_elements key, elements
    end

    # See CartonDb::ListMapDb#element?
    def_delegator :list_map_db, :element?

    # Yields each entry in the database as a key/array pair.
    #
    # See the documentation for CartonDb::ListMapDb#each for
    # performance characteristics.
    #
    # @yieldparam key [String] The key of the entry.
    # @yeildparam array [Array<String>] The elements of the list
    #   entry's content.
    def each
      list_map_db.each do |key, list|
        yield key, Set.new(list)
      end
    end

    private

    attr_accessor :list_map_db

  end

end
