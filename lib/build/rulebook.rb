# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2026, by Samuel Williams.

require_relative "rule"

module Build
	# Represents a collection of rules, organized by process name for fast lookup.
	class Rulebook
		# Initialize the rulebook.
		# @parameter name [String | Nil] An optional name for this rulebook.
		def initialize(name = nil)
			@name = name
			@rules = {}
			@processes = {}
		end
		
		attr :rules
		
		# Add a rule to this rulebook.
		# @parameter rule [Build::Rule] The rule to add.
		def << rule
			@rules[rule.name] = rule
			
			# A cache for fast process/file-type lookup:
			processes = @processes[rule.process_name] ||= []
			processes << rule
		end
		
		# Look up a rule by its full name.
		# @parameter name [String] The rule name, e.g. `"compile.cpp"`.
		# @returns [Build::Rule | Nil] The matching rule, or `nil`.
		def [] name
			@rules[name]
		end
		
		# Generate a task subclass with methods for all rules in this rulebook.
		# @parameter superclass [Class] The base task class to inherit from.
		# @parameter state [Hash] Additional state methods to define on the subclass.
		# @returns [Class] The generated task subclass.
		def with(superclass, **state)
			task_class = Class.new(superclass)
			
			# name = @name
			# task_class.send(:define_method, :to_s) do
			# 	"name"
			# end
			
			# Define methods for all processes, e.g. task_class#compile
			@processes.each do |key, rules|
				# Define general rules, which use rule applicability for disambiguation:
				task_class.send(:define_method, key) do |arguments, &block|
					rule = rules.find{|rule| rule.applicable? arguments}
					
					if rule
						invoke_rule(rule, arguments, &block)
					else
						raise NoApplicableRule.new(key, arguments)
					end
				end
			end
			
			# Define methods for all rules, e.g. task_class#compile_cpp
			@rules.each do |key, rule|
				task_class.send(:define_method, rule.full_name) do |arguments, &block|
					invoke_rule(rule, arguments, &block)
				end
			end
			
			# Typically, this defines methods like #environment and #target which can be accessed in the build rule.
			state.each do |key, value|
				task_class.send(:define_method, key) do
					value
				end
			end
			
			return task_class
		end
		
		# Build a rulebook from all rule definitions in the given environment.
		# @parameter environment [Build::Environment] The environment to extract rules from.
		# @returns [Build::Rulebook] The populated rulebook.
		def self.for(environment)
			rulebook = self.new(environment.name)
			
			environment.defined.each do |name, define|
				rulebook << define.klass.build(name, &define.block)
			end
			
			return rulebook
		end
	end
end
