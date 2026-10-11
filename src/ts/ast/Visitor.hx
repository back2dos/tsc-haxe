package ts.ast;

// Port of visitor.go (types and methods; NewNodeVisitor is in Ast.hx).

// NodeVisitor
@:allow(ts.ast)
class NodeVisitor {
	public var Visit:(node:Node) -> Node = null; // Required. The callback used to visit a node
	public var Factory:NodeFactory = null; // Required. The NodeFactory used to produce new nodes when passed to VisitEachChild
	public var Hooks:NodeVisitorHooks = new NodeVisitorHooks(); // Hooks to be invoked when visiting a node
	public var VisitSliceChanged:Bool = false; // PORT: perf — second result of VisitSlice

	public function new() {}

	public function VisitSourceFile(node:SourceFile):SourceFile {
		return VisitNode(node.AsNode()).AsSourceFile();
	}

	// Visits a Node, possibly returning a new Node in its place.
	//
	//   - If the input node is nil, then the output is nil.
	//   - If v.Visit is nil, then the output is the input.
	//   - If v.Visit returns nil, then the output is nil.
	//   - If v.Visit returns a SyntaxList Node, then the output is the only child of the SyntaxList Node.
	public function VisitNode(node:Node):Node {
		if (node == null || Visit == null) {
			return node;
		}

		if (Visit != null) {
			var visited = Visit(node);
			if (visited != null && visited.Kind == KindSyntaxList) {
				final nodes = visited.AsSyntaxList().Children;
				if (Core.len(nodes) != 1) {
					throw "Expected only a single node to be written to output";
				}
				visited = nodes[0];
				if (visited != null && visited.Kind == KindSyntaxList) {
					throw "The result of visiting and lifting a Node may not be SyntaxList";
				}
			}
			return visited;
		}

		return node;
	}

	// Visits an embedded Statement (i.e., the single statement body of a loop, `if..else` branch, etc.), possibly returning a new Statement in its place.
	//
	//   - If the input node is nil, then the output is nil.
	//   - If v.Visit is nil, then the output is the input.
	//   - If v.Visit returns nil, then the output is nil.
	//   - If v.Visit returns a SyntaxList Node, then the output is either the only child of the SyntaxList Node, or a Block containing the nodes in the list.
	public function VisitEmbeddedStatement(node:Statement):Statement {
		if (node == null || Visit == null) {
			return node;
		}

		final visited = Visit(node);
		if (visited == null) {
			return null;
		}
		return liftToBlock(visited);
	}

	// Visits a NodeList, possibly returning a new NodeList in its place.
	//
	//   - If the input NodeList is nil, the output is nil.
	//   - If v.Visit is nil, then the output is the input.
	//   - If v.Visit returns nil, the visited Node will be absent in the output.
	//   - If v.Visit returns a different Node than the input, a new NodeList will be generated and returned.
	//   - If v.Visit returns a SyntaxList Node, then the children of that node will be merged into the output and a new NodeList will be returned.
	//   - If this method returns a new NodeList for any reason, it will have the same Loc as the input NodeList.
	public function VisitNodes(nodes:NodeList):NodeList {
		if (nodes == null || Visit == null) {
			return nodes;
		}

		final r = VisitSlice(nodes.Nodes);
		if (VisitSliceChanged) {
			final list = Factory.NewNodeList(r);
			list.Loc = nodes.Loc;
			return list;
		}

		return nodes;
	}

	// Visits a ModifierList, possibly returning a new ModifierList in its place.
	//
	//   - If the input ModifierList is nil, the output is nil.
	//   - If v.Visit is nil, then the output is the input.
	//   - If v.Visit returns nil, the visited Node will be absent in the output.
	//   - If v.Visit returns a different Node than the input, a new ModifierList will be generated and returned.
	//   - If v.Visit returns a SyntaxList Node, then the children of that node will be merged into the output and a new NodeList will be returned.
	//   - If this method returns a new NodeList for any reason, it will have the same Loc as the input NodeList.
	public function VisitModifiers(nodes:ModifierList):ModifierList {
		if (nodes == null || Visit == null) {
			return nodes;
		}

		final r = VisitSlice(nodes.Nodes);
		if (VisitSliceChanged) {
			final list = Factory.NewModifierList(r);
			list.Loc = nodes.Loc;
			return list;
		}

		return nodes;
	}

	// Visits a slice of Nodes, returning the resulting slice and a value indicating whether the slice was changed.
	//
	//   - If the input slice is nil, the output is nil.
	//   - If v.Visit is nil, then the output is the input.
	//   - If v.Visit returns nil, the visited Node will be absent in the output.
	//   - If v.Visit returns a different Node than the input, a new slice will be generated and returned.
	//   - If v.Visit returns a SyntaxList Node, then the children of that node will be merged into the output and a new slice will be returned.
	// PORT: perf — Go returns (result []*Node, changed bool); changed is left in VisitSliceChanged, read by the caller right
	// after the call (no Pair per visited list).
	public function VisitSlice(nodes:Array<Node>):Array<Node> {
		if (nodes == null || Visit == null) {
			VisitSliceChanged = false;
			return nodes;
		}

		var i = 0;
		while (i < nodes.length) {
			var node = nodes[i];
			if (Visit == null) {
				break;
			}

			var visited = Visit(node);
			if (visited == null || visited != node) {
				final updated = nodes.slice(0, i);

				while (true) {
					// finish prior loop
					if (visited == null) {
						// do nothing
					} else if (visited.Kind == KindSyntaxList) {
						for (c in visited.AsSyntaxList().Children)
							updated.push(c);
					} else {
						updated.push(visited);
					}

					i++;

					// loop over remaining elements
					if (i >= nodes.length) {
						break;
					}

					if (Visit != null) {
						node = nodes[i];
						visited = Visit(node);
					} else {
						for (j in i...nodes.length)
							updated.push(nodes[j]);
						break;
					}
				}

				VisitSliceChanged = true;
				return updated;
			}
			i++;
		}

		VisitSliceChanged = false;
		return nodes;
	}

	// Visits each child of a Node, possibly returning a new Node of the same kind in its place.
	public function VisitEachChild(node:Node):Node {
		if (node == null || Visit == null) {
			return node;
		}

		return node.VisitEachChild(this);
	}

	function visitNode(node:Node):Node {
		if (Hooks.VisitNode != null) {
			return Hooks.VisitNode(node, this);
		}
		return VisitNode(node);
	}

	function visitEmbeddedStatement(node:Node):Node {
		if (Hooks.VisitEmbeddedStatement != null) {
			return Hooks.VisitEmbeddedStatement(node, this);
		}
		if (Hooks.VisitNode != null) {
			return liftToBlock(Hooks.VisitNode(node, this));
		}
		return VisitEmbeddedStatement(node);
	}

	function visitIterationBody(node:Statement):Statement {
		if (Hooks.VisitIterationBody != null) {
			return Hooks.VisitIterationBody(node, this);
		}
		return visitEmbeddedStatement(node);
	}

	function visitFunctionBody(node:BlockOrExpression):BlockOrExpression {
		if (Hooks.VisitFunctionBody != null) {
			return Hooks.VisitFunctionBody(node, this);
		}
		return visitNode(node);
	}

	function visitToken(node:Node):Node {
		if (Hooks.VisitToken != null) {
			return Hooks.VisitToken(node, this);
		}
		return VisitNode(node);
	}

	function visitNodes(nodes:NodeList):NodeList {
		if (Hooks.VisitNodes != null) {
			return Hooks.VisitNodes(nodes, this);
		}
		return VisitNodes(nodes);
	}

	function visitModifiers(nodes:ModifierList):ModifierList {
		if (Hooks.VisitModifiers != null) {
			return Hooks.VisitModifiers(nodes, this);
		}
		return VisitModifiers(nodes);
	}

	function visitParameters(nodes:ParameterList):ParameterList {
		if (Hooks.VisitParameters != null) {
			return Hooks.VisitParameters(nodes, this);
		}
		return visitNodes(nodes);
	}

	function visitTopLevelStatements(nodes:StatementList):StatementList {
		if (Hooks.VisitTopLevelStatements != null) {
			return Hooks.VisitTopLevelStatements(nodes, this);
		}
		return visitNodes(nodes);
	}

	function liftToBlock(node:Statement):Statement {
		var nodes:Array<Node> = null;
		if (node != null) {
			if (node.Kind == KindSyntaxList) {
				nodes = node.AsSyntaxList().Children;
			} else {
				nodes = [node];
			}
		}
		if (Core.len(nodes) == 1) {
			node = nodes[0];
		} else {
			node = Factory.NewBlock(Factory.NewNodeList(nodes), true /*multiLine*/);
		}
		if (node.Kind == KindSyntaxList) {
			throw "The result of visiting and lifting a Node may not be SyntaxList";
		}
		return node;
	}
}

// These hooks are used to intercept the default behavior of the visitor
class NodeVisitorHooks {
	public var VisitNode:(node:Node, v:NodeVisitor) -> Node = null; // Overrides visiting a Node. Only invoked by the VisitEachChild method on a given Node subtype.
	public var VisitToken:(node:TokenNode, v:NodeVisitor) -> Node = null; // Overrides visiting a TokenNode. Only invoked by the VisitEachChild method on a given Node subtype.
	public var VisitNodes:(nodes:NodeList, v:NodeVisitor) -> NodeList = null; // Overrides visiting a NodeList. Only invoked by the VisitEachChild method on a given Node subtype.
	public var VisitModifiers:(nodes:ModifierList, v:NodeVisitor) -> ModifierList = null; // Overrides visiting a ModifierList. Only invoked by the VisitEachChild method on a given Node subtype.
	public var VisitEmbeddedStatement:(node:Statement, v:NodeVisitor) -> Statement = null; // Overrides visiting a Node when it is the embedded statement body of an iteration statement, `if` statement, or `with` statement. Only invoked by the VisitEachChild method on a given Node subtype.
	public var VisitIterationBody:(node:Statement, v:NodeVisitor) -> Statement = null; // Overrides visiting a Node when it is the embedded statement body of an iteration statement. Only invoked by the VisitEachChild method on a given Node subtype.
	public var VisitParameters:(nodes:ParameterList, v:NodeVisitor) -> ParameterList = null; // Overrides visiting a ParameterList. Only invoked by the VisitEachChild method on a given Node subtype.
	public var VisitFunctionBody:(node:BlockOrExpression, v:NodeVisitor) -> BlockOrExpression = null; // Overrides visiting a function body. Only invoked by the VisitEachChild method on a given Node subtype.
	public var VisitTopLevelStatements:(nodes:StatementList, v:NodeVisitor) -> StatementList = null; // Overrides visiting a variable environment. Only invoked by the VisitEachChild method on a given Node subtype.

	public function new() {}
}
