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

require 'teapot/rulebook'

require 'build/files'
require 'build/graph'
require 'build/makefile'

require 'teapot/name'

require 'graphviz'
require 'process/group'
require 'system'

module Teapot
	module Build
		Graph = ::Build::Graph
		Files = ::Build::Files
		Paths = ::Build::Files::Paths
		Makefile = ::Build::Makefile
		
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
				@rule.name
			end
			
			def hash
				[@rule.name, @arguments].hash
			end
			
			def eql?(other)
				other.kind_of?(self.class) and @rule.eql?(other.rule) and @arguments.eql?(other.arguments)
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
				
				super(Paths::NONE, Paths::NONE, @update)
			end
			
			attr :task_class
			
			def apply!(scope)
				scope.instance_exec(&@update)
			end
			
			def inspect
				@task_class.name.inspect
			end
		end
		
		class Task < Process::Task
			def initialize(walker, node, group)
				super(walker, node)
				
				@group = group
			end
			
			def process(inputs, outputs = :inherit, **options, &block)
				inputs = Build::Files::List.coerce(inputs)
				outputs = Build::Files::List.coerce(outputs) unless outputs.kind_of? Symbol
				
				node = ProcessNode.new(inputs, outputs, block, **options)
				
				self.invoke(node)
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
			
			# This function is called to finish the invocation of the task within the graph.
			# There are two possible ways this function can generally proceed.
			# 1/ The node this task is running for is clean, and thus no actual processing needs to take place, but children should probably be executed.
			# 2/ The node this task is running for is dirty, and the execution of commands should work as expected.
			def update
				@node.evaluate(self)
			end
		end
		
		class Controller < Graph::Controller
			def initialize
				@module = Module.new
				
				@top = []
				
				yield self
				
				@top.freeze
				
				@task_class = nil
				
				super()
			end
			
			attr :top
			
			attr :visualisation
			
			# Because we do a depth first traversal, we can capture global state per branch, such as `@task_class`.
			def traverse!(walker)
				@top.each do |node|
					# Capture the task class for each top level node:
					@task_class = node.task_class
					
					node.update!(walker)
				end
			end
			
			def add_target(target, environment, &block)
				task_class = Rulebook.for(environment).with(Task, environment: environment, target: target)
				
				# Not sure if this is a good idea - makes debugging slightly easier.
				Object.const_set("TaskClassFor#{Name.from_target(target.name).identifier}_#{self.object_id}", task_class)
				
				@top << Top.new(self, task_class, &target.build)
			end
			
			def build_graph!
				super do |walker, node|
					@task_class.new(self, walker, node)
				end
			end
			
			def enter(task, node)
				return unless @g
				
				parent_node = @hierarchy.last
				
				task_node = @g.nodes[node] || @g.add_node(node, shape: 'box')
				
				if parent_node
					parent_node.connect(task_node)
				end
				
				node.inputs.map{|path| path.shortest_path(Dir.pwd)}.each do |path|
					input_node = @g.nodes[path.to_s] || @g.add_node(path.to_s, shape: 'box')
					input_node.connect(task_node)
				end
				
				@hierarchy << task_node
			end
			
			def exit(task, node)
				return unless @g
				
				@hierarchy.pop
				
				task_node = @g.nodes[node] || @g.add_node(node, shape: 'box')
				
				node.outputs.map{|path| path.shortest_path(Dir.pwd)}.each do |path|
					output_node = @g.nodes[path.to_s] || @g.add_node(path.to_s, shape: 'box')
					output_node.connect(task_node)
				end
			end
			
			def update!
				group = Process::Group.new
				
				@g = Graphviz::Graph.new('G', rankdir: "LR")
				@hierarchy = []
				
				walker = super do |walker, node|
					@task_class.new(self, walker, node, group)
				end
				
				group.wait
				
				if ENV['BUILD_GRAPH_PDF']
					Graphviz::output(@g, path: ENV['BUILD_GRAPH_PDF']) rescue nil
				end
				
				return walker
			end
		end
	end
end
