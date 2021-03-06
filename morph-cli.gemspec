# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'morph-cli/version'

Gem::Specification.new do |spec|
  spec.name          = "morph-cli"
  spec.version       = MorphCLI::VERSION
  spec.authors       = ["Matthew Landauer"]
  spec.email         = ["matthew@oaf.org.au"]
  spec.description   = %q{Command line interface for Morph}
  spec.summary       = %q{Command line interface for Morph}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "> 0.17"
  spec.add_dependency "rest-client"
  spec.add_dependency 'archive-tar-minitar'
  spec.add_dependency "filesize", ">= 0.1"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.executables   = %w(morph)
end
