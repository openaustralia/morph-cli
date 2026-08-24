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
    option :skip_data, default: false, type: :boolean,
                       desc: "Don't upload the local data.sqlite database with the scraper"

    def execute
      env_config = load_env_config

      with_working_api_key(env_config) do
        MorphCLI.execute(options[:directory], options[:dev], env_config, skip_data: options[:skip_data])
      end
    end

    desc 'download [SCRAPER]', 'download the sqlite database of a scraper from morph'
    option :directory, default: Dir.getwd

    def download(scraper = nil)
      env_config = load_env_config

      scraper ||= MorphCLI.scraper_name(options[:directory])
      if scraper.nil?
        warn "Can't work out the scraper name from the git remote. Give it explicitly with: morph download OWNER/SCRAPER"
        exit(1)
      end

      with_working_api_key(env_config) do
        MorphCLI.download(options[:directory], env_config, scraper)
      rescue Faraday::ResourceNotFound
        warn "Can't find a database for #{scraper} on #{env_config[:base_url]}. Has the scraper run successfully?"
        exit(1)
      end
    end

    desc 'version', 'Show Morph version number and quit'
    def version
      puts "Morph CLI #{MorphCLI::VERSION}"
      exit
    end

    no_commands do
      def load_env_config
        @config = MorphCLI.load_config
        env_config = if options[:dev]
                       @config[:development]
                     else
                       @config[:production]
                     end

        ask_and_save_api_key(env_config) if env_config[:api_key].nil?
        env_config
      end

      # Runs the block, prompting for a new API key and retrying if the server
      # rejects the current one, and turning other request failures into
      # friendly errors
      def with_working_api_key(env_config)
        yield
      rescue Faraday::UnauthorizedError
        puts "Your key isn't working. Let's try again."
        ask_and_save_api_key(env_config)
        retry
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

      def ask_and_save_api_key(env_config)
        env_config[:api_key] = ask("What is your key? (Go to #{env_config[:base_url]}/settings)")
        MorphCLI.save_config(@config)
      end
    end
  end
end
