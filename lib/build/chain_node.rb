# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'build/files'
require 'build/graph'

require_relative 'task'

module Build
	class ChainNode < Graph::Node
		def initialize(chain, arguments, environment)
			@chain = chain
			@arguments = arguments
			@environment = environment
			
			# Wait here, for all dependent targets, to be done:
			super(Files::List::NONE, :inherit, chain)
		end
		
		def name
			@environment.name
		end
		
		def task_class
			Task
		end
		
		def apply_dependency(scope, dependency, tasks = [])
			logger = scope.logger
			
			# logger.debug {"Traversing: #{dependency}..."}
			
			environments = [@environment]
			
			public_environments = []
			public_alias = dependency.alias?
			
			# Lookup what things this dependency provides:
			provisions = @chain.resolved[dependency]
			
			provisions.each do |provision|
				provision.each_dependency do |nested_dependency|
					if environment = apply_dependency(scope, nested_dependency, tasks)
						# logger.debug("Evaluating #{nested_dependency} -> #{provision} generated: #{environment}")
						
						environments << environment
						
						if public_alias || nested_dependency.public?
							public_environments << environment
						# else
						# 	logger.debug("Skipping #{nested_dependency} in public environment.")
						end
					end
				end
			end
			
			unless dependency.alias?
				logger.debug {"Building: #{dependency}"}
				
				# environments.each do |environment|
				# 	logger.debug {"Using #{environment}"}
				# end
				
				local_environment = Build::Environment.combine(*environments)&.evaluate || Build::Environment.new
				
				# logger.debug("Local Environment: #{local_environment}")
				
				task_class = Rulebook.for(local_environment).with(Task, environment: local_environment)
				task = task_class.new(scope.walker, self, scope.group, logger: scope.logger, dependencies: tasks.dup)
				tasks.clear
				
				task.visit do
					output_environment = Build::Environment.new(local_environment, name: dependency.name)
					
					provisions.each do |provision|
						# When executing the environment build steps, we create new build nodes. But those build nodes are not capturing the right task class.
						output_environment.construct!(task, *@arguments, &provision.value)
					end
					
					public_environments << output_environment.dup(parent: nil, name: dependency.name)
				end
				
				tasks << task
			end
			
			return Build::Environment.combine(*public_environments)
		end
		
		# This is the main entry point when invoking the node from a task.
		def apply!(scope)
			# Go through all the dependencies in order and apply them to the given scope:
			@chain.dependencies.each do |dependency|
				apply_dependency(scope, dependency)
			end
		end
		
		def to_s
			"#<#{self.class}>"
		end
	end
end
