lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "morph-cli/version"

Gem::Specification.new do |spec|
  spec.name          = "morph-cli"
  spec.version       = MorphCLI::VERSION
  spec.authors       = ["Matthew Landauer"]
  spec.email         = ["matthew@oaf.org.au"]
  spec.summary       = "Run morph.io scrapers from the command line"
  spec.description   = "Command line interface for morph.io. Uploads the scraper in the " \
                       "current directory to a morph.io server, runs it there and streams " \
                       "the output back to your terminal."
  spec.homepage      = "https://github.com/openaustralia/morph-cli"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri" => "https://github.com/openaustralia/morph-cli",
    "source_code_uri" => "https://github.com/openaustralia/morph-cli",
    "bug_tracker_uri" => "https://github.com/openaustralia/morph-cli/issues",
    "changelog_uri" => "https://github.com/openaustralia/morph-cli/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = %w[morph]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "filesize", "~> 0.2"
  spec.add_dependency "minitar", "~> 1.0"
  spec.add_dependency "thor", "~> 1.0"
end
