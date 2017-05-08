# -*- coding: UTF-8 -*-
# frozen_string_literal: true

require 'fileutils'

module CartonDb
  class ListMapDb

    class SegmentGroup

      def self.in_db_for_hashcode(db_name, hashcode)
        group_hash_part = hashcode[-1]
        group_num = group_hash_part.bytes[0] & 127
        new(db_name, group_num.to_s)
      end

      def self.each_in_db(db_name)
        Dir.entries(db_name).each do |de|
          next unless de =~ /^\d{1,3}$/
          seg_group = new(db_name, de)
          next unless File.directory?(seg_group.directory_path)
          yield seg_group
        end
      end

      attr_accessor :db_name,  :name_part
      private       :db_name=, :name_part=

      def initialize(db_name, name_part)
        self.db_name   = db_name
        self.name_part = name_part
      end

      def directory_path
        @directory_path ||= File.join(db_name, name_part)
      end
    end

  end
end
