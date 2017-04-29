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
    # concatenating may be faster.
    #
    # @param key [String] The key identifying the entry.
    # @param content [Array<String>] An array or other
    #   enumerable collection of 0 or more list element string
    #   values to be stored.
    def []=(key, content)
      key = key.to_s
      file = file_path_for(key)
      stat = File.stat(file) if File.file?(file)
      if stat.nil? or stat.zero?
        concat_to key, content
      else
        esc_key = (key)
        new_file = "#{file}.new"
        open_overwrite new_file do |nf_io|
          each_file_esc_pair file do |l_esc_key, l_esc_element, line|
            nf_io.print line unless l_esc_key == esc_key
          end
          element_count = 0
          content.each do |element|
            element_count += 1
            nf_io.puts "#{escape(key)}\t#{escape(element)}"
          end
          if element_count.zero?
            nf_io.puts escape(key)
          end
        end
        File.unlink file
        File.rename new_file, file
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
      key = key.to_s
      file = file_path_for(key)
      return nil unless File.file?(file)
      esc_key = escape(key)
      ary = nil
      each_file_esc_pair file do |l_esc_key, l_esc_element, line|
        line.strip!
        next ary unless l_esc_key == esc_key
        ary ||= []
        next unless l_esc_element
        ary << unescape(l_esc_element)
      end
      ary
    end

    # Returns true if the map has no entries.
    #
    # This is a fairly fast operation.
    #
    # @return [Boolean]
    def empty?
      each_data_file do |file, stat|
        return false unless stat.zero?
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
      file_esc_key_set = Set.new
      each_data_file do |file, stat|
        next if stat.zero?
        file_esc_key_set.clear
        each_file_esc_pair file do |esc_key, _|
          file_esc_key_set << esc_key
        end
        key_count += file_esc_key_set.length
      end
      key_count
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
      esc_key_arrays_slice = {}
      each_data_file do |file, stat|
        next if stat.zero?
        esc_key_arrays_slice.clear
        each_file_esc_pair file do |esc_key, esc_element|
          array = esc_key_arrays_slice[esc_key] ||= []
          array << unescape(esc_element) if esc_element
        end
        esc_key_arrays_slice.each do |esc_key, array|
          key = unescape(esc_key)
          yield key, array
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
      key = key.to_s
      file = file_path_for(key)
      stat = File.stat(file) if File.file?(file)
      return if stat.nil? or stat.zero?

      esc_key = escape(key)
      new_file = "#{file}.new"
      open_overwrite new_file do |io|
        each_file_esc_pair file do |l_esc_key, l_esc_element|
          io << line unless l_esc_key == esc_key
        end
      end

      File.unlink file
      File.rename new_file, file
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
    def append_to(key, element)
      key = key.to_s
      file = file_path_for(key)
      FileUtils.mkpath File.dirname(file)
      open_append file do |io|
        io.puts "#{escape(key)}\t#{escape(element)}"
      end
    end

    # Appends any number of element strings to the content of an
    # entry. If the entry does not already exist, then one is
    # created with the given list as its content.
    #
    # Appending an empty array does cause the database to grow
    # slightly even though it might not change the effective
    # content of the data because it appends a key-existence
    # entry to the file without checking to see if it already
    # contains other entries for the key.
    #
    # Since this will only append text to a file within the
    # database, it is a very fast operation.
    #
    # @param key [String] The key identifying the entry.
    # @param elements [Array<String>] An array or other
    #   enumerable collection of elements to append.
    def concat_to(key, elements)
      key = key.to_s
      file = file_path_for(key)
      FileUtils.mkpath File.dirname(file)
      open_append file do |io|
        element_count = 0
        elements.each do |element|
          element_count += 1
          io.puts "#{escape(key)}\t#{escape(element)}"
        end
        if element_count.zero?
          io.puts escape(key)
        end
      end
    end

    private

    attr_accessor :name

    def_delegators CartonDb::Escaping,
      :escape,
      :unescape

    def file_path_for(key)
      hex_hashcode = Digest::MD5.hexdigest(key)[0..3]
      subdir = "#{hex_hashcode[0..1].to_i(16) % 128}"
      filename = "#{hex_hashcode[2..3].to_i(16) % 128}.txt"
      File.join(name, subdir, filename)
    end

    def each_file_esc_pair(file)
      each_file_line file do |line|
        esc_key, esc_element = line.strip.split("\t", 2)
        yield esc_key, esc_element, line
      end
    end

    def each_file_line(file)
      open_read file do |io|
        io.each_line do |line|
          yield line
        end
      end
    end

    def open_read(file)
      File.open file, 'r', **FILE_ENCODING_OPTS do |io|
        yield io
      end
    end

    def open_append(file)
      File.open file, 'a', **FILE_ENCODING_OPTS do |io|
        yield io
      end
    end

    def open_overwrite(file)
      File.open file, 'w', **FILE_ENCODING_OPTS do |io|
        yield io
      end
    end

    def each_data_file
      each_subdir do |subdir|
        each_data_file_in subdir do |file, stat|
          yield file, stat
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
        file = File.join(dir, e)
        stat = File.stat(file)
        next unless stat.file?
        yield file, stat
      end
    end
  end

end
