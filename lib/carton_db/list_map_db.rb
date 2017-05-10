# -*- coding: UTF-8 -*-
# frozen_string_literal: true

require 'forwardable'
require 'fileutils'
require 'carton_db/list_map_db/segment'
require 'carton_db/list_map_db/segment_group'

module CartonDb

  # A map with strings as keys and lists of strings as contents.
  #
  # This is suitable for storing a total number of elements as
  # large as the low millions, with each entry containing a
  # number of elements in the hundreds or low thousands.
  class ListMapDb
    extend Forwardable
    include Enumerable

    FILE_ENCODING_OPTS = {
      internal_encoding: Encoding::UTF_8,
      external_encoding: Encoding::UTF_8
    }.freeze

    # Initializes an instance that interacts with the database
    # identified by the given name, which is the full path to a
    # directory in the filesystem.
    #
    # The directory for the database will be created if it does
    # not already exist.
    #
    # The parent directory is assumed to already exist, and an
    # exception will be raised if it does not.
    #
    # Other instance methods assume that the directory exists but
    # make no other assumptions about the state of the persisted
    # data, and an empty directory is a valid representation of
    # an empty database.
    #
    # This is a very fast operation.
    #
    # @param name [String] The full path of the directory in the
    #   filesystem in which the data is stored or will be stored.
    def initialize(name)
      self.name = name
      FileUtils.mkdir name unless File.directory?(name)
    end

    # Creates a new entry or replaces the contents of the
    # existing entry identified by the given key.
    #
    # The is a fairly fast operation, but can be somewhat
    # slower in a large database. Note that appending and
    # concatenating may be faster than assignment.
    #
    # @param key [String] The key identifying the entry.
    # @param content [Array<String>] An array or other
    #   enumerable collection of 0 or more list element string
    #   values to be stored.
    def []=(key, content)
      key_d = CartonDb::Datum.for_plain(key)
      segment = segment_containing(key_d)
      if segment.empty?
        concat_elements key_d.plain, content
      else
        replace_entry_in_file segment, key_d, content
      end
    end

    # Returns the content of the entry identified by the given
    # key or nil if no such entry exists.
    #
    # This operation is fast, but may be slower for a larger
    # database.
    #
    # @param key [String] The key identifying the entry.
    # @return [Array<String>] if a matching entry exists.
    # @return [nil] if no matching entry exists.
    def [](key)
      key_d = CartonDb::Datum.for_plain(key)
      segment = segment_containing(key_d)
      segment.collect_content(key_d, Array)
    end

    # Returns true if an entry with the given key exists.
    #
    # Performance is similar to #[] but may be somewhat faster
    # when a key is found since it doesn't need to ensure that
    # it has read all of the elements for an entry.
    #
    # @param key [String] The key identifying the entry.
    def key?(key)
      key_d = CartonDb::Datum.for_plain(key)
      segment = segment_containing(key_d)
      segment.key_d?(key_d)
    end

    # Returns trus if an entry with the given key exists and its
    # content includes at least one element with the given
    # element value.
    #
    # Performance is similar to #key?
    #
    # @param key [String] The key identifying the entry.
    # @param element [String] The element value to match.
    def element?(key, element)
      key_d = CartonDb::Datum.for_plain(key)
      element_d = CartonDb::Datum.for_plain(element)
      segment = segment_containing(key_d)
      segment.element_d?(key_d, element_d)
    end

    # Returns true if the map has no entries.
    #
    # This is a fairly fast operation.
    #
    # @return [Boolean]
    def empty?
      ListMapDb::Segment.each_in_db name do |segment|
        return false unless segment.empty?
      end
      true
    end

    # Returns the number of entries in the map.
    #
    # This operation scans the entire database to count the keys,
    # so it can be be a slow operation if the database is large.
    #
    # @return [Fixnum]
    def count
      key_count = 0
      ListMapDb::Segment.each_in_db name do |segment|
        key_count += segment.key_count
      end
      key_count
    end

    # Creates an entry with an empty list as its content if no
    # entry exists for the given key. Has no effect on the content
    # of the entry if it already exists.
    #
    # Using :small optimization (the default), the operation may
    # be slow for a large database since it checks for the
    # existence of the key before marking its existence.
    #
    # Using :fast optimization, the operation will always be
    # fast, but it will add a mark for the existence of the key
    # even if that is redundant, thus adding to the size of the
    # stored data.
    #
    # @param key [String] The key identifying the entry.
    # @param optimization[:small, :fast] The optimization mode.
    def touch(key, optimization: :small)
      if optimization != :small && optimization != :fast
        raise ArgumentError, "Invalid optimization value. Must be :small or :fast"
      end

      key_d = CartonDb::Datum.for_plain(key)
      segment = segment_containing(key_d)
      segment.touch_d key_d, optimization
    end

    # Removes all entries from the database, leaving it empty.
    #
    # This operation can be somewhat slow for a large database.
    #
    def clear
      ListMapDb::Segment.clear_all_in_db name
    end

    # Yields each entry in the database as a key/array pair.
    #
    # This operation can take a lot of total time for a large
    # database, but yields entries pretty rapidly regardless
    # of database size.
    #
    # @yieldparam key [String] The key of the entry.
    # @yeildparam array [Array<String>] The elements of the list
    #   entry's content.
    def each
      key_arrays_slice = {}
      ListMapDb::Segment.each_in_db name do |segment|
        segment.each_entry do |key, content|
          yield key, content
        end
      end
    end

    # For each entry in the database, yields the first element
    # in the entry's content or nil if the content is an empty
    # list.
    #
    # Performance is pretty much identical to that of #each.
    #
    # @yieldparam key [String] The key of the entry.
    # @yeildparam array [String, nil] The first element of the
    #   entry's content.
    def each_first_element
      ListMapDb::Segment.each_in_db name do |segment|
        segment.each_first_element do |key, element|
          yield key, element
        end
      end
    end

    # Removes an entry from the database. Has no effect if the
    # entry already does not exist.
    #
    # This operation is fast, but may be slower for a larger
    # database.
    #
    # @param key [String] The key identifying the entry to be
    #   deleted.
    def delete(key)
      key_d = CartonDb::Datum.for_plain(key)
      segment = segment_containing(key_d)
      return if segment.empty?

      segment.replace do |repl_io|
        segment.copy_entries_except key_d, repl_io
      end
    end

    # Appends an element string to the content of an entry.
    # If the entry does not already exist, then one is
    # created with a list containing the given element as its
    # content.
    #
    # Since this will only append text to a file within the
    # database, it is a very fast operation.
    #
    # @param key [String] The key identifying the entry.
    # @param element [String] The element to be appended to the
    #   content of the entry.
    def append_element(key, element)
      key_d = CartonDb::Datum.for_plain(key)
      element_d = CartonDb::Datum.for_plain(element)
      segment = segment_containing(key_d)
      segment.write_key_element_d key_d, element_d
    end

    # Appends any number of element strings to the content of an
    # entry. If the entry does not already exist, then one is
    # created with the given list as its content.
    #
    # Appending an empty or nil collection is equivalent to
    # invoking `db.touch key, optimization: :small`.
    #
    # When appending a non-empty collection, this is a fast
    # operation since it only appends text to an existing file.
    #
    # @param key [String] The key identifying the entry.
    # @param elements [Array<String>] An array or other
    #   enumerable collection of elements to append.
    def concat_elements(key, elements)
      if empty_collection?(elements)
        touch key, optimization: :small
      else
        concat_any_elements key, elements
      end
    end

    # Appends any number of element strings to the content of an
    # entry. If the given elements collection is empty or nil,
    # then the database is unchanged, and a new entry is not
    # created if one did not exist previously.
    #
    # This is a fast operation since it only appends text to an
    # existing file.
    #
    # @param key [String] The key identifying the entry.
    # @param elements [Array<String>] An array or other
    #   enumerable collection of elements to append.
    def concat_any_elements(key, elements)
      key_d = CartonDb::Datum.for_plain(key)
      segment = segment_containing(key_d)
      segment.write_key_d_elements key_d, elements
    end

    # Appends an element to the content of an entry if no
    # element with the same value already exists in the content.
    #
    # @param key [String] The key identifying the entry.
    # @param element [String] The element to be appended to the
    #   content of the entry if applicable.
    def touch_element(key, element)
      key_d = CartonDb::Datum.for_plain(key)
      element_d = CartonDb::Datum.for_plain(element)
      return if element?(key_d, element_d)
      append_element key_d, element_d
    end

    # Performs a bag-wise merge of the given elements with the
    # content of an entry. Appends whatever elements are
    # necessary so the content has an element corresponding to
    # each of the given elements.
    #
    # Performance is similar to #[] when no new elements need to
    # be added and similar to #[] followed by #concat_elements
    # when one or more new elements needs to be added.
    #
    # @param key [String] The key identifying the entry.
    # @param elements [Array<String>] An array or other
    #   enumerable collection of elements to be appended as
    #   applicable.
    def merge_elements(key, elements)
      key_d = CartonDb::Datum.for_plain(key)
      element_ds = elements.map { |el|
        CartonDb::Datum.for_plain(el)
      }
      segment = segment_containing(key_d)
      segment.each_element_for_d key_d do |ed|
        eds_idx = element_ds.index(ed)
        element_ds.delete_at(eds_idx) if eds_idx
      end

      concat_elements key_d, element_ds
    end

    private

    attr_accessor :name

    def replace_entry_in_file(segment, key_d, content)
      segment.replace do |repl_io|
        segment.copy_entries_except key_d, repl_io
        element_count = 0
        count = write_key_elements(key_d, content, repl_io)
        repl_io << "#{key_d.escaped}\n" if count.zero?
      end
    end

    def segment_containing(key)
      ListMapDb::Segment.in_db_for_hashcode(
        name, key.storage_hashcode
      )
    end

    def empty_collection?(collection)
      return true if collection.nil?
      occupied = collection.any? { true }
      ! occupied
    end

    def write_key_elements(key_d, elements, to_io)
      count = 0
      elements.each do |element|
        element_d = CartonDb::Datum.for_plain(element)
        count += 1
        to_io << "#{key_d.escaped}\t#{element_d.escaped}\n"
      end
      count
    end

  end

end
