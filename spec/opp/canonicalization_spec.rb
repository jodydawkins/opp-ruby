RSpec.describe OPP::Canonicalization do
  it "uses UTF-16 property ordering and RFC 8785 number formatting" do
    value = { "\u{1F600}" => 1.0e30, "\u20ac" => "x\n" }

    expect(described_class.canonicalize(value))
      .to eq("{\"€\":\"x\\n\",\"😀\":1e+30}")
  end
end
