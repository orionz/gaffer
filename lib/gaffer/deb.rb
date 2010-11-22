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
        install_dir = "#{dir}/#{@base.prefix}"
        Git.clone(@base.dir, install_dir)
        Rush.bash "mkdir #{dir}/DEBIAN"
        File.open("#{dir}/DEBIAN/control", "w") do |f|
          f.write(control)
        end
        puts control
        if @dev
          Rush.bash "find #{install_dir} | grep -v [.]git | grep -v #{install_dir}$ | xargs rm -rf"
        else
          Rush.bash "find #{install_dir} | grep    [.]git | grep -v #{install_dir}$ | xargs rm -rf"
#          [ :preinst, :postinst, :prerm, :postrm ].each do |script|
#            file = File.open("#{dir}/DEBIAN/#{script}","w")
#            file.chmod(0755)
#            file.write(template(script))
#            file.close
#          end
          if has_init?
            puts "INSTALLING init.conf"
            Rush.bash "mkdir -p #{dir}/etc/init"
            Rush.bash "cp #{@base.dir}/init.conf #{dir}/etc/init/#{@base.project}.conf"
          end
          if File.exists?("#{@base.dir}/Gemfile")
            Dir.chdir(@base.dir) do
              # TODO this can break in strange ways - STDOUT/STDERR is a mess
              if Rush.bash('bundle install --deployment').match(/native extensions/)
                @arch = Rush.bash "dpkg --print-architecture"
              end
            end
          end
        end
        Rush.bash "dpkg-deb -b #{dir} ./#{filebase}.deb"
        File.expand_path("./#{filebase}.deb")
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

    def maintainer
      @base.maintainer
    end

    def build_name
      @base.build_name
    end

    def control
      template(:control)
    end
  end
end
