module OPP
  class Error < StandardError
    attr_reader :code, :path

    def initialize(message = nil, code: nil, path: nil)
      super(message)
      @code = code || self.class.name.split("::").last
        .gsub(/([a-z\d])([A-Z])/, "\\1_\\2").downcase.delete_suffix("_error")
      @path = path
    end
  end

  ParseError = Class.new(Error)
  DuplicateMemberError = Class.new(Error)
  ValidationError = Class.new(Error)
  CanonicalizationError = Class.new(Error)
  InvalidEncodingError = Class.new(Error)
  InvalidPublicKeyError = Class.new(Error)
  SubjectMismatchError = Class.new(Error)
  InvalidSignatureError = Class.new(Error)
  ExpiredDocumentError = Class.new(Error)
  UnsupportedVersionError = Class.new(Error)
end
