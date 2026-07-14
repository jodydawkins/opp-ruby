require "time"
require "uri"

module OPP
  module Presence
    REQUIRED = %w[type version subject public_key issued_at services signature].freeze
    TYPES = {
      "type" => String,
      "version" => String,
      "subject" => String,
      "public_key" => String,
      "issued_at" => String,
      "services" => Array,
      "signature" => Hash,
      "expires_at" => String
    }.freeze
    TIMESTAMP_PATTERN = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\z/

    module_function

    def sign(document, private_key:)
      raise ValidationError, "document must be an object" unless document.is_a?(Hash)

      pair = KeyPair.from_private_key(private_key)
      unsigned = copy(document).tap { |value| value.delete("signature") }.merge(
        "public_key" => pair.public_key,
        "subject" => Subject.derive(pair.public_key)
      )
      errors = validate(unsigned, at: nil, signature_required: false)
      raise errors.first unless errors.empty?

      Signature.sign(unsigned, private_key:)
    end

    def verify(input, at: Time.now.utc)
      document = input.is_a?(String) ? OPP::JSON.parse(input) : copy(input)
      VerificationResult.new(validate(document, at:, signature_required: true))
    rescue OPP::Error => error
      VerificationResult.new([error])
    end

    def verify!(input, at: Time.now.utc)
      result = verify(input, at:)
      raise result.errors.first unless result.valid?

      true
    end

    def validate(document, at:, signature_required:)
      return [ValidationError.new("document must be an object")] unless document.is_a?(Hash)

      errors = required_errors(document, signature_required:)
      errors.concat(type_errors(document))
      errors << ValidationError.new("type must be open-presence", path: "type") if
        document["type"].is_a?(String) && document["type"] != "open-presence"
      errors << UnsupportedVersionError.new("unsupported version: #{document["version"]}", path: "version") if
        document["version"].is_a?(String) && document["version"] != "0.1"

      public_key_usable = validate_credentials(document, errors)
      validate_timestamps(document, at:, errors:)
      validate_services(document, errors)
      if signature_required && public_key_usable && document["signature"].is_a?(Hash)
        begin
          Signature.verify!(document, public_key: document["public_key"])
        rescue OPP::Error => error
          errors << error
        end
      end
      errors
    end
    private_class_method :validate

    def required_errors(document, signature_required:)
      required = signature_required ? REQUIRED : REQUIRED - ["signature"]
      required.filter_map do |field|
        ValidationError.new("missing required field: #{field}", path: field) unless document.key?(field)
      end
    end
    private_class_method :required_errors

    def type_errors(document)
      TYPES.filter_map do |field, type|
        next unless document.key?(field) && !document[field].is_a?(type)

        ValidationError.new("#{field} must be #{type.name.downcase}", path: field)
      end
    end
    private_class_method :type_errors

    def validate_credentials(document, errors)
      return false unless document["public_key"].is_a?(String)

      begin
        PublicKey.decode(document["public_key"])
      rescue InvalidPublicKeyError => error
        errors << InvalidPublicKeyError.new(error.message, path: "public_key")
        return false
      end

      if document["subject"].is_a?(String)
        begin
          Subject.verify!(document["subject"], public_key: document["public_key"])
        rescue SubjectMismatchError => error
          errors << SubjectMismatchError.new(error.message, path: "subject")
        end
      end
      true
    end
    private_class_method :validate_credentials

    def validate_timestamps(document, at:, errors:)
      issued_at = parse_timestamp(document, "issued_at", errors)
      expires_at = parse_timestamp(document, "expires_at", errors) if document.key?("expires_at")
      return unless expires_at

      if issued_at && expires_at <= issued_at
        errors << ValidationError.new("expires_at must be later than issued_at", path: "expires_at")
      elsif at && at >= expires_at
        errors << ExpiredDocumentError.new("document has expired", path: "expires_at")
      end
    end
    private_class_method :validate_timestamps

    def parse_timestamp(document, field, errors)
      value = document[field]
      return unless value.is_a?(String)

      unless TIMESTAMP_PATTERN.match?(value)
        errors << ValidationError.new("#{field} must be an RFC 3339 UTC timestamp", path: field)
        return
      end

      parsed = Time.iso8601(value)
      raise ArgumentError unless parsed.strftime("%Y-%m-%dT%H:%M:%S") == value[0, 19]

      parsed
    rescue ArgumentError
      errors << ValidationError.new("#{field} must be a valid timestamp", path: field)
      nil
    end
    private_class_method :parse_timestamp

    def validate_services(document, errors)
      return unless document["services"].is_a?(Array)

      document["services"].each_with_index do |service, index|
        base = "services[#{index}]"
        unless service.is_a?(Hash)
          errors << ValidationError.new("#{base} must be an object", path: base)
          next
        end

        %w[type url].each do |field|
          errors << ValidationError.new("missing required field: #{base}.#{field}", path: "#{base}.#{field}") unless
            service.key?(field)
        end
        %w[type url].each do |field|
          errors << ValidationError.new("#{base}.#{field} must be a string", path: "#{base}.#{field}") if
            service.key?(field) && !service[field].is_a?(String)
        end
        validate_service_url(service["url"], "#{base}.url", errors) if service["url"].is_a?(String)
      end
    end
    private_class_method :validate_services

    def validate_service_url(value, path, errors)
      uri = ::URI.parse(value)
      return if uri.is_a?(::URI::HTTPS) && !uri.host.to_s.empty? && uri.user.nil? && uri.password.nil?

      errors << ValidationError.new("#{path} must be an absolute credential-free HTTPS URL", path: path)
    rescue ::URI::InvalidURIError
      errors << ValidationError.new("#{path} must be a valid URL", path: path)
    end
    private_class_method :validate_service_url

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
