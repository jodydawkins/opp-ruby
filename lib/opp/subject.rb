require "digest"

module OPP
  module Subject
    PREFIX = "key:sha256:"

    module_function

    def derive(public_key)
      PREFIX + Base64URL.encode(Digest::SHA256.digest(PublicKey.decode(public_key)))
    end

    def verify!(subject, public_key:)
      return true if subject.is_a?(String) && secure_equal(subject, derive(public_key))

      raise SubjectMismatchError, "subject does not match public key"
    end

    def secure_equal(left, right)
      left.bytesize == right.bytesize && left.bytes.zip(right.bytes).reduce(0) do |difference, (a, b)|
        difference | (a ^ b)
      end.zero?
    end
    private_class_method :secure_equal
  end
end
