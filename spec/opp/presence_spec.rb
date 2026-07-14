require "spec_helper"

RSpec.describe OPP::VerificationResult do
  it "exposes frozen errors and validity" do
    valid = described_class.new([])
    error = OPP::ValidationError.new("invalid")
    invalid = described_class.new([error])

    expect(valid).to be_valid
    expect(invalid).not_to be_valid
    expect(invalid.errors).to eq([error])
    expect(invalid.errors).to be_frozen
  end
end

RSpec.describe OPP::Presence do
  let(:private_key) { "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8" }
  let(:public_key) { "A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg" }
  let(:subject) { OPP::Subject.derive(public_key) }
  let(:verification_time) { Time.iso8601("2026-07-12T00:00:00Z") }
  let(:document) do
    {
      "type" => "open-presence",
      "version" => "0.1",
      "issued_at" => "2026-07-11T20:00:00Z",
      "expires_at" => "2026-10-11T20:00:00Z",
      "services" => [{ "type" => "profile", "url" => "https://example.com/jody", "label" => "Jody" }],
      "extension" => { "count" => 1 }
    }
  end

  it "provides the Presence lifecycle API" do
    expect(described_class).to respond_to(:sign, :verify, :verify!)
  end

  it "signs and verifies the complete lifecycle without mutation" do
    original = Marshal.load(Marshal.dump(document))
    signed = described_class.sign(document, private_key:)

    expect(document).to eq(original)
    expect(signed).to include("public_key" => public_key, "subject" => subject)
    expect(signed["extension"]).not_to equal(document["extension"])
    expect(described_class.verify(signed, at: verification_time)).to be_valid
    expect(described_class.verify!(signed, at: verification_time)).to be(true)
  end

  it "accepts raw JSON and authenticates unknown fields" do
    signed = described_class.sign(document, private_key:)
    expect(described_class.verify(::JSON.generate(signed), at: verification_time)).to be_valid

    signed["extension"]["count"] = 2
    result = described_class.verify(signed, at: verification_time)
    expect(result.errors).to contain_exactly(an_instance_of(OPP::InvalidSignatureError))
  end

  it "aggregates schema failures in deterministic rule order" do
    result = described_class.verify({ "type" => "wrong", "version" => "9" }, at: verification_time)

    expect(result.errors.map { |error| [error.class, error.path] }).to eq([
      [OPP::ValidationError, "subject"],
      [OPP::ValidationError, "public_key"],
      [OPP::ValidationError, "issued_at"],
      [OPP::ValidationError, "services"],
      [OPP::ValidationError, "signature"],
      [OPP::ValidationError, "type"],
      [OPP::UnsupportedVersionError, "version"]
    ])
    expect { described_class.verify!({ "type" => "wrong", "version" => "9" }, at: verification_time) }
      .to raise_error(OPP::ValidationError, /subject/)
  end

  it "reports root and field type errors without dependent cascades" do
    expect(described_class.verify([], at: verification_time).errors.map(&:path)).to eq([nil])

    invalid = {
      "type" => 1,
      "version" => nil,
      "subject" => [],
      "public_key" => {},
      "issued_at" => 7,
      "expires_at" => false,
      "services" => {},
      "signature" => []
    }
    result = described_class.verify(invalid, at: verification_time)

    expect(result.errors.map(&:path)).to eq(
      %w[type version subject public_key issued_at services signature expires_at]
    )
    expect(result.errors).to all(be_an_instance_of(OPP::ValidationError))
  end

  it "validates the public key before subject matching and signature verification" do
    signed = described_class.sign(document, private_key:)
    signed["public_key"] = "invalid"

    result = described_class.verify(signed, at: verification_time)
    expect(result.errors.map { |error| [error.class, error.path] }).to eq([
      [OPP::InvalidPublicKeyError, "public_key"]
    ])
  end

  it "matches the subject to the usable public key" do
    mismatched = document.merge("public_key" => public_key, "subject" => "key:sha256:wrong")
    signed = OPP::Signature.sign(mismatched, private_key:)

    result = described_class.verify(signed, at: verification_time)
    expect(result.errors.map { |error| [error.class, error.path] }).to eq([
      [OPP::SubjectMismatchError, "subject"]
    ])
  end

  it "requires strict valid RFC 3339 UTC timestamps" do
    invalid_values = [
      "2026-07-11T20:00:00z",
      "2026-07-11T20:00:00+00:00",
      "2026-07-11T20:00Z",
      "2026-02-30T20:00:00Z",
      "2026-07-11T24:00:00Z",
      "2026-07-11T20:00:61Z"
    ]

    invalid_values.each do |issued_at|
      signed = OPP::Signature.sign(
        document.merge("public_key" => public_key, "subject" => subject, "issued_at" => issued_at),
        private_key:
      )
      result = described_class.verify(signed, at: verification_time)
      expect(result.errors.map { |error| [error.class, error.path] })
        .to eq([[OPP::ValidationError, "issued_at"]])
    end
  end

  it "normalizes an RFC 3339 leap second for ordering and expiration" do
    candidate = document.merge(
      "issued_at" => "1990-12-31T23:59:60Z",
      "expires_at" => "1991-01-01T00:00:01Z"
    )

    signed = described_class.sign(candidate, private_key:)
    expect(described_class.verify(signed, at: Time.iso8601("1991-01-01T00:00:00Z"))).to be_valid
  end

  it "requires expires_at to be later than issued_at" do
    before_expiration = Time.iso8601("2026-07-11T19:00:00Z")

    ["2026-07-11T20:00:00Z", "2026-07-11T19:59:59Z"].each do |expires_at|
      candidate = document.merge("expires_at" => expires_at, "public_key" => public_key, "subject" => subject)
      signed = OPP::Signature.sign(candidate, private_key:)

      expect(described_class.verify(signed, at: before_expiration).errors.map(&:path))
        .to eq(["expires_at"])
    end
  end

  it "reports both invalid ordering and expiration when both timestamps are usable" do
    candidate = document.merge(
      "expires_at" => "2026-07-11T20:00:00Z",
      "public_key" => public_key,
      "subject" => subject
    )
    signed = OPP::Signature.sign(candidate, private_key:)

    result = described_class.verify(signed, at: verification_time)
    expect(result.errors.map { |error| [error.class, error.path] }).to eq([
      [OPP::ValidationError, "expires_at"],
      [OPP::ExpiredDocumentError, "expires_at"]
    ])
  end

  it "expires at the exact boundary and accepts fractional UTC timestamps" do
    candidate = document.merge(
      "issued_at" => "2026-07-11T20:00:00.25Z",
      "expires_at" => "2026-07-12T00:00:00.5Z",
      "public_key" => public_key,
      "subject" => subject
    )
    signed = OPP::Signature.sign(candidate, private_key:)

    expect(described_class.verify(signed, at: Time.iso8601("2026-07-12T00:00:00.499Z"))).to be_valid
    result = described_class.verify(signed, at: Time.iso8601("2026-07-12T00:00:00.5Z"))
    expect(result.errors.map { |error| [error.class, error.path] }).to eq([
      [OPP::ExpiredDocumentError, "expires_at"]
    ])
  end

  it "validates each service object and its required string fields in order" do
    candidate = document.merge(
      "public_key" => public_key,
      "subject" => subject,
      "services" => [
        nil,
        {},
        { "type" => 7, "url" => 8 },
        { "type" => "custom-service", "url" => "http://example.com" }
      ]
    )
    signed = OPP::Signature.sign(candidate, private_key:)
    result = described_class.verify(signed, at: verification_time)

    expect(result.errors.map(&:path)).to eq([
      "services[0]",
      "services[1].type",
      "services[1].url",
      "services[2].type",
      "services[2].url",
      "services[3].url"
    ])
    expect(result.errors).to all(be_an_instance_of(OPP::ValidationError))
  end

  it "requires absolute credential-free HTTPS service URLs" do
    invalid_urls = [
      "http://example.com/x",
      "/relative",
      "https:///missing-host",
      "https://user@example.com/x",
      "https://user:pass@example.com/x",
      "not a url"
    ]

    invalid_urls.each do |url|
      candidate = document.merge("services" => [{ "type" => "unknown", "url" => url }])
      expect { described_class.sign(candidate, private_key:) }
        .to raise_error(OPP::ValidationError, /url/)
    end
  end

  it "returns raw JSON parse and duplicate-member failures as result entries" do
    duplicate = '{"type":"open-presence","extension":{"x":1,"x":2}}'

    expect(described_class.verify(duplicate, at: verification_time).errors)
      .to contain_exactly(an_instance_of(OPP::DuplicateMemberError))
    expect(described_class.verify("{", at: verification_time).errors)
      .to contain_exactly(an_instance_of(OPP::ParseError))
  end

  it "replaces stale credentials and signatures while preserving caller input" do
    candidate = document.merge(
      "public_key" => "claimed",
      "subject" => "claimed",
      "signature" => "stale"
    )
    original = Marshal.load(Marshal.dump(candidate))

    signed = described_class.sign(candidate, private_key:)
    expect(candidate).to eq(original)
    expect(signed).to include("public_key" => public_key, "subject" => subject)
    expect(signed["signature"]).to be_a(Hash)
  end

  it "can sign a structurally valid historical document without hiding expiration on verify" do
    historical = document.merge("expires_at" => "2026-07-12T00:00:00Z")

    signed = described_class.sign(historical, private_key:)
    expect(described_class.verify(signed, at: verification_time).errors)
      .to contain_exactly(an_instance_of(OPP::ExpiredDocumentError))
  end

  it "raises a structured validation error when signing a non-object" do
    expect { described_class.sign([], private_key:) }
      .to raise_error(OPP::ValidationError, /object/)
  end
end
