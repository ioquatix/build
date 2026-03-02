# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2024, by Samuel Williams.

require "build/rule"

describe Build::Rule do
	it "should validate input and output parameters" do
		rule = Build::Rule.new("compile", "cpp")
		
		rule.input :source
		rule.output :destination
		
		expect(rule.parameters.size).to be == 2
		
		expect(rule.applicable?(source: "foo", destination: "bar")).to be_truthy
		expect(rule.applicable?(source: "foo")).to be_falsey
	end
	
	it "respects false argument" do
		rule = Build::Rule.new("compile", "cpp")
		
		rule.parameter :install, default: true
		
		expect(
			rule.normalize({}, binding)
		).to be == {install: true}
		
		expect(
			rule.normalize({install: true}, binding)
		).to be == {install: true}
		
		expect(
			rule.normalize({install: false}, binding)
		).to be == {install: false}
	end
end
