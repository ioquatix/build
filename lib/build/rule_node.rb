# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'build/graph'

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
