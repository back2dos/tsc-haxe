package ts.transformers.declarations;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/declarations/transform.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.declarations)
class ReferencedFilePair {
	var file:SourceFile = null;
	var ref:FileReference = null;

	public function new() {}
}

interface OutputPaths {
	function DeclarationFilePath():std.String;
	function JsFilePath():std.String;
}

// Used to be passed in the TransformationContext, which is now just an EmitContext
interface DeclarationEmitHost {
	function CommonSourceDirectory():std.String;
	function FileExists(path:std.String):Bool;
	function GetCurrentDirectory():std.String;
	function GetDefaultResolutionModeForFile(file:HasFileName):ResolutionMode;
	function GetEffectiveDeclarationFlags(node:Node, flags:ModifierFlags):ModifierFlags;
	function GetEmitResolver():EmitResolver;
	function GetGlobalTypingsCacheLocation():std.String;
	function GetModeForUsageLocation(file:HasFileName, moduleSpecifier:StringLiteralLike):ResolutionMode;
	function GetNearestAncestorDirectoryWithPackageJson(dirname:std.String):std.String;
	function GetOutputPathsFor(file:SourceFile, forceDtsPaths:Bool):OutputPaths;
	function GetPackageJsonInfo(pkgJsonPath:std.String):InfoCacheEntry;
	function GetProjectReferenceFromSource(path:Path):SourceOutputAndProjectReference;
	function GetRedirectTargets(path:Path):Array<std.String>;
	function GetResolutionModeOverride(node:Node):ResolutionMode;
	function GetResolvedModuleFromModuleSpecifier(file:HasFileName, moduleSpecifier:StringLiteralLike):ResolvedModule;
	function GetSourceFileFromReference(origin:SourceFile, ref:FileReference):SourceFile;
	function GetSourceOfProjectReferenceIfOutputIncluded(file:HasFileName):std.String;
	function GetSymlinkCache():KnownSymlinks;
	function UseCaseSensitiveFileNames():Bool;
}

@:allow(ts.transformers.declarations)
class ThisPropertyAssignmentKey {
	var name:std.String = "";
	var node:Node = null;
	var isStatic:Bool = false;
	var isPrivate:Bool = false;

	public function new() {}

	// PORT: struct map key (collections.Set[thisPropertyAssignmentKey]) encoded as a String; the
	// *ast.Node field is encoded by an identity number of the owning DeclarationTransformer (0 for nil).
	public function Key(tx:DeclarationTransformer):std.String {
		return (isStatic ? "s" : "-") + (isPrivate ? "p" : "-") + tx.identityKeyOf(node) + ":" + name;
	}
}

@:allow(ts.transformers.declarations)
@:allow(ts.transformers.declarations)
class DeclarationTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var host:DeclarationEmitHost = null;
	var compilerOptions:CompilerOptions = null;
	var tracker:SymbolTrackerImpl = null;
	var state:SymbolTrackerSharedState = null;
	var resolver:EmitResolver = null;
	var declarationFilePath:std.String = "";
	var declarationMapPath:std.String = "";
	var needsDeclare:Bool = false;
	var needsScopeFixMarker:Bool = false;
	var resultHasScopeMarker:Bool = false;
	var enclosingDeclaration:Node = null;
	var resultHasExternalModuleIndicator:Bool = false;
	var suppressNewDiagnosticContexts:Bool = false;
	var witnessedCjsExports:Set<std.String> = new Set<std.String>();
	var lateStatementReplacementMap:IntMap<Node> = null;
	var expandoHosts:IntMap<Node> = null; // store the result of transforming expando hosts so they can be inserted later if the host is actually referenced
	var expandoMembers:IntMap<Array<Node>> = null; // store any found expando _members_ after transforming them so *if* the host is referenced, they can be emitted alongside it
	// PORT: struct key — Go collections.Set[thisPropertyAssignmentKey]; keys are ThisPropertyAssignmentKey.Key(tx).
	var seenProperties:Set<std.String> = new Set<std.String>();
	var thisPropertyAssignmentsCollected:Array<Node> = null;
	var rawReferencedFiles:Array<ReferencedFilePair> = null;
	var rawTypeReferenceDirectives:Array<FileReference> = null;
	var rawLibReferenceDirectives:Array<FileReference> = null;
	var bindingNameVisitor:NodeVisitor = null;
	var expressionVisitor:NodeVisitor = null;
	var cjsExportAssignmentVisitor:NodeVisitor = null;
	var exportStrippingVisitor:NodeVisitor = null;
	var thisPropertyVisitor:NodeVisitor = null;
	var cjsExportAssignment:Node = null;
	var cjsExportMembers:Array<Node> = null;
	var cjsExportAssignmentName:Node = null; // tracks the name node used for `export =` in CJS module.exports assignments
	var declareStrippingVisitor:NodeVisitor = null;
	var inClassExpressionDeclaration:Bool = false; // true when serializing members of a class expression kept as a class declaration

	// PORT: identity numbers for the *ast.Node field of the thisPropertyAssignmentKey struct key.
	var identityKeys:IdentityMap<Node, Int> = new IdentityMap<Node, Int>();
	var identityKeyCount:Int = 0;

	public function new() {}

	// PORT: struct key helper (see ThisPropertyAssignmentKey.Key).
	function identityKeyOf(node:Node):Int {
		if (node == null) {
			return 0;
		}
		var id:Null<Int> = identityKeys.get(node);
		if (id == null) {
			id = ++identityKeyCount;
			identityKeys.set(node, id);
		}
		return id;
	}

	// PORT: Go promoted methods of the embedded transformers.Transformer.
	inline function EmitContext():EmitContext {
		return Transformer.EmitContext();
	}

	inline function Visitor():NodeVisitor {
		return Transformer.Visitor();
	}

	inline function Factory():ts.printer.Factory.NodeFactory {
		return Transformer.Factory();
	}

	// PORT: Go `printer.AutoGenerateOptions{Flags: printer.GeneratedIdentifierFlagsOptimistic}` (a new value each use).
	static inline function optimisticOptions():AutoGenerateOptions {
		return new AutoGenerateOptions(ts.printer.Generatedidentifierflags.GeneratedIdentifierFlags.GeneratedIdentifierFlagsOptimistic);
	}

	public function GetDiagnostics():Array<Diagnostic> {
		return state.diagnostics;
	}

	function shouldStripInternal(node:Node):Bool {
		return state.stripInternal && node != null && isInternalDeclaration(node, state.currentSourceFile);
	}

	function isInternalDeclaration(node:Node, sourceFile:SourceFile):Bool {
		if (node == null) {
			return false;
		}
		final parseTreeNode = EmitContext().MostOriginal(node);
		if (!Ast.IsParseTreeNode(parseTreeNode)) {
			return false;
		}
		if (parseTreeNode.Kind == KindParameter) {
			final params = parseTreeNode.Parent.Parameters();
			var paramIdx = -1;
			if (params != null) {
				for (i in 0...params.length) {
					if (params[i].AsNode() == parseTreeNode) {
						paramIdx = i;
						break;
					}
				}
			}
			var previousSibling:Node = null;
			if (paramIdx > 0) {
				previousSibling = params[paramIdx - 1].AsNode();
			}

			final text = sourceFile.Text();
			var commentRanges:Array<CommentRange> = null;

			if (previousSibling != null) {
				// to handle
				// ... parameters, /** @internal */
				// public param: string
				final opts = new SkipTriviaOptions();
				opts.StopAtComments = true;
				final trailingPos = Scanner.SkipTriviaEx(text, previousSibling.End() + 1, opts);
				for (comment in Scanner.GetTrailingCommentRanges(Factory().AsNodeFactory(), text, trailingPos)) {
					if (commentRanges == null) {
						commentRanges = [];
					}
					commentRanges.push(comment);
				}
				for (comment in Scanner.GetLeadingCommentRanges(Factory().AsNodeFactory(), text, node.Pos())) {
					if (commentRanges == null) {
						commentRanges = [];
					}
					commentRanges.push(comment);
				}
			} else {
				final opts = new SkipTriviaOptions();
				opts.StopAtComments = true;
				final trailingPos = Scanner.SkipTriviaEx(text, node.Pos(), opts);
				for (comment in Scanner.GetTrailingCommentRanges(Factory().AsNodeFactory(), text, trailingPos)) {
					if (commentRanges == null) {
						commentRanges = [];
					}
					commentRanges.push(comment);
				}
			}

			if (Core.len(commentRanges) > 0) {
				return Declarations.hasInternalAnnotation(commentRanges[commentRanges.length - 1], sourceFile);
			}
			return false;
		}

		// PORT: Go range-over-func; the yield callback returns false to stop early.
		var found = false;
		getLeadingCommentRangesOfNode(parseTreeNode, sourceFile)(function(commentRange:CommentRange):Bool {
			if (Declarations.hasInternalAnnotation(commentRange, sourceFile)) {
				found = true;
				return false;
			}
			return true;
		});
		return found;
	}

	function getLeadingCommentRangesOfNode(node:Node, sourceFile:SourceFile):(yield:(CommentRange) -> Bool) -> Void {
		if (node == null || node.Kind == KindJsxText) {
			return null;
		}
		// PORT: iter.Seq over the scanner's Iterator.
		final factory = Factory().AsNodeFactory();
		final text = sourceFile.Text();
		final pos = node.Pos();
		return function(yield:(CommentRange) -> Bool):Void {
			for (c in Scanner.GetLeadingCommentRanges(factory, text, pos)) {
				if (!yield(c)) {
					return;
				}
			}
		};
	}

	// functions as both `visitDeclarationStatements` and `transformRoot`, utilitzing SyntaxList nodes
	function visit(node:Node):Node {
		if (node == null) {
			return null;
		}
		switch (node.Kind) {
			case KindSourceFile:
				return visitSourceFile(node.AsSourceFile());
			// statements we keep but do something to
			case KindFunctionDeclaration, KindModuleDeclaration, KindImportEqualsDeclaration, KindInterfaceDeclaration, KindClassDeclaration,
				KindJSTypeAliasDeclaration, KindTypeAliasDeclaration, KindEnumDeclaration, KindVariableStatement, KindImportDeclaration,
				KindJSImportDeclaration, KindExportDeclaration, KindExportAssignment:
				return visitDeclarationStatements(node);
			// statements we elide
			case KindBreakStatement, KindContinueStatement, KindDebuggerStatement, KindDoStatement, KindEmptyStatement, KindForInStatement,
				KindForOfStatement, KindForStatement, KindIfStatement, KindLabeledStatement, KindReturnStatement, KindSwitchStatement,
				KindThrowStatement, KindTryStatement, KindWhileStatement, KindWithStatement, KindNotEmittedStatement, KindBlock,
				KindMissingDeclaration, KindExpressionStatement:
				return null;
			// parts of things, things we just visit children of
			default:
				return visitDeclarationSubtree(node);
		}
	}

	function visitSourceFile(node:SourceFile):Node {
		cjsExportAssignmentName = null;
		if (node.IsDeclarationFile) {
			return node.AsNode();
		}

		needsDeclare = true;
		needsScopeFixMarker = false;
		resultHasScopeMarker = false;
		enclosingDeclaration = node.AsNode();
		state.getSymbolAccessibilityDiagnostic = Declarations.throwDiagnostic;
		resultHasExternalModuleIndicator = false;
		suppressNewDiagnosticContexts = false;
		state.lateMarkedStatements = [];
		lateStatementReplacementMap = new IntMap<Node>();
		expandoHosts = new IntMap<Node>();
		expandoMembers = new IntMap<Array<Node>>();
		rawReferencedFiles = [];
		rawTypeReferenceDirectives = [];
		rawLibReferenceDirectives = [];
		witnessedCjsExports.Clear();
		state.currentSourceFile = node;
		collectFileReferences(node);
		resolver.PrecalculateDeclarationEmitVisibility(EmitContext().MostOriginal(node.AsNode()).AsSourceFile());
		final updated = transformSourceFile(node);
		state.currentSourceFile = null;
		return updated;
	}

	function collectFileReferences(sourceFile:SourceFile):Void {
		if (sourceFile.ReferencedFiles != null) {
			for (ref in sourceFile.ReferencedFiles) {
				final pair = new ReferencedFilePair();
				pair.file = sourceFile;
				pair.ref = ref;
				rawReferencedFiles.push(pair);
			}
		}
		if (sourceFile.TypeReferenceDirectives != null) {
			for (ref in sourceFile.TypeReferenceDirectives) {
				rawTypeReferenceDirectives.push(ref);
			}
		}
		if (sourceFile.LibReferenceDirectives != null) {
			for (ref in sourceFile.LibReferenceDirectives) {
				rawLibReferenceDirectives.push(ref);
			}
		}
	}

	function appendCjsExports(combinedStatements:StatementList):StatementList {
		final result:Array<Node> = [];
		if (cjsExportAssignment != null) {
			result.push(cjsExportAssignment);
		}
		if (cjsExportMembers != null) {
			for (m in cjsExportMembers) {
				result.push(m);
			}
		}
		if (combinedStatements.Nodes != null) {
			for (s in combinedStatements.Nodes) {
				result.push(s);
			}
		}
		final statementNodes = Declarations.flattenSyntaxLists(result);
		if (Core.len(statementNodes) != Core.len(combinedStatements.Nodes)) {
			combinedStatements = Factory().NewNodeList(statementNodes);
		}
		return combinedStatements;
	}

	function transformSourceFile(node:SourceFile):Node {
		cjsExportAssignment = null;
		cjsExportAssignmentName = null;
		cjsExportMembers = null;
		// PORT: defer on the success path only (docs/PORTING.md §4).
		cjsExportAssignmentVisitor.VisitNode(node.AsNode()); // collect nested module.exports= assignments
		expressionVisitor.VisitNode(node.AsNode()); // collect expando members (requires any export assignment be located in advance)
		var combinedStatements:StatementList;
		final statements = Visitor().VisitNodes(node.Statements);
		combinedStatements = transformAndReplaceLatePaintedStatements(statements);
		combinedStatements = appendCjsExports(combinedStatements);
		combinedStatements.Loc = statements.Loc; // setTextRange
		if (Ast.IsExternalOrCommonJSModule(node)) {
			if (Ast.IsInJSFile(node.AsNode())) {
				final exportEquals = node.Symbol.Exports == null ? null : node.Symbol.Exports.get(Ast.InternalSymbolNameExportEquals);
				if (exportEquals != null && Core.len(exportEquals.Declarations) > 1) {
					for (node in exportEquals.Declarations) {
						state.addDiagnostic(Declarations.createDiagnosticForNode(node,
							Diagnostics.Multiple_module_exports_assignments_cannot_be_serialized_for_declaration_emit));
					}
				}
			}
			if (!resultHasExternalModuleIndicator || (needsScopeFixMarker && !resultHasScopeMarker)) {
				final marker = Declarations.createEmptyExports(Factory().AsNodeFactory());
				// PORT: Go append may share combinedStatements.Nodes' backing array; copy.
				final newList = combinedStatements.Nodes == null ? [] : combinedStatements.Nodes.copy();
				newList.push(marker);
				final withMarker = Factory().NewNodeList(newList);
				withMarker.Loc = combinedStatements.Loc;
				combinedStatements = withMarker;
			}
		}
		final outputFilePath = Tspath.GetDirectoryPath(Tspath.NormalizeSlashes(declarationFilePath));
		final result = Factory().UpdateSourceFile(node, combinedStatements, node.EndOfFileToken);
		result.AsSourceFile().LibReferenceDirectives = getLibReferences();
		result.AsSourceFile().TypeReferenceDirectives = getTypeReferences();
		result.AsSourceFile().IsDeclarationFile = true;
		result.AsSourceFile().ReferencedFiles = getReferencedFiles(outputFilePath);
		cjsExportAssignment = null;
		cjsExportAssignmentName = null;
		cjsExportMembers = null;
		return result.AsNode();
	}

	function transformAndReplaceLatePaintedStatements(statements:StatementList):StatementList {
		// This is a `while` loop because `handleSymbolAccessibilityError` can see additional import aliases marked as visible during
		// error handling which must now be included in the output and themselves checked for errors.
		// For example:
		// ```
		// module A {
		//   export module Q {}
		//   import B = Q;
		//   import C = B;
		//   export import D = C;
		// }
		// ```
		// In such a scenario, only Q and D are initially visible, but we don't consider imports as private names - instead we say they if they are referenced they must
		// be recorded. So while checking D's visibility we mark C as visible, then we must check C which in turn marks B, completing the chain of
		// dependent imports and allowing a valid declaration file output. Today, this dependent alias marking only happens for internal import aliases.
		while (true) {
			if (Core.len(state.lateMarkedStatements) == 0) {
				break;
			}

			final next = state.lateMarkedStatements[0];
			state.lateMarkedStatements = state.lateMarkedStatements.slice(1);

			final saveNeedsDeclare = needsDeclare;
			needsDeclare = next.Parent != null && Ast.IsSourceFile(next.Parent);

			final result = transformTopLevelDeclaration(next);

			needsDeclare = saveNeedsDeclare;
			final original = EmitContext().MostOriginal(next);
			final id = Ast.GetNodeId(original);
			lateStatementReplacementMap.set(id, result);
		}

		// And lastly, we need to get the final form of all those indetermine import declarations from before and add them to the output list
		// (and remove them from the set to examine for outter declarations)
		final results:Array<Node> = [];
		if (statements.Nodes != null) {
			for (statement in statements.Nodes) {
				if (!Ast.IsLateVisibilityPaintedStatement(statement)) {
					results.push(statement);
					continue;
				}
				final original = EmitContext().MostOriginal(statement);
				final id = Ast.GetNodeId(original);
				if (!lateStatementReplacementMap.exists(id)) {
					results.push(statement);
					continue; // not replaced
				}
				final replacement = lateStatementReplacementMap.get(id);
				if (replacement == null) {
					continue; // deleted
				}
				if (replacement.Kind == KindSyntaxList) {
					if (!needsScopeFixMarker || !resultHasExternalModuleIndicator) {
						for (elem in replacement.AsSyntaxList().Children) {
							if (Declarations.needsScopeMarker(elem)) {
								needsScopeFixMarker = true;
							}
							if (Ast.IsSourceFile(statement.Parent) && Ast.IsExternalModuleIndicator(elem)) {
								resultHasExternalModuleIndicator = true;
							}
						}
					}
					for (c in replacement.AsSyntaxList().Children) {
						results.push(c);
					}
				} else {
					if (Declarations.needsScopeMarker(replacement)) {
						needsScopeFixMarker = true;
					}
					if (Ast.IsSourceFile(statement.Parent) && Ast.IsExternalModuleIndicator(replacement)) {
						resultHasExternalModuleIndicator = true;
					}
					results.push(replacement);
				}
			}
		}

		return Factory().NewNodeList(results);
	}

	function getReferencedFiles(outputFilePath:std.String):Array<FileReference> {
		var results:Array<FileReference> = null;
		// Handle path rewrites for triple slash ref comments
		for (pair in rawReferencedFiles) {
			final sourceFile = pair.file;
			final ref = pair.ref;

			if (!ref.Preserve) {
				continue;
			}

			final file = host.GetSourceFileFromReference(sourceFile, ref);
			if (file == null) {
				continue;
			}

			var declFileName:std.String;
			if (file.IsDeclarationFile) {
				declFileName = file.FileName();
			} else {
				final paths = host.GetOutputPathsFor(file, true);
				// Try to use output path for referenced file, or output js path if that doesn't exist, or the input path if all else fails
				declFileName = paths.DeclarationFilePath();
				if (declFileName.length == 0) {
					declFileName = paths.JsFilePath();
				}
				if (declFileName.length == 0) {
					declFileName = file.FileName();
				}
			}
			// Should only be missing if the source file is missing a fileName (at which point we can't name a reference to it anyway)
			// TODO: Shouldn't this be a crash or assert instead of a silent continue?
			if (declFileName.length == 0) {
				continue;
			}

			final opts = new ComparePathsOptions();
			opts.CurrentDirectory = host.GetCurrentDirectory();
			opts.UseCaseSensitiveFileNames = host.UseCaseSensitiveFileNames();
			final fileName = Tspath.GetRelativePathToDirectoryOrUrl(outputFilePath, declFileName, false, // TODO: Probably unsafe to assume this isn't a URL, but that's what strada does
				opts);

			final r = new FileReference();
			r.TextRange = Core.NewTextRange(-1, -1);
			r.FileName = fileName;
			r.ResolutionMode = ref.ResolutionMode;
			r.Preserve = ref.Preserve;
			if (results == null) {
				results = [];
			}
			results.push(r);
		}
		return results;
	}

	function getLibReferences():Array<FileReference> {
		var result:Array<FileReference> = null;
		// clone retained references
		for (ref in rawLibReferenceDirectives) {
			if (!ref.Preserve) {
				continue;
			}
			final r = new FileReference();
			r.TextRange = Core.NewTextRange(-1, -1);
			r.FileName = ref.FileName;
			r.ResolutionMode = ref.ResolutionMode;
			r.Preserve = ref.Preserve;
			if (result == null) {
				result = [];
			}
			result.push(r);
		}
		return result;
	}

	function getTypeReferences():Array<FileReference> {
		var result:Array<FileReference> = null;
		// clone retained references
		for (ref in rawTypeReferenceDirectives) {
			if (!ref.Preserve) {
				continue;
			}
			final r = new FileReference();
			r.TextRange = Core.NewTextRange(-1, -1);
			r.FileName = ref.FileName;
			r.ResolutionMode = ref.ResolutionMode;
			r.Preserve = ref.Preserve;
			if (result == null) {
				result = [];
			}
			result.push(r);
		}
		return result;
	}

	// PORT: perf — Go returns (bool, func()); the bool is left in setupDiagnosticContextResult (no
	// result object per visited node).
	var setupDiagnosticContextResult:Bool = false;

	// PORT: perf — Go's cleanup closure (one per node visited) is a stack of the state it restores:
	// setupDiagnosticContext pushes it, cleanupDiagnosticContext() pops it (every caller runs the
	// cleanup on each path, last in first out, as the defers).
	final diagnosticContextDiag:Array<GetSymbolAccessibilityDiagnostic> = [];
	final diagnosticContextName:Array<Node> = [];
	final diagnosticContextWithin:Array<Bool> = [];
	var diagnosticContexts:Int = 0; // (the stack's depth; the arrays keep their length)

	function cleanupDiagnosticContext():Void {
		final k = --diagnosticContexts;
		state.getSymbolAccessibilityDiagnostic = diagnosticContextDiag[k];
		state.errorNameNode = diagnosticContextName[k];
		suppressNewDiagnosticContexts = diagnosticContextWithin[k];
		diagnosticContextDiag[k] = null;
		diagnosticContextName[k] = null;
	}

	function setupDiagnosticContext(input:Node):Void {
		final canProdiceDiagnostic = Declarations.canProduceDiagnostics(input);
		final oldWithinObjectLiteralType = suppressNewDiagnosticContexts;
		final shouldEnterSuppressNewDiagnosticsContextContext = (input.Kind == KindTypeLiteral || input.Kind == KindMappedType)
			&& !(input.Parent.Kind == KindTypeAliasDeclaration || input.Parent.Kind == KindJSTypeAliasDeclaration);

		final oldDiag = state.getSymbolAccessibilityDiagnostic;
		if (canProdiceDiagnostic && !suppressNewDiagnosticContexts) {
			state.getSymbolAccessibilityDiagnostic = Declarations.createGetSymbolAccessibilityDiagnosticForNode(input);
		}
		final oldName = state.errorNameNode;

		if (shouldEnterSuppressNewDiagnosticsContextContext) {
			suppressNewDiagnosticContexts = true;
		}

		setupDiagnosticContextResult = canProdiceDiagnostic;
		final k = diagnosticContexts++;
		if (k == diagnosticContextDiag.length) {
			diagnosticContextDiag.push(oldDiag);
			diagnosticContextName.push(oldName);
			diagnosticContextWithin.push(oldWithinObjectLiteralType);
		} else {
			diagnosticContextDiag[k] = oldDiag;
			diagnosticContextName[k] = oldName;
			diagnosticContextWithin[k] = oldWithinObjectLiteralType;
		}
	}

	function visitDeclarationSubtree(input:Node):Node {
		if (shouldStripInternal(input)) {
			return null;
		}
		if (Ast.IsDeclaration(input)) {
			if (Declarations.isDeclarationAndNotVisible(EmitContext(), resolver, input)) {
				return null;
			}
			if (Ast.HasDynamicName(input)) {
				if (state.isolatedDeclarations) {
					// Classes and object literals usually elide properties with computed names that are not of a literal type
					// In isolated declarations TSC needs to error on these as we don't know the type in a DTE.
					if (!resolver.IsDefinitelyReferenceToGlobalSymbolObject(input.Name().Expression())) {
						if (Ast.IsClassDeclaration(input.Parent) || Ast.IsObjectLiteralExpression(input.Parent)) {
							state.addDiagnostic(Declarations.createDiagnosticForNode(input,
								Diagnostics.Computed_property_names_on_class_or_object_literals_cannot_be_inferred_with_isolatedDeclarations));
							return null;
						} else if ((Ast.IsInterfaceDeclaration(input.Parent) || Ast.IsTypeLiteralNode(input.Parent))
							&& !Ast.IsEntityNameExpression(input.Name().Expression())) {
							// Type declarations just need to double-check that the input computed name is an entity name expression
							state.addDiagnostic(Declarations.createDiagnosticForNode(input,
								Diagnostics.Computed_properties_must_be_number_or_string_literals_variables_or_dotted_expressions_with_isolatedDeclarations));
							return null;
						}
					}
				} else if (!resolver.IsLateBound(EmitContext().ParseNode(input)) || !Ast.IsEntityNameExpression(input.Name().Expression())) {
					return null;
				}
			}
		}

		// Elide implementation signatures from overload sets
		if (Ast.IsFunctionLike(input) && resolver.IsImplementationOfOverload(input)) {
			return null;
		}

		if (input.Kind == KindSemicolonClassElement) {
			return null;
		}

		if (Ast.IsHeritageClause(input)
			&& (Core.len(input.AsHeritageClause().Types.Nodes) == 0
				|| (Core.len(input.AsHeritageClause().Types.Nodes) == 1 && Ast.NodeIsMissing(input.AsHeritageClause().Types.Nodes[0])))) {
			return null;
		}

		final previousEnclosingDeclaration = enclosingDeclaration;
		if (Declarations.isEnclosingDeclaration(input)) {
			enclosingDeclaration = input;
		}

		setupDiagnosticContext(input);
		final canProdiceDiagnostic = setupDiagnosticContextResult;
		// PORT: defer on the success path only (docs/PORTING.md §4).

		var result:Node = null;

		switch (input.Kind) {
			case KindMappedType:
				result = transformMappedTypeNode(input.AsMappedTypeNode());
			case KindHeritageClause:
				result = transformHeritageClause(input.AsHeritageClause());
			case KindMethodSignature:
				result = transformMethodSignatureDeclaration(input.AsMethodSignatureDeclaration());
			case KindMethodDeclaration:
				result = transformMethodDeclaration(input.AsMethodDeclaration());
			case KindConstructSignature:
				result = transformConstructSignatureDeclaration(input.AsConstructSignatureDeclaration());
			case KindConstructor:
				result = transformConstructorDeclaration(input.AsConstructorDeclaration());
			case KindGetAccessor:
				result = transformGetAccesorDeclaration(input.AsGetAccessorDeclaration());
			case KindSetAccessor:
				result = transformSetAccessorDeclaration(input.AsSetAccessorDeclaration());
			case KindPropertyDeclaration:
				result = transformPropertyDeclaration(input.AsPropertyDeclaration());
			case KindPropertySignature:
				result = transformPropertySignatureDeclaration(input.AsPropertySignatureDeclaration());
			case KindCallSignature:
				result = transformCallSignatureDeclaration(input.AsCallSignatureDeclaration());
			case KindIndexSignature:
				result = transformIndexSignatureDeclaration(input.AsIndexSignatureDeclaration());
			case KindVariableDeclaration:
				result = transformVariableDeclaration(input.AsVariableDeclaration());
			case KindTypeParameter:
				result = transformTypeParameterDeclaration(input.AsTypeParameterDeclaration());
			case KindExpressionWithTypeArguments:
				result = transformExpressionWithTypeArguments(input.AsExpressionWithTypeArguments());
			case KindTypeReference:
				result = transformTypeReference(input.AsTypeReferenceNode());
			case KindConditionalType:
				result = transformConditionalTypeNode(input.AsConditionalTypeNode());
			case KindFunctionType:
				result = transformFunctionTypeNode(input.AsFunctionTypeNode());
			case KindConstructorType:
				result = transformConstructorTypeNode(input.AsConstructorTypeNode());
			case KindImportType:
				result = transformImportTypeNode(input.AsImportTypeNode());
			case KindTypeQuery:
				checkEntityNameVisibility(input.AsTypeQueryNode().ExprName, enclosingDeclaration);
				result = Visitor().VisitEachChild(input);
			case KindTupleType:
				result = Visitor().VisitEachChild(input);
				if (result != null) {
					if (Transformers.IsOriginalNodeSingleLine(EmitContext(), input)) {
						EmitContext().AddEmitFlags(result, EFSingleLine);
					}
				}
			case KindJSDocTypeExpression:
				result = transformJSDocTypeExpression(input.AsJSDocTypeExpression());
			case KindJSDocTypeLiteral:
				result = transformJSDocTypeLiteral(input.AsJSDocTypeLiteral());
			case KindJSDocPropertyTag:
				result = transformJSDocPropertyTag(input.AsJSDocParameterOrPropertyTag());
			case KindJSDocAllType:
				result = transformJSDocAllType(input.AsJSDocAllType());
			case KindJSDocNullableType:
				result = transformJSDocNullableType(input.AsJSDocNullableType());
			case KindJSDocNonNullableType:
				result = transformJSDocNonNullableType(input.AsJSDocNonNullableType());
			case KindJSDocOptionalType:
				result = transformJSDocOptionalType(input.AsJSDocOptionalType());
			case KindJSDocVariadicType:
				result = transformJSDocVariadicType(input.AsJSDocVariadicType());
			default:
				result = Visitor().VisitEachChild(input);
		}

		if (result != null && canProdiceDiagnostic && Ast.HasDynamicName(input)) {
			checkName(input);
		}

		enclosingDeclaration = previousEnclosingDeclaration;
		cleanupDiagnosticContext();
		return result;
	}

	function checkName(node:Node):Void {
		final oldDiag = state.getSymbolAccessibilityDiagnostic;
		if (!suppressNewDiagnosticContexts) {
			state.getSymbolAccessibilityDiagnostic = Declarations.createGetSymbolAccessibilityDiagnosticForNodeName(node);
		}
		state.errorNameNode = node.Name();
		Debug.Assert(Ast.HasDynamicName(node)); // Should only be called with dynamic names
		final entityName = node.Name().Expression();
		checkEntityNameVisibility(entityName, enclosingDeclaration);
		if (!suppressNewDiagnosticContexts) {
			state.getSymbolAccessibilityDiagnostic = oldDiag;
		}
		state.errorNameNode = null;
	}

	function transformMappedTypeNode(input:MappedTypeNode):Node {
		// handle missing template type nodes, since the printer does not
		var typeNode:Node;
		if (input.Type == null) {
			typeNode = Factory().NewKeywordTypeNode(KindAnyKeyword);
		} else {
			typeNode = Visitor().Visit(input.Type);
		}
		return Factory().UpdateMappedTypeNode(input, input.ReadonlyToken, Visitor().Visit(input.TypeParameter), Visitor().Visit(input.NameType),
			input.QuestionToken, typeNode, null);
	}

	function transformHeritageClause(clause:HeritageClause):Node {
		final retainedClauses = Core.Filter(clause.Types.Nodes, function(t:Node):Bool {
			return Ast.IsEntityNameExpression(t.AsExpressionWithTypeArguments().Expression)
				|| (clause.Token == KindExtendsKeyword && t.Expression().Kind == KindNullKeyword);
		});
		if (Core.len(retainedClauses) == 0) {
			return null; // elide empty clause
		}
		if (Core.len(retainedClauses) == Core.len(clause.Types.Nodes)) {
			return Visitor().VisitEachChild(clause.AsNode());
		}
		return Factory().UpdateHeritageClause(clause, clause.Token, Visitor().VisitNodes(Factory().NewNodeList(retainedClauses)));
	}

	function transformImportTypeNode(input:ImportTypeNode):Node {
		if (!Ast.IsLiteralImportTypeNode(input.AsNode())) {
			return input.AsNode();
		}
		return Factory().UpdateImportTypeNode(input, input.IsTypeOf,
			Factory().UpdateLiteralTypeNode(input.Argument.AsLiteralTypeNode(), rewriteModuleSpecifier(input.AsNode(), input.Argument.AsLiteralTypeNode().Literal)),
			input.Attributes, input.Qualifier, Visitor().VisitNodes(input.TypeArguments));
	}

	function transformConstructorTypeNode(input:ConstructorTypeNode):Node {
		return Factory().UpdateConstructorTypeNode(input, ensureModifiers(input.AsNode()), Visitor().VisitNodes(input.TypeParameters),
			updateParamList(input.AsNode(), input.Parameters), Visitor().Visit(input.Type));
	}

	function transformFunctionTypeNode(input:FunctionTypeNode):Node {
		return Factory().UpdateFunctionTypeNode(input, Visitor().VisitNodes(input.TypeParameters), updateParamList(input.AsNode(), input.Parameters),
			Visitor().Visit(input.Type));
	}

	function transformConditionalTypeNode(input:ConditionalTypeNode):Node {
		final checkType = Visitor().Visit(input.CheckType);
		final extendsType = Visitor().Visit(input.ExtendsType);
		final oldEnclosingDecl = enclosingDeclaration;
		enclosingDeclaration = input.TrueType;
		final trueType = Visitor().Visit(input.TrueType);
		enclosingDeclaration = oldEnclosingDecl;
		final falseType = Visitor().Visit(input.FalseType);

		return Factory().UpdateConditionalTypeNode(input, checkType, extendsType, trueType, falseType);
	}

	function transformTypeReference(input:TypeReferenceNode):Node {
		checkEntityNameVisibility(input.TypeName, enclosingDeclaration);
		return Visitor().VisitEachChild(input.AsNode());
	}

	function transformExpressionWithTypeArguments(input:ExpressionWithTypeArguments):Node {
		if (Ast.IsEntityName(input.Expression) || Ast.IsEntityNameExpression(input.Expression)) {
			checkEntityNameVisibility(input.Expression, enclosingDeclaration);
		}
		return Visitor().VisitEachChild(input.AsNode());
	}

	function transformTypeParameterDeclaration(input:TypeParameterDeclaration):Node {
		if (Declarations.isPrivateMethodTypeParameter(host, input) && (input.DefaultType != null || input.Constraint != null)) {
			return Factory().UpdateTypeParameterDeclaration(input, input.Modifiers(), input.Name(), null, input.Expression, null);
		}
		return Visitor().VisitEachChild(input.AsNode());
	}

	function transformVariableDeclaration(input:VariableDeclaration):Node {
		if (state.currentSourceFile.CommonJSModuleIndicator != null && Ast.IsVariableDeclarationInitializedToRequire(input.AsNode())) {
			return transformCjsRequireVariableDeclaration(input);
		}
		if (Ast.IsBindingPattern(input.Name())) {
			return recreateBindingPattern(input.Name().AsBindingPattern());
		}
		// Variable declaration types also suppress new diagnostic contexts, provided the contexts wouldn't be made for binding pattern types
		suppressNewDiagnosticContexts = true;
		return Factory().UpdateVariableDeclaration(input, input.Name(), null, ensureType(input.AsNode(), false), ensureNoInitializer(input.AsNode()));
	}

	function transformCjsRequireVariableDeclaration(input:VariableDeclaration):Node {
		final specifier = rewriteModuleSpecifier(input.AsNode(), input.Initializer.AsCallExpression().Arguments.Nodes[0]);
		if (Ast.IsIdentifier(input.Name())) {
			// `const x = require("something")` -> `import x = require("something")`
			return Factory().NewImportEqualsDeclaration(null, false, input.Name(), Factory().NewExternalModuleReference(specifier));
		} else if (Ast.IsArrayBindingPattern(input.Name())) {
			// TODO: Is this actually reachable? should we error on this?
			return null;
		} else { // object binding pattern
			// `const {x, y: z} = require("something")` -> `import {x, y as z} from "something"`
			final b = input.Name().AsBindingPattern();
			var importSpecifiers:Array<Node> = null;
			for (elem in b.Elements.Nodes) {
				if (!Ast.IsIdentifier(elem.Name())) {
					continue; // nested destructuring, bail
				}
				if (importSpecifiers == null) {
					importSpecifiers = [];
				}
				importSpecifiers.push(Factory().NewImportSpecifier(false, elem.PropertyName(), elem.Name()));
			}
			return Factory().NewImportDeclaration(null, Factory().NewImportClause(KindUnknown, null, Factory().NewNamedImports(Factory().NewNodeList(importSpecifiers))),
				specifier, null);
		}
	}

	function recreateBindingPattern(input:BindingPattern):Node {
		var results:Array<Node> = null;
		for (elem in input.Elements.Nodes) {
			final result = recreateBindingElement(elem.AsBindingElement());
			if (result == null) {
				continue;
			}
			if (results == null) {
				results = [];
			}
			if (result.Kind == KindSyntaxList) {
				for (c in result.AsSyntaxList().Children) {
					results.push(c);
				}
			} else {
				results.push(result);
			}
		}
		if (Core.len(results) == 0) {
			return null;
		}
		if (results.length == 1) {
			return results[0];
		}
		return Factory().NewSyntaxList(results);
	}

	function recreateBindingElement(e:BindingElement):Node {
		if (e.Name() == null) {
			return null;
		}
		if (!Declarations.getBindingNameVisible(resolver, e.AsNode())) {
			return null;
		}
		if (Ast.IsBindingPattern(e.Name())) {
			return recreateBindingPattern(e.Name().AsBindingPattern());
		}
		return Factory().NewVariableDeclaration(e.Name(), null, ensureType(e.AsNode(), false), null // TODO: possible strada bug - not emitting const initialized binding pattern elements?
		);
	}

	function transformIndexSignatureDeclaration(input:IndexSignatureDeclaration):Node {
		var t = Visitor().Visit(input.Type);
		if (t == null) {
			t = Factory().NewKeywordTypeNode(KindAnyKeyword);
		}
		return Factory().UpdateIndexSignatureDeclaration(input, ensureModifiers(input.AsNode()), updateParamList(input.AsNode(), input.Parameters), t);
	}

	function transformCallSignatureDeclaration(input:CallSignatureDeclaration):Node {
		return Factory().UpdateCallSignatureDeclaration(input, ensureTypeParams(input.AsNode(), input.TypeParameters),
			updateParamList(input.AsNode(), input.Parameters), ensureType(input.AsNode(), false));
	}

	function transformPropertySignatureDeclaration(input:PropertySignatureDeclaration):Node {
		if (Ast.IsPrivateIdentifier(input.Name())) {
			return null;
		}
		final result = Factory().UpdatePropertySignatureDeclaration(input, ensureModifiers(input.AsNode()), input.Name(), input.PostfixToken,
			ensureType(input.AsNode(), false), ensureNoInitializer(input.AsNode()) // TODO: possible strada bug (fixed here) - const property signatures never initialized
		);
		preservePartialJsDoc(result, input.AsNode());
		return result;
	}

	function transformPropertyDeclaration(input:PropertyDeclaration):Node {
		if (Ast.IsPrivateIdentifier(input.Name())) {
			return null;
		}
		// Remove definite assignment assertion (!) from declaration files
		var postfixToken = input.PostfixToken;
		if (postfixToken != null && postfixToken.Kind == KindExclamationToken) {
			postfixToken = null;
		}
		return Factory().UpdatePropertyDeclaration(input, ensureModifiers(input.AsNode()), input.Name(), postfixToken, ensureType(input.AsNode(), false),
			ensureNoInitializer(input.AsNode()));
	}

	function transformSetAccessorDeclaration(input:SetAccessorDeclaration):Node {
		if (Ast.IsPrivateIdentifier(input.Name())) {
			return null;
		}

		return Factory().UpdateSetAccessorDeclaration(input, ensureModifiers(input.AsNode()), input.Name(), null, // accessors shouldn't have type params
			updateAccessorParamList(input.AsNode(), host.GetEffectiveDeclarationFlags(EmitContext().ParseNode(input.AsNode()), ModifierFlagsPrivate) != 0),
			null, null, null);
	}

	function transformGetAccesorDeclaration(input:GetAccessorDeclaration):Node {
		if (Ast.IsPrivateIdentifier(input.Name())) {
			return null;
		}
		return Factory().UpdateGetAccessorDeclaration(input, ensureModifiers(input.AsNode()), input.Name(), null, // accessors shouldn't have type params
			updateAccessorParamList(input.AsNode(), host.GetEffectiveDeclarationFlags(EmitContext().ParseNode(input.AsNode()), ModifierFlagsPrivate) != 0),
			ensureType(input.AsNode(), false), null, null);
	}

	function updateAccessorParamList(input:Node, isPrivate:Bool):ParameterList {
		var newParams:Array<Node> = null;
		if (!isPrivate) {
			final thisParam = Ast.GetThisParameter(input);
			if (thisParam != null) {
				newParams = [ensureParameter(thisParam.AsParameterDeclaration())];
			}
		}
		if (Ast.IsSetAccessorDeclaration(input)) {
			var valueParam:Node = null;
			if (!isPrivate) {
				if (Core.len(newParams) == 1 && Core.len(input.AsSetAccessorDeclaration().Parameters.Nodes) >= 2) {
					valueParam = ensureParameter(input.AsSetAccessorDeclaration().Parameters.Nodes[1].AsParameterDeclaration());
				} else if (Core.len(newParams) == 0 && Core.len(input.AsSetAccessorDeclaration().Parameters.Nodes) >= 1) {
					valueParam = ensureParameter(input.AsSetAccessorDeclaration().Parameters.Nodes[0].AsParameterDeclaration());
				}
			}
			if (valueParam == null) {
				// When synthesizing a missing value parameter, emit `value: any` for non-private accessors to match TypeScript's declaration emit behavior.
				var t:Node = null;
				if (!isPrivate) {
					t = Factory().NewKeywordTypeNode(KindAnyKeyword);
				}
				valueParam = Factory().NewParameterDeclaration(null, null, Factory().NewIdentifier("value"), null, t, null);
			}
			if (newParams == null) {
				newParams = [];
			}
			newParams.push(valueParam);
		}
		return Factory().NewNodeList(newParams);
	}

	function transformConstructorDeclaration(input:ConstructorDeclaration):Node {
		// A constructor declaration may not have a type annotation
		return Factory().UpdateConstructorDeclaration(input, ensureModifiers(input.AsNode()), null, // no type params
			updateParamList(input.AsNode(), input.Parameters), null, // no return type
			null, null);
	}

	function transformConstructSignatureDeclaration(input:ConstructSignatureDeclaration):Node {
		return Factory().UpdateConstructSignatureDeclaration(input, ensureTypeParams(input.AsNode(), input.TypeParameters),
			updateParamList(input.AsNode(), input.Parameters), ensureType(input.AsNode(), false));
	}

	function omitPrivateMethodType(input:Node):Node {
		if (input.Symbol() != null && Core.len(input.Symbol().Declarations) > 0 && input.Symbol().Declarations[0] != input) {
			return null;
		}
		final result = Factory().NewPropertyDeclaration(ensureModifiers(input), input.Name(), null, null, null);
		preserveJsDoc(result, input);
		return result;
	}

	function transformMethodSignatureDeclaration(input:MethodSignatureDeclaration):Node {
		if (host.GetEffectiveDeclarationFlags(EmitContext().ParseNode(input.AsNode()), ModifierFlagsPrivate) != 0) {
			return omitPrivateMethodType(input.AsNode());
		} else if (Ast.IsPrivateIdentifier(input.Name())) {
			return null;
		} else {
			return Factory().UpdateMethodSignatureDeclaration(input, ensureModifiers(input.AsNode()), input.Name(), input.PostfixToken,
				ensureTypeParams(input.AsNode(), input.TypeParameters), updateParamList(input.AsNode(), input.Parameters), ensureType(input.AsNode(), false));
		}
	}

	function transformMethodDeclaration(input:MethodDeclaration):Node {
		if (host.GetEffectiveDeclarationFlags(EmitContext().ParseNode(input.AsNode()), ModifierFlagsPrivate) != 0) {
			return omitPrivateMethodType(input.AsNode());
		} else if (Ast.IsPrivateIdentifier(input.Name())) {
			return null;
		} else {
			return Factory().UpdateMethodDeclaration(input, ensureModifiers(input.AsNode()), null, input.Name(), input.PostfixToken,
				ensureTypeParams(input.AsNode(), input.TypeParameters), updateParamList(input.AsNode(), input.Parameters), ensureType(input.AsNode(), false),
				null, null);
		}
	}

	function visitDeclarationStatements(input:Node):Node {
		if (shouldStripInternal(input)) {
			return null;
		}
		switch (input.Kind) {
			case KindExportDeclaration:
				if (Ast.IsSourceFile(input.Parent)) {
					resultHasExternalModuleIndicator = true;
				}
				resultHasScopeMarker = true;
				// Rewrite external module names if necessary
				return Factory().UpdateExportDeclaration(input.AsExportDeclaration(), input.Modifiers(), input.IsTypeOnly(),
					input.AsExportDeclaration().ExportClause, rewriteModuleSpecifier(input, input.ModuleSpecifier()),
					tryGetResolutionModeOverride(input.AsExportDeclaration().Attributes));
			case KindExportAssignment:
				return transformExportAssignment(input, input, input.Expression(), input.AsExportAssignment().IsExportEquals);
			default:
				final id = Ast.GetNodeId(EmitContext().MostOriginal(input));
				if (lateStatementReplacementMap.get(id) == null) {
					// Don't actually transform yet; just leave as original node - will be elided/swapped by late pass
					lateStatementReplacementMap.set(id, transformTopLevelDeclaration(input));
				}
				return input;
		}
	}

	function tryGetNameOfAssignedExpression(unwrapped:Node):Node {
		var nameNode:Node = null;
		var nameText = "";
		if (!Ast.IsPropertyAccessExpression(unwrapped) && unwrapped.Name() != null) {
			nameText = unwrapped.Name().Text();
		} else if (Ast.IsIdentifier(unwrapped)) {
			nameText = unwrapped.Text();
		}
		if (nameText != "" && nameText != "default") {
			if (resolver.IsNameResolvable(enclosingDeclaration, nameText)) {
				// create a unique name that shares the same text as its' base
				nameNode = Factory().NewUniqueNameEx(nameText, optimisticOptions());
			} else {
				// use the node's name as-is, since it's not otherwise in-scope
				nameNode = Factory().NewIdentifier(nameText);
			}
		}
		return nameNode;
	}

	function getNameOfExportedAssignedExpression(unwrapped:Node, isExportEquals:Bool):Node {
		var nameNode = tryGetNameOfAssignedExpression(unwrapped);
		if (nameNode == null) {
			// fallback to a default name
			if (isExportEquals && Ast.IsSourceFileJS(state.currentSourceFile)) {
				// only JS files prefer to use `_exports` for export assignments - TS has always used `_default` for both `export=` and `export default`
				nameNode = Factory().NewUniqueNameEx("_exports", optimisticOptions());
			} else {
				nameNode = Factory().NewUniqueNameEx("_default", optimisticOptions());
			}
		}
		cjsExportAssignmentName = nameNode;
		return nameNode;
	}

	function transformExportAssignment(input:Node, assignment:Node, expression:Node, isExportEquals:Bool):Node {
		if (Ast.IsSourceFile(input.Parent)) {
			resultHasExternalModuleIndicator = true;
		}
		resultHasScopeMarker = true;
		if (Ast.IsIdentifier(expression) && (Ast.IsSourceFile(input.Parent) || Ast.IsModuleBlock(input.Parent))) {
			final exportAssignment = Factory().NewExportAssignment(null, isExportEquals, null, expression);
			preserveJsDoc(exportAssignment, input);
			return exportAssignment;
		}

		// Check if the expression is a class expression - emit as a class declaration + export assignment
		final unwrapped = Ast.SkipOuterExpressions(expression, OEKExpressionTypePassthrough);
		final newId = getNameOfExportedAssignedExpression(unwrapped, isExportEquals);
		if (Ast.IsClassExpression(unwrapped)) {
			var mods:Array<Node> = null;
			if (needsDeclare) {
				mods = [Factory().NewModifier(KindDeclareKeyword)];
			}
			final classDecl = transformClassExpressionToDeclaration(unwrapped, newId, Factory().NewModifierList(mods));
			preserveJsDoc(classDecl, input);
			// Reuse the same name node for the export so unique names resolve consistently
			final exportAssignment = Factory().NewExportAssignment(null, isExportEquals, null, newId);
			removeAllComments(exportAssignment);
			return Factory().NewSyntaxList([exportAssignment, classDecl]);
		} else if (Ast.IsFunctionLike(unwrapped)) {
			// Promote function or arrow function expressions to a function declaration
			var mods:Array<Node> = null;
			if (needsDeclare) {
				mods = [Factory().NewModifier(KindDeclareKeyword)];
			}
			final funcDecl = transformFunctionLikeToDeclaration(unwrapped, newId, Factory().NewModifierList(mods));
			preserveJsDoc(funcDecl, input);
			// Reuse the same name node for the export so unique names resolve consistently
			final exportAssignment = Factory().NewExportAssignment(null, isExportEquals, null, newId);
			removeAllComments(exportAssignment);
			return Factory().NewSyntaxList([exportAssignment, funcDecl]);
		}

		// expression is non-identifier, create _default typed variable to reference
		state.getSymbolAccessibilityDiagnostic = function(_:SymbolAccessibilityResult):SymbolAccessibilityDiagnostic {
			final d = new SymbolAccessibilityDiagnostic();
			d.diagnosticMessage = Diagnostics.Default_export_of_the_module_has_or_is_using_private_name_0;
			d.errorNode = input;
			return d;
		};
		cjsExportAssignmentName = newId;
		tracker.PushErrorFallbackNode(assignment);
		var type_:Node = null;
		var initializer:Node = null;
		if (Ast.IsPrimitiveLiteralValue(Declarations.unwrapParenthesizedExpression(expression), true)) {
			initializer = resolver.CreateLiteralConstValue(EmitContext(), EmitContext().ParseNode(assignment), tracker);
		}
		if (initializer == null) {
			type_ = ensureType(assignment, false);
		}
		final varDecl = Factory().NewVariableDeclaration(newId, null, type_, initializer);
		tracker.PopErrorFallbackNode();
		var modList:ModifierList;
		if (needsDeclare) {
			modList = Factory().NewModifierList([Factory().NewModifier(KindDeclareKeyword)]);
		} else {
			modList = Factory().NewModifierList([]);
		}
		final statement = Factory().NewVariableStatement(modList, Factory().NewVariableDeclarationList(Factory().NewNodeList([varDecl]), NodeFlagsConst));
		final exportAssignment = Factory().NewExportAssignment(null, isExportEquals, null, newId);
		// Remove comments from the export declaration and copy them onto the synthetic _default declaration
		preserveJsDoc(statement, input);
		return Factory().NewSyntaxList([statement, exportAssignment]);
	}

	function transformFunctionLikeToDeclaration(unwrapped:Node, funcName:Node, mods:ModifierList):Node {
		final d = unwrapped.FunctionLikeData();
		return Factory().NewFunctionDeclaration(mods, null, funcName, ensureTypeParams(unwrapped, d.TypeParameters), updateParamList(unwrapped, d.Parameters),
			ensureType(unwrapped, false), Visitor().VisitNode(d.FullSignature), null);
	}

	function transformBinaryExpressionToExportDeclaration(input:Node, name:Node):Node {
		var propertyName = input.AsBinaryExpression().Right;

		// track alias target so referenced declarations are included in the output
		tracker.handleSymbolAccessibilityError(resolver.IsEntityNameVisible(propertyName, enclosingDeclaration));

		if (Ast.IsIdentifier(name) && propertyName.Text() == name.Text()) {
			propertyName = null;
		}

		return Factory().NewExportDeclaration(null, false, Factory().NewNamedExports(Factory().NewNodeList([Factory().NewExportSpecifier(false, propertyName, name)])),
			null, null);
	}

	function transformCommonJSExport(input:Node, name:Node):Node {
		final res = transformCommonJSExportWorker(input, name);
		if (res == null) {
			return res;
		}
		return wrapInCJSExportNamespace(res);
	}

	function transformCommonJSExportWorker(input:Node, name:Node):Node {
		var nameText = "";
		if (Ast.IsIdentifier(name) || Ast.IsStringLiteral(name)) {
			nameText = name.Text();
		}
		if (witnessedCjsExports.Has(nameText) && nameText != "") {
			return null; // Already emitted this export name
		}
		witnessedCjsExports.Add(nameText);
		resultHasExternalModuleIndicator = true;
		resultHasScopeMarker = true;
		// only transform cjs exports to shorthand at the top-level of a source file, otherwise we uniformly emit nested exports with a type annotation
		if (Declarations.isCommonJSAliasExport(input) && Ast.IsExpressionStatement(input.Parent) && Ast.IsSourceFile(input.Parent.Parent)) {
			// export { name }
			// export { source as name }
			return transformBinaryExpressionToExportDeclaration(input, name);
		}

		// Check if the RHS is a class expression - emit as a class declaration instead of a typed variable
		if (Ast.IsBinaryExpression(input)) {
			final rhs = Declarations.unwrapParenthesizedExpression(input.AsBinaryExpression().Right);
			if (Ast.IsClassExpression(rhs)) {
				final ce = rhs.AsClassExpression();
				final classExprName = ce.Name();
				final hasExprName = classExprName != null && classExprName.Text().length > 0;

				if (hasExprName) {
					// Set up TrackSymbol watch to detect if the class expression's own
					// symbol is referenced during member type serialization.
					tracker.watchedClassSymbol = rhs.Symbol();
					tracker.classSymbolTracked = false;
					// PORT: defer on the success path only (docs/PORTING.md §4): restoreWatch() at each return below.
					final restoreWatch = function():Void {
						tracker.watchedClassSymbol = null;
						tracker.classSymbolTracked = false;
					};

					// Serialize class members using the class expression name, which
					// triggers TrackSymbol for any self-referential member types.
					final className = Factory().NewIdentifier(classExprName.Text());
					final classMods = [Factory().NewModifier(KindExportKeyword)];
					var classDecl = transformClassExpressionToDeclaration(rhs, className, Factory().NewModifierList(classMods));
					preserveJsDoc(classDecl, input);

					// Determine if namespace isolation is needed:
					// - The class expression name differs from the export name, OR
					// - The class's own symbol was used in a member's serialized type
					final namesDiffer = !Ast.IsIdentifier(name) || classExprName.Text() != name.Text();
					final needsIsolation = namesDiffer || tracker.classSymbolTracked;

					if (needsIsolation) {
						final nsName = Factory().NewUniqueNameEx("_ns", optimisticOptions());
						var nsMods:Array<Node> = null;
						if (needsDeclare) {
							nsMods = [Factory().NewModifier(KindDeclareKeyword)];
						}
						final nsDecl = Factory().NewModuleDeclaration(Factory().NewModifierList(nsMods), KindNamespaceKeyword, nsName,
							Factory().NewModuleBlock(Factory().NewNodeList([classDecl])));

						var aliasBase = "_exported";
						final nameText = name.Text();
						if (Ast.IsIdentifier(name) && Scanner.IsIdentifierText("_" + nameText, LanguageVariantStandard)) {
							aliasBase = "_" + nameText;
						}
						final importAlias = Factory().NewUniqueNameEx(aliasBase, optimisticOptions());
						final qualifiedName = Factory().NewQualifiedName(nsName, className);
						final importDecl = Factory().NewImportEqualsDeclaration(null, false, importAlias, qualifiedName);

						final exportSpecifier = Factory().NewExportSpecifier(false, importAlias, name);
						final exportDecl = Factory().NewExportDeclaration(null, false, Factory().NewNamedExports(Factory().NewNodeList([exportSpecifier])), null, null);
						removeAllComments(exportDecl);

						final r = Factory().NewSyntaxList([nsDecl, importDecl, exportDecl]);
						restoreWatch();
						return r;
					}

					// No isolation needed: names match and no self-references.
					// Update modifiers to include declare if needed.
					var mods:Array<Node> = null;
					mods = [Factory().NewModifier(KindExportKeyword)];
					if (needsDeclare) {
						mods.push(Factory().NewModifier(KindDeclareKeyword));
					}
					classDecl = Factory().UpdateClassDeclaration(classDecl.AsClassDeclaration(), Factory().NewModifierList(mods), classDecl.AsClassDeclaration().Name(),
						classDecl.AsClassDeclaration().TypeParameters, classDecl.AsClassDeclaration().HeritageClauses, classDecl.AsClassDeclaration().Members);
					restoreWatch();
					return classDecl;
				}
				var mods:Array<Node> = null;
				mods = [Factory().NewModifier(KindExportKeyword)];
				if (needsDeclare) {
					mods.push(Factory().NewModifier(KindDeclareKeyword));
				}
				var className = name;
				if (!Ast.IsIdentifier(className)) {
					className = Factory().NewUniqueNameEx("_class", optimisticOptions());
				}
				final classDecl = transformClassExpressionToDeclaration(rhs, className, Factory().NewModifierList(mods));
				preserveJsDoc(classDecl, input);
				if (!Ast.IsIdentifier(name)) {
					// Non-identifier name: emit class declaration + named export
					final exportDecl = Factory().NewExportDeclaration(null, false,
						Factory().NewNamedExports(Factory().NewNodeList([Factory().NewExportSpecifier(false, className, name)])), null, null);
					removeAllComments(exportDecl);
					return Factory().NewSyntaxList([classDecl, exportDecl]);
				}
				return classDecl;
			}
		}

		if (Ast.IsIdentifier(name)) {
			if (name.Text() == "default") {
				// const _default: Type; export default _default;
				final newId = Factory().NewUniqueNameEx("_default", optimisticOptions());
				state.getSymbolAccessibilityDiagnostic = function(_:SymbolAccessibilityResult):SymbolAccessibilityDiagnostic {
					final d = new SymbolAccessibilityDiagnostic();
					d.diagnosticMessage = Diagnostics.Default_export_of_the_module_has_or_is_using_private_name_0;
					d.errorNode = input;
					return d;
				};
				tracker.PushErrorFallbackNode(input);
				final type_ = ensureType(input, false);
				final varDecl = Factory().NewVariableDeclaration(newId, null, type_, null);
				tracker.PopErrorFallbackNode();
				var modList:ModifierList;
				if (needsDeclare) {
					modList = Factory().NewModifierList([Factory().NewModifier(KindDeclareKeyword)]);
				} else {
					modList = Factory().NewModifierList([]);
				}
				final statement = Factory().NewVariableStatement(modList, Factory().NewVariableDeclarationList(Factory().NewNodeList([varDecl]), NodeFlagsConst));

				final assignment = Factory().NewExportAssignment(input.Modifiers(), false, null, newId);
				// Remove comments from the export declaration and copy them onto the synthetic _default declaration
				preserveJsDoc(statement, input);
				removeAllComments(assignment);
				return Factory().NewSyntaxList([statement, assignment]);
			} else if (host.GetEmitResolver().GetReferencedValueDeclaration(name) == input || host.GetEmitResolver().GetReferencedValueDeclaration(name) == null) {
				// only inline to a export var if the `name` lookup points at this assignment or nothing - if it points at something else, we must use a temp name
				// export var name: Type
				tracker.PushErrorFallbackNode(input);
				final type_ = ensureType(input, false);
				final varDecl = Factory().NewVariableDeclaration(name, null, type_, null);
				tracker.PopErrorFallbackNode();
				var modList:ModifierList;
				if (needsDeclare) {
					modList = Factory().NewModifierList([Factory().NewModifier(KindExportKeyword), Factory().NewModifier(KindDeclareKeyword)]);
				} else {
					modList = Factory().NewModifierList([Factory().NewModifier(KindExportKeyword)]);
				}
				return Factory().NewVariableStatement(modList, Factory().NewVariableDeclarationList(Factory().NewNodeList([varDecl]), NodeFlagsNone));
			}
		}
		// const _exported: Type; export {_exported as "name"};
		final newId = Factory().NewUniqueNameEx("_exported", optimisticOptions());
		state.getSymbolAccessibilityDiagnostic = function(_:SymbolAccessibilityResult):SymbolAccessibilityDiagnostic {
			final d = new SymbolAccessibilityDiagnostic();
			d.diagnosticMessage = Diagnostics.Default_export_of_the_module_has_or_is_using_private_name_0;
			d.errorNode = input;
			return d;
		};
		tracker.PushErrorFallbackNode(input);
		final type_ = ensureType(input, false);
		final varDecl = Factory().NewVariableDeclaration(newId, null, type_, null);
		tracker.PopErrorFallbackNode();
		var modList:ModifierList;
		if (needsDeclare) {
			modList = Factory().NewModifierList([Factory().NewModifier(KindDeclareKeyword)]);
		} else {
			modList = Factory().NewModifierList([]);
		}
		final statement = Factory().NewVariableStatement(modList, Factory().NewVariableDeclarationList(Factory().NewNodeList([varDecl]), NodeFlagsConst));

		final assignment = Factory().NewExportDeclaration(null, false, Factory().NewNamedExports(Factory().NewNodeList([Factory().NewExportSpecifier(false, newId, name)])),
			null, null);
		// Remove comments from the export declaration and copy them onto the synthetic _default declaration
		preserveJsDoc(statement, input);
		removeAllComments(assignment);
		return Factory().NewSyntaxList([statement, assignment]);
	}

	function wrapInCJSExportNamespace(content:Node):Node {
		if (cjsExportAssignmentName == null) {
			return content;
		}
		// Reuse the same name node so unique names resolve consistently with the class/export
		final nsName = cjsExportAssignmentName;
		var members:Array<Node>;
		if (content.Kind == KindSyntaxList) {
			members = content.AsSyntaxList().Children;
		} else {
			members = [content];
		}
		var nsMods:Array<Node> = null;
		if (needsDeclare) {
			nsMods = [Factory().NewModifier(KindDeclareKeyword)];
		}
		members = declareStrippingVisitor.VisitSlice(members);
		return Factory().NewModuleDeclaration(Factory().NewModifierList(nsMods), KindNamespaceKeyword, nsName,
			Factory().NewModuleBlock(Factory().NewNodeList(members)));
	}

	// transformClassExpressionToDeclaration converts a class expression into a class declaration
	// for use in CJS export declarations (e.g., exports.K = class K {} or module.exports = class Thing {}).
	// This delegates to the shared buildClassMembers helper to stay in sync with transformClassDeclaration.
	function transformClassExpressionToDeclaration(classExpr:Node, className:Node, modifiers:ModifierList):Node {
		final previousEnclosingDeclaration = enclosingDeclaration;
		enclosingDeclaration = classExpr;
		final previousInClassExpressionDeclaration = inClassExpressionDeclaration;
		inClassExpressionDeclaration = true;
		// PORT: defer on the success path only (docs/PORTING.md §4).

		var extraMembers:Array<Node> = null;
		if (Ast.IsInJSFile(classExpr)) {
			extraMembers = collectThisPropertyAssignments(classExpr);
		}
		// PORT: Go `extraMembers...` with a nil slice spreads nothing.
		final members = buildClassMembers(classExpr, ...(extraMembers == null ? [] : extraMembers));
		final typeParameters = ensureTypeParams(classExpr, classExpr.AsClassExpression().TypeParameters);
		final heritageClauses = Visitor().VisitNodes(classExpr.AsClassExpression().HeritageClauses);

		final r = Factory().NewClassDeclaration(modifiers, className, typeParameters, heritageClauses, members);
		enclosingDeclaration = previousEnclosingDeclaration;
		inClassExpressionDeclaration = previousInClassExpressionDeclaration;
		return r;
	}

	function rewriteModuleSpecifier(parent:Node, input:Node):Node {
		if (input == null) {
			return null;
		}
		resultHasExternalModuleIndicator = resultHasExternalModuleIndicator || (parent.Kind != KindModuleDeclaration && parent.Kind != KindImportType);
		return input;
	}

	function tryGetResolutionModeOverride(node:Node):Node {
		if (node == null) {
			return node;
		}
		final mode = host.GetResolutionModeOverride(node);
		if (mode != Core.ResolutionModeNone) {
			return node;
		}
		return null;
	}

	function preserveJsDoc(updated:Node, original:Node):Void {
		// Copy comment range from original to updated node so JSDoc comments are preserved
		EmitContext().AssignCommentRange(updated, original);
	}

	function preservePartialJsDoc(updated:Node, original:Node):Void {
		if ((original.Flags & NodeFlagsReparsed) == 0) {
			return;
		}
		final jsdoc = Core.FirstOrNil(original.EagerJSDoc(Ast.GetSourceFileOfNode(original)));
		if (jsdoc == null) {
			return;
		}
		final description = Scanner.GetTextOfJSDocComment(jsdoc.AsJSDoc().Comment);
		if (description == "") {
			return;
		}
		final comment = "*\n * " + StringTools.replace(description, "\n", "\n * ") + "\n ";
		EmitContext().AddSyntheticLeadingComment(updated, KindMultiLineCommentTrivia, comment, true /*hasTrailingNewLine*/);
	}

	function removeAllComments(node:Node):Void {
		EmitContext().AddEmitFlags(node, EFNoComments);
		// !!! TODO: Also remove synthetic trailing/leading comments added by transforms
		// emitNode.leadingComments = undefined;
		// emitNode.trailingComments = undefined;
	}

	function ensureType(node:Node, ignorePrivate:Bool):Node {
		if (!ignorePrivate && host.GetEffectiveDeclarationFlags(EmitContext().ParseNode(node), ModifierFlagsPrivate) != 0) {
			// Private nodes emit no types (except private parameter properties, whose parameter types are actually visible)
			return null;
		}

		if (shouldPrintWithInitializer(node)) {
			// Literal const declarations will have an initializer ensured rather than a type
			return null;
		}

		// Should be removed createTypeOfDeclaration will actually now reuse the existing annotation so there is no real need to duplicate type walking
		// Left in for now to minimize diff during syntactic type node builder refactor
		if (!Ast.IsExportAssignment(node) && !Ast.IsBindingElement(node) && node.Type() != null
			&& (!Ast.IsParameterDeclaration(node) || !resolver.RequiresAddingImplicitUndefined(node, null, enclosingDeclaration))) {
			if (state.currentSourceFile.IsJS()) {
				// JS types have a heap of constructs we can't directly emit into .d.ts files; the node builder contains logic to remap those where possible, so we invoke it here
				// In strada we always built js declarations symbolically, so all js type nodes went through this postprocessing
				var jsFlags = Declarations.declarationEmitNodeBuilderFlags;
				if (inClassExpressionDeclaration) {
					jsFlags = jsFlags & ~FlagsWriteClassExpressionAsTypeLiteral;
				}
				final res = resolver.TryJSTypeNodeToTypeNode(EmitContext(), node.Type(), enclosingDeclaration, jsFlags,
					Declarations.declarationEmitInternalNodeBuilderFlags, tracker);
				if (res != null) {
					return res;
				}
				// otherwise, fall back to full serialization
			} else {
				return Visitor().Visit(node.Type());
			}
		}

		final oldErrorNameNode = state.errorNameNode;
		state.errorNameNode = node.Name();
		var oldDiag:GetSymbolAccessibilityDiagnostic = null;
		if (!suppressNewDiagnosticContexts) {
			oldDiag = state.getSymbolAccessibilityDiagnostic;
			if (Declarations.canProduceDiagnostics(node)) {
				state.getSymbolAccessibilityDiagnostic = Declarations.createGetSymbolAccessibilityDiagnosticForNode(node);
			}
		}
		var typeNode:Node = null;

		var flags = Declarations.declarationEmitNodeBuilderFlags;
		if (inClassExpressionDeclaration) {
			flags = flags & ~FlagsWriteClassExpressionAsTypeLiteral;
		}
		if (Ast.HasInferredType(node)) {
			typeNode = resolver.CreateTypeOfDeclaration(EmitContext(), node, enclosingDeclaration, flags, Declarations.declarationEmitInternalNodeBuilderFlags, tracker);
		} else if (Ast.IsFunctionLike(node)) {
			typeNode = resolver.CreateReturnTypeOfSignatureDeclaration(EmitContext(), node, enclosingDeclaration, flags,
				Declarations.declarationEmitInternalNodeBuilderFlags, tracker);
		} else {
			Debug.AssertNever(node);
		}

		state.errorNameNode = oldErrorNameNode;
		if (!suppressNewDiagnosticContexts) {
			state.getSymbolAccessibilityDiagnostic = oldDiag;
		}
		if (typeNode == null) {
			return Factory().NewKeywordTypeNode(KindAnyKeyword);
		}
		return typeNode;
	}

	function shouldPrintWithInitializer(node:Node):Bool {
		return Declarations.canHaveLiteralInitializer(host, node) && node.Initializer() != null
			&& resolver.IsLiteralConstDeclaration(EmitContext().MostOriginal(node));
	}

	function checkEntityNameVisibility(entityName:Node, enclosingDeclaration:Node):Void {
		final visibilityResult = resolver.IsEntityNameVisible(entityName, enclosingDeclaration);
		tracker.handleSymbolAccessibilityError(visibilityResult);
	}

	// Transforms the direct child of a source file into zero or more replacement statements
	function transformTopLevelDeclaration(input:Node):Node {
		if (Core.len(state.lateMarkedStatements) > 0) {
			// Remove duplicates of the current statement from the deferred work queue (this was done via orderedRemoveItem in strada - why? to ensure the same backing array? microop?)
			state.lateMarkedStatements = Core.Filter(state.lateMarkedStatements, function(node:Node):Bool {
				return node != input;
			});
		}
		if (shouldStripInternal(input)) {
			return null;
		}
		if (input.Kind == KindImportEqualsDeclaration) {
			return transformImportEqualsDeclaration(input.AsImportEqualsDeclaration());
		}
		if (input.Kind == KindImportDeclaration || input.Kind == KindJSImportDeclaration) {
			final res = transformImportDeclaration(input.AsImportDeclaration());
			if (res != null && res.Kind != KindImportDeclaration) {
				final res = res.Clone(Factory());
				res.Kind = KindImportDeclaration;
				return res;
			}
			return res;
		}
		if (Ast.IsDeclaration(input) && Declarations.isDeclarationAndNotVisible(EmitContext(), resolver, input)) {
			return null;
		}

		// !!! TODO: JSDoc support
		// if (isJSDocImportTag(input)) return;

		// Elide implementation signatures from overload sets
		if (Ast.IsFunctionLike(input) && resolver.IsImplementationOfOverload(input)) {
			return null;
		}
		final original = EmitContext().MostOriginal(input);
		final id = Ast.GetNodeId(original);
		if (expandoHosts.exists(id)) {
			return createFullExpandoBlock(id);
		}

		final previousEnclosingDeclaration = enclosingDeclaration;
		if (Declarations.isEnclosingDeclaration(input)) {
			enclosingDeclaration = input;
		}

		final canProdiceDiagnostic = Declarations.canProduceDiagnostics(input);
		final oldDiag = state.getSymbolAccessibilityDiagnostic;
		final oldName = state.errorNameNode;
		if (canProdiceDiagnostic) {
			state.getSymbolAccessibilityDiagnostic = Declarations.createGetSymbolAccessibilityDiagnosticForNode(input);
		}
		final saveNeedsDeclare = needsDeclare;

		var result:Node = null;
		switch (input.Kind) {
			case KindTypeAliasDeclaration, KindJSTypeAliasDeclaration:
				result = transformTypeAliasDeclaration(input.AsTypeAliasDeclaration());
			case KindInterfaceDeclaration:
				result = transformInterfaceDeclaration(input.AsInterfaceDeclaration());
			case KindFunctionDeclaration:
				result = transformFunctionDeclaration(input.AsFunctionDeclaration());
			case KindModuleDeclaration:
				result = transformModuleDeclaration(input.AsModuleDeclaration());
			case KindClassDeclaration:
				result = transformClassDeclaration(input.AsClassDeclaration());
			case KindVariableStatement:
				result = transformVariableStatement(input.AsVariableStatement());
			case KindEnumDeclaration:
				result = transformEnumDeclaration(input.AsEnumDeclaration());
			default:
				// Anything left unhandled is an error, so this should be unreachable
				// PORT: Go fmt.Sprintf("%q", input.Kind) → quoted Kind name.
				throw "Unhandled top-level node in declaration emit: \"" + input.Kind.String() + "\"";
		}

		enclosingDeclaration = previousEnclosingDeclaration;
		state.getSymbolAccessibilityDiagnostic = oldDiag;
		needsDeclare = saveNeedsDeclare;
		state.errorNameNode = oldName;
		return result;
	}

	function transformTypeAliasDeclaration(input:TypeAliasDeclaration):Node {
		needsDeclare = false;
		return Factory().UpdateTypeAliasDeclaration(input, ensureModifiers(input.AsNode()), input.Name(), Visitor().VisitNodes(input.TypeParameters),
			Visitor().Visit(input.Type));
	}

	function transformInterfaceDeclaration(input:InterfaceDeclaration):Node {
		return Factory().UpdateInterfaceDeclaration(input, ensureModifiers(input.AsNode()), input.Name(), Visitor().VisitNodes(input.TypeParameters),
			Visitor().VisitNodes(input.HeritageClauses), Visitor().VisitNodes(input.Members));
	}

	function transformFunctionDeclaration(input:FunctionDeclaration):Node {
		if (resolver.IsExpandoFunctionDeclaration(input.AsNode())) {
			state.reportExpandoFunctionErrors(input.AsNode());
		}
		return Factory().UpdateFunctionDeclaration(input, ensureModifiers(input.AsNode()), null, input.Name(), ensureTypeParams(input.AsNode(), input.TypeParameters),
			updateParamList(input.AsNode(), input.Parameters), ensureType(input.AsNode(), false), null, /*fullSignature*/ null);
	}

	function transformModuleDeclaration(input:ModuleDeclaration):Node {
		// !!! TODO: module declarations are now parsed into nested module objects with export modifiers
		// It'd be good to collapse those back in the declaration output, but the AST can't represent the
		// `namespace a.b.c` shape for the printer (without using invalid identifier names).
		final mods = ensureModifiers(input.AsNode());
		final saveNeedsDeclare = needsDeclare;
		needsDeclare = false;
		final inner = input.Body;
		var keyword = input.Keyword;
		if (keyword != KindGlobalKeyword && (input.Name() == null || !Ast.IsStringLiteral(input.Name()))) {
			keyword = KindNamespaceKeyword;
		}

		if (inner != null && inner.Kind == KindModuleBlock) {
			final oldNeedsScopeFix = needsScopeFixMarker;
			final oldHasScopeFix = resultHasScopeMarker;
			resultHasScopeMarker = false;
			needsScopeFixMarker = false;
			final statements = Visitor().VisitNodes(inner.StatementList());
			var lateStatements = transformAndReplaceLatePaintedStatements(statements);
			if ((input.Flags & NodeFlagsAmbient) != 0) {
				needsScopeFixMarker = false; // If it was `declare`'d everything is implicitly exported already, ignore late printed "privates"
			}
			// With the final list of statements, there are 3 possibilities:
			// 1. There's an export assignment or export declaration in the namespace - do nothing
			// 2. Everything is exported and there are no export assignments or export declarations - strip all export modifiers
			// 3. Some things are exported, some are not, and there's no marker - add an empty marker
			if (!Ast.IsGlobalScopeAugmentation(input.AsNode()) && !resultHasScopeMarker && !Declarations.hasScopeMarker(lateStatements)) {
				if (needsScopeFixMarker) {
					// PORT: Go append may share lateStatements.Nodes' backing array; copy.
					final nodes = lateStatements.Nodes == null ? [] : lateStatements.Nodes.copy();
					nodes.push(Declarations.createEmptyExports(Factory().AsNodeFactory()));
					lateStatements = Factory().NewNodeList(nodes);
				} else {
					lateStatements = exportStrippingVisitor.VisitNodes(lateStatements);
				}
			}

			final body = Factory().UpdateModuleBlock(inner.AsModuleBlock(), lateStatements);
			needsDeclare = saveNeedsDeclare;
			needsScopeFixMarker = oldNeedsScopeFix;
			resultHasScopeMarker = oldHasScopeFix;

			return Factory().UpdateModuleDeclaration(input, mods, keyword, input.Name(), body);
		}
		if (inner != null) {
			// trigger visit. ignore result (is deferred, so is just inner unless elided)
			Visitor().Visit(inner);
			// eagerly transform nested namespaces (the nesting doesn't need any elision or painting done)
			final original = EmitContext().MostOriginal(inner);
			final id = Ast.GetNodeId(original);
			final body = lateStatementReplacementMap.get(id);
			lateStatementReplacementMap.remove(id);
			return Factory().UpdateModuleDeclaration(input, mods, keyword, input.Name(), body);
		}
		return Factory().UpdateModuleDeclaration(input, mods, keyword, input.Name(), null);
	}

	function stripExportModifiers(statement:Node):Node {
		if (statement == null) {
			return null;
		}
		final parseNode = EmitContext().ParseNode(statement);
		if (Ast.IsImportEqualsDeclaration(statement)
			|| (parseNode != null && host.GetEffectiveDeclarationFlags(parseNode, ModifierFlagsDefault) != 0)
			|| !Ast.CanHaveModifiers(statement)) {
			// `export import` statements should remain as-is, as imports are _not_ implicitly exported in an ambient namespace
			// Likewise, `export default` classes and the like and just be `default`, so we preserve their `export` modifiers, too
			return statement;
		}

		final oldFlags = Ast.GetCombinedModifierFlags(statement);
		if ((oldFlags & ModifierFlagsExport) == 0) {
			return statement;
		}
		final newFlags = oldFlags & (ModifierFlagsAll ^ ModifierFlagsExport);
		final modifiers = Ast.CreateModifiersFromModifierFlags(newFlags, Factory().NewModifier);
		return Ast.ReplaceModifiers(Factory().AsNodeFactory(), statement, Factory().NewModifierList(modifiers));
	}

	// buildClassMembers builds the member list for a class-like node (ClassDeclaration or ClassExpression).
	// It handles parameter properties, private identifiers, late-bound index signatures, and visited members.
	// Extra members (e.g., this-property assignments from JS files) can be passed via extraMembers.
	function buildClassMembers(classNode:Node, ...extraMembers:Node):NodeList {
		final ctor = Ast.GetFirstConstructorWithBody(classNode);
		var parameterProperties:Array<Node> = null;
		if (ctor != null) {
			final oldDiag = state.getSymbolAccessibilityDiagnostic;
			for (param in ctor.AsConstructorDeclaration().Parameters.Nodes) {
				if (!Ast.HasSyntacticModifier(param, ModifierFlagsParameterPropertyModifier) || shouldStripInternal(param)) {
					continue;
				}
				state.getSymbolAccessibilityDiagnostic = Declarations.createGetSymbolAccessibilityDiagnosticForNode(param);
				if (parameterProperties == null) {
					parameterProperties = [];
				}
				if (param.Name().Kind == KindIdentifier) {
					final updated = Factory().NewPropertyDeclaration(ensureModifiers(param), param.Name(), param.QuestionToken(), ensureType(param, false),
						ensureNoInitializer(param));
					preserveJsDoc(updated, param);
					parameterProperties.push(updated);
				} else {
					// Pattern - this is currently an error, but we emit declarations for it somewhat correctly
					final elems = walkBindingPattern(param.Name().AsBindingPattern(), param);
					if (elems != null) {
						for (e in elems) {
							parameterProperties.push(e);
						}
					}
				}
			}
			state.getSymbolAccessibilityDiagnostic = oldDiag;
		}

		// When the class has at least one private identifier, create a unique constant identifier to retain the nominal typing behavior
		// Prevents other classes with the same public members from being used in place of the current class
		var privateIdentifier:Node = null;
		if (Core.Some(classNode.ClassLikeData().Members.Nodes, function(member:Node):Bool {
			return member.Name() != null && Ast.IsPrivateIdentifier(member.Name());
		})) {
			privateIdentifier = Factory().NewPropertyDeclaration(null, Factory().NewPrivateIdentifier("#private"), null, null, null);
		}

		final lateIndexes = resolver.CreateLateBoundIndexSignatures(EmitContext(), classNode, enclosingDeclaration, Declarations.declarationEmitNodeBuilderFlags,
			Declarations.declarationEmitInternalNodeBuilderFlags, tracker);

		final memberNodes:Array<Node> = [];
		if (privateIdentifier != null) {
			memberNodes.push(privateIdentifier);
		}
		if (lateIndexes != null) {
			for (n in lateIndexes) {
				memberNodes.push(n);
			}
		}
		if (parameterProperties != null) {
			for (n in parameterProperties) {
				memberNodes.push(n);
			}
		}
		for (n in extraMembers) {
			memberNodes.push(n);
		}
		final visitResult = Visitor().VisitNodes(classNode.ClassLikeData().Members);
		if (visitResult != null && Core.len(visitResult.Nodes) > 0) {
			for (n in visitResult.Nodes) {
				memberNodes.push(n);
			}
		}
		return Factory().NewNodeList(memberNodes);
	}

	function transformClassDeclaration(input:ClassDeclaration):Node {
		final previousEnclosingDeclaration = enclosingDeclaration;
		enclosingDeclaration = input.AsNode();

		state.errorNameNode = input.Name();
		tracker.PushErrorFallbackNode(input.AsNode());
		// PORT: the two Go defers (LIFO: PopErrorFallbackNode, then restore enclosingDeclaration) run on the success path at each return.
		final done = function(r:Node):Node {
			tracker.PopErrorFallbackNode();
			enclosingDeclaration = previousEnclosingDeclaration;
			return r;
		};

		final modifiers = ensureModifiers(input.AsNode());
		final typeParameters = ensureTypeParams(input.AsNode(), input.TypeParameters);

		// Collect this.x property assignments from constructors and static blocks in JS files
		var extraMembers:Array<Node> = null;
		if (Ast.IsInJSFile(input.AsNode())) {
			extraMembers = collectThisPropertyAssignments(input.AsNode());
		}

		// PORT: Go `extraMembers...` with a nil slice spreads nothing.
		final members = buildClassMembers(input.AsNode(), ...(extraMembers == null ? [] : extraMembers));

		final extendsClause = Declarations.getEffectiveBaseTypeNode(input.AsNode());

		if (extendsClause != null && !Ast.IsEntityNameExpression(extendsClause.AsExpressionWithTypeArguments().Expression)
			&& extendsClause.AsExpressionWithTypeArguments().Expression.Kind != KindNullKeyword) {
			tracker.ReportInferenceFallback(extendsClause.AsExpressionWithTypeArguments().Expression); // Add an isolated declarations error on this extends clause
			var oldId = "default";
			if (Ast.NodeIsPresent(input.Name()) && Ast.IsIdentifier(input.Name()) && input.Name().Text().length > 0) {
				oldId = input.Name().Text();
			}
			final newId = Factory().NewUniqueNameEx(oldId + "_base", optimisticOptions());
			state.getSymbolAccessibilityDiagnostic = function(_:SymbolAccessibilityResult):SymbolAccessibilityDiagnostic {
				final d = new SymbolAccessibilityDiagnostic();
				d.diagnosticMessage = Diagnostics.X_extends_clause_of_exported_class_0_has_or_is_using_private_name_1;
				d.errorNode = extendsClause;
				d.typeName = input.Name();
				return d;
			};

			final varDecl = Factory().NewVariableDeclaration(newId, null,
				resolver.CreateTypeOfExpression(EmitContext(), extendsClause.Expression(), input.AsNode(), Declarations.declarationEmitNodeBuilderFlags,
					Declarations.declarationEmitInternalNodeBuilderFlags, tracker), null);
			var mods:ModifierList = null;
			if (needsDeclare) {
				mods = Factory().NewModifierList([Factory().NewModifier(KindDeclareKeyword)]);
			}
			final statement = Factory().NewVariableStatement(mods, Factory().NewVariableDeclarationList(Factory().NewNodeList([varDecl]), NodeFlagsConst));
			final newHeritageClause = Factory().UpdateHeritageClause(extendsClause.Parent.AsHeritageClause(), extendsClause.Parent.AsHeritageClause().Token,
				Factory().NewNodeList([
					Factory().UpdateExpressionWithTypeArguments(extendsClause.AsExpressionWithTypeArguments(), newId,
						Visitor().VisitNodes(extendsClause.AsExpressionWithTypeArguments().TypeArguments)),
				]));
			final retainedHeritageClauses = Visitor().VisitNodes(input.HeritageClauses); // should just be `implements`
			final heritageList:Array<Node> = [newHeritageClause];
			if (retainedHeritageClauses != null && Core.len(retainedHeritageClauses.Nodes) > 0) {
				for (n in retainedHeritageClauses.Nodes) {
					heritageList.push(n);
				}
			}
			final heritageClauses = Factory().NewNodeList(heritageList);

			return done(Factory().NewSyntaxList([
				statement,
				Factory().UpdateClassDeclaration(input, modifiers, input.Name(), typeParameters, heritageClauses, members),
			]));
		}

		return done(Factory().UpdateClassDeclaration(input, modifiers, input.Name(), typeParameters, Visitor().VisitNodes(input.HeritageClauses), members));
	}

	function visitThisPropertyAssignments(node:Node):Node {
		var thisTarget:Node = null;
		var isStatic = false;
		final thisContainer = Ast.GetThisContainer(node, false, false);
		thisTarget = thisContainer.Parent;
		if (thisTarget == null) {
			return null; // thisContainer was source file, can't have expando-this
		}
		if (Ast.HasStaticModifier(thisContainer) || Ast.IsClassStaticBlockDeclaration(thisContainer)) {
			isStatic = true;
		}
		if (thisTarget != enclosingDeclaration) {
			return null; // stop searching within new `this` contexts
		}
		// PORT: label — `caseBlock: switch` with `break` / `break caseBlock` → a local function whose `return` leaves the switch.
		final caseBlock = function():Void {
			switch (Ast.GetAssignmentDeclarationKind(node)) {
				case JSDeclarationKindThisProperty:
					var name = Ast.GetNameOfDeclaration(node);
					final base = resolver.GetReferencedMemberValueDeclaration(node);
					final key = Declarations.getThisPropertyAssignmentKey(name, node, isStatic);
					if (base == null || seenProperties.Has(key.Key(this))) {
						return;
					}
					seenProperties.Add(key.Key(this));

					// problem: this prop might be overriding a prop from a base type. The checker has special bails for override compat comparisons for binary expression properties,
					// but what we transform to won't - so we either need to match the base type (for example, if it's a getter/setter) or emit nothing
					// See `checkKindsOfPropertyMemberOverrides` in the checker for what we're trying to satisfy here
					if (thisTarget.ClassLikeData().HeritageClauses != null && Core.len(thisTarget.ClassLikeData().HeritageClauses.Nodes) > 0
						&& !Declarations.isClassExtendingNull(thisTarget)) {
						// there is a base type any assignments might be "from"
						tracker.ReportInferenceFallback(thisTarget); // Add an isolated declarations error on this class - we can't know how to transform this prop into an assignment without referring to type information
						if (resolver.IsThisPropertyAssignmentDeclarationRedundant(node)) {
							return; // skip assignments whose member is already provided by an `extends` base type (an inherited accessor/method, or an identical inherited property)
							// TODO: If the property has an explicit `@type` annotation, we should probably emit it (maybe with an `override` modifier) instead of skipping it
						}
					}

					var mods:ModifierList = null;
					if (isStatic) {
						mods = Factory().NewModifierList([Factory().NewModifier(KindStaticKeyword)]);
					}
					if (Ast.HasDynamicName(node)) {
						if (!Transformers.IsSimpleInlineableExpression(name)) {
							return; // Member either becomes an index signature or is a reassignment
						}
						checkName(node);
						name = Factory().NewComputedPropertyName(name); // Convert `this[foo] = expr` to `[foo]: Type`
					}
					if (Ast.GetTextOfPropertyName(name) == "constructor") {
						return; // `constructor` is a builtin class member, not allowed to redeclare it
					}
					if (Ast.IsIdentifier(name) && !Scanner.IsIdentifierText(name.Text(), LanguageVariantStandard)) {
						name = Factory().NewStringLiteralFromNode(name);
					}
					final prop = Factory().NewPropertyDeclaration(mods, name, null, ensureType(node, false), null);
					if (Ast.IsExpressionStatement(node.Parent)) {
						preserveJsDoc(prop, node.Parent);
					}
					thisPropertyAssignmentsCollected.push(prop);
				default:
			}
		};
		caseBlock();
		return thisPropertyVisitor.VisitEachChild(node);
	}

	// collectThisPropertyAssignments finds `this.x = expr` assignments in constructors, methods, and static blocks
	// of JS classes and synthesizes PropertyDeclaration nodes for each unique property name.
	function collectThisPropertyAssignments(classNode:Node):Array<Node> {
		final members = classNode.ClassLikeData().Members;
		final seen = new Set<std.String>();
		// Pre-populate seen with existing direct member nodes to avoid duplicates
		for (member in members.Nodes) {
			if (member.Name() != null) {
				final isStatic = Ast.IsStatic(member);
				seen.Add(Declarations.getThisPropertyAssignmentKey(member.Name(), member, isStatic).Key(this));
			}
		}
		seenProperties = seen;
		thisPropertyAssignmentsCollected = [];
		// PORT: the two Go defers run on the success path below (LIFO).

		for (n in members.Nodes) {
			thisPropertyVisitor.VisitEachChild(n);
		}
		final r = thisPropertyAssignmentsCollected;
		thisPropertyAssignmentsCollected = null;
		seenProperties.Clear();
		return r;
	}

	function walkBindingPattern(pattern:BindingPattern, param:Node):Array<Node> {
		var elems:Array<Node> = null;
		for (elem in pattern.Elements.Nodes) {
			if (Ast.IsOmittedExpression(elem)) {
				continue;
			}
			if (Ast.IsBindingPattern(elem.Name())) {
				final inner = walkBindingPattern(elem.Name().AsBindingPattern(), param);
				if (inner != null) {
					if (elems == null) {
						elems = [];
					}
					for (e in inner) {
						elems.push(e);
					}
				}
				continue;
			}
			if (elems == null) {
				elems = [];
			}
			elems.push(Factory().NewPropertyDeclaration(ensureModifiers(param), elem.Name(), null, /*questionOrExclamationToken*/
				ensureType(elem, false), null /*initializer*/));
		}
		return elems;
	}

	function transformVariableStatement(input:VariableStatement):Node {
		var visible = false;
		for (decl in input.DeclarationList.AsVariableDeclarationList().Declarations.Nodes) {
			visible = Declarations.getBindingNameVisible(resolver, decl);
			if (visible) {
				break;
			}
		}
		if (!visible) {
			return null;
		}

		var inputNodes = input.DeclarationList.AsVariableDeclarationList().Declarations.Nodes;
		var extraImports:Array<Node> = null;
		if (state.currentSourceFile.CommonJSModuleIndicator != null) {
			var normalDeclarations:Array<Node> = null;
			var imports:Array<Node> = null;
			for (n in inputNodes) {
				if (Ast.IsVariableDeclarationInitializedToRequire(n)) {
					if (imports == null) {
						imports = [];
					}
					imports.push(n);
				} else {
					if (normalDeclarations == null) {
						normalDeclarations = [];
					}
					normalDeclarations.push(n);
				}
			}
			inputNodes = normalDeclarations;
			extraImports = Visitor().VisitSlice(imports);
		}

		final nodes = Visitor().VisitSlice(inputNodes);
		if (Core.len(nodes) == 0) {
			if (Core.len(extraImports) > 0) {
				return Factory().NewSyntaxList(extraImports);
			}
			return null;
		}
		final nodeList = Factory().NewNodeList(nodes);

		final modifiers = ensureModifiers(input.AsNode());

		var declList:Node;
		if (Ast.IsVarUsing(input.DeclarationList) || Ast.IsVarAwaitUsing(input.DeclarationList)) {
			declList = Factory().NewVariableDeclarationList(nodeList, NodeFlagsConst);
			EmitContext().SetOriginal(declList, input.DeclarationList);
			EmitContext().SetCommentRange(declList, input.DeclarationList.Loc);
			declList.Loc = input.DeclarationList.Loc;
		} else {
			declList = Factory().UpdateVariableDeclarationList(input.DeclarationList.AsVariableDeclarationList(), nodeList, input.DeclarationList.Flags);
		}
		final res = Factory().UpdateVariableStatement(input, modifiers, declList);
		if (Core.len(extraImports) > 0) {
			// PORT: Go append may share extraImports' backing array; copy.
			final list = extraImports.copy();
			list.push(res);
			return Factory().NewSyntaxList(list);
		}
		return res;
	}

	function transformEnumDeclaration(input:EnumDeclaration):Node {
		return Factory().UpdateEnumDeclaration(input, ensureModifiers(input.AsNode()), input.Name(),
			Factory().NewNodeList(Core.MapNonNil(input.Members.Nodes, function(m:Node):Node {
				if (shouldStripInternal(m)) {
					return null;
				}

				// Rewrite enum values to their constants, if available
				final enumValue = resolver.GetEnumMemberValue(m);

				if (state.isolatedDeclarations && m.Initializer() != null && enumValue.HasExternalReferences && // This will be its own compiler error instead, so don't report.
					!Ast.IsComputedPropertyName(m.Name())) {
					state.addDiagnostic(Declarations.createDiagnosticForNode(m,
						Diagnostics.Enum_member_initializers_must_be_computable_without_references_to_external_symbols_with_isolatedDeclarations));
				}

				var newInitializer:Node = null;
				// PORT: Go type switch on enumValue.Value (jsnum.Number | string | nil).
				final v:Any = enumValue.Value;
				if (v != null && Std.isOfType(v, Float)) {
					final value:ts.jsnum.Jsnum.Number = (v : Float);
					if (value.IsInf()) {
						if (value > 0) {
							newInitializer = Factory().NewIdentifier("Infinity");
						} else {
							newInitializer = Factory().NewPrefixUnaryExpression(KindMinusToken, Factory().NewIdentifier("Infinity"));
						}
					} else if (value.IsNaN()) {
						newInitializer = Factory().NewIdentifier("NaN");
					} else if (value >= 0) {
						newInitializer = Factory().NewNumericLiteral(ts.jsnum.String_.String(value), TokenFlagsNone);
					} else {
						newInitializer = Factory().NewPrefixUnaryExpression(KindMinusToken, Factory().NewNumericLiteral(ts.jsnum.String_.String(-value), TokenFlagsNone));
					}
				} else if (v != null && Std.isOfType(v, std.String)) {
					newInitializer = Factory().NewStringLiteral((v : std.String), TokenFlagsNone);
				} else {
					// nil
					newInitializer = null;
				}
				final result = Factory().UpdateEnumMember(m.AsEnumMember(), m.Name(), newInitializer);
				preserveJsDoc(result, m);
				return result;
			})));
	}

	function ensureModifiers(node:Node):ModifierList {
		final currentFlags = Ast.GetCombinedModifierFlags(EmitContext().ParseNode(node)) & ModifierFlagsAll;
		final newFlags = ensureModifierFlags(node);
		if (currentFlags == newFlags) {
			// Elide decorators
			final mods = node.Modifiers();
			if (mods == null) {
				return mods;
			}
			if (Declarations.canReuseModifierNodes(mods.Nodes)) {
				return Factory().NewModifierList(Core.Filter(mods.Nodes, Ast.IsModifier));
			}
		}
		final result = Ast.CreateModifiersFromModifierFlags(newFlags, Factory().NewModifier);
		if (Core.len(result) == 0) {
			return null;
		}
		return Factory().NewModifierList(result);
	}

	function ensureModifierFlags(node:Node):ModifierFlags {
		var mask = ModifierFlagsAll ^ (ModifierFlagsPublic | ModifierFlagsAsync | ModifierFlagsOverride); // No async and override modifiers in declaration files
		var additions = ModifierFlagsNone;
		if (needsDeclare && !Declarations.isAlwaysType(node)) {
			additions = ModifierFlagsAmbient;
		}
		final parentIsFile = node.Parent.Kind == KindSourceFile;
		if (!parentIsFile) {
			mask = mask ^ ModifierFlagsAmbient;
			additions = ModifierFlagsNone;
		}
		if (Ast.IsImplicitlyExportedJSDocDeclaration(node)) {
			additions = additions | ModifierFlagsExport;
		}
		return Declarations.maskModifierFlags(node, mask, additions);
	}

	function ensureTypeParams(node:Node, params:TypeParameterList):TypeParameterList {
		if (host.GetEffectiveDeclarationFlags(EmitContext().ParseNode(node), ModifierFlagsPrivate) != 0) {
			return null;
		}
		var typeParameters:TypeParameterList = null;
		if ((typeParameters = Visitor().VisitNodes(params)) != null) {
			return typeParameters;
		}
		final oldErrorNameNode = state.errorNameNode;
		state.errorNameNode = node.Name();
		var oldDiag:GetSymbolAccessibilityDiagnostic = null;
		if (!suppressNewDiagnosticContexts) {
			oldDiag = state.getSymbolAccessibilityDiagnostic;
			if (Declarations.canProduceDiagnostics(node)) {
				state.getSymbolAccessibilityDiagnostic = Declarations.createGetSymbolAccessibilityDiagnosticForNode(node);
			}
		}

		final data = node.FunctionLikeData();
		if (data != null && data.FullSignature != null) {
			final nodes = resolver.CreateTypeParametersOfSignatureDeclaration(EmitContext(), node, enclosingDeclaration, Declarations.declarationEmitNodeBuilderFlags,
				Declarations.declarationEmitInternalNodeBuilderFlags, tracker);
			if (nodes != null) {
				final list = new NodeList();
				list.Loc = node.Loc;
				list.Nodes = nodes;
				typeParameters = list;
			}
		}

		state.errorNameNode = oldErrorNameNode;
		if (!suppressNewDiagnosticContexts) {
			state.getSymbolAccessibilityDiagnostic = oldDiag;
		}
		return typeParameters;
	}

	function updateParamList(node:Node, params:ParameterList):ParameterList {
		if (host.GetEffectiveDeclarationFlags(EmitContext().ParseNode(node), ModifierFlagsPrivate) != 0 || Core.len(params.Nodes) == 0) {
			return Factory().NewNodeList([]);
		}
		final results:Array<Node> = [];
		for (i in 0...params.Nodes.length) {
			results.push(ensureParameter(params.Nodes[i].AsParameterDeclaration()));
		}
		return Factory().NewNodeList(results);
	}

	function ensureParameter(p:ParameterDeclaration):Node {
		final oldDiag = state.getSymbolAccessibilityDiagnostic;
		if (!suppressNewDiagnosticContexts) {
			state.getSymbolAccessibilityDiagnostic = Declarations.createGetSymbolAccessibilityDiagnosticForNode(p.AsNode());
		}
		var questionToken:TokenNode = null;
		if (resolver.IsOptionalParameter(p.AsNode())) {
			if (p.QuestionToken != null) {
				questionToken = p.QuestionToken;
			} else {
				questionToken = Factory().NewToken(KindQuestionToken);
			}
		}
		final result = Factory().UpdateParameterDeclaration(p, null, p.DotDotDotToken, bindingNameVisitor.VisitNode(p.Name()), questionToken,
			ensureType(p.AsNode(), true), ensureNoInitializer(p.AsNode()));
		state.getSymbolAccessibilityDiagnostic = oldDiag;
		return result;
	}

	function ensureNoInitializer(node:Node):Node {
		if (shouldPrintWithInitializer(node)) {
			final unwrappedInitializer = Declarations.unwrapParenthesizedExpression(node.Initializer());
			if (!Ast.IsPrimitiveLiteralValue(unwrappedInitializer, true)) {
				tracker.ReportInferenceFallback(node);
			}
			return resolver.CreateLiteralConstValue(EmitContext(), EmitContext().ParseNode(node), tracker);
		}
		return null;
	}

	function visitBindingName(node:Node):Node {
		switch (node.Kind) {
			case KindIdentifier, KindOmittedExpression:
				return node;
			case KindArrayBindingPattern, KindObjectBindingPattern:
				return node.VisitEachChild(bindingNameVisitor);
			case KindBindingElement:
				if (node.PropertyName() != null && Ast.IsComputedPropertyName(node.PropertyName())
					&& Ast.IsEntityNameExpression(node.PropertyName().Expression())) {
					checkEntityNameVisibility(node.PropertyName().Expression(), enclosingDeclaration);
				}
				return Factory().UpdateBindingElement(node.AsBindingElement(), node.AsBindingElement().DotDotDotToken, node.PropertyName(),
					bindingNameVisitor.VisitNode(node.Name()), null /*initializer*/);
			default:
				return node;
		}
	}

	function transformImportEqualsDeclaration(decl:ImportEqualsDeclaration):Node {
		if (!resolver.IsDeclarationVisible(decl.AsNode())) {
			return null;
		}
		if (decl.ModuleReference.Kind == KindExternalModuleReference) {
			// Rewrite external module names if necessary
			final specifier = Ast.GetExternalModuleImportEqualsDeclarationExpression(decl.AsNode());
			return Factory().UpdateImportEqualsDeclaration(decl, decl.Modifiers(), decl.IsTypeOnly, decl.Name(),
				Factory().UpdateExternalModuleReference(decl.ModuleReference.AsExternalModuleReference(), rewriteModuleSpecifier(decl.AsNode(), specifier)));
		} else {
			final oldDiag = state.getSymbolAccessibilityDiagnostic;
			state.getSymbolAccessibilityDiagnostic = Declarations.createGetSymbolAccessibilityDiagnosticForNode(decl.AsNode());
			checkEntityNameVisibility(decl.ModuleReference, enclosingDeclaration);
			state.getSymbolAccessibilityDiagnostic = oldDiag;
			return decl.AsNode();
		}
	}

	function transformImportDeclaration(decl:ImportDeclaration):Node {
		if (decl.ImportClause == null) {
			// import "mod" - possibly needed for side effects? (global interface patches, module augmentations, etc)
			return Factory().UpdateImportDeclaration(decl, decl.Modifiers(), decl.ImportClause, rewriteModuleSpecifier(decl.AsNode(), decl.ModuleSpecifier),
				tryGetResolutionModeOverride(decl.Attributes));
		}
		var phaseModifier = decl.ImportClause.AsImportClause().PhaseModifier;
		if (phaseModifier == KindDeferKeyword) {
			phaseModifier = KindUnknown;
		}
		// The `importClause` visibility corresponds to the default's visibility.
		var visibleDefaultBinding:Node = null;
		if (decl.ImportClause != null && decl.ImportClause.Name() != null && resolver.IsDeclarationVisible(decl.ImportClause)) {
			visibleDefaultBinding = decl.ImportClause.Name();
		}
		if (decl.ImportClause.AsImportClause().NamedBindings == null) {
			// No named bindings (either namespace or list), meaning the import is just default or should be elided
			if (visibleDefaultBinding == null) {
				return null;
			}
			return Factory().UpdateImportDeclaration(decl, decl.Modifiers(),
				Factory().UpdateImportClause(decl.ImportClause.AsImportClause(), phaseModifier, visibleDefaultBinding, /*namedBindings*/ null),
				rewriteModuleSpecifier(decl.AsNode(), decl.ModuleSpecifier), tryGetResolutionModeOverride(decl.Attributes));
		}
		if (decl.ImportClause.AsImportClause().NamedBindings.Kind == KindNamespaceImport) {
			// Namespace import (optionally with visible default)
			var namedBindings:Node = null;
			if (resolver.IsDeclarationVisible(decl.ImportClause.AsImportClause().NamedBindings)) {
				namedBindings = decl.ImportClause.AsImportClause().NamedBindings;
			}
			if (visibleDefaultBinding == null && namedBindings == null) {
				return null;
			}
			return Factory().UpdateImportDeclaration(decl, decl.Modifiers(),
				Factory().UpdateImportClause(decl.ImportClause.AsImportClause(), phaseModifier, visibleDefaultBinding, namedBindings),
				rewriteModuleSpecifier(decl.AsNode(), decl.ModuleSpecifier), tryGetResolutionModeOverride(decl.Attributes));
		}
		// Named imports (optionally with visible default)
		final bindingList = Core.Filter(decl.ImportClause.AsImportClause().NamedBindings.Elements(), function(b:Node):Bool {
			return resolver.IsDeclarationVisible(b);
		});
		if (Core.len(bindingList) > 0 || visibleDefaultBinding != null) {
			var namedImports:Node = null;
			if (Core.len(bindingList) > 0) {
				namedImports = Factory().UpdateNamedImports(decl.ImportClause.AsImportClause().NamedBindings.AsNamedImports(), Factory().NewNodeList(bindingList));
			}
			return Factory().UpdateImportDeclaration(decl, decl.Modifiers(),
				Factory().UpdateImportClause(decl.ImportClause.AsImportClause(), phaseModifier, visibleDefaultBinding, namedImports),
				rewriteModuleSpecifier(decl.AsNode(), decl.ModuleSpecifier), tryGetResolutionModeOverride(decl.Attributes));
		}
		// Augmentation of export depends on import
		if (resolver.IsImportRequiredByAugmentation(decl)) {
			if (state.isolatedDeclarations) {
				state.addDiagnostic(Declarations.createDiagnosticForNode(decl.AsNode(),
					Diagnostics.Declaration_emit_for_this_file_requires_preserving_this_import_for_augmentations_This_is_not_supported_with_isolatedDeclarations));
			}
			return Factory().UpdateImportDeclaration(decl, decl.Modifiers(), /*importClause*/ null, rewriteModuleSpecifier(decl.AsNode(), decl.ModuleSpecifier),
				tryGetResolutionModeOverride(decl.Attributes));
		}
		// Nothing visible
		return null;
	}

	function transformJSDocTypeExpression(input:JSDocTypeExpression):Node {
		return Visitor().Visit(input.Type);
	}

	function transformJSDocTypeLiteral(input:JSDocTypeLiteral):Node {
		final members = Visitor().VisitSlice(input.JSDocPropertyTags);
		final replacement = Factory().NewTypeLiteralNode(Factory().NewNodeList(members));
		EmitContext().SetOriginal(replacement, input.AsNode());
		return replacement;
	}

	function transformJSDocPropertyTag(input:JSDocParameterOrPropertyTag):Node {
		final replacement = Factory().NewPropertySignatureDeclaration(null, Visitor().Visit(input.TagName), null, Visitor().Visit(input.TypeExpression), null);
		EmitContext().SetOriginal(replacement, input.AsNode());
		return replacement;
	}

	function transformJSDocAllType(input:JSDocAllType):Node {
		final replacement = Factory().NewKeywordTypeNode(KindAnyKeyword);
		EmitContext().SetOriginal(replacement, input.AsNode());
		return replacement;
	}

	function transformJSDocNullableType(input:JSDocNullableType):Node {
		final replacement = Factory().NewUnionTypeNode(Factory().NewNodeList([
			Visitor().Visit(input.Type),
			Factory().NewLiteralTypeNode(Factory().NewKeywordExpression(KindNullKeyword)),
		]));
		EmitContext().SetOriginal(replacement, input.AsNode());
		return replacement;
	}

	function transformJSDocNonNullableType(input:JSDocNonNullableType):Node {
		return Visitor().Visit(input.Type);
	}

	function transformJSDocVariadicType(input:JSDocVariadicType):Node {
		final replacement = Factory().NewArrayTypeNode(Visitor().Visit(input.Type));
		EmitContext().SetOriginal(replacement, input.AsNode());
		return replacement;
	}

	function transformJSDocOptionalType(input:JSDocOptionalType):Node {
		final replacement = Factory().NewUnionTypeNode(Factory().NewNodeList([Visitor().Visit(input.Type), Factory().NewKeywordTypeNode(KindUndefinedKeyword),]));
		EmitContext().SetOriginal(replacement, input.AsNode());
		return replacement;
	}

	function getNameExpressionPreferringIdentifier(nameExpr:Node):Node {
		if (Ast.IsNumericLiteral(nameExpr)) {
			// Numeric property names are string properties in JS; convert to string literal
			nameExpr = Factory().NewStringLiteral(nameExpr.Text(), TokenFlagsNone);
		}
		if (Ast.IsStringLiteralLike(nameExpr) && Scanner.IsIdentifierText(nameExpr.Text(), LanguageVariantStandard)) {
			final result = Factory().NewIdentifier(nameExpr.Text()); // prefer non-string literal names where possible
			final kwKind = Scanner.IdentifierToKeywordKind(result.AsIdentifier());
			// keep keywords as strings, except `default`, which has special reformulations in the transformer
			if (kwKind == KindUnknown || kwKind == KindDefaultKeyword) {
				// fake this into a parse tree node so the reference resolver resolves the node via `resolveName`
				result.Parent = nameExpr.Parent;
				result.Flags = result.Flags & ~NodeFlagsSynthesized;
				// intentionally leave Loc unset so the string isn't used as the text source of the identifier
				return result;
			}
		}
		return nameExpr;
	}

	function stripDeclareModifiers(node:Node):Node {
		if (node == null) {
			return null;
		}
		final mods = node.Modifiers();
		if (mods != null) {
			final flags = node.ModifierFlags();
			if ((flags & ModifierFlagsAmbient) != 0) {
				final filtered = Core.Filter(mods.Nodes, Declarations.isNotDeclareModifier);
				node.AsMutable().SetModifiers(Factory().NewModifierList(filtered));
			}
		}
		return node; // no need to recur into children, only strip at top-level
	}

	function visitCJSExportAssignments(expression:Node):Node {
		if (expression != null) {
			setupDiagnosticContext(expression);
			// PORT: defer on the success path only (docs/PORTING.md §4).
			switch (Ast.GetAssignmentDeclarationKind(expression)) {
				case JSDeclarationKindModuleExports:
					if (state.currentSourceFile.CommonJSModuleIndicator != null) {
						final result = transformExportAssignment(expression.Parent, expression, expression.AsBinaryExpression().Right, true /*isExportEquals*/);
						if (result != null) {
							cjsExportAssignment = result;
							resultHasScopeMarker = true;
							resultHasExternalModuleIndicator = true;
						}
					}
				default:
			}
			final r = cjsExportAssignmentVisitor.VisitEachChild(expression); // recur through the whole tree, looking for module.exports=
			cleanupDiagnosticContext();
			return r;
		}
		return null;
	}

	function visitNestedExpression(expression:Node):Node {
		if (expression != null) {
			setupDiagnosticContext(expression);
			// PORT: defer on the success path only (docs/PORTING.md §4).
			switch (Ast.GetAssignmentDeclarationKind(expression)) {
				case JSDeclarationKindProperty:
					transformExpandoAssignment(expression.AsBinaryExpression());
				case JSDeclarationKindExportsProperty:
					if (state.currentSourceFile.CommonJSModuleIndicator != null) {
						final result = transformCommonJSExport(expression,
							getNameExpressionPreferringIdentifier(Ast.GetElementOrPropertyAccessName(expression.AsBinaryExpression().Left)));
						if (result != null) {
							if (cjsExportMembers == null) {
								cjsExportMembers = [];
							}
							cjsExportMembers.push(result);
						}
					}
				case JSDeclarationKindObjectDefinePropertyExports:
					if (state.currentSourceFile.CommonJSModuleIndicator != null) {
						final result = transformCommonJSExport(expression, getNameExpressionPreferringIdentifier(expression.Arguments()[1]));
						if (result != null) {
							if (cjsExportMembers == null) {
								cjsExportMembers = [];
							}
							cjsExportMembers.push(result);
						}
					}
				default:
			}
			final r = expressionVisitor.VisitEachChild(expression); // recur through the whole tree, looking for special assignments
			cleanupDiagnosticContext();
			return r;
		}
		return null;
	}

	function transformExpandoAssignment(node:BinaryExpression):Void {
		final left = node.Left;

		final symbol = node.Symbol;
		if (symbol == null || (symbol.Flags & SymbolFlagsAssignment) == 0) {
			return;
		}

		final ns = Ast.GetLeftmostAccessExpression(left);
		if (ns == null || ns.Kind != KindIdentifier) {
			return;
		}

		final declaration = resolver.GetReferencedValueDeclaration(ns);
		if (declaration == null) {
			return;
		}

		if (shouldStripInternal(declaration)) {
			return;
		}

		if (Ast.IsVariableDeclaration(declaration) && declaration.Type() != null) {
			return;
		}

		if (Ast.IsFunctionDeclaration(declaration) && declaration.FunctionLikeData().FullSignature != null) {
			return;
		}

		if (Ast.IsVariableDeclaration(declaration) && !Ast.IsFunctionLike(declaration.Initializer())) {
			return; // We're going to add a type, no need to dupe members with a namespace
		}

		final host = declaration.Symbol();
		if (host == null) {
			return;
		}

		final name = Factory().NewIdentifier(ns.Text());
		final property = tryGetPropertyName(left);
		if (property == "" || !Scanner.IsIdentifierText(property, LanguageVariantStandard)) {
			return;
		}

		if (Ast.IsDeclaration(declaration) && Declarations.isDeclarationAndNotVisible(EmitContext(), resolver, declaration)) {
			return;
		}

		if (Ast.IsFunctionDeclaration(declaration) && !Declarations.shouldEmitFunctionProperties(declaration.AsFunctionDeclaration())) {
			return;
		}

		transformExpandoHost(name, declaration);

		final exportName = Factory().NewIdentifier(property);
		var localName = tryGetNameOfAssignedExpression(node.AsNode());
		if (localName == null && !resolver.IsNameResolvable(enclosingDeclaration, property)
			&& !Ast.IsNonContextualKeyword(Scanner.StringToToken(exportName.Text()))) {
			// use exportName as localName if there won't be any conflicts or keyword issues
			localName = exportName;
		}
		if (localName == null || Ast.IsNonContextualKeyword(Scanner.StringToToken(localName.Text()))) {
			// fallback to a generated name if the localName doesn't exist or is a keyword
			localName = Factory().NewGeneratedNameForNode(node.AsNode());
		}

		final hostId = getExpandoHostId(declaration);
		setupDiagnosticContext(node.AsNode());
		// PORT: the Go defers (cleanupDiagnosticContext, later the enclosingDeclaration restore) run on the success path at each return (LIFO).

		if (Ast.IsIdentifier(node.Right)) {
			// alias-like, emit an `export {name}` or `export {name as alias}`
			final result = transformBinaryExpressionToExportDeclaration(node.AsNode(), exportName);
			var list = expandoMembers.get(hostId);
			if (list == null) {
				list = [];
				expandoMembers.set(hostId, list);
			}
			list.push(result);
			cleanupDiagnosticContext();
			return;
		}

		final preexistingExpandoHasExport = Core.Some(expandoMembers.get(hostId), Ast.IsExportDeclaration);
		var varModifiers:ModifierList = null;

		if (preexistingExpandoHasExport) {
			varModifiers = Factory().NewModifierList(Ast.CreateModifiersFromModifierFlags(ModifierFlagsExport, Factory().NewModifier));
		}

		final synthesizedNamespace = Factory().NewModuleDeclaration(null /*modifiers*/, KindNamespaceKeyword, name,
			Factory().NewModuleBlock(Factory().NewNodeList([])));
		synthesizedNamespace.Parent = enclosingDeclaration;
		final declarationData = synthesizedNamespace.DeclarationData();
		declarationData.Symbol = host;
		final containerData = synthesizedNamespace.LocalsContainerData();
		containerData.Locals = new SymbolTable();
		containerData.Locals.set(localName.Text(), symbol);

		final oldEnclosing = enclosingDeclaration;
		enclosingDeclaration = synthesizedNamespace;

		final statements:Array<Statement> = [
			Factory().NewVariableStatement(varModifiers,
				Factory().NewVariableDeclarationList(Factory().NewNodeList([
					Factory().NewVariableDeclaration(localName, null /*exclamationToken*/, ensureType(node.AsNode(), false), null /*initializer*/),
				]), NodeFlagsNone)),
		];

		if (localName.Text() != exportName.Text()) {
			final namedExports = Factory().NewNamedExports(Factory().NewNodeList([Factory().NewExportSpecifier(false /*isTypeOnly*/, localName, exportName),]));
			statements.push(Factory().NewExportDeclaration(null /*modifiers*/, false /*isTypeOnly*/, namedExports, null /*moduleSpecifier*/, null /*attributes*/));
		}

		if (statements.length > 1 && !preexistingExpandoHasExport) {
			// Add an `export` modifier to all existing expando members so they remain exported after the `export {}` is added
			final existing = expandoMembers.get(hostId);
			if (existing != null) {
				for (decl in existing) {
					final modifierFlags = ModifierFlagsExport | Ast.GetCombinedModifierFlags(decl);
					decl.AsMutable().SetModifiers(Factory().NewModifierList(Ast.CreateModifiersFromModifierFlags(modifierFlags, Factory().NewModifier)));
				}
			}
		}
		var list = expandoMembers.get(hostId);
		if (list == null) {
			list = [];
			expandoMembers.set(hostId, list);
		}
		for (s in statements) {
			list.push(s);
		}
		enclosingDeclaration = oldEnclosing;
		cleanupDiagnosticContext();
	}

	function getExpandoHostId(declaration:Declaration):NodeId {
		final root = Core.IfElse(Ast.IsVariableDeclaration(declaration), declaration.Parent.Parent, declaration);
		final id = Ast.GetNodeId(EmitContext().MostOriginal(root));
		return id;
	}

	function transformExpandoHost(name:Node, declaration:Declaration):Void {
		final root = Core.IfElse(Ast.IsVariableDeclaration(declaration), declaration.Parent.Parent, declaration);
		final id = getExpandoHostId(declaration);

		if (expandoHosts.exists(id)) {
			return;
		}

		final saveNeedsDeclare = needsDeclare;
		needsDeclare = true;

		var modifierFlags = ensureModifierFlags(root);
		final defaultExport = (modifierFlags & ModifierFlagsExport) != 0 && (modifierFlags & ModifierFlagsDefault) != 0;

		needsDeclare = saveNeedsDeclare;

		if (defaultExport) {
			modifierFlags = modifierFlags | ModifierFlagsAmbient;
			modifierFlags = modifierFlags ^ ModifierFlagsDefault;
			modifierFlags = modifierFlags ^ ModifierFlagsExport;
		}

		setupDiagnosticContext(declaration);
		// PORT: defer on the success path only (docs/PORTING.md §4): cleanupDiagnosticContext() at each return.

		final modifiers = Factory().NewModifierList(Ast.CreateModifiersFromModifierFlags(modifierFlags, Factory().NewModifier));
		final replacement:Array<Node> = [];

		if (Ast.IsFunctionDeclaration(declaration)) {
			final p = Declarations.extractExpandoHostParams(declaration);
			final typeParameters = p.a;
			final parameters = p.b;
			final asteriskToken = p.c;
			replacement.push(Factory().UpdateFunctionDeclaration(declaration.AsFunctionDeclaration(), modifiers, asteriskToken, declaration.Name(),
				ensureTypeParams(declaration, typeParameters), updateParamList(declaration, parameters), ensureType(declaration, false), null /*fullSignature*/,
				null /*body*/));
		} else if (Ast.IsVariableDeclaration(declaration) && Ast.IsFunctionExpressionOrArrowFunction(declaration.Initializer())) {
			final fn = declaration.Initializer();
			final p = Declarations.extractExpandoHostParams(fn);
			final typeParameters = p.a;
			final parameters = p.b;
			final asteriskToken = p.c;
			replacement.push(Factory().NewFunctionDeclaration(modifiers, asteriskToken, Factory().NewIdentifier(name.Text()), ensureTypeParams(fn, typeParameters),
				updateParamList(fn, parameters), ensureType(fn, false), null /*fullSignature*/, null /*body*/));
		} else {
			expandoHosts.set(id, transformTopLevelDeclaration(declaration));
			cleanupDiagnosticContext();
			return;
		}

		state.reportExpandoFunctionErrors(declaration);

		if (defaultExport) {
			if (Ast.IsSourceFile(declaration.Parent)) {
				resultHasExternalModuleIndicator = true;
			}
			resultHasScopeMarker = true;
			replacement.push(Factory().NewExportAssignment(null /*modifiers*/, false /*isExportEquals*/, null /*typeNode*/, name));
		}

		// store host result to be added to the output when it's actually visited
		expandoHosts.set(id, Factory().NewSyntaxList(replacement));
		if (lateStatementReplacementMap.exists(id)) {
			lateStatementReplacementMap.set(id, createFullExpandoBlock(id));
		}
		cleanupDiagnosticContext();
	}

	function createFullExpandoBlock(id:NodeId):Node {
		final n = expandoHosts.get(id);
		if (expandoMembers.exists(id)) {
			final addOns = expandoMembers.get(id);
			var modifiers:ModifierList = null;
			var name:Node = null;
			var host:Array<Node> = null;
			if (n != null && n.Kind == KindSyntaxList) {
				// find the first named syntax list element and use its' name & modifiers
				for (c in n.AsSyntaxList().AsNode().IterChildren()) {
					if (c.Name() != null) {
						name = c.Name().Clone(Factory());
						if (c.Modifiers() != null) {
							modifiers = c.Modifiers().Clone(Factory().AsNodeFactory());
						}
						break;
					}
				}
				host = n.AsSyntaxList().Children;
			} else if (n != null) {
				name = n.Name().Clone(Factory());
				if (n.Modifiers() != null) {
					modifiers = n.Modifiers().Clone(Factory().AsNodeFactory());
				}
				host = [n];
			}
			if (name != null) {
				final moduleDecl = Factory().NewModuleDeclaration(modifiers, KindNamespaceKeyword, name, Factory().NewModuleBlock(Factory().NewNodeList(addOns)));
				// PORT: Go append may write into the SyntaxList's backing array; copy.
				final members = host == null ? [] : host.copy();
				members.push(moduleDecl);
				return Factory().NewSyntaxList(members);
			}
		}
		return n;
	}

	function tryGetPropertyName(node:Node):std.String {
		if (Ast.IsElementAccessExpression(node)) {
			return resolver.GetElementAccessExpressionName(node.AsElementAccessExpression());
		}
		if (Ast.IsPropertyAccessExpression(node)) {
			return node.Name().Text();
		}
		return "";
	}
}
