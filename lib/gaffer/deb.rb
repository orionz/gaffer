module Gaffer
  class Deb
    def initialize(base, arch, package, depends)
      @base = base
      @arch = arch
      @package = package
      @depends = depends
      @dev = !!(@package =~ /-dev$/)
    end

    def compile
      puts self.inspect
      Dir.mktmpdir do |dir|
        install_dir = "#{dir}/#{@base.prefix}"
        Git.clone(@base.dir, install_dir)
        system "mkdir #{dir}/DEBIAN"
        puts control
        File.open("#{dir}/DEBIAN/control", "w") do |f|
          f.write(control)
        end
        if @dev
          system "find #{install_dir} | grep -v [.]git | grep -v #{install_dir}$ | xargs rm -rf"
        else
          system "find #{install_dir} | grep    [.]git | grep -v #{install_dir}$ | xargs rm -rf"
          [ "preinst", "postinst", "prerm", "postrm" ].each do |script|
            system "cp #{@base.dir}/#{script} #{dir}/DEBIAN/" if File.exists?("#{@base.dir}/#{script}")
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
      "Gaffer package #{@package} #{@base.build}"
    end

    def filebase
        "#{@package}_#{@base.build}_#{@arch}"
    end

    def control
      <<CONTROL
Source: #{@package}
Section: unknown
Priority: extra
Maintainer: #{@base.maintainer}
Version: #{@base.build}
Homepage: #{origin_url}
Package: #{@package}
Architecture: #{@arch}
Depends: #{@depends}
Description: #{description}
  #{@readme}
CONTROL
    end
  end
end
