require "spec_helper"

RSpec.describe OPP::KeyPair do
  let(:seed) { "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8" }

  it "derives the upstream deterministic public key" do
    pair = described_class.from_private_key(seed)

    expect(pair.private_key).to eq(seed)
    expect(pair.public_key).to eq("A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg")
  end

  it "generates an encodable Ed25519 key pair" do
    pair = described_class.generate

    expect(OPP::Base64URL.decode(pair.private_key, length: 32)).to be_a(String)
    expect(OPP::PublicKey.decode(pair.public_key).bytesize).to eq(32)
  end

  it "signs raw bytes" do
    pair = described_class.from_private_key(seed)

    verify_key = Ed25519::VerifyKey.new(OPP::PublicKey.decode(pair.public_key))

    expect(verify_key.verify(pair.sign("message"), "message")).to be(true)
  end

  it "raises a structured error for an invalid private key type" do
    expect { described_class.from_private_key(nil) }
      .to raise_error(OPP::InvalidEncodingError)
  end

  it "raises a structured error for an invalid private key length" do
    expect { described_class.from_private_key(OPP::Base64URL.encode("short")) }
      .to raise_error(OPP::InvalidEncodingError)
  end
end
