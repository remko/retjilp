require 'yard'
require 'rake/testtask'
require 'rubygems/package_task'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |s|
	s.pattern = 'test/spec/*_spec.rb'
end

#Rake::TestTask.new do |t|
#  t.libs << 'test'
#end

YARD::Rake::YardocTask.new do |t|
	t.files = ['lib/**/*.rb', '-', 'README.markdown', 'COPYING']
	t.options = ['--no-private', '--protected']
end

spec = eval(File.read('retjilp.gemspec'))
Gem::PackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "Run tests"
task :test => :spec

task :default => :test



