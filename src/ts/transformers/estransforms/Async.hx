package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/async.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).
import ts.printer.Generatedidentifierflags.GeneratedIdentifierFlags.*;

enum abstract AsyncContextFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:AsyncContextFlags, b:AsyncContextFlags):AsyncContextFlags;
	@:op(A & B) static function and(a:AsyncContextFlags, b:AsyncContextFlags):AsyncContextFlags;
	@:op(~A) static function not(a:AsyncContextFlags):AsyncContextFlags;

	var asyncContextNonTopLevel = 1 << 0;
	var asyncContextHasLexicalThis = 1 << 1;
}

@:allow(ts.transformers.estransforms)
class LexicalArgumentsInfo {
	var binding:IdentifierNode = null;
	var used:Bool = false;

	public function new() {}

	// PORT: Go value type; explicit copy where Go copies and the original is later mutated.
	public function copy():LexicalArgumentsInfo {
		final c = new LexicalArgumentsInfo();
		c.binding = binding;
		c.used = used;
		return c;
	}
}

@:allow(ts.transformers.estransforms)
class AsyncTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var superAccessState:SuperAccessState = new SuperAccessState(); // Go: embedded
	var contextFlags:AsyncContextFlags = 0;
	var enclosingFunctionParameterNames:Set<std.String> = null;
	var lexicalArguments:LexicalArgumentsInfo = new LexicalArgumentsInfo();
	var asyncBodyVisitor:NodeVisitor = null;
	var fallbackNodeVisitor:NodeVisitor = null;

	public function new() {}

	// PORT: promoted methods of the embedded transformers.Transformer.
	inline function Visitor():NodeVisitor return Transformer.Visitor();
	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();
	inline function EmitContext():EmitContext return Transformer.EmitContext();

	// PORT: Go method expressions `(*asyncTransformer).visitX`, created once (PORTING §7a).
	static final visitMethodDeclarationFn:(AsyncTransformer, Node) -> Node = (tx, node) -> tx.visitMethodDeclaration(node);
	static final visitFunctionDeclarationFn:(AsyncTransformer, Node) -> Node = (tx, node) -> tx.visitFunctionDeclaration(node);
	static final visitFunctionExpressionFn:(AsyncTransformer, Node) -> Node = (tx, node) -> tx.visitFunctionExpression(node);
	static final visitArrowFunctionFn:(AsyncTransformer, Node) -> Node = (tx, node) -> tx.visitArrowFunction(node);
	static final visitGetAccessorDeclarationFn:(AsyncTransformer, Node) -> Node = (tx, node) -> tx.visitGetAccessorDeclaration(node);
	static final visitSetAccessorDeclarationFn:(AsyncTransformer, Node) -> Node = (tx, node) -> tx.visitSetAccessorDeclaration(node);
	static final visitConstructorDeclarationFn:(AsyncTransformer, Node) -> Node = (tx, node) -> tx.visitConstructorDeclaration(node);
	static final visitDefaultFn:(AsyncTransformer, Node) -> Node = (tx, node) -> tx.visitDefault(node);

	function visitSourceFile(node:SourceFile):Node {
		if (node.IsDeclarationFile) {
			return node.AsNode();
		}

		setContextFlag(asyncContextNonTopLevel, false);
		setContextFlag(asyncContextHasLexicalThis, false);
		final visited = Visitor().VisitEachChild(node.AsNode());
		// PORT: Go spreads a possibly-nil slice; a Haxe spread of null throws.
		final helpers = EmitContext().ReadEmitHelpers();
		if (helpers != null) {
			EmitContext().AddEmitHelper(visited, ...helpers);
		} else {
			EmitContext().AddEmitHelper(visited);
		}
		return visited;
	}

	function setContextFlag(flag:AsyncContextFlags, val:Bool):Void {
		if (val) {
			contextFlags |= flag;
		} else {
			contextFlags = contextFlags & ~flag;
		}
	}

	function inContext(flags:AsyncContextFlags):Bool {
		return (contextFlags & flags) != 0;
	}

	function inTopLevelContext():Bool {
		return !inContext(asyncContextNonTopLevel);
	}

	function inHasLexicalThisContext():Bool {
		return inContext(asyncContextHasLexicalThis);
	}

	function doWithContext(flags:AsyncContextFlags, cb:(AsyncTransformer, Node) -> Node, node:Node):Node {
		final flagsToSet = flags & ~contextFlags;
		if (flagsToSet != 0) {
			setContextFlag(flagsToSet, true);
			final result = cb(this, node);
			setContextFlag(flagsToSet, false);
			return result;
		}
		return cb(this, node);
	}

	function visitDefault(node:Node):Node {
		return Visitor().VisitEachChild(node);
	}

	function fallbackVisitor(node:Node):Node {
		if (superAccessState.capturedSuperProperties == null && lexicalArguments.binding == null) {
			return node;
		}
		superAccessState.trackSuperAccess(node);
		switch (node.Kind) {
			case KindFunctionExpression, KindFunctionDeclaration, KindMethodDeclaration, KindGetAccessor, KindSetAccessor, KindConstructor:
				return node;
			case KindParameter, KindBindingElement, KindVariableDeclaration:
				// fall through to visitEachChild
			case KindIdentifier:
				if (lexicalArguments.binding != null && node.Text() == "arguments" && !Ast.IsIdentifierName(node) && !Ast.IsLabelName(node)) {
					lexicalArguments.used = true;
					return lexicalArguments.binding;
				}
			default:
		}
		return fallbackNodeVisitor.VisitEachChild(node);
	}

	function visitFallback(node:Node):Node {
		return fallbackVisitor(node);
	}

	function visit(node:Node):Node {
		// PORT: defer — the deferred restore runs at the single exit below.
		var restoreHasLexicalThis = false;
		if ((EmitContext().EmitFlags(node) & EFNoLexicalThis) != 0 && inHasLexicalThisContext()) {
			setContextFlag(asyncContextHasLexicalThis, false);
			restoreHasLexicalThis = true;
		}

		var result:Node;
		if ((node.SubtreeFacts() & (SubtreeContainsAnyAwait | SubtreeContainsAwait)) == 0) {
			result = fallbackVisitor(node);
		} else {
			superAccessState.trackSuperAccess(node);
			switch (node.Kind) {
				case KindAsyncKeyword:
					// ES2017 async modifier should be elided for targets < ES2017
					result = null;
				case KindSourceFile:
					result = visitSourceFile(node.AsSourceFile());
				case KindAwaitExpression:
					result = visitAwaitExpression(node.AsAwaitExpression());
				case KindMethodDeclaration:
					result = doWithContext(asyncContextNonTopLevel | asyncContextHasLexicalThis, visitMethodDeclarationFn, node);
				case KindFunctionDeclaration:
					result = doWithContext(asyncContextNonTopLevel | asyncContextHasLexicalThis, visitFunctionDeclarationFn, node);
				case KindFunctionExpression:
					result = doWithContext(asyncContextNonTopLevel | asyncContextHasLexicalThis, visitFunctionExpressionFn, node);
				case KindArrowFunction:
					result = doWithContext(asyncContextNonTopLevel, visitArrowFunctionFn, node);
				case KindGetAccessor:
					result = doWithContext(asyncContextNonTopLevel | asyncContextHasLexicalThis, visitGetAccessorDeclarationFn, node);
				case KindSetAccessor:
					result = doWithContext(asyncContextNonTopLevel | asyncContextHasLexicalThis, visitSetAccessorDeclarationFn, node);
				case KindConstructor:
					result = doWithContext(asyncContextNonTopLevel | asyncContextHasLexicalThis, visitConstructorDeclarationFn, node);
				case KindClassDeclaration, KindClassExpression:
					result = doWithContext(asyncContextNonTopLevel | asyncContextHasLexicalThis, visitDefaultFn, node);
				default:
					result = Visitor().VisitEachChild(node);
			}
		}

		if (restoreHasLexicalThis) {
			setContextFlag(asyncContextHasLexicalThis, true);
		}
		return result;
	}

	function visitAsyncBodyNode(node:Node):Node {
		if (Estransforms.isNodeWithPossibleHoistedDeclaration(node)) {
			switch (node.Kind) {
				case KindVariableStatement:
					return visitVariableStatementInAsyncBody(node);
				case KindForStatement:
					return visitForStatementInAsyncBody(node.AsForStatement());
				case KindForInStatement:
					return visitForInStatementInAsyncBody(node.AsForInOrOfStatement());
				case KindForOfStatement:
					return visitForOfStatementInAsyncBody(node.AsForInOrOfStatement());
				case KindCatchClause:
					return visitCatchClauseInAsyncBody(node.AsCatchClause());
				case KindBlock, KindSwitchStatement, KindCaseBlock, KindCaseClause, KindDefaultClause, KindTryStatement, KindDoStatement,
					KindWhileStatement, KindIfStatement, KindWithStatement, KindLabeledStatement:
					return asyncBodyVisitor.VisitEachChild(node);
				default:
			}
		}
		return visit(node);
	}

	function visitCatchClauseInAsyncBody(node:CatchClause):Node {
		final catchClauseNames = new Set<std.String>();
		if (node.VariableDeclaration != null) {
			recordDeclarationName(node.VariableDeclaration, catchClauseNames);
		}

		// names declared in a catch variable are block scoped
		var catchClauseUnshadowedNames:Set<std.String> = null;
		for (escapedName in catchClauseNames.Keys().keys()) {
			if (enclosingFunctionParameterNames != null && enclosingFunctionParameterNames.Has(escapedName)) {
				if (catchClauseUnshadowedNames == null) {
					catchClauseUnshadowedNames = enclosingFunctionParameterNames.Clone();
				}
				catchClauseUnshadowedNames.Delete(escapedName);
			}
		}

		if (catchClauseUnshadowedNames != null) {
			final savedEnclosingFunctionParameterNames = enclosingFunctionParameterNames;
			enclosingFunctionParameterNames = catchClauseUnshadowedNames;
			final result = asyncBodyVisitor.VisitEachChild(node.AsNode());
			enclosingFunctionParameterNames = savedEnclosingFunctionParameterNames;
			return result;
		}
		return asyncBodyVisitor.VisitEachChild(node.AsNode());
	}

	function visitVariableStatementInAsyncBody(node:Node):Node {
		final declList = node.AsVariableStatement().DeclarationList;
		if (isVariableDeclarationListWithCollidingName(declList)) {
			final expression = visitVariableDeclarationListWithCollidingNames(declList.AsVariableDeclarationList(), false);
			if (expression != null) {
				return Factory().NewExpressionStatement(expression);
			}
			return null;
		}
		return Visitor().VisitEachChild(node);
	}

	function visitForInStatementInAsyncBody(node:ForInOrOfStatement):Node {
		var visitedInitializer:Node = null;
		if (isVariableDeclarationListWithCollidingName(node.Initializer)) {
			visitedInitializer = visitVariableDeclarationListWithCollidingNames(node.Initializer.AsVariableDeclarationList(), true);
		} else {
			visitedInitializer = Visitor().VisitNode(node.Initializer);
		}

		return Factory().UpdateForInOrOfStatement(node, null, /*awaitModifier*/
			visitedInitializer, Visitor().VisitNode(node.Expression), asyncBodyVisitor.VisitEmbeddedStatement(node.Statement));
	}

	function visitForOfStatementInAsyncBody(node:ForInOrOfStatement):Node {
		var visitedInitializer:Node = null;
		if (isVariableDeclarationListWithCollidingName(node.Initializer)) {
			visitedInitializer = visitVariableDeclarationListWithCollidingNames(node.Initializer.AsVariableDeclarationList(), true);
		} else {
			visitedInitializer = Visitor().VisitNode(node.Initializer);
		}

		return Factory().UpdateForInOrOfStatement(node, Visitor().VisitNode(node.AwaitModifier), visitedInitializer, Visitor().VisitNode(node.Expression),
			asyncBodyVisitor.VisitEmbeddedStatement(node.Statement));
	}

	function visitForStatementInAsyncBody(node:ForStatement):Node {
		final initializer = node.Initializer;
		var visitedInitializer:Node = null;
		if (initializer != null && isVariableDeclarationListWithCollidingName(initializer)) {
			visitedInitializer = visitVariableDeclarationListWithCollidingNames(initializer.AsVariableDeclarationList(), false);
		} else {
			visitedInitializer = Visitor().VisitNode(node.Initializer);
		}

		return Factory().UpdateForStatement(node, visitedInitializer, Visitor().VisitNode(node.Condition), Visitor().VisitNode(node.Incrementor),
			asyncBodyVisitor.VisitEmbeddedStatement(node.Statement));
	}

	// visitAwaitExpression visits an AwaitExpression node.
	//
	// This function will be called any time a ES2017 await expression is encountered.
	function visitAwaitExpression(node:AwaitExpression):Node {
		// do not downlevel a top-level await as it is module syntax...
		if (inTopLevelContext()) {
			return Visitor().VisitEachChild(node.AsNode());
		}
		final yieldExpr = Factory().NewYieldExpression(null, /*asteriskToken*/
			Visitor().VisitNode(node.Expression));
		yieldExpr.Loc = node.Loc;
		EmitContext().SetOriginal(yieldExpr, node.AsNode());
		return yieldExpr;
	}

	function visitConstructorDeclaration(node:Node):Node {
		final decl = node.AsConstructorDeclaration();
		final savedLexicalArguments = lexicalArguments;
		lexicalArguments = new LexicalArgumentsInfo();
		final updated = Factory().UpdateConstructorDeclaration(decl, Visitor().VisitModifiers(decl.Modifiers()), null, /*typeParameters*/
			EmitContext().VisitParameters(decl.Parameters, Visitor()), null, /*returnType*/ null, /*fullSignature*/ transformMethodBody(node));
		lexicalArguments = savedLexicalArguments;
		return updated;
	}

	// visitMethodDeclaration visits a MethodDeclaration node.
	//
	// This function will be called when one of the following conditions are met:
	// - The node is marked as async
	function visitMethodDeclaration(node:Node):Node {
		final decl = node.AsMethodDeclaration();
		final functionFlags = Ast.GetFunctionFlags(node);
		final savedLexicalArguments = lexicalArguments;
		lexicalArguments = new LexicalArgumentsInfo();

		var parameters:NodeList = null;
		var body:Node = null;
		if ((functionFlags & FunctionFlagsAsync) != 0) {
			parameters = transformAsyncFunctionParameterList(node);
			body = transformAsyncFunctionBody(node, parameters);
		} else {
			parameters = EmitContext().VisitParameters(decl.Parameters, Visitor());
			body = transformMethodBody(node);
		}

		final updated = Factory().UpdateMethodDeclaration(decl, Visitor().VisitModifiers(decl.Modifiers()), decl.AsteriskToken, decl.Name(), null, /*postfixToken*/
			null, /*typeParameters*/ parameters, null, /*returnType*/ null, /*fullSignature*/ body);
		lexicalArguments = savedLexicalArguments;
		return updated;
	}

	function visitGetAccessorDeclaration(node:Node):Node {
		final decl = node.AsGetAccessorDeclaration();
		final savedLexicalArguments = lexicalArguments;
		lexicalArguments = new LexicalArgumentsInfo();
		final updated = Factory().UpdateGetAccessorDeclaration(decl, Visitor().VisitModifiers(decl.Modifiers()), decl.Name(), null, /*typeParameters*/
			EmitContext().VisitParameters(decl.Parameters, Visitor()), null, /*returnType*/ null, /*fullSignature*/ transformMethodBody(node));
		lexicalArguments = savedLexicalArguments;
		return updated;
	}

	function visitSetAccessorDeclaration(node:Node):Node {
		final decl = node.AsSetAccessorDeclaration();
		final savedLexicalArguments = lexicalArguments;
		lexicalArguments = new LexicalArgumentsInfo();
		final updated = Factory().UpdateSetAccessorDeclaration(decl, Visitor().VisitModifiers(decl.Modifiers()), decl.Name(), null, /*typeParameters*/
			EmitContext().VisitParameters(decl.Parameters, Visitor()), null, /*returnType*/ null, /*fullSignature*/ transformMethodBody(node));
		lexicalArguments = savedLexicalArguments;
		return updated;
	}

	// visitFunctionDeclaration visits a FunctionDeclaration node.
	//
	// This function will be called when one of the following conditions are met:
	// - The node is marked async
	function visitFunctionDeclaration(node:Node):Node {
		final decl = node.AsFunctionDeclaration();
		final functionFlags = Ast.GetFunctionFlags(node);
		final savedLexicalArguments = lexicalArguments;
		lexicalArguments = new LexicalArgumentsInfo();

		var parameters:NodeList = null;
		var body:Node = null;
		if ((functionFlags & FunctionFlagsAsync) != 0) {
			parameters = transformAsyncFunctionParameterList(node);
			body = transformAsyncFunctionBody(node, parameters);
		} else {
			parameters = EmitContext().VisitParameters(decl.Parameters, Visitor());
			body = EmitContext().VisitFunctionBody(decl.Body, Visitor());
		}

		final updated = Factory().UpdateFunctionDeclaration(decl, Visitor().VisitModifiers(decl.Modifiers()), decl.AsteriskToken, Visitor().VisitNode(decl.Name()),
			null, /*typeParameters*/ parameters, null, /*returnType*/ null, /*fullSignature*/ body);
		lexicalArguments = savedLexicalArguments;
		return updated;
	}

	// visitFunctionExpression visits a FunctionExpression node.
	//
	// This function will be called when one of the following conditions are met:
	// - The node is marked async
	function visitFunctionExpression(node:Node):Node {
		final decl = node.AsFunctionExpression();
		final functionFlags = Ast.GetFunctionFlags(node);
		final savedLexicalArguments = lexicalArguments;
		lexicalArguments = new LexicalArgumentsInfo();

		var parameters:NodeList = null;
		var body:Node = null;
		if ((functionFlags & FunctionFlagsAsync) != 0) {
			parameters = transformAsyncFunctionParameterList(node);
			body = transformAsyncFunctionBody(node, parameters);
		} else {
			parameters = EmitContext().VisitParameters(decl.Parameters, Visitor());
			body = EmitContext().VisitFunctionBody(decl.Body, Visitor());
		}

		final updated = Factory().UpdateFunctionExpression(decl, Visitor().VisitModifiers(decl.Modifiers()), decl.AsteriskToken, Visitor().VisitNode(decl.Name()),
			null, /*typeParameters*/ parameters, null, /*returnType*/ null, /*fullSignature*/ body);
		lexicalArguments = savedLexicalArguments;
		return updated;
	}

	// visitArrowFunction visits an ArrowFunction.
	//
	// This function will be called when one of the following conditions are met:
	// - The node is marked async
	function visitArrowFunction(node:Node):Node {
		// `arguments` in class static blocks is always an error, but we preserve Strada's emit
		// behavior for baseline compatibility. In Strada, checker-based `isArgumentsLocalBinding`
		// returns false for `arguments` in static blocks (since the binding doesn't exist due to
		// the error), so the async transform leaves them untouched.
		// PORT: defer — the deferred restore runs before the single return below.
		var restoreLexicalArguments = false;
		var savedLexicalArguments:LexicalArgumentsInfo = null;
		if ((EmitContext().EmitFlags(node) & EFNoLexicalArguments) != 0) {
			savedLexicalArguments = lexicalArguments;
			lexicalArguments = new LexicalArgumentsInfo();
			restoreLexicalArguments = true;
		}

		final decl = node.AsArrowFunction();
		final functionFlags = Ast.GetFunctionFlags(node);

		var parameters:NodeList = null;
		var body:Node = null;
		if ((functionFlags & FunctionFlagsAsync) != 0) {
			parameters = transformAsyncFunctionParameterList(node);
			body = transformAsyncFunctionBody(node, parameters);
		} else {
			parameters = EmitContext().VisitParameters(decl.Parameters, Visitor());
			body = EmitContext().VisitFunctionBody(decl.Body, Visitor());
		}

		final result = Factory().UpdateArrowFunction(decl, Visitor().VisitModifiers(decl.Modifiers()), null, /*typeParameters*/ parameters,
			null, /*returnType*/ null, /*fullSignature*/ decl.EqualsGreaterThanToken, body);
		if (restoreLexicalArguments) {
			lexicalArguments = savedLexicalArguments;
		}
		return result;
	}

	function recordDeclarationName(node:Node, names:Set<std.String>):Void {
		final name = node.Name();
		if (name == null) {
			return;
		}
		if (Ast.IsIdentifier(name)) {
			names.Add(name.Text());
		} else if (Ast.IsBindingPattern(name)) {
			for (element in name.AsBindingPattern().Elements.Nodes) {
				if (!Ast.IsOmittedExpression(element)) {
					recordDeclarationName(element, names);
				}
			}
		}
	}

	function isVariableDeclarationListWithCollidingName(node:Node):Bool {
		// PORT: slices.ContainsFunc → Core.Some (same semantics).
		return node != null && Ast.IsVariableDeclarationList(node) && (node.Flags & NodeFlagsBlockScoped) == 0
			&& Core.Some(node.AsVariableDeclarationList().Declarations.Nodes, collidesWithParameterName);
	}

	function visitVariableDeclarationListWithCollidingNames(node:VariableDeclarationList, hasReceiver:Bool):Node {
		hoistVariableDeclarationList(node);

		var variables:Array<Node> = null;
		for (decl in node.Declarations.Nodes) {
			if (decl.AsVariableDeclaration().Initializer != null) {
				if (variables == null) {
					variables = [];
				}
				variables.push(decl);
			}
		}

		if (Core.len(variables) == 0) {
			if (hasReceiver) {
				final name = node.Declarations.Nodes[0].Name();
				var target:Node = null;
				if (Ast.IsBindingPattern(name)) {
					target = Transformers.ConvertBindingPatternToAssignmentPattern(EmitContext(), name.AsBindingPattern());
				} else {
					target = name;
				}
				return Visitor().VisitNode(target);
			}
			return null;
		}

		var expressions:Array<Node> = null;
		for (variable in variables) {
			if (expressions == null) {
				expressions = [];
			}
			expressions.push(transformInitializedVariable(variable.AsVariableDeclaration()));
		}
		return Factory().InlineExpressions(expressions);
	}

	function hoistVariableDeclarationList(node:VariableDeclarationList):Void {
		for (decl in node.Declarations.Nodes) {
			hoistVariable(decl);
		}
	}

	function hoistVariable(node:Node):Void {
		final name = node.Name();
		if (name == null) {
			return;
		}
		if (Ast.IsIdentifier(name)) {
			EmitContext().AddVariableDeclaration(name);
		} else if (Ast.IsBindingPattern(name)) {
			for (element in name.AsBindingPattern().Elements.Nodes) {
				if (!Ast.IsOmittedExpression(element)) {
					hoistVariable(element);
				}
			}
		}
	}

	function transformInitializedVariable(node:VariableDeclaration):Node {
		var target:Node = null;
		if (Ast.IsBindingPattern(node.Name())) {
			target = Transformers.ConvertBindingPatternToAssignmentPattern(EmitContext(), node.Name().AsBindingPattern());
		} else {
			target = node.Name();
		}
		final converted = Factory().NewAssignmentExpression(target, node.Initializer);
		EmitContext().SetSourceMapRange(converted, node.Loc);
		return Visitor().VisitNode(converted);
	}

	function collidesWithParameterName(node:Node):Bool {
		final name = node.Name();
		if (name == null) {
			return false;
		}
		if (Ast.IsIdentifier(name)) {
			return enclosingFunctionParameterNames != null && enclosingFunctionParameterNames.Has(name.Text());
		}
		if (Ast.IsBindingPattern(name)) {
			for (element in name.AsBindingPattern().Elements.Nodes) {
				if (!Ast.IsOmittedExpression(element) && collidesWithParameterName(element)) {
					return true;
				}
			}
		}
		return false;
	}

	function transformMethodBody(node:Node):Node {
		final savedCapturedSuperProperties = superAccessState.capturedSuperProperties;
		final savedHasSuperElementAccess = superAccessState.hasSuperElementAccess;
		final savedHasSuperPropertyAssignment = superAccessState.hasSuperPropertyAssignment;
		final savedSuperBinding = superAccessState.superBinding;
		final savedSuperIndexBinding = superAccessState.superIndexBinding;
		superAccessState.capturedSuperProperties = new OrderedSet<std.String>();
		superAccessState.hasSuperElementAccess = false;
		superAccessState.hasSuperPropertyAssignment = false;
		superAccessState.superBinding = Factory().NewUniqueNameEx("_super",
			new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));
		superAccessState.superIndexBinding = Factory().NewUniqueNameEx("_superIndex",
			new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));

		EmitContext().StartVariableEnvironment();
		var updated = EmitContext().VisitFunctionBody(node.Body(), Visitor());

		// Minor optimization, emit `_super` helper to capture `super` access in an arrow.
		final emitSuperHelpers = (superAccessState.capturedSuperProperties.Size() > 0 || superAccessState.hasSuperElementAccess)
			&& (Ast.GetFunctionFlags(getOriginalIfFunctionLike(node)) & FunctionFlagsAsyncGenerator) != FunctionFlagsAsyncGenerator;

		if (emitSuperHelpers) {
			if (superAccessState.capturedSuperProperties.Size() > 0) {
				EmitContext().AddInitializationStatement(superAccessState.createSuperAccessVariableStatement());
			}
		}

		final mergedStatements = EmitContext().EndAndMergeVariableEnvironmentList(updated.StatementList());
		if (emitSuperHelpers && superAccessState.hasSuperElementAccess && !updated.AsBlock().MultiLine) {
			final newBlock = Factory().NewBlock(mergedStatements, true);
			newBlock.Loc = updated.Loc;
			updated = newBlock;
		} else {
			updated = Factory().UpdateBlock(updated.AsBlock(), mergedStatements, updated.AsBlock().MultiLine);
		}

		if (emitSuperHelpers && superAccessState.hasSuperElementAccess) {
			if (superAccessState.hasSuperPropertyAssignment) {
				EmitContext().AddEmitHelper(updated, Printer.AdvancedAsyncSuperHelper);
			} else {
				EmitContext().AddEmitHelper(updated, Printer.AsyncSuperHelper);
			}
		}

		superAccessState.capturedSuperProperties = savedCapturedSuperProperties;
		superAccessState.hasSuperElementAccess = savedHasSuperElementAccess;
		superAccessState.hasSuperPropertyAssignment = savedHasSuperPropertyAssignment;
		superAccessState.superBinding = savedSuperBinding;
		superAccessState.superIndexBinding = savedSuperIndexBinding;
		return updated;
	}

	function createCaptureArgumentsStatement():Node {
		final variable = Factory().NewVariableDeclaration(lexicalArguments.binding, null, null, Factory().NewIdentifier("arguments"));
		final declList = Factory().NewVariableDeclarationList(Factory().NewNodeList([variable]), NodeFlagsNone);
		final statement = Factory().NewVariableStatement(null, declList);
		EmitContext().AddEmitFlags(statement, EFStartOnNewLine | EFCustomPrologue);
		return statement;
	}

	function transformAsyncFunctionParameterList(node:Node):NodeList {
		if (Estransforms.isSimpleParameterList(node.Parameters())) {
			return EmitContext().VisitParameters(node.ParameterList(), Visitor());
		}

		var newParameters:Array<Node> = null;
		for (parameter in node.Parameters()) {
			final param = parameter.AsParameterDeclaration();
			if (param.Initializer != null || param.DotDotDotToken != null) {
				// for an arrow function, capture the remaining arguments in a rest parameter.
				// for any other function/method this isn't necessary as we can just use `arguments`.
				if (node.Kind == KindArrowFunction) {
					final restParameter = Factory().NewParameterDeclaration(null, Factory().NewToken(KindDotDotDotToken),
						Factory().NewUniqueNameEx("args", new AutoGenerateOptions(GeneratedIdentifierFlagsReservedInNestedScopes)), null, null, null);
					if (newParameters == null) {
						newParameters = [];
					}
					newParameters.push(restParameter);
				}
				break;
			}
			// for arrow functions we capture fixed parameters to forward to `__awaiter`. For all other functions
			// we add fixed parameters to preserve the function's `length` property.
			final newParameter = Factory().NewParameterDeclaration(null, null,
				Factory().NewGeneratedNameForNodeEx(param.Name(), new AutoGenerateOptions(GeneratedIdentifierFlagsReservedInNestedScopes)), null, null, null);
			if (newParameters == null) {
				newParameters = [];
			}
			newParameters.push(newParameter);
		}
		final newParametersArray = Factory().NewNodeList(newParameters);
		newParametersArray.Loc = node.ParameterList().Loc;
		return newParametersArray;
	}

	function transformAsyncFunctionBody(node:Node, outerParameters:NodeList):Node {
		final isArrow = node.Kind == KindArrowFunction;
		final savedCapturedSuperProperties = superAccessState.capturedSuperProperties;
		final savedHasSuperElementAccess = superAccessState.hasSuperElementAccess;
		final savedHasSuperPropertyAssignment = superAccessState.hasSuperPropertyAssignment;
		final savedSuperBinding = superAccessState.superBinding;
		final savedSuperIndexBinding = superAccessState.superIndexBinding;
		if (!isArrow) {
			superAccessState.capturedSuperProperties = new OrderedSet<std.String>();
			superAccessState.hasSuperElementAccess = false;
			superAccessState.hasSuperPropertyAssignment = false;
			superAccessState.superBinding = Factory().NewUniqueNameEx("_super",
				new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));
			superAccessState.superIndexBinding = Factory().NewUniqueNameEx("_superIndex",
				new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));
		}

		var innerParameters:NodeList = null;
		if (!Estransforms.isSimpleParameterList(node.Parameters())) {
			innerParameters = EmitContext().VisitParameters(node.ParameterList(), Visitor());
		}

		// PORT: Go copies the struct; tx.lexicalArguments may be mutated below while still the same object.
		final savedLexicalArguments = lexicalArguments.copy();
		final captureLexicalArguments = lexicalArguments.binding == null;
		if (captureLexicalArguments) {
			lexicalArguments = new LexicalArgumentsInfo();
			lexicalArguments.binding = Factory().NewUniqueName("arguments");
		}

		var argumentsExpression:Expression = null;
		if (innerParameters != null) {
			if (isArrow) {
				// `node` does not have a simple parameter list, so `outerParameters` refers to placeholders that are
				// forwarded to `innerParameters`, matching how they are introduced in `transformAsyncFunctionParameterList`.
				var parameterBindings:Array<Node> = null;
				final outerLen = Core.len(outerParameters.Nodes);
				final params = node.Parameters();
				for (i in 0...params.length) {
					final param = params[i];
					if (i >= outerLen) {
						break;
					}
					final originalParameter = param.AsParameterDeclaration();
					final outerParameter = outerParameters.Nodes[i].AsParameterDeclaration();
					if (originalParameter.Initializer != null || originalParameter.DotDotDotToken != null) {
						if (parameterBindings == null) {
							parameterBindings = [];
						}
						parameterBindings.push(Factory().NewSpreadElement(outerParameter.Name()));
						break;
					}
					if (parameterBindings == null) {
						parameterBindings = [];
					}
					parameterBindings.push(outerParameter.Name());
				}
				argumentsExpression = Factory().NewArrayLiteralExpression(Factory().NewNodeList(parameterBindings), false);
			} else {
				argumentsExpression = Factory().NewIdentifier("arguments");
			}
		}

		// An async function is emit as an outer function that calls an inner
		// generator function. To preserve lexical bindings, we pass the current
		// `this` and `arguments` objects to `__awaiter`. The generator function
		// passed to `__awaiter` is executed inside of the callback to the
		// promise constructor.

		final savedEnclosingFunctionParameterNames = enclosingFunctionParameterNames;
		enclosingFunctionParameterNames = new Set<std.String>();
		for (parameter in node.Parameters()) {
			recordDeclarationName(parameter, enclosingFunctionParameterNames);
		}

		final hasLexicalThis = inHasLexicalThisContext();

		var asyncBody = transformAsyncFunctionBodyWorker(node.Body());
		asyncBody = Factory().UpdateBlock(asyncBody.AsBlock(), EmitContext().EndAndMergeVariableEnvironmentList(asyncBody.StatementList()),
			asyncBody.AsBlock().MultiLine);

		// Substitute super property accesses with _super/_superIndex helpers
		final emitSuperHelpers = superAccessState.capturedSuperProperties != null
			&& (superAccessState.capturedSuperProperties.Size() > 0 || superAccessState.hasSuperElementAccess);
		if (emitSuperHelpers) {
			innerParameters = superAccessState.superAccessVisitor.VisitNodes(innerParameters);
			asyncBody = superAccessState.substituteSuperAccessesInBody(asyncBody);
		}

		var result:Node = null;
		if (!isArrow) {
			EmitContext().StartVariableEnvironment();

			// Minor optimization, emit `_super` helper to capture `super` access in an arrow.
			if (emitSuperHelpers) {
				if (superAccessState.capturedSuperProperties.Size() > 0) {
					EmitContext().AddInitializationStatement(superAccessState.createSuperAccessVariableStatement());
				}
			}

			if (captureLexicalArguments && lexicalArguments.used) {
				EmitContext().AddInitializationStatement(createCaptureArgumentsStatement());
			}

			final statements:Array<Node> = [
				Factory().NewReturnStatement(Factory().NewAwaiterHelper(hasLexicalThis, argumentsExpression, innerParameters, asyncBody)),
			];

			final block = Factory().NewBlock(EmitContext().EndAndMergeVariableEnvironmentList(Factory().NewNodeList(statements)), true);
			block.Loc = node.Body().Loc;

			if (emitSuperHelpers && superAccessState.hasSuperElementAccess) {
				if (superAccessState.hasSuperPropertyAssignment) {
					EmitContext().AddEmitHelper(block, Printer.AdvancedAsyncSuperHelper);
				} else {
					EmitContext().AddEmitHelper(block, Printer.AsyncSuperHelper);
				}
			}

			result = block;
		} else {
			result = Factory().NewAwaiterHelper(hasLexicalThis, argumentsExpression, innerParameters, asyncBody);

			if (captureLexicalArguments && lexicalArguments.used) {
				final block = convertToFunctionBlock(result);
				result = Factory().UpdateBlock(block.AsBlock(),
					EmitContext().MergeEnvironmentList(block.StatementList(), [createCaptureArgumentsStatement()]), block.AsBlock().MultiLine);
			}
		}

		enclosingFunctionParameterNames = savedEnclosingFunctionParameterNames;
		if (!isArrow) {
			superAccessState.capturedSuperProperties = savedCapturedSuperProperties;
			superAccessState.hasSuperElementAccess = savedHasSuperElementAccess;
			superAccessState.hasSuperPropertyAssignment = savedHasSuperPropertyAssignment;
			superAccessState.superBinding = savedSuperBinding;
			superAccessState.superIndexBinding = savedSuperIndexBinding;
			lexicalArguments = savedLexicalArguments;
		} else if (captureLexicalArguments && !lexicalArguments.used) {
			// If we created a new binding but it wasn't used, restore the previous state.
			// If it was used, keep the binding alive so sibling arrows can reuse it
			// (the `var` declaration hoists to the enclosing function scope).
			lexicalArguments = savedLexicalArguments;
		} else if (captureLexicalArguments) {
			// Keep the binding but clear the used flag so siblings don't re-emit the capture statement.
			lexicalArguments.used = false;
		}
		return result;
	}

	function transformAsyncFunctionBodyWorker(body:Node):Node {
		if (Ast.IsBlock(body)) {
			return Factory().UpdateBlock(body.AsBlock(), asyncBodyVisitor.VisitNodes(body.StatementList()), body.AsBlock().MultiLine);
		}
		// Convert expression body to block body with return statement
		final visited = asyncBodyVisitor.VisitNode(body);
		final ret = Factory().NewReturnStatement(visited);
		ret.Loc = body.Loc;
		final list = Factory().NewNodeList([ret]);
		list.Loc = body.Loc;
		final block = Factory().NewBlock(list, false /*multiLine*/);
		block.Loc = body.Loc;
		return block;
	}

	function convertToFunctionBlock(node:Node):Node {
		if (Ast.IsBlock(node)) {
			return node;
		}
		final ret = Factory().NewReturnStatement(node);
		ret.Loc = node.Loc;
		EmitContext().SetOriginal(ret, node);
		final list = Factory().NewNodeList([ret]);
		list.Loc = node.Loc;
		final block = Factory().NewBlock(list, true);
		block.Loc = node.Loc;
		return block;
	}

	function getOriginalIfFunctionLike(node:Node):Node {
		final original = EmitContext().MostOriginal(node);
		if (original != null && Ast.IsFunctionLikeDeclaration(original)) {
			return original;
		}
		return node;
	}
}
