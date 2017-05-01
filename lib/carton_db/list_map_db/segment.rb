# -*- coding: UTF-8 -*-
require 'fileutils'

module CartonDb
  class ListMapDb

    class Segment

      attr_accessor :db_name,  :chunk_dirname,  :segment_filename
      private       :db_name=, :chunk_dirname=, :segment_filename=

      def initialize(db_name, chunk_dirname, segment_filename)
        self.db_name = db_name
        self.chunk_dirname = chunk_dirname
        self.segment_filename = segment_filename
      end

      def filename
        File.join(db_name, chunk_dirname, segment_filename)
      end

      def content?
        stat && ! stat.zero?
      end

      def empty?
        ! content?
      end

      def each_entry_element_line
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
