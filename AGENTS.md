# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, GitHub Copilot,
and others) when working with code in this repository. `CLAUDE.md` and
`.github/copilot-instructions.md` point here so the guidance lives in one place.

## What this gem is

`morph-cli` gives the `morph` command, which tars up the scraper in the current
directory, uploads it to a morph.io server, runs it there and streams the
output back to the terminal. The scraper never runs locally, which is the whole
point: developers get the morph.io scraper environment without installing it.

The audience is developers, so error messages and documentation here can assume
command-line familiarity.

## Layout

- `lib/morph-cli.rb` is the substance: finding the files, building the tar,
  posting it, and decoding the streamed response.
- `lib/morph-cli/cli.rb` is a thin Thor wrapper handling options, the API key
  prompt and turning Faraday exceptions into messages worth reading.
- `bin/morph` runs `execute` when given no arguments, so bare `morph` and
  `morph execute` are the same thing.

## Things that will catch you out

- **`~/.morph` holds a live API key.** It is YAML with separate
  `:development` and `:production` sections, written with mode 0600 and read
  back with `YAML.safe_load_file(..., permitted_classes: [Symbol])`. Never echo
  its contents, paste them into an issue, or use a real key in a spec or
  fixture. Use an obvious placeholder.
- **The upload includes every file in the directory** that isn't under a
  directory starting with `.`, so `.git` is skipped but anything else the
  person happens to have sitting there is not, including `data.sqlite`. Bear
  that in mind before changing `all_paths`.
- **The server streams newline-delimited JSON, not plain text.** Each line has
  a `stream` (`stdout`, `internalout` or `stderr`) and `text`, and `log` raises
  on any other stream value. Partial chunks are buffered on the newline, so
  changes there need to keep handling a chunk that splits a line.
- `create_tar` deliberately returns an open, rewound tempfile: it closes the
  tar writer to flush the trailer but leaves the underlying handle usable for
  the upload. The comments in that method say so; keep them true if you touch
  it.
- The default request timeout is 600 seconds, overridable per environment with
  `:timeout` in the config. `--dev` switches the whole thing to
  `http://127.0.0.1:3000` for people working on morph.io itself.
- `scraper.rb` in the repository root is a leftover sample morph.io scraper
  for a NSW council. It is tracked, but it is not gem code, nothing in `lib/`
  loads it, and it is neither linted nor tested. It is there so you can run
  `morph` against this directory by hand. Don't treat it as an example of the
  house style.

## Commands

    bundle exec rspec
    bundle exec rubocop
    bundle exec bundler-audit check --update
    bundle exec rake build

Those are the four CI jobs; the test job runs on Ruby 3.2, 3.3 and 3.4 and the
rest on 3.2. `.ruby-version` pins 3.2.2 locally.

**`bundle exec rake` on its own fails here** with "Don't know how to build task
'default'". The Rakefile is nothing but `require "bundler/gem_tasks"`, so there
is no default task and no `rake spec`. Run `rspec` directly.

`spec/spec_helper.rb` sets SimpleCov `minimum_coverage 90`, so the suite fails
on a coverage regression even when every example passes. It also sets
`disable_monkey_patching!`, so use `RSpec.describe` and the `expect` syntax,
and it loads `webmock/rspec` so specs don't reach the network.

`.rubocop.yml` inherits `.rubocop_todo.yml`, which is an existing backlog of
accepted offences. Fix them or leave them, but don't regenerate that file
wholesale as part of an unrelated change.

`Gemfile.lock` is gitignored and untracked. `bundle install` changes it
locally, which is expected. Never force-add it.

## Releasing

Don't run `bundle exec rake release`. It exists only because of
`bundler/gem_tasks` and would tag and publish from your machine. Releases are
automated: a version bump in `lib/morph-cli/version.rb` merged to `main`
publishes the gem through RubyGems trusted publishing in the `rubygems`
environment. Follow the README's "Releasing a new version" section.

## Org-level guidance

Workflow, branch naming, commit sign-off, AI disclosure and review conventions
are org-wide and deliberately not restated here. Fetch them when you need them:

    gh api repos/openaustralia/.github/contents/.github/CONTRIBUTING.md -H "Accept: application/vnd.github.raw"
    gh api repos/openaustralia/.github/contents/AGENTS.md -H "Accept: application/vnd.github.raw"

The README's Contributing section points people at the same guide. This
repository has no overrides of it. If one is ever agreed, record it here with
the reason, so the difference reads as a decision rather than drift.
