require "base64"

module OPP
  module Base64URL
    ALPHABET = /\A[A-Za-z0-9_-]*\z/

    module_function

    def encode(bytes)
      Base64.urlsafe_encode64(bytes, padding: false)
    end

    def decode(value, length: nil)
      unless value.is_a?(String) && ALPHABET.match?(value)
        raise InvalidEncodingError, "invalid unpadded Base64url"
      end

      bytes = Base64.urlsafe_decode64(value.ljust((value.length + 3) / 4 * 4, "="))
      raise InvalidEncodingError, "non-canonical Base64url" unless encode(bytes) == value
      raise InvalidEncodingError, "expected #{length} bytes" if length && bytes.bytesize != length

      bytes
    rescue ArgumentError => error
      raise InvalidEncodingError, error.message
    end
  end
end
