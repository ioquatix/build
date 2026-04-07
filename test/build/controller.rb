# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2026, by Samuel Williams.

require "tmpdir"
require "build/rulebook"
require "build/controller"

require "build/target"

describe Build::Controller do
	let(:base) {Build::Environment.new(name: "base")}
	
	with "failure exit status" do
		let(:make_target) do
			Target.new("make") do |target|
				target.provides "make" do
					define Build::Rule, "make.file" do
						output :destination
						
						apply do |parameters|
							run! "exit -1"
						end
					end
				end
			end
		end
		
		let(:build_target) do
			Target.new("foo") do |target|
				target.depends "make"
				
				target.provides "foo" do
					foo_path = Build::Files::Path["foo"]
					
					make destination: foo_path
				end
			end
		end
		
		it "build graph should fail" do
			chain = Build::Dependency::Chain.expand(["foo"], [make_target, build_target])
			
			controller = Build::Controller.build do |builder|
				builder.add_chain(chain, [], base)
			end
			
			controller.update
			
			expect(controller.failed?).to be_truthy
		end
	end
	
	with "copying files" do
		let(:files_target) do
			Target.new("files") do |target|
				target.provides "files" do
					define Build::Rule, "make.file" do
						output :destination
						
						apply do |parameters|
							run! "sleep 0.1"
							touch parameters[:destination]
						end
					end
					
					define Build::Rule, "copy.file" do
						input :source
						output :destination
						
						apply do |parameters|
							cp parameters[:source], parameters[:destination]
						end
					end
				end
			end
		end
		
		let(:build_target) do
			Target.new("build") do |target|
				target.depends "files"
				
				target.provides "foo" do
					foo_path = Build::Files::Path["foo"]
					bar_path = Build::Files::Path["bar"]
					
					make destination: foo_path
					copy source: foo_path, destination: bar_path
				end
			end
		end
		
		around do |&block|
			Dir.mktmpdir do |tmpdir|
				Dir.chdir(tmpdir) do
					block.call
				end
			end
		end
		
		it "should execute the build graph" do
			chain = Build::Dependency::Chain.expand(["foo"], [files_target, build_target])
			
			controller = Build::Controller.build do |builder|
				builder.add_chain(chain, [], base)
			end
			
			expect(controller.nodes.size).to be == 1
			
			controller.update
			
			expect(File).to be(:exist?, "foo")
			expect(File).to be(:exist?, "bar")
		end
	end
end
