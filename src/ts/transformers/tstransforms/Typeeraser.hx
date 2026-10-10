package ts.transformers.tstransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/tstransforms/typeeraser.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.tstransforms)
class TypeEraserTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var compilerOptions:CompilerOptions = null;
	var parentNode:Node = null;
	var currentNode:Node = null;

	public function new() {}

	// PORT: promoted methods of embedded transformers.Transformer
	inline function EmitContext():ts.printer.Emitcontext.EmitContext
		return Transformer.EmitContext();

	inline function Factory():ts.printer.Factory.NodeFactory
		return Transformer.Factory();

	inline function Visitor():NodeVisitor
		return Transformer.Visitor();

	// Pushes a new child node onto the ancestor tracking stack, returning the grandparent node to be restored later via `popNode`.
	function pushNode(node:Node):Node {
		final grandparentNode = parentNode;
		parentNode = currentNode;
		currentNode = node;
		return grandparentNode;
	}

	// Pops the last child node off the ancestor tracking stack, restoring the grandparent node.
	function popNode(grandparentNode:Node):Void {
		currentNode = parentNode;
		parentNode = grandparentNode;
	}

	function elide(node:Statement):Statement {
		return EmitContext().NewNotEmittedStatement(node.AsNode());
	}

	function visit(node:Node):Node {
		if ((node.SubtreeFacts() & SubtreeContainsTypeScript) == 0) {
			return node;
		}

		if (Ast.IsStatement(node) && Ast.HasSyntacticModifier(node, ModifierFlagsAmbient)) {
			return elide(node);
		}

		final grandparentNode = pushNode(node);
		// PORT: defer — popNode runs after the switch body (visitWorker) returns.
		final result = visitWorker(node);
		popNode(grandparentNode);
		return result;
	}

	// PORT: defer — the switch of Go `visit` after pushNode, so that popNode runs at every return.
	function visitWorker(node:Node):Node {
		switch (node.Kind) {
			case
				// TypeScript accessibility and readonly modifiers are elided
				KindPublicKeyword, KindPrivateKeyword, KindProtectedKeyword, KindAbstractKeyword, KindOverrideKeyword, KindConstKeyword, KindDeclareKeyword,
				KindReadonlyKeyword,
				// TypeScript type nodes are elided.
				KindArrayType, KindTupleType, KindOptionalType, KindRestType, KindTypeLiteral, KindTypePredicate, KindTypeParameter, KindAnyKeyword,
				KindUnknownKeyword, KindBooleanKeyword, KindStringKeyword, KindNumberKeyword, KindNeverKeyword, KindVoidKeyword, KindSymbolKeyword,
				KindConstructorType, KindFunctionType, KindTypeQuery, KindTypeReference, KindUnionType, KindIntersectionType, KindConditionalType,
				KindParenthesizedType, KindThisType, KindTypeOperator, KindIndexedAccessType, KindMappedType, KindLiteralType,
				// TypeScript index signatures are elided.
				KindIndexSignature:
				return null;

			case KindInKeyword, KindOutKeyword:
				// TypeScript `in`/`out` variance modifiers are elided. These keywords are only
				// meaningful as modifiers on type parameters (which are themselves elided), but they may
				// appear as a grammar error on other declarations and must not leak into the emitted JS.
				// The `in` binary operator shares this token kind, so only elide when used as a modifier.
				if (parentNode == null || !Ast.IsBinaryExpression(parentNode)) {
					return null;
				}
				return Visitor().VisitEachChild(node);

			case KindJSImportDeclaration:
				// reparsed commonjs are elided
				return null;
			case KindTypeAliasDeclaration, KindJSTypeAliasDeclaration, KindInterfaceDeclaration:
				// TypeScript type-only declarations are elided.
				return elide(node);

			case KindNamespaceExportDeclaration:
				// TypeScript namespace export declarations are elided.
				return null;

			case KindModuleDeclaration:
				if (!Ast.IsIdentifier(node.Name())
					|| !Ast.IsInstantiatedModule(node, compilerOptions.ShouldPreserveConstEnums())
					|| Tstransforms.getInnermostModuleDeclarationFromDottedModule(node.AsModuleDeclaration()).Body == null) {
					// TypeScript module declarations are elided if they are not instantiated or have no body
					return elide(node);
				}
				return Visitor().VisitEachChild(node);

			case KindExpressionWithTypeArguments:
				final n = node.AsExpressionWithTypeArguments();
				return Factory().UpdateExpressionWithTypeArguments(n, Visitor().VisitNode(n.Expression), null);

			case KindPropertyDeclaration:
				if (compilerOptions.ExperimentalDecorators.IsTrue()
					&& Ast.HasSyntacticModifier(node, ModifierFlagsAmbient | ModifierFlagsAbstract)
					&& Ast.HasDecorators(node)) {
					// declare/abstract props with decorators must be preserved until the decorator transform can process them and remove them
					final n = node.AsPropertyDeclaration();
					return Factory().UpdatePropertyDeclaration(n, Visitor().VisitModifiers(n.Modifiers()), Visitor().VisitNode(n.Name()), null, null,
						Visitor().VisitNode(n.Initializer));
				}
				if (Ast.HasSyntacticModifier(node, ModifierFlagsAmbient | ModifierFlagsAbstract)) {
					// TypeScript `declare` fields are elided
					return null;
				}
				final n = node.AsPropertyDeclaration();
				return Factory().UpdatePropertyDeclaration(n, Visitor().VisitModifiers(n.Modifiers()), Visitor().VisitNode(n.Name()), null, null,
					Visitor().VisitNode(n.Initializer));

			case KindConstructor:
				final n = node.AsConstructorDeclaration();
				if (Ast.NodeIsMissing(n.Body)) {
					// TypeScript overloads are elided
					return null;
				}
				return Factory().UpdateConstructorDeclaration(n, null, null, Visitor().VisitNodes(n.Parameters), null, null, Visitor().VisitNode(n.Body));

			case KindMethodDeclaration:
				final n = node.AsMethodDeclaration();
				if (Ast.NodeIsMissing(n.Body)) {
					// TypeScript overloads are elided
					return null;
				}
				return Factory().UpdateMethodDeclaration(n, Visitor().VisitModifiers(n.Modifiers()), n.AsteriskToken, Visitor().VisitNode(n.Name()), null, null,
					Visitor().VisitNodes(n.Parameters), null, null, Visitor().VisitNode(n.Body));

			case KindGetAccessor:
				final n = node.AsGetAccessorDeclaration();
				if (Ast.NodeIsMissing(n.Body) && Ast.HasSyntacticModifier(node, ModifierFlagsAbstract)) {
					// Abstract accessors are elided
					return null;
				}
				var body = Visitor().VisitNode(n.Body);
				if (body == null) {
					body = Factory().NewBlock(Factory().NewNodeList(null), false);
				}
				return Factory().UpdateGetAccessorDeclaration(n, Visitor().VisitModifiers(n.Modifiers()), Visitor().VisitNode(n.Name()), null,
					Visitor().VisitNodes(n.Parameters), null, null, body);

			case KindSetAccessor:
				final n = node.AsSetAccessorDeclaration();
				if (Ast.NodeIsMissing(n.Body) && Ast.HasSyntacticModifier(node, ModifierFlagsAbstract)) {
					// Abstract accessors are elided
					return null;
				}
				var body = Visitor().VisitNode(n.Body);
				if (body == null) {
					body = Factory().NewBlock(Factory().NewNodeList(null), false);
				}
				return Factory().UpdateSetAccessorDeclaration(n, Visitor().VisitModifiers(n.Modifiers()), Visitor().VisitNode(n.Name()), null,
					Visitor().VisitNodes(n.Parameters), null, null, body);

			case KindVariableDeclaration:
				final n = node.AsVariableDeclaration();
				final updated = Factory().UpdateVariableDeclaration(n, Visitor().VisitNode(n.Name()), null, null, Visitor().VisitNode(n.Initializer));
				if (n.Type != null) {
					EmitContext().SetTypeNode(updated.AsVariableDeclaration().Name(), n.Type);
				}
				return updated;

			case KindHeritageClause:
				final n = node.AsHeritageClause();
				if (n.Token == KindImplementsKeyword) {
					// TypeScript `implements` clauses are elided
					return null;
				}
				return Factory().UpdateHeritageClause(n, n.Token, Visitor().VisitNodes(n.Types));

			case KindClassDeclaration:
				final n = node.AsClassDeclaration();
				return Factory().UpdateClassDeclaration(n, Visitor().VisitModifiers(n.Modifiers()), Visitor().VisitNode(n.Name()), null,
					Visitor().VisitNodes(n.HeritageClauses), Visitor().VisitNodes(n.Members));

			case KindClassExpression:
				final n = node.AsClassExpression();
				return Factory().UpdateClassExpression(n, Visitor().VisitModifiers(n.Modifiers()), Visitor().VisitNode(n.Name()), null,
					Visitor().VisitNodes(n.HeritageClauses), Visitor().VisitNodes(n.Members));

			case KindFunctionDeclaration:
				final n = node.AsFunctionDeclaration();
				if (Ast.NodeIsMissing(n.Body)) {
					// TypeScript overloads are elided
					return elide(node);
				}
				return Factory().UpdateFunctionDeclaration(n, Visitor().VisitModifiers(n.Modifiers()), n.AsteriskToken, Visitor().VisitNode(n.Name()), null,
					Visitor().VisitNodes(n.Parameters), null, null, Visitor().VisitNode(n.Body));

			case KindFunctionExpression:
				final n = node.AsFunctionExpression();
				return Factory().UpdateFunctionExpression(n, Visitor().VisitModifiers(n.Modifiers()), n.AsteriskToken, Visitor().VisitNode(n.Name()), null,
					Visitor().VisitNodes(n.Parameters), null, null, Visitor().VisitNode(n.Body));

			case KindArrowFunction:
				final n = node.AsArrowFunction();
				return Factory().UpdateArrowFunction(n, Visitor().VisitModifiers(n.Modifiers()), null, Visitor().VisitNodes(n.Parameters), null, null,
					n.EqualsGreaterThanToken, Visitor().VisitNode(n.Body));

			case KindParameter:
				if (Ast.IsThisParameter(node)) {
					// TypeScript `this` parameters are elided
					return null;
				}
				final n = node.AsParameterDeclaration();
				// preserve parameter property modifiers to be handled by the runtime transformer
				var modifiers:ModifierList = null;
				if (Ast.IsParameterPropertyDeclaration(node, parentNode)) {
					modifiers = Transformers.ExtractModifiers(EmitContext(), n.Modifiers(), ModifierFlagsParameterPropertyModifier);
				}
				// preserve decorators for the decorator transforms
				if (Ast.HasDecorators(node)) {
					final decorators = node.Decorators();
					final visited = Visitor().VisitSlice(decorators).a;
					if (modifiers == null) {
						modifiers = Factory().NewModifierList(visited);
					} else {
						modifiers = Factory().NewModifierList(Slices.Concat(modifiers.Nodes, visited));
					}
				}
				return Factory().UpdateParameterDeclaration(n, modifiers, n.DotDotDotToken, Visitor().VisitNode(n.Name()), null, null,
					Visitor().VisitNode(n.Initializer));

			case KindCallExpression:
				final n = node.AsCallExpression();
				return Factory().UpdateCallExpression(n, Visitor().VisitNode(n.Expression), n.QuestionDotToken, null, Visitor().VisitNodes(n.Arguments), n.Flags);

			case KindNewExpression:
				final n = node.AsNewExpression();
				return Factory().UpdateNewExpression(n, Visitor().VisitNode(n.Expression), null, Visitor().VisitNodes(n.Arguments));

			case KindTaggedTemplateExpression:
				final n = node.AsTaggedTemplateExpression();
				return Factory().UpdateTaggedTemplateExpression(n, Visitor().VisitNode(n.Tag), n.QuestionDotToken, null, Visitor().VisitNode(n.Template), n.Flags);

			case KindNonNullExpression, KindTypeAssertionExpression, KindAsExpression, KindSatisfiesExpression:
				final partial = Factory().NewPartiallyEmittedExpression(Visitor().VisitNode(node.Expression()));
				EmitContext().SetOriginal(partial, node);
				partial.Loc = node.Loc;
				return partial;

			case KindParenthesizedExpression:
				if (!Ast.IsJSDocTypeAssertion(node)) {
					final n = node.AsParenthesizedExpression();
					final expression = Ast.SkipOuterExpressions(n.Expression, OEKAllExceptAssertionsOrExpressionsWithTypeArguments);
					if (Ast.IsAssertionExpression(expression) || Ast.IsSatisfiesExpression(expression)) {
						final partial = Factory().NewPartiallyEmittedExpression(Visitor().VisitNode(n.Expression));
						EmitContext().SetOriginal(partial, node);
						partial.Loc = node.Loc;
						return partial;
					}
				}
				return Visitor().VisitEachChild(node);

			case KindJsxSelfClosingElement:
				final n = node.AsJsxSelfClosingElement();
				return Factory().UpdateJsxSelfClosingElement(n, Visitor().VisitNode(n.TagName), null, Visitor().VisitNode(n.Attributes));

			case KindJsxOpeningElement:
				final n = node.AsJsxOpeningElement();
				return Factory().UpdateJsxOpeningElement(n, Visitor().VisitNode(n.TagName), null, Visitor().VisitNode(n.Attributes));

			case KindImportEqualsDeclaration:
				final n = node.AsImportEqualsDeclaration();
				if (n.IsTypeOnly) {
					// elide type-only imports
					return null;
				}
				return Visitor().VisitEachChild(node);

			case KindImportDeclaration:
				final n = node.AsImportDeclaration();
				if (n.ImportClause == null) {
					// Do not elide a side-effect only import declaration.
					//  import "foo";
					return node;
				}
				final importClause = Visitor().VisitNode(n.ImportClause);
				if (importClause == null) {
					return null;
				}
				return Factory().UpdateImportDeclaration(n, n.Modifiers(), importClause, n.ModuleSpecifier, n.Attributes);

			case KindImportClause:
				final n = node.AsImportClause();
				if (n.AsNode().IsTypeOnly()) {
					// Always elide type-only imports
					return null;
				}
				final name = n.Name();
				final namedBindings = Visitor().VisitNode(n.NamedBindings);
				if (name == null && namedBindings == null) {
					// all import bindings were elided
					return null;
				}
				return Factory().UpdateImportClause(n, n.PhaseModifier, name, namedBindings);

			case KindNamedImports:
				final n = node.AsNamedImports();
				if (Core.len(n.Elements.Nodes) == 0) {
					// Do not elide a side-effect only import declaration.
					return node;
				}
				final elements = Visitor().VisitNodes(n.Elements);
				if (!compilerOptions.VerbatimModuleSyntax.IsTrue() && Core.len(elements.Nodes) == 0) {
					// all import specifiers were elided
					return null;
				}
				return Factory().UpdateNamedImports(n, elements);

			case KindImportSpecifier:
				final n = node.AsImportSpecifier();
				if (n.IsTypeOnly) {
					// elide type-only or unused imports
					return null;
				}
				return node;

			case KindExportDeclaration:
				final n = node.AsExportDeclaration();
				if (n.IsTypeOnly) {
					// elide type-only exports
					return null;
				}
				var exportClause:Node = null;
				if (n.ExportClause != null) {
					exportClause = Visitor().VisitNode(n.ExportClause);
					if (exportClause == null) {
						// all export bindings were elided
						return null;
					}
				}
				return Factory().UpdateExportDeclaration(n, null /*modifiers*/, false /*isTypeOnly*/, exportClause, Visitor().VisitNode(n.ModuleSpecifier),
					Visitor().VisitNode(n.Attributes));

			case KindNamedExports:
				final n = node.AsNamedExports();
				if (Core.len(n.Elements.Nodes) == 0) {
					// Do not elide an empty export declaration.
					return node;
				}

				final elements = Visitor().VisitNodes(n.Elements);
				if (!compilerOptions.VerbatimModuleSyntax.IsTrue() && Core.len(elements.Nodes) == 0) {
					// all export specifiers were elided
					return null;
				}
				return Factory().UpdateNamedExports(n, elements);

			case KindExportSpecifier:
				final n = node.AsExportSpecifier();
				if (n.IsTypeOnly) {
					// elide unused export
					return null;
				}
				return node;

			case KindEnumDeclaration:
				if (Ast.IsEnumConst(node)) {
					return node;
				}
				return Visitor().VisitEachChild(node);

			default:
				return Visitor().VisitEachChild(node);
		}
	}
}
