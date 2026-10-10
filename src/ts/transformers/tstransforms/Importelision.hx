package ts.transformers.tstransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/tstransforms/importelision.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.tstransforms)
class ImportElisionTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var compilerOptions:CompilerOptions = null;
	var currentSourceFile:SourceFile = null;
	var emitResolver:EmitResolver = null;

	public function new() {}

	// PORT: promoted methods of embedded transformers.Transformer
	inline function EmitContext():ts.printer.Emitcontext.EmitContext
		return Transformer.EmitContext();

	inline function Factory():ts.printer.Factory.NodeFactory
		return Transformer.Factory();

	inline function Visitor():NodeVisitor
		return Transformer.Visitor();

	function visit(node:Node):Node {
		if (Ast.IsSourceFile(node) && emitResolver != null) {
			emitResolver.MarkLinkedReferencesRecursively(EmitContext().MostOriginal(node).AsSourceFile());
		}

		switch (node.Kind) {
			case KindImportEqualsDeclaration:
				if (Ast.IsExternalModuleImportEqualsDeclaration(node)) {
					if (!shouldEmitAliasDeclaration(node)) {
						return null;
					}
				} else {
					if (!shouldEmitImportEqualsDeclaration(node.AsImportEqualsDeclaration())) {
						return null;
					}
				}
				return Visitor().VisitEachChild(node);
			case KindImportDeclaration:
				final n = node.AsImportDeclaration();
				// Do not elide a side-effect only import declaration.
				//  import "foo";
				if (n.ImportClause != null) {
					final importClause = Visitor().VisitNode(n.ImportClause);
					if (importClause == null) {
						return null;
					}
					return Factory().UpdateImportDeclaration(n, n.Modifiers(), importClause, n.ModuleSpecifier, Visitor().VisitNode(n.Attributes));
				}
				return Visitor().VisitEachChild(node);
			case KindImportClause:
				final n = node.AsImportClause();
				final name = Core.IfElse(shouldEmitAliasDeclaration(node), n.Name(), null);
				final namedBindings = Visitor().VisitNode(n.NamedBindings);
				if (name == null && namedBindings == null) {
					// all import bindings were elided
					return null;
				}
				return Factory().UpdateImportClause(n, n.PhaseModifier, name, namedBindings);
			case KindNamespaceImport:
				if (!shouldEmitAliasDeclaration(node)) {
					// elide unused imports
					return null;
				}
				return node;
			case KindNamedImports:
				final n = node.AsNamedImports();
				final elements = Visitor().VisitNodes(n.Elements);
				if (Core.len(elements.Nodes) == 0) {
					// all import specifiers were elided
					return null;
				}
				return Factory().UpdateNamedImports(n, elements);
			case KindImportSpecifier:
				if (!shouldEmitAliasDeclaration(node)) {
					// elide type-only or unused imports
					return null;
				}
				return node;
			case KindExportAssignment:
				if (!compilerOptions.VerbatimModuleSyntax.IsTrue() && !isValueAliasDeclaration(node)) {
					// elide unused import
					return null;
				}
				return Visitor().VisitEachChild(node);
			case KindExportDeclaration:
				final n = node.AsExportDeclaration();
				var exportClause:Node = null;
				if (n.ExportClause != null) {
					exportClause = Visitor().VisitNode(n.ExportClause);
					if (exportClause == null) {
						// all export bindings were elided
						return null;
					}
				}
				return Factory().UpdateExportDeclaration(n, null /*modifiers*/, false /*isTypeOnly*/, exportClause, Visitor().VisitNode(n.ModuleSpecifier),
					Visitor().VisitNode(n.Attributes));
			case KindNamedExports:
				final n = node.AsNamedExports();
				final elements = Visitor().VisitNodes(n.Elements);
				if (Core.len(elements.Nodes) == 0) {
					// all export specifiers were elided
					return null;
				}
				return Factory().UpdateNamedExports(n, elements);
			case KindExportSpecifier:
				if (!isValueAliasDeclaration(node)) {
					// elide unused export
					return null;
				}
				return node;
			case KindSourceFile:
				final savedCurrentSourceFile = currentSourceFile;
				currentSourceFile = node.AsSourceFile();
				node = Visitor().VisitEachChild(node);
				currentSourceFile = savedCurrentSourceFile;
				return node;
			case KindModuleDeclaration, KindModuleBlock:
				return Visitor().VisitEachChild(node);
			default:
				return node;
		}
	}

	function shouldEmitAliasDeclaration(node:Node):Bool {
		return Ast.IsInJSFile(node) || isReferencedAliasDeclaration(node);
	}

	function shouldEmitImportEqualsDeclaration(node:ImportEqualsDeclaration):Bool {
		// preserve old compiler's behavior: emit import declaration (even if we do not consider them referenced) when
		// - current file is not external module
		// - import declaration is top level and target is value imported by entity name
		return shouldEmitAliasDeclaration(node.AsNode())
			|| (!Ast.IsExternalModule(currentSourceFile) && isTopLevelValueImportEqualsWithEntityName(node.AsNode()));
	}

	function isReferencedAliasDeclaration(node:Node):Bool {
		node = EmitContext().ParseNode(node);
		return node == null || emitResolver.IsReferencedAliasDeclaration(node);
	}

	function isValueAliasDeclaration(node:Node):Bool {
		node = EmitContext().ParseNode(node);
		return node == null || emitResolver.IsValueAliasDeclaration(node);
	}

	function isTopLevelValueImportEqualsWithEntityName(node:Node):Bool {
		node = EmitContext().ParseNode(node);
		return node != null && emitResolver.IsTopLevelValueImportEqualsWithEntityName(node);
	}
}
