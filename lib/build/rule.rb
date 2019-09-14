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

module Build
	# A rule is a function with a specific set of input and output parameters, which can match against a given set of specific arguments. For example, there might be several rules for compiling, but the specific rules depend on the language being compiled.
	class Rule
		def self.build(name, &block)
			rule = self.new(*name.split('.', 2))
			
			rule.instance_eval(&block)
			
			return rule.freeze
		end
		
		class Parameter
			def initialize(direction, name, options = {}, &block)
				@direction = direction
				@name = name
				
				@options = options
				
				@dynamic = block_given? ? Proc.new(&block) : nil
			end
			
			attr :direction
			attr :name
			
			attr :options
			attr :dynamic
			
			def input?
				@direction == :input
			end
			
			def output?
				@direction == :output
			end
			
			def dynamic?
				@dynamic != nil
			end
			
			# Do we have a default value for this parameter?
			def default?
				@options.key?(:default)
			end
			
			def implicit?
				dynamic? and @options[:implicit]
			end
			
			# Optional parameters are those that are either defined as optional or implicit.
			def optional?
				@options[:optional] || implicit? || default?
			end
			
			def applicable? arguments
				value = arguments.fetch(@name) do
					# Value couldn't be found, if it wasn't optional, this parameter didn't apply:
					return optional?
				end
				
				# If a pattern is provided, we must match it.
				if pattern = @options[:pattern]
					return Array(value).all? {|item| pattern.match(item)}
				end
				
				return true
			end
			
			def compute(arguments, scope)
				if implicit?
					# Can be replaced if supplied:
					arguments[@name] || scope.instance_exec(arguments, &@dynamic)
				elsif dynamic?
					# Argument is optional:
					scope.instance_exec(arguments[@name], arguments, &@dynamic)
				else
					arguments[@name]
				end || @options[:default]
			end
			
			def hash
				[self.class, @direction, @name, @options].hash
			end
			
			# TODO fix implementation
			def eql? other
				other.kind_of?(self.class) and @direction.eql?(other.direction) and @name.eql?(other.name) and @options.eql?(other.options) # and @dynamic == other.dynamic
			end
			
			def inspect
				"#{direction}:#{@name} (#{options.inspect})"
			end
		end
		
		def initialize(process_name, type)
			@name = process_name + "." + type
			@full_name = @name.gsub(/[^\w]/, '_')
			
			@process_name = process_name.gsub('-', '_').to_sym
			@type = type
			
			@apply = nil
			
			@parameters = []
			@primary_output = nil
		end
		
		# compile.cpp
		attr :name
		
		attr :parameters
		
		# compile
		attr :process_name
		
		# compile_cpp
		attr :full_name
		
		attr :primary_output
		
		def freeze
			return self if frozen?
			
			@name.freeze
			@full_name.freeze
			@process_name.freeze
			@type.freeze
			
			@apply.freeze
			@parameters.freeze
			@primary_output.freeze
			
			super
		end
		
		def input(name, options = {}, &block)
			self << Parameter.new(:input, name, options, &block)
		end
		
		def parameter(name, options = {}, &block)
			self << Parameter.new(:argument, name, options, &block)
		end
		
		def output(name, options = {}, &block)
			self << Parameter.new(:output, name, options, &block)
		end
		
		def << parameter
			@parameters << parameter
			
			if parameter.output?
				@primary_output ||= parameter
			end
		end
		
		# Check if this rule can process these parameters
		def applicable?(arguments)
			@parameters.each do |parameter|
				next if parameter.implicit?
				
				return false unless parameter.applicable?(arguments)
			end
			
			return true
		end
		
		# The scope is the context in which the dynamic rule computation is done, usually an instance of Task.
		def normalize(arguments, scope)
			Hash[
				@parameters.collect do |parameter|
					[parameter.name, parameter.compute(arguments, scope)]
				end
			]
		end
		
		def files(arguments)
			input_files = []
			output_files = []
			
			@parameters.each do |parameter|
				# This could probably be improved a bit, we are assuming all parameters are file based:
				value = arguments[parameter.name]
				
				next unless value
				
				case parameter.direction
				when :input
					input_files << value
				when :output
					output_files << value
				end
			end
			
			return Build::Files::Composite.new(input_files), Build::Files::Composite.new(output_files)
		end
		
		def apply(&block)
			@apply = Proc.new(&block)
		end
		
		def apply!(scope, arguments)
			scope.instance_exec(arguments, &@apply) if @apply
		end
		
		def result(arguments)
			if @primary_output
				arguments[@primary_output.name]
			end
		end
		
		def hash
			[self.class, @name, @parameters].hash
		end
		
		def eql?(other)
			other.kind_of?(self.class) and @name.eql?(other.name) and @parameters.eql?(other.parameters)
		end
		
		def to_s
			"#<#{self.class} #{@name.dump}>"
		end
	end
	
	class NoApplicableRule < StandardError
		def initialize(name, arguments)
			super "No applicable rule with name #{name}.* for parameters: #{arguments.inspect}"
			
			@name = name
			@arguments = arguments
		end
	end
end
