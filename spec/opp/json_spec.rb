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
end
