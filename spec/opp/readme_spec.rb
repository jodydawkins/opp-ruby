require "spec_helper"

RSpec.describe "README lifecycle" do
  it "documents the public lifecycle and boundaries" do
    readme = File.read(File.expand_path("../../README.md", __dir__))

    expect(readme).to include(
      "OPP::KeyPair.generate",
      "OPP::Subject.derive",
      "OPP::Presence.sign",
      "OPP::Presence.verify",
      "OPP::Presence.verify!",
      "OPP::Signature.sign",
      "OPP::Signature.verify!",
      "Do not log, publish, or commit it",
      "Unknown top-level fields",
      "does not validate Directory Registration schemas",
      "UPSTREAM.yml",
      "no CLI"
    )
  end

  it "matches the documented public API" do
    pair = OPP::KeyPair.generate
    document = {
      "type" => "open-presence", "version" => "0.1",
      "issued_at" => "2026-07-12T00:00:00Z",
      "expires_at" => "2026-07-13T00:00:00Z", "services" => []
    }
    signed = OPP::Presence.sign(document, private_key: pair.private_key)

    expect(OPP::Subject.derive(pair.public_key)).to eq(signed["subject"])
    expect(OPP::Presence.verify(signed, at: Time.iso8601("2026-07-12T12:00:00Z"))).to be_valid
    expect(OPP::Presence.verify!(signed, at: Time.iso8601("2026-07-12T12:00:00Z"))).to be(true)

    generic = OPP::Signature.sign(
      { "type" => "directory-registration", "extension" => { "enabled" => true } },
      private_key: pair.private_key
    )
    expect(OPP::Signature.verify!(generic, public_key: pair.public_key)).to be(true)
  end
end
