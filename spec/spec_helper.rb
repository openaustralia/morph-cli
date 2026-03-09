require "morph-cli"

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
