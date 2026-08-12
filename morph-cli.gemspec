lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "morph-cli/version"

Gem::Specification.new do |spec|
  spec.name          = "morph-cli"
  spec.version       = MorphCLI::VERSION
  spec.authors       = ["Matthew Landauer"]
  spec.email         = ["matthew@oaf.org.au"]
  spec.description   = "Command line interface for Morph"
  spec.summary       = "Command line interface for Morph"
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.3"

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = %w[morph]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "filesize", "~> 0.2"
  spec.add_dependency "minitar", "~> 1.0"
  spec.add_dependency "thor", "~> 1.0"
end
