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
		def initialize(environment, dependency, provisions, arguments)
			@environment = environment
			@dependency = dependency
			@provisions = provisions
			@arguments = arguments
			
			super(Files::List::NONE, :inherit)
		end
		
		attr :environment
		attr :dependency
		attr :provisions
		attr :arguments
		
		def == other
			super and
				@environment == other.environment and
				@dependency == other.dependency and
				@provisions == other.provisions and
				@arguments == other.arguments
		end
		
		def hash
			super ^ @environment.hash ^ @dependency.hash ^ @provisions.hash ^ @arguments.hash
		end
		
		def task_class(parent_task)
			task_class = Rulebook.for(@environment).with(BuildTask, environment: @environment)
		end
		
		def initial_environment
			Build::Environment.new(@environment, name: @dependency.name)
		end
		
		def name
			@dependency.name
		end
		
		def apply!(task)
			output_environment = self.initial_environment
			
			@provisions.each do |provision|
				output_environment.construct!(task, *@arguments, &provision.value)
			end
			
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
		
		def spawn(*arguments)
			if wet?
				@logger&.info(self) {Console::Event::Spawn.for(*arguments)}
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
			
			@logger&.info(self) {Console::Shell.for('touch', path)}
			FileUtils.touch(path)
		end
		
		def cp(source_path, destination_path)
			return unless wet?
			
			@logger&.info(self) {Console::Shell.for('cp', source_path, destination_path)}
			FileUtils.copy(source_path, destination_path)
		end
		
		def rm(path)
			return unless wet?
			
			@logger&.info(self) {Console::Shell.for('rm -rf', path)}
			FileUtils.rm_rf(path)
		end
		
		def mkpath(path)
			return unless wet?
			
			unless File.exist?(path)
				@logger&.info(self) {Console::Shell.for('mkpath', path)}
				FileUtils.mkpath(path)
			end
		end
		
		def install(source_path, destination_path)
			return unless wet?
			
			@logger&.info(self) {Console::Shell.for('install', source_path, destination_path)}
			FileUtils.install(source_path, destination_path)
		end
		
		def write(path, data, mode = "w")
			return unless wet?
			
			@logger&.info(self) {Console::Shell.for("write", path, "#{data.size}bytes")}
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
