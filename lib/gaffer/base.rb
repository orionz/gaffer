module Gaffer
  class Base
    attr_accessor :dir, :git, :project, :readme, :depends, :version, :prefix, :maintainer, :build_name

    def initialize(options)
      @force = options[:force]
    end

    def build(dir)
      @dir     = dir
      @git     = Git::open(dir)

      @project = File::basename(File::dirname(@git.repo.path))
      @maintainer = "#{@git.config["user.name"]} <#{@git.config["user.email"]}>"
      @prefix  = "opt/#{@project}"

      @readme  = File::read("#{dir}/README") rescue "no README file"
      @depends = File::read("#{dir}/DEPENDS").chomp rescue "libc6 (>= 2.10)"
      @version = File::read("#{dir}/VERSION").chomp

      raise "Bad version #{@version}" unless @version =~ /^\d+[.]\d+[.]\d+$/

      @build_name = "#{@version}-#{next_build_id}"

      puts "======> #{@version.inspect}"

      @git.add_tag(@build_name)
      ## check version - tag repo

      Gaffer::Deb::new(self, project, depends).build
#      Gaffer::Deb::new(self, "#{project}-dev", "#{project} (>= #{@version})").build
    end

    def git_build_id
      @git.tags.map { |a| a.name =~ /^#{@version}-(.+)/; $1.to_i }.sort.last.to_i
    end

    def repro_build_id
      x1 = repro.packages
      puts "DEBUG: #{x1.inspect}"
      x2 = x1.map { |p| p =~ /^#{@project}_#{@version}-(\d+)_/; $1 }
      puts "DEBUG: #{x2.inspect}"
      x3 = x2.reject { |x| x.nil? }
      puts "DEBUG: #{x3.inspect}"
      x3.max.to_i
    end

    def next_build_id
      [git_build_id, repro_build_id].max + 1
    end

    def add(file)
      repro.include(file)
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
      options[:key]        ||= ENV['GAFFER_KEY']
      options[:key]        ||= options[:email]

      options[:codename]   ||= "maverick"
      options[:components] ||= "main"
      options[:force]      ||= !!@force

      Gaffer::Repro.new(repro_dir, options)
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
