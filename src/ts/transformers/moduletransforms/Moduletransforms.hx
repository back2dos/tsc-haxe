package ts.transformers.moduletransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/moduletransforms/Moduletransforms.hx (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Package class: package-level funcs, vars and consts of internal/transformers/moduletransforms (all files).
@:allow(ts.transformers.moduletransforms)
class Moduletransforms {
	// PORT: Go `range` over a possibly-nil slice (parser lists of zero elements have nil Nodes).
	static inline function rangeOf<T>(a:Null<Array<T>>):Array<T> {
		return a == null ? [] : a;
	}


	// --- commonjsmodule.go ---

	public static function NewCommonJSModuleTransformer(opts:TransformOptions):Transformer {
		final compilerOptions = opts.CompilerOptions;
		final emitContext = opts.Context;
		final tx = new CommonJSModuleTransformer();
		tx.compilerOptions = compilerOptions;
		tx.resolver = opts.Resolver;
		tx.getEmitModuleFormatOfFile = opts.GetEmitModuleFormatOfFile;
		tx.topLevelVisitor = emitContext.NewNodeVisitor(tx.visitTopLevel);
		tx.topLevelNestedVisitor = emitContext.NewNodeVisitor(tx.visitTopLevelNested);
		tx.discardedValueVisitor = emitContext.NewNodeVisitor(tx.visitDiscardedValue);
		tx.assignmentPatternVisitor = emitContext.NewNodeVisitor(tx.visitAssignmentPattern);
		tx.languageVersion = compilerOptions.GetEmitScriptTarget();
		tx.moduleKind = compilerOptions.GetEmitModuleKind();
		return tx.Transformer.NewTransformer(tx.visit, emitContext);
	}

	// --- esmodule.go ---

	public static function NewESModuleTransformer(opts:TransformOptions):Transformer {
		final compilerOptions = opts.CompilerOptions;
		final tx = new ESModuleTransformer();
		tx.compilerOptions = compilerOptions;
		tx.resolver = opts.Resolver;
		tx.getEmitModuleFormatOfFile = opts.GetEmitModuleFormatOfFile;
		return tx.Transformer.NewTransformer(tx.visit, opts.Context);
	}

	// --- externalmoduleinfo.go ---

	static function collectExternalModuleInfo(sourceFile:SourceFile, compilerOptions:CompilerOptions, emitContext:EmitContext, resolver:ReferenceResolver):ExternalModuleInfo {
		final c = new ExternalModuleInfoCollector();
		c.sourceFile = sourceFile;
		c.compilerOptions = compilerOptions;
		c.emitContext = emitContext;
		c.resolver = resolver;
		c.output = new ExternalModuleInfo();
		return c.collect();
	}

	static inline final externalHelpersModuleNameText:std.String = "tslib";

	static function createExternalHelpersImportDeclarationIfNeeded(emitContext:EmitContext, sourceFile:SourceFile, compilerOptions:CompilerOptions, fileModuleKind:ModuleKind, hasExportStarsToExportValues:Bool, hasImportStar:Bool, hasImportDefault:Bool):Node {
		if (compilerOptions.ImportHelpers.IsTrue() && Ast.IsEffectiveExternalModule(sourceFile, compilerOptions)) {
			final moduleKind = compilerOptions.GetEmitModuleKind();
			final helpers = getImportedHelpers(emitContext, sourceFile);
			if (fileModuleKind == ModuleKindCommonJS || fileModuleKind == ModuleKindNone && moduleKind == ModuleKindCommonJS) {
				// When we emit to a non-ES module, generate a synthetic `import tslib = require("tslib")` to be further transformed.
				final externalHelpersModuleName = getOrCreateExternalHelpersModuleNameIfNeeded(emitContext, sourceFile, compilerOptions, helpers,
					hasExportStarsToExportValues, hasImportStar || hasImportDefault, fileModuleKind);
				if (externalHelpersModuleName != null) {
					final externalHelpersImportDeclaration = emitContext.Factory.NewImportEqualsDeclaration(null /*modifiers*/, false /*isTypeOnly*/,
						externalHelpersModuleName,
						emitContext.Factory.NewExternalModuleReference(emitContext.Factory.NewStringLiteral(externalHelpersModuleNameText, TokenFlagsNone)));
					emitContext.AddEmitFlags(externalHelpersImportDeclaration, EFCustomPrologue);
					return externalHelpersImportDeclaration;
				}
			} else {
				// When we emit as an ES module, generate an `import` declaration that uses named imports for helpers.
				// If we cannot determine the implied module kind under `module: preserve` we assume ESM.
				var helperNames:Array<std.String> = null;
				if (helpers != null)
					for (helper in helpers) {
						final importName = helper.ImportName;
						if (importName.length > 0) {
							helperNames = Core.AppendIfUnique(helperNames, importName);
						}
					}
				if (Core.len(helperNames) > 0) {
					Slices.SortFunc(helperNames, Stringutil.CompareStringsCaseSensitive);
					// Alias the imports if the names are used somewhere in the file.
					// NOTE: We don't need to care about global import collisions as this is a module.

					final importSpecifiers = Core.Map(helperNames, function(name:std.String):ImportSpecifierNode {
						if (Printer.IsFileLevelUniqueName(sourceFile, name, null /*hasGlobalName*/)) {
							return emitContext.Factory.NewImportSpecifier(false /*isTypeOnly*/, null /*propertyName*/, emitContext.Factory.NewIdentifier(name));
						} else {
							return emitContext.Factory.NewImportSpecifier(false /*isTypeOnly*/, emitContext.Factory.NewIdentifier(name),
								emitContext.Factory.NewUnscopedHelperName(name));
						}
					});
					final namedBindings = emitContext.Factory.NewNamedImports(emitContext.Factory.NewNodeList(importSpecifiers));
					final parseNode = emitContext.MostOriginal(sourceFile.AsNode());
					emitContext.AddEmitFlags(parseNode, EFExternalHelpers);

					final externalHelpersImportDeclaration = emitContext.Factory.NewImportDeclaration(null /*modifiers*/,
						emitContext.Factory.NewImportClause(KindUnknown /*phaseModifier*/, null /*name*/, namedBindings),
						emitContext.Factory.NewStringLiteral(externalHelpersModuleNameText, TokenFlagsNone), null /*attributes*/);

					emitContext.AddEmitFlags(externalHelpersImportDeclaration, EFCustomPrologue);
					return externalHelpersImportDeclaration;
				}
			}
		}
		return null;
	}

	static function getImportedHelpers(emitContext:EmitContext, sourceFile:SourceFile):Array<EmitHelper> {
		var helpers:Array<EmitHelper> = null;
		final all = emitContext.GetEmitHelpers(sourceFile.AsNode());
		if (all != null)
			for (helper in all) {
				if (!helper.Scoped) {
					if (helpers == null)
						helpers = [];
					helpers.push(helper);
				}
			}
		return helpers;
	}

	static function getOrCreateExternalHelpersModuleNameIfNeeded(emitContext:EmitContext, node:SourceFile, compilerOptions:CompilerOptions, helpers:Array<EmitHelper>, hasExportStarsToExportValues:Bool, hasImportStarOrImportDefault:Bool, fileModuleKind:ModuleKind):IdentifierNode {
		var externalHelpersModuleName = emitContext.GetExternalHelpersModuleName(node);
		if (externalHelpersModuleName != null) {
			return externalHelpersModuleName;
		}

		final create = Core.len(helpers) > 0 || (hasExportStarsToExportValues || hasImportStarOrImportDefault) && fileModuleKind < ModuleKindSystem;

		if (create) {
			externalHelpersModuleName = emitContext.Factory.NewUniqueName(externalHelpersModuleNameText);
			emitContext.SetExternalHelpersModuleName(node, externalHelpersModuleName);
		}

		return externalHelpersModuleName;
	}

	static function isNamedDefaultReference(e:Node):Bool {
		return Ast.ModuleExportNameIsDefault(e.PropertyNameOrName());
	}

	static function containsDefaultReference(node:Node):Bool {
		return node != null && (Ast.IsNamedImports(node) || Ast.IsNamedExports(node)) && Core.Some(node.Elements(), isNamedDefaultReference);
	}

	static function getExportNeedsImportStarHelper(node:ExportDeclaration):Bool {
		return Ast.GetNamespaceDeclarationNode(node.AsNode()) != null;
	}

	static function getImportNeedsImportStarHelper(node:ImportDeclaration):Bool {
		if (Ast.GetNamespaceDeclarationNode(node.AsNode()) != null) {
			return true;
		}
		if (node.ImportClause == null) {
			return false;
		}
		final bindings = node.ImportClause.AsImportClause().NamedBindings;
		if (bindings == null) {
			return false;
		}
		if (!Ast.IsNamedImports(bindings)) {
			return false;
		}
		final namedImports = bindings.AsNamedImports();
		var defaultRefCount = 0;
		for (binding in rangeOf(namedImports.Elements.Nodes)) {
			if (isNamedDefaultReference(binding)) {
				defaultRefCount++;
			}
		}
		// Import star is required if there's default named refs mixed with non-default refs, or if theres non-default refs and it has a default import
		return (defaultRefCount > 0 && defaultRefCount != Core.len(namedImports.Elements.Nodes))
			|| ((Core.len(namedImports.Elements.Nodes) - defaultRefCount) != 0 && Ast.IsDefaultImport(node.AsNode()));
	}

	static function getImportNeedsImportDefaultHelper(node:ImportDeclaration):Bool {
		// Import default is needed if there's a default import or a default ref and no other refs (meaning an import star helper wasn't requested)
		return !getImportNeedsImportStarHelper(node)
			&& (Ast.IsDefaultImport(node.AsNode())
				|| (node.ImportClause != null && Ast.IsNamedImports(node.ImportClause.AsImportClause().NamedBindings)
					&& containsDefaultReference(node.ImportClause.AsImportClause().NamedBindings)));
	}

	// --- impliedmodule.go ---

	public static function NewImpliedModuleTransformer(opts:TransformOptions):Transformer {
		final tx = new ImpliedModuleTransformer();
		tx.opts = opts;
		tx.resolver = opts.Resolver;
		tx.getEmitModuleFormatOfFile = opts.GetEmitModuleFormatOfFile;
		return tx.Transformer.NewTransformer(tx.visit, opts.Context);
	}

	// --- utilities.go ---

	static function isDeclarationNameOfEnumOrNamespace(emitContext:EmitContext, node:IdentifierNode):Bool {
		final original = emitContext.MostOriginal(node);
		if (original != null && original.Parent != null) {
			switch (original.Parent.Kind) {
				case KindEnumDeclaration, KindModuleDeclaration:
					return original == original.Parent.Name();
				default:
			}
		}
		return false;
	}

	static function rewriteModuleSpecifier(emitContext:EmitContext, node:Expression, compilerOptions:CompilerOptions):Expression {
		if (node == null || !Ast.IsStringLiteral(node) || !Core.ShouldRewriteModuleSpecifier(node.Text(), compilerOptions)) {
			return node;
		}
		final updatedText = Tspath.ChangeExtension(node.Text(), Outputpaths.GetOutputExtension(node.Text(), compilerOptions.Jsx));
		if (updatedText != node.Text()) {
			final updated = emitContext.Factory.NewStringLiteral(updatedText, node.AsStringLiteral().TokenFlags);
			emitContext.SetOriginal(updated, node);
			emitContext.AssignCommentAndSourceMapRanges(updated, node);
			return updated;
		}
		return node;
	}

	static function createEmptyImports(factory:ts.printer.Factory.NodeFactory):Statement {
		return factory.NewExportDeclaration(null /*modifiers*/, false /*isTypeOnly*/, factory.NewNamedExports(factory.NewNodeList(null)),
			null /*moduleSpecifier*/, null /*attributes*/);
	}

	// Get the name of a target module from an import/export declaration as should be written in the emitted output.
	// The emitted output name can be different from the input if:
	//  1. The module has a /// <amd-module name="<new name>" />
	//  2. --out or --outFile is used, making the name relative to the rootDir
	//     3- The containing SourceFile has an entry in renamedDependencies for the import as requested by some module loaders (e.g. System).
	//
	// Otherwise, a new StringLiteral node representing the module name will be returned.
	static function getExternalModuleNameLiteral(factory:ts.printer.Factory.NodeFactory, importNode:Node, sourceFile:SourceFile, host:Any, resolver:EmitResolver, compilerOptions:CompilerOptions):StringLiteralNode {
		final moduleName = Ast.GetExternalModuleName(importNode);
		if (moduleName != null && Ast.IsStringLiteral(moduleName)) {
			var name = tryGetModuleNameFromDeclaration(importNode, host, factory, resolver, compilerOptions);
			if (name == null) {
				name = tryRenameExternalModule(factory, moduleName, sourceFile);
			}
			if (name == null) { // !!! propagate token flags (will produce new diffs)
				name = factory.NewStringLiteral(moduleName.Text(), TokenFlagsNone);
			}
			return name;
		}
		return null;
	}

	// Get the name of a module as should be written in the emitted output.
	// The emitted output name can be different from the input if:
	//  1. The module has a /// <amd-module name="<new name>" />
	//  2. --out or --outFile is used, making the name relative to the rootDir
	//
	// Otherwise, a new StringLiteral node representing the module name will be returned.
	static function tryGetModuleNameFromFile(factory:ts.printer.Factory.NodeFactory, file:SourceFile, host:Any, options:CompilerOptions):StringLiteralNode {
		if (file == null) {
			return null;
		}
		// !!!
		// if file.moduleName {
		// 	return factory.createStringLiteral(file.moduleName)
		// }
		return null;
	}

	static function tryGetModuleNameFromDeclaration(declaration:Node, host:Any, factory:ts.printer.Factory.NodeFactory, resolver:EmitResolver, compilerOptions:CompilerOptions):StringLiteralNode {
		if (resolver == null) {
			return null;
		}
		return tryGetModuleNameFromFile(factory, resolver.GetExternalModuleFileFromDeclaration(declaration), host, compilerOptions);
	}

	// Resolves a local path to a path which is absolute to the base of the emit
	static function getExternalModuleNameFromPath(host:Any, fileName:std.String, referencePath:std.String):std.String {
		// !!!
		return "";
	}

	// Some bundlers (SystemJS builder) sometimes want to rename dependencies.
	// Here we check if alternative name was provided for a given moduleName and return it if possible.
	static function tryRenameExternalModule(factory:ts.printer.Factory.NodeFactory, moduleName:LiteralExpression, sourceFile:SourceFile):StringLiteralNode {
		// !!!
		return null;
	}

	static function isFileLevelReservedGeneratedIdentifier(emitContext:EmitContext, name:IdentifierNode):Bool {
		final info = emitContext.GetAutoGenerateInfo(name);
		return info != null && info.Flags.IsFileLevel() && info.Flags.IsOptimistic() && info.Flags.IsReservedInNestedScopes();
	}

	// A simple inlinable expression is an expression which can be copied into multiple locations
	// without risk of repeating any sideeffects and whose value could not possibly change between
	// any such locations
	static function isSimpleInlineableExpression(expression:Expression):Bool {
		return !Ast.IsIdentifier(expression) && Transformers.IsSimpleCopiableExpression(expression);
	}
}
