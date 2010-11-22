module Gaffer
  class Base
    attr_accessor :dir, :git, :project, :readme, :depends, :version, :prefix, :maintainer, :build

    def initialize
    end

    def pull
      ### grap repreppro pull code here
    end

    def compile(_dir)
      @git     = Git::open(_dir)

      @project = File::basename(File::dirname(@git.repo.path))
      @maintainer = "#{@git.config["user.name"]} <#{@git.config["user.email"]}>"
      @prefix  = "opt/#{@project}"

      @readme  = File::read("#{_dir}/README") rescue "no README file"
      @depends = File::read("#{_dir}/DEPENDS").chomp rescue "libc6 (>= 2.10)"
      @version = File::read("#{_dir}/VERSION").chomp

      raise "Bad version #{@version}" unless @version =~ /^\d+[.]\d+[.]\d+$/

      build_id = @git.tags.map { |a| a.name =~ /^#{@version}-(.+)/; $1.to_i }.sort.last.to_i + 1
      @build = "#{@version}-#{build_id}"

      puts "======> #{@version.inspect}"

      @git.add_tag(@build)
      ## check version - tag repo

      Gaffer::Deb::new(self, project, depends).compile
#      Gaffer::Deb::new(self, "#{project}-dev", "#{project} (>= #{@version})").compile
    end

    def upload(file)
      push do
        system "reprepro include #{file}"
      end
    end

    def push(&blk)
      start = Time::now
      blk.call
      changed_dir("/tmp", start).each { |f| push_file(f) }
    end
 
    def push_file(f)
    end

    def changed_since(_dir, time)
      Dir["#{_dir}/*/**"].select { |file| File::stat(file).mtime > time }
    end
  end
end
