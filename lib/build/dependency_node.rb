# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019, by Samuel Williams.

require "build/graph"

require_relative "provision_node"

module Build
	# Represents a build graph node for resolving and building a single dependency.
	class DependencyNode < Graph::Node
		# Initialize the dependency node.
		# @parameter chain [Build::Dependency::Chain] The dependency chain.
		# @parameter dependency [Build::Dependency] The dependency to resolve.
		# @parameter environment [Build::Environment] The root environment.
		# @parameter arguments [Array] Arguments passed down the build chain.
		def initialize(chain, dependency, environment, arguments)
			@chain = chain
			@dependency = dependency
			@environment = environment
			@arguments = arguments
			
			# Wait here, for all dependent targets, to be done:
			super(Files::List::NONE, :inherit)
		end
		
		attr :chain
		attr :dependency
		attr :environment
		attr :arguments
		
		# @returns [Boolean] Whether this node is equal to another.
		def == other
			super and
				@chain == other.chain and
				@dependency == other.dependency and
				@environment == other.environment and
				@arguments == other.arguments
		end
		
		# @returns [Integer] A hash value for this node.
		def hash
			super ^ @chain.hash ^ @dependency.hash ^ @environment.hash ^ @arguments.hash
		end
		
		# @returns [Class] The task class to use for this node.
		def task_class(parent_task)
			DependencyTask
		end
		
		# @returns [String] The name of the dependency.
		def name
			@dependency.name
		end
		
		# @returns [Array] The provisions resolved for this dependency.
		def provisions
			@chain.resolved[@dependency]
		end
		
		# @returns [Boolean] Whether this dependency is public.
		def public?
			@dependency.public?
		end
		
		# Build a {ProvisionNode} for the given provision.
		# @parameter provision [Build::Dependency::Provision] The provision to wrap.
		# @returns [Build::ProvisionNode] The corresponding provision node.
		def provision_node_for(provision)
			ProvisionNode.new(@chain, provision, @environment, @arguments)
		end
	end
	
	# @namespace
	module ProvisionsFailed
		# @returns [String] A description of the failure.
		def self.to_s
			"Failed to build all provisions!"
		end
	end
	
	# Represents a task that resolves and builds all provisions for a dependency.
	class DependencyTask < Task
		# Initialize the dependency task.
		def initialize(*arguments, **options)
			super
			
			@provisions = []
			
			@environments = nil
			@environment = nil
		end
		
		attr :environment
		
		# @returns [Build::Dependency] The dependency being resolved by this task.
		def dependency
			@node.dependency
		end
		
		# Build all provisions for the dependency and combine the resulting environments.
		def update
			Console.debug(self) do |buffer|
				buffer.puts "building #{@node} which #{@node.dependency}"
				@node.provisions.each do |provision|
					buffer.puts "\tbuilding #{provision.provider.name} which #{provision}"
				end
			end
			
			# Lookup what things this dependency provides:
			@node.provisions.each do |provision|
				@provisions << invoke(
					@node.provision_node_for(provision)
				)
			end
			
			if wait_for_children?
				update_environments!
			else
				fail!(ProvisionsFailed)
			end
		end
		
		private
		
		def update_environments!
			@environments = @provisions.flat_map(&:output_environments)
			
			@environment = Build::Environment.combine(*@environments)
		end
	end
end
