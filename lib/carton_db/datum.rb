module CartonDb
  class Datum
    def initialize(plain: nil, escaped: nil)
      @plain = plain&.to_s
      @escaped = escaped&.to_s
      @placeholder = plain.nil? && escaped.nil?
    end

    def plain
      return nil if @placeholder
      @plain ||= CartonDb::Escaping.unescape(@escaped)
    end

    def escaped
      return nil if @placeholder
      @escaped ||= CartonDb::Escaping.escape(@plain)
    end

    def placeholder?
      @placeholder
    end

    def eql?(other)
      if self.class != other.class
        false
      elsif @escaped && other._escaped
        @escaped == other._escaped
      elsif @plain && other._plain
        @plain == other._plain
      elsif @placeholder
        @placeholder == other.placeholder?
      else
        escaped == other.escaped
      end
    end

    alias == eql?

    def hash
      # It is more common to already know the escaped value
      # than to already know the plain value, so this should
      # be faster on average.
      escaped.hash
    end

    protected

    def _plain
      @plain
    end

    def _escaped
      @escaped
    end
  end
end
