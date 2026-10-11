package ts.transformers.moduletransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/moduletransforms/esmodule.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.moduletransforms)
class ESModuleTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var compilerOptions:CompilerOptions = null;
	var resolver:ReferenceResolver = null;
	var getEmitModuleFormatOfFile:(file:HasFileName) -> ModuleKind = null;
	var currentSourceFile:SourceFile = null;
	var importRequireStatements:ImportRequireStatements = null;
	var helperNameSubstitutions:StringMap<IdentifierNode> = null;

	public function new() {}

	// PORT: promoted methods of embedded transformers.Transformer
	inline function EmitContext():ts.printer.Emitcontext.EmitContext
		return Transformer.EmitContext();

	inline function Factory():ts.printer.Factory.NodeFactory
		return Transformer.Factory();

	inline function Visitor():ts.ast.Visitor.NodeVisitor
		return Transformer.Visitor();

	// Visits source elements that are not top-level or top-level nested statements.
	function visit(node:Node):Node {
		switch (node.Kind) {
			case KindSourceFile:
				node = visitSourceFile(node.AsSourceFile());
			case KindImportDeclaration:
				node = visitImportDeclaration(node.AsImportDeclaration());
			case KindImportEqualsDeclaration:
				node = visitImportEqualsDeclaration(node.AsImportEqualsDeclaration());
			case KindExportAssignment:
				node = visitExportAssignment(node.AsExportAssignment());
			case KindExportDeclaration:
				node = visitExportDeclaration(node.AsExportDeclaration());
			case KindCallExpression:
				node = visitCallExpression(node.AsCallExpression());
			default:
				node = Visitor().VisitEachChild(node);
		}
		return node;
	}

	function visitSourceFile(node:SourceFile):Node {
		if (node.IsDeclarationFile || !(Ast.IsExternalModule(node) || compilerOptions.GetIsolatedModules())) {
			return node.AsNode();
		}

		currentSourceFile = node;
		importRequireStatements = null;

		var result = Visitor().VisitEachChild(node.AsNode()).AsSourceFile();
		EmitContext().AddEmitHelper(result.AsNode(), ...Core.Coalesce(EmitContext().ReadEmitHelpers(), [])); // PORT: spread of a nil slice is an empty variadic call

		final externalHelpersImportDeclaration = Moduletransforms.createExternalHelpersImportDeclarationIfNeeded(EmitContext(), result, compilerOptions,
			getEmitModuleFormatOfFile(ts.modulespecifiers.Types.SourceFileAdapter.Of(node)) /* PORT: SourceFile as ast.HasFileName (adapter) */, false /*hasExportStarsToExportValues*/, false /*hasImportStar*/, false /*hasImportDefault*/);
		if (externalHelpersImportDeclaration != null || importRequireStatements != null) {
			final p1 = Factory().SplitStandardPrologue(result.Statements.Nodes);
			final prologue = p1.a;
			final p2 = Factory().SplitCustomPrologue(p1.b);
			final custom = p2.a;
			final rest = p2.b;
			var statements = Slices.Clone(prologue);
			if (statements == null)
				statements = [];
			if (custom != null)
				for (s in custom)
					statements.push(s);
			if (externalHelpersImportDeclaration != null) {
				// The helpers import must be visited so that `import x = require("tslib")`
				// (TypeScript-only syntax) is transformed to `const x = require("tslib")`
				// for CJS output files via visitImportEqualsDeclaration.
				statements.push(Visitor().VisitNode(externalHelpersImportDeclaration));
			}
			if (importRequireStatements != null) {
				for (s in importRequireStatements.statements)
					statements.push(s);
			}
			if (rest != null)
				for (s in rest)
					statements.push(s);
			final statementList = Factory().NewNodeList(statements);
			statementList.Loc = result.Statements.Loc;
			result = Factory().UpdateSourceFile(result, statementList, node.EndOfFileToken).AsSourceFile();
		}

		if (Ast.IsExternalModule(result)
			&& compilerOptions.GetEmitModuleKind() != ModuleKindPreserve
			&& !Core.Some(result.Statements.Nodes, Ast.IsExternalModuleIndicator)) {
			var statements = Slices.Clone(result.Statements.Nodes);
			if (statements == null)
				statements = [];
			statements.push(Moduletransforms.createEmptyImports(Factory()));
			final statementList = Factory().NewNodeList(statements);
			statementList.Loc = result.Statements.Loc;
			result = Factory().UpdateSourceFile(result, statementList, node.EndOfFileToken).AsSourceFile();
		}

		importRequireStatements = null;
		currentSourceFile = null;
		return result.AsNode();
	}

	function visitImportDeclaration(node:ImportDeclaration):Node {
		if (!compilerOptions.RewriteRelativeImportExtensions.IsTrue()) {
			return node.AsNode();
		}
		final updatedModuleSpecifier = Moduletransforms.rewriteModuleSpecifier(EmitContext(), node.ModuleSpecifier, compilerOptions);
		return Factory().UpdateImportDeclaration(node, null /*modifiers*/, Visitor().VisitNode(node.ImportClause), updatedModuleSpecifier,
			Visitor().VisitNode(node.Attributes));
	}

	function visitImportEqualsDeclaration(node:ImportEqualsDeclaration):Node {
		// Though an error in es2020 modules, in node-flavor es2020 modules, we can helpfully transform this to a synthetic `require` call
		// To give easy access to a synchronous `require` in node-flavor esm. We do the transform even in scenarios where we error, but `import.meta.url`
		// is available, just because the output is reasonable for a node-like runtime.
		if (compilerOptions.GetEmitModuleKind() < ModuleKindNode16) {
			return null;
		}

		if (!Ast.IsExternalModuleImportEqualsDeclaration(node.AsNode())) {
			throw "import= for internal module references should be handled in an earlier transformer.";
		}

		final varStatement = Factory().NewVariableStatement(null /*modifiers*/, Factory().NewVariableDeclarationList(Factory().NewNodeList([
			Factory().NewVariableDeclaration(node.Name().Clone(Factory()), null /*exclamationToken*/, null /*type*/, createRequireCall(node.AsNode())),
		]), NodeFlagsConst));
		EmitContext().SetOriginal(varStatement, node.AsNode());
		EmitContext().AssignCommentAndSourceMapRanges(varStatement, node.AsNode());

		var statements:Array<Statement> = [];
		statements.push(varStatement);
		statements = appendExportsOfImportEqualsDeclaration(statements, node);
		return Transformers.SingleOrMany(statements, Factory());
	}

	function appendExportsOfImportEqualsDeclaration(statements:Array<Statement>, node:ImportEqualsDeclaration):Array<Statement> {
		if (Ast.HasSyntacticModifier(node.AsNode(), ModifierFlagsExport)) {
			// PORT: Go append on a possibly-nil slice owned by the caller.
			if (statements == null)
				statements = [];
			statements.push(Factory().NewExportDeclaration(null /*modifiers*/, false /*isTypeOnly*/, Factory().NewNamedExports(Factory().NewNodeList([
				Factory().NewExportSpecifier(false /*isTypeOnly*/, null /*propertyName*/, node.Name().Clone(Factory())),
			])), null /*moduleSpecifier*/, null /*attributes*/));
		}
		return statements;
	}

	function visitExportAssignment(node:ExportAssignment):Node {
		if (!node.IsExportEquals) {
			return Visitor().VisitEachChild(node.AsNode());
		}
		if (compilerOptions.GetEmitModuleKind() != ModuleKindPreserve) {
			// Elide `export=` as it is not legal with --module ES6
			return null;
		}
		final statement = Factory().NewExpressionStatement(Factory().NewAssignmentExpression(Factory().NewPropertyAccessExpression(Factory().NewIdentifier("module"),
			null /*questionDotToken*/, Factory().NewIdentifier("exports"), NodeFlagsNone),
			Visitor().VisitNode(node.Expression)));
		EmitContext().SetOriginal(statement, node.AsNode());
		return statement;
	}

	function visitExportDeclaration(node:ExportDeclaration):Node {
		if (node.ModuleSpecifier == null) {
			return node.AsNode();
		}

		final updatedModuleSpecifier = Moduletransforms.rewriteModuleSpecifier(EmitContext(), node.ModuleSpecifier, compilerOptions);
		if (compilerOptions.Module > ModuleKindES2015 || node.ExportClause == null || !Ast.IsNamespaceExport(node.ExportClause)) {
			// Either ill-formed or don't need to be transformed.
			return Factory().UpdateExportDeclaration(node, null /*modifiers*/, false /*isTypeOnly*/, node.ExportClause, updatedModuleSpecifier,
				Visitor().VisitNode(node.Attributes));
		}

		final oldIdentifier = node.ExportClause.Name();
		final synthName = Factory().NewGeneratedNameForNode(oldIdentifier);
		final importDecl = Factory().NewImportDeclaration(null /*modifiers*/,
			Factory().NewImportClause(KindUnknown /*phaseModifier*/, null /*name*/, Factory().NewNamespaceImport(synthName)), updatedModuleSpecifier,
			Visitor().VisitNode(node.Attributes));
		EmitContext().SetOriginal(importDecl, node.ExportClause);

		var exportDecl:Node = null;
		if (Ast.IsExportNamespaceAsDefaultDeclaration(node.AsNode())) {
			exportDecl = Factory().NewExportAssignment(null /*modifiers*/, false /*isExportEquals*/, null /*typeNode*/, synthName);
		} else {
			exportDecl = Factory().NewExportDeclaration(null /*modifiers*/, false /*isTypeOnly*/,
				Factory().NewNamedExports(Factory().NewNodeList([Factory().NewExportSpecifier(false /*isTypeOnly*/, synthName, oldIdentifier),])),
				null /*moduleSpecifier*/, null /*attributes*/);
		}
		EmitContext().SetOriginal(exportDecl, node.AsNode());
		return Transformers.SingleOrMany([importDecl, exportDecl], Factory());
	}

	function visitCallExpression(node:CallExpression):Node {
		if (compilerOptions.RewriteRelativeImportExtensions.IsTrue()) {
			if (Ast.IsImportCall(node.AsNode()) && Core.len(node.Arguments.Nodes) > 0
				|| Ast.IsInJSFile(node.AsNode()) && Ast.IsRequireCall(node.AsNode(), false /*requireStringLiteralLikeArgument*/)) {
				return visitImportOrRequireCall(node);
			}
		}
		return Visitor().VisitEachChild(node.AsNode());
	}

	function visitImportOrRequireCall(node:CallExpression):Node {
		if (Core.len(node.Arguments.Nodes) == 0) {
			return Visitor().VisitEachChild(node.AsNode());
		}

		final expression = Visitor().VisitNode(node.Expression);

		var argument:Expression = null;
		if (Ast.IsStringLiteralLike(node.Arguments.Nodes[0])) {
			argument = Moduletransforms.rewriteModuleSpecifier(EmitContext(), node.Arguments.Nodes[0], compilerOptions);
		} else {
			argument = Factory().NewRewriteRelativeImportExtensionsHelper(node.Arguments.Nodes[0], compilerOptions.Jsx == JsxEmitPreserve);
		}

		final arguments:Array<Expression> = [];
		arguments.push(argument);

		final rest = Visitor().VisitSlice(node.Arguments.Nodes.slice(1));
		if (rest != null)
			for (r in rest)
				arguments.push(r);

		final argumentList = Factory().NewNodeList(arguments);
		argumentList.Loc = node.Arguments.Loc;
		return Factory().UpdateCallExpression(node, expression, node.QuestionDotToken, null /*typeArguments*/, argumentList, node.Flags);
	}

	function createRequireCall(node:Node /*ImportDeclaration | ImportEqualsDeclaration | ExportDeclaration*/):Expression {
		final moduleName = Moduletransforms.getExternalModuleNameLiteral(Factory(), node, currentSourceFile, null /*host*/, null /*emitResolver*/,
			compilerOptions);

		var args:Array<Expression> = null;
		if (moduleName != null) {
			args = [Moduletransforms.rewriteModuleSpecifier(EmitContext(), moduleName, compilerOptions)];
		}

		if (compilerOptions.GetEmitModuleKind() == ModuleKindPreserve) {
			return Factory().NewCallExpression(Factory().NewIdentifier("require"), null /*questionDotToken*/, null /*typeArguments*/,
				Factory().NewNodeList(args), NodeFlagsNone);
		}

		if (importRequireStatements == null) {
			final createRequireName = Factory().NewUniqueNameEx("_createRequire",
				new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));
			final importStatement = Factory().NewImportDeclaration(null /*modifiers*/, Factory().NewImportClause(KindUnknown /*phaseModifier*/, null /*name*/,
				Factory().NewNamedImports(Factory().NewNodeList([
					Factory().NewImportSpecifier(false /*isTypeOnly*/, Factory().NewIdentifier("createRequire"), createRequireName),
				]))),
				Factory().NewStringLiteral("module", TokenFlagsNone), null /*attributes*/);
			EmitContext().AddEmitFlags(importStatement, EFCustomPrologue);

			final requireHelperName = Factory().NewUniqueNameEx("__require",
				new AutoGenerateOptions(GeneratedIdentifierFlagsOptimistic | GeneratedIdentifierFlagsFileLevel));
			final requireStatement = Factory().NewVariableStatement(null /*modifiers*/, Factory().NewVariableDeclarationList(Factory().NewNodeList([
				Factory().NewVariableDeclaration(requireHelperName, null /*exclamationToken*/, null /*type*/,
					Factory().NewCallExpression(createRequireName.Clone(Factory()), null /*questionDotToken*/, null /*typeArguments*/,
						Factory().NewNodeList([
							Factory().NewPropertyAccessExpression(Factory().NewMetaProperty(KindImportKeyword, Factory().NewIdentifier("meta")),
								null /*questionDotToken*/, Factory().NewIdentifier("url"), NodeFlagsNone),
						]), NodeFlagsNone)),
			]), NodeFlagsConst));
			EmitContext().AddEmitFlags(requireStatement, EFCustomPrologue);
			final irs = new ImportRequireStatements();
			irs.statements = [importStatement, requireStatement];
			irs.requireHelperName = requireHelperName;
			importRequireStatements = irs;
		}

		return Factory().NewCallExpression(importRequireStatements.requireHelperName.Clone(Factory()), null /*questionDotToken*/, null /*typeArguments*/,
			Factory().NewNodeList(args), NodeFlagsNone);
	}
}

@:allow(ts.transformers.moduletransforms)
class ImportRequireStatements {
	var statements:Array<Statement> = null;
	var requireHelperName:IdentifierNode = null;

	public function new() {}
}
