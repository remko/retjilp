require 'yard'
require 'rake/testtask'
require 'rubygems/package_task'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

YARD::Rake::YardocTask.new do |t|
	t.files = ['lib/**/*.rb', '-', 'README.markdown', 'COPYING']
	t.options = ['--no-private', '--protected']
end

spec = eval(File.read('retjilp.gemspec'))
Gem::PackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "Run tests"
task :default => :test



