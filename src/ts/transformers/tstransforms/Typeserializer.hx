package ts.transformers.tstransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/tstransforms/typeserializer.go (upstream v7.0.2).
// Ported from internal/transformers/tstransforms/typeserializer.go (upstream v7.0.2).

@:allow(ts.transformers.tstransforms)
class MetadataSerializer {
	var resolver:EmitResolver = null;
	var languageVersion:ScriptTarget = 0;
	var strictNullChecks:Bool = false;
	var f:ts.printer.Factory.NodeFactory = null;
	var ec:EmitContext = null;
	var c:MetadataSerializerContext = new MetadataSerializerContext();

	public function new() {}

	function setContext(ctx:MetadataSerializerContext):Void {
		this.c = ctx;
	}

	public function SerializeTypeOfNode(ctx:MetadataSerializerContext, node:Node, container:Node):Node {
		final oldCtx = this.c;
		this.c = ctx.copy(); // PORT: Go passes the struct by value
		final r = serializeTypeOfNode(node, container);
		setContext(oldCtx); // PORT: defer
		return r;
	}

	public function SerializeParameterTypesOfNode(ctx:MetadataSerializerContext, node:Node, container:Node):Node {
		final oldCtx = this.c;
		this.c = ctx.copy(); // PORT: Go passes the struct by value
		final r = serializeParameterTypesOfNode(node, container);
		setContext(oldCtx); // PORT: defer
		return r;
	}

	public function SerializeReturnTypeOfNode(ctx:MetadataSerializerContext, node:Node):Node {
		final oldCtx = this.c;
		this.c = ctx.copy(); // PORT: Go passes the struct by value
		final r = serializeReturnTypeOfNode(node);
		setContext(oldCtx); // PORT: defer
		return r;
	}

	/**
	* Serializes the type of a node for use with decorator type metadata.
	* @param node The node that should have its type serialized.
	 */
	function serializeTypeOfNode(node:Node, container:Node):Node {
		switch (node.Kind) {
			case KindPropertyDeclaration | KindParameter:
				return serializeTypeNode(node.Type());
			case KindGetAccessor | KindSetAccessor:
				return serializeTypeNode(Tstransforms.getAccessorTypeNode(node, container));
			case KindClassDeclaration | KindClassExpression | KindMethodDeclaration:
				return f.NewIdentifier("Function");
			default:
				return f.NewVoidZeroExpression();
		}
	}

	/**
	* Serializes the type of a node for use with decorator type metadata.
	* @param node The node that should have its type serialized.
	 */
	function serializeParameterTypesOfNode(node:Node, container:Node):Node {
		var valueDeclaration:Node = null;
		if (Ast.IsClassLike(node)) {
			valueDeclaration = Ast.GetFirstConstructorWithBody(node);
		} else if (Ast.IsFunctionLike(node) && Ast.NodeIsPresent(node.Body())) {
			valueDeclaration = node;
		}

		if (valueDeclaration == null) {
			return f.NewArrayLiteralExpression(f.NewNodeList([]), false);
		}

		var expressions:Array<Node> = null;
		final parameters = Tstransforms.getParametersOfDecoratedDeclaration(valueDeclaration, container);
		for (i in 0...Core.len(parameters.Nodes)) {
			final parameter = parameters.Nodes[i];
			if (i == 0 && Ast.IsIdentifier(parameter.Name()) && parameter.Name().Text() == "this") {
				continue;
			}
			if (expressions == null) {
				expressions = [];
			}
			if (parameter.AsParameterDeclaration().DotDotDotToken != null) {
				expressions.push(serializeTypeNode(Ast.GetRestParameterElementType(parameter.Type())));
			} else {
				expressions.push(serializeTypeOfNode(parameter, container));
			}
		}
		return f.NewArrayLiteralExpression(f.NewNodeList(expressions), false);
	}

	/**
	* Serializes the return type of a node for use with decorator type metadata.
	* @param node The node that should have its return type serialized.
	 */
	function serializeReturnTypeOfNode(node:Node):Node {
		if (Ast.IsFunctionLike(node) && node.Type() != null) {
			return serializeTypeNode(node.Type());
		} else if (Ast.IsAsyncFunction(node)) {
			return f.NewIdentifier("Promise");
		}
		return f.NewVoidZeroExpression();
	}

	/**
	* Serializes a type node for use with decorator type metadata.
	*
	* Types are serialized in the following fashion:
	* - Void types point to "undefined" (e.g. "void 0")
	* - Function and Constructor types point to the global "Function" constructor.
	* - Interface types with a call or construct signature types point to the global
	*   "Function" constructor.
	* - Array and Tuple types point to the global "Array" constructor.
	* - Type predicates and booleans point to the global "Boolean" constructor.
	* - String literal types and strings point to the global "String" constructor.
	* - Enum and number types point to the global "Number" constructor.
	* - Symbol types point to the global "Symbol" constructor.
	* - Type references to classes (or class-like variables) point to the constructor for the class.
	* - Anything else points to the global "Object" constructor.
	*
	* @param node The type node to serialize.
	 */
	function serializeTypeNode(node:Node):Node {
		if (node == null) {
			return f.NewIdentifier("Object");
		}

		node = Ast.SkipTypeParentheses(node);

		switch (node.Kind) {
			case KindVoidKeyword | KindUndefinedKeyword | KindNeverKeyword:
				return f.NewVoidZeroExpression();
			case KindFunctionType | KindConstructorType:
				return f.NewIdentifier("Function");
			case KindArrayType | KindTupleType:
				return f.NewIdentifier("Array");
			case KindTypePredicate:
				if (node.AsTypePredicateNode().AssertsModifier != null) {
					return f.NewVoidZeroExpression();
				}
				return f.NewIdentifier("Boolean");
			case KindBooleanKeyword:
				return f.NewIdentifier("Boolean");
			case KindTemplateLiteralType | KindStringKeyword:
				return f.NewIdentifier("String");
			case KindObjectKeyword:
				return f.NewIdentifier("Object");
			case KindLiteralType:
				return serializeLiteralOfLiteralTypeNode(node.AsLiteralTypeNode().Literal);
			case KindNumberKeyword:
				return f.NewIdentifier("Number");
			case KindBigIntKeyword:
				return serializeBigIntConstructor();
			case KindSymbolKeyword:
				return f.NewIdentifier("Symbol");
			case KindTypeReference:
				return serializeTypeReferenceNode(node.AsTypeReferenceNode());
			case KindIntersectionType:
				return serializeUnionOrIntersectionConstituents(node.AsIntersectionTypeNode().Types.Nodes, true);
			case KindUnionType:
				return serializeUnionOrIntersectionConstituents(node.AsUnionTypeNode().Types.Nodes, false);
			case KindConditionalType:
				final oldState = c.serializingConditionalTypeBranch;
				c.serializingConditionalTypeBranch = true;
				final r = serializeUnionOrIntersectionConstituents([node.AsConditionalTypeNode().TrueType, node.AsConditionalTypeNode().FalseType], false);
				c.serializingConditionalTypeBranch = oldState; // PORT: defer
				return r;
			case KindTypeOperator:
				if (node.AsTypeOperatorNode().Operator == KindReadonlyKeyword) {
					return serializeTypeNode(node.Type());
				}
				// TODO: why is `unique symbol` not handled as `Symbol`? This falls back to `Object`
			case KindTypeQuery | KindIndexedAccessType | KindMappedType | KindTypeLiteral | KindAnyKeyword | KindUnknownKeyword | KindThisType | KindImportType:
				// PORT: Go `break` (leaves the switch)

			// handle JSDoc types from an invalid parse
			case KindJSDocAllType | KindJSDocVariadicType:
				// PORT: Go `break` (leaves the switch)
			case KindJSDocNullableType | KindJSDocNonNullableType | KindJSDocOptionalType:
				return serializeTypeNode(node.Type());
			default:
				Debug.FailBadSyntaxKind({KindString: () -> node.KindString()});
				return null;
		}
		return f.NewIdentifier("Object");
	}

	function serializeUnionOrIntersectionConstituents(types:Array<Node>, isIntersection:Bool):Node {
		// Note when updating logic here also update `getEntityNameForDecoratorMetadata` in checker.ts so that aliases can be marked as referenced
		var serializedType:Node = null;
		for (typeNode in Tstransforms.rangeOf(types)) {
			typeNode = Ast.SkipTypeParentheses(typeNode);
			if (typeNode.Kind == KindNeverKeyword) {
				if (isIntersection) {
					return f.NewVoidZeroExpression(); // Reduce to `never` in an intersection
				}
				continue; // Elide `never` in a union
			}

			if (typeNode.Kind == KindUnknownKeyword) {
				if (!isIntersection) {
					return f.NewIdentifier("Object"); // Reduce to `unknown` in a union
				}
				continue; // Elide `unknown` in an intersection
			}

			if (typeNode.Kind == KindAnyKeyword) {
				return f.NewIdentifier("Object"); // Reduce to `any` in a union or intersection
			}

			if (!strictNullChecks
				&& ((Ast.IsLiteralTypeNode(typeNode) && typeNode.AsLiteralTypeNode().Literal.Kind == KindNullKeyword)
					|| typeNode.Kind == KindUndefinedKeyword)) {
				continue; // Elide null and undefined from unions for metadata, just like what we did prior to the implementation of strict null checks
			}

			final serializedConstituent = serializeTypeNode(typeNode);
			if (Ast.IsIdentifier(serializedConstituent) && serializedConstituent.AsIdentifier().Text == "Object") {
				// One of the individual is global object, return immediately
				return serializedConstituent;
			}

			// If there exists union that is not `void 0` expression, check if the the common type is identifier.
			// anything more complex and we will just default to Object
			if (serializedType != null) {
				// Different types
				if (!equateSerializedTypeNodes(serializedType, serializedConstituent)) {
					return f.NewIdentifier("Object");
				}
			} else {
				// Initialize the union type
				serializedType = serializedConstituent;
			}
		}

		// If we were able to find common type, use it
		if (serializedType != null) {
			return serializedType;
		}
		return f.NewVoidZeroExpression(); // Fallback is only hit if all union constituents are null/undefined/never
	}

	function serializeLiteralOfLiteralTypeNode(node:Node):Node {
		switch (node.Kind) {
			case KindStringLiteral | KindNoSubstitutionTemplateLiteral:
				return f.NewIdentifier("String");
			case KindPrefixUnaryExpression:
				final operand = node.AsPrefixUnaryExpression().Operand;
				switch (operand.Kind) {
					case KindNumericLiteral | KindBigIntLiteral:
						return serializeLiteralOfLiteralTypeNode(operand);
					default:
						Debug.FailBadSyntaxKind({KindString: () -> operand.KindString()});
				}
			case KindNumericLiteral:
				return f.NewIdentifier("Number");
			case KindBigIntLiteral:
				return serializeBigIntConstructor();
			case KindTrueKeyword | KindFalseKeyword:
				return f.NewIdentifier("Boolean");
			case KindNullKeyword:
				return f.NewVoidZeroExpression();
			default:
				Debug.FailBadSyntaxKind({KindString: () -> node.KindString()});
				return null;
		}
		return null;
	}

	/**
	* Serializes a TypeReferenceNode to an appropriate JS constructor value for use with decorator type metadata.
	* @param node The type reference node.
	 */
	function serializeTypeReferenceNode(node:TypeReferenceNode):Node {
		var serialScope = c.currentNameScope;
		if (serialScope == null) {
			serialScope = c.currentLexicalScope;
		}
		final kind = resolver.GetTypeReferenceSerializationKind(ec.ParseNode(node.TypeName), ec.ParseNode(serialScope));
		switch (kind) {
			case TypeReferenceSerializationKindUnknown:
				// From conditional type type reference that cannot be resolved is Similar to any or unknown
				if (c.serializingConditionalTypeBranch) {
					return f.NewIdentifier("Object");
				}

				final serialized = serializeEntityNameAsExpressionFallback(node.TypeName);
				final temp = f.NewTempVariable();
				ec.AddVariableDeclaration(temp);
				return f.NewConditionalExpression(f.NewTypeCheck(f.NewAssignmentExpression(temp, serialized), "function"), f.NewToken(KindQuestionToken), temp,
					f.NewToken(KindColonToken), f.NewIdentifier("Object"));

			case TypeReferenceSerializationKindTypeWithConstructSignatureAndValue:
				return serializeEntityNameAsExpression(node.TypeName);

			case TypeReferenceSerializationKindVoidNullableOrNeverType:
				return f.NewVoidZeroExpression();

			case TypeReferenceSerializationKindBigIntLikeType:
				return serializeBigIntConstructor();

			case TypeReferenceSerializationKindBooleanType:
				return f.NewIdentifier("Boolean");

			case TypeReferenceSerializationKindNumberLikeType:
				return f.NewIdentifier("Number");

			case TypeReferenceSerializationKindStringLikeType:
				return f.NewIdentifier("String");

			case TypeReferenceSerializationKindArrayLikeType:
				return f.NewIdentifier("Array");

			case TypeReferenceSerializationKindESSymbolType:
				return f.NewIdentifier("Symbol");

			case TypeReferenceSerializationKindTypeWithCallSignature:
				return f.NewIdentifier("Function");

			case TypeReferenceSerializationKindPromise:
				return f.NewIdentifier("Promise");

			case TypeReferenceSerializationKindObjectType:
				return f.NewIdentifier("Object");
			default:
				Debug.AssertNever(kind, "unknown type reference serialization kind");
				return null;
		}
	}

	function serializeBigIntConstructor():Node {
		if ((languageVersion : Int) >= (ScriptTargetES2020 : Int)) {
			return f.NewIdentifier("BigInt");
		}
		return f.NewConditionalExpression(f.NewTypeCheck(f.NewIdentifier("BigInt"), "function"), f.NewToken(KindQuestionToken), f.NewIdentifier("BigInt"),
			f.NewToken(KindColonToken), f.NewIdentifier("Object"));
	}

	/**
	* Serializes an entity name as an expression for decorator type metadata.
	* @param node The entity name to serialize.
	 */
	function serializeEntityNameAsExpression(node:EntityName):Node {
		switch (node.Kind) {
			case KindIdentifier:
				// Create a clone of the name with a new parent, and treat it as if it were
				// a source tree node for the purposes of the checker.
				final name = node.Clone(f);
				name.Loc = node.Loc;
				ec.UnsetOriginal(name); // make this identifier emulate a parse node, making it behave correctly when inspected by the module transforms
				name.Parent = ec.ParseNode(c.currentLexicalScope); // ensure the parent is set to a parse tree node.
				return name;
			case KindQualifiedName:
				return serializeQualifiedNameAsExpression(node.AsQualifiedName());
			default:
		}
		return null;
	}

	/**
	* Serializes an qualified name as an expression for decorator type metadata.
	* @param node The qualified name to serialize.
	 */
	function serializeQualifiedNameAsExpression(node:QualifiedName):Node {
		return f.NewPropertyAccessExpression(serializeEntityNameAsExpression(node.Left), null, node.Right, NodeFlagsNone);
	}

	/**
	* Serializes an entity name which may not exist at runtime, but whose access shouldn't throw
	* @param node The entity name to serialize.
	 */
	function serializeEntityNameAsExpressionFallback(node:EntityName):Node {
		if (node.Kind == KindIdentifier) {
			// A -> typeof A !== "undefined" && A
			final copied = serializeEntityNameAsExpression(node);
			return createCheckedValue(copied, copied);
		}
		if (node.AsQualifiedName().Left.Kind == KindIdentifier) {
			// A.B -> typeof A !== "undefined" && A.B
			return createCheckedValue(serializeEntityNameAsExpression(node.AsQualifiedName().Left), serializeEntityNameAsExpression(node));
		}
		// A.B.C -> typeof A !== "undefined" && (_a = A.B) !== void 0 && _a.C
		final left = serializeEntityNameAsExpressionFallback(node.AsQualifiedName().Left);
		final temp = f.NewTempVariable();
		ec.AddVariableDeclaration(temp);
		return f.NewLogicalANDExpression(f.NewLogicalANDExpression(left.AsBinaryExpression().Left,
			f.NewStrictInequalityExpression(f.NewAssignmentExpression(temp, left.AsBinaryExpression().Right), f.NewVoidZeroExpression())),
			f.NewPropertyAccessExpression(temp, null, node.AsQualifiedName().Right, NodeFlagsNone));
	}

	/**
	* Produces an expression that results in `right` if `left` is not undefined at runtime:
	*
	* ```
	* typeof left !== "undefined" && right
	* ```
	*
	* We use `typeof L !== "undefined"` (rather than `L !== undefined`) since `L` may not be declared.
	* It's acceptable for this expression to result in `false` at runtime, as the result is intended to be
	* further checked by any containing expression.
	 */
	function createCheckedValue(left:Node, right:Node):Node {
		return f.NewLogicalANDExpression(f.NewStrictInequalityExpression(f.NewTypeOfExpression(left), f.NewStringLiteral("undefined", TokenFlagsNone)), right);
	}

	function equateSerializedTypeNodes(left:Node, right:Node):Bool {
		// temp vars used in fallback
		if (Transformers.IsGeneratedIdentifier(ec, left)) {
			return Transformers.IsGeneratedIdentifier(ec, right);
		}
		// entity names
		if (Ast.IsIdentifier(left)) {
			return Ast.IsIdentifier(right) && left.Text() == right.Text();
		}
		if (Ast.IsPropertyAccessExpression(left)) {
			return Ast.IsPropertyAccessExpression(right) && equateSerializedTypeNodes(left.Expression(), right.Expression())
				&& equateSerializedTypeNodes(left.Name(), right.Name());
		}
		// `void 0`
		if (Ast.IsVoidExpression(left)) {
			return Ast.IsVoidExpression(right) && Ast.IsNumericLiteral(left.Expression()) && Ast.IsNumericLiteral(right.Expression())
				&& left.Expression().Text() == "0" && right.Expression().Text() == "0";
		}
		// `"undefined"` or `"function"` in `typeof` checks
		if (Ast.IsStringLiteral(left)) {
			return Ast.IsStringLiteral(right) && left.Text() == right.Text();
		}
		// used in `typeof` checks for fallback
		if (Ast.IsTypeOfExpression(left)) {
			return Ast.IsTypeOfExpression(right) && equateSerializedTypeNodes(left.Expression(), right.Expression());
		}
		// parens in `typeof` checks with temps
		if (Ast.IsParenthesizedExpression(left)) {
			return Ast.IsParenthesizedExpression(right) && equateSerializedTypeNodes(left.Expression(), right.Expression());
		}
		// conditionals used in fallback
		if (Ast.IsConditionalExpression(left)) {
			return Ast.IsConditionalExpression(right)
				&& equateSerializedTypeNodes(left.AsConditionalExpression().Condition, right.AsConditionalExpression().Condition)
				&& equateSerializedTypeNodes(left.AsConditionalExpression().WhenTrue, right.AsConditionalExpression().WhenTrue)
				&& equateSerializedTypeNodes(left.AsConditionalExpression().WhenFalse, right.AsConditionalExpression().WhenFalse);
		}
		// logical binary and assignments used in fallback
		if (Ast.IsBinaryExpression(left)) {
			return Ast.IsBinaryExpression(right)
				&& left.AsBinaryExpression().OperatorToken.Kind == right.AsBinaryExpression().OperatorToken.Kind
				&& equateSerializedTypeNodes(left.AsBinaryExpression().Left, right.AsBinaryExpression().Left)
				&& equateSerializedTypeNodes(left.AsBinaryExpression().Right, right.AsBinaryExpression().Right);
		}
		return false;
	}
}

// PORT: value struct (Go passes it by value) → class with copy().
@:allow(ts.transformers.tstransforms)
class MetadataSerializerContext {
	var currentLexicalScope:Node = null;
	var currentNameScope:Node = null;
	var serializingConditionalTypeBranch:Bool = false;

	public function new(currentLexicalScope:Node = null, currentNameScope:Node = null, serializingConditionalTypeBranch:Bool = false) {
		this.currentLexicalScope = currentLexicalScope;
		this.currentNameScope = currentNameScope;
		this.serializingConditionalTypeBranch = serializingConditionalTypeBranch;
	}

	public function copy():MetadataSerializerContext {
		return new MetadataSerializerContext(currentLexicalScope, currentNameScope, serializingConditionalTypeBranch);
	}
}
