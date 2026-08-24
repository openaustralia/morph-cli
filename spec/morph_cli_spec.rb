require "fileutils"
require "tmpdir"
require "stringio"
require "zlib"

require "spec_helper"

RSpec.describe MorphCLI do
  describe "::VERSION" do
    it "is defined" do
      expect(MorphCLI::VERSION).not_to be_nil
    end
  end

  describe ".execute" do
    let(:env_config) { { base_url: "https://morph.io", api_key: "secret-key" } }

    def with_scraper_directory
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "scraper.rb"), "puts 'hi'\n")
        yield dir
      end
    end

    # Extracts tar entry names from a multipart request body that contains
    # a gzip-compressed tar as one of its parts.
    def tar_entry_names(body)
      binary = body.b
      gzip_start = binary.index("\x1f\x8b".b)
      return [] unless gzip_start

      gzip_io = StringIO.new(binary[gzip_start..])
      names = []
      Zlib::GzipReader.wrap(gzip_io) do |gz|
        Minitar::Input.open(gz) { |tar| tar.each { |entry| names << entry.full_name } }
      end
      names
    rescue StandardError
      []
    end

    it "uploads the scraper and streams the run output to stdout" do
      stub_request(:post, "https://morph.io/run")
        .to_return(status: 200, body: %({"stream":"stdout","text":"hello from morph"}\n))

      with_scraper_directory do |dir|
        expect { described_class.execute(dir, false, env_config) }
          .to output(/\AUploading .*\nhello from morph\n\z/).to_stdout
      end
    end

    it "tells the user the run succeeded when the scraper produces no output" do
      stub_request(:post, "https://morph.io/run")
        .to_return(status: 200, body: %({"stream":"internalout","text":"Injecting configuration"}\n))

      with_scraper_directory do |dir|
        expect { described_class.execute(dir, false, env_config) }
          .to output(/Scraper didn't output anything, but it ran successfully\./).to_stdout
      end
    end

    it "doesn't add a message when the scraper writes to stdout" do
      stub_request(:post, "https://morph.io/run")
        .to_return(status: 200, body: %({"stream":"stdout","text":"hello from morph"}\n))

      with_scraper_directory do |dir|
        expect { described_class.execute(dir, false, env_config) }
          .not_to output(/ran successfully/).to_stdout
      end
    end

    it "doesn't add a message when the scraper writes to stderr" do
      stub_request(:post, "https://morph.io/run")
        .to_return(status: 200, body: %({"stream":"stderr","text":"oops"}\n))

      with_scraper_directory do |dir|
        expect do
          expect { described_class.execute(dir, false, env_config) }
            .not_to output(/ran successfully/).to_stdout
        end.to output("oops\n").to_stderr
      end
    end

    it "posts the API key and the gzipped code as multipart form data" do
      stub_request(:post, "https://morph.io/run").to_return(status: 200, body: "")

      with_scraper_directory do |dir|
        expect { described_class.execute(dir, false, env_config) }
          .to output(/Uploading/).to_stdout
      end

      expect(WebMock).to(have_requested(:post, "https://morph.io/run").with do |req|
        req.headers["Content-Type"].start_with?("multipart/form-data") &&
          req.body.include?("secret-key") &&
          req.body.b.include?("\x1f\x8b".b) # gzip magic bytes
      end)
    end

    it "uploads the local database and says so" do
      stub_request(:post, "https://morph.io/run").to_return(status: 200, body: "")

      with_scraper_directory do |dir|
        File.write(File.join(dir, "data.sqlite"), "sqlite data")

        expect { described_class.execute(dir, false, env_config) }
          .to output(/\AUploading 21\.00 B \(including data\.sqlite\)\.\.\.\n/).to_stdout
      end

      expect(WebMock).to(have_requested(:post, "https://morph.io/run").with do |req|
        # Sent as its own multipart field rather than packed into the tar
        req.body.include?("data.sqlite") &&
          !tar_entry_names(req.body).include?("data.sqlite")
      end)
    end

    it "leaves the database out of the upload when skip_data is true" do
      stub_request(:post, "https://morph.io/run").to_return(status: 200, body: "")

      with_scraper_directory do |dir|
        File.write(File.join(dir, "data.sqlite"), "sqlite data")

        expect { described_class.execute(dir, false, env_config, skip_data: true) }
          .to output(/\AUploading 10\.00 B\.\.\.\n/).to_stdout
      end

      expect(WebMock).to(have_requested(:post, "https://morph.io/run").with do |req|
        !req.body.include?("data.sqlite") &&
          !tar_entry_names(req.body).include?("data.sqlite")
      end)
    end

    it "raises Faraday::UnauthorizedError when the API key is rejected" do
      stub_request(:post, "https://morph.io/run").to_return(status: 401, body: "")

      with_scraper_directory do |dir|
        expect { described_class.execute(dir, false, env_config) }
          .to raise_error(Faraday::UnauthorizedError)
          .and output(/Uploading/).to_stdout
      end
    end

    it "exits with an error when there is no scraper to upload" do
      Dir.mktmpdir do |dir|
        expect do
          expect { described_class.execute(dir, false, env_config) }
            .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
        end.to output(/Can't find scraper to upload/).to_stderr
      end
    end
  end

  describe ".download" do
    let(:env_config) { { base_url: "https://morph.io", api_key: "secret-key" } }

    it "saves the scraper's database as data.sqlite and reports the size" do
      stub_request(:get, "https://morph.io/mlandauer/scraper-blue-mountains/data.sqlite")
        .with(query: { key: "secret-key" })
        .to_return(status: 200, body: "sqlite bytes")

      Dir.mktmpdir do |dir|
        expect { described_class.download(dir, env_config, "mlandauer/scraper-blue-mountains") }
          .to output("Saved 12.00 B to data.sqlite\n").to_stdout

        expect(File.read(File.join(dir, "data.sqlite"))).to eq("sqlite bytes")
      end
    end

    it "overwrites an existing database on a successful download" do
      stub_request(:get, "https://morph.io/mlandauer/scraper-blue-mountains/data.sqlite")
        .with(query: { key: "secret-key" })
        .to_return(status: 200, body: "new data")

      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "data.sqlite"), "old data")

        expect { described_class.download(dir, env_config, "mlandauer/scraper-blue-mountains") }
          .to output(/Saved/).to_stdout

        expect(File.read(File.join(dir, "data.sqlite"))).to eq("new data")
      end
    end

    it "leaves an existing database and no tempfile behind when the download fails" do
      stub_request(:get, "https://morph.io/mlandauer/scraper-blue-mountains/data.sqlite")
        .with(query: { key: "secret-key" })
        .to_return(status: 404, body: "")

      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "data.sqlite"), "old data")

        expect { described_class.download(dir, env_config, "mlandauer/scraper-blue-mountains") }
          .to raise_error(Faraday::ResourceNotFound)

        expect(File.read(File.join(dir, "data.sqlite"))).to eq("old data")
        expect(Dir.children(dir)).to contain_exactly("data.sqlite")
      end
    end
  end

  describe ".scraper_name" do
    def with_git_remote(url)
      Dir.mktmpdir do |dir|
        system("git", "init", "--quiet", dir, exception: true)
        system("git", "-C", dir, "remote", "add", "origin", url, exception: true)
        yield dir
      end
    end

    it "derives owner/name from an https git remote" do
      with_git_remote("https://github.com/openaustralia/morph-cli.git") do |dir|
        expect(described_class.scraper_name(dir)).to eq("openaustralia/morph-cli")
      end
    end

    it "derives owner/name from an ssh git remote" do
      with_git_remote("git@github.com:openaustralia/morph-cli.git") do |dir|
        expect(described_class.scraper_name(dir)).to eq("openaustralia/morph-cli")
      end
    end

    it "derives owner/name from a remote without a .git suffix" do
      with_git_remote("https://github.com/openaustralia/morph-cli") do |dir|
        expect(described_class.scraper_name(dir)).to eq("openaustralia/morph-cli")
      end
    end

    it "returns nil when the directory is not a git repository" do
      Dir.mktmpdir do |dir|
        expect(described_class.scraper_name(dir)).to be_nil
      end
    end

    it "returns nil when the repository has no origin remote" do
      Dir.mktmpdir do |dir|
        system("git", "init", "--quiet", dir, exception: true)

        expect(described_class.scraper_name(dir)).to be_nil
      end
    end
  end

  describe ".log" do
    it "writes stdout stream lines to stdout" do
      expect { described_class.log(%({"stream":"stdout","text":"out"})) }
        .to output("out\n").to_stdout
    end

    it "writes internalout stream lines to stdout" do
      expect { described_class.log(%({"stream":"internalout","text":"internal"})) }
        .to output("internal\n").to_stdout
    end

    it "writes stderr stream lines to stderr" do
      expect { described_class.log(%({"stream":"stderr","text":"err"})) }
        .to output("err\n").to_stderr
    end

    it "ignores empty lines" do
      expect { described_class.log("") }.not_to output.to_stdout
    end

    it "raises on an unknown stream" do
      expect { described_class.log(%({"stream":"mystery","text":"?"})) }
        .to raise_error(/Unknown stream/)
    end
  end

  describe ".save_config / .load_config" do
    let(:tmpdir) { Dir.mktmpdir }
    let(:config_file) { File.join(tmpdir, ".morph") }

    before do
      allow(described_class).to receive(:config_path).and_return(config_file)
    end

    after do
      FileUtils.remove_entry(tmpdir)
    end

    it "round-trips a symbol-keyed config" do
      config = { production: { api_key: "secret", base_url: "https://morph.io" } }
      described_class.save_config(config)

      expect(described_class.load_config).to eq(config)
    end

    it "writes the config file with 0600 permissions" do
      described_class.save_config({ production: { api_key: "secret" } })

      expect(File.stat(config_file).mode & 0o777).to eq(0o600)
    end

    it "returns the default config when no file exists" do
      expect(described_class.load_config).to eq(MorphCLI::DEFAULT_CONFIG)
    end
  end

  describe ".create_tar" do
    it "packs the given paths into a readable gzip-compressed tar" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "scraper.rb"), "puts 'hi'\n")
        FileUtils.mkdir_p(File.join(dir, "lib"))
        File.write(File.join(dir, "lib", "helper.rb"), "# helper\n")
        paths = described_class.all_paths(dir)

        tar = described_class.create_tar(dir, paths)

        names = []
        Zlib::GzipReader.open(tar.path) do |gzip|
          Minitar::Input.open(gzip) do |input|
            input.each { |entry| names << entry.full_name }
          end
        end
        expect(names).to contain_exactly("scraper.rb", "lib/helper.rb")
      end
    end

    it "compresses the tar" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "scraper.rb"), "a" * 100_000)

        tar = described_class.create_tar(dir, described_class.all_paths(dir))

        expect(File.size(tar.path)).to be < 100_000
      end
    end

    it "returns an open file handle ready for reading" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "scraper.rb"), "puts 'hi'\n")

        tar = described_class.create_tar(dir, described_class.all_paths(dir))

        expect(tar).not_to be_closed
        expect(tar.pos).to eq(0)
        expect(tar.read(2)).to eq("\x1f\x8b".b) # gzip magic bytes
      end
    end
  end

  describe ".get_dir_size" do
    it "returns a human readable size of the given paths" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "scraper.rb"), "a" * 10)

        size = described_class.get_dir_size(dir, described_class.all_paths(dir))

        expect(size).to eq("10.00 B")
      end
    end
  end

  describe ".in_directory" do
    it "runs the block in the given directory and restores the old one" do
      original = Dir.pwd
      Dir.mktmpdir do |dir|
        described_class.in_directory(dir) do
          expect(Dir.pwd).to eq(File.realpath(dir))
        end
        expect(Dir.pwd).to eq(original)
      end
    end

    it "restores the working directory when the block raises" do
      original = Dir.pwd
      Dir.mktmpdir do |dir|
        expect do
          described_class.in_directory(dir) { raise "boom" }
        end.to raise_error("boom")
        expect(Dir.pwd).to eq(original)
      end
    end
  end

  describe ".all_paths" do
    it "excludes files inside dot-directories" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "scraper.rb"), "puts 'hi'\n")
        FileUtils.mkdir_p(File.join(dir, ".git"))
        File.write(File.join(dir, ".git", "config"), "internal")

        paths = described_class.all_paths(dir)

        expect(paths).to include("scraper.rb")
        expect(paths).not_to include(".git/config")
      end
    end
  end

  describe ".database_path" do
    it "returns the database file path when present" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "data.sqlite"), "")

        expect(described_class.database_path(dir)).to eq("data.sqlite")
      end
    end

    it "returns nil when the database file is absent" do
      Dir.mktmpdir do |dir|
        expect(described_class.database_path(dir)).to be_nil
      end
    end
  end
end
