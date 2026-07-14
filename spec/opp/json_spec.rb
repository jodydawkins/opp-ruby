RSpec.describe OPP::JSON do
  it "returns ordinary nested hashes" do
    expect(described_class.parse('{"a":{"b":1}}')).to eq("a" => { "b" => 1 })
  end

  it "rejects duplicate members at any depth" do
    expect { described_class.parse('{"a":{"x":1,"x":2}}') }
      .to raise_error(OPP::DuplicateMemberError, /x/)
  end

  it "wraps malformed JSON" do
    expect { described_class.parse("{") }.to raise_error(OPP::ParseError)
  end

  it "rejects invalid UTF-8 in string values and object keys" do
    expect { described_class.parse(%Q({"x":"\xFF"}).b) }.to raise_error(OPP::ParseError)
    expect { described_class.parse(%Q({"\xFF":1}).b) }.to raise_error(OPP::ParseError)
  end

  it "rejects lone Unicode surrogates" do
    expect { described_class.parse('{"x":"\\uDC00"}') }.to raise_error(OPP::ParseError)
  end

  it "preserves valid Unicode strings and keys" do
    expect(described_class.parse('{"é":"é","😀":"雪"}'))
      .to eq("é" => "é", "😀" => "雪")
  end
end
