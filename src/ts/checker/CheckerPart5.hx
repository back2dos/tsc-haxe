package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/checker.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Part of checker.go, Go lines 15981-19955 (3975 lines): the Checker methods of this range as static extension
// (receiver first, PORTING.md §2; `using ts.checker.CheckerPart5` in import.hx). Inside class Checker call them as `this.m(...)`.
@:allow(ts.checker)
class CheckerPart5 {

	static function lateBindIndexSignature(c:Checker, parent:Symbol, earlySymbols:SymbolTable, lateSymbols:SymbolTable, decl:Node):Void {
		// First, late bind the index symbol itself, if needed
		var indexSymbol = lateSymbols.get(Ast.InternalSymbolNameIndex);
		if (indexSymbol == null) {
			final early = symbolTableGet(earlySymbols, Ast.InternalSymbolNameIndex);
			if (early == null) {
				indexSymbol = c.newSymbolEx(SymbolFlagsNone, Ast.InternalSymbolNameIndex, CheckFlagsLate);
			} else {
				indexSymbol = c.cloneSymbol(early);
				indexSymbol.CheckFlags |= CheckFlagsLate;
			}
			lateSymbols.set(Ast.InternalSymbolNameIndex, indexSymbol);
		}
		// Then just add the computed name as a late bound declaration
		// (note: unlike `addDeclarationToLateBoundSymbol` we do not set up a `.lateSymbol` on `decl`'s links,
		// since that would point at an index symbol and not a single property symbol, like most consumers would expect)
		if (Core.len(indexSymbol.Declarations) == 0 || (decl.Symbol().Flags & SymbolFlagsReplaceableByMethod) == 0) {
			indexSymbol.Declarations = appendDeclaration(indexSymbol.Declarations, decl);
		}
	}

	// Adds a declaration to a late-bound dynamic member. This performs the same function for
	// late-bound members that `addDeclarationToSymbol` in binder.ts performs for early-bound
	// members.
	static function addDeclarationToLateBoundSymbol(c:Checker, symbol:Symbol, member:Node, symbolFlags:SymbolFlags):Void {
		Debug.Assert((symbol.CheckFlags & CheckFlagsLate) != 0, "Expected a late-bound symbol.");
		c.lateBoundLinks.Get(member.Symbol()).lateSymbol = symbol;
		if (Core.len(symbol.Declarations) == 0 || (member.Symbol().Flags & SymbolFlagsReplaceableByMethod) == 0) {
			symbol.Flags |= symbolFlags;
			symbol.Declarations = appendDeclaration(symbol.Declarations, member);
		} else if ((symbol.Flags & SymbolFlagsReplaceableByMethod) != 0 && (member.Symbol().Flags & SymbolFlagsMethod) != 0) {
			// Remove all replacable-by-method members, along with their flags.
			symbol.Declarations = appendNode(Core.Filter(symbol.Declarations, fn_isNotReplacableByMethod), member);
			final oldFlags = symbol.Flags;
			symbol.Flags = SymbolFlagsNone;
			for (d in symbol.Declarations) {
				symbol.Flags |= d.Symbol().Flags;
			}
			if ((oldFlags & SymbolFlagsAccessor) != 0) {
				symbol.Flags |= SymbolFlagsAccessor;
			}
		}
		if ((symbolFlags & SymbolFlagsValue) != 0) {
			Binder.SetValueDeclaration(symbol, member);
		}
	}

	/**
	 * Gets a SymbolTable containing both the early- and late-bound members of a symbol.
	 *
	 * For a description of late-binding, see `lateBindMember`.
	 */
	static function getMembersOfSymbol(c:Checker, symbol:Symbol):SymbolTable {
		if ((symbol.Flags & SymbolFlagsLateBindingContainer) != 0) {
			return c.getResolvedMembersOrExportsOfSymbol(symbol, MembersOrExportsResolutionKindResolvedMembers);
		}
		return symbol.Members;
	}

	static function getExportsOfModule(c:Checker, moduleSymbol:Symbol):SymbolTable {
		final links = c.moduleSymbolLinks.Get(moduleSymbol);
		if (links.resolvedExports == null) {
			final r = c.getExportsOfModuleWorker(moduleSymbol);
			links.resolvedExports = r.a;
			links.typeOnlyExportStarMap = r.b;
		}
		return links.resolvedExports;
	}

	static function getExportsOfModuleWorker(c:Checker, moduleSymbol:Symbol):Pair<SymbolTable, StringMap<Node>> {
		var exports:SymbolTable = null;
		var typeOnlyExportStarMap:StringMap<Node> = null;
		var visitedSymbols:Array<Symbol> = null;
		final nonTypeOnlyNames = new Set<std.String>();
		// The ES6 spec permits export * declarations in a module to circularly reference the module itself. For example,
		// module 'a' can 'export * from "b"' and 'b' can 'export * from "a"' without error.
		var visit:(Symbol, Node, Bool) -> SymbolTable = null;
		visit = function(symbol:Symbol, exportStar:Node, isTypeOnly:Bool):SymbolTable {
			if (!isTypeOnly && symbol != null) {
				// Add non-type-only names before checking if we've visited this module,
				// because we might have visited it via an 'export type *', and visiting
				// again with 'export *' will override the type-onlyness of its exports.
				if (symbol.Exports != null) {
					for (name in symbol.Exports.keys()) {
						nonTypeOnlyNames.Add(name);
					}
				}
			}
			if (symbol == null || symbol.Exports == null || Slices.Contains(visitedSymbols, symbol)) {
				return null;
			}
			if (visitedSymbols == null) {
				visitedSymbols = [];
			}
			visitedSymbols.push(symbol);
			final symbols = symbol.Exports.copy();
			// All export * declarations are collected in an __export symbol by the binder
			final exportStars = symbol.Exports.get(Ast.InternalSymbolNameExportStar);
			if (exportStars != null) {
				final nestedSymbols = new SymbolTable();
				final lookupTable = new ExportCollisionTable();
				for (node in rangeOf(exportStars.Declarations)) {
					final resolvedModule = c.resolveExternalModuleName(node, node.ModuleSpecifier(), false /*ignoreErrors*/);
					final exportedSymbols = visit(resolvedModule, node, isTypeOnly || node.IsTypeOnly());
					c.extendExportSymbols(nestedSymbols, exportedSymbols, lookupTable, node);
				}
				for (id => s in lookupTable) {
					// It's not an error if the file with multiple `export *`s with duplicate names exports a member with that name itself
					if (id == Ast.InternalSymbolNameExportEquals || Core.len(s.exportsWithDuplicate) == 0 || symbols.get(id) != null) {
						continue;
					}
					for (node in s.exportsWithDuplicate) {
						c.addDiagnostic(Checker.createDiagnosticForNode(node,
							Diagnostics.Module_0_has_already_exported_a_member_named_1_Consider_explicitly_re_exporting_to_resolve_the_ambiguity, s.specifierText,
							id));
					}
				}
				c.extendExportSymbols(symbols, nestedSymbols, null, null);
			}
			if (exportStar != null && exportStar.IsTypeOnly()) {
				if (typeOnlyExportStarMap == null) {
					typeOnlyExportStarMap = new StringMap<Node>();
				}
				for (name in symbols.keys()) {
					typeOnlyExportStarMap.set(name, exportStar);
				}
			}
			return symbols;
		};
		var originalModule:Symbol = null;
		if (moduleSymbol != null) {
			if (c.resolveSymbolEx(symbolTableGet(moduleSymbol.Exports, Ast.InternalSymbolNameExportEquals), false /*dontResolveAlias*/) != null) {
				originalModule = moduleSymbol;
			}
		}
		// A module defined by an 'export=' consists of one export that needs to be resolved
		moduleSymbol = c.resolveExternalModuleSymbol(moduleSymbol, false /*dontResolveAlias*/);
		exports = visit(moduleSymbol, null, false);
		if (exports == null) {
			exports = new SymbolTable();
		}
		// A CommonJS module defined by an 'export=' might also export typedefs, stored on the original module
		if (originalModule != null && symbolTableLen(originalModule.Exports) > 1) {
			for (symbol in originalModule.Exports) {
				if (symbol.Name == Ast.InternalSymbolNameExportEquals || symbol.Name == Ast.InternalSymbolNameExportStar) {
					continue;
				}
				final flags = c.getSymbolFlags(symbol);
				if ((flags & (SymbolFlagsType | SymbolFlagsNamespace)) != 0 && (flags & SymbolFlagsValue) == 0 && exports.get(symbol.Name) == null) {
					exports.set(symbol.Name, symbol);
				}
			}
		}
		for (name in nonTypeOnlyNames.Keys().keys()) {
			if (typeOnlyExportStarMap != null) {
				typeOnlyExportStarMap.remove(name);
			}
		}
		return new Pair(exports, typeOnlyExportStarMap);
	}

	/**
	 * Extends one symbol table with another while collecting information on name collisions for error message generation into the `lookupTable` argument
	 * Not passing `lookupTable` and `exportNode` disables this collection, and just extends the tables
	 */
	static function extendExportSymbols(c:Checker, target:SymbolTable, source:SymbolTable, lookupTable:ExportCollisionTable, exportNode:Node):Void {
		if (source == null) {
			return;
		}
		for (id => sourceSymbol in source) {
			if (id == Ast.InternalSymbolNameDefault) {
				continue;
			}
			final targetSymbol = target.get(id);
			if (targetSymbol == null) {
				target.set(id, sourceSymbol);
				if (lookupTable != null && exportNode != null) {
					final collision = new ExportCollision();
					collision.specifierText = Scanner.GetTextOfNode(exportNode.ModuleSpecifier());
					lookupTable.set(id, collision);
				}
			} else if (lookupTable != null && exportNode != null && c.resolveSymbol(targetSymbol) != c.resolveSymbol(sourceSymbol)) {
				final s = lookupTable.get(id);
				s.exportsWithDuplicate = appendNode(s.exportsWithDuplicate, exportNode);
			}
		}
	}

	public static function ResolveAlias(c:Checker, symbol:Symbol):ValueOk<Symbol> {
		if (symbol == null) {
			return new ValueOk<Symbol>(null, false);
		}
		final resolved = c.resolveAlias(symbol);
		return new ValueOk(resolved, resolved != c.unknownSymbol);
	}

	// Resolve an alias symbol to the first target symbol in the resolution chain that includes some other
	// meaning. Pure aliases are eagerly resolved and any type-only markers are back-propagated to the original
	// symbol. The function panics if the argument is not a symbol with an alias meaning.
	static function resolveAlias(c:Checker, symbol:Symbol):Symbol {
		if ((symbol.Flags & SymbolFlagsAlias) == 0) {
			throw "Should only get alias here";
		}
		final links = c.aliasSymbolLinks.Get(symbol);
		if (links.aliasTarget == null) {
			if (!c.pushTypeResolution(entity(symbol), TypeSystemPropertyNameAliasTarget)) {
				return c.unknownSymbol;
			}
			final node = c.getDeclarationOfAliasSymbol(symbol);
			if (node == null) {
				throw "Unexpected nil in resolveAlias for symbol: " + c.symbolToString(symbol);
			}
			var target = c.getTargetOfAliasDeclaration(node);
			if (Ast.IsNonLocalAlias(target, SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace)) {
				// When the target is a pure alias, we transitively resolve and propagate any typeOnlyDeclaration
				target = c.resolveIndirectionAlias(symbol, target);
			}
			links.aliasTarget = Core.OrElse(target, c.unknownSymbol);
			if (!c.popTypeResolution()) {
				c.error(node, Diagnostics.Circular_definition_of_import_alias_0, c.symbolToString(symbol));
				links.aliasTarget = c.unknownSymbol;
			}
		}
		return links.aliasTarget;
	}

	static function resolveIndirectionAlias(c:Checker, source:Symbol, target:Symbol):Symbol {
		final result = c.getMergedSymbol(c.resolveAlias(target));
		final targetLinks = c.aliasSymbolLinks.Get(target);
		if (targetLinks.typeOnlyDeclaration != null) {
			final sourceLinks = c.aliasSymbolLinks.Get(source);
			if (sourceLinks.typeOnlyDeclaration == null) {
				sourceLinks.typeOnlyDeclaration = targetLinks.typeOnlyDeclaration;
			}
		}
		return result;
	}

	static function tryResolveAlias(c:Checker, symbol:Symbol):Symbol {
		final links = c.aliasSymbolLinks.Get(symbol);
		if (links.aliasTarget != null || c.findResolutionCycleStartIndex(entity(symbol), TypeSystemPropertyNameAliasTarget) < 0) {
			return c.resolveAlias(symbol);
		}
		return null;
	}

	static function resolveAliasWithDeprecationCheck(c:Checker, symbol:Symbol, location:Node):Symbol {
		if ((symbol.Flags & SymbolFlagsAlias) == 0 || c.isDeprecatedSymbol(symbol) || c.getDeclarationOfAliasSymbol(symbol) == null) {
			return symbol;
		}
		final targetSymbol = c.resolveAlias(symbol);
		if (targetSymbol == c.unknownSymbol) {
			return targetSymbol;
		}
		while ((symbol.Flags & SymbolFlagsAlias) != 0) {
			final target = c.getImmediateAliasedSymbol(symbol);
			if (target != null) {
				if (target == targetSymbol) {
					break;
				}
				if (Core.len(target.Declarations) != 0) {
					if (c.isDeprecatedSymbol(target)) {
						c.addDeprecatedSuggestion(location, target.Declarations, target.Name);
						break;
					} else {
						if (symbol == targetSymbol) {
							break;
						}
						symbol = target;
					}
				}
			} else {
				break;
			}
		}
		return targetSymbol;
	}

	/**
	 * Gets combined flags of a `symbol` and all alias targets it resolves to. `resolveAlias`
	 * is typically recursive over chains of aliases, but stops mid-chain if an alias is merged
	 * with another exported symbol, e.g.
	 * ```ts
	 * // a.ts
	 * export const a = 0;
	 * // b.ts
	 * export { a } from "./a";
	 * export type a = number;
	 * // c.ts
	 * import { a } from "./b";
	 * ```
	 * Calling `resolveAlias` on the `a` in c.ts would stop at the merged symbol exported
	 * from b.ts, even though there is still more alias to resolve. Consequently, if we were
	 * trying to determine if the `a` in c.ts has a value meaning, looking at the flags on
	 * the local symbol and on the symbol returned by `resolveAlias` is not enough.
	 * @returns SymbolFlags.All if `symbol` is an alias that ultimately resolves to `unknown`;
	 * combined flags of all alias targets otherwise.
	 */
	static function getSymbolFlags(c:Checker, symbol:Symbol):SymbolFlags {
		return c.getSymbolFlagsEx(symbol, false /*excludeTypeOnlyMeanings*/, false /*excludeLocalMeanings*/);
	}

	static function getSymbolFlagsEx(c:Checker, symbol:Symbol, excludeTypeOnlyMeanings:Bool, excludeLocalMeanings:Bool):SymbolFlags {
		final seenSymbols = new Set<Symbol>();
		var flags:SymbolFlags = SymbolFlagsNone;
		if (!excludeLocalMeanings) {
			flags = symbol.Flags;
		}
		while ((symbol.Flags & SymbolFlagsAlias) != 0) {
			if (excludeTypeOnlyMeanings && c.getTypeOnlyAliasDeclaration(symbol) != null) {
				break;
			}
			final target = c.getExportSymbolOfValueSymbolIfExported(c.resolveAlias(symbol));
			if (target == c.unknownSymbol) {
				return SymbolFlagsAll;
			}
			if ((target.Flags & SymbolFlagsAlias) != 0) {
				// Optimization - try to avoid creating or adding to `seenSymbols` if possible
				if (target == symbol || seenSymbols.Has(target)) {
					break;
				}
				if (seenSymbols.Len() == 0) {
					seenSymbols.Add(symbol);
				}
				seenSymbols.Add(target);
			}
			flags |= target.Flags;
			symbol = target;
		}
		return flags;
	}

	static function getDeclarationOfAliasSymbol(c:Checker, symbol:Symbol):Node {
		return Core.FindLast(symbol.Declarations, fn_IsAliasSymbolDeclaration);
	}

	static function getTypeOfSymbolWithDeferredType(c:Checker, symbol:Symbol):Type {
		final links = c.valueSymbolLinks.Get(symbol);
		if (links.resolvedType == null) {
			final deferred = c.deferredSymbolLinks.Get(symbol);
			if ((deferred.parent.flags & TypeFlagsUnion) != 0) {
				links.resolvedType = c.getUnionType(deferred.constituents);
			} else {
				links.resolvedType = c.getIntersectionType(deferred.constituents);
			}
		}
		return links.resolvedType;
	}

	static function getWriteTypeOfSymbolWithDeferredType(c:Checker, symbol:Symbol):Type {
		final links = c.valueSymbolLinks.Get(symbol);
		if (links.writeType == null) {
			final deferred = c.deferredSymbolLinks.Get(symbol);
			if (Core.len(deferred.writeConstituents) != 0) {
				if ((deferred.parent.flags & TypeFlagsUnion) != 0) {
					links.writeType = c.getUnionType(deferred.writeConstituents);
				} else {
					links.writeType = c.getIntersectionType(deferred.writeConstituents);
				}
			} else {
				links.writeType = c.getTypeOfSymbolWithDeferredType(symbol);
			}
		}
		return links.writeType;
	}

	// Distinct write types come only from set accessors, but synthetic union and intersection
	// properties deriving from set accessors will either pre-compute or defer the union or
	// intersection of the writeTypes of their constituents.
	static function getWriteTypeOfSymbol(c:Checker, symbol:Symbol):Type {
		if ((symbol.CheckFlags & CheckFlagsSyntheticProperty) != 0) {
			if ((symbol.CheckFlags & CheckFlagsDeferredType) != 0) {
				return c.getWriteTypeOfSymbolWithDeferredType(symbol);
			}
			final links = c.valueSymbolLinks.Get(symbol);
			return Core.OrElse(links.writeType, links.resolvedType);
		}
		if ((symbol.Flags & SymbolFlagsProperty) != 0) {
			return c.removeMissingType(c.getTypeOfSymbol(symbol), (symbol.Flags & SymbolFlagsOptional) != 0);
		}
		if ((symbol.Flags & SymbolFlagsAccessor) != 0) {
			if ((symbol.CheckFlags & CheckFlagsInstantiated) != 0) {
				return c.getWriteTypeOfInstantiatedSymbol(symbol);
			}
			return c.getWriteTypeOfAccessors(symbol);
		}
		return c.getTypeOfSymbol(symbol);
	}

	public static function GetTypeOfSymbolAtLocation(c:Checker, symbol:Symbol, location:Node):Type {
		symbol = c.getExportSymbolOfValueSymbolIfExported(symbol);
		if (location != null) {
			// If we have an identifier or a property access at the given location, if the location is
			// an dotted name expression, and if the location is not an assignment target, obtain the type
			// of the expression (which will reflect control flow analysis). If the expression indeed
			// resolved to the given symbol, return the narrowed type.
			if ((Ast.IsIdentifier(location) || Ast.IsPrivateIdentifier(location))
				&& !(Ast.IsJsxTagName(location) || Ast.IsJsxAttribute(location.Parent) || Ast.IsJsxNamespacedName(location.Parent))) {
				if (Ast.IsRightSideOfQualifiedNameOrPropertyAccess(location)) {
					location = location.Parent;
				}
				if (Ast.IsExpressionNode(location) && (!Ast.IsAssignmentTarget(location) || Ast.IsWriteAccess(location))) {
					var t:Type = null;
					if (Ast.IsWriteAccess(location) && location.Kind == KindPropertyAccessExpression) {
						t = c.checkPropertyAccessExpression(location, CheckModeNormal, true /*writeOnly*/);
					} else {
						t = c.getTypeOfExpression(location);
					}
					if (c.getExportSymbolOfValueSymbolIfExported(c.symbolNodeLinks.Get(location).resolvedSymbol) == symbol) {
						return c.removeOptionalTypeMarker(t);
					}
				}
			}
			if (Ast.IsDeclarationName(location) && Ast.IsSetAccessorDeclaration(location.Parent) && c.getAnnotatedAccessorTypeNode(location.Parent) != null) {
				return c.getWriteTypeOfAccessors(location.Parent.Symbol());
			}
			// The location isn't a reference to the given symbol, meaning we're being asked
			// a hypothetical question of what type the symbol would have if there was a reference
			// to it at the given location. Since we have no control flow information for the
			// hypothetical reference (control flow information is created and attached by the
			// binder), we simply return the declared type of the symbol.
			if (Checker.isRightSideOfAccessExpression(location) && Ast.IsWriteAccess(location.Parent)) {
				return c.getWriteTypeOfSymbol(symbol);
			}
		}
		return c.getNonMissingTypeOfSymbol(symbol);
	}

	static function getTypeOfSymbol(c:Checker, symbol:Symbol):Type {
		if ((symbol.CheckFlags & CheckFlagsDeferredType) != 0) {
			return c.getTypeOfSymbolWithDeferredType(symbol);
		}
		if ((symbol.CheckFlags & CheckFlagsInstantiated) != 0) {
			return c.getTypeOfInstantiatedSymbol(symbol);
		}
		if ((symbol.CheckFlags & CheckFlagsMapped) != 0) {
			return c.getTypeOfMappedSymbol(symbol);
		}
		if ((symbol.CheckFlags & CheckFlagsReverseMapped) != 0) {
			return c.getTypeOfReverseMappedSymbol(symbol);
		}
		if ((symbol.Flags & SymbolFlagsAccessor) != 0) {
			return c.getTypeOfAccessors(symbol);
		}
		if ((symbol.Flags & (SymbolFlagsVariable | SymbolFlagsProperty)) != 0) {
			return c.getTypeOfVariableOrParameterOrProperty(symbol);
		}
		if ((symbol.Flags & (SymbolFlagsFunction | SymbolFlagsMethod | SymbolFlagsClass | SymbolFlagsEnum | SymbolFlagsValueModule)) != 0) {
			return c.getTypeOfFuncClassEnumModule(symbol);
		}
		if ((symbol.Flags & SymbolFlagsEnumMember) != 0) {
			return c.getTypeOfEnumMember(symbol);
		}
		if ((symbol.Flags & SymbolFlagsAlias) != 0) {
			return c.getTypeOfAlias(symbol);
		}
		return c.errorType;
	}

	static function getNonMissingTypeOfSymbol(c:Checker, symbol:Symbol):Type {
		return c.removeMissingType(c.getTypeOfSymbol(symbol), (symbol.Flags & SymbolFlagsOptional) != 0);
	}

	static function getTypeOfInstantiatedSymbol(c:Checker, symbol:Symbol):Type {
		final links = c.valueSymbolLinks.Get(symbol);
		if (links.resolvedType == null) {
			links.resolvedType = c.instantiateType(c.getTypeOfSymbol(links.target), links.mapper);
		}
		return links.resolvedType;
	}

	static function getWriteTypeOfInstantiatedSymbol(c:Checker, symbol:Symbol):Type {
		final links = c.valueSymbolLinks.Get(symbol);
		if (links.writeType == null) {
			links.writeType = c.instantiateType(c.getWriteTypeOfSymbol(links.target), links.mapper);
		}
		return links.writeType;
	}

	static function getTypeOfVariableOrParameterOrProperty(c:Checker, symbol:Symbol):Type {
		final links = c.valueSymbolLinks.Get(symbol);
		if (links.resolvedType == null) {
			final t = c.getTypeOfVariableOrParameterOrPropertyWorker(symbol);
			if (t == null) {
				throw "Unexpected nil type";
			}
			// For a contextually typed parameter it is possible that a type has already
			// been assigned (in assignTypeToParameterAndFixTypeParameters), and we want
			// to preserve this type. In fact, we need to _prefer_ that type, but it won't
			// be assigned until contextual typing is complete, so we need to defer in
			// cases where contextual typing may take place.
			if (links.resolvedType == null && !c.isParameterOfContextSensitiveSignature(symbol)) {
				links.resolvedType = t;
			}
			return t;
		}
		return links.resolvedType;
	}

	static function isParameterOfContextSensitiveSignature(c:Checker, symbol:Symbol):Bool {
		var decl = symbol.ValueDeclaration;
		if (decl == null) {
			return false;
		}
		if (Ast.IsBindingElement(decl)) {
			decl = Ast.WalkUpBindingElementsAndPatterns(decl);
		}
		if (Ast.IsParameterDeclaration(decl)) {
			return c.isContextSensitiveFunctionOrObjectLiteralMethod(decl.Parent);
		}
		return false;
	}

	static function getTypeOfVariableOrParameterOrPropertyWorker(c:Checker, symbol:Symbol):Type {
		// Handle prototype property
		if ((symbol.Flags & SymbolFlagsPrototype) != 0) {
			return c.getTypeOfPrototypeProperty(symbol);
		}
		// CommonsJS require and module both have type any.
		if (symbol == c.requireSymbol) {
			return c.anyType;
		}
		Debug.Assert(symbol.ValueDeclaration != null);
		final declaration = symbol.ValueDeclaration;
		if (Ast.IsSourceFile(declaration) && Ast.IsJsonSourceFile(declaration.AsSourceFile())) {
			final statements = declaration.Statements();
			if (Core.len(statements) == 0) {
				return c.emptyObjectType;
			}
			return c.getWidenedType(c.getWidenedLiteralType(c.checkExpression(statements[0].Expression())));
		}
		// Handle variable, parameter or property
		if (!c.pushTypeResolution(entity(symbol), TypeSystemPropertyNameType)) {
			return c.reportCircularityError(symbol);
		}
		if ((symbol.Flags & SymbolFlagsModuleExports) != 0) {
			if (symbol.Name == "exports") {
				return c.getTypeOfSymbol(c.resolveExternalModuleSymbol(symbol.ValueDeclaration.Symbol(), false /*dontResolveAlias*/));
			}
			return c.newAnonymousType(symbol, symbol.Members, null, null, null);
		}
		var result:Type = null;
		switch (declaration.Kind) {
			case KindParameter | KindPropertyDeclaration | KindPropertySignature | KindVariableDeclaration | KindBindingElement:
				result = c.getWidenedTypeForVariableLikeDeclaration(declaration, true /*reportErrors*/);
			case KindPropertyAssignment:
				result = c.checkPropertyAssignment(declaration, CheckModeNormal);
			case KindShorthandPropertyAssignment:
				result = c.checkShorthandPropertyAssignment(declaration, true /*inDestructuringPattern*/, CheckModeNormal);
			case KindMethodDeclaration:
				result = c.checkObjectLiteralMethod(declaration, CheckModeNormal);
			case KindExportAssignment:
				if (declaration.Type() != null) {
					result = c.getTypeFromTypeNode(declaration.Type());
				} else {
					result = c.widenTypeForVariableLikeDeclaration(c.checkExpressionCached(declaration.Expression()), declaration, false /*reportErrors*/);
				}
			case KindBinaryExpression | KindCallExpression:
				result = c.getWidenedTypeForAssignmentDeclaration(symbol);
			case KindJsxAttribute:
				result = c.checkJsxAttribute(declaration, CheckModeNormal);
			case KindEnumMember:
				result = c.getTypeOfEnumMember(symbol);
			default:
				throw "Unhandled case in getTypeOfVariableOrParameterOrPropertyWorker: " + declaration.Kind.String();
		}
		if (!c.popTypeResolution()) {
			return c.reportCircularityError(symbol);
		}
		return result;
	}

	// Return the type associated with a variable, parameter, or property declaration. In the simple case this is the type
	// specified in a type annotation or inferred from an initializer. However, in the case of a destructuring declaration it
	// is a bit more involved. For example:
	//
	//	var [x, s = ""] = [1, "one"];
	//
	// Here, the array literal [1, "one"] is contextually typed by the type [any, string], which is the implied type of the
	// binding pattern [x, s = ""]. Because the contextual type is a tuple type, the resulting type of [1, "one"] is the
	// tuple type [number, string]. Thus, the type inferred for 'x' is number and the type inferred for 's' is string.
	static function getWidenedTypeForVariableLikeDeclaration(c:Checker, declaration:Node, reportErrors:Bool):Type {
		return c.widenTypeForVariableLikeDeclaration(c.getTypeForVariableLikeDeclaration(declaration /*includeOptionality*/, true, CheckModeNormal), declaration,
			reportErrors);
	}

	// Return the inferred type for a variable, parameter, or property declaration
	static function getTypeForVariableLikeDeclaration(c:Checker, declaration:Node, includeOptionality:Bool, checkMode:CheckMode):Type {
		// A variable declared in a for..in statement is of type string, or of type keyof T when the
		// right hand expression is of a type parameter type.
		if (Ast.IsVariableDeclaration(declaration)) {
			final grandParent = declaration.Parent.Parent;
			switch (grandParent.Kind) {
				case KindForInStatement:
					final indexType = c.getIndexType(c.getNonNullableTypeIfNeeded(c.checkExpressionEx(grandParent.Expression(), checkMode /*checkMode*/)));
					if ((indexType.flags & (TypeFlagsTypeParameter | TypeFlagsIndex)) != 0) {
						return c.getExtractStringType(indexType);
					}
					return c.stringType;
				case KindForOfStatement:
					// checkRightHandSideOfForOf will return undefined if the for-of expression type was
					// missing properties/signatures required to get its iteratedType (like
					// [Symbol.iterator] or next). This may be because we accessed properties from anyType,
					// or it may have led to an error inside getElementTypeOfIterable.
					return c.checkRightHandSideOfForOf(grandParent);
				default:
			}
		} else if (Ast.IsBindingElement(declaration)) {
			return c.getTypeForBindingElement(declaration);
		}
		final isProperty = Ast.IsPropertyDeclaration(declaration) && !Ast.HasAccessorModifier(declaration) || Ast.IsPropertySignatureDeclaration(declaration);
		final isOptional = includeOptionality && Checker.isOptionalDeclaration(declaration);
		// Use type from type annotation if one is present
		final declaredType = c.tryGetTypeFromTypeNode(declaration);
		if (Ast.IsCatchClauseVariableDeclarationOrBindingElement(declaration)) {
			if (declaredType != null) {
				// If the catch clause is explicitly annotated with any or unknown, accept it, otherwise error.
				if ((declaredType.flags & TypeFlagsAnyOrUnknown) != 0) {
					return declaredType;
				}
				return c.errorType;
			}
			// If the catch clause is not explicitly annotated, treat it as though it were explicitly
			// annotated with unknown or any, depending on useUnknownInCatchVariables.
			if (c.useUnknownInCatchVariables) {
				return c.unknownType;
			} else {
				return c.anyType;
			}
		}
		if (declaredType != null) {
			return c.addOptionalityEx(declaredType, isProperty, isOptional);
		}
		if (c.noImplicitAny && Ast.IsVariableDeclaration(declaration) && !Ast.IsBindingPattern(declaration.Name())
			&& (c.getCombinedModifierFlagsCached(declaration) & ModifierFlagsExport) == 0 && (declaration.Flags & NodeFlagsAmbient) == 0) {
			// If --noImplicitAny is on or the declaration is in a Javascript file,
			// use control flow tracked 'any' type for non-ambient, non-exported var or let variables with no
			// initializer or a 'null' or 'undefined' initializer.
			final initializer = declaration.Initializer();
			if ((c.getCombinedNodeFlagsCached(declaration) & NodeFlagsConstant) == 0 && (initializer == null || c.isNullOrUndefined(initializer))) {
				return c.autoType;
			}
			// Use control flow tracked 'any[]' type for non-ambient, non-exported variables with an empty array
			// literal initializer.
			if (initializer != null && Checker.isEmptyArrayLiteral(initializer)) {
				return c.autoArrayType;
			}
		}
		if (Ast.IsParameterDeclaration(declaration)) {
			if (declaration.Symbol() == null) {
				// parameters of function types defined in JSDoc in TS files don't have symbols
				return null;
			}
			final fn = declaration.Parent;
			// For a parameter of a set accessor, use the type of the get accessor if one is present
			if (Ast.IsSetAccessorDeclaration(fn) && c.hasBindableName(fn)) {
				final getter = Ast.GetDeclarationOfKind(c.getSymbolOfDeclaration(declaration.Parent), KindGetAccessor);
				if (getter != null) {
					final getterSignature = c.getSignatureFromDeclaration(getter);
					final thisParameter = c.getAccessorThisParameter(fn);
					if (thisParameter != null && declaration == thisParameter) {
						// Use the type from the *getter*
						Debug.Assert(thisParameter.Type() == null);
						return c.getTypeOfSymbol(getterSignature.thisParameter);
					}
					return c.getReturnTypeOfSignature(getterSignature);
				}
			}
			final pt = c.getParameterTypeOfFullSignature(fn, declaration);
			if (pt != null) {
				return pt;
			}
			// Use contextual parameter type if one is available
			var t:Type = null;
			if (declaration.Symbol().Name == Ast.InternalSymbolNameThis) {
				t = c.getContextualThisParameterType(fn);
			} else {
				t = c.getContextuallyTypedParameterType(declaration);
			}
			if (t != null) {
				return c.addOptionalityEx(t, false /*isProperty*/, isOptional);
			}
		}
		// Use the type of the initializer expression if one is present and the declaration is
		// not a parameter of a contextually typed function
		if (declaration.Initializer() != null) {
			final t = c.widenTypeInferredFromInitializer(declaration, c.checkDeclarationInitializer(declaration, checkMode, null /*contextualType*/));
			return c.addOptionalityEx(t, isProperty, isOptional);
		}
		if (c.noImplicitAny && Ast.IsPropertyDeclaration(declaration)) {
			// We have a property declaration with no type annotation or initializer, in noImplicitAny mode or a .js file.
			// Use control flow analysis of this.xxx assignments in the constructor or static block to determine the type of the property.
			if (!Ast.HasStaticModifier(declaration)) {
				final constructor = Ast.FindConstructorDeclaration(declaration.Parent);
				var t:Type = null;
				if (constructor != null) {
					t = c.getFlowTypeInConstructor(declaration.Symbol(), constructor);
				} else if ((declaration.ModifierFlags() & ModifierFlagsAmbient) != 0) {
					t = c.getTypeOfPropertyInBaseClass(declaration.Symbol());
				}
				if (t == null) {
					return null;
				}
				return c.addOptionalityEx(t, true /*isProperty*/, isOptional);
			} else {
				final staticBlocks = Core.Filter(declaration.Parent.Members(), fn_IsClassStaticBlockDeclaration);
				var t:Type = null;
				if (Core.len(staticBlocks) != 0) {
					t = c.getFlowTypeInStaticBlocks(declaration.Symbol(), staticBlocks);
				} else if ((declaration.ModifierFlags() & ModifierFlagsAmbient) != 0) {
					t = c.getTypeOfPropertyInBaseClass(declaration.Symbol());
				}
				if (t == null) {
					return null;
				}
				return c.addOptionalityEx(t, true /*isProperty*/, isOptional);
			}
		}
		if (Ast.IsJsxAttribute(declaration)) {
			// if JSX attribute doesn't have initializer, by default the attribute will have boolean value of true.
			// I.e <Elem attr /> is sugar for <Elem attr={true} />
			return c.trueType;
		}
		// If the declaration specifies a binding pattern and is not a parameter of a contextually
		// typed function, use the type implied by the binding pattern
		if (Ast.IsBindingPattern(declaration.Name())) {
			return c.getTypeFromBindingPattern(declaration.Name() /*includePatternInType*/, false /*reportErrors*/, true);
		}
		// No type specified and nothing can be inferred
		return null;
	}

	static function checkDeclarationInitializer(c:Checker, declaration:Node, checkMode:CheckMode, contextualType:Type):Type {
		final initializer = declaration.Initializer();
		var t = c.getQuickTypeOfExpression(initializer);
		if (t == null) {
			if (contextualType != null) {
				t = c.checkExpressionWithContextualType(initializer, contextualType, null /*inferenceContext*/, checkMode);
			} else {
				t = c.checkExpressionCachedEx(initializer, checkMode);
			}
		}
		if (Ast.IsParameterDeclaration(Ast.GetRootDeclaration(declaration))) {
			final name = declaration.Name();
			switch (name.Kind) {
				case KindObjectBindingPattern:
					if (Checker.isObjectLiteralType(t)) {
						return c.padObjectLiteralType(t, name);
					}
				case KindArrayBindingPattern:
					if (Checker.isTupleType(t)) {
						return c.padTupleType(t, name);
					}
				default:
			}
		}
		return t;
	}

	static function padObjectLiteralType(c:Checker, t:Type, pattern:Node):Type {
		var missingElements:Array<Node> = null;
		for (e in rangeOf(pattern.Elements())) {
			if (e.Initializer() != null) {
				final name = c.getPropertyNameFromBindingElement(e);
				if (name != Ast.InternalSymbolNameMissing && c.getPropertyOfType(t, name) == null) {
					missingElements = appendNode(missingElements, e);
				}
			}
		}
		if (Core.len(missingElements) == 0) {
			return t;
		}
		final members = new SymbolTable();
		for (prop in rangeOf(c.getPropertiesOfObjectType(t))) {
			members.set(prop.Name, prop);
		}
		for (e in missingElements) {
			final symbol = c.newSymbol(SymbolFlagsProperty | SymbolFlagsOptional, c.getPropertyNameFromBindingElement(e));
			c.valueSymbolLinks.Get(symbol).resolvedType = c.getTypeFromBindingElement(e, false /*includePatternInType*/, false /*reportErrors*/);
			members.set(symbol.Name, symbol);
		}
		final result = c.newAnonymousType(t.symbol, members, null, null, c.getIndexInfosOfType(t));
		result.objectFlags = t.objectFlags;
		return result;
	}

	static function getPropertyNameFromBindingElement(c:Checker, e:Node):std.String {
		final exprType = c.getLiteralTypeFromPropertyName(e.PropertyNameOrName());
		if (Checker.isTypeUsableAsPropertyName(exprType)) {
			return Checker.getPropertyNameFromType(exprType);
		}
		return Ast.InternalSymbolNameMissing;
	}

	static function padTupleType(c:Checker, t:Type, pattern:Node):Type {
		final patternElements = pattern.Elements();
		if ((t.TargetTupleType().combinedFlags & ElementFlagsVariable) != 0 || c.getTypeReferenceArity(t) >= Core.len(patternElements)) {
			return t;
		}
		var elementTypes = Slices.Clone(c.getElementTypes(t));
		// PORT: Go `slices.Clone` of []TupleElementInfo copies the struct values.
		var elementInfos = Core.Map(t.TargetTupleType().elementInfos, function(info:TupleElementInfo):TupleElementInfo {
			final r = new TupleElementInfo();
			r.flags = info.flags;
			r.labeledDeclaration = info.labeledDeclaration;
			return r;
		});
		var i = c.getTypeReferenceArity(t);
		while (i < Core.len(patternElements)) {
			final e = patternElements[i];
			if (i < patternElements.length - 1 || !(Ast.IsBindingElement(e) && Checker.hasDotDotDotToken(e))) {
				var elementType = c.anyType;
				if (!Ast.IsOmittedExpression(e) && c.hasDefaultValue(e)) {
					elementType = c.getTypeFromBindingElement(e, false /*includePatternInType*/, false /*reportErrors*/);
				}
				if (elementTypes == null) {
					elementTypes = [];
				}
				elementTypes.push(elementType);
				final info = new TupleElementInfo();
				info.flags = ElementFlagsOptional;
				if (elementInfos == null) {
					elementInfos = [];
				}
				elementInfos.push(info);
				if (!Ast.IsOmittedExpression(e) && !c.hasDefaultValue(e)) {
					c.reportImplicitAny(e, c.anyType, WideningKindNormal);
				}
			}
			i++;
		}
		return c.createTupleTypeEx(elementTypes, elementInfos, t.TargetTupleType().readonly);
	}

	static function widenTypeInferredFromInitializer(c:Checker, declaration:Node, t:Type):Type {
		final widened = c.getWidenedLiteralTypeForInitializer(declaration, t);
		if (Ast.IsInJSFile(declaration)) {
			if (c.isEmptyLiteralType(widened)) {
				c.reportImplicitAny(declaration, c.anyType, WideningKindNormal);
				return c.anyType;
			}
			if (c.isEmptyArrayLiteralType(widened)) {
				c.reportImplicitAny(declaration, c.anyArrayType, WideningKindNormal);
				return c.anyArrayType;
			}
		}
		return widened;
	}

	static function getWidenedLiteralTypeForInitializer(c:Checker, declaration:Node, t:Type):Type {
		if ((c.getCombinedNodeFlagsCached(declaration) & NodeFlagsConstant) != 0 || Checker.isDeclarationReadonly(declaration)) {
			return t;
		}
		return c.getWidenedLiteralType(t);
	}

	static function getTypeOfFuncClassEnumModule(c:Checker, symbol:Symbol):Type {
		final links = c.valueSymbolLinks.Get(symbol);
		if (links.resolvedType == null) {
			links.resolvedType = c.getTypeOfFuncClassEnumModuleWorker(symbol);
		}
		return links.resolvedType;
	}

	static function getTypeOfFuncClassEnumModuleWorker(c:Checker, symbol:Symbol):Type {
		if ((symbol.Flags & SymbolFlagsModule) != 0 && Checker.isShorthandAmbientModuleSymbol(symbol)) {
			return c.anyType;
		} else if ((symbol.Flags & SymbolFlagsValueModule) != 0 && symbol.ValueDeclaration != null && Ast.IsSourceFile(symbol.ValueDeclaration)
			&& symbol.ValueDeclaration.AsSourceFile().CommonJSModuleIndicator != null) {
			final resolvedModule = c.resolveExternalModuleSymbol(symbol, false /*dontResolveAlias*/);
			if (resolvedModule != symbol) {
				return c.getTypeOfSymbol(resolvedModule);
			}
		}
		final t = c.newObjectType(ObjectFlagsAnonymous, symbol);
		if ((symbol.Flags & SymbolFlagsClass) != 0) {
			final baseTypeVariable = c.getBaseTypeVariableOfClass(symbol);
			if (baseTypeVariable != null) {
				return c.getIntersectionType([t, baseTypeVariable]);
			}
			return t;
		}
		if (c.strictNullChecks && (symbol.Flags & SymbolFlagsOptional) != 0) {
			return c.getOptionalType(t /*isProperty*/, true);
		}
		return t;
	}

	static function getBaseTypeVariableOfClass(c:Checker, symbol:Symbol):Type {
		final baseConstructorType = c.getBaseConstructorTypeOfClass(c.getDeclaredTypeOfClassOrInterface(symbol));
		if ((baseConstructorType.flags & TypeFlagsTypeVariable) != 0) {
			return baseConstructorType;
		} else if ((baseConstructorType.flags & TypeFlagsIntersection) != 0) {
			return Core.Find(baseConstructorType.Types(), t -> (t.flags & TypeFlagsTypeVariable) != 0);
		}
		return null;
	}

	/**
	 * The base constructor of a class can resolve to
	 * * undefinedType if the class has no extends clause,
	 * * errorType if an error occurred during resolution of the extends expression,
	 * * nullType if the extends expression is the null value,
	 * * anyType if the extends expression has type any, or
	 * * an object type with at least one construct signature.
	 */
	static function getBaseConstructorTypeOfClass(c:Checker, t:Type):Type {
		final data = t.AsInterfaceType();
		if (data.resolvedBaseConstructorType != null) {
			return data.resolvedBaseConstructorType;
		}
		final baseTypeNode = Checker.getBaseTypeNodeOfClass(t);
		if (baseTypeNode == null) {
			data.resolvedBaseConstructorType = c.undefinedType;
			return data.resolvedBaseConstructorType;
		}
		if (!c.pushTypeResolution(entity(t), TypeSystemPropertyNameResolvedBaseConstructorType)) {
			return c.errorType;
		}
		final baseConstructorType = c.checkExpression(baseTypeNode.Expression());
		if ((baseConstructorType.flags & (TypeFlagsObject | TypeFlagsIntersection)) != 0) {
			// Resolving the members of a class requires us to resolve the base class of that class.
			// We force resolution here such that we catch circularities now.
			c.resolveStructuredTypeMembers(baseConstructorType);
		}
		if (!c.popTypeResolution()) {
			c.error(t.symbol.ValueDeclaration, Diagnostics.X_0_is_referenced_directly_or_indirectly_in_its_own_base_expression, c.symbolToString(t.symbol));
			if (data.resolvedBaseConstructorType == null) {
				data.resolvedBaseConstructorType = c.errorType;
			}
			return data.resolvedBaseConstructorType;
		}
		if ((baseConstructorType.flags & TypeFlagsAny) == 0 && baseConstructorType != c.nullWideningType && !c.isConstructorType(baseConstructorType)) {
			final err = c.error(baseTypeNode.Expression(), Diagnostics.Type_0_is_not_a_constructor_function_type, c.TypeToString(baseConstructorType));
			if ((baseConstructorType.flags & TypeFlagsTypeParameter) != 0) {
				final constraint = c.getConstraintFromTypeParameter(baseConstructorType);
				var ctorReturn:Type = c.unknownType;
				if (constraint != null) {
					final ctorSigs = c.getSignaturesOfType(constraint, SignatureKindConstruct);
					if (Core.len(ctorSigs) != 0) {
						ctorReturn = c.getReturnTypeOfSignature(ctorSigs[0]);
					}
				}
				if (baseConstructorType.symbol.Declarations != null) {
					err.AddRelatedInfo(Checker.createDiagnosticForNode(baseConstructorType.symbol.Declarations[0],
						Diagnostics.Did_you_mean_for_0_to_be_constrained_to_type_new_args_Colon_any_1, c.symbolToString(baseConstructorType.symbol),
						c.TypeToString(ctorReturn)));
				}
			}
			if (data.resolvedBaseConstructorType == null) {
				data.resolvedBaseConstructorType = c.errorType;
			}
			return data.resolvedBaseConstructorType;
		}
		if (data.resolvedBaseConstructorType == null) {
			data.resolvedBaseConstructorType = baseConstructorType;
		}
		return data.resolvedBaseConstructorType;
	}

	static function isFunctionType(c:Checker, t:Type):Bool {
		return (t.flags & TypeFlagsObject) != 0 && Core.len(c.getSignaturesOfType(t, SignatureKindCall)) > 0;
	}

	static function isConstructorType(c:Checker, t:Type):Bool {
		if (Core.len(c.getSignaturesOfType(t, SignatureKindConstruct)) > 0) {
			return true;
		}
		if ((t.flags & TypeFlagsTypeVariable) != 0) {
			final constraint = c.getBaseConstraintOfType(t);
			return constraint != null && c.isMixinConstructorType(constraint);
		}
		return false;
	}

	// A type is a mixin constructor if it has a single construct signature taking no type parameters and a single
	// rest parameter of type any[].
	static function isMixinConstructorType(c:Checker, t:Type):Bool {
		final signatures = c.getSignaturesOfType(t, SignatureKindConstruct);
		if (Core.len(signatures) == 1) {
			final s = signatures[0];
			if (Core.len(s.typeParameters) == 0 && Core.len(s.parameters) == 1 && Checker.signatureHasRestParameter(s)) {
				final paramType = c.getTypeOfParameter(s.parameters[0]);
				return Checker.IsTypeAny(paramType) || c.getElementTypeOfArrayType(paramType) == c.anyType;
			}
		}
		return false;
	}

	static function getTypeOfParameter(c:Checker, symbol:Symbol):Type {
		final declaration = symbol.ValueDeclaration;
		return c.addOptionalityEx(c.getTypeOfSymbol(symbol), false,
			declaration != null && (declaration.Initializer() != null || Checker.isOptionalDeclaration(declaration)));
	}

	static function getConstraintOfType(c:Checker, t:Type):Type {
		if ((t.flags & TypeFlagsTypeParameter) != 0) {
			return c.getConstraintOfTypeParameter(t);
		} else if ((t.flags & TypeFlagsIndexedAccess) != 0) {
			return c.getConstraintOfIndexedAccess(t);
		} else if ((t.flags & TypeFlagsConditional) != 0) {
			return c.getConstraintOfConditionalType(t);
		}
		return c.getBaseConstraintOfType(t);
	}

	static function getConstraintOfTypeParameter(c:Checker, typeParameter:Type):Type {
		if (c.hasNonCircularBaseConstraint(typeParameter)) {
			return c.getConstraintFromTypeParameter(typeParameter);
		}
		return null;
	}

	static function hasNonCircularBaseConstraint(c:Checker, t:Type):Bool {
		return c.getResolvedBaseConstraint(t, null) != c.circularConstraintType;
	}

	// This is a worker function. Use getConstraintOfTypeParameter which guards against circular constraints
	static function getConstraintFromTypeParameter(c:Checker, t:Type):Type {
		if ((t.flags & TypeFlagsTypeParameter) == 0) {
			return null;
		}
		final tp = t.AsTypeParameter();
		if (tp.constraint == null) {
			var constraint:Type = null;
			if (tp.target != null) {
				constraint = c.instantiateType(c.getConstraintOfTypeParameter(tp.target), tp.mapper);
			} else {
				final constraintDeclaration = c.getConstraintDeclaration(t);
				if (constraintDeclaration != null) {
					constraint = c.getTypeFromTypeNode(constraintDeclaration);
					if ((constraint.flags & TypeFlagsAny) != 0 && !c.isErrorType(constraint)) {
						// use stringNumberSymbolType as the base constraint for mapped type key constraints (unknown isn;t assignable to that, but `any` was),
						// use unknown otherwise
						if (Ast.IsMappedTypeNode(constraintDeclaration.Parent.Parent)) {
							constraint = c.stringNumberSymbolType;
						} else {
							constraint = c.unknownType;
						}
					}
				} else {
					constraint = c.getInferredTypeParameterConstraint(t, false);
				}
			}
			if (constraint == null) {
				constraint = c.noConstraintType;
			}
			tp.constraint = constraint;
		}
		if (tp.constraint != c.noConstraintType) {
			return tp.constraint;
		}
		return null;
	}

	static function getConstraintOrUnknownFromTypeParameter(c:Checker, t:Type):Type {
		final result = c.getConstraintFromTypeParameter(t);
		return Core.IfElse(result != null, result, c.unknownType);
	}

	static function getInferredTypeParameterConstraint(c:Checker, t:Type, omitTypeReferences:Bool):Type {
		var inferences:Array<Type> = null;
		if (t.symbol != null && Core.len(t.symbol.Declarations) != 0) {
			for (declaration in t.symbol.Declarations) {
				if (Ast.IsInferTypeNode(declaration.Parent)) {
					// When an 'infer T' declaration is immediately contained in a type reference node
					// (such as 'Foo<infer T>'), T's constraint is inferred from the constraint of the
					// corresponding type parameter in 'Foo'. When multiple 'infer T' declarations are
					// present, we form an intersection of the inferred constraint types.
					var child = declaration.Parent;
					var parent = child.Parent;
					while (parent != null && Ast.IsParenthesizedTypeNode(parent)) {
						child = parent;
						parent = child.Parent;
					}
					if (Ast.IsTypeReferenceNode(parent) && !omitTypeReferences) {
						final typeParameters = c.getTypeParametersForTypeReferenceOrImport(parent);
						if (typeParameters != null) {
							final index = Slices.Index(parent.TypeArguments(), child);
							if (index >= 0 && index < typeParameters.length) {
								final declaredConstraint = c.getConstraintOfTypeParameter(typeParameters[index]);
								if (declaredConstraint != null) {
									// Type parameter constraints can reference other type parameters so
									// constraints need to be instantiated. If instantiation produces the
									// type parameter itself, we discard that inference. For example, in
									//   type Foo<T extends string, U extends T> = [T, U];
									//   type Bar<T> = T extends Foo<infer X, infer X> ? Foo<X, X> : T;
									// the instantiated constraint for U is X, so we discard that inference.
									final p = parent;
									final mapper = Checker.newDeferredTypeMapper(typeParameters, Core.MapIndex(typeParameters, function(_:Type, index:Int):() -> Type {
										return function():Type {
											return c.getEffectiveTypeArgumentAtIndex(p, typeParameters, index);
										};
									}));
									final constraint = c.instantiateType(declaredConstraint, mapper);
									if (constraint != t) {
										if (inferences == null) {
											inferences = [];
										}
										inferences.push(constraint);
									}
								}
							}
						}
					} else if (Ast.IsParameterDeclaration(parent) && parent.AsParameterDeclaration().DotDotDotToken != null
						|| Ast.IsRestTypeNode(parent)
						|| Ast.IsNamedTupleMember(parent) && parent.AsNamedTupleMember().DotDotDotToken != null) {
						if (inferences == null) {
							inferences = [];
						}
						inferences.push(c.createArrayType(c.unknownType));
					} else if (Ast.IsTemplateLiteralTypeSpan(parent)) {
						if (inferences == null) {
							inferences = [];
						}
						inferences.push(c.stringType);
					} else if (Ast.IsTypeParameterDeclaration(parent) && Ast.IsMappedTypeNode(parent.Parent)) {
						if (inferences == null) {
							inferences = [];
						}
						inferences.push(c.stringNumberSymbolType);
					} else if (Ast.IsMappedTypeNode(parent) && parent.Type() != null && Ast.SkipParentheses(parent.Type()) == declaration.Parent
						&& Ast.IsConditionalTypeNode(parent.Parent) && parent.Parent.AsConditionalTypeNode().ExtendsType == parent
						&& Ast.IsMappedTypeNode(parent.Parent.AsConditionalTypeNode().CheckType)
						&& parent.Parent.AsConditionalTypeNode().CheckType.Type() != null) {
						final checkMappedType = parent.Parent.AsConditionalTypeNode().CheckType;
						final nodeType = c.getTypeFromTypeNode(checkMappedType.Type());
						final checkMappedTypeParameter = checkMappedType.AsMappedTypeNode().TypeParameter;
						final mapper = Checker.newSimpleTypeMapper(c.getDeclaredTypeOfTypeParameter(c.getSymbolOfDeclaration(checkMappedTypeParameter)),
							Core.IfElse(checkMappedTypeParameter.AsTypeParameterDeclaration().Constraint != null,
								c.getTypeFromTypeNode(checkMappedTypeParameter.AsTypeParameterDeclaration().Constraint), c.stringNumberSymbolType));
						if (inferences == null) {
							inferences = [];
						}
						inferences.push(c.instantiateType(nodeType, mapper));
					}
				}
			}
		}
		if (Core.len(inferences) != 0) {
			return c.getIntersectionType(inferences);
		}
		return null;
	}

	static function getTypeParametersForTypeReferenceOrImport(c:Checker, node:Node):Array<Type> {
		final t = c.getTypeFromTypeNode(node);
		if (!c.isErrorType(t)) {
			final symbol = c.getResolvedSymbolOrNil(node);
			if (symbol != null) {
				return c.getTypeParametersForTypeAndSymbol(t, symbol);
			}
		}
		return null;
	}

	static function getTypeParametersForTypeAndSymbol(c:Checker, t:Type, symbol:Symbol):Array<Type> {
		if (!c.isErrorType(t)) {
			if ((symbol.Flags & SymbolFlagsTypeAlias) != 0) {
				final typeParameters = c.typeAliasLinks.Get(symbol).typeParameters;
				if (Core.len(typeParameters) != 0) {
					return typeParameters;
				}
			}
			if ((t.objectFlags & ObjectFlagsReference) != 0) {
				return t.Target().AsInterfaceType().LocalTypeParameters();
			}
		}
		return null;
	}

	static function getEffectiveTypeArgumentAtIndex(c:Checker, node:Node, typeParameters:Array<Type>, index:Int):Type {
		final typeArguments = node.TypeArguments();
		if (index < Core.len(typeArguments)) {
			return c.getTypeFromTypeNode(typeArguments[index]);
		}
		return c.getEffectiveTypeArguments(node, typeParameters)[index];
	}

	static function getConstraintOfIndexedAccess(c:Checker, t:Type):Type {
		if (c.hasNonCircularBaseConstraint(t)) {
			return c.getConstraintFromIndexedAccess(t);
		}
		return null;
	}

	static function getConstraintFromIndexedAccess(c:Checker, t:Type):Type {
		final d = t.AsIndexedAccessType();
		if (c.isMappedTypeGenericIndexedAccess(t)) {
			// For indexed access types of the form { [P in K]: E }[X], where K is non-generic and X is generic,
			// we substitute an instantiation of E where P is replaced with X.
			return c.substituteIndexedMappedType(d.objectType, d.indexType);
		}
		final indexConstraint = c.getSimplifiedTypeOrConstraint(d.indexType);
		if (indexConstraint != null && indexConstraint != d.indexType) {
			final indexedAccess = c.getIndexedAccessTypeOrUndefined(d.objectType, indexConstraint, d.accessFlags, null, null);
			if (indexedAccess != null) {
				return indexedAccess;
			}
		}
		final objectConstraint = c.getSimplifiedTypeOrConstraint(d.objectType);
		if (objectConstraint != null && objectConstraint != d.objectType) {
			return c.getIndexedAccessTypeOrUndefined(objectConstraint, d.indexType, d.accessFlags, null, null);
		}
		return null;
	}

	static function getConstraintOfConditionalType(c:Checker, t:Type):Type {
		if (c.hasNonCircularBaseConstraint(t)) {
			return c.getConstraintFromConditionalType(t);
		}
		return null;
	}

	static function getConstraintFromConditionalType(c:Checker, t:Type):Type {
		final constraint = c.getConstraintOfDistributiveConditionalType(t);
		if (constraint != null) {
			return constraint;
		}
		return c.getDefaultConstraintOfConditionalType(t);
	}

	static function getDefaultConstraintOfConditionalType(c:Checker, t:Type):Type {
		final d = t.AsConditionalType();
		if (d.resolvedDefaultConstraint == null) {
			// An `any` branch of a conditional type would normally be viral - specifically, without special handling here,
			// a conditional type with a single branch of type `any` would be assignable to anything, since it's constraint would simplify to
			// just `any`. This result is _usually_ unwanted - so instead here we elide an `any` branch from the constraint type,
			// in effect treating `any` like `never` rather than `unknown` in this location.
			final trueConstraint = c.getInferredTrueTypeFromConditionalType(t);
			final falseConstraint = c.getFalseTypeFromConditionalType(t);
			if (Checker.IsTypeAny(trueConstraint)) {
				d.resolvedDefaultConstraint = falseConstraint;
			} else if (Checker.IsTypeAny(falseConstraint)) {
				d.resolvedDefaultConstraint = trueConstraint;
			} else {
				d.resolvedDefaultConstraint = c.getUnionType([trueConstraint, falseConstraint]);
			}
		}
		return d.resolvedDefaultConstraint;
	}

	static function getConstraintOfDistributiveConditionalType(c:Checker, t:Type):Type {
		final d = t.AsConditionalType();
		if (d.resolvedConstraintOfDistributive == null) {
			// Check if we have a conditional type of the form 'T extends U ? X : Y', where T is a constrained
			// type parameter. If so, create an instantiation of the conditional type where T is replaced
			// with its constraint. We do this because if the constraint is a union type it will be distributed
			// over the conditional type and possibly reduced. For example, 'T extends undefined ? never : T'
			// removes 'undefined' from T.
			// We skip returning a distributive constraint for a restrictive instantiation of a conditional type
			// as the constraint for all type params (check type included) have been replace with `unknown`, which
			// is going to produce even more false positive/negative results than the distribute constraint already does.
			// Please note: the distributive constraint is a kludge for emulating what a negated type could to do filter
			// a union - once negated types exist and are applied to the conditional false branch, this "constraint"
			// likely doesn't need to exist.
			if (d.root.isDistributive && c.cachedTypes.get(CachedTypeKey.keyOf(CachedTypeKindRestrictiveInstantiation, t.id)) != t) {
				var constraint = c.getSimplifiedType(d.checkType, false /*writing*/);
				if (constraint == d.checkType) {
					constraint = c.getConstraintOfType(constraint);
				}
				if (constraint != null && constraint != d.checkType) {
					final instantiated = c.getConditionalTypeInstantiation(t, Checker.prependTypeMapping(d.root.checkType, constraint, d.mapper), true /*forConstraint*/,
						null);
					if ((instantiated.flags & TypeFlagsNever) == 0) {
						d.resolvedConstraintOfDistributive = instantiated;
						return instantiated;
					}
				}
			}
			d.resolvedConstraintOfDistributive = c.noConstraintType;
		}
		if (d.resolvedConstraintOfDistributive != c.noConstraintType) {
			return d.resolvedConstraintOfDistributive;
		}
		return null;
	}

	static function getDeclaredTypeOfClassOrInterface(c:Checker, symbol:Symbol):Type {
		final links = c.declaredTypeLinks.Get(symbol);
		if (links.declaredType == null) {
			final kind:ObjectFlags = Core.IfElse((symbol.Flags & SymbolFlagsClass) != 0, ObjectFlagsClass, ObjectFlagsInterface);
			final t = c.newObjectType(kind, symbol);
			links.declaredType = t;
			final outerTypeParameters = c.getOuterTypeParametersOfClassOrInterface(symbol);
			// PORT: Go's append below leaves len(outerTypeParameters) unchanged; Haxe push grows the same array.
			final outerTypeParameterCount = Core.len(outerTypeParameters);
			final typeParameters = c.appendLocalTypeParametersOfClassOrInterfaceOrTypeAlias(outerTypeParameters, symbol);
			// A class or interface is generic if it has type parameters or a "this" type. We always give classes a "this" type
			// because it is not feasible to analyze all members to determine if the "this" type escapes the class (in particular,
			// property types inferred from initializers and method return types inferred from return statements are very hard
			// to exhaustively analyze). We give interfaces a "this" type if we can't definitely determine that they are free of
			// "this" references.
			if (typeParameters != null || kind == ObjectFlagsClass || !c.isThislessInterface(symbol)) {
				t.objectFlags |= ObjectFlagsReference;
				final d = t.AsInterfaceType();
				d.thisType = c.newTypeParameter(symbol);
				d.thisType.AsTypeParameter().isThisType = true;
				d.thisType.AsTypeParameter().constraint = t;
				// PORT: Go `append(typeParameters, d.thisType)` never shows in the holder of typeParameters; copy first.
				final all = typeParameters == null ? [] : typeParameters.copy();
				all.push(d.thisType);
				d.allTypeParameters = all;
				d.outerTypeParameterCount = outerTypeParameterCount;
				d.resolvedTypeArguments = d.TypeParameters();
				d.instantiations = new StringMap<Type>();
				d.instantiations.set(Checker.getTypeListKey(d.resolvedTypeArguments).Key(), t);
				d.target = t;
			}
		}
		return links.declaredType;
	}

	/**
	 * Returns true if the interface given by the symbol is free of "this" references.
	 *
	 * Specifically, the result is true if the interface itself contains no references
	 * to "this" in its body, if all base types are interfaces,
	 * and if none of the base interfaces have a "this" type.
	 */
	static function isThislessInterface(c:Checker, symbol:Symbol):Bool {
		for (declaration in rangeOf(symbol.Declarations)) {
			if (Ast.IsInterfaceDeclaration(declaration)) {
				if ((declaration.Flags & NodeFlagsContainsThis) != 0) {
					return false;
				}
				final baseTypeNodes = Ast.GetExtendsHeritageClauseElements(declaration);
				for (node in rangeOf(baseTypeNodes)) {
					if (Ast.IsEntityNameExpression(node.Expression())) {
						final baseSymbol = c.resolveEntityName(node.Expression(), SymbolFlagsType, true /*ignoreErrors*/, false, null);
						if (baseSymbol == null || (baseSymbol.Flags & SymbolFlagsInterface) == 0
							|| c.getDeclaredTypeOfClassOrInterface(baseSymbol).AsInterfaceType().thisType != null) {
							return false;
						}
					}
				}
			}
		}
		return true;
	}

	static function isNullOrUndefined(c:Checker, node:Node):Bool {
		final expr = Ast.SkipParentheses(node);
		switch (expr.Kind) {
			case KindNullKeyword:
				return true;
			case KindIdentifier:
				return c.getResolvedSymbol(expr) == c.undefinedSymbol;
			default:
		}
		return false;
	}

	static function checkRightHandSideOfForOf(c:Checker, statement:Node):Type {
		final use:IterationUse = Core.IfElse(statement.AsForInOrOfStatement().AwaitModifier != null, IterationUseForAwaitOf, IterationUseForOf);
		return c.checkIteratedTypeOrElementType(use, c.checkNonNullExpression(statement.Expression()), c.undefinedType, statement.Expression());
	}

	// Return the inferred type for a binding element
	static function getTypeForBindingElement(c:Checker, declaration:Node):Type {
		final checkMode:CheckMode = Core.IfElse(Checker.hasDotDotDotToken(declaration), CheckModeRestBindingElement, CheckModeNormal);
		final parentType = c.getTypeForBindingElementParent(declaration.Parent.Parent, checkMode);
		if (parentType != null) {
			return c.getBindingElementTypeFromParentType(declaration, parentType, false /*noTupleBoundsCheck*/);
		}
		return null;
	}

	// Return the type of a binding element parent. We check SymbolLinks first to see if a type has been
	// assigned by contextual typing.
	static function getTypeForBindingElementParent(c:Checker, node:Node, checkMode:CheckMode):Type {
		if (checkMode == CheckModeNormal) {
			// We can use a cached resolved type if no optionality was included in that type.
			final symbol = c.getSymbolOfDeclaration(node);
			if (symbol != null) {
				final resolvedType = c.valueSymbolLinks.Get(symbol).resolvedType;
				if (resolvedType != null && !(c.strictNullChecks && Checker.isOptionalDeclaration(node))) {
					return resolvedType;
				}
			}
		}
		return c.getTypeForVariableLikeDeclaration(node, false /*includeOptionality*/, checkMode);
	}

	static function getBindingElementTypeFromParentType(c:Checker, declaration:Node, parentType:Type, noTupleBoundsCheck:Bool):Type {
		// If an any type was inferred for parent, infer that for the binding element
		if (Checker.IsTypeAny(parentType)) {
			return parentType;
		}
		final pattern = declaration.Parent;
		// Relax null check on ambient destructuring parameters, since the parameters have no implementation and are just documentation
		if (c.strictNullChecks && (declaration.Flags & NodeFlagsAmbient) != 0 && Ast.IsPartOfParameterDeclaration(declaration)) {
			parentType = c.GetNonNullableType(parentType);
		} else if (c.strictNullChecks && pattern.Parent.Initializer() != null
			&& !c.hasTypeFacts(c.getTypeOfInitializer(pattern.Parent.Initializer()), TypeFactsEQUndefined)) {
			parentType = c.getTypeWithFacts(parentType, TypeFactsNEUndefined);
		}
		final accessFlags:AccessFlags = AccessFlagsExpressionPosition | Core.IfElse(noTupleBoundsCheck || c.hasDefaultValue(declaration), AccessFlagsAllowMissing, 0);
		var t:Type = null;
		switch (pattern.Kind) {
			case KindObjectBindingPattern:
				if (Checker.hasDotDotDotToken(declaration)) {
					parentType = c.getReducedType(parentType);
					if ((parentType.flags & TypeFlagsUnknown) != 0 || !c.isValidSpreadType(parentType)) {
						c.error(declaration, Diagnostics.Rest_types_may_only_be_created_from_object_types);
						return c.errorType;
					}
					final elements = pattern.Elements();
					final literalMembers:Array<Node> = [];
					for (element in rangeOf(elements)) {
						if (!Checker.hasDotDotDotToken(element)) {
							final name = element.PropertyNameOrName();
							literalMembers.push(name);
						}
					}
					t = c.getRestType(parentType, literalMembers, declaration.Symbol());
				} else {
					// Use explicitly specified property name ({ p: xxx } form), or otherwise the implied name ({ p } form)
					final name = declaration.PropertyNameOrName();
					final indexType = c.getLiteralTypeFromPropertyName(name);
					final declaredType = c.getIndexedAccessTypeEx(parentType, indexType, accessFlags, name, null);
					t = c.getFlowTypeOfDestructuring(declaration, declaredType);
				}
			case KindArrayBindingPattern:
				// This elementType will be used if the specific property corresponding to this index is not
				// present (aka the tuple element property). This call also checks that the parentType is in
				// fact an iterable or array (depending on target language).
				final elementType = c.checkIteratedTypeOrElementType(IterationUseDestructuring
					| Core.IfElse(Checker.hasDotDotDotToken(declaration), 0, IterationUsePossiblyOutOfBounds), parentType,
					c.undefinedType, pattern);
				final index = Slices.Index(pattern.Elements(), declaration);
				if (Checker.hasDotDotDotToken(declaration)) {
					// If the parent is a tuple type, the rest element has a tuple type of the
					// remaining tuple element types. Otherwise, the rest element has an array type with same
					// element type as the parent type.
					final baseConstraint = c.mapType(parentType, function(t:Type):Type {
						if ((t.flags & TypeFlagsInstantiableNonPrimitive) != 0) {
							return c.getBaseConstraintOrType(t);
						}
						return t;
					});
					if (Checker.everyType(baseConstraint, fn_isTupleType)) {
						t = c.mapType(baseConstraint, function(t:Type):Type {
							return c.sliceTupleType(t, index, 0);
						});
					} else {
						t = c.createArrayType(elementType);
					}
				} else if (c.isArrayLikeType(parentType)) {
					final indexType = c.getNumberLiteralType(index);
					final declaredType = Core.OrElse(c.getIndexedAccessTypeOrUndefined(parentType, indexType, accessFlags, declaration.Name(), null), c.errorType);
					t = c.getFlowTypeOfDestructuring(declaration, declaredType);
				} else {
					t = elementType;
				}
			default:
				throw "Unhandled case in getBindingElementTypeFromParentType";
		}
		if (declaration.Initializer() == null) {
			return t;
		}
		if (Ast.WalkUpBindingElementsAndPatterns(declaration).Type() != null) {
			// In strict null checking mode, if a default value of a non-undefined type is specified, remove
			// undefined from the final type.
			if (c.strictNullChecks && !c.hasTypeFacts(c.checkDeclarationInitializer(declaration, CheckModeNormal, null), TypeFactsIsUndefined)) {
				return c.getNonUndefinedType(t);
			}
			return t;
		}
		return c.widenTypeInferredFromInitializer(declaration,
			c.getUnionTypeEx([c.getNonUndefinedType(t), c.checkDeclarationInitializer(declaration, CheckModeNormal, null)], UnionReductionSubtype, null, null));
	}

	static function getRestType(c:Checker, source:Type, properties:Array<Node>, symbol:Symbol):Type {
		source = c.filterType(source, t -> (t.flags & TypeFlagsNullable) == 0);
		if ((source.flags & TypeFlagsNever) != 0) {
			return c.emptyObjectType;
		}
		if ((source.flags & TypeFlagsUnion) != 0) {
			return c.mapType(source, function(t:Type):Type {
				return c.getRestType(t, properties, symbol);
			});
		}
		var omitKeyType = c.getUnionType(Core.Map(properties, n -> c.getLiteralTypeFromPropertyName(n)));
		var spreadableProperties:Array<Symbol> = null;
		var unspreadableToRestKeys:Array<Type> = null;
		for (prop in rangeOf(c.getPropertiesOfType(source))) {
			final literalTypeFromProperty = c.getLiteralTypeFromProperty(prop, TypeFlagsStringOrNumberLiteralOrUnique, false);
			if (!c.isTypeAssignableTo(literalTypeFromProperty, omitKeyType)
				&& (Checker.getDeclarationModifierFlagsFromSymbol(prop) & (ModifierFlagsPrivate | ModifierFlagsProtected)) == 0
				&& c.isSpreadableProperty(prop)) {
				if (spreadableProperties == null) {
					spreadableProperties = [];
				}
				spreadableProperties.push(prop);
			} else {
				if (unspreadableToRestKeys == null) {
					unspreadableToRestKeys = [];
				}
				unspreadableToRestKeys.push(literalTypeFromProperty);
			}
		}
		if (c.isGenericObjectType(source) || c.isGenericIndexType(omitKeyType)) {
			if (Core.len(unspreadableToRestKeys) != 0) {
				// If the type we're spreading from has properties that cannot
				// be spread into the rest type (e.g. getters, methods), ensure
				// they are explicitly omitted, as they would in the non-generic case.
				omitKeyType = c.getUnionType([omitKeyType].concat(unspreadableToRestKeys));
			}
			if ((omitKeyType.flags & TypeFlagsNever) != 0) {
				return source;
			}
			final omitTypeAlias = c.getGlobalOmitSymbol();
			if (omitTypeAlias == null) {
				return c.errorType;
			}
			return c.getTypeAliasInstantiation(omitTypeAlias, [source, omitKeyType], null);
		}
		final members = new SymbolTable();
		for (prop in rangeOf(spreadableProperties)) {
			members.set(prop.Name, c.getSpreadSymbol(prop, false /*readonly*/));
		}
		final result = c.newAnonymousType(symbol, members, null, null, c.getIndexInfosOfType(source));
		result.objectFlags |= ObjectFlagsObjectRestType;
		return result;
	}

	// Determine the control flow type associated with a destructuring declaration or assignment. The following
	// forms of destructuring are possible:
	//
	//	let { x } = obj;  // BindingElement
	//	let [ x ] = obj;  // BindingElement
	//	{ x } = obj;      // ShorthandPropertyAssignment
	//	{ x: v } = obj;   // PropertyAssignment
	//	[ x ] = obj;      // Expression
	//
	// We construct a synthetic element access expression corresponding to 'obj.x' such that the control
	// flow analyzer doesn't have to handle all the different syntactic forms.
	static function getFlowTypeOfDestructuring(c:Checker, node:Node, declaredType:Type):Type {
		final reference = c.getSyntheticElementAccess(node);
		if (reference != null) {
			return c.getFlowTypeOfReference(reference, declaredType);
		}
		return declaredType;
	}

	static function getSyntheticElementAccess(c:Checker, node:Node):Node {
		final parentAccess = c.getParentElementAccess(node);
		if (parentAccess != null && Checker.getFlowNodeOfNode(parentAccess) != null) {
			final r = c.getDestructuringPropertyName(node);
			if (r.ok) {
				final propName = r.value;
				final literal = c.factory.NewStringLiteral(propName, TokenFlagsNone);
				literal.Loc = node.Loc;
				var lhsExpr = parentAccess;
				if (!Ast.IsLeftHandSideExpression(parentAccess)) {
					lhsExpr = c.factory.NewParenthesizedExpression(parentAccess);
					lhsExpr.Loc = node.Loc;
				}
				final result = c.factory.NewElementAccessExpression(lhsExpr, null, literal, NodeFlagsNone);
				result.Loc = node.Loc;
				literal.Parent = result;
				result.Parent = node;
				if (lhsExpr != parentAccess) {
					lhsExpr.Parent = result;
				}
				result.FlowNodeData().FlowNode = Checker.getFlowNodeOfNode(parentAccess);
				return result;
			}
		}
		return null;
	}

	static function getParentElementAccess(c:Checker, node:Node):Node {
		final ancestor = node.Parent.Parent;
		switch (ancestor.Kind) {
			case KindBindingElement | KindPropertyAssignment:
				return c.getSyntheticElementAccess(ancestor);
			case KindArrayLiteralExpression:
				return c.getSyntheticElementAccess(node.Parent);
			case KindVariableDeclaration:
				return ancestor.Initializer();
			case KindBinaryExpression:
				return ancestor.AsBinaryExpression().Right;
			default:
		}
		return null;
	}

	// Return the type implied by a binding pattern. This is the type implied purely by the binding pattern itself
	// and without regard to its context (i.e. without regard any type annotation or initializer associated with the
	// declaration in which the binding pattern is contained). For example, the implied type of [x, y] is [any, any]
	// and the implied type of { x, y: z = 1 } is { x: any; y: number; }. The type implied by a binding pattern is
	// used as the contextual type of an initializer associated with the binding pattern. Also, for a destructuring
	// parameter with no type annotation or initializer, the type implied by the binding pattern becomes the type of
	// the parameter.
	static function getTypeFromBindingPattern(c:Checker, pattern:Node, includePatternInType:Bool, reportErrors:Bool):Type {
		if (includePatternInType) {
			if (c.contextualBindingPatterns == null) {
				c.contextualBindingPatterns = [];
			}
			c.contextualBindingPatterns.push(pattern);
		}
		var result:Type = null;
		if (Ast.IsObjectBindingPattern(pattern)) {
			result = c.getTypeFromObjectBindingPattern(pattern, includePatternInType, reportErrors);
		} else {
			result = c.getTypeFromArrayBindingPattern(pattern, includePatternInType, reportErrors);
		}
		if (includePatternInType) {
			c.contextualBindingPatterns.pop();
		}
		return result;
	}

	// Return the type implied by an object binding pattern
	static function getTypeFromObjectBindingPattern(c:Checker, pattern:Node, includePatternInType:Bool, reportErrors:Bool):Type {
		final members = new SymbolTable();
		var stringIndexInfo:IndexInfo = null;
		var objectFlags:ObjectFlags = ObjectFlagsObjectLiteral | ObjectFlagsContainsObjectOrArrayLiteral;
		for (e in rangeOf(pattern.Elements())) {
			final name = e.PropertyNameOrName();
			if (Checker.hasDotDotDotToken(e)) {
				stringIndexInfo = c.newIndexInfo(c.stringType, c.anyType, false /*isReadonly*/, null, null);
				continue;
			}
			final exprType = c.getLiteralTypeFromPropertyName(name);
			if (!Checker.isTypeUsableAsPropertyName(exprType)) {
				// do not include computed properties in the implied type
				objectFlags |= ObjectFlagsObjectLiteralPatternWithComputedProperties;
				continue;
			}
			final text = Checker.getPropertyNameFromType(exprType);
			final flags:SymbolFlags = SymbolFlagsProperty | Core.IfElse(e.Initializer() != null, SymbolFlagsOptional, 0);
			final symbol = c.newSymbol(flags, text);
			c.valueSymbolLinks.Get(symbol).resolvedType = c.getTypeFromBindingElement(e, includePatternInType, reportErrors);
			members.set(symbol.Name, symbol);
		}
		var indexInfos:Array<IndexInfo> = null;
		if (stringIndexInfo != null) {
			indexInfos = [stringIndexInfo];
		}
		final result = c.newAnonymousType(null, members, null, null, indexInfos);
		result.objectFlags |= objectFlags;
		if (includePatternInType) {
			c.patternForType.set(result, pattern);
			result.objectFlags |= ObjectFlagsContainsObjectOrArrayLiteral;
		}
		return result;
	}

	// Return the type implied by an array binding pattern
	static function getTypeFromArrayBindingPattern(c:Checker, pattern:Node, includePatternInType:Bool, reportErrors:Bool):Type {
		final elements = pattern.Elements();
		final lastElement = Core.LastOrNil(elements);
		var restElement:Node = null;
		if (lastElement != null && Ast.IsBindingElement(lastElement) && Checker.hasDotDotDotToken(lastElement)) {
			restElement = lastElement;
		}
		if (Core.len(elements) == 0 || Core.len(elements) == 1 && restElement != null) {
			// TODO: remove ScriptTargetES2015
			if ((c.languageVersion : Int) >= (ScriptTargetES2015 : Int)) {
				return c.createIterableType(c.anyType);
			}
			return c.anyArrayType;
		}
		final minLength = Core.FindLastIndex(elements, function(e:Node):Bool {
			return !(e == restElement || e.Name() == null || c.hasDefaultValue(e));
		}) + 1;
		final elementTypes:Array<Type> = [for (_ in 0...elements.length) null];
		final elementInfos:Array<TupleElementInfo> = [for (_ in 0...elements.length) null];
		for (i in 0...elements.length) {
			final e = elements[i];
			var t:Type = null;
			if (e.Name() == null) {
				t = c.anyType;
			} else {
				t = c.getTypeFromBindingElement(e, includePatternInType, reportErrors);
			}
			var flags:ElementFlags = ElementFlagsNone;
			if (e == restElement) {
				flags = ElementFlagsRest;
			} else if (i >= minLength) {
				flags = ElementFlagsOptional;
			} else {
				flags = ElementFlagsRequired;
			}
			elementTypes[i] = t;
			final info = new TupleElementInfo();
			info.flags = flags;
			elementInfos[i] = info;
		}
		var result = c.createTupleTypeEx(elementTypes, elementInfos, false);
		if (includePatternInType) {
			result = c.cloneTypeReference(result);
			c.patternForType.set(result, pattern);
			result.objectFlags |= ObjectFlagsContainsObjectOrArrayLiteral;
		}
		return result;
	}

	// Return the type implied by a binding pattern element. This is the type of the initializer of the element if
	// one is present. Otherwise, if the element is itself a binding pattern, it is the type implied by the binding
	// pattern. Otherwise, it is the type any.
	static function getTypeFromBindingElement(c:Checker, element:Node, includePatternInType:Bool, reportErrors:Bool):Type {
		if (element.Initializer() != null) {
			// The type implied by a binding pattern is independent of context, so we check the initializer with no
			// contextual type or, if the element itself is a binding pattern, with the type implied by that binding
			// pattern.
			var contextualType = c.unknownType;
			if (Ast.IsBindingPattern(element.Name())) {
				contextualType = c.getTypeFromBindingPattern(element.Name(), true /*includePatternInType*/, false /*reportErrors*/);
			}
			return c.addOptionality(c.getWidenedLiteralTypeForInitializer(element, c.checkDeclarationInitializer(element, CheckModeNormal, contextualType)));
		}
		if (Ast.IsBindingPattern(element.Name())) {
			return c.getTypeFromBindingPattern(element.Name(), includePatternInType, reportErrors);
		}
		if (reportErrors && !c.declarationBelongsToPrivateAmbientMember(element)) {
			c.reportImplicitAny(element, c.anyType, WideningKindNormal);
		}
		// When we're including the pattern in the type (an indication we're obtaining a contextual type), we
		// use a non-inferrable any type. Inference will never directly infer this type, but it is possible
		// to infer a type that contains it, e.g. for a binding pattern like [foo] or { foo }. In such cases,
		// widening of the binding pattern type substitutes a regular any for the non-inferrable any.
		if (includePatternInType) {
			return c.nonInferrableAnyType;
		}
		return c.anyType;
	}

	static function declarationBelongsToPrivateAmbientMember(c:Checker, declaration:Node):Bool {
		var memberDeclaration = Ast.GetRootDeclaration(declaration);
		if (Ast.IsParameterDeclaration(memberDeclaration)) {
			memberDeclaration = memberDeclaration.Parent;
		}
		return Checker.isPrivateWithinAmbient(memberDeclaration);
	}

	static function getTypeOfPrototypeProperty(c:Checker, prototype:Symbol):Type {
		// TypeScript 1.0 spec (April 2014): 8.4
		// Every class automatically contains a static property member named 'prototype',
		// the type of which is an instantiation of the class type with type Any supplied as a type argument for each type parameter.
		// It is an error to explicitly declare a static property member with the name 'prototype'.
		final classType = c.getDeclaredTypeOfSymbol(c.getParentOfSymbol(prototype));
		final typeParameters = classType.AsInterfaceType().TypeParameters();
		if (Core.len(typeParameters) != 0) {
			return c.createTypeReference(classType, Core.Map(typeParameters, function(_:Type):Type {
				return c.anyType;
			}));
		}
		return classType;
	}

	static function getWidenedTypeForAssignmentDeclaration(c:Checker, symbol:Symbol):Type {
		var t:Type = null;
		final r = c.isConstructorDeclaredThisProperty(symbol);
		final kind = r.a;
		final location = r.b;
		switch (kind) {
			case thisAssignmentDeclarationTyped:
				if (location == null) {
					throw "location should not be nil when this assignment has a type.";
				}
				t = c.getTypeFromTypeNode(location);
			case thisAssignmentDeclarationConstructor:
				if (location == null) {
					throw "constructor should not be nil when this assignment is in a constructor.";
				}
				t = c.getFlowTypeInConstructor(symbol, location);
			case thisAssignmentDeclarationMethod:
				t = c.getTypeOfPropertyInBaseClass(symbol);
			default:
		}
		if (t == null) {
			var types:Array<Type> = null;
			final declarations = rangeOf(symbol.Declarations);
			for (i in 0...declarations.length) {
				final declaration = declarations[i];
				if (Ast.IsBinaryExpression(declaration) && declaration.Type() != null) {
					t = c.getTypeFromTypeNode(declaration.Type());
					break;
				}
				final assignedType = c.getAssignmentDeclarationInitializerType(declaration);
				if (assignedType != null) {
					// We ignore initial assignments of undefined to CommonJS exports when there are multiple assignment declarations
					if (Ast.GetAssignmentDeclarationKind(declaration) != JSDeclarationKindExportsProperty || i != 0 || Core.len(symbol.Declarations) == 1
						|| (assignedType.flags & TypeFlagsUndefined) == 0) {
						types = Core.AppendIfUnique(types, assignedType);
					}
				}
			}
			if (kind == thisAssignmentDeclarationMethod && Core.len(types) > 0) {
				if (c.strictNullChecks) {
					types = Core.AppendIfUnique(types, c.undefinedOrMissingType);
				}
			}
			if (t == null) {
				t = c.anyType;
				if (Core.len(types) != 0) {
					t = c.getUnionType(types);
				}
			}
		}
		t = c.getWidenedType(t);
		// report an all-nullable or empty union as an implicit any in JS files
		if (symbol.ValueDeclaration != null && Ast.IsInJSFile(symbol.ValueDeclaration)
			&& c.filterType(t, t -> (t.Flags() & ~TypeFlagsNullable) != 0) == c.neverType) {
			c.reportImplicitAny(symbol.ValueDeclaration, c.anyType, WideningKindNormal);
			return c.anyType;
		}
		return t;
	}

	static function getAssignmentDeclarationInitializerType(c:Checker, node:Node):Type {
		if (Ast.IsBinaryExpression(node)) {
			var t:Type = null;
			// PORT: Go `fallthrough` from the this-property case into the default case.
			switch (Ast.GetAssignmentDeclarationKind(node)) {
				case JSDeclarationKindModuleExports | JSDeclarationKindExportsProperty:
					t = c.getRegularTypeOfLiteralType(c.checkExpressionCached(Ast.GetRightMostAssignedExpression(node)));
				case JSDeclarationKindThisProperty:
					if (c.containsSameNamedThisProperty(node.AsBinaryExpression().Left, node.AsBinaryExpression().Right)) {
						return null;
					}
					t = c.checkExpressionForMutableLocation(node.AsBinaryExpression().Right, CheckModeNormal);
				default:
					t = c.checkExpressionForMutableLocation(node.AsBinaryExpression().Right, CheckModeNormal);
			}
			if (c.isEmptyArrayLiteralType(t) && !c.hasParentWithTypeAnnotation(node.Symbol())) {
				c.reportImplicitAny(node, c.anyArrayType, WideningKindNormal);
				return c.anyArrayType;
			}
			return t;
		}
		if (Ast.IsCallExpression(node)) {
			return c.getTypeFromPropertyDescriptor(node.Arguments()[2]);
		}
		return null;
	}

	// Return true if the parent symbol of the given assignment declaration symbol has declaration with a type
	// annotation. For example, returns true for the symbol associated with `f.a` below:
	//
	//	const f: { (): void, a: string[] } = () => {};
	//	f.a = [];
	static function hasParentWithTypeAnnotation(c:Checker, symbol:Symbol):Bool {
		if (symbol.Parent != null && symbol.Parent.ValueDeclaration != null && Ast.IsFunctionExpressionOrArrowFunction(symbol.Parent.ValueDeclaration)) {
			final possiblyAnnotatedSymbol = c.getSymbolOfNode(symbol.Parent.ValueDeclaration.Parent);
			if (possiblyAnnotatedSymbol != null && possiblyAnnotatedSymbol.ValueDeclaration != null) {
				return possiblyAnnotatedSymbol.ValueDeclaration.Type() != null;
			}
		}
		return false;
	}

	static function containsSameNamedThisProperty(c:Checker, thisProperty:Node, expression:Node):Bool {
		var visit:(Node) -> Bool = null;
		visit = function(node:Node):Bool {
			if (c.isMatchingReference(thisProperty, node)) {
				return true;
			}
			if (Ast.IsFunctionLike(node)) {
				return false;
			}
			return node.ForEachChild(visit);
		};
		return visit(expression);
	}

	static function getTypeFromPropertyDescriptor(c:Checker, node:Node):Type {
		final objectLiteralType = c.checkExpressionCached(node);
		final valueType = c.getTypeOfPropertyOfType(objectLiteralType, "value");
		if (valueType != null) {
			return valueType;
		}
		final getFunc = c.getTypeOfPropertyOfType(objectLiteralType, "get");
		if (getFunc != null) {
			final getSig = c.getSingleCallSignature(getFunc);
			if (getSig != null) {
				return c.getReturnTypeOfSignature(getSig);
			}
		}
		final setFunc = c.getTypeOfPropertyOfType(objectLiteralType, "set");
		if (setFunc != null) {
			final setSig = c.getSingleCallSignature(setFunc);
			if (setSig != null) {
				return c.getTypeOfFirstParameterOfSignature(setSig);
			}
		}
		return c.anyType;
	}

	// A property is considered a constructor declared property when all declaration sites are this.xxx assignments,
	// when no declaration sites have JSDoc type annotations, and when at least one declaration site is in the body of
	// a class constructor.
	static function isConstructorDeclaredThisProperty(c:Checker, symbol:Symbol):Pair<ThisAssignmentDeclarationKind, Node> {
		if (symbol.ValueDeclaration == null || !Ast.IsBinaryExpression(symbol.ValueDeclaration)) {
			return new Pair<ThisAssignmentDeclarationKind, Node>(thisAssignmentDeclarationNone, null);
		}
		if (c.thisExpandoKinds.exists(symbol)) {
			final kind = c.thisExpandoKinds.get(symbol);
			if (!c.thisExpandoLocations.exists(symbol)) {
				throw "location should be cached whenever this expando symbol is cached";
			}
			final location = c.thisExpandoLocations.get(symbol);
			return new Pair<ThisAssignmentDeclarationKind, Node>(kind, location);
		}
		var allThis = true;
		var typeAnnotation:Node = null;
		for (declaration in rangeOf(symbol.Declarations)) {
			if (!Ast.IsBinaryExpression(declaration)) {
				allThis = false;
				break;
			}
			final bin = declaration.AsBinaryExpression();
			if (Ast.GetAssignmentDeclarationKind(declaration) == JSDeclarationKindThisProperty
				&& (bin.Left.Kind != KindElementAccessExpression || Ast.IsStringOrNumericLiteralLike(bin.Left.AsElementAccessExpression().ArgumentExpression))) {
				if (bin.Type != null) {
					typeAnnotation = bin.Type;
				}
			} else {
				allThis = false;
				break;
			}
		}
		var location:Node = null;
		var kind = thisAssignmentDeclarationNone;
		if (allThis) {
			if (typeAnnotation != null) {
				location = typeAnnotation;
				kind = thisAssignmentDeclarationTyped;
			} else {
				location = c.getDeclaringConstructor(symbol);
				kind = Core.IfElse(location == null, thisAssignmentDeclarationMethod, thisAssignmentDeclarationConstructor);
			}
		}
		c.thisExpandoKinds.set(symbol, kind);
		c.thisExpandoLocations.set(symbol, location);
		return new Pair<ThisAssignmentDeclarationKind, Node>(kind, location);
	}

	static function isGlobalSymbolConstructor(c:Checker, node:Node):Bool {
		final symbol = c.getSymbolOfNode(node);
		final globalSymbol = c.getGlobalESSymbolConstructorTypeSymbolOrNil();
		return globalSymbol != null && symbol == globalSymbol;
	}

	static function widenTypeForVariableLikeDeclaration(c:Checker, t:Type, declaration:Node, reportErrors:Bool):Type {
		if (t != null) {
			// This special case is required for backwards compatibility with libraries that merge a `symbol` property into `SymbolConstructor`.
			// See https://github.com/microsoft/typescript-go/issues/1212
			if ((t.flags & TypeFlagsESSymbol) != 0 && c.isGlobalSymbolConstructor(declaration.Parent)) {
				t = c.getESSymbolLikeTypeForNode(declaration);
			}
			if (reportErrors) {
				c.reportErrorsFromWidening(declaration, t, WideningKindNormal);
			}
			// always widen a 'unique symbol' type if the type was created for a different declaration.
			if ((t.flags & TypeFlagsUniqueESSymbol) != 0 && (Ast.IsBindingElement(declaration) || declaration.Type() == null)
				&& t.symbol != c.getSymbolOfDeclaration(declaration)) {
				t = c.esSymbolType;
			}
			return c.getWidenedType(t);
		}
		// Rest parameters default to type any[], other parameters default to type any
		if (Ast.IsParameterDeclaration(declaration) && declaration.AsParameterDeclaration().DotDotDotToken != null) {
			t = c.anyArrayType;
		} else {
			t = c.anyType;
		}
		// Report implicit any errors unless this is a private property within an ambient declaration
		if (reportErrors) {
			if (!Checker.declarationBelongsToPrivateAmbientMember(declaration)) {
				c.reportImplicitAny(declaration, t, WideningKindNormal);
			}
		}
		return t;
	}

	static function reportImplicitAny(c:Checker, declaration:Node, t:Type, wideningKind:WideningKind):Void {
		if (Ast.IsInJSFile(declaration) && !Ast.IsCheckJSEnabledForFile(Ast.GetSourceFileOfNode(declaration), c.compilerOptions)) {
			// Only report implicit any errors/suggestions in TS and ts-check JS files
			return;
		}
		final typeAsString = c.TypeToString(c.getWidenedType(t));
		var diagnostic:Message = null;
		switch (declaration.Kind) {
			case KindBinaryExpression | KindPropertyDeclaration | KindPropertySignature:
				diagnostic = Core.IfElse(c.noImplicitAny, Diagnostics.Member_0_implicitly_has_an_1_type,
					Diagnostics.Member_0_implicitly_has_an_1_type_but_a_better_type_may_be_inferred_from_usage);
			case KindParameter:
				final param = declaration.AsParameterDeclaration();
				if (Ast.IsIdentifier(param.Name())) {
					final name = param.Name().AsIdentifier();
					final originalKeywordKind = Scanner.IdentifierToKeywordKind(name);
					if ((Ast.IsCallSignatureDeclaration(declaration.Parent) || Ast.IsMethodSignatureDeclaration(declaration.Parent)
						|| Ast.IsFunctionTypeNode(declaration.Parent))
						&& Slices.Contains(declaration.Parent.Parameters(), declaration)
						&& (Ast.IsTypeNodeKind(originalKeywordKind)
							|| c.resolveName(declaration, name.Text, SymbolFlagsType, null /*nameNotFoundMessage*/, true /*isUse*/, false /*excludeGlobals*/) != null)) {
						final newName = "arg" + Slices.Index(declaration.Parent.Parameters(), declaration);
						final typeName = Scanner.DeclarationNameToString(param.Name()) + Core.IfElse(param.DotDotDotToken != null, "[]", "");
						c.errorOrSuggestion(c.noImplicitAny, declaration, Diagnostics.Parameter_has_a_name_but_no_type_Did_you_mean_0_Colon_1, newName, typeName);
						return;
					}
				}
				if (param.DotDotDotToken != null) {
					if (c.noImplicitAny) {
						diagnostic = Diagnostics.Rest_parameter_0_implicitly_has_an_any_type;
					} else {
						diagnostic = Diagnostics.Rest_parameter_0_implicitly_has_an_any_type_but_a_better_type_may_be_inferred_from_usage;
					}
				} else if (c.noImplicitAny) {
					diagnostic = Diagnostics.Parameter_0_implicitly_has_an_1_type;
				} else {
					diagnostic = Diagnostics.Parameter_0_implicitly_has_an_1_type_but_a_better_type_may_be_inferred_from_usage;
				}
			case KindBindingElement:
				diagnostic = Diagnostics.Binding_element_0_implicitly_has_an_1_type;
				if (!c.noImplicitAny) {
					// Don't issue a suggestion for binding elements since the codefix doesn't yet support them.
					return;
				}
			case KindFunctionDeclaration | KindMethodDeclaration | KindMethodSignature | KindGetAccessor | KindSetAccessor | KindFunctionExpression | KindArrowFunction:
				if (c.noImplicitAny && declaration.Name() == null) {
					if (wideningKind == WideningKindGeneratorYield) {
						c.error(declaration, Diagnostics.Generator_implicitly_has_yield_type_0_Consider_supplying_a_return_type_annotation, typeAsString);
					} else {
						c.error(declaration, Diagnostics.Function_expression_which_lacks_return_type_annotation_implicitly_has_an_0_return_type, typeAsString);
					}
					return;
				}
				if (!c.noImplicitAny) {
					diagnostic = Diagnostics.X_0_implicitly_has_an_1_return_type_but_a_better_type_may_be_inferred_from_usage;
				} else if ((declaration.Flags & NodeFlagsReparsed) != 0) {
					c.error(declaration, Diagnostics.This_overload_implicitly_returns_the_type_0_because_it_lacks_a_return_type_annotation, typeAsString);
					return;
				} else if (wideningKind == WideningKindGeneratorYield) {
					diagnostic = Diagnostics.X_0_which_lacks_return_type_annotation_implicitly_has_an_1_yield_type;
				} else {
					diagnostic = Diagnostics.X_0_which_lacks_return_type_annotation_implicitly_has_an_1_return_type;
				}
			case KindMappedType:
				if (c.noImplicitAny) {
					c.error(declaration, Diagnostics.Mapped_object_type_implicitly_has_an_any_template_type);
				}
				return;
			default:
				if (c.noImplicitAny) {
					diagnostic = Diagnostics.Variable_0_implicitly_has_an_1_type;
				} else {
					diagnostic = Diagnostics.Variable_0_implicitly_has_an_1_type_but_a_better_type_may_be_inferred_from_usage;
				}
		}
		c.errorOrSuggestion(c.noImplicitAny, declaration, diagnostic, Scanner.DeclarationNameToString(Ast.GetNameOfDeclaration(declaration)), typeAsString);
	}

	static function getWidenedType(c:Checker, t:Type):Type {
		return c.getWidenedTypeWithContext(t, null /*context*/);
	}

	static function getWidenedTypeWithContext(c:Checker, t:Type, context:WideningContext):Type {
		if ((t.objectFlags & ObjectFlagsRequiresWidening) != 0) {
			if (context == null) {
				final cached = c.cachedTypes.get(CachedTypeKey.keyOf(CachedTypeKindWidened, t.id));
				if (cached != null) {
					return cached;
				}
			}
			var result:Type = null;
			if ((t.flags & (TypeFlagsAny | TypeFlagsNullable)) != 0) {
				result = c.anyType;
			} else if (Checker.isObjectLiteralType(t)) {
				result = c.getWidenedTypeOfObjectLiteral(t, context);
			} else if ((t.flags & TypeFlagsUnion) != 0) {
				var unionContext = context;
				if (unionContext == null) {
					unionContext = new WideningContext();
					unionContext.siblings = t.Types();
				}
				final widenedTypes = Core.SameMap(t.Types(), function(t:Type):Type {
					if ((t.flags & TypeFlagsNullable) != 0) {
						return t;
					}
					return c.getWidenedTypeWithContext(t, unionContext);
				});
				// Widening an empty object literal transitions from a highly restrictive type to
				// a highly inclusive one. For that reason we perform subtype reduction here if the
				// union includes empty object types (e.g. reducing {} | string to just {}).
				result = c.getUnionTypeEx(widenedTypes, Core.IfElse(Core.Some(widenedTypes, t -> c.isEmptyObjectType(t)), UnionReductionSubtype, UnionReductionLiteral),
					null, null);
			} else if ((t.flags & TypeFlagsIntersection) != 0) {
				result = c.getIntersectionType(Core.SameMap(t.Types(), t -> c.getWidenedType(t)));
			} else if (c.isArrayOrTupleType(t)) {
				result = c.createTypeReference(t.Target(), Core.SameMap(c.getTypeArguments(t), t -> c.getWidenedType(t)));
			}
			if (result != null && context == null) {
				c.cachedTypes.set(CachedTypeKey.keyOf(CachedTypeKindWidened, t.id), result);
			}
			return Core.OrElse(result, t);
		}
		return t;
	}

	static function getWidenedTypeOfObjectLiteral(c:Checker, t:Type, context:WideningContext):Type {
		if (context != null) {
			final cached = context.widenedTypes == null ? null : context.widenedTypes.get(t);
			if (cached != null) {
				return cached;
			}
		}
		final members = new SymbolTable();
		for (prop in rangeOf(c.getPropertiesOfObjectType(t))) {
			members.set(prop.Name, c.getWidenedProperty(prop, context));
		}
		if (context != null) {
			for (prop in rangeOf(c.getPropertiesOfContext(context))) {
				if (!members.exists(prop.Name)) {
					members.set(prop.Name, c.getUndefinedProperty(prop));
				}
			}
		}
		final result = c.newAnonymousType(t.symbol, members, null, null, Core.SameMap(c.getIndexInfosOfType(t), function(info:IndexInfo):IndexInfo {
			return c.newIndexInfo(info.keyType, c.getWidenedType(info.valueType), info.isReadonly, info.declaration, info.components);
		}));
		// Retain js literal flag through widening
		result.objectFlags |= t.objectFlags & (ObjectFlagsJSLiteral | ObjectFlagsNonInferrableType);
		// Only cache in child contexts since the root context never widens a particular object literal type more than once
		if (context != null && context.parent != null) {
			if (context.widenedTypes == null) {
				context.widenedTypes = new IdentityMap<Type, Type>();
			}
			context.widenedTypes.set(t, result);
		}
		return result;
	}

	static function getWidenedProperty(c:Checker, prop:Symbol, context:WideningContext):Symbol {
		if ((prop.Flags & SymbolFlagsProperty) == 0) {
			// Since get accessors already widen their return value there is no need to
			// widen accessor based properties here.
			return prop;
		}
		final original = c.getTypeOfSymbol(prop);
		var propContext:WideningContext = null;
		if (context != null) {
			propContext = context.getChildContext(prop.Name);
		}
		final widened = c.getWidenedTypeWithContext(original, propContext);
		if (widened == original) {
			return prop;
		}
		return c.createSymbolWithType(prop, widened);
	}

	static function getPropertiesOfContext(c:Checker, context:WideningContext):Array<Symbol> {
		if (context.resolvedProperties == null) {
			final names = new ts.collections.OrderedMap<std.String, Symbol>();
			for (t in rangeOf(c.getSiblingsOfContext(context))) {
				if (Checker.isObjectLiteralType(t) && (t.objectFlags & ObjectFlagsContainsSpread) == 0) {
					for (prop in rangeOf(c.getPropertiesOfType(t))) {
						names.Set(prop.Name, prop);
					}
				}
			}
			context.resolvedProperties = Slices.Collect(names.Values());
		}
		return context.resolvedProperties;
	}

	static function getSiblingsOfContext(c:Checker, context:WideningContext):Array<Type> {
		if (context.siblings == null) {
			final siblings:Array<Type> = [];
			for (t in rangeOf(c.getSiblingsOfContext(context.parent))) {
				if (Checker.isObjectLiteralType(t)) {
					final prop = c.getPropertyOfObjectType(t, context.propertyName);
					if (prop != null) {
						for (d in rangeOf(c.getTypeOfSymbol(prop).Distributed())) {
							siblings.push(d);
						}
					}
				}
			}
			context.siblings = siblings;
		}
		return context.siblings;
	}

	static function getUndefinedProperty(c:Checker, prop:Symbol):Symbol {
		final cached = c.undefinedProperties.get(prop.Name);
		if (cached != null) {
			return cached;
		}
		final result = c.createSymbolWithType(prop, c.undefinedOrMissingType);
		result.Flags |= SymbolFlagsOptional;
		c.undefinedProperties.set(prop.Name, result);
		return result;
	}

	static function getTypeOfEnumMember(c:Checker, symbol:Symbol):Type {
		final links = c.valueSymbolLinks.Get(symbol);
		if (links.resolvedType == null) {
			links.resolvedType = c.getDeclaredTypeOfEnumMember(symbol);
		}
		return links.resolvedType;
	}

	static function getTypeOfAccessors(c:Checker, symbol:Symbol):Type {
		final links = c.valueSymbolLinks.Get(symbol);
		if (links.resolvedType == null) {
			if (!c.pushTypeResolution(entity(symbol), TypeSystemPropertyNameType)) {
				return c.errorType;
			}
			final getter = Ast.GetDeclarationOfKind(symbol, KindGetAccessor);
			final setter = Ast.GetDeclarationOfKind(symbol, KindSetAccessor);
			final accessor = Core.Find(symbol.Declarations, fn_IsAutoAccessorPropertyDeclaration);
			// We try to resolve a getter type annotation, a setter type annotation, or a getter function
			// body return type inference, in that order.
			var t = c.getAnnotatedAccessorType(getter);
			if (t == null) {
				t = c.getAnnotatedAccessorType(setter);
			}
			if (t == null) {
				t = c.getAnnotatedAccessorType(accessor);
			}
			if (t == null && getter != null) {
				final body = getter.Body();
				if (body != null) {
					t = c.getReturnTypeFromBody(getter, CheckModeNormal);
				}
			}
			if (t == null && accessor != null) {
				t = c.getWidenedTypeForVariableLikeDeclaration(accessor, true /*reportErrors*/);
			}
			if (t == null) {
				if (setter != null && !Checker.isPrivateWithinAmbient(setter)) {
					c.errorOrSuggestion(c.noImplicitAny, setter,
						Diagnostics.Property_0_implicitly_has_type_any_because_its_set_accessor_lacks_a_parameter_type_annotation, c.symbolToString(symbol));
				} else if (getter != null && !Checker.isPrivateWithinAmbient(getter)) {
					c.errorOrSuggestion(c.noImplicitAny, getter,
						Diagnostics.Property_0_implicitly_has_type_any_because_its_get_accessor_lacks_a_return_type_annotation, c.symbolToString(symbol));
				} else if (accessor != null && !Checker.isPrivateWithinAmbient(accessor)) {
					c.errorOrSuggestion(c.noImplicitAny, accessor, Diagnostics.Member_0_implicitly_has_an_1_type, c.symbolToString(symbol), "any");
				}
				t = c.anyType;
			}
			if (!c.popTypeResolution()) {
				if (c.getAnnotatedAccessorTypeNode(getter) != null) {
					c.error(getter, Diagnostics.X_0_is_referenced_directly_or_indirectly_in_its_own_type_annotation, c.symbolToString(symbol));
				} else if (c.getAnnotatedAccessorTypeNode(setter) != null) {
					c.error(setter, Diagnostics.X_0_is_referenced_directly_or_indirectly_in_its_own_type_annotation, c.symbolToString(symbol));
				} else if (c.getAnnotatedAccessorTypeNode(accessor) != null) {
					c.error(setter, Diagnostics.X_0_is_referenced_directly_or_indirectly_in_its_own_type_annotation, c.symbolToString(symbol));
				} else if (getter != null && c.noImplicitAny) {
					c.error(getter,
						Diagnostics.X_0_implicitly_has_return_type_any_because_it_does_not_have_a_return_type_annotation_and_is_referenced_directly_or_indirectly_in_one_of_its_return_expressions,
						c.symbolToString(symbol));
				}
				t = c.anyType;
			}
			if (links.resolvedType == null) {
				links.resolvedType = t;
			}
		}
		return links.resolvedType;
	}

	static function getWriteTypeOfAccessors(c:Checker, symbol:Symbol):Type {
		final links = c.valueSymbolLinks.Get(symbol);
		if (links.writeType == null) {
			if (!c.pushTypeResolution(entity(symbol), TypeSystemPropertyNameWriteType)) {
				return c.errorType;
			}
			var setter = Ast.GetDeclarationOfKind(symbol, KindSetAccessor);
			if (setter == null) {
				final propDeclaration = Ast.GetDeclarationOfKind(symbol, KindPropertyDeclaration);
				if (propDeclaration != null && Ast.IsAutoAccessorPropertyDeclaration(propDeclaration)) {
					setter = propDeclaration;
				}
			}
			var writeType = c.getAnnotatedAccessorType(setter);
			if (!c.popTypeResolution()) {
				if (c.getAnnotatedAccessorTypeNode(setter) != null) {
					c.error(setter, Diagnostics.X_0_is_referenced_directly_or_indirectly_in_its_own_type_annotation, c.symbolToString(symbol));
				}
				writeType = c.anyType;
			}
			// Absent an explicit setter type annotation we use the read type of the accessor.
			if (links.writeType == null) {
				if (writeType != null) {
					links.writeType = writeType;
				} else {
					links.writeType = c.getTypeOfAccessors(symbol);
				}
			}
		}
		return links.writeType;
	}

	static function getTypeOfAlias(c:Checker, symbol:Symbol):Type {
		final links = c.valueSymbolLinks.Get(symbol);
		if (links.resolvedType == null) {
			if (!c.pushTypeResolution(entity(symbol), TypeSystemPropertyNameType)) {
				return c.errorType;
			}
			final targetSymbol = c.resolveAlias(symbol);
			final exportSymbol = c.getTargetOfAliasDeclaration(c.getDeclarationOfAliasSymbol(symbol));
			// It only makes sense to get the type of a value symbol. If the result of resolving
			// the alias is not a value, then it has no type. To get the type associated with a
			// type symbol, call getDeclaredTypeOfSymbol.
			// This check is important because without it, a call to getTypeOfSymbol could end
			// up recursively calling getTypeOfAlias, causing a stack overflow.
			if (links.resolvedType == null) {
				if ((c.getSymbolFlags(targetSymbol) & SymbolFlagsValue) != 0) {
					links.resolvedType = c.getTypeOfSymbol(targetSymbol);
				} else {
					links.resolvedType = c.errorType;
				}
			}
			if (!c.popTypeResolution()) {
				c.reportCircularityError(Core.OrElse(exportSymbol, symbol));
				if (links.resolvedType == null) {
					links.resolvedType = c.errorType;
				}
				return links.resolvedType;
			}
		}
		return links.resolvedType;
	}

	static function addOptionality(c:Checker, t:Type):Type {
		return c.addOptionalityEx(t, false /*isProperty*/, true /*isOptional*/);
	}

	static function addOptionalityEx(c:Checker, t:Type, isProperty:Bool, isOptional:Bool):Type {
		if (c.strictNullChecks && isOptional) {
			return c.getOptionalType(t, isProperty);
		}
		return t;
	}

	static function getOptionalType(c:Checker, t:Type, isProperty:Bool):Type {
		Debug.Assert(c.strictNullChecks);
		final missingOrUndefined = Core.IfElse(isProperty, c.undefinedOrMissingType, c.undefinedType);
		if (t == missingOrUndefined || (t.flags & TypeFlagsUnion) != 0 && t.Types()[0] == missingOrUndefined) {
			return t;
		}
		return c.getUnionType([t, missingOrUndefined]);
	}

	// Add undefined or null or both to a type if they are missing.
	static function getNullableType(c:Checker, t:Type, flags:TypeFlags):Type {
		final missing = (flags & ~t.flags) & (TypeFlagsUndefined | TypeFlagsNull);
		if (missing == 0) {
			return t;
		} else if (missing == TypeFlagsUndefined) {
			return c.getUnionType([t, c.undefinedType]);
		} else if (missing == TypeFlagsNull) {
			return c.getUnionType([t, c.nullType]);
		}
		return c.getUnionType([t, c.undefinedType, c.nullType]);
	}

	public static function GetNonNullableType(c:Checker, t:Type):Type {
		if (c.strictNullChecks) {
			return c.getAdjustedTypeWithFacts(t, TypeFactsNEUndefinedOrNull);
		}
		return t;
	}

	public static function IsNullableType(c:Checker, t:Type):Bool {
		return c.hasTypeFacts(t, TypeFactsIsUndefinedOrNull);
	}

	static function getNonNullableTypeIfNeeded(c:Checker, t:Type):Type {
		if (c.IsNullableType(t)) {
			return c.GetNonNullableType(t);
		}
		return t;
	}

	static function getDeclarationNodeFlagsFromSymbol(c:Checker, s:Symbol):NodeFlags {
		if (s.ValueDeclaration != null) {
			return c.getCombinedNodeFlagsCached(s.ValueDeclaration);
		}
		return NodeFlagsNone;
	}

	static function getCombinedNodeFlagsCached(c:Checker, node:Node):NodeFlags {
		// we hold onto the last node and result to speed up repeated lookups against the same node.
		if (c.lastGetCombinedNodeFlagsNode == node) {
			return c.lastGetCombinedNodeFlagsResult;
		}
		c.lastGetCombinedNodeFlagsNode = node;
		c.lastGetCombinedNodeFlagsResult = Ast.GetCombinedNodeFlags(node);
		return c.lastGetCombinedNodeFlagsResult;
	}

	static function isVarConstLike(c:Checker, node:Node):Bool {
		final blockScopeKind = c.getCombinedNodeFlagsCached(node) & NodeFlagsBlockScoped;
		return blockScopeKind == NodeFlagsConst || blockScopeKind == NodeFlagsUsing || blockScopeKind == NodeFlagsAwaitUsing;
	}

	static function getEffectivePropertyNameForPropertyNameNode(c:Checker, node:PropertyName):ValueOk<std.String> {
		final name = Ast.GetPropertyNameForPropertyNameNode(node);
		if (name != Ast.InternalSymbolNameMissing) {
			return new ValueOk(name, true);
		} else if (Ast.IsComputedPropertyName(node)) {
			return c.tryGetNameFromType(c.getTypeOfExpression(node.Expression()));
		}
		return new ValueOk("", false);
	}

	static function tryGetNameFromType(c:Checker, t:Type):ValueOk<std.String> {
		if ((t.flags & TypeFlagsUniqueESSymbol) != 0) {
			return new ValueOk(t.AsUniqueESSymbolType().name, true);
		} else if ((t.flags & TypeFlagsStringLiteral) != 0) {
			final s = Checker.getStringLiteralValue(t);
			return new ValueOk(s, true);
		} else if ((t.flags & TypeFlagsNumberLiteral) != 0) {
			final s = ts.jsnum.String_.String(Checker.getNumberLiteralValue(t));
			return new ValueOk(s, true);
		} else {
			return new ValueOk("", false);
		}
	}

	static function getCombinedModifierFlagsCached(c:Checker, node:Node):ModifierFlags {
		// we hold onto the last node and result to speed up repeated lookups against the same node.
		if (c.lastGetCombinedModifierFlagsNode == node) {
			return c.lastGetCombinedModifierFlagsResult;
		}
		c.lastGetCombinedModifierFlagsNode = node;
		c.lastGetCombinedModifierFlagsResult = Ast.GetCombinedModifierFlags(node);
		return c.lastGetCombinedModifierFlagsResult;
	}

	/**
	 * Push an entry on the type resolution stack. If an entry with the given target and the given property name
	 * is already on the stack, and no entries in between already have a type, then a circularity has occurred.
	 * In this case, the result values of the existing entry and all entries pushed after it are changed to false,
	 * and the value false is returned. Otherwise, the new entry is just pushed onto the stack, and true is returned.
	 * In order to see if the same query has already been done before, the target object and the propertyName both
	 * must match the one passed in.
	 *
	 * @param target The symbol, type, or signature whose type is being queried
	 * @param propertyName The property name that should be used to query the target for its type
	 */
	static function pushTypeResolution(c:Checker, target:TypeSystemEntity, propertyName:TypeSystemPropertyName):Bool {
		final resolutionCycleStartIndex = c.findResolutionCycleStartIndex(target, propertyName);
		if (resolutionCycleStartIndex >= 0) {
			// A cycle was found
			for (i in resolutionCycleStartIndex...c.typeResolutions.length) {
				c.typeResolutions[i].result = false;
			}
			return false;
		}
		final r = new TypeResolution();
		r.target = target;
		r.propertyName = propertyName;
		r.result = true;
		if (c.typeResolutions == null) {
			c.typeResolutions = [];
		}
		c.typeResolutions.push(r);
		return true;
	}

	/**
	 * Pop an entry from the type resolution stack and return its associated result value. The result value will
	 * be true if no circularities were detected, or false if a circularity was found.
	 */
	static function popTypeResolution(c:Checker):Bool {
		final lastIndex = c.typeResolutions.length - 1;
		final result = c.typeResolutions[lastIndex].result;
		// Clear the last entry to avoid memory leaks
		c.typeResolutions.pop();
		return result;
	}

	static function findResolutionCycleStartIndex(c:Checker, target:TypeSystemEntity, propertyName:TypeSystemPropertyName):Int {
		var i = Core.len(c.typeResolutions) - 1;
		while (i >= c.resolutionStart) {
			final resolution = c.typeResolutions[i];
			if (c.typeResolutionHasProperty(resolution)) {
				return -1;
			}
			if (resolution.target == target && resolution.propertyName == propertyName) {
				return i;
			}
			i--;
		}
		return -1;
	}

	static function typeResolutionHasProperty(c:Checker, r:TypeResolution):Bool {
		switch (r.propertyName) {
			case TypeSystemPropertyNameType:
				return c.valueSymbolLinks.Get((cast r.target : Symbol)).resolvedType != null;
			case TypeSystemPropertyNameDeclaredType:
				return c.typeAliasLinks.Get((cast r.target : Symbol)).declaredType != null;
			case TypeSystemPropertyNameResolvedTypeArguments:
				return (cast r.target : Type).AsTypeReference().resolvedTypeArguments != null;
			case TypeSystemPropertyNameResolvedBaseTypes:
				return (cast r.target : Type).AsInterfaceType().baseTypesResolved;
			case TypeSystemPropertyNameResolvedBaseConstructorType:
				return (cast r.target : Type).AsInterfaceType().resolvedBaseConstructorType != null;
			case TypeSystemPropertyNameResolvedReturnType:
				return (cast r.target : Signature).resolvedReturnType != null;
			case TypeSystemPropertyNameResolvedBaseConstraint:
				return (cast r.target : Type).AsConstrainedType().resolvedBaseConstraint != null;
			case TypeSystemPropertyNameInitializerIsUndefined:
				return (c.nodeLinks.Get((cast r.target : Node)).flags & NodeCheckFlagsInitializerIsUndefinedComputed) != 0;
			case TypeSystemPropertyNameWriteType:
				return c.valueSymbolLinks.Get((cast r.target : Symbol)).writeType != null;
			case TypeSystemPropertyNameAliasTarget:
				return c.aliasSymbolLinks.Get((cast r.target : Symbol)).aliasTarget != null;
			default:
		}
		throw "Unhandled case in typeResolutionHasProperty";
	}

	static function reportCircularityError(c:Checker, symbol:Symbol):Type {
		final declaration = symbol.ValueDeclaration;
		// Check if variable has type annotation that circularly references the variable itself
		if (declaration != null) {
			if (declaration.Type() != null) {
				c.error(symbol.ValueDeclaration, Diagnostics.X_0_is_referenced_directly_or_indirectly_in_its_own_type_annotation, c.symbolToString(symbol));
				return c.errorType;
			}
			// Check if variable has initializer that circularly references the variable itself
			if (c.noImplicitAny && (!Ast.IsParameterDeclaration(declaration) || declaration.Initializer() != null)) {
				c.error(symbol.ValueDeclaration,
					Diagnostics.X_0_implicitly_has_type_any_because_it_does_not_have_a_type_annotation_and_is_referenced_directly_or_indirectly_in_its_own_initializer,
					c.symbolToString(symbol));
			}
		} else if ((symbol.Flags & SymbolFlagsAlias) != 0) {
			final node = c.getDeclarationOfAliasSymbol(symbol);
			if (node != null) {
				c.error(node, Diagnostics.Circular_definition_of_import_alias_0, c.symbolToString(symbol));
			}
		}
		// Circularities could also result from parameters in function expressions that end up
		// having themselves as contextual types following type argument inference. In those cases
		// we have already reported an implicit any error so we don't report anything here.
		return c.anyType;
	}

	static function getPropertiesOfType(c:Checker, t:Type):Array<Symbol> {
		t = c.getReducedApparentType(t);
		if ((t.flags & TypeFlagsUnionOrIntersection) != 0) {
			return c.getPropertiesOfUnionOrIntersectionType(t);
		}
		return c.getPropertiesOfObjectType(t);
	}

	static function getPropertiesOfObjectType(c:Checker, t:Type):Array<Symbol> {
		if ((t.flags & TypeFlagsObject) != 0) {
			return c.resolveStructuredTypeMembers(t).properties;
		}
		return null;
	}

	static function getPropertiesOfUnionOrIntersectionType(c:Checker, t:Type):Array<Symbol> {
		final d = t.AsUnionOrIntersectionType();
		if (d.resolvedProperties == null) {
			final checked = new Set<std.String>();
			final props:Array<Symbol> = [];
			for (current in rangeOf(d.types)) {
				for (prop in rangeOf(c.getPropertiesOfType(current))) {
					if (!checked.Has(prop.Name)) {
						checked.Add(prop.Name);
						final combinedProp = c.getPropertyOfUnionOrIntersectionType(t, prop.Name,
							(t.flags & TypeFlagsIntersection) != 0 /*skipObjectFunctionPropertyAugment*/);
						if (combinedProp != null) {
							props.push(combinedProp);
						}
					}
				}
				// The properties of a union type are those that are present in all constituent types, so
				// we only need to check the properties of the first type without index signature
				if ((t.flags & TypeFlagsUnion) != 0 && Core.len(c.getIndexInfosOfType(current)) == 0) {
					break;
				}
			}
			d.resolvedProperties = props;
		}
		return d.resolvedProperties;
	}

	static function getPropertyOfType(c:Checker, t:Type, name:std.String):Symbol {
		return c.getPropertyOfTypeEx(t, name, false /*skipObjectFunctionPropertyAugment*/, false /*includeTypeOnlyMembers*/);
	}

	/**
	 * Return the symbol for the property with the given name in the given type. Creates synthetic union properties when
	 * necessary, maps primitive types and type parameters are to their apparent types, and augments with properties from
	 * Object and Function as appropriate.
	 *
	 * @param type a type to look up property from
	 * @param name a name of property to look up in a given type
	 */
	static function getPropertyOfTypeEx(c:Checker, t:Type, name:std.String, skipObjectFunctionPropertyAugment:Bool, includeTypeOnlyMembers:Bool):Symbol {
		t = c.getReducedApparentType(t);
		if ((t.flags & TypeFlagsObject) != 0) {
			final resolved = c.resolveStructuredTypeMembers(t);
			var symbol = symbolTableGet(resolved.members, name);
			if (symbol != null) {
				if (!includeTypeOnlyMembers && t.symbol != null && (t.symbol.Flags & SymbolFlagsValueModule) != 0) {
					final typeOnlyExportStarMap = c.moduleSymbolLinks.Get(t.symbol).typeOnlyExportStarMap;
					if (typeOnlyExportStarMap != null && typeOnlyExportStarMap.get(name) != null) {
						// If this is the type of a module, `resolved.members.get(name)` might have effectively skipped over
						// an `export type * from './foo'`, leaving `symbolIsValue` unable to see that the symbol is being
						// viewed through a type-only export.
						return null;
					}
				}
				if (c.symbolIsValueEx(symbol, includeTypeOnlyMembers)) {
					return symbol;
				}
			}
			if (skipObjectFunctionPropertyAugment) {
				return null;
			}
			var functionType:Type = null;
			if (t == c.anyFunctionType) {
				functionType = c.globalFunctionType;
			} else if (Core.len(resolved.CallSignatures()) != 0) {
				functionType = c.globalCallableFunctionType;
			} else if (Core.len(resolved.ConstructSignatures()) != 0) {
				functionType = c.globalNewableFunctionType;
			}
			if (functionType != null) {
				symbol = c.getPropertyOfObjectType(functionType, name);
				if (symbol != null) {
					return symbol;
				}
			}
			return c.getPropertyOfObjectType(c.globalObjectType, name);
		} else if ((t.flags & TypeFlagsIntersection) != 0) {
			final prop = c.getPropertyOfUnionOrIntersectionType(t, name, true /*skipObjectFunctionPropertyAugment*/);
			if (prop != null) {
				return prop;
			}
			if (!skipObjectFunctionPropertyAugment) {
				return c.getPropertyOfUnionOrIntersectionType(t, name, skipObjectFunctionPropertyAugment);
			}
			return null;
		} else if ((t.flags & TypeFlagsUnion) != 0) {
			return c.getPropertyOfUnionOrIntersectionType(t, name, skipObjectFunctionPropertyAugment);
		}
		return null;
	}

	// Return the type of the given property in the given type, or nil if no such property exists
	static function getTypeOfPropertyOfType(c:Checker, t:Type, name:std.String):Type {
		final prop = c.getPropertyOfType(t, name);
		if (prop != null) {
			return c.getTypeOfSymbol(prop);
		}
		return null;
	}

	static function getSignaturesOfType(c:Checker, t:Type, kind:SignatureKind):Array<Signature> {
		return c.getSignaturesOfStructuredType(c.getReducedApparentType(t), kind);
	}

	static function getSignaturesOfStructuredType(c:Checker, t:Type, kind:SignatureKind):Array<Signature> {
		if ((t.flags & TypeFlagsStructuredType) == 0) {
			return null;
		}
		final resolved = c.resolveStructuredTypeMembers(t);
		// PORT: Go returns a subslice view of resolved.signatures. When the view covers the whole slice the same array
		// is returned (as in Go, which shares the backing array); otherwise a copy of the range.
		final signatures = resolved.signatures;
		if (signatures == null) {
			return null;
		}
		if (kind == SignatureKindCall) {
			if (resolved.callSignatureCount == signatures.length) {
				return signatures;
			}
			return signatures.slice(0, resolved.callSignatureCount);
		}
		if (resolved.callSignatureCount == 0) {
			return signatures;
		}
		return signatures.slice(resolved.callSignatureCount);
	}

	static function getIndexInfosOfType(c:Checker, t:Type):Array<IndexInfo> {
		return c.getIndexInfosOfStructuredType(c.getReducedApparentType(t));
	}

	static function getIndexInfosOfStructuredType(c:Checker, t:Type):Array<IndexInfo> {
		if ((t.flags & TypeFlagsStructuredType) != 0) {
			return c.resolveStructuredTypeMembers(t).indexInfos;
		}
		return null;
	}

	// Return the indexing info of the given kind in the given type. Creates synthetic union index types when necessary and
	// maps primitive types and type parameters are to their apparent types.
	static function getIndexInfoOfType(c:Checker, t:Type, keyType:Type):IndexInfo {
		return Checker.findIndexInfo(c.getIndexInfosOfType(t), keyType);
	}

	// Return the index type of the given kind in the given type. Creates synthetic union index types when necessary and
	// maps primitive types and type parameters are to their apparent types.
	static function getIndexTypeOfType(c:Checker, t:Type, keyType:Type):Type {
		final info = c.getIndexInfoOfType(t, keyType);
		if (info != null) {
			return info.valueType;
		}
		return null;
	}

	static function getIndexTypeOfTypeEx(c:Checker, t:Type, keyType:Type, defaultType:Type):Type {
		final result = c.getIndexTypeOfType(t, keyType);
		if (result != null) {
			return result;
		}
		return defaultType;
	}

	static function getApplicableIndexInfo(c:Checker, t:Type, keyType:Type):IndexInfo {
		return c.findApplicableIndexInfo(c.getIndexInfosOfType(t), keyType);
	}

	static function getApplicableIndexInfoForName(c:Checker, t:Type, name:std.String):IndexInfo {
		if (Checker.isLateBoundName(name)) {
			return c.getApplicableIndexInfo(t, c.esSymbolType);
		}
		return c.getApplicableIndexInfo(t, c.getStringLiteralType(name));
	}

	static function findApplicableIndexInfo(c:Checker, indexInfos:Array<IndexInfo>, keyType:Type):IndexInfo {
		// Index signatures for type 'string' are considered only when no other index signatures apply.
		var stringIndexInfo:IndexInfo = null;
		final applicableInfos:Array<IndexInfo> = [];
		for (info in rangeOf(indexInfos)) {
			if (info.keyType == c.stringType) {
				stringIndexInfo = info;
			} else if (c.isApplicableIndexType(keyType, info.keyType)) {
				applicableInfos.push(info);
			}
		}
		// When more than one index signature is applicable we create a synthetic IndexInfo. Instead of computing
		// the intersected key type, we just use unknownType for the key type as nothing actually depends on the
		// keyType property of the returned IndexInfo.
		switch (applicableInfos.length) {
			case 0:
				if (stringIndexInfo != null && c.isApplicableIndexType(keyType, c.stringType)) {
					return stringIndexInfo;
				}
				return null;
			case 1:
				return applicableInfos[0];
			default:
				var isReadonly = true;
				final types:Array<Type> = [for (_ in 0...applicableInfos.length) null];
				for (i in 0...applicableInfos.length) {
					final info = applicableInfos[i];
					types[i] = info.valueType;
					if (!info.isReadonly) {
						isReadonly = false;
					}
				}
				return c.newIndexInfo(c.unknownType, c.getIntersectionType(types), isReadonly, null, null);
		}
	}

	static function isApplicableIndexType(c:Checker, source:Type, target:Type):Bool {
		// A 'string' index signature applies to types assignable to 'string' or 'number', and a 'number' index
		// signature applies to types assignable to 'number', `${number}` and numeric string literal types.
		return c.isTypeAssignableTo(source, target)
			|| target == c.stringType && c.isTypeAssignableTo(source, c.numberType)
			|| target == c.numberType
				&& (source == c.numericStringType || (source.flags & TypeFlagsStringLiteral) != 0 && Checker.isNumericLiteralName(Checker.getStringLiteralValue(source)));
	}

	static function resolveStructuredTypeMembers(c:Checker, t:Type):StructuredType {
		if ((t.objectFlags & ObjectFlagsMembersResolved) == 0) {
			if ((t.flags & TypeFlagsObject) != 0) {
				if ((t.objectFlags & ObjectFlagsReference) != 0) {
					c.resolveTypeReferenceMembers(t);
				} else if ((t.objectFlags & ObjectFlagsClassOrInterface) != 0) {
					c.resolveClassOrInterfaceMembers(t);
				} else if ((t.objectFlags & ObjectFlagsReverseMapped) != 0) {
					c.resolveReverseMappedTypeMembers(t);
				} else if ((t.objectFlags & ObjectFlagsAnonymous) != 0) {
					c.resolveAnonymousTypeMembers(t);
				} else if ((t.objectFlags & ObjectFlagsMapped) != 0) {
					c.resolveMappedTypeMembers(t);
				} else {
					throw "Unhandled case in resolveStructuredTypeMembers";
				}
			} else if ((t.flags & TypeFlagsUnion) != 0) {
				c.resolveUnionTypeMembers(t);
			} else if ((t.flags & TypeFlagsIntersection) != 0) {
				c.resolveIntersectionTypeMembers(t);
			} else {
				throw "Unhandled case in resolveStructuredTypeMembers";
			}
		}
		return t.AsStructuredType();
	}

	static function resolveClassOrInterfaceMembers(c:Checker, t:Type):Void {
		c.resolveObjectTypeMembers(t, t, null, null);
	}

	static function resolveTypeReferenceMembers(c:Checker, t:Type):Void {
		final source = t.Target();
		final typeParameters = source.AsInterfaceType().allTypeParameters;
		final typeArguments = c.getTypeArguments(t);
		var paddedTypeArguments = typeArguments;
		if (Core.len(typeArguments) == Core.len(typeParameters) - 1) {
			paddedTypeArguments = Core.Concatenate(typeArguments, [t]);
		}
		c.resolveObjectTypeMembers(t, source, typeParameters, paddedTypeArguments);
	}

	static function resolveObjectTypeMembers(c:Checker, t:Type, source:Type, typeParameters:Array<Type>, typeArguments:Array<Type>):Void {
		var mapper:TypeMapper = null;
		var members:SymbolTable = null;
		var callSignatures:Array<Signature> = null;
		var constructSignatures:Array<Signature> = null;
		var indexInfos:Array<IndexInfo> = null;
		var instantiated = false;
		final resolved = c.resolveDeclaredMembers(source);
		if (Slices.Equal(typeParameters, typeArguments)) {
			members = resolved.declaredMembers;
			callSignatures = resolved.declaredCallSignatures;
			constructSignatures = resolved.declaredConstructSignatures;
			indexInfos = resolved.declaredIndexInfos;
		} else {
			instantiated = true;
			mapper = Checker.newTypeMapper(typeParameters, typeArguments);
			members = c.instantiateSymbolTable(resolved.declaredMembers, mapper);
			callSignatures = c.instantiateSignatures(resolved.declaredCallSignatures, mapper);
			constructSignatures = c.instantiateSignatures(resolved.declaredConstructSignatures, mapper);
			indexInfos = c.instantiateIndexInfos(resolved.declaredIndexInfos, mapper);
		}
		final baseTypes = c.getBaseTypes(source);
		if (Core.len(baseTypes) != 0) {
			if (!instantiated) {
				members = members == null ? null : members.copy();
			}
			c.setStructuredTypeMembers(t, members, callSignatures, constructSignatures, indexInfos);
			final thisArgument = Core.LastOrNil(typeArguments);
			t.objectFlags |= ObjectFlagsUnresolvedMembers;
			for (baseType in baseTypes) {
				var instantiatedBaseType = baseType;
				if (thisArgument != null) {
					instantiatedBaseType = c.getTypeWithThisArgument(c.instantiateType(baseType, mapper), thisArgument, false /*needsApparentType*/);
				}
				members = c.addInheritedMembers(members, c.getPropertiesOfType(instantiatedBaseType));
				callSignatures = Core.Concatenate(callSignatures, c.getSignaturesOfType(instantiatedBaseType, SignatureKindCall));
				constructSignatures = Core.Concatenate(constructSignatures, c.getSignaturesOfType(instantiatedBaseType, SignatureKindConstruct));
				var inheritedIndexInfos:Array<IndexInfo> = null;
				if (instantiatedBaseType != c.anyType) {
					inheritedIndexInfos = c.getIndexInfosOfType(instantiatedBaseType);
				} else {
					inheritedIndexInfos = [c.anyBaseTypeIndexInfo];
				}
				final current = indexInfos;
				indexInfos = Core.Concatenate(indexInfos, Core.Filter(inheritedIndexInfos, function(info:IndexInfo):Bool {
					return Checker.findIndexInfo(current, info.keyType) == null;
				}));
			}
			t.objectFlags &= ~ObjectFlagsUnresolvedMembers;
		}
		c.setStructuredTypeMembers(t, members, callSignatures, constructSignatures, indexInfos);
	}

	static function getBaseTypes(c:Checker, t:Type):Array<Type> {
		if ((t.objectFlags & (ObjectFlagsClassOrInterface | ObjectFlagsTuple)) == 0) {
			return null;
		}
		final data = t.AsInterfaceType();
		if (!data.baseTypesResolved) {
			if (!c.pushTypeResolution(entity(t), TypeSystemPropertyNameResolvedBaseTypes)) {
				return data.resolvedBaseTypes;
			}
			if ((t.objectFlags & ObjectFlagsTuple) != 0) {
				data.resolvedBaseTypes = [c.getTupleBaseType(t)];
			} else if ((t.symbol.Flags & (SymbolFlagsClass | SymbolFlagsInterface)) != 0) {
				if ((t.symbol.Flags & SymbolFlagsClass) != 0) {
					c.resolveBaseTypesOfClass(t);
				}
				if ((t.symbol.Flags & SymbolFlagsInterface) != 0) {
					c.resolveBaseTypesOfInterface(t);
				}
			} else {
				throw "Unhandled case in getBaseTypes";
			}
			if (!c.popTypeResolution() && t.symbol.Declarations != null) {
				for (declaration in t.symbol.Declarations) {
					if (Ast.IsClassDeclaration(declaration) || Ast.IsInterfaceDeclaration(declaration)) {
						c.reportCircularBaseType(declaration, t);
					}
				}
			}
			// In general, base type resolution always precedes member resolution. However, it is possible
			// for resolution of type parameter defaults to cause circularity errors, possibly leaving
			// members partially resolved. Here we ensure any such partial resolution is reset.
			// See https://github.com/microsoft/TypeScript/issues/16861 for an example.
			t.objectFlags &= ~ObjectFlagsMembersResolved;
			data.baseTypesResolved = true;
		}
		return data.resolvedBaseTypes;
	}

	static function getTupleBaseType(c:Checker, t:Type):Type {
		final typeParameters = t.AsTupleType().TypeParameters();
		final elementInfos = t.AsTupleType().elementInfos;
		final elementTypes:Array<Type> = [for (_ in 0...Core.len(typeParameters)) null];
		for (i in 0...Core.len(typeParameters)) {
			final tp = typeParameters[i];
			if ((elementInfos[i].flags & ElementFlagsVariadic) != 0) {
				elementTypes[i] = c.getIndexedAccessType(tp, c.numberType);
			} else {
				elementTypes[i] = tp;
			}
		}
		return c.createArrayTypeEx(c.getUnionType(elementTypes), t.AsTupleType().readonly);
	}

	static function resolveBaseTypesOfClass(c:Checker, t:Type):Void {
		final baseConstructorType = c.getApparentType(c.getBaseConstructorTypeOfClass(t));
		if ((baseConstructorType.flags & (TypeFlagsObject | TypeFlagsIntersection | TypeFlagsAny)) == 0) {
			return;
		}
		final baseTypeNode = Checker.getBaseTypeNodeOfClass(t);
		var baseType:Type = null;
		var originalBaseType:Type = null;
		if (baseConstructorType.symbol != null) {
			originalBaseType = c.getDeclaredTypeOfSymbol(baseConstructorType.symbol);
		}
		if (baseConstructorType.symbol != null && (baseConstructorType.symbol.Flags & SymbolFlagsClass) != 0
			&& c.areAllOuterTypeParametersApplied(originalBaseType)) {
			// When base constructor type is a class with no captured type arguments we know that the constructors all have the same type parameters as the
			// class and all return the instance type of the class. There is no need for further checks and we can apply the
			// type arguments in the same manner as a type reference to get the same error reporting experience.
			baseType = c.getTypeFromClassOrInterfaceReference(baseTypeNode, baseConstructorType.symbol);
		} else if ((baseConstructorType.flags & TypeFlagsAny) != 0) {
			baseType = baseConstructorType;
		} else {
			// The class derives from a "class-like" constructor function, check that we have at least one construct signature
			// with a matching number of type parameters and use the return type of the first instantiated signature. Elsewhere
			// we check that all instantiated signatures return the same type.
			final constructors = c.getInstantiatedConstructorsForTypeArguments(baseConstructorType, baseTypeNode.TypeArguments(), baseTypeNode);
			if (Core.len(constructors) == 0) {
				c.error(baseTypeNode.Expression(), Diagnostics.No_base_constructor_has_the_specified_number_of_type_arguments);
				return;
			}
			baseType = c.getReturnTypeOfSignature(constructors[0]);
		}
		if (c.isErrorType(baseType)) {
			return;
		}
		final reducedBaseType = c.getReducedType(baseType);
		if (!c.isValidBaseType(reducedBaseType)) {
			final errorNode = baseTypeNode.Expression();
			var diagnostic = c.elaborateNeverIntersection(null, errorNode, baseType);
			diagnostic = Checker.NewDiagnosticChainForNode(diagnostic, errorNode,
				Diagnostics.Base_constructor_return_type_0_is_not_an_object_type_or_intersection_of_object_types_with_statically_known_members,
				c.TypeToString(reducedBaseType));
			c.addDiagnostic(diagnostic);
			return;
		}
		if (t == reducedBaseType || c.hasBaseType(reducedBaseType, t)) {
			c.error(t.symbol.ValueDeclaration, Diagnostics.Type_0_recursively_references_itself_as_a_base_type, c.TypeToString(t));
			return;
		}
		t.AsInterfaceType().resolvedBaseTypes = [reducedBaseType];
	}

	static function getInstantiatedConstructorsForTypeArguments(c:Checker, t:Type, typeArgumentNodes:Array<Node>, location:Node):Array<Signature> {
		final signatures = c.getConstructorsForTypeArguments(t, typeArgumentNodes, location);
		final typeArguments = Core.Map(typeArgumentNodes, n -> c.getTypeFromTypeNode(n));
		return Core.SameMap(signatures, function(sig:Signature):Signature {
			if (Core.len(sig.typeParameters) != 0) {
				return c.getSignatureInstantiation(sig, typeArguments, Ast.IsInJSFile(location), null);
			}
			return sig;
		});
	}

	static function getConstructorsForTypeArguments(c:Checker, t:Type, typeArgumentNodes:Array<Node>, location:Node):Array<Signature> {
		final typeArgCount = Core.len(typeArgumentNodes);
		return Core.Filter(c.getSignaturesOfType(t, SignatureKindConstruct), function(sig:Signature):Bool {
			return typeArgCount >= c.getMinTypeArgumentCount(sig.typeParameters) && typeArgCount <= Core.len(sig.typeParameters);
		});
	}

	static function getSignatureInstantiation(c:Checker, sig:Signature, typeArguments:Array<Type>, isJavaScript:Bool, inferredTypeParameters:Array<Type>):Signature {
		final instantiatedSignature = c.getSignatureInstantiationWithoutFillingInTypeArguments(sig,
			c.fillMissingTypeArguments(typeArguments, sig.typeParameters, c.getMinTypeArgumentCount(sig.typeParameters), isJavaScript));
		if (Core.len(inferredTypeParameters) != 0) {
			final returnSignature = c.getSingleCallOrConstructSignature(c.getReturnTypeOfSignature(instantiatedSignature));
			if (returnSignature != null) {
				final newReturnSignature = c.cloneSignature(returnSignature);
				newReturnSignature.typeParameters = inferredTypeParameters;
				final newReturnType = c.getOrCreateTypeFromSignature(newReturnSignature);
				newReturnType.AsObjectType().mapper = instantiatedSignature.mapper;
				final newInstantiatedSignature = c.cloneSignature(instantiatedSignature);
				newInstantiatedSignature.resolvedReturnType = newReturnType;
				return newInstantiatedSignature;
			}
		}
		return instantiatedSignature;
	}

	static function cloneSignature(c:Checker, sig:Signature):Signature {
		final result = c.newSignature(sig.flags & SignatureFlagsPropagatingFlags, sig.declaration, sig.typeParameters, sig.thisParameter, sig.parameters, null, null,
			sig.minArgumentCount);
		result.target = sig.target;
		result.mapper = sig.mapper;
		result.composite = sig.composite;
		return result;
	}

	static function getSignatureInstantiationWithoutFillingInTypeArguments(c:Checker, sig:Signature, typeArguments:Array<Type>):Signature {
		final key = CachedSignatureKey.keyOf(sig, Checker.getTypeListKey(typeArguments));
		var instantiation = c.cachedSignatures.get(key);
		if (instantiation == null) {
			instantiation = c.createSignatureInstantiation(sig, typeArguments);
			c.cachedSignatures.set(key, instantiation);
		}
		return instantiation;
	}

	static function createSignatureInstantiation(c:Checker, sig:Signature, typeArguments:Array<Type>):Signature {
		return c.instantiateSignatureEx(sig, c.createSignatureTypeMapper(sig, typeArguments), true /*eraseTypeParameters*/);
	}

	static function createSignatureTypeMapper(c:Checker, sig:Signature, typeArguments:Array<Type>):TypeMapper {
		return Checker.newTypeMapper(c.getTypeParametersForMapper(sig), typeArguments);
	}

	static function getTypeParametersForMapper(c:Checker, sig:Signature):Array<Type> {
		return Core.SameMap(sig.typeParameters, tp -> c.instantiateType(tp, tp.Mapper()));
	}

	// If type has a single call signature and no other members, return that signature. Otherwise, return nil.
	static function getSingleCallSignature(c:Checker, t:Type):Signature {
		return c.getSingleSignature(t, SignatureKindCall, false /*allowMembers*/);
	}

	static function getSingleCallOrConstructSignature(c:Checker, t:Type):Signature {
		final callSig = c.getSingleSignature(t, SignatureKindCall, false /*allowMembers*/);
		if (callSig != null) {
			return callSig;
		}
		return c.getSingleSignature(t, SignatureKindConstruct, false /*allowMembers*/);
	}

	static function getSingleSignature(c:Checker, t:Type, kind:SignatureKind, allowMembers:Bool):Signature {
		if ((t.flags & TypeFlagsObject) != 0) {
			final resolved = c.resolveStructuredTypeMembers(t);
			if (allowMembers || Core.len(resolved.properties) == 0 && Core.len(resolved.indexInfos) == 0) {
				if (kind == SignatureKindCall && Core.len(resolved.CallSignatures()) == 1 && Core.len(resolved.ConstructSignatures()) == 0) {
					return resolved.CallSignatures()[0];
				}
				if (kind == SignatureKindConstruct && Core.len(resolved.ConstructSignatures()) == 1 && Core.len(resolved.CallSignatures()) == 0) {
					return resolved.ConstructSignatures()[0];
				}
			}
		}
		return null;
	}

	static function getOrCreateTypeFromSignature(c:Checker, sig:Signature):Type {
		// There are two ways to declare a construct signature, one is by declaring a class constructor
		// using the constructor keyword, and the other is declaring a bare construct signature in an
		// object type literal or interface (using the new keyword). Each way of declaring a constructor
		// will result in a different declaration kind.
		if (sig.isolatedSignatureType == null) {
			var kind:Kind = KindUnknown;
			if (sig.declaration != null) {
				kind = sig.declaration.Kind;
			}
			// If declaration is undefined, it is likely to be the signature of the default constructor.
			final isConstructor = kind == KindUnknown || kind == KindConstructor || kind == KindConstructSignature || kind == KindConstructorType;
			var symbol:Symbol = null;
			if (sig.declaration != null) {
				symbol = sig.declaration.Symbol();
			}
			final t = c.newObjectType(ObjectFlagsAnonymous | ObjectFlagsSingleSignatureType, symbol);
			if (isConstructor) {
				c.setStructuredTypeMembers(t, null, null, [sig], null);
			} else {
				c.setStructuredTypeMembers(t, null, [sig], null, null);
			}
			sig.isolatedSignatureType = t;
		}
		return sig.isolatedSignatureType;
	}

	static function getErasedSignature(c:Checker, signature:Signature):Signature {
		if (Core.len(signature.typeParameters) == 0) {
			return signature;
		}
		final key = CachedSignatureKey.keyOf(signature, Checker.SignatureKeyErased);
		var erased = c.cachedSignatures.get(key);
		if (erased == null) {
			erased = c.instantiateSignatureEx(signature, Checker.newArrayToSingleTypeMapper(signature.typeParameters, c.anyType), true /*eraseTypeParameters*/);
			c.cachedSignatures.set(key, erased);
		}
		return erased;
	}

	static function getCanonicalSignature(c:Checker, signature:Signature):Signature {
		if (Core.len(signature.typeParameters) == 0) {
			return signature;
		}
		final key = CachedSignatureKey.keyOf(signature, Checker.SignatureKeyCanonical);
		var canonical = c.cachedSignatures.get(key);
		if (canonical == null) {
			canonical = c.createCanonicalSignature(signature);
			c.cachedSignatures.set(key, canonical);
		}
		return canonical;
	}

	static function createCanonicalSignature(c:Checker, signature:Signature):Signature {
		// Create an instantiation of the signature where each unconstrained type parameter is replaced with
		// its original. When a generic class or interface is instantiated, each generic method in the class or
		// interface is instantiated with a fresh set of cloned type parameters (which we need to handle scenarios
		// where different generations of the same type parameter are in scope). This leads to a lot of new type
		// identities, and potentially a lot of work comparing those identities, so here we create an instantiation
		// that uses the original type identities for all unconstrained type parameters.
		final typeArguments = Core.Map(signature.typeParameters, function(tp:Type):Type {
			if (tp.Target() != null && c.getConstraintOfTypeParameter(tp.Target()) == null) {
				return tp.Target();
			}
			return tp;
		});
		return c.getSignatureInstantiation(signature, typeArguments, Ast.IsInJSFile(signature.declaration), null /*inferredTypeParameters*/);
	}

	static function getBaseSignature(c:Checker, signature:Signature):Signature {
		final typeParameters = signature.typeParameters;
		if (Core.len(typeParameters) == 0) {
			return signature;
		}
		final key = CachedSignatureKey.keyOf(signature, Checker.SignatureKeyBase);
		final cached = c.cachedSignatures.get(key);
		if (cached != null) {
			return cached;
		}
		final baseConstraintMapper = Checker.newTypeMapper(typeParameters, Core.Map(typeParameters, function(tp:Type):Type {
			return Core.OrElse(c.getConstraintOfTypeParameter(tp), c.unknownType);
		}));
		var baseConstraints = Core.Map(typeParameters, function(tp:Type):Type {
			return c.instantiateType(tp, baseConstraintMapper);
		});
		// Run the immediate constraint mapper N-1 times so non-circular interdependent type parameters
		// resolve to their external dependencies without adding an extra expansion step for self-recursive constraints.
		for (_ in 0...typeParameters.length - 1) {
			baseConstraints = c.instantiateTypes(baseConstraints, baseConstraintMapper);
		}
		// and then apply a type eraser to remove any remaining circularly dependent type parameters
		baseConstraints = c.instantiateTypes(baseConstraints, Checker.newArrayToSingleTypeMapper(typeParameters, c.anyType));
		final result = c.instantiateSignatureEx(signature, Checker.newTypeMapper(typeParameters, baseConstraints), true /*eraseTypeParameters*/);
		c.cachedSignatures.set(key, result);
		return result;
	}

	// Instantiate a generic signature in the context of a non-generic signature (section 3.8.5 in TypeScript spec)
	static function instantiateSignatureInContextOf(c:Checker, signature:Signature, contextualSignature:Signature, inferenceContext:InferenceContext, compareTypes:TypeComparer):Signature {
		final context = c.newInferenceContext(c.getTypeParametersForMapper(signature), signature, InferenceFlagsNone, compareTypes);
		// We clone the inferenceContext to avoid fixing. For example, when the source signature is <T>(x: T) => T[] and
		// the contextual signature is (...args: A) => B, we want to infer the element type of A's constraint (say 'any')
		// for T but leave it possible to later infer '[any]' back to A.
		final restType = c.getEffectiveRestType(contextualSignature);
		var mapper:TypeMapper = null;
		if (inferenceContext != null) {
			if (restType != null && (restType.flags & TypeFlagsTypeParameter) != 0) {
				mapper = inferenceContext.nonFixingMapper;
			} else {
				mapper = inferenceContext.mapper;
			}
		}
		var sourceSignature:Signature = null;
		if (mapper != null) {
			sourceSignature = c.instantiateSignature(contextualSignature, mapper);
		} else {
			sourceSignature = contextualSignature;
		}
		c.applyToParameterTypes(sourceSignature, signature, function(source:Type, target:Type):Void {
			// Type parameters from outer context referenced by source type are fixed by instantiation of the source type
			c.inferTypes(context.inferences, source, target, InferencePriorityNone, false);
		});
		if (inferenceContext == null) {
			c.applyToReturnTypes(contextualSignature, signature, function(source:Type, target:Type):Void {
				c.inferTypes(context.inferences, source, target, InferencePriorityReturnType, false);
			});
		}
		return c.getSignatureInstantiation(signature, c.getInferredTypes(context), Ast.IsInJSFile(contextualSignature.declaration), null /*inferredTypeParameters*/);
	}

	static function resolveBaseTypesOfInterface(c:Checker, t:Type):Void {
		final data = t.AsInterfaceType();
		for (declaration in rangeOf(t.symbol.Declarations)) {
			if (Ast.IsInterfaceDeclaration(declaration)) {
				for (node in rangeOf(Ast.GetExtendsHeritageClauseElements(declaration))) {
					final baseType = c.getReducedType(c.getTypeFromTypeNode(node));
					if (!c.isErrorType(baseType)) {
						if (c.isValidBaseType(baseType)) {
							if (t != baseType && !c.hasBaseType(baseType, t)) {
								if (data.resolvedBaseTypes == null) {
									data.resolvedBaseTypes = [];
								}
								data.resolvedBaseTypes.push(baseType);
							} else {
								c.reportCircularBaseType(declaration, t);
							}
						} else {
							c.error(node, Diagnostics.An_interface_can_only_extend_an_object_type_or_intersection_of_object_types_with_statically_known_members);
						}
					}
				}
			}
		}
	}

	static function areAllOuterTypeParametersApplied(c:Checker, t:Type):Bool {
		// An unapplied type parameter has its symbol still the same as the matching argument symbol.
		// Since parameters are applied outer-to-inner, only the last outer parameter needs to be checked.
		final outerTypeParameters = t.AsInterfaceType().OuterTypeParameters();
		if (Core.len(outerTypeParameters) != 0) {
			final last = outerTypeParameters.length - 1;
			final typeArguments = c.getTypeArguments(t);
			return outerTypeParameters[last].symbol != typeArguments[last].symbol;
		}
		return true;
	}

	static function reportCircularBaseType(c:Checker, node:Node, t:Type):Void {
		c.error(node, Diagnostics.Type_0_recursively_references_itself_as_a_base_type, c.typeToStringEx(t, null, TypeFormatFlagsWriteArrayAsGenericType, null));
	}

	// A valid base type is `any`, an object type or intersection of object types.
	static function isValidBaseType(c:Checker, t:Type):Bool {
		if ((t.flags & TypeFlagsTypeParameter) != 0) {
			final constraint = c.getBaseConstraintOfType(t);
			if (constraint != null) {
				return c.isValidBaseType(constraint);
			}
		}
		// TODO: Given that we allow type parameters here now, is this `!isGenericMappedType(type)` check really needed?
		// There's no reason a `T` should be allowed while a `Readonly<T>` should not.
		return (t.flags & (TypeFlagsObject | TypeFlagsNonPrimitive | TypeFlagsAny)) != 0 && !c.isGenericMappedType(t)
			|| (t.flags & TypeFlagsIntersection) != 0 && Core.Every(t.Types(), t -> c.isValidBaseType(t));
	}

	// TODO: GH#18217 If `checkBase` is undefined, we should not call this because this will always return false.
	static function hasBaseType(c:Checker, t:Type, checkBase:Type):Bool {
		var check:(Type) -> Bool = null;
		check = function(t:Type):Bool {
			if ((t.objectFlags & (ObjectFlagsClassOrInterface | ObjectFlagsReference)) != 0) {
				final target = Checker.getTargetType(t);
				return target == checkBase || Core.Some(c.getBaseTypes(target), check);
			}
			if ((t.flags & TypeFlagsIntersection) != 0) {
				return Core.Some(t.Types(), check);
			}
			return false;
		};
		return check(t);
	}

	static function getTypeWithThisArgument(c:Checker, t:Type, thisArgument:Type, needApparentType:Bool):Type {
		if ((t.objectFlags & ObjectFlagsReference) != 0) {
			final target = t.Target();
			final typeArguments = c.getTypeArguments(t);
			if (Core.len(target.AsInterfaceType().TypeParameters()) == Core.len(typeArguments)) {
				if (thisArgument == null) {
					thisArgument = target.AsInterfaceType().thisType;
				}
				return c.createTypeReference(target, Core.Concatenate(typeArguments, [thisArgument]));
			}
			return t;
		} else if ((t.flags & TypeFlagsIntersection) != 0) {
			final types = t.Types();
			final newTypes = Core.SameMap(types, function(t:Type):Type {
				return c.getTypeWithThisArgument(t, thisArgument, needApparentType);
			});
			if (Core.Same(newTypes, types)) {
				return t;
			}
			return c.getIntersectionType(newTypes);
		}
		if (needApparentType) {
			return c.getApparentType(t);
		}
		return t;
	}

	static function addInheritedMembers(c:Checker, symbols:SymbolTable, baseSymbols:Array<Symbol>):SymbolTable {
		for (base in rangeOf(baseSymbols)) {
			if (!Checker.isStaticPrivateIdentifierProperty(base)) {
				final s = symbolTableGet(symbols, base.Name);
				final ok = symbols != null && symbols.exists(base.Name);
				if (!ok || (s.Flags & SymbolFlagsValue) == 0) {
					if (symbols == null) {
						symbols = new SymbolTable();
					}
					symbols.set(base.Name, base);
				}
			}
		}
		return symbols;
	}

	static function resolveDeclaredMembers(c:Checker, t:Type):InterfaceType {
		final d = t.AsInterfaceType();
		if (!d.declaredMembersResolved) {
			final members = c.getMembersOfSymbol(t.symbol);
			d.declaredMembersResolved = true;
			d.declaredMembers = members;
			d.declaredCallSignatures = c.getSignaturesOfSymbol(symbolTableGet(d.declaredMembers, Ast.InternalSymbolNameCall));
			d.declaredConstructSignatures = c.getSignaturesOfSymbol(symbolTableGet(d.declaredMembers, Ast.InternalSymbolNameNew));
			d.declaredIndexInfos = c.getIndexInfosOfSymbol(t.symbol);
		}
		return d;
	}

	static function getIndexInfosOfSymbol(c:Checker, symbol:Symbol):Array<IndexInfo> {
		final indexSymbol = c.getIndexSymbol(symbol);
		if (indexSymbol != null) {
			return c.getIndexInfosOfIndexSymbol(indexSymbol, symbolTableValues(c.getMembersOfSymbol(symbol)));
		}
		return null;
	}

	// note intentional similarities to index signature building in `checkObjectLiteral` for parity
	static function getIndexInfosOfIndexSymbol(c:Checker, indexSymbol:Symbol, siblingSymbols:Array<Symbol>):Array<IndexInfo> {
		var indexInfos:Array<IndexInfo> = null;
		var hasComputedStringProperty = false;
		var hasComputedNumberProperty = false;
		var hasComputedSymbolProperty = false;
		var readonlyComputedStringProperty = true;
		var readonlyComputedNumberProperty = true;
		var readonlyComputedSymbolProperty = true;
		var propertySymbols:Array<Symbol> = null;
		for (declaration in rangeOf(indexSymbol.Declarations)) {
			if (Ast.IsIndexSignatureDeclaration(declaration)) {
				final parameters = declaration.Parameters();
				final returnTypeNode = declaration.Type();
				if (Core.len(parameters) == 1) {
					final typeNode = parameters[0].Type();
					if (typeNode != null) {
						var valueType = c.anyType;
						if (returnTypeNode != null) {
							valueType = c.getTypeFromTypeNode(returnTypeNode);
						}
						Checker.forEachType(c.getTypeFromTypeNode(typeNode), function(keyType:Type):Void {
							if (c.isValidIndexKeyType(keyType) && Checker.findIndexInfo(indexInfos, keyType) == null) {
								final indexInfo = c.newIndexInfo(keyType, valueType, Ast.HasModifier(declaration, ModifierFlagsReadonly), declaration, null);
								if (indexInfos == null) {
									indexInfos = [];
								}
								indexInfos.push(indexInfo);
							}
						});
					}
				}
			} else if (c.hasLateBindableIndexSignature(declaration)) {
				var declName:Node = null;
				if (Ast.IsBinaryExpression(declaration)) {
					declName = declaration.AsBinaryExpression().Left;
				} else {
					declName = declaration.Name();
				}
				var keyType:Type = null;
				if (Ast.IsElementAccessExpression(declName)) {
					keyType = c.checkExpressionCached(declName.AsElementAccessExpression().ArgumentExpression);
				} else {
					keyType = c.checkComputedPropertyName(declName);
				}
				if (Checker.findIndexInfo(indexInfos, keyType) != null) {
					continue;
					// Explicit index for key type takes priority
				}
				if (c.isTypeAssignableTo(keyType, c.stringNumberSymbolType)) {
					if (c.isTypeAssignableTo(keyType, c.numberType)) {
						hasComputedNumberProperty = true;
						if (!Checker.hasReadonlyModifier(declaration)) {
							readonlyComputedNumberProperty = false;
						}
					} else if (c.isTypeAssignableTo(keyType, c.esSymbolType)) {
						hasComputedSymbolProperty = true;
						if (!Checker.hasReadonlyModifier(declaration)) {
							readonlyComputedSymbolProperty = false;
						}
					} else {
						hasComputedStringProperty = true;
						if (!Checker.hasReadonlyModifier(declaration)) {
							readonlyComputedStringProperty = false;
						}
					}
					if (propertySymbols == null) {
						propertySymbols = [];
					}
					propertySymbols.push(declaration.Symbol());
				}
			}
		}
		if (hasComputedStringProperty || hasComputedNumberProperty || hasComputedSymbolProperty) {
			for (sym in rangeOf(siblingSymbols)) {
				if (sym != indexSymbol) {
					if (propertySymbols == null) {
						propertySymbols = [];
					}
					propertySymbols.push(sym);
				}
			}
			// aggregate similar index infos implied to be the same key to the same combined index info
			if (hasComputedStringProperty && Checker.findIndexInfo(indexInfos, c.stringType) == null) {
				if (indexInfos == null) {
					indexInfos = [];
				}
				indexInfos.push(c.getObjectLiteralIndexInfo(readonlyComputedStringProperty, propertySymbols, c.stringType));
			}
			if (hasComputedNumberProperty && Checker.findIndexInfo(indexInfos, c.numberType) == null) {
				if (indexInfos == null) {
					indexInfos = [];
				}
				indexInfos.push(c.getObjectLiteralIndexInfo(readonlyComputedNumberProperty, propertySymbols, c.numberType));
			}
			if (hasComputedSymbolProperty && Checker.findIndexInfo(indexInfos, c.esSymbolType) == null) {
				if (indexInfos == null) {
					indexInfos = [];
				}
				indexInfos.push(c.getObjectLiteralIndexInfo(readonlyComputedSymbolProperty, propertySymbols, c.esSymbolType));
			}
		}
		return indexInfos;
	}

	// NOTE: currently does not make pattern literal indexers, eg `${number}px`
	static function getObjectLiteralIndexInfo(c:Checker, isReadonly:Bool, properties:Array<Symbol>, keyType:Type):IndexInfo {
		var propTypes:Array<Type> = null;
		var components:Array<Node> = null;
		for (prop in rangeOf(properties)) {
			if (keyType == c.stringType && !c.isSymbolWithSymbolName(prop)
				|| keyType == c.numberType && c.isSymbolWithNumericName(prop)
				|| keyType == c.esSymbolType && c.isSymbolWithSymbolName(prop)) {
				if (propTypes == null) {
					propTypes = [];
				}
				propTypes.push(c.getTypeOfSymbol(prop));
				if (c.isSymbolWithComputedName(prop)) {
					components = appendNode(components, prop.Declarations[0]);
				}
			}
		}
		var unionType = c.undefinedType;
		if (Core.len(propTypes) != 0) {
			unionType = c.getUnionTypeEx(propTypes, UnionReductionSubtype, null, null);
		}
		return c.newIndexInfo(keyType, unionType, isReadonly, null /*declaration*/, components);
	}

	static function isSymbolWithSymbolName(c:Checker, symbol:Symbol):Bool {
		if (Checker.IsKnownSymbol(symbol)) {
			return true;
		}
		if (Core.len(symbol.Declarations) != 0) {
			final name = symbol.Declarations[0].Name();
			return name != null && Ast.IsComputedPropertyName(name) && c.isTypeAssignableToKind(c.checkComputedPropertyName(name), TypeFlagsESSymbol);
		}
		return false;
	}

	static function isSymbolWithNumericName(c:Checker, symbol:Symbol):Bool {
		if (Checker.isNumericLiteralName(symbol.Name)) {
			return true;
		}
		if (Core.len(symbol.Declarations) != 0) {
			final name = symbol.Declarations[0].Name();
			return name != null && c.isNumericName(name);
		}
		return false;
	}

	static function isSymbolWithComputedName(c:Checker, symbol:Symbol):Bool {
		if (Core.len(symbol.Declarations) != 0) {
			final name = symbol.Declarations[0].Name();
			return name != null && Ast.IsComputedPropertyName(name);
		}
		return false;
	}

	static function isNumericName(c:Checker, name:Node):Bool {
		switch (name.Kind) {
			case KindComputedPropertyName:
				return c.isNumericComputedName(name);
			case KindIdentifier | KindNumericLiteral | KindStringLiteral:
				return Checker.isNumericLiteralName(name.Text());
			default:
		}
		return false;
	}

	static function isNumericComputedName(c:Checker, name:Node):Bool {
		// It seems odd to consider an expression of type Any to result in a numeric name,
		// but this behavior is consistent with checkIndexedAccess
		return c.isTypeAssignableToKind(c.checkComputedPropertyName(name), TypeFlagsNumberLike);
	}

	static function isValidIndexKeyType(c:Checker, t:Type):Bool {
		return (t.flags & (TypeFlagsString | TypeFlagsNumber | TypeFlagsESSymbol)) != 0
			|| c.isPatternLiteralType(t)
			|| (t.flags & TypeFlagsIntersection) != 0 && !c.isGenericType(t) && Core.Some(t.Types(), t -> c.isValidIndexKeyType(t));
	}

	static function findIndexInfo(c:Checker, indexInfos:Array<IndexInfo>, keyType:Type):IndexInfo {
		for (info in rangeOf(indexInfos)) {
			if (info.keyType == keyType) {
				return info;
			}
		}
		return null;
	}

	static function getIndexSymbol(c:Checker, symbol:Symbol):Symbol {
		return symbolTableGet(c.getMembersOfSymbol(symbol), Ast.InternalSymbolNameIndex);
	}

	static function getSignaturesOfSymbol(c:Checker, symbol:Symbol):Array<Signature> {
		if (symbol == null) {
			return null;
		}
		var result:Array<Signature> = null;
		final declarations = rangeOf(symbol.Declarations);
		for (i in 0...declarations.length) {
			final decl = declarations[i];
			if (!Ast.IsFunctionLike(decl)) {
				continue;
			}
			// Don't include signature if node is the implementation of an overloaded function. A node is considered
			// an implementation node if it has a body and the previous node is of the same kind and immediately
			// precedes the implementation node (i.e. has the same parent and ends where the implementation starts).
			if (i > 0 && decl.Body() != null) {
				final previous = declarations[i - 1];
				if (decl.Parent == previous.Parent && decl.Kind == previous.Kind
					&& (decl.Pos() == previous.End() || (previous.Flags & NodeFlagsReparsed) != 0)) {
					continue;
				}
			}
			// If this is a function or method declaration, get the signature from the @type tag for the sake of optional parameters.
			// Exclude contextually-typed kinds because we already apply the @type tag to the context, plus applying it here to the initializer would suppress checks that the two are compatible.
			var sig = c.getSignatureOfFullSignatureType(decl);
			if (sig == null) {
				sig = c.getSignatureFromDeclaration(decl);
			}
			if (result == null) {
				result = [];
			}
			result.push(sig);
		}
		return result;
	}

	static function getSignatureFromDeclaration(c:Checker, declaration:Node):Signature {
		final links = c.signatureLinks.Get(declaration);
		if (links.resolvedSignature != null) {
			return links.resolvedSignature;
		}
		var parameters:Array<Symbol> = null;
		var flags:SignatureFlags = SignatureFlagsNone;
		var thisParameter:Symbol = null;
		var minArgumentCount = 0;
		var hasThisParameter = false;
		final iife = Ast.GetImmediatelyInvokedFunctionExpression(declaration);
		final isUntypedSignatureInJSFile = iife == null
			&& Ast.IsInJSFile(declaration)
			&& (Ast.IsFunctionExpression(declaration) || Ast.IsArrowFunction(declaration) || Ast.IsMethodOrAccessor(declaration)
				|| Ast.IsFunctionDeclaration(declaration) || Ast.IsConstructorDeclaration(declaration))
			&& Core.Every(declaration.Parameters(), param -> param.Type() == null)
			&& c.getContextualType(declaration, ContextFlagsSignature) == null;
		if (isUntypedSignatureInJSFile) {
			flags |= SignatureFlagsIsUntypedSignatureInJSFile;
		}
		final params = rangeOf(declaration.Parameters());
		for (i in 0...params.length) {
			final param = params[i];
			var paramSymbol = param.Symbol();
			final typeNode = param.Type();
			// Include parameter symbol instead of property symbol in the signature
			if (paramSymbol != null && (paramSymbol.Flags & SymbolFlagsProperty) != 0 && !Ast.IsBindingPattern(param.Name())) {
				final resolvedSymbol = c.resolveName(param, paramSymbol.Name, SymbolFlagsValue, null /*nameNotFoundMessage*/, false /*isUse*/, false /*excludeGlobals*/);
				paramSymbol = resolvedSymbol;
			}
			if (i == 0 && paramSymbol.Name == Ast.InternalSymbolNameThis) {
				hasThisParameter = true;
				thisParameter = param.Symbol();
			} else {
				if (parameters == null) {
					parameters = [];
				}
				parameters.push(paramSymbol);
			}
			if (typeNode != null && typeNode.Kind == KindLiteralType) {
				flags |= SignatureFlagsHasLiteralTypes;
			}
			// Record a new minimum argument count if this is not an optional parameter
			final isOptionalParameter = Checker.isOptionalDeclaration(param)
				|| param.Initializer() != null
				|| Checker.isRestParameter(param)
				|| iife != null && Core.len(parameters) > Core.len(iife.Arguments()) && typeNode == null;
			if (!isOptionalParameter) {
				minArgumentCount = Core.len(parameters);
			}
		}
		// If only one accessor includes a this-type annotation, the other behaves as if it had the same type annotation
		if ((Ast.IsGetAccessorDeclaration(declaration) || Ast.IsSetAccessorDeclaration(declaration)) && c.hasBindableName(declaration)
			&& (!hasThisParameter || thisParameter == null)) {
			final otherKind = Core.IfElse(Ast.IsGetAccessorDeclaration(declaration), KindSetAccessor, KindGetAccessor);
			final other = Ast.GetDeclarationOfKind(c.getSymbolOfDeclaration(declaration), otherKind);
			if (other != null) {
				thisParameter = c.getAnnotatedAccessorThisParameter(other);
			}
		}
		var classType:Type = null;
		if (Ast.IsConstructorDeclaration(declaration)) {
			classType = c.getDeclaredTypeOfClassOrInterface(c.getMergedSymbol(declaration.Parent.Symbol()));
		}
		var typeParameters:Array<Type> = null;
		if (classType != null) {
			typeParameters = classType.AsInterfaceType().LocalTypeParameters();
		} else {
			typeParameters = c.getTypeParametersFromDeclaration(declaration);
		}
		if (Checker.hasRestParameter(declaration)) {
			flags |= SignatureFlagsHasRestParameter;
		}
		if (Ast.IsConstructorTypeNode(declaration) || Ast.IsConstructorDeclaration(declaration) || Ast.IsConstructSignatureDeclaration(declaration)) {
			flags |= SignatureFlagsConstruct;
		}
		if (Ast.IsConstructorTypeNode(declaration) && Ast.HasSyntacticModifier(declaration, ModifierFlagsAbstract)
			|| Ast.IsConstructorDeclaration(declaration) && Ast.HasSyntacticModifier(declaration.Parent, ModifierFlagsAbstract)) {
			flags |= SignatureFlagsAbstract;
		}
		links.resolvedSignature = c.newSignature(flags, declaration, typeParameters, thisParameter, parameters, null /*resolvedReturnType*/,
			null /*resolvedTypePredicate*/, minArgumentCount);
		return links.resolvedSignature;
	}

	static function getTypeParametersFromDeclaration(c:Checker, declaration:Node):Array<Type> {
		final sig = c.getSignatureOfFullSignatureType(declaration);
		if (sig != null) {
			return sig.TypeParameters();
		}
		var result:Array<Type> = null;
		for (node in rangeOf(declaration.TypeParameters())) {
			result = Core.AppendIfUnique(result, c.getDeclaredTypeOfTypeParameter(node.Symbol()));
		}
		return result;
	}

	static function getAnnotatedAccessorThisParameter(c:Checker, accessor:Node):Symbol {
		final parameter = c.getAccessorThisParameter(accessor);
		if (parameter != null) {
			return parameter.Symbol();
		}
		return null;
	}

	static function getAccessorThisParameter(c:Checker, accessor:Node):Node {
		if (Core.len(accessor.Parameters()) == Core.IfElse(Ast.IsGetAccessorDeclaration(accessor), 1, 2)) {
			return Ast.GetThisParameter(accessor);
		}
		return null;
	}

	/**
	 * Indicates whether a declaration has an early-bound name or a dynamic name that can be late-bound.
	 */
	static function hasBindableName(c:Checker, node:Node):Bool {
		return !Ast.HasDynamicName(node) || c.hasLateBindableName(node);
	}

	/**
	 * Indicates whether a declaration has a late-bindable dynamic name.
	 */
	static function hasLateBindableName(c:Checker, node:Node):Bool {
		final name = Ast.GetNameOfDeclaration(node);
		return name != null && c.isLateBindableName(name);
	}

	/**
	 * Indicates whether a declaration name is definitely late-bindable.
	 * A declaration name is only late-bindable if:
	 * - It is a `ComputedPropertyName`.
	 * - Its expression is an `Identifier` or either a `PropertyAccessExpression` an
	 * `ElementAccessExpression` consisting only of these same three types of nodes.
	 * - The type of its expression is a string or numeric literal type, or is a `unique symbol` type.
	 */
	static function isLateBindableName(c:Checker, node:Node):Bool {
		if (!Checker.isLateBindableAST(node)) {
			return false;
		}
		if (Ast.IsComputedPropertyName(node)) {
			return Checker.isTypeUsableAsPropertyName(c.checkComputedPropertyName(node));
		}
		return Checker.isTypeUsableAsPropertyName(c.checkExpressionCached(node.AsElementAccessExpression().ArgumentExpression));
	}

	static function hasLateBindableIndexSignature(c:Checker, node:Node):Bool {
		final name = Ast.GetNameOfDeclaration(node);
		return name != null && c.isLateBindableIndexSignature(name);
	}

	static function isLateBindableIndexSignature(c:Checker, node:Node):Bool {
		if (!Checker.isLateBindableAST(node)) {
			return false;
		}
		if (Ast.IsComputedPropertyName(node)) {
			return c.isTypeUsableAsIndexSignatureDeclaration(c.checkComputedPropertyName(node));
		}
		return c.isTypeUsableAsIndexSignatureDeclaration(c.checkExpressionCached(node.AsElementAccessExpression().ArgumentExpression));
	}

	static function isTypeUsableAsIndexSignatureDeclaration(c:Checker, t:Type):Bool {
		return c.isTypeAssignableTo(t, c.stringNumberSymbolType);
	}

	static function getReturnTypeOfSignature(c:Checker, sig:Signature):Type {
		if (sig.resolvedReturnType != null) {
			return sig.resolvedReturnType;
		}
		if (!c.pushTypeResolution(entity(sig), TypeSystemPropertyNameResolvedReturnType)) {
			return c.errorType;
		}
		var t:Type = null;
		if (sig.target != null) {
			t = c.instantiateType(c.getReturnTypeOfSignature(sig.target), sig.mapper);
		} else if (sig.composite != null) {
			t = c.instantiateType(c.getUnionOrIntersectionType(Core.Map(sig.composite.signatures, s -> c.getReturnTypeOfSignature(s)), sig.composite.isUnion,
				UnionReductionSubtype), sig.mapper);
		} else {
			t = c.getReturnTypeFromAnnotation(sig.declaration);
			if (t == null) {
				if (!Ast.NodeIsMissing(sig.declaration.Body())) {
					t = c.getReturnTypeFromBody(sig.declaration, CheckModeNormal);
				} else {
					t = c.anyType;
				}
			}
		}
		if ((sig.flags & SignatureFlagsIsInnerCallChain) != 0) {
			t = c.addOptionalTypeMarker(t);
		} else if ((sig.flags & SignatureFlagsIsOuterCallChain) != 0) {
			t = c.getOptionalType(t, false /*isProperty*/);
		}
		if (!c.popTypeResolution()) {
			if (sig.declaration != null) {
				final typeNode = sig.declaration.Type();
				if (typeNode != null) {
					c.error(typeNode, Diagnostics.Return_type_annotation_circularly_references_itself);
				} else if (c.noImplicitAny) {
					final name = Ast.GetNameOfDeclaration(sig.declaration);
					if (name != null) {
						c.error(name,
							Diagnostics.X_0_implicitly_has_return_type_any_because_it_does_not_have_a_return_type_annotation_and_is_referenced_directly_or_indirectly_in_one_of_its_return_expressions,
							Scanner.DeclarationNameToString(name));
					} else {
						c.error(sig.declaration,
							Diagnostics.Function_implicitly_has_return_type_any_because_it_does_not_have_a_return_type_annotation_and_is_referenced_directly_or_indirectly_in_one_of_its_return_expressions);
					}
				}
			}
			t = c.anyType;
		}
		if (sig.resolvedReturnType == null) {
			sig.resolvedReturnType = t;
		}
		return sig.resolvedReturnType;
	}
	// PORT: Go `range` over a possibly-nil slice (PORTING.md §3): a nil slice iterates zero times.
	static inline function rangeOf<T>(a:Null<Array<T>>):Array<T> {
		return a != null ? a : [];
	}
	
	// PORT: Go map lookup `table[name]` on a possibly-nil ast.SymbolTable (nil map reads as empty).
	static inline function symbolTableGet(table:SymbolTable, name:std.String):Symbol {
		return table != null ? table.get(name) : null;
	}
	
	// PORT: Go `len(table)` on a possibly-nil ast.SymbolTable.
	static function symbolTableLen(table:SymbolTable):Int {
		if (table == null) {
			return 0;
		}
		var n = 0;
		for (_ in table.keys()) {
			n++;
		}
		return n;
	}
	
	// PORT: Go `append(s, x)` on a possibly-nil []*ast.Node owned by the caller.
	static inline function appendNode(s:Array<Node>, x:Node):Array<Node> {
		if (s == null) {
			return [x];
		}
		s.push(x);
		return s;
	}
	
	// PORT: Go `append(symbol.Declarations, d)`: the slice may share its backing array with a cloned symbol
	// (cloneSymbol forces reallocation in Go), so the append never shows in another holder; copy first.
	static function appendDeclaration(s:Array<Node>, x:Node):Array<Node> {
		if (s == null) {
			return [x];
		}
		final r = s.copy();
		r.push(x);
		return r;
	}
	
	// PORT: Go TypeSystemEntity is `any`; the skeleton's empty interface is not declared by Symbol/Type/Signature,
	// so the value is passed through an unchecked cast (as in Relater.hx).
	static inline function entity(o:Dynamic):TypeSystemEntity {
		return cast o;
	}
	
	// PORT: method values created once (PORTING.md §7a).
	static final fn_isNotReplacableByMethod:(Node) -> Bool = decl -> Checker.isNotReplacableByMethod(decl);
	static final fn_IsAliasSymbolDeclaration:(Node) -> Bool = n -> Ast.IsAliasSymbolDeclaration(n);
	
	static final fn_IsClassStaticBlockDeclaration:(Node) -> Bool = n -> Ast.IsClassStaticBlockDeclaration(n);
	
	static final fn_isTupleType:(Type) -> Bool = t -> Checker.isTupleType(t);
	static final fn_IsAutoAccessorPropertyDeclaration:(Node) -> Bool = n -> Ast.IsAutoAccessorPropertyDeclaration(n);
	
	// PORT: Go untyped consts of ObjectFlags (types.go: ContainsSpread = 1 << 22, ObjectRestType = 1 << 23,
	// SingleSignatureType = 1 << 25, UnresolvedMembers = 1 << 29) are missing from the skeleton's ObjectFlags
	// (Types.hx, lane O5); local copies until they exist there.
	static inline final ObjectFlagsContainsSpread:ObjectFlags = 1 << 22;
	static inline final ObjectFlagsObjectRestType:ObjectFlags = 1 << 23;
	static inline final ObjectFlagsSingleSignatureType:ObjectFlags = 1 << 25;
	static inline final ObjectFlagsUnresolvedMembers:ObjectFlags = 1 << 29;
	
	// PORT: Go `slices.Collect(maps.Values(table))` on a possibly-nil ast.SymbolTable (nil for an empty table).
	static function symbolTableValues(table:SymbolTable):Array<Symbol> {
		if (table == null) {
			return null;
		}
		var result:Array<Symbol> = null;
		for (s in table) {
			if (result == null) {
				result = [];
			}
			result.push(s);
		}
		return result;
	}
	
}
