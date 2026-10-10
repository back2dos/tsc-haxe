package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/logicalassignment.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.estransforms)
class LogicalAssignmentTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded

	public function new() {}

	// PORT: promoted methods of the embedded transformers.Transformer.
	inline function Visitor():NodeVisitor return Transformer.Visitor();
	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();
	inline function EmitContext():EmitContext return Transformer.EmitContext();

	function visit(node:Node):Node {
		if ((node.SubtreeFacts() & SubtreeContainsLogicalAssignments) == 0) {
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
		var nonAssignmentOperator:Kind;
		switch (node.OperatorToken.Kind) {
			case KindBarBarEqualsToken:
				nonAssignmentOperator = KindBarBarToken;
			case KindAmpersandAmpersandEqualsToken:
				nonAssignmentOperator = KindAmpersandAmpersandToken;
			case KindQuestionQuestionEqualsToken:
				nonAssignmentOperator = KindQuestionQuestionToken;
			default:
				return Visitor().VisitEachChild(node.AsNode());
		}

		var left = Ast.SkipParentheses(Visitor().VisitNode(node.Left));
		var assignmentTarget = left;
		final right = Ast.SkipParentheses(Visitor().VisitNode(node.Right));

		if (Ast.IsAccessExpression(left)) {
			final propertyAccessTargetSimpleCopiable = Transformers.IsSimpleCopiableExpression(left.Expression());
			var propertyAccessTarget = left.Expression();
			var propertyAccessTargetAssignment = left.Expression();
			if (!propertyAccessTargetSimpleCopiable) {
				propertyAccessTarget = Factory().NewTempVariable();
				EmitContext().AddVariableDeclaration(propertyAccessTarget);
				propertyAccessTargetAssignment = Factory().NewAssignmentExpression(propertyAccessTarget, left.Expression());
			}

			if (Ast.IsPropertyAccessExpression(left)) {
				assignmentTarget = Factory().NewPropertyAccessExpression(propertyAccessTarget, null, left.Name(), NodeFlagsNone);
				left = Factory().NewPropertyAccessExpression(propertyAccessTargetAssignment, null, left.Name(), NodeFlagsNone);
			} else {
				final elementAccessArgumentSimpleCopiable = Transformers.IsSimpleCopiableExpression(left.AsElementAccessExpression().ArgumentExpression);
				var elementAccessArgument = left.AsElementAccessExpression().ArgumentExpression;
				var argumentExpr = elementAccessArgument;
				if (!elementAccessArgumentSimpleCopiable) {
					elementAccessArgument = Factory().NewTempVariable();
					EmitContext().AddVariableDeclaration(elementAccessArgument);
					argumentExpr = Factory().NewAssignmentExpression(elementAccessArgument, left.AsElementAccessExpression().ArgumentExpression);
				}

				assignmentTarget = Factory().NewElementAccessExpression(propertyAccessTarget, null, elementAccessArgument, NodeFlagsNone);
				left = Factory().NewElementAccessExpression(propertyAccessTargetAssignment, null, argumentExpr, NodeFlagsNone);
			}
		}

		return Factory().NewBinaryExpression(null, left, null, Factory().NewToken(nonAssignmentOperator),
			Factory().NewParenthesizedExpression(Factory().NewAssignmentExpression(assignmentTarget, right)));
	}
}
