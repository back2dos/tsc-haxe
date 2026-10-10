package ts.pseudochecker;

import ts.pseudochecker.Pseudochecker.*;

// --- lookup.go --- (methods of PseudoChecker; the package-level funcs are in Pseudochecker.hx)
@:allow(ts.pseudochecker)
class Lookup {
	public static function GetReturnTypeOfSignature(ch:PseudoChecker, signatureNode:Node):PseudoType {
		switch (signatureNode.Kind) {
			case KindGetAccessor:
				return ch.GetTypeOfAccessor(signatureNode);
			case KindMethodDeclaration, KindFunctionDeclaration, KindConstructor, KindMethodSignature, KindCallSignature, KindConstructSignature,
				KindSetAccessor, KindIndexSignature, KindFunctionType, KindConstructorType, KindFunctionExpression, KindArrowFunction,
				KindJSDocSignature:
				return ch.createReturnFromSignature(signatureNode);
			default:
				// PORT: Debug.FailBadSyntaxKind takes a structure with KindString(); Node's methods live on an abstract.
				Debug.FailBadSyntaxKind({KindString: () -> signatureNode.KindString()}, "Node needs to be an inferrable node");
				return null;
		}
	}

	public static function GetTypeOfAccessor(ch:PseudoChecker, accessor:Node):PseudoType {
		return ch.typeFromAccessor(accessor);
	}

	public static function GetTypeOfExpression(ch:PseudoChecker, node:Node):PseudoType {
		return ch.typeFromExpression(node);
	}

	public static function GetTypeOfDeclaration(ch:PseudoChecker, node:Node):PseudoType {
		switch (node.Kind) {
			case KindParameter:
				return ch.typeFromParameter(node.AsParameterDeclaration());
			case KindVariableDeclaration:
				return ch.typeFromVariable(node.AsVariableDeclaration());
			case KindPropertySignature, KindPropertyDeclaration, KindJSDocPropertyTag:
				return ch.typeFromProperty(node);
			case KindBindingElement:
				return NewPseudoTypeNoResult(node);
			case KindExportAssignment:
				return ch.typeFromExpression(node.AsExportAssignment().Expression);
			case KindPropertyAccessExpression, KindElementAccessExpression, KindBinaryExpression:
				return ch.typeFromExpandoProperty(node);
			case KindPropertyAssignment, KindShorthandPropertyAssignment:
				return ch.typeFromPropertyAssignment(node);
			case KindCallExpression:
				switch (Ast.GetAssignmentDeclarationKind(node)) {
					// TODO: How much of the checker's getTypeFromPropertyDescriptor is worth trying to emulate over ASTs?
					case JSDeclarationKindObjectDefinePropertyValue:
						{
							// !!!
						}
					case JSDeclarationKindObjectDefinePropertyExports:
						{
							// !!!
						}
					default:
				}
				return NewPseudoTypeNoResult(node);
			default:
				Debug.FailBadSyntaxKind({KindString: () -> node.KindString()}, "node needs to be an inferrable node");
				return null;
		}
	}

	static function typeFromPropertyAssignment(ch:PseudoChecker, node:Node):PseudoType {
		final annotation = node.Type();
		if (annotation != null) {
			return NewPseudoTypeDirect(annotation);
		}
		if (node.Kind == KindPropertyAssignment) {
			final init = node.Initializer();
			if (init != null) {
				final expr = ch.typeFromExpression(init);
				if (expr != null && (expr.Kind != PseudoTypeKindInferred || Core.len(expr.AsPseudoTypeInferred().ErrorNodes) > 0)) {
					return expr;
				}
				// fallback to NoResult if PseudoTypeKindInferred without error nodes
			}
		}
		return NewPseudoTypeNoResult(node);
	}

	// This is _not_ redundant with the reparser; see how expandoFunctionSymbolProperty.ts and similar behaves
	static function typeFromExpandoProperty(ch:PseudoChecker, node:Node):PseudoType {
		final declaredType = node.Type();
		if (declaredType != null) {
			return NewPseudoTypeDirect(declaredType);
		}
		// While `node` is an expression, as an expando, it should also always be a
		// declaration with a `.Symbol()` which requires declaration fallback handling
		return NewPseudoTypeNoResult(node);
	}

	static function typeFromProperty(ch:PseudoChecker, node:Node):PseudoType {
		final t = node.Type();
		if (t != null) {
			return NewPseudoTypeDirect(t);
		}
		if (Ast.IsPropertyDeclaration(node)) {
			final init = node.Initializer();
			if (init != null && !isContextuallyTyped(node)) {
				// explicit fail on readonly template literals to allow for literal freshness in the future
				if (Ast.HasModifier(node, ModifierFlagsReadonly) && Ast.IsTemplateExpression(init)) {
					return NewPseudoTypeNoResult(node);
				}
				final expr = ch.typeFromExpression(init);
				if (expr != null && (expr.Kind != PseudoTypeKindInferred || Core.len(expr.AsPseudoTypeInferred().ErrorNodes) > 0)) {
					if (expr.Kind != PseudoTypeKindDirect && node.AsPropertyDeclaration().PostfixToken != null
						&& node.AsPropertyDeclaration().PostfixToken.Kind == KindQuestionToken) {
						// type comes from the initializer expression on a property with a `?` - add `| undefined` to the type
						return addUndefinedIfDefinitelyRequired(expr);
					}
					return expr;
				}
				// fallback to NoResult if PseudoTypeKindInferred without error nodes
			}
		}
		return NewPseudoTypeNoResult(node);
	}

	static function typeFromVariable(ch:PseudoChecker, declaration:VariableDeclaration):PseudoType {
		final t = declaration.Type;
		if (t != null) {
			return NewPseudoTypeDirect(t);
		}
		final init = declaration.Initializer;
		if (init != null
			&& (Core.len(declaration.Symbol.Declarations) == 1 || Core.CountWhere(declaration.Symbol.Declarations, Ast.IsVariableDeclaration) == 1)) {
			if (!isContextuallyTyped(declaration.AsNode())) { // TODO: also should bail on expando declarations; reuse syntactic expando check used in declaration emit
				// TODO: Strada forces an inference fallback on `const` variables with template expression initializers, to leave space for template literal freshness in the future
				if (Ast.IsVarConst(declaration.AsNode()) && Ast.IsTemplateExpression(init)) {
					return NewPseudoTypeNoResult(declaration.AsNode());
				}
				final expr = ch.typeFromExpression(init);
				if (expr != null && (expr.Kind != PseudoTypeKindInferred || Core.len(expr.AsPseudoTypeInferred().ErrorNodes) > 0)) {
					return expr;
				}
				// fallback to NoResult if PseudoTypeKindInferred without error nodes
			}
		}
		return NewPseudoTypeNoResult(declaration.AsNode());
	}

	static function typeFromAccessor(ch:PseudoChecker, accessor:Node):PseudoType {
		final accessorDeclarations = Ast.GetAllAccessorDeclarationsForDeclaration(accessor, accessor.DeclarationData().Symbol.Declarations);
		final accessorType = ch.getTypeAnnotationFromAllAccessorDeclarations(accessor, accessorDeclarations);
		if (accessorType != null && !Ast.IsTypePredicateNode(accessorType)) {
			return NewPseudoTypeDirect(accessorType);
		}
		if (accessorDeclarations.GetAccessor != null) {
			var res = ch.createReturnFromSignature(accessorDeclarations.GetAccessor.AsNode());
			if (res.Kind == PseudoTypeKindInferred && Core.len(res.AsPseudoTypeInferred().ErrorNodes) == 0) {
				final errorNodes:Array<Node> = [accessorDeclarations.GetAccessor.AsNode()];
				if (accessorDeclarations.SetAccessor != null) {
					errorNodes.push(accessorDeclarations.SetAccessor.AsNode());
				}
				res = NewPseudoTypeInferredWithErrors(res.AsPseudoTypeInferred().Expression, res.AsPseudoTypeInferred().IsSignatureReturn,
					errorNodes); // Move error up to the accessor
			}
			return res;
		}
		return NewPseudoTypeNoResult(accessor);
	}

	static function getTypeAnnotationFromAllAccessorDeclarations(ch:PseudoChecker, node:Node, accessors:AllAccessorDeclarations):Node {
		var accessorType = ch.getTypeAnnotationFromAccessor(node);
		if (accessorType == null && node != accessors.FirstAccessor) {
			accessorType = ch.getTypeAnnotationFromAccessor(accessors.FirstAccessor);
		}
		if (accessorType == null && accessors.SecondAccessor != null && node != accessors.SecondAccessor) {
			accessorType = ch.getTypeAnnotationFromAccessor(accessors.SecondAccessor);
		}
		return accessorType;
	}

	static function getTypeAnnotationFromAccessor(ch:PseudoChecker, node:Node):Node {
		if (node == null) {
			return null;
		}
		// !!! TODO: support ripping return type off of .FullSignature
		if (node.Kind == KindGetAccessor) {
			return node.AsGetAccessorDeclaration().Type;
		}
		final set = node.AsSetAccessorDeclaration();
		if (set.Parameters == null || set.Parameters.Nodes.length < 1) {
			return null;
		}
		final p = set.Parameters.Nodes[0];
		if (!Ast.IsParameterDeclaration(p)) {
			return null;
		}
		return p.AsParameterDeclaration().Type;
	}

	// does not return `nil`, returns a `NoResult` pseudotype instead
	static function createReturnFromSignature(ch:PseudoChecker, fn:Node):PseudoType {
		if (Ast.IsFunctionLike(fn)) {
			final d = fn.FunctionLikeData();
			// !!! TODO: support ripping return type off of .FullSignature
			final r = d.Type;
			if (r != null) {
				return NewPseudoTypeDirect(r);
			}
		}
		if (isValueSignatureDeclaration(fn)) {
			return ch.typeFromSingleReturnExpression(fn);
		}
		return NewPseudoTypeNoResult(fn);
	}

	static function typeFromSingleReturnExpression(ch:PseudoChecker, fn:Node):PseudoType {
		var candidateExpr:Node = null;
		if (fn != null && !Ast.NodeIsMissing(fn.Body())) {
			final flags = Ast.GetFunctionFlags(fn);
			if (flags & FunctionFlagsAsyncGenerator != 0) {
				return NewPseudoTypeInferred(fn, true);
			}

			final body = fn.Body();
			if (Ast.IsBlock(body)) {
				Ast.ForEachReturnStatement(body, function(stmt:Node):Bool {
					if (stmt.Parent != body) { // Why bail on nested return statements?
						candidateExpr = null;
						return true;
					}
					if (candidateExpr == null) {
						candidateExpr = stmt.AsReturnStatement().Expression;
					} else {
						candidateExpr = null;
						return true;
					}
					return false;
				});
			} else {
				candidateExpr = body;
			}
		}
		if (candidateExpr != null) {
			if (isContextuallyTyped(candidateExpr)) {
				var t:Node = null;
				if (candidateExpr.Kind == KindTypeAssertionExpression) {
					t = candidateExpr.AsTypeAssertion().Type;
				} else if (candidateExpr.Kind == KindAsExpression) {
					t = candidateExpr.AsAsExpression().Type;
				}
				if (t != null && !Ast.IsConstTypeReference(t)) {
					return NewPseudoTypeDirect(t);
				}
			} else {
				return ch.typeFromExpression(candidateExpr);
			}
		}
		return NewPseudoTypeInferred(fn, true);
	}

	// This is basically `checkExpression` for pseudotypes
	static function typeFromExpression(ch:PseudoChecker, node:Node):PseudoType {
		switch (node.Kind) {
			case KindOmittedExpression:
				return PseudoTypeUndefined;
			case KindParenthesizedExpression:
				// assertions transformed on reparse, just unwrap
				return ch.typeFromExpression(node.AsParenthesizedExpression().Expression);
			case KindIdentifier:
				// !!! TODO: in strada, this uses symbol information to ensure `node` refers to the global `undefined` symbol instead
				// we should probably import `resolveName` and use it here to check for the same; but we have to setup some barebones pseudoglobals for that to work!
				if (node.AsIdentifier().Text == "undefined") {
					return PseudoTypeUndefined;
				}
			case KindNullKeyword:
				return PseudoTypeNull;
			case KindArrowFunction, KindFunctionExpression:
				return ch.typeFromFunctionLikeExpression(node);
			case KindTypeAssertionExpression:
				return ch.typeFromTypeAssertion(node.AsTypeAssertion().Expression, node.AsTypeAssertion().Type);
			case KindAsExpression:
				return ch.typeFromTypeAssertion(node.AsAsExpression().Expression, node.AsAsExpression().Type);
			case KindPrefixUnaryExpression:
				if (Ast.IsPrimitiveLiteralValue(node, true)) {
					return ch.typeFromPrimitiveLiteralPrefix(node.AsPrefixUnaryExpression());
				}
			case KindArrayLiteralExpression:
				return ch.typeFromArrayLiteral(node.AsArrayLiteralExpression());
			case KindObjectLiteralExpression:
				return ch.typeFromObjectLiteral(node.AsObjectLiteralExpression());
			case KindClassExpression:
				return NewPseudoTypeInferredWithErrors(node, false, [node]); // No possible annotation/directly mappable syntax
			case KindTemplateExpression:
				// templateLitWithHoles as const, not supported
				if (IsInConstContext(node)) {
					return NewPseudoTypeInferred(node, false);
				}
				return NewPseudoTypeMaybeConstLocation(node, NewPseudoTypeInferred(node, false), PseudoTypeString);
			case KindNumericLiteral:
				return NewPseudoTypeMaybeConstLocation(node, NewPseudoTypeNumericLiteral(node), PseudoTypeNumber);
			case KindNoSubstitutionTemplateLiteral:
				return NewPseudoTypeMaybeConstLocation(node, NewPseudoTypeStringLiteral(node), PseudoTypeString);
			case KindStringLiteral:
				return NewPseudoTypeMaybeConstLocation(node, NewPseudoTypeStringLiteral(node), PseudoTypeString);
			case KindBigIntLiteral:
				return NewPseudoTypeMaybeConstLocation(node, NewPseudoTypeBigIntLiteral(node), PseudoTypeBigInt);
			case KindTrueKeyword:
				return NewPseudoTypeMaybeConstLocation(node, PseudoTypeTrue, PseudoTypeBoolean);
			case KindFalseKeyword:
				return NewPseudoTypeMaybeConstLocation(node, PseudoTypeFalse, PseudoTypeBoolean);
			default:
		}
		return NewPseudoTypeInferred(node, false);
	}

	static function typeFromObjectLiteral(ch:PseudoChecker, node:ObjectLiteralExpression):PseudoType {
		final errorNodes = ch.canGetTypeFromObjectLiteral(node);
		if (errorNodes != null) {
			return NewPseudoTypeInferredWithErrors(node.AsNode(), false, errorNodes);
		}
		// we are in a const context producing an object literal type, there are no shorthand or spread assignments
		if (node.Properties == null || node.Properties.Nodes.length == 0) {
			return NewPseudoTypeObjectLiteral(null);
		}
		final results = new Array<PseudoObjectElement>();
		for (e in node.Properties.Nodes) {
			switch (e.Kind) {
				case KindMethodDeclaration:
					final optional = e.AsMethodDeclaration().PostfixToken != null && e.AsMethodDeclaration().PostfixToken.Kind == KindQuestionToken;
					if (e.FunctionLikeData().FullSignature != null) {
						results.push(NewPseudoPropertyAssignment(false, e.Name(), optional, NewPseudoTypeDirect(e.FunctionLikeData().FullSignature)));
					} else {
						results.push(NewPseudoObjectMethod(e, e.Name(), optional, ch.cloneTypeParameters(e.AsMethodDeclaration().TypeParameters),
							ch.cloneParameters(e.ParameterList()), ch.createReturnFromSignature(e)));
					}
				case KindPropertyAssignment:
					results.push(NewPseudoPropertyAssignment(false, e.Name(),
						e.AsPropertyAssignment().PostfixToken != null && e.AsPropertyAssignment().PostfixToken.Kind == KindQuestionToken,
						ch.typeFromExpression(e.Initializer())));
				case KindSetAccessor, KindGetAccessor:
					final member = ch.getAccessorMember(e, e.Name());
					if (member != null) {
						results.push(member);
					}
				default:
			}
		}
		return NewPseudoTypeObjectLiteral(results);
	}

	// roughly analogous to typeFromObjectLiteralAccessor in strada
	static function getAccessorMember(ch:PseudoChecker, accessor:Node, name:Node):PseudoObjectElement {
		final allAccessors = Ast.GetAllAccessorDeclarationsForDeclaration(accessor,
			accessor.Symbol().Declarations); // TODO: node preservation for late-bound accessor pairs?

		// TODO: handle pseudo-annotations from get accessor return positions?
		if (allAccessors.GetAccessor != null && allAccessors.GetAccessor.Type != null && allAccessors.SetAccessor != null
			&& allAccessors.SetAccessor.Parameters.Nodes.length > 0
			&& allAccessors.SetAccessor.Parameters.Nodes[0].AsParameterDeclaration().Type != null) {
			// We have possible types for both accessors, we can't know if they are the same type so we keep both accessors

			if (Ast.IsGetAccessorDeclaration(accessor)) {
				return NewPseudoGetAccessor(accessor, name, false, ch.typeFromAccessor(accessor));
			} else {
				return NewPseudoSetAccessor(accessor, name, false, ch.cloneParameters(accessor.AsSetAccessorDeclaration().Parameters)[0]);
			}
		}

		if (accessor == allAccessors.FirstAccessor) {
			// only one annotated accessor; output a property - `readonly` for a single `get` accessor

			final accessorType = ch.typeFromAccessor(accessor);
			final readonly = Ast.IsGetAccessorDeclaration(accessor) && allAccessors.SecondAccessor == null;
			return NewPseudoPropertyAssignment(readonly, name, false, accessorType);
		}
		return null;
	}

	// canGetTypeFromObjectLiteral checks whether an object literal can be typed by the pseudochecker.
	// Returns nil if the object can be typed, or a slice of error nodes (shorthand/spread properties,
	// non-literal computed names) that prevent typing.
	static function canGetTypeFromObjectLiteral(ch:PseudoChecker, node:ObjectLiteralExpression):Array<Node> {
		if (node.Properties == null || node.Properties.Nodes.length == 0) {
			return null; // empty object, ok
		}
		var errorNodes:Array<Node> = null;
		// PORT: Go append to a nil slice → create the array on first push.
		inline function append(n:Node) {
			if (errorNodes == null)
				errorNodes = [];
			errorNodes.push(n);
		}
		for (e in node.Properties.Nodes) {
			if (e.Flags & NodeFlagsThisNodeHasError != 0) {
				append(e);
				continue;
			}
			if (e.Kind == KindShorthandPropertyAssignment || e.Kind == KindSpreadAssignment) {
				append(e);
				continue;
			}
			if (e.Name().Flags & NodeFlagsThisNodeHasError != 0) {
				append(e.Name());
				continue;
			}
			if (e.Name().Kind == KindPrivateIdentifier) {
				append(e);
				continue;
			}
			if (e.Name().Kind == KindComputedPropertyName) {
				final expression = e.Name().Expression();
				if (!Ast.IsPrimitiveLiteralValue(expression, false)) {
					append(e.Name());
				}
			}
		}
		return errorNodes;
	}

	static function typeFromArrayLiteral(ch:PseudoChecker, node:ArrayLiteralExpression):PseudoType {
		final errorNodes = ch.canGetTypeFromArrayLiteral(node);
		if (errorNodes != null) {
			return NewPseudoTypeInferredWithErrors(node.AsNode(), false, errorNodes);
		}
		if (IsInConstContext(node.AsNode()) && isContextuallyTyped(node.AsNode())) {
			return NewPseudoTypeInferred(node.AsNode(), false); // expr in an as const cast with a contextual type has variable readonly state, bail
		}
		// we are in a const context producing a tuple type, there are no spread elements
		final results = new Array<PseudoType>();
		for (e in node.Elements.Nodes) {
			results.push(ch.typeFromExpression(e));
		}
		return NewPseudoTypeTuple(results);
	}

	// canGetTypeFromArrayLiteral checks whether an array literal can be typed by the pseudochecker.
	// Returns nil if the array can be typed, or a slice of error nodes that prevent typing.
	// For non-const arrays, the error node is the array expression itself.
	// For const arrays with spreads, the error node is the spread element.
	static function canGetTypeFromArrayLiteral(ch:PseudoChecker, node:ArrayLiteralExpression):Array<Node> {
		if (!IsInConstContext(node.AsNode())) {
			return [node.AsNode()];
		}
		for (e in node.Elements.Nodes) {
			if (e.Kind == KindSpreadElement) {
				return [e];
			}
		}
		return null;
	}

	static function typeFromPrimitiveLiteralPrefix(ch:PseudoChecker, node:PrefixUnaryExpression):PseudoType {
		var expr = node.AsNode();
		if (node.Operator == KindPlusToken) {
			expr = node.Operand;
		}
		final inner = node.Operand;
		if (inner.Kind == KindBigIntLiteral) {
			return NewPseudoTypeMaybeConstLocation(node.AsNode(), NewPseudoTypeBigIntLiteral(expr.AsNode()), PseudoTypeBigInt);
		}
		if (inner.Kind == KindNumericLiteral) {
			return NewPseudoTypeMaybeConstLocation(node.AsNode(), NewPseudoTypeNumericLiteral(expr.AsNode()), PseudoTypeNumber);
		}
		Debug.FailBadSyntaxKind({KindString: () -> inner.KindString()});
		return null;
	}

	static function typeFromTypeAssertion(ch:PseudoChecker, expression:Node, typeNode:Node):PseudoType {
		if (Ast.IsConstTypeReference(typeNode)) {
			return ch.typeFromExpression(expression);
		}
		return NewPseudoTypeDirect(typeNode);
	}

	static function typeFromFunctionLikeExpression(ch:PseudoChecker, node:Node):PseudoType {
		if (node.FunctionLikeData().FullSignature != null) {
			return NewPseudoTypeDirect(node.FunctionLikeData().FullSignature);
		}
		final returnType = ch.createReturnFromSignature(node);
		final typeParameters = ch.cloneTypeParameters(node.FunctionLikeData().TypeParameters);
		final parameters = ch.cloneParameters(node.FunctionLikeData().Parameters);
		return NewPseudoTypeSingleCallSignature(node, parameters, typeParameters, returnType);
	}

	static function cloneTypeParameters(ch:PseudoChecker, nodes:NodeList):Array<TypeParameterDeclaration> {
		if (nodes == null) {
			return null;
		}
		if (nodes.Nodes.length == 0) {
			return null;
		}
		final result = new Array<TypeParameterDeclaration>();
		for (e in nodes.Nodes) {
			result.push(e.AsTypeParameterDeclaration());
		}
		return result;
	}

	static function typeFromParameter(ch:PseudoChecker, node:ParameterDeclaration):PseudoType {
		final parent = node.Parent;
		if (parent.Kind == KindSetAccessor) {
			return ch.GetTypeOfAccessor(parent);
		}
		// Fast path: no initializer means we never need parameter position info.
		if (node.Initializer == null) {
			if (node.Type != null) {
				return NewPseudoTypeDirect(node.Type);
			}
			return NewPseudoTypeNoResult(node.AsNode());
		}
		final p = parent.Parameters();
		final selfIdx = Slices.Index(p, node.AsNode());
		final lastRequired = lastRequiredParamIndex(p);
		return ch.typeFromParameterWorker(node, selfIdx, lastRequired);
	}

	static function typeFromParameterWorker(ch:PseudoChecker, node:ParameterDeclaration, selfIdx:Int, lastRequired:Int):PseudoType {
		final parent = node.Parent;
		if (parent.Kind == KindSetAccessor) {
			return ch.GetTypeOfAccessor(parent);
		}
		final hasRequiredAfter = selfIdx < lastRequired - 1;
		final declaredType = node.Type;
		if (declaredType != null) {
			final result = NewPseudoTypeDirect(declaredType);
			// When the parameter has an initializer and strict null checks are enabled,
			// check if `| undefined` needs to be added because there are required parameters after this one.
			// This mirrors the checker's getTypeOfParameter which adds optionality for initialized parameters.
			if (ch.strictNullChecks && node.Initializer != null && hasRequiredAfter) {
				return addUndefinedIfDefinitelyRequired(result);
			}
			return result;
		}
		if (node.Initializer != null && Ast.IsIdentifier(node.AsNode().Name()) && !isContextuallyTyped(node.AsNode())) {
			var expr = ch.typeFromExpression(node.Initializer);
			if (expr != null && (expr.Kind == PseudoTypeKindInferred && Core.len(expr.AsPseudoTypeInferred().ErrorNodes) == 0)) {
				expr = NewPseudoTypeInferredWithErrors(expr.AsPseudoTypeInferred().Expression, false, [node.AsNode()]); // Move error up to the parameter
			}
			if (!ch.strictNullChecks) {
				return expr;
			}
			if (!hasRequiredAfter) {
				return expr;
			}
			// if there is a non-optional parameter after this one, a `| undefined` will need to explicitly be emitted on this parameter, if it's not already there
			return addUndefinedIfDefinitelyRequired(expr);
		}
		// TODO: In strada, the ID checker doesn't infer a parameter type from binding pattern names, but the real checker _does_!
		// This means ID won't let you write, say, `({elem}) => false` without an annotation, even though it's trivially of type
		// `(p0: {elem: any}) => boolean` and error-free under `noImplicitAny: false`!
		// That limitation is retained here.
		return NewPseudoTypeNoResult(node.AsNode());
	}

	static function cloneParameters(ch:PseudoChecker, nodes:NodeList):Array<PseudoParameter> {
		if (nodes == null) {
			return null;
		}
		if (nodes.Nodes.length == 0) {
			return null;
		}
		final lastRequired = lastRequiredParamIndex(nodes.Nodes);
		final result = new Array<PseudoParameter>();
		for (i in 0...nodes.Nodes.length) {
			final e = nodes.Nodes[i];
			final p = e.AsParameterDeclaration();
			var optional = p.QuestionToken != null;
			if (!optional && p.Initializer != null) {
				// A parameter with an initializer is optional only if all subsequent
				// parameters are also optional/have initializers/are rest parameters.
				// This matches the checker's isOptionalParameter semantics.
				optional = i >= lastRequired - 1;
			}
			result.push(NewPseudoParameter(p.DotDotDotToken != null, e.Name(), optional, ch.typeFromParameterWorker(p, i, lastRequired)));
		}
		return result;
	}
}
