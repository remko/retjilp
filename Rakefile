require 'yard'
require 'rake/clean'
require 'rake/testtask'
require 'rubygems/package_task'
require 'rspec/core/rake_task'

CLEAN.include('.yardoc')
CLEAN.include('doc')
CLEAN.include('pkg')

spec = eval(File.read('retjilp.gemspec'))

RSpec::Core::RakeTask.new(:spec) do |s|
	s.pattern = 'test/spec/*_spec.rb'
end

#Rake::TestTask.new do |t|
#  t.libs << 'test'
#end

YARD::Rake::YardocTask.new do |t|
	t.files = ['lib/**/*.rb', '-'] + spec.extra_rdoc_files
	t.options = spec.rdoc_options
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "Run tests"
task :test => :spec

task :default => :test



