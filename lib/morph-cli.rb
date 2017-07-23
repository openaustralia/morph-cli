require "morph-cli/version"
require 'yaml'
require 'find'
require 'filesize'

module MorphCLI
  def self.execute(directory, development, env_config)
    all_paths = MorphCLI.all_paths(directory)
    size = MorphCLI.get_dir_size(directory, all_paths)
    puts "Uploading #{size}..."

    file = MorphCLI.create_tar(directory, all_paths)
    buffer = ""
    block = Proc.new do |http_response|
      if http_response.code == "200"
        http_response.read_body do |line|
          before, match, after = line.rpartition("\n")
          buffer += before + match
          buffer.split("\n").each do |l|
            log(l)
          end
          buffer = after
        end
      elsif http_response.code == "401"
        raise RestClient::Unauthorized
      else
        puts http_response.body
        exit(1)
      end
    end
    if env_config.key?(:timeout)
      timeout = env_config[:timeout]
    else
      timeout = 600 # 10 minutes should be "enough for everyone", right?
                    # Setting to nil will disable the timeout entirely.
                    # Default is 60 seconds.
    end
    result = RestClient::Request.execute(:method => :post, :url => "#{env_config[:base_url]}/run",
      :payload => {:api_key => env_config[:api_key], :code => file}, :block_response => block,
      :timeout => timeout)
  end

  def self.log(line)
    unless line.empty?
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
  end

  def self.config_path
    File.join(Dir.home, ".morph")
  end

  def self.save_config(config)
    File.open(config_path, "w") {|f| f.write config.to_yaml}
    File.chmod(0600, config_path)
  end

  DEFAULT_CONFIG = {
    development: {
      base_url: "http://127.0.0.1:3000"
    },
    production: {
      base_url: "https://morph.io"
    }
  }

  def self.load_config
    if File.exists?(config_path)
      YAML.load(File.read(config_path))
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

  def self.create_tar(directory, paths)
    tempfile = File.new('/tmp/out', 'wb')

    in_directory(directory) do
      begin
        tar = Archive::Tar::Minitar::Output.new("/tmp/out")
        paths.each do |entry|
          Archive::Tar::Minitar.pack_file(entry, tar)
        end
      ensure
        tar.close
      end
    end
    File.new('/tmp/out', 'r')
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
        if File.basename(path)[0] == ?.
          Find.prune
        end
      else
        result << Pathname.new(path).relative_path_from(Pathname.new(directory)).to_s
      end
    end
    result
  end

  # Relative path of database file (if it exists)
  def self.database_path(directory)
    path = "data.sqlite"
    path if File.exists?(File.join(directory, path))
  end
end
