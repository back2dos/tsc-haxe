package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/using.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

import ts.printer.Generatedidentifierflags.GeneratedIdentifierFlags.*;

@:allow(ts.transformers.estransforms)
class UsingDeclarationTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var exportBindings:StringMap<ExportSpecifierNode> = null;
	var exportBindingNames:Array<std.String> = null;
	var exportVars:Array<VariableDeclarationNode> = null;
	var defaultExportBinding:IdentifierNode = null;
	var exportEqualsBinding:IdentifierNode = null;

	public function new() {}

	// PORT: promoted methods of the embedded transformers.Transformer.
	inline function Visitor():NodeVisitor return Transformer.Visitor();
	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();
	inline function EmitContext():EmitContext return Transformer.EmitContext();

	function visit(node:Node):Node {
		if ((node.SubtreeFacts() & SubtreeContainsUsing) == 0) {
			return node;
		}

		switch (node.Kind) {
			case KindSourceFile:
				node = visitSourceFile(node.AsSourceFile());
			case KindBlock:
				node = visitBlock(node.AsBlock());
			case KindForStatement:
				node = visitForStatement(node.AsForStatement());
			case KindForOfStatement:
				node = visitForOfStatement(node.AsForInOrOfStatement());
			default:
				node = Visitor().VisitEachChild(node);
		}
		return node;
	}

	function visitSourceFile(node:SourceFile):Node {
		if (node.IsDeclarationFile) {
			return node.AsNode();
		}

		var visited:SourceFileNode = null;
		final usingKind = Estransforms.getUsingKindOfStatements(node.Statements.Nodes);
		if (usingKind != usingKindNone) {
			// Imports and exports must stay at the top level. This means we must hoist all imports, exports, and
			// top-level function declarations and bindings out of the `try` statements we generate. For example:
			//
			// given:
			//
			//  import { w } from "mod";
			//  const x = expr1;
			//  using y = expr2;
			//  const z = expr3;
			//  export function f() {
			//    console.log(z);
			//  }
			//
			// produces:
			//
			//  import { x } from "mod";        // <-- preserved
			//  const x = expr1;                // <-- preserved
			//  var y, z;                       // <-- hoisted
			//  export function f() {           // <-- hoisted
			//    console.log(z);
			//  }
			//  const env_1 = { stack: [], error: void 0, hasError: false };
			//  try {
			//    y = __addDisposableResource(env_1, expr2, false);
			//    z = expr3;
			//  }
			//  catch (e_1) {
			//    env_1.error = e_1;
			//    env_1.hasError = true;
			//  }
			//  finally {
			//    __disposeResource(env_1);
			//  }
			//
			// In this transformation, we hoist `y`, `z`, and `f` to a new outer statement list while moving all other
			// statements in the source file into the `try` block, which is the same approach we use for System module
			// emit. Unlike System module emit, we attempt to preserve all statements prior to the first top-level
			// `using` to isolate the complexity of the transformed output to only where it is necessary.
			EmitContext().StartVariableEnvironment();

			exportBindings = new StringMap<ExportSpecifierNode>();
			exportVars = null;

			final split = Factory().SplitStandardPrologue(node.Statements.Nodes);
			final prologue = split.a, rest = split.b;
			// PORT: pointer — Go passes &topLevelStatements; the Haxe array is shared by reference, so it starts non-null.
			final topLevelStatements:Array<Statement> = [];
			appendAll(topLevelStatements, Visitor().VisitSlice(prologue).a);

			// Collect and transform any leading statements up to the first `using` or `await using`. This preserves
			// the original statement order much as is possible.

			var pos = 0;
			while (pos < rest.length) {
				final statement = rest[pos];
				if (Estransforms.getUsingKind(statement) != usingKindNone) {
					if (pos > 0) {
						appendAll(topLevelStatements, Visitor().VisitSlice(rest.slice(0, pos)).a);
					}
					break;
				}
				pos++;
			}

			if (pos >= rest.length) {
				throw "Should have encountered at least one 'using' statement.";
			}

			// transform the rest of the body
			final envBinding = createEnvBinding();
			final bodyStatements = transformUsingDeclarations(rest.slice(pos), envBinding, topLevelStatements);

			// add `export {}` declarations for any hoisted bindings.
			if (exportBindings.keys().hasNext()) {
				final exportSpecifiers:Array<ExportSpecifierNode> = [];
				if (exportBindingNames != null) for (name in exportBindingNames) {
					final specifier = exportBindings.get(name);
					Debug.Assert(specifier != null, "Missing export binding for hoisted export name");
					exportSpecifiers.push(specifier);
				}
				topLevelStatements.push(
					Factory().NewExportDeclaration(
						null, /*modifiers*/
						false, /*isTypeOnly*/
						Factory().NewNamedExports(
							Factory().NewNodeList(
								exportSpecifiers
							)
						),
						null, /*moduleSpecifier*/
						null /*attributes*/
					)
				);
			}

			appendAll(topLevelStatements, EmitContext().EndVariableEnvironment());
			if (exportVars != null && exportVars.length > 0) {
				topLevelStatements.push(Factory().NewVariableStatement(
					Factory().NewModifierList([
						Factory().NewModifier(KindExportKeyword),
					]),
					Factory().NewVariableDeclarationList(
						Factory().NewNodeList(exportVars),
						NodeFlagsLet
					)
				));
			}
			appendAll(topLevelStatements, createDownlevelUsingStatements(bodyStatements, envBinding, usingKind == usingKindAsync));

			if (exportEqualsBinding != null) {
				topLevelStatements.push(Factory().NewExportAssignment(
					null, /*modifiers*/
					true, /*isExportEquals*/
					null, /*typeNode*/
					exportEqualsBinding
				));
			}

			visited = Factory().UpdateSourceFile(node, Factory().NewNodeList(topLevelStatements), node.EndOfFileToken);
		} else {
			visited = Visitor().VisitEachChild(node.AsNode());
		}
		EmitContext().AddEmitHelper(visited, ...EmitContext().ReadEmitHelpers());
		exportVars = null;
		exportBindings = null;
		exportBindingNames = null;
		defaultExportBinding = null;
		exportEqualsBinding = null;
		return visited;
	}

	// PORT: helper for Go `s = append(s, xs...)` on an owned slice where xs may be nil.
	static inline function appendAll(target:Array<Node>, xs:Array<Node>):Void {
		if (xs != null) for (x in xs) target.push(x);
	}

	function visitBlock(node:Block):Node {
		final usingKind = Estransforms.getUsingKindOfStatements(node.Statements.Nodes);
		if (usingKind != usingKindNone) {
			final split = Factory().SplitStandardPrologue(node.Statements.Nodes);
			final prologue = split.a, rest = split.b;
			final envBinding = createEnvBinding();
			final statements:Array<Statement> = [];
			appendAll(statements, Visitor().VisitSlice(prologue).a);
			appendAll(statements, createDownlevelUsingStatements(
				transformUsingDeclarations(rest, envBinding, null /*topLevelStatements*/),
				envBinding,
				usingKind == usingKindAsync
			));
			final statementList = Factory().NewNodeList(statements);
			statementList.Loc = node.Statements.Loc;
			return Factory().UpdateBlock(node, statementList, node.MultiLine);
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitForStatement(node:ForStatement):Node {
		if (node.Initializer != null && Estransforms.isUsingVariableDeclarationList(node.Initializer)) {
			// given:
			//
			//  for (using x = expr; cond; incr) { ... }
			//
			// produces a shallow transformation to:
			//
			//  {
			//    using x = expr;
			//    for (; cond; incr) { ... }
			//  }
			//
			// before handing the shallow transformation back to the visitor for an in-depth transformation.
			return Visitor().VisitNode(
				Factory().NewBlock(Factory().NewNodeList([
					Factory().NewVariableStatement(null /*modifiers*/, node.Initializer),
					Factory().UpdateForStatement(
						node,
						null, /*initializer*/
						node.Condition,
						node.Incrementor,
						node.Statement
					),
				]), false /*multiLine*/)
			);
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitForOfStatement(node:ForInOrOfStatement):Node {
		if (Estransforms.isUsingVariableDeclarationList(node.Initializer)) {
			// given:
			//
			//  for (using x of y) { ... }
			//
			// produces a shallow transformation to:
			//
			//  for (const x_1 of y) {
			//    using x = x;
			//    ...
			//  }
			//
			// before handing the shallow transformation back to the visitor for an in-depth transformation.
			final forInitializer = node.Initializer.AsVariableDeclarationList();
			var forDecl = Core.FirstOrNil(forInitializer.Declarations.Nodes);
			if (forDecl == null) {
				forDecl = Factory().NewVariableDeclaration(Factory().NewTempVariable(), null, null, null);
			}

			final isAwaitUsing = Estransforms.getUsingKindOfVariableDeclarationList(forInitializer) == usingKindAsync;
			final temp = Factory().NewGeneratedNameForNode(forDecl.Name());
			final usingVar = Factory().UpdateVariableDeclaration(forDecl.AsVariableDeclaration(), forDecl.Name(), null /*exclamationToken*/, null /*type*/, temp);
			final usingVarList = Factory().NewVariableDeclarationList(
				Factory().NewNodeList([usingVar]),
				Core.IfElse(isAwaitUsing, NodeFlagsAwaitUsing, NodeFlagsUsing)
			);
			final usingVarStatement = Factory().NewVariableStatement(null /*modifiers*/, usingVarList);
			var statement:Statement = null;
			if (Ast.IsBlock(node.Statement)) {
				final statements:Array<Statement> = [];
				statements.push(usingVarStatement);
				appendAll(statements, node.Statement.Statements());
				statement = Factory().UpdateBlock(
					node.Statement.AsBlock(),
					Factory().NewNodeList(statements),
					node.Statement.AsBlock().MultiLine
				);
			} else {
				statement = Factory().NewBlock(
					Factory().NewNodeList([
						usingVarStatement,
						node.Statement,
					]),
					true /*multiLine*/
				);
			}
			return Visitor().VisitNode(
				Factory().UpdateForInOrOfStatement(
					node,
					node.AwaitModifier,
					Factory().NewVariableDeclarationList(
						Factory().NewNodeList([
							Factory().NewVariableDeclaration(temp, null /*exclamationToken*/, null /*type*/, null),
						]),
						NodeFlagsConst
					),
					node.Expression,
					statement
				)
			);
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function transformUsingDeclarations(statementsIn:Array<Statement>, envBinding:IdentifierNode, topLevelStatements:Array<Statement>):Array<Node> {
		var statements:Array<Statement> = null;

		final hoist = function(node:Statement):Statement {
			if (topLevelStatements == null) {
				return node;
			}

			switch (node.Kind) {
				case KindImportDeclaration, KindImportEqualsDeclaration, KindExportDeclaration, KindFunctionDeclaration:
					hoistImportOrExportOrHoistedDeclaration(node, topLevelStatements);
					return null;
				case KindExportAssignment:
					return hoistExportAssignment(node.AsExportAssignment());
				case KindClassDeclaration:
					return hoistClassDeclaration(node.AsClassDeclaration());
				case KindVariableStatement:
					return hoistVariableStatement(node.AsVariableStatement());
				default:
			}

			return node;
		};

		final hoistOrAppendNode = function(node:Node):Void {
			node = hoist(node);
			if (node != null) {
				if (statements == null) statements = [];
				statements.push(node);
			}
		};

		if (statementsIn != null) for (statement in statementsIn) {
			final usingKind = Estransforms.getUsingKind(statement);
			if (usingKind != usingKindNone) {
				final varStatement = statement.AsVariableStatement();
				final declarationList = varStatement.DeclarationList;
				var declarations:Array<VariableDeclarationNode> = null;
				for (declaration_ in declarationList.AsVariableDeclarationList().Declarations.Nodes) {
					var declaration = declaration_;
					if (!Ast.IsIdentifier(declaration.Name())) {
						// Since binding patterns are a grammar error, we reset `declarations` so we don't process this as a `using`.
						declarations = null;
						break;
					}

					// perform a shallow transform for any named evaluation
					if (Estransforms.isNamedEvaluation(EmitContext(), declaration)) {
						declaration = Estransforms.transformNamedEvaluation(EmitContext(), declaration, false /*ignoreEmptyStringLiteral*/, "" /*assignedName*/);
					}

					var initializer = Visitor().VisitNode(declaration.Initializer());
					if (initializer == null) {
						initializer = Factory().NewVoidZeroExpression();
					}
					if (declarations == null) declarations = [];
					declarations.push(Factory().UpdateVariableDeclaration(
						declaration.AsVariableDeclaration(),
						declaration.Name(),
						null, /*exclamationToken*/
						null, /*type*/
						Factory().NewAddDisposableResourceHelper(
							envBinding,
							initializer,
							usingKind == usingKindAsync
						)
					));
				}

				// Only replace the statement if it was valid.
				if (declarations != null && declarations.length > 0) {
					final varList = Factory().NewVariableDeclarationList(Factory().NewNodeList(declarations), NodeFlagsConst);
					EmitContext().SetOriginal(varList, declarationList);
					varList.Loc = declarationList.Loc;
					hoistOrAppendNode(Factory().UpdateVariableStatement(varStatement, null /*modifiers*/, varList));
					continue;
				}
			}

			final result = visit(statement);
			if (result != null) {
				if (result.Kind == KindSyntaxList) {
					final children = result.AsSyntaxList().Children;
					if (children != null) for (node in children) { // PORT: range over possibly-nil slice
						hoistOrAppendNode(node);
					}
				} else {
					hoistOrAppendNode(result);
				}
			}
		}
		return statements;
	}

	function hoistImportOrExportOrHoistedDeclaration(node:Statement, topLevelStatements:Array<Statement>):Void {
		// NOTE: `node` has already been visited
		topLevelStatements.push(node);
	}

	function hoistExportAssignment(node:ExportAssignment):Statement {
		if (node.IsExportEquals) {
			return hoistExportEquals(node);
		} else {
			return hoistExportDefault(node);
		}
	}

	function hoistExportDefault(node:ExportAssignment):Statement {
		// NOTE: `node` has already been visited
		if (defaultExportBinding != null) {
			// invalid case of multiple `export default` declarations. Don't assert here, just pass it through
			return node.AsNode();
		}

		// given:
		//
		//   export default expr;
		//
		// produces:
		//
		//   // top level
		//   var default_1;
		//   export { default_1 as default };
		//
		//   // body
		//   default_1 = expr;

		defaultExportBinding = Factory().NewUniqueNameEx("_default", new AutoGenerateOptions(GeneratedIdentifierFlagsReservedInNestedScopes | GeneratedIdentifierFlagsFileLevel | GeneratedIdentifierFlagsOptimistic));
		hoistBindingIdentifier(defaultExportBinding /*isExport*/, true, Factory().NewIdentifier("default"), node.AsNode());

		// give a class or function expression an assigned name, if needed.
		var expression = node.Expression;
		var innerExpression = Ast.SkipOuterExpressions(expression, OEKAll);
		if (Estransforms.isNamedEvaluation(EmitContext(), innerExpression)) {
			innerExpression = Estransforms.transformNamedEvaluation(EmitContext(), innerExpression /*ignoreEmptyStringLiteral*/, false, "default");
			expression = Factory().RestoreOuterExpressions(expression, innerExpression, OEKAll);
		}

		final assignment = Factory().NewAssignmentExpression(defaultExportBinding, expression);
		return Factory().NewExpressionStatement(assignment);
	}

	function hoistExportEquals(node:ExportAssignment):Statement {
		// NOTE: `node` has already been visited
		if (exportEqualsBinding != null) {
			// invalid case of multiple `export default` declarations. Don't assert here, just pass it through
			return node.AsNode();
		}

		// given:
		//
		//   export = expr;
		//
		// produces:
		//
		//   // top level
		//   var default_1;
		//
		//   try {
		//       // body
		//       default_1 = expr;
		//   } ...
		//
		//   // top level suffix
		//   export = default_1;

		exportEqualsBinding = Factory().NewUniqueNameEx("_default", new AutoGenerateOptions(GeneratedIdentifierFlagsReservedInNestedScopes | GeneratedIdentifierFlagsFileLevel | GeneratedIdentifierFlagsOptimistic));
		EmitContext().AddVariableDeclaration(exportEqualsBinding);

		// give a class or function expression an assigned name, if needed.
		final assignment = Factory().NewAssignmentExpression(exportEqualsBinding, node.Expression);
		return Factory().NewExpressionStatement(assignment);
	}

	function hoistClassDeclaration(node:ClassDeclaration):Statement {
		// NOTE: `node` has already been visited
		if (node.AsNode().Name() == null && defaultExportBinding != null) {
			// invalid case of multiple `export default` declarations. Don't assert here, just pass it through
			return node.AsNode();
		}

		final isExported = Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsExport);
		final isDefault = Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsDefault);

		// When hoisting a class declaration at the top level of a file containing a top-level `using` statement, we
		// must first convert it to a class expression so that we can hoist the binding outside of the `try`.
		var expression = Estransforms.convertClassDeclarationToClassExpression(EmitContext(), node);
		if (node.AsNode().Name() != null) {
			// given:
			//
			//  using x = expr;
			//  class C {}
			//
			// produces:
			//
			//  var x, C;
			//  const env_1 = { ... };
			//  try {
			//    x = __addDisposableResource(env_1, expr, false);
			//    C = class {};
			//  }
			//  catch (e_1) {
			//    env_1.error = e_1;
			//    env_1.hasError = true;
			//  }
			//  finally {
			//    __disposeResources(env_1);
			//  }
			//
			// If the class is exported, we also produce an `export { C };`
			hoistBindingIdentifier(Factory().GetLocalName(node.AsNode()), isExported && !isDefault, null /*exportAlias*/, node.AsNode());
			expression = Factory().NewAssignmentExpression(Factory().GetDeclarationName(node.AsNode()), expression);
			EmitContext().SetOriginal(expression, node.AsNode());
			EmitContext().SetSourceMapRange(expression, node.Loc);
			EmitContext().SetCommentRange(expression, node.Loc);
			if (Estransforms.isNamedEvaluation(EmitContext(), expression)) {
				expression = Estransforms.transformNamedEvaluation(EmitContext(), expression, false /*ignoreEmptyStringLiteral*/, "" /*assignedName*/);
			}
		}

		if (isDefault && defaultExportBinding == null) {
			// In the case of a default export, we create a temporary variable that we export as the default and then
			// assign to that variable.
			//
			// given:
			//
			//  using x = expr;
			//  export default class C {}
			//
			// produces:
			//
			//  export { default_1 as default };
			//  var x, C, default_1;
			//  const env_1 = { ... };
			//  try {
			//    x = __addDisposableResource(env_1, expr, false);
			//    default_1 = C = class {};
			//  }
			//  catch (e_1) {
			//    env_1.error = e_1;
			//    env_1.hasError = true;
			//  }
			//  finally {
			//    __disposeResources(env_1);
			//  }
			//
			// Though we will never reassign `default_1`, this most closely matches the specified runtime semantics.
			defaultExportBinding = Factory().NewUniqueNameEx("_default", new AutoGenerateOptions(GeneratedIdentifierFlagsReservedInNestedScopes | GeneratedIdentifierFlagsFileLevel | GeneratedIdentifierFlagsOptimistic));
			hoistBindingIdentifier(defaultExportBinding /*isExport*/, true, Factory().NewIdentifier("default"), node.AsNode());
			expression = Factory().NewAssignmentExpression(defaultExportBinding, expression);
			EmitContext().SetOriginal(expression, node.AsNode());
			if (Estransforms.isNamedEvaluation(EmitContext(), expression)) {
				expression = Estransforms.transformNamedEvaluation(EmitContext(), expression /*ignoreEmptyStringLiteral*/, false, "default");
			}
		}

		return Factory().NewExpressionStatement(expression);
	}

	function hoistVariableStatement(node:VariableStatement):Statement {
		// NOTE: `node` has already been visited
		var expressions:Array<Expression> = null;
		final isExported = Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsExport);
		for (variable in node.DeclarationList.AsVariableDeclarationList().Declarations.Nodes) {
			hoistBindingElement(variable, isExported, variable);
			if (variable.Initializer() != null) {
				if (expressions == null) expressions = [];
				expressions.push(hoistInitializedVariable(variable.AsVariableDeclaration()));
			}
		}
		if (expressions != null && expressions.length > 0) {
			final statement = Factory().NewExpressionStatement(Factory().InlineExpressions(expressions));
			EmitContext().SetOriginal(statement, node.AsNode());
			EmitContext().SetCommentRange(statement, node.Loc);
			EmitContext().SetSourceMapRange(statement, node.Loc);
			return statement;
		}
		return null;
	}

	function hoistInitializedVariable(node:VariableDeclaration):Expression {
		// NOTE: `node` has already been visited
		if (node.Initializer == null) {
			throw "Expected initializer";
		}
		var target:Expression = null;
		if (Ast.IsIdentifier(node.AsNode().Name())) {
			target = node.AsNode().Name().Clone(Factory());
			EmitContext().SetEmitFlags(target, EmitContext().EmitFlags(target) & ~(EFLocalName | EFExportName));
		} else {
			target = Transformers.ConvertBindingPatternToAssignmentPattern(EmitContext(), node.AsNode().Name().AsBindingPattern());
		}

		final assignment = Factory().NewAssignmentExpression(target, node.Initializer);
		EmitContext().SetOriginal(assignment, node.AsNode());
		EmitContext().SetCommentRange(assignment, node.Loc);
		EmitContext().SetSourceMapRange(assignment, node.Loc);
		return assignment;
	}

	function hoistBindingElement(node:Node /*VariableDeclaration|BindingElement*/, isExportedDeclaration:Bool, original:Node):Void {
		// NOTE: `node` has already been visited
		if (Ast.IsBindingPattern(node.Name())) {
			for (element in node.Name().Elements()) {
				if (element.Name() != null) {
					hoistBindingElement(element, isExportedDeclaration, original);
				}
			}
		} else {
			hoistBindingIdentifier(node.Name(), isExportedDeclaration, null /*exportAlias*/, original);
		}
	}

	function hoistBindingIdentifier(node:IdentifierNode, isExport:Bool, exportAlias:IdentifierNode, original:Node):Void {
		// NOTE: `node` has already been visited
		var name = node;
		if (!Transformers.IsGeneratedIdentifier(EmitContext(), node)) {
			name = name.Clone(Factory());
		}
		if (isExport) {
			if (exportAlias == null && !Transformers.IsLocalName(EmitContext(), name)) {
				final varDecl = Factory().NewVariableDeclaration(name, null /*exclamationToken*/, null /*type*/, null /*initializer*/);
				if (original != null) {
					EmitContext().SetOriginal(varDecl, original);
				}
				if (exportVars == null) exportVars = [];
				exportVars.push(varDecl);
				return;
			}

			var localName:ModuleExportName = null;
			var exportName:ModuleExportName = null;
			if (exportAlias != null) {
				localName = name;
				exportName = exportAlias;
			} else {
				exportName = name;
			}
			final specifier = Factory().NewExportSpecifier(/*isTypeOnly*/ false, localName, exportName);
			if (original != null) {
				EmitContext().SetOriginal(specifier, original);
			}
			if (exportBindings == null) {
				exportBindings = new StringMap<ExportSpecifierNode>();
			}
			if (!exportBindings.exists(name.Text())) {
				if (exportBindingNames == null) exportBindingNames = [];
				exportBindingNames.push(name.Text());
			}
			exportBindings.set(name.Text(), specifier);
		}
		EmitContext().AddVariableDeclaration(name);
	}

	function createEnvBinding():IdentifierNode {
		return Factory().NewUniqueName("env");
	}

	function createDownlevelUsingStatements(bodyStatements:Array<Node>, envBinding:IdentifierNode, async:Bool):Array<Statement> {
		final statements:Array<Statement> = [];

		// produces:
		//
		//  const env_1 = { stack: [], error: void 0, hasError: false };
		//
		final envObject = Factory().NewObjectLiteralExpression(Factory().NewNodeList([
			Factory().NewPropertyAssignment(null /*modifiers*/, Factory().NewIdentifier("stack"), null /*postfixToken*/, null /*typeNode*/, Factory().NewArrayLiteralExpression(null, false /*multiLine*/)),
			Factory().NewPropertyAssignment(null /*modifiers*/, Factory().NewIdentifier("error"), null /*postfixToken*/, null /*typeNode*/, Factory().NewVoidZeroExpression()),
			Factory().NewPropertyAssignment(null /*modifiers*/, Factory().NewIdentifier("hasError"), null /*postfixToken*/, null /*typeNode*/, Factory().NewFalseExpression()),
		]), false /*multiLine*/);
		final envVar = Factory().NewVariableDeclaration(envBinding, null /*exclamationToken*/, null /*typeNode*/, envObject);
		final envVarList = Factory().NewVariableDeclarationList(Factory().NewNodeList([envVar]), NodeFlagsConst);
		final envVarStatement = Factory().NewVariableStatement(null /*modifiers*/, envVarList);
		statements.push(envVarStatement);

		// when `async` is `false`, produces:
		//
		//  try {
		//    <bodyStatements>
		//  }
		//  catch (e_1) {
		//      env_1.error = e_1;
		//      env_1.hasError = true;
		//  }
		//  finally {
		//    __disposeResources(env_1);
		//  }

		// when `async` is `true`, produces:
		//
		//  try {
		//    <bodyStatements>
		//  }
		//  catch (e_1) {
		//      env_1.error = e_1;
		//      env_1.hasError = true;
		//  }
		//  finally {
		//    const result_1 = __disposeResources(env_1);
		//    if (result_1) {
		//      await result_1;
		//    }
		//  }

		// Unfortunately, it is necessary to use two properties to indicate an error because `throw undefined` is legal
		// JavaScript.
		final tryBlock = Factory().NewBlock(Factory().NewNodeList(bodyStatements), true /*multiLine*/);
		final bodyCatchBinding = Factory().NewUniqueName("e");
		final catchClause = Factory().NewCatchClause(
			Factory().NewVariableDeclaration(
				bodyCatchBinding,
				null, /*exclamationToken*/
				null, /*type*/
				null /*initializer*/
			),
			Factory().NewBlock(Factory().NewNodeList([
				Factory().NewExpressionStatement(
					Factory().NewAssignmentExpression(
						Factory().NewPropertyAccessExpression(envBinding, null, Factory().NewIdentifier("error"), NodeFlagsNone),
						bodyCatchBinding
					)
				),
				Factory().NewExpressionStatement(
					Factory().NewAssignmentExpression(
						Factory().NewPropertyAccessExpression(envBinding, null, Factory().NewIdentifier("hasError"), NodeFlagsNone),
						Factory().NewTrueExpression()
					)
				),
			]), true /*multiLine*/)
		);

		var finallyBlock:BlockNode = null;
		if (async) {
			final result = Factory().NewUniqueName("result");
			finallyBlock = Factory().NewBlock(Factory().NewNodeList([
				Factory().NewVariableStatement(
					null, /*modifiers*/
					Factory().NewVariableDeclarationList(Factory().NewNodeList([
						Factory().NewVariableDeclaration(
							result,
							null, /*exclamationToken*/
							null, /*type*/
							Factory().NewDisposeResourcesHelper(envBinding)
						),
					]), NodeFlagsConst)
				),
				Factory().NewIfStatement(result, Factory().NewExpressionStatement(Factory().NewAwaitExpression(result)), null /*elseStatement*/),
			]), true /*multiLine*/);
		} else {
			finallyBlock = Factory().NewBlock(Factory().NewNodeList([
				Factory().NewExpressionStatement(
					Factory().NewDisposeResourcesHelper(envBinding)
				),
			]), true /*multiLine*/);
		}

		final tryStatement = Factory().NewTryStatement(tryBlock, catchClause, finallyBlock);
		statements.push(tryStatement);
		return statements;
	}
}

enum abstract UsingKind(Int) from Int to Int {
	var usingKindNone = 0;
	var usingKindSync = 1;
	var usingKindAsync = 2;
}

