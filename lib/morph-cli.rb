require "morph-cli/version"
require 'yaml'
require 'find'
require 'json'
require 'pathname'
require 'tempfile'
require 'fileutils'
require 'filesize'
require 'faraday'
require 'faraday/multipart'
require 'minitar'

module MorphCLI
  def self.execute(directory, _development, env_config)
    all_paths = MorphCLI.all_paths(directory)

    unless all_paths.find { |file| /scraper\.[\S]+$/ =~ file }
      warn "Can't find scraper to upload. Expected to find a file called scraper.rb, scraper.php, scraper.py, scraper.pl, scraper.js, etc to upload"
      exit(1)
    end

    size = MorphCLI.get_dir_size(directory, all_paths)
    puts "Uploading #{size}..."

    file = MorphCLI.create_tar(directory, all_paths)

    timeout = if env_config.key?(:timeout)
                env_config[:timeout]
              else
                600 # 10 minutes should be "enough for everyone", right?
                # Setting to nil will disable the timeout entirely.
                # Default is 60 seconds.
              end

    connection = Faraday.new(url: env_config[:base_url]) do |f|
      f.request :multipart
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end

    buffer = +""
    connection.post("/run") do |req|
      req.body = {
        api_key: env_config[:api_key],
        code: Faraday::Multipart::FilePart.new(file, "application/octet-stream")
      }
      req.options.timeout = timeout
      req.options.on_data = proc do |chunk, _overall_received_bytes, env|
        next unless env.status == 200

        before, match, after = chunk.rpartition("\n")
        buffer << before << match
        buffer.split("\n").each { |l| log(l) }
        buffer = after
      end
    end
  end

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

  # Packs the given paths (relative to directory) into a tar file and returns
  # an open, rewound file handle ready for upload.
  def self.create_tar(directory, paths)
    tempfile = Tempfile.new(["morph", ".tar"])
    tempfile.binmode

    in_directory(directory) do
      output = Minitar::Output.new(tempfile)
      paths.each do |entry|
        Minitar.pack_file(entry, output)
      end
    ensure
      # Writes the tar trailer and flushes without closing the underlying
      # tempfile, so the returned handle stays open for reading.
      output&.tar&.close
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
