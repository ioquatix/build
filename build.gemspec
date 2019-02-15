
require_relative 'lib/build/version'

Gem::Specification.new do |spec|
	spec.name          = "build"
	spec.version       = Build::VERSION
	spec.authors       = ["Samuel Williams"]
	spec.email         = ["samuel.williams@oriontransfer.co.nz"]
	spec.summary       = %q{Build is a framework for working with task based build systems.}
	spec.homepage      = ""
	spec.license       = "MIT"

	spec.files         = `git ls-files -z`.split("\x0")
	spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
	spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
	spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.0'
	
	spec.add_dependency "build-graph", "~> 1.0"
	spec.add_dependency "build-environment", "~> 1.3"
	spec.add_dependency "build-dependency", "~> 1.4"
	spec.add_dependency "build-makefile", "~> 1.0"
	
	spec.add_dependency "graphviz"
	
	spec.add_development_dependency "covered"
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "rspec", "~> 3.6"
	spec.add_development_dependency "rake"
end
