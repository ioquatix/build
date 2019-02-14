
require 'build/dependency'

class Target
	include Build::Dependency
	
	def initialize(name = nil)
		@name = name
		
		if block_given?
			yield self
		end
	end
	
	attr :name
	
	def inspect
		"\#<#{self.class}: #{@name}>"
	end
end
