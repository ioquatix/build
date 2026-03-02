# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019, by Samuel Williams.

require "build/graph"

require_relative "build_node"

module Build
	# Represents a build graph node for applying a single provision within a dependency chain.
	class ProvisionNode < Graph::Node
		# Initialize the provision node.
		# @parameter chain [Build::Dependency::Chain] The dependency chain.
		# @parameter provision [Build::Dependency::Provision] The provision to apply.
		# @parameter environment [Build::Environment] The root environment.
		# @parameter arguments [Array] Arguments passed down the build chain.
		def initialize(chain, provision, environment, arguments)
			@chain = chain
			@provision = provision
			@environment = environment
			@arguments = arguments
			
			# Wait here, for all dependent targets, to be done:
			super(Files::List::NONE, :inherit)
		end
		
		attr :chain
		attr :provision
		attr :environment
		attr :arguments
		
		# @returns [Boolean] Whether this node is equal to another.
		def == other
			super and
				@chain == other.chain and
				@provision == other.provision and
				@environment == other.environment and
				@arguments == other.arguments
		end
		
		# @returns [Integer] A hash value for this node.
		def hash
			super ^ @chain.hash ^ @provision.hash ^ @environment.hash ^ @arguments.hash
		end
		
		# @returns [Class] The task class to use for this node.
		def task_class(parent_task)
			ProvisionTask
		end
		
		# @returns [String] The name of the provision.
		def name
			@provision.name
		end
		
		# Build a {DependencyNode} for the given dependency.
		# @parameter dependency [Build::Dependency] The dependency to wrap.
		# @returns [Build::DependencyNode] The corresponding dependency node.
		def dependency_node_for(dependency)
			DependencyNode.new(@chain, dependency, @environment, @arguments)
		end
	end
	
	# @namespace
	module DependenciesFailed
		# @returns [String] A description of the failure.
		def self.to_s
			"Failed to build all dependencies!"
		end
	end
	
	# Represents a task that builds the dependencies of a provision and applies the provision itself.
	class ProvisionTask < Task
		# Initialize the provision task.
		def initialize(*arguments, **options)
			super
			
			@dependencies = []
			
			@environments = []
			@public_environments = []
			
			@build_task = nil
		end
		
		attr :environments
		attr :public_environments
		
		attr :build_task
		
		# @returns [Build::Dependency::Provision] The provision being built by this task.
		def provision
			@node.provision
		end
		
		# Build all dependencies and then apply the provision.
		def update
			provision.each_dependency do |dependency|
				@dependencies << invoke(@node.dependency_node_for(dependency))
			end
			
			if wait_for_children?
				update_environments!
			else
				fail!(DependenciesFailed)
			end
		end
		
		# @returns [Build::Environment] The combined local environment for this provision.
		def local_environment
			Build::Environment.combine(@node.environment, *@environments)&.evaluate(name: @node.name).freeze
		end
		
		# @returns [Build::Environment | Nil] The output environment produced by the build task, if any.
		def output_environment
			if @build_task
				@build_task.output_environment.dup(parent: nil)
			end
		end
		
		# @returns [Array(Build::Environment)] All output environments including any public ones.
		def output_environments
			environments = @public_environments.dup
			
			if environment = self.output_environment
				environments << environment
			end
			
			return environments
		end
		
		private
		
		def update_environments!
			@dependencies.each do |task|
				if environment = task.environment
					@environments << environment
					
					if task.dependency.public? || @node.provision.alias?
						@public_environments << environment
					end
				end
			end
			
			unless @node.provision.alias?
				@build_task = invoke(
					BuildNode.new(local_environment, @node.provision, @node.arguments)
				)
			end
		end
	end
end
