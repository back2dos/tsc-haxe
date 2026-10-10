package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/exponentiation.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.estransforms)
class ExponentiationTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded

	public function new() {}

	// PORT: promoted methods of the embedded transformers.Transformer.
	inline function Visitor():NodeVisitor return Transformer.Visitor();
	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();
	inline function EmitContext():EmitContext return Transformer.EmitContext();

	function visit(node:Node):Node {
		if ((node.SubtreeFacts() & SubtreeContainsExponentiationOperator) == 0) {
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
			case KindAsteriskAsteriskEqualsToken:
				return visitExponentiationAssignmentExpression(node);
			case KindAsteriskAsteriskToken:
				return visitExponentiationExpression(node);
			default:
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitExponentiationAssignmentExpression(node:BinaryExpression):Node {
		var target:Node = null;
		var value:Node = null;
		final left = Visitor().VisitNode(node.Left);
		final right = Visitor().VisitNode(node.Right);
		if (Ast.IsElementAccessExpression(left)) {
			// Transforms `a[x] **= b` into `(_a = a)[_x = x] = Math.pow(_a[_x], b)`
			final expressionTemp = Factory().NewTempVariable();
			EmitContext().AddVariableDeclaration(expressionTemp);
			final argumentExpressionTemp = Factory().NewTempVariable();
			EmitContext().AddVariableDeclaration(argumentExpressionTemp);

			final objExpr = Factory().NewAssignmentExpression(expressionTemp, left.Expression());
			objExpr.Loc = left.Expression().Loc;
			final accessExpr = Factory().NewAssignmentExpression(argumentExpressionTemp, left.AsElementAccessExpression().ArgumentExpression);
			accessExpr.Loc = left.AsElementAccessExpression().ArgumentExpression.Loc;

			target = Factory().NewElementAccessExpression(objExpr, null, accessExpr, NodeFlagsNone);

			value = Factory().NewElementAccessExpression(expressionTemp, null, argumentExpressionTemp, NodeFlagsNone);
			value.Loc = left.Loc;
		} else if (Ast.IsPropertyAccessExpression(left)) {
			// Transforms `a.x **= b` into `(_a = a).x = Math.pow(_a.x, b)`
			final expressionTemp = Factory().NewTempVariable();
			EmitContext().AddVariableDeclaration(expressionTemp);
			final assignment = Factory().NewAssignmentExpression(expressionTemp, left.Expression());
			assignment.Loc = left.Expression().Loc;
			target = Factory().NewPropertyAccessExpression(assignment, null, left.Name(), NodeFlagsNone);
			target.Loc = left.Loc;

			value = Factory().NewPropertyAccessExpression(expressionTemp, null, left.Name(), NodeFlagsNone);
			value.Loc = left.Loc;
		} else {
			// Transforms `a **= b` into `a = Math.pow(a, b)`
			target = left;
			value = left;
		}

		final rhs = Factory().NewGlobalMethodCall("Math", "pow", [value, right]);
		rhs.Loc = node.Loc;
		final result = Factory().NewAssignmentExpression(target, rhs);
		result.Loc = node.Loc;
		return result;
	}

	function visitExponentiationExpression(node:BinaryExpression):Node {
		final left = Visitor().VisitNode(node.Left);
		final right = Visitor().VisitNode(node.Right);
		final result = Factory().NewGlobalMethodCall("Math", "pow", [left, right]);
		result.Loc = node.Loc;
		return result;
	}
}
