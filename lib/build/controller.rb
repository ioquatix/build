# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2026, by Samuel Williams.

require "build/files"
require "build/makefile"
require "build/environment"
require "process/group"

require_relative "rulebook"
require_relative "name"

require_relative "rule_node"
require_relative "chain_node"
require_relative "task"

require "console"

module Build
	# Represents the top-level build controller that manages the walker and process group.
	class Controller
		# A builder class for constructing the controller.
		class Builder
			# Initialize the builder with an empty list of nodes.
			def initialize
				@nodes = []
			end
			
			# @attribute [Array(Graph::Node)] The list of nodes to build.
			attr :nodes
			
			# Add a build environment to the controller.
			def add_chain(chain, arguments = [], environment)
				@nodes << ChainNode.new(chain, arguments, environment)
			end
		end
		
		# Create a new controller using a builder.
		def self.build(**options)
			builder = Builder.new
			
			yield builder
			
			new(builder.nodes, **options)
		end
		
		# Initialize the controller, yielding self to allow adding chain nodes.
		# @parameter limit [Integer | Nil] Maximum number of concurrent processes.
		def initialize(nodes = [], limit: nil)
			@module = Module.new
			
			if block_given?
				warn "Passing a block to Build::Controller.new is deprecated, use Build::Controller.build instead."
				
				builder = Builder.new
				yield builder
				@nodes = builder.nodes.freeze
			else
				@nodes = nodes.freeze
			end
			
			@group = Process::Group.new(limit: limit)
			
			# The task class is captured as we traverse all the top level targets:
			@task_class = nil
			
			@walker = Graph::Walker.new(&self.method(:step))
		end
		
		attr :nodes
		attr :walker
		
		# Visit a task, executing its update method within the context of the task's visit method.
		#
		# @parameter task [Build::Task] The task to visit.
		def visit(task)
			task.visit do
				task.update
			end
		end
		
		# Execute a single step of the build graph for the given node.
		# @parameter walker [Build::Graph::Walker] The graph walker.
		# @parameter node [Build::Graph::Node] The node to process.
		# @parameter parent_task [Build::Task | Nil] The parent task, if any.
		def step(walker, node, parent_task = nil)
			task_class = node.task_class(parent_task) || Task
			task = task_class.new(walker, node, @group)
			
			self.visit(task)
		end
		
		# @returns [Boolean] Whether the build has failed.
		def failed?
			@walker.failed?
		end
		
		# Execute all top-level nodes, waiting for each to complete.
		def update
			@nodes.each do |node|
				# We wait for all processes to complete within each node. The result is that we don't execute top level nodes concurrently, but we do execute within each node concurrently where possible. Ideally, some node could be executed concurrently, but right now expressing non-file dependencies between nodes is not possible.
				@group.wait do
					@walker.call(node)
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
