package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/nullishcoalescing.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.estransforms)
class NullishCoalescingTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded

	public function new() {}

	// PORT: promoted methods of the embedded transformers.Transformer.
	inline function Visitor():NodeVisitor return Transformer.Visitor();
	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();
	inline function EmitContext():EmitContext return Transformer.EmitContext();

	function visit(node:Node):Node {
		if ((node.SubtreeFacts() & SubtreeContainsNullishCoalescing) == 0) {
			return node;
		}
		switch (node.Kind) {
			case KindBinaryExpression:
				return visitBinaryExpression(node.AsBinaryExpression());
			default:
				return Visitor().VisitEachChild(node);
		}
	}

	function visitBinaryExpression(node:BinaryExpression):Node {
		switch (node.OperatorToken.Kind) {
			case KindQuestionQuestionToken:
				var left = Visitor().VisitNode(node.Left);
				var right = left;
				if (!Transformers.IsSimpleCopiableExpression(left)) {
					right = Factory().NewTempVariable();
					EmitContext().AddVariableDeclaration(right);
					left = Factory().NewAssignmentExpression(right, left);
				}
				return Factory().NewConditionalExpression(Estransforms.createNotNullCondition(EmitContext(), left, right, false),
					Factory().NewToken(KindQuestionToken), right, Factory().NewToken(KindColonToken), Visitor().VisitNode(node.Right));
			default:
				return Visitor().VisitEachChild(node.AsNode());
		}
	}
}
