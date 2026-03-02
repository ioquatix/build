# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2019, by Samuel Williams.

module Build
	# Represents a human-readable name with helpers for generating identifiers, target names, and macros.
	class Name
		# Initialize the name with the given text.
		# @parameter text [String] The human-readable name text.
		def initialize(text)
			@text = text
			
			@identifier = nil
			@target = nil
			@key = nil
		end
		
		# Construct a {Name} from a hyphen-separated target name string.
		# @parameter string [String] A target name such as `"foo-bar"`.
		# @returns [Build::Name] The corresponding name instance.
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
