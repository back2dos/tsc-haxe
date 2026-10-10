package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/objectrestspread.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

import ts.core.Text.TextRange;

@:allow(ts.transformers.estransforms)
class ObjectRestSpreadTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var compilerOptions:CompilerOptions = null;
	var inExportedVariableStatement:Bool = false;
	var expressionResultIsUnused:Bool = false;
	var parametersWithPrecedingObjectRestOrSpread:IdentityMap<Node, Bool> = null;

	public function new() {}

	// PORT: promoted methods of the embedded transformers.Transformer.
	inline function Visitor():NodeVisitor return Transformer.Visitor();
	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();
	inline function EmitContext():EmitContext return Transformer.EmitContext();

	function visit(node:Node):Node {
		if ((node.SubtreeFacts() & SubtreeContainsESObjectRestOrSpread) == 0 && parametersWithPrecedingObjectRestOrSpread == null) {
			return node;
		}
		// Save the expressionResultIsUnused flag set by the parent for this node,
		// then reset to false for children (the default). Specific cases below override as needed.
		final expressionResultIsUnused = this.expressionResultIsUnused;
		this.expressionResultIsUnused = false;
		// PORT: defer → restore on the success path after computing the result.
		var result:Node = null;
		switch (node.Kind) {
			case KindSourceFile:
				result = visitSourceFile(node.AsSourceFile());
			case KindObjectLiteralExpression:
				result = visitObjectLiteralExpression(node.AsObjectLiteralExpression());
			case KindBinaryExpression:
				result = visitBinaryExpression(node.AsBinaryExpression(), expressionResultIsUnused);
			case KindExpressionStatement:
				this.expressionResultIsUnused = true;
				result = Visitor().VisitEachChild(node);
			case KindParenthesizedExpression:
				this.expressionResultIsUnused = expressionResultIsUnused;
				result = Visitor().VisitEachChild(node);
			case KindForOfStatement:
				result = visitForOftatement(node.AsForInOrOfStatement());
			case KindVariableStatement:
				result = visitVariableStatement(node.AsVariableStatement());
			case KindVariableDeclaration:
				result = visitVariableDeclaration(node.AsVariableDeclaration());
			case KindCatchClause:
				result = visitCatchClause(node.AsCatchClause());
			case KindParameter:
				result = visitParameter(node.AsParameterDeclaration());
			case KindConstructor:
				result = visitContructorDeclaration(node.AsConstructorDeclaration());
			case KindGetAccessor:
				result = visitGetAccessorDeclaration(node.AsGetAccessorDeclaration());
			case KindSetAccessor:
				result = visitSetAccessorDeclaration(node.AsSetAccessorDeclaration());
			case KindMethodDeclaration:
				result = visitMethodDeclaration(node.AsMethodDeclaration());
			case KindFunctionDeclaration:
				result = visitFunctionDeclaration(node.AsFunctionDeclaration());
			case KindArrowFunction:
				result = visitArrowFunction(node.AsArrowFunction());
			case KindFunctionExpression:
				result = visitFunctionExpression(node.AsFunctionExpression());
			default:
				result = Visitor().VisitEachChild(node);
		}
		this.expressionResultIsUnused = expressionResultIsUnused;
		return result;
	}

	function visitSourceFile(node:SourceFile):Node {
		final visited = Visitor().VisitEachChild(node.AsNode());
		EmitContext().AddEmitHelper(visited.AsNode(), ...EmitContext().ReadEmitHelpers());
		return visited;
	}

	function visitParameter(node:ParameterDeclaration):Node {
		if (parametersWithPrecedingObjectRestOrSpread != null) {
			if (parametersWithPrecedingObjectRestOrSpread.exists(node.AsNode())) {
				var name = node.AsNode().Name();
				if (Ast.IsBindingPattern(name)) {
					name = Factory().NewGeneratedNameForNode(node.AsNode());
				}
				return Factory().UpdateParameterDeclaration(
					node,
					null,
					node.DotDotDotToken,
					name,
					null,
					null,
					null
				);
			}
		}
		if ((node.SubtreeFacts() & SubtreeContainsObjectRestOrSpread) != 0) {
			// Binding patterns are converted into a generated name and are
			// evaluated inside the function body.
			return Factory().UpdateParameterDeclaration(
				node,
				null,
				node.DotDotDotToken,
				Factory().NewGeneratedNameForNode(node.AsNode()),
				null,
				null,
				Visitor().VisitNode(node.Initializer)
			);
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function collectParametersWithPrecedingObjectRestOrSpread(node:Node):IdentityMap<Node, Bool> {
		var result:IdentityMap<Node, Bool> = null;
		for (parameter in node.Parameters()) {
			if (result != null) {
				result.set(parameter, true);
			} else if ((parameter.SubtreeFacts() & SubtreeContainsObjectRestOrSpread) != 0) {
				result = new IdentityMap<Node, Bool>();
			}
		}
		return result;
	}

	function enterParameterListContext(node:Node):OldParamScope {
		final old = parametersWithPrecedingObjectRestOrSpread;
		parametersWithPrecedingObjectRestOrSpread = collectParametersWithPrecedingObjectRestOrSpread(node);
		return old;
	}

	function exitParameterListContext(scope:OldParamScope):Void {
		parametersWithPrecedingObjectRestOrSpread = scope;
	}

	function visitContructorDeclaration(node:ConstructorDeclaration):Node {
		final old = enterParameterListContext(node.AsNode());
		// PORT: defer → exit after computing the result.
		final result = Factory().UpdateConstructorDeclaration(
			node,
			node.Modifiers(),
			null,
			Visitor().VisitNodes(node.Parameters),
			null,
			null,
			transformFunctionBody(node.AsNode())
		);
		exitParameterListContext(old);
		return result;
	}

	function visitGetAccessorDeclaration(node:GetAccessorDeclaration):Node {
		final old = enterParameterListContext(node.AsNode());
		// PORT: defer → exit after computing the result.
		final result = Factory().UpdateGetAccessorDeclaration(
			node,
			node.Modifiers(),
			Visitor().VisitNode(node.AsNode().Name()),
			null,
			Visitor().VisitNodes(node.Parameters),
			null,
			null,
			transformFunctionBody(node.AsNode())
		);
		exitParameterListContext(old);
		return result;
	}

	function visitSetAccessorDeclaration(node:SetAccessorDeclaration):Node {
		final old = enterParameterListContext(node.AsNode());
		// PORT: defer → exit after computing the result.
		final result = Factory().UpdateSetAccessorDeclaration(
			node,
			node.Modifiers(),
			Visitor().VisitNode(node.AsNode().Name()),
			null,
			Visitor().VisitNodes(node.Parameters),
			null,
			null,
			transformFunctionBody(node.AsNode())
		);
		exitParameterListContext(old);
		return result;
	}

	function visitMethodDeclaration(node:MethodDeclaration):Node {
		final old = enterParameterListContext(node.AsNode());
		// PORT: defer → exit after computing the result.
		final result = Factory().UpdateMethodDeclaration(
			node,
			node.Modifiers(),
			node.AsteriskToken,
			Visitor().VisitNode(node.AsNode().Name()),
			node.PostfixToken,
			null,
			Visitor().VisitNodes(node.Parameters),
			null,
			null,
			transformFunctionBody(node.AsNode())
		);
		exitParameterListContext(old);
		return result;
	}

	function visitFunctionDeclaration(node:FunctionDeclaration):Node {
		final old = enterParameterListContext(node.AsNode());
		// PORT: defer → exit after computing the result.
		final result = Factory().UpdateFunctionDeclaration(
			node,
			node.Modifiers(),
			node.AsteriskToken,
			Visitor().VisitNode(node.AsNode().Name()),
			null,
			Visitor().VisitNodes(node.Parameters),
			null,
			null,
			transformFunctionBody(node.AsNode())
		);
		exitParameterListContext(old);
		return result;
	}

	function visitArrowFunction(node:ArrowFunction):Node {
		final old = enterParameterListContext(node.AsNode());
		// PORT: defer → exit after computing the result.
		final result = Factory().UpdateArrowFunction(
			node,
			node.Modifiers(),
			null,
			Visitor().VisitNodes(node.Parameters),
			null,
			null,
			node.EqualsGreaterThanToken,
			transformFunctionBody(node.AsNode())
		);
		exitParameterListContext(old);
		return result;
	}

	function visitFunctionExpression(node:FunctionExpression):Node {
		final old = enterParameterListContext(node.AsNode());
		// PORT: defer → exit after computing the result.
		final result = Factory().UpdateFunctionExpression(
			node,
			node.Modifiers(),
			node.AsteriskToken,
			Visitor().VisitNode(node.AsNode().Name()),
			null,
			Visitor().VisitNodes(node.Parameters),
			null,
			null,
			transformFunctionBody(node.AsNode())
		);
		exitParameterListContext(old);
		return result;
	}

	function transformFunctionBody(node:Node):Node {
		// EmitContext().VisitFunctionBody is not used here because this transformer needs to inject
		// object rest assignments between visiting the body and merging the variable environment.
		EmitContext().StartVariableEnvironment();
		var body = Visitor().VisitNode(node.Body());
		var extras = EmitContext().EndVariableEnvironment();
		EmitContext().StartVariableEnvironment();
		final newStatements = collectObjectRestAssignments(node);
		extras = EmitContext().EndAndMergeVariableEnvironment(extras);
		if ((newStatements == null || newStatements.length == 0) && (extras == null || extras.length == 0)) {
			return body;
		}

		if (body == null) {
			body = Factory().NewBlock(Factory().NewNodeList([]), true);
		}
		final prefix:Array<Node> = [];
		var suffix:Array<Node> = null;
		if (Ast.IsBlock(body)) {
			var custom = false;
			final bodyStatements = body.Statements();
			for (i in 0...bodyStatements.length) {
				final statement = bodyStatements[i];
				if (!custom && Ast.IsPrologueDirective(statement)) {
					prefix.push(statement);
				} else if ((EmitContext().EmitFlags(statement) & EFCustomPrologue) != 0) {
					custom = true;
					prefix.push(statement);
				} else {
					suffix = bodyStatements.slice(i);
					break;
				}
			}
		} else {
			final ret = Factory().NewReturnStatement(body);
			ret.Loc = body.Loc;
			final list = Factory().NewNodeList([]);
			list.Loc = body.Loc;
			body = Factory().NewBlock(list, true);
			suffix = [ret];
		}

		// PORT: append(append(append(prefix, extras...), newStatements...), suffix...) → owned array.
		final all:Array<Node> = prefix;
		if (extras != null) for (x in extras) all.push(x);
		if (newStatements != null) for (x in newStatements) all.push(x);
		if (suffix != null) for (x in suffix) all.push(x);
		final newStatementList = Factory().NewNodeList(all);
		newStatementList.Loc = body.StatementList().Loc;
		return Factory().UpdateBlock(body.AsBlock(), newStatementList, body.AsBlock().MultiLine);
	}

	function collectObjectRestAssignments(node:Node):Array<Node> {
		var containsPrecedingObjectRestOrSpread = false;
		var results:Array<Node> = null;
		for (parameter in node.Parameters()) {
			if (containsPrecedingObjectRestOrSpread) {
				if (Ast.IsBindingPattern(parameter.Name())) {
					// In cases where a binding pattern is simply '[]' or '{}',
					// we usually don't want to emit a var declaration; however, in the presence
					// of an initializer, we must emit that expression to preserve side effects.
					if (parameter.Name().Elements().length > 0) {
						final declarations = Transformers.FlattenDestructuringBinding(
							Transformer,
							parameter, Factory().NewGeneratedNameForNode(parameter),
							FlattenLevelAll, false, false
						);
						if (declarations != null) {
							final declarationList = Factory().NewVariableDeclarationList(Factory().NewNodeList([]), NodeFlagsNone);
							var decls:Array<Node> = [declarations];
							if (declarations.Kind == KindSyntaxList) {
								decls = declarations.AsSyntaxList().Children;
							}
							final declNodes = declarationList.AsVariableDeclarationList().Declarations.Nodes;
							for (d in decls) declNodes.push(d);
							final statement = Factory().NewVariableStatement(null, declarationList);
							EmitContext().AddEmitFlags(statement, EFCustomPrologue);
							if (results == null) results = [];
							results.push(statement);
						}
					} else if (parameter.Initializer() != null) {
						final name = Factory().NewGeneratedNameForNode(parameter);
						final initializer = Visitor().VisitNode(parameter.Initializer());
						final assignment = Factory().NewAssignmentExpression(name, initializer);
						final statement = Factory().NewExpressionStatement(assignment);
						EmitContext().AddEmitFlags(statement, EFCustomPrologue);
						if (results == null) results = [];
						results.push(statement);
					}
				} else if (parameter.Initializer() != null) {
					// Converts a parameter initializer into a function body statement, i.e.:
					//
					//  function f(x = 1) { }
					//
					// becomes
					//
					//  function f(x) {
					//    if (typeof x === "undefined") { x = 1; }
					//  }
					final name = parameter.Name().Clone(Factory());
					name.Loc = parameter.Name().Loc;
					EmitContext().AddEmitFlags(name, EFNoSourceMap);

					final initializer = Visitor().VisitNode(parameter.Initializer());
					EmitContext().AddEmitFlags(initializer, EFNoSourceMap | EFNoComments);

					final assignment = Factory().NewAssignmentExpression(name, initializer);
					assignment.Loc = parameter.Loc;
					EmitContext().AddEmitFlags(assignment, EFNoComments);

					final block = Factory().NewBlock(Factory().NewNodeList([Factory().NewExpressionStatement(assignment)]), false);
					block.Loc = parameter.Loc;
					EmitContext().AddEmitFlags(block, EFSingleLine | EFNoTrailingSourceMap | EFNoTokenSourceMaps | EFNoComments);

					final typeCheck = Factory().NewTypeCheck(name.Clone(Factory()), "undefined");
					final statement = Factory().NewIfStatement(typeCheck, block, null);
					statement.Loc = parameter.Loc;
					EmitContext().AddEmitFlags(statement, EFNoTokenSourceMaps | EFNoTrailingSourceMap | EFCustomPrologue | EFNoComments | EFStartOnNewLine);
					if (results == null) results = [];
					results.push(statement);
				}
			} else if ((parameter.SubtreeFacts() & SubtreeContainsObjectRestOrSpread) != 0) {
				containsPrecedingObjectRestOrSpread = true;
				final declarations = Transformers.FlattenDestructuringBinding(
					Transformer,
					parameter, Factory().NewGeneratedNameForNode(parameter),
					FlattenLevelObjectRest, false, true
				);
				if (declarations != null) {
					final declarationList = Factory().NewVariableDeclarationList(Factory().NewNodeList([]), NodeFlagsNone);
					var decls:Array<Node> = [declarations];
					if (declarations.Kind == KindSyntaxList) {
						decls = declarations.AsSyntaxList().Children;
					}
					final declNodes = declarationList.AsVariableDeclarationList().Declarations.Nodes;
					for (d in decls) declNodes.push(d);
					final statement = Factory().NewVariableStatement(null, declarationList);
					EmitContext().AddEmitFlags(statement, EFCustomPrologue);
					if (results == null) results = [];
					results.push(statement);
				}
			}
		}

		return results;
	}

	function visitCatchClause(node:CatchClause):Node {
		if (node.VariableDeclaration != null && Ast.IsBindingPattern(node.VariableDeclaration.Name()) && (node.VariableDeclaration.Name().SubtreeFacts() & SubtreeContainsObjectRestOrSpread) != 0) {
			final name = Factory().NewGeneratedNameForNode(node.VariableDeclaration.Name());
			final updatedDecl = Factory().UpdateVariableDeclaration(node.VariableDeclaration.AsVariableDeclaration(), node.VariableDeclaration.Name(), null, null, name);
			final visitedBindings = Transformers.FlattenDestructuringBinding(
				Transformer,
				updatedDecl, null,
				FlattenLevelObjectRest, false, false
			);
			var block = Visitor().VisitNode(node.Block);
			if (visitedBindings != null) {
				var decls:Array<Node> = null;
				if (visitedBindings.Kind == KindSyntaxList) {
					decls = visitedBindings.AsSyntaxList().Children;
				} else {
					decls = [visitedBindings];
				}
				final newStatement = Factory().NewVariableStatement(null, Factory().NewVariableDeclarationList(Factory().NewNodeList(decls), NodeFlagsNone));
				final statements:Array<Node> = [newStatement];
				for (s in block.Statements()) statements.push(s);
				final statementList = Factory().NewNodeList(statements);
				statementList.Loc = block.StatementList().Loc;

				block = Factory().UpdateBlock(block.AsBlock(), statementList, block.AsBlock().MultiLine);
			}
			return Factory().UpdateCatchClause(
				node,
				Factory().UpdateVariableDeclaration(node.VariableDeclaration.AsVariableDeclaration(), name, null, null, null),
				block
			);
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitVariableStatement(node:VariableStatement):Node {
		if (Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsExport)) {
			final oldInExportedVariableStatement = inExportedVariableStatement;
			inExportedVariableStatement = true;
			final result = Visitor().VisitEachChild(node.AsNode());
			inExportedVariableStatement = oldInExportedVariableStatement;
			return result;
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitVariableDeclaration(node:VariableDeclaration):Node {
		if (inExportedVariableStatement) {
			inExportedVariableStatement = false;
			final result = visitVariableDeclarationWorker(node, true);
			inExportedVariableStatement = true;
			return result;
		}
		return visitVariableDeclarationWorker(node, false);
	}

	function visitVariableDeclarationWorker(node:VariableDeclaration, exported:Bool):Node {
		// If we are here it is because the name contains a binding pattern with a rest somewhere in it.
		if (Ast.IsBindingPattern(node.AsNode().Name()) && (node.SubtreeFacts() & SubtreeContainsObjectRestOrSpread) != 0) {
			return Transformers.FlattenDestructuringBinding(
				Transformer,
				node.AsNode(), null,
				FlattenLevelObjectRest, exported, false
			);
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitForOftatement(node:ForInOrOfStatement):Node {
		if ((node.Initializer.SubtreeFacts() & SubtreeContainsObjectRestOrSpread) != 0 || (Ast.IsAssignmentPattern(node.Initializer) && Ast.ContainsObjectRestOrSpread(node.Initializer))) {
			final initializerWithoutParens = Ast.SkipParentheses(node.Initializer);
			if (Ast.IsVariableDeclarationList(initializerWithoutParens) || Ast.IsAssignmentPattern(initializerWithoutParens)) {
				var bodyLocation = new TextRange(0, 0);
				var statementsLocation = new TextRange(0, 0);
				final temp = Factory().NewTempVariable();
				final res = Visitor().VisitNode(Factory().CreateForOfBindingStatement(initializerWithoutParens, temp));
				final statements:Array<Node> = [];
				if (res != null) {
					statements.push(res);
				}
				if (Ast.IsBlock(node.Statement)) {
					for (statement in node.Statement.Statements()) {
						final visited = Visitor().VisitEachChild(statement);
						if (visited != null) {
							statements.push(visited);
						}
					}
					bodyLocation = node.Statement.Loc;
					statementsLocation = node.Statement.StatementList().Loc;
				} else if (node.Statement != null) {
					statements.push(Visitor().VisitEachChild(node.Statement));
					bodyLocation = node.Statement.Loc;
					statementsLocation = node.Statement.Loc;
				}

				final list = Factory().NewVariableDeclarationList(
					Factory().NewNodeList([Factory().NewVariableDeclaration(temp, null, null, null)]),
					NodeFlagsLet
				);
				list.Loc = node.Initializer.Loc;

				final expr = Visitor().VisitEachChild(node.Expression);

				final statementsList = Factory().NewNodeList(statements);
				statementsList.Loc = statementsLocation;

				final block = Factory().NewBlock(statementsList, true);
				block.Loc = bodyLocation;

				return Factory().UpdateForInOrOfStatement(
					node,
					node.AwaitModifier,
					list,
					expr,
					block
				);
			}
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitBinaryExpression(node:BinaryExpression, expressionResultIsUnused:Bool):Node {
		if (Ast.IsDestructuringAssignment(node.AsNode()) && Ast.ContainsObjectRestOrSpread(node.Left)) {
			return Transformers.FlattenDestructuringAssignment(
				Transformer,
				node.AsNode(), !expressionResultIsUnused,
				FlattenLevelObjectRest, null
			);
		}
		if (node.OperatorToken.Kind == KindCommaToken) {
			this.expressionResultIsUnused = true;
			final left = Visitor().VisitNode(node.Left);
			this.expressionResultIsUnused = expressionResultIsUnused;
			final right = Visitor().VisitNode(node.Right);
			return Factory().UpdateBinaryExpression(node, null, left, null, node.OperatorToken, right);
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitObjectLiteralExpression(node:ObjectLiteralExpression):Node {
		if ((node.SubtreeFacts() & SubtreeContainsObjectRestOrSpread) == 0) {
			return Visitor().VisitEachChild(node.AsNode());
		}
		// spread elements emit like so:
		// non-spread elements are chunked together into object literals, and then all are passed to __assign:
		//     { a, ...o, b } => __assign(__assign({a}, o), {b});
		// If the first element is a spread element, then the first argument to __assign is {}:
		//     { ...o, a, b, ...o2 } => __assign(__assign(__assign({}, o), {a, b}), o2)
		//
		// We cannot call __assign with more than two elements, since any element could cause side effects. For
		// example:
		//      var k = { a: 1, b: 2 };
		//      var o = { a: 3, ...k, b: k.a++ };
		//      // expected: { a: 1, b: 1 }
		// If we translate the above to `__assign({ a: 3 }, k, { b: k.a++ })`, the `k.a++` will evaluate before
		// `k` is spread and we end up with `{ a: 2, b: 1 }`.
		//
		// This also occurs for spread elements, not just property assignments:
		//      var k = { a: 1, get b() { l = { z: 9 }; return 2; } };
		//      var l = { c: 3 };
		//      var o = { ...k, ...l };
		//      // expected: { a: 1, b: 2, z: 9 }
		// If we translate the above to `__assign({}, k, l)`, the `l` will evaluate before `k` is spread and we
		// end up with `{ a: 1, b: 2, c: 3 }`

		var objects = chunkObjectLiteralElements(node.Properties);
		if (objects != null && objects.length > 0 && objects[0].Kind != KindObjectLiteralExpression) {
			final prepended:Array<Node> = [Factory().NewObjectLiteralExpression(Factory().NewNodeList(null), false)];
			for (o in objects) prepended.push(o);
			objects = prepended;
		}
		var expression = objects[0];
		if (objects.length > 1) {
			for (i in 0...objects.length) {
				final obj = objects[i];
				if (i == 0) {
					continue;
				}
				expression = Factory().NewAssignHelper([expression, obj], compilerOptions.GetEmitScriptTarget());
			}
			return expression;
		}
		return Factory().NewAssignHelper(objects, compilerOptions.GetEmitScriptTarget());
	}

	function chunkObjectLiteralElements(list:NodeList):Array<Node> {
		if (list == null || list.Nodes.length == 0) {
			return null;
		}
		final elements = list.Nodes;
		var chunkObject:Array<Node> = null;
		final objects:Array<Node> = [];
		for (e in elements) {
			if (e.Kind == KindSpreadAssignment) {
				if (chunkObject != null && chunkObject.length > 0) {
					objects.push(Factory().NewObjectLiteralExpression(Factory().NewNodeList(chunkObject), false));
					chunkObject = null;
				}
				final target = e.Expression();
				objects.push(Visitor().VisitNode(target));
			} else {
				var elem:Node = null;
				if (e.Kind == KindPropertyAssignment) {
					elem = Factory().NewPropertyAssignment(null, e.Name(), null, null, Visitor().VisitNode(e.Initializer()));
				} else {
					elem = Visitor().VisitNode(e);
				}
				if (chunkObject == null) chunkObject = [];
				chunkObject.push(elem);
			}
		}
		if (chunkObject != null && chunkObject.length > 0) {
			objects.push(Factory().NewObjectLiteralExpression(Factory().NewNodeList(chunkObject), false));
		}
		return objects;
	}
}

typedef OldParamScope = IdentityMap<Node, Bool>;

