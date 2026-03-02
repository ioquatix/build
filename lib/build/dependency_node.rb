# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019, by Samuel Williams.

require "build/graph"

require_relative "provision_node"

module Build
	class DependencyNode < Graph::Node
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
		
		def == other
			super and
				@chain == other.chain and
				@dependency == other.dependency and
				@environment == other.environment and
				@arguments == other.arguments
		end
		
		def hash
			super ^ @chain.hash ^ @dependency.hash ^ @environment.hash ^ @arguments.hash
		end
		
		def task_class(parent_task)
			DependencyTask
		end
		
		def name
			@dependency.name
		end
		
		def provisions
			@chain.resolved[@dependency]
		end
		
		def public?
			@dependency.public?
		end
		
		def provision_node_for(provision)
			ProvisionNode.new(@chain, provision, @environment, @arguments)
		end
	end
	
	module ProvisionsFailed
		def self.to_s
			"Failed to build all provisions!"
		end
	end
	
	class DependencyTask < Task
		def initialize(*arguments, **options)
			super
			
			@provisions = []
			
			@environments = nil
			@environment = nil
		end
		
		attr :environment
		
		def dependency
			@node.dependency
		end
		
		def update
			logger.debug(self) do |buffer|
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
