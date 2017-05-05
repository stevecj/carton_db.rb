# -*- coding: UTF-8 -*-
require 'fileutils'

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

      def each_entry
        entries = nil
        each_entry_element_line do |key_d, elem_d, _line|
          entries ||= {}
          content = entries[key_d] ||= []
          content << elem_d.plain unless elem_d.placeholder?
        end
        return unless entries
        entries.each do |key_d, content|
          yield key_d.plain, content
        end
      end

      def each_entry_element_line
        return if empty?
        each_line do |line|
          esc_key, esc_element = line.strip.split("\t", 2)
          key_d = CartonDb::Datum.for_escaped(esc_key)
          element_d = CartonDb::Datum.for_escaped(
            esc_element, auto_placeholder: true)
          yield key_d, element_d, line
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

      def open_read
        File.open filename, 'r', **FILE_ENCODING_OPTS do |io|
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

    end

  end
end
