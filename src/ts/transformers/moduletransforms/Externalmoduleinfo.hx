package ts.transformers.moduletransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/moduletransforms/externalmoduleinfo.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.moduletransforms)
class ExternalModuleInfo {
	var externalImports:Array<Declaration> = null; // ImportDeclaration | ImportEqualsDeclaration | ExportDeclaration. imports and reexports of other external modules
	var exportSpecifiers:MultiMap<std.String, ExportSpecifier> = new MultiMap<std.String, ExportSpecifier>(); // Maps local names to their associated export specifiers (excludes reexports)
	var exportedBindings:MultiMap<Declaration, ModuleExportName> = new MultiMap<Declaration, ModuleExportName>(); // Maps local declarations to their associated export aliases
	var exportedNames:Array<ModuleExportName> = null; // all exported names in the module, both local and re-exported, excluding the names of locally exported function declarations
	var exportedFunctions:OrderedSet<FunctionDeclarationNode> = new OrderedSet<FunctionDeclarationNode>(); // all of the top-level exported function declarations
	var exportEquals:ExportAssignment = null; // an export=/module.exports= declaration if one was present
	var hasExportStarsToExportValues:Bool = false; // whether this module contains export*

	public function new() {}
}

@:allow(ts.transformers.moduletransforms)
class ExternalModuleInfoCollector {
	// PORT: Go `range` over a possibly-nil slice (parser lists of zero elements have nil Nodes).
	static inline function rangeOf<T>(a:Null<Array<T>>):Array<T> {
		return a == null ? [] : a;
	}

	var sourceFile:SourceFile = null;
	var compilerOptions:CompilerOptions = null;
	var emitContext:EmitContext = null;
	var resolver:ReferenceResolver = null;
	var uniqueExports:Set<std.String> = new Set<std.String>();
	var hasExportDefault:Bool = false;
	var output:ExternalModuleInfo = null;

	public function new() {}

	function collect():ExternalModuleInfo {
		var hasImportStar = false;
		var hasImportDefault = false;
		for (node in rangeOf(sourceFile.Statements.Nodes)) {
			// Look through NotEmittedStatement to find elided export= declarations
			// (e.g., `declare export = x` is elided by the type eraser but must still be collected)
			if (Ast.IsNotEmittedStatement(node)) {
				final original = emitContext.MostOriginal(node);
				if (original != null && Ast.IsExportAssignment(original)) {
					final n = original.AsExportAssignment();
					if (n.IsExportEquals && output.exportEquals == null) {
						output.exportEquals = n;
					}
				}
				continue;
			}
			switch (node.Kind) {
				case KindImportDeclaration:
					// import "mod"
					// import x from "mod"
					// import * as x from "mod"
					// import { x, y } from "mod"
					final n = node.AsImportDeclaration();
					addExternalImport(node);
					if (!hasImportStar && Moduletransforms.getImportNeedsImportStarHelper(n)) {
						hasImportStar = true;
					}
					if (!hasImportDefault && Moduletransforms.getImportNeedsImportDefaultHelper(n)) {
						hasImportDefault = true;
					}

				case KindImportEqualsDeclaration:
					final n = node.AsImportEqualsDeclaration();
					if (Ast.IsExternalModuleReference(n.ModuleReference)) {
						// import x = require("mod")
						addExternalImport(node);
					}

				case KindExportDeclaration:
					final n = node.AsExportDeclaration();
					if (n.ModuleSpecifier != null) {
						// export * from "mod"
						// export * as ns from "mod"
						// export { x, y } from "mod"
						addExternalImport(node);
						if (n.ExportClause == null) {
							// export * from "mod"
							output.hasExportStarsToExportValues = true;
						} else if (Ast.IsNamedExports(n.ExportClause)) {
							// export { x, y } from "mod"
							addExportedNamesForExportDeclaration(n);
							if (!hasImportDefault) {
								hasImportDefault = Moduletransforms.containsDefaultReference(n.ExportClause);
							}
						} else {
							// export * as ns from "mod"
							final name = n.ExportClause.AsNamespaceExport().Name();
							final nameText = name.Text();
							if (addUniqueExport(nameText)) {
								addExportedBinding(node, name);
								addExportedName(name);
							}
							// we use the same helpers for `export * as ns` as we do for `import * as ns`
							hasImportStar = true;
						}
					} else {
						// export { x, y }
						addExportedNamesForExportDeclaration(node.AsExportDeclaration());
					}

				case KindExportAssignment:
					final n = node.AsExportAssignment();
					if (n.IsExportEquals && output.exportEquals == null) {
						// export = x
						output.exportEquals = n;
					}

				case KindVariableStatement:
					final n = node.AsVariableStatement();
					if (Ast.HasSyntacticModifier(node, ModifierFlagsExport)) {
						for (decl in rangeOf(n.DeclarationList.AsVariableDeclarationList().Declarations.Nodes)) {
							collectExportedVariableInfo(decl);
						}
					}

				case KindFunctionDeclaration:
					final n = node.AsFunctionDeclaration();
					if (Ast.HasSyntacticModifier(node, ModifierFlagsExport)) {
						addExportedFunctionDeclaration(n, null /*name*/, Ast.HasSyntacticModifier(node, ModifierFlagsDefault));
					}

				case KindClassDeclaration:
					final n = node.AsClassDeclaration();
					if (Ast.HasSyntacticModifier(node, ModifierFlagsExport)) {
						if (Ast.HasSyntacticModifier(node, ModifierFlagsDefault)) {
							// export default class { }
							if (!hasExportDefault) {
								var name = n.Name();
								if (name == null) {
									name = emitContext.Factory.NewGeneratedNameForNode(node);
								}
								addExportedBinding(node, name);
								hasExportDefault = true;
							}
						} else {
							// export class x { }
							final name = n.Name();
							if (name != null) {
								if (addUniqueExport(name.Text())) {
									addExportedBinding(node, name);
									addExportedName(name);
								}
							}
						}
					}
				default:
			}
		}

		return output;
	}

	function addUniqueExport(name:std.String):Bool {
		if (!uniqueExports.Has(name)) {
			uniqueExports.Add(name);
			return true;
		}
		return false;
	}

	function addExportedBinding(decl:Declaration, name:ModuleExportName):Void {
		output.exportedBindings.Add(emitContext.MostOriginal(decl), name);
	}

	function addExternalImport(node:Node /*ImportDeclaration | ImportEqualsDeclaration | ExportDeclaration*/):Void {
		if (output.externalImports == null)
			output.externalImports = [];
		output.externalImports.push(node);
	}

	function addExportedName(name:ModuleExportName):Void {
		if (output.exportedNames == null)
			output.exportedNames = [];
		output.exportedNames.push(name);
	}

	function addExportedNamesForExportDeclaration(node:ExportDeclaration):Void {
		for (specifier in rangeOf(node.ExportClause.Elements())) {
			final specifierNameText = specifier.Name().Text();
			if (addUniqueExport(specifierNameText)) {
				final name = specifier.PropertyNameOrName();
				if (name.Kind != KindStringLiteral) {
					if (node.ModuleSpecifier == null) {
						output.exportSpecifiers.Add(name.Text(), specifier.AsExportSpecifier());
					}

					var decl = resolver.GetReferencedImportDeclaration(emitContext.MostOriginal(name));
					if (decl == null) {
						decl = resolver.GetReferencedValueDeclaration(emitContext.MostOriginal(name));
					}
					if (decl != null) {
						if (decl.Kind == KindFunctionDeclaration) {
							uniqueExports.Delete(specifierNameText);
							addExportedFunctionDeclaration(decl.AsFunctionDeclaration(), specifier.Name(), Ast.ModuleExportNameIsDefault(specifier.Name()));
							continue;
						}
						addExportedBinding(decl, specifier.Name());
					}
				}

				addExportedName(specifier.Name());
			}
		}
	}

	function addExportedFunctionDeclaration(node:FunctionDeclaration, name:ModuleExportName, isDefault:Bool):Void {
		output.exportedFunctions.Add(emitContext.MostOriginal(node.AsNode()));
		if (isDefault) {
			// export default function() { }
			// function x() { } + export { x as default };
			if (!hasExportDefault) {
				if (name == null) {
					name = emitContext.Factory.NewGeneratedNameForNode(node.AsNode());
				}
				addExportedBinding(node.AsNode(), name);
				hasExportDefault = true;
			}
		} else {
			// export function x() { }
			// function x() { } + export { x }
			if (name == null) {
				name = node.Name();
			}
			final nameText = name.Text();
			if (addUniqueExport(nameText)) {
				addExportedBinding(node.AsNode(), name);
			}
		}
	}

	function collectExportedVariableInfo(decl:Node /*VariableDeclaration | BindingElement*/):Void {
		if (Ast.IsBindingPattern(decl.Name())) {
			for (element in rangeOf(decl.Name().Elements())) {
				final e = element.AsBindingElement();
				if (e.Name() != null) {
					collectExportedVariableInfo(element);
				}
			}
		} else if (!emitContext.HasAutoGenerateInfo(decl.Name())) {
			final text = decl.Name().Text();
			if (addUniqueExport(text)) {
				addExportedName(decl.Name());
				if (Transformers.IsLocalName(emitContext, decl.Name())) {
					addExportedBinding(decl, decl.Name());
				}
			}
		}
	}
}
