# -*- coding: UTF-8 -*-
# frozen_string_literal: true

module CartonDb

  module Escaping

    ESCAPING_MAP = {
      "\u0000" => '\x00',
      "\u0001" => '\x01',
      "\u0002" => '\x02',
      "\u0003" => '\x03',
      "\u0004" => '\x04',
      "\u0005" => '\x05',
      "\u0006" => '\x06',
      "\u0007" => '\a',
      "\u0008" => '\b',
      "\u0009" => '\t',
      "\u000A" => '\n',
      "\u000B" => '\v',
      "\u000C" => '\f',
      "\u000D" => '\r',
      "\u000E" => '\x0E',
      "\u000F" => '\x0F',
      "\u0010" => '\x10',
      "\u0011" => '\x11',
      "\u0012" => '\x12',
      "\u0013" => '\x13',
      "\u0014" => '\x14',
      "\u0015" => '\x15',
      "\u0016" => '\x16',
      "\u0017" => '\x17',
      "\u0018" => '\x18',
      "\u0019" => '\x19',
      "\u001A" => '\x1A',
      "\u001B" => '\x1B',
      "\u001C" => '\x1C',
      "\u001D" => '\x1D',
      "\u001E" => '\x1E',
      "\u001F" => '\x1F',
      "\u007F" => '\x7F',
      "\\"     => "\\\\",
    }.freeze

    UNESCAPING_MAP = ESCAPING_MAP.invert.freeze

    def self.escape(value)
      value.gsub(
        /[\x00-\x1F\x7F\\]/,
        ESCAPING_MAP
      )
    end

    def self.unescape(esc)
      esc.gsub(
        /\\(?:\\|x[01][0-9A-F]|x7F|[abtnvfr])/,
        UNESCAPING_MAP
      )
    end

  end

end
