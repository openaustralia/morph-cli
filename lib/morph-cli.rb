require "morph-cli/version"

module MorphCLI
  def self.execute(directory, api_key, development)
    puts "Uploading and running..."
    file = MorphCLI.create_tar(directory, MorphCLI.all_paths(directory))
    result = RestClient.post("#{MorphCLI.base_url(development)}/run", :api_key => api_key, :code => file)
    # Interpret each line separately as json
    result.split("\n").each do |line|
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
  
  def self.base_url(development)
    if development
      "http://127.0.0.1:3000"
    else
      "https://morph.io"
    end
  end

  def self.config_path
    File.join(Dir.home, ".morph")
  end

  def self.save_api_key(api_key)
    configuration = {api_key: api_key}
    File.open(config_path, "w") {|f| f.write configuration.to_yaml}
    File.chmod(0600, config_path)
  end

  def self.retrieve_api_key
    if File.exists?(config_path)
      YAML.load(File.read(config_path))[:api_key]
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
