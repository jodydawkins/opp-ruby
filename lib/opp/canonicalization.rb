require "json/canonicalization"

module OPP
  module Canonicalization
    module_function

    def canonicalize(value)
      value.to_json_c14n.force_encoding(Encoding::UTF_8)
    rescue StandardError => error
      raise if error.is_a?(OPP::Error)

      raise CanonicalizationError, error.message
    end
  end
end
