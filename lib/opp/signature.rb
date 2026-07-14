require "ed25519"

module OPP
  module Signature
    module_function

    def sign(document, private_key:)
      unsigned = unsigned_document(document)
      bytes = KeyPair.from_private_key(private_key)
        .sign(Canonicalization.canonicalize(unsigned))

      unsigned.merge(
        "signature" => {
          "algorithm" => "ed25519",
          "value" => Base64URL.encode(bytes)
        }
      )
    rescue InvalidEncodingError => error
      raise InvalidSignatureError, error.message
    end

    def verify(document, public_key:)
      verify!(document, public_key:)
    rescue InvalidSignatureError
      false
    end

    def verify!(document, public_key:)
      unsigned, signature = split(document)
      unless signature["algorithm"] == "ed25519"
        raise InvalidSignatureError, "unsupported signature algorithm"
      end

      bytes = Base64URL.decode(signature["value"], length: 64)
      verify_key = Ed25519::VerifyKey.new(PublicKey.decode(public_key))
      verify_key.verify(bytes, Canonicalization.canonicalize(unsigned))
      true
    rescue Ed25519::VerifyError, InvalidEncodingError, InvalidPublicKeyError => error
      raise InvalidSignatureError, error.message
    end

    def split(document)
      unsigned = unsigned_document(document)
      signature = document["signature"]
      unless signature.is_a?(Hash) &&
          signature.size == 2 &&
          signature.key?("algorithm") && signature.key?("value") &&
          signature.values.all?(String)
        raise InvalidSignatureError, "invalid signature object"
      end

      [unsigned, copy(signature)]
    end
    private_class_method :split

    def unsigned_document(document)
      raise ValidationError, "document must be an object" unless document.is_a?(Hash)

      copy(document).tap { |value| value.delete("signature") }
    end
    private_class_method :unsigned_document

    def copy(value)
      case value
      when Hash
        value.to_h { |key, item| [key, copy(item)] }
      when Array
        value.map { |item| copy(item) }
      when String
        value.dup
      else
        value
      end
    end
    private_class_method :copy
  end
end
