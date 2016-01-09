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
		def initialize(verbose: true)
			@start = Time.now
			@verbose = verbose
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
		
		def format_command(arguments)
			if arguments.last.is_a? Hash
				options = arguments.last
				arguments = arguments[0...-1]
			else
				options = {}
			end
			
			arguments = arguments.flatten.collect(&:to_s)
			
			Rainbow(arguments.join(' ')).blue + chdir_string(options)
		end
		
		def call(severity, datetime, progname, message)
			buffer = []
			
			if @verbose
				buffer << time_offset_string << ": "
			end
			
			if progname == 'shell' and Array === message
				buffer << format_command(message)
			else
				buffer << message
			end
			
			buffer << "\n"
			
			return buffer.join
		end
	end
end
