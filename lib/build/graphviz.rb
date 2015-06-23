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

module Build
	def self.graph_visualisation(walker)
		viz = Graphviz::Graph.new('G', rankdir: "LR")
		
		walker.tasks.each do |node, task|
			input_nodes = []
			output_nodes = []
			
			task.inputs.each do |path|
				input_nodes << viz.add_node(path.basename)
			end
			
			task.outputs.each do |path|
				output_nodes << viz.add_node(path.basename)
			end
			
			if output_nodes.size == 1
				input_nodes.each do |input_node|
					edge = input_node.connect(output_nodes.first)
					edge.attributes[:label] = node.title
				end
			end
		end

		return viz
		#Graphviz::output(viz, path: ENV['BUILD_GRAPH_PDF']) rescue nil
		#`dot -Tpdf graph.dot > graph.pdf && open graph.pdf`
	end
end
