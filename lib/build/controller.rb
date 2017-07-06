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

require 'build/files'
require 'build/makefile'
require 'build/environment'
require 'process/group'

require_relative 'rulebook'
require_relative 'name'

require_relative 'rule_node'
require_relative 'target_node'
require_relative 'task'

require_relative 'logger'

module Build
	class Controller
		def initialize(logger: nil, limit: nil)
			@module = Module.new
			
			@logger = logger || Logger.new($stdout).tap do |logger|
				logger.level = Logger::INFO
				logger.formatter = CompactFormatter.new
			end
			
			# Top level nodes, for sanity this is a static list.
			@nodes = []
			yield self
			@nodes.freeze
			
			@group = Process::Group.new(limit: limit)
			
			# The task class is captured as we traverse all the top level targets:
			@task_class = nil
			
			@walker = Graph::Walker.new(logger: @logger, &self.method(:step))
		end
		
		attr :logger
		
		attr :nodes
		attr :walker
		
		private def step(walker, node, task_class:)
			task = task_class.new(walker, node, @group, logger: @logger)
			
			task.visit do
				task.update
			end
		end
		
		def failed?
			@walker.failed?
		end
		
		# Add a build target to the controller.
		def add_target(target, environment, arguments = [])
			task_class = Rulebook.for(environment).with(Task, environment: environment, target: target)
			
			# Not sure if this is a good idea - makes debugging slightly easier.
			Object.const_set("TaskClassFor#{Name.from_target(target.name).identifier}_#{task_class.object_id}", task_class)
			
			# A target node will invoke the build callback on target.
			@nodes << TargetNode.new(task_class, target, arguments)
			
			return @nodes.last
		end
		
		def update
			@nodes.each do |node|
				# We wait for all processes to complete within each node. The result is that we don't execute top level nodes concurrently, but we do execute within each node concurrently where possible. Ideally, some node could be executed concurrently, but right now expressing non-file dependencies between nodes is not possible.
				@group.wait do
					@walker.call(node, task_class: node.task_class)
				end
			end
		end
		
		# The entry point for running the walker over the build graph.
		def run
			@walker.run do
				self.update
				
				yield @walker if block_given?
			end
		end
	end
end
