module CartonDb

  module Escaping

    ESCAPING_MAP = {
      "\u0000".freeze => '\x00'.freeze,
      "\u0001".freeze => '\x01'.freeze,
      "\u0002".freeze => '\x02'.freeze,
      "\u0003".freeze => '\x03'.freeze,
      "\u0004".freeze => '\x04'.freeze,
      "\u0005".freeze => '\x05'.freeze,
      "\u0006".freeze => '\x06'.freeze,
      "\u0007".freeze => '\a'.freeze,
      "\u0008".freeze => '\b'.freeze,
      "\u0009".freeze => '\t'.freeze,
      "\u000A".freeze => '\n'.freeze,
      "\u000B".freeze => '\v'.freeze,
      "\u000C".freeze => '\f'.freeze,
      "\u000D".freeze => '\r'.freeze,
      "\u000E".freeze => '\x0E'.freeze,
      "\u000F".freeze => '\x0F'.freeze,
      "\u0010".freeze => '\x10'.freeze,
      "\u0011".freeze => '\x11'.freeze,
      "\u0012".freeze => '\x12'.freeze,
      "\u0013".freeze => '\x13'.freeze,
      "\u0014".freeze => '\x14'.freeze,
      "\u0015".freeze => '\x15'.freeze,
      "\u0016".freeze => '\x16'.freeze,
      "\u0017".freeze => '\x17'.freeze,
      "\u0018".freeze => '\x18'.freeze,
      "\u0019".freeze => '\x19'.freeze,
      "\u001A".freeze => '\x1A'.freeze,
      "\u001B".freeze => '\x1B'.freeze,
      "\u001C".freeze => '\x1C'.freeze,
      "\u001D".freeze => '\x1D'.freeze,
      "\u001E".freeze => '\x1E'.freeze,
      "\u001F".freeze => '\x1F'.freeze,
      "\u007F".freeze => '\x7F'.freeze,
      "\\".freeze     => "\\\\".freeze,
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
