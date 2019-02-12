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

RSpec.describe Build::Controller do
	it "build graph should fail" do
		rules = Build::Environment.new do
			define Build::Rule, "make.file" do
				output :destination
				
				apply do |parameters|
					run! "exit -1"
				end
			end
		end
		
		target = Build::Environment.new(rules) do |graph|
			foo_path = Build::Files::Path['foo']
			
			graph.make destination: foo_path
		end
		
		controller = Build::Controller.new do |controller|
			controller.add_environment(target)
		end
		
		controller.logger.level = Logger::DEBUG
		
		controller.update
		
		expect(controller.failed?).to be_truthy
	end
	
	it "should execute the build graph" do
		rules = Build::Environment.new do
			define Build::Rule, "make.file" do
				output :destination
				
				apply do |parameters|
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
		
		target = Build::Environment.new(rules) do |graph|
			foo_path = Build::Files::Path['foo']
			bar_path = Build::Files::Path['bar']
			
			graph.make destination: foo_path
			graph.copy source: foo_path, destination: bar_path
		end
		
		controller = Build::Controller.new do |controller|
			controller.add_environment(target)
		end
		
		expect(controller.nodes.size).to be 1
		
		controller.update
		
		expect(File).to be_exist('foo')
		expect(File).to be_exist('bar')
		
		FileUtils.rm ['foo', 'bar']
	end
end
