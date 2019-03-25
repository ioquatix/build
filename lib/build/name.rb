# Copyright, 2013, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

module Build
	class Name
		def initialize(text)
			@text = text
			
			@identifier = nil
			@target = nil
			@key = nil
		end
		
		def self.from_target(string)
			self.new(string.gsub(/(^|[ \-_])(.)/){" " + $2.upcase}.strip)
		end
		
		attr :text
		
		# @return [String] suitable for constant identifier.
		def identifier
			@identifier ||= @text.gsub(/\s+/, '')
		end
		
		# @return [String] suitable for target name.
		def target
			@target ||= @text.gsub(/\s+/, '-').downcase
		end
		
		# @return [String] suitable for variable name.
		def key(*postfix)
			@key ||= ([@text] + postfix).collect{|part| part.downcase.gsub(/\s+/, '_')}.join('_')
		end
		
		# @return [String] suitable for C macro name.
		def macro(prefix = [])
			(Array(prefix) + [@text]).collect{|name| name.upcase.gsub(/\s+/, '_')}.join('_')
		end
		
		# @return [String] suitable for C header guard macro.
		def header_guard(path)
			macro(path) + '_H'
		end
	end
end
