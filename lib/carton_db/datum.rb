# -*- coding: UTF-8 -*-
# frozen_string_literal: true

require 'digest'

module CartonDb

  module Datum

    def self.for_plain(plain_text, auto_placeholder: false)
      if auto_placeholder && (! plain_text) && plain_text.nil?
        Datum::Placeholder
      elsif plain_text.is_a?(Datum::Base)
        plain_text
      else
        Datum::ForPlain.new(plain_text.to_s)
      end
    end

    def self.for_escaped(escaped_text, auto_placeholder: false)
      if auto_placeholder && (! escaped_text) && escaped_text.nil?
        Datum::Placeholder
      elsif escaped_text.is_a?(Datum::Base)
        escaped_text
      else
        Datum::ForEscaped.new(escaped_text.to_s)
      end
    end

    def self.placeholder
      Datum::Placeholder
    end

    class Base
      def plain
        raise NotImplementedError, "Subclass responsibility."
      end

      def escaped
        raise NotImplementedError, "Subclass responsibility."
      end

      def placeholder?
        raise NotImplementedError, "Subclass responsibility."
      end

      def storage_hashcode
        return nil if placeholder?
        @storage_hashcode ||= Digest::MD5.digest(plain)
      end

      def eql?(other)
        raise NotImplementedError, "Subclass responsibility."
      end

      alias == eql?

      def hash
        raise NotImplementedError, "Subclass responsibility."
      end
    end

    class ForPlain < Datum::Base
      attr_reader :plain


      def initialize(plain)
        if (! plain) && plain.nil?
          raise ArgumentError "A non-nil 'plain' value is required."
        end
        @plain = plain
      end

      def escaped
        @escaped ||= CartonDb::Escaping.escape(@plain)
      end

      def placeholder?
        false
      end

      def eql?(other)
        return false unless other.is_a?(Datum::Base)
        return true if other.class == self.class && @plain == other.plain
        return escaped == other.escaped
      end

      alias == eql?

      def hash
        escaped.hash
      end
    end

    class ForEscaped < Datum::Base
      attr_reader :escaped

      def initialize(escaped)
        if (! escaped) && escaped.nil?
          raise ArgumentError "A non-nil 'escaped' value is required."
        end
        @escaped = escaped
      end

      def plain
        @plain ||= CartonDb::Escaping.unescape(@escaped)
      end

      def placeholder?
        false
      end

      def eql?(other)
        return false unless other.is_a?(Datum::Base)
        return true if other.class == self.class && @escaped == other.escaped
        return escaped == other.escaped
      end

      alias == eql?

      def hash
        escaped.hash
      end
    end

    class PlaceholderClass < Datum::Base
      def plain
        nil
      end

      def escaped
        nil
      end

      def placeholder?
        true
      end

      def eql?(other)
        return false unless other.is_a?(Datum::Base)
        return other.placeholder?
      end

      alias == eql?

      def hash
        PlaceholderClass.hash
      end
    end

    Placeholder = PlaceholderClass.new

  end

end
