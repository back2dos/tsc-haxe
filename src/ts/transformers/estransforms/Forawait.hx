package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/forawait.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).
import ts.printer.Generatedidentifierflags.GeneratedIdentifierFlags.*;

// Facts we track as we traverse the tree
enum abstract ForAwaitHierarchyFacts(Int) from Int to Int {
	@:op(A | B) static function or(a:ForAwaitHierarchyFacts, b:ForAwaitHierarchyFacts):ForAwaitHierarchyFacts;
	@:op(A & B) static function and(a:ForAwaitHierarchyFacts, b:ForAwaitHierarchyFacts):ForAwaitHierarchyFacts;
	@:op(~A) static function not(a:ForAwaitHierarchyFacts):ForAwaitHierarchyFacts;

	var forAwaitHierarchyFactsNone = 0;
	var forAwaitHierarchyFactsHasLexicalThis = 1 << 0;
	var forAwaitHierarchyFactsIterationContainer = 1 << 1;
	var forAwaitHierarchyFactsSourceFileExcludes = 1 << 1;
	var forAwaitHierarchyFactsStrictModeSourceFileIncludes = 0;
	var forAwaitHierarchyFactsClassOrFunctionIncludes = 1 << 0;
	var forAwaitHierarchyFactsClassOrFunctionExcludes = 1 << 1;
	var forAwaitHierarchyFactsArrowFunctionIncludes = 0;
	var forAwaitHierarchyFactsArrowFunctionExcludes = 1 << 1;
	var forAwaitHierarchyFactsIterationStatementIncludes = 1 << 1;
	var forAwaitHierarchyFactsIterationStatementExcludes = 0;
}

@:allow(ts.transformers.estransforms)
class ForawaitTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var superAccessState:SuperAccessState = new SuperAccessState(); // Go: embedded
	var compilerOptions:CompilerOptions = null;
	var enclosingFunctionFlags:FunctionFlags = 0;
	var forAwaitHierarchyFacts:ForAwaitHierarchyFacts = 0;
	var exportedVariableStatement:Bool = false;
	var fallbackNodeVisitor:NodeVisitor = null;
	var noAsyncModifierVisitor:NodeVisitor = null;

	public function new() {}

	// PORT: promoted methods of the embedded transformers.Transformer.
	inline function Visitor():NodeVisitor return Transformer.Visitor();
	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();
	inline function EmitContext():EmitContext return Transformer.EmitContext();

	// PORT: Go method expressions `(*forawaitTransformer).visitX`, created once (PORTING §7a).
	static final visitDefaultFn:(ForawaitTransformer, Node) -> Node = (tx, node) -> tx.visitDefault(node);
	static final visitConstructorDeclarationFn:(ForawaitTransformer, Node) -> Node = (tx, node) -> tx.visitConstructorDeclaration(node);
	static final visitMethodDeclarationFn:(ForawaitTransformer, Node) -> Node = (tx, node) -> tx.visitMethodDeclaration(node);
	static final visitGetAccessorDeclarationFn:(ForawaitTransformer, Node) -> Node = (tx, node) -> tx.visitGetAccessorDeclaration(node);
	static final visitSetAccessorDeclarationFn:(ForawaitTransformer, Node) -> Node = (tx, node) -> tx.visitSetAccessorDeclaration(node);
	static final visitFunctionDeclarationFn:(ForawaitTransformer, Node) -> Node = (tx, node) -> tx.visitFunctionDeclaration(node);
	static final visitFunctionExpressionFn:(ForawaitTransformer, Node) -> Node = (tx, node) -> tx.visitFunctionExpression(node);
	static final visitArrowFunctionFn:(ForawaitTransformer, Node) -> Node = (tx, node) -> tx.visitArrowFunction(node);

	function affectsSubtree(excludeFacts:ForAwaitHierarchyFacts, includeFacts:ForAwaitHierarchyFacts):Bool {
		return forAwaitHierarchyFacts != ((forAwaitHierarchyFacts & ~excludeFacts) | includeFacts);
	}

	// enterSubtree sets the HierarchyFacts for this node prior to visiting this node's subtree,
	// returning the facts set prior to modification.
	function enterSubtree(excludeFacts:ForAwaitHierarchyFacts, includeFacts:ForAwaitHierarchyFacts):ForAwaitHierarchyFacts {
		final ancestorFacts = forAwaitHierarchyFacts;
		forAwaitHierarchyFacts = ((forAwaitHierarchyFacts & ~excludeFacts) | includeFacts) & Estransforms.forAwaitHierarchyFactsAncestorFactsMask;
		return ancestorFacts;
	}

	// exitSubtree restores the HierarchyFacts for this node's ancestor after visiting this node's
	// subtree.
	function exitSubtree(ancestorFacts:ForAwaitHierarchyFacts):Void {
		forAwaitHierarchyFacts = ancestorFacts;
	}

	function visitModifiersNoAsync(modifiers:ModifierList):ModifierList {
		return noAsyncModifierVisitor.VisitModifiers(modifiers);
	}

	function doWithHierarchyFacts(cb:(ForawaitTransformer, Node) -> Node, node:Node, excludeFacts:ForAwaitHierarchyFacts, includeFacts:ForAwaitHierarchyFacts):Node {
		if (affectsSubtree(excludeFacts, includeFacts)) {
			final ancestorFacts = enterSubtree(excludeFacts, includeFacts);
			final result = cb(this, node);
			exitSubtree(ancestorFacts);
			return result;
		}
		return cb(this, node);
	}

	function visitDefault(node:Node):Node {
		return Visitor().VisitEachChild(node);
	}

	function fallbackVisitor(node:Node):Node {
		if (superAccessState.capturedSuperProperties == null) {
			return node;
		}
		switch (node.Kind) {
			case KindFunctionExpression, KindFunctionDeclaration, KindMethodDeclaration, KindGetAccessor, KindSetAccessor, KindConstructor:
				return node;
			default:
		}
		superAccessState.trackSuperAccess(node);
		return fallbackNodeVisitor.VisitEachChild(node);
	}

	function visitFallback(node:Node):Node {
		return fallbackVisitor(node);
	}

	function visit(node:Node):Node {
		if ((node.SubtreeFacts() & SubtreeContainsForAwaitOrAsyncGenerator) == 0) {
			return fallbackVisitor(node);
		}
		superAccessState.trackSuperAccess(node);
		switch (node.Kind) {
			case KindSourceFile:
				return visitSourceFile(node.AsSourceFile());
			case KindAwaitExpression:
				return visitAwaitExpression(node.AsAwaitExpression());
			case KindYieldExpression:
				return visitYieldExpression(node.AsYieldExpression());
			case KindReturnStatement:
				return visitReturnStatement(node.AsReturnStatement());
			case KindLabeledStatement:
				return visitLabeledStatement(node.AsLabeledStatement());
			case KindDoStatement, KindWhileStatement, KindForInStatement:
				return doWithHierarchyFacts(visitDefaultFn, node, forAwaitHierarchyFactsIterationStatementExcludes,
					forAwaitHierarchyFactsIterationStatementIncludes);
			case KindForOfStatement:
				return visitForOfStatement(node.AsForInOrOfStatement(), null);
			case KindForStatement:
				return doWithHierarchyFacts(visitDefaultFn, node, forAwaitHierarchyFactsIterationStatementExcludes,
					forAwaitHierarchyFactsIterationStatementIncludes);
			case KindConstructor:
				return doWithHierarchyFacts(visitConstructorDeclarationFn, node, forAwaitHierarchyFactsClassOrFunctionExcludes,
					forAwaitHierarchyFactsClassOrFunctionIncludes);
			case KindMethodDeclaration:
				return doWithHierarchyFacts(visitMethodDeclarationFn, node, forAwaitHierarchyFactsClassOrFunctionExcludes,
					forAwaitHierarchyFactsClassOrFunctionIncludes);
			case KindGetAccessor:
				return doWithHierarchyFacts(visitGetAccessorDeclarationFn, node, forAwaitHierarchyFactsClassOrFunctionExcludes,
					forAwaitHierarchyFactsClassOrFunctionIncludes);
			case KindSetAccessor:
				return doWithHierarchyFacts(visitSetAccessorDeclarationFn, node, forAwaitHierarchyFactsClassOrFunctionExcludes,
					forAwaitHierarchyFactsClassOrFunctionIncludes);
			case KindFunctionDeclaration:
				return doWithHierarchyFacts(visitFunctionDeclarationFn, node, forAwaitHierarchyFactsClassOrFunctionExcludes,
					forAwaitHierarchyFactsClassOrFunctionIncludes);
			case KindFunctionExpression:
				return doWithHierarchyFacts(visitFunctionExpressionFn, node, forAwaitHierarchyFactsClassOrFunctionExcludes,
					forAwaitHierarchyFactsClassOrFunctionIncludes);
			case KindArrowFunction:
				return doWithHierarchyFacts(visitArrowFunctionFn, node, forAwaitHierarchyFactsArrowFunctionExcludes,
					forAwaitHierarchyFactsArrowFunctionIncludes);
			case KindClassDeclaration, KindClassExpression:
				return doWithHierarchyFacts(visitDefaultFn, node, forAwaitHierarchyFactsClassOrFunctionExcludes,
					forAwaitHierarchyFactsClassOrFunctionIncludes);
			default:
				return Visitor().VisitEachChild(node);
		}
	}

	function visitAwaitExpression(node:AwaitExpression):Node {
		if ((enclosingFunctionFlags & FunctionFlagsAsync) != 0 && (enclosingFunctionFlags & FunctionFlagsGenerator) != 0) {
			final result = Factory().NewYieldExpression(null, /*asteriskToken*/
				Factory().NewAwaitHelper(Visitor().VisitNode(node.Expression)));
			result.Loc = node.Loc;
			EmitContext().SetOriginal(result, node.AsNode());
			return result;
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitYieldExpression(node:YieldExpression):Node {
		if ((enclosingFunctionFlags & FunctionFlagsAsync) != 0 && (enclosingFunctionFlags & FunctionFlagsGenerator) != 0) {
			if (node.AsteriskToken != null) {
				final expression = Visitor().VisitNode(node.Expression);

				final asyncValuesResult = Factory().NewAsyncValuesHelper(expression);
				asyncValuesResult.Loc = expression.Loc;

				final asyncDelegatorResult = Factory().NewAsyncDelegatorHelper(asyncValuesResult);
				asyncDelegatorResult.Loc = expression.Loc;

				final innerYield = Factory().UpdateYieldExpression(node, node.AsteriskToken, asyncDelegatorResult);

				final awaitedYield = Factory().NewAwaitHelper(innerYield);

				final result = Factory().NewYieldExpression(null, /*asteriskToken*/ awaitedYield);
				result.Loc = node.Loc;
				EmitContext().SetOriginal(result, node.AsNode());
				return result;
			}

			var innerExpression:Node = null;
			if (node.Expression != null) {
				innerExpression = Visitor().VisitNode(node.Expression);
			} else {
				innerExpression = Factory().NewVoidZeroExpression();
			}

			final result = Factory().NewYieldExpression(null, /*asteriskToken*/ createDownlevelAwait(innerExpression));
			result.Loc = node.Loc;
			EmitContext().SetOriginal(result, node.AsNode());
			return result;
		}

		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitReturnStatement(node:ReturnStatement):Node {
		if ((enclosingFunctionFlags & FunctionFlagsAsync) != 0 && (enclosingFunctionFlags & FunctionFlagsGenerator) != 0) {
			var expression:Node = null;
			if (node.Expression != null) {
				expression = Visitor().VisitNode(node.Expression);
			} else {
				expression = Factory().NewVoidZeroExpression();
			}
			return Factory().UpdateReturnStatement(node, createDownlevelAwait(expression));
		}

		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitLabeledStatement(node:LabeledStatement):Node {
		if ((enclosingFunctionFlags & FunctionFlagsAsync) != 0) {
			final statement = Estransforms.unwrapInnermostStatementOfLabel(node);
			if (statement.Kind == KindForOfStatement && statement.AsForInOrOfStatement().AwaitModifier != null) {
				return visitForOfStatement(statement.AsForInOrOfStatement(), node);
			}
			return Factory().RestoreEnclosingLabel(Visitor().VisitNode(statement), node);
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitSourceFile(node:SourceFile):Node {
		final ancestorFacts = enterSubtree(forAwaitHierarchyFactsSourceFileExcludes, forAwaitHierarchyFactsStrictModeSourceFileIncludes);
		exportedVariableStatement = false;
		final visited = Visitor().VisitEachChild(node.AsNode());
		// PORT: Go spreads a possibly-nil slice; a Haxe spread of null throws.
		final helpers = EmitContext().ReadEmitHelpers();
		if (helpers != null) {
			EmitContext().AddEmitHelper(visited, ...helpers);
		} else {
			EmitContext().AddEmitHelper(visited);
		}
		exitSubtree(ancestorFacts);
		return visited;
	}

	// visitForOfStatement visits a ForOfStatement and converts it into a ES2015-compatible ForOfStatement.
	function visitForOfStatement(node:ForInOrOfStatement, outermostLabeledStatement:LabeledStatement):Node {
		final ancestorFacts = enterSubtree(forAwaitHierarchyFactsIterationStatementExcludes, forAwaitHierarchyFactsIterationStatementIncludes);
		var result:Node = null;
		if (node.AwaitModifier != null) {
			result = transformForAwaitOfStatement(node, outermostLabeledStatement, ancestorFacts);
		} else {
			result = Factory().RestoreEnclosingLabel(Visitor().VisitEachChild(node.AsNode()), outermostLabeledStatement);
		}
		exitSubtree(ancestorFacts);
		return result;
	}

	function convertForOfStatementHead(node:ForInOrOfStatement, boundValue:Node, nonUserCode:Node):Node {
		final f = Factory();
		final value = f.NewTempVariable();
		EmitContext().AddVariableDeclaration(value);
		final iteratorValueExpression = f.NewAssignmentExpression(value, boundValue);
		final iteratorValueStatement = f.NewExpressionStatement(iteratorValueExpression);
		EmitContext().SetSourceMapRange(iteratorValueStatement, node.Expression.Loc);

		final exitNonUserCodeExpression = f.NewAssignmentExpression(nonUserCode, f.NewKeywordExpression(KindFalseKeyword));
		final exitNonUserCodeStatement = f.NewExpressionStatement(exitNonUserCodeExpression);
		EmitContext().SetSourceMapRange(exitNonUserCodeStatement, node.Expression.Loc);

		final statements:Array<Node> = [iteratorValueStatement, exitNonUserCodeStatement];
		final binding = Factory().CreateForOfBindingStatement(node.Initializer, value);
		statements.push(Visitor().VisitNode(binding));

		// PORT: Go zero value core.TextRange{}.
		var bodyLocation = new ts.core.Text.TextRange(0, 0);
		var statementsLocation = new ts.core.Text.TextRange(0, 0);
		final statement = Visitor().VisitEmbeddedStatement(node.Statement);
		if (Ast.IsBlock(statement)) {
			for (s in statement.Statements()) {
				statements.push(s);
			}
			bodyLocation = statement.Loc;
			statementsLocation = statement.StatementList().Loc;
		} else {
			statements.push(statement);
		}

		final stmtList = f.NewNodeList(statements);
		stmtList.Loc = statementsLocation;
		final block = f.NewBlock(stmtList, true);
		block.Loc = bodyLocation;
		return block;
	}

	function createDownlevelAwait(expression:Node):Node {
		if ((enclosingFunctionFlags & FunctionFlagsGenerator) != 0) {
			return Factory().NewYieldExpression(null, /*asteriskToken*/ Factory().NewAwaitHelper(expression));
		}
		return Factory().NewAwaitExpression(expression);
	}

	function transformForAwaitOfStatement(node:ForInOrOfStatement, outermostLabeledStatement:LabeledStatement, ancestorFacts:ForAwaitHierarchyFacts):Node {
		final f = Factory();
		final expression = Visitor().VisitNode(node.Expression);

		var iterator:Node = null;
		if (Ast.IsIdentifier(expression)) {
			iterator = f.NewGeneratedNameForNode(expression);
		} else {
			iterator = f.NewTempVariable();
		}

		var result:Node = null;
		if (Ast.IsIdentifier(expression)) {
			result = f.NewGeneratedNameForNode(iterator);
		} else {
			result = f.NewTempVariable();
		}

		final nonUserCode = f.NewTempVariable();
		final done = f.NewTempVariable();
		EmitContext().AddVariableDeclaration(done);
		final errorRecord = f.NewUniqueName("e");
		final catchVariable = f.NewGeneratedNameForNode(errorRecord);
		final returnMethod = f.NewTempVariable();
		final callValues = f.NewAsyncValuesHelper(expression);
		callValues.Loc = node.Expression.Loc;
		final callNext = f.NewCallExpression(f.NewPropertyAccessExpression(iterator, null, f.NewIdentifier("next"), NodeFlagsNone), null, null,
			f.NewNodeList([]), NodeFlagsNone);
		final getDone = f.NewPropertyAccessExpression(result, null, f.NewIdentifier("done"), NodeFlagsNone);
		final getValue = f.NewPropertyAccessExpression(result, null, f.NewIdentifier("value"), NodeFlagsNone);
		final callReturn = f.NewFunctionCallCall(returnMethod, iterator, []);

		EmitContext().AddVariableDeclaration(errorRecord);
		EmitContext().AddVariableDeclaration(returnMethod);

		// if we are enclosed in an outer loop ensure we reset 'errorRecord' per each iteration
		var initializer:Node = null;
		if ((ancestorFacts & forAwaitHierarchyFactsIterationContainer) != 0) {
			initializer = f.InlineExpressions([f.NewAssignmentExpression(errorRecord, f.NewVoidZeroExpression()), callValues]);
		} else {
			initializer = callValues;
		}

		// Build the for statement
		final iteratorDecl = f.NewVariableDeclaration(iterator, null, null, initializer);
		iteratorDecl.Loc = node.Expression.Loc;
		final varDeclList = f.NewVariableDeclarationList(f.NewNodeList([
			f.NewVariableDeclaration(nonUserCode, null, null, f.NewKeywordExpression(KindTrueKeyword)),
			iteratorDecl,
			f.NewVariableDeclaration(result, null, null, null),
		]), NodeFlagsNone);
		varDeclList.Loc = node.Expression.Loc;

		final condition = f.InlineExpressions([
			f.NewAssignmentExpression(result, createDownlevelAwait(callNext)),
			f.NewAssignmentExpression(done, getDone),
			f.NewPrefixUnaryExpression(KindExclamationToken, done),
		]);

		final incrementor = f.NewAssignmentExpression(nonUserCode, f.NewKeywordExpression(KindTrueKeyword));

		final forStatement = f.NewForStatement(varDeclList, condition, incrementor, convertForOfStatementHead(node, getValue, nonUserCode));
		forStatement.Loc = node.Loc;
		EmitContext().AddEmitFlags(forStatement, EFNoTokenTrailingSourceMaps);
		EmitContext().SetOriginal(forStatement, node.AsNode());

		// Build the try/catch/finally
		final tryBlock = f.NewBlock(f.NewNodeList([f.RestoreEnclosingLabel(forStatement, outermostLabeledStatement),]), true);

		// catch clause: { e_1 = { error: e_2 }; }
		final catchBody = f.NewBlock(f.NewNodeList([
			f.NewExpressionStatement(f.NewAssignmentExpression(errorRecord,
				f.NewObjectLiteralExpression(f.NewNodeList([f.NewPropertyAssignment(null, f.NewIdentifier("error"), null, null, catchVariable),]), false))),
		]), false);
		EmitContext().AddEmitFlags(catchBody, EFSingleLine);
		final catchClause = f.NewCatchClause(f.NewVariableDeclaration(catchVariable, null, null, null), catchBody);

		// finally block
		// inner try: if (!nonUserCode && !done && (returnMethod = iterator.return)) await returnMethod.call(iterator);
		final innerIfCondition = f.NewBinaryExpression(null,
			f.NewBinaryExpression(null, f.NewPrefixUnaryExpression(KindExclamationToken, nonUserCode), null, f.NewToken(KindAmpersandAmpersandToken),
				f.NewPrefixUnaryExpression(KindExclamationToken, done)),
			null, f.NewToken(KindAmpersandAmpersandToken),
			f.NewAssignmentExpression(returnMethod, f.NewPropertyAccessExpression(iterator, null, f.NewIdentifier("return"), NodeFlagsNone)));
		final innerIfStatement = f.NewIfStatement(innerIfCondition, f.NewExpressionStatement(createDownlevelAwait(callReturn)), null);
		EmitContext().AddEmitFlags(innerIfStatement, EFSingleLine);

		final innerTryBlock = f.NewBlock(f.NewNodeList([innerIfStatement]), false);

		// inner finally: if (errorRecord) throw errorRecord.error;
		final innerFinallyIf = f.NewIfStatement(errorRecord,
			f.NewThrowStatement(f.NewPropertyAccessExpression(errorRecord, null, f.NewIdentifier("error"), NodeFlagsNone)), null);
		EmitContext().AddEmitFlags(innerFinallyIf, EFSingleLine);
		final innerFinallyBlock = f.NewBlock(f.NewNodeList([innerFinallyIf]), false);
		EmitContext().AddEmitFlags(innerFinallyBlock, EFSingleLine);

		final innerTryStatement = f.NewTryStatement(innerTryBlock, null, innerFinallyBlock);
		final finallyBlock = f.NewBlock(f.NewNodeList([innerTryStatement]), true);

		return f.NewTryStatement(tryBlock, catchClause, finallyBlock);
	}

	function visitConstructorDeclaration(node:Node):Node {
		final decl = node.AsConstructorDeclaration();
		final savedEnclosingFunctionFlags = enclosingFunctionFlags;
		enclosingFunctionFlags = Ast.GetFunctionFlags(node);
		final updated = Factory().UpdateConstructorDeclaration(decl, decl.Modifiers(), null, /*typeParameters*/
			EmitContext().VisitParameters(decl.Parameters, Visitor()), null, /*returnType*/ null, /*fullSignature*/
			EmitContext().VisitFunctionBody(node.Body(), Visitor()));
		enclosingFunctionFlags = savedEnclosingFunctionFlags;
		return updated;
	}

	function visitGetAccessorDeclaration(node:Node):Node {
		final decl = node.AsGetAccessorDeclaration();
		final savedEnclosingFunctionFlags = enclosingFunctionFlags;
		enclosingFunctionFlags = Ast.GetFunctionFlags(node);
		final updated = Factory().UpdateGetAccessorDeclaration(decl, decl.Modifiers(), Visitor().VisitNode(decl.Name()), null, /*typeParameters*/
			EmitContext().VisitParameters(decl.Parameters, Visitor()), null, /*returnType*/ null, /*fullSignature*/
			EmitContext().VisitFunctionBody(node.Body(), Visitor()));
		enclosingFunctionFlags = savedEnclosingFunctionFlags;
		return updated;
	}

	function visitSetAccessorDeclaration(node:Node):Node {
		final decl = node.AsSetAccessorDeclaration();
		final savedEnclosingFunctionFlags = enclosingFunctionFlags;
		enclosingFunctionFlags = Ast.GetFunctionFlags(node);
		final updated = Factory().UpdateSetAccessorDeclaration(decl, decl.Modifiers(), Visitor().VisitNode(decl.Name()), null, /*typeParameters*/
			EmitContext().VisitParameters(decl.Parameters, Visitor()), null, /*returnType*/ null, /*fullSignature*/
			EmitContext().VisitFunctionBody(node.Body(), Visitor()));
		enclosingFunctionFlags = savedEnclosingFunctionFlags;
		return updated;
	}

	function visitMethodDeclaration(node:Node):Node {
		final decl = node.AsMethodDeclaration();
		final savedEnclosingFunctionFlags = enclosingFunctionFlags;
		enclosingFunctionFlags = Ast.GetFunctionFlags(node);

		var modifiers:ModifierList = null;
		if ((enclosingFunctionFlags & FunctionFlagsGenerator) != 0) {
			modifiers = visitModifiersNoAsync(decl.Modifiers());
		} else {
			modifiers = decl.Modifiers();
		}

		var asteriskToken:TokenNode = null;
		if ((enclosingFunctionFlags & FunctionFlagsAsync) != 0) {
			asteriskToken = null;
		} else {
			asteriskToken = decl.AsteriskToken;
		}

		var parameters:NodeList = null;
		var body:Node = null;
		if ((enclosingFunctionFlags & FunctionFlagsAsync) != 0 && (enclosingFunctionFlags & FunctionFlagsGenerator) != 0) {
			parameters = transformAsyncGeneratorFunctionParameterList(node);
			body = transformAsyncGeneratorFunctionBody(node);
		} else {
			parameters = EmitContext().VisitParameters(decl.Parameters, Visitor());
			body = EmitContext().VisitFunctionBody(node.Body(), Visitor());
		}

		final updated = Factory().UpdateMethodDeclaration(decl, modifiers, asteriskToken, Visitor().VisitNode(decl.Name()), null, /*postfixToken*/
			null, /*typeParameters*/ parameters, null, /*returnType*/ null, /*fullSignature*/ body);
		enclosingFunctionFlags = savedEnclosingFunctionFlags;
		return updated;
	}

	function visitFunctionDeclaration(node:Node):Node {
		final decl = node.AsFunctionDeclaration();
		final savedEnclosingFunctionFlags = enclosingFunctionFlags;
		enclosingFunctionFlags = Ast.GetFunctionFlags(node);

		var modifiers:ModifierList = null;
		if ((enclosingFunctionFlags & FunctionFlagsGenerator) != 0) {
			modifiers = visitModifiersNoAsync(decl.Modifiers());
		} else {
			modifiers = decl.Modifiers();
		}

		var asteriskToken:TokenNode = null;
		if ((enclosingFunctionFlags & FunctionFlagsAsync) != 0) {
			asteriskToken = null;
		} else {
			asteriskToken = decl.AsteriskToken;
		}

		var parameters:NodeList = null;
		var body:Node = null;
		if ((enclosingFunctionFlags & FunctionFlagsAsync) != 0 && (enclosingFunctionFlags & FunctionFlagsGenerator) != 0) {
			parameters = transformAsyncGeneratorFunctionParameterList(node);
			body = transformAsyncGeneratorFunctionBody(node);
		} else {
			parameters = EmitContext().VisitParameters(decl.Parameters, Visitor());
			body = EmitContext().VisitFunctionBody(node.Body(), Visitor());
		}

		final updated = Factory().UpdateFunctionDeclaration(decl, modifiers, asteriskToken, decl.Name(), null, /*typeParameters*/ parameters,
			null, /*returnType*/ null, /*fullSignature*/ body);
		enclosingFunctionFlags = savedEnclosingFunctionFlags;
		return updated;
	}

	function visitArrowFunction(node:Node):Node {
		final decl = node.AsArrowFunction();
		final savedEnclosingFunctionFlags = enclosingFunctionFlags;
		enclosingFunctionFlags = Ast.GetFunctionFlags(node);
		final updated = Factory().UpdateArrowFunction(decl, decl.Modifiers(), null, /*typeParameters*/
			EmitContext().VisitParameters(decl.Parameters, Visitor()), null, /*returnType*/ null, /*fullSignature*/ decl.EqualsGreaterThanToken,
			EmitContext().VisitFunctionBody(node.Body(), Visitor()));
		enclosingFunctionFlags = savedEnclosingFunctionFlags;
		return updated;
	}

	function visitFunctionExpression(node:Node):Node {
		final decl = node.AsFunctionExpression();
		final savedEnclosingFunctionFlags = enclosingFunctionFlags;
		enclosingFunctionFlags = Ast.GetFunctionFlags(node);

		var modifiers:ModifierList = null;
		if ((enclosingFunctionFlags & FunctionFlagsGenerator) != 0) {
			modifiers = visitModifiersNoAsync(decl.Modifiers());
		} else {
			modifiers = decl.Modifiers();
		}

		var asteriskToken:TokenNode = null;
		if ((enclosingFunctionFlags & FunctionFlagsAsync) != 0) {
			asteriskToken = null;
		} else {
			asteriskToken = decl.AsteriskToken;
		}

		var parameters:NodeList = null;
		var body:Node = null;
		if ((enclosingFunctionFlags & FunctionFlagsAsync) != 0 && (enclosingFunctionFlags & FunctionFlagsGenerator) != 0) {
			parameters = transformAsyncGeneratorFunctionParameterList(node);
			body = transformAsyncGeneratorFunctionBody(node);
		} else {
			parameters = EmitContext().VisitParameters(decl.Parameters, Visitor());
			body = EmitContext().VisitFunctionBody(node.Body(), Visitor());
		}

		final updated = Factory().UpdateFunctionExpression(decl, modifiers, asteriskToken, decl.Name(), null, /*typeParameters*/ parameters,
			null, /*returnType*/ null, /*fullSignature*/ body);
		enclosingFunctionFlags = savedEnclosingFunctionFlags;
		return updated;
	}

	function transformAsyncGeneratorFunctionParameterList(node:Node):NodeList {
		if (Estransforms.isSimpleParameterList(node.Parameters())) {
			return EmitContext().VisitParameters(node.ParameterList(), Visitor());
		}
		// Add fixed parameters to preserve the function's `length` property.
		var newParameters:Array<Node> = null;
		for (parameter in node.Parameters()) {
			final param = parameter.AsParameterDeclaration();
			if (param.Initializer != null || param.DotDotDotToken != null) {
				break;
			}
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

	function transformAsyncGeneratorFunctionBody(node:Node):Node {
		final f = Factory();
		var innerParameters:NodeList = null;
		if (!Estransforms.isSimpleParameterList(node.Parameters())) {
			innerParameters = EmitContext().VisitParameters(node.ParameterList(), Visitor());
		}

		final savedCapturedSuperProperties = superAccessState.capturedSuperProperties;
		final savedHasSuperElementAccess = superAccessState.hasSuperElementAccess;
		final savedHasSuperPropertyAssignment = superAccessState.hasSuperPropertyAssignment;
		final savedSuperBinding = superAccessState.superBinding;
		final savedSuperIndexBinding = superAccessState.superIndexBinding;
		superAccessState.capturedSuperProperties = new OrderedSet<std.String>();
		superAccessState.hasSuperElementAccess = false;
		superAccessState.hasSuperPropertyAssignment = false;
		superAccessState.superBinding = f.NewUniqueNameEx("_super", new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));
		superAccessState.superIndexBinding = f.NewUniqueNameEx("_superIndex",
			new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));

		var asyncBody = f.UpdateBlock(node.Body().AsBlock(), Visitor().VisitNodes(node.Body().StatementList()), node.Body().AsBlock().MultiLine);
		asyncBody = f.UpdateBlock(asyncBody.AsBlock(), EmitContext().EndAndMergeVariableEnvironmentList(asyncBody.StatementList()),
			asyncBody.AsBlock().MultiLine);

		// Substitute super property accesses with _super/_superIndex helpers
		final emitSuperHelpers = superAccessState.capturedSuperProperties.Size() > 0 || superAccessState.hasSuperElementAccess;
		if (emitSuperHelpers) {
			asyncBody = superAccessState.substituteSuperAccessesInBody(asyncBody);
		}

		var innerParams:NodeList = null;
		if (innerParameters != null) {
			innerParams = innerParameters;
		} else {
			innerParams = f.NewNodeList([]);
		}

		var name:Node = null;
		if (node.Name() != null) {
			name = f.NewGeneratedNameForNode(node.Name());
		}

		final generatorFunc = f.NewFunctionExpression(null, /*modifiers*/ f.NewToken(KindAsteriskToken), name, null, /*typeParameters*/ innerParams,
			null, /*returnType*/ null, /*fullSignature*/ asyncBody);

		final returnStatement = f.NewReturnStatement(f.NewAsyncGeneratorHelper(generatorFunc,
			(forAwaitHierarchyFacts & forAwaitHierarchyFactsHasLexicalThis) != 0));

		EmitContext().StartVariableEnvironment();
		if (emitSuperHelpers) {
			if (superAccessState.capturedSuperProperties.Size() > 0) {
				EmitContext().AddInitializationStatement(superAccessState.createSuperAccessVariableStatement());
			}
		}

		final outerStatements:Array<Node> = [returnStatement];

		final block = f.UpdateBlock(node.Body().AsBlock(), EmitContext().EndAndMergeVariableEnvironmentList(f.NewNodeList(outerStatements)),
			node.Body().AsBlock().MultiLine);

		if (emitSuperHelpers && superAccessState.hasSuperElementAccess) {
			if (superAccessState.hasSuperPropertyAssignment) {
				EmitContext().AddEmitHelper(block, Printer.AdvancedAsyncSuperHelper);
			} else {
				EmitContext().AddEmitHelper(block, Printer.AsyncSuperHelper);
			}
		}

		superAccessState.capturedSuperProperties = savedCapturedSuperProperties;
		superAccessState.hasSuperElementAccess = savedHasSuperElementAccess;
		superAccessState.hasSuperPropertyAssignment = savedHasSuperPropertyAssignment;
		superAccessState.superBinding = savedSuperBinding;
		superAccessState.superIndexBinding = savedSuperIndexBinding;

		return block;
	}
}
