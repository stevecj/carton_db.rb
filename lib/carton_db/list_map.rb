# -*- coding: UTF-8 -*-
require 'forwardable'
require 'fileutils'
require 'digest'

module CartonDb

  class ListMap
    extend Forwardable

    FILE_ENCODING_OPTS = {
      internal_encoding: Encoding::UTF_8,
      external_encoding: Encoding::UTF_8
    }.freeze

    def initialize(name)
      self.name = name
      FileUtils.mkpath name
    end

    def empty?
      each_data_file do |file, stat|
        return false unless stat.zero?
      end
      true
    end

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

    def []=(key, array_val)
      key = key.to_s
      file = file_path_for(key)
      stat = File.stat(file) if File.file?(file)
      if stat.nil? or stat.zero?
        concat_to key, array_val
      else
        esc_key = (key)
        new_file = "#{file}.new"
        open_overwrite new_file do |nf_io|
          each_file_esc_pair file do |l_esc_key, l_esc_element, line|
            nf_io.print line unless l_esc_key == esc_key
          end
          element_count = 0
          array_val.each do |element|
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

    def delete(key)
      key = key.to_s
      file = file_path_for(key)
      stat = File.stat(file) if File.file?(file)
      if stat.nil? or stat.zero?
        concat_to key, array_val
      else
        esc_key = escape(key)
        new_file = "#{file}.new"
        open_overwrite new_file do |nf_io|
          each_file_esc_pair file do |l_esc_key, l_esc_element|
            nf_io.print line unless l_esc_key == esc_key
          end
        end
        File.unlink file
        File.rename new_file, file
      end
    end

    def append_to(key, element)
      key = key.to_s
      file = file_path_for(key)
      FileUtils.mkpath File.dirname(file)
      open_append file do |io|
        io.puts "#{escape(key)}\t#{escape(element)}"
      end
    end

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
