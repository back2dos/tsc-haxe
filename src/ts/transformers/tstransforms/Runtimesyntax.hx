package ts.transformers.tstransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/tstransforms/runtimesyntax.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).
// !!! SourceMaps and Comments need to be validated

// Transforms TypeScript-specific runtime syntax into JavaScript-compatible syntax.
@:allow(ts.transformers.tstransforms)
class RuntimeSyntaxTransformer {
	// PORT: Go `range` over a possibly-nil slice (parser lists of zero elements have nil Nodes).
	static inline function rangeOf<T>(a:Null<Array<T>>):Array<T> {
		return a == null ? [] : a;
	}

	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var compilerOptions:CompilerOptions = null;
	var parentNode:Node = null;
	var currentNode:Node = null;
	var currentSourceFile:Node = null;
	var currentScope:Node = null; // SourceFile | Block | ModuleBlock | CaseBlock
	var currentScopeFirstDeclarationsOfName:StringMap<Node> = null;
	var currentEnum:EnumDeclarationNode = null;
	var currentNamespace:ModuleDeclarationNode = null;
	var resolver:ReferenceResolver = null;
	var emitResolver:EmitResolver = null;

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

	function pushScope(node:Node):Pair<Node, StringMap<Node>> {
		final savedCurrentScope = currentScope;
		final savedCurrentScopeFirstDeclarationsOfName = currentScopeFirstDeclarationsOfName;
		switch (node.Kind) {
			case KindSourceFile:
				currentScope = node;
				currentSourceFile = node;
				currentScopeFirstDeclarationsOfName = null;
			case KindCaseBlock, KindModuleBlock, KindBlock:
				currentScope = node;
				currentScopeFirstDeclarationsOfName = null;
			case KindFunctionDeclaration, KindClassDeclaration, KindVariableStatement:
				recordDeclarationInScope(node);
			default:
		}
		return new Pair(savedCurrentScope, savedCurrentScopeFirstDeclarationsOfName);
	}

	function popScope(savedCurrentScope:Node, savedCurrentScopeFirstDeclarationsOfName:StringMap<Node>):Void {
		if (currentScope != savedCurrentScope) {
			// only reset the first declaration for a name if we are exiting the scope in which it was declared
			currentScopeFirstDeclarationsOfName = savedCurrentScopeFirstDeclarationsOfName;
		}

		currentScope = savedCurrentScope;
	}

	// Visits each node in the AST
	function visit(node:Node):Node {
		final grandparentNode = pushNode(node);
		final saved = pushScope(node);
		// PORT: defer — popScope then popNode (Go LIFO order) after the single result is computed.

		if ((node.SubtreeFacts() & SubtreeContainsTypeScript) == 0
			&& ((currentNamespace == null && currentEnum == null) || (node.SubtreeFacts() & SubtreeContainsIdentifier) == 0)) {
			popScope(saved.a, saved.b);
			popNode(grandparentNode);
			return node;
		}

		switch (node.Kind) {
			// TypeScript parameter property modifiers are elided
			case KindPublicKeyword, KindPrivateKeyword, KindProtectedKeyword, KindReadonlyKeyword, KindOverrideKeyword:
				node = null;
			case KindEnumDeclaration:
				node = visitEnumDeclaration(node.AsEnumDeclaration());
			case KindModuleDeclaration:
				node = visitModuleDeclaration(node.AsModuleDeclaration());
			case KindClassDeclaration:
				node = visitClassDeclaration(node.AsClassDeclaration());
			case KindClassExpression:
				node = visitClassExpression(node.AsClassExpression());
			case KindConstructor:
				node = visitConstructorDeclaration(node.AsConstructorDeclaration());
			case KindFunctionDeclaration:
				node = visitFunctionDeclaration(node.AsFunctionDeclaration());
			case KindVariableStatement:
				node = visitVariableStatement(node.AsVariableStatement());
			case KindExportDeclaration, KindImportDeclaration, KindImportClause:
				if (currentNamespace != null && currentScope != null && currentScope.Kind != KindBlock) {
					// do not emit ES6 imports and exports since they are illegal inside a namespace
					node = null;
				} else {
					node = Visitor().VisitEachChild(node);
				}
			case KindImportEqualsDeclaration:
				if (currentNamespace != null && currentScope != null && currentScope.Kind != KindBlock
					&& node.AsImportEqualsDeclaration().ModuleReference.Kind == KindExternalModuleReference) {
					// do not emit ES6 imports and exports since they are illegal inside a namespace
					node = null;
				} else if (currentNamespace != null && currentScope != null && currentScope.Kind == KindBlock
					&& node.AsImportEqualsDeclaration().ModuleReference.Kind != KindExternalModuleReference) {
					// inside a block within a namespace, elide internal import aliases
					node = null;
				} else {
					node = visitImportEqualsDeclaration(node.AsImportEqualsDeclaration());
				}
			case KindIdentifier:
				node = visitIdentifier(node);
			case KindShorthandPropertyAssignment:
				node = visitShorthandPropertyAssignment(node.AsShorthandPropertyAssignment());
			default:
				node = Visitor().VisitEachChild(node);
		}
		popScope(saved.a, saved.b);
		popNode(grandparentNode);
		return node;
	}

	// Records that a declaration was emitted in the current scope, if it was the first declaration for the provided symbol.
	function recordDeclarationInScope(node:Node):Void {
		switch (node.Kind) {
			case KindVariableStatement:
				recordDeclarationInScope(node.AsVariableStatement().DeclarationList);
				return;
			case KindVariableDeclarationList:
				for (decl in rangeOf(node.AsVariableDeclarationList().Declarations.Nodes)) {
					recordDeclarationInScope(decl);
				}
				return;
			case KindArrayBindingPattern, KindObjectBindingPattern:
				final elements = node.Elements();
				if (elements != null) {
					for (element in elements) {
						recordDeclarationInScope(element);
					}
				}
				return;
			default:
		}
		final name = node.Name();
		if (name != null) {
			if (Ast.IsIdentifier(name)) {
				if (currentScopeFirstDeclarationsOfName == null) {
					currentScopeFirstDeclarationsOfName = new StringMap<Node>();
				}
				final text = name.Text();
				if (!currentScopeFirstDeclarationsOfName.exists(text)) {
					currentScopeFirstDeclarationsOfName.set(text, node);
				}
			} else if (Ast.IsBindingPattern(name)) {
				recordDeclarationInScope(name);
			}
		}
	}

	// Determines whether a declaration is the first declaration with the same name emitted in the current scope.
	function isFirstDeclarationInScope(node:Node):Bool {
		final name = node.Name();
		if (name != null && Ast.IsIdentifier(name)) {
			final text = name.Text();
			if (currentScopeFirstDeclarationsOfName != null && currentScopeFirstDeclarationsOfName.exists(text)) {
				final firstDeclaration = currentScopeFirstDeclarationsOfName.get(text);
				return firstDeclaration == node;
			}
		}
		return false;
	}

	function isExportOfNamespace(node:Node):Bool {
		return currentNamespace != null && (currentScope == null || currentScope.Kind != KindBlock) && (node.ModifierFlags() & ModifierFlagsExport) != 0;
	}

	// Gets an expression that represents a property name, such as `"foo"` for the identifier `foo`.
	function getExpressionForPropertyName(member:EnumMember):Expression {
		final name = member.Name();
		switch (name.Kind) {
			case KindPrivateIdentifier:
				return Factory().NewIdentifier("");
			case KindComputedPropertyName:
				final n = name.AsComputedPropertyName();
				// enums don't support computed properties so we always generate the 'expression' part of the name as-is.
				return Visitor().VisitNode(n.Expression);
			case KindIdentifier:
				return Factory().NewStringLiteral(name.Text(), TokenFlagsNone);
			case KindStringLiteral: // !!! propagate token flags (will produce new diffs)
				return Factory().NewStringLiteral(name.Text(), TokenFlagsNone);
			case KindNumericLiteral:
				return Factory().NewNumericLiteral(name.Text(), TokenFlagsNone);
			default:
				return name;
		}
	}

	// Gets an expression like `E["A"]` that references an enum member.
	function getEnumQualifiedElement(enum_:EnumDeclaration, member:EnumMember):Expression {
		final prop = getNamespaceQualifiedElement(getNamespaceContainerName(enum_.AsNode()), getExpressionForPropertyName(member));
		EmitContext().AddEmitFlags(prop, EFNoComments | EFNoNestedComments | EFNoSourceMap | EFNoNestedSourceMaps);
		return prop;
	}

	// Gets an expression used to refer to a namespace or enum from within the body of its declaration.
	function getNamespaceContainerName(node:Node):IdentifierNode {
		return Factory().NewGeneratedNameForNode(node);
	}

	// Gets an expression used to refer to an export of a namespace or a member of an enum by property name.
	function getNamespaceQualifiedProperty(ns:IdentifierNode, name:IdentifierNode):Expression {
		return Factory().GetNamespaceMemberName(ns, name, new NameOptions(false, true));
	}

	// Gets an expression used to refer to an export of a namespace or a member of an enum by indexed access.
	function getNamespaceQualifiedElement(ns:IdentifierNode, expression:Expression):Expression {
		final qualifiedName = EmitContext().Factory.NewElementAccessExpression(ns, null /*questionDotToken*/, expression, NodeFlagsNone);
		EmitContext().AssignCommentAndSourceMapRanges(qualifiedName, expression);
		return qualifiedName;
	}

	// Gets an expression used within the provided node's container for any exported references.
	function getExportQualifiedReferenceToDeclaration(node:Declaration):Expression {
		if (isExportOfNamespace(node.AsNode())) {
			return Factory().GetExternalModuleOrNamespaceExportName(getNamespaceContainerName(currentNamespace), node, false /*allowComments*/,
				true /*allowSourceMaps*/);
		}
		return Factory().GetDeclarationNameEx(node.AsNode(), new NameOptions(false, true));
	}

	// PORT: Go returns ([]*ast.Statement, bool) → ValueOk (value = statements, ok = added).
	function addVarForDeclaration(statements:Array<Statement>, node:Declaration):ValueOk<Array<Statement>> {
		recordDeclarationInScope(node);
		if (!isFirstDeclarationInScope(node)) {
			return new ValueOk(statements, false);
		}

		// var name;
		final name = Factory().GetLocalNameEx(node, new AssignedNameOptions(false, true));
		final varDecl = Factory().NewVariableDeclaration(name, null, null, null);
		final varFlags = Core.IfElse(currentScope == currentSourceFile, NodeFlagsNone, NodeFlagsLet);
		final varDecls = Factory().NewVariableDeclarationList(Factory().NewNodeList([varDecl]), varFlags);
		// Replicate modifierVisitor: strip decorators, TypeScript modifiers, and export when in namespace.
		var modifierMask = ~(ModifierFlagsTypeScriptModifier | ModifierFlagsDecorator);
		if (currentNamespace != null) {
			modifierMask = modifierMask & ~ModifierFlagsExport;
		}
		final modifiers = Transformers.ExtractModifiers(EmitContext(), node.Modifiers(), modifierMask);
		final varStatement = Factory().NewVariableStatement(modifiers, varDecls);

		EmitContext().SetOriginal(varDecl, node);
		// !!! synthetic comments
		EmitContext().SetOriginal(varStatement, node);

		// Adjust the source map emit to match the old emitter.
		if (Ast.IsEnumDeclaration(node)) {
			EmitContext().SetSourceMapRange(varDecls, node.Loc);
		} else {
			EmitContext().SetSourceMapRange(varStatement, node.Loc);
		}

		// Trailing comments for enum declaration should be emitted after the function closure
		// instead of the variable statement:
		//
		//     /** Leading comment*/
		//     enum E {
		//         A
		//     } // trailing comment
		//
		// Should emit:
		//
		//     /** Leading comment*/
		//     var E;
		//     (function (E) {
		//         E[E["A"] = 0] = "A";
		//     })(E || (E = {})); // trailing comment
		//
		EmitContext().SetCommentRange(varStatement, node.Loc);
		EmitContext().AddEmitFlags(varStatement, EFNoTrailingComments);
		statements.push(varStatement);

		return new ValueOk(statements, true);
	}

	function visitEnumDeclaration(node:EnumDeclaration):Node {
		if (!shouldEmitEnumDeclaration(node)) {
			return EmitContext().NewNotEmittedStatement(node.AsNode());
		}

		var statements:Array<Statement> = [];

		// If needed, we should emit a variable declaration for the enum:
		//  var name;
		final r = addVarForDeclaration(statements, node.AsNode());
		statements = r.value;
		final varAdded = r.ok;

		// If we emit a leading variable declaration, we should not emit leading comments for the enum body, but we should
		// still emit the comments if we are emitting to a System module.
		var emitFlags = EFNone;
		if (varAdded && (compilerOptions.GetEmitModuleKind() != ModuleKindSystem || currentScope != currentSourceFile)) {
			emitFlags = emitFlags | EFNoLeadingComments;
		}

		//  x || (x = {})
		//  exports.x || (exports.x = {})
		var enumArg = Factory().NewLogicalORExpression(getExportQualifiedReferenceToDeclaration(node.AsNode()),
			Factory().NewAssignmentExpression(getExportQualifiedReferenceToDeclaration(node.AsNode()),
				Factory().NewObjectLiteralExpression(Factory().NewNodeList([]), false)));

		if (isExportOfNamespace(node.AsNode())) {
			// `localName` is the expression used within this node's containing scope for any local references.
			final localName = Factory().GetLocalNameEx(node.AsNode(), new AssignedNameOptions(false, true));

			//  x = (exports.x || (exports.x = {}))
			enumArg = Factory().NewAssignmentExpression(localName, enumArg);
		}

		// (function (name) { ... })(name || (name = {}))
		final enumParamName = Factory().NewGeneratedNameForNode(node.AsNode());
		EmitContext().SetSourceMapRange(enumParamName, node.Name().Loc);

		final enumParam = Factory().NewParameterDeclaration(null, null, enumParamName, null, null, null);
		final enumBody = transformEnumBody(node);
		final enumFunc = Factory().NewFunctionExpression(null, null, null, null, Factory().NewNodeList([enumParam]), null, null, enumBody);
		final enumCall = Factory().NewCallExpression(Factory().NewParenthesizedExpression(enumFunc), null, null, Factory().NewNodeList([enumArg]),
			NodeFlagsNone);
		final enumStatement = Factory().NewExpressionStatement(enumCall);
		EmitContext().SetOriginal(enumStatement, node.AsNode());
		EmitContext().AssignCommentAndSourceMapRanges(enumStatement, node.AsNode());
		EmitContext().AddEmitFlags(enumStatement, emitFlags);
		statements.push(enumStatement);
		return Factory().NewSyntaxList(statements);
	}

	// Transforms the body of an enum declaration.
	function transformEnumBody(node:EnumDeclaration):BlockNode {
		final savedCurrentEnum = currentEnum;
		currentEnum = node.AsNode();

		// visit the children of `node` in advance to capture any references to enum members
		node = Visitor().VisitEachChild(node.AsNode()).AsEnumDeclaration();

		var statements:Array<Statement> = [];
		for (i in 0...Core.len(node.Members.Nodes)) {
			//  E[E["A"] = 0] = "A";
			statements = transformEnumMember(statements, node, i);
		}

		final statementList = Factory().NewNodeList(statements);
		statementList.Loc = node.Members.Loc;

		currentEnum = savedCurrentEnum;
		return Factory().NewBlock(statementList, true /*multiline*/);
	}

	// Transforms an enum member into a statement. It is expected that `enum` has already been visited.
	function transformEnumMember(statements:Array<Statement>, enum_:EnumDeclaration, index:Int):Array<Statement> {
		final memberNode = enum_.Members.Nodes[index];
		final member = memberNode.AsEnumMember();

		final savedParent = parentNode;
		parentNode = currentNode;
		currentNode = memberNode;

		//  E[E["A"] = x] = "A";
		//             ^
		var expression = member.Initializer; // NOTE: already visited

		var useExplicitReverseMapping = false;

		final parseNode = EmitContext().ParseNode(memberNode);
		final result = emitResolver.GetEnumMemberValue(parseNode);
		final value:Any = result.Value;
		// PORT: Go `case jsnum.Number`; a jsnum.Number in `any` is a raw Float (PORTING.md §3).
		if (Std.isOfType(value, Float)) {
			expression = Core.Coalesce(Tstransforms.constantExpression(value, Factory()), expression);
			useExplicitReverseMapping = true;
		} else if (Std.isOfType(value, std.String)) {
			expression = Core.Coalesce(Tstransforms.constantExpression(value, Factory()), expression);
		} else {
			if (expression == null) {
				expression = Factory().NewVoidZeroExpression();
			}
			useExplicitReverseMapping = !result.IsSyntacticallyString;
		}

		// Define the enum member property:
		//  E[E["A"] = 0] = "A";
		//    ^^^^^^^^--_____
		expression = Factory().NewAssignmentExpression(getEnumQualifiedElement(enum_, member), expression);

		if (useExplicitReverseMapping) {
			//  E[E["A"] = 0] = "A";
			//  ^^--------------^^^^^
			expression = Factory().NewAssignmentExpression(Factory().NewElementAccessExpression(getNamespaceContainerName(enum_.AsNode()),
				null, /*questionDotToken*/ expression, NodeFlagsNone),
				getExpressionForPropertyName(member));
		}

		final memberStatement = Factory().NewExpressionStatement(expression);
		EmitContext().AssignCommentAndSourceMapRanges(expression, member.AsNode());
		EmitContext().AssignCommentAndSourceMapRanges(memberStatement, member.AsNode());
		statements.push(memberStatement);

		currentNode = parentNode;
		parentNode = savedParent;
		return statements;
	}

	function visitModuleDeclaration(node:ModuleDeclaration):Node {
		if (!shouldEmitModuleDeclaration(node)) {
			return EmitContext().NewNotEmittedStatement(node.AsNode());
		}

		var statements:Array<Statement> = [];

		// If needed, we should emit a variable declaration for the module:
		//  var name;
		final r = addVarForDeclaration(statements, node.AsNode());
		statements = r.value;
		final varAdded = r.ok;

		// If we emit a leading variable declaration, we should not emit leading comments for the module body, but we should
		// still emit the comments if we are emitting to a System module.
		var emitFlags = EFNone;
		if (varAdded && (compilerOptions.GetEmitModuleKind() != ModuleKindSystem || currentScope != currentSourceFile)) {
			emitFlags = emitFlags | EFNoLeadingComments;
		}

		//  x || (x = {})
		//  exports.x || (exports.x = {})
		var moduleArg = Factory().NewLogicalORExpression(getExportQualifiedReferenceToDeclaration(node.AsNode()),
			Factory().NewAssignmentExpression(getExportQualifiedReferenceToDeclaration(node.AsNode()),
				Factory().NewObjectLiteralExpression(Factory().NewNodeList([]), false)));

		if (isExportOfNamespace(node.AsNode())) {
			// `localName` is the expression used within this node's containing scope for any local references.
			final localName = Factory().GetLocalNameEx(node.AsNode(), new AssignedNameOptions(false, true));

			//  x = (exports.x || (exports.x = {}))
			moduleArg = Factory().NewAssignmentExpression(localName, moduleArg);
		}

		// (function (name) { ... })(name || (name = {}))
		final moduleParamName = Factory().NewGeneratedNameForNode(node.AsNode());
		EmitContext().SetSourceMapRange(moduleParamName, node.Name().Loc);

		final moduleParam = Factory().NewParameterDeclaration(null, null, moduleParamName, null, null, null);
		final moduleBody = transformModuleBody(node, getNamespaceContainerName(node.AsNode()));
		final moduleFunc = Factory().NewFunctionExpression(null, null, null, null, Factory().NewNodeList([moduleParam]), null, null, moduleBody);
		final moduleCall = Factory().NewCallExpression(Factory().NewParenthesizedExpression(moduleFunc), null, null, Factory().NewNodeList([moduleArg]),
			NodeFlagsNone);
		final moduleStatement = Factory().NewExpressionStatement(moduleCall);
		EmitContext().SetOriginal(moduleStatement, node.AsNode());
		EmitContext().AssignCommentAndSourceMapRanges(moduleStatement, node.AsNode());
		EmitContext().AddEmitFlags(moduleStatement, emitFlags);
		statements.push(moduleStatement);
		return Factory().NewSyntaxList(statements);
	}

	function transformModuleBody(node:ModuleDeclaration, namespaceLocalName:IdentifierNode):BlockNode {
		final savedCurrentNamespace = currentNamespace;
		final savedCurrentScope = currentScope;
		final savedCurrentScopeFirstDeclarationsOfName = currentScopeFirstDeclarationsOfName;

		currentNamespace = node.AsNode();
		currentScopeFirstDeclarationsOfName = null;

		var statements:Array<Statement> = null;
		EmitContext().StartVariableEnvironment();

		var statementsLocation = new TextRange(0, 0);
		var blockLocation = new TextRange(0, 0);
		if (node.Body != null) {
			if (node.Body.Kind == KindModuleBlock) {
				// visit the children of `node` in advance to capture any references to namespace members
				node = Visitor().VisitEachChild(node.AsNode()).AsModuleDeclaration();
				final body = node.Body.AsModuleBlock();
				statements = body.Statements.Nodes;
				statementsLocation = body.Statements.Loc;
				blockLocation = body.Loc;
			} else { // node.Body.Kind == ast.KindModuleDeclaration
				// !!! Strada didn't do this; why?
				// tx.currentScope = node.AsNode()
				statements = Visitor().VisitSlice([node.Body]);
				final moduleBlock = Tstransforms.getInnermostModuleDeclarationFromDottedModule(node).Body.AsModuleBlock();
				statementsLocation = moduleBlock.Statements.Loc.WithPos(-1);
			}
		}

		currentNamespace = savedCurrentNamespace;
		currentScope = savedCurrentScope;
		currentScopeFirstDeclarationsOfName = savedCurrentScopeFirstDeclarationsOfName;

		statements = EmitContext().EndAndMergeVariableEnvironment(statements);
		final statementList = Factory().NewNodeList(statements);
		statementList.Loc = statementsLocation;
		final block = Factory().NewBlock(statementList, true /*multiline*/);
		block.Loc = blockLocation;

		//  namespace hello.hi.world {
		//       function foo() {}
		//
		//       // TODO, blah
		//  }
		//
		// should be emitted as
		//
		//  var hello;
		//  (function (hello) {
		//      var hi;
		//      (function (hi) {
		//          var world;
		//          (function (world) {
		//              function foo() { }
		//              // TODO, blah
		//          })(world = hi.world || (hi.world = {}));
		//      })(hi = hello.hi || (hello.hi = {}));
		//  })(hello || (hello = {}));
		//
		// We only want to emit comment on the namespace which contains block body itself, not the containing namespaces.
		if (node.Body == null || node.Body.Kind != KindModuleBlock) {
			EmitContext().AddEmitFlags(block, EFNoComments);
		}
		return block;
	}

	function visitImportEqualsDeclaration(node:ImportEqualsDeclaration):Node {
		if (node.ModuleReference.Kind == KindExternalModuleReference) {
			return Visitor().VisitEachChild(node.AsNode());
		}

		final moduleReference = Factory().CreateExpressionFromEntityName(node.ModuleReference);
		EmitContext().SetEmitFlags(moduleReference, EFNoComments | EFNoNestedComments);
		if (!isExportOfNamespace(node.AsNode())) {
			//  export var ${name} = ${moduleReference};
			//  var ${name} = ${moduleReference};
			final varDecl = Factory().NewVariableDeclaration(node.Name(), null /*exclamationToken*/, null /*type*/, moduleReference);
			EmitContext().SetOriginal(varDecl, node.AsNode());
			final varList = Factory().NewVariableDeclarationList(Factory().NewNodeList([varDecl]), NodeFlagsNone);
			final varModifiers = Transformers.ExtractModifiers(EmitContext(), node.Modifiers(), ModifierFlagsExport);
			final varStatement = Factory().NewVariableStatement(varModifiers, varList);
			EmitContext().SetOriginal(varStatement, node.AsNode());
			EmitContext().AssignCommentAndSourceMapRanges(varStatement, node.AsNode());
			return varStatement;
		} else {
			// exports.${name} = ${moduleReference};
			final statement = createExportStatement(node.Name(), moduleReference, node.Loc, node.Loc, node.AsNode());
			statement.Loc = node.Loc;
			return statement;
		}
	}

	function visitVariableStatement(node:VariableStatement):Node {
		if (isExportOfNamespace(node.AsNode())) {
			final expressions:Array<Expression> = [];
			for (declaration in rangeOf(node.DeclarationList.AsVariableDeclarationList().Declarations.Nodes)) {
				final v = declaration.AsVariableDeclaration();
				if (v.Initializer == null) {
					continue;
				}
				if (Ast.IsBindingPattern(v.Name())) {
					final expression = Transformers.FlattenDestructuringAssignment(Transformer, Visitor().VisitNode(declaration), false, /*needsValue*/
						FlattenLevelAll, createNamespaceExportExpression);
					if (expression != null) {
						expressions.push(expression);
					}
				} else {
					final expression = Transformers.ConvertVariableDeclarationToAssignmentExpression(EmitContext(), v);
					if (expression != null) {
						expressions.push(expression);
					}
				}
			}
			if (expressions.length == 0) {
				return null;
			}
			final expression = Factory().InlineExpressions(expressions);
			var statement = Factory().NewExpressionStatement(expression);
			EmitContext().SetOriginal(statement, node.AsNode());
			EmitContext().AssignCommentAndSourceMapRanges(statement, node.AsNode());

			// re-visit as the new node
			final savedCurrent = currentNode;
			currentNode = statement;
			statement = Visitor().VisitEachChild(statement);
			currentNode = savedCurrent;
			return statement;
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	// createNamespaceExportExpression creates an assignment to a namespace member for use as a
	// callback during destructuring flattening.
	function createNamespaceExportExpression(exportName:IdentifierNode, exportValue:Expression, location:TextRange):Expression {
		final memberName = getNamespaceQualifiedProperty(getNamespaceContainerName(currentNamespace), exportName);
		final expression = Factory().NewAssignmentExpression(memberName, exportValue);
		if (location != null) {
			expression.Loc = location;
		}
		return expression;
	}

	function visitFunctionDeclaration(node:FunctionDeclaration):Node {
		if (isExportOfNamespace(node.AsNode())) {
			final updated = Factory().UpdateFunctionDeclaration(node, Visitor().VisitModifiers(Transformers.ExtractModifiers(EmitContext(), node.Modifiers(),
				~ModifierFlagsExport)), node.AsteriskToken, Visitor().VisitNode(node.Name()), null, /*typeParameters*/
				Visitor().VisitNodes(node.Parameters), null, /*returnType*/ null, /*fullSignature*/ Visitor().VisitNode(node.Body));
			final export = createExportStatementForDeclaration(node.AsNode());
			if (export != null) {
				return Factory().NewSyntaxList([updated, export]);
			}
			return updated;
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function getParameterProperties(constructor:Node):Array<ParameterDeclaration> {
		var parameterProperties:Array<ParameterDeclaration> = null;
		if (constructor != null) {
			for (parameter in rangeOf(constructor.Parameters())) {
				if (Ast.IsParameterPropertyDeclaration(parameter, constructor)) {
					if (parameterProperties == null) {
						parameterProperties = [];
					}
					parameterProperties.push(parameter.AsParameterDeclaration());
				}
			}
		}
		return parameterProperties;
	}

	function visitClassDeclaration(node:ClassDeclaration):Node {
		final exported = isExportOfNamespace(node.AsNode());
		var modifiers:ModifierList = null;
		if (exported) {
			modifiers = Visitor().VisitModifiers(Transformers.ExtractModifiers(EmitContext(), node.Modifiers(), ~ModifierFlagsExportDefault));
		} else {
			modifiers = Visitor().VisitModifiers(node.Modifiers());
		}

		var name = Visitor().VisitNode(node.Name());
		if (name == null && (exported || Ast.ChildIsDecorated(compilerOptions.ExperimentalDecorators.IsTrue(), node.AsNode(), null))) {
			name = Factory().NewGeneratedNameForNode(node.AsNode());
		}
		final heritageClauses = Visitor().VisitNodes(node.HeritageClauses);
		var members = Visitor().VisitNodes(node.Members);
		final parameterProperties = getParameterProperties(Core.Find(node.Members.Nodes, Ast.IsConstructorDeclaration));

		if (Core.len(parameterProperties) > 0) {
			var newMembers:Array<ClassElement> = null;
			for (parameter in parameterProperties) {
				if (Ast.IsIdentifier(parameter.Name())) {
					final parameterProperty = Factory().NewPropertyDeclaration(null, /*modifiers*/ parameter.Name().Clone(Factory()), null,
						/*questionOrExclamationToken*/ null, /*type*/ null /*initializer*/);
					EmitContext().SetOriginal(parameterProperty, parameter.AsNode());
					if (newMembers == null) {
						newMembers = [];
					}
					newMembers.push(parameterProperty);
				}
			}
			if (Core.len(newMembers) > 0) {
				for (m in rangeOf(members.Nodes)) {
					newMembers.push(m);
				}
				members = Factory().NewNodeList(newMembers);
				members.Loc = node.Members.Loc;
			}
		}

		final updated = Factory().UpdateClassDeclaration(node, modifiers, name, null /*typeParameters*/, heritageClauses, members);
		if (exported) {
			final export = createExportStatementForDeclaration(node.AsNode());
			if (export != null) {
				return Factory().NewSyntaxList([updated, export]);
			}
		}
		return updated;
	}

	function visitClassExpression(node:ClassExpression):Node {
		final modifiers = Visitor().VisitModifiers(Transformers.ExtractModifiers(EmitContext(), node.Modifiers(), ~ModifierFlagsExportDefault));
		final name = Visitor().VisitNode(node.Name());
		final heritageClauses = Visitor().VisitNodes(node.HeritageClauses);
		var members = Visitor().VisitNodes(node.Members);
		final parameterProperties = getParameterProperties(Core.Find(node.Members.Nodes, Ast.IsConstructorDeclaration));

		if (Core.len(parameterProperties) > 0) {
			var newMembers:Array<ClassElement> = null;
			for (parameter in parameterProperties) {
				if (Ast.IsIdentifier(parameter.Name())) {
					final parameterProperty = Factory().NewPropertyDeclaration(null, /*modifiers*/ parameter.Name().Clone(Factory()), null,
						/*questionOrExclamationToken*/ null, /*type*/ null /*initializer*/);
					EmitContext().SetOriginal(parameterProperty, parameter.AsNode());
					if (newMembers == null) {
						newMembers = [];
					}
					newMembers.push(parameterProperty);
				}
			}
			if (Core.len(newMembers) > 0) {
				for (m in rangeOf(members.Nodes)) {
					newMembers.push(m);
				}
				members = Factory().NewNodeList(newMembers);
				members.Loc = node.Members.Loc;
			}
		}

		return Factory().UpdateClassExpression(node, modifiers, name, null /*typeParameters*/, heritageClauses, members);
	}

	function visitConstructorDeclaration(node:ConstructorDeclaration):Node {
		final modifiers = Visitor().VisitModifiers(node.Modifiers());
		final parameters = EmitContext().VisitParameters(node.AsNode().ParameterList(), Visitor());
		final body = visitConstructorBody(node.Body.AsBlock(), node.AsNode());
		return Factory().UpdateConstructorDeclaration(node, modifiers, null /*typeParameters*/, parameters, null /*returnType*/, null /*fullSignature*/, body);
	}

	function visitConstructorBody(body:Block, constructor:Node):Node {
		final parameterProperties = getParameterProperties(constructor);
		if (Core.len(parameterProperties) == 0) {
			return EmitContext().VisitFunctionBody(body.AsNode(), Visitor());
		}

		final grandparentOfBody = pushNode(body.AsNode());
		final savedScope = pushScope(body.AsNode());

		EmitContext().StartVariableEnvironment();
		final split = Factory().SplitStandardPrologue(body.Statements.Nodes);
		final prologue = split.a;
		final rest = split.b;
		var statements:Array<Statement> = Slices.Clone(prologue);

		// Transform parameters into property assignments. Transforms this:
		//
		//  constructor (public x, public y) {
		//  }
		//
		// Into this:
		//
		//  constructor (x, y) {
		//      this.x = x;
		//      this.y = y;
		//  }
		//

		var parameterPropertyAssignments:Array<Statement> = null;
		for (parameter in parameterProperties) {
			if (Ast.IsIdentifier(parameter.Name())) {
				final propertyName = parameter.Name().Clone(Factory());
				propertyName.Parent = parameter.Name().Parent; //nolint:customlint // .Parent set to get node to printback using text from original file instead of processed text; TODO: this should be achievable via EmitFlags instead
				EmitContext().AddEmitFlags(propertyName, EFNoComments | EFNoSourceMap);

				final localName = parameter.Name().Clone(Factory());
				localName.Parent = parameter.Name().Parent; //nolint:customlint // .Parent set to get node to printback using text from original file instead of processed text; TODO: this should be achievable via EmitFlags instead
				EmitContext().AddEmitFlags(localName, EFNoComments);

				final parameterProperty = Factory().NewExpressionStatement(Factory().NewAssignmentExpression(Factory().NewPropertyAccessExpression(Factory()
					.NewThisExpression(), null, /*questionDotToken*/ propertyName, NodeFlagsNone),
					localName));
				EmitContext().SetOriginal(parameterProperty, parameter.AsNode());
				EmitContext().AddEmitFlags(parameterProperty, EFStartOnNewLine);
				if (parameterPropertyAssignments == null) {
					parameterPropertyAssignments = [];
				}
				parameterPropertyAssignments.push(parameterProperty);
			}
		}

		final superPath = Transformers.FindSuperStatementIndexPath(rest, 0);

		if (Core.len(superPath) > 0) {
			statements = appendAll(statements, transformConstructorBodyWorker(rest, superPath, parameterPropertyAssignments));
		} else {
			statements = appendAll(statements, parameterPropertyAssignments);
			statements = appendAll(statements, Visitor().VisitSlice(rest));
		}

		statements = EmitContext().EndAndMergeVariableEnvironment(statements);
		final statementList = Factory().NewNodeList(statements);
		statementList.Loc = body.Statements.Loc;

		popScope(savedScope.a, savedScope.b);
		popNode(grandparentOfBody);
		final updated = Factory().NewBlock(statementList /*multiline*/, true);
		EmitContext().SetOriginal(updated, body.AsNode());
		updated.Loc = body.Loc;
		return updated;
	}

	// PORT: Go `append(s, xs...)` where this function owns `s` (nil → new array; nil/empty xs → s).
	static function appendAll(s:Array<Statement>, xs:Array<Statement>):Array<Statement> {
		if (xs == null || xs.length == 0) {
			return s;
		}
		if (s == null) {
			s = [];
		}
		for (x in xs) {
			s.push(x);
		}
		return s;
	}

	function transformConstructorBodyWorker(statementsIn:Array<Statement>, superPath:Array<Int>, initializerStatements:Array<Statement>):Array<Statement> {
		var statementsOut:Array<Statement> = null;
		final superStatementIndex = superPath[0];
		final superStatement = statementsIn[superStatementIndex];

		// visit up to the statement containing `super`
		statementsOut = appendAll(statementsOut, Visitor().VisitSlice(statementsIn.slice(0, superStatementIndex)));

		// if the statement containing `super` is a `try` statement, transform the body of the `try` block
		if (Ast.IsTryStatement(superStatement)) {
			final tryStatement = superStatement.AsTryStatement();
			final tryBlock = tryStatement.TryBlock.AsBlock();

			// keep track of hierarchy as we descend
			final grandparentOfTryStatement = pushNode(tryStatement.AsNode());
			final grandparentOfTryBlock = pushNode(tryBlock.AsNode());
			final savedScope = pushScope(tryBlock.AsNode());

			// visit the `try` block
			final tryBlockStatements = transformConstructorBodyWorker(tryBlock.Statements.Nodes, superPath.slice(1), initializerStatements);

			// restore hierarchy as we ascend to the `try` statement
			popScope(savedScope.a, savedScope.b);
			popNode(grandparentOfTryBlock);

			final tryBlockStatementList = Factory().NewNodeList(tryBlockStatements);
			tryBlockStatementList.Loc = tryBlock.Statements.Loc;
			statementsOut = appendAll(statementsOut, [
				Factory().UpdateTryStatement(tryStatement, Factory().UpdateBlock(tryBlock, tryBlockStatementList, tryBlock.MultiLine),
					Visitor().VisitNode(tryStatement.CatchClause), Visitor().VisitNode(tryStatement.FinallyBlock))
			]);

			// restore hierarchy as we ascend to the parent of the `try` statement
			popNode(grandparentOfTryStatement);
		} else {
			// visit the statement containing `super`
			statementsOut = appendAll(statementsOut, Visitor().VisitSlice(statementsIn.slice(superStatementIndex, superStatementIndex + 1)));

			// insert the initializer statements
			statementsOut = appendAll(statementsOut, initializerStatements);
		}

		// visit the statements after `super`
		statementsOut = appendAll(statementsOut, Visitor().VisitSlice(statementsIn.slice(superStatementIndex + 1)));
		return statementsOut;
	}

	function visitShorthandPropertyAssignment(node:ShorthandPropertyAssignment):Node {
		final name = node.Name();
		final exportedOrImportedName = visitExpressionIdentifier(name);
		if (exportedOrImportedName != name) {
			var expression = exportedOrImportedName;
			if (node.ObjectAssignmentInitializer != null) {
				var equalsToken = node.EqualsToken;
				if (equalsToken == null) {
					equalsToken = Factory().NewToken(KindEqualsToken);
				}
				expression = Factory().NewBinaryExpression(null, /*modifiers*/ expression, null, /*typeNode*/ equalsToken,
					Visitor().VisitNode(node.ObjectAssignmentInitializer));
			}

			final updated = Factory().NewPropertyAssignment(null /*modifiers*/, node.Name(), null /*postfixToken*/, null /*typeNode*/, expression);
			updated.Loc = node.Loc;
			EmitContext().SetOriginal(updated, node.AsNode());
			EmitContext().AssignCommentAndSourceMapRanges(updated, node.AsNode());
			return updated;
		}
		return Factory().UpdateShorthandPropertyAssignment(node, null, /*modifiers*/ exportedOrImportedName, null, /*postfixToken*/ null, /*typeNode*/
			node.EqualsToken, Visitor().VisitNode(node.ObjectAssignmentInitializer));
	}

	function visitIdentifier(node:IdentifierNode):Node {
		if (Transformers.IsIdentifierReference(node, parentNode)) {
			return visitExpressionIdentifier(node);
		}
		return node;
	}

	function visitExpressionIdentifier(node:IdentifierNode):Node {
		if ((currentEnum != null || currentNamespace != null)
			&& !Transformers.IsGeneratedIdentifier(EmitContext(), node)
			&& !Transformers.IsLocalName(EmitContext(), node)) {
			final location = EmitContext().MostOriginal(node.AsNode());
			final container = resolver.GetReferencedExportContainer(location, false /*prefixLocals*/);
			if (container != null && (Ast.IsEnumDeclaration(container) || Ast.IsModuleDeclaration(container))) {
				final containerName = getNamespaceContainerName(container);

				final memberName = node.Clone(Factory());
				EmitContext().SetEmitFlags(memberName, EFNoComments | EFNoSourceMap);

				final expression = Factory().GetNamespaceMemberName(containerName, memberName, new NameOptions(false, true));
				EmitContext().AssignCommentAndSourceMapRanges(expression, node.AsNode());
				return expression;
			}
		}
		return node;
	}

	function createExportStatementForDeclaration(node:Declaration):Statement {
		final exportName = Factory().GetExternalModuleOrNamespaceExportName(getNamespaceContainerName(currentNamespace), node, false /*allowComments*/,
			true /*allowSourceMaps*/);
		final localName = Factory().GetLocalName(node);
		final expression = Factory().NewAssignmentExpression(exportName, localName);
		var exportAssignmentSourceMapRange = node.Loc;
		if (node.Name() != null) {
			exportAssignmentSourceMapRange = exportAssignmentSourceMapRange.WithPos(node.Name().Pos());
		}
		EmitContext().SetSourceMapRange(expression, exportAssignmentSourceMapRange);

		final statement = Factory().NewExpressionStatement(expression);
		final exportStatementSourceMapRange = node.Loc.WithPos(-1);
		EmitContext().SetSourceMapRange(statement, exportStatementSourceMapRange);
		return statement;
	}

	function createExportAssignment(name:IdentifierNode, expression:Expression, exportAssignmentSourceMapRange:TextRange, original:Node):Expression {
		final exportName = getNamespaceQualifiedProperty(getNamespaceContainerName(currentNamespace), name);
		final exportAssignment = Factory().NewAssignmentExpression(exportName, expression);
		EmitContext().SetOriginal(exportAssignment, original);
		EmitContext().SetSourceMapRange(exportAssignment, exportAssignmentSourceMapRange);
		return exportAssignment;
	}

	function createExportStatement(name:IdentifierNode, expression:Expression, exportAssignmentSourceMapRange:TextRange,
			exportStatementSourceMapRange:TextRange, original:Node):Statement {
		final exportStatement = Factory().NewExpressionStatement(createExportAssignment(name, expression, exportAssignmentSourceMapRange, original));
		EmitContext().SetOriginal(exportStatement, original);
		EmitContext().SetSourceMapRange(exportStatement, exportStatementSourceMapRange);
		return exportStatement;
	}

	function shouldEmitEnumDeclaration(node:EnumDeclaration):Bool {
		return !Ast.IsEnumConst(node.AsNode()) || compilerOptions.ShouldPreserveConstEnums();
	}

	function shouldEmitModuleDeclaration(node:ModuleDeclaration):Bool {
		final pn = EmitContext().ParseNode(node.AsNode());
		if (pn == null) {
			// If we can't find a parse tree node, assume the node is instantiated.
			return true;
		}
		return Ast.IsInstantiatedModule(pn, compilerOptions.ShouldPreserveConstEnums());
	}
}
