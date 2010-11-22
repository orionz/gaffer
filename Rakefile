require 'jeweler'

Jeweler::Tasks.new do |s|
	s.name = "gaffer"
	s.description = "Duct tape together some debian packages"
	s.summary = s.description
	s.author = "Orion Henry"
	s.email = "orion@heroku.com"
	s.homepage = "http://github.com/orionz/gaffer"
	s.files = FileList["[A-Z]*", "{bin,default,lib,spec}/**/*"]
	s.executables = %w(gaffer)
	s.add_dependency "git"
	s.add_dependency "right_aws"
end

#Jeweler::RubyforgeTasks.new

#desc 'Run specs'
#task :spec do
#	sh 'bacon -s spec/*_spec.rb'
#end

task :default => :spec

