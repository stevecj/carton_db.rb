# -*- coding: UTF-8 -*-
require 'forwardable'
require 'fileutils'
require 'digest'
require 'carton_db/list_map_db/segment'

module CartonDb

  # A map with string keys lists of strings as contents.
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
      segment = segment_containing(key_d.plain)
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
      segment = segment_containing(key_d.plain)
      return nil if segment.empty?

      ary = nil
      segment.each_entry_element_line do |kd, ed, _line|
        next ary unless kd == key_d
        ary ||= []
        ary << ed.plain unless ed.placeholder?
      end
      ary
    end

    def key?(key)
      key_d = CartonDb::Datum.for_plain(key)
      segment = segment_containing(key_d.plain)
      return false if segment.empty?

      segment.each_entry_element_line do |kd, _ed, _line|
        return true if kd = key_d
      end
      false
    end

    # Returns true if the map has no entries.
    #
    # This is a fairly fast operation.
    #
    # @return [Boolean]
    def empty?
      each_segment do |segment|
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
      file_key_datum_set = Set.new
      each_segment do |segment|
        next if segment.empty?
        file_key_datum_set.clear
        segment.each_entry_element_line do |kd, _ed, _line|
          file_key_datum_set << kd
        end
        key_count += file_key_datum_set.length
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
      segment = segment_containing(key_d.plain)

      if optimization == :small && segment.content?
        segment.each_entry_element_line do |kd, _ed, _line|
          return if kd == key_d
        end
      end

      segment.open_append do |io|
        io << key_d.escaped << "\n"
      end
    end

    # Removes all entries from the database, leaving it empty.
    #
    # This operation can be somewhat slow for a large database.
    #
    def clear
      subdirs = to_enum(:each_subdir).to_a
      FileUtils.rm_rf subdirs
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
      each_segment do |segment|
        next if segment.empty?
        key_arrays_slice.clear
        segment.each_entry_element_line do |kd, ed, _line|
          array = key_arrays_slice[kd] ||= []
          array << ed.plain unless ed.placeholder?
        end
        key_arrays_slice.each do |kd, array|
          yield kd.plain, array
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
      segment = segment_containing(key_d.plain)
      return if segment.empty?

      new_segment = ListMapDb::Segment.new(
        name, segment.chunk_dirname, "#{segment.segment_filename}.new")
      new_segment.open_overwrite do |io|
        segment.each_entry_element_line do |kd, _ed, line|
          io << line unless kd == key_d
        end
      end

      File.unlink segment.filename
      File.rename new_segment.filename, segment.filename
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
      segment = segment_containing(key_d.plain)
      FileUtils.mkpath File.dirname(segment.filename)
      segment.open_append do |io|
        io << "#{key_d.escaped}\t#{element_d.escaped}\n"
      end
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
      segment = segment_containing(key_d.plain)
      segment.open_append do |io|
        elements.each do |element|
          element_d = CartonDb::Datum.for_plain(element)
          io<< "#{key_d.escaped}\t#{element_d.escaped}\n"
        end
      end
    end

    private

    attr_accessor :name

    def replace_entry_in_file(segment, key_d, content)
      new_segment = ListMapDb::Segment.new(
        name, segment.chunk_dirname, "#{segment.segment_filename}.new")
      new_segment.open_overwrite do |nf_io|
        segment.each_entry_element_line do |kd, _ed, line|
          nf_io.print line unless kd == key_d
        end
        element_count = 0
        content.each do |element|
          element_d = CartonDb::Datum.for_plain(element)
          element_count += 1
          nf_io.puts "#{key_d.escaped}\t#{element_d.escaped}"
        end
        if element_count.zero?
          nf_io.puts key_d.escaped
        end
      end
      File.unlink segment.filename
      File.rename new_segment.filename, segment.filename
    end

    def segment_containing(key)
      hex_hashcode = Digest::MD5.hexdigest(key)[0..3]
      chunk_dirname = "#{hex_hashcode[0..1].to_i(16) % 128}"
      segment_filename = "#{hex_hashcode[2..3].to_i(16) % 128}.txt"
      ListMapDb::Segment.new(name, chunk_dirname, segment_filename)
    end

    def each_segment
      each_subdir do |subdir|
        each_segment_in subdir do |segment|
          yield segment
        end
      end
    end

    def each_subdir
      Dir.entries(name).each do |e|
        next unless e =~ /^\d{1,3}$/
        subdir = File.join(name, e)
        next unless File.directory?(subdir)
        yield subdir
      end
    end

    def each_segment_in(dir)
      Dir.entries(dir).each do |e|
        next unless e =~ /^\d{1,3}[.]txt$/
        filename = File.join(dir, e)
        yield ListMapDb::Segment.new(
        name, File.basename(File.dirname(filename)), File.basename(filename))
      end
    end

    def empty_collection?(collection)
      return true if collection.nil?
      occupied = collection.any? { true }
      ! occupied
    end

  end

end
