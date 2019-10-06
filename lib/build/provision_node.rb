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
	class ProvisionNode < Graph::Node
		def initialize(chain, provision, environment, arguments)
			@chain = chain
			@provision = provision
			@environment = environment
			@arguments = arguments
			
			# Wait here, for all dependent targets, to be done:
			super(Files::List::NONE, :inherit)
		end
		
		attr :chain
		attr :provision
		attr :environment
		attr :arguments
		
		def == other
			super and
				@chain == other.chain and
				@provision == other.provision and
				@environment == other.environment and
				@arguments == other.arguments
		end
		
		def hash
			super ^ @chain.hash ^ @provision.hash ^ @environment.hash ^ @arguments.hash
		end
		
		def task_class(parent_task)
			ProvisionTask
		end
		
		def name
			@provision.name
		end
		
		def dependency_node_for(dependency)
			DependencyNode.new(@chain, dependency, @environment, @arguments)
		end
	end
	
	module DependenciesFailed
		def self.to_s
			"Failed to build all dependencies!"
		end
	end
	
	class ProvisionTask < Task
		def initialize(*arguments, **options)
			super
			
			@dependencies = []
			
			@environments = []
			@public_environments = []
			
			@build_task = nil
		end
		
		attr :environments
		
		attr :build_task
		
		def provision
			@node.provision
		end
		
		def update
			provision.each_dependency do |dependency|
				@dependencies << invoke(@node.dependency_node_for(dependency))
			end
			
			if wait_for_children?
				update_environments!
			else
				fail!(DependenciesFailed)
			end
		end
		
		def local_environment
			Build::Environment.combine(@node.environment, *@environments)&.evaluate(name: @node.name)
		end
		
		def output_environment
			@build_task.output_environment.dup(parent: nil)
		end
		
		private
		
		def update_environments!
			@dependencies.each do |task|
				if environment = task.environment
					@environments << environment
				end
				
				if task.dependency.public?
					@public_environments << environment
				end
			end
			
			@build_task = invoke(
				BuildNode.new(local_environment, @node.provision, @node.arguments)
			)
		end
	end
end
