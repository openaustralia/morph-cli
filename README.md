[![Gem Version](https://img.shields.io/gem/v/morph-cli)](https://rubygems.org/gems/morph-cli)
[![CI](https://github.com/openaustralia/morph-cli/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/openaustralia/morph-cli/actions/workflows/ci.yml)

# Morph CLI

Runs [morph.io](https://morph.io) scrapers from the command line.

Actually it will run them on the morph.io server identically to the real thing.
That means not installing a bucket load of libraries and bits and bobs that are
already installed with the morph.io scraper environments.

## Installation

You'll need Ruby 3.2 or later. Then

    gem install morph-cli

## Usage

To run the scraper in your current directory

    morph

Yup, that's it.

It runs the code that's there right now. It doesn't need to be checked into git
or anything.

The first time you run it, it will ask for your morph.io API key, which it
saves in `~/.morph`.

For help

    morph help

## Limitations

It uploads your code every time. So if it's big it might take a little while.
Scrapers are not usually so I'm hoping this won't really be an issue.

It doesn't yet return you the resulting sqlite database (or use the one you
might have locally).

## Development

After checking out the repo, run `bundle install` to install dependencies.
Then run the tests with

    bundle exec rspec

## Contributing

Contributions are welcome! Please see the
[OpenAustralia Foundation contributing guide](https://github.com/openaustralia/.github/blob/main/.github/CONTRIBUTING.md)
for how we work: GitHub Flow, draft pull requests, signed-off commits (DCO)
and our contributor licence agreement.

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -s -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new pull request

## License

The gem is available as open source under the terms of the
[MIT License](LICENSE.txt).
