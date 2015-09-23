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
require_relative 'name'

require 'build/files'
require 'build/graph'

require 'process/group'

require_relative 'logger'

module Build
	class RuleNode < Graph::Node
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
	
	class TargetNode < Graph::Node
		def initialize(task_class, &update)
			@update = update
			@task_class = task_class
			
			super(Files::Paths::NONE, :inherit, @update)
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
	class Task < Graph::Task
		class CommandFailure < StandardError
			def initialize(task, arguments, status)
				@task = task
				@arguments = arguments
				@status = status
				
				super "#{@arguments.first} exited with status #{@status}"
			end
			
			attr :task
			attr :arguments
			attr :status
		end
		
		def initialize(walker, node, group, logger: nil)
			super(walker, node)
			
			@group = group
			
			@logger = logger || Logger.new($stderr)
		end
		
		def wet?
			@node.dirty?
		end
		
		def spawn(*arguments)
			if wet?
				@logger.info('shell') {arguments}
				status = @group.spawn(*arguments)
				
				if status != 0
					raise CommandFailure.new(self, arguments, status)
				end
			end
		end
		
		def shell_environment
			@shell_environment ||= environment.flatten.export
		end
		
		def run!(*arguments)
			self.spawn(shell_environment, *arguments)
		end
		
		def touch(path)
			return unless wet?
			
			@logger.info('shell'){ ['touch', path] }
			FileUtils.touch(path)
		end
		
		def cp(source_path, destination_path)
			return unless wet?
			
			@logger.info('shell'){ ['cp', source_path, destination_path]}
			FileUtils.copy(source_path, destination_path)
		end
		
		def rm(path)
			return unless wet?
			
			@logger.info('shell'){ ['rm', path] }
			FileUtils.rm(path)
		end
		
		def mkpath(path)
			return unless wet?
			
			unless File.exist?(path)
				@logger.info('shell'){ ['mkpath', path] }
				
				FileUtils.mkpath(path)
			end
		end
		
		def install(source_path, destination_path)
			return unless wet?
			
			@logger.info('shell'){ ['install', source_path, destination_path]}
			FileUtils.install(source_path, destination_path)
		end
		
		# Legacy FileUtils access, replaced with direct function calls.
		def fs
			self
		end
		
		def update
			@node.apply!(self)
		end
		
		def invoke_rule(rule, arguments, &block)
			arguments = rule.normalize(arguments, self)
			
			@logger.debug('invoke') {"-> #{rule}: #{arguments.inspect}"}
			
			node = RuleNode.new(rule, arguments, &block)
			task = invoke(node)
			
			@logger.debug('invoke') {"<- #{rule}: #{rule.result(arguments)}"}
			
			return rule.result(arguments)
		end
	end
	
	class Controller
		def initialize
			@module = Module.new
			
			@logger = Logger.new($stdout)
			@logger.level = Logger::INFO
			@logger.formatter = CompactFormatter.new
			
			# Top level nodes:
			@nodes = []
			
			yield self
			
			@nodes.freeze
			
			@group = Process::Group.new
			
			# The task class is captured as we traverse all the top level targets:
			@task_class = nil
			
			@walker = Graph::Walker.new do |walker, node|
				# Instantiate the task class here:
				task = @task_class.new(walker, node, @group, logger: @logger)
				
				task.visit do
					task.update
				end
			end
		end
		
		attr :nodes
		attr :visualisation
		
		def add_target(target, environment)
			task_class = Rulebook.for(environment).with(Task, environment: environment, target: target)
			
			# Not sure if this is a good idea - makes debugging slightly easier.
			Object.const_set("TaskClassFor#{Name.from_target(target.name).identifier}_#{self.object_id}", task_class)
			
			@nodes << TargetNode.new(task_class, &target.build)
		end
		
		def update
			@nodes.each do |node|
				# Update the task class here:
				@task_class = node.task_class
				
				@walker.call(node)
			end
			
			@group.wait
			
			yield @walker if block_given?
		end
		
		def run(&block)
			@walker.run do
				self.update(&block)
			end
		end
	end
end
