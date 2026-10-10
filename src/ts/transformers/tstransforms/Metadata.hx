package ts.transformers.tstransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/tstransforms/metadata.go (upstream v7.0.2).
// Ported from internal/transformers/tstransforms/metadata.go (upstream v7.0.2).

@:allow(ts.transformers.tstransforms)
class MetadataTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var legacyDecorators:Bool = false;
	var resolver:EmitResolver = null;
	var serializer:MetadataSerializer = null;
	var languageVersion:ScriptTarget = 0;
	var strictNullChecks:Bool = false;
	var parent:Node = null;
	var currentLexicalScope:Node = null;

	public function new() {}

	// PORT: promoted methods of embedded transformers.Transformer
	inline function EmitContext():ts.printer.Emitcontext.EmitContext return Transformer.EmitContext();

	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();

	inline function Visitor():NodeVisitor return Transformer.Visitor();

	function visit(node:Node):Node {
		if ((node.SubtreeFacts() & SubtreeContainsDecorators) == 0) {
			return node;
		}

		switch (node.Kind) {
			case KindClassDeclaration:
				return visitClassDeclaration(node.AsClassDeclaration());
			case KindClassExpression:
				return visitClassExpression(node.AsClassExpression());
			case KindPropertyDeclaration:
				return visitPropertyDeclaration(node.AsPropertyDeclaration());
			case KindMethodDeclaration:
				return visitMethodDeclaration(node.AsMethodDeclaration());
			case KindSetAccessor:
				return visitSetAccessor(node.AsSetAccessorDeclaration());
			case KindGetAccessor:
				return visitGetAccessor(node.AsGetAccessorDeclaration());
			case KindSourceFile:
				this.parent = null;
				this.currentLexicalScope = node;
				this.serializer = Tstransforms.newMetadataSerializer(resolver, Factory(), EmitContext(), languageVersion, strictNullChecks);
				final updated = Visitor().VisitEachChild(node);
				EmitContext().AddEmitHelper(updated, ...Core.Coalesce(EmitContext().ReadEmitHelpers(), [])); // PORT: spread of a nil slice is an empty variadic call
				// PORT: defer (in reverse order)
				setCurrentLexicalScope(null);
				setParent(null);
				return updated;
			case KindModuleBlock | KindBlock | KindCaseBlock:
				final oldScope = currentLexicalScope;
				this.currentLexicalScope = node;
				final r = Visitor().VisitEachChild(node);
				setCurrentLexicalScope(oldScope); // PORT: defer
				return r;
			default:
				return Visitor().VisitEachChild(node);
		}
	}

	function setParent(node:Node):Void {
		this.parent = node;
	}

	function setCurrentLexicalScope(node:Node):Void {
		this.currentLexicalScope = node;
	}

	function visitClassExpression(node:ClassExpression):Node {
		final oldParent = parent;
		this.parent = node.AsNode();

		if (!Ast.ClassOrConstructorParameterIsDecorated(legacyDecorators, node.AsNode())) {
			final r = Visitor().VisitEachChild(node.AsNode());
			setParent(oldParent); // PORT: defer
			return r;
		}
		final modifiers = injectClassTypeMetadata(Visitor().VisitModifiers(node.Modifiers()), node.AsNode());
		final r = Factory().UpdateClassExpression(node, modifiers, Visitor().VisitNode(node.Name()), Visitor().VisitNodes(node.TypeParameters),
			Visitor().VisitNodes(node.HeritageClauses), Visitor().VisitNodes(node.Members));
		setParent(oldParent); // PORT: defer
		return r;
	}

	function visitClassDeclaration(node:ClassDeclaration):Node {
		final oldParent = parent;
		this.parent = node.AsNode();

		if (!Ast.ClassOrConstructorParameterIsDecorated(legacyDecorators, node.AsNode())) {
			final r = Visitor().VisitEachChild(node.AsNode());
			setParent(oldParent); // PORT: defer
			return r;
		}
		final modifiers = injectClassTypeMetadata(Visitor().VisitModifiers(node.Modifiers()), node.AsNode());
		final r = Factory().UpdateClassDeclaration(node, modifiers, Visitor().VisitNode(node.Name()), Visitor().VisitNodes(node.TypeParameters),
			Visitor().VisitNodes(node.HeritageClauses), Visitor().VisitNodes(node.Members));
		setParent(oldParent); // PORT: defer
		return r;
	}

	function visitPropertyDeclaration(node:PropertyDeclaration):Node {
		if (!Ast.HasDecorators(node.AsNode())) {
			return Visitor().VisitEachChild(node.AsNode());
		}

		final modifiers = injectClassElementTypeMetadata(Visitor().VisitModifiers(node.Modifiers()), node.AsNode(), parent);
		return Factory().UpdatePropertyDeclaration(node, modifiers, Visitor().VisitNode(node.Name()), Visitor().VisitNode(node.PostfixToken),
			Visitor().VisitNode(node.Type), Visitor().VisitNode(node.Initializer));
	}

	function visitMethodDeclaration(node:MethodDeclaration):Node {
		if (!Ast.HasDecorators(node.AsNode()) && Core.len(Tstransforms.getDecoratorsOfParameters(node.AsNode())) == 0) {
			return Visitor().VisitEachChild(node.AsNode());
		}

		final modifiers = injectClassElementTypeMetadata(Visitor().VisitModifiers(node.Modifiers()), node.AsNode(), parent);
		return Factory().UpdateMethodDeclaration(node, modifiers, Visitor().VisitNode(node.AsteriskToken), Visitor().VisitNode(node.Name()),
			Visitor().VisitNode(node.PostfixToken), Visitor().VisitNodes(node.TypeParameters), Visitor().VisitNodes(node.Parameters),
			Visitor().VisitNode(node.Type), Visitor().VisitNode(node.FullSignature), Visitor().VisitNode(node.Body));
	}

	function visitSetAccessor(node:SetAccessorDeclaration):Node {
		if (!Ast.HasDecorators(node.AsNode()) && Core.len(Tstransforms.getDecoratorsOfParameters(node.AsNode())) == 0) {
			return Visitor().VisitEachChild(node.AsNode());
		}

		final modifiers = injectClassElementTypeMetadata(Visitor().VisitModifiers(node.Modifiers()), node.AsNode(), parent);
		return Factory().UpdateSetAccessorDeclaration(node, modifiers, Visitor().VisitNode(node.Name()), Visitor().VisitNodes(node.TypeParameters),
			Visitor().VisitNodes(node.Parameters), Visitor().VisitNode(node.Type), Visitor().VisitNode(node.FullSignature), Visitor().VisitNode(node.Body));
	}

	function visitGetAccessor(node:GetAccessorDeclaration):Node {
		if (!Ast.HasDecorators(node.AsNode())) {
			return Visitor().VisitEachChild(node.AsNode());
		}

		final modifiers = injectClassElementTypeMetadata(Visitor().VisitModifiers(node.Modifiers()), node.AsNode(), parent);
		return Factory().UpdateGetAccessorDeclaration(node, modifiers, Visitor().VisitNode(node.Name()), Visitor().VisitNodes(node.TypeParameters),
			Visitor().VisitNodes(node.Parameters), Visitor().VisitNode(node.Type), Visitor().VisitNode(node.FullSignature), Visitor().VisitNode(node.Body));
	}

	function injectClassTypeMetadata(list:ModifierList, node:Node):ModifierList {
		final metadata = getTypeMetadata(node, node);
		if (Core.len(metadata) > 0) {
			var originalNodes:Array<Node> = null;
			if (list != null) {
				originalNodes = list.Nodes;
			}
			if (Core.len(originalNodes) == 0) {
				final res = Factory().NewModifierList(metadata);
				if (list != null) {
					res.Loc = list.Loc;
				}
				return res;
			}
			final modifiersArray:Array<Node> = [];
			if (Ast.IsModifier(originalNodes[0]) && (originalNodes[0].Kind == KindDefaultKeyword || originalNodes[0].Kind == KindExportKeyword)) {
				modifiersArray.push(originalNodes[0]);
				if (originalNodes.length > 1 && (originalNodes[1].Kind == KindDefaultKeyword || originalNodes[1].Kind == KindExportKeyword)) {
					modifiersArray.push(originalNodes[1]);
				}
			}
			final restStart = modifiersArray.length;
			final decos = Core.Filter(originalNodes, Ast.IsDecorator);
			if (decos != null) {
				for (d in decos)
					modifiersArray.push(d);
			}
			for (m in metadata)
				modifiersArray.push(m);
			final otherModifiers = Core.Filter(originalNodes.slice(restStart), Ast.IsModifier);
			if (otherModifiers != null) {
				for (m in otherModifiers)
					modifiersArray.push(m);
			}
			final res = Factory().NewModifierList(modifiersArray);
			res.Loc = list.Loc;
			return res;
		}
		return list;
	}

	function injectClassElementTypeMetadata(list:ModifierList, node:Node, container:Node):ModifierList {
		if (!Ast.IsClassLike(container)) {
			return list;
		}
		if (!Ast.ClassElementOrClassElementParameterIsDecorated(legacyDecorators, node, container)) {
			return list;
		}
		final metadata = getTypeMetadata(node, container);
		if (Core.len(metadata) > 0) {
			var originalNodes:Array<Node> = null;
			if (list != null) {
				originalNodes = list.Nodes;
			}
			if (Core.len(originalNodes) == 0) {
				final res = Factory().NewModifierList(metadata);
				if (list != null) {
					res.Loc = list.Loc;
				}
				return res;
			}
			final modifiersArray:Array<Node> = [];
			final decos = Core.Filter(originalNodes, Ast.IsDecorator);
			if (decos != null) {
				for (d in decos)
					modifiersArray.push(d);
			}
			for (m in metadata)
				modifiersArray.push(m);
			final modifiers = Core.Filter(originalNodes, Ast.IsModifier);
			if (modifiers != null) {
				for (m in modifiers)
					modifiersArray.push(m);
			}
			final res = Factory().NewModifierList(modifiersArray);
			res.Loc = list.Loc;
			return res;
		}
		return list;
	}

	/**
	 * Gets optional type metadata for a declaration.
	 *
	 * @param node The declaration node.
	 */
	function getTypeMetadata(node:Node, container:Node):Array<Node> {
		// Decorator metadata is not yet supported for ES decorators.
		if (!legacyDecorators) {
			return null;
		}
		if (Tstransforms.USE_NEW_TYPE_METADATA_FORMAT) {
			return getNewTypeMetadata(node, container);
		}
		return getOldTypeMetadata(node, container);
	}

	function getOldTypeMetadata(node:Node, container:Node):Array<Node> {
		var decorators:Array<Node> = null;
		if (shouldAddTypeMetadata(node)) {
			final typeMetadata = Factory().NewMetadataHelper("design:type",
				serializer.SerializeTypeOfNode(new MetadataSerializerContext(currentLexicalScope, container), node, container));
			if (decorators == null)
				decorators = [];
			decorators.push(Factory().NewDecorator(typeMetadata));
		}
		if (shouldAddParamTypesMetadata(node)) {
			final paramTypesMetadata = Factory().NewMetadataHelper("design:paramtypes",
				serializer.SerializeParameterTypesOfNode(new MetadataSerializerContext(currentLexicalScope, container), node, container));
			if (decorators == null)
				decorators = [];
			decorators.push(Factory().NewDecorator(paramTypesMetadata));
		}
		if (shouldAddReturnTypeMetadata(node)) {
			final returnTypeMetadata = Factory().NewMetadataHelper("design:returntype",
				serializer.SerializeReturnTypeOfNode(new MetadataSerializerContext(currentLexicalScope, container), node));
			if (decorators == null)
				decorators = [];
			decorators.push(Factory().NewDecorator(returnTypeMetadata));
		}
		return decorators;
	}

	function getNewTypeMetadata(node:Node, container:Node):Array<Node> {
		var properties:Array<Node> = null;
		if (shouldAddTypeMetadata(node)) {
			if (properties == null)
				properties = [];
			properties.push(Factory().NewPropertyAssignment(null, Factory().NewIdentifier("type"), null, null,
				Factory().NewArrowFunction(null, null, Factory().NewNodeList([]), null, null, Factory().NewToken(KindEqualsGreaterThanToken),
					serializer.SerializeTypeOfNode(new MetadataSerializerContext(currentLexicalScope, container), node, container))));
		}
		if (shouldAddParamTypesMetadata(node)) {
			if (properties == null)
				properties = [];
			properties.push(Factory().NewPropertyAssignment(null, Factory().NewIdentifier("paramTypes"), null, null,
				Factory().NewArrowFunction(null, null, Factory().NewNodeList([]), null, null, Factory().NewToken(KindEqualsGreaterThanToken),
					serializer.SerializeParameterTypesOfNode(new MetadataSerializerContext(currentLexicalScope, container), node, container))));
		}
		if (shouldAddReturnTypeMetadata(node)) {
			if (properties == null)
				properties = [];
			properties.push(Factory().NewPropertyAssignment(null, Factory().NewIdentifier("returnType"), null, null,
				Factory().NewArrowFunction(null, null, Factory().NewNodeList([]), null, null, Factory().NewToken(KindEqualsGreaterThanToken),
					serializer.SerializeReturnTypeOfNode(new MetadataSerializerContext(currentLexicalScope, container), node))));
		}
		if (Core.len(properties) > 0) {
			final typeInfoMetadata = Factory().NewMetadataHelper("design:typeinfo", Factory().NewObjectLiteralExpression(Factory().NewNodeList(properties), true));
			return [Factory().NewDecorator(typeInfoMetadata)];
		}
		return null;
	}

	/**
	* Determines whether to emit the "design:type" metadata based on the node's kind.
	* The caller should have already tested whether the node has decorators and whether the
	* emitDecoratorMetadata compiler option is set.
	*
	* @param node The node to test.
	 */
	function shouldAddTypeMetadata(node:Node):Bool {
		switch (node.Kind) {
			case KindMethodDeclaration | KindGetAccessor | KindSetAccessor | KindPropertyDeclaration:
				return true;
			default:
		}
		return false;
	}

	/**
	* Determines whether to emit the "design:returntype" metadata based on the node's kind.
	* The caller should have already tested whether the node has decorators and whether the
	* emitDecoratorMetadata compiler option is set.
	*
	* @param node The node to test.
	 */
	function shouldAddReturnTypeMetadata(node:Node):Bool {
		return node.Kind == KindMethodDeclaration;
	}

	/**
	* Determines whether to emit the "design:paramtypes" metadata based on the node's kind.
	* The caller should have already tested whether the node has decorators and whether the
	* emitDecoratorMetadata compiler option is set.
	*
	* @param node The node to test.
	 */
	function shouldAddParamTypesMetadata(node:Node):Bool {
		switch (node.Kind) {
			case KindClassDeclaration | KindClassExpression:
				return Ast.GetFirstConstructorWithBody(node) != null;
			case KindMethodDeclaration | KindGetAccessor | KindSetAccessor:
				return true;
			default:
		}
		return false;
	}
}
