require "morph-cli/version"
require 'yaml'
require 'find'
require 'json'
require 'open3'
require 'pathname'
require 'tempfile'
require 'fileutils'
require 'filesize'
require 'zlib'
require 'faraday'
require 'faraday/multipart'
require 'minitar'

module MorphCLI
  def self.execute(directory, _development, env_config, skip_data: false)
    all_paths = MorphCLI.all_paths(directory)

    unless all_paths.find { |file| /scraper\.[\S]+$/ =~ file }
      warn "Can't find scraper to upload. Expected to find a file called scraper.rb, scraper.php, scraper.py, scraper.pl, scraper.js, etc to upload"
      exit(1)
    end

    database_path = MorphCLI.database_path(directory)
    all_paths.delete(database_path)
    database_path = nil if skip_data

    size = MorphCLI.get_dir_size(directory, all_paths + [database_path].compact)
    puts "Uploading #{size}#{" (including #{database_path})" if database_path}..."

    file = MorphCLI.create_tar(directory, all_paths)

    scraper_output = run(file, env_config, directory, database_path)

    puts "Scraper didn't output anything, but it ran successfully." unless scraper_output
  end

  # Uploads the code to the server, streams the run output to the local
  # stdout/stderr and returns whether the scraper itself wrote anything
  # to stdout or stderr
  def self.run(file, env_config, directory, database_path)
    connection = Faraday.new(url: env_config[:base_url]) do |f|
      f.request :multipart
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end

    buffer = +""
    scraper_output = false
    connection.post("/run") do |req|
      body = {
        api_key: env_config[:api_key],
        code: Faraday::Multipart::FilePart.new(file, "application/gzip")
      }
      if database_path
        body[:database] = Faraday::Multipart::FilePart.new(
          File.join(directory, database_path),
          "application/octet-stream",
          database_path
        )
      end
      req.body = body
      # 10 minutes should be "enough for everyone", right?
      # Setting :timeout to nil in the config will disable the timeout
      # entirely. The Faraday default is 60 seconds.
      req.options.timeout = env_config.fetch(:timeout, 600)
      req.options.on_data = proc do |chunk, _overall_received_bytes, env|
        next unless env.status == 200

        before, match, after = chunk.rpartition("\n")
        buffer << before << match
        buffer.split("\n").each do |l|
          stream = log(l)
          scraper_output = true if %w[stdout stderr].include?(stream)
        end
        buffer = after
      end
    end
    scraper_output
  end

  def self.download(directory, env_config, scraper)
    connection = Faraday.new(url: env_config[:base_url]) do |f|
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end

    # Download to a tempfile in the same directory first so a failed download
    # doesn't clobber an existing database
    tempfile = Tempfile.new(["morph", ".sqlite"], directory)
    tempfile.binmode

    begin
      connection.get("/#{scraper}/data.sqlite") do |req|
        req.params[:key] = env_config[:api_key]
        req.options.timeout = env_config.fetch(:timeout, 600)
        req.options.on_data = proc do |chunk, _overall_received_bytes, env|
          tempfile.write(chunk) if env.status == 200
        end
      end

      tempfile.close
      File.rename(tempfile.path, File.join(directory, "data.sqlite"))
    ensure
      tempfile.close unless tempfile.closed?
      FileUtils.rm_f(tempfile.path)
    end

    size = Filesize.from("#{File.size(File.join(directory, 'data.sqlite'))} B").pretty
    puts "Saved #{size} to data.sqlite"
  end

  # The name of the scraper on morph (owner/name), worked out from the git
  # remote of the given directory. Returns nil if it can't be worked out.
  def self.scraper_name(directory)
    url, _stderr, status = Open3.capture3("git", "-C", directory, "config", "--get", "remote.origin.url")
    return nil unless status.success?

    url.strip[%r{([^/:]+/[^/:]+?)(?:\.git)?\z}, 1]
  end

  # Writes the line to the local stdout/stderr and returns the name of the
  # stream it came from
  def self.log(line)
    return if line.empty?

    a = JSON.parse(line)
    s = case a["stream"]
        when "stdout", "internalout"
          $stdout
        when "stderr"
          $stderr
        else
          raise "Unknown stream"
        end

    s.puts a["text"]
    a["stream"]
  end

  def self.config_path
    File.join(Dir.home, ".morph")
  end

  def self.save_config(config)
    File.write(config_path, config.to_yaml)
    File.chmod(0o600, config_path)
  end

  DEFAULT_CONFIG = {
    development: {
      base_url: "http://127.0.0.1:3000"
    },
    production:  {
      base_url: "https://morph.io"
    }
  }

  def self.load_config
    if File.exist?(config_path)
      YAML.safe_load_file(config_path, permitted_classes: [Symbol])
    else
      DEFAULT_CONFIG
    end
  end

  def self.in_directory(directory)
    cwd = FileUtils.pwd
    FileUtils.cd(directory)
    yield
  ensure
    FileUtils.cd(cwd)
  end

  # Packs the given paths (relative to directory) into a gzip-compressed tar
  # file and returns an open, rewound file handle ready for upload.
  def self.create_tar(directory, paths)
    tempfile = Tempfile.new(["morph", ".tar.gz"])
    tempfile.binmode

    in_directory(directory) do
      gzip = Zlib::GzipWriter.new(tempfile)
      output = Minitar::Output.new(gzip)
      paths.each { |entry| Minitar.pack_file(entry, output) }
    ensure
      # Closing the tar writer writes the tar trailer; finishing (not
      # closing) the gzip stream writes the gzip trailer, leaving the
      # underlying tempfile handle open for reading.
      output&.tar&.close
      gzip&.finish
    end

    tempfile.flush
    tempfile.rewind
    tempfile
  end

  def self.get_dir_size(directory, paths)
    size = 0
    in_directory(directory) do
      paths.each { |entry| size += File.size(entry) }
    end
    Filesize.from("#{size} B").pretty
  end

  # Relative paths to all the files in the given directory (recursive)
  # (except for anything below a directory starting with ".")
  def self.all_paths(directory)
    result = []
    Find.find(directory) do |path|
      if FileTest.directory?(path)
        Find.prune if File.basename(path)[0] == '.'
      else
        result << Pathname.new(path).relative_path_from(Pathname.new(directory)).to_s
      end
    end
    result
  end

  # Relative path of database file (if it exists)
  def self.database_path(directory)
    path = "data.sqlite"
    path if File.exist?(File.join(directory, path))
  end
end
