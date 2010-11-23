module Gaffer
  class Base
    attr_accessor :dir, :git, :project, :readme, :depends, :version, :prefix, :maintainer, :build_name

    def initialize(options)
      @force = options[:force]
    end

    def build(dir)
      @git     = Git::open(dir)

      @project = File::basename(File::dirname(@git.repo.path))
      @maintainer = "#{@git.config["user.name"]} <#{@git.config["user.email"]}>"
      @prefix  = "opt/#{@project}"

      @readme  = File::read("#{dir}/README") rescue "no README file"
      @depends = File::read("#{dir}/DEPENDS").chomp rescue "libc6 (>= 2.10)"
      @version = File::read("#{dir}/VERSION").chomp

      raise "Bad version #{@version}" unless @version =~ /^\d+[.]\d+[.]\d+$/

      build_id = @git.tags.map { |a| a.name =~ /^#{@version}-(.+)/; $1.to_i }.sort.last.to_i + 1
      @build_name = "#{@version}-#{build_id}"

      puts "======> #{@version.inspect}"

      @git.add_tag(@build_name)
      ## check version - tag repo

      Gaffer::Deb::new(self, project, depends).build
#      Gaffer::Deb::new(self, "#{project}-dev", "#{project} (>= #{@version})").build
    end

    def add(file)
      file = File.expand_path(file)
      Dir.chdir(repro_dir) do
        repro.include(file)
      end
    end

    def push_changed(dir, &blk)
      # I can optimze later
      start = Time::now
      Dir.chdir(dir) do
        blk.call
        Dir["**/*"].select { |file| File::stat(file).mtime >= start }.each do |file|
          puts "PUSHING: #{f}"
        end
      end
    end
 
    def repro
      options = {}

      options[:aws_key]    ||= ENV['AWS_ACCESS_KEY_ID']
      options[:aws_secret] ||= ENV['AWS_SECRET_ACCESS_KEY']
      options[:bucket]     ||= ENV['GAFFER_BUCKET']
      options[:email]      ||= ENV['GAFFER_EMAIL']
      options[:maintainer] ||= ENV['GAFFER_MAINTAINER']
      options[:key]        ||= options[:email]

      options[:codename]   ||= "maverick"
      options[:components] ||= "main"
      options[:force]      ||= !!@force

      dir = repro_dir

      puts "Repo: #{dir}"

      Gaffer::Repro.new(dir, options)
    end

    def repro_dir
      if ENV['HOME']
        "#{ENV['HOME']}/.gaffer/repo"
      else
        "/var/lib/gaffer/repo"
      end
    end

    def repro_ready?
      File.exists? "#{repro_dir}/ubuntu/conf/distributions"
    end
  end
end
