module Gaffer
  class Base
    attr_accessor :dir, :git, :project, :readme, :depends, :version, :prefix, :maintainer, :build

    def initialize(options)
      @dir     = options[:dir] || Dir.pwd
      @git     = Git.open(@dir)
      @version = options[:version]
      @project = options[:project] || File.basename(File.dirname(@git.repo.path))
      @maintainer = "#{@git.config["user.name"]} <#{@git.config["user.email"]}>"
      @prefix  = options[:prefix] || "opt/#{@project}"

      @git.chdir do
        @readme = File.read("README") rescue "no README file"
        @depends = File.read("DEPENDS").chomp rescue "libc6 (>= 2.10)"
        @version ||= File.read("VERSION").chomp
      end

      puts "======> #{@version.inspect}"
      build_id = @git.tags.map { |a| a.name =~ /^#{@version}-(.+)/; $1.to_i }.sort.last.to_i + 1
      @build = "#{@version}-#{build_id}"

      raise "Bad version #{@version}" unless @version =~ /^\d+[.]\d+[.]\d+$/
    end

    def compile
      @git.add_tag(@build)
      ## check version - tag repo
      Gaffer::Deb.new(self, "all", project, depends).compile
      Gaffer::Deb.new(self, "all", "#{project}-dev", "#{project} (>= #{@version})").compile
    end
  end
end
