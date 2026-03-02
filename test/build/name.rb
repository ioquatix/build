# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2024, by Samuel Williams.

require "build/name"

describe Build::Name do
	let(:name) {Build::Name.new("Foo Bar")}
	
	it "retains the original text" do
		expect(name.text).to be == "Foo Bar"
	end
	
	it "should generate useful identifiers" do
		expect(name.identifier).to be == "FooBar"
	end
	
	it "should generate useful target names" do
		expect(name.target).to be == "foo-bar"
	end
	
	it "should generate useful key names" do
		expect(name.key("executable")).to be == "foo_bar_executable"
	end
	
	it "should generate useful macro names" do
		expect(name.macro).to be == "FOO_BAR"
	end
	
	it "can be constructed from target name" do
		expect(Build::Name.from_target(name.target).text).to be == name.text
	end
end
