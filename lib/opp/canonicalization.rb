require "json/canonicalization"

module OPP
  module Canonicalization
    class NumberAdapter
      def initialize(value)
        @value = value.to_f
      end

      def to_json_c14n
        Canonicalization.send(:serialize_float, @value)
      end
    end
    private_constant :NumberAdapter

    module_function

    def canonicalize(value)
      adapt(value).to_json_c14n.encode(Encoding::UTF_8)
    rescue StandardError => error
      raise if error.is_a?(OPP::Error)

      raise CanonicalizationError, error.message
    end

    def adapt(value)
      case value
      when Integer, Float
        NumberAdapter.new(value)
      when Hash
        value.to_h { |key, member| [key, adapt(member)] }
      when Array
        value.map { |member| adapt(member) }
      else
        value
      end
    end
    private_class_method :adapt

    def serialize_float(value)
      raise RangeError, "non-finite number" unless value.finite?
      return "0" if value.zero?

      representation = value.to_s
      sign = representation.delete_prefix!("-") ? "-" : ""
      return sign + representation.delete_suffix(".0") unless representation.include?("e")

      mantissa, exponent_text = representation.split("e")
      exponent = exponent_text.to_i
      digits = mantissa.end_with?(".0") ? mantissa.delete_suffix(".0") : mantissa.delete(".")

      if exponent.between?(-6, 20)
        decimal_position = exponent + 1
        decimal = if decimal_position <= 0
                    "0." + ("0" * -decimal_position) + digits
                  elsif decimal_position >= digits.length
                    digits + ("0" * (decimal_position - digits.length))
                  else
                    digits.dup.insert(decimal_position, ".")
                  end
        sign + decimal
      else
        coefficient = digits.length == 1 ? digits : digits.dup.insert(1, ".")
        sign + coefficient + "e" + (exponent.positive? ? "+" : "") + exponent.to_s
      end
    end
    private_class_method :serialize_float
  end
end
