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
require_relative 'dependency_node'

module Build
	# Responsible for processing a chain into a series of dependency nodes.
	class ChainNode < Graph::Node
		# @param chain [Chain] the chain to build.
		# @param arguments [Array] the arguments to pass to the output environment constructor.
		# @param anvironment [Build::Environment] the root environment to prepend into the chain.
		def initialize(chain, arguments, environment)
			@chain = chain
			@arguments = arguments
			@environment = environment
			
			# Wait here, for all dependent targets, to be done:
			super(Files::List::NONE, :inherit)
		end
		
		attr :chain
		attr :arguments
		attr :environment
		
		def == other
			super and
				@chain == other.chain and
				@arguments == other.arguments and
				@environment == other.environment
		end
		
		def hash
			super ^ @chain.hash ^ @arguments.hash ^ @environment.hash
		end
		
		def task_class(parent_task)
			Task
		end
		
		def name
			@environment.name
		end
		
		# This is the main entry point when invoking the node from `Build::Task`.
		def apply!(task)
			# Go through all the dependencies in order and apply them to the build graph:
			@chain.dependencies.each do |dependency|
				task.invoke(
					DependencyNode.new(@chain, dependency, @environment, @arguments)
				)
			end
		end
		
		def inspect
			"#<#{self.class} #{@environment.inspect}>"
		end
	end
end
