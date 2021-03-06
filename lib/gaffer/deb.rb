module Gaffer
  class Deb
    attr_accessor :package, :readme, :depends, :arch

    def initialize(base, _package, _depends)
      @base = base
      @arch = "all"
      @package = _package
      @depends = _depends
      @dev = !!(@package =~ /-dev$/)
    end

    def build
      Dir.mktmpdir do |dir|
        install_dir = Rush["#{dir}/#{@base.prefix}/"]
        Git.clone(@base.dir, install_dir.full_path)
        Rush.bash "mkdir #{dir}/DEBIAN"
        File.open("#{dir}/DEBIAN/control", "w") do |f|
          f.write(control)
        end
        puts control
        if @dev
          Rush.bash "find #{install_dir.full_path} | grep -v [.]git | grep -v #{install_dir.full_path}$ | xargs rm -rf"
        else
          Rush.bash "find #{install_dir.full_path} | grep    [.]git | grep -v #{install_dir.full_path}$ | xargs rm -rf"
          [ :preinst, :postinst, :prerm, :postrm ].each do |script|
            File.open("#{dir}/DEBIAN/#{script}","w") do |file|
              file.chmod(0755)
              file.write(template(script))
            end
          end
          if install_dir["sudoers"].exists?
            Rush["#{dir}/etc/sudoers.d/"].create
            File.open("#{dir}/etc/sudoers.d/#{project}","w") do |file|
              file.chmod(0440)
              file.write install_dir["sudoers"].read
            end
            puts "sudoers -> /etc/sudoers.d/#{project}"
          end
          if install_dir["init.conf"].exists?
            puts " * detected init.conf - installing..."
            Rush["#{dir}/etc/init/"].create
            Rush["#{dir}/etc/init/#{project}.conf"].write install_dir["init.conf"].read
            puts "init.conf -> /etc/init/#{project}.conf"
          elsif install_dir["run"].exists?
            puts " * detected file 'run' - setting up initfile ..."
            initfile = template(:init)
            puts "----"
            puts initfile
            puts "----"
            puts " * installing to /etc/init/#{project}.conf"
            Rush["#{dir}/etc/init/#{project}.conf"].parent.create
            Rush["#{dir}/etc/init/#{project}.conf"].write(initfile)
          end
          if install_dir["Gemfile"].exists?
            puts " * Gemfile detected - installing gems before packaging"
            ## bundle output cannot be trusted - errors go to stdout and output goes to stderr
            begin
              install_dir.bash "bundle package 2>&1 > .tmp.bundle.out"
#              install_dir.bash "bundle install --development 2>&1 > .tmp.bundle.out"
            rescue Object => e
              puts " * Bundle error:"
              puts install_dir[".tmp.bundle.out"].read
              raise "Bundle failed"
            end
            puts install_dir[".tmp.bundle.out"].read
#            if out.match(/native extensions/)
#                puts "Warning: native extensions - the package is arch specific"
#                @arch = Rush.bash("dpkg --print-architecture").chomp
#              end
#            end
          end
        end
        puts Rush.bash "pwd"
        puts "fakeroot dpkg-deb -b #{dir} ./#{filebase}.deb"
        puts Rush.bash "fakeroot dpkg-deb -b #{dir} ./#{filebase}.deb"
        x = File.expand_path("./#{filebase}.deb")
        puts x
        x
      end
    end

    def has_init?
      File.exists?("#{@base.dir}/init.conf")
    end

    def origin_url
      @base.git.remotes.select { |r| r.name == "origin" }.map { |r| r.url }.first
    end

    def description
      "Gaffer package #{package} #{build_name}"
    end

    def filebase
        "#{package}_#{build_name}_#{@arch}"
    end

    def template(type)
      ERB.new(File.read("#{File.dirname(__FILE__)}/../../templates/#{type}.erb")).result(binding)
    end

    def origin
      Rush[@base.dir]
    end

    def maintainer
      @base.maintainer
    end

    def build_name
      @base.build_name
    end

    def project
      @base.project
    end

    def control
      template(:control)
    end
  end
end
