module Gaffer
  class Deb
    attr_accessor :package, :readme, :depends, :arch

    def initialize(base, _arch, _package, _depends)
      @base = base
      @arch = _arch
      @package = _package
      @depends = _depends
      @dev = !!(@package =~ /-dev$/)
    end

    def compile
      Dir.mktmpdir do |dir|
        install_dir = "#{dir}/#{@base.prefix}"
        Git.clone(@base.dir, install_dir)
        system "mkdir #{dir}/DEBIAN"
        File.open("#{dir}/DEBIAN/control", "w") do |f|
          f.write(control)
        end
        puts control
        if @dev
          system "find #{install_dir} | grep -v [.]git | grep -v #{install_dir}$ | xargs rm -rf"
        else
          system "find #{install_dir} | grep    [.]git | grep -v #{install_dir}$ | xargs rm -rf"
          [ :preinst, :postinst, :prerm, :postrm ].each do |script|
            file = File.open("#{dir}/DEBIAN/#{script}","w")
            file.chmod(0755)
            file.write(template(script))
            file.close
          end
          if File.exists?("#{@base.dir}/init.conf")
            puts "INSTALLING init.conf"
            system "mkdir -p #{dir}/etc/init"
            system "cp #{@base.dir}/init.conf #{dir}/etc/init/#{@base.project}.conf"
          end
        end
        system "dpkg-deb -b #{dir} ./#{filebase}.deb"
      end
    end

    def origin_url
      @base.git.remotes.select { |r| r.name == "origin" }.map { |r| r.url }.first
    end

    def description
      "Gaffer package #{package} #{@base.build}"
    end

    def filebase
        "#{package}_#{@base.build}_#{@arch}"
    end

    def template(type)
      ERB.new(File.read("#{File.dirname(__FILE__)}/../../templates/#{type}.erb")).result(binding)
    end

    def maintainer
      @base.maintainer
    end

    def build
      @base.build
    end

    def control
      template(:control)
    end
  end
end
