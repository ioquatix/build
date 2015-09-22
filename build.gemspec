# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'build/version'

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
	
	spec.add_dependency "build-graph", "~> 1.0.1"
	spec.add_dependency "build-environment", "~> 1.0.0"
	spec.add_dependency "build-makefile", "~> 1.0.0"
	
	spec.add_dependency "graphviz"
	
	spec.add_development_dependency "bundler", "~> 1.3"
	spec.add_development_dependency "rspec", "~> 3.0.0.rc1"
	spec.add_development_dependency "rake"
end
