# Signature Unknown Elements Test Design

## Scope

Update tests only. `OPP::Signature.split` already implements the protocol rule that a signature object must contain string-valued `algorithm` and `value` members while unknown members may be ignored.

## Test changes

- Keep invalid cases for a missing signature object, missing required members, non-string required values, and symbol-keyed replacements for the required string keys.
- Remove unknown members from the invalid-case table.
- Add a positive example showing that verification succeeds when the signature object contains additional string-keyed and symbol-keyed members.

## Verification

Run `spec/opp/signature_spec.rb`, then the complete RSpec suite. No production files or protocol behavior will change.
