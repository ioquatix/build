# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2016-2026, by Samuel Williams.

require "build/files"
require "build/graph"

require_relative "task"
require_relative "dependency_node"

module Build
	# Responsible for processing a chain into a series of dependency nodes.
	class ChainNode < Graph::Node
		# @parameter chain [Chain] the chain to build.
		# @parameter arguments [Array] the arguments to pass to the output environment constructor.
		# @parameter environment [Build::Environment] the root environment to prepend into the chain.
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
		
		# @returns [Boolean] Whether this node is equal to another.
		def == other
			super and
				@chain == other.chain and
				@arguments == other.arguments and
				@environment == other.environment
		end
		
		# @returns [Integer] A hash value for this node.
		def hash
			super ^ @chain.hash ^ @arguments.hash ^ @environment.hash
		end
		
		# @returns [Class] The task class to use for this node.
		def task_class(parent_task)
			Task
		end
		
		# @returns [String] The name of the environment.
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
		
		# @returns [String] A human-readable representation of this node.
		def inspect
			"#<#{self.class} #{@environment.inspect}>"
		end
	end
end
