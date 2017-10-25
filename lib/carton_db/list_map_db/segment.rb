# -*- coding: UTF-8 -*-
# frozen_string_literal: true

require 'fileutils'
require 'set'

module CartonDb
  class ListMapDb

    class Segment

      def self.in_db_for_hashcode(db_name, hashcode)
        seg_hash_part = hashcode[-1]
        seg_num = seg_hash_part.bytes[0] & 127

        group_hashcode = hashcode[0..-2]
        seg_group = ListMapDb::SegmentGroup.
          in_db_for_hashcode(db_name, group_hashcode)

        new(seg_group, "#{seg_num}.txt")
      end

      def self.each_in_db(db_name)
        ListMapDb::SegmentGroup.each_in_db db_name do |seg_group|
          Dir.entries(seg_group.directory_path).each do |de|
            next unless de =~ /^\d{1,3}[.]txt$/
            yield new(seg_group, de)
          end
        end
      end

      def self.clear_all_in_db(db_name)
        ListMapDb::SegmentGroup.each_in_db db_name do |seg_group|
          filenames = []
          Dir.entries(seg_group.directory_path).each do |de|
            next unless de =~ /^\d{1,3}[.]txt$/
            filename = File.join(seg_group.directory_path, de)
            filenames << filename
          end
          FileUtils.rm *filenames
        end
      end

      attr_accessor :segment_group,  :segment_filename
      private       :segment_group=, :segment_filename=

      def initialize(segment_group, segment_filename)
        self.segment_group = segment_group
        self.segment_filename = segment_filename
      end

      def filename
        File.join(segment_group.directory_path, segment_filename)
      end

      def content?
        stat && ! stat.zero?
      end

      def empty?
        ! content?
      end

      def key_count
        return 0 if empty?
        key_d_set.length
      end

      def touch_d(key_d, optimization)
        return if optimization == :small && key_d?(key_d)

        # Add a placeholder: An escaped key not followed by a tab
        # character.
        open_append do |io|
          io << key_d.escaped << "\n"
        end
      end

      def key_d_set
        result = Set.new
        each_entry_element_line do |kd, _ed, _line|
          result << kd
        end
        result
      end

      def key_d?(key_d)
        each_entry_element_line do |kd, _ed, _line|
          return true if kd = key_d
        end
        false
      end

      def element_d?(key_d, element_d)
        each_entry_element_line do |kd, ed, _line|
          return true if kd == key_d && ed == element_d
        end
        false
      end

      def collect_content(key_d, collection_class)
        result = nil
        each_element_for_d key_d do |ed|
          result ||= collection_class.new
          result << ed.plain unless ed.placeholder?
        end
        result
      end

      def each_entry
        entries = key_d_contents_map
        return unless entries
        entries.each do |key_d, content|
          yield key_d.plain, content
        end
      end

      def each_element_for_d(key_d)
        each_entry_element_line do |kd, ed, _line|
          next unless kd == key_d
          yield ed
        end
      end

      def each_first_element
        first_element_map = key_d_first_element_map
        return unless first_element_map

        first_element_map.each do |key_d, element|
          yield key_d.plain, element
        end
      end

      def each_entry_element_line
        return if empty?
        each_line do |line|
          # For a placeholder line, there is no tab character, so
          # esc_element is nil.
          esc_key, esc_element = line.strip.split("\t", 2)
          key_d = CartonDb::Datum.for_escaped(esc_key)
          element_d = CartonDb::Datum.for_escaped(
            esc_element, auto_placeholder: true)
          yield key_d, element_d, line
        end
      end

      def replace
        repl_name = "#{segment_filename}.temp"
        replacement = self.class.new(segment_group, repl_name)
        begin
          replacement.open_overwrite do |io|
            yield io
          end
        rescue StandardError
          File.unlink replacement.filename
          raise
        end
        File.unlink filename
        File.rename replacement.filename, filename
      end

      def write_key_element_d(key_d, element_d)
        open_append do |io|
          io << "#{key_d.escaped}\t#{element_d.escaped}\n"
        end
      end

      def write_key_d_elements(key_d, elements)
        open_append do |io|
          elements.each do |element|
            element_d = CartonDb::Datum.for_plain(element)
            io<< "#{key_d.escaped}\t#{element_d.escaped}\n"
          end
        end
      end

      def copy_entries_except(key_d, to_io)
        each_entry_element_line do |kd, _ed, line|
          to_io << line unless kd == key_d
        end
      end

      protected

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

      def touch_dir
        dir = File.dirname(filename)
        return if File.directory?(dir)
        FileUtils.mkdir dir
      end

      def each_line
        open_read do |io|
          io.each_line do |line|
            yield line
          end
        end
      end

      def key_d_contents_map
        entries = nil
        each_entry_element_line do |key_d, elem_d, _line|
          entries ||= {}
          content = entries[key_d] ||= []
          content << elem_d.plain unless elem_d.placeholder?
        end
        entries
      end

      def key_d_first_element_map
        result = nil
        each_entry_element_line do |key_d, elem_d, _line|
          result ||= {}
          result[key_d] ||= elem_d.plain
        end
        return result
      end

    end

  end
end
