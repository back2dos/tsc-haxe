package ts.transformers.jsxtransforms;

// Port of internal/transformers/jsxtransforms/jsx.go (upstream v7.0.2).

@:allow(ts.transformers.jsxtransforms)
class JSXTransformer {
	// PORT: Go `range` over a possibly-nil slice (parser lists of zero elements have nil Nodes).
	static inline function rangeOf<T>(a:Null<Array<T>>):Array<T> {
		return a == null ? [] : a;
	}

	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var compilerOptions:CompilerOptions = null;
	var emitResolver:EmitResolver = null;
	var importSpecifier:std.String = "";
	var filenameDeclaration:Node = null;
	var utilizedImplicitRuntimeImports:OrderedMap<std.String, StringMap<Node>> = new OrderedMap<std.String, StringMap<Node>>(null);
	var inJsxChild:Bool = false;
	var currentSourceFile:SourceFile = null;

	public function new() {}

	// PORT: promoted methods of embedded transformers.Transformer
	inline function NewTransformer(visit:(node:Node) -> Node, emitContext:ts.printer.Emitcontext.EmitContext):ts.transformers.Transformer {
		return Transformer.NewTransformer(visit, emitContext);
	}

	inline function EmitContext():ts.printer.Emitcontext.EmitContext {
		return Transformer.EmitContext();
	}

	inline function Factory():ts.printer.Factory.NodeFactory {
		return Transformer.Factory();
	}

	inline function Visitor():NodeVisitor {
		return Transformer.Visitor();
	}

	function getCurrentFileNameExpression():Node {
		if (filenameDeclaration != null) {
			return filenameDeclaration.AsVariableDeclaration().Name();
		}
		final d = Factory().NewVariableDeclaration(Factory().NewUniqueNameEx("_jsxFileName",
			new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel)),
			null, null, Factory().NewStringLiteral(currentSourceFile.FileName(), TokenFlagsNone));
		filenameDeclaration = d;
		return d.AsVariableDeclaration().Name();
	}

	function getJsxFactoryCalleePrimitive(isStaticChildren:Bool):std.String {
		if (compilerOptions.Jsx == JsxEmitReactJSXDev) {
			return "jsxDEV";
		}
		if (isStaticChildren) {
			return "jsxs";
		}
		return "jsx";
	}

	function getJsxFactoryCallee(isStaticChildren:Bool):Node {
		final t = getJsxFactoryCalleePrimitive(isStaticChildren);
		return getImplicitImportForName(t);
	}

	function getImplicitJsxFragmentReference():Node {
		return getImplicitImportForName("Fragment");
	}

	function getImplicitImportForName(name:std.String):Node {
		var importSource = importSpecifier;
		if (name != "createElement") {
			importSource = Ast.GetJSXRuntimeImport(importSource, compilerOptions);
		}
		final got = utilizedImplicitRuntimeImports.Get(importSource);
		var existing = got.value;
		if (got.ok) {
			if (existing.exists(name)) {
				final elem = existing.get(name);
				return elem.AsImportSpecifier().Name();
			}
		} else {
			existing = new StringMap<Node>();
			utilizedImplicitRuntimeImports.Set(importSource, existing);
		}

		final generatedName = Factory().NewUniqueNameEx("_" + name,
			new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel | GeneratedIdentifierFlagsAllowNameSubstitution));
		final specifier = Factory().NewImportSpecifier(false, Factory().NewIdentifier(name), generatedName);
		emitResolver.SetReferencedImportDeclaration(generatedName, specifier);
		existing.set(name, specifier);
		return specifier.Name();
	}

	function setInChild(v:Bool):Void {
		inJsxChild = v;
	}

	function visit(node:Node):Node {
		if (node == null) {
			return null;
		}
		if ((node.SubtreeFacts() & SubtreeContainsJsx) == 0) {
			return node;
		}
		switch (node.Kind) {
			case KindSourceFile:
				setInChild(false);
				return visitSourceFile(node.AsSourceFile());
			case KindJsxElement:
				return visitJsxElement(node.AsJsxElement());
			case KindJsxSelfClosingElement:
				return visitJsxSelfClosingElement(node.AsJsxSelfClosingElement());
			case KindJsxFragment:
				return visitJsxFragment(node.AsJsxFragment());
			case KindJsxOpeningElement:
				throw "JsxOpeningElement should not be visited, handled in visitJsxElement";
			case KindJsxOpeningFragment:
				throw "JsxOpeningFragment should not be visited, handled in visitJsxFragment";
			case KindJsxText:
				setInChild(false);
				return visitJsxText(node.AsJsxText());
			case KindJsxExpression:
				setInChild(false);
				return visitJsxExpression(node.AsJsxExpression());
			default:
		}
		setInChild(false);
		return Visitor().VisitEachChild(node); // by default, do nothing
	}

	function shouldUseCreateElement(node:Node):Bool {
		return importSpecifier.length == 0 || Jsxtransforms.hasKeyAfterPropsSpread(node);
	}

	function isAnyPrologueDirective(node:Node):Bool {
		return Ast.IsPrologueDirective(node) || ((EmitContext().EmitFlags(node) & EFCustomPrologue) != 0);
	}

	// PORT: Go method expression `(*JSXTransformer).isAnyPrologueDirective`.
	static final isAnyPrologueDirectiveFn:(callee:JSXTransformer, node:Node) -> Bool = (callee, node) -> callee.isAnyPrologueDirective(node);

	function insertStatementAfterCustomPrologue(to:Array<Node>, statement:Node):Array<Node> {
		return Jsxtransforms.insertStatementAfterPrologue(to, statement, isAnyPrologueDirectiveFn, this);
	}

	function visitSourceFile(file:SourceFile):Node {
		if (file.IsDeclarationFile) {
			return file.AsNode();
		}

		currentSourceFile = file;
		importSpecifier = Ast.GetJSXImplicitImportBase(compilerOptions, file);
		filenameDeclaration = null;
		utilizedImplicitRuntimeImports.Clear();

		var visited = Visitor().VisitEachChild(file.AsNode());
		// PORT: spread of a nil slice is an empty variadic call (it still creates the emit node).
		final helpers = EmitContext().ReadEmitHelpers();
		if (helpers == null) {
			EmitContext().AddEmitHelper(visited.AsNode());
		} else {
			EmitContext().AddEmitHelper(visited.AsNode(), ...helpers);
		}
		var statements = visited.Statements();
		var statementsUpdated = false;
		if (filenameDeclaration != null) {
			statements = insertStatementAfterCustomPrologue(statements, Factory().NewVariableStatement(null, Factory().NewVariableDeclarationList(
				Factory().NewNodeList([filenameDeclaration]),
				NodeFlagsConst
			)));
			statementsUpdated = true;
		}

		if (utilizedImplicitRuntimeImports.Size() > 0) {
			if (Ast.IsExternalModule(file)) {
				statementsUpdated = true;
				final newStatements:Array<Node> = [];
				for (entry in utilizedImplicitRuntimeImports.Entries()) {
					final importSource = entry.key;
					final importSpecifiersMap = entry.value;
					final s = Factory().NewImportDeclaration(
						null,
						Factory().NewImportClause(KindUnknown, null, Factory().NewNamedImports(Factory().NewNodeList(Jsxtransforms.getSortedSpecifiers(importSpecifiersMap)))),
						Factory().NewStringLiteral(importSource, TokenFlagsNone),
						null
					);
					Ast.SetParentInChildren(s);
					newStatements.push(s);
				}
				for (e in newStatements) {
					statements = insertStatementAfterCustomPrologue(statements, e);
				}
			} else if (Ast.IsExternalOrCommonJSModule(file)) {
				statementsUpdated = true;
				final newStatements:Array<Node> = [];
				for (entry in utilizedImplicitRuntimeImports.Entries()) {
					final importSource = entry.key;
					final importSpecifiersMap = entry.value;
					final sorted = Jsxtransforms.getSortedSpecifiers(importSpecifiersMap);
					final asBindingElems:Array<Node> = [];
					if (sorted != null) {
						for (elem in sorted) {
							asBindingElems.push(Factory().NewBindingElement(null, elem.PropertyName(), elem.AsImportSpecifier().Name(), null));
						}
					}
					final s = Factory().NewVariableStatement(null, Factory().NewVariableDeclarationList(Factory().NewNodeList([Factory().NewVariableDeclaration(
						Factory().NewBindingPattern(KindObjectBindingPattern, Factory().NewNodeList(asBindingElems)),
						null,
						null,
						Factory().NewCallExpression(
							Factory().NewIdentifier("require"),
							null,
							null,
							Factory().NewNodeList([Factory().NewStringLiteral(importSource, TokenFlagsNone)]), NodeFlagsNone
						)
					)]), NodeFlagsConst));
					Ast.SetParentInChildren(s);
					newStatements.push(s);
				}
				for (e in newStatements) {
					statements = insertStatementAfterCustomPrologue(statements, e);
				}
			} else {
				// Do nothing (script file) - consider an error in the checker?
			}
		}

		if (statementsUpdated) {
			visited = Factory().UpdateSourceFile(file, Factory().NewNodeList(statements), file.EndOfFileToken);
		}

		currentSourceFile = null;
		importSpecifier = "";
		filenameDeclaration = null;
		utilizedImplicitRuntimeImports.Clear();

		return visited;
	}

	function visitJsxElement(element:JsxElement):Node {
		final location = Core.NewTextRange(Scanner.SkipTrivia(currentSourceFile.Text(), element.Pos()), element.End());
		// PORT: Go selects a method expression `tagTransform`; called directly.
		if (shouldUseCreateElement(element.AsNode())) {
			return visitJsxOpeningLikeElementCreateElement(element.OpeningElement, element.Children, location);
		}
		return visitJsxOpeningLikeElementJSX(element.OpeningElement, element.Children, location);
	}

	function visitJsxSelfClosingElement(element:JsxSelfClosingElement):Node {
		final location = Core.NewTextRange(Scanner.SkipTrivia(currentSourceFile.Text(), element.Pos()), element.End());
		// PORT: Go selects a method expression `tagTransform`; called directly.
		if (shouldUseCreateElement(element.AsNode())) {
			return visitJsxOpeningLikeElementCreateElement(element.AsNode(), null, location);
		}
		return visitJsxOpeningLikeElementJSX(element.AsNode(), null, location);
	}

	function visitJsxFragment(fragment:JsxFragment):Node {
		final location = Core.NewTextRange(Scanner.SkipTrivia(currentSourceFile.Text(), fragment.Pos()), fragment.End());
		// PORT: Go selects a method expression `tagTransform`; called directly.
		if (importSpecifier.length == 0) {
			return visitJsxOpeningFragmentCreateElement(fragment.OpeningFragment.AsJsxOpeningFragment(), fragment.Children, location);
		}
		return visitJsxOpeningFragmentJSX(fragment.OpeningFragment.AsJsxOpeningFragment(), fragment.Children, location);
	}

	function convertJsxChildrenToChildrenPropObject(children:Array<JsxChild>):Node {
		final prop = convertJsxChildrenToChildrenPropAssignment(children);
		if (prop == null) {
			return null;
		}
		return Factory().NewObjectLiteralExpression(Factory().NewNodeList([prop]), false);
	}

	function transformJsxChildToExpression(node:Node):Node {
		final prev = inJsxChild;
		setInChild(true);
		final result = Visitor().Visit(node);
		setInChild(prev); // PORT: defer
		return result;
	}

	function convertJsxChildrenToChildrenPropAssignment(children:Array<JsxChild>):Node {
		final nonWhitespceChildren = Ast.GetSemanticJsxChildren(children);
		if (Core.len(nonWhitespceChildren) == 1 && (nonWhitespceChildren[0].Kind != KindJsxExpression || nonWhitespceChildren[0].AsJsxExpression().DotDotDotToken == null)) {
			final result = transformJsxChildToExpression(nonWhitespceChildren[0]);
			if (result == null) {
				return null;
			}
			return Factory().NewPropertyAssignment(null, Factory().NewIdentifier("children"), null, null, result);
		}
		// For multiple children in the children property array, don't set StartOnNewLine
		// on child elements — the array literal is single-line.
		final results:Array<Node> = [];
		if (nonWhitespceChildren != null) {
			for (child in nonWhitespceChildren) {
				final res = transformJsxChildToExpression(child);
				if (res == null) {
					continue;
				}
				EmitContext().SetEmitFlags(res, EmitContext().EmitFlags(res) & ~EFStartOnNewLine);
				results.push(res);
			}
		}
		if (results.length == 0) {
			return null;
		}
		return Factory().NewPropertyAssignment(null, Factory().NewIdentifier("children"), null, null, Factory().NewArrayLiteralExpression(Factory().NewNodeList(results), false));
	}

	function getTagName(node:Node):Node {
		if (node.Kind == KindJsxElement) {
			return getTagName(node.AsJsxElement().OpeningElement);
		} else if (Ast.IsJsxOpeningLikeElement(node)) {
			final tagName = node.TagName();
			if (Ast.IsIdentifier(tagName) && Scanner.IsIntrinsicJsxName(tagName.Text())) {
				return Factory().NewStringLiteral(tagName.Text(), TokenFlagsNone);
			} else if (Ast.IsJsxNamespacedName(tagName)) {
				return Factory().NewStringLiteral(
					tagName.AsJsxNamespacedName().Namespace.Text() + ":" + tagName.AsJsxNamespacedName().Name().Text(), TokenFlagsNone
				);
			} else {
				return Factory().CreateExpressionFromEntityName(tagName);
			}
		} else {
			throw "unhandled node kind passed to getTagName: " + node.Kind.String();
		}
	}

	function visitJsxOpeningLikeElementJSX(element:Node, children:NodeList, location:TextRange):Node {
		final tagName = getTagName(element);
		var childrenProp:Node = null;
		if (children != null && Core.len(children.Nodes) > 0) {
			childrenProp = convertJsxChildrenToChildrenPropAssignment(children.Nodes);
		}
		var keyAttr:Node = null;
		var attrs = element.Attributes().Properties();
		for (i in 0...Core.len(attrs)) {
			final p = attrs[i];
			if (p.Kind == KindJsxAttribute && p.AsJsxAttribute().Name() != null && Ast.IsIdentifier(p.AsJsxAttribute().Name()) && p.AsJsxAttribute().Name().Text() == "key") {
				keyAttr = p;
				attrs = Slices.Clone(attrs);
				attrs.splice(i, 1);
				break; // Go `break` of the range loop
			}
		}
		var object:Node = null;
		if (Core.len(attrs) > 0) {
			object = transformJsxAttributesToObjectProps(attrs, childrenProp);
		} else {
			final objectChildren:Array<Node> = [];
			if (childrenProp != null) {
				objectChildren.push(childrenProp);
			}
			object = Factory().NewObjectLiteralExpression(Factory().NewNodeList(objectChildren), false); // When there are no attributes, React wants {}
		}
		return visitJsxOpeningLikeElementOrFragmentJSX(
			tagName,
			object,
			keyAttr,
			children,
			location
		);
	}

	function transformJsxAttributesToObjectProps(attrs:Array<Node>, childrenProp:Node):Node {
		final target = compilerOptions.GetEmitScriptTarget();
		if ((target : Int) >= (ScriptTargetES2018 : Int)) {
			// target has object spreads, can keep as-is
			return Factory().NewObjectLiteralExpression(Factory().NewNodeList(transformJsxAttributesToProps(attrs, childrenProp)), false);
		}
		return transformJsxAttributesToExpression(attrs, childrenProp);
	}

	// PORT: Go `append` to a possibly-nil slice.
	static inline function append(s:Array<Node>, x:Node):Array<Node> {
		if (s == null) {
			return [x];
		}
		s.push(x);
		return s;
	}

	function transformJsxAttributesToExpression(attrs:Array<Node>, childrenProp:Node):Node {
		var expressions:Array<Expression> = [];
		var properties:Array<ObjectLiteralElement> = [];

		for (attr in rangeOf(attrs)) {
			if (Ast.IsJsxSpreadAttribute(attr)) {
				// as an optimization we try to flatten the first level of spread inline object
				// as if its props would be passed as JSX attributes
				if (Ast.IsObjectLiteralExpression(attr.Expression()) && !Jsxtransforms.hasProto(attr.Expression().AsObjectLiteralExpression())) {
					for (prop in rangeOf(attr.Expression().Properties())) {
						if (Ast.IsSpreadAssignment(prop)) {
							final r = combinePropertiesIntoNewExpression(expressions, properties);
							expressions = r.a;
							properties = r.b;
							expressions = append(expressions, Visitor().Visit(prop.Expression()));
							continue;
						}
						properties = append(properties, Visitor().Visit(prop));
					}
					continue;
				}
				final r = combinePropertiesIntoNewExpression(expressions, properties);
				expressions = r.a;
				properties = r.b;
				expressions = append(expressions, Visitor().Visit(attr.Expression()));
				continue;
			}
			properties = append(properties, transformJsxAttributeToObjectLiteralElement(attr.AsJsxAttribute()));
		}

		if (childrenProp != null) {
			properties = append(properties, childrenProp);
		}

		expressions = combinePropertiesIntoNewExpression(expressions, properties).a;

		if (expressions.length > 0 && !Ast.IsObjectLiteralExpression(expressions[0])) {
			// We must always emit at least one object literal before a spread attribute
			// as the JSX always factory expects a fresh object, so we need to make a copy here
			// we also avoid mutating an external reference by doing this (first expression is used as assign's target)
			expressions = [Factory().NewObjectLiteralExpression(Factory().NewNodeList([]), false)].concat(expressions);
		}

		if (expressions.length == 1) {
			return expressions[0];
		}
		return Factory().NewAssignHelper(expressions, compilerOptions.GetEmitScriptTarget());
	}

	function combinePropertiesIntoNewExpression(expressions:Array<Expression>, props:Array<ObjectLiteralElement>):Pair<Array<Expression>, Array<ObjectLiteralElement>> {
		if (Core.len(props) == 0) {
			return new Pair(expressions, props);
		}
		final newObj = Factory().NewObjectLiteralExpression(Factory().NewNodeList(props), false);
		expressions = append(expressions, newObj);
		return new Pair(expressions, null);
	}

	function transformJsxAttributesToProps(attrs:Array<Node>, childrenProp:Node):Array<Node> {
		final props:Array<Node> = [];
		for (attr in rangeOf(attrs)) {
			if (attr.Kind == KindJsxSpreadAttribute) {
				final res = transformJsxSpreadAttributesToProps(attr.AsJsxSpreadAttribute());
				if (res != null) {
					for (r in res) {
						props.push(r);
					}
				}
			} else {
				props.push(transformJsxAttributeToObjectLiteralElement(attr.AsJsxAttribute()));
			}
		}
		if (childrenProp != null) {
			props.push(childrenProp);
		}
		return props;
	}

	function transformJsxSpreadAttributesToProps(node:JsxSpreadAttribute):Array<Node> {
		if (Ast.IsObjectLiteralExpression(node.Expression) && !Jsxtransforms.hasProto(node.Expression.AsObjectLiteralExpression())) {
			final res = Visitor().VisitSlice(node.Expression.Properties()).a;
			return res;
		}
		return [Factory().NewSpreadAssignment(Visitor().Visit(node.Expression))];
	}

	function transformJsxAttributeToObjectLiteralElement(node:JsxAttribute):Node {
		final name = getAttributeName(node);
		final expression = transformJsxAttributeInitializer(node.Initializer);
		return Factory().NewPropertyAssignment(null, name, null, null, expression);
	}

	/**
	* Emit an attribute name, which is quoted if it needs to be quoted. Because
	* these emit into an object literal property name, we don't need to be worried
	* about keywords, just non-identifier characters
	 */
	function getAttributeName(node:JsxAttribute):Node {
		final name = node.Name();
		if (Ast.IsIdentifier(name)) {
			final text = name.Text();
			if (Scanner.IsIdentifierText(text, LanguageVariantStandard)) {
				return name;
			}
			return Factory().NewStringLiteral(text, TokenFlagsNone);
		}
		// must be jsx namespace
		return Factory().NewStringLiteral(
			name.AsJsxNamespacedName().Namespace.Text() + ":" + name.AsJsxNamespacedName().Name().Text(), TokenFlagsNone
		);
	}

	function transformJsxAttributeInitializer(node:Node):Node {
		if (node == null) {
			return Factory().NewTrueExpression();
		}
		if (node.Kind == KindStringLiteral) {
			// Always recreate the literal to escape any escape sequences or newlines which may be in the original jsx string and which
			// Need to be escaped to be handled correctly in a normal string
			final res = Factory().NewStringLiteral(Jsxtransforms.decodeEntities(node.Text()), node.AsStringLiteral().TokenFlags);
			res.Loc = node.Loc;
			// Preserve the original quote style (single vs double quotes)
			res.AsStringLiteral().TokenFlags = node.AsStringLiteral().TokenFlags;
			return res;
		}
		if (node.Kind == KindJsxExpression) {
			if (node.Expression() == null) {
				return Factory().NewTrueExpression();
			}
			return Visitor().Visit(node.Expression());
		}
		if (Ast.IsJsxElement(node) || Ast.IsJsxSelfClosingElement(node) || Ast.IsJsxFragment(node)) {
			setInChild(false);
			return Visitor().Visit(node);
		}
		throw "Unhandled node kind found in jsx initializer: " + node.Kind.String();
	}

	function visitJsxOpeningLikeElementOrFragmentJSX(tagName:Expression, object:Expression, keyAttr:Node, children:NodeList, location:TextRange):Node {
		var nonWhitespaceChildren:Array<Node> = null;
		if (children != null) {
			nonWhitespaceChildren = Ast.GetSemanticJsxChildren(children.Nodes);
		}
		final isStaticChildren = Core.len(nonWhitespaceChildren) > 1
			|| (Core.len(nonWhitespaceChildren) == 1 && Ast.IsJsxExpression(nonWhitespaceChildren[0]) && nonWhitespaceChildren[0].AsJsxExpression().DotDotDotToken != null);
		final args:Array<Node> = [];
		args.push(tagName);
		args.push(object);
		// function jsx(type, config, maybeKey) {}
		// "maybeKey" is optional. It is acceptable to use "_jsx" without a third argument
		if (keyAttr != null) {
			args.push(transformJsxAttributeInitializer(keyAttr.Initializer()));
		}

		if (compilerOptions.Jsx == JsxEmitReactJSXDev) {
			final originalFile = EmitContext().MostOriginal(currentSourceFile.AsNode());
			if (originalFile != null && Ast.IsSourceFile(originalFile)) {
				// "maybeKey" has to be replaced with "void 0" to not break the jsxDEV signature
				if (keyAttr == null) {
					args.push(Factory().NewVoidZeroExpression());
				}
				// isStaticChildren development flag
				if (isStaticChildren) {
					args.push(Factory().NewTrueExpression());
				} else {
					args.push(Factory().NewFalseExpression());
				}
				// __source development flag
				final lc = Scanner.GetECMALineAndUTF16CharacterOfPosition(originalFile.AsSourceFile(), location.Pos());
				final line = lc.a;
				final col = lc.b;
				args.push(Factory().NewObjectLiteralExpression(Factory().NewNodeList([
					Factory().NewPropertyAssignment(null, Factory().NewIdentifier("fileName"), null, null, getCurrentFileNameExpression()),
					Factory().NewPropertyAssignment(null, Factory().NewIdentifier("lineNumber"), null, null, Factory().NewNumericLiteral(Std.string(line + 1), TokenFlagsNone)),
					Factory().NewPropertyAssignment(null, Factory().NewIdentifier("columnNumber"), null, null, Factory().NewNumericLiteral(Std.string(col + 1), TokenFlagsNone)),
				]), false));
				// __self development flag
				args.push(Factory().NewThisExpression());
			}
		}

		final element = Factory().NewCallExpression(getJsxFactoryCallee(isStaticChildren), null, null, Factory().NewNodeList(args), NodeFlagsNone);
		element.Loc = location;

		if (inJsxChild) {
			EmitContext().AddEmitFlags(element, EFStartOnNewLine);
		}

		return element;
	}

	function visitJsxOpeningFragmentJSX(fragment:JsxOpeningFragment, children:NodeList, location:TextRange):Node {
		var childrenProps:Expression = null;
		if (children != null && Core.len(children.Nodes) > 0) {
			final result = convertJsxChildrenToChildrenPropObject(children.Nodes);
			if (result != null) {
				childrenProps = result;
			}
		}
		if (childrenProps == null) {
			childrenProps = Factory().NewObjectLiteralExpression(Factory().NewNodeList([]), false);
		}
		return visitJsxOpeningLikeElementOrFragmentJSX(
			getImplicitJsxFragmentReference(),
			childrenProps,
			null,
			children,
			location
		);
	}

	function createReactNamespace(reactNamespace:std.String, parent:Node):Node {
		// To ensure the emit resolver can properly resolve the namespace, we need to
		// treat this identifier as if it were a source tree node by clearing the `Synthesized`
		// flag and setting a parent node. TODO: Is this still true? The emit resolver is supposed to be
		// hardened aginast this, so long as the node retains original node pointers back to a parsed node
		if (reactNamespace.length == 0) {
			reactNamespace = "React";
		}
		final react = Factory().NewIdentifier(reactNamespace);
		react.Flags &= ~NodeFlagsSynthesized;

		// Set the parent that is in parse tree
		// this makes sure that parent chain is intact for checker to traverse complete scope tree
		react.Parent = EmitContext().ParseNode(parent);

		// If the identifier refers to an exported member of a namespace, substitute with
		// a qualified namespace property access (e.g., `React` -> `M.React`).
		// See also: RuntimeSyntaxTransformer.visitExpressionIdentifier in runtimesyntax.go
		final container = emitResolver.GetReferencedExportContainer(react, false /*prefixLocals*/);
		if (container != null && Ast.IsModuleDeclaration(container)) {
			final containerName = Factory().NewGeneratedNameForNode(container);
			return Factory().NewPropertyAccessExpression(containerName, null, react, NodeFlagsNone);
		}

		return react;
	}

	function createJsxFactoryExpressionFromEntityName(e:Node, parent:Node):Node {
		if (Ast.IsQualifiedName(e)) {
			final left = createJsxFactoryExpressionFromEntityName(e.AsQualifiedName().Left, parent);
			final right = Factory().NewIdentifier(e.AsQualifiedName().Right.Text());
			return Factory().NewPropertyAccessExpression(left, null, right, NodeFlagsNone);
		}
		return createReactNamespace(e.Text(), parent);
	}

	function createJsxPseudoFactoryExpression(parent:Node, e:Node, target:std.String):Node {
		if (e != null) {
			return createJsxFactoryExpressionFromEntityName(e, parent);
		}
		return Factory().NewPropertyAccessExpression(
			createReactNamespace(compilerOptions.ReactNamespace, parent),
			null,
			Factory().NewIdentifier(target),
			NodeFlagsNone
		);
	}

	function createJsxFactoryExpression(parent:Node):Node {
		final e = emitResolver.GetJsxFactoryEntity(currentSourceFile.AsNode());
		return createJsxPseudoFactoryExpression(parent, e, "createElement");
	}

	function createJsxFragmentFactoryExpression(parent:Node):Node {
		final e = emitResolver.GetJsxFragmentFactoryEntity(currentSourceFile.AsNode());
		return createJsxPseudoFactoryExpression(parent, e, "Fragment");
	}

	function visitJsxOpeningLikeElementCreateElement(element:Node, children:NodeList, location:TextRange):Node {
		final tagName = getTagName(element);
		final attrs = element.Attributes().Properties();
		var objectProperties:Expression = null;
		if (Core.len(attrs) > 0) {
			objectProperties = transformJsxAttributesToObjectProps(attrs, null);
		} else {
			objectProperties = Factory().NewKeywordExpression(KindNullKeyword); // When there are no attributes, React wants "null"
		}

		var callee:Expression = null;
		if (importSpecifier.length == 0) {
			callee = createJsxFactoryExpression(element);
		} else {
			callee = getImplicitImportForName("createElement");
		}

		var newChildren:Array<Node> = null;
		if (children != null && Core.len(children.Nodes) > 0) {
			for (c in rangeOf(children.Nodes)) {
				final res = transformJsxChildToExpression(c);
				if (res != null) {
					newChildren = append(newChildren, res);
				}
			}
		}

		// Add StartOnNewLine flag only if there are multiple actual children (after filtering)
		if (Core.len(newChildren) > 1) {
			for (child in newChildren) {
				EmitContext().AddEmitFlags(child, EFStartOnNewLine);
			}
		}

		final args:Array<Expression> = [];
		args.push(tagName);
		args.push(objectProperties);
		if (newChildren != null) {
			for (c in newChildren) {
				args.push(c);
			}
		}

		final result = Factory().NewCallExpression(
			callee,
			null,
			null,
			Factory().NewNodeList(args),
			NodeFlagsNone
		);
		result.Loc = location;

		if (inJsxChild) {
			EmitContext().AddEmitFlags(result, EFStartOnNewLine);
		}
		return result;
	}

	function visitJsxOpeningFragmentCreateElement(fragment:JsxOpeningFragment, children:NodeList, location:TextRange):Node {
		final tagName = createJsxFragmentFactoryExpression(fragment.AsNode());
		final callee = createJsxFactoryExpression(fragment.AsNode());

		var newChildren:Array<Node> = null;
		if (children != null && Core.len(children.Nodes) > 0) {
			for (c in rangeOf(children.Nodes)) {
				final res = transformJsxChildToExpression(c);
				if (res != null) {
					newChildren = append(newChildren, res);
				}
			}
		}

		// Add StartOnNewLine flag only if there are multiple actual children (after filtering)
		if (Core.len(newChildren) > 1) {
			for (child in newChildren) {
				EmitContext().AddEmitFlags(child, EFStartOnNewLine);
			}
		}

		final args:Array<Expression> = [];
		args.push(tagName);
		args.push(Factory().NewKeywordExpression(KindNullKeyword));
		if (newChildren != null) {
			for (c in newChildren) {
				args.push(c);
			}
		}

		final result = Factory().NewCallExpression(
			callee,
			null,
			null,
			Factory().NewNodeList(args),
			NodeFlagsNone
		);
		result.Loc = location;

		if (inJsxChild) {
			EmitContext().AddEmitFlags(result, EFStartOnNewLine);
		}
		return result;
	}

	function visitJsxText(text:JsxText):Node {
		final fixed = Jsxtransforms.fixupWhitespaceAndDecodeEntities(text.Text);
		if (fixed.length == 0) {
			return null;
		}
		return Factory().NewStringLiteral(fixed, TokenFlagsNone);
	}

	function visitJsxExpression(expression:JsxExpression):Node {
		final e = Visitor().Visit(expression.Expression);
		if (expression.DotDotDotToken != null) {
			return Factory().NewSpreadElement(e);
		}
		return e;
	}
}
