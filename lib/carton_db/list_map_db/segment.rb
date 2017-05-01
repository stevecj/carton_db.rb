# -*- coding: UTF-8 -*-
require 'fileutils'

module CartonDb
  class ListMapDb

    class Segment

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

      def each_line
        open_read do |io|
          io.each_line do |line|
            yield line
          end
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

    end

  end
end
