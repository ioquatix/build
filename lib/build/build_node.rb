# Copyright, 2016, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'fileutils'
require 'build/graph'

require 'console/event/spawn'

module Build
	class BuildNode < Graph::Node
		def initialize(environment, provision, arguments)
			@environment = environment
			@provision = provision
			@arguments = arguments
			
			super(Files::List::NONE, :inherit)
		end
		
		attr :environment
		attr :provision
		attr :arguments
		
		def == other
			super and
				@environment == other.environment and
				@provision == other.provision and
				@arguments == other.arguments
		end
		
		def hash
			super ^ @environment.hash ^ @provision.hash ^ @arguments.hash
		end
		
		def task_class(parent_task)
			task_class = Rulebook.for(@environment).with(BuildTask, environment: @environment)
		end
		
		def initial_environment
			Build::Environment.new(@environment)
		end
		
		def name
			@environment.name
		end
		
		def apply!(task)
			output_environment = self.initial_environment
			
			output_environment.construct!(task, *@arguments, &@provision.value)
			
			task.output_environment = output_environment
		end
	end
	
	# This task class serves as the base class for the environment specific task classes genearted when adding targets.
	class BuildTask < Task
		class CommandFailure < Graph::TransientError
			def initialize(task, arguments, status)
				@task = task
				@arguments = arguments
				@status = status
				
				super "#{File.basename(executable_name).inspect} exited with status #{@status.to_i}"
			end
			
			def executable_name
				if @arguments[0].kind_of? Hash
					@arguments[1]
				else
					@arguments[0]
				end
			end
			
			attr :task
			attr :arguments
			attr :status
		end
		
		attr_accessor :output_environment
		
		def wet?
			@node.dirty?
		end
		
		def spawn(*arguments, **options)
			if wet?
				@logger&.info(self) {Console::Event::Spawn.for(*arguments, **options)}
				status = @group.spawn(*arguments, **options)
				
				if status != 0
					raise CommandFailure.new(self, arguments, status)
				end
			end
		end
		
		def shell_environment
			@shell_environment ||= environment.flatten.export
		end
		
		def run!(*arguments, **options)
			self.spawn(shell_environment, *arguments, **options)
		end
		
		def touch(path)
			return unless wet?
			
			Console::Event::Spawn.for('touch', path).emit(self)
			FileUtils.touch(path)
		end
		
		def cp(source_path, destination_path)
			return unless wet?
			
			Console::Event::Spawn.for('cp', source_path, destination_path).emit(self)
			FileUtils.copy(source_path, destination_path)
		end
		
		def rm(path)
			return unless wet?
			
			Console::Event::Spawn.for('rm', '-rf', path).emit(self)
			FileUtils.rm_rf(path)
		end
		
		def mkpath(path)
			return unless wet?
			
			unless File.exist?(path)
				Console::Event::Spawn.for('mkdir', '-p', path).emit(self)
				FileUtils.mkpath(path)
			end
		end
		
		def install(source_path, destination_path)
			return unless wet?
			
			Console::Event::Spawn.for('install', source_path, destination_path).emit(self)
			FileUtils.install(source_path, destination_path)
		end
		
		def write(path, data, mode = "w")
			return unless wet?
			
			Console::Event::Spawn.for('write', path).emit(self, size: data.size)
			File.open(path, mode) do |file|
				file.write(data)
			end
		end
		
		def invoke_rule(rule, arguments, &block)
			arguments = rule.normalize(arguments, self)
			
			@logger&.debug(self) {"-> #{rule}(#{arguments.inspect})"}
			
			invoke(
				RuleNode.new(rule, arguments, &block)
			)
			
			@logger&.debug(self) {"<- #{rule}(...) -> #{rule.result(arguments)}"}
			
			return rule.result(arguments)
		end
	end
end
