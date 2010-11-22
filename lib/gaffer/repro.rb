module Gaffer
  class Repro

    def initialize(root, options = {})
      @root       = root
      @maintainer = options[:maintainer]
      @email      = options[:email]
      @key        = options[:key]
      @force      = options[:force]
      @codename   = options[:codename]
      @components = options[:components]
      @bucket     = options[:bucket]
      @aws_key    = options[:aws_key]
      @aws_secret = options[:aws_secret]
    end

    def init
      raise "Dir #{@root} not empty - cannot init" unless Dir[@root].empty?
      create_dirs
      write_file "ubuntu/conf/options", options
      write_file "ubuntu/conf/distributions", distributes
      write_version 1
    end

    def create_dirs
      repo_dirs.each do |dir|
        if not File.exists?("#{@root}/ubuntu/#{dir}")
          puts "* mkdir -p #{@root}/ubuntu/#{dir}"
          FileUtils.mkdir_p "#{@root}/ubuntu/#{dir}"
        end
      end
    end

    def include(file)
      bump_version
      run "reprepro includedeb #{@codename} #{File.expand_path(file)}"
    end

    def push
      raise "Remote version #{remote_version} is higher than local #{local_version}.  Use --force to override" if (remote_version > local_version && !@force)
      puts "Version: #{local_version}"
      delete_remote
      write_remote
      puts " [apt source]"
      puts url
      puts ""
    end

    def pull
      raise "Local version #{local_version} is higher than local #{remote_version}.  Use --force to override" if (remote_version < local_version && !@force)
      create_dirs
      puts "Version: #{remote_version}"
      delete_local
      write_local
    end

    def url
      "deb http://#{@bucket}.s3.amazonaws.com/ubuntu/ #{@codename} #{@components}"
    end

    private

    def repo_dirs
      %w(conf dists incoming indices logs pool project tmp)
    end

    def write_file(path, data)
      FileUtils.mkdir_p File.dirname("#{@root}/#{path}")
      File.open("#{@root}/#{path}","w") do |f|
        f.write(data)
      end
    end

    def options
      d = []
      d << "ask-passphrase"
      d << "basedir ."
      d.join("\n") + "\n"
    end

    def distributes
      d = []
      d << "Origin: #{@maintainer}"
      d << "Label: #{@maintainer} Deploy Repo"
      d << "Codename: #{@codename}"
      d << "Architectures: i386 amd64 source"
      d << "Components: #{@components}"
      d << "Description: Deploy repo for #{@maintainer}"
      d << "SignWith: #{@key}" if @key
      d.join("\n") + "\n"
    end

    def run(cmd)
      Dir.chdir("#{@root}/ubuntu") do
        puts "DEBUG: #{cmd}"
        system(cmd) || (raise "Commmand failed: #{cmd}")
      end
    end

    def s3
      raise "Need aws key and secret to use s3" if @aws_key.nil? or @aws_secret.nil?
      @s3 ||= RightAws::S3.new(@aws_key, @aws_secret, :logger => Logger.new(nil))
    end

    def remote
      bucket.keys('prefix' => 'ubuntu').map { |k| k.to_s }
    end

    def local
      Dir.chdir(@root) do
         Dir["**/*"].reject { |f| File.directory?(f) }
      end
    end

    def delete_local
      (local - remote).each do |file|
        puts "* local delete #{file}"
        File.delete("#{@root}/#{file}")
      end
    end

    def delete_remote
      (remote - local).each do |file|
        puts "* remote delete #{file}"
        bucket.delete(file)
      end
    end

    def write_local
      remote.each do |file|
        puts "* local write #{file}"
        write_file(file, bucket.get(file))
      end
    end

    def write_remote
      local.each do |file|
        next if File.directory?("#{@root}/#{file}")
        puts "* remote write #{file}"
        bucket.put("#{file}", File.open("#{@root}/#{file}"), {}, file =~ /^ubuntu\/(db|conf)\// ? 'private' : 'public-read')
      end
    end

    def bucket
        raise "bucket not set" unless @bucket
        s3.bucket(@bucket, true)
    end

    def local_version
      File.read("#{@root}/ubuntu/conf/version").to_i rescue 0
    end

    def remote_version
      bucket.get("ubuntu/conf/version").to_i rescue 0
    end

    def bump_version
      write_version(local_version + 1)
    end

    def write_version(version)
      write_file "ubuntu/conf/version", version.to_s
    end
  end
end
