require "spec_helper"

RSpec.describe "OPP 0.1 conformance vectors" do
  fixture_root = File.expand_path("../fixtures/opp", __dir__)
  private_key = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"
  public_key = "A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg"
  subject = "key:sha256:Vkdap1RjR0wChd9dvyvKtz2mUTWIOem3dIGy6rEHcIw"
  verification_time = Time.iso8601("2026-07-12T00:00:00Z")

  def parse_fixture(path)
    OPP::JSON.parse(File.binread(path))
  end

  it "accepts valid/signed-document.json produced by Rust" do
    path = File.join(fixture_root, "valid/signed-document.json")

    expect(OPP::Presence.verify(File.binread(path), at: verification_time)).to be_valid
  end

  {
    "duplicate-nested.json" => [OPP::DuplicateMemberError, nil],
    "duplicate-top-level.json" => [OPP::DuplicateMemberError, nil],
    "missing-type.json" => [OPP::ValidationError, "type"],
    "missing-version.json" => [OPP::ValidationError, "version"],
    "unsupported-version.json" => [OPP::UnsupportedVersionError, "version"],
    "wrong-type.json" => [OPP::ValidationError, "type"]
  }.each do |filename, (error_class, path)|
    it "rejects #{filename} as #{error_class.name.split("::").last}" do
      result = OPP::Presence.verify(
        File.binread(File.join(fixture_root, "invalid", filename)),
        at: verification_time
      )

      expect(result).not_to be_valid
      expect(result.errors.first).to be_a(error_class)
      expect(result.errors.first.path).to eq(path)
    end
  end

  it "reproduces valid/unsigned-document.json and valid/signed-document.json byte-for-byte" do
    unsigned = parse_fixture(File.join(fixture_root, "valid/unsigned-document.json"))
    signed_path = File.join(fixture_root, "valid/signed-document.json")
    expected_signed = parse_fixture(signed_path)
    pair = OPP::KeyPair.from_private_key(private_key)
    canonical = OPP::Canonicalization.canonicalize(unsigned)
    signed = OPP::Presence.sign(unsigned, private_key: private_key)

    expect(pair.private_key).to eq(private_key)
    expect(pair.public_key).to eq(public_key)
    expect(OPP::Subject.derive(pair.public_key)).to eq(subject)
    expect(canonical).to eq(
      '{"expires_at":"2026-10-11T20:00:00Z","issued_at":"2026-07-11T20:00:00Z",' \
      '"public_key":"A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg","services":' \
      '[{"type":"profile","url":"https://example.com/jody"},{"type":"feed",' \
      '"url":"https://example.com/jody/feed"}],"subject":' \
      '"key:sha256:Vkdap1RjR0wChd9dvyvKtz2mUTWIOem3dIGy6rEHcIw","type":"open-presence",' \
      '"version":"0.1"}'
    )
    expect(signed).to eq(expected_signed)
    expect(::JSON.pretty_generate(signed) + "\n").to eq(File.binread(signed_path))
    expect(signed.dig("signature", "value")).to eq(
      "-ojCCq5ngoVSQsUB68EGtvuTAQBLajwoHP4irGZUlvfkuyFOy_1uTOp-0lmAWX6wnUs_upzl6mwfMoizUNZbAw"
    )
  end

  it "signs a Directory Registration-shaped object without Presence coupling" do
    registration = {
      "type" => "directory-registration",
      "version" => "0.1",
      "subject" => subject,
      "sequence" => 7,
      "presence_url" => "https://example.com/.well-known/opp.json"
    }

    signed = OPP::Signature.sign(registration, private_key: private_key)

    expect(OPP::Signature.verify(signed, public_key: public_key)).to be(true)
    expect(OPP::Presence.verify(signed, at: verification_time)).not_to be_valid
  end
end
