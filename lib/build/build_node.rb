# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require "fileutils"
require "build/graph"

require "console/event/spawn"

# @namespace
module Build
	# Represents a build graph node that applies a single provision to produce an output environment.
	class BuildNode < Graph::Node
		# Initialize the build node with an environment, provision, and arguments.
		# @parameter environment [Build::Environment] The environment to build within.
		# @parameter provision [Build::Dependency::Provision] The provision to apply.
		# @parameter arguments [Array] Arguments passed to the provision constructor.
		def initialize(environment, provision, arguments)
			@environment = environment
			@provision = provision
			@arguments = arguments
			
			super(Files::List::NONE, :inherit)
		end
		
		attr :environment
		attr :provision
		attr :arguments
		
		# @returns [Boolean] Whether this node is equal to another.
		def == other
			super and
				@environment == other.environment and
				@provision == other.provision and
				@arguments == other.arguments
		end
		
		# @returns [Integer] A hash value for this node.
		def hash
			super ^ @environment.hash ^ @provision.hash ^ @arguments.hash
		end
		
		# @returns [Class] The task class to use for building this node.
		def task_class(parent_task)
			task_class = Rulebook.for(@environment).with(BuildTask, environment: @environment)
		end
		
		# @returns [Build::Environment] A fresh copy of the environment for output.
		def initial_environment
			Build::Environment.new(@environment)
		end
		
		# @returns [String] The name of the environment.
		def name
			@environment.name
		end
		
		# Apply this node to the given task, constructing the output environment.
		# @parameter task [Build::Task] The task context.
		def apply!(task)
			output_environment = self.initial_environment
			
			output_environment.construct!(task, *@arguments, &@provision.value)
			
			task.output_environment = output_environment
		end
	end
	
	# This task class serves as the base class for the environment specific task classes genearted when adding targets.
	class BuildTask < Task
		# Represents a failure when a spawned command exits with a non-zero status.
		class CommandFailure < Graph::TransientError
			# Initialize the failure with the task, arguments, and exit status.
			# @parameter task [Build::BuildTask] The task that spawned the command.
			# @parameter arguments [Array] The command arguments that were run.
			# @parameter status [Process::Status] The exit status of the command.
			def initialize(task, arguments, status)
				@task = task
				@arguments = arguments
				@status = status
				
				super "#{File.basename(executable_name).inspect} exited with status #{@status.to_i}"
			end
			
			# @returns [String] The name of the executable that failed.
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
		
		# @returns [Boolean] Whether the node is dirty and commands should actually be executed.
		def wet?
			@node.dirty?
		end
		
		# Spawn a process if the node is dirty, raising {CommandFailure} on non-zero exit.
		# @parameter arguments [Array] The command and its arguments.
		# @parameter options [Hash] Options forwarded to the process group.
		def spawn(*arguments, **options)
			if wet?
				Console.info(self){Console::Event::Spawn.for(*arguments, **options)}
				status = @group.spawn(*arguments, **options)
				
				if status != 0
					raise CommandFailure.new(self, arguments, status)
				end
			end
		end
		
		# @returns [Hash] A flattened, exported shell environment hash.
		def shell_environment
			@shell_environment ||= environment.flatten.export
		end
		
		# Run a shell command within the task's environment.
		# @parameter arguments [Array] The command and its arguments.
		# @parameter options [Hash] Options forwarded to the process group.
		def run!(*arguments, **options)
			self.spawn(shell_environment, *arguments, **options)
		end
		
		# Touch a file, creating or updating its modification time.
		# @parameter path [String] The file path to touch.
		def touch(path)
			return unless wet?
			
			Console::Event::Spawn.for("touch", path).emit(self)
			FileUtils.touch(path)
		end
		
		# Copy a file from source to destination.
		# @parameter source_path [String] The source file path.
		# @parameter destination_path [String] The destination file path.
		def cp(source_path, destination_path)
			return unless wet?
			
			Console::Event::Spawn.for("cp", source_path, destination_path).emit(self)
			FileUtils.copy(source_path, destination_path)
		end
		
		# Remove a file or directory recursively.
		# @parameter path [String] The path to remove.
		def rm(path)
			return unless wet?
			
			Console::Event::Spawn.for("rm", "-rf", path).emit(self)
			FileUtils.rm_rf(path)
		end
		
		# Create a directory and all intermediate directories.
		# @parameter path [String] The directory path to create.
		def mkpath(path)
			return unless wet?
			
			unless File.exist?(path)
				Console::Event::Spawn.for("mkdir", "-p", path).emit(self)
				FileUtils.mkpath(path)
			end
		end
		
		# Install a file to a destination path.
		# @parameter source_path [String] The source file path.
		# @parameter destination_path [String] The destination file path.
		def install(source_path, destination_path)
			return unless wet?
			
			Console::Event::Spawn.for("install", source_path, destination_path).emit(self)
			FileUtils.install(source_path, destination_path)
		end
		
		# Write data to a file.
		# @parameter path [String] The destination file path.
		# @parameter data [String] The data to write.
		# @parameter mode [String] The file open mode.
		def write(path, data, mode = "w")
			return unless wet?
			
			Console::Event::Spawn.for("write", path).emit(self, size: data.size)
			File.open(path, mode) do |file|
				file.write(data)
			end
		end
		
		# Invoke a rule with the given arguments, normalising them and invoking the rule node.
		# @parameter rule [Build::Rule] The rule to invoke.
		# @parameter arguments [Hash] The arguments to pass to the rule.
		# @returns [Object] The result of the rule, typically a file path.
		def invoke_rule(rule, arguments, &block)
			arguments = rule.normalize(arguments, self)
			
			Console.debug(self){"-> #{rule}(#{arguments.inspect})"}
			
			invoke(
				RuleNode.new(rule, arguments, &block)
			)
			
			Console.debug(self){"<- #{rule}(...) -> #{rule.result(arguments)}"}
			
			return rule.result(arguments)
		end
	end
end
