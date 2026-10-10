package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/optionalcatch.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.estransforms)
class OptionalCatchTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded

	public function new() {}

	// PORT: promoted methods of the embedded transformers.Transformer.
	inline function Visitor():NodeVisitor return Transformer.Visitor();
	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();
	inline function EmitContext():EmitContext return Transformer.EmitContext();

	function visit(node:Node):Node {
		if ((node.SubtreeFacts() & SubtreeContainsMissingCatchClauseVariable) == 0) {
			return node;
		}
		switch (node.Kind) {
			case KindCatchClause:
				return visitCatchClause(node.AsCatchClause());
			default:
				return Visitor().VisitEachChild(node);
		}
	}

	function visitCatchClause(node:CatchClause):Node {
		if (node.VariableDeclaration == null) {
			return Factory().NewCatchClause(Factory().NewVariableDeclaration(Factory().NewTempVariable(), null, null, null),
				Visitor().Visit(node.Block));
		}
		return Visitor().VisitEachChild(node.AsNode());
	}
}
