# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MorphCLI::CLI do
  describe 'version' do
    it 'prints the version and exits' do
      expect do
        expect { described_class.start(['version']) }.to raise_error(SystemExit)
      end.to output("Morph CLI #{MorphCLI::VERSION}\n").to_stdout
    end
  end

  describe 'execute' do
    let(:config) do
      {
        development: { base_url: 'http://127.0.0.1:3000', api_key: 'dev-key' },
        production: { base_url: 'https://morph.io', api_key: 'prod-key' }
      }
    end

    before do
      allow(MorphCLI).to receive(:load_config).and_return(config)
      allow(MorphCLI).to receive(:save_config)
    end

    it 'runs the scraper with the production config by default' do
      allow(MorphCLI).to receive(:execute)

      described_class.start(['execute', '--directory', '/somewhere'])

      expect(MorphCLI).to have_received(:execute)
        .with('/somewhere', false, config[:production], skip_data: false)
    end

    it 'leaves the database out when --skip-data is given' do
      allow(MorphCLI).to receive(:execute)

      described_class.start(['execute', '--skip-data'])

      expect(MorphCLI).to have_received(:execute)
        .with(anything, false, config[:production], skip_data: true)
    end

    it 'runs the scraper with the development config when --dev is given' do
      allow(MorphCLI).to receive(:execute)

      described_class.start(['execute', '--dev'])

      expect(MorphCLI).to have_received(:execute)
        .with(anything, true, config[:development], skip_data: false)
    end

    it 'asks for an API key and saves the config when none is set' do
      config[:production].delete(:api_key)
      allow(MorphCLI).to receive(:execute)
      allow(Thor::LineEditor).to receive(:readline).and_return('shiny-new-key')

      described_class.start(['execute'])

      expect(Thor::LineEditor).to have_received(:readline)
        .with(a_string_matching(/What is your key\?/), anything)
      expect(config[:production][:api_key]).to eq('shiny-new-key')
      expect(MorphCLI).to have_received(:save_config).with(config)
      expect(MorphCLI).to have_received(:execute)
        .with(anything, false, config[:production], skip_data: false)
    end

    it 'asks for a new API key and retries when the server rejects it' do
      attempts = 0
      allow(MorphCLI).to receive(:execute) do
        attempts += 1
        raise Faraday::UnauthorizedError, '401' if attempts == 1
      end
      allow(Thor::LineEditor).to receive(:readline).and_return('fresh-key')

      expect { described_class.start(['execute']) }
        .to output(/Your key isn't working\. Let's try again\./).to_stdout

      expect(attempts).to eq(2)
      expect(config[:production][:api_key]).to eq('fresh-key')
      expect(MorphCLI).to have_received(:save_config).with(config)
    end

    it 'exits with an error when morph is not reachable' do
      allow(MorphCLI).to receive(:execute)
        .and_raise(Faraday::ConnectionFailed, 'connection refused')

      expect do
        expect { described_class.start(['execute']) }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end.to output(%r{Morph doesn't look to be running at https://morph\.io}).to_stderr
    end

    it 'exits with an error when the morph server fails' do
      allow(MorphCLI).to receive(:execute)
        .and_raise(Faraday::ServerError, '500')

      expect do
        expect { described_class.start(['execute']) }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end.to output(/Something has gone wrong on the Morph server/).to_stderr
    end

    it 'exits with an error on any other request failure' do
      allow(MorphCLI).to receive(:execute)
        .and_raise(Faraday::BadRequestError, '400')

      expect do
        expect { described_class.start(['execute']) }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end.to output(%r{Request to https://morph\.io failed}).to_stderr
    end
  end

  describe 'download' do
    let(:config) do
      {
        development: { base_url: 'http://127.0.0.1:3000', api_key: 'dev-key' },
        production: { base_url: 'https://morph.io', api_key: 'prod-key' }
      }
    end

    before do
      allow(MorphCLI).to receive(:load_config).and_return(config)
      allow(MorphCLI).to receive(:save_config)
    end

    it 'downloads the database of the given scraper with the production config' do
      allow(MorphCLI).to receive(:download)

      described_class.start(['download', 'openaustralia/scraper', '--directory', '/somewhere'])

      expect(MorphCLI).to have_received(:download)
        .with('/somewhere', config[:production], 'openaustralia/scraper')
    end

    it 'works out the scraper name from the git remote when none is given' do
      allow(MorphCLI).to receive(:download)
      allow(MorphCLI).to receive(:scraper_name).with('/somewhere').and_return('openaustralia/scraper')

      described_class.start(['download', '--directory', '/somewhere'])

      expect(MorphCLI).to have_received(:download)
        .with('/somewhere', config[:production], 'openaustralia/scraper')
    end

    it 'exits with an error when the scraper name cannot be worked out' do
      allow(MorphCLI).to receive(:scraper_name).and_return(nil)

      expect do
        expect { described_class.start(['download']) }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end.to output(/Can't work out the scraper name/).to_stderr
    end

    it 'uses the development config when --dev is given' do
      allow(MorphCLI).to receive(:download)

      described_class.start(['download', 'openaustralia/scraper', '--dev'])

      expect(MorphCLI).to have_received(:download)
        .with(anything, config[:development], 'openaustralia/scraper')
    end

    it 'asks for a new API key and retries when the server rejects it' do
      attempts = 0
      allow(MorphCLI).to receive(:download) do
        attempts += 1
        raise Faraday::UnauthorizedError, '401' if attempts == 1
      end
      allow(Thor::LineEditor).to receive(:readline).and_return('fresh-key')

      expect { described_class.start(['download', 'openaustralia/scraper']) }
        .to output(/Your key isn't working\. Let's try again\./).to_stdout

      expect(attempts).to eq(2)
      expect(config[:production][:api_key]).to eq('fresh-key')
      expect(MorphCLI).to have_received(:save_config).with(config)
    end

    it 'exits with an error when the scraper has no downloadable database' do
      allow(MorphCLI).to receive(:download)
        .and_raise(Faraday::ResourceNotFound, '404')

      expect do
        expect { described_class.start(['download', 'openaustralia/scraper']) }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end.to output(%r{Can't find a database for openaustralia/scraper on https://morph\.io}).to_stderr
    end

    it 'exits with an error when morph is not reachable' do
      allow(MorphCLI).to receive(:download)
        .and_raise(Faraday::ConnectionFailed, 'connection refused')

      expect do
        expect { described_class.start(['download', 'openaustralia/scraper']) }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end.to output(%r{Morph doesn't look to be running at https://morph\.io}).to_stderr
    end
  end
end
