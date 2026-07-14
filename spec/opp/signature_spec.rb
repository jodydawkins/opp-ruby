require "spec_helper"

RSpec.describe OPP::Signature do
  let(:private_key) { "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8" }
  let(:public_key) { "A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg" }
  let(:registration) do
    {
      "type" => "directory-registration",
      "sequence" => 7,
      "subject" => "example",
      "extension" => { "enabled" => true, "labels" => ["one", "two"] }
    }
  end

  it "signs and verifies a non-Presence object without mutation" do
    original = registration.dup
    signed = described_class.sign(registration, private_key:)

    expect(registration).to eq(original)
    expect(registration).not_to have_key("signature")
    expect(signed["signature"]).to match(
      "algorithm" => "ed25519",
      "value" => a_kind_of(String)
    )
    expect(OPP::Base64URL.decode(signed.dig("signature", "value"), length: 64).bytesize).to eq(64)
    expect(described_class.verify(signed, public_key:)).to be(true)
  end

  it "deep-copies nested hashes, arrays, and strings" do
    signed = described_class.sign(registration, private_key:)

    expect(signed["extension"]).not_to equal(registration["extension"])
    expect(signed.dig("extension", "labels")).not_to equal(registration.dig("extension", "labels"))
    expect(signed.dig("extension", "labels", 0)).not_to equal(registration.dig("extension", "labels", 0))
  end

  it "authenticates unknown and nested members" do
    signed = described_class.sign(registration, private_key:)
    signed["extension"]["labels"] << "tampered"

    expect { described_class.verify!(signed, public_key:) }
      .to raise_error(OPP::InvalidSignatureError)
    expect(described_class.verify(signed, public_key:)).to be(false)
  end

  it "omits only a top-level string signature member when signing" do
    document = registration.merge(
      "signature" => { "stale" => true },
      "nested" => { "signature" => "authenticated" }
    )
    signed = described_class.sign(document, private_key:)

    expect(described_class.verify(signed, public_key:)).to be(true)
    signed["nested"]["signature"] = "tampered"
    expect(described_class.verify(signed, public_key:)).to be(false)
  end

  it "requires string-valued algorithm and value members" do
    valid = described_class.sign(registration, private_key:)
    invalid_signatures = [
      nil,
      { "algorithm" => "ed25519" },
      { "algorithm" => "ed25519", "value" => 7 },
      { algorithm: "ed25519", value: valid.dig("signature", "value") }
    ]

    invalid_signatures.each do |signature|
      document = valid.merge("signature" => signature)
      expect { described_class.verify!(document, public_key:) }
        .to raise_error(OPP::InvalidSignatureError)
    end
  end

  it "ignores unknown signature members" do
    signed = described_class.sign(registration, private_key:)

    expect(
      described_class.verify!(
        signed.merge("signature" => signed["signature"].merge("extra" => true, extra: true)),
        public_key:
      )
    ).to be(true)
  end

  it "recognizes only the top-level string signature key" do
    signed = described_class.sign(registration, private_key:)
    symbol_keyed = signed.reject { |key, _| key == "signature" }
      .merge(signature: signed["signature"])

    expect { described_class.verify!(symbol_keyed, public_key:) }
      .to raise_error(OPP::InvalidSignatureError)
  end

  it "rejects unsupported algorithms and signatures of the wrong decoded length" do
    signed = described_class.sign(registration, private_key:)

    unsupported = signed.merge("signature" => signed["signature"].merge("algorithm" => "other"))
    short = signed.merge("signature" => signed["signature"].merge("value" => OPP::Base64URL.encode("short")))

    expect { described_class.verify!(unsupported, public_key:) }
      .to raise_error(OPP::InvalidSignatureError, "unsupported signature algorithm")
    expect { described_class.verify!(short, public_key:) }
      .to raise_error(OPP::InvalidSignatureError)
  end

  it "translates private-key and public-key failures to InvalidSignatureError" do
    expect { described_class.sign(registration, private_key: "invalid") }
      .to raise_error(OPP::InvalidSignatureError)

    signed = described_class.sign(registration, private_key:)
    expect { described_class.verify!(signed, public_key: "invalid") }
      .to raise_error(OPP::InvalidSignatureError)
  end

  it "rejects non-object roots without converting validation errors to false" do
    expect { described_class.sign([], private_key:) }
      .to raise_error(OPP::ValidationError)
    expect { described_class.verify!([], public_key:) }
      .to raise_error(OPP::ValidationError)
    expect { described_class.verify([], public_key:) }
      .to raise_error(OPP::ValidationError)
  end
end
