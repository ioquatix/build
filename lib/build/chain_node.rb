# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2016-2019, by Samuel Williams.

require "build/files"
require "build/graph"

require_relative "task"
require_relative "dependency_node"

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
