# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2016-2019, by Samuel Williams.

require "fileutils"
require "build/graph"

require "console/event/spawn"

module Build
	# This task class serves as the base class for the environment specific task classes genearted when adding targets.
	class Task < Graph::Task
		def initialize(walker, node, group, logger: nil)
			super(walker, node)
			
			@group = group
			@logger = logger
		end
		
		def task_class
			self.class
		end
		
		attr :group
		attr :logger
		
		def update
			@node.apply!(self)
		end
		
		def name
			self.to_s
		end
		
		def node_string
			@node.name
		end
	end
end
