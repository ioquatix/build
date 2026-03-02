# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2016-2019, by Samuel Williams.

require "build/graph"

module Build
	class RuleNode < Graph::Node
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
		
		def == other
			super and
				@arguments == other.arguments and
				@rule == other.rule and
				@callback == other.callback
		end
		
		def hash
			super ^ @arguments.hash ^ @rule.hash ^ @callback.hash
		end
		
		def task_class(parent_task)
			parent_task.class
		end
		
		def name
			@rule.name
		end
		
		def apply!(scope)
			@rule.apply!(scope, @arguments)
			
			if @callback
				scope.instance_exec(@arguments, &@callback)
			end
		end
		
		def inspect
			@rule.name.inspect
		end
	end
end
