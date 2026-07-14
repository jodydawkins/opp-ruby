# OPP Ruby 0.1 Design

## Scope

Implement issue #1 as a Ruby 3.2+ gem that provides the complete Open Presence Protocol 0.1 Presence Document lifecycle and reusable lower-level protocol primitives. The gem will not include a CLI.

The implementation will conform to the language-neutral vectors in `jodydawkins/opp`, interoperate with its Rust reference implementation, use the `OPP` namespace, and retain the repository's Apache-2.0 license.

Directory Registration schema rules, sequence handling, persistence, networking, discovery, and other directory-specific concerns remain outside the gem.

## Dependencies

Use Ruby's standard `json`, `base64`, `digest`, `time`, and `uri` libraries wherever possible. Add two focused runtime dependencies:

- `ed25519` for key generation, deterministic seed loading, signing, and verification.
- `json-canonicalization` for RFC 8785 JSON Canonicalization Scheme serialization.

RSpec is the test dependency. No general schema framework, URL validation library, or command framework is needed.

## Public Architecture

The gem exposes the following components:

- `OPP::JSON`: strict JSON parsing with duplicate member detection at every nesting level.
- `OPP::Canonicalization`: RFC 8785 serialization of parsed Ruby values.
- `OPP::Base64URL`: strict unpadded Base64url encoding and decoding.
- `OPP::KeyPair`: Ed25519 key generation and construction from a 32-byte private-key seed.
- `OPP::PublicKey`: decoding and validation of 32-byte Ed25519 public keys.
- `OPP::Subject`: subject derivation and subject/public-key matching.
- `OPP::Signature`: generic OPP-style signing and verification for arbitrary JSON objects.
- `OPP::Presence`: high-level parsing, signing, validation, and verification of Presence Documents.
- `OPP::VerificationResult`: a result containing structured validation errors and a `valid?` predicate.
- Structured exception classes rooted at `OPP::Error`.

Primitive modules remain independently usable by `opp-directory` and other OPP implementations. Generic signature verification never invokes Presence Document validation.

## Parsing and Canonicalization

`OPP::JSON.parse` accepts a JSON string and returns ordinary Ruby hashes, arrays, strings, numbers, booleans, and `nil`. It detects a repeated member name before overwriting and raises `OPP::DuplicateMemberError`. Malformed JSON, invalid Unicode, or a non-object top-level value required by an object API raises a structured parse or validation error as appropriate.

`OPP::Canonicalization.canonicalize` delegates RFC 8785 serialization to `json-canonicalization`, returns a UTF-8 string, and translates dependency failures into `OPP::CanonicalizationError`.

## Encoding and Keys

`OPP::Base64URL` uses unpadded URL-safe Base64. Decoding rejects padding, whitespace, non-URL-safe alphabet characters, non-canonical encodings, and unexpected decoded lengths when a length is supplied.

`OPP::KeyPair.generate` returns a key pair with Base64url-encoded `private_key` and `public_key` values. The private key is the 32-byte Ed25519 seed used by the protocol fixtures. Construction from a supplied seed supports deterministic vectors.

`OPP::Subject.derive` decodes and validates the public key, hashes its 32 raw bytes with SHA-256, encodes the digest with unpadded Base64url, and prefixes `key:sha256:`. `verify!` raises `OPP::SubjectMismatchError` when the supplied subject differs.

## Generic Signatures

`OPP::Signature.sign(document, private_key:)`:

1. Requires a JSON object.
2. Creates a deep copy with only the top-level `signature` member removed.
3. Canonicalizes the copy with RFC 8785.
4. Signs its UTF-8 bytes with Ed25519.
5. Returns a new object containing `signature: { "algorithm" => "ed25519", "value" => "..." }`.

The caller's object is never mutated. Every nested and unknown member is authenticated.

`OPP::Signature.verify!` validates the signature object's exact required members and types, requires `ed25519`, strictly decodes a 32-byte public key and 64-byte signature, canonicalizes the unsigned object, and verifies the signature. It performs no Presence schema checks. A non-bang `verify` returns a boolean.

## Presence Documents

`OPP::Presence.sign(document, private_key:)` derives the public key and subject from the private key, places those values into a copy of the document, validates all unsigned Presence fields, and delegates signing to `OPP::Signature`. It returns the signed copy and cannot produce a document whose subject and public key disagree with its signing key.

`OPP::Presence.verify(input, at: Time.now.utc)` accepts either raw JSON or a parsed hash. Its data flow is:

1. Strictly parse raw JSON when needed.
2. Validate the Presence schema and field types.
3. Validate the public key and derived subject.
4. Validate timestamps, expiration, and services.
5. Verify the generic signature when prerequisite fields are usable.
6. Return an `OPP::VerificationResult` containing errors in deterministic validation order.

`OPP::Presence.verify!` performs the same work and raises the first error when verification fails.

Required members are `type`, `version`, `subject`, `public_key`, `issued_at`, `services`, and `signature`. `type` must equal `open-presence`; `version` must equal `0.1`. Unknown top-level fields, service fields, and service types are retained and accepted.

Timestamps must be valid RFC 3339 UTC values using an uppercase `Z` suffix. When present, `expires_at` must be later than `issued_at`, and the document is expired when the verification time is at or after `expires_at`.

`services` must be an array. Each member must be an object containing string-valued `type` and `url` members. The URL must be an absolute HTTPS URL without username or password components.

## Errors and Results

The public exception hierarchy includes:

- `OPP::ParseError`
- `OPP::DuplicateMemberError`
- `OPP::ValidationError`
- `OPP::CanonicalizationError`
- `OPP::InvalidEncodingError`
- `OPP::InvalidPublicKeyError`
- `OPP::SubjectMismatchError`
- `OPP::InvalidSignatureError`
- `OPP::ExpiredDocumentError`
- `OPP::UnsupportedVersionError`

Errors carry a machine-readable code and message, plus an optional field path. Primitive bang APIs raise their specific error immediately. Presence verification aggregates independent failures while skipping checks whose prerequisites are unusable, avoiding misleading cascades. Bang verification raises the first collected error.

## Test Vectors and Interoperability

Vendor a snapshot of upstream `vectors/` beneath `spec/fixtures/opp/`. A manifest records the exact upstream repository and commit SHA. Tests never download a moving branch.

Conformance specs will:

- Accept every valid upstream vector at its declared verification time.
- Reject every invalid vector with the expected structured error category.
- Detect duplicate members, including nested duplicates.
- Reproduce the deterministic public key, subject, canonical document, signature, and verification result.
- Verify Rust-produced signed fixtures with Ruby.
- Cover generic signatures with a Directory Registration-shaped object without applying Presence validation.

Focused unit specs cover strict Base64url behavior, key lengths, subject matching, RFC 8785 edge cases, non-mutation, signature structure, error aggregation, timestamp boundaries, URL restrictions, and unknown fields.

The reciprocal Ruby-to-Rust fixture process will be documented and use the same deterministic fixture so the Rust suite or CLI can verify Ruby output without runtime coupling between repositories.

## Gem and CI

Use a conventional gem layout with `lib/opp.rb`, focused files under `lib/opp/`, `opp.gemspec`, `Gemfile`, RSpec configuration, and no executable. The gemspec requires Ruby 3.2 or newer and declares Apache-2.0 metadata.

GitHub Actions runs dependency installation, `bundle exec rspec`, and `gem build opp.gemspec` on Ruby 3.2, 3.3, 3.4, and 3.5.

The README documents installation, key generation, subject derivation, Presence signing and verification, generic object signing, structured errors, security expectations for private keys, vector provenance, and the absence of directory-specific validation.

## Completion Criteria

The work is complete when:

- The public APIs above are implemented and documented.
- All unit and vendored-vector specs pass.
- The deterministic values match upstream exactly.
- Generic signatures work independently of Presence validation.
- The gem builds successfully.
- CI covers Ruby 3.2 through 3.5.
- No CLI or directory-specific behavior is present.
