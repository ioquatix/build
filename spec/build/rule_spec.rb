# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'build/rule'

RSpec.describe Build::Rule do
	it "should validate input and output parameters" do
		rule = Build::Rule.new("compile", "cpp")
		
		rule.input :source
		rule.output :destination
		
		expect(rule.parameters.size).to be 2
		
		expect(rule.applicable?(source: 'foo', destination: 'bar')).to be_truthy
		expect(rule.applicable?(source: 'foo')).to be_falsey
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
