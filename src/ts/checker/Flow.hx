package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/flow.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).
//
// PORT: FlowType is a Go value struct. It is never mutated after construction here, so instances
// are shared freely; the Go zero value `FlowType{}` is the shared `FlowType.nil` instance.
//
// Struct map keys use the `keyOf` helpers next to the key types in Checker.hx.

@:allow(ts.checker)
class FlowType {
	var t:Type = null;
	var incomplete:Bool = false;

	public function new() {}

	function isNil():Bool {
		return t == null;
	}

	// PORT: Go `FlowType{}` (shared, immutable).
	static final nil:FlowType = new FlowType();

	// PORT: Go composite literal `FlowType{t: t, incomplete: incomplete}`.
	// PORT: perf — FlowType is immutable (a Go value): one per type and flag, kept on the type.
	static inline function of(t:Type, incomplete:Bool):FlowType {
		return t == null ? make(t, incomplete) : incomplete ? ofIncomplete(t) : ofComplete(t);
	}

	static function ofComplete(t:Type):FlowType {
		var ft:FlowType = @:privateAccess t.flowType;
		if (ft == null) {
			ft = make(t, false);
			@:privateAccess t.flowType = ft;
		}
		return ft;
	}

	static function ofIncomplete(t:Type):FlowType {
		var ft:FlowType = @:privateAccess t.flowTypeIncomplete;
		if (ft == null) {
			ft = make(t, true);
			@:privateAccess t.flowTypeIncomplete = ft;
		}
		return ft;
	}

	static function make(t:Type, incomplete:Bool):FlowType {
		final ft = new FlowType();
		ft.t = t;
		ft.incomplete = incomplete;
		return ft;
	}
}

@:allow(ts.checker)
class SharedFlow {
	var flow:FlowNode = null;
	var flowType:FlowType = new FlowType();

	public function new() {}
}

@:allow(ts.checker)
class FlowState {
	var reference:Node = null;
	var declaredType:Type = null;
	var initialType:Type = null;
	var flowContainer:Node = null;
	var refKey:CacheHashKey = new CacheHashKey();
	var depth:Int = 0;
	var sharedFlowStart:Int = 0;
	var reduceLabels:Array<FlowReduceLabelData> = null;
	var next:FlowState = null;

	public function new() {}
}

// Methods of flow.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Flow {
	// PORT: Go `==` on CacheHashKey values.
	static inline function sameCacheHashKey(a:CacheHashKey, b:CacheHashKey):Bool {
		return a.s == b.s;
	}

	// slices.Contains(s[start:], t)
	static function containsTypeFrom(s:Array<Type>, start:Int, t:Type):Bool {
		if (s == null) {
			return false;
		}
		for (i in start...s.length) {
			if (s[i] == t) {
				return true;
			}
		}
		return false;
	}

	static function newFlowType(c:Checker, t:Type, incomplete:Bool):FlowType {
		if (incomplete && (t.flags & TypeFlagsNever) != 0) {
			t = c.silentNeverType;
		}
		return FlowType.of(t, incomplete);
	}

	static function getFlowState(c:Checker):FlowState {
		var f = c.freeFlowState;
		if (f == null) {
			f = new FlowState();
		}
		c.freeFlowState = f.next;
		return f;
	}

	static function putFlowState(c:Checker, f:FlowState):Void {
		final reduceLabels = f.reduceLabels;
		if (reduceLabels != null) {
			reduceLabels.resize(0);
		}
		f.reference = null;
		f.declaredType = null;
		f.initialType = null;
		f.flowContainer = null;
		f.refKey = new CacheHashKey();
		f.depth = 0;
		f.sharedFlowStart = 0;
		f.reduceLabels = reduceLabels;
		f.next = c.freeFlowState;
		c.freeFlowState = f;
	}

	static function getFlowTypeOfReference(c:Checker, reference:Node, declaredType:Type):Type {
		return c.getFlowTypeOfReferenceEx(reference, declaredType, declaredType, null, null);
	}

	static function getFlowTypeOfReferenceEx(c:Checker, reference:Node, declaredType:Type, initialType:Type, flowContainer:Node, flowNode:FlowNode):Type {
		if (c.flowAnalysisDisabled) {
			return c.errorType;
		}
		if (flowNode == null) {
			flowNode = Checker.getFlowNodeOfNode(reference);
			if (flowNode == null) {
				return declaredType;
			}
		}
		final f = c.getFlowState();
		f.reference = reference;
		f.declaredType = declaredType;
		f.initialType = Core.Coalesce(initialType, declaredType);
		f.flowContainer = flowContainer;
		f.sharedFlowStart = Core.len(c.sharedFlows);
		c.flowInvocationCount++;
		final evolvedType = c.getTypeAtFlowNode(f, flowNode).t;
		if (c.sharedFlows != null) {
			c.sharedFlows.resize(f.sharedFlowStart);
		}
		c.putFlowState(f);
		// When the reference is 'x' in an 'x.length', 'x.push(value)', 'x.unshift(value)' or x[n] = value' operation,
		// we give type 'any[]' to 'x' instead of using the type determined by control flow analysis such that operations
		// on empty arrays are possible without implicit any errors and new element types can be inferred without
		// type mismatch errors.
		var resultType:Type;
		if ((evolvedType.objectFlags & ObjectFlagsEvolvingArray) != 0 && c.isEvolvingArrayOperationTarget(reference)) {
			resultType = c.autoArrayType;
		} else {
			resultType = c.finalizeEvolvingArrayType(evolvedType);
		}
		if (resultType == c.unreachableNeverType
			|| reference.Parent != null && Ast.IsNonNullExpression(reference.Parent) && (resultType.flags & TypeFlagsNever) == 0
			&& (c.getTypeWithFacts(resultType, TypeFactsNEUndefinedOrNull).flags & TypeFlagsNever) != 0) {
			return declaredType;
		}
		return resultType;
	}

	static function getTypeAtFlowNode(c:Checker, f:FlowState, flow:FlowNode):FlowType {
		if (f.depth == 2000) {
			// We have made 2000 recursive invocations. To avoid overflowing the call stack we report an error
			// and disable further control flow analysis in the containing function or module body.
			final tr = c.tracer;
			if (tr != null) {
				final args = new StringMap<Any>();
				args.set("depth", f.depth);
				tr.Instant(PhaseCheckTypes, "getTypeAtFlowNode_DepthLimit", args);
			}
			c.flowAnalysisDisabled = true;
			c.reportFlowControlError(f.reference);
			return FlowType.of(c.errorType, false);
		}
		f.depth++;
		var sharedFlow:FlowNode = null;
		while (true) {
			final flags = flow.Flags;
			if ((flags & FlowFlagsShared) != 0) {
				// We cache results of flow type resolution for shared nodes that were previously visited in
				// the same getFlowTypeOfReference invocation. A node is considered shared when it is the
				// antecedent of more than one node.
				for (i in f.sharedFlowStart...Core.len(c.sharedFlows)) {
					if (c.sharedFlows[i].flow == flow) {
						f.depth--;
						return c.sharedFlows[i].flowType;
					}
				}
				sharedFlow = flow;
			}
			var t:FlowType;
			if ((flags & FlowFlagsAssignment) != 0) {
				t = c.getTypeAtFlowAssignment(f, flow);
				if (t.isNil()) {
					flow = flow.Antecedent;
					continue;
				}
			} else if ((flags & FlowFlagsCall) != 0) {
				t = c.getTypeAtFlowCall(f, flow);
				if (t.isNil()) {
					flow = flow.Antecedent;
					continue;
				}
			} else if ((flags & FlowFlagsCondition) != 0) {
				t = c.getTypeAtFlowCondition(f, flow);
			} else if ((flags & FlowFlagsSwitchClause) != 0) {
				t = c.getTypeAtSwitchClause(f, flow);
			} else if ((flags & FlowFlagsBranchLabel) != 0) {
				final antecedents = Checker.getBranchLabelAntecedents(flow, f.reduceLabels);
				if (antecedents.Next == null) {
					flow = antecedents.Flow;
					continue;
				}
				t = c.getTypeAtFlowBranchLabel(f, flow, antecedents);
			} else if ((flags & FlowFlagsLoopLabel) != 0) {
				if (flow.Antecedents.Next == null) {
					flow = flow.Antecedents.Flow;
					continue;
				}
				t = c.getTypeAtFlowLoopLabel(f, flow);
			} else if ((flags & FlowFlagsArrayMutation) != 0) {
				t = c.getTypeAtFlowArrayMutation(f, flow);
				if (t.isNil()) {
					flow = flow.Antecedent;
					continue;
				}
			} else if ((flags & FlowFlagsReduceLabel) != 0) {
				if (f.reduceLabels == null) {
					f.reduceLabels = [];
				}
				f.reduceLabels.push(flow.Node.AsFlowReduceLabelData());
				t = c.getTypeAtFlowNode(f, flow.Antecedent);
				f.reduceLabels.resize(f.reduceLabels.length - 1);
			} else if ((flags & FlowFlagsStart) != 0) {
				// Check if we should continue with the control flow of the containing function.
				final container = flow.Node;
				if (container != null && container != f.flowContainer && !Ast.IsPropertyAccessExpression(f.reference)
					&& !Ast.IsElementAccessExpression(f.reference) && !(f.reference.Kind == KindThisKeyword && !Ast.IsArrowFunction(container))) {
					flow = container.FlowNodeData().FlowNode;
					continue;
				}
				// At the top of the flow we have the initial type.
				t = FlowType.of(f.initialType, false);
			} else {
				// Unreachable code errors are reported in the binding phase. Here we
				// simply return the non-auto declared type to reduce follow-on errors.
				t = FlowType.of(c.convertAutoToAny(f.declaredType), false);
			}
			if (sharedFlow != null) {
				// Record visited node and the associated type in the cache.
				final sf = new SharedFlow();
				sf.flow = sharedFlow;
				sf.flowType = t;
				if (c.sharedFlows == null) {
					c.sharedFlows = [];
				}
				c.sharedFlows.push(sf);
			}
			f.depth--;
			return t;
		}
	}

	static function getTypeAtFlowAssignment(c:Checker, f:FlowState, flow:FlowNode):FlowType {
		final node = flow.Node;
		// Assignments only narrow the computed type if the declared type is a union type. Thus, we
		// only need to evaluate the assigned type if the declared type is a union type.
		if (c.isMatchingReference(f.reference, node)) {
			if (!c.isReachableFlowNode(flow)) {
				return FlowType.of(c.unreachableNeverType, false);
			}
			if (Checker.getAssignmentTargetKind(node) == AssignmentKindCompound) {
				final flowType = c.getTypeAtFlowNode(f, flow.Antecedent);
				return c.newFlowType(c.getBaseTypeOfLiteralType(flowType.t), flowType.incomplete);
			}
			if (f.declaredType == c.autoType || f.declaredType == c.autoArrayType) {
				if (c.isEmptyArrayAssignment(node)) {
					return FlowType.of(c.getEvolvingArrayType(c.neverType), false);
				}
				final assignedType = c.getWidenedLiteralType(c.getInitialOrAssignedType(f, flow));
				if (c.isTypeAssignableTo(assignedType, f.declaredType)) {
					return FlowType.of(assignedType, false);
				}
				return FlowType.of(c.anyArrayType, false);
			}
			var t = f.declaredType;
			if (Checker.isInCompoundLikeAssignment(node)) {
				t = c.getBaseTypeOfLiteralType(t);
			}
			if ((t.flags & TypeFlagsUnion) != 0) {
				return FlowType.of(c.getAssignmentReducedType(t, c.getInitialOrAssignedType(f, flow)), false);
			}
			return FlowType.of(t, false);
		}
		// We didn't have a direct match. However, if the reference is a dotted name, this
		// may be an assignment to a left hand part of the reference. For example, for a
		// reference 'x.y.z', we may be at an assignment to 'x.y' or 'x'. In that case,
		// return the declared type.
		if (c.containsMatchingReference(f.reference, node)) {
			if (!c.isReachableFlowNode(flow)) {
				return FlowType.of(c.unreachableNeverType, false);
			}
			// A matching dotted name might also be an expando property on a function *expression*,
			// in which case we continue control flow analysis back to the function's declaration
			if (Ast.IsVariableDeclaration(node) && (Ast.IsInJSFile(node) || Ast.IsVarConstLike(node))) {
				final init = node.Initializer();
				if (init != null && Ast.IsFunctionExpressionOrArrowFunction(init)) {
					return c.getTypeAtFlowNode(f, flow.Antecedent);
				}
			}
			return FlowType.of(f.declaredType, false);
		}
		// for (const _ in ref) acts as a nonnull on ref
		if (Ast.IsVariableDeclaration(node) && Ast.IsForInStatement(node.Parent.Parent)
			&& (c.isMatchingReference(f.reference, node.Parent.Parent.Expression())
				|| c.optionalChainContainsReference(node.Parent.Parent.Expression(), f.reference))) {
			return FlowType.of(c.getNonNullableTypeIfNeeded(c.finalizeEvolvingArrayType(c.getTypeAtFlowNode(f, flow.Antecedent).t)), false);
		}
		// Assignment doesn't affect reference
		return FlowType.nil;
	}

	static function getInitialOrAssignedType(c:Checker, f:FlowState, flow:FlowNode):Type {
		if (Ast.IsVariableDeclaration(flow.Node) || Ast.IsBindingElement(flow.Node)) {
			return c.getNarrowableTypeForReference(c.getInitialType(flow.Node), f.reference, CheckModeNormal);
		}
		return c.getNarrowableTypeForReference(c.getAssignedType(flow.Node), f.reference, CheckModeNormal);
	}

	static function isEmptyArrayAssignment(c:Checker, node:Node):Bool {
		return Ast.IsVariableDeclaration(node) && node.Initializer() != null && Checker.isEmptyArrayLiteral(node.Initializer())
			|| !Ast.IsBindingElement(node) && Ast.IsBinaryExpression(node.Parent)
			&& Checker.isEmptyArrayLiteral(node.Parent.AsBinaryExpression().Right);
	}

	static function getTypeAtFlowCall(c:Checker, f:FlowState, flow:FlowNode):FlowType {
		final signature = c.getEffectsSignature(flow.Node);
		if (signature != null) {
			final predicate = c.getTypePredicateOfSignature(signature);
			if (predicate != null && (predicate.kind == TypePredicateKindAssertsThis || predicate.kind == TypePredicateKindAssertsIdentifier)) {
				final flowType = c.getTypeAtFlowNode(f, flow.Antecedent);
				final t = c.finalizeEvolvingArrayType(flowType.t);
				var narrowedType:Type;
				if (predicate.t != null) {
					narrowedType = c.narrowTypeByTypePredicate(f, t, predicate, flow.Node, true /*assumeTrue*/);
				} else if (predicate.kind == TypePredicateKindAssertsIdentifier && predicate.parameterIndex >= 0
					&& predicate.parameterIndex < flow.Node.Arguments().length) {
					narrowedType = c.narrowTypeByAssertion(f, t, flow.Node.Arguments()[predicate.parameterIndex]);
				} else {
					narrowedType = t;
				}
				if (narrowedType == t) {
					return flowType;
				}
				return c.newFlowType(narrowedType, flowType.incomplete);
			}
			if ((c.getReturnTypeOfSignature(signature).flags & TypeFlagsNever) != 0) {
				return FlowType.of(c.unreachableNeverType, false);
			}
		}
		return FlowType.nil;
	}

	static function narrowTypeByTypePredicate(c:Checker, f:FlowState, t:Type, predicate:TypePredicate, callExpression:Node, assumeTrue:Bool):Type {
		// Don't narrow from 'any' if the predicate type is exactly 'Object' or 'Function'
		if (predicate.t != null && !(Checker.IsTypeAny(t) && (predicate.t == c.globalObjectType || predicate.t == c.globalFunctionType))) {
			final predicateArgument = c.getTypePredicateArgument(predicate, callExpression);
			if (predicateArgument != null) {
				if (c.isMatchingReference(f.reference, predicateArgument)) {
					return c.getNarrowedType(t, predicate.t, assumeTrue, false /*checkDerived*/);
				}
				if (c.strictNullChecks && c.optionalChainContainsReference(predicateArgument, f.reference)
					&& (assumeTrue && !c.hasTypeFacts(predicate.t, TypeFactsEQUndefined)
						|| !assumeTrue && Checker.everyType(predicate.t, t -> c.IsNullableType(t)))) {
					t = c.getAdjustedTypeWithFacts(t, TypeFactsNEUndefinedOrNull);
				}
				final access = c.getDiscriminantPropertyAccess(f, predicateArgument, t);
				if (access != null) {
					return c.narrowTypeByDiscriminant(t, access, function(t:Type):Type {
						return c.getNarrowedType(t, predicate.t, assumeTrue, false /*checkDerived*/);
					});
				}
			}
		}
		return t;
	}

	static function narrowTypeByAssertion(c:Checker, f:FlowState, t:Type, expr:Node):Type {
		final node = Ast.SkipParentheses(expr);
		if (node.Kind == KindFalseKeyword) {
			return c.unreachableNeverType;
		}
		if (node.Kind == KindBinaryExpression) {
			if (node.AsBinaryExpression().OperatorToken.Kind == KindAmpersandAmpersandToken) {
				return c.narrowTypeByAssertion(f, c.narrowTypeByAssertion(f, t, node.AsBinaryExpression().Left), node.AsBinaryExpression().Right);
			}
			if (node.AsBinaryExpression().OperatorToken.Kind == KindBarBarToken) {
				return c.getUnionType([
					c.narrowTypeByAssertion(f, t, node.AsBinaryExpression().Left),
					c.narrowTypeByAssertion(f, t, node.AsBinaryExpression().Right)
				]);
			}
		}
		return c.narrowType(f, t, node, true /*assumeTrue*/);
	}

	static function getTypeAtFlowCondition(c:Checker, f:FlowState, flow:FlowNode):FlowType {
		final flowType = c.getTypeAtFlowNode(f, flow.Antecedent);
		if ((flowType.t.flags & TypeFlagsNever) != 0) {
			return flowType;
		}
		// If we have an antecedent type (meaning we're reachable in some way), we first
		// attempt to narrow the antecedent type. If that produces the never type, and if
		// the antecedent type is incomplete (i.e. a transient type in a loop), then we
		// take the type guard as an indication that control *could* reach here once we
		// have the complete type. We proceed by switching to the silent never type which
		// doesn't report errors when operators are applied to it. Note that this is the
		// *only* place a silent never type is ever generated.
		final assumeTrue = (flow.Flags & FlowFlagsTrueCondition) != 0;
		final nonEvolvingType = c.finalizeEvolvingArrayType(flowType.t);
		final narrowedType = c.narrowType(f, nonEvolvingType, flow.Node, assumeTrue);
		if (narrowedType == nonEvolvingType) {
			return flowType;
		}
		return c.newFlowType(narrowedType, flowType.incomplete);
	}

	// Narrow the given type based on the given expression having the assumed boolean value. The returned type
	// will be a subtype or the same type as the argument.
	static function narrowType(c:Checker, f:FlowState, t:Type, expr:Node, assumeTrue:Bool):Type {
		// for `a?.b`, we emulate a synthetic `a !== null && a !== undefined` condition for `a`
		if (Ast.IsExpressionOfOptionalChainRoot(expr)
			|| Ast.IsBinaryExpression(expr.Parent)
			&& (expr.Parent.AsBinaryExpression().OperatorToken.Kind == KindQuestionQuestionToken
				|| expr.Parent.AsBinaryExpression().OperatorToken.Kind == KindQuestionQuestionEqualsToken)
			&& expr.Parent.AsBinaryExpression().Left == expr) {
			return c.narrowTypeByOptionality(f, t, expr, assumeTrue);
		}
		switch (expr.Kind) {
			case KindIdentifier:
				// When narrowing a reference to a const variable, non-assigned parameter, or readonly property, we inline
				// up to five levels of aliased conditional expressions that are themselves declared as const variables.
				if (!c.isMatchingReference(f.reference, expr) && c.inlineLevel < 5) {
					final symbol = c.getResolvedSymbol(expr);
					if (c.isConstantVariable(symbol)) {
						final declaration = symbol.ValueDeclaration;
						if (declaration != null && Ast.IsVariableDeclaration(declaration) && declaration.Type() == null
							&& declaration.Initializer() != null && c.isConstantReference(f.reference)) {
							c.inlineLevel++;
							final result = c.narrowType(f, t, declaration.Initializer(), assumeTrue);
							c.inlineLevel--;
							return result;
						}
					}
				}
				// PORT: fallthrough
				return c.narrowTypeByTruthiness(f, t, expr, assumeTrue);
			case KindThisKeyword | KindSuperKeyword | KindPropertyAccessExpression | KindElementAccessExpression:
				return c.narrowTypeByTruthiness(f, t, expr, assumeTrue);
			case KindCallExpression:
				return c.narrowTypeByCallExpression(f, t, expr, assumeTrue);
			case KindParenthesizedExpression | KindNonNullExpression | KindSatisfiesExpression:
				return c.narrowType(f, t, expr.Expression(), assumeTrue);
			case KindBinaryExpression:
				return c.narrowTypeByBinaryExpression(f, t, expr.AsBinaryExpression(), assumeTrue);
			case KindPrefixUnaryExpression:
				if (expr.AsPrefixUnaryExpression().Operator == KindExclamationToken) {
					return c.narrowType(f, t, expr.AsPrefixUnaryExpression().Operand, !assumeTrue);
				}
			default:
		}
		return t;
	}

	static function narrowTypeByOptionality(c:Checker, f:FlowState, t:Type, expr:Node, assumePresent:Bool):Type {
		if (c.isMatchingReference(f.reference, expr)) {
			return c.getAdjustedTypeWithFacts(t, Core.IfElse(assumePresent, TypeFactsNEUndefinedOrNull, TypeFactsEQUndefinedOrNull));
		}
		final access = c.getDiscriminantPropertyAccess(f, expr, t);
		if (access != null) {
			return c.narrowTypeByDiscriminant(t, access, function(t:Type):Type {
				return c.getTypeWithFacts(t, Core.IfElse(assumePresent, TypeFactsNEUndefinedOrNull, TypeFactsEQUndefinedOrNull));
			});
		}
		return t;
	}

	static function narrowTypeByTruthiness(c:Checker, f:FlowState, t:Type, expr:Node, assumeTrue:Bool):Type {
		if (c.isMatchingReference(f.reference, expr)) {
			return c.getAdjustedTypeWithFacts(t, Core.IfElse(assumeTrue, TypeFactsTruthy, TypeFactsFalsy));
		}
		if (c.strictNullChecks && assumeTrue && c.optionalChainContainsReference(expr, f.reference)) {
			t = c.getAdjustedTypeWithFacts(t, TypeFactsNEUndefinedOrNull);
		}
		final access = c.getDiscriminantPropertyAccess(f, expr, t);
		if (access != null) {
			return c.narrowTypeByDiscriminant(t, access, function(t:Type):Type {
				return c.getTypeWithFacts(t, Core.IfElse(assumeTrue, TypeFactsTruthy, TypeFactsFalsy));
			});
		}
		return t;
	}

	static function narrowTypeByCallExpression(c:Checker, f:FlowState, t:Type, callExpression:Node, assumeTrue:Bool):Type {
		if (c.hasMatchingArgument(callExpression, f.reference)) {
			var predicate:TypePredicate = null;
			if (assumeTrue || !Checker.isCallChain(callExpression)) {
				final signature = c.getEffectsSignature(callExpression);
				if (signature != null) {
					predicate = c.getTypePredicateOfSignature(signature);
				}
			}
			if (predicate != null && (predicate.kind == TypePredicateKindThis || predicate.kind == TypePredicateKindIdentifier)) {
				return c.narrowTypeByTypePredicate(f, t, predicate, callExpression, assumeTrue);
			}
		}
		if (c.containsMissingType(t) && Ast.IsAccessExpression(f.reference) && Ast.IsPropertyAccessExpression(callExpression.Expression())) {
			final callAccess = callExpression.Expression();
			if (c.isMatchingReference(f.reference.Expression(), c.getReferenceCandidate(callAccess.Expression())) && Ast.IsIdentifier(callAccess.Name())
				&& callAccess.Name().Text() == "hasOwnProperty" && callExpression.Arguments().length == 1) {
				final argument = callExpression.Arguments()[0];
				final accessed = c.getAccessedPropertyName(f.reference);
				if (accessed != null && Ast.IsStringLiteralLike(argument) && accessed == argument.Text()) {
					return c.getTypeWithFacts(t, Core.IfElse(assumeTrue, TypeFactsNEUndefined, TypeFactsEQUndefined));
				}
			}
		}
		return t;
	}

	static function narrowTypeByBinaryExpression(c:Checker, f:FlowState, t:Type, expr:BinaryExpression, assumeTrue:Bool):Type {
		switch (expr.OperatorToken.Kind) {
			case KindEqualsToken | KindBarBarEqualsToken | KindAmpersandAmpersandEqualsToken | KindQuestionQuestionEqualsToken:
				return c.narrowTypeByTruthiness(f, c.narrowType(f, t, expr.Right, assumeTrue), expr.Left, assumeTrue);
			case KindEqualsEqualsToken | KindExclamationEqualsToken | KindEqualsEqualsEqualsToken | KindExclamationEqualsEqualsToken:
				final operator_ = expr.OperatorToken.Kind;
				final left = c.getReferenceCandidate(expr.Left);
				final right = c.getReferenceCandidate(expr.Right);
				if (left.Kind == KindTypeOfExpression && Ast.IsStringLiteralLike(right)) {
					return c.narrowTypeByTypeof(f, t, left.AsTypeOfExpression(), operator_, right, assumeTrue);
				}
				if (right.Kind == KindTypeOfExpression && Ast.IsStringLiteralLike(left)) {
					return c.narrowTypeByTypeof(f, t, right.AsTypeOfExpression(), operator_, left, assumeTrue);
				}
				if (c.isMatchingReference(f.reference, left)) {
					return c.narrowTypeByEquality(t, operator_, right, assumeTrue);
				}
				if (c.isMatchingReference(f.reference, right)) {
					return c.narrowTypeByEquality(t, operator_, left, assumeTrue);
				}
				if (c.strictNullChecks) {
					if (c.optionalChainContainsReference(left, f.reference)) {
						t = c.narrowTypeByOptionalChainContainment(f, t, operator_, right, assumeTrue);
					} else if (c.optionalChainContainsReference(right, f.reference)) {
						t = c.narrowTypeByOptionalChainContainment(f, t, operator_, left, assumeTrue);
					}
				}
				final leftAccess = c.getDiscriminantPropertyAccess(f, left, t);
				if (leftAccess != null) {
					return c.narrowTypeByDiscriminantProperty(t, leftAccess, operator_, right, assumeTrue);
				}
				final rightAccess = c.getDiscriminantPropertyAccess(f, right, t);
				if (rightAccess != null) {
					return c.narrowTypeByDiscriminantProperty(t, rightAccess, operator_, left, assumeTrue);
				}
				if (c.isMatchingConstructorReference(f, left)) {
					return c.narrowTypeByConstructor(t, operator_, right, assumeTrue);
				}
				if (c.isMatchingConstructorReference(f, right)) {
					return c.narrowTypeByConstructor(t, operator_, left, assumeTrue);
				}
				if (Ast.IsBooleanLiteral(right) && !Ast.IsAccessExpression(left)) {
					return c.narrowTypeByBooleanComparison(f, t, left, right, operator_, assumeTrue);
				}
				if (Ast.IsBooleanLiteral(left) && !Ast.IsAccessExpression(right)) {
					return c.narrowTypeByBooleanComparison(f, t, right, left, operator_, assumeTrue);
				}
			case KindInstanceOfKeyword:
				return c.narrowTypeByInstanceof(f, t, expr, assumeTrue);
			case KindInKeyword:
				if (Ast.IsPrivateIdentifier(expr.Left)) {
					return c.narrowTypeByPrivateIdentifierInInExpression(f, t, expr, assumeTrue);
				}
				final target = c.getReferenceCandidate(expr.Right);
				if (c.containsMissingType(t) && Ast.IsAccessExpression(f.reference) && c.isMatchingReference(f.reference.Expression(), target)) {
					final leftType = c.getTypeOfExpression(expr.Left);
					if (Checker.isTypeUsableAsPropertyName(leftType)) {
						final accessed = c.getAccessedPropertyName(f.reference);
						if (accessed != null && accessed == Checker.getPropertyNameFromType(leftType)) {
							return c.getTypeWithFacts(t, Core.IfElse(assumeTrue, TypeFactsNEUndefined, TypeFactsEQUndefined));
						}
					}
				}
				if (c.isMatchingReference(f.reference, target)) {
					final leftType = c.getTypeOfExpression(expr.Left);
					if (Checker.isTypeUsableAsPropertyName(leftType)) {
						return c.narrowTypeByInKeyword(f, t, leftType, assumeTrue);
					}
				}
			case KindCommaToken:
				return c.narrowType(f, t, expr.Right, assumeTrue);
			case KindAmpersandAmpersandToken:
				// Ordinarily we won't see && and || expressions in control flow analysis because the Binder breaks those
				// expressions down to individual conditional control flows. However, we may encounter them when analyzing
				// aliased conditional expressions.
				if (assumeTrue) {
					return c.narrowType(f, c.narrowType(f, t, expr.Left, true /*assumeTrue*/), expr.Right, true /*assumeTrue*/);
				}
				return c.getUnionType([
					c.narrowType(f, t, expr.Left, false /*assumeTrue*/),
					c.narrowType(f, t, expr.Right, false /*assumeTrue*/)
				]);
			case KindBarBarToken:
				if (assumeTrue) {
					return c.getUnionType([
						c.narrowType(f, t, expr.Left, true /*assumeTrue*/),
						c.narrowType(f, t, expr.Right, true /*assumeTrue*/)
					]);
				}
				return c.narrowType(f, c.narrowType(f, t, expr.Left, false /*assumeTrue*/), expr.Right, false /*assumeTrue*/);
			default:
		}
		return t;
	}

	static function narrowTypeByEquality(c:Checker, t:Type, operator_:Kind, value:Node, assumeTrue:Bool):Type {
		if ((t.flags & TypeFlagsAny) != 0) {
			return t;
		}
		if (operator_ == KindExclamationEqualsToken || operator_ == KindExclamationEqualsEqualsToken) {
			assumeTrue = !assumeTrue;
		}
		final valueType = c.getTypeOfExpression(value);
		final doubleEquals = operator_ == KindEqualsEqualsToken || operator_ == KindExclamationEqualsToken;
		if ((valueType.flags & TypeFlagsNullable) != 0) {
			if (!c.strictNullChecks) {
				return t;
			}
			var facts:TypeFacts;
			if (doubleEquals) {
				facts = Core.IfElse(assumeTrue, TypeFactsEQUndefinedOrNull, TypeFactsNEUndefinedOrNull);
			} else if ((valueType.flags & TypeFlagsNull) != 0) {
				facts = Core.IfElse(assumeTrue, TypeFactsEQNull, TypeFactsNENull);
			} else {
				facts = Core.IfElse(assumeTrue, TypeFactsEQUndefined, TypeFactsNEUndefined);
			}
			return c.getAdjustedTypeWithFacts(t, facts);
		}
		if (assumeTrue) {
			if (!doubleEquals && ((t.flags & TypeFlagsUnknown) != 0 || Checker.someType(t, t -> c.IsEmptyAnonymousObjectType(t)))) {
				if ((valueType.flags & (TypeFlagsPrimitive | TypeFlagsNonPrimitive)) != 0 || c.IsEmptyAnonymousObjectType(valueType)) {
					return valueType;
				}
				if ((valueType.flags & TypeFlagsObject) != 0) {
					return c.nonPrimitiveType;
				}
			}
			final filteredType = c.filterType(t, function(t:Type):Bool {
				return c.areTypesComparable(t, valueType) || doubleEquals && Checker.isCoercibleUnderDoubleEquals(t, valueType);
			});
			return c.replacePrimitivesWithLiterals(filteredType, valueType);
		}
		if (Checker.isUnitType(valueType)) {
			return c.filterType(t, function(t:Type):Bool {
				return !(c.isUnitLikeType(t) && c.areTypesComparable(t, valueType));
			});
		}
		return t;
	}

	static function narrowTypeByTypeof(c:Checker, f:FlowState, t:Type, typeOfExpr:TypeOfExpression, operator_:Kind, literal:Node, assumeTrue:Bool):Type {
		// We have '==', '!=', '===', or !==' operator with 'typeof xxx' and string literal operands
		if (operator_ == KindExclamationEqualsToken || operator_ == KindExclamationEqualsEqualsToken) {
			assumeTrue = !assumeTrue;
		}
		final target = c.getReferenceCandidate(typeOfExpr.Expression);
		if (!c.isMatchingReference(f.reference, target)) {
			if (c.strictNullChecks && c.optionalChainContainsReference(target, f.reference) && assumeTrue == (literal.Text() != "undefined")) {
				t = c.getAdjustedTypeWithFacts(t, TypeFactsNEUndefinedOrNull);
			}
			final propertyAccess = c.getDiscriminantPropertyAccess(f, target, t);
			if (propertyAccess != null) {
				return c.narrowTypeByDiscriminant(t, propertyAccess, function(t:Type):Type {
					return c.narrowTypeByLiteralExpression(t, literal, assumeTrue);
				});
			}
			return t;
		}
		return c.narrowTypeByLiteralExpression(t, literal, assumeTrue);
	}

	static function narrowTypeByLiteralExpression(c:Checker, t:Type, literal:LiteralExpression, assumeTrue:Bool):Type {
		if (assumeTrue) {
			return c.narrowTypeByTypeName(t, literal.Text());
		}
		var facts:TypeFacts;
		if (Checker.typeofNEFacts.exists(literal.Text())) {
			facts = Checker.typeofNEFacts.get(literal.Text());
		} else {
			facts = TypeFactsTypeofNEHostObject;
		}
		return c.getAdjustedTypeWithFacts(t, facts);
	}

	static function narrowTypeByTypeName(c:Checker, t:Type, typeName:std.String):Type {
		switch (typeName) {
			case "string":
				return c.narrowTypeByTypeFacts(t, c.stringType, TypeFactsTypeofEQString);
			case "number":
				return c.narrowTypeByTypeFacts(t, c.numberType, TypeFactsTypeofEQNumber);
			case "bigint":
				return c.narrowTypeByTypeFacts(t, c.bigintType, TypeFactsTypeofEQBigInt);
			case "boolean":
				return c.narrowTypeByTypeFacts(t, c.booleanType, TypeFactsTypeofEQBoolean);
			case "symbol":
				return c.narrowTypeByTypeFacts(t, c.esSymbolType, TypeFactsTypeofEQSymbol);
			case "object":
				if ((t.flags & TypeFlagsAny) != 0) {
					return t;
				}
				return c.getUnionType([
					c.narrowTypeByTypeFacts(t, c.nonPrimitiveType, TypeFactsTypeofEQObject),
					c.narrowTypeByTypeFacts(t, c.nullType, TypeFactsEQNull)
				]);
			case "function":
				if ((t.flags & TypeFlagsAny) != 0) {
					return t;
				}
				return c.narrowTypeByTypeFacts(t, c.globalFunctionType, TypeFactsTypeofEQFunction);
			case "undefined":
				return c.narrowTypeByTypeFacts(t, c.undefinedType, TypeFactsEQUndefined);
			default:
		}
		return c.narrowTypeByTypeFacts(t, c.nonPrimitiveType, TypeFactsTypeofEQHostObject);
	}

	static function narrowTypeByTypeFacts(c:Checker, t:Type, impliedType:Type, facts:TypeFacts):Type {
		return c.mapType(t, function(t:Type):Type {
			if (c.isTypeRelatedTo(t, impliedType, c.strictSubtypeRelation)) {
				if (c.hasTypeFacts(t, facts)) {
					return t;
				}
				return c.neverType;
			} else if (c.isTypeSubtypeOf(impliedType, t)) {
				return impliedType;
			} else if (c.hasTypeFacts(t, facts)) {
				return c.getIntersectionType([t, impliedType]);
			}
			return c.neverType;
		});
	}

	static function narrowTypeByDiscriminantProperty(c:Checker, t:Type, access:Node, operator_:Kind, value:Node, assumeTrue:Bool):Type {
		if ((operator_ == KindEqualsEqualsEqualsToken || operator_ == KindExclamationEqualsEqualsToken) && (t.flags & TypeFlagsUnion) != 0) {
			final keyPropertyName = c.getKeyPropertyName(t);
			if (keyPropertyName != "") {
				final accessed = c.getAccessedPropertyName(access);
				if (accessed != null && keyPropertyName == accessed) {
					final candidate = c.getConstituentTypeForKeyType(t, c.getTypeOfExpression(value));
					if (candidate != null) {
						if (assumeTrue && operator_ == KindEqualsEqualsEqualsToken || !assumeTrue && operator_ == KindExclamationEqualsEqualsToken) {
							return candidate;
						}
						final propType = c.getTypeOfPropertyOfType(candidate, keyPropertyName);
						if (propType != null && Checker.isUnitType(propType)) {
							return c.removeType(t, candidate);
						}
						return t;
					}
				}
			}
		}
		return c.narrowTypeByDiscriminant(t, access, function(t:Type):Type {
			return c.narrowTypeByEquality(t, operator_, value, assumeTrue);
		});
	}

	static function narrowTypeByDiscriminant(c:Checker, t:Type, access:Node, narrowType:(t:Type) -> Type):Type {
		final accessed = c.getAccessedPropertyName(access);
		if (accessed == null) {
			return t;
		}
		final propName:std.String = accessed;
		final optionalChain = Ast.IsOptionalChain(access);
		final removeNullable = c.strictNullChecks && (optionalChain || Checker.isNonNullAccess(access)) && c.maybeTypeOfKind(t, TypeFlagsNullable);
		var nonNullType = t;
		if (removeNullable) {
			nonNullType = c.getTypeWithFacts(t, TypeFactsNEUndefinedOrNull);
		}
		var propType = c.getTypeOfPropertyOfType(nonNullType, propName);
		if (propType == null) {
			return t;
		}
		if (removeNullable && optionalChain) {
			propType = c.getOptionalType(propType, false);
		}
		final narrowedPropType = narrowType(propType);
		return c.filterType(t, function(t:Type):Bool {
			final discriminantType = Core.OrElse(c.getTypeOfPropertyOrIndexSignatureOfType(t, propName), c.unknownType);
			return (discriminantType.flags & TypeFlagsNever) == 0 && (narrowedPropType.flags & TypeFlagsNever) == 0
				&& c.areTypesComparable(narrowedPropType, discriminantType);
		});
	}

	static function isMatchingConstructorReference(c:Checker, f:FlowState, expr:Node):Bool {
		if (Ast.IsAccessExpression(expr)) {
			final accessed = c.getAccessedPropertyName(expr);
			if (accessed != null && accessed == "constructor" && c.isMatchingReference(f.reference, expr.Expression())) {
				return true;
			}
		}
		return false;
	}

	static function narrowTypeByConstructor(c:Checker, t:Type, operator_:Kind, identifier:Node, assumeTrue:Bool):Type {
		// Do not narrow when checking inequality.
		if (assumeTrue && operator_ != KindEqualsEqualsToken && operator_ != KindEqualsEqualsEqualsToken
			|| !assumeTrue && operator_ != KindExclamationEqualsToken && operator_ != KindExclamationEqualsEqualsToken) {
			return t;
		}
		// Get the type of the constructor identifier expression, if it is not a function then do not narrow.
		final identifierType = c.getTypeOfExpression(identifier);
		if (!c.isFunctionType(identifierType) && !c.isConstructorType(identifierType)) {
			return t;
		}
		// Get the prototype property of the type identifier so we can find out its type.
		final prototypeProperty = c.getPropertyOfType(identifierType, "prototype");
		if (prototypeProperty == null) {
			return t;
		}
		// Get the type of the prototype, if it is undefined, or the global `Object` or `Function` types then do not narrow.
		final prototypeType = c.getTypeOfSymbol(prototypeProperty);
		var candidate:Type = null;
		if (!Checker.IsTypeAny(prototypeType)) {
			candidate = prototypeType;
		}
		if (candidate == null || candidate == c.globalObjectType || candidate == c.globalFunctionType) {
			return t;
		}
		// If the type that is being narrowed is `any` then just return the `candidate` type since every type is a subtype of `any`.
		if (Checker.IsTypeAny(t)) {
			return candidate;
		}
		// Filter out types that are not considered to be "constructed by" the `candidate` type.
		return c.filterType(t, function(t:Type):Bool {
			return c.isConstructedBy(t, candidate);
		});
	}

	static function isConstructedBy(c:Checker, source:Type, target:Type):Bool {
		// If either the source or target type are a class type then we need to check that they are the same exact type.
		// This is because you may have a class `A` that defines some set of properties, and another class `B`
		// that defines the same set of properties as class `A`, in that case they are structurally the same
		// type, but when you do something like `instanceOfA.constructor === B` it will return false.
		if ((source.flags & TypeFlagsObject) != 0 && (source.objectFlags & ObjectFlagsClass) != 0
			|| (target.flags & TypeFlagsObject) != 0 && (target.objectFlags & ObjectFlagsClass) != 0) {
			return source.symbol == target.symbol;
		}
		// For all other types just check that the `source` type is a subtype of the `target` type.
		return c.isTypeSubtypeOf(source, target);
	}

	static function narrowTypeByBooleanComparison(c:Checker, f:FlowState, t:Type, expr:Node, boolValue:Node, operator_:Kind, assumeTrue:Bool):Type {
		assumeTrue = (assumeTrue != (boolValue.Kind == KindTrueKeyword)) != (operator_ != KindExclamationEqualsEqualsToken
			&& operator_ != KindExclamationEqualsToken);
		return c.narrowType(f, t, expr, assumeTrue);
	}

	static function narrowTypeByInstanceof(c:Checker, f:FlowState, t:Type, expr:BinaryExpression, assumeTrue:Bool):Type {
		final left = c.getReferenceCandidate(expr.Left);
		if (!c.isMatchingReference(f.reference, left)) {
			if (assumeTrue && c.strictNullChecks && c.optionalChainContainsReference(left, f.reference)) {
				return c.getAdjustedTypeWithFacts(t, TypeFactsNEUndefinedOrNull);
			}
			return t;
		}
		final right = expr.Right;
		final rightType = c.getTypeOfExpression(right);
		if (!c.isTypeDerivedFrom(rightType, c.globalObjectType)) {
			return t;
		}
		// if the right-hand side has an object type with a custom `[Symbol.hasInstance]` method, and that method
		// has a type predicate, use the type predicate to perform narrowing. This allows normal `object` types to
		// participate in `instanceof`, as per Step 2 of https://tc39.es/ecma262/#sec-instanceofoperator.
		var predicate:TypePredicate = null;
		final signature = c.getEffectsSignature(expr.AsNode());
		if (signature != null) {
			predicate = c.getTypePredicateOfSignature(signature);
		}
		if (predicate != null && predicate.kind == TypePredicateKindIdentifier && predicate.parameterIndex == 0) {
			return c.getNarrowedType(t, predicate.t, assumeTrue, true /*checkDerived*/);
		}
		if (!c.isTypeDerivedFrom(rightType, c.globalFunctionType)) {
			return t;
		}
		final instanceType = c.mapType(rightType, t -> c.getInstanceType(t));
		// Don't narrow from `any` if the target type is exactly `Object` or `Function`, and narrow
		// in the false branch only if the target is a non-empty object type.
		if (Checker.IsTypeAny(t) && (instanceType == c.globalObjectType || instanceType == c.globalFunctionType)
			|| !assumeTrue && !((instanceType.flags & TypeFlagsObject) != 0 && !c.IsEmptyAnonymousObjectType(instanceType))) {
			return t;
		}
		return c.getNarrowedType(t, instanceType, assumeTrue, true /*checkDerived*/);
	}

	static function getNarrowedType(c:Checker, t:Type, candidate:Type, assumeTrue:Bool, checkDerived:Bool):Type {
		if ((t.flags & TypeFlagsUnion) == 0) {
			return c.getNarrowedTypeWorker(t, candidate, assumeTrue, checkDerived);
		}
		final key = NarrowedTypeKey.keyOf(t, candidate, assumeTrue, checkDerived);
		if (c.narrowedTypes.exists(key)) {
			return c.narrowedTypes.get(key);
		}
		final narrowedType = c.getNarrowedTypeWorker(t, candidate, assumeTrue, checkDerived);
		c.narrowedTypes.set(key, narrowedType);
		return narrowedType;
	}

	static function getNarrowedTypeWorker(c:Checker, t:Type, candidate:Type, assumeTrue:Bool, checkDerived:Bool):Type {
		if (!assumeTrue) {
			if (t == candidate) {
				return c.neverType;
			}
			if (checkDerived) {
				return c.filterType(t, function(t:Type):Bool {
					return !c.isTypeDerivedFrom(t, candidate);
				});
			}
			if ((t.flags & TypeFlagsUnknown) != 0) {
				t = c.unknownUnionType;
			}
			final trueType = c.getNarrowedType(t, candidate, true /*assumeTrue*/, false /*checkDerived*/);
			return c.recombineUnknownType(c.filterType(t, function(t:Type):Bool {
				return !c.isTypeSubsetOf(t, trueType);
			}));
		}
		if ((t.flags & TypeFlagsAnyOrUnknown) != 0) {
			return candidate;
		}
		if (t == candidate) {
			return candidate;
		}
		// We first attempt to filter the current type, narrowing constituents as appropriate and removing
		// constituents that are unrelated to the candidate.
		var keyPropertyName = "";
		if ((t.flags & TypeFlagsUnion) != 0) {
			keyPropertyName = c.getKeyPropertyName(t);
		}
		final outerT = t;
		final narrowedType = c.mapType(candidate, function(n:Type):Type {
			// If a discriminant property is available, use that to reduce the type.
			var matching = outerT;
			if (keyPropertyName != "") {
				final discriminant = c.getTypeOfPropertyOfType(n, keyPropertyName);
				if (discriminant != null) {
					final constituent = c.getConstituentTypeForKeyType(outerT, discriminant);
					if (constituent != null) {
						matching = constituent;
					}
				}
			}
			// For each constituent t in the current type, if t and c are directly related, pick the most
			// specific of the two. When t and c are related in both directions, we prefer c for type predicates
			// because that is the asserted type, but t for `instanceof` because generics aren't reflected in
			// prototype object types.
			var mapType:(Type) -> Type;
			if (checkDerived) {
				mapType = function(t:Type):Type {
					if (c.isTypeDerivedFrom(t, n)) {
						return t;
					} else if (c.isTypeDerivedFrom(n, t)) {
						return n;
					}
					return c.neverType;
				};
			} else {
				mapType = function(t:Type):Type {
					if (c.isTypeStrictSubtypeOf(t, n)) {
						return t;
					} else if (c.isTypeStrictSubtypeOf(n, t)) {
						return n;
					} else if (c.isTypeSubtypeOf(t, n)) {
						return t;
					} else if (c.isTypeSubtypeOf(n, t)) {
						return n;
					}
					return c.neverType;
				};
			}
			final directlyRelated = c.mapType(matching, mapType);
			if ((directlyRelated.flags & TypeFlagsNever) == 0) {
				return directlyRelated;
			}
			// If no constituents are directly related, create intersections for any generic constituents that
			// are related by constraint.
			var isRelated:(Type, Type) -> Bool;
			if (checkDerived) {
				isRelated = (s, t) -> c.isTypeDerivedFrom(s, t);
			} else {
				isRelated = (s, t) -> c.isTypeSubtypeOf(s, t);
			}
			return c.mapType(outerT, function(t:Type):Type {
				if (c.maybeTypeOfKind(t, TypeFlagsInstantiable)) {
					final constraint = c.getBaseConstraintOfType(t);
					if (constraint == null || isRelated(n, constraint)) {
						return c.getIntersectionType([t, n]);
					}
				}
				return c.neverType;
			});
		});
		// If filtering produced a non-empty type, return that. Otherwise, pick the most specific of the two
		// based on assignability, or as a last resort produce an intersection.
		if ((narrowedType.flags & TypeFlagsNever) == 0) {
			return narrowedType;
		} else if (c.isTypeSubtypeOf(candidate, t)) {
			return candidate;
		} else if (c.isTypeAssignableTo(t, candidate)) {
			return t;
		} else if (c.isTypeAssignableTo(candidate, t)) {
			return candidate;
		}
		return c.getIntersectionType([t, candidate]);
	}

	static function getInstanceType(c:Checker, constructorType:Type):Type {
		final prototypePropertyType = c.getTypeOfPropertyOfType(constructorType, "prototype");
		if (prototypePropertyType != null && !Checker.IsTypeAny(prototypePropertyType)) {
			return prototypePropertyType;
		}
		final constructSignatures = c.getSignaturesOfType(constructorType, SignatureKindConstruct);
		if (Core.len(constructSignatures) != 0) {
			return c.getUnionType(Core.Map(constructSignatures, function(signature:Signature):Type {
				return c.getReturnTypeOfSignature(c.getErasedSignature(signature));
			}));
		}
		// We use the empty object type to indicate we don't know the type of objects created by
		// this constructor function.
		return c.emptyObjectType;
	}

	static function narrowTypeByPrivateIdentifierInInExpression(c:Checker, f:FlowState, t:Type, expr:BinaryExpression, assumeTrue:Bool):Type {
		final target = c.getReferenceCandidate(expr.Right);
		if (!c.isMatchingReference(f.reference, target)) {
			return t;
		}
		final symbol = c.getSymbolForPrivateIdentifierExpression(expr.Left);
		if (symbol == null) {
			return t;
		}
		final classSymbol = symbol.Parent;
		var targetType:Type;
		if (Ast.HasStaticModifier(symbol.ValueDeclaration)) {
			targetType = c.getTypeOfSymbol(classSymbol);
		} else {
			targetType = c.getDeclaredTypeOfSymbol(classSymbol);
		}
		return c.getNarrowedType(t, targetType, assumeTrue, true /*checkDerived*/);
	}

	static function narrowTypeByInKeyword(c:Checker, f:FlowState, t:Type, nameType:Type, assumeTrue:Bool):Type {
		final name = Checker.getPropertyNameFromType(nameType);
		final isKnownProperty = Checker.someType(t, function(t:Type):Bool {
			return c.isTypePresencePossible(t, name, true /*assumeTrue*/);
		});
		if (isKnownProperty) {
			// If the check is for a known property (i.e. a property declared in some constituent of
			// the target type), we filter the target type by presence of absence of the property.
			return c.filterType(t, function(t:Type):Bool {
				return c.isTypePresencePossible(t, name, assumeTrue);
			});
		}
		if (assumeTrue) {
			// If the check is for an unknown property, we intersect the target type with `Record<X, unknown>`,
			// where X is the name of the property.
			final recordSymbol = c.getGlobalRecordSymbol();
			if (recordSymbol != null) {
				return c.getIntersectionType([t, c.getTypeAliasInstantiation(recordSymbol, [nameType, c.unknownType], null)]);
			}
		}
		return t;
	}

	static function isTypePresencePossible(c:Checker, t:Type, propName:std.String, assumeTrue:Bool):Bool {
		final prop = c.getPropertyOfType(t, propName);
		if (prop != null) {
			return (prop.Flags & SymbolFlagsOptional) != 0 || (prop.CheckFlags & CheckFlagsPartial) != 0 || assumeTrue;
		}
		return c.getApplicableIndexInfoForName(t, propName) != null || !assumeTrue;
	}

	static function narrowTypeByOptionalChainContainment(c:Checker, f:FlowState, t:Type, operator_:Kind, value:Node, assumeTrue:Bool):Type {
		// We are in a branch of obj?.foo === value (or any one of the other equality operators). We narrow obj as follows:
		// When operator is === and type of value excludes undefined, null and undefined is removed from type of obj in true branch.
		// When operator is !== and type of value excludes undefined, null and undefined is removed from type of obj in false branch.
		// When operator is == and type of value excludes null and undefined, null and undefined is removed from type of obj in true branch.
		// When operator is != and type of value excludes null and undefined, null and undefined is removed from type of obj in false branch.
		// When operator is === and type of value is undefined, null and undefined is removed from type of obj in false branch.
		// When operator is !== and type of value is undefined, null and undefined is removed from type of obj in true branch.
		// When operator is == and type of value is null or undefined, null and undefined is removed from type of obj in false branch.
		// When operator is != and type of value is null or undefined, null and undefined is removed from type of obj in true branch.
		final equalsOperator = operator_ == KindEqualsEqualsToken || operator_ == KindEqualsEqualsEqualsToken;
		var nullableFlags:TypeFlags;
		if (operator_ == KindEqualsEqualsToken || operator_ == KindExclamationEqualsToken) {
			nullableFlags = TypeFlagsNullable;
		} else {
			nullableFlags = TypeFlagsUndefined;
		}
		final valueType = c.getTypeOfExpression(value);
		// Note that we include any and unknown in the exclusion test because their domain includes null and undefined.
		final removeNullable = equalsOperator != assumeTrue && Checker.everyType(valueType, t -> (t.flags & nullableFlags) != 0)
			|| equalsOperator == assumeTrue && Checker.everyType(valueType, t -> (t.flags & (TypeFlagsAnyOrUnknown | nullableFlags)) == 0);
		if (removeNullable) {
			return c.getAdjustedTypeWithFacts(t, TypeFactsNEUndefinedOrNull);
		}
		return t;
	}

	static function getTypeAtSwitchClause(c:Checker, f:FlowState, flow:FlowNode):FlowType {
		final data = flow.Node.AsFlowSwitchClauseData();
		final expr = Ast.SkipParentheses(data.SwitchStatement.Expression());
		final flowType = c.getTypeAtFlowNode(f, flow.Antecedent);
		var t = flowType.t;
		if (c.isMatchingReference(f.reference, expr)) {
			t = c.narrowTypeBySwitchOnDiscriminant(t, data);
		} else if (expr.Kind == KindTypeOfExpression && c.isMatchingReference(f.reference, expr.Expression())) {
			t = c.narrowTypeBySwitchOnTypeOf(t, data);
		} else if (expr.Kind == KindTrueKeyword) {
			t = c.narrowTypeBySwitchOnTrue(f, t, data);
		} else {
			if (c.strictNullChecks) {
				if (c.optionalChainContainsReference(expr, f.reference)) {
					t = c.narrowTypeBySwitchOptionalChainContainment(t, data, function(t:Type):Bool {
						return (t.flags & (TypeFlagsUndefined | TypeFlagsNever)) == 0;
					});
				} else if (Ast.IsTypeOfExpression(expr) && c.optionalChainContainsReference(expr.Expression(), f.reference)) {
					t = c.narrowTypeBySwitchOptionalChainContainment(t, data, function(t:Type):Bool {
						return !((t.flags & TypeFlagsNever) != 0 || (t.flags & TypeFlagsStringLiteral) != 0 && Checker.getStringLiteralValue(t) == "undefined");
					});
				}
			}
			final access = c.getDiscriminantPropertyAccess(f, expr, t);
			if (access != null) {
				t = c.narrowTypeBySwitchOnDiscriminantProperty(t, access, data);
			}
		}
		return c.newFlowType(t, flowType.incomplete);
	}

	static function narrowTypeBySwitchOnDiscriminant(c:Checker, t:Type, data:FlowSwitchClauseData):Type {
		// We only narrow if all case expressions specify
		// values with unit types, except for the case where
		// `type` is unknown. In this instance we map object
		// types to the nonPrimitive type and narrow with that.
		final switchTypes = c.getSwitchClauseTypes(data.SwitchStatement);
		if (Core.len(switchTypes) == 0) {
			return t;
		}
		final clauseTypes = switchTypes.slice(data.ClauseStart, data.ClauseEnd);
		final hasDefaultClause = data.ClauseStart == data.ClauseEnd || Slices.Contains(clauseTypes, c.neverType);
		if ((t.flags & TypeFlagsUnknown) != 0 && !hasDefaultClause) {
			var groundClauseTypes:Array<Type> = null;
			for (i in 0...clauseTypes.length) {
				final s = clauseTypes[i];
				if ((s.flags & (TypeFlagsPrimitive | TypeFlagsNonPrimitive)) != 0) {
					if (groundClauseTypes != null) {
						groundClauseTypes.push(s);
					}
				} else if ((s.flags & TypeFlagsObject) != 0) {
					if (groundClauseTypes == null) {
						groundClauseTypes = clauseTypes.slice(0, i);
					}
					groundClauseTypes.push(c.nonPrimitiveType);
				} else {
					return t;
				}
			}
			return c.getUnionType(groundClauseTypes == null ? clauseTypes : groundClauseTypes);
		}
		final discriminantType = c.getUnionType(clauseTypes);
		var caseType:Type;
		if ((discriminantType.flags & TypeFlagsNever) != 0) {
			caseType = c.neverType;
		} else {
			final filtered = c.filterType(t, t -> c.areTypesComparable(discriminantType, t));
			caseType = c.replacePrimitivesWithLiterals(filtered, discriminantType);
		}
		if (!hasDefaultClause) {
			return caseType;
		}
		final defaultType = c.filterType(t, function(t:Type):Bool {
			if (!c.isUnitLikeType(t)) {
				return true;
			}
			var u = c.undefinedType;
			if ((t.flags & TypeFlagsUndefined) == 0) {
				u = c.getRegularTypeOfLiteralType(c.extractUnitType(t));
			}
			return !Core.Some(switchTypes, function(st:Type):Bool {
				return Checker.isUnitType(st) && c.areTypesComparable(st, u);
			});
		});
		if ((caseType.flags & TypeFlagsNever) != 0) {
			return defaultType;
		}
		return c.getUnionType([caseType, defaultType]);
	}

	static function narrowTypeBySwitchOnTypeOf(c:Checker, t:Type, data:FlowSwitchClauseData):Type {
		final witnesses = c.getSwitchClauseTypeOfWitnesses(data.SwitchStatement);
		if (witnesses == null) {
			return t;
		}
		final clauses = data.SwitchStatement.AsSwitchStatement().CaseBlock.AsCaseBlock().Clauses.Nodes;
		// Equal start and end denotes implicit fallthrough; undefined marks explicit default clause.
		final defaultIndex = Core.FindIndex(clauses, function(clause:Node):Bool {
			return clause.Kind == KindDefaultClause;
		});
		final clauseStart = data.ClauseStart;
		final clauseEnd = data.ClauseEnd;
		final hasDefaultClause = clauseStart == clauseEnd || (defaultIndex >= clauseStart && defaultIndex < clauseEnd);
		if (hasDefaultClause) {
			// In the default clause we filter constituents down to those that are not-equal to all handled cases.
			final notEqualFacts = c.getNotEqualFactsFromTypeofSwitch(clauseStart, clauseEnd, witnesses);
			return c.filterType(t, function(t:Type):Bool {
				return c.getTypeFacts(t, notEqualFacts) == notEqualFacts;
			});
		}
		// In the non-default cause we create a union of the type narrowed by each of the listed cases.
		final clauseWitnesses = witnesses.slice(clauseStart, clauseEnd);
		return c.getUnionType(Core.Map(clauseWitnesses, function(text:std.String):Type {
			if (text != "") {
				return c.narrowTypeByTypeName(t, text);
			}
			return c.neverType;
		}));
	}

	static function narrowTypeBySwitchOnTrue(c:Checker, f:FlowState, t:Type, data:FlowSwitchClauseData):Type {
		final clauses = data.SwitchStatement.AsSwitchStatement().CaseBlock.AsCaseBlock().Clauses.Nodes;
		final defaultIndex = Core.FindIndex(clauses, function(clause:Node):Bool {
			return clause.Kind == KindDefaultClause;
		});
		final clauseStart = data.ClauseStart;
		final clauseEnd = data.ClauseEnd;
		final hasDefaultClause = clauseStart == clauseEnd || (defaultIndex >= clauseStart && defaultIndex < clauseEnd);
		// First, narrow away all of the cases that preceded this set of cases.
		for (i in 0...clauseStart) {
			final clause = clauses[i];
			if (clause.Kind == KindCaseClause) {
				t = c.narrowType(f, t, clause.Expression(), false /*assumeTrue*/);
			}
		}
		// If our current set has a default, then none the other cases were hit either.
		// There's no point in narrowing by the other cases in the set, since we can
		// get here through other paths.
		if (hasDefaultClause) {
			for (i in clauseEnd...clauses.length) {
				final clause = clauses[i];
				if (clause.Kind == KindCaseClause) {
					t = c.narrowType(f, t, clause.Expression(), false /*assumeTrue*/);
				}
			}
			return t;
		}
		// Now, narrow based on the cases in this set.
		final narrowedT = t;
		return c.getUnionType(Core.Map(clauses.slice(clauseStart, clauseEnd), function(clause:Node):Type {
			if (clause.Kind == KindCaseClause) {
				return c.narrowType(f, narrowedT, clause.Expression(), true /*assumeTrue*/);
			}
			return c.neverType;
		}));
	}

	static function narrowTypeBySwitchOptionalChainContainment(c:Checker, t:Type, data:FlowSwitchClauseData, clauseCheck:(t:Type) -> Bool):Type {
		final everyClauseChecks = data.ClauseStart != data.ClauseEnd
			&& Core.Every(c.getSwitchClauseTypes(data.SwitchStatement).slice(data.ClauseStart, data.ClauseEnd), clauseCheck);
		if (everyClauseChecks) {
			return c.getTypeWithFacts(t, TypeFactsNEUndefinedOrNull);
		}
		return t;
	}

	static function narrowTypeBySwitchOnDiscriminantProperty(c:Checker, t:Type, access:Node, data:FlowSwitchClauseData):Type {
		if (data.ClauseStart < data.ClauseEnd && (t.flags & TypeFlagsUnion) != 0) {
			final accessedOrNull = c.getAccessedPropertyName(access);
			final accessedName = accessedOrNull == null ? "" : accessedOrNull; // Go: "" when not ok
			if (accessedName != "" && c.getKeyPropertyName(t) == accessedName) {
				final clauseTypes = c.getSwitchClauseTypes(data.SwitchStatement).slice(data.ClauseStart, data.ClauseEnd);
				final candidate = c.getUnionType(Core.Map(clauseTypes, function(s:Type):Type {
					final result = c.getConstituentTypeForKeyType(t, s);
					if (result != null) {
						return result;
					}
					return c.unknownType;
				}));
				if (candidate != c.unknownType) {
					return candidate;
				}
			}
		}
		return c.narrowTypeByDiscriminant(t, access, function(t:Type):Type {
			return c.narrowTypeBySwitchOnDiscriminant(t, data);
		});
	}

	static function getTypeAtFlowBranchLabel(c:Checker, f:FlowState, flow:FlowNode, antecedents:FlowList):FlowType {
		if (c.antecedentTypes == null) {
			c.antecedentTypes = [];
		}
		final antecedentStart = c.antecedentTypes.length;
		var subtypeReduction = false;
		var seenIncomplete = false;
		var bypassFlow:FlowNode = null;
		var list = antecedents;
		while (list != null) {
			final antecedent = list.Flow;
			if (bypassFlow == null && (antecedent.Flags & FlowFlagsSwitchClause) != 0 && antecedent.Node.AsFlowSwitchClauseData().IsEmpty()) {
				// The antecedent is the bypass branch of a potentially exhaustive switch statement.
				bypassFlow = antecedent;
				list = list.Next;
				continue;
			}
			final flowType = c.getTypeAtFlowNode(f, antecedent);
			// If the type at a particular antecedent path is the declared type and the
			// reference is known to always be assigned (i.e. when declared and initial types
			// are the same), there is no reason to process more antecedents since the only
			// possible outcome is subtypes that will be removed in the final union type anyway.
			if (flowType.t == f.declaredType && f.declaredType == f.initialType) {
				c.antecedentTypes.resize(antecedentStart);
				return FlowType.of(flowType.t, false);
			}
			if (!containsTypeFrom(c.antecedentTypes, antecedentStart, flowType.t)) {
				c.antecedentTypes.push(flowType.t);
			}
			// If an antecedent type is not a subset of the declared type, we need to perform
			// subtype reduction. This happens when a "foreign" type is injected into the control
			// flow using the instanceof operator or a user defined type predicate.
			if (!c.isTypeSubsetOf(flowType.t, f.initialType)) {
				subtypeReduction = true;
			}
			if (flowType.incomplete) {
				seenIncomplete = true;
			}
			list = list.Next;
		}
		if (bypassFlow != null) {
			final flowType = c.getTypeAtFlowNode(f, bypassFlow);
			// If the bypass flow contributes a type we haven't seen yet and the switch statement
			// isn't exhaustive, process the bypass flow type. Since exhaustiveness checks increase
			// the risk of circularities, we only want to perform them when they make a difference.
			if ((flowType.t.flags & TypeFlagsNever) == 0 && !containsTypeFrom(c.antecedentTypes, antecedentStart, flowType.t)
				&& !c.isExhaustiveSwitchStatement(bypassFlow.Node.AsFlowSwitchClauseData().SwitchStatement)) {
				if (flowType.t == f.declaredType && f.declaredType == f.initialType) {
					c.antecedentTypes.resize(antecedentStart);
					return FlowType.of(flowType.t, false);
				}
				c.antecedentTypes.push(flowType.t);
				if (!c.isTypeSubsetOf(flowType.t, f.initialType)) {
					subtypeReduction = true;
				}
				if (flowType.incomplete) {
					seenIncomplete = true;
				}
			}
		}
		final result = c.newFlowType(c.getUnionOrEvolvingArrayType(f, c.antecedentTypes.slice(antecedentStart),
			Core.IfElse(subtypeReduction, UnionReductionSubtype, UnionReductionLiteral)), seenIncomplete);
		c.antecedentTypes.resize(antecedentStart);
		return result;
	}

	// At flow control branch or loop junctions, if the type along every antecedent code path
	// is an evolving array type, we construct a combined evolving array type. Otherwise we
	// finalize all evolving array types.
	static function getUnionOrEvolvingArrayType(c:Checker, f:FlowState, types:Array<Type>, subtypeReduction:UnionReduction):Type {
		if (Checker.isEvolvingArrayTypeList(types)) {
			return c.getEvolvingArrayType(c.getUnionType(Core.Map(types, t -> c.getElementTypeOfEvolvingArrayType(t))));
		}
		final result = c.recombineUnknownType(c.getUnionTypeEx(Core.SameMap(types, t -> c.finalizeEvolvingArrayType(t)), subtypeReduction, null, null));
		if (result != f.declaredType && (result.flags & f.declaredType.flags & TypeFlagsUnion) != 0
			&& Slices.Equal(result.AsUnionType().types, f.declaredType.AsUnionType().types)) {
			return f.declaredType;
		}
		return result;
	}

	static function getTypeAtFlowLoopLabel(c:Checker, f:FlowState, flow:FlowNode):FlowType {
		if (f.refKey.IsZero()) {
			f.refKey = c.getFlowReferenceKey(f);
		}
		if (sameCacheHashKey(f.refKey, Checker.nonDottedNameCacheKey)) {
			// No cache key is generated when binding patterns are in unnarrowable situations
			return FlowType.of(f.declaredType, false);
		}
		final key = new FlowLoopKey();
		key.flowNode = flow;
		key.refKey = f.refKey;
		final keyString = key.Key(c);
		// If we have previously computed the control flow type for the reference at
		// this flow loop junction, return the cached type.
		final cached = c.flowLoopCache.get(keyString);
		if (cached != null) {
			return FlowType.of(cached, false);
		}
		// If this flow loop junction and reference are already being processed, return
		// the union of the types computed for each branch so far, marked as incomplete.
		// It is possible to see an empty array in cases where loops are nested and the
		// back edge of the outer loop reaches an inner loop that is already being analyzed.
		// In such cases we restart the analysis of the inner loop, which will then see
		// a non-empty in-process array for the outer loop and eventually terminate because
		// the first antecedent of a loop junction is always the non-looping control flow
		// path that leads to the top.
		if (c.flowLoopStack != null) {
			for (loopInfo in c.flowLoopStack) {
				if (loopInfo.key.flowNode == key.flowNode && sameCacheHashKey(loopInfo.key.refKey, key.refKey) && Core.len(loopInfo.types) != 0) {
					return c.newFlowType(c.getUnionOrEvolvingArrayType(f, loopInfo.types, UnionReductionLiteral), true /*incomplete*/);
				}
			}
		}
		// Add the flow loop junction and reference to the in-process stack and analyze
		// each antecedent code path.
		// PORT: the Go slice header in FlowLoopInfo sees appends only up to its captured length; it is
		// read only while the antecedent at that point is analyzed, so the shared array is equivalent.
		var antecedentTypes:Array<Type> = [];
		var subtypeReduction = false;
		var firstAntecedentType:FlowType = FlowType.nil;
		var list = flow.Antecedents;
		while (list != null) {
			var flowType:FlowType;
			if (firstAntecedentType.isNil()) {
				// The first antecedent of a loop junction is always the non-looping control
				// flow path that leads to the top.
				firstAntecedentType = c.getTypeAtFlowNode(f, list.Flow);
				flowType = firstAntecedentType;
			} else {
				// All but the first antecedent are the looping control flow paths that lead
				// back to the loop junction. We track these on the flow loop stack.
				final loopInfo = new FlowLoopInfo();
				loopInfo.key = key;
				loopInfo.types = antecedentTypes;
				if (c.flowLoopStack == null) {
					c.flowLoopStack = [];
				}
				c.flowLoopStack.push(loopInfo);
				final saveFlowTypeCache = c.flowTypeCache;
				c.flowTypeCache = null;
				flowType = c.getTypeAtFlowNode(f, list.Flow);
				c.flowTypeCache = saveFlowTypeCache;
				c.flowLoopStack.resize(c.flowLoopStack.length - 1);
				// If we see a value appear in the cache it is a sign that control flow analysis
				// was restarted and completed by checkExpressionCached. We can simply pick up
				// the resulting type and bail out.
				final cached = c.flowLoopCache.get(keyString);
				if (cached != null) {
					return FlowType.of(cached, false);
				}
			}
			antecedentTypes = Core.AppendIfUnique(antecedentTypes, flowType.t);
			// If an antecedent type is not a subset of the declared type, we need to perform
			// subtype reduction. This happens when a "foreign" type is injected into the control
			// flow using the instanceof operator or a user defined type predicate.
			if (!c.isTypeSubsetOf(flowType.t, f.initialType)) {
				subtypeReduction = true;
			}
			// If the type at a particular antecedent path is the declared type there is no
			// reason to process more antecedents since the only possible outcome is subtypes
			// that will be removed in the final union type anyway.
			if (flowType.t == f.declaredType) {
				break;
			}
			list = list.Next;
		}
		// The result is incomplete if the first antecedent (the non-looping control flow path)
		// is incomplete.
		final result = c.getUnionOrEvolvingArrayType(f, antecedentTypes, Core.IfElse(subtypeReduction, UnionReductionSubtype, UnionReductionLiteral));
		if (firstAntecedentType.incomplete) {
			return c.newFlowType(result, true /*incomplete*/);
		}
		c.flowLoopCache.set(keyString, result);
		return FlowType.of(result, false);
	}

	static function getTypeAtFlowArrayMutation(c:Checker, f:FlowState, flow:FlowNode):FlowType {
		if (f.declaredType == c.autoType || f.declaredType == c.autoArrayType) {
			final node = flow.Node;
			var expr:Node;
			if (Ast.IsCallExpression(node)) {
				expr = node.Expression().Expression();
			} else {
				expr = node.AsBinaryExpression().Left.Expression();
			}
			if (c.isMatchingReference(f.reference, c.getReferenceCandidate(expr))) {
				final flowType = c.getTypeAtFlowNode(f, flow.Antecedent);
				if ((flowType.t.objectFlags & ObjectFlagsEvolvingArray) != 0) {
					var evolvedType = flowType.t;
					if (Ast.IsCallExpression(node)) {
						for (arg in node.Arguments()) {
							evolvedType = c.addEvolvingArrayElementType(evolvedType, arg);
						}
					} else {
						// We must get the context free expression type so as to not recur in an uncached fashion on the LHS (which causes exponential blowup in compile time)
						final indexType = c.getContextFreeTypeOfExpression(node.AsBinaryExpression().Left.AsElementAccessExpression().ArgumentExpression);
						if (c.isTypeAssignableToKind(indexType, TypeFlagsNumberLike)) {
							evolvedType = c.addEvolvingArrayElementType(evolvedType, node.AsBinaryExpression().Right);
						}
					}
					return c.newFlowType(evolvedType, flowType.incomplete);
				}
				return flowType;
			}
		}
		return FlowType.nil;
	}

	static function getDiscriminantPropertyAccess(c:Checker, f:FlowState, expr:Node, computedType:Type):Node {
		// As long as the computed type is a subset of the declared type, we use the full declared type to detect
		// a discriminant property. In cases where the computed type isn't a subset, e.g because of a preceding type
		// predicate narrowing, we use the actual computed type.
		if ((f.declaredType.flags & TypeFlagsUnion) != 0 || (computedType.flags & TypeFlagsUnion) != 0) {
			final access = c.getCandidateDiscriminantPropertyAccess(f, expr);
			if (access != null) {
				final accessed = c.getAccessedPropertyName(access);
				if (accessed != null) {
					var t = computedType;
					if ((f.declaredType.flags & TypeFlagsUnion) != 0 && c.isTypeSubsetOf(computedType, f.declaredType)) {
						t = f.declaredType;
					}
					if (c.isDiscriminantProperty(t, accessed)) {
						return access;
					}
				}
			}
		}
		return null;
	}

	static function getCandidateDiscriminantPropertyAccess(c:Checker, f:FlowState, expr:Node):Node {
		if (Ast.IsBindingPattern(f.reference) || Ast.IsFunctionExpressionOrArrowFunction(f.reference) || Ast.IsObjectLiteralMethod(f.reference)) {
			// When the reference is a binding pattern or function or arrow expression, we are narrowing a pseudo-reference in
			// getNarrowedTypeOfSymbol. An identifier for a destructuring variable declared in the same binding pattern or
			// parameter declared in the same parameter list is a candidate.
			if (Ast.IsIdentifier(expr)) {
				final symbol = c.getResolvedSymbol(expr);
				final declaration = c.getExportSymbolOfValueSymbolIfExported(symbol).ValueDeclaration;
				if (declaration != null && (Ast.IsBindingElement(declaration) || Ast.IsParameterDeclaration(declaration))
					&& f.reference == declaration.Parent && declaration.Initializer() == null && !Checker.hasDotDotDotToken(declaration)) {
					return declaration;
				}
			}
		} else if (Ast.IsAccessExpression(expr)) {
			// An access expression is a candidate if the reference matches the left hand expression.
			if (c.isMatchingReference(f.reference, expr.Expression())) {
				return expr;
			}
		} else if (Ast.IsIdentifier(expr)) {
			final symbol = c.getResolvedSymbol(expr);
			if (c.isConstantVariable(symbol)) {
				final declaration = symbol.ValueDeclaration;
				var initializer = Checker.getCandidateVariableDeclarationInitializer(declaration);
				// Given 'const x = obj.kind', allow 'x' as an alias for 'obj.kind'
				if (initializer != null && Ast.IsAccessExpression(initializer) && c.isMatchingReference(f.reference, initializer.Expression())) {
					return initializer;
				}
				// Given 'const { kind: x } = obj', allow 'x' as an alias for 'obj.kind'
				if (Ast.IsBindingElement(declaration) && declaration.Initializer() == null) {
					initializer = Checker.getCandidateVariableDeclarationInitializer(declaration.Parent.Parent);
					if (initializer != null && (Ast.IsIdentifier(initializer) || Ast.IsAccessExpression(initializer))
						&& c.isMatchingReference(f.reference, initializer)) {
						return declaration;
					}
				}
			}
		}
		return null;
	}

	// An evolving array type tracks the element types that have so far been seen in an
	// 'x.push(value)' or 'x[n] = value' operation along the control flow graph. Evolving
	// array types are ultimately converted into manifest array types (using getFinalArrayType)
	// and never escape the getFlowTypeOfReference function.
	static function getEvolvingArrayType(c:Checker, elementType:Type):Type {
		final key = CachedTypeKey.keyOf(CachedTypeKindEvolvingArrayType, elementType.id);
		var result = c.cachedTypes.get(key);
		if (result == null) {
			result = c.newObjectType(ObjectFlagsEvolvingArray, null);
			result.AsEvolvingArrayType().elementType = elementType;
			c.cachedTypes.set(key, result);
		}
		return result;
	}

	static function getElementTypeOfEvolvingArrayType(c:Checker, t:Type):Type {
		if ((t.objectFlags & ObjectFlagsEvolvingArray) != 0) {
			return t.AsEvolvingArrayType().elementType;
		}
		return c.neverType;
	}

	// Return true if the given node is 'x' in an 'x.length', x.push(value)', 'x.unshift(value)' or
	// 'x[n] = value' operation, where 'n' is an expression of type any, undefined, or a number-like type.
	static function isEvolvingArrayOperationTarget(c:Checker, node:Node):Bool {
		final root = c.getReferenceRoot(node);
		final parent = root.Parent;
		final isLengthPushOrUnshift = Ast.IsPropertyAccessExpression(parent)
			&& (parent.Name().Text() == "length"
				|| Ast.IsCallExpression(parent.Parent) && Ast.IsIdentifier(parent.Name()) && Ast.IsPushOrUnshiftIdentifier(parent.Name()));
		final isElementAssignment = Ast.IsElementAccessExpression(parent) && parent.Expression() == root
			&& Ast.IsBinaryExpression(parent.Parent) && parent.Parent.AsBinaryExpression().OperatorToken.Kind == KindEqualsToken
			&& parent.Parent.AsBinaryExpression().Left == parent && !Ast.IsAssignmentTarget(parent.Parent)
			&& c.isTypeAssignableToKind(c.getTypeOfExpression(parent.AsElementAccessExpression().ArgumentExpression), TypeFlagsNumberLike);
		return isLengthPushOrUnshift || isElementAssignment;
	}

	// When adding evolving array element types we do not perform subtype reduction. Instead,
	// we defer subtype reduction until the evolving array type is finalized into a manifest
	// array type.
	static function addEvolvingArrayElementType(c:Checker, evolvingArrayType:Type, node:Node):Type {
		final newElementType = c.getRegularTypeOfObjectLiteral(c.getBaseTypeOfLiteralType(c.getContextFreeTypeOfExpression(node)));
		final elementType = evolvingArrayType.AsEvolvingArrayType().elementType;
		if (c.isTypeSubsetOf(newElementType, elementType)) {
			return evolvingArrayType;
		}
		return c.getEvolvingArrayType(c.getUnionType([elementType, newElementType]));
	}

	static function finalizeEvolvingArrayType(c:Checker, t:Type):Type {
		if ((t.objectFlags & ObjectFlagsEvolvingArray) != 0) {
			return c.getFinalArrayType(t.AsEvolvingArrayType());
		}
		return t;
	}

	static function getFinalArrayType(c:Checker, t:EvolvingArrayType):Type {
		if (t.finalArrayType == null) {
			t.finalArrayType = c.createFinalArrayType(t.elementType);
		}
		return t.finalArrayType;
	}

	static function createFinalArrayType(c:Checker, elementType:Type):Type {
		if ((elementType.flags & TypeFlagsNever) != 0) {
			return c.autoArrayType;
		} else if ((elementType.flags & TypeFlagsUnion) != 0) {
			return c.createArrayType(c.getUnionTypeEx(elementType.Types(), UnionReductionSubtype, null, null));
		}
		return c.createArrayType(elementType);
	}

	static function reportFlowControlError(c:Checker, node:Node):Void {
		final block = Ast.FindAncestor(node, Ast.IsFunctionOrModuleBlock);
		final sourceFile = Ast.GetSourceFileOfNode(node);
		final span = Scanner.GetRangeOfTokenAtPosition(sourceFile, block.StatementList().Pos());
		c.addDiagnostic(Ast.NewDiagnostic(sourceFile, span, Diagnostics.The_containing_function_or_module_body_is_too_large_for_control_flow_analysis));
	}

	static function isMatchingReference(c:Checker, source:Node, target:Node):Bool {
		switch (target.Kind) {
			case KindParenthesizedExpression | KindNonNullExpression:
				return c.isMatchingReference(source, target.Expression());
			case KindBinaryExpression:
				return Ast.IsAssignmentExpression(target, false) && c.isMatchingReference(source, target.AsBinaryExpression().Left)
					|| Ast.IsBinaryExpression(target) && target.AsBinaryExpression().OperatorToken.Kind == KindCommaToken
					&& c.isMatchingReference(source, target.AsBinaryExpression().Right);
			default:
		}
		switch (source.Kind) {
			case KindMetaProperty:
				return Ast.IsMetaProperty(target) && source.AsMetaProperty().KeywordToken == target.AsMetaProperty().KeywordToken
					&& source.Name().Text() == target.Name().Text();
			case KindIdentifier | KindPrivateIdentifier:
				if (Ast.IsThisInTypeQuery(source)) {
					return target.Kind == KindThisKeyword;
				}
				return Ast.IsIdentifier(target) && c.getResolvedSymbol(source) == c.getResolvedSymbol(target)
					|| (Ast.IsVariableDeclaration(target) || Ast.IsBindingElement(target))
					&& c.getExportSymbolOfValueSymbolIfExported(c.getResolvedSymbol(source)) == c.getSymbolOfDeclaration(target);
			case KindThisKeyword:
				return target.Kind == KindThisKeyword;
			case KindSuperKeyword:
				return target.Kind == KindSuperKeyword;
			case KindNonNullExpression | KindParenthesizedExpression | KindSatisfiesExpression:
				return c.isMatchingReference(source.Expression(), target);
			case KindPropertyAccessExpression | KindElementAccessExpression:
				final sourcePropertyName = c.getAccessedPropertyName(source);
				if (sourcePropertyName != null) {
					if (Ast.IsAccessExpression(target)) {
						final targetPropertyName = c.getAccessedPropertyName(target);
						if (targetPropertyName != null) {
							return targetPropertyName == sourcePropertyName && c.isMatchingReference(source.Expression(), target.Expression());
						}
					}
				}
				if (Ast.IsElementAccessExpression(source) && Ast.IsElementAccessExpression(target)) {
					final sourceArg = source.AsElementAccessExpression().ArgumentExpression;
					final targetArg = target.AsElementAccessExpression().ArgumentExpression;
					if (Ast.IsIdentifier(sourceArg) && Ast.IsIdentifier(targetArg)) {
						final symbol = c.getResolvedSymbol(sourceArg);
						if (symbol == c.getResolvedSymbol(targetArg)
							&& (c.isConstantVariable(symbol) || c.isParameterOrMutableLocalVariable(symbol) && !c.isSymbolAssigned(symbol))) {
							return c.isMatchingReference(source.Expression(), target.Expression());
						}
					}
				}
			case KindQualifiedName:
				if (Ast.IsAccessExpression(target)) {
					final targetPropertyName = c.getAccessedPropertyName(target);
					if (targetPropertyName != null) {
						return source.AsQualifiedName().Right.Text() == targetPropertyName
							&& c.isMatchingReference(source.AsQualifiedName().Left, target.Expression());
					}
				}
			case KindBinaryExpression:
				return Ast.IsBinaryExpression(source) && source.AsBinaryExpression().OperatorToken.Kind == KindCommaToken
					&& c.isMatchingReference(source.AsBinaryExpression().Right, target);
			default:
		}
		return false;
	}

	// Return the flow cache key for a "dotted name" (i.e. a sequence of identifiers
	// separated by dots). The key consists of the id of the symbol referenced by the
	// leftmost identifier followed by zero or more property names separated by dots.
	// The result is nonDottedNameCacheKey if the reference isn't a dotted name.
	static function getFlowReferenceKey(c:Checker, f:FlowState):CacheHashKey {
		final b = new KeyBuilder();
		if (c.writeFlowCacheKey(b, f.reference, f.declaredType, f.initialType, f.flowContainer)) {
			return b.hash();
		}
		return Checker.nonDottedNameCacheKey; // Reference isn't a dotted name
	}

	static function writeFlowCacheKey(c:Checker, b:KeyBuilder, node:Node, declaredType:Type, initialType:Type, flowContainer:Node):Bool {
		// PORT: fallthrough (KindIdentifier into KindThisKeyword) via a local function.
		inline function writeThisKeywordCase():Bool {
			b.writeByte(":".code);
			b.writeType(declaredType);
			if (initialType != declaredType) {
				b.writeByte("=".code);
				b.writeType(initialType);
			}
			if (flowContainer != null) {
				b.writeByte("@".code);
				b.writeNode(flowContainer);
			}
			return true;
		}
		switch (node.Kind) {
			case KindIdentifier:
				if (!Ast.IsThisInTypeQuery(node)) {
					final symbol = c.getResolvedSymbol(node);
					if (symbol == c.unknownSymbol) {
						return false;
					}
					b.writeSymbol(symbol);
				}
				return writeThisKeywordCase();
			case KindThisKeyword:
				return writeThisKeywordCase();
			case KindNonNullExpression | KindParenthesizedExpression:
				return c.writeFlowCacheKey(b, node.Expression(), declaredType, initialType, flowContainer);
			case KindQualifiedName:
				if (!c.writeFlowCacheKey(b, node.AsQualifiedName().Left, declaredType, initialType, flowContainer)) {
					return false;
				}
				b.writeByte(".".code);
				b.writeString(node.AsQualifiedName().Right.Text());
				return true;
			case KindPropertyAccessExpression | KindElementAccessExpression:
				final accessed = c.getAccessedPropertyName(node);
				if (accessed != null) {
					if (!c.writeFlowCacheKey(b, node.Expression(), declaredType, initialType, flowContainer)) {
						return false;
					}
					b.writeByte(".".code);
					b.writeString(accessed);
					return true;
				}
				if (Ast.IsElementAccessExpression(node) && Ast.IsIdentifier(node.AsElementAccessExpression().ArgumentExpression)) {
					final symbol = c.getResolvedSymbol(node.AsElementAccessExpression().ArgumentExpression);
					if (c.isConstantVariable(symbol) || c.isParameterOrMutableLocalVariable(symbol) && !c.isSymbolAssigned(symbol)) {
						if (!c.writeFlowCacheKey(b, node.Expression(), declaredType, initialType, flowContainer)) {
							return false;
						}
						b.writeString(".@");
						b.writeSymbol(symbol);
						return true;
					}
				}
			case KindObjectBindingPattern | KindArrayBindingPattern | KindFunctionDeclaration | KindFunctionExpression | KindArrowFunction | KindMethodDeclaration:
				b.writeNode(node);
				b.writeByte("#".code);
				b.writeType(declaredType);
				return true;
			default:
		}
		return false;
	}

	// PORT: perf — Go returns (string, bool); here the name, or null for ok == false (no result object
	// per call: it runs for every reference matched during control flow analysis).
	static function getAccessedPropertyName(c:Checker, access:Node):Null<std.String> {
		if (Ast.IsPropertyAccessExpression(access)) {
			return access.Name().Text();
		}
		if (Ast.IsElementAccessExpression(access)) {
			final r = c.tryGetElementAccessExpressionName(access.AsElementAccessExpression());
			return r.ok ? r.value : null;
		}
		if (Ast.IsBindingElement(access)) {
			final r = c.getDestructuringPropertyName(access);
			return r.ok ? r.value : null;
		}
		if (Ast.IsParameterDeclaration(access)) {
			return Std.string(Slices.Index(access.Parent.Parameters(), access));
		}
		return null;
	}

	static function tryGetElementAccessExpressionName(c:Checker, node:ElementAccessExpression):ValueOk<std.String> {
		if (Ast.IsStringOrNumericLiteralLike(node.ArgumentExpression)) {
			return new ValueOk(node.ArgumentExpression.Text(), true);
		} else if (Ast.IsEntityNameExpression(node.ArgumentExpression)) {
			return c.tryGetNameFromEntityNameExpression(node.ArgumentExpression);
		}
		return new ValueOk("", false);
	}

	static function tryGetNameFromEntityNameExpression(c:Checker, node:Node):ValueOk<std.String> {
		final symbol = c.resolveEntityName(node, SymbolFlagsValue, true /*ignoreErrors*/, false, null);
		if (symbol == null || !(c.isConstantVariable(symbol) || (symbol.Flags & SymbolFlagsEnumMember) != 0)) {
			return new ValueOk("", false);
		}
		final declaration = symbol.ValueDeclaration;
		if (declaration == null) {
			return new ValueOk("", false);
		}
		final t = c.tryGetTypeFromTypeNode(declaration);
		if (t != null) {
			final name = Checker.tryGetNameFromType(t);
			if (name.ok) {
				return new ValueOk(name.value, true);
			}
		}
		// We exclude binding elements because their initializers don't solely determine their types and resolving
		// full types can cause circularities (see https://github.com/microsoft/TypeScript/issues/63192).
		if (Checker.hasOnlyExpressionInitializer(declaration) && !Ast.IsBindingElement(declaration) && c.isBlockScopedNameDeclaredBeforeUse(declaration, node)) {
			final initializer = declaration.Initializer();
			if (initializer != null) {
				final initializerType = c.getTypeOfExpression(initializer);
				if (initializerType != null) {
					return Checker.tryGetNameFromType(initializerType);
				}
			} else if (Ast.IsEnumMember(declaration)) {
				return Ast.TryGetTextOfPropertyName(declaration.Name());
			}
		}
		return new ValueOk("", false);
	}

	static function getDestructuringPropertyName(c:Checker, node:Node):ValueOk<std.String> {
		final parent = node.Parent;
		if (Ast.IsBindingElement(node) && Ast.IsObjectBindingPattern(parent)) {
			return c.getLiteralPropertyNameText(Checker.getBindingElementPropertyName(node));
		}
		if (Ast.IsPropertyAssignment(node) || Ast.IsShorthandPropertyAssignment(node)) {
			return c.getLiteralPropertyNameText(node.Name());
		}
		if (Ast.IsArrayLiteralExpression(parent) || Ast.IsArrayBindingPattern(parent)) {
			return new ValueOk(Std.string(Slices.Index(parent.Elements(), node)), true);
		}
		return new ValueOk("", false);
	}

	static function getLiteralPropertyNameText(c:Checker, name:Node):ValueOk<std.String> {
		final t = c.getLiteralTypeFromPropertyName(name);
		if ((t.flags & (TypeFlagsStringLiteral | TypeFlagsNumberLiteral)) != 0) {
			return new ValueOk(Evaluator.AnyToString(t.AsLiteralType().value), true);
		}
		return new ValueOk("", false);
	}

	static function isConstantReference(c:Checker, node:Node):Bool {
		switch (node.Kind) {
			case KindThisKeyword:
				return true;
			case KindIdentifier:
				if (!Ast.IsThisInTypeQuery(node)) {
					final symbol = c.getResolvedSymbol(node);
					return c.isConstantVariable(symbol) || c.isParameterOrMutableLocalVariable(symbol) && !c.isSymbolAssigned(symbol)
						|| symbol.ValueDeclaration != null && Ast.IsFunctionExpression(symbol.ValueDeclaration);
				}
			case KindPropertyAccessExpression | KindElementAccessExpression:
				// The resolvedSymbol property is initialized by checkPropertyAccess or checkElementAccess before we get here.
				if (c.isConstantReference(node.Expression())) {
					final symbol = c.getResolvedSymbolOrNil(node);
					if (symbol != null) {
						return c.isReadonlySymbol(symbol);
					}
				}
			case KindObjectBindingPattern | KindArrayBindingPattern:
				final rootDeclaration = Ast.GetRootDeclaration(node.Parent);
				if (Ast.IsParameterDeclaration(rootDeclaration) || Ast.IsVariableDeclaration(rootDeclaration) && Ast.IsCatchClause(rootDeclaration.Parent)) {
					return !c.isSomeSymbolAssigned(rootDeclaration);
				}
				return Ast.IsVariableDeclaration(rootDeclaration) && c.isVarConstLike(rootDeclaration);
			default:
		}
		return false;
	}

	static function containsMatchingReference(c:Checker, source:Node, target:Node):Bool {
		while (Ast.IsAccessExpression(source)) {
			source = source.Expression();
			if (c.isMatchingReference(source, target)) {
				return true;
			}
		}
		return false;
	}

	static function optionalChainContainsReference(c:Checker, source:Node, target:Node):Bool {
		while (Ast.IsOptionalChain(source)) {
			source = source.Expression();
			if (c.isMatchingReference(source, target)) {
				return true;
			}
		}
		return false;
	}

	static function getReferenceCandidate(c:Checker, node:Node):Node {
		switch (node.Kind) {
			case KindParenthesizedExpression:
				return c.getReferenceCandidate(node.Expression());
			case KindBinaryExpression:
				switch (node.AsBinaryExpression().OperatorToken.Kind) {
					case KindEqualsToken | KindBarBarEqualsToken | KindAmpersandAmpersandEqualsToken | KindQuestionQuestionEqualsToken:
						return c.getReferenceCandidate(node.AsBinaryExpression().Left);
					case KindCommaToken:
						return c.getReferenceCandidate(node.AsBinaryExpression().Right);
					default:
				}
			default:
		}
		return node;
	}

	static function getReferenceRoot(c:Checker, node:Node):Node {
		final parent = node.Parent;
		if (Ast.IsParenthesizedExpression(parent)
			|| Ast.IsBinaryExpression(parent) && parent.AsBinaryExpression().OperatorToken.Kind == KindEqualsToken && parent.AsBinaryExpression().Left == node
			|| Ast.IsBinaryExpression(parent) && parent.AsBinaryExpression().OperatorToken.Kind == KindCommaToken && parent.AsBinaryExpression().Right == node) {
			return c.getReferenceRoot(parent);
		}
		return node;
	}

	static function hasMatchingArgument(c:Checker, expression:Node, reference:Node):Bool {
		final arguments = expression.Arguments();
		if (arguments != null) {
			for (argument in arguments) {
				if (c.isOrContainsMatchingReference(reference, argument) || c.optionalChainContainsReference(argument, reference)) {
					return true;
				}
			}
		}
		if (Ast.IsPropertyAccessExpression(expression.Expression()) && c.isOrContainsMatchingReference(reference, expression.Expression().Expression())) {
			return true;
		}
		return false;
	}

	static function isOrContainsMatchingReference(c:Checker, source:Node, target:Node):Bool {
		return c.isMatchingReference(source, target) || c.containsMatchingReference(source, target);
	}

	// Return a new type in which occurrences of the string, number and bigint primitives and placeholder template
	// literal types in typeWithPrimitives have been replaced with occurrences of compatible and more specific types
	// from typeWithLiterals. This is essentially a limited form of intersection between the two types. We avoid a
	// true intersection because it is more costly and, when applied to union types, generates a large number of
	// types we don't actually care about.
	static function replacePrimitivesWithLiterals(c:Checker, typeWithPrimitives:Type, typeWithLiterals:Type):Type {
		if (c.maybeTypeOfKind(typeWithPrimitives, TypeFlagsString | TypeFlagsTemplateLiteral | TypeFlagsNumber | TypeFlagsBigInt)
			&& c.maybeTypeOfKind(typeWithLiterals,
				TypeFlagsStringLiteral | TypeFlagsTemplateLiteral | TypeFlagsStringMapping | TypeFlagsNumberLiteral | TypeFlagsBigIntLiteral)) {
			return c.mapType(typeWithPrimitives, function(t:Type):Type {
				if ((t.flags & TypeFlagsString) != 0) {
					return c.extractTypesOfKind(typeWithLiterals, TypeFlagsString | TypeFlagsStringLiteral | TypeFlagsTemplateLiteral | TypeFlagsStringMapping);
				} else if (c.isPatternLiteralType(t) && !c.maybeTypeOfKind(typeWithLiterals, TypeFlagsString | TypeFlagsTemplateLiteral | TypeFlagsStringMapping)) {
					return c.extractTypesOfKind(typeWithLiterals, TypeFlagsStringLiteral);
				} else if ((t.flags & TypeFlagsNumber) != 0) {
					return c.extractTypesOfKind(typeWithLiterals, TypeFlagsNumber | TypeFlagsNumberLiteral);
				} else if ((t.flags & TypeFlagsBigInt) != 0) {
					return c.extractTypesOfKind(typeWithLiterals, TypeFlagsBigInt | TypeFlagsBigIntLiteral);
				} else {
					return t;
				}
			});
		}
		return typeWithPrimitives;
	}

	static function isExhaustiveSwitchStatement(c:Checker, node:Node):Bool {
		final links = c.switchStatementLinks.Get(node);
		if (links.exhaustiveState == ExhaustiveStateUnknown) {
			// Indicate resolution is in process
			links.exhaustiveState = ExhaustiveStateComputing;
			final isExhaustive = c.computeExhaustiveSwitchStatement(node);
			if (links.exhaustiveState == ExhaustiveStateComputing) {
				links.exhaustiveState = Core.IfElse(isExhaustive, ExhaustiveStateTrue, ExhaustiveStateFalse);
			}
		} else if (links.exhaustiveState == ExhaustiveStateComputing) {
			// Resolve circularity to false
			links.exhaustiveState = ExhaustiveStateFalse;
		}
		return links.exhaustiveState == ExhaustiveStateTrue;
	}

	static function computeExhaustiveSwitchStatement(c:Checker, node:Node):Bool {
		if (Ast.IsTypeOfExpression(node.Expression())) {
			final witnesses = c.getSwitchClauseTypeOfWitnesses(node);
			if (witnesses == null) {
				return false;
			}
			final operandConstraint = c.getBaseConstraintOrType(c.checkExpressionCached(node.Expression().Expression()));
			// Get the not-equal flags for all handled cases.
			final notEqualFacts = c.getNotEqualFactsFromTypeofSwitch(0, 0, witnesses);
			if ((operandConstraint.flags & TypeFlagsAnyOrUnknown) != 0) {
				// We special case the top types to be exhaustive when all cases are handled.
				return (TypeFactsAllTypeofNE & notEqualFacts) == TypeFactsAllTypeofNE;
			}
			// A missing not-equal flag indicates that the type wasn't handled by some case.
			return !Checker.someType(operandConstraint, function(t:Type):Bool {
				return c.getTypeFacts(t, notEqualFacts) == notEqualFacts;
			});
		}
		final t = c.getBaseConstraintOrType(c.checkExpressionCached(node.Expression()));
		if (!Checker.isLiteralType(t)) {
			return false;
		}
		final switchTypes = c.getSwitchClauseTypes(node);
		if (Core.len(switchTypes) == 0 || Core.Some(switchTypes, Checker.isNeitherUnitTypeNorNever)) {
			return false;
		}
		return c.eachTypeContainedIn(c.mapType(t, t -> c.getRegularTypeOfLiteralType(t)), switchTypes);
	}

	static function eachTypeContainedIn(c:Checker, source:Type, types:Array<Type>):Bool {
		if ((source.flags & TypeFlagsUnion) != 0) {
			return !Core.Some(source.AsUnionType().types, function(t:Type):Bool {
				return !Slices.Contains(types, t);
			});
		}
		return Slices.Contains(types, source);
	}

	// Get the type names from all cases in a switch on `typeof`. The default clause and/or duplicate type names are
	// represented as empty strings. Return nil if one or more case clause expressions are not string literals.
	static function getSwitchClauseTypeOfWitnesses(c:Checker, node:Node):Array<std.String> {
		final links = c.switchStatementLinks.Get(node);
		if (!links.witnessesComputed) {
			final clauses = node.AsSwitchStatement().CaseBlock.AsCaseBlock().Clauses.Nodes;
			var witnesses:Array<std.String> = [for (_ in 0...clauses.length) ""];
			for (i in 0...clauses.length) {
				final clause = clauses[i];
				if (clause.Kind == KindCaseClause) {
					if (!Ast.IsStringLiteralLike(clause.Expression())) {
						witnesses = null;
						break;
					}
					final text = clause.Expression().Text();
					if (!Slices.Contains(witnesses, text)) {
						witnesses[i] = text;
					}
				}
			}
			links.witnesses = witnesses;
			links.witnessesComputed = true;
		}
		return links.witnesses;
	}

	// Return the combined not-equal type facts for all cases except those between the start and end indices.
	static function getNotEqualFactsFromTypeofSwitch(c:Checker, start:Int, end:Int, witnesses:Array<std.String>):TypeFacts {
		var facts:TypeFacts = TypeFactsNone;
		for (i in 0...witnesses.length) {
			final witness = witnesses[i];
			if ((i < start || i >= end) && witness != "") {
				var f:TypeFacts;
				if (Checker.typeofNEFacts.exists(witness)) {
					f = Checker.typeofNEFacts.get(witness);
				} else {
					f = TypeFactsTypeofNEHostObject;
				}
				facts |= f;
			}
		}
		return facts;
	}

	static function getSwitchClauseTypes(c:Checker, node:Node):Array<Type> {
		final links = c.switchStatementLinks.Get(node);
		if (!links.switchTypesComputed) {
			final clauses = node.AsSwitchStatement().CaseBlock.AsCaseBlock().Clauses.Nodes;
			final types = new Array<Type>();
			types.resize(clauses.length);
			for (i in 0...clauses.length) {
				types[i] = c.getTypeOfSwitchClause(clauses[i]);
			}
			links.switchTypes = types;
			links.switchTypesComputed = true;
		}
		return links.switchTypes;
	}

	static function getTypeOfSwitchClause(c:Checker, clause:Node):Type {
		if (clause.Kind == KindCaseClause) {
			return c.getRegularTypeOfLiteralType(c.getTypeOfExpression(clause.Expression()));
		}
		return c.neverType;
	}

	static function getEffectsSignature(c:Checker, node:Node):Signature {
		final links = c.signatureLinks.Get(node);
		var signature = links.effectsSignature;
		if (signature == null) {
			// A call expression parented by an expression statement is a potential assertion. Other call
			// expressions are potential type predicate function calls. In order to avoid triggering
			// circularities in control flow analysis, we use getTypeOfDottedName when resolving the call
			// target expression of an assertion.
			var funcType:Type = null;
			if (Ast.IsBinaryExpression(node)) {
				final rightType = c.checkNonNullExpression(node.AsBinaryExpression().Right);
				funcType = c.getSymbolHasInstanceMethodOfObjectType(rightType);
			} else if (Ast.IsExpressionStatement(node.Parent)) {
				funcType = c.getTypeOfDottedName(node.Expression(), null /*diagnostic*/);
			} else if (node.Expression().Kind != KindSuperKeyword) {
				if (Ast.IsOptionalChain(node)) {
					funcType = c.checkNonNullType(c.getOptionalExpressionType(c.checkExpression(node.Expression()), node.Expression()), node.Expression());
				} else {
					funcType = c.checkNonNullExpression(node.Expression());
				}
			}
			var apparentType:Type = null;
			if (funcType != null) {
				apparentType = c.getApparentType(funcType);
			}
			final signatures = c.getSignaturesOfType(Core.OrElse(apparentType, c.unknownType), SignatureKindCall);
			if (Core.len(signatures) == 1 && Core.len(signatures[0].typeParameters) == 0) {
				signature = signatures[0];
			} else if (Core.Some(signatures, s -> c.hasTypePredicateOrNeverReturnType(s))) {
				signature = c.getResolvedSignature(node, null, CheckModeNormal);
			}
			if (!(signature != null && c.hasTypePredicateOrNeverReturnType(signature))) {
				signature = c.unknownSignature;
			}
			links.effectsSignature = signature;
		}
		if (signature == c.unknownSignature) {
			return null;
		}
		return signature;
	}

	/**
	 * Get the type of the `[Symbol.hasInstance]` method of an object type.
	 */
	static function getSymbolHasInstanceMethodOfObjectType(c:Checker, t:Type):Type {
		final hasInstancePropertyName = c.getPropertyNameForKnownSymbolName("hasInstance");
		if (c.allTypesAssignableToKind(t, TypeFlagsNonPrimitive)) {
			final hasInstanceProperty = c.getPropertyOfType(t, hasInstancePropertyName);
			if (hasInstanceProperty != null) {
				final hasInstancePropertyType = c.getTypeOfSymbol(hasInstanceProperty);
				if (hasInstancePropertyType != null && Core.len(c.getSignaturesOfType(hasInstancePropertyType, SignatureKindCall)) != 0) {
					return hasInstancePropertyType;
				}
			}
		}
		return null;
	}

	static function getPropertyNameForKnownSymbolName(c:Checker, symbolName:std.String):std.String {
		final ctorType = c.getGlobalESSymbolConstructorSymbolOrNil();
		if (ctorType != null) {
			final uniqueType = c.getTypeOfPropertyOfType(c.getTypeOfSymbol(ctorType), symbolName);
			if (uniqueType != null && Checker.isTypeUsableAsPropertyName(uniqueType)) {
				return Checker.getPropertyNameFromType(uniqueType);
			}
		}
		return Ast.InternalSymbolNamePrefix + "@" + symbolName;
	}

	// We require the dotted function name in an assertion expression to be comprised of identifiers
	// that reference function, method, class or value module symbols; or variable, property or
	// parameter symbols with declarations that have explicit type annotations. Such references are
	// resolvable with no possibility of triggering circularities in control flow analysis.
	static function getTypeOfDottedName(c:Checker, node:Node, diagnostic:Diagnostic):Type {
		if ((node.Flags & NodeFlagsInWithStatement) == 0) {
			switch (node.Kind) {
				case KindIdentifier:
					final symbol = c.getExportSymbolOfValueSymbolIfExported(c.getResolvedSymbol(node));
					return c.getExplicitTypeOfSymbol(symbol, diagnostic);
				case KindThisKeyword:
					return c.getExplicitThisType(node);
				case KindSuperKeyword:
					return c.checkSuperExpression(node);
				case KindPropertyAccessExpression:
					final t = c.getTypeOfDottedName(node.Expression(), diagnostic);
					if (t != null) {
						final name = node.Name();
						var prop:Symbol = null;
						if (Ast.IsPrivateIdentifier(name)) {
							if (t.symbol != null) {
								prop = c.getPropertyOfType(t, Binder.GetSymbolNameForPrivateIdentifier(t.symbol, name.Text()));
							}
						} else {
							prop = c.getPropertyOfType(t, name.Text());
						}
						if (prop != null) {
							return c.getExplicitTypeOfSymbol(prop, diagnostic);
						}
					}
				case KindParenthesizedExpression:
					return c.getTypeOfDottedName(node.Expression(), diagnostic);
				default:
			}
		}
		return null;
	}

	static function getExplicitTypeOfSymbol(c:Checker, symbol:Symbol, diagnostic:Diagnostic):Type {
		symbol = c.resolveSymbol(symbol);
		if ((symbol.Flags & (SymbolFlagsFunction | SymbolFlagsMethod | SymbolFlagsClass | SymbolFlagsValueModule)) != 0) {
			return c.getTypeOfSymbol(symbol);
		}
		if ((symbol.Flags & (SymbolFlagsVariable | SymbolFlagsProperty)) != 0) {
			if ((symbol.CheckFlags & CheckFlagsMapped) != 0) {
				final origin = c.mappedSymbolLinks.Get(symbol).syntheticOrigin;
				if (origin != null && c.getExplicitTypeOfSymbol(origin, diagnostic) != null) {
					return c.getTypeOfSymbol(symbol);
				}
			}
			final declaration = symbol.ValueDeclaration;
			if (declaration != null) {
				if (c.isDeclarationWithExplicitTypeAnnotation(declaration)) {
					return c.getTypeOfSymbol(symbol);
				}
				if (Ast.IsVariableDeclaration(declaration) && Ast.IsForOfStatement(declaration.Parent.Parent)) {
					final statement = declaration.Parent.Parent;
					final expressionType = c.getTypeOfDottedName(statement.Expression(), null /*diagnostic*/);
					if (expressionType != null) {
						var use:IterationUse;
						if (statement.AsForInOrOfStatement().AwaitModifier != null) {
							use = IterationUseForAwaitOf;
						} else {
							use = IterationUseForOf;
						}
						return c.checkIteratedTypeOrElementType(use, expressionType, c.undefinedType, null /*errorNode*/);
					}
				}
				if (diagnostic != null) {
					diagnostic.AddRelatedInfo(Checker.createDiagnosticForNode(declaration, Diagnostics.X_0_needs_an_explicit_type_annotation, c.symbolToString(symbol)));
				}
			}
		}
		return null;
	}

	static function isDeclarationWithExplicitTypeAnnotation(c:Checker, node:Node):Bool {
		return (Ast.IsVariableDeclaration(node) || Ast.IsPropertyDeclaration(node) || Ast.IsPropertySignatureDeclaration(node) || Ast.IsParameterDeclaration(node))
			&& node.Type() != null
			|| c.isExpandoPropertyFunctionWithReturnTypeAnnotation(node);
	}

	static function isExpandoPropertyFunctionWithReturnTypeAnnotation(c:Checker, node:Node):Bool {
		if (Ast.IsBinaryExpression(node)) {
			final expr = node.AsBinaryExpression().Right;
			if (Ast.IsFunctionLike(expr) && expr.Type() != null) {
				return true;
			}
		}
		return false;
	}

	static function hasTypePredicateOrNeverReturnType(c:Checker, sig:Signature):Bool {
		return c.getTypePredicateOfSignature(sig) != null
			|| sig.declaration != null && (Core.OrElse(c.getReturnTypeFromAnnotation(sig.declaration), c.unknownType).flags & TypeFlagsNever) != 0;
	}

	static function getExplicitThisType(c:Checker, node:Node):Type {
		final container = Ast.GetThisContainer(node, false /*includeArrowFunctions*/, false /*includeClassComputedPropertyName*/);
		if (Ast.IsFunctionLike(container)) {
			final signature = c.getSignatureFromDeclaration(container);
			if (signature.thisParameter != null) {
				return c.getExplicitTypeOfSymbol(signature.thisParameter, null);
			}
		}
		if (container.Parent != null && Ast.IsClassLike(container.Parent)) {
			final symbol = c.getSymbolOfDeclaration(container.Parent);
			if (Ast.IsStatic(container)) {
				return c.getTypeOfSymbol(symbol);
			} else {
				return c.getDeclaredTypeOfSymbol(symbol).AsInterfaceType().thisType;
			}
		}
		return null;
	}

	static function getInitialType(c:Checker, node:Node):Type {
		switch (node.Kind) {
			case KindVariableDeclaration:
				return c.getInitialTypeOfVariableDeclaration(node);
			case KindBindingElement:
				return c.getInitialTypeOfBindingElement(node);
			default:
		}
		throw "Unhandled case in getInitialType";
	}

	static function getInitialTypeOfVariableDeclaration(c:Checker, node:Node):Type {
		if (node.Initializer() != null) {
			return c.getTypeOfInitializer(node.Initializer());
		}
		if (Ast.IsForInStatement(node.Parent.Parent)) {
			return c.stringType;
		}
		if (Ast.IsForOfStatement(node.Parent.Parent)) {
			final t = c.checkRightHandSideOfForOf(node.Parent.Parent);
			if (t != null) {
				return t;
			}
		}
		return c.errorType;
	}

	static function getTypeOfInitializer(c:Checker, node:Node):Type {
		// Return the cached type if one is available. If the type of the variable was inferred
		// from its initializer, we'll already have cached the type. Otherwise we compute it now
		// without caching such that transient types are reflected.
		if (c.typeNodeLinks.Has(node)) {
			final t = c.typeNodeLinks.Get(node).resolvedType;
			if (t != null) {
				return t;
			}
		}
		return c.getTypeOfExpression(node);
	}

	static function getInitialTypeOfBindingElement(c:Checker, node:Node):Type {
		final pattern = node.Parent;
		final parentType = c.getInitialType(pattern.Parent);
		var t:Type;
		if (Ast.IsObjectBindingPattern(pattern)) {
			t = c.getTypeOfDestructuredProperty(parentType, Checker.getBindingElementPropertyName(node));
		} else if (!Checker.hasDotDotDotToken(node)) {
			t = c.getTypeOfDestructuredArrayElement(parentType, Slices.Index(pattern.Elements(), node));
		} else {
			t = c.getTypeOfDestructuredSpreadExpression(parentType);
		}
		return c.getTypeWithDefault(t, node.Initializer());
	}

	static function getAssignedType(c:Checker, node:Node):Type {
		final parent = node.Parent;
		switch (parent.Kind) {
			case KindForInStatement:
				return c.stringType;
			case KindForOfStatement:
				final t = c.checkRightHandSideOfForOf(parent);
				if (t != null) {
					return t;
				}
			case KindBinaryExpression:
				return c.getAssignedTypeOfBinaryExpression(parent);
			case KindDeleteExpression:
				return c.undefinedType;
			case KindArrayLiteralExpression:
				return c.getAssignedTypeOfArrayLiteralElement(parent, node);
			case KindSpreadElement:
				return c.getAssignedTypeOfSpreadExpression(parent);
			case KindPropertyAssignment:
				return c.getAssignedTypeOfPropertyAssignment(parent);
			case KindShorthandPropertyAssignment:
				return c.getAssignedTypeOfShorthandPropertyAssignment(parent);
			default:
		}
		return c.errorType;
	}

	static function getAssignedTypeOfBinaryExpression(c:Checker, node:Node):Type {
		final isDestructuringDefaultAssignment = Ast.IsArrayLiteralExpression(node.Parent) && c.isDestructuringAssignmentTarget(node.Parent)
			|| Ast.IsPropertyAssignment(node.Parent) && c.isDestructuringAssignmentTarget(node.Parent.Parent);
		if (isDestructuringDefaultAssignment) {
			return c.getTypeWithDefault(c.getAssignedType(node), node.AsBinaryExpression().Right);
		}
		return c.getTypeOfExpression(node.AsBinaryExpression().Right);
	}

	static function getAssignedTypeOfArrayLiteralElement(c:Checker, node:Node, element:Node):Type {
		return c.getTypeOfDestructuredArrayElement(c.getAssignedType(node), Slices.Index(node.Elements(), element));
	}

	static function getTypeOfDestructuredArrayElement(c:Checker, t:Type, index:Int):Type {
		if (Checker.everyType(t, t -> c.isTupleLikeType(t))) {
			final elementType = c.getTupleElementType(t, index);
			if (elementType != null) {
				return elementType;
			}
		}
		final elementType = c.checkIteratedTypeOrElementType(IterationUseDestructuring, t, c.undefinedType, null /*errorNode*/);
		if (elementType != null) {
			return c.includeUndefinedInIndexSignature(elementType);
		}
		return c.errorType;
	}

	static function includeUndefinedInIndexSignature(c:Checker, t:Type):Type {
		if (t == null) {
			return null;
		}
		if (c.compilerOptions.NoUncheckedIndexedAccess == TSTrue) {
			return c.getUnionType([t, c.missingType]);
		}
		return t;
	}

	static function getAssignedTypeOfSpreadExpression(c:Checker, node:Node):Type {
		return c.getTypeOfDestructuredSpreadExpression(c.getAssignedType(node.Parent));
	}

	static function getTypeOfDestructuredSpreadExpression(c:Checker, t:Type):Type {
		var elementType = c.checkIteratedTypeOrElementType(IterationUseDestructuring, t, c.undefinedType, null /*errorNode*/);
		if (elementType == null) {
			elementType = c.errorType;
		}
		return c.createArrayType(elementType);
	}

	static function getAssignedTypeOfPropertyAssignment(c:Checker, node:Node):Type {
		return c.getTypeOfDestructuredProperty(c.getAssignedType(node.Parent), node.Name());
	}

	static function getTypeOfDestructuredProperty(c:Checker, t:Type, name:Node):Type {
		final nameType = c.getLiteralTypeFromPropertyName(name);
		if (!Checker.isTypeUsableAsPropertyName(nameType)) {
			return c.errorType;
		}
		final text = Checker.getPropertyNameFromType(nameType);
		final propType = c.getTypeOfPropertyOfType(t, text);
		if (propType != null) {
			return propType;
		}
		final indexInfo = c.getApplicableIndexInfoForName(t, text);
		if (indexInfo != null) {
			return c.includeUndefinedInIndexSignature(indexInfo.valueType);
		}
		return c.errorType;
	}

	static function getAssignedTypeOfShorthandPropertyAssignment(c:Checker, node:Node):Type {
		return c.getTypeWithDefault(c.getAssignedTypeOfPropertyAssignment(node), node.AsShorthandPropertyAssignment().ObjectAssignmentInitializer);
	}

	static function isDestructuringAssignmentTarget(c:Checker, parent:Node):Bool {
		return Ast.IsBinaryExpression(parent.Parent) && parent.Parent.AsBinaryExpression().Left == parent
			|| Ast.IsForOfStatement(parent.Parent) && parent.Parent.Initializer() == parent;
	}

	static function getTypeWithDefault(c:Checker, t:Type, defaultExpression:Node):Type {
		if (defaultExpression != null) {
			return c.getUnionType([c.getNonUndefinedType(t), c.getTypeOfExpression(defaultExpression)]);
		}
		return t;
	}

	// Remove those constituent types of declaredType to which no constituent type of assignedType is assignable.
	// For example, when a variable of type number | string | boolean is assigned a value of type number | boolean,
	// we remove type string.
	static function getAssignmentReducedType(c:Checker, declaredType:Type, assignedType:Type):Type {
		if (declaredType == assignedType) {
			return declaredType;
		}
		if ((assignedType.flags & TypeFlagsNever) != 0) {
			return assignedType;
		}
		final key = AssignmentReducedKey.keyOf(declaredType.id, assignedType.id);
		var result = c.assignmentReducedTypes.get(key);
		if (result == null) {
			result = c.getAssignmentReducedTypeWorker(declaredType, assignedType);
			c.assignmentReducedTypes.set(key, result);
		}
		return result;
	}

	static function getAssignmentReducedTypeWorker(c:Checker, declaredType:Type, assignedType:Type):Type {
		final filteredType = c.filterType(declaredType, function(t:Type):Bool {
			return c.typeMaybeAssignableTo(assignedType, t);
		});
		// Ensure that we narrow to fresh types if the assignment is a fresh boolean literal type.
		var reducedType = filteredType;
		if ((assignedType.flags & TypeFlagsBooleanLiteral) != 0 && Checker.isFreshLiteralType(assignedType)) {
			reducedType = c.mapType(filteredType, t -> c.getFreshTypeOfLiteralType(t));
		}
		// Our crude heuristic produces an invalid result in some cases: see GH#26130.
		// For now, when that happens, we give up and don't narrow at all.  (This also
		// means we'll never narrow for erroneous assignments where the assigned type
		// is not assignable to the declared type.)
		if (c.isTypeAssignableTo(assignedType, reducedType)) {
			return reducedType;
		}
		return declaredType;
	}

	static function typeMaybeAssignableTo(c:Checker, source:Type, target:Type):Bool {
		if ((source.flags & TypeFlagsUnion) == 0) {
			return c.isTypeAssignableTo(source, target);
		}
		for (t in source.AsUnionType().types) {
			if (c.isTypeAssignableTo(t, target)) {
				return true;
			}
		}
		return false;
	}

	static function getTypePredicateArgument(c:Checker, predicate:TypePredicate, callExpression:Node):Node {
		if (predicate.kind == TypePredicateKindIdentifier || predicate.kind == TypePredicateKindAssertsIdentifier) {
			final arguments = callExpression.Arguments();
			if (predicate.parameterIndex >= 0 && predicate.parameterIndex < Core.len(arguments)) {
				return arguments[predicate.parameterIndex];
			}
		} else {
			final invokedExpression = Ast.SkipParentheses(callExpression.Expression());
			if (Ast.IsAccessExpression(invokedExpression)) {
				return Ast.SkipParentheses(invokedExpression.Expression());
			}
		}
		return null;
	}

	static function getFlowTypeInConstructor(c:Checker, symbol:Symbol, constructor:Node):Type {
		var accessName:Node;
		if (StringTools.startsWith(symbol.Name, Ast.InternalSymbolNamePrefix + "#")) {
			accessName = c.factory.NewPrivateIdentifier(symbol.Name.substring(symbol.Name.indexOf("@") + 1));
		} else {
			accessName = c.factory.NewIdentifier(symbol.Name);
		}
		final reference = c.factory.NewPropertyAccessExpression(c.factory.NewKeywordExpression(KindThisKeyword), null, accessName, NodeFlagsNone);
		reference.Expression().Parent = reference;
		reference.Parent = constructor;
		reference.FlowNodeData().FlowNode = constructor.AsConstructorDeclaration().ReturnFlowNode;
		final flowType = c.getFlowTypeOfProperty(reference, symbol);
		if (c.noImplicitAny && (flowType == c.autoType || flowType == c.autoArrayType)) {
			c.error(symbol.ValueDeclaration, Diagnostics.Member_0_implicitly_has_an_1_type, c.symbolToString(symbol), c.TypeToString(flowType));
		}
		// We don't infer a type if assignments are only null or undefined.
		if (Checker.everyType(flowType, t -> c.IsNullableType(t))) {
			return null;
		}
		return c.convertAutoToAny(flowType);
	}

	static function getFlowTypeInStaticBlocks(c:Checker, symbol:Symbol, staticBlocks:Array<Node>):Type {
		var accessName:Node;
		if (StringTools.startsWith(symbol.Name, Ast.InternalSymbolNamePrefix + "#")) {
			accessName = c.factory.NewPrivateIdentifier(symbol.Name.substring(symbol.Name.indexOf("@") + 1));
		} else {
			accessName = c.factory.NewIdentifier(symbol.Name);
		}
		if (staticBlocks != null) {
			for (staticBlock in staticBlocks) {
				final reference = c.factory.NewPropertyAccessExpression(c.factory.NewKeywordExpression(KindThisKeyword), null, accessName, NodeFlagsNone);
				reference.Expression().Parent = reference;
				reference.Parent = staticBlock;
				reference.FlowNodeData().FlowNode = staticBlock.AsClassStaticBlockDeclaration().ReturnFlowNode;
				final flowType = c.getFlowTypeOfProperty(reference, symbol);
				if (c.noImplicitAny && (flowType == c.autoType || flowType == c.autoArrayType)) {
					c.error(symbol.ValueDeclaration, Diagnostics.Member_0_implicitly_has_an_1_type, c.symbolToString(symbol), c.TypeToString(flowType));
				}
				// We don't infer a type if assignments are only null or undefined.
				if (Checker.everyType(flowType, t -> c.IsNullableType(t))) {
					continue;
				}
				return c.convertAutoToAny(flowType);
			}
		}
		return null;
	}

	static function isReachableFlowNode(c:Checker, flow:FlowNode):Bool {
		final f = c.getFlowState();
		final result = c.isReachableFlowNodeWorker(f, flow, false /*noCacheCheck*/);
		c.putFlowState(f);
		c.lastFlowNode = flow;
		c.lastFlowNodeReachable = result;
		return result;
	}

	static function isReachableFlowNodeWorker(c:Checker, f:FlowState, flow:FlowNode, noCacheCheck:Bool):Bool {
		while (true) {
			if (flow == c.lastFlowNode) {
				return c.lastFlowNodeReachable;
			}
			final flags = flow.Flags;
			if ((flags & FlowFlagsShared) != 0) {
				if (!noCacheCheck) {
					if (c.flowNodeReachable.exists(flow)) {
						return c.flowNodeReachable.get(flow);
					}
					final reachable = c.isReachableFlowNodeWorker(f, flow, true /*noCacheCheck*/);
					c.flowNodeReachable.set(flow, reachable);
					return reachable;
				}
				noCacheCheck = false;
			}
			if ((flags & (FlowFlagsAssignment | FlowFlagsCondition | FlowFlagsArrayMutation)) != 0) {
				flow = flow.Antecedent;
			} else if ((flags & FlowFlagsCall) != 0) {
				final signature = c.getEffectsSignature(flow.Node);
				if (signature != null) {
					final predicate = c.getTypePredicateOfSignature(signature);
					if (predicate != null && predicate.kind == TypePredicateKindAssertsIdentifier && predicate.t == null) {
						final arguments = flow.Node.Arguments();
						if (predicate.parameterIndex >= 0 && predicate.parameterIndex < Core.len(arguments)
							&& c.isFalseExpression(arguments[predicate.parameterIndex])) {
							return false;
						}
					}
					if ((c.getReturnTypeOfSignature(signature).flags & TypeFlagsNever) != 0) {
						return false;
					}
				}
				flow = flow.Antecedent;
			} else if ((flags & FlowFlagsBranchLabel) != 0) {
				// A branching point is reachable if any branch is reachable.
				var list = Checker.getBranchLabelAntecedents(flow, f.reduceLabels);
				while (list != null) {
					if (c.isReachableFlowNodeWorker(f, list.Flow, false /*noCacheCheck*/)) {
						return true;
					}
					list = list.Next;
				}
				return false;
			} else if ((flags & FlowFlagsLoopLabel) != 0) {
				if (flow.Antecedents == null) {
					return false;
				}
				// A loop is reachable if the control flow path that leads to the top is reachable.
				flow = flow.Antecedents.Flow;
			} else if ((flags & FlowFlagsSwitchClause) != 0) {
				// The control flow path representing an unmatched value in a switch statement with
				// no default clause is unreachable if the switch statement is exhaustive.
				final data = flow.Node.AsFlowSwitchClauseData();
				if (data.ClauseStart == data.ClauseEnd && c.isExhaustiveSwitchStatement(data.SwitchStatement)) {
					return false;
				}
				flow = flow.Antecedent;
			} else if ((flags & FlowFlagsReduceLabel) != 0) {
				// Cache is unreliable once we start adjusting labels
				c.lastFlowNode = null;
				if (f.reduceLabels == null) {
					f.reduceLabels = [];
				}
				f.reduceLabels.push(flow.Node.AsFlowReduceLabelData());
				final result = c.isReachableFlowNodeWorker(f, flow.Antecedent, false /*noCacheCheck*/);
				f.reduceLabels.resize(f.reduceLabels.length - 1);
				return result;
			} else {
				return (flags & FlowFlagsUnreachable) == 0;
			}
		}
	}

	static function isFalseExpression(c:Checker, expr:Node):Bool {
		final node = Ast.SkipParentheses(expr);
		if (node.Kind == KindFalseKeyword) {
			return true;
		}
		if (Ast.IsBinaryExpression(node)) {
			final binary = node.AsBinaryExpression();
			return binary.OperatorToken.Kind == KindAmpersandAmpersandToken && (c.isFalseExpression(binary.Left) || c.isFalseExpression(binary.Right))
				|| binary.OperatorToken.Kind == KindBarBarToken && c.isFalseExpression(binary.Left) && c.isFalseExpression(binary.Right);
		}
		return false;
	}

	// Return true if the given flow node is preceded by a 'super(...)' call in every possible code path
	// leading to the node.
	static function isPostSuperFlowNode(c:Checker, flow:FlowNode, noCacheCheck:Bool):Bool {
		final f = c.getFlowState();
		final result = c.isPostSuperFlowNodeWorker(f, flow, noCacheCheck);
		c.putFlowState(f);
		return result;
	}

	static function isPostSuperFlowNodeWorker(c:Checker, f:FlowState, flow:FlowNode, noCacheCheck:Bool):Bool {
		while (true) {
			final flags = flow.Flags;
			if ((flags & FlowFlagsShared) != 0) {
				if (!noCacheCheck) {
					if (c.flowNodePostSuper.exists(flow)) {
						return c.flowNodePostSuper.get(flow);
					}
					final postSuper = c.isPostSuperFlowNodeWorker(f, flow, true /*noCacheCheck*/);
					c.flowNodePostSuper.set(flow, postSuper);
				}
				noCacheCheck = false;
			}
			if ((flags & (FlowFlagsAssignment | FlowFlagsCondition | FlowFlagsArrayMutation | FlowFlagsSwitchClause)) != 0) {
				flow = flow.Antecedent;
			} else if ((flags & FlowFlagsCall) != 0) {
				if (flow.Node.Expression().Kind == KindSuperKeyword) {
					return true;
				}
				flow = flow.Antecedent;
			} else if ((flags & FlowFlagsBranchLabel) != 0) {
				var list = Checker.getBranchLabelAntecedents(flow, f.reduceLabels);
				while (list != null) {
					if (!c.isPostSuperFlowNodeWorker(f, list.Flow, false /*noCacheCheck*/)) {
						return false;
					}
					list = list.Next;
				}
				return true;
			} else if ((flags & FlowFlagsLoopLabel) != 0) {
				// A loop is post-super if the control flow path that leads to the top is post-super.
				flow = flow.Antecedents.Flow;
			} else if ((flags & FlowFlagsReduceLabel) != 0) {
				if (f.reduceLabels == null) {
					f.reduceLabels = [];
				}
				f.reduceLabels.push(flow.Node.AsFlowReduceLabelData());
				final result = c.isPostSuperFlowNodeWorker(f, flow.Antecedent, false /*noCacheCheck*/);
				f.reduceLabels.resize(f.reduceLabels.length - 1);
				return result;
			} else {
				// Unreachable nodes are considered post-super to silence errors
				return (flags & FlowFlagsUnreachable) != 0;
			}
		}
	}

	// Check if a parameter, catch variable, or mutable local variable is definitely assigned anywhere
	static function isSymbolAssignedDefinitely(c:Checker, symbol:Symbol):Bool {
		c.ensureAssignmentsMarked(symbol);
		return c.markedAssignmentSymbolLinks.Get(symbol).hasDefiniteAssignment;
	}

	// Check if a parameter, catch variable, or mutable local variable is assigned anywhere
	static function isSymbolAssigned(c:Checker, symbol:Symbol):Bool {
		c.ensureAssignmentsMarked(symbol);
		return c.markedAssignmentSymbolLinks.Get(symbol).lastAssignmentPos != 0;
	}

	// Return true if there are no assignments to the given symbol or if the given location
	// is past the last assignment to the symbol.
	static function isPastLastAssignment(c:Checker, symbol:Symbol, location:Node):Bool {
		c.ensureAssignmentsMarked(symbol);
		final lastAssignmentPos = c.markedAssignmentSymbolLinks.Get(symbol).lastAssignmentPos;
		return lastAssignmentPos == 0 || location != null && lastAssignmentPos < location.Pos();
	}

	static function ensureAssignmentsMarked(c:Checker, symbol:Symbol):Void {
		if (c.markedAssignmentSymbolLinks.Get(symbol).lastAssignmentPos != 0) {
			return;
		}
		final parent = Ast.FindAncestor(symbol.ValueDeclaration, Ast.IsFunctionOrSourceFile);
		if (parent == null) {
			return;
		}
		final links = c.nodeLinks.Get(parent);
		if ((links.flags & NodeCheckFlagsAssignmentsMarked) == 0) {
			links.flags |= NodeCheckFlagsAssignmentsMarked;
			if (!c.hasParentWithAssignmentsMarked(parent)) {
				c.markNodeAssignments(parent);
			}
		}
	}

	static function hasParentWithAssignmentsMarked(c:Checker, node:Node):Bool {
		return Ast.FindAncestor(node.Parent, function(node:Node):Bool {
			return Ast.IsFunctionOrSourceFile(node) && (c.nodeLinks.Get(node).flags & NodeCheckFlagsAssignmentsMarked) != 0;
		}) != null;
	}

	// For all assignments within the given root node, record the last assignment source position for all
	// referenced parameters and mutable local variables. When assignments occur in nested functions  or
	// references occur in export specifiers, record math.MaxInt32 as the assignment position. When
	// assignments occur in compound statements, record the ending source position of the compound statement
	// as the assignment position (this is more conservative than full control flow analysis, but requires
	// only a single walk over the AST).
	static function markNodeAssignmentsWorker(c:Checker, node:Node):Bool {
		switch (node.Kind) {
			case KindIdentifier:
				final assignmentKind = Checker.getAssignmentTargetKind(node);
				if (assignmentKind != AssignmentKindNone) {
					final symbol = c.getResolvedSymbol(node);
					if (c.isParameterOrMutableLocalVariable(symbol)) {
						final links = c.markedAssignmentSymbolLinks.Get(symbol);
						final pos = links.lastAssignmentPos;
						if (pos == 0 || pos != 2147483647) {
							final referencingFunction = Ast.FindAncestor(node, Ast.IsFunctionOrSourceFile);
							final declaringFunction = Ast.FindAncestor(symbol.ValueDeclaration, Ast.IsFunctionOrSourceFile);
							if (referencingFunction == declaringFunction) {
								links.lastAssignmentPos = c.extendAssignmentPosition(node, symbol.ValueDeclaration);
							} else {
								links.lastAssignmentPos = 2147483647; // math.MaxInt32
							}
						}
						if (assignmentKind == AssignmentKindDefinite) {
							links.hasDefiniteAssignment = true;
						}
					}
				}
				return false;
			case KindExportSpecifier:
				final exportDeclaration = node.AsExportSpecifier().Parent.Parent.AsExportDeclaration();
				final name = node.PropertyNameOrName();
				if (!node.IsTypeOnly() && !exportDeclaration.IsTypeOnly && exportDeclaration.ModuleSpecifier == null && !Ast.IsStringLiteral(name)) {
					final symbol = c.resolveEntityName(name, SymbolFlagsValue, true /*ignoreErrors*/, true /*dontResolveAlias*/, null);
					if (symbol != null && c.isParameterOrMutableLocalVariable(symbol)) {
						final links = c.markedAssignmentSymbolLinks.Get(symbol);
						links.lastAssignmentPos = 2147483647; // math.MaxInt32
					}
				}
				return false;
			case KindInterfaceDeclaration | KindTypeAliasDeclaration | KindJSTypeAliasDeclaration | KindEnumDeclaration:
				return false;
			default:
		}
		if (Ast.IsTypeNode(node)) {
			return false;
		}
		return node.ForEachChild(c.markNodeAssignments);
	}

	// Extend the position of the given assignment target node to the end of any intervening variable statement,
	// expression statement, compound statement, or class declaration occurring between the node and the given
	// declaration node.
	static function extendAssignmentPosition(c:Checker, node:Node, declaration:Node):Int {
		var pos = node.Pos();
		while (node != null && node.Pos() > declaration.Pos()) {
			switch (node.Kind) {
				case KindVariableStatement | KindExpressionStatement | KindIfStatement | KindDoStatement | KindWhileStatement | KindForStatement | KindForInStatement |
					KindForOfStatement | KindWithStatement | KindSwitchStatement | KindTryStatement | KindClassDeclaration:
					pos = node.End();
				default:
			}
			node = node.Parent;
		}
		return pos;
	}
}
