# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2024, by Samuel Williams.

require "build/environment"
require "build/rulebook"

describe Build::Rulebook do
	it "should generate a valid rulebook" do
		environment = Build::Environment.new do
			define Build::Rule, "copy.file" do
				input :source
				output :destination
				
				apply do |parameters|
					cp parameters[:source], parameters[:destination]
				end
			end
			
			define Build::Rule, "delete.file" do
				input :target
				
				apply do |parameters|
					rm parameters[:target]
				end
			end
		end
		
		rulebook = Build::Rulebook.for(environment.flatten)
		
		expect(rulebook.rules.size).to be == 2
		
		expect(rulebook.rules).to be(:include?, "copy.file")
		expect(rulebook.rules).to be(:include?, "delete.file")
	end
end
