RSpec.describe OPP::Error do
  it "exposes a default machine-readable code and optional path" do
    error = OPP::InvalidEncodingError.new("bad encoding", path: ["public_key"])

    expect(error.code).to eq("invalid_encoding")
    expect(error.path).to eq(["public_key"])
  end
end

RSpec.describe OPP::Base64URL do
  it "round trips bytes without padding" do
    encoded = described_class.encode("\x00\xff".b)
    expect(encoded).to eq("AP8")
    expect(described_class.decode(encoded)).to eq("\x00\xff".b)
  end

  %w[AP8= AP8\n AP+8 AP/8].each do |invalid|
    it "rejects non-canonical input #{invalid.inspect}" do
      expect { described_class.decode(invalid) }
        .to raise_error(OPP::InvalidEncodingError)
    end
  end

  it "checks the decoded length" do
    expect { described_class.decode("AP8", length: 32) }
      .to raise_error(OPP::InvalidEncodingError, /32 bytes/)
  end
end
