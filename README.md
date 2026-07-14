# OPP Ruby

`opp` implements the Open Presence Protocol (OPP) 0.1 Presence Document
lifecycle and reusable OPP signing primitives for Ruby 3.2 and newer.

## Installation

Add the gem to your bundle:

```ruby
gem "opp", "~> 0.1.0"
```

Then run `bundle install`. To install it directly, run
`gem install opp -v "~> 0.1.0"`.

## Presence Documents

Generate an Ed25519 key pair and derive its OPP subject:

```ruby
require "opp"
require "time"

pair = OPP::KeyPair.generate
subject = OPP::Subject.derive(pair.public_key)
```

`pair.private_key` is a secret 32-byte seed encoded as unpadded Base64url.
Do not log, publish, or commit it. Store it with the same protections as any
other signing credential. The public key and derived subject are safe to
publish.

Sign a Presence Document. Signing returns a new hash and does not mutate the
input. The public key, subject, and signature are added by the library.

```ruby
document = {
  "type" => "open-presence",
  "version" => "0.1",
  "issued_at" => "2026-07-12T00:00:00Z",
  "expires_at" => "2026-07-13T00:00:00Z",
  "services" => [
    { "type" => "profile", "url" => "https://example.com/alice" }
  ]
}

signed = OPP::Presence.sign(document, private_key: pair.private_key)
```

Non-bang verification returns an `OPP::VerificationResult`. Pass `at:` when
you need a reproducible verification time; otherwise it defaults to the
current UTC time.

```ruby
result = OPP::Presence.verify(
  signed,
  at: Time.iso8601("2026-07-12T12:00:00Z")
)

if result.valid?
  puts "valid"
else
  result.errors.each do |error|
    warn [error.code, error.path, error.message].compact.join(": ")
  end
end
```

`OPP::Presence.verify!` returns `true` for a valid document and raises the
first structured `OPP::Error` for an invalid one:

```ruby
begin
  OPP::Presence.verify!(signed, at: Time.iso8601("2026-07-12T12:00:00Z"))
rescue OPP::Error => error
  warn "#{error.code} at #{error.path}: #{error.message}"
end
```

Errors expose a machine-readable `code`, an optional field `path`, and a
human-readable message. Specific failures use subclasses such as
`OPP::ValidationError`, `OPP::InvalidSignatureError`,
`OPP::ExpiredDocumentError`, and `OPP::UnsupportedVersionError`.

Unknown top-level fields, unknown service fields, and unknown service types
are accepted. They remain part of the canonical signed payload, so changing
or removing them invalidates the signature.

## Generic signatures

`OPP::Signature` signs any JSON-object-shaped hash without applying Presence
validation. This is useful for other OPP objects:

```ruby
registration = {
  "type" => "open-presence-directory-registration",
  "version" => "0.2"
  "sequence" => 7,
  "subject" => subject,
  "extension" => { "enabled" => true }
}

signed_registration = OPP::Signature.sign(
  registration,
  private_key: pair.private_key
)
OPP::Signature.verify!(signed_registration, public_key: pair.public_key)
```

`OPP::Signature.verify!` returns `true` or raises
`OPP::InvalidSignatureError`. `OPP::Signature.verify` is also available when
a boolean result is preferable. Both signing APIs return deep copies rather
than mutating caller-owned hashes, and unknown and nested fields are
authenticated.

The generic API is responsible only for signature structure,
canonicalization, key handling, and cryptographic verification. In
particular, it does not validate Directory Registration schemas, sequence
rules, persistence, networking, or discovery. Applications using generic
signatures must validate their own object schema and protocol rules.

## Vectors and interoperability

The offline conformance suite vendors the language-neutral OPP vectors under
`spec/fixtures/opp`. Their source repository, exact commit, retrieval date,
and verification time are recorded in `spec/fixtures/opp/UPSTREAM.yml`; the
current snapshot comes from `jodydawkins/opp` commit
`73e4e761ad05ac5b6f4cd7ac3ad7c59842dadeba`.

For reciprocal interoperability testing:

1. Use the deterministic private-key seed from the pinned vector snapshot.
2. Sign the same document with `OPP::Presence.sign` and serialize the returned
   hash as JSON.
3. Add the Ruby-produced JSON to the upstream/Rust interoperability fixtures
   and verify it there at the manifest's fixed verification time.
4. Copy the corresponding Rust-produced signed fixture into the pinned Ruby
   snapshot and run `bundle exec rspec spec/opp/conformance_spec.rb` offline.

This gem deliberately has no CLI. Use the Ruby API directly or build
application-specific commands around it.

## License

Apache-2.0. See `LICENSE`.
