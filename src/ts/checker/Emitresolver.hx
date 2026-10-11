package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/emitresolver.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Links for jsx
@:allow(ts.checker)
class JSXLinks {
	var importRef:Node = null;

	public function new() {}
}

@:allow(ts.checker)
class DeclarationLinks {
	var isVisible:Tristate = 0; // if declaration is depended upon by exported declarations

	public function new() {}
}

@:allow(ts.checker)
class DeclarationFileLinks {
	var aliasesMarked:Bool = false; // if file has had alias visibility marked

	public function new() {}
}

@:allow(ts.checker)
class EmitResolver implements ReferenceResolver implements ts.printer.Emitresolver.EmitResolver {
	var checker:Checker = null;
	var checkerMu:Any /* sync.Mutex */ = null;
	var isValueAliasDeclaration:(node:Node) -> Bool = null;
	var aliasMarkingVisitor:(node:Node) -> Bool = null;
	var referenceResolver:ReferenceResolver = null;
	var jsxLinks:LinkStore<Node, JSXLinks> = new LinkStore<Node, JSXLinks>(() -> new JSXLinks());
	var declarationLinks:LinkStore<Node, DeclarationLinks> = new LinkStore<Node, DeclarationLinks>(() -> new DeclarationLinks());
	var declarationFileLinks:LinkStore<Node, DeclarationFileLinks> = new LinkStore<Node, DeclarationFileLinks>(() -> new DeclarationFileLinks());

	public function new() {}

	public function GetJsxFactoryEntity(location:Node):Node {
		// PORT: single-threaded — checkerMu.Lock/Unlock dropped throughout this file.
		return checker.getJsxFactoryEntity(location);
	}

	public function GetJsxFragmentFactoryEntity(location:Node):Node {
		return checker.getJsxFragmentFactoryEntity(location);
	}

	public function IsOptionalParameter(node:Node):Bool {
		return isOptionalParameter(node);
	}

	public function IsLateBound(node:Node):Bool {
		// TODO: Require an emitContext to construct an EmitResolver, remove all emitContext arguments
		// node = r.emitContext.ParseNode(node)
		if (node == null) {
			return false;
		}
		if (!Ast.IsParseTreeNode(node)) {
			return false;
		}
		final symbol = checker.getSymbolOfDeclaration(node);
		if (symbol == null) {
			return false;
		}
		return (symbol.CheckFlags & CheckFlagsLate) != 0;
	}

	public function GetEnumMemberValue(node:Node):Result {
		// node = r.emitContext.ParseNode(node)
		if (!Ast.IsParseTreeNode(node)) {
			return Evaluator.NewResult(null, false, false, false);
		}

		checker.computeEnumMemberValues(node.Parent);
		if (!checker.enumMemberLinks.Has(node)) {
			return Evaluator.NewResult(null, false, false, false);
		}
		return checker.enumMemberLinks.Get(node).value;
	}

	public function IsDeclarationVisible(node:Node):Bool {
		// Only lock on external API func to prevent deadlocks
		return isDeclarationVisible(node);
	}

	function isDeclarationVisible(node:Node):Bool {
		// node = r.emitContext.ParseNode(node)
		if (!Ast.IsParseTreeNode(node)) {
			return false;
		}
		if (node == null) {
			return false;
		}

		final links = declarationLinks.Get(node);
		if (links.isVisible == TSUnknown) {
			if (determineIfDeclarationIsVisible(node)) {
				links.isVisible = TSTrue;
			} else {
				links.isVisible = TSFalse;
			}
		}
		return links.isVisible == TSTrue;
	}

	function determineIfDeclarationIsVisible(node:Node):Bool {
		switch (node.Kind) {
			case KindJSDocCallbackTag,
				// ast.KindJSDocEnumTag, // !!! TODO: JSDoc @enum support?
				KindJSDocTypedefTag:
				// Top-level jsdoc type aliases are considered exported
				// First parent is comment node, second is hosting declaration or token; we only care about those tokens or declarations whose parent is a source file
				return node.Parent != null && node.Parent.Parent != null && node.Parent.Parent.Parent != null && Ast.IsSourceFile(node.Parent.Parent.Parent);
			case KindBindingElement:
				return isDeclarationVisible(node.Parent.Parent);
			case KindVariableDeclaration, KindModuleDeclaration, KindClassDeclaration, KindInterfaceDeclaration, KindTypeAliasDeclaration,
				KindJSTypeAliasDeclaration, KindFunctionDeclaration, KindEnumDeclaration, KindImportEqualsDeclaration:
				if (Ast.IsVariableDeclaration(node)) {
					if (Ast.IsBindingPattern(node.Name()) && Core.len(node.Name().Elements()) == 0) {
						// If the binding pattern is empty, this variable declaration is not visible
						return false;
					}
					// falls through
				}
				// External module augmentation is always visible
				// A @typedef at top-level in an external module is always visible
				if (Ast.IsExternalModuleAugmentation(node) || Ast.IsImplicitlyExportedJSDocDeclaration(node)) {
					return true;
				}
				final parent = Ast.GetDeclarationContainer(node);
				// If the node is not exported or it is not ambient module element (except import declaration)
				if ((checker.getCombinedModifierFlagsCached(node) & ModifierFlagsExport) == 0
					&& !(node.Kind != KindImportEqualsDeclaration && parent.Kind != KindSourceFile && (parent.Flags & NodeFlagsAmbient) != 0)) {
					return Ast.IsGlobalSourceFile(parent);
				}
				// Exported members/ambient module elements (exception import declaration) are visible if parent is visible
				return isDeclarationVisible(parent);

			case KindPropertyDeclaration, KindPropertySignature, KindGetAccessor, KindSetAccessor, KindMethodDeclaration, KindMethodSignature:
				if (checker.GetEffectiveDeclarationFlags(node, ModifierFlagsPrivate | ModifierFlagsProtected) != 0) {
					// Private/protected properties/methods are not visible
					return false;
				}
				// Public properties/methods are visible if its parents are visible, so:
				return isDeclarationVisible(node.Parent);

			case KindConstructor, KindConstructSignature, KindCallSignature, KindIndexSignature, KindParameter, KindModuleBlock, KindFunctionType,
				KindConstructorType, KindTypeLiteral, KindTypeReference, KindArrayType, KindTupleType, KindUnionType, KindIntersectionType,
				KindParenthesizedType, KindNamedTupleMember:
				return isDeclarationVisible(node.Parent);

			// Default binding, import specifier and namespace import is visible
			// only on demand so by default it is not visible
			case KindImportClause, KindNamespaceImport, KindImportSpecifier:
				return false;

			// Type parameters are always visible
			case KindTypeParameter:
				return true;
			// Source file and namespace export are always visible
			case KindSourceFile, KindNamespaceExportDeclaration:
				return true;

			// Export assignments do not create name bindings outside the module
			case KindExportAssignment:
				return false;

			// An `export {X}` (without a module specifier) is itself a visible re-export of
			// the named binding; it contributes to the symbol's external visibility.
			case KindExportSpecifier:
				final exportDecl = node.Parent.Parent;
				if (Ast.IsExportDeclaration(exportDecl) && exportDecl.AsExportDeclaration().ModuleSpecifier == null) {
					return isDeclarationVisible(exportDecl.Parent);
				}
				return false;

			default:
				return false;
		}
	}

	public function PrecalculateDeclarationEmitVisibility(file:SourceFile):Void {
		if (declarationFileLinks.Get(file.AsNode()).aliasesMarked) {
			return;
		}
		declarationFileLinks.Get(file.AsNode()).aliasesMarked = true;
		// TODO: Does this even *have* to be an upfront walk? If it's not possible for a
		// import a = a.b.c statement to chain into exposing a statement in a sibling scope,
		// it could at least be pushed into scope entry -  then it wouldn't need to be recursive.
		file.AsNode().ForEachChild(aliasMarkingVisitor);
	}

	function aliasMarkingVisitorWorker(node:Node):Bool {
		switch (node.Kind) {
			case KindBinaryExpression:
				if (Checker.isCommonJSModuleExports(node) && Ast.IsIdentifier(node.AsBinaryExpression().Right)) {
					markLinkedAliases(node.AsBinaryExpression().Right);
				}
			case KindExportAssignment:
				if (node.Expression().Kind == KindIdentifier) {
					markLinkedAliases(node.Expression());
				}
			case KindExportSpecifier:
				markLinkedAliases(node.PropertyNameOrName());
			default:
		}
		return node.ForEachChild(aliasMarkingVisitor);
	}

	// Sets the isVisible link on statements the Identifier or ExportName node points at
	// Follows chains of import d = a.b.c
	function markLinkedAliases(node:Node):Void {
		var exportSymbol:Symbol = null;
		if (node.Kind != KindStringLiteral && node.Parent != null && (Ast.IsExportAssignment(node.Parent) || Checker.isCommonJSModuleExports(node.Parent))) {
			exportSymbol = checker.resolveName(node, node.Text(), SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace | SymbolFlagsAlias, null /*nameNotFoundMessage*/,
				false /*isUse*/, false);
		} else if (node.Parent.Kind == KindExportSpecifier) {
			exportSymbol = checker.getTargetOfExportSpecifier(node.Parent, SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace | SymbolFlagsAlias, false);
		}

		final visited = new IntMap<Bool>(); // guard against circular imports
		while (exportSymbol != null) {
			final seen = visited.exists(Ast.GetSymbolId(exportSymbol));
			if (seen) {
				break;
			}
			visited.set(Ast.GetSymbolId(exportSymbol), true);

			var nextSymbol:Symbol = null;
			if (exportSymbol.Declarations != null) {
				for (declaration in exportSymbol.Declarations) {
					declarationLinks.Get(declaration).isVisible = TSTrue;

					if (Ast.IsInternalModuleImportEqualsDeclaration(declaration)) {
						// Add the referenced top container visible
						final internalModuleReference = declaration.AsImportEqualsDeclaration().ModuleReference;
						final firstIdentifier = Ast.GetFirstIdentifier(internalModuleReference);
						final importSymbol = checker.resolveName(declaration, firstIdentifier.Text(), SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace | SymbolFlagsAlias,
							null /*nameNotFoundMessage*/, false /*isUse*/, false);
						nextSymbol = importSymbol;
					}
				}
			}

			exportSymbol = nextSymbol;
		}
	}

	public function IsEntityNameVisible(entityName:Node, enclosingDeclaration:Node):SymbolAccessibilityResult {
		return isEntityNameVisible(entityName, enclosingDeclaration, true);
	}

	function isEntityNameVisible(entityName:Node, enclosingDeclaration:Node, shouldComputeAliasToMakeVisible:Bool):SymbolAccessibilityResult {
		// node = r.emitContext.ParseNode(entityName)
		if (!Ast.IsParseTreeNode(entityName)) {
			return newAccessibilityResult(SymbolAccessibilityNotAccessible, "", null);
		}

		final meaning = Checker.getMeaningOfEntityNameReference(entityName);
		final firstIdentifier = Ast.GetFirstIdentifier(entityName);

		final symbol = checker.resolveName(enclosingDeclaration, firstIdentifier.Text(), meaning, null, false, false);

		if (symbol != null && (symbol.Flags & SymbolFlagsTypeParameter) != 0 && (meaning & SymbolFlagsType) != 0) {
			return newAccessibilityResult(SymbolAccessibilityAccessible, "", null);
		}

		if (symbol == null && Ast.IsThisIdentifier(firstIdentifier)) {
			final sym = checker.getSymbolOfDeclaration(checker.getThisContainer(firstIdentifier, false, false));
			if (isSymbolAccessible(sym, enclosingDeclaration, meaning, false).Accessibility == SymbolAccessibilityAccessible) {
				return newAccessibilityResult(SymbolAccessibilityAccessible, "", null);
			}
		}

		if (symbol == null) {
			return newAccessibilityResult(SymbolAccessibilityNotResolved, firstIdentifier.Text(), firstIdentifier);
		}

		final visible = hasVisibleDeclarations(symbol, shouldComputeAliasToMakeVisible);
		if (visible != null) {
			return visible.copy();
		}

		return newAccessibilityResult(SymbolAccessibilityNotAccessible, firstIdentifier.Text(), firstIdentifier);
	}

	function hasVisibleDeclarations(symbol:Symbol, shouldComputeAliasToMakeVisible:Bool):SymbolAccessibilityResult {
		var aliasesToMakeVisibleSet:IntMap<Node> = null;

		var addVisibleAlias:(declaration:Node, aliasingStatement:Node) -> Void;
		if (shouldComputeAliasToMakeVisible) {
			addVisibleAlias = (declaration:Node, aliasingStatement:Node) -> {
				declarationLinks.Get(declaration).isVisible = TSTrue;
				if (aliasesToMakeVisibleSet == null) {
					aliasesToMakeVisibleSet = new IntMap<Node>();
				}
				aliasesToMakeVisibleSet.set(Ast.GetNodeId(declaration), aliasingStatement);
			};
		} else {
			addVisibleAlias = Checker.noopAddVisibleAlias;
		}

		if (symbol.Declarations != null) {
			for (declaration in symbol.Declarations) {
				if (Ast.IsIdentifier(declaration)) {
					continue;
				}
				if (!isDeclarationVisible(declaration)) {
					// Mark the unexported alias as visible if its parent is visible
					// because these kind of aliases can be used to name types in declaration file
					final anyImportSyntax = Checker.getAnyImportSyntax(declaration);
					if (anyImportSyntax != null && !Ast.HasSyntacticModifier(anyImportSyntax, ModifierFlagsExport) // import clause without export
						&& isDeclarationVisible(anyImportSyntax.Parent)) {
						addVisibleAlias(declaration, anyImportSyntax);
						continue;
					}
					if (Ast.IsVariableDeclaration(declaration) && Ast.IsVariableStatement(declaration.Parent.Parent)
						&& !Ast.HasSyntacticModifier(declaration.Parent.Parent, ModifierFlagsExport) // unexported variable statement
						&& isDeclarationVisible(declaration.Parent.Parent.Parent)) {
						addVisibleAlias(declaration, declaration.Parent.Parent);
						continue;
					}
					if (Ast.IsLateVisibilityPaintedStatement(declaration) // unexported top-level statement
						&& !Ast.HasSyntacticModifier(declaration, ModifierFlagsExport)
						&& isDeclarationVisible(declaration.Parent)) {
						addVisibleAlias(declaration, declaration);
						continue;
					}
					if (Ast.IsBindingElement(declaration)) {
						if ((symbol.Flags & SymbolFlagsAlias) != 0 && Ast.IsInJSFile(declaration) && declaration.Parent != null
							&& declaration.Parent.Parent != null // exported import-like top-level JS require statement
							&& Ast.IsVariableDeclaration(declaration.Parent.Parent)
							&& declaration.Parent.Parent.Parent.Parent != null && Ast.IsVariableStatement(declaration.Parent.Parent.Parent.Parent)
							&& !Ast.HasSyntacticModifier(declaration.Parent.Parent.Parent.Parent, ModifierFlagsExport)
							&& declaration.Parent.Parent.Parent.Parent.Parent != null // check if the thing containing the variable statement is visible (ie, the file)
							&& isDeclarationVisible(declaration.Parent.Parent.Parent.Parent.Parent)) {
							addVisibleAlias(declaration, declaration.Parent.Parent.Parent.Parent);
							continue;
						}
						if ((symbol.Flags & SymbolFlagsBlockScopedVariable) != 0) {
							final rootDeclaration = Ast.WalkUpBindingElementsAndPatterns(declaration);
							if (Ast.IsParameterDeclaration(rootDeclaration)) {
								return null;
							}
							final variableStatement = rootDeclaration.Parent.Parent;
							if (!Ast.IsVariableStatement(variableStatement)) {
								return null;
							}
							if (Ast.HasSyntacticModifier(variableStatement, ModifierFlagsExport)) {
								continue; // no alias to add, already exported
							}
							if (!isDeclarationVisible(variableStatement.Parent)) {
								return null; // not visible
							}
							addVisibleAlias(declaration, variableStatement);
							continue;
						}
					}

					// Declaration is not visible
					return null;
				}
			}
		}

		final result = new SymbolAccessibilityResult();
		result.Accessibility = SymbolAccessibilityAccessible;
		result.AliasesToMakeVisible = aliasesToMakeVisibleSet == null ? null : [for (v in aliasesToMakeVisibleSet) v];
		return result;
	}

	public function IsImplementationOfOverload(node:SignatureDeclaration):Bool {
		// node = r.emitContext.ParseNode(node)
		if (!Ast.IsParseTreeNode(node)) {
			return false;
		}
		if (Ast.NodeIsPresent(node.Body())) {
			if (Ast.IsGetAccessorDeclaration(node) || Ast.IsSetAccessorDeclaration(node)) {
				return false; // Get or set accessors can never be overload implementations, but can have up to 2 signatures
			}
			final symbol = checker.getSymbolOfDeclaration(node);
			final signaturesOfSymbol = checker.getSignaturesOfSymbol(symbol);
			// If this function body corresponds to function with multiple signature, it is implementation of overload
			// e.g.: function foo(a: string): string;
			//       function foo(a: number): number;
			//       function foo(a: any) { // This is implementation of the overloads
			//           return a;
			//       }
			if (Core.len(signaturesOfSymbol) > 1) {
				return true;
			}
			// If there is single signature for the symbol, it is overload if that signature isn't coming from the node
			// e.g.: function foo(a: string): string;
			//       function foo(a: any) { // This is implementation of the overloads
			//           return a;
			//       }
			if (Core.len(signaturesOfSymbol) == 1) {
				final declaration = signaturesOfSymbol[0].declaration;
				if (declaration != node && (declaration.Flags & NodeFlagsJSDoc) == 0) {
					return true;
				}
			}
		}
		return false;
	}

	public function IsImportRequiredByAugmentation(decl:ImportDeclaration):Bool {
		// node = r.emitContext.ParseNode(node)
		if (!Ast.IsParseTreeNode(decl.AsNode())) {
			return false;
		}
		final file = Ast.GetSourceFileOfNode(decl.AsNode());
		if (file.Symbol == null) {
			// script file
			return false;
		}
		final importTarget = GetExternalModuleFileFromDeclaration(decl.AsNode());
		if (importTarget == null) {
			return false;
		}
		if (importTarget == file) {
			return false;
		}
		final exports = checker.getExportsOfModule(file.Symbol);
		if (exports != null) {
			for (s in exports) {
				final merged = checker.getMergedSymbol(s);
				if (merged != s) {
					if (Core.len(merged.Declarations) > 0) {
						for (d in merged.Declarations) {
							final declFile = Ast.GetSourceFileOfNode(d);
							if (declFile == importTarget) {
								return true;
							}
						}
					}
				}
			}
		}
		return false;
	}

	public function IsDefinitelyReferenceToGlobalSymbolObject(node:Node):Bool {
		if (!Ast.IsPropertyAccessExpression(node)
			|| !Ast.IsIdentifier(node.Name())
			|| (!Ast.IsPropertyAccessExpression(node.Expression()) && !Ast.IsIdentifier(node.Expression()))) {
			return false;
		}
		if (node.Expression().Kind == KindIdentifier) {
			if (node.Expression().Text() != "Symbol") {
				return false;
			}
			// Exactly `Symbol.something` and `Symbol` either does not resolve or definitely resolves to the global Symbol
			return checker.getResolvedSymbol(node.Expression()) == checker.getGlobalSymbol("Symbol", SymbolFlagsValue | SymbolFlagsExportValue, null /*diagnostic*/);
		}
		if (node.Expression().Expression().Kind != KindIdentifier || node.Expression().Expression().Text() != "globalThis"
			|| node.Expression().Name().Text() != "Symbol") {
			return false;
		}
		// Exactly `globalThis.Symbol.something` and `globalThis` resolves to the global `globalThis`
		return checker.getResolvedSymbol(node.Expression().Expression()) == checker.globalThisSymbol;
	}

	public function RequiresAddingImplicitUndefined(declaration:Node, symbol:Symbol, enclosingDeclaration:Node):Bool {
		if (!Ast.IsParseTreeNode(declaration)) {
			return false;
		}
		return requiresAddingImplicitUndefined(declaration, symbol, enclosingDeclaration);
	}

	public function RequiresAddingImplicitUndefinedUnsafe(declaration:Node, symbol:Symbol, enclosingDeclaration:Node):Bool {
		if (!Ast.IsParseTreeNode(declaration)) {
			return false;
		}
		// NO LOCKING - only should be called in contexts that already have a checker lock
		return requiresAddingImplicitUndefined(declaration, symbol, enclosingDeclaration);
	}

	function requiresAddingImplicitUndefined(declaration:Node, symbol:Symbol, enclosingDeclaration:Node):Bool {
		// node = r.emitContext.ParseNode(node)
		if (!Ast.IsParseTreeNode(declaration)) {
			return false;
		}
		switch (declaration.Kind) {
			case KindPropertyDeclaration, KindPropertySignature, KindJSDocPropertyTag:
				if (symbol == null) {
					symbol = checker.getSymbolOfDeclaration(declaration);
				}
				final t = checker.getTypeOfSymbol(symbol);
				checker.mappedSymbolLinks.Has(symbol);
				return ((symbol.Flags & SymbolFlagsProperty) != 0) && ((symbol.Flags & SymbolFlagsOptional) != 0) && Checker.isOptionalDeclaration(declaration)
					&& checker.ReverseMappedSymbolLinks.Has(symbol) && checker.ReverseMappedSymbolLinks.Get(symbol).mappedType != null
					&& Checker.containsNonMissingUndefinedType(checker, t);
			case KindParameter, KindJSDocParameterTag:
				return requiresAddingImplicitUndefinedWorker(declaration, enclosingDeclaration);
			default:
				throw "Node cannot possibly require adding undefined";
		}
	}

	function requiresAddingImplicitUndefinedWorker(parameter:Node, enclosingDeclaration:Node):Bool {
		return (isRequiredInitializedParameter(parameter, enclosingDeclaration) || isOptionalUninitializedParameterProperty(parameter))
			&& !declaredParameterTypeContainsUndefined(parameter);
	}

	function declaredParameterTypeContainsUndefined(parameter:Node):Bool {
		// typeNode := getNonlocalEffectiveTypeAnnotationNode(parameter); // !!! JSDoc Support
		final typeNode = parameter.Type();
		if (typeNode == null) {
			return false;
		}
		final t = checker.getTypeFromTypeNode(typeNode);
		// allow error type here to avoid confusing errors that the annotation has to contain undefined when it does in cases like this:
		//
		// export function fn(x?: Unresolved | undefined): void {}
		return checker.isErrorType(t) || checker.containsUndefinedType(t);
	}

	function isOptionalUninitializedParameterProperty(parameter:Node):Bool {
		return checker.strictNullChecks && isOptionalParameter(parameter) && ( /*isJSDocParameterTag(parameter) ||*/ parameter.Initializer() == null) // !!! TODO: JSDoc support
			&& Ast.HasSyntacticModifier(parameter, ModifierFlagsParameterPropertyModifier);
	}

	function isRequiredInitializedParameter(parameter:Node, enclosingDeclaration:Node):Bool {
		if (!checker.strictNullChecks || isOptionalParameter(parameter) || /*isJSDocParameterTag(parameter) ||*/ parameter.Initializer() == null) { // !!! TODO: JSDoc Support
			return false;
		}
		if (Ast.HasSyntacticModifier(parameter, ModifierFlagsParameterPropertyModifier)) {
			return enclosingDeclaration != null && Ast.IsFunctionLikeDeclaration(enclosingDeclaration);
		}
		return true;
	}

	function isOptionalParameter(node:Node):Bool {
		return checker.isOptionalParameter(node);
	}

	public function IsLiteralConstDeclaration(node:Node):Bool {
		// node = r.emitContext.ParseNode(node)
		if (!Ast.IsParseTreeNode(node)) {
			return false;
		}
		if (Checker.isDeclarationReadonly(node) || (Ast.IsVariableDeclaration(node) && Ast.IsVarConst(node))) {
			return Checker.isFreshLiteralType(checker.getTypeOfSymbol(checker.getSymbolOfDeclaration(node)));
		}
		return false;
	}

	public function IsExpandoFunctionDeclarationUnsafe(node:Node):Bool {
		// node = r.emitContext.ParseNode(node)
		if (!Ast.IsParseTreeNode(node)) {
			return false;
		}
		// this is substantially different from strada, but so is expando property checking
		final props = GetPropertiesOfContainerFunction(node);
		if (props != null) {
			for (p in props) {
				if (Ast.IsExpandoPropertyDeclaration(p.ValueDeclaration)) {
					return true;
				}
			}
		}
		return false;
	}

	public function IsExpandoFunctionDeclaration(node:Node):Bool {
		return IsExpandoFunctionDeclarationUnsafe(node);
	}

	function isSymbolAccessible(symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags, shouldComputeAliasToMarkVisible:Bool):SymbolAccessibilityResult {
		return checker.IsSymbolAccessible(symbol, enclosingDeclaration, meaning, shouldComputeAliasToMarkVisible);
	}

	public function IsSymbolAccessible(symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags, shouldComputeAliasToMarkVisible:Bool):SymbolAccessibilityResult {
		// TODO: Split into locking and non-locking API methods - only current usage is the symbol tracker, which is non-locking,
		// as all tracker calls happen within a CreateX call below, which already holds a lock
		// r.checkerMu.Lock()
		// defer r.checkerMu.Unlock()
		return isSymbolAccessible(symbol, enclosingDeclaration, meaning, shouldComputeAliasToMarkVisible);
	}

	public function IsReferencedAliasDeclaration(node:Node):Bool {
		final c = checker;
		if (!c.canCollectSymbolAliasAccessibilityData || !Ast.IsParseTreeNode(node)) {
			return true;
		}

		if (Ast.IsAliasSymbolDeclaration(node)) {
			final symbol = c.getSymbolOfDeclaration(node);
			if (symbol != null) {
				final aliasLinks = c.aliasSymbolLinks.Get(symbol);
				if (aliasLinks.referenced) {
					return true;
				}
				final target = aliasLinks.aliasTarget;
				if (target != null && (node.ModifierFlags() & ModifierFlagsExport) != 0
					&& (c.getSymbolFlags(target) & SymbolFlagsValue) != 0
					&& (c.compilerOptions.ShouldPreserveConstEnums() || !Checker.isConstEnumOrConstEnumOnlyModule(target))) {
					return true;
				}
			}
		}
		return false;
	}

	public function IsValueAliasDeclaration(node:Node):Bool {
		final c = checker;
		if (!c.canCollectSymbolAliasAccessibilityData || !Ast.IsParseTreeNode(node)) {
			return true;
		}

		return isValueAliasDeclarationWorker(node);
	}

	function isValueAliasDeclarationWorker(node:Node):Bool {
		final c = checker;

		switch (node.Kind) {
			case KindImportEqualsDeclaration:
				return isAliasResolvedToValue(c.getSymbolOfDeclaration(node), false /*excludeTypeOnlyValues*/);
			case KindImportClause, KindNamespaceImport, KindImportSpecifier, KindExportSpecifier:
				final symbol = c.getSymbolOfDeclaration(node);
				return symbol != null && isAliasResolvedToValue(symbol, true /*excludeTypeOnlyValues*/);
			case KindExportDeclaration:
				final exportClause = node.AsExportDeclaration().ExportClause;
				return exportClause != null && (Ast.IsNamespaceExport(exportClause) || Core.Some(exportClause.Elements(), isValueAliasDeclaration));
			case KindExportAssignment:
				if (node.Expression() != null && node.Expression().Kind == KindIdentifier) {
					return isAliasResolvedToValue(c.getSymbolOfDeclaration(node), true /*excludeTypeOnlyValues*/);
				}
				return true;
			case KindBinaryExpression:
				if (Checker.isCommonJSModuleExports(node) && Ast.IsIdentifier(node.AsBinaryExpression().Right)) {
					return isAliasResolvedToValue(c.getSymbolOfDeclaration(node), true /*excludeTypeOnlyValues*/);
				}
			default:
		}
		return false;
	}

	function isAliasResolvedToValue(symbol:Symbol, excludeTypeOnlyValues:Bool):Bool {
		final c = checker;
		if (symbol == null) {
			return false;
		}
		if (symbol.ValueDeclaration != null) {
			final container = Ast.GetSourceFileOfNode(symbol.ValueDeclaration);
			if (container != null) {
				final fileSymbol = c.getSymbolOfDeclaration(container.AsNode());
				// Ensures cjs export assignment is setup, since this symbol may point at, and merge with, the file itself.
				// If we don't, the merge may not have yet occurred, and the flags check below will be missing flags that
				// are added as a result of the merge.
				c.resolveExternalModuleSymbol(fileSymbol, false /*dontResolveAlias*/);
			}
		}
		final target = c.getExportSymbolOfValueSymbolIfExported(c.resolveAlias(symbol));
		if (target == c.unknownSymbol) {
			return !excludeTypeOnlyValues || c.getTypeOnlyAliasDeclaration(symbol) == null;
		}
		// const enums and modules that contain only const enums are not considered values from the emit perspective
		// unless 'preserveConstEnums' option is set to true
		return (c.getSymbolFlagsEx(symbol, excludeTypeOnlyValues, true /*excludeLocalMeanings*/) & SymbolFlagsValue) != 0
			&& (c.compilerOptions.ShouldPreserveConstEnums() || !Checker.isConstEnumOrConstEnumOnlyModule(target));
	}

	public function IsTopLevelValueImportEqualsWithEntityName(node:Node):Bool {
		final c = checker;
		if (!c.canCollectSymbolAliasAccessibilityData) {
			return true;
		}
		if (!Ast.IsParseTreeNode(node) || node.Kind != KindImportEqualsDeclaration || node.Parent.Kind != KindSourceFile) {
			return false;
		}
		if (Ast.IsImportEqualsDeclaration(node)
			&& (Ast.NodeIsMissing(node.AsImportEqualsDeclaration().ModuleReference)
				|| node.AsImportEqualsDeclaration().ModuleReference.Kind == KindExternalModuleReference)) {
			return false;
		}

		return isAliasResolvedToValue(c.getSymbolOfDeclaration(node), false /*excludeTypeOnlyValues*/);
	}

	public function MarkLinkedReferencesRecursively(file:SourceFile):Void {
		if (!Ast.IsParseTreeNode(file.AsNode())) {
			return;
		}

		if (file != null) {
			var visit:Visitor = null;
			visit = (n:Node) -> {
				if (Ast.IsImportEqualsDeclaration(n) && (n.ModifierFlags() & ModifierFlagsExport) == 0) {
					return false; // These are deferred and marked in a chain when referenced
				}
				if (Ast.IsImportDeclaration(n)) {
					return false; // likewise, these are ultimately what get marked by calls on other nodes - we want to skip them
				}
				checker.markLinkedReferences(n, ReferenceHintUnspecified, null /*propSymbol*/, null /*parentType*/);
				n.ForEachChild(visit);
				return false;
			};
			file.AsNode().ForEachChild(visit);
		}
	}

	public function GetExternalModuleFileFromDeclaration(declaration:Node):SourceFile {
		if (!Ast.IsParseTreeNode(declaration)) {
			return null;
		}

		return checker.getExternalModuleFileFromDeclaration(declaration);
	}

	function getReferenceResolver():ReferenceResolver {
		if (referenceResolver == null) {
			final c = checker;
			final hooks = new ReferenceResolverHooks();
			hooks.ResolveName = c.nameResolver.Resolve; // PORT: perf (typed resolver hooks), see Checker.resolveName
			hooks.GetResolvedSymbol = (node:Node) -> c.getResolvedSymbolOrNil(node);
			hooks.GetMergedSymbol = (symbol:Symbol) -> c.getMergedSymbol(symbol);
			hooks.GetParentOfSymbol = (symbol:Symbol) -> c.getParentOfSymbol(symbol);
			hooks.GetSymbolOfDeclaration = (declaration:Node) -> c.getSymbolOfDeclaration(declaration);
			hooks.GetTypeOnlyAliasDeclaration = (symbol:Symbol, include:SymbolFlags) -> c.getTypeOnlyAliasDeclarationEx(symbol, include);
			hooks.GetExportSymbolOfValueSymbolIfExported = (symbol:Symbol) -> c.getExportSymbolOfValueSymbolIfExported(symbol);
			hooks.GetElementAccessExpressionName = (expression:ElementAccessExpression) -> c.tryGetElementAccessExpressionName(expression);
			referenceResolver = Binder.NewReferenceResolver(c.compilerOptions, hooks);
		}
		return referenceResolver;
	}

	public function GetReferencedExportContainer(node:IdentifierNode, prefixLocals:Bool):Node {
		if (!Ast.IsParseTreeNode(node)) {
			return null;
		}

		return getReferenceResolver().GetReferencedExportContainer(node, prefixLocals);
	}

	public function SetReferencedImportDeclaration(node:IdentifierNode, ref:Declaration):Void {
		jsxLinks.Get(node).importRef = ref;
	}

	public function GetReferencedImportDeclaration(node:IdentifierNode):Declaration {
		if (!Ast.IsParseTreeNode(node)) {
			return jsxLinks.Get(node).importRef;
		}

		final symbol = checker.getReferencedValueOrAliasSymbol(node);
		if (Ast.IsNonLocalAlias(symbol, SymbolFlagsValue) && checker.getTypeOnlyAliasDeclarationEx(symbol, SymbolFlagsValue) == null) {
			return checker.getDeclarationOfAliasSymbol(symbol);
		}
		return null;
	}

	public function GetReferencedValueDeclaration(node:IdentifierNode):Declaration {
		if (!Ast.IsParseTreeNode(node)) {
			return null;
		}

		return getReferenceResolver().GetReferencedValueDeclaration(node);
	}

	public function GetReferencedValueDeclarationUnsafe(node:IdentifierNode):Declaration {
		return getReferenceResolver().GetReferencedValueDeclaration(node);
	}

	public function GetReferencedValueDeclarations(node:IdentifierNode):Array<Declaration> {
		if (!Ast.IsParseTreeNode(node)) {
			return null;
		}

		return getReferenceResolver().GetReferencedValueDeclarations(node);
	}

	// IsNameResolvable returns `true` if the given `name` resolves to any symbol at `location`
	public function IsNameResolvable(location:Node, name:std.String):Bool {
		final symbol = checker.resolveName(location, name, SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace, null /*nameNotFoundMessage*/, false /*isUse*/,
			false /*excludeGlobals*/);
		return symbol != null;
	}

	public function GetElementAccessExpressionName(expression:ElementAccessExpression):std.String {
		if (!Ast.IsParseTreeNode(expression.AsNode())) {
			return "";
		}

		return getReferenceResolver().GetElementAccessExpressionName(expression);
	}

	public function GetReferencedMemberValueDeclaration(node:Node):Declaration {
		if (!Ast.IsParseTreeNode(node)) {
			return null;
		}

		return getReferenceResolver().GetReferencedMemberValueDeclaration(node);
	}

	public function CreateReturnTypeOfSignatureDeclaration(emitContext:EmitContext, signatureDeclaration:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		final original = emitContext.ParseNode(signatureDeclaration);
		if (original == null) {
			return emitContext.Factory.NewKeywordTypeNode(KindAnyKeyword);
		}

		final requestNodeBuilder = Checker.NewNodeBuilder(checker, emitContext); // TODO: cache per-context
		return requestNodeBuilder.SerializeReturnTypeForSignature(original, enclosingDeclaration, flags, internalFlags, tracker);
	}

	public function CreateTypeParametersOfSignatureDeclaration(emitContext:EmitContext, signatureDeclaration:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Array<Node> {
		final original = emitContext.ParseNode(signatureDeclaration);
		if (original == null) {
			return null;
		}

		final requestNodeBuilder = Checker.NewNodeBuilder(checker, emitContext); // TODO: cache per-context
		return requestNodeBuilder.SerializeTypeParametersForSignature(original, enclosingDeclaration, flags, internalFlags, tracker);
	}

	public function CreateTypeOfDeclaration(emitContext:EmitContext, declaration:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		final original = emitContext.ParseNode(declaration);
		if (original == null) {
			return emitContext.Factory.NewKeywordTypeNode(KindAnyKeyword);
		}

		final requestNodeBuilder = Checker.NewNodeBuilder(checker, emitContext); // TODO: cache per-context
		// // Get type of the symbol if this is the valid symbol otherwise get type at location
		final symbol = checker.getSymbolOfDeclaration(declaration);
		return requestNodeBuilder.SerializeTypeForDeclaration(declaration, symbol, enclosingDeclaration, flags | FlagsMultilineObjectLiterals, internalFlags, tracker);
	}

	public function CreateLiteralConstValue(emitContext:EmitContext, node:Node, tracker:SymbolTracker):Node {
		node = emitContext.ParseNode(node);
		final t = checker.getTypeOfSymbol(checker.getSymbolOfDeclaration(node));
		if (t == null) {
			return null; // TODO: How!? Maybe this should be a panic. All symbols should have a type.
		}

		var enumResult:Node = null;
		if ((t.flags & TypeFlagsEnumLike) != 0) {
			final requestNodeBuilder = Checker.NewNodeBuilder(checker, emitContext); // TODO: cache per-context
			enumResult = requestNodeBuilder.SymbolToExpression(t.symbol, SymbolFlagsValue, node, FlagsNone, InternalFlagsNone, tracker);
			// What about regularTrueType/regularFalseType - since those aren't fresh, we never make initializers from them
			// TODO: handle those if this function is ever used for more than initializers in declaration emit
		} else if (t == checker.trueType) {
			enumResult = emitContext.Factory.NewKeywordExpression(KindTrueKeyword);
		} else if (t == checker.falseType) {
			enumResult = emitContext.Factory.NewKeywordExpression(KindFalseKeyword);
		}
		if (enumResult != null) {
			return enumResult;
		}
		if ((t.flags & TypeFlagsLiteral) == 0) {
			return null; // non-literal type
		}
		final value:Any = t.AsLiteralType().value;
		if (Std.isOfType(value, std.String)) {
			return emitContext.Factory.NewStringLiteral((value : std.String), TokenFlagsNone);
		} else if (Std.isOfType(value, Float)) {
			final value:ts.jsnum.Jsnum.Number = (value : Float);
			if (value.IsInf()) {
				if (value > 0) {
					return emitContext.Factory.NewIdentifier("Infinity");
				}
				return emitContext.Factory.NewPrefixUnaryExpression(KindMinusToken, emitContext.Factory.NewIdentifier("Infinity"));
			}
			if (value.IsNaN()) {
				return emitContext.Factory.NewIdentifier("NaN");
			}
			if (value.Abs() != value) {
				// negative
				return emitContext.Factory.NewPrefixUnaryExpression(KindMinusToken,
					emitContext.Factory.NewNumericLiteral(ts.jsnum.String_.String(value).substring(1), TokenFlagsNone));
			}
			return emitContext.Factory.NewNumericLiteral(ts.jsnum.String_.String(value), TokenFlagsNone);
		} else if (Std.isOfType(value, PseudoBigInt)) {
			return emitContext.Factory.NewBigIntLiteral(Checker.pseudoBigIntToString((value : PseudoBigInt)) + "n", TokenFlagsNone);
		} else if (Std.isOfType(value, Bool)) {
			var kind = KindFalseKeyword;
			if ((value : Bool)) {
				kind = KindTrueKeyword;
			}
			return emitContext.Factory.NewKeywordExpression(kind);
		}
		throw "unhandled literal const value kind";
	}

	public function CreateTypeOfExpression(emitContext:EmitContext, expression:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		expression = emitContext.ParseNode(expression);
		if (expression == null) {
			return emitContext.Factory.NewKeywordTypeNode(KindAnyKeyword);
		}

		final requestNodeBuilder = Checker.NewNodeBuilder(checker, emitContext); // TODO: cache per-context
		return requestNodeBuilder.SerializeTypeForExpression(expression, enclosingDeclaration, flags | FlagsMultilineObjectLiterals, internalFlags, tracker);
	}

	public function CreateLateBoundIndexSignatures(emitContext:EmitContext, container:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Array<Node> {
		container = emitContext.ParseNode(container);

		final sym = container.Symbol();
		final staticInfos = checker.getIndexInfosOfType(checker.getTypeOfSymbol(sym));
		final instanceIndexSymbol = checker.getIndexSymbol(sym);
		var instanceInfos:Array<IndexInfo> = null;
		if (instanceIndexSymbol != null) {
			final members = checker.getMembersOfSymbol(sym);
			final siblingSymbols = members == null ? null : [for (v in members) v];
			instanceInfos = checker.getIndexInfosOfIndexSymbol(instanceIndexSymbol, siblingSymbols);
		}

		final requestNodeBuilder = Checker.NewNodeBuilder(checker, emitContext); // TODO: cache per-context

		var result:Array<Node> = null;
		final infoLists = [staticInfos, instanceInfos];
		for (i in 0...infoLists.length) {
			final infoList = infoLists[i];
			var isStatic = true;
			if (i > 0) {
				isStatic = false;
			}
			if (Core.len(infoList) == 0) {
				continue;
			}
			for (info in infoList) {
				if (info.declaration != null) {
					continue;
				}
				if (info == checker.anyBaseTypeIndexInfo) {
					continue; // inherited, but looks like a late-bound signature because it has no declarations
				}
				if (Core.len(info.components) != 0) {
					// !!! TODO: Complete late-bound index info support - getObjectLiteralIndexInfo does not yet add late bound components to index signatures
					final allComponentComputedNamesSerializable = enclosingDeclaration != null && Core.Every(info.components, (c:Node) -> {
						return c.Name() != null
							&& Ast.IsComputedPropertyName(c.Name())
							&& Ast.IsEntityNameExpression(c.Name().Expression())
							&& isEntityNameVisible(c.Name().Expression(), enclosingDeclaration, false).Accessibility == SymbolAccessibilityAccessible;
					});
					if (allComponentComputedNamesSerializable) {
						for (c in info.components) {
							if (checker.hasLateBindableName(c)) {
								// skip late bound props that contribute to the index signature - they'll be preserved via other means
								continue;
							}

							final firstIdentifier = Ast.GetFirstIdentifier(c.Name().Expression());
							final name = checker.resolveName(firstIdentifier, firstIdentifier.Text(), SymbolFlagsValue | SymbolFlagsExportValue, null /*nameNotFoundMessage*/,
								true /*isUse*/, false /*excludeGlobals*/);
							if (name != null) {
								tracker.TrackSymbol(name, enclosingDeclaration, SymbolFlagsValue);
							}

							// PORT: core.IfElse evaluates both arguments, so the modifier node is created either way.
							final staticMods = [emitContext.Factory.NewModifier(KindStaticKeyword)];
							var mods:Array<Node> = isStatic ? staticMods : null;
							if (info.isReadonly) {
								if (mods == null) {
									mods = [];
								}
								mods.push(emitContext.Factory.NewModifier(KindReadonlyKeyword));
							}

							final modifierList = emitContext.Factory.NewModifierList(mods);
							final decl = emitContext.Factory.NewPropertyDeclaration(mods != null ? modifierList : null, c.Name(), c.QuestionToken(),
								requestNodeBuilder.TypeToTypeNode(checker.getTypeOfSymbol(c.Symbol()), enclosingDeclaration, flags, internalFlags, tracker), null);
							if (result == null) {
								result = [];
							}
							result.push(decl);
						}
						continue;
					}
				}
				var node = requestNodeBuilder.IndexInfoToIndexSignatureDeclaration(info, enclosingDeclaration, flags, internalFlags, tracker);
				if (node != null && isStatic) {
					final modNodes = [emitContext.Factory.NewModifier(KindStaticKeyword)];
					final existing = node.ModifierNodes();
					if (existing != null) {
						for (m in existing) {
							modNodes.push(m);
						}
					}
					final mods = emitContext.Factory.NewModifierList(modNodes);
					node = emitContext.Factory.UpdateIndexSignatureDeclaration(node.AsIndexSignatureDeclaration(), mods, node.ParameterList(), node.Type());
				}
				if (node != null) {
					if (result == null) {
						result = [];
					}
					result.push(node);
				}
			}
		}
		return result;
	}

	public function GetEffectiveDeclarationFlags(node:Node, flags:ModifierFlags):ModifierFlags {
		// node = emitContext.ParseNode(node)
		return checker.GetEffectiveDeclarationFlags(node, flags);
	}

	public function GetResolutionModeOverride(node:Node):ResolutionMode {
		// node = emitContext.ParseNode(node)
		return checker.GetResolutionModeOverride(node.AsImportAttributes(), false);
	}

	public function GetConstantValue(node:Node):Any {
		// node = emitContext.ParseNode(node)
		return checker.GetConstantValue(node);
	}

	public function GetTypeReferenceSerializationKind(typeName:Node, location:Node):TypeReferenceSerializationKind {
		// typeName = emitContext.ParseNode(typeName)
		// location = emitContext.ParseNode(location)
		if (typeName == null || location == null) {
			return TypeReferenceSerializationKindUnknown;
		}

		// Resolve the symbol as a value to ensure the type can be reached at runtime during emit.
		var isTypeOnly = false;
		if (Ast.IsQualifiedName(typeName)) {
			final rootValueSymbol = checker.resolveEntityName(Ast.GetFirstIdentifier(typeName), SymbolFlagsValue, true, true, location);

			if (rootValueSymbol != null && Core.len(rootValueSymbol.Declarations) > 0) {
				isTypeOnly = Core.Every(rootValueSymbol.Declarations, Ast.IsTypeOnlyImportOrExportDeclaration);
			}
		}
		final valueSymbol = checker.resolveEntityName(typeName, SymbolFlagsValue, true, true, location);
		var resolvedValueSymbol = valueSymbol;
		if (valueSymbol != null && (valueSymbol.Flags & SymbolFlagsAlias) != 0) {
			resolvedValueSymbol = checker.resolveAlias(valueSymbol);
		}

		isTypeOnly = isTypeOnly || (valueSymbol != null && checker.getTypeOnlyAliasDeclarationEx(valueSymbol, SymbolFlagsValue) != null);

		// Resolve the symbol as a type so that we can provide a more useful hint for the type serializer.
		final typeSymbol = checker.resolveEntityName(typeName, SymbolFlagsType, true, true, location);
		var resolvedTypeSymbol = typeSymbol;
		if (typeSymbol != null && (typeSymbol.Flags & SymbolFlagsAlias) != 0) {
			resolvedTypeSymbol = checker.resolveAlias(typeSymbol);
		}
		// In case the value symbol can't be resolved (e.g. because of missing declarations), use type symbol for reachability check.
		isTypeOnly = isTypeOnly || (typeSymbol != null && checker.getTypeOnlyAliasDeclarationEx(typeSymbol, SymbolFlagsType) != null);

		if (resolvedValueSymbol != null && resolvedValueSymbol == resolvedTypeSymbol) {
			final globalPromiseSymbol = checker.getGlobalPromiseConstructorSymbol();
			if (globalPromiseSymbol != null && resolvedValueSymbol == globalPromiseSymbol) {
				return TypeReferenceSerializationKindPromise;
			}

			final constructorType = checker.getTypeOfSymbol(resolvedValueSymbol);
			if (constructorType != null && checker.isConstructorType(constructorType)) {
				if (isTypeOnly) {
					return TypeReferenceSerializationKindTypeWithCallSignature;
				}
				return TypeReferenceSerializationKindTypeWithConstructSignatureAndValue;
			}
		}

		// We might not be able to resolve type symbol so use unknown type in that case (eg error case)
		if (resolvedTypeSymbol == null) {
			if (isTypeOnly) {
				return TypeReferenceSerializationKindObjectType;
			}
			return TypeReferenceSerializationKindUnknown;
		}

		final type_ = checker.getDeclaredTypeOfSymbol(resolvedTypeSymbol);
		if (checker.isErrorType(type_)) {
			if (isTypeOnly) {
				return TypeReferenceSerializationKindObjectType;
			}
			return TypeReferenceSerializationKindUnknown;
		}

		if ((type_.flags & TypeFlagsAnyOrUnknown) != 0) {
			return TypeReferenceSerializationKindObjectType;
		} else if (checker.isTypeAssignableToKind(type_, TypeFlagsVoid | TypeFlagsNullable | TypeFlagsNever)) {
			return TypeReferenceSerializationKindVoidNullableOrNeverType;
		} else if (checker.isTypeAssignableToKind(type_, TypeFlagsBooleanLike)) {
			return TypeReferenceSerializationKindBooleanType;
		} else if (checker.isTypeAssignableToKind(type_, TypeFlagsNumberLike)) {
			return TypeReferenceSerializationKindNumberLikeType;
		} else if (checker.isTypeAssignableToKind(type_, TypeFlagsBigIntLike)) {
			return TypeReferenceSerializationKindBigIntLikeType;
		} else if (checker.isTypeAssignableToKind(type_, TypeFlagsStringLike)) {
			return TypeReferenceSerializationKindStringLikeType;
		} else if (Checker.isTupleType(type_)) {
			return TypeReferenceSerializationKindArrayLikeType;
		} else if (checker.isTypeAssignableToKind(type_, TypeFlagsESSymbolLike)) {
			return TypeReferenceSerializationKindESSymbolType;
		} else if (checker.isFunctionType(type_)) {
			return TypeReferenceSerializationKindTypeWithCallSignature;
		} else if (checker.isArrayType(type_)) {
			return TypeReferenceSerializationKindArrayLikeType;
		} else {
			return TypeReferenceSerializationKindObjectType;
		}
	}

	public function GetPropertiesOfContainerFunction(node:Node):Array<Symbol> {
		// This is explicitly _not locked_ because it is only called via error reporters invoked via node builder calls
		// to the symbol tracker already within locked contexts.
		// r.checkerMu.Lock()
		// defer r.checkerMu.Unlock()
		if (node == null) {
			return [];
		}
		final s = checker.getSymbolOfDeclaration(node);
		if (s == null) {
			return [];
		}
		return checker.getPropertiesOfType(checker.getTypeOfSymbol(s));
	}

	public function TryJSTypeNodeToTypeNode(emitContext:EmitContext, typeNode:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		typeNode = emitContext.ParseNode(typeNode);

		final requestNodeBuilder = Checker.NewNodeBuilder(checker, emitContext); // TODO: cache per-context
		return requestNodeBuilder.TryJSTypeNodeToTypeNode(typeNode, enclosingDeclaration, flags, internalFlags, tracker);
	}

	// IsThisPropertyAssignmentDeclarationRedundant reports whether a JS `this.<name> = ...` expando
	// assignment should be omitted from declaration emit because the member it would synthesize is
	// already provided by an `extends` base type. This mirrors the skip condition in the checker's
	// serializePropertySymbol: an inherited member is redundant when it is identical to the assigned
	// one (same readonly-ness, optionality and type). Inherited accessors and methods are always
	// treated as redundant here, since accessors merge oddly with value assignments (and run via the
	// accessor at runtime), and `this`-expando props carry the ReplaceableByMethod contract, so a
	// rebind such as `this.method = this.method.bind(this)` must not override the base method.
	//
	// Only `extends` base types are considered. Members coming from `implements` clauses are not
	// inherited, so the class must redeclare them, and they are always emitted.
	public function IsThisPropertyAssignmentDeclarationRedundant(node:Node):Bool {
		if (node == null) {
			return false;
		}

		final s = checker.getSymbolOfDeclaration(node);
		if (s == null || s.Parent == null) {
			return false;
		}
		final parentType = checker.getDeclaredTypeOfSymbol(s.Parent);
		if (parentType == null) {
			return false;
		}
		final baseTypes = checker.getBaseTypes(parentType);
		if (baseTypes != null) {
			for (base in baseTypes) {
				final baseProp = checker.getPropertyOfType(base, s.Name);
				if (baseProp == null) {
					continue;
				}
				if ((baseProp.Flags & (SymbolFlagsAccessor | SymbolFlagsMethod | SymbolFlagsFunction)) != 0) {
					return true;
				}
				if (checker.isReadonlySymbol(baseProp) == checker.isReadonlySymbol(s)
					&& (s.Flags & SymbolFlagsOptional) == (baseProp.Flags & SymbolFlagsOptional)
					&& checker.isTypeIdenticalTo(checker.getTypeOfSymbol(s), checker.getTypeOfSymbol(baseProp))) {
					return true;
				}
			}
		}
		return false;
	}

	// PORT: helper for the Go struct literal printer.SymbolAccessibilityResult{Accessibility, ErrorSymbolName, ErrorNode}.
	static function newAccessibilityResult(accessibility:ts.printer.Emitresolver.SymbolAccessibility, errorSymbolName:std.String, errorNode:Node):SymbolAccessibilityResult {
		final r = new SymbolAccessibilityResult();
		r.Accessibility = accessibility;
		r.ErrorSymbolName = errorSymbolName;
		r.ErrorNode = errorNode;
		return r;
	}
}
