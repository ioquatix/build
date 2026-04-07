# frozen_string_literal: true

require_relative "lib/build/version"

Gem::Specification.new do |spec|
	spec.name = "build"
	spec.version = Build::VERSION
	
	spec.summary = "Build is a framework for creating task based build systems."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.metadata = {
		"documentation_uri" => "https://ioquatix.github.io/build/",
		"source_code_uri" => "https://github.com/kurocha/build.git",
		"funding_uri" => "https://github.com/sponsors/ioquatix",
	}
	
	spec.files = Dir.glob(["{context,lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.3"
	
	spec.add_dependency "build-dependency", "~> 1.5"
	spec.add_dependency "build-environment", "~> 1.12"
	spec.add_dependency "build-graph", "~> 2.1"
	spec.add_dependency "build-makefile", "~> 1.0"
end
