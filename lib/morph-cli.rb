require "morph-cli/version"

module MorphCLI
  def self.execute(directory, development, env_config)
    puts "Uploading and running..."
    file = MorphCLI.create_tar(directory, MorphCLI.all_paths(directory))
    block = Proc.new do |http_response|
      http_response.read_body do |line|
        unless line.empty?
          a = JSON.parse(line)
          if a["stream"] == "stdout"
            s = $stdout
          elsif a["stream"] == "stderr"
            s = $stderr
          else
            raise "Unknown stream"
          end
          s.puts a["text"]
        end
      end
    end
    result = RestClient::Request.execute(:method => :post, :url => "#{env_config[:base_url]}/run",
      :payload => {:api_key => env_config[:api_key], :code => file}, :block_response => block)
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
