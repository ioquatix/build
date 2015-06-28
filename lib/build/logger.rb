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

require 'logger'
require 'rainbow'

module Build
	class CompactFormatter
		def initialize
			@start = Time.now
		end
		
		def time_offset_string
			offset = Time.now - @start
			
			"T+#{offset.round(2).to_s.ljust(5)}"
		end
		
		def chdir_string(options)
			if options[:chdir]
				" in #{options[:chdir]}"
			else
				""
			end
		end
		
		def format_command(args)
			options = Hash === args.last ? args.pop : {}
			args = args.flatten.collect &:to_s
			
			Rainbow(args.join(' ')).blue + chdir_string(options)
		end
		
		def call(severity, datetime, progname, msg)
			if progname == 'shell' and Array === msg
				"#{time_offset_string}: #{format_command(msg)}\n"
			else
				"#{time_offset_string}: #{msg}\n"
			end
		end
	end
end
