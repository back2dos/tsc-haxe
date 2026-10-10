package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/optionalchain.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.estransforms)
class OptionalChainTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded

	public function new() {}

	// PORT: promoted methods of the embedded transformers.Transformer.
	inline function Visitor():NodeVisitor return Transformer.Visitor();
	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();
	inline function EmitContext():EmitContext return Transformer.EmitContext();

	function visit(node:Node):Node {
		if ((node.SubtreeFacts() & SubtreeContainsOptionalChaining) == 0) {
			return node;
		}
		switch (node.Kind) {
			case KindCallExpression:
				return visitCallExpression(node.AsCallExpression(), false);
			case KindPropertyAccessExpression, KindElementAccessExpression:
				if ((node.Flags & NodeFlagsOptionalChain) != 0) {
					return visitOptionalExpression(node, false, false);
				}
				return Visitor().VisitEachChild(node);
			case KindDeleteExpression:
				return visitDeleteExpression(node.AsDeleteExpression());
			default:
				return Visitor().VisitEachChild(node);
		}
	}

	function visitCallExpression(node:CallExpression, captureThisArg:Bool):Node {
		if ((node.Flags & NodeFlagsOptionalChain) != 0) {
			// If `node` is an optional chain, then it is the outermost chain of an optional expression.
			return visitOptionalExpression(node.AsNode(), captureThisArg, false);
		}
		if (Ast.IsParenthesizedExpression(node.Expression)) {
			final unwrapped = Ast.SkipParentheses(node.Expression);
			if ((unwrapped.Flags & NodeFlagsOptionalChain) != 0) {
				// capture thisArg for calls of parenthesized optional chains like `(foo?.bar)()`
				final expression = visitParenthesizedExpression(node.Expression.AsParenthesizedExpression(), true, false);
				final args = Visitor().VisitNodes(node.Arguments);
				if (Ast.IsSyntheticReferenceExpression(expression)) {
					final res = Factory().NewFunctionCallCall(expression.AsSyntheticReferenceExpression().Expression,
						expression.AsSyntheticReferenceExpression().ThisArg, args.Nodes);
					res.Loc = node.Loc;
					EmitContext().SetOriginal(res, node.AsNode());
					return res;
				}
				return Factory().UpdateCallExpression(node, expression, null /*questionDotToken*/, null /*typeArguments*/, args, node.Flags);
			}
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitParenthesizedExpression(node:ParenthesizedExpression, captureThisArg:Bool, isDelete:Bool):Node {
		final expr = visitNonOptionalExpression(node.Expression, captureThisArg, isDelete);
		if (Ast.IsSyntheticReferenceExpression(expr)) {
			// `(a.b)` -> { expression `((_a = a).b)`, thisArg: `_a` }
			// `(a[b])` -> { expression `((_a = a)[b])`, thisArg: `_a` }
			final synth = expr.AsSyntheticReferenceExpression();
			final res = Factory().NewSyntheticReferenceExpression(Factory().UpdateParenthesizedExpression(node, synth.Expression), synth.ThisArg);
			EmitContext().SetOriginal(res, node.AsNode());
			return res;
		}
		return Factory().UpdateParenthesizedExpression(node, expr);
	}

	function visitPropertyOrElementAccessExpression(node:Expression, captureThisArg:Bool, isDelete:Bool):Expression {
		if ((node.Flags & NodeFlagsOptionalChain) != 0) {
			// If `node` is an optional chain, then it is the outermost chain of an optional expression.
			return visitOptionalExpression(node.AsNode(), captureThisArg, isDelete);
		}
		var expression = Visitor().VisitNode(node.Expression());
		Debug.Assert(expression == null || !Ast.IsSyntheticReferenceExpression(expression));

		var thisArg:Expression = null;
		if (captureThisArg) {
			if (!Transformers.IsSimpleCopiableExpression(expression)) {
				thisArg = Factory().NewTempVariable();
				EmitContext().AddVariableDeclaration(thisArg);
				expression = Factory().NewAssignmentExpression(thisArg, expression);
			} else {
				thisArg = expression;
			}
		}

		if (node.Kind == KindPropertyAccessExpression) {
			final p = node.AsPropertyAccessExpression();
			expression = Factory().UpdatePropertyAccessExpression(p, expression, null /*questionDotToken*/, Visitor().VisitNode(p.Name()), p.Flags);
		} else {
			final p = node.AsElementAccessExpression();
			expression = Factory().UpdateElementAccessExpression(p, expression, null, Visitor().VisitNode(p.AsNode().AsElementAccessExpression().ArgumentExpression), p.Flags);
		}

		if (thisArg != null) {
			final res = Factory().NewSyntheticReferenceExpression(expression, thisArg);
			EmitContext().SetOriginal(res, node.AsNode());
			return res;
		}
		return expression;
	}

	function visitDeleteExpression(node:DeleteExpression):Node {
		final unwrapped = Ast.SkipParentheses(node.Expression);
		if ((unwrapped.Flags & NodeFlagsOptionalChain) != 0) {
			return visitNonOptionalExpression(node.Expression, false, true);
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitNonOptionalExpression(node:Expression, captureThisArg:Bool, isDelete:Bool):Expression {
		switch (node.Kind) {
			case KindParenthesizedExpression:
				return visitParenthesizedExpression(node.AsParenthesizedExpression(), captureThisArg, isDelete);
			case KindElementAccessExpression, KindPropertyAccessExpression:
				return visitPropertyOrElementAccessExpression(node, captureThisArg, isDelete);
			case KindCallExpression:
				return visitCallExpression(node.AsCallExpression(), captureThisArg);
			default:
				return Visitor().VisitNode(node.AsNode());
		}
	}

	function visitOptionalExpression(node:Node, captureThisArg:Bool, isDelete:Bool):Node {
		final r = Estransforms.flattenChain(node);
		final expression = r.expression;
		final chain = r.chain;
		final left = visitNonOptionalExpression(Ast.SkipPartiallyEmittedExpressions(expression), Estransforms.isCallChain(chain[0]), false);
		var leftThisArg:Expression = null;
		var capturedLeft = left;
		if (Ast.IsSyntheticReferenceExpression(left)) {
			leftThisArg = left.AsSyntheticReferenceExpression().ThisArg;
			capturedLeft = left.AsSyntheticReferenceExpression().Expression;
		}
		var leftExpression = Factory().RestoreOuterExpressions(expression, capturedLeft, OEKPartiallyEmittedExpressions);
		if (!Transformers.IsSimpleCopiableExpression(capturedLeft)) {
			capturedLeft = Factory().NewTempVariable();
			EmitContext().AddVariableDeclaration(capturedLeft);
			leftExpression = Factory().NewAssignmentExpression(capturedLeft, leftExpression);
		}
		var rightExpression = capturedLeft;
		var thisArg:Expression = null;

		for (i in 0...chain.length) {
			final segment = chain[i];
			switch (segment.Kind) {
				case KindElementAccessExpression, KindPropertyAccessExpression:
					if (i == chain.length - 1 && captureThisArg) {
						if (!Transformers.IsSimpleCopiableExpression(rightExpression)) {
							thisArg = Factory().NewTempVariable();
							EmitContext().AddVariableDeclaration(thisArg);
							rightExpression = Factory().NewAssignmentExpression(thisArg, rightExpression);
						} else {
							thisArg = rightExpression;
						}
					}
					if (segment.Kind == KindElementAccessExpression) {
						rightExpression = Factory().NewElementAccessExpression(rightExpression, null,
							Visitor().VisitNode(segment.AsElementAccessExpression().ArgumentExpression), NodeFlagsNone);
					} else {
						rightExpression = Factory().NewPropertyAccessExpression(rightExpression, null,
							Visitor().VisitNode(segment.AsPropertyAccessExpression().Name()), NodeFlagsNone);
					}
				case KindCallExpression:
					if (i == 0 && leftThisArg != null) {
						if (!EmitContext().HasAutoGenerateInfo(leftThisArg)) {
							leftThisArg = leftThisArg.Clone(Factory());
							EmitContext().AddEmitFlags(leftThisArg, EFNoComments);
						}
						var callThisArg = leftThisArg;
						if (leftThisArg.Kind == KindSuperKeyword) {
							callThisArg = Factory().NewThisExpression();
						}
						rightExpression = Factory().NewFunctionCallCall(rightExpression, callThisArg, Visitor().VisitNodes(segment.ArgumentList()).Nodes);
					} else {
						rightExpression = Factory().NewCallExpression(rightExpression, null, null, Visitor().VisitNodes(segment.ArgumentList()), NodeFlagsNone);
					}
				default:
			}
			EmitContext().SetOriginal(rightExpression, segment);
		}

		var target:Node = null;
		if (isDelete) {
			target = Factory().NewConditionalExpression(Estransforms.createNotNullCondition(EmitContext(), leftExpression, capturedLeft, true),
				Factory().NewToken(KindQuestionToken), Factory().NewTrueExpression(), Factory().NewToken(KindColonToken),
				Factory().NewDeleteExpression(rightExpression));
		} else {
			target = Factory().NewConditionalExpression(Estransforms.createNotNullCondition(EmitContext(), leftExpression, capturedLeft, true),
				Factory().NewToken(KindQuestionToken), Factory().NewVoidZeroExpression(), Factory().NewToken(KindColonToken), rightExpression);
		}
		target.Loc = node.Loc;
		if (thisArg != null) {
			target = Factory().NewSyntheticReferenceExpression(target, thisArg);
		}
		EmitContext().SetOriginal(target, node.AsNode());
		return target;
	}
}

@:allow(ts.transformers.estransforms)
class FlattenResult {
	var expression:Expression = null;
	var chain:Array<Node> = null;

	public function new() {}
}
