package ts.transformers.moduletransforms;

// Port of internal/transformers/moduletransforms/commonjsmodule.go (upstream v7.0.2).

@:allow(ts.transformers.moduletransforms)
class CommonJSModuleTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var topLevelVisitor:NodeVisitor = null; // visits statements at top level of a module
	var topLevelNestedVisitor:NodeVisitor = null; // visits nested statements at top level of a module
	var discardedValueVisitor:NodeVisitor = null; // visits expressions whose values would be discarded at runtime
	var assignmentPatternVisitor:NodeVisitor = null; // visits assignment patterns in a destructuring assignment
	var compilerOptions:CompilerOptions = null;
	var resolver:ReferenceResolver = null;
	var getEmitModuleFormatOfFile:(file:HasFileName) -> ModuleKind = null;
	var moduleKind:ModuleKind = 0;
	var languageVersion:ScriptTarget = 0;
	var currentSourceFile:SourceFile = null;
	var currentModuleInfo:ExternalModuleInfo = null;
	var parentNode:Node = null; // used for ancestor tracking via pushNode/popNode to detect expression identifiers
	var currentNode:Node = null; // used for ancestor tracking via pushNode/popNode to detect expression identifiers

	public function new() {}

	// PORT: promoted methods of embedded transformers.Transformer
	inline function EmitContext():ts.printer.Emitcontext.EmitContext {
		return Transformer.EmitContext();
	}

	inline function Factory():ts.printer.Factory.NodeFactory {
		return Transformer.Factory();
	}

	inline function Visitor():ts.ast.Visitor.NodeVisitor {
		return Transformer.Visitor();
	}

	// PORT: Go passes *ast.SourceFile as ast.HasFileName; adapter cached per file.
	static inline function hasFileName(file:SourceFile):HasFileName {
		return ts.modulespecifiers.Types.SourceFileAdapter.Of(file);
	}

	// PORT: Go `range` over a possibly-nil slice (Haxe `for` on null crashes).
	static inline function rangeOf<T>(a:Array<T>):Array<T> {
		return a == null ? [] : a;
	}

	// PORT: Go `append` on a statement slice this transformer owns (nil → new array).
	static inline function append(s:Array<Statement>, x:Statement):Array<Statement> {
		if (s == null) {
			s = [];
		}
		s.push(x);
		return s;
	}

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

	// Visits a node at the top level of the source file.
	function visitTopLevel(node:Node):Node {
		final grandparentNode = pushNode(node);

		switch (node.Kind) {
			case KindImportDeclaration:
				node = visitTopLevelImportDeclaration(node.AsImportDeclaration());
			case KindImportEqualsDeclaration:
				node = visitTopLevelImportEqualsDeclaration(node.AsImportEqualsDeclaration());
			case KindExportDeclaration:
				node = visitTopLevelExportDeclaration(node.AsExportDeclaration());
			case KindExportAssignment:
				node = visitTopLevelExportAssignment(node.AsExportAssignment());
			case KindFunctionDeclaration:
				node = visitTopLevelFunctionDeclaration(node.AsFunctionDeclaration());
			case KindClassDeclaration:
				node = visitTopLevelClassDeclaration(node.AsClassDeclaration());
			case KindVariableStatement:
				node = visitTopLevelVariableStatement(node.AsVariableStatement());
			default:
				node = visitTopLevelNestedNoStack(node);
		}
		popNode(grandparentNode); // PORT: defer
		return node;
	}

	// Visits nested elements at the top-level of a module.
	function visitTopLevelNested(node:Node):Node {
		final grandparentNode = pushNode(node);

		final result = visitTopLevelNestedNoStack(node);
		popNode(grandparentNode); // PORT: defer
		return result;
	}

	// Visits nested elements at the top-level of a module without ancestor tracking.
	function visitTopLevelNestedNoStack(node:Node):Node {
		switch (node.Kind) {
			case KindVariableStatement:
				node = visitTopLevelVariableStatement(node.AsVariableStatement());
			case KindForStatement:
				node = visitTopLevelNestedForStatement(node.AsForStatement());
			case KindForInStatement, KindForOfStatement:
				node = visitTopLevelNestedForInOrOfStatement(node.AsForInOrOfStatement());
			case KindDoStatement:
				node = visitTopLevelNestedDoStatement(node.AsDoStatement());
			case KindWhileStatement:
				node = visitTopLevelNestedWhileStatement(node.AsWhileStatement());
			case KindLabeledStatement:
				node = visitTopLevelNestedLabeledStatement(node.AsLabeledStatement());
			case KindWithStatement:
				node = visitTopLevelNestedWithStatement(node.AsWithStatement());
			case KindIfStatement:
				node = visitTopLevelNestedIfStatement(node.AsIfStatement());
			case KindSwitchStatement:
				node = visitTopLevelNestedSwitchStatement(node.AsSwitchStatement());
			case KindCaseBlock:
				node = visitTopLevelNestedCaseBlock(node.AsCaseBlock());
			case KindCaseClause, KindDefaultClause:
				node = visitTopLevelNestedCaseOrDefaultClause(node.AsCaseOrDefaultClause());
			case KindTryStatement:
				node = visitTopLevelNestedTryStatement(node.AsTryStatement());
			case KindCatchClause:
				node = visitTopLevelNestedCatchClause(node.AsCatchClause());
			case KindBlock:
				node = visitTopLevelNestedBlock(node.AsBlock());
			default:
				node = visitNoStack(node, false /*resultIsDiscarded*/);
		}
		return node;
	}

	// Visits source elements that are not top-level or top-level nested statements.
	function visit(node:Node):Node {
		final grandparentNode = pushNode(node);

		final result = visitNoStack(node, false /*resultIsDiscarded*/);
		popNode(grandparentNode); // PORT: defer
		return result;
	}

	// Visits source elements that are not top-level or top-level nested statements without ancestor tracking.
	function visitNoStack(node:Node, resultIsDiscarded:Bool):Node {
		// This visitor does not need to descend into the tree if there are no dynamic imports or identifiers in the subtree
		if (!Ast.IsSourceFile(node) && (node.SubtreeFacts() & (SubtreeContainsDynamicImport | SubtreeContainsIdentifier)) == 0) {
			return node;
		}

		switch (node.Kind) {
			case KindSourceFile:
				node = visitSourceFile(node.AsSourceFile());
			case KindForStatement:
				node = visitForStatement(node.AsForStatement());
			case KindForInStatement, KindForOfStatement:
				node = visitForInOrOfStatement(node.AsForInOrOfStatement());
			case KindExpressionStatement:
				node = visitExpressionStatement(node.AsExpressionStatement());
			case KindVoidExpression:
				node = visitVoidExpression(node.AsVoidExpression());
			case KindParenthesizedExpression:
				node = visitParenthesizedExpression(node.AsParenthesizedExpression(), resultIsDiscarded);
			case KindPartiallyEmittedExpression:
				node = visitPartiallyEmittedExpression(node.AsPartiallyEmittedExpression(), resultIsDiscarded);
			case KindCallExpression:
				node = visitCallExpression(node.AsCallExpression());
			case KindTaggedTemplateExpression:
				node = visitTaggedTemplateExpression(node.AsTaggedTemplateExpression());
			case KindBinaryExpression:
				node = visitBinaryExpression(node.AsBinaryExpression(), resultIsDiscarded);
			case KindPrefixUnaryExpression:
				node = visitPrefixUnaryExpression(node.AsPrefixUnaryExpression(), resultIsDiscarded);
			case KindPostfixUnaryExpression:
				node = visitPostfixUnaryExpression(node.AsPostfixUnaryExpression(), resultIsDiscarded);
			case KindShorthandPropertyAssignment:
				node = visitShorthandPropertyAssignment(node.AsShorthandPropertyAssignment());
			case KindIdentifier:
				node = visitIdentifier(node);
			default:
				node = Visitor().VisitEachChild(node);
		}

		return node;
	}

	// Visits source elements whose value is discarded if they are expressions.
	function visitDiscardedValue(node:Node):Node {
		final grandparentNode = pushNode(node);

		final result = visitNoStack(node, true /*resultIsDiscarded*/);
		popNode(grandparentNode); // PORT: defer
		return result;
	}

	function visitAssignmentPattern(node:Node):Node {
		final grandparentNode = pushNode(node);

		final result = visitAssignmentPatternNoStack(node);
		popNode(grandparentNode); // PORT: defer
		return result;
	}

	function visitAssignmentPatternNoStack(node:Node):Node {
		switch (node.Kind) {
			// AssignmentPattern
			case KindObjectLiteralExpression, KindArrayLiteralExpression:
				node = assignmentPatternVisitor.VisitEachChild(node);

			// AssignmentProperty
			case KindPropertyAssignment:
				node = visitAssignmentProperty(node.AsPropertyAssignment());
			case KindShorthandPropertyAssignment:
				node = visitShorthandAssignmentProperty(node.AsShorthandPropertyAssignment());

			// AssignmentRestProperty
			case KindSpreadAssignment:
				node = visitAssignmentRestProperty(node.AsSpreadAssignment());

			// AssignmentRestElement
			case KindSpreadElement:
				node = visitAssignmentRestElement(node.AsSpreadElement());

			// AssignmentElement
			default:
				// PORT: Go `break` inside the switch → else branch.
				if (Ast.IsExpression(node)) {
					node = visitAssignmentElement(node);
				} else {
					node = visitNoStack(node, false /*resultIsDiscarded*/);
				}
		}
		return node;
	}

	function visitSourceFile(node:SourceFile):Node {
		if (node.IsDeclarationFile
			|| !(Ast.IsEffectiveExternalModule(node, compilerOptions)
				|| (node.SubtreeFacts() & SubtreeContainsDynamicImport) != 0)) {
			return node.AsNode();
		}

		currentSourceFile = node;
		currentModuleInfo = Moduletransforms.collectExternalModuleInfo(node, compilerOptions, EmitContext(), resolver);
		final updated = transformCommonJSModule(node);
		currentSourceFile = null;
		currentModuleInfo = null;
		return updated;
	}

	function shouldEmitUnderscoreUnderscoreESModule():Bool {
		if (Tspath.FileExtensionIsOneOf(currentSourceFile.FileName(), Tspath.SupportedJSExtensionsFlat)
			&& currentSourceFile.CommonJSModuleIndicator != null
			&& (currentSourceFile.ExternalModuleIndicator == null || currentSourceFile.ExternalModuleIndicator.Kind == KindSourceFile)) {
			return false;
		}
		if (currentModuleInfo.exportEquals == null && Ast.IsExternalModule(currentSourceFile)) {
			return true;
		}
		return false;
	}

	function createUnderscoreUnderscoreESModule():Statement {
		final statement = Factory().NewExpressionStatement(Factory().NewCallExpression(Factory().NewPropertyAccessExpression(Factory().NewIdentifier("Object"),
			null, /*questionDotToken*/
			Factory().NewIdentifier("defineProperty"), NodeFlagsNone),
			null, /*questionDotToken*/
			null, /*typeArguments*/
			Factory().NewNodeList([
				Factory().NewIdentifier("exports"),
				Factory().NewStringLiteral("__esModule", TokenFlagsNone),
				Factory().NewObjectLiteralExpression(Factory().NewNodeList([
					Factory().NewPropertyAssignment(null, /*modifiers*/
						Factory().NewIdentifier("value"), null, /*postfixToken*/
						null, /*typeNode*/
						Factory().NewTrueExpression()),
				]), false /*multiLine*/),
			]), NodeFlagsNone));
		EmitContext().SetEmitFlags(statement, EFCustomPrologue);
		return statement;
	}

	function transformCommonJSModule(node:SourceFile):Node {
		EmitContext().StartVariableEnvironment();

		// emit standard prologue directives (e.g. "use strict")
		final split = Factory().SplitStandardPrologue(node.Statements.Nodes);
		final prologue = split.a;
		var rest = split.b;
		var statements:Array<Statement> = prologue == null ? [] : prologue.copy();

		// emit custom prologues from other transformations
		final split2 = Factory().SplitCustomPrologue(rest);
		final custom = split2.a;
		rest = split2.b;
		final visitedCustom = topLevelVisitor.VisitSlice(custom).a;
		if (visitedCustom != null) {
			for (s in visitedCustom) {
				statements.push(s);
			}
		}

		// emits `Object.defineProperty(exports, "__esModule", { value: true });` at the top of the file
		if (shouldEmitUnderscoreUnderscoreESModule()) {
			statements.push(createUnderscoreUnderscoreESModule());
		}

		// initialize all exports to `undefined`, e.g.:
		//  exports.a = exports.b = void 0;
		if (Core.len(currentModuleInfo.exportedNames) > 0) {
			final chunkSize = 50;
			final l = currentModuleInfo.exportedNames.length;
			var i = 0;
			while (i < l) {
				var right = Factory().NewVoidZeroExpression();
				for (nextId in currentModuleInfo.exportedNames.slice(i, i + chunkSize < l ? i + chunkSize : l)) {
					var left:Expression;
					if (nextId.Kind == KindStringLiteral) {
						left = Factory().NewElementAccessExpression(Factory().NewIdentifier("exports"), null, /*questionDotToken*/
							Factory().NewStringLiteralFromNode(nextId), NodeFlagsNone);
					} else {
						final name = nextId.Clone(Factory());
						EmitContext().SetEmitFlags(name, EFNoSourceMap | EFNoComments);
						left = Factory().NewPropertyAccessExpression(Factory().NewIdentifier("exports"), null, /*questionDotToken*/
							name, NodeFlagsNone);
					}
					right = Factory().NewAssignmentExpression(left, right);
				}
				final statement = Factory().NewExpressionStatement(right);
				EmitContext().AddEmitFlags(statement, EFCustomPrologue);
				statements.push(statement);
				i += chunkSize;
			}
		}

		// initialize exports for function declarations, e.g.:
		//  exports.f = f;
		//  function f() {}
		// These are marked as custom prologue so they are ordered before the external helpers
		// import declaration (e.g., `const tslib_1 = require("tslib")`), matching TypeScript's emit order.
		final exportedFunctionsStart = statements.length;
		for (f in currentModuleInfo.exportedFunctions.Values()) {
			statements = appendExportsOfClassOrFunctionDeclaration(statements, f.AsNode());
		}
		for (j in exportedFunctionsStart...statements.length) {
			EmitContext().AddEmitFlags(statements[j], EFCustomPrologue);
		}

		// visit the remaining statements in the source file
		rest = topLevelVisitor.VisitSlice(rest).a;
		if (rest != null) {
			for (s in rest) {
				statements.push(s);
			}
		}

		// emit `module.exports = ...` if needd
		statements = appendExportEqualsIfNeeded(statements);

		// merge temp variables into the statement list
		statements = EmitContext().EndAndMergeVariableEnvironment(statements);

		final statementList = Factory().NewNodeList(statements);
		statementList.Loc = node.Statements.Loc;
		var result = Factory().UpdateSourceFile(node, statementList, node.EndOfFileToken).AsSourceFile();
		final helpers = EmitContext().ReadEmitHelpers();
		EmitContext().AddEmitHelper(result.AsNode(), ...(helpers == null ? [] : helpers));

		final externalHelpersImportDeclaration = Moduletransforms.createExternalHelpersImportDeclarationIfNeeded(EmitContext(), result, compilerOptions,
			getEmitModuleFormatOfFile(hasFileName(node)), false /*hasExportStarsToExportValues*/, false /*hasImportStar*/, false /*hasImportDefault*/);
		if (externalHelpersImportDeclaration != null) {
			final split3 = Factory().SplitStandardPrologue(result.Statements.Nodes);
			final prologue = split3.a;
			final split4 = Factory().SplitCustomPrologue(split3.b);
			final custom = split4.a;
			final rest = split4.b;
			final statements:Array<Statement> = prologue == null ? [] : prologue.copy();
			if (custom != null) {
				for (s in custom) {
					statements.push(s);
				}
			}
			statements.push(topLevelVisitor.VisitNode(externalHelpersImportDeclaration));
			if (rest != null) {
				for (s in rest) {
					statements.push(s);
				}
			}
			final statementList = Factory().NewNodeList(statements);
			statementList.Loc = result.Statements.Loc;
			result = Factory().UpdateSourceFile(result, statementList, node.EndOfFileToken).AsSourceFile();
		}

		return result.AsNode();
	}

	// Adds the down-level representation of `export=` to the statement list if one exists in the source file.
	//
	// - The `statements` parameter is a statement list to which the down-level export statements are to be appended.
	function appendExportEqualsIfNeeded(statements:Array<Statement>):Array<Statement> {
		if (currentModuleInfo.exportEquals != null) {
			final expressionResult = visitExportEquals(currentModuleInfo.exportEquals);
			if (expressionResult != null) {
				final statement = Factory().NewExpressionStatement(Factory().NewAssignmentExpression(Factory().NewPropertyAccessExpression(Factory().NewIdentifier("module"),
					null, /*questionDotToken*/
					Factory().NewIdentifier("exports"), NodeFlagsNone),
					expressionResult));

				EmitContext().AssignCommentAndSourceMapRanges(statement, currentModuleInfo.exportEquals.AsNode());
				EmitContext().AddEmitFlags(statement, EFNoComments);
				statements = append(statements, statement);
			}
		}
		return statements;
	}

	function visitExportEquals(node:ExportAssignment):Expression {
		final grandparentNode = pushNode(node.AsNode());
		final result = Visitor().VisitNode(node.Expression);
		popNode(grandparentNode); // PORT: defer
		return result;
	}

	// Appends the exports of an ImportDeclaration to a statement list, returning the statement list.
	//
	//   - The `statements` parameter is a statement list to which the down-level export statements are to be appended.
	//   - The `decl` parameter is the declaration whose exports are to be recorded.
	function appendExportsOfImportDeclaration(statements:Array<Statement>, decl:ImportDeclaration):Array<Statement> {
		if (currentModuleInfo.exportEquals != null) {
			return statements;
		}

		final importClause = decl.ImportClause;
		if (importClause == null) {
			return statements;
		}

		final seen = new Set<std.String>();
		if (importClause.Name() != null) {
			statements = appendExportsOfDeclaration(statements, importClause, seen, false /*liveBinding*/);
		}

		final namedBindings = importClause.AsImportClause().NamedBindings;
		if (namedBindings != null) {
			switch (namedBindings.Kind) {
				case KindNamespaceImport:
					statements = appendExportsOfDeclaration(statements, namedBindings, seen, false /*liveBinding*/);

				case KindNamedImports:
					for (importBinding in rangeOf(namedBindings.Elements())) {
						statements = appendExportsOfDeclaration(statements, importBinding, seen, true /*liveBinding*/);
					}
				default:
			}
		}

		return statements;
	}

	// Appends the exports of a VariableStatement to a statement list, returning the statement list.
	//
	//   - The `statements` parameter is a statement list to which the down-level export statements are to be appended.
	//   - The `node` parameter is the VariableStatement whose exports are to be recorded.
	function appendExportsOfVariableStatement(statements:Array<Statement>, node:VariableStatement):Array<Statement> {
		return appendExportsOfVariableDeclarationList(statements, node.DeclarationList.AsVariableDeclarationList() /*isForInOrOfInitializer*/, false);
	}

	// Appends the exports of a VariableDeclarationList to a statement list, returning the statement list.
	//
	//   - The `statements` parameter is a statement list to which the down-level export statements are to be appended.
	//   - The `node` parameter is the VariableDeclarationList whose exports are to be recorded.
	function appendExportsOfVariableDeclarationList(statements:Array<Statement>, node:VariableDeclarationList, isForInOrOfInitializer:Bool):Array<Statement> {
		if (currentModuleInfo.exportEquals != null) {
			return statements;
		}

		for (decl in rangeOf(node.Declarations.Nodes)) {
			statements = appendExportsOfBindingElement(statements, decl, isForInOrOfInitializer);
		}

		return statements;
	}

	// Appends the exports of a VariableDeclaration or BindingElement to a statement list, returning the statement list.
	//
	//   - The `statements` parameter is a statement list to which the down-level export statements are to be appended.
	//   - The `decl` parameter is the declaration whose exports are to be recorded.
	function appendExportsOfBindingElement(statements:Array<Statement>, decl:Node /*VariableDeclaration | BindingElement*/, isForInOrOfInitializer:Bool):Array<Statement> {
		if (currentModuleInfo.exportEquals != null || decl.Name() == null) {
			return statements;
		}

		if (Ast.IsBindingPattern(decl.Name())) {
			for (element in rangeOf(decl.Name().Elements())) {
				if (!Ast.IsOmittedExpression(element)) {
					statements = appendExportsOfBindingElement(statements, element, isForInOrOfInitializer);
				}
			}
		} else if (!Transformers.IsGeneratedIdentifier(EmitContext(), decl.Name())
			&& (!Ast.IsVariableDeclaration(decl) || decl.Initializer() != null || isForInOrOfInitializer)) {
			statements = appendExportsOfDeclaration(statements, decl, null /*seen*/, false /*liveBinding*/);
		}

		return statements;
	}

	// Appends the exports of a ClassDeclaration or FunctionDeclaration to a statement list, returning the statement list.
	//
	//   - The `statements` parameter is a statement list to which the down-level export statements are to be appended.
	//   - The `decl` parameter is the declaration whose exports are to be recorded.
	function appendExportsOfClassOrFunctionDeclaration(statements:Array<Statement>, decl:Declaration):Array<Statement> {
		if (currentModuleInfo.exportEquals != null) {
			return statements;
		}

		final seen = new Set<std.String>();
		if (Ast.HasSyntacticModifier(decl, ModifierFlagsExport)) {
			var exportName:IdentifierNode;
			if (Ast.HasSyntacticModifier(decl, ModifierFlagsDefault)) {
				exportName = Factory().NewIdentifier("default");
			} else {
				exportName = Factory().GetDeclarationName(decl);
			}

			final exportValue = Factory().GetLocalName(decl);
			statements = appendExportStatement(statements, seen, exportName, exportValue, decl.Loc, false /*allowComments*/, false /*liveBinding*/);
		}

		if (decl.Name() != null) {
			return appendExportsOfDeclaration(statements, decl, seen, false /*liveBinding*/);
		}

		return statements;
	}

	// Appends the exports of a declaration to a statement list, returning the statement list.
	//
	//   - The `statements` parameter is a statement list to which the down-level export statements are to be appended.
	//   - The `decl` parameter is the declaration to export.
	function appendExportsOfDeclaration(statements:Array<Statement>, decl:Declaration, seen:Set<std.String>, liveBinding:Bool):Array<Statement> {
		if (currentModuleInfo.exportEquals != null) {
			return statements;
		}

		if (seen == null) {
			seen = new Set<std.String>();
		}

		var name = decl.Name();
		if (currentModuleInfo.exportSpecifiers.Len() > 0 && name != null && Ast.IsIdentifier(name)) {
			name = Factory().GetDeclarationName(decl);
			final exportSpecifiers = currentModuleInfo.exportSpecifiers.Get(name.Text());
			if (Core.len(exportSpecifiers) > 0) {
				final exportValue = visitExpressionIdentifier(name);
				for (exportSpecifier in exportSpecifiers) {
					statements = appendExportStatement(statements, seen, exportSpecifier.Name(), exportValue, exportSpecifier.Name().Loc /*location*/,
						false /*allowComments*/, liveBinding);
				}
			}
		}

		return statements;
	}

	// Appends the down-level representation of an export to a statement list, returning the statement list.
	//
	//   - The `statements` parameter is a statement list to which the down-level export statements are to be appended.
	//   - The `exportName` parameter is the name of the export.
	//   - The `expression` parameter is the expression to export.
	//   - The `location` parameter is the location to use for source maps and comments for the export.
	//   - The `allowComments` parameter indicates whether to allow comments on the export.
	function appendExportStatement(statements:Array<Statement>, seen:Set<std.String>, exportName:ModuleExportName, expression:Expression, location:TextRange,
			allowComments:Bool, liveBinding:Bool):Array<Statement> {
		if (exportName.Kind != KindStringLiteral) {
			if (seen.Has(exportName.Text())) {
				return statements;
			}
			seen.Add(exportName.Text());
		}
		statements = append(statements, createExportStatement(exportName, expression, location, allowComments, liveBinding));
		return statements;
	}

	// Creates a call to the current file's export function to export a value.
	//
	//   - The `name` parameter is the bound name of the export.
	//   - The `value` parameter is the exported value.
	//   - The `location` parameter is the location to use for source maps and comments for the export.
	//   - The `allowComments` parameter indicates whether to emit comments for the statement.
	function createExportStatement(name:ModuleExportName, value:Expression, location:TextRange, allowComments:Bool, liveBinding:Bool):Statement {
		final statement = Factory().NewExpressionStatement(createExportExpression(name, value, null /*location*/, liveBinding));
		if (location != null) {
			EmitContext().SetCommentRange(statement, location);
		}
		EmitContext().AddEmitFlags(statement, EFStartOnNewLine);
		if (!allowComments) {
			EmitContext().AddEmitFlags(statement, EFNoComments);
		}
		return statement;
	}

	// Creates a call to the current file's export function to export a value.
	//
	//   - The `name` parameter is the bound name of the export.
	//   - The `value` parameter is the exported value.
	//   - The `location` parameter is the location to use for source maps and comments for the export.
	function createExportExpression(name:ModuleExportName, value:Expression, location:TextRange, liveBinding:Bool):Expression {
		var expression:Expression;
		if (liveBinding) {
			// For a live binding we emit a getter on `exports` that returns the value:
			//  Object.defineProperty(exports, "<name>", { enumerable: true, get: function () { return <value>; } });
			expression = Factory().NewCallExpression(Factory().NewPropertyAccessExpression(Factory().NewIdentifier("Object"), null, /*questionDotToken*/
				Factory().NewIdentifier("defineProperty"), NodeFlagsNone),
				null, /*questionDotToken*/
				null, /*typeArguments*/
				Factory().NewNodeList([
					Factory().NewIdentifier("exports"),
					Factory().NewStringLiteralFromNode(name),
					Factory().NewObjectLiteralExpression(Factory().NewNodeList([
						Factory().NewPropertyAssignment(null, /*modifiers*/
							Factory().NewIdentifier("enumerable"), null, /*postfixToken*/
							null, /*typeNode*/
							Factory().NewTrueExpression()),
						Factory().NewPropertyAssignment(null, /*modifiers*/
							Factory().NewIdentifier("get"), null, /*postfixToken*/
							null, /*typeNode*/
							Factory().NewFunctionExpression(null, /*modifiers*/
								null, /*asteriskToken*/
								null, /*name*/
								null, /*typeParameters*/
								Factory().NewNodeList([]), null, /*type*/
								null, /*fullSignature*/
								Factory().NewBlock(Factory().NewNodeList([Factory().NewReturnStatement(value),]), false /*multiLine*/))),
					]), false /*multiLine*/),
				]), NodeFlagsNone);
		} else {
			// Otherwise, we emit a simple property assignment.
			var left:Expression;
			if (name.Kind == KindStringLiteral) {
				// emits:
				//  exports["<name>"] = <value>;
				left = Factory().NewElementAccessExpression(Factory().NewIdentifier("exports"), null, /*questionDotToken*/
					Factory().NewStringLiteralFromNode(name), NodeFlagsNone);
			} else {
				// emits:
				//  exports.<name> = <value>;
				left = Factory().NewPropertyAccessExpression(Factory().NewIdentifier("exports"), null, /*questionDotToken*/
					name.Clone(Factory()), NodeFlagsNone);
			}
			expression = Factory().NewAssignmentExpression(left, value);
		}
		if (location != null) {
			EmitContext().SetCommentRange(expression, location);
		}
		return expression;
	}

	// Creates a `require()` call to import an external module.
	function createRequireCall(node:Node /*ImportDeclaration | ImportEqualsDeclaration | ExportDeclaration*/):Node {
		var args:Array<Expression> = null;
		final moduleName = Moduletransforms.getExternalModuleNameLiteral(Factory(), node, currentSourceFile, null /*host*/, null /*resolver*/, compilerOptions);
		if (moduleName != null) {
			args = [Moduletransforms.rewriteModuleSpecifier(EmitContext(), moduleName, compilerOptions)];
		}
		return Factory().NewCallExpression(Factory().NewIdentifier("require"), null, /*questionDotToken*/
			null, /*typeArguments*/
			Factory().NewNodeList(args), NodeFlagsNone);
	}

	function getHelperExpressionForExport(node:ExportDeclaration, innerExpr:Expression):Expression {
		if (Moduletransforms.getExportNeedsImportStarHelper(node)) {
			return Visitor().VisitNode(Factory().NewImportStarHelper(innerExpr));
		}
		return innerExpr;
	}

	function getHelperExpressionForImport(node:ImportDeclaration, innerExpr:Expression):Expression {
		if (Moduletransforms.getImportNeedsImportStarHelper(node)) {
			return Visitor().VisitNode(Factory().NewImportStarHelper(innerExpr));
		}
		if (Moduletransforms.getImportNeedsImportDefaultHelper(node)) {
			return Visitor().VisitNode(Factory().NewImportDefaultHelper(innerExpr));
		}
		return innerExpr;
	}

	function visitTopLevelImportDeclaration(node:ImportDeclaration):Node {
		if (node.ImportClause == null) {
			// import "mod";
			final statement = Factory().NewExpressionStatement(createRequireCall(node.AsNode()));
			EmitContext().SetOriginal(statement, node.AsNode());
			EmitContext().AssignCommentAndSourceMapRanges(statement, node.AsNode());
			return statement;
		}

		var statements:Array<Statement> = null;
		final variables:Array<VariableDeclarationNode> = [];
		final namespaceDeclaration = Ast.GetNamespaceDeclarationNode(node.AsNode());
		if (namespaceDeclaration != null && !Ast.IsDefaultImport(node.AsNode())) {
			// import * as n from "mod";
			variables.push(Factory().NewVariableDeclaration(namespaceDeclaration.Name().Clone(Factory()), null, /*exclamationToken*/
				null, /*type*/
				getHelperExpressionForImport(node, createRequireCall(node.AsNode()))));
		} else {
			// import d from "mod";
			// import { x, y } from "mod";
			// import d, { x, y } from "mod";
			// import d, * as n from "mod";
			variables.push(Factory().NewVariableDeclaration(Factory().NewGeneratedNameForNode(node.AsNode()), null, /*exclamationToken*/
				null, /*type*/
				getHelperExpressionForImport(node, createRequireCall(node.AsNode()))));

			if (namespaceDeclaration != null && Ast.IsDefaultImport(node.AsNode())) {
				variables.push(Factory().NewVariableDeclaration(namespaceDeclaration.Name().Clone(Factory()), null, /*exclamationToken*/
					null, /*type*/
					Factory().NewGeneratedNameForNode(node.AsNode())));
			}
		}

		final varStatement = Factory().NewVariableStatement(null, /*modifiers*/
			Factory().NewVariableDeclarationList(Factory().NewNodeList(variables), NodeFlagsConst));

		EmitContext().SetOriginal(varStatement, node.AsNode());
		EmitContext().AssignCommentAndSourceMapRanges(varStatement, node.AsNode());
		statements = append(statements, varStatement);
		statements = appendExportsOfImportDeclaration(statements, node);
		return Transformers.SingleOrMany(statements, Factory());
	}

	function visitTopLevelImportEqualsDeclaration(node:ImportEqualsDeclaration):Node {
		if (!Ast.IsExternalModuleImportEqualsDeclaration(node.AsNode())) {
			// import m = n;
			throw "import= for internal module references should be handled in an earlier transformer.";
		}

		var statements:Array<Statement> = null;
		if (Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsExport)) {
			// export import m = require("mod");
			final statement = Factory().NewExpressionStatement(createExportExpression(node.Name(), createRequireCall(node.AsNode()), node.Loc,
				false /*liveBinding*/));

			EmitContext().SetOriginal(statement, node.AsNode());
			EmitContext().AssignCommentAndSourceMapRanges(statement, node.AsNode());
			statements = append(statements, statement);
		} else {
			// import m = require("mod");
			final statement = Factory().NewVariableStatement(null, /*modifiers*/
				Factory().NewVariableDeclarationList(Factory().NewNodeList([
					Factory().NewVariableDeclaration(node.Name().Clone(Factory()), null, /*exclamationToken*/
						null, /*typeNode*/
						createRequireCall(node.AsNode())),
				]), NodeFlagsConst));
			EmitContext().SetOriginal(statement, node.AsNode());
			EmitContext().AssignCommentAndSourceMapRanges(statement, node.AsNode());
			statements = append(statements, statement);
		}

		statements = appendExportsOfDeclaration(statements, node.AsNode(), null /*seen*/, false /*liveBinding*/);
		return Transformers.SingleOrMany(statements, Factory());
	}

	function visitTopLevelExportDeclaration(node:ExportDeclaration):Node {
		if (node.ModuleSpecifier == null) {
			// Elide export declarations with no module specifier as they are handled
			// elsewhere.
			return null;
		}

		final generatedName = Factory().NewGeneratedNameForNode(node.AsNode());
		if (node.ExportClause != null && Ast.IsNamedExports(node.ExportClause)) {
			// export { x, y } from "mod";
			var statements:Array<Statement> = null;
			final varStatement = Factory().NewVariableStatement(null, /*modifiers*/
				Factory().NewVariableDeclarationList(Factory().NewNodeList([
					Factory().NewVariableDeclaration(generatedName, null, /*exclamationToken*/
						null, /*type*/
						createRequireCall(node.AsNode())),
				]), NodeFlagsNone));
			EmitContext().SetOriginal(varStatement, node.AsNode());
			EmitContext().AssignCommentAndSourceMapRanges(varStatement, node.AsNode());
			statements = append(statements, varStatement);

			for (specifier in rangeOf(node.ExportClause.Elements())) {
				final specifierName = specifier.PropertyNameOrName();
				final exportNeedsImportDefault = Ast.ModuleExportNameIsDefault(specifierName);

				var target:Node;
				if (exportNeedsImportDefault) {
					target = Factory().NewImportDefaultHelper(generatedName);
				} else {
					target = generatedName;
				}

				var exportName:Node;
				if (Ast.IsStringLiteral(specifier.Name())) {
					exportName = Factory().NewStringLiteralFromNode(specifier.Name());
				} else {
					exportName = Factory().GetExportName(specifier.AsNode());
				}

				var exportedValue:Node;
				if (Ast.IsStringLiteral(specifierName)) {
					exportedValue = Factory().NewElementAccessExpression(target, null /*questionDotToken*/, specifierName, NodeFlagsNone);
				} else {
					exportedValue = Factory().NewPropertyAccessExpression(target, null /*questionDotToken*/, specifierName, NodeFlagsNone);
				}
				final statement = Factory().NewExpressionStatement(createExportExpression(exportName, exportedValue, null, /*location*/
					true /*liveBinding*/));
				EmitContext().SetOriginal(statement, specifier.AsNode());
				EmitContext().AssignCommentAndSourceMapRanges(statement, specifier.AsNode());
				statements = append(statements, statement);
			}

			return Transformers.SingleOrMany(statements, Factory());
		}

		if (node.ExportClause != null) {
			// export * as ns from "mod";
			// export * as default from "mod";
			var exportName:Node;
			if (Ast.IsStringLiteral(node.ExportClause.Name())) {
				exportName = Factory().NewStringLiteralFromNode(node.ExportClause.Name());
			} else {
				exportName = node.ExportClause.Name().Clone(Factory());
			}
			final statement = Factory().NewExpressionStatement(createExportExpression(exportName,
				getHelperExpressionForExport(node, createRequireCall(node.AsNode())), null, /*location*/
				false /*liveBinding*/));
			EmitContext().SetOriginal(statement, node.AsNode());
			EmitContext().AssignCommentAndSourceMapRanges(statement, node.AsNode());
			return statement;
		}

		// export * from "mod";
		final statement = Factory().NewExpressionStatement(Visitor()
			.VisitNode(Factory().NewExportStarHelper(createRequireCall(node.AsNode()), Factory().NewIdentifier("exports"))));
		EmitContext().SetOriginal(statement, node.AsNode());
		EmitContext().AssignCommentAndSourceMapRanges(statement, node.AsNode());
		return statement;
	}

	function visitTopLevelExportAssignment(node:ExportAssignment):Node {
		if (node.IsExportEquals) {
			return null;
		}

		return createExportStatement(Factory().NewIdentifier("default"), Visitor().VisitNode(node.Expression), node.Loc, /*location*/
			true, /*allowComments*/
			false /*liveBinding*/);
	}

	function visitTopLevelFunctionDeclaration(node:FunctionDeclaration):Node {
		if (Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsExport)) {
			return Factory().UpdateFunctionDeclaration(node, Transformers.ExtractModifiers(EmitContext(), node.Modifiers(), ~ModifierFlagsExportDefault),
				node.AsteriskToken, Factory().GetDeclarationName(node.AsNode()), null, /*typeParameters*/
				Visitor().VisitNodes(node.Parameters), null, /*type*/
				null, /*fullSignature*/
				Visitor().VisitNode(node.Body));
		} else {
			return Visitor().VisitEachChild(node.AsNode());
		}
	}

	function visitTopLevelClassDeclaration(node:ClassDeclaration):Node {
		var statements:Array<Statement> = null;
		if (Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsExport)) {
			statements = append(statements,
				Factory().UpdateClassDeclaration(node, Visitor().VisitModifiers(Transformers.ExtractModifiers(EmitContext(), node.Modifiers(), ~ModifierFlagsExportDefault)),
					Factory().GetDeclarationName(node.AsNode()), null, /*typeParameters*/
					Visitor().VisitNodes(node.HeritageClauses), Visitor().VisitNodes(node.Members)));
		} else {
			statements = append(statements, Visitor().VisitEachChild(node.AsNode()));
		}
		statements = appendExportsOfClassOrFunctionDeclaration(statements, node.AsNode());
		return Transformers.SingleOrMany(statements, Factory());
	}

	function visitTopLevelVariableStatement(node:VariableStatement):Node {
		var statements:Array<Statement> = null;
		if (Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsExport)) {
			// export var a = b;
			var variables:Array<VariableDeclarationNode> = null;
			var expressions:Array<Expression> = null;
			var modifiers:ModifierList = null;

			final commitPendingVariables = function() {
				if (Core.len(variables) > 0) {
					final variableList = Factory().NewNodeList(variables);
					final statement = Factory().UpdateVariableStatement(node, modifiers,
						Factory().UpdateVariableDeclarationList(node.DeclarationList.AsVariableDeclarationList(), variableList, node.DeclarationList.Flags));
					if (Core.len(statements) > 0) {
						EmitContext().AddEmitFlags(statement, EFNoComments);
					}
					statements = append(statements, statement);
					variables = null;
				}
			};

			final commitPendingExpressions = function() {
				if (Core.len(expressions) > 0) {
					final statement = Factory().NewExpressionStatement(Factory().InlineExpressions(expressions));
					EmitContext().AssignCommentAndSourceMapRanges(statement, node.AsNode());
					if (Core.len(statements) > 0) {
						EmitContext().AddEmitFlags(statement, EFNoComments);
					}
					statements = append(statements, statement);
					expressions = null;
				}
			};

			final pushVariable = function(variable:VariableDeclarationNode) {
				commitPendingExpressions();
				if (variables == null) {
					variables = [];
				}
				variables.push(variable);
			};

			final pushExpression = function(expression:Expression) {
				commitPendingVariables();
				if (expressions == null) {
					expressions = [];
				}
				expressions.push(expression);
			};

			// If we're exporting these variables, then these just become assignments to 'exports.x'.
			for (variable in rangeOf(node.DeclarationList.AsVariableDeclarationList().Declarations.Nodes)) {
				final v = variable.AsVariableDeclaration();

				if (Ast.IsIdentifier(v.Name()) && Transformers.IsLocalName(EmitContext(), v.Name())) {
					// A "local name" generally means a variable declaration that *shouldn't* be
					// converted to `exports.x = ...`, even if the declaration is exported. This
					// usually indicates a class or function declaration that was converted into
					// a variable declaration, as most references to the declaration will remain
					// untransformed (i.e., `new C` rather than `new exports.C`). In these cases,
					// an `export { x }` declaration will follow.

					if (modifiers == null) {
						modifiers = Transformers.ExtractModifiers(EmitContext(), node.Modifiers(), ~ModifierFlagsExportDefault);
					}

					if (v.Initializer != null) {
						variable = Factory().UpdateVariableDeclaration(v, v.Name(), null, /*exclamationToken*/
							null, /*type*/
							createExportExpression(v.Name(), Visitor().VisitNode(v.Initializer), null, false /*liveBinding*/));
					}

					pushVariable(variable);
				} else if (v.Initializer != null
					&& !Ast.IsBindingPattern(v.Name())
					&& (Ast.IsArrowFunction(v.Initializer) || Ast.IsFunctionExpression(v.Initializer) || Ast.IsClassExpression(v.Initializer))) {
					// preserve variable declarations for functions and classes to assign names

					pushVariable(Factory().NewVariableDeclaration(v.Name(), v.ExclamationToken, v.Type, Visitor().VisitNode(v.Initializer)));

					final propertyAccess = Factory().NewPropertyAccessExpression(Factory().NewIdentifier("exports"), null, /*questionDotToken*/
						v.Name(), NodeFlagsNone);
					EmitContext().AssignCommentAndSourceMapRanges(propertyAccess, v.Name());

					pushExpression(Factory().NewAssignmentExpression(propertyAccess, v.Name().Clone(Factory())));
				} else if (Ast.IsIdentifier(v.Name())) {
					final expression = transformInitializedVariable(v);
					if (expression != null) {
						pushExpression(Visitor().VisitNode(expression));
					}
				} else if (Ast.IsBindingPattern(v.Name())) {
					// For binding patterns with export modifier, use flattenDestructuringAssignment
					// to decompose into individual export assignments
					final expression = transformInitializedVariable(v);
					if (expression != null) {
						pushExpression(expression);
					}
				} else {
					// For binding patterns, we can't do exports.{pattern} = value
					// Just emit the assignment and let appendExportsOfVariableStatement handle the exports
					final expression = Transformers.ConvertVariableDeclarationToAssignmentExpression(EmitContext(), v);
					if (expression != null) {
						pushExpression(Visitor().VisitNode(expression));
					}
				}
			}

			commitPendingVariables();
			commitPendingExpressions();
			statements = appendExportsOfVariableStatement(statements, node);
			return Transformers.SingleOrMany(statements, Factory());
		}
		return visitTopLevelNestedVariableStatement(node);
	}

	function transformInitializedVariable(node:VariableDeclaration):Expression {
		if (node.Initializer == null) {
			return null;
		}
		final name = node.Name();
		if (Ast.IsBindingPattern(name)) {
			// Convert the binding pattern into an equivalent assignment expression and visit it
			// as a destructuring assignment. This preserves native destructuring (and therefore
			// iterator semantics for array patterns) whenever each leaf identifier can be
			// substituted to an export reference. Only when the destructuring would assign to
			// re-aliased or multi-exported names (where native destructuring cannot update all
			// targets) does `visitDestructuringAssignment` fall back to flattening.
			final assignment = Transformers.ConvertVariableDeclarationToAssignmentExpression(EmitContext(), node);
			final grandparentNode = pushNode(assignment);
			final result = visitDestructuringAssignment(assignment.AsBinaryExpression(), true /*valueIsDiscarded*/);
			popNode(grandparentNode); // PORT: defer
			return result;
		}
		final propertyAccess = Factory().NewPropertyAccessExpression(Factory().NewIdentifier("exports"), null, /*questionDotToken*/
			name, NodeFlagsNone);
		EmitContext().AssignCommentAndSourceMapRanges(propertyAccess, name);
		return Factory().NewAssignmentExpression(propertyAccess, node.Initializer);
	}

	// Visits a top-level nested variable statement as it may contain `var` declarations that are hoisted and may still be
	// exported with `export {}`.
	function visitTopLevelNestedVariableStatement(node:VariableStatement):Node {
		var statements:Array<Statement> = null;
		statements = append(statements, Visitor().VisitEachChild(node.AsNode()));
		statements = appendExportsOfVariableStatement(statements, node);
		return Transformers.SingleOrMany(statements, Factory());
	}

	// Visits a top-level nested `for` statement as it may contain `var` declarations that are hoisted and may still be
	// exported with `export {}`.
	function visitTopLevelNestedForStatement(node:ForStatement):Node {
		if (node.Initializer != null && Ast.IsVariableDeclarationList(node.Initializer) && (node.Initializer.Flags & NodeFlagsBlockScoped) == 0) {
			final exportStatements = appendExportsOfVariableDeclarationList(null /*statements*/, node.Initializer.AsVariableDeclarationList(),
				false /*isForInOrOfInitializer*/);
			if (Core.len(exportStatements) > 0) {
				// given:
				//   export { x }
				//   for (var x = 0; ;) { }
				// emits:
				//   var x = 0;
				//   exports.x = x;
				//   for (; ;) { }

				var statements:Array<Statement> = null;
				final varDeclList = discardedValueVisitor.VisitNode(node.Initializer);
				final varStatement = Factory().NewVariableStatement(null /*modifiers*/, varDeclList);
				statements = append(statements, varStatement);
				for (s in exportStatements) {
					statements.push(s);
				}

				final condition = Visitor().VisitNode(node.Condition);
				final incrementor = discardedValueVisitor.VisitNode(node.Incrementor);
				final body = EmitContext().VisitIterationBody(node.Statement, topLevelNestedVisitor);
				statements = append(statements, Factory().UpdateForStatement(node, null, /*initializer*/
					condition, incrementor, body));
				return Transformers.SingleOrMany(statements, Factory());
			}
		}
		return Factory().UpdateForStatement(node, discardedValueVisitor.VisitNode(node.Initializer), Visitor().VisitNode(node.Condition),
			discardedValueVisitor.VisitNode(node.Incrementor), EmitContext().VisitIterationBody(node.Statement, topLevelNestedVisitor));
	}

	// Visits a top-level nested `for..in` or `for..of` statement as it may contain `var` declarations that are hoisted and
	// may still be exported with `export {}`.
	function visitTopLevelNestedForInOrOfStatement(node:ForInOrOfStatement):Node {
		if (Ast.IsVariableDeclarationList(node.Initializer) && (node.Initializer.Flags & NodeFlagsBlockScoped) == 0) {
			final exportStatements = appendExportsOfVariableDeclarationList(null /*statements*/, node.Initializer.AsVariableDeclarationList(),
				true /*isForInOrOfInitializer*/);
			if (Core.len(exportStatements) > 0) {
				// given:
				//   export { x }
				//   for (var x in y) {
				//     ...
				//   }
				// emits:
				//   for (var x in y) {
				//     exports.x = x;
				//     ...
				//   }

				final initializer = discardedValueVisitor.VisitNode(node.Initializer);
				final expression = Visitor().VisitNode(node.Expression);
				var body = EmitContext().VisitIterationBody(node.Statement, topLevelNestedVisitor);
				if (Ast.IsBlock(body)) {
					final block = body.AsBlock();
					final bodyStatements = block.Statements.Nodes == null ? exportStatements : exportStatements.concat(block.Statements.Nodes);
					final bodyStatementList = Factory().NewNodeList(bodyStatements);
					bodyStatementList.Loc = block.Statements.Loc;
					body = Factory().UpdateBlock(block, bodyStatementList, block.MultiLine);
				} else {
					final bodyStatements = exportStatements.concat([body]);
					body = Factory().NewBlock(Factory().NewNodeList(bodyStatements), true /*multiLine*/);
				}
				return Factory().UpdateForInOrOfStatement(node, node.AwaitModifier, initializer, expression, body);
			}
		}
		return Factory().UpdateForInOrOfStatement(node, node.AwaitModifier, discardedValueVisitor.VisitNode(node.Initializer),
			Visitor().VisitNode(node.Expression), EmitContext().VisitIterationBody(node.Statement, topLevelNestedVisitor));
	}

	// Visits a top-level nested `do` statement as it may contain `var` declarations that are hoisted and may still be
	// exported with `export {}`.
	function visitTopLevelNestedDoStatement(node:DoStatement):Node {
		return Factory().UpdateDoStatement(node, EmitContext().VisitIterationBody(node.Statement, topLevelNestedVisitor), Visitor().VisitNode(node.Expression));
	}

	// Visits a top-level nested `while` statement as it may contain `var` declarations that are hoisted and may still be
	// exported with `export {}`.
	function visitTopLevelNestedWhileStatement(node:WhileStatement):Node {
		return Factory().UpdateWhileStatement(node, Visitor().VisitNode(node.Expression), EmitContext().VisitIterationBody(node.Statement, topLevelNestedVisitor));
	}

	// Visits a top-level nested labeled statement as it may contain `var` declarations that are hoisted and may still be
	// exported with `export {}`.
	function visitTopLevelNestedLabeledStatement(node:LabeledStatement):Node {
		var statement = topLevelNestedVisitor.VisitEmbeddedStatement(node.Statement);
		if (statement == null) {
			statement = Factory().NewEmptyStatement();
		}
		return Factory().UpdateLabeledStatement(node, node.Label, statement);
	}

	// Visits a top-level nested `with` statement as it may contain `var` declarations that are hoisted and may still be
	// exported with `export {}`.
	function visitTopLevelNestedWithStatement(node:WithStatement):Node {
		return Factory().UpdateWithStatement(node, Visitor().VisitNode(node.Expression), topLevelNestedVisitor.VisitEmbeddedStatement(node.Statement));
	}

	// Visits a top-level nested `if` statement as it may contain `var` declarations that are hoisted and may still be
	// exported with `export {}`.
	function visitTopLevelNestedIfStatement(node:IfStatement):Node {
		final expression = Visitor().VisitNode(node.Expression);
		var thenStatement = topLevelNestedVisitor.VisitEmbeddedStatement(node.ThenStatement);
		if (thenStatement == null) {
			thenStatement = Factory().NewBlock(Factory().NewNodeList(null), false /*multiLine*/);
		}
		final elseStatement = topLevelNestedVisitor.VisitEmbeddedStatement(node.ElseStatement);
		return Factory().UpdateIfStatement(node, expression, thenStatement, elseStatement);
	}

	// Visits a top-level nested `switch` statement as it may contain `var` declarations that are hoisted and may still be
	// exported with `export {}`.
	function visitTopLevelNestedSwitchStatement(node:SwitchStatement):Node {
		return Factory().UpdateSwitchStatement(node, Visitor().VisitNode(node.Expression), topLevelNestedVisitor.VisitNode(node.CaseBlock));
	}

	// Visits a top-level nested case block as it may contain `var` declarations that are hoisted and may still be exported
	// with `export {}`.
	function visitTopLevelNestedCaseBlock(node:CaseBlock):Node {
		return topLevelNestedVisitor.VisitEachChild(node.AsNode());
	}

	// Visits a top-level nested `case` or `default` clause as it may contain `var` declarations that are hoisted and may
	// still be exported with `export {}`.
	function visitTopLevelNestedCaseOrDefaultClause(node:CaseOrDefaultClause):Node {
		return Factory().UpdateCaseOrDefaultClause(node, Visitor().VisitNode(node.Expression), topLevelNestedVisitor.VisitNodes(node.Statements));
	}

	// Visits a top-level nested `try` statement as it may contain `var` declarations that are hoisted and may still be
	// exported with `export {}`.
	function visitTopLevelNestedTryStatement(node:TryStatement):Node {
		return topLevelNestedVisitor.VisitEachChild(node.AsNode());
	}

	// Visits a top-level nested `catch` clause as it may contain `var` declarations that are hoisted and may still be
	// exported with `export {}`.
	function visitTopLevelNestedCatchClause(node:CatchClause):Node {
		return Factory().UpdateCatchClause(node, node.VariableDeclaration, topLevelNestedVisitor.VisitNode(node.Block));
	}

	// Visits a top-level nested block as it may contain `var` declarations that are hoisted and may still be exported with
	// `export {}`.
	function visitTopLevelNestedBlock(node:Block):Node {
		return topLevelNestedVisitor.VisitEachChild(node.AsNode());
	}

	function visitForStatement(node:ForStatement):Node {
		return Factory().UpdateForStatement(node, discardedValueVisitor.VisitNode(node.Initializer), Visitor().VisitNode(node.Condition),
			discardedValueVisitor.VisitNode(node.Incrementor), EmitContext().VisitIterationBody(node.Statement, topLevelNestedVisitor));
	}

	function visitForInOrOfStatement(node:ForInOrOfStatement):Node {
		return Factory().UpdateForInOrOfStatement(node, node.AwaitModifier, discardedValueVisitor.VisitNode(node.Initializer),
			Visitor().VisitNode(node.Expression), EmitContext().VisitIterationBody(node.Statement, topLevelNestedVisitor));
	}

	// Visits an expression statement whose value will be discarded at runtime.
	function visitExpressionStatement(node:ExpressionStatement):Node {
		return discardedValueVisitor.VisitEachChild(node.AsNode());
	}

	// Visits a `void` expression whose value will be discarded at runtime.
	function visitVoidExpression(node:VoidExpression):Node {
		return discardedValueVisitor.VisitEachChild(node.AsNode());
	}

	// Visits a parenthesized expression whose value may be discarded at runtime.
	function visitParenthesizedExpression(node:ParenthesizedExpression, resultIsDiscarded:Bool):Node {
		final expression = Core.IfElse(resultIsDiscarded, discardedValueVisitor, Visitor()).VisitNode(node.Expression);
		return Factory().UpdateParenthesizedExpression(node, expression);
	}

	// Visits a partially emitted expression whose value may be discarded at runtime.
	function visitPartiallyEmittedExpression(node:PartiallyEmittedExpression, resultIsDiscarded:Bool):Node {
		final expression = Core.IfElse(resultIsDiscarded, discardedValueVisitor, Visitor()).VisitNode(node.Expression);
		return Factory().UpdatePartiallyEmittedExpression(node, expression);
	}

	// Visits a binary expression whose value may be discarded, or which might contain an assignment to an exported
	// identifier.
	function visitBinaryExpression(node:BinaryExpression, resultIsDiscarded:Bool):Node {
		if (Ast.IsDestructuringAssignment(node.AsNode())) {
			return visitDestructuringAssignment(node, resultIsDiscarded);
		}

		if (Ast.IsAssignmentExpression(node.AsNode(), false /*excludeCompoundAssignment*/)) {
			return visitAssignmentExpression(node);
		}

		if (Ast.IsCommaExpression(node.AsNode())) {
			return visitCommaExpression(node, resultIsDiscarded);
		}

		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitAssignmentExpression(node:BinaryExpression):Node {
		// When we see an assignment expression whose left-hand side is an exported symbol,
		// we should ensure all exports of that symbol are updated with the correct value.
		//
		// - We do not transform generated identifiers unless they are file-level reserved names.
		// - We do not transform identifiers tagged with the LocalName flag.
		// - We only transform identifiers that are exported at the top level.
		if (Ast.IsIdentifier(node.Left)
			&& (!Transformers.IsGeneratedIdentifier(EmitContext(), node.Left)
				|| Moduletransforms.isFileLevelReservedGeneratedIdentifier(EmitContext(), node.Left))
			&& !Transformers.IsLocalName(EmitContext(), node.Left)) {
			final exportedNames = getExports(node.Left);
			if (Core.len(exportedNames) > 0) {
				// For each additional export of the declaration, apply an export assignment.
				var expression = Visitor().VisitEachChild(node.AsNode());
				for (exportName in exportedNames) {
					expression = createExportExpression(exportName, expression, node.Loc /*location*/, false /*liveBinding*/);
				}
				return expression;
			}
		}

		return Visitor().VisitEachChild(node.AsNode());
	}

	// Visits a destructuring assignment which might target an exported identifier.
	function visitDestructuringAssignment(node:BinaryExpression, valueIsDiscarded:Bool):Node {
		if (destructuringNeedsFlattening(node.Left)) {
			return Transformers.FlattenDestructuringAssignment(Transformer, node.AsNode(), !valueIsDiscarded, /*needsValue*/
				FlattenLevelAll, createAllExportExpressions);
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	// destructuringNeedsFlattening checks whether a destructuring assignment target contains any
	// exported identifiers that need to be flattened into individual export assignments.
	function destructuringNeedsFlattening(node:Node):Bool {
		if (Ast.IsObjectLiteralExpression(node)) {
			for (elem in rangeOf(node.Properties())) {
				switch (elem.Kind) {
					case KindPropertyAssignment:
						if (destructuringNeedsFlattening(elem.Initializer())) {
							return true;
						}
					case KindShorthandPropertyAssignment:
						if (destructuringNeedsFlattening(elem.Name())) {
							return true;
						}
					case KindSpreadAssignment:
						if (destructuringNeedsFlattening(elem.Expression())) {
							return true;
						}
					case KindMethodDeclaration, KindGetAccessor, KindSetAccessor:
						return false;
					default:
				}
			}
		} else if (Ast.IsArrayLiteralExpression(node)) {
			for (elem in rangeOf(node.AsArrayLiteralExpression().Elements.Nodes)) {
				if (Ast.IsSpreadElement(elem)) {
					if (destructuringNeedsFlattening(elem.Expression())) {
						return true;
					}
				} else if (destructuringNeedsFlattening(elem)) {
					return true;
				}
			}
		} else if (Ast.IsIdentifier(node)) {
			final exportedNames = getExports(node);
			if (Transformers.IsExportName(EmitContext(), node)) {
				// The identifier is already wrapped to be an export reference; tolerate up to one
				// matching export.
				return Core.len(exportedNames) > 1;
			}
			if (Core.len(exportedNames) == 0) {
				return false;
			}
			// A single direct export whose export name matches the identifier text can be handled
			// natively: substitution will rewrite the identifier to `exports.X`, so no flattening
			// is needed. Re-aliased exports (where the export name differs from the local name) or
			// multi-exported names cannot be expressed natively in a destructuring assignment.
			if (exportedNames.length == 1 && isDirectExport(node) && exportedNames[0].Text() == node.Text()) {
				return false;
			}
			return true;
		}
		return false;
	}

	// createAllExportExpressions is the callback used during destructuring flattening to create
	// export expressions for each exported identifier binding.
	function createAllExportExpressions(name:IdentifierNode, value:Expression, location:TextRange):Expression {
		final exportedNames = getExports(name);
		if (Core.len(exportedNames) > 0) {
			// If the name is directly exported (i.e., `export let x`), assign to exports.name directly.
			// Otherwise, assign to the local binding first (i.e., `let x; export { x }`).
			var expression:Expression;
			if (isDirectExport(name)) {
				// Create exports.name = value to handle the direct export assignment,
				// since the Go port doesn't have an onSubstituteNode mechanism to rewrite identifiers.
				final exportName = name.Clone(Factory());
				EmitContext().AddEmitFlags(exportName, EFNoComments | EFNoSourceMap);
				final propertyAccess = Factory().NewPropertyAccessExpression(Factory().NewIdentifier("exports"), null, /*questionDotToken*/
					exportName, NodeFlagsNone);
				EmitContext().AddEmitFlags(propertyAccess, EFNoComments);
				expression = Factory().NewAssignmentExpression(propertyAccess, value);
				EmitContext().AssignCommentAndSourceMapRanges(expression, name);
			} else {
				expression = Factory().NewAssignmentExpression(name, value);
			}
			for (exportName in exportedNames) {
				expression = createExportExpression(exportName, expression, location, false /*liveBinding*/);
			}
			return expression;
		}
		// If the identifier is directly exported but has no additional export aliases,
		// still write to exports.name.
		if (isDirectExport(name)) {
			final exportName = name.Clone(Factory());
			EmitContext().AddEmitFlags(exportName, EFNoComments | EFNoSourceMap);
			final propertyAccess = Factory().NewPropertyAccessExpression(Factory().NewIdentifier("exports"), null, /*questionDotToken*/
				exportName, NodeFlagsNone);
			EmitContext().AddEmitFlags(propertyAccess, EFNoComments);
			final result = Factory().NewAssignmentExpression(propertyAccess, value);
			EmitContext().AssignCommentAndSourceMapRanges(result, name);
			return result;
		}
		return Factory().NewAssignmentExpression(name, value);
	}

	// isDirectExport checks whether the identifier is directly exported from the source file
	// (e.g., `export let x` or `export function f()`), as opposed to being re-exported via
	// `export { x }` for a locally-declared variable.
	function isDirectExport(name:IdentifierNode):Bool {
		final exportContainer = resolver.GetReferencedExportContainer(EmitContext().MostOriginal(name), false /*prefixLocals*/);
		return exportContainer != null && Ast.IsSourceFile(exportContainer);
	}

	function visitAssignmentProperty(node:PropertyAssignment):Node {
		return Factory().UpdatePropertyAssignment(node, null, /*modifiers*/
			Visitor().VisitNode(node.Name()), null, /*postfixToken*/
			null, /*typeNode*/
			assignmentPatternVisitor.VisitNode(node.Initializer));
	}

	function visitShorthandAssignmentProperty(node:ShorthandPropertyAssignment):Node {
		var target = visitDestructuringAssignmentTargetNoStack(node.Name());
		if (Ast.IsIdentifier(target)) {
			return Factory().UpdateShorthandPropertyAssignment(node, null, /*modifiers*/
				target, null, /*postfixToken*/
				null, /*typeNode*/
				node.EqualsToken, Visitor().VisitNode(node.ObjectAssignmentInitializer));
		}
		if (node.ObjectAssignmentInitializer != null) {
			var equalsToken = node.EqualsToken;
			if (equalsToken == null) {
				equalsToken = Factory().NewToken(KindEqualsToken);
			}
			target = Factory().NewBinaryExpression(null, /*modifiers*/
				target, null, /*typeNode*/
				equalsToken, Visitor().VisitNode(node.ObjectAssignmentInitializer));
		}
		final updated = Factory().NewPropertyAssignment(null, /*modifiers*/
			node.Name(), null, /*postfixToken*/
			null, /*typeNode*/
			target);
		EmitContext().SetOriginal(updated, node.AsNode());
		EmitContext().AssignCommentAndSourceMapRanges(updated, node.AsNode());
		return updated;
	}

	function visitAssignmentRestProperty(node:SpreadAssignment):Node {
		return Factory().UpdateSpreadAssignment(node, visitDestructuringAssignmentTarget(node.Expression));
	}

	function visitAssignmentRestElement(node:SpreadElement):Node {
		return Factory().UpdateSpreadElement(node, visitDestructuringAssignmentTarget(node.Expression));
	}

	function visitAssignmentElement(node:Node):Node {
		if (Ast.IsBinaryExpression(node)) {
			final n = node.AsBinaryExpression();
			if (n.OperatorToken.Kind == KindEqualsToken) {
				return Factory().UpdateBinaryExpression(n, null, /*modifiers*/
					visitDestructuringAssignmentTarget(n.Left), null, /*typeNode*/
					n.OperatorToken, Visitor().VisitNode(n.Right));
			}
		}

		return visitDestructuringAssignmentTargetNoStack(node);
	}

	function visitDestructuringAssignmentTarget(node:Node):Node {
		final grandparentNode = pushNode(node);

		switch (node.Kind) {
			case KindObjectLiteralExpression, KindArrayLiteralExpression:
				node = visitAssignmentPatternNoStack(node);
			default:
				node = visitDestructuringAssignmentTargetNoStack(node);
		}
		popNode(grandparentNode); // PORT: defer
		return node;
	}

	function visitDestructuringAssignmentTargetNoStack(node:Node):Node {
		if (Ast.IsIdentifier(node)
			&& (!Transformers.IsGeneratedIdentifier(EmitContext(), node) || Moduletransforms.isFileLevelReservedGeneratedIdentifier(EmitContext(), node))
			&& !Transformers.IsLocalName(EmitContext(), node)) {
			var expression = visitExpressionIdentifier(node);
			final exportedNames = getExports(node);
			if (Core.len(exportedNames) > 0) {
				// transforms:
				//  var x;
				//  export { x }
				//  { x: x } = y
				// to:
				//  { x: { set value(v) { exports.x = x = v; } }.value } = y

				final value = Factory().NewUniqueNameEx("value", new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic));
				expression = Factory().NewAssignmentExpression(expression, value);

				for (exportName in exportedNames) {
					expression = createExportExpression(exportName, expression, null /*location*/, false /*liveBinding*/);
				}

				final statement = Factory().NewExpressionStatement(expression);
				final statementList = Factory().NewNodeList([statement]);
				final param = Factory().NewParameterDeclaration(null, /*modifiers*/
					null, /*dotDotDotToken*/
					value, null, /*questionToken*/
					null, /*type*/
					null /*initializer*/);
				final valueSetter = Factory().NewSetAccessorDeclaration(null, /*modifiers*/
					Factory().NewIdentifier("value"), null, /*typeParameters*/
					Factory().NewNodeList([param]), null, /*returnType*/
					null, /*fullSignature*/
					Factory().NewBlock(statementList, false /*multiLine*/));
				final propertyList = Factory().NewNodeList([valueSetter]);
				expression = Factory().NewObjectLiteralExpression(propertyList, false /*multiLine*/);
				expression = Factory().NewPropertyAccessExpression(expression, null /*questionDotToken*/, Factory().NewIdentifier("value"), NodeFlagsNone);
			}
			return expression;
		}

		return visitNoStack(node, false /*resultIsDiscarded*/);
	}

	// Visits a comma expression whose left-hand value is always discard, and whose right-hand value may be discarded at runtime.
	function visitCommaExpression(node:BinaryExpression, resultIsDiscarded:Bool):Node {
		final left = discardedValueVisitor.VisitNode(node.Left);
		final right = Core.IfElse(resultIsDiscarded, discardedValueVisitor, Visitor()).VisitNode(node.Right);
		return Factory().UpdateBinaryExpression(node, null /*modifiers*/, left, null /*typeNode*/, node.OperatorToken, right);
	}

	// Visits a prefix unary expression that might modify an exported identifier.
	function visitPrefixUnaryExpression(node:PrefixUnaryExpression, resultIsDiscarded:Bool):Node {
		// When we see a prefix increment expression whose operand is an exported
		// symbol, we should ensure all exports of that symbol are updated with the correct
		// value.
		//
		// - We do not transform generated identifiers for any reason.
		// - We do not transform identifiers tagged with the LocalName flag.
		// - We do not transform identifiers that were originally the name of an enum or
		//   namespace due to how they are transformed in TypeScript.
		// - We only transform identifiers that are exported at the top level.
		if ((node.Operator == KindPlusPlusToken || node.Operator == KindMinusMinusToken)
			&& Ast.IsIdentifier(node.Operand)
			&& !Transformers.IsLocalName(EmitContext(), node.Operand)) {
			final exportedNames = getExports(node.Operand);
			if (Core.len(exportedNames) > 0) {
				// given:
				//   var x = 0;
				//   export { x }
				//   ++x;
				// emits:
				//   var x = 0;
				//   exports.x = x;
				//   exports.x = ++x;
				// note:
				//   after the operation, `exports.x` will hold the value of `x` after the increment.

				var expression = Factory().UpdatePrefixUnaryExpression(node, node.Operator, Visitor().VisitNode(node.Operand));
				for (exportName in exportedNames) {
					expression = createExportExpression(exportName, expression, null /*location*/, false /*liveBinding*/);
					EmitContext().AssignCommentAndSourceMapRanges(expression, node.AsNode());
				}
				return expression;
			}
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	// Visits a postfix unary expression that might modify an exported identifier.
	function visitPostfixUnaryExpression(node:PostfixUnaryExpression, resultIsDiscarded:Bool):Node {
		// When we see a postfix increment expression whose operand is an exported
		// symbol, we should ensure all exports of that symbol are updated with the correct
		// value.
		//
		// - We do not transform generated identifiers for any reason.
		// - We do not transform identifiers tagged with the LocalName flag.
		// - We do not transform identifiers that were originally the name of an enum or
		//   namespace due to how they are transformed in TypeScript.
		// - We only transform identifiers that are exported at the top level.
		if ((node.Operator == KindPlusPlusToken || node.Operator == KindMinusMinusToken)
			&& Ast.IsIdentifier(node.Operand)
			&& !Transformers.IsLocalName(EmitContext(), node.Operand)) {
			final exportedNames = getExports(node.Operand);
			if (Core.len(exportedNames) > 0) {
				// given (value is discarded):
				//   var x = 0;
				//   export { x }
				//   x++;
				// emits:
				//   var x = 0, y;
				//   exports.x = x;
				//   exports.x = (x++, x);
				// note:
				//   after the operation, `exports.x` will hold the value of `x` after the increment.
				//
				// given (value is not discarded):
				//   var x = 0, y;
				//   export { x }
				//   y = x++;
				// emits:
				//   var _a;
				//   var x = 0, y;
				//   exports.x = x;
				//   y = (exports.x = (_a = x++, x), _a);
				// note:
				//   after the operation, `exports.x` will hold the value of `x` after the increment, while
				//   `y` will hold the value of `x` before the increment.

				var temp:IdentifierNode = null;
				var expression = Factory().UpdatePostfixUnaryExpression(node, Visitor().VisitNode(node.Operand), node.Operator);
				if (!resultIsDiscarded) {
					temp = Factory().NewTempVariable();
					EmitContext().AddVariableDeclaration(temp);

					expression = Factory().NewAssignmentExpression(temp, expression);
					EmitContext().AssignCommentAndSourceMapRanges(expression, node.AsNode());
				}

				expression = Factory().NewCommaExpression(expression, node.Operand.Clone(Factory()));
				EmitContext().AssignCommentAndSourceMapRanges(expression, node.AsNode());

				for (exportName in exportedNames) {
					expression = createExportExpression(exportName, expression, null /*location*/, false /*liveBinding*/);
					EmitContext().AssignCommentAndSourceMapRanges(expression, node.AsNode());
				}

				if (temp != null) {
					expression = Factory().NewCommaExpression(expression, temp.AsNode());
					EmitContext().AssignCommentAndSourceMapRanges(expression, node.AsNode());
				}

				return expression;
			}
		}

		return Visitor().VisitEachChild(node.AsNode());
	}

	// Visits a call expression that might reference an imported symbol and thus require an indirect call, or that might
	// be an `import()` or `require()` call that may need to be rewritten.
	function visitCallExpression(node:CallExpression):Node {
		var needsRewrite = false;
		if (compilerOptions.RewriteRelativeImportExtensions.IsTrue()) {
			if (Ast.IsImportCall(node.AsNode()) && Core.len(node.Arguments.Nodes) > 0
				|| Ast.IsInJSFile(node.AsNode()) && Ast.IsRequireCall(node.AsNode(), false /*requireStringLiteralLikeArgument*/)) {
				needsRewrite = true;
			}
		}
		if (Ast.IsImportCall(node.AsNode()) && shouldTransformImportCall()) {
			return visitImportCallExpression(node, needsRewrite);
		}
		if (needsRewrite) {
			return shimOrRewriteImportOrRequireCall(node.AsNode().AsCallExpression());
		}
		if (Ast.IsIdentifier(node.Expression)) {
			// given:
			//   import { f } from "mod";
			//   f();
			// emits:
			//   const mod_1 = require("mod");
			//   (0, mod_1.f)();
			// note:
			//   the indirect call is applied by the printer by way of the `EFIndirectCall` emit flag.
			final expression = visitExpressionIdentifier(node.Expression);
			final updated = Factory().UpdateCallExpression(node, expression, node.QuestionDotToken, null, /*typeArguments*/
				Visitor().VisitNodes(node.Arguments), node.Flags);
			if (!Ast.IsIdentifier(expression) && !Transformers.IsHelperName(EmitContext(), node.Expression)) {
				EmitContext().AddEmitFlags(updated, EFIndirectCall);
			}
			return updated;
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function shouldTransformImportCall():Bool {
		return Ast.ShouldTransformImportCall(currentSourceFile.FileName(), compilerOptions, getEmitModuleFormatOfFile(hasFileName(currentSourceFile)));
	}

	function visitImportCallExpression(node:CallExpression, rewriteOrShim:Bool):Node {
		if (moduleKind == ModuleKindNone && (languageVersion : Int) >= (ScriptTargetES2020 : Int)) {
			return Visitor().VisitEachChild(node.AsNode());
		}

		final externalModuleName = Moduletransforms.getExternalModuleNameLiteral(Factory(), node.AsNode(), currentSourceFile, null /*host*/, null /*resolver*/,
			compilerOptions);
		final firstArgument = Visitor().VisitNode(Core.FirstOrNil(node.Arguments.Nodes));

		// Only use the external module name if it differs from the first argument. This allows us to preserve the quote style of the argument on output.
		var argument:Expression;
		if (externalModuleName != null
			&& (firstArgument == null || !Ast.IsStringLiteral(firstArgument) || firstArgument.Text() != externalModuleName.Text())) {
			argument = externalModuleName;
		} else if (firstArgument != null && rewriteOrShim) {
			if (Ast.IsStringLiteral(firstArgument)) {
				argument = Moduletransforms.rewriteModuleSpecifier(EmitContext(), firstArgument, compilerOptions);
			} else {
				argument = Factory().NewRewriteRelativeImportExtensionsHelper(firstArgument, compilerOptions.Jsx == JsxEmitPreserve);
			}
		} else {
			argument = firstArgument;
		}
		return createImportCallExpressionCommonJS(argument);
	}

	function createImportCallExpressionCommonJS(arg:Expression):Expression {
		// import(x)
		// emit as
		// Promise.resolve(`${x}`).then((s) => require(s)) /*CommonJS Require*/
		// We have to wrap require in then callback so that require is done in asynchronously
		// if we simply do require in resolve callback in Promise constructor. We will execute the loading immediately
		// If the arg is not inlineable, we have to evaluate and ToString() it in the current scope
		// Otherwise, we inline it in require() so that it's statically analyzable

		final needSyncEval = arg != null && !Moduletransforms.isSimpleInlineableExpression(arg);

		var promiseResolveArguments:Array<Expression> = null;
		if (needSyncEval) {
			promiseResolveArguments = [
				Factory().NewTemplateExpression(Factory().NewTemplateHead("", "", TokenFlagsNone),
					Factory().NewNodeList([
						Factory().NewTemplateSpan(arg, Factory().NewTemplateTail("", "", TokenFlagsNone)),
					])),
			];
		}
		final promiseResolveCall = Factory().NewCallExpression(Factory().NewPropertyAccessExpression(Factory().NewIdentifier("Promise"), null, /*questionDotToken*/
			Factory().NewIdentifier("resolve"), NodeFlagsNone),
			null, /*questionDotToken*/
			null, /*typeArguments*/
			Factory().NewNodeList(promiseResolveArguments), NodeFlagsNone);

		var requireArguments:Array<Expression> = null;
		if (needSyncEval) {
			requireArguments = [Factory().NewIdentifier("s"),];
		} else if (arg != null) {
			requireArguments = [arg];
		}

		final requireCall = Factory().NewImportStarHelper(Factory().NewCallExpression(Factory().NewIdentifier("require"), null, /*questionDotToken*/
			null, /*typeArguments*/
			Factory().NewNodeList(requireArguments), NodeFlagsNone));

		var parameters:Array<ParameterDeclarationNode> = null;
		if (needSyncEval) {
			parameters = [
				Factory().NewParameterDeclaration(null, /*modifiers*/
					null, /*dotDotDotToken*/
					Factory().NewIdentifier("s"), null, /*questionToken*/
					null, /*type*/
					null /*initializer*/),
			];
		}

		final function_ = Factory().NewArrowFunction(null, /*modifiers*/
			null, /*typeParameters*/
			Factory().NewNodeList(parameters), null, /*type*/
			null, /*fullSignature*/
			Factory().NewToken(KindEqualsGreaterThanToken), /*equalsGreaterThanToken*/
			requireCall);

		final downleveledImport = Factory().NewCallExpression(Factory().NewPropertyAccessExpression(promiseResolveCall, null, /*questionDotToken*/
			Factory().NewIdentifier("then"), NodeFlagsNone),
			null, /*questionDotToken*/
			null, /*typeArguments*/
			Factory().NewNodeList([function_]), NodeFlagsNone);
		return downleveledImport;
	}

	function shimOrRewriteImportOrRequireCall(node:CallExpression):Node {
		final expression = Visitor().VisitNode(node.Expression);
		var argumentsList = node.Arguments;
		if (Core.len(node.Arguments.Nodes) > 0) {
			var firstArgument = node.Arguments.Nodes[0];
			var firstArgumentChanged = false;
			if (Ast.IsStringLiteralLike(firstArgument)) {
				final rewritten = Moduletransforms.rewriteModuleSpecifier(EmitContext(), firstArgument, compilerOptions);
				firstArgumentChanged = rewritten != firstArgument;
				firstArgument = rewritten;
			} else {
				firstArgument = Factory().NewRewriteRelativeImportExtensionsHelper(firstArgument, compilerOptions.Jsx == JsxEmitPreserve);
				firstArgumentChanged = true;
			}

			final r = Visitor().VisitSlice(node.Arguments.Nodes.slice(1));
			final rest = r.a;
			final restChanged = r.b;
			if (firstArgumentChanged || restChanged) {
				final arguments = [firstArgument];
				if (rest != null) {
					for (a in rest) {
						arguments.push(a);
					}
				}
				argumentsList = Factory().NewNodeList(arguments);
				argumentsList.Loc = node.Arguments.Loc;
			}
		}

		return Factory().UpdateCallExpression(node, expression, node.QuestionDotToken, null, /*typeArguments*/
			argumentsList, node.Flags);
	}

	// Visits a tagged template expression that might reference an imported symbol and thus require an indirect call.
	function visitTaggedTemplateExpression(node:TaggedTemplateExpression):Node {
		if (Ast.IsIdentifier(node.Tag)) {
			// given:
			//   import { f } from "mod";
			//   f``;
			// emits:
			//   const mod_1 = require("mod");
			//   (0, mod_1.f) ``;
			// note:
			//   the indirect call is applied by the printer by way of the `EFIndirectCall` emit flag.

			final expression = visitExpressionIdentifier(node.Tag);
			final updated = Factory().UpdateTaggedTemplateExpression(node, expression, null, /*questionDotToken*/
				null, /*typeArguments*/
				Visitor().VisitNode(node.Template), node.Flags);
			if (!Ast.IsIdentifier(expression) && !Transformers.IsHelperName(EmitContext(), node.Tag)) {
				EmitContext().AddEmitFlags(updated, EFIndirectCall);
			}
			return updated;
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	// Visits a shorthand property assignment that might reference an imported or exported symbol.
	function visitShorthandPropertyAssignment(node:ShorthandPropertyAssignment):Node {
		final name = node.Name();
		final exportedOrImportedName = visitExpressionIdentifier(name);
		if (exportedOrImportedName != name) {
			// A shorthand property with an assignment initializer is probably part of a
			// destructuring assignment
			var expression = exportedOrImportedName;
			if (node.ObjectAssignmentInitializer != null) {
				expression = Factory().NewAssignmentExpression(expression, Visitor().VisitNode(node.ObjectAssignmentInitializer));
			}
			final assignment = Factory().NewPropertyAssignment(null /*modifiers*/, name, null /*postfixToken*/, null /*typeNode*/, expression);
			assignment.Loc = node.Loc;
			EmitContext().AssignCommentAndSourceMapRanges(assignment, node.AsNode());
			return assignment;
		}
		return Factory().UpdateShorthandPropertyAssignment(node, null, /*modifiers*/
			exportedOrImportedName, null, /*postfixToken*/
			null, /*typeNode*/
			node.EqualsToken, Visitor().VisitNode(node.ObjectAssignmentInitializer));
	}

	// Visits an identifier that, if it is in an expression position, might reference an imported or exported symbol.
	function visitIdentifier(node:IdentifierNode):Node {
		if (Transformers.IsIdentifierReference(node, parentNode)) {
			return visitExpressionIdentifier(node);
		}
		return node;
	}

	// Visits an identifier in an expression position that might reference an imported or exported symbol.
	function visitExpressionIdentifier(node:IdentifierNode):Node {
		final info = EmitContext().GetAutoGenerateInfo(node);
		if (!(info != null && !info.Flags.HasAllowNameSubstitution())
			&& !Transformers.IsHelperName(EmitContext(), node)
			&& !Transformers.IsLocalName(EmitContext(), node)
			&& !Moduletransforms.isDeclarationNameOfEnumOrNamespace(EmitContext(), node)) {
			final exportContainer = resolver.GetReferencedExportContainer(EmitContext().MostOriginal(node), Transformers.IsExportName(EmitContext(), node));
			if (exportContainer != null && Ast.IsSourceFile(exportContainer)) {
				final reference = Factory().NewPropertyAccessExpression(Factory().NewIdentifier("exports"), null, /*questionDotToken*/
					node.Clone(Factory()), NodeFlagsNone);
				EmitContext().AssignCommentAndSourceMapRanges(reference, node);
				reference.Loc = node.Loc;
				return reference;
			}

			final importDeclaration = resolver.GetReferencedImportDeclaration(EmitContext().MostOriginal(node));
			if (importDeclaration != null) {
				if (Ast.IsImportClause(importDeclaration)) {
					final reference = Factory().NewPropertyAccessExpression(Factory().NewGeneratedNameForNode(importDeclaration.Parent),
						null, /*questionDotToken*/
						Factory().NewIdentifier("default"), NodeFlagsNone);
					EmitContext().AssignCommentAndSourceMapRanges(reference, node);
					reference.Loc = node.Loc;
					return reference;
				}
				if (Ast.IsImportSpecifier(importDeclaration)) {
					final name = importDeclaration.PropertyNameOrName() /* PORT: Go AsImportSpecifier().PropertyNameOrName() is the promoted Node method */;
					final decl = Ast.FindAncestor(importDeclaration, Ast.IsImportDeclaration);
					final target = Factory().NewGeneratedNameForNode(Core.Coalesce(decl, importDeclaration));
					var reference:Node;
					if (Ast.IsStringLiteral(name)) {
						reference = Factory().NewElementAccessExpression(target, null, /*questionDotToken*/
							Factory().NewStringLiteralFromNode(name), NodeFlagsNone);
					} else {
						final referenceName = name.Clone(Factory());
						EmitContext().AddEmitFlags(referenceName, EFNoSourceMap | EFNoComments);
						reference = Factory().NewPropertyAccessExpression(target, null, /*questionDotToken*/
							referenceName, NodeFlagsNone);
					}
					EmitContext().AssignCommentAndSourceMapRanges(reference, node);
					reference.Loc = node.Loc;
					return reference;
				}
			}
		}
		return node;
	}

	// Gets the exported names of an identifier, if it is exported.
	function getExports(name:IdentifierNode):Array<ModuleExportName> {
		if (!Transformers.IsGeneratedIdentifier(EmitContext(), name)) {
			final importDeclaration = resolver.GetReferencedImportDeclaration(EmitContext().MostOriginal(name));
			if (importDeclaration != null) {
				return currentModuleInfo.exportedBindings.Get(importDeclaration);
			}

			// An exported namespace or enum may merge with an ambient declaration, which won't show up in .js emit, so
			// we analyze all value exports of a symbol.
			final bindingsSet = new Set<ModuleExportName>();
			var bindings:Array<ModuleExportName> = null;
			final declarations = resolver.GetReferencedValueDeclarations(EmitContext().MostOriginal(name));
			if (declarations != null) {
				for (declaration in declarations) {
					final exportedBindings = currentModuleInfo.exportedBindings.Get(declaration);
					if (exportedBindings != null) {
						for (binding in exportedBindings) {
							if (!bindingsSet.Has(binding)) {
								bindingsSet.Add(binding);
								if (bindings == null) {
									bindings = [];
								}
								bindings.push(binding);
							}
						}
					}
				}
				return bindings;
			}
		} else if (Moduletransforms.isFileLevelReservedGeneratedIdentifier(EmitContext(), name)) {
			final exportSpecifiers = currentModuleInfo.exportSpecifiers.Get(name.Text());
			if (exportSpecifiers != null) {
				var exportedNames:Array<ModuleExportName> = null;
				for (exportSpecifier in exportSpecifiers) {
					if (exportedNames == null) {
						exportedNames = [];
					}
					exportedNames.push(exportSpecifier.Name());
				}
				return exportedNames;
			}
		}
		return null;
	}
}
