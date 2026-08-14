# frozen_string_literal: true

require 'thor'
require 'morph-cli'

module MorphCLI
  # Thor command line interface for running Morph scrapers
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    class_option :dev, default: false, type: :boolean, desc: 'Run against development Morph (for morph developers)'

    desc '[execute]', 'execute morph scraper'
    option :directory, default: Dir.getwd

    def execute
      config = MorphCLI.load_config
      env_config = if options[:dev]
                     config[:development]
                   else
                     config[:production]
                   end

      config = ask_and_save_api_key(env_config, config) if env_config[:api_key].nil?

      api_key_is_valid = false
      until api_key_is_valid
        begin
          MorphCLI.execute(options[:directory], options[:dev], env_config)
          api_key_is_valid = true
        rescue Faraday::UnauthorizedError
          puts "Your key isn't working. Let's try again."
          config = ask_and_save_api_key(env_config, config)
        rescue Faraday::ConnectionFailed => e
          warn "Morph doesn't look to be running at #{env_config[:base_url]} (#{e})"
          exit(1)
        rescue Faraday::ServerError => e
          warn "Uh oh. Something has gone wrong on the Morph server at #{env_config[:base_url]} (#{e})"
          exit(1)
        rescue Faraday::Error => e
          warn "Request to #{env_config[:base_url]} failed (#{e})"
          exit(1)
        end
      end
    end

    desc 'version', 'Show Morph version number and quit'
    def version
      puts "Morph CLI #{MorphCLI::VERSION}"
      exit
    end

    no_commands do
      def ask_and_save_api_key(env_config, config)
        env_config[:api_key] = ask("What is your key? (Go to #{env_config[:base_url]}/settings)")
        MorphCLI.save_config(config)
        config
      end
    end
  end
end
