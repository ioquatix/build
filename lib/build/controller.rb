# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2019, by Samuel Williams.

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
		# Initialize the controller, yielding self to allow adding chain nodes.
		# @parameter limit [Integer | Nil] Maximum number of concurrent processes.
		def initialize(limit: nil)
			@module = Module.new
			
			# Top level nodes, for sanity this is a static list.
			@nodes = []
			yield self
			@nodes.freeze
			
			@group = Process::Group.new(limit: limit)
			
			# The task class is captured as we traverse all the top level targets:
			@task_class = nil
			
			@walker = Graph::Walker.new(&self.method(:step))
		end
		
		attr :nodes
		attr :walker
		
		# Execute a single step of the build graph for the given node.
		# @parameter walker [Build::Graph::Walker] The graph walker.
		# @parameter node [Build::Graph::Node] The node to process.
		# @parameter parent_task [Build::Task | Nil] The parent task, if any.
		def step(walker, node, parent_task = nil)
			task_class = node.task_class(parent_task) || Task
			task = task_class.new(walker, node, @group)
			
			task.visit do
				task.update
			end
		end
		
		# @returns [Boolean] Whether the build has failed.
		def failed?
			@walker.failed?
		end
		
		# Add a build environment to the controller.
		def add_chain(chain, arguments = [], environment)
			@nodes << ChainNode.new(chain, arguments, environment)
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
