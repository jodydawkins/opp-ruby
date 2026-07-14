require "json"

module OPP
  module JSON
    class DuplicateCheckingObject
      include Enumerable

      def initialize
        @members = {}
      end

      def []=(key, value)
        raise DuplicateMemberError, "duplicate JSON member: #{key}" if @members.key?(key)

        @members[key] = value
      end

      def each(&block)
        @members.each(&block)
      end
    end
    private_constant :DuplicateCheckingObject

    module_function

    def parse(input)
      plain_value(::JSON.parse(input, object_class: DuplicateCheckingObject))
    rescue ::JSON::ParserError, EncodingError => error
      raise ParseError, error.message
    end

    def plain_value(value)
      case value
      when DuplicateCheckingObject
        value.to_h { |key, member| [valid_string(key), plain_value(member)] }
      when Array
        value.map { |member| plain_value(member) }
      when String
        valid_string(value)
      else
        value
      end
    end
    private_class_method :plain_value

    def valid_string(value)
      raise EncodingError, "invalid Unicode in JSON string" unless value.valid_encoding?

      value
    end
    private_class_method :valid_string
  end
end
