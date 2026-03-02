# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015, by Samuel Williams.

module Build
	def self.graph_visualisation(walker)
		graph = Graphviz::Graph.new("G", rankdir: "LR")
		
		walker.tasks.each do |node, task|
			input_nodes = []
			output_nodes = []
			
			task.inputs.each do |path|
				input_nodes << graph.add_node(path.basename)
			end
			
			task.outputs.each do |path|
				output_nodes << graph.add_node(path.basename)
			end
			
			if output_nodes.size == 1
				input_nodes.each do |input_node|
					edge = input_node.connect(output_nodes.first)
					edge.attributes[:label] = node.title
				end
			end
		end
		
		return graph
	end
end
