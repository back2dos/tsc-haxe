package ts.binder;

// Port of referenceresolver.go (types and methods; NewReferenceResolver is in Binder.hx).

interface ReferenceResolver {
	function GetReferencedExportContainer(node:IdentifierNode, prefixLocals:Bool):Node;
	function GetReferencedImportDeclaration(node:IdentifierNode):Declaration;
	function GetReferencedValueDeclaration(node:IdentifierNode):Declaration;
	function GetReferencedValueDeclarations(node:IdentifierNode):Array<Declaration>;
	function GetElementAccessExpressionName(expression:ElementAccessExpression):std.String;
	function GetReferencedMemberValueDeclaration(node:Node):Declaration;
}

class ReferenceResolverHooks {
	public var ResolveName:(location:Node, name:std.String, meaning:SymbolFlags, nameNotFoundMessage:Message, isUse:Bool, excludeGlobals:Bool) -> Symbol = null;
	public var GetResolvedSymbol:(node:Node) -> Symbol = null;
	public var GetMergedSymbol:(symbol:Symbol) -> Symbol = null;
	public var GetParentOfSymbol:(symbol:Symbol) -> Symbol = null;
	public var GetSymbolOfDeclaration:(declaration:Declaration) -> Symbol = null;
	public var GetTypeOnlyAliasDeclaration:(symbol:Symbol, include:SymbolFlags) -> Declaration = null;
	public var GetExportSymbolOfValueSymbolIfExported:(symbol:Symbol) -> Symbol = null;
	// PORT: Go returns (string, bool) → ValueOk.
	public var GetElementAccessExpressionName:(expression:ElementAccessExpression) -> ValueOk<std.String> = null;

	public function new() {}
}

// PORT: unexported Go type `referenceResolver` clashes with the exported interface
// `ReferenceResolver` once capitalized → `ReferenceResolver_` (PORTING.md §1).
@:allow(ts.binder)
class ReferenceResolver_ implements ReferenceResolver {
	var resolver:NameResolver = null;
	var options:CompilerOptions = null;
	var hooks:ReferenceResolverHooks = new ReferenceResolverHooks();

	function new() {}

	function getResolvedSymbol(node:Node):Symbol {
		if (node != null) {
			if (hooks.GetResolvedSymbol != null) {
				return hooks.GetResolvedSymbol(node);
			}
		}
		return null;
	}

	function getMergedSymbol(symbol:Symbol):Symbol {
		if (symbol != null) {
			if (hooks.GetMergedSymbol != null) {
				return hooks.GetMergedSymbol(symbol);
			}
			return symbol;
		}
		return null;
	}

	function getParentOfSymbol(symbol:Symbol):Symbol {
		if (symbol != null) {
			if (hooks.GetParentOfSymbol != null) {
				return hooks.GetParentOfSymbol(symbol);
			}
			return symbol.Parent;
		}
		return null;
	}

	function getSymbolOfDeclaration(declaration:Declaration):Symbol {
		if (declaration != null) {
			if (hooks.GetSymbolOfDeclaration != null) {
				return hooks.GetSymbolOfDeclaration(declaration);
			}
			return declaration.Symbol();
		}
		return null;
	}

	function getReferencedValueSymbol(reference:IdentifierNode, startInDeclarationContainer:Bool):Symbol {
		final resolvedSymbol = getResolvedSymbol(reference);
		if (resolvedSymbol != null) {
			return resolvedSymbol;
		}

		var location = reference;
		if (startInDeclarationContainer && reference.Parent != null && Ast.IsDeclaration(reference.Parent) && reference.Parent.Name() == reference) {
			location = Ast.GetDeclarationContainer(reference.Parent);
		}

		if (hooks.ResolveName != null) {
			return hooks.ResolveName(location, reference.Text(), SymbolFlagsExportValue | SymbolFlagsValue | SymbolFlagsAlias, null /*nameNotFoundMessage*/,
				false /*isUse*/, false /*excludeGlobals*/);
		}

		if (resolver == null) {
			resolver = new NameResolver();
			resolver.CompilerOptions = options;
		}

		return resolver.Resolve(location, reference.Text(), SymbolFlagsExportValue | SymbolFlagsValue | SymbolFlagsAlias, null /*nameNotFoundMessage*/,
			false /*isUse*/, false /*excludeGlobals*/);
	}

	function isTypeOnlyAliasDeclaration(symbol:Symbol):Bool {
		if (symbol != null) {
			if (hooks.GetTypeOnlyAliasDeclaration != null) {
				return hooks.GetTypeOnlyAliasDeclaration(symbol, SymbolFlagsValue) != null;
			}

			var node = getDeclarationOfAliasSymbol(symbol);
			// PORT: Go `for node != nil { switch { ... continue }; break }` → loop with a flag.
			while (node != null) {
				var next = false;
				switch (node.Kind) {
					case KindImportEqualsDeclaration | KindExportDeclaration:
						return node.IsTypeOnly();
					case KindImportClause | KindImportSpecifier | KindExportSpecifier:
						if (node.IsTypeOnly()) {
							return true;
						}
						node = node.Parent;
						next = true;
					case KindNamedImports | KindNamedExports:
						node = node.Parent;
						next = true;
					default:
				}
				if (!next) {
					break;
				}
			}
		}
		return false;
	}

	function getDeclarationOfAliasSymbol(symbol:Symbol):Declaration {
		return Core.FindLast(symbol.Declarations, Ast.IsAliasSymbolDeclaration);
	}

	function getExportSymbolOfValueSymbolIfExported(symbol:Symbol):Symbol {
		if (symbol != null) {
			if (hooks.GetExportSymbolOfValueSymbolIfExported != null) {
				return hooks.GetExportSymbolOfValueSymbolIfExported(symbol);
			}
			if (symbol.Flags & SymbolFlagsExportValue != 0 && symbol.ExportSymbol != null) {
				symbol = symbol.ExportSymbol;
			}
			return getMergedSymbol(symbol);
		}
		return null;
	}

	public function GetReferencedExportContainer(node:IdentifierNode, prefixLocals:Bool):Node /*SourceFile|ModuleDeclaration|EnumDeclaration*/ {
		// When resolving the export for the name of a module or enum
		// declaration, we need to start resolution at the declaration's container.
		// Otherwise, we could incorrectly resolve the export as the
		// declaration if it contains an exported member with the same name.
		final startInDeclarationContainer = node.Parent != null
			&& (node.Parent.Kind == KindModuleDeclaration || node.Parent.Kind == KindEnumDeclaration)
			&& node == node.Parent.Name();
		var symbol = getReferencedValueSymbol(node, startInDeclarationContainer);
		if (symbol != null) {
			if (symbol.Flags & SymbolFlagsExportValue != 0) {
				// If we reference an exported entity within the same module declaration, then whether
				// we prefix depends on the kind of entity. SymbolFlags.ExportHasLocal encompasses all the
				// kinds that we do NOT prefix.
				final exportSymbol = getMergedSymbol(symbol.ExportSymbol);
				if (!prefixLocals && exportSymbol.Flags & SymbolFlagsExportHasLocal != 0 && exportSymbol.Flags & SymbolFlagsVariable == 0) {
					return null;
				}
				symbol = exportSymbol;
			}
			final parentSymbol = getParentOfSymbol(symbol);
			if (parentSymbol != null) {
				if (parentSymbol.Flags & SymbolFlagsValueModule != 0 && parentSymbol.ValueDeclaration != null && parentSymbol.ValueDeclaration.Kind == KindSourceFile) {
					final symbolFile = parentSymbol.ValueDeclaration.AsSourceFile();
					final referenceFile = Ast.GetSourceFileOfNode(node);
					// If `node` accesses an export and that export isn't in the same file, then symbol is a namespace export, so return nil.
					final symbolIsUmdExport = symbolFile != referenceFile;
					if (symbolIsUmdExport) {
						return null;
					}
					return symbolFile.AsNode();
				}
				final isMatchingContainer = function(n:Node):Bool {
					return (n.Kind == KindModuleDeclaration || n.Kind == KindEnumDeclaration) && getSymbolOfDeclaration(n) == parentSymbol;
				};
				return Ast.FindAncestor(node.Parent, isMatchingContainer);
			}
		}

		return null;
	}

	public function GetReferencedImportDeclaration(node:IdentifierNode):Declaration {
		final symbol = getReferencedValueSymbol(node, false /*startInDeclarationContainer*/);
		if (symbol != null) {
			// We should only get the declaration of an alias if there isn't a local value
			// declaration for the symbol
			if (Ast.IsNonLocalAlias(symbol, SymbolFlagsValue /*excludes*/) && !isTypeOnlyAliasDeclaration(symbol)) {
				return getDeclarationOfAliasSymbol(symbol);
			}
		}

		return null;
	}

	public function GetReferencedValueDeclaration(node:IdentifierNode):Declaration {
		final symbol = getReferencedValueSymbol(node, false /*startInDeclarationContainer*/);
		if (symbol != null) {
			return getExportSymbolOfValueSymbolIfExported(symbol).ValueDeclaration;
		}
		return null;
	}

	public function GetReferencedValueDeclarations(node:IdentifierNode):Array<Declaration> {
		var declarations:Array<Declaration> = null;
		var symbol = getReferencedValueSymbol(node, false /*startInDeclarationContainer*/);
		if (symbol != null) {
			symbol = getExportSymbolOfValueSymbolIfExported(symbol);
			if (symbol.Declarations != null) {
				for (declaration in symbol.Declarations) {
					switch (declaration.Kind) {
						case KindVariableDeclaration | KindParameter | KindBindingElement | KindPropertyDeclaration | KindPropertyAssignment |
							KindShorthandPropertyAssignment | KindEnumMember | KindObjectLiteralExpression | KindFunctionDeclaration | KindFunctionExpression |
							KindArrowFunction | KindClassDeclaration | KindClassExpression | KindEnumDeclaration | KindMethodDeclaration | KindGetAccessor |
							KindSetAccessor | KindModuleDeclaration:
							if (declarations == null) {
								declarations = [];
							}
							declarations.push(declaration);
						default:
					}
				}
			}
		}
		return declarations;
	}

	public function GetElementAccessExpressionName(expression:ElementAccessExpression):std.String {
		if (expression != null) {
			if (hooks.GetElementAccessExpressionName != null) {
				final r = hooks.GetElementAccessExpressionName(expression);
				if (r.ok) {
					return r.value;
				}
			}
		}
		return "";
	}

	public function GetReferencedMemberValueDeclaration(node:Node):Declaration {
		// member references are `this.something` or `this[something]`, so should always simply have a resolved symbol
		var s = getResolvedSymbol(node);
		if (s == null && node.Symbol() != null) {
			// might be a declaration instead of a ref, get the merged declaration symbol
			s = getMergedSymbol(node.Symbol());
		}
		if (s == null) {
			return null;
		}
		return getExportSymbolOfValueSymbolIfExported(s).ValueDeclaration;
	}
}
