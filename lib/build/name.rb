# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2019, by Samuel Williams.

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
			@identifier ||= @text.gsub(/\s+/, "")
		end
		
		# @return [String] suitable for target name.
		def target
			@target ||= @text.gsub(/\s+/, "-").downcase
		end
		
		# @return [String] suitable for variable name.
		def key(*postfix)
			@key ||= ([@text] + postfix).collect{|part| part.downcase.gsub(/\s+/, "_")}.join("_")
		end
		
		# @return [String] suitable for C macro name.
		def macro(prefix = [])
			(Array(prefix) + [@text]).collect{|name| name.upcase.gsub(/\s+/, "_")}.join("_")
		end
		
		# @return [String] suitable for C header guard macro.
		def header_guard(path)
			macro(path) + "_H"
		end
	end
end
