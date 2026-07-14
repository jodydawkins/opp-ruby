require "spec_helper"

RSpec.describe "opp.gemspec" do
  it "packages only the public library and root documentation" do
    gemspec = Gem::Specification.load(File.expand_path("../../opp.gemspec", __dir__))
    expected = Dir[File.expand_path("../../lib/**/*.rb", __dir__)]
      .map { |path| path.delete_prefix(File.expand_path("../..", __dir__) + "/") }
      .concat(%w[LICENSE README.md])

    expect(gemspec.files.sort).to eq(expected.sort)
  end

  it "declares base64 as a runtime dependency" do
    gemspec = Gem::Specification.load(File.expand_path("../../opp.gemspec", __dir__))

    expect(gemspec.runtime_dependencies.map(&:name)).to include("base64")
  end
end
