#!/usr/bin/env rspec

# Copyright, 2015, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'build/rulebook'
require 'build/controller'

require_relative 'target'

RSpec.describe Build::Controller do
	let(:base) {Build::Environment.new(name: "base")}
	
	context "failure exit status" do
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
					foo_path = Build::Files::Path['foo']
					
					make destination: foo_path
				end
			end
		end
		
		it "build graph should fail" do
			chain = Build::Dependency::Chain.expand(["foo"], [make_target, build_target])
			
			controller = Build::Controller.new do |controller|
				controller.add_chain(chain, [], base)
			end
			
			controller.logger.level = Logger::DEBUG
			
			controller.update
			
			expect(controller.failed?).to be_truthy
		end
	end
	
	context "copying files" do
		let(:files_target) do
			Target.new("files") do |target|
				target.provides "files" do
					define Build::Rule, "make.file" do
						output :destination
						
						apply do |parameters|
							run! 'sleep 0.1'
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
					foo_path = Build::Files::Path['foo']
					bar_path = Build::Files::Path['bar']
					
					make destination: foo_path
					copy source: foo_path, destination: bar_path
				end
			end
		end
		
		it "should execute the build graph" do
			chain = Build::Dependency::Chain.expand(["foo"], [files_target, build_target])
			
			controller = Build::Controller.new do |controller|
				controller.add_chain(chain, [], base)
			end
			
			expect(controller.nodes.size).to be 1
			
			controller.update
			
			expect(File).to be_exist('foo')
			expect(File).to be_exist('bar')
			
			FileUtils.rm ['foo', 'bar']
		end
	end
end
