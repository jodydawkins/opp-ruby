Gem::Specification.new do |spec|
  spec.name = "opp"
  spec.version = "0.1.0"
  spec.authors = ["Jody Dawkins"]
  spec.summary = "Open Presence Protocol for Ruby"
  spec.homepage = "https://github.com/jodydawkins/opp-ruby"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ed25519", "~> 1.4"
  spec.add_dependency "base64", ">= 0.2", "< 1"
  spec.add_dependency "json-canonicalization", "~> 0.4"
  spec.add_development_dependency "rspec", "~> 3.13"
end
