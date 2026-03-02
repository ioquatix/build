# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2016-2019, by Samuel Williams.

require "build/graph"

module Build
	# Represents a build graph node that applies a specific rule with given arguments.
	class RuleNode < Graph::Node
		# Initialize the rule node.
		# @parameter rule [Build::Rule] The rule to apply.
		# @parameter arguments [Hash] The normalised arguments for the rule.
		def initialize(rule, arguments, &block)
			@arguments = arguments
			@rule = rule
			
			@callback = block
			
			inputs, outputs = @rule.files(@arguments)
			
			super(inputs, outputs)
		end
		
		attr :arguments
		attr :rule
		attr :callback
		
		# @returns [Boolean] Whether this node is equal to another.
		def == other
			super and
				@arguments == other.arguments and
				@rule == other.rule and
				@callback == other.callback
		end
		
		# @returns [Integer] A hash value for this node.
		def hash
			super ^ @arguments.hash ^ @rule.hash ^ @callback.hash
		end
		
		# @returns [Class] The task class inherited from the parent task.
		def task_class(parent_task)
			parent_task.class
		end
		
		# @returns [String] The name of the rule.
		def name
			@rule.name
		end
		
		# Apply the rule in the given scope, then invoke the callback if present.
		# @parameter scope [Object] The task scope.
		def apply!(scope)
			@rule.apply!(scope, @arguments)
			
			if @callback
				scope.instance_exec(@arguments, &@callback)
			end
		end
		
		# @returns [String] A human-readable representation of the rule node.
		def inspect
			@rule.name.inspect
		end
	end
end
