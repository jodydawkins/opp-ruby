require "json"

module OPP
  module JSON
    class DuplicateCheckingHash < Hash
      def []=(key, value)
        raise DuplicateMemberError, "duplicate JSON member: #{key}" if key?(key)

        super
      end
    end
    private_constant :DuplicateCheckingHash

    module_function

    def parse(input)
      plain_value(::JSON.parse(input, object_class: DuplicateCheckingHash))
    rescue ::JSON::ParserError, EncodingError => error
      raise ParseError, error.message
    end

    def plain_value(value)
      case value
      when DuplicateCheckingHash
        value.to_h.transform_values { |member| plain_value(member) }
      when Array
        value.map { |member| plain_value(member) }
      else
        value
      end
    end
    private_class_method :plain_value
  end
end
