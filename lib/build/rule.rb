# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2026, by Samuel Williams.

module Build
	# A rule is a function with a specific set of input and output parameters, which can match against a given set of specific arguments. For example, there might be several rules for compiling, but the specific rules depend on the language being compiled.
	class Rule
		# Build a frozen rule from a name and a definition block.
		# @parameter name [String] The rule name in `"process.type"` format.
		# @returns [Build::Rule] The constructed and frozen rule.
		def self.build(name, &block)
			rule = self.new(*name.split(".", 2))
			
			rule.instance_eval(&block)
			
			return rule.freeze
		end
		
		# Represents a single input, output, or argument parameter of a rule.
		class Parameter
			# Initialize the parameter.
			# @parameter direction [Symbol] One of `:input`, `:output`, or `:argument`.
			# @parameter name [Symbol] The parameter name.
			# @parameter options [Hash] Options such as `:default`, `:optional`, `:implicit`, `:pattern`.
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
			
			# @returns [Boolean] Whether this is an input parameter.
			def input?
				@direction == :input
			end
			
			# @returns [Boolean] Whether this is an output parameter.
			def output?
				@direction == :output
			end
			
			# @returns [Boolean] Whether this parameter has a dynamic computation block.
			def dynamic?
				@dynamic != nil
			end
			
			# Do we have a default value for this parameter?
			def default?
				@options.key?(:default)
			end
			
			# @returns [Boolean] Whether this parameter is implicitly computed and can be overridden.
			def implicit?
				dynamic? and @options[:implicit]
			end
			
			# Optional parameters are those that are either defined as optional or implicit.
			def optional?
				@options[:optional] || implicit? || default?
			end
			
			# Check whether the given arguments satisfy this parameter.
			# @parameter arguments [Hash] The arguments to check.
			# @returns [Boolean] Whether this parameter is satisfied.
			def applicable? arguments
				value = arguments.fetch(@name) do
					# Value couldn't be found, if it wasn't optional, this parameter didn't apply:
					return optional?
				end
				
				# If a pattern is provided, we must match it.
				if pattern = @options[:pattern]
					return Array(value).all?{|item| pattern.match(item)}
				end
				
				return true
			end
			
			# Compute the value for this parameter given the arguments and scope.
			# @parameter arguments [Hash] The current argument set.
			# @parameter scope [Object] The task scope used for dynamic evaluation.
			# @returns [Object] The computed parameter value.
			def compute(arguments, scope)
				if implicit?
					# Can be replaced if supplied:
					arguments[@name] || scope.instance_exec(arguments, &@dynamic) || @options[:default]
				elsif dynamic?
					# Argument is optional:
					scope.instance_exec(arguments[@name], arguments, &@dynamic) || @options[:default]
				elsif arguments.key?(@name)
					arguments[@name]
				else
					@options[:default]
				end
			end
			
			# @returns [Integer] A hash value for this parameter.
			def hash
				[self.class, @direction, @name, @options].hash
			end
			
			# TODO fix implementation
			def eql? other
				other.kind_of?(self.class) and @direction.eql?(other.direction) and @name.eql?(other.name) and @options.eql?(other.options) # and @dynamic == other.dynamic
			end
			
			# @returns [String] A human-readable representation of the parameter.
			def inspect
				"#{direction}:#{@name} (#{options.inspect})"
			end
		end
		
		# Initialize a rule with a process name and type.
		# @parameter process_name [String] The process name, e.g. `"compile"`.
		# @parameter type [String] The file type, e.g. `"cpp"`.
		def initialize(process_name, type)
			@name = process_name + "." + type
			@full_name = @name.gsub(/[^\w]/, "_")
			
			@process_name = process_name.gsub("-", "_").to_sym
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
		
		# Freeze the rule and all its components.
		# @returns [Build::Rule] The frozen rule.
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
		
		# Add an input parameter to the rule.
		# @parameter name [Symbol] The parameter name.
		# @parameter options [Hash] Parameter options.
		def input(name, options = {}, &block)
			self << Parameter.new(:input, name, options, &block)
		end
		
		# Add a generic argument parameter to the rule.
		# @parameter name [Symbol] The parameter name.
		# @parameter options [Hash] Parameter options.
		def parameter(name, options = {}, &block)
			self << Parameter.new(:argument, name, options, &block)
		end
		
		# Add an output parameter to the rule.
		# @parameter name [Symbol] The parameter name.
		# @parameter options [Hash] Parameter options.
		def output(name, options = {}, &block)
			self << Parameter.new(:output, name, options, &block)
		end
		
		# Append a parameter to the rule.
		# @parameter parameter [Build::Rule::Parameter] The parameter to add.
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
		
		# Derive the input and output file lists from the given arguments.
		# @parameter arguments [Hash] The argument set.
		# @returns [Array(Build::Files::Composite, Build::Files::Composite)] Input and output file composites.
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
		
		# Set the apply block that is executed when the rule is invoked.
		def apply(&block)
			@apply = Proc.new(&block)
		end
		
		# Apply the rule in the given scope with the provided arguments.
		# @parameter scope [Object] The task scope.
		# @parameter arguments [Hash] The normalised arguments.
		def apply!(scope, arguments)
			scope.instance_exec(arguments, &@apply) if @apply
		end
		
		# @returns [Object | Nil] The primary output value from the given arguments, if any.
		def result(arguments)
			if @primary_output
				arguments[@primary_output.name]
			end
		end
		
		# @returns [Integer] A hash value for this rule.
		def hash
			[self.class, @name, @parameters].hash
		end
		
		# @returns [Boolean] Whether this rule is equal to another by name and parameters.
		def eql?(other)
			other.kind_of?(self.class) and @name.eql?(other.name) and @parameters.eql?(other.parameters)
		end
		
		# @returns [String] A human-readable representation of the rule.
		def to_s
			"#<#{self.class} #{@name.dump}>"
		end
	end
	
	# Raised when no applicable rule can be found for a given process name and arguments.
	class NoApplicableRule < StandardError
		# Initialize with the process name and arguments that had no matching rule.
		# @parameter name [String] The process name that was looked up.
		# @parameter arguments [Hash] The arguments that could not be matched.
		def initialize(name, arguments)
			super "No applicable rule with name #{name}.* for parameters: #{arguments.inspect}"
			
			@name = name
			@arguments = arguments
		end
	end
end
