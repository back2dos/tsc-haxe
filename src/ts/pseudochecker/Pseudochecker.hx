package ts.pseudochecker;

// Port of internal/pseudochecker.
// Package-level functions and vars of all files (Go file order). Types: Checker.hx (PseudoChecker),
// Type_.hx (type.go). Methods of PseudoChecker from lookup.go: Lookup.hx.
@:allow(ts.pseudochecker)
class Pseudochecker {
	// --- checker.go ---

	public static function NewPseudoChecker(strictNullChecks:Bool, exactOptionalPropertyTypes:Bool):PseudoChecker {
		final ch = new PseudoChecker();
		ch.strictNullChecks = strictNullChecks;
		ch.exactOptionalPropertyTypes = exactOptionalPropertyTypes;
		return ch;
	}

	// --- lookup.go ---

	static function isValueSignatureDeclaration(node:Node):Bool {
		return Ast.IsFunctionExpression(node) || Ast.IsArrowFunction(node) || Ast.IsMethodDeclaration(node) || Ast.IsAccessor(node)
			|| Ast.IsFunctionDeclaration(node) || Ast.IsConstructorDeclaration(node);
	}

	// See `isConstContext` in `checker.go` - this is basically any node kind mentioned in that
	static function isConstContextPropagatingKind(kind:Kind):Bool {
		switch (kind) {
			case KindArrayLiteralExpression, KindObjectLiteralExpression, KindParenthesizedExpression, KindSpreadElement, KindPropertyAssignment,
				KindShorthandPropertyAssignment, KindTemplateSpan, KindPrefixUnaryExpression:
				return true;
			default:
		}
		return false;
	}

	// IsInConstContext traverses up the parent chain to determine if the node is within a const context without needing any
	// persistent traversal scope tracking (which could be unreliable in the presence of `typeof` queries anyway!)
	public static function IsInConstContext(node:Node):Bool {
		// An expression is in a const context if an ancestor is a const type maybeAssertion expression
		final maybeAssertion = Ast.FindAncestor(node.Parent, function(n:Node):Bool {
			// stop traversing at assertions or anything not an array/object literal, since only those create or transfer const-ness
			return Ast.IsAssertionExpression(n) || !isConstContextPropagatingKind(n.Kind);
		});
		return Ast.IsConstAssertion(maybeAssertion);
	}

	static function isUndefinedPseudoType(t:PseudoType):Bool {
		return t.Kind == PseudoTypeKindUndefined
			|| (t.Kind == PseudoTypeKindMaybeConstLocation && isUndefinedPseudoType(t.AsPseudoTypeMaybeConstLocation().ConstType));
	}

	static function typeNodeCouldReferToUndefined(node:Node):Bool {
		while (node.Kind == KindParenthesizedType) {
			node = node.AsParenthesizedTypeNode().Type;
		}
		switch (node.Kind) {
			// these types require symbolic/type resolution to know if they definitely do or do not refer to `undefined`, so might (or definitely do)
			case KindTypeReference, KindIndexedAccessType, KindTypeQuery, KindOptionalType, KindRestType, KindImportType:
				return true;
			case KindIntersectionType:
				// TODO: why is this not `core.Every`? strada treated unions and intersections the same, but logically every intersection member needs to contain a possible `undefined`
				// for the result type to contain `undefined`. Likely a bug persisting from strada.
				return Core.Some(node.AsIntersectionTypeNode().Types.Nodes, typeNodeCouldReferToUndefined);
			case KindUnionType:
				return Core.Some(node.AsUnionTypeNode().Types.Nodes, typeNodeCouldReferToUndefined);
			case KindConditionalType: // suspect - should be treated as a union of both branches instead, likely a bug persisted from strada
				return true;
			case KindTypeOperator: // suspect - always refers to a subset of `string | number | symbol` for `keyof` or `symbol` for `unique`
				return true;
			case KindTypePredicate: // suspect - always refers to `never` or `boolean`, depending on kind - considered possibly-`undefined` referencing for strada compat
				return true;
			case KindUndefinedKeyword:
				return true;
			default: // all other keywords, literal types, function-y types, array/tuple types, type literals, template types, this types
				return false;
		}
	}

	// see this as the inverse of `canAddUndefined` in `expressionToTypeNode` in strada
	public static function CouldAlreadyReferToUndefinedType(t:PseudoType):Bool {
		if (t.Kind == PseudoTypeKindNoResult || t.Kind == PseudoTypeKindInferred || isUndefinedPseudoType(t)) {
			return true;
		}
		if (t.Kind == PseudoTypeKindMaybeConstLocation) {
			final mc = t.AsPseudoTypeMaybeConstLocation();
			return CouldAlreadyReferToUndefinedType(mc.RegularType); // if we're even asking this question, it's not a `const` location
		}
		if (t.Kind == PseudoTypeKindDirect) {
			// inspect the direct type node
			final node = t.AsPseudoTypeDirect().TypeNode;
			return typeNodeCouldReferToUndefined(node);
		}
		if (t.Kind == PseudoTypeKindUnion) {
			return Core.Some(t.AsPseudoTypeUnion().Types, CouldAlreadyReferToUndefinedType);
		}
		return false;
	}

	static function isOptionalInitializedOrRestParameter(node:ParameterDeclarationNode):Bool {
		final p = node.AsParameterDeclaration();
		if (p.DotDotDotToken != null || p.Initializer != null || p.QuestionToken != null) {
			return true;
		}
		return false;
	}

	// lastRequiredParamIndex returns the index just past the last required parameter
	// in the list. A parameter is "required" if it has no question token, no initializer,
	// and no rest token. This is computed in a single reverse pass so callers can
	// determine "has required parameter after index i" with `i+1 < lastRequired`
	// (equivalently, `i < lastRequired-1`) in O(1).
	static function lastRequiredParamIndex(params:Array<Node>):Int {
		var i = Core.len(params) - 1;
		while (i >= 0) {
			if (!isOptionalInitializedOrRestParameter(params[i])) {
				return i + 1;
			}
			i--;
		}
		return 0;
	}

	static function addUndefinedIfDefinitelyRequired(expr:PseudoType):PseudoType {
		// If `expr` doesn't already contain `| undefined` or a direct/inferred type that may contain `undefined`, add `| undefined`
		// in Strada, this reached into the checker to see if `undefined` was necessary, using `isRequiredOptionalParameter` from the emit resolver,
		// but that's not required on top of the syntactic checks to get the same behavior. (If we get the type wrong, it'll mismatch later and be discarded
		// for an inference error since corsa actually validates that pseudotypes semantically match the inferred type the checker produces)
		if (CouldAlreadyReferToUndefinedType(expr)) {
			return expr; // will just error later, more like than not, unless the `undefined` is explicit in the pseudo
		}
		// Explicitly add an `| undefined`
		return NewPseudoTypeUnion([expr, PseudoTypeUndefined]);
	}

	static function isContextuallyTyped(node:Node):Bool {
		return Ast.FindAncestor(node.Parent, function(n:Node):Bool {
			// Functions calls or parent type annotations (but not the return type of a function expression) may impact the inferred type and local inference is unreliable
			if (Ast.IsCallExpression(n)) {
				return true;
			}
			if (Ast.IsSatisfiesExpression(n)) {
				return true;
			}
			if ((Ast.IsVariableParameterOrProperty(n) || Ast.IsAssertionExpression(n)) && n.Type() != null && !Ast.IsConstAssertion(n)) {
				return true;
			}
			return Ast.IsJsxElement(n) || Ast.IsJsxExpression(n);
		}) != null;
	}

	// --- type.go ---

	static function newPseudoType(kind:PseudoTypeKind, data:PseudoTypeData):PseudoType {
		final n = data.AsPseudoType();
		n.Kind = kind;
		n.data = data;
		return n;
	}

	public static final PseudoTypeUndefined:PseudoType = newPseudoType(PseudoTypeKindUndefined, new PseudoTypeBase());
	public static final PseudoTypeNull:PseudoType = newPseudoType(PseudoTypeKindNull, new PseudoTypeBase());
	public static final PseudoTypeAny:PseudoType = newPseudoType(PseudoTypeKindAny, new PseudoTypeBase());
	public static final PseudoTypeString:PseudoType = newPseudoType(PseudoTypeKindString, new PseudoTypeBase());
	public static final PseudoTypeNumber:PseudoType = newPseudoType(PseudoTypeKindNumber, new PseudoTypeBase());
	public static final PseudoTypeBigInt:PseudoType = newPseudoType(PseudoTypeKindBigInt, new PseudoTypeBase());
	public static final PseudoTypeBoolean:PseudoType = newPseudoType(PseudoTypeKindBoolean, new PseudoTypeBase());
	public static final PseudoTypeFalse:PseudoType = newPseudoType(PseudoTypeKindFalse, new PseudoTypeBase());
	public static final PseudoTypeTrue:PseudoType = newPseudoType(PseudoTypeKindTrue, new PseudoTypeBase());

	public static function NewPseudoTypeDirect(typeNode:Node):PseudoType {
		final d = new PseudoTypeDirect();
		d.TypeNode = typeNode;
		return newPseudoType(PseudoTypeKindDirect, d);
	}

	public static function NewPseudoTypeInferred(expr:Node, isSignatureReturn:Bool):PseudoType {
		final d = new PseudoTypeInferred();
		d.Expression = expr;
		d.IsSignatureReturn = isSignatureReturn;
		return newPseudoType(PseudoTypeKindInferred, d);
	}

	public static function NewPseudoTypeInferredWithErrors(expr:Node, isSignatureReturn:Bool, errorNodes:Array<Node>):PseudoType {
		final d = new PseudoTypeInferred();
		d.Expression = expr;
		d.ErrorNodes = errorNodes;
		d.IsSignatureReturn = isSignatureReturn;
		return newPseudoType(PseudoTypeKindInferred, d);
	}

	public static function NewPseudoTypeNoResult(decl:Node):PseudoType {
		final d = new PseudoTypeNoResult();
		d.Declaration = decl;
		return newPseudoType(PseudoTypeKindNoResult, d);
	}

	public static function NewPseudoTypeMaybeConstLocation(loc:Node, ct:PseudoType, reg:PseudoType):PseudoType {
		final d = new PseudoTypeMaybeConstLocation();
		d.Node = loc;
		d.ConstType = ct;
		d.RegularType = reg;
		return newPseudoType(PseudoTypeKindMaybeConstLocation, d);
	}

	public static function NewPseudoTypeUnion(types:Array<PseudoType>):PseudoType {
		final d = new PseudoTypeUnion();
		d.Types = types;
		return newPseudoType(PseudoTypeKindUnion, d);
	}

	public static function NewPseudoParameter(isRest:Bool, name:Node, isOptional:Bool, t:PseudoType):PseudoParameter {
		final p = new PseudoParameter();
		p.Rest = isRest;
		p.Name = name;
		p.Optional = isOptional;
		p.Type = t;
		return p;
	}

	public static function NewPseudoTypeSingleCallSignature(signature:Node, parameters:Array<PseudoParameter>,
			typeParameters:Array<TypeParameterDeclaration>, returnType:PseudoType):PseudoType {
		final d = new PseudoTypeSingleCallSignature();
		d.Signature = signature;
		d.Parameters = parameters;
		d.TypeParameters = typeParameters;
		d.ReturnType = returnType;
		return newPseudoType(PseudoTypeKindSingleCallSignature, d);
	}

	public static function NewPseudoTypeTuple(elements:Array<PseudoType>):PseudoType {
		final d = new PseudoTypeTuple();
		d.Elements = elements;
		return newPseudoType(PseudoTypeKindTuple, d);
	}

	static function newPseudoObjectElement(kind:PseudoObjectElementKind, name:Node, optional:Bool, data:PseudoObjectElementData):PseudoObjectElement {
		final e = data.AsPseudoObjectElement();
		e.Kind = kind;
		e.Name = name;
		e.Optional = optional;
		e.data = data;
		return e;
	}

	public static function NewPseudoObjectMethod(signature:Node, name:Node, optional:Bool, typeParameters:Array<TypeParameterDeclaration>,
			parameters:Array<PseudoParameter>, returnType:PseudoType):PseudoObjectElement {
		final d = new PseudoObjectMethod();
		d.Signature = signature;
		d.TypeParameters = typeParameters;
		d.Parameters = parameters;
		d.ReturnType = returnType;
		return newPseudoObjectElement(PseudoObjectElementKindMethod, name, optional, d);
	}

	public static function NewPseudoPropertyAssignment(readonly:Bool, name:Node, optional:Bool, t:PseudoType):PseudoObjectElement {
		final d = new PseudoPropertyAssignment();
		d.Readonly = readonly;
		d.Type = t;
		return newPseudoObjectElement(PseudoObjectElementKindPropertyAssignment, name, optional, d);
	}

	public static function NewPseudoSetAccessor(signature:Node, name:Node, optional:Bool, p:PseudoParameter):PseudoObjectElement {
		final d = new PseudoSetAccessor();
		d.Signature = signature;
		d.Parameter = p;
		return newPseudoObjectElement(PseudoObjectElementKindSetAccessor, name, optional, d);
	}

	public static function NewPseudoGetAccessor(signature:Node, name:Node, optional:Bool, t:PseudoType):PseudoObjectElement {
		final d = new PseudoGetAccessor();
		d.Signature = signature;
		d.Type = t;
		return newPseudoObjectElement(PseudoObjectElementKindGetAccessor, name, optional, d);
	}

	public static function NewPseudoTypeObjectLiteral(elements:Array<PseudoObjectElement>):PseudoType {
		final d = new PseudoTypeObjectLiteral();
		d.Elements = elements;
		return newPseudoType(PseudoTypeKindObjectLiteral, d);
	}

	public static function NewPseudoTypeStringLiteral(node:Node):PseudoType {
		final d = new PseudoTypeLiteral();
		d.Node = node;
		return newPseudoType(PseudoTypeKindStringLiteral, d);
	}

	public static function NewPseudoTypeNumericLiteral(node:Node):PseudoType {
		final d = new PseudoTypeLiteral();
		d.Node = node;
		return newPseudoType(PseudoTypeKindNumericLiteral, d);
	}

	public static function NewPseudoTypeBigIntLiteral(node:Node):PseudoType {
		final d = new PseudoTypeLiteral();
		d.Node = node;
		return newPseudoType(PseudoTypeKindBigIntLiteral, d);
	}
}
