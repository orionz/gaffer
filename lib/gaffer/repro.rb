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
      unless root_dir.exists?
        raise "Dir #{root_dir} exists - cannot init" unless @force
        root_dir.destroy
      end
      create_dirs
      conf_dir["options"].write options
      conf_dir["distributions"].write distributions
      write_version 1
    end

    def packages
      index_dir["*"].map { |s| s.name }.sort
    end

    def create_dirs
      repo_dir.create
      index_dir.create
      subdirs.each do |dir|
        repo_dir["#{dir}/"].create
      end
    end

    def include(file)
      f = Rush[File.expand_path(file)]
      bump_version
      raise "File already in index" if index_dir[f.name].exists?
      f.copy_to index_dir
      bucket_put "index/#{f.name}"
      includedeb f
      f.destroy
      puts "* #{f.name} -> index/#{f.name}"
    end

    def rebuild
      repo_dir["*"].reject { |dir| dir.name == "conf" }.each { |dir| dir.destroy }
      create_dirs
      index_dir["*"].each do |file|
        includedeb file
      end
    end

    def includedeb(file)
      repo_dir.bash "reprepro includedeb #{@codename} #{file}"
    end

    def ready!
      raise "No repo.  Use 'gaffer pull' to download a repo from S3 or 'gaffer initrepo' to make a new one" unless File.include? "#{@root}/ubuntu/conf/distributions"
    end

    def push
      raise "Remote version #{remote_version} is higher than local #{local_version}.  Use --force to override" if (remote_version > local_version && !@force)
      puts "Version: #{local_version}"
      delete_remote
      write_remote
      touch
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
      touch
    end

    def url
      "deb http://#{@bucket}.s3.amazonaws.com/ubuntu/ #{@codename} #{@components}"
    end

    private

    def subdirs
      %w(conf dists incoming indices logs pool project tmp)
    end

    def options
      d = []
      d << "ask-passphrase"
      d << "basedir ."
      d.join("\n") + "\n"
    end

    def distributions
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
      repo_dir.bash cmd
    end

    def s3
      raise "Need aws key and secret to use s3" if @aws_key.nil? or @aws_secret.nil?
      @s3 ||= RightAws::S3.new(@aws_key, @aws_secret, :logger => Logger.new(nil))
    end

    def remote
      bucket.keys.map { |k| k.to_s }
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
        puts " * local write #{file}"
        root_dir[file].parent.create
        root_dir[file].write bucket.get(file)
      end
    end

    def write_remote
      local.each do |file|
        next if root_dir[file].dir?
        new = last_accessed <= root_dir[file].last_accessed
        next unless new
        puts "* remote write #{file}"
        bucket_put file
      end
    end

    def bucket_put(file)
      bucket.put file, root_dir[file].read, {}, remote_perm(file)
    end

    def remote_perm(file)
      if file =~ /^index|^ubuntu.db|^ubuntu.conf/
        'private'
      else
        'public-read'
      end
    end

    def bucket
        raise "bucket not set" unless @bucket
        s3.bucket(@bucket, true)
    end

    def local_version
      conf_dir["version"].read.to_i rescue 0
    end

    def remote_version
      bucket.get("ubuntu/conf/version").to_i rescue 0
    end

    def bump_version
      write_version(local_version + 1)
    end

    def root_dir
      Rush["#{@root}/"]
    end

    def index_dir
      root_dir["index/"]
    end

    def repo_dir
      root_dir["ubuntu/"]
    end

    def conf_dir
      repo_dir["conf/"]
    end

    def last_accessed
      Time.at(conf_dir["last_accessed"].read.to_i) rescue Time.at(0)
    end

    def touch
      conf_dir["last_accessed"].write Time.now.to_i
    end

    def write_version(version)
      conf_dir["version"].write version.to_s
    end
  end
end
