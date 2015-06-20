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

require_relative 'rulebook'

require 'build/files'
require 'build/graph'
require 'build/makefile'

require 'graphviz'
require 'process/group'
require 'system'

module Build
	class Node < Graph::Node
		def initialize(rule, arguments, &block)
			@arguments = arguments
			@rule = rule
			
			@callback = block
			
			inputs, outputs = @rule.files(@arguments)
			
			super(inputs, outputs, @rule)
		end
		
		attr :arguments
		attr :rule
		attr :callback
		
		def title
			@rule.title
		end
		
		def apply!(scope)
			@rule.apply!(scope, @arguments)
			
			if @callback
				scope.instance_exec(@arguments, &@callback)
			end
		end
		
		def inspect
			@rule.name.inspect
		end
	end
	
	class Top < Graph::Node
		def initialize(task_class, &update)
			@update = update
			@task_class = task_class
			
			super(Paths::NONE, :inherit, @update)
		end
		
		attr :task_class
		
		def apply!(scope)
			scope.instance_exec(&@update)
		end
		
		def inspect
			@task_class.name.inspect
		end
	end
	
	# This task class serves as the base class for the environment specific task classes genearted when adding targets.
	class Task < Process::Task
		def initialize(walker, node, group)
			super(walker, node)
			
			@group = group
		end
		
		def wet?
			@node.dirty?
		end
		
		def run(*arguments)
			if wet?
				puts "\t[run] #{arguments.join(' ')}"
				status = @group.spawn(*arguments)
				
				if status != 0
					raise CommandError.new(status)
				end
			end
		end
		
		def fs
			if wet?
				FileUtils::Verbose
			else
				FileUtils::Verbose::Dry
			end
		end
		
		def update
			@node.evaluate(self)
		end
		
		def invoke_rule(rule, arguments, &block)
			invoke Node.new(rule, arguments, &block)
		end
	end
	
	class Controller
		def initialize
			@module = Module.new
			
			@top = []
			
			yield self
			
			@top.freeze
		end
		
		attr :top
		attr :visualisation
		
		def add_target(target, environment, &block)
			task_class = Rulebook.for(environment).with(Task, environment: environment, target: target)
			
			# Not sure if this is a good idea - makes debugging slightly easier.
			Object.const_set("TaskClassFor#{Name.from_target(target.name).identifier}_#{self.object_id}", task_class)
			
			@top << Top.new(self, task_class, &target.build)
		end
		
		def update!
			group = Process::Group.new
			
			# The task class is captured as we traverse all the top level targets:
			task_class = nil
			
			walker = Walker.new do |walker, node|
				# Instantiate the task class here:
				task = task_class.new(walker, node, group)
				
				task.visit do
					task.update
				end
			end
			
			@top.each do |node|
				# Update the task class here:
				task_class = node.task_class
				
				walker.call(node)
			end
			
			group.wait
			
			if ENV['BUILD_GRAPH_PDF']
				generate_graph_visualisation(walker)
			end
			
			return walker
		end
		
		def genreate_graph_visualisation(walker)
			viz = Graphviz::Graph.new('G', rankdir: "LR")
			
			walker.tasks.each do |node, task|
				input_nodes = []
				output_nodes = []
				
				task.inputs.each do |path|
					input_nodes << viz.add_node(path.basename)
				end
				
				task.outputs.each do |path|
					output_nodes << viz.add_node(path.basename)
				end
				
				if output_nodes.size == 1
					input_nodes.each do |input_node|
						edge = input_node.connect(output_nodes.first)
						edge.attributes[:label] = node.title
					end
				end
			end

			Graphviz::output(viz, path: ENV['BUILD_GRAPH_PDF']) rescue nil
			#`dot -Tpdf graph.dot > graph.pdf && open graph.pdf`
		end
	end
end
