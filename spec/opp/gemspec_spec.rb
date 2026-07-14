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

  it "uses a JSON version that supports custom object classes" do
    gemspec = Gem::Specification.load(File.expand_path("../../opp.gemspec", __dir__))
    dependency = gemspec.runtime_dependencies.find { |candidate| candidate.name == "json" }

    expect(dependency).not_to be_nil
    expect(dependency.requirement).to be_satisfied_by(Gem::Version.new("2.9.1"))
    expect(dependency.requirement).not_to be_satisfied_by(Gem::Version.new("2.10.0"))
  end
end
