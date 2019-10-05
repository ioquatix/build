# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'build/graph'

require_relative 'build_node'

module Build
	class DependencyNode < Graph::Node
		def initialize(chain, dependency, environment, arguments)
			@chain = chain
			@dependency = dependency
			@environment = environment
			@arguments = arguments
			
			# Wait here, for all dependent targets, to be done:
			super(Files::List::NONE, :inherit)
		end
		
		attr :chain
		attr :dependency
		attr :environment
		attr :arguments
		
		def == other
			super and
				@chain == other.chain and
				@dependency == other.dependency and
				@environment == other.environment and
				@arguments == other.arguments
		end
		
		def hash
			super ^ @chain.hash ^ @environment.hash ^ @arguments.hash
		end
		
		def task_class(parent_task)
			DependencyTask
		end
		
		def name
			@dependency.name
		end
		
		def provisions
			@chain.resolved[@dependency]
		end
		
		def alias?
			@dependency.alias?
		end
		
		def public?
			@dependency.public?
		end
		
		# This is the main entry point when invoking the node from `Build::Task`.
		def apply!(task)
			# Go through all the dependencies in order and apply them to the build graph:
			@chain.dependencies.each do |dependency|
				node = DependencyNode.new(@chain, dependency, @environment, @arguments)
				
				task.invoke(node)
			end
		end
		
		def dependency_node_for(dependency)
			DependencyNode.new(@chain, dependency, @environment, @arguments)
		end
		
		def print_dependencies(buffer = $stderr, level = 0)
			self.provisions.each do |provision|
				buffer.puts "#{" " * indentation}building #{provision.provider.name} which #{provision} which depends on:"
				
				provision.each_dependency do |nested_dependency|
					child = self.dependency_node_for(nested_dependency)
					
					child.print_dependencies(buffer, level + 1)
				end
			end
			
			return nil
		end
	end
	
	class DependencyTask < Task
		def initialize(*arguments, **options)
			super
			
			@environment = nil
			@tasks = []
		end
		
		attr :group
		attr :logger
		
		attr :environment
		
		def update
			logger.debug(self) do |buffer|
				buffer.puts "building #{@node} which #{@node.dependency}"
				@node.provisions.each do |provision|
					buffer.puts "\tbuilding #{provision.provider.name} which #{provision}"
				end
			end
			
			# Lookup what things this dependency provides:
			@node.provisions.each do |provision|
				provision.each_dependency do |nested_dependency|
					@tasks << invoke(@node.dependency_node_for(nested_dependency))
				end
			end
		end
		
		def update_outputs
			dependency = @node.dependency
			environments = [@node.environment]
			
			public_environments = []
			public_alias = @node.alias?
			
			@tasks.each do |task|
				if environment = task.environment
					environments << environment
					
					if public_alias || task.node.public?
						public_environments << environment
					# else
					# 	logger.debug("Skipping #{nested_dependency} in public environment.")
					end
				end
			end
			
			unless public_alias
				logger.debug(self) {"Building: #{dependency} <- #{@tasks.join}"}
				
				# environments.each do |environment|
				# 	logger.debug {"Using #{environment}"}
				# end
				
				local_environment = Build::Environment.combine(*environments)&.evaluate || Build::Environment.new
				
				# logger.debug("Local Environment: #{local_environment}")
				
				build_task = invoke(
					BuildNode.new(local_environment, dependency, @node.provisions, @node.arguments)
				)
				
				if wait_for_children?
					output_environment = build_task.output_environment
					public_environments << output_environment.dup(parent: nil, name: dependency.name)
				end
			end
			
			@environment = Build::Environment.combine(*public_environments)
			
			super
		end
	end
end
