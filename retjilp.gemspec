# encoding: utf-8

Gem::Specification.new do |s|
	s.name = 'retjilp'
	s.summary = 'Automatically retweet tweets'
	s.description = 'Retjilp logs into your account, scans all the tweets from your following list or another defined list for a set of matching words, and retweets the ones that match (using the native retweet API).'
	s.requirements = ['']
	s.version = '0.2'
	s.author = 'Remko Tronçon'
	s.email = 'remko@el-tramo.be'
	s.homepage = 'http://el-tramo.be/blog/retjilp'
	s.platform = Gem::Platform::RUBY
	s.required_ruby_version = '>=1.8'
	s.files = Dir['**/**']
	s.executables = 'retjilp'
	s.require_paths = ['lib']
	s.has_rdoc = false
	s.license = 'BSD'

	s.add_runtime_dependency('oauth')
	s.add_runtime_dependency('json_pure')
end
