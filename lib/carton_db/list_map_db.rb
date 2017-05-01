# -*- coding: UTF-8 -*-
require 'forwardable'
require 'fileutils'
require 'digest'

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
      key_d = ListMapDb::Datum.new(plain: key)
      data_file = data_file_containing(key_d.plain)
      if data_file.empty?
        concat_elements key_d.plain, content
      else
        replace_entry_in_file data_file, key_d, content
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
      key_d = ListMapDb::Datum.new(plain: key)
      data_file = data_file_containing(key_d.plain)
      return nil if data_file.empty?

      ary = nil
      each_datum_pair_in_file data_file do |kd, ed|
        next ary unless kd == key_d
        ary ||= []
        ary << ed.plain unless ed.placeholder?
      end
      ary
    end

    def key?(key)
      key_d = ListMapDb::Datum.new(plain: key)
      data_file = data_file_containing(key_d.plain)
      return false if data_file.empty?

      each_datum_pair_in_file data_file do |kd, _|
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
      each_data_file do |data_file|
        return false unless data_file.empty?
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
      each_data_file do |data_file|
        next if data_file.empty?
        file_key_datum_set.clear
        each_datum_pair_in_file data_file do |kd, _|
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

      key_d = ListMapDb::Datum.new(plain: key)
      data_file = data_file_containing(key_d.plain)

      if optimization == :small && data_file.content?
        each_datum_pair_in_file data_file do |kd, _|
          return if kd == key_d
        end
      end

      data_file.open_append do |io|
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
      each_data_file do |data_file|
        next if data_file.empty?
        key_arrays_slice.clear
        each_datum_pair_in_file data_file do |kd, ed|
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
      key_d = ListMapDb::Datum.new(plain: key)
      data_file = data_file_containing(key_d.plain)
      return if data_file.empty?

      new_data_file = ListMapDb::DataFile.new("#{data_file.filename}.new")
      new_data_file.open_overwrite do |io|
        each_datum_pair_in_file data_file do |kd, _, line|
          io << line unless kd == key_d
        end
      end

      File.unlink data_file.filename
      File.rename new_data_file.filename, data_file.filename
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
      key_d = ListMapDb::Datum.new(plain: key)
      element_d = ListMapDb::Datum.new(plain: element)
      data_file = data_file_containing(key_d.plain)
      FileUtils.mkpath File.dirname(data_file.filename)
      data_file.open_append do |io|
        io << "#{key_d.escaped}\t#{element_d.escaped}\n"
      end
    end

    # Appends any number of element strings to the content of an
    # entry. If the entry does not already exist, then one is
    # created with the given list as its content.
    #
    # Appending an empty collection is equivalent to invoking
    # `db.touch key, optimization: :small`.
    #
    # When appending a non-empty collection, this is a fast
    # operation since it only append text to an existing file.
    #
    # @param key [String] The key identifying the entry.
    # @param elements [Array<String>] An array or other
    #   enumerable collection of elements to append.
    def concat_elements(key, elements)
      if empty_collection?(elements)
        touch key, optimization: :small
        return
      end

      key_d = ListMapDb::Datum.new(plain: key)
      data_file = data_file_containing(key_d.plain)
      data_file.open_append do |io|
        element_count = 0
        elements.each do |element|
          element_d = ListMapDb::Datum.new(plain: element)
          element_count += 1
          io<< "#{key_d.escaped}\t#{element_d.escaped}\n"
        end
        if element_count.zero?
          io.puts key_d.escaped
        end
      end
    end

    class Datum
      def initialize(plain: nil, escaped: nil)
        @plain = plain&.to_s
        @escaped = escaped&.to_s
        @placeholder = plain.nil? && escaped.nil?
      end

      def plain
        @plain ||= CartonDb::Escaping.unescape(@escaped)
      end

      def escaped
        @escaped ||= CartonDb::Escaping.escape(@plain)
      end

      def placeholder?
        @placeholder
      end

      def eql?(other)
        if self.class != other.class
          false
        elsif @escaped && other._escaped
          @escaped == other._escaped
        elsif @plain && other._plain
          @plain == other._plain
        elsif @placeholder
          @placeholder == other.placeholder?
        else
          escaped == other.escaped
        end
      end

      alias == eql?

      def hash
        # It is more common to already know the escaped value
        # than to already know the plain value, so this should
        # be faster on average.
        escaped.hash
      end

      protected

      def _plain
        @plain
      end

      def _escaped
        @escaped
      end
    end

    class DataFile
      attr_accessor :filename
      private       :filename=

      def initialize(filename)
        self.filename = filename
      end

      def content?
        stat && ! stat.zero?
      end

      def empty?
        ! content?
      end

      def open_read
        File.open filename, 'r', **FILE_ENCODING_OPTS do |io|
          yield io
        end
      end

      def open_append
        touch_dir
        File.open filename, 'a', **FILE_ENCODING_OPTS do |io|
          yield io
        end
      end

      def open_overwrite
        touch_dir
        File.open filename, 'w', **FILE_ENCODING_OPTS do |io|
          yield io
        end
      end

      private

      def stat
        return @stat if defined? @stat
        return @stat = nil unless File.file?(filename)
        return @stat = File.stat(filename)
      end

      def touch_dir
        dir = File.dirname(filename)
        return if File.directory?(dir)
        FileUtils.mkdir dir
      end

    end

    private

    attr_accessor :name

    def_delegators CartonDb::Escaping,
      :escape,
      :unescape

    def replace_entry_in_file(data_file, key_d, content)
      new_data_file = ListMapDb::DataFile.new("#{data_file.filename}.new")
      new_data_file.open_overwrite do |nf_io|
        each_datum_pair_in_file data_file do |kd, _, line|
          nf_io.print line unless kd == key_d
        end
        element_count = 0
        content.each do |element|
          element_d = Datum.new(plain: element)
          element_count += 1
          nf_io.puts "#{key_d.escaped}\t#{element_d.escaped}"
        end
        if element_count.zero?
          nf_io.puts key_d.escaped
        end
      end
      File.unlink data_file.filename
      File.rename new_data_file.filename, data_file.filename
    end

    def data_file_containing(key)
      filename = file_path_for(key)
      ListMapDb::DataFile.new(filename)
    end

    def file_path_for(key)
      hex_hashcode = Digest::MD5.hexdigest(key)[0..3]
      subdir = "#{hex_hashcode[0..1].to_i(16) % 128}"
      filename = "#{hex_hashcode[2..3].to_i(16) % 128}.txt"
      File.join(name, subdir, filename)
    end

    def each_datum_pair_in_file(data_file)
      each_file_line data_file do |line|
        esc_key, esc_element = line.strip.split("\t", 2)
        key_d = ListMapDb::Datum.new(escaped: esc_key)
        element_d = ListMapDb::Datum.new(escaped: esc_element)
        yield key_d, element_d, line
      end
    end

    def each_file_line(data_file)
      data_file.open_read do |io|
        io.each_line do |line|
          yield line
        end
      end
    end

    def each_data_file
      each_subdir do |subdir|
        each_data_file_in subdir do |data_file|
          yield data_file
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

    def each_data_file_in(dir)
      Dir.entries(dir).each do |e|
        next unless e =~ /^\d{1,3}[.]txt$/
        filename = File.join(dir, e)
        yield ListMapDb::DataFile.new( filename )
      end
    end

    def empty_collection?(collection)
      ! collection.any? { true }
    end

  end

end
