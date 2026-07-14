require "ed25519"

module OPP
  class KeyPair
    attr_reader :private_key, :public_key

    def self.generate
      new(Ed25519::SigningKey.generate)
    end

    def self.from_private_key(value)
      new(Ed25519::SigningKey.new(Base64URL.decode(value, length: 32)))
    end

    def initialize(signing_key)
      @signing_key = signing_key
      @private_key = Base64URL.encode(signing_key.to_bytes)
      @public_key = Base64URL.encode(signing_key.verify_key.to_bytes)
    end

    def sign(bytes)
      @signing_key.sign(bytes)
    end

    private_class_method :new
  end
end
