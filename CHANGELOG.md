# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Require Ruby 3.3 or later (was Ruby 2.7)
- Replace unmaintained `rest-client` with `faraday` + `faraday-multipart`
- Replace unmaintained `archive-tar-minitar` with `minitar` 1.x
- Write the upload tarball to a temporary file instead of the shared `/tmp/out` path
- Load `~/.morph` config with safe YAML loading
- Fill in gem metadata: homepage, source code, bug tracker and changelog URIs; require
  MFA for manual pushes to RubyGems

### Added

- SimpleCov coverage reporting and a much expanded test suite (CLI and HTTP behaviour
  tested with WebMock, no network access in tests)

## [0.2.5] and earlier

No changelog was kept for releases up to and including 0.2.5. See the
[commit history](https://github.com/openaustralia/morph-cli/commits/main) for details.

[Unreleased]: https://github.com/openaustralia/morph-cli/compare/v0.2.5...HEAD
[0.2.5]: https://github.com/openaustralia/morph-cli/releases/tag/v0.2.5
