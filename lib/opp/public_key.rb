require "ed25519"

module OPP
  module PublicKey
    module_function

    def decode(value)
      bytes = Base64URL.decode(value, length: 32)
      Ed25519::VerifyKey.new(bytes)
      bytes
    rescue InvalidEncodingError => error
      raise InvalidPublicKeyError, error.message
    end
  end
end
