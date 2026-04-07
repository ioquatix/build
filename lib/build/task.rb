# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2016-2026, by Samuel Williams.

require "fileutils"
require "build/graph"

require "console/event/spawn"

module Build
	# This task class serves as the base class for the environment specific task classes genearted when adding targets.
	class Task < Graph::Task
		# Initialize the task.
		# @parameter walker [Build::Graph::Walker] The graph walker.
		# @parameter node [Build::Graph::Node] The node being processed.
		# @parameter group [Process::Group] The process group for spawning commands.
		def initialize(walker, node, group)
			super(walker, node)
			
			@group = group
		end
		
		# @returns [Class] The class of this task.
		def task_class
			self.class
		end
		
		attr :group
		
		# Apply the node to this task, executing any build logic.
		def update
			@node.apply!(self)
		end
		
		# @returns [String] A string representation of the task.
		def name
			self.to_s
		end
		
		# @returns [String] The name of the underlying node.
		def node_string
			@node.name
		end
	end
end
