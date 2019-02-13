# Copyright, 2016, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'build/files'
require 'build/graph'

require_relative 'task'

module Build
	class EnvironmentNode < Graph::Node
		def initialize(environment, *arguments)
			@environment = environment
			@arguments = arguments
			
			# Wait here, for all dependent targets, to be done:
			super(Files::List::NONE, :inherit, environment)
		end
		
		def task_class
			Task
		end
		
		def apply!(scope)
			@environment.flatten do |environment|
				parent = environment.parent&.flatten || Build::Environment.new
				
				task_class = Rulebook.for(parent).with(Task, environment: parent.evaluate)
				task = task_class.new(scope.walker, self, scope.group, logger: scope.logger)
				
				scope.walker.with(task_class: task_class) do
					task.visit do
						environment.update! do |update|
							environment.construct!(task, *@arguments, &update)
						end
					end
				end
			end
		end
		
		def to_s
			"#<#{self.class}>"
		end
	end
end
