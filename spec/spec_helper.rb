require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  skip "/spec/"
  minimum_coverage 90
end

require "webmock/rspec"

require "morph-cli"
require "morph-cli/cli"

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
