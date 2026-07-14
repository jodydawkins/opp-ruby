RSpec.describe OPP::Canonicalization do
  RFC_8785_NUMBERS = {
    "0000000000000000" => "0",
    "8000000000000000" => "0",
    "0000000000000001" => "5e-324",
    "8000000000000001" => "-5e-324",
    "7fefffffffffffff" => "1.7976931348623157e+308",
    "ffefffffffffffff" => "-1.7976931348623157e+308",
    "4340000000000000" => "9007199254740992",
    "c340000000000000" => "-9007199254740992",
    "4430000000000000" => "295147905179352830000",
    "44b52d02c7e14af5" => "9.999999999999997e+22",
    "44b52d02c7e14af6" => "1e+23",
    "44b52d02c7e14af7" => "1.0000000000000001e+23",
    "444b1ae4d6e2ef4e" => "999999999999999700000",
    "444b1ae4d6e2ef4f" => "999999999999999900000",
    "444b1ae4d6e2ef50" => "1e+21",
    "3eb0c6f7a0b5ed8c" => "9.999999999999997e-7",
    "3eb0c6f7a0b5ed8d" => "0.000001",
    "41b3de4355555553" => "333333333.3333332",
    "41b3de4355555554" => "333333333.33333325",
    "41b3de4355555555" => "333333333.3333333",
    "41b3de4355555556" => "333333333.3333334",
    "41b3de4355555557" => "333333333.33333343",
    "becbf647612f3696" => "-0.0000033333333333333333",
    "43143ff3c1cb0959" => "1424953923781206.2"
  }.freeze

  it "uses UTF-16 property ordering and RFC 8785 number formatting" do
    value = { "\u{1F600}" => 1.0e30, "\u20ac" => "x\n" }

    expect(described_class.canonicalize(value))
      .to eq("{\"€\":\"x\\n\",\"😀\":1e+30}")
  end

  it "serializes the RFC 8785 Appendix B IEEE 754 vectors" do
    RFC_8785_NUMBERS.each do |bits, expected|
      number = [bits].pack("H*").unpack1("G")
      expect(described_class.canonicalize(number)).to eq(expected), bits
    end
  end

  it "preserves all shortest round-trip digits" do
    expect(described_class.canonicalize(1.2345678901234567)).to eq("1.2345678901234567")
  end

  it "applies IEEE 754 double semantics to parsed integer tokens" do
    parsed = OPP::JSON.parse('{"number":295147905179352825856}')

    expect(described_class.canonicalize(parsed)).to eq('{"number":295147905179352830000}')
  end

  it "rejects non-finite numbers" do
    expect { described_class.canonicalize(Float::NAN) }.to raise_error(OPP::CanonicalizationError)
    expect { described_class.canonicalize(Float::INFINITY) }.to raise_error(OPP::CanonicalizationError)
  end
end
