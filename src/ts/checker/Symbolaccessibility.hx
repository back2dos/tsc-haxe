package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/symbolaccessibility.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.checker)
class AccessibleSymbolChainContext {
	var symbol:Symbol = null;
	var enclosingDeclaration:Node = null;
	var meaning:SymbolFlags = 0;
	var useOnlyExternalAliasing:Bool = false;
	var visitedSymbolTablesMap:IntMap<IntMap<Bool>> = null;

	public function new() {}
}

// symbolTableID uniquely identifies a symbol table by encoding its source.
// The high 3 bits encode the kind, and the remaining bits encode the
// NodeId or SymbolId of the source.
enum abstract SymbolTableID(Int) from Int to Int {
	@:op(A | B) static function or(a:SymbolTableID, b:SymbolTableID):SymbolTableID;
	@:op(A & B) static function and(a:SymbolTableID, b:SymbolTableID):SymbolTableID;
	@:op(~A) static function not(a:SymbolTableID):SymbolTableID;

	// PORT: 64-bit. Go encodes `kind << 61 | id` in a uint64; here `id << 3 | kind` (Checker.symbolTableIDOf).
	var stKindLocals = 0;
	var stKindExports = 1;
	var stKindMembers = 2;
	var stKindGlobals = 3;
	var stKindResolvedExports = 4; // resolved/derived exports from getExportsOfSymbol, distinct from raw sym.Exports
	// stKindMask extracts the kind bits from a symbolTableID.
	// PORT: Go's value is `(iota - 1) << stKindShift` = 4 << 61, i.e. only the top kind bit (an upstream quirk:
	// `tableId & stKindMask` is non-zero only for stKindResolvedExports). 4 reproduces exactly that here.
	var stKindMask = 4;
}

// Methods of symbolaccessibility.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Symbolaccessibility {
	// PORT: method values created once (PORTING.md §7a).
	static final fn_hasNonGlobalAugmentationExternalModuleSymbol:(Node) -> Bool = d -> Checker.hasNonGlobalAugmentationExternalModuleSymbol(d);
	static final fn_IsExternalModuleImportEqualsDeclaration:(Node) -> Bool = d -> Ast.IsExternalModuleImportEqualsDeclaration(d);
	static final fn_isNamespaceReexportDeclaration:(Node) -> Bool = d -> Checker.isNamespaceReexportDeclaration(d);

	// PORT: struct map key accessibleChainCacheKey{useOnlyExternalAliasing, location, meaning} encoded as a String
	// (location by checker-local identity number, 0 for nil).
	static function accessibleChainCacheKeyOf(c:Checker, useOnlyExternalAliasing:Bool, location:Node, meaning:SymbolFlags):std.String {
		return (useOnlyExternalAliasing ? "1" : "0") + ":" + Checker.identityKeyOf(c, location) + ":" + (meaning : Int);
	}

	// PORT: Go indexes a possibly-nil ast.SymbolTable (nil map lookup yields nil).
	static inline function symbolTableGet(t:SymbolTable, name:std.String):Symbol {
		return t == null ? null : t.get(name);
	}

	// PORT: Go `append(res, xs...)` on possibly-nil slices; `res` is owned by the caller.
	static function appendAll(res:Array<Symbol>, xs:Array<Symbol>):Array<Symbol> {
		if (xs == null || xs.length == 0) {
			return res;
		}
		if (res == null) {
			res = [];
		}
		for (x in xs) {
			res.push(x);
		}
		return res;
	}

	public static function IsTypeSymbolAccessible(c:Checker, typeSymbol:Symbol, enclosingDeclaration:Node):Bool {
		final access = c.isSymbolAccessibleWorker(typeSymbol, enclosingDeclaration, SymbolFlagsType /*shouldComputeAliasesToMakeVisible*/, false /*allowModules*/, true);
		return access.Accessibility == SymbolAccessibilityAccessible;
	}

	public static function IsValueSymbolAccessible(c:Checker, symbol:Symbol, enclosingDeclaration:Node):Bool {
		final access = c.isSymbolAccessibleWorker(symbol, enclosingDeclaration, SymbolFlagsValue /*shouldComputeAliasesToMakeVisible*/, false /*allowModules*/, true);
		return access.Accessibility == SymbolAccessibilityAccessible;
	}

	public static function IsSymbolAccessibleByFlags(c:Checker, symbol:Symbol, enclosingDeclaration:Node, flags:SymbolFlags):Bool {
		final access = c.isSymbolAccessibleWorker(symbol, enclosingDeclaration, flags /*shouldComputeAliasesToMakeVisible*/, false /*allowModules*/, false); // TODO: Strada bug? Why is this allowModules: false?
		return access.Accessibility == SymbolAccessibilityAccessible;
	}

	public static function IsAnySymbolAccessible(c:Checker, symbols:Array<Symbol>, enclosingDeclaration:Node, initialSymbol:Symbol, meaning:SymbolFlags, shouldComputeAliasesToMakeVisible:Bool, allowModules:Bool):SymbolAccessibilityResult {
		if (Core.len(symbols) == 0) {
			return null;
		}

		var hadAccessibleChain:Symbol = null;
		var earlyModuleBail = false;
		for (symbol in symbols) {
			// Symbol is accessible if it by itself is accessible
			final accessibleSymbolChain = c.getAccessibleSymbolChain(symbol, enclosingDeclaration, meaning /*useOnlyExternalAliasing*/, false);
			if (Core.len(accessibleSymbolChain) > 0) {
				hadAccessibleChain = symbol;
				// TODO: going through emit resolver here is weird. Relayer these APIs.
				final hasAccessibleDeclarations = c.GetEmitResolver().hasVisibleDeclarations(accessibleSymbolChain[0], shouldComputeAliasesToMakeVisible);
				if (hasAccessibleDeclarations != null) {
					return hasAccessibleDeclarations;
				}
			}
			if (allowModules) {
				if (Core.Some(symbol.Declarations, fn_hasNonGlobalAugmentationExternalModuleSymbol)) {
					if (shouldComputeAliasesToMakeVisible) {
						earlyModuleBail = true;
						// Generally speaking, we want to use the aliases that already exist to refer to a module, if present
						// In order to do so, we need to find those aliases in order to retain them in declaration emit; so
						// if we are in declaration emit, we cannot use the fast path for module visibility until we've exhausted
						// all other visibility options (in order to capture the possible aliases used to reference the module)
						continue;
					}
					// Any meaning of a module symbol is always accessible via an `import` type
					final r = new SymbolAccessibilityResult();
					r.Accessibility = SymbolAccessibilityAccessible;
					return r;
				}
			}

			// If we haven't got the accessible symbol, it doesn't mean the symbol is actually inaccessible.
			// It could be a qualified symbol and hence verify the path
			// e.g.:
			// module m {
			//     export class c {
			//     }
			// }
			// const x: typeof m.c
			// In the above example when we start with checking if typeof m.c symbol is accessible,
			// we are going to see if c can be accessed in scope directly.
			// But it can't, hence the accessible is going to be undefined, but that doesn't mean m.c is inaccessible
			// It is accessible if the parent m is accessible because then m.c can be accessed through qualification

			final containers = c.getContainersOfSymbol(symbol, enclosingDeclaration, meaning);
			var nextMeaning = meaning;
			if (initialSymbol == symbol) {
				nextMeaning = Checker.getQualifiedLeftMeaning(meaning);
			}
			final parentResult = c.IsAnySymbolAccessible(containers, enclosingDeclaration, initialSymbol, nextMeaning, shouldComputeAliasesToMakeVisible, allowModules);
			if (parentResult != null) {
				return parentResult;
			}
		}

		if (earlyModuleBail) {
			final r = new SymbolAccessibilityResult();
			r.Accessibility = SymbolAccessibilityAccessible;
			return r;
		}

		if (hadAccessibleChain != null) {
			var moduleName = "";
			if (hadAccessibleChain != initialSymbol) {
				moduleName = c.symbolToStringEx(hadAccessibleChain, enclosingDeclaration, SymbolFlagsNamespace, SymbolFormatFlagsAllowAnyNodeKind);
			}
			final r = new SymbolAccessibilityResult();
			r.Accessibility = SymbolAccessibilityNotAccessible;
			r.ErrorSymbolName = c.symbolToStringEx(initialSymbol, enclosingDeclaration, meaning, SymbolFormatFlagsAllowAnyNodeKind);
			r.ErrorModuleName = moduleName;
			return r;
		}
		return null;
	}

	static function getWithAlternativeContainers(c:Checker, container:Symbol, symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags):Array<Symbol> {
		final additionalContainers = Core.MapNonNil(container.Declarations, (d:Node) -> {
			return c.getFileSymbolIfFileSymbolExportEqualsContainer(d, container);
		});
		var reexportContainers:Array<Symbol> = null;
		if (enclosingDeclaration != null) {
			reexportContainers = c.getAlternativeContainingModules(symbol, enclosingDeclaration);
		}
		final objectLiteralContainer = c.getVariableDeclarationOfObjectLiteral(container, meaning);
		final leftMeaning = Checker.getQualifiedLeftMeaning(meaning);
		if (enclosingDeclaration != null
			&& (container.Flags & leftMeaning) != 0
			&& Core.len(c.getAccessibleSymbolChain(container, enclosingDeclaration, SymbolFlagsNamespace /*useOnlyExternalAliasing*/, false)) > 0) {
			// This order expresses a preference for the real container if it is in scope
			var res = appendAll(appendAll([container], additionalContainers), reexportContainers);
			if (objectLiteralContainer != null) {
				res.push(objectLiteralContainer);
			}
			return res;
		}
		// we potentially have a symbol which is a member of the instance side of something - look for a variable in scope with the container's type
		// which may be acting like a namespace (eg, `Symbol` acts like a namespace when looking up `Symbol.toStringTag`)
		var variableMatches:Array<Symbol> = null;
		if ((meaning == SymbolFlagsValue
			&& (container.Flags & leftMeaning) == 0)
			&& (container.Flags & SymbolFlagsType) != 0
			&& (c.getDeclaredTypeOfSymbol(container).flags & TypeFlagsObject) != 0) {
			c.someSymbolTableInScope(enclosingDeclaration, (t:SymbolTable, _:SymbolTableID, _:Bool, _:Bool, _:Node) -> {
				var found = false;
				if (t != null) {
					for (s in t) {
						if ((s.Flags & leftMeaning) != 0 && c.getTypeOfSymbol(s) == c.getDeclaredTypeOfSymbol(container)) {
							if (variableMatches == null) {
								variableMatches = [];
							}
							variableMatches.push(s);
							found = true;
						}
					}
				}
				return found;
			});
			c.sortSymbols(variableMatches);
		}

		var res:Array<Symbol> = null;
		res = appendAll(res, variableMatches);
		res = appendAll(res, additionalContainers);
		res = appendAll(res, [container]);
		if (objectLiteralContainer != null) {
			res.push(objectLiteralContainer);
		}
		res = appendAll(res, reexportContainers);
		return res;
	}

	static function getAlternativeContainingModules(c:Checker, symbol:Symbol, enclosingDeclaration:Node):Array<Symbol> {
		if (enclosingDeclaration == null) {
			return null;
		}
		final containingFile = Ast.GetSourceFileOfNode(enclosingDeclaration);
		final id = Ast.GetNodeId(containingFile.AsNode());
		final links = c.symbolContainerLinks.Get(symbol);
		if (links.extendedContainersByFile == null) {
			links.extendedContainersByFile = new IntMap<Array<Symbol>>();
		}
		final existing = links.extendedContainersByFile.get(id);
		if (existing != null) {
			return existing;
		}
		var results:Array<Symbol> = null;
		if (Core.len(containingFile.Imports()) > 0) {
			// Try to make an import using an import already in the enclosing file, if possible
			for (importRef in containingFile.Imports()) {
				if (Ast.NodeIsSynthesized(importRef)) {
					// Synthetic names can't be resolved by `resolveExternalModuleName` - they'll cause a debug assert if they error
					continue;
				}
				final resolvedModule = c.resolveExternalModuleName(enclosingDeclaration, importRef /*ignoreErrors*/, true);
				if (resolvedModule == null) {
					continue;
				}
				final ref = c.getAliasForSymbolInContainer(resolvedModule, symbol);
				if (ref == null) {
					continue;
				}
				if (results == null) {
					results = [];
				}
				results.push(resolvedModule);
			}
			if (Core.len(results) > 0) {
				links.extendedContainersByFile.set(id, results);
				return results;
			}
		}

		if (links.extendedContainers != null) {
			return links.extendedContainers;
		}
		// No results from files already being imported by this file - expand search (expensive, but not location-specific, so cached)
		final otherFiles = c.program.SourceFiles();
		for (file in otherFiles) {
			if (!Ast.IsExternalModule(file)) {
				continue;
			}
			final sym = c.getSymbolOfDeclaration(file.AsNode());
			final ref = c.getAliasForSymbolInContainer(sym, symbol);
			if (ref == null) {
				continue;
			}
			if (results == null) {
				results = [];
			}
			results.push(sym);
		}
		// PORT: pointer. Go stores `&results`, so a nil result is cached too; a non-null empty array stands for it here.
		links.extendedContainers = results == null ? [] : results;
		return results;
	}

	static function getVariableDeclarationOfObjectLiteral(c:Checker, symbol:Symbol, meaning:SymbolFlags):Symbol {
		// If we're trying to reference some object literal in, eg `var a = { x: 1 }`, the symbol for the literal, `__object`, is distinct
		// from the symbol of the declaration it is being assigned to. Since we can use the declaration to refer to the literal, however,
		// we'd like to make that connection here - potentially causing us to paint the declaration's visibility, and therefore the literal.
		if ((meaning & SymbolFlagsValue) == 0) {
			return null;
		}
		if (Core.len(symbol.Declarations) == 0) {
			return null;
		}
		final firstDecl = symbol.Declarations[0];
		if (firstDecl.Parent == null) {
			return null;
		}
		if (!Ast.IsVariableDeclaration(firstDecl.Parent)) {
			return null;
		}
		if (Ast.IsObjectLiteralExpression(firstDecl) && firstDecl == firstDecl.Parent.Initializer() || Ast.IsTypeLiteralNode(firstDecl) && firstDecl == firstDecl.Parent.Type()) {
			return c.getSymbolOfDeclaration(firstDecl.Parent);
		}
		return null;
	}

	static function getExternalModuleContainer(c:Checker, declaration:Node):Symbol {
		final node = Ast.FindAncestor(declaration, Checker.hasExternalModuleSymbol);
		if (node == null) {
			return null;
		}
		return c.getSymbolOfDeclaration(node);
	}

	static function getFileSymbolIfFileSymbolExportEqualsContainer(c:Checker, d:Node, container:Symbol):Symbol {
		final fileSymbol = c.getExternalModuleContainer(d);
		if (fileSymbol == null || fileSymbol.Exports == null) {
			return null;
		}
		final exported = fileSymbol.Exports.get(Ast.InternalSymbolNameExportEquals);
		if (exported == null) {
			return null;
		}
		if (c.getSymbolIfSameReference(exported, container) != null) {
			return fileSymbol;
		}
		return null;
	}

	/**
	* Attempts to find the symbol corresponding to the container a symbol is in - usually this
	* is just its' `.parent`, but for locals, this value is `undefined`
	 */
	static function getContainersOfSymbol(c:Checker, symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags):Array<Symbol> {
		final container = c.getParentOfSymbol(symbol);
		// Type parameters end up in the `members` lists but are not externally visible
		if (container != null && ((symbol.Flags & SymbolFlagsTypeParameter) == 0)) {
			return c.getWithAlternativeContainers(container, symbol, enclosingDeclaration, meaning);
		}
		var candidates:Array<Symbol> = null;
		if (symbol.Declarations != null) {
			for (d in symbol.Declarations) {
				if (!Ast.IsAmbientModule(d) && d.Parent != null) {
					// direct children of a module
					if (Checker.hasNonGlobalAugmentationExternalModuleSymbol(d.Parent)) {
						final sym = c.getSymbolOfDeclaration(d.Parent);
						if (sym != null && !Slices.Contains(candidates, sym)) {
							if (candidates == null) {
								candidates = [];
							}
							candidates.push(sym);
						}
						continue;
					}
					// export ='d member of an ambient module
					if (Ast.IsModuleBlock(d.Parent) && d.Parent.Parent != null && c.resolveExternalModuleSymbol(c.getSymbolOfDeclaration(d.Parent.Parent), false) == symbol) {
						final sym = c.getSymbolOfDeclaration(d.Parent.Parent);
						if (sym != null && !Slices.Contains(candidates, sym)) {
							if (candidates == null) {
								candidates = [];
							}
							candidates.push(sym);
						}
						continue;
					}
				}
				if (Ast.IsClassExpression(d) && Ast.IsBinaryExpression(d.Parent) && d.Parent.AsBinaryExpression().OperatorToken.Kind == KindEqualsToken && Ast.IsAccessExpression(d.Parent.AsBinaryExpression().Left) && Ast.IsEntityNameExpression(d.Parent.AsBinaryExpression().Left.Expression())) {
					if (Ast.IsModuleExportsAccessExpression(d.Parent.AsBinaryExpression().Left) || Ast.IsExportsIdentifier(d.Parent.AsBinaryExpression().Left.Expression())) {
						final sym = c.getSymbolOfDeclaration(Ast.GetSourceFileOfNode(d).AsNode());
						if (sym != null && !Slices.Contains(candidates, sym)) {
							if (candidates == null) {
								candidates = [];
							}
							candidates.push(sym);
						}
						continue;
					}
					c.checkExpressionCached(d.Parent.AsBinaryExpression().Left.Expression());
					final sym = c.symbolNodeLinks.Get(d.Parent.AsBinaryExpression().Left.Expression()).resolvedSymbol;
					if (sym != null && !Slices.Contains(candidates, sym)) {
						if (candidates == null) {
							candidates = [];
						}
						candidates.push(sym);
					}
					continue;
				}
			}
		}
		if (Core.len(candidates) == 0) {
			return null;
		}

		var bestContainers:Array<Symbol> = null;
		var alternativeContainers:Array<Symbol> = null;
		for (container in candidates) {
			if (c.getAliasForSymbolInContainer(container, symbol) == null) {
				continue;
			}
			final allAlts = c.getWithAlternativeContainers(container, symbol, enclosingDeclaration, meaning);
			if (Core.len(allAlts) == 0) {
				continue;
			}
			if (bestContainers == null) {
				bestContainers = [];
			}
			bestContainers.push(allAlts[0]);
			alternativeContainers = appendAll(alternativeContainers, allAlts.slice(1));
		}
		return appendAll(bestContainers, alternativeContainers);
	}

	static function getAliasForSymbolInContainer(c:Checker, container:Symbol, symbol:Symbol):Symbol {
		if (container == c.getParentOfSymbol(symbol)) {
			// fast path, `symbol` is either already the alias or isn't aliased
			return symbol;
		}
		// Check if container is a thing with an `export=` which points directly at `symbol`, and if so, return
		// the container itself as the alias for the symbol
		if (container.Exports != null) {
			final exportEquals = container.Exports.get(Ast.InternalSymbolNameExportEquals);
			if (exportEquals != null && c.getSymbolIfSameReference(exportEquals, symbol) != null) {
				return container;
			}
		}
		final exports = c.getExportsOfSymbol(container);
		final quick = symbolTableGet(exports, symbol.Name);
		if (quick != null && c.getSymbolIfSameReference(quick, symbol) != null) {
			return quick;
		}
		var candidates:Array<Symbol> = null;
		if (exports != null) {
			for (exported in exports) {
				if (c.getSymbolIfSameReference(exported, symbol) != null) {
					if (candidates == null) {
						candidates = [];
					}
					candidates.push(exported);
				}
			}
		}
		if (Core.len(candidates) > 0) {
			c.sortSymbols(candidates); // _must_ sort exports for stable results - symbol table is randomly iterated
			return candidates[0];
		}
		return null;
	}

	static function getAccessibleSymbolChain(c:Checker, symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags, useOnlyExternalAliasing:Bool):Array<Symbol> {
		final ctx = new AccessibleSymbolChainContext();
		ctx.symbol = symbol;
		ctx.enclosingDeclaration = enclosingDeclaration;
		ctx.meaning = meaning;
		ctx.useOnlyExternalAliasing = useOnlyExternalAliasing;
		ctx.visitedSymbolTablesMap = new IntMap<IntMap<Bool>>();
		return c.getAccessibleSymbolChainEx(ctx);
	}

	public static function GetAccessibleSymbolChain(c:Checker, symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags, useOnlyExternalAliasing:Bool):Array<Symbol> {
		return c.getAccessibleSymbolChain(symbol, enclosingDeclaration, meaning, useOnlyExternalAliasing);
	}

	static function getAccessibleSymbolChainEx(c:Checker, ctx:AccessibleSymbolChainContext):Array<Symbol> {
		if (ctx.symbol == null) {
			return null;
		}
		if (Checker.isPropertyOrMethodDeclarationSymbol(ctx.symbol)) {
			return null;
		}
		// Go from enclosingDeclaration to the first scope we check, so the cache is keyed off the scope and thus shared more
		var firstRelevantLocation:Node = null;
		c.someSymbolTableInScope(ctx.enclosingDeclaration, (_:SymbolTable, _:SymbolTableID, _:Bool, _:Bool, node:Node) -> {
			firstRelevantLocation = node;
			return true;
		});
		final links = c.symbolContainerLinks.Get(ctx.symbol);
		final linkKey = accessibleChainCacheKeyOf(c, ctx.useOnlyExternalAliasing, firstRelevantLocation, ctx.meaning);
		if (links.accessibleChainCache == null) {
			links.accessibleChainCache = new StringMap<Array<Symbol>>();
		}
		if (links.accessibleChainCache.exists(linkKey)) {
			return links.accessibleChainCache.get(linkKey);
		}

		var result:Array<Symbol> = null;

		c.someSymbolTableInScope(ctx.enclosingDeclaration, (t:SymbolTable, tableId:SymbolTableID, ignoreQualification:Bool, isLocalNameLookup:Bool, _:Node) -> {
			final res = c.getAccessibleSymbolChainFromSymbolTable(ctx, t, tableId, ignoreQualification, isLocalNameLookup);
			if (Core.len(res) > 0) {
				result = res;
				return true;
			}
			return false;
		});
		links.accessibleChainCache.set(linkKey, result);
		return result;
	}

	/**
	* @param {ignoreQualification} boolean Set when a symbol is being looked for through the exports of another symbol (meaning we have a route to qualify it already)
	 */
	static function getAccessibleSymbolChainFromSymbolTable(c:Checker, ctx:AccessibleSymbolChainContext, t:SymbolTable, tableId:SymbolTableID, ignoreQualification:Bool, isLocalNameLookup:Bool):Array<Symbol> {
		final symId = Ast.GetSymbolId(ctx.symbol);
		var visitedSymbolTables = ctx.visitedSymbolTablesMap.get(symId);
		if (visitedSymbolTables == null) {
			visitedSymbolTables = new IntMap<Bool>();
			ctx.visitedSymbolTablesMap.set(symId, visitedSymbolTables);
		}

		final present = visitedSymbolTables.exists(tableId);
		if (present) {
			return null;
		}
		visitedSymbolTables.set(tableId, true);

		final res = c.trySymbolTable(ctx, t, tableId, ignoreQualification, isLocalNameLookup);

		visitedSymbolTables.remove(tableId);
		return res;
	}

	// getSymbolTableAliases returns only the alias symbols from a symbol table,
	// caching the result by tableId to avoid repeated iteration over large tables.
	// Members tables are skipped entirely since someSymbolTableInScope filters them
	// to SymbolFlagsType & ^SymbolFlagsAssignment, which never includes aliases.
	static function getSymbolTableAliases(c:Checker, symbols:SymbolTable, tableId:SymbolTableID):Array<Symbol> {
		final kind:SymbolTableID = tableId & stKindMask;
		// Members tables never contain alias symbols; skip entirely.
		if (kind == stKindMembers) {
			return null;
		}
		// Cache globals and exports tables (which are large and revisited often).
		// Locals tables are small and per-scope, so they are filtered but not cached.
		if (kind == stKindGlobals || kind == stKindExports || kind == stKindResolvedExports) {
			if (c.symbolTableAliasCache != null) {
				if (c.symbolTableAliasCache.exists(tableId)) {
					return c.symbolTableAliasCache.get(tableId);
				}
			}
		}
		var aliases:Array<Symbol> = null;
		if (symbols != null) {
			for (sym in symbols) {
				if ((sym.Flags & SymbolFlagsAlias) != 0) {
					if (aliases == null) {
						aliases = [];
					}
					aliases.push(sym);
				}
			}
		}
		if (kind == stKindGlobals || kind == stKindExports || kind == stKindResolvedExports) {
			if (c.symbolTableAliasCache == null) {
				c.symbolTableAliasCache = new IntMap<Array<Symbol>>();
			}
			c.symbolTableAliasCache.set(tableId, aliases);
		}
		return aliases;
	}

	static function trySymbolTable(c:Checker, ctx:AccessibleSymbolChainContext, symbols:SymbolTable, tableId:SymbolTableID, ignoreQualification:Bool, isLocalNameLookup:Bool):Array<Symbol> {
		final isGlobals = tableId == stKindGlobals;
		// If symbol is directly available by its name in the symbol table
		final res = symbolTableGet(symbols, ctx.symbol.Name);
		if (res != null && c.isAccessible(ctx, res /*resolvedAliasSymbol*/, null, ignoreQualification)) {
			return [ctx.symbol];
		}

		var candidateChains:Array<Array<Symbol>> = null;

		// Check for ExportSymbol by direct name lookup rather than discovering it during
		// the alias iteration below (where it would never match, since only alias-flagged
		// symbols are iterated).
		if (res != null && res.ExportSymbol != null) {
			if (c.isAccessible(ctx, c.getMergedSymbol(res.ExportSymbol) /*resolvedAliasSymbol*/, null, ignoreQualification)) {
				if (candidateChains == null) {
					candidateChains = [];
				}
				candidateChains.push([ctx.symbol]);
			}
		}

		// Iterate only alias symbols from the table (cached per tableId).
		// This avoids iterating thousands of non-alias symbols in large tables like globals.
		final aliases = c.getSymbolTableAliases(symbols, tableId);
		if (aliases != null) {
			for (symbolFromSymbolTable in aliases) {
				// for every non-default, non-export= alias symbol in scope, check if it refers to or can chain to the target symbol
				if (symbolFromSymbolTable.Name != Ast.InternalSymbolNameExportEquals
					&& symbolFromSymbolTable.Name != Ast.InternalSymbolNameDefault
					&& !(Checker.isUMDExportSymbol(symbolFromSymbolTable) && ctx.enclosingDeclaration != null && Ast.IsExternalModule(Ast.GetSourceFileOfNode(ctx.enclosingDeclaration)))
					// If `!useOnlyExternalAliasing`, we can use any type of alias to get the name
					&& (!ctx.useOnlyExternalAliasing || Core.Some(symbolFromSymbolTable.Declarations, fn_IsExternalModuleImportEqualsDeclaration))
					// If we're looking up a local name to reference directly, omit namespace reexports, otherwise when we're trawling through an export list to make a dotted name, we can keep it
					&& (isLocalNameLookup && !Core.Some(symbolFromSymbolTable.Declarations, fn_isNamespaceReexportDeclaration) || !isLocalNameLookup)
					// While exports are generally considered to be in scope, export-specifier declared symbols are _not_
					// See similar comment in `resolveName` for details
					&& (ignoreQualification || Core.len(Checker.getDeclarationsOfKind(symbolFromSymbolTable, KindExportSpecifier)) == 0)) {
					final resolvedImportedSymbol = c.resolveAlias(symbolFromSymbolTable);
					final candidate = c.getCandidateListForSymbol(ctx, symbolFromSymbolTable, resolvedImportedSymbol, ignoreQualification);
					if (Core.len(candidate) > 0) {
						if (candidateChains == null) {
							candidateChains = [];
						}
						candidateChains.push(candidate);
					}
				}
			}
		}

		if (Core.len(candidateChains) > 0) {
			// pick first, shortest
			Slices.SortStableFunc(candidateChains, c.compareSymbolChains);
			return candidateChains[0];
		}

		// If there's no result and we're looking at the global symbol table, treat `globalThis` like an alias and try to lookup thru that
		if (isGlobals) {
			return c.getCandidateListForSymbol(ctx, c.globalThisSymbol, c.globalThisSymbol, ignoreQualification);
		}
		return null;
	}

	static function compareSymbolChainsWorker(c:Checker, a:Array<Symbol>, b:Array<Symbol>):Int {
		final chainLen = Core.len(a) - Core.len(b);
		if (chainLen != 0) {
			return chainLen;
		}

		var idx = 0;
		while (idx < Core.len(a)) {
			final comparison = c.compareSymbols(a[idx], b[idx]);
			if (comparison != 0) {
				return comparison;
			}
			idx++;
		}
		return 0;
	}

	static function getCandidateListForSymbol(c:Checker, ctx:AccessibleSymbolChainContext, symbolFromSymbolTable:Symbol, resolvedImportedSymbol:Symbol, ignoreQualification:Bool):Array<Symbol> {
		if (c.isAccessible(ctx, symbolFromSymbolTable, resolvedImportedSymbol, ignoreQualification)) {
			return [symbolFromSymbolTable];
		}

		// Look in the exported members, if we can find accessibleSymbolChain, symbol is accessible using this chain
		// but only if the symbolFromSymbolTable can be qualified
		final candidateTable = c.getExportsOfSymbol(resolvedImportedSymbol);
		if (candidateTable == null) {
			return null;
		}
		final candidateTableId = Checker.symbolTableIDFromResolvedExports(resolvedImportedSymbol);
		final accessibleSymbolsFromExports = c.getAccessibleSymbolChainFromSymbolTable(ctx, candidateTable, candidateTableId /*ignoreQualification*/, true, false);
		if (Core.len(accessibleSymbolsFromExports) == 0) {
			return null;
		}
		if (!c.canQualifySymbol(ctx, symbolFromSymbolTable, Checker.getQualifiedLeftMeaning(ctx.meaning))) {
			return null;
		}
		return appendAll([symbolFromSymbolTable], accessibleSymbolsFromExports);
	}

	static function isAccessible(c:Checker, ctx:AccessibleSymbolChainContext, symbolFromSymbolTable:Symbol, resolvedAliasSymbol:Symbol, ignoreQualification:Bool):Bool {
		var likeSymbols = false;
		if (ctx.symbol == resolvedAliasSymbol) {
			likeSymbols = true;
		}
		if (ctx.symbol == symbolFromSymbolTable) {
			likeSymbols = true;
		}
		final symbol = c.getMergedSymbol(ctx.symbol);
		if (symbol == c.getMergedSymbol(resolvedAliasSymbol)) {
			likeSymbols = true;
		}
		if (symbol == c.getMergedSymbol(symbolFromSymbolTable)) {
			likeSymbols = true;
		}
		if (!likeSymbols) {
			return false;
		}
		// if the symbolFromSymbolTable is not external module (it could be if it was determined as ambient external module and would be in globals table)
		// and if symbolFromSymbolTable or alias resolution matches the symbol,
		// check the symbol can be qualified, it is only then this symbol is accessible
		return !Core.Some(symbolFromSymbolTable.Declarations, fn_hasNonGlobalAugmentationExternalModuleSymbol)
			&& (ignoreQualification || c.canQualifySymbol(ctx, c.getMergedSymbol(symbolFromSymbolTable), ctx.meaning));
	}

	static function canQualifySymbol(c:Checker, ctx:AccessibleSymbolChainContext, symbolFromSymbolTable:Symbol, meaning:SymbolFlags):Bool {
		// If the symbol is equivalent and doesn't need further qualification, this symbol is accessible
		if (!c.needsQualification(symbolFromSymbolTable, ctx.enclosingDeclaration, meaning)) {
			return true;
		}
		// If symbol needs qualification, make sure that parent is accessible, if it is then this symbol is accessible too
		final parentCtx = new AccessibleSymbolChainContext();
		parentCtx.symbol = symbolFromSymbolTable.Parent;
		parentCtx.enclosingDeclaration = ctx.enclosingDeclaration;
		parentCtx.meaning = Checker.getQualifiedLeftMeaning(meaning);
		parentCtx.useOnlyExternalAliasing = ctx.useOnlyExternalAliasing;
		parentCtx.visitedSymbolTablesMap = ctx.visitedSymbolTablesMap;
		return Core.len(c.getAccessibleSymbolChainEx(parentCtx)) > 0;
	}

	static function needsQualification(c:Checker, symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags):Bool {
		var qualify = false;
		c.someSymbolTableInScope(enclosingDeclaration, (symbolTable:SymbolTable, _:SymbolTableID, _:Bool, _:Bool, _:Node) -> {
			// If symbol of this name is not available in the symbol table we are ok
			final res = symbolTableGet(symbolTable, symbol.Name);
			if (res == null) {
				return false;
			}
			var symbolFromSymbolTable = c.getMergedSymbol(res);
			if (symbolFromSymbolTable == null) {
				// Continue to the next symbol table
				return false;
			}
			// If the symbol with this name is present it should refer to the symbol
			if (symbolFromSymbolTable == symbol) {
				// No need to qualify
				return true;
			}

			// Qualify if the symbol from symbol table has same meaning as expected
			final shouldResolveAlias = (symbolFromSymbolTable.Flags & SymbolFlagsAlias) != 0 && Ast.GetDeclarationOfKind(symbolFromSymbolTable, KindExportSpecifier) == null;
			if (shouldResolveAlias) {
				symbolFromSymbolTable = c.resolveAlias(symbolFromSymbolTable);
			}
			var flags = symbolFromSymbolTable.Flags;
			if (shouldResolveAlias) {
				flags = c.getSymbolFlags(symbolFromSymbolTable);
			}
			if ((flags & meaning) != 0) {
				qualify = true;
				return true;
			}

			// Continue to the next symbol table
			return false;
		});

		return qualify;
	}

	static function someSymbolTableInScope(c:Checker, enclosingDeclaration:Node, callback:(symbolTable:SymbolTable, tableId:SymbolTableID, ignoreQualification:Bool, isLocalNameLookup:Bool, scopeNode:Node) -> Bool):Bool {
		var location = enclosingDeclaration;
		while (location != null) {
			// Locals of a source file are not in scope (because they get merged into the global symbol table)
			if (Checker.canHaveLocals(location) && location.Locals() != null && !Ast.IsGlobalSourceFile(location)) {
				if (callback(location.Locals(), Checker.symbolTableIDFromLocals(location.AsNode()), false, true, location)) {
					return true;
				}
			}
			switch (location.Kind) {
				case KindSourceFile | KindModuleDeclaration:
					// PORT: Go `break` out of the switch → if/else (PORTING.md §4).
					if (!(Ast.IsSourceFile(location) && !Ast.IsExternalOrCommonJSModule(location.AsSourceFile()))) {
						final sym = c.getSymbolOfDeclaration(Ast.GetReparsedNodeForNode(location));
						if (callback(sym.Exports, Checker.symbolTableIDFromExports(sym), false, true, location)) {
							return true;
						}
					}
				case KindClassDeclaration | KindClassExpression | KindInterfaceDeclaration:
					// Type parameters are bound into `members` lists so they can merge across declarations
					// This is troublesome, since in all other respects, they behave like locals :cries:
					// TODO: the below is shared with similar code in `resolveName` - in fact, rephrasing all this symbol
					// lookup logic in terms of `resolveName` would be nice
					// The below is used to lookup type parameters within a class or interface, as they are added to the class/interface locals
					// These can never be latebound, so the symbol's raw members are sufficient. `getMembersOfNode` cannot be used, as it would
					// trigger resolving late-bound names, which we may already be in the process of doing while we're here!
					var table:SymbolTable = null;
					final sym = c.getSymbolOfDeclaration(location);
					// TODO: Should this filtered table be cached in some way?
					if (sym.Members != null) {
						for (key => memberSymbol in sym.Members) {
							if ((memberSymbol.Flags & (SymbolFlagsType & ~SymbolFlagsAssignment)) != 0) {
								if (table == null) {
									table = new SymbolTable();
								}
								table.set(key, memberSymbol);
							}
						}
					}
					if (table != null && callback(table, Checker.symbolTableIDFromMembers(sym), false, false, location)) {
						return true;
					}
					// Class expression names (e.g., `B` in `class B {}`) are not stored in any
					// scope table — the binder uses bindAnonymousDeclaration. Expose the name
					// binding here so getAccessibleSymbolChain can resolve self-references.
					// This mirrors the special casing of class expression names in
					// (*NameResolver).Resolve; if class names are ever bound differently
					// (e.g., via class-local type aliases), both sites should be updated.
					if (Ast.IsClassExpression(location) && location.AsClassExpression().Name() != null) {
						final nameTable = c.getClassExpressionNameTable(location);
						if (nameTable != null && callback(nameTable, Checker.symbolTableIDFromLocals(location.AsNode()), false, true, location)) {
							return true;
						}
					}
				default:
			}
			location = location.Parent;
		}

		return callback(c.globals, Checker.symbolTableIDFromGlobals(), false, true, null);
	}

	// getClassExpressionNameTable returns a cached symbol table containing the class
	// expression's name binding. Class expression names are bound via
	// bindAnonymousDeclaration and aren't stored in any container's locals, so this
	// synthesized table lets someSymbolTableInScope expose them during accessibility checks.
	static function getClassExpressionNameTable(c:Checker, location:Node):SymbolTable {
		final nodeId = Ast.GetNodeId(location);
		if (c.classExpressionNameTables != null) {
			if (c.classExpressionNameTables.exists(nodeId)) {
				return c.classExpressionNameTables.get(nodeId);
			}
		}
		final classSymbol = c.getSymbolOfDeclaration(location);
		final nameText = location.AsClassExpression().Name().Text();
		if (nameText.length == 0 || classSymbol == null) {
			return null;
		}
		final table = new SymbolTable();
		table.set(nameText, classSymbol);
		if (c.classExpressionNameTables == null) {
			c.classExpressionNameTables = new IntMap<SymbolTable>();
		}
		c.classExpressionNameTables.set(nodeId, table);
		return table;
	}

	/**
	 * Check if the given symbol in given enclosing declaration is accessible and mark all associated alias to be visible if requested
	 *
	 * @param symbol a Symbol to check if accessible
	 * @param enclosingDeclaration a Node containing reference to the symbol
	 * @param meaning a SymbolFlags to check if such meaning of the symbol is accessible
	 * @param shouldComputeAliasToMakeVisible a boolean value to indicate whether to return aliases to be mark visible in case the symbol is accessible
	 */
	public static function IsSymbolAccessible(c:Checker, symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags, shouldComputeAliasesToMakeVisible:Bool):SymbolAccessibilityResult {
		return c.isSymbolAccessibleWorker(symbol, enclosingDeclaration, meaning, shouldComputeAliasesToMakeVisible, true /*allowModules*/);
	}

	static function isSymbolAccessibleWorker(c:Checker, symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags, shouldComputeAliasesToMakeVisible:Bool, allowModules:Bool):SymbolAccessibilityResult {
		if (symbol != null && enclosingDeclaration != null) {
			final result = c.IsAnySymbolAccessible([symbol], enclosingDeclaration, symbol, meaning, shouldComputeAliasesToMakeVisible, allowModules);
			if (result != null) {
				return result.copy();
			}

			// This could be a symbol that is not exported in the external module
			// or it could be a symbol from different external module that is not aliased and hence cannot be named
			final symbolExternalModule = Core.FirstNonNil(symbol.Declarations, (d:Node) -> c.getExternalModuleContainer(d));
			if (symbolExternalModule != null) {
				final enclosingExternalModule = c.getExternalModuleContainer(enclosingDeclaration);
				if (symbolExternalModule != enclosingExternalModule) {
					// name from different external module that is not visible
					final r = new SymbolAccessibilityResult();
					r.Accessibility = SymbolAccessibilityCannotBeNamed;
					r.ErrorSymbolName = c.symbolToStringEx(symbol, enclosingDeclaration, meaning, SymbolFormatFlagsAllowAnyNodeKind);
					r.ErrorModuleName = c.symbolToString(symbolExternalModule);
					r.ErrorNode = Ast.IsInJSFile(enclosingDeclaration) ? enclosingDeclaration : null;
					return r;
				}
			}

			// Just a local name that is not accessible
			final r = new SymbolAccessibilityResult();
			r.Accessibility = SymbolAccessibilityNotAccessible;
			r.ErrorSymbolName = c.symbolToStringEx(symbol, enclosingDeclaration, meaning, SymbolFormatFlagsAllowAnyNodeKind);
			return r;
		}

		final r = new SymbolAccessibilityResult();
		r.Accessibility = SymbolAccessibilityAccessible;
		return r;
	}
}
