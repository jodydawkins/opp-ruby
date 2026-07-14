require "spec_helper"

RSpec.describe OPP::PublicKey do
  it "returns validated raw key bytes" do
    key = "A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg"

    expect(described_class.decode(key)).to be_a(String)
  end

  it "raises a structured error for an invalid public key type" do
    expect { described_class.decode(nil) }
      .to raise_error(OPP::InvalidPublicKeyError)
  end

  it "raises a structured error for an invalid public key length" do
    expect { described_class.decode(OPP::Base64URL.encode("short")) }
      .to raise_error(OPP::InvalidPublicKeyError)
  end
end

RSpec.describe OPP::Subject do
  let(:public_key) { "A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg" }

  it "derives the upstream subject" do
    expect(described_class.derive(public_key))
      .to eq("key:sha256:Vkdap1RjR0wChd9dvyvKtz2mUTWIOem3dIGy6rEHcIw")
  end

  it "verifies a matching subject" do
    subject = described_class.derive(public_key)

    expect(described_class.verify!(subject, public_key:)).to be(true)
  end

  it "raises on a mismatch" do
    expect { described_class.verify!("key:sha256:wrong", public_key:) }
      .to raise_error(OPP::SubjectMismatchError)
  end
end
