# -*- coding: UTF-8 -*-
# frozen_string_literal: true

module CartonDb

  module Escaping

    # Most importantly, escape values that would interfere with
    # the use of newline and tab delimiters. Also escape the
    # characters most likely to cause problems when dumping
    # contents to a terminal console or viewing/editing content
    # in a text editor.
    # Use fairly short, commonly understood, ANSI-C backslash
    # quoting sequences. Not using the slightly shorter
    # "\c<x>" control character sequences since those are much
    # less wll known.

    ESCAPING_MAP = {
      "\u0000" => '\x00',  # null
      "\u0001" => '\x01',  # Ctrl+A
      "\u0002" => '\x02',  # Ctrl+B
      "\u0003" => '\x03',  # Ctrl+C
      "\u0004" => '\x04',  # Ctrl+D
      "\u0005" => '\x05',  # Ctrl+E
      "\u0006" => '\x06',  # Ctrl+F
      "\u0007" => '\a',    # alert/bell
      "\u0008" => '\b',    # backspace
      "\u0009" => '\t',    # tab
      "\u000A" => '\n',    # newline
      "\u000B" => '\v',    # vertical tab
      "\u000C" => '\f',    # form feed
      "\u000D" => '\r',    # carriage return
      "\u000E" => '\x0E',  # Ctrl+N
      "\u000F" => '\x0F',  # Ctrl+O
      "\u0010" => '\x10',  # Ctrl+P
      "\u0011" => '\x11',  # Ctrl+Q
      "\u0012" => '\x12',  # Ctrl+R
      "\u0013" => '\x13',  # Ctrl+S
      "\u0014" => '\x14',  # Ctrl+T
      "\u0015" => '\x15',  # Ctrl+U
      "\u0016" => '\x16',  # Ctrl+V
      "\u0017" => '\x17',  # Ctrl+W
      "\u0018" => '\x18',  # Ctrl+X
      "\u0019" => '\x19',  # Ctrl+Y
      "\u001A" => '\x1A',  # Ctrl+Z
      "\u001B" => '\x1B',  # escape
      "\u001C" => '\x1C',  # file separator
      "\u001D" => '\x1D',  # group separator
      "\u001E" => '\x1E',  # record separator
      "\u001F" => '\x1F',  # unit separator
      "\u007F" => '\x7F',  # delete
      "\\"     => "\\\\",  # backslash
    }.freeze

    UNESCAPING_MAP = ESCAPING_MAP.invert.freeze

    class << self
      # Replace special characters with backslashed escape
      # sequences.
      def escape(value)
        value.gsub(
          /[\x00-\x1F\x7F\\]/,
          ESCAPING_MAP
        )
      end

      # Replace backslashed escape sequences with special
      # characters.
      def unescape(esc)
        esc.gsub( /\\(?:\\|x[01][0-9A-F]|x7F|[^x\\]|$)/ ) { |match|
          UNESCAPING_MAP.fetch match do
            incomplete_sequence! match if match == "\\"
            invalid_sequence! match
          end
        }
      end

      private

      def incomplete_sequence!(sequence)
        message =
          "Escaped text contains incomplete escape sequence %s" % sequence
        raise CartonDb::IncompleteEscapeSequence, message
      end

      def invalid_sequence!(sequence)
        message =
          "Escaped text contains invalid escape sequence %s" % sequence
        raise CartonDb::InvalidEscapeSequence, message
      end
    end

  end

end
