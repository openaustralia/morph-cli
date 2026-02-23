require "fileutils"
require "tmpdir"

require "spec_helper"

RSpec.describe MorphCLI do
  describe "::VERSION" do
    it "is defined" do
      expect(MorphCLI::VERSION).not_to be_nil
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
