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

require_relative 'provision_node'

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
			super ^ @chain.hash ^ @dependency.hash ^ @environment.hash ^ @arguments.hash
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
		
		def public?
			@dependency.public?
		end
		
		def provision_node_for(provision)
			ProvisionNode.new(@chain, provision, @environment, @arguments)
		end
	end
	
	class DependencyTask < Task
		def initialize(*arguments, **options)
			super
			
			@environments = []
			@provisions = []
		end
		
		attr :environment
		
		def dependency
			@node.dependency
		end
		
		def update
			logger.debug(self) do |buffer|
				buffer.puts "building #{@node} which #{@node.dependency}"
				@node.provisions.each do |provision|
					buffer.puts "\tbuilding #{provision.provider.name} which #{provision}"
				end
			end
			
			# Lookup what things this dependency provides:
			@node.provisions.each do |provision|
				@provisions << invoke(
					@node.provision_node_for(provision)
				)
			end
			
			if wait_for_children?
				update_environments!
			else
				fail!(ChildrenFailed)
			end
		end
		
		private
		
		def update_environments!
			@provisions.each do |task|
				if dependency.alias?
					@environments.concat(task.public_environments)
				else
					@environments << task.output_environment
				end
			end
			
			@environment = Build::Environment.combine(*@environments)
		end
	end
end
