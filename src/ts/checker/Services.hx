package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/services.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Methods of services.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Services {

	public static function GetSymbolsInScope(c:Checker, location:Node, meaning:SymbolFlags):Array<Symbol> {
		return c.getSymbolsInScope(location, meaning);
	}

	static function getSymbolsInScope(c:Checker, location:Node, meaning:SymbolFlags):Array<Symbol> {
		if ((location.Flags & NodeFlagsInWithStatement) != 0) {
			// We cannot answer semantic questions within a with block, do not proceed any further
			return null;
		}

		final symbols:SymbolTable = new StringMap<Symbol>();
		var isStaticSymbol = false;

		// Copy the given symbol into symbol tables if the symbol has the given meaning
		// and it doesn't already exists in the symbol table.
		final copySymbol = (symbol:Symbol, meaning:SymbolFlags) -> {
			if ((symbol.CombinedLocalAndExportSymbolFlags() & meaning) != 0) {
				final id = symbol.Name;
				// We will copy all symbol regardless of its reserved name because
				// symbolsToArray will check whether the key is a reserved name and
				// it will not copy symbol with reserved name to the array
				if (!symbols.exists(id)) {
					symbols.set(id, symbol);
				}
			}
		};

		final copySymbols = (source:SymbolTable, meaning:SymbolFlags) -> {
			if (meaning != 0 && source != null) {
				for (symbol in source) {
					copySymbol(symbol, meaning);
				}
			}
		};

		final copyLocallyVisibleExportSymbols = (source:SymbolTable, meaning:SymbolFlags) -> {
			if (meaning != 0 && source != null) {
				for (symbol in source) {
					// Similar condition as in `resolveNameHelper`
					if (Ast.GetDeclarationOfKind(symbol, KindExportSpecifier) == null
						&& Ast.GetDeclarationOfKind(symbol, KindNamespaceExport) == null
						&& symbol.Name != Ast.InternalSymbolNameDefault) {
						copySymbol(symbol, meaning);
					}
				}
			}
		};

		final populateSymbols = () -> {
			while (location != null) {
				if (Checker.canHaveLocals(location) && location.Locals() != null && !Ast.IsGlobalSourceFile(location)) {
					copySymbols(location.Locals(), meaning);
				}

				// PORT: switch with break/fallthrough restructured
				switch (location.Kind) {
					case KindSourceFile, KindModuleDeclaration:
						if (location.Kind == KindModuleDeclaration || Ast.IsExternalModule(location.AsSourceFile())) {
							copyLocallyVisibleExportSymbols(c.getSymbolOfDeclaration(location).Exports, meaning & SymbolFlagsModuleMember);
						}
					case KindEnumDeclaration:
						copySymbols(c.getSymbolOfDeclaration(location).Exports, meaning & SymbolFlagsEnumMember);
					case KindClassExpression, KindClassDeclaration, KindInterfaceDeclaration:
						if (location.Kind == KindClassExpression) {
							final className = location.AsClassExpression().Name();
							if (className != null) {
								copySymbol(location.Symbol(), meaning);
							}
							// this fall-through is necessary because we would like to handle
							// type parameter inside class expression similar to how we handle it in classDeclaration and interface Declaration.
						}
						// If we didn't come from static member of class or interface,
						// add the type parameters into the symbol table
						// (type parameters of classDeclaration/classExpression and interface are in member property of the symbol.
						// Note: that the memberFlags come from previous iteration.
						if (!isStaticSymbol) {
							copySymbols(c.getMembersOfSymbol(c.getSymbolOfDeclaration(location)), meaning & SymbolFlagsType);
						}
					case KindFunctionExpression:
						final funcName = location.Name();
						if (funcName != null) {
							copySymbol(location.Symbol(), meaning);
						}
					default:
				}

				if (Checker.introducesArgumentsExoticObject(location)) {
					copySymbol(c.argumentsSymbol, meaning);
				}

				isStaticSymbol = Ast.IsStatic(location);
				location = location.Parent;
			}

			copySymbols(c.globals, meaning);
		};

		populateSymbols();

		symbols.remove(Ast.InternalSymbolNameThis); // Not a symbol, a keyword
		return Checker.symbolsToArray(symbols);
	}

	public static function GetExportsOfModule(c:Checker, symbol:Symbol):Array<Symbol> {
		return Checker.symbolsToArray(c.getExportsOfModule(symbol));
	}

	public static function ForEachExportAndPropertyOfModule(c:Checker, moduleSymbol:Symbol, cb:(Symbol, std.String) -> Void):Void {
		final exports = c.getExportsOfModule(moduleSymbol);
		if (exports != null) {
			for (key => exportedSymbol in exports) {
				if (!Checker.isReservedMemberName(key)) {
					cb(exportedSymbol, key);
				}
			}
		}

		final exportEquals = c.resolveExternalModuleSymbol(moduleSymbol, false /*dontResolveAlias*/);
		if (exportEquals == moduleSymbol) {
			return;
		}

		final typeOfSymbol = c.getTypeOfSymbol(exportEquals);
		if (!c.shouldTreatPropertiesOfExternalModuleAsExports(typeOfSymbol)) {
			return;
		}

		// forEachPropertyOfType
		final reducedType = c.getReducedApparentType(typeOfSymbol);
		if ((reducedType.flags & TypeFlagsStructuredType) == 0) {
			return;
		}
		final members = c.resolveStructuredTypeMembers(reducedType).members;
		if (members != null) {
			for (name => symbol in members) {
				if (c.isNamedMember(symbol, name)) {
					cb(symbol, name);
				}
			}
		}
	}

	public static function IsValidPropertyAccess(c:Checker, node:Node, propertyName:std.String):Bool {
		return c.isValidPropertyAccess(node, propertyName);
	}

	static function isValidPropertyAccess(c:Checker, node:Node, propertyName:std.String):Bool {
		switch (node.Kind) {
			case KindPropertyAccessExpression:
				return c.isValidPropertyAccessWithType(node, node.Expression().Kind == KindSuperKeyword, propertyName, c.getWidenedType(c.checkExpression(node.Expression())));
			case KindQualifiedName:
				return c.isValidPropertyAccessWithType(node, false /*isSuper*/, propertyName, c.getWidenedType(c.checkExpression(node.AsQualifiedName().Left)));
			case KindImportType:
				return c.isValidPropertyAccessWithType(node, false /*isSuper*/, propertyName, c.getTypeFromTypeNode(node));
			default:
		}
		throw "Unexpected node kind in isValidPropertyAccess: " + node.Kind.String();
	}

	static function isValidPropertyAccessWithType(c:Checker, node:Node, isSuper:Bool, propertyName:std.String, t:Type):Bool {
		// Short-circuiting for improved performance.
		if (Checker.IsTypeAny(t)) {
			return true;
		}

		final prop = c.getPropertyOfType(t, propertyName);
		return prop != null && c.isPropertyAccessible(node, isSuper, false /*isWrite*/, t, prop);
	}

	// Checks if an existing property access is valid for completions purposes.
	// node: a property access-like node where we want to check if we can access a property.
	// This node does not need to be an access of the property we are checking.
	// e.g. in completions, this node will often be an incomplete property access node, as in `foo.`.
	// Besides providing a location (i.e. scope) used to check property accessibility, we use this node for
	// computing whether this is a `super` property access.
	// type: the type whose property we are checking.
	// property: the accessed property's symbol.
	public static function IsValidPropertyAccessForCompletions(c:Checker, node:Node, t:Type, property:Symbol):Bool {
		return c.isPropertyAccessible(node, node.Kind == KindPropertyAccessExpression && node.Expression().Kind == KindSuperKeyword, false, /*isWrite*/ t,
			property);
		// Previously we validated the 'this' type of methods but this adversely affected performance. See #31377 for more context.
	}

	public static function GetAllPossiblePropertiesOfTypes(c:Checker, types:Array<Type>):Array<Symbol> {
		final unionType = c.getUnionType(types);
		if ((unionType.flags & TypeFlagsUnion) == 0) {
			return c.getAugmentedPropertiesOfType(unionType);
		}

		final props:SymbolTable = new StringMap<Symbol>();
		if (types != null) {
			for (memberType in types) {
				final augmentedProps = c.getAugmentedPropertiesOfType(memberType);
				if (augmentedProps != null) {
					for (p in augmentedProps) {
						if (!props.exists(p.Name)) {
							final prop = c.createUnionOrIntersectionProperty(unionType, p.Name, false /*skipObjectFunctionPropertyAugment*/);
							// May be undefined if the property is private
							if (prop != null) {
								props.set(p.Name, prop);
							}
						}
					}
				}
			}
		}
		return [for (v in props) v];
	}

	public static function IsUnknownSymbol(c:Checker, symbol:Symbol):Bool {
		return symbol == c.unknownSymbol;
	}

	public static function IsUndefinedSymbol(c:Checker, symbol:Symbol):Bool {
		return symbol == c.undefinedSymbol;
	}

	public static function IsArgumentsSymbol(c:Checker, symbol:Symbol):Bool {
		return symbol == c.argumentsSymbol;
	}

	// Originally from services.ts
	public static function GetNonOptionalType(c:Checker, t:Type):Type {
		return c.removeOptionalTypeMarker(t);
	}

	public static function GetStringIndexType(c:Checker, t:Type):Type {
		return c.getIndexTypeOfType(t, c.stringType);
	}

	public static function GetNumberIndexType(c:Checker, t:Type):Type {
		return c.getIndexTypeOfType(t, c.numberType);
	}

	public static function GetElementTypeOfArrayType(c:Checker, t:Type):Type {
		return c.getElementTypeOfArrayType(t);
	}

	public static function GetCallSignatures(c:Checker, t:Type):Array<Signature> {
		return c.getSignaturesOfType(t, SignatureKindCall);
	}

	public static function GetConstructSignatures(c:Checker, t:Type):Array<Signature> {
		return c.getSignaturesOfType(t, SignatureKindConstruct);
	}

	public static function GetApparentProperties(c:Checker, t:Type):Array<Symbol> {
		return c.getAugmentedPropertiesOfType(t);
	}

	static function getAugmentedPropertiesOfType(c:Checker, t:Type):Array<Symbol> {
		t = c.getApparentType(t);
		var propsByName = Checker.createSymbolTable(c.getPropertiesOfType(t));
		var functionType:Type = null;
		if (Core.len(c.getSignaturesOfType(t, SignatureKindCall)) > 0) {
			functionType = c.globalCallableFunctionType;
		} else if (Core.len(c.getSignaturesOfType(t, SignatureKindConstruct)) > 0) {
			functionType = c.globalNewableFunctionType;
		}

		if (propsByName == null) {
			propsByName = new StringMap<Symbol>();
		}
		if (functionType != null) {
			final functionProps = c.getPropertiesOfType(functionType);
			if (functionProps != null) {
				for (p in functionProps) {
					if (!propsByName.exists(p.Name)) {
						propsByName.set(p.Name, p);
					}
				}
			}
		}
		return c.getNamedMembers(propsByName, null);
	}

	public static function TryGetMemberInModuleExportsAndProperties(c:Checker, memberName:std.String, moduleSymbol:Symbol):Symbol {
		final symbol = c.TryGetMemberInModuleExports(memberName, moduleSymbol);
		if (symbol != null) {
			return symbol;
		}

		final exportEquals = c.resolveExternalModuleSymbol(moduleSymbol, false /*dontResolveAlias*/);
		if (exportEquals == moduleSymbol) {
			return null;
		}

		final t = c.getTypeOfSymbol(exportEquals);
		if (c.shouldTreatPropertiesOfExternalModuleAsExports(t)) {
			return c.getPropertyOfType(t, memberName);
		}
		return null;
	}

	public static function TryGetMemberInModuleExports(c:Checker, memberName:std.String, moduleSymbol:Symbol):Symbol {
		final symbolTable = c.getExportsOfModule(moduleSymbol);
		return symbolTable == null ? null : symbolTable.get(memberName);
	}

	static function shouldTreatPropertiesOfExternalModuleAsExports(c:Checker, resolvedExternalModuleType:Type):Bool {
		return (resolvedExternalModuleType.flags & TypeFlagsPrimitive) == 0
			|| (resolvedExternalModuleType.objectFlags & ObjectFlagsClass) != 0
			// `isArrayOrTupleLikeType` is too expensive to use in this auto-imports hot path.
			|| c.isArrayType(resolvedExternalModuleType)
			|| Checker.isTupleType(resolvedExternalModuleType);
	}

	public static function GetContextualType(c:Checker, node:Expression, contextFlags:ContextFlags):Type {
		if ((contextFlags & ContextFlagsIgnoreNodeInferences) != 0) {
			return Checker.runWithInferenceBlockedFromSourceNode(c, node, () -> {
				return c.getContextualType(node, contextFlags);
			});
		}
		return c.getContextualType(node, contextFlags);
	}

	public static function SkipAlias(c:Checker, symbol:Symbol):Symbol {
		if ((symbol.Flags & SymbolFlagsAlias) != 0) {
			return c.GetAliasedSymbol(symbol);
		}
		return symbol;
	}

	public static function GetRootSymbols(c:Checker, symbol:Symbol):Array<Symbol> {
		final roots = c.getImmediateRootSymbols(symbol);
		if (Core.len(roots) == 0) {
			return [symbol];
		}
		var result:Array<Symbol> = null;
		for (root in roots) {
			final rootSymbols = c.GetRootSymbols(root);
			if (Core.len(rootSymbols) > 0) {
				if (result == null) {
					result = [];
				}
				for (s in rootSymbols) {
					result.push(s);
				}
			}
		}
		return result;
	}

	public static function GetMappedTypeSymbolOfProperty(c:Checker, symbol:Symbol):Symbol {
		final valueLinks = c.valueSymbolLinks.TryGet(symbol);
		if (valueLinks != null) {
			return valueLinks.containingType.symbol;
		}
		return null;
	}

	static function getImmediateRootSymbols(c:Checker, symbol:Symbol):Array<Symbol> {
		if ((symbol.CheckFlags & CheckFlagsSynthetic) != 0) {
			return Core.MapNonNil(c.valueSymbolLinks.Get(symbol).containingType.Types(), (t:Type) -> {
				return c.getPropertyOfType(t, symbol.Name);
			});
		}
		if ((symbol.Flags & SymbolFlagsTransient) != 0) {
			if (c.spreadLinks.Has(symbol)) {
				final leftSpread = c.spreadLinks.Get(symbol).leftSpread;
				final rightSpread = c.spreadLinks.Get(symbol).rightSpread;
				if (leftSpread != null) {
					return [leftSpread, rightSpread];
				}
			}
			if (c.mappedSymbolLinks.Has(symbol)) {
				final syntheticOrigin = c.mappedSymbolLinks.Get(symbol).syntheticOrigin;
				if (syntheticOrigin != null) {
					return [syntheticOrigin];
				}
			}
			final target = c.tryGetTarget(symbol);
			if (target != null) {
				return [target];
			}
		}
		return null;
	}

	static function tryGetTarget(c:Checker, symbol:Symbol):Symbol {
		var target:Symbol = null;
		var next = symbol;
		while (true) {
			if (c.valueSymbolLinks.Has(next)) {
				next = c.valueSymbolLinks.Get(next).target;
			} else if (c.exportTypeLinks.Has(next)) {
				next = c.exportTypeLinks.Get(next).target;
			} else {
				next = null;
			}
			if (next == null) {
				break;
			}
			target = next;
		}
		return target;
	}

	public static function GetExportSymbolOfSymbol(c:Checker, symbol:Symbol):Symbol {
		return c.getMergedSymbol(symbol.ExportSymbol != null ? symbol.ExportSymbol : symbol);
	}

	public static function GetExportSpecifierLocalTargetSymbol(c:Checker, node:Node):Symbol {
		// node should be ExportSpecifier | Identifier
		switch (node.Kind) {
			case KindExportSpecifier:
				if (node.Parent.Parent.ModuleSpecifier() != null) {
					return c.getExternalModuleMember(node.Parent.Parent, node, false /*dontResolveAlias*/);
				}
				final name = node.PropertyNameOrName();
				if (name.Kind == KindStringLiteral) {
					// Skip for invalid syntax like this: export { "x" }
					return null;
				}
				return c.resolveEntityName(name, SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace | SymbolFlagsAlias, true /*ignoreErrors*/, false, null);
			case KindIdentifier:
				return c.resolveEntityName(node, SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace | SymbolFlagsAlias, true /*ignoreErrors*/, false, null);
			default:
		}
		throw "Unhandled case in getExportSpecifierLocalTargetSymbol, node should be ExportSpecifier | Identifier";
	}

	public static function GetShorthandAssignmentValueSymbol(c:Checker, location:Node):Symbol {
		if (location != null && location.Kind == KindShorthandPropertyAssignment) {
			return c.resolveEntityName(location.Name(), SymbolFlagsValue | SymbolFlagsAlias, true /*ignoreErrors*/, false, null);
		}
		return null;
	}

	/**
	* Get symbols that represent parameter-property-declaration as parameter and as property declaration
	* @param parameter a parameterDeclaration node
	* @param parameterName a name of the parameter to get the symbols for.
	* @return a tuple of two symbols
	 */
	public static function GetSymbolsOfParameterPropertyDeclaration(c:Checker, parameter:Node, parameterName:std.String):Pair<Symbol, Symbol> {
		final constructorDeclaration = parameter.Parent;
		final classDeclaration = parameter.Parent.Parent;

		final parameterSymbol = c.getSymbol(constructorDeclaration.Locals(), parameterName, SymbolFlagsValue);
		final propertySymbol = c.getSymbol(c.getMembersOfSymbol(classDeclaration.Symbol()), parameterName, SymbolFlagsValue);

		if (parameterSymbol != null && propertySymbol != null) {
			return new Pair(parameterSymbol, propertySymbol);
		}

		throw "There should exist two symbols, one as property declaration and one as parameter declaration";
	}

	// IsDeclarationUsed checks if an import declaration identifier is used in the source file.
	// This is primarily used for organizing imports to determine which imports can be removed.
	public static function IsDeclarationUsed(c:Checker, sourceFile:SourceFile, identifier:Identifier, jsxElementsPresent:Bool, jsxModeNeedsExplicitImport:Bool):Bool {
		if (jsxElementsPresent && jsxModeNeedsExplicitImport) {
			final jsxNamespace = c.getJsxNamespace(sourceFile.AsNode());
			final jsxFragmentFactory = c.GetJsxFragmentFactory(sourceFile.AsNode());
			final identifierText = identifier.Text;
			if (identifierText == jsxNamespace) {
				return true;
			}
			if (jsxFragmentFactory != "" && identifierText == jsxFragmentFactory) {
				return true;
			}
		}

		final symbol = c.GetSymbolAtLocation(identifier.AsNode());
		if (symbol == null) {
			return true;
		}

		return c.IsSymbolReferencedInFile(sourceFile, identifier, symbol);
	}

	// IsSymbolReferencedInFile checks if a symbol is referenced in the source file (besides its definition).
	// This is used as a quick check for whether a symbol is used at all in a file.
	public static function IsSymbolReferencedInFile(c:Checker, sourceFile:SourceFile, definition:Identifier, symbol:Symbol):Bool {
		final identifierText = definition.Text;
		final tokens = Checker.getPossibleSymbolReferenceNodes(sourceFile, identifierText, sourceFile.AsNode());
		if (tokens != null) {
			for (token in tokens) {
				if (!Ast.IsIdentifier(token)) {
					continue;
				}
				final id = token.AsIdentifier();
				if (id == definition || id.Text != identifierText) {
					continue;
				}
				final refSymbol = c.GetSymbolAtLocation(token);
				if (refSymbol == symbol) {
					return true;
				}
				if (token.Parent != null && token.Parent.Kind == KindShorthandPropertyAssignment) {
					final shorthandSymbol = c.GetShorthandAssignmentValueSymbol(token.Parent);
					if (shorthandSymbol == symbol) {
						return true;
					}
				}
				if (token.Parent != null && Ast.IsExportSpecifier(token.Parent)) {
					final localSymbol = c.getLocalSymbolForExportSpecifier(token.AsIdentifier(), refSymbol, token.Parent.AsExportSpecifier());
					if (localSymbol == symbol) {
						return true;
					}
				}
			}
		}
		return false;
	}

	// GetReferencesToSymbolInFile returns all identifier nodes in the file that reference the given symbol.
	public static function GetReferencesToSymbolInFile(c:Checker, sourceFile:SourceFile, symbol:Symbol):Array<Node> {
		final identifierText = symbol.Name;
		var result:Array<Node> = null;
		final tokens = Checker.getPossibleSymbolReferenceNodes(sourceFile, identifierText, sourceFile.AsNode());
		if (tokens != null) {
			for (token in tokens) {
				if (!Ast.IsIdentifier(token)) {
					continue;
				}
				final id = token.AsIdentifier();
				if (id.Text != identifierText) {
					continue;
				}
				final refSymbol = c.GetSymbolAtLocation(token);
				if (refSymbol == symbol) {
					if (result == null) {
						result = [];
					}
					result.push(token);
					continue;
				}
				if (token.Parent != null && token.Parent.Kind == KindShorthandPropertyAssignment) {
					final shorthandSymbol = c.GetShorthandAssignmentValueSymbol(token.Parent);
					if (shorthandSymbol == symbol) {
						if (result == null) {
							result = [];
						}
						result.push(token);
						continue;
					}
				}
				if (token.Parent != null && Ast.IsExportSpecifier(token.Parent)) {
					final localSymbol = c.getLocalSymbolForExportSpecifier(token.AsIdentifier(), refSymbol, token.Parent.AsExportSpecifier());
					if (localSymbol == symbol) {
						if (result == null) {
							result = [];
						}
						result.push(token);
						continue;
					}
				}
			}
		}
		return result;
	}

	static function getLocalSymbolForExportSpecifier(c:Checker, referenceLocation:Identifier, referenceSymbol:Symbol, exportSpecifier:ExportSpecifier):Symbol {
		if (Checker.isExportSpecifierAlias(referenceLocation, exportSpecifier)) {
			final symbol = c.GetExportSpecifierLocalTargetSymbol(exportSpecifier.AsNode());
			if (symbol != null) {
				return symbol;
			}
		}
		return referenceSymbol;
	}

	public static function GetTypeArgumentConstraint(c:Checker, node:Node):Type {
		if (!Ast.IsTypeNode(node)) {
			return null;
		}
		return c.getTypeArgumentConstraint(node);
	}

	// getUninstantiatedSignatures gets generic signatures from the function's/constructor's type.
	static function getUninstantiatedSignatures(c:Checker, node:Node):Array<Signature> {
		switch (node.Kind) {
			case KindCallExpression, KindDecorator:
				return c.getSignaturesOfType(c.getTypeOfExpression(node.Expression()), SignatureKindCall);
			case KindNewExpression:
				return c.getSignaturesOfType(c.getTypeOfExpression(node.Expression()), SignatureKindConstruct);
			case KindJsxSelfClosingElement, KindJsxOpeningElement:
				if (Checker.isJsxIntrinsicTagName(node.TagName())) {
					return null;
				}
				return c.getSignaturesOfType(c.getTypeOfExpression(node.TagName()), SignatureKindCall);
			case KindTaggedTemplateExpression:
				return c.getSignaturesOfType(c.getTypeOfExpression(node.AsTaggedTemplateExpression().Tag), SignatureKindCall);
			case KindBinaryExpression, KindJsxOpeningFragment:
				return null;
			default:
		}
		return null;
	}

	static function getTypeParameterConstraintForPositionAcrossSignatures(c:Checker, signatures:Array<Signature>, position:Int):Type {
		var relevantConstraints:Array<Type> = null;
		if (signatures != null) {
			for (signature in signatures) {
				if (position >= Core.len(signature.typeParameters)) {
					continue;
				}
				final relevantTypeParameter = signature.typeParameters[position];
				final relevantConstraint = c.getConstraintOfTypeParameter(relevantTypeParameter);
				if (relevantConstraint != null) {
					if (relevantConstraints == null) {
						relevantConstraints = [];
					}
					relevantConstraints.push(relevantConstraint);
				}
			}
		}
		return c.getUnionType(relevantConstraints);
	}

	static function getTypeArgumentConstraint(c:Checker, node:Node):Type {
		var typeArgumentPosition:Int = -1;
		if (Ast.HasTypeArguments(node.Parent)) {
			final typeArgs = node.Parent.TypeArguments();
			if (typeArgs != null) {
				for (i in 0...typeArgs.length) {
					if (typeArgs[i] == node) {
						typeArgumentPosition = i;
						break;
					}
				}
			}
		}

		if (typeArgumentPosition >= 0) {
			// The node could be a type argument of a call, a `new` expression, a decorator, an
			// instantiation expression, or a generic type instantiation.

			if (Ast.IsCallLikeExpression(node.Parent)) {
				return c.getTypeParameterConstraintForPositionAcrossSignatures(c.getUninstantiatedSignatures(node.Parent), typeArgumentPosition);
			}

			if (Ast.IsDecorator(node.Parent.Parent)) {
				return c.getTypeParameterConstraintForPositionAcrossSignatures(c.getUninstantiatedSignatures(node.Parent.Parent), typeArgumentPosition);
			}

			if (Ast.IsExpressionWithTypeArguments(node.Parent) && Ast.IsExpressionStatement(node.Parent.Parent)) {
				final uninstantiatedType = c.checkExpression(node.Parent.Expression());

				final callConstraint = c.getTypeParameterConstraintForPositionAcrossSignatures(c.getSignaturesOfType(uninstantiatedType, SignatureKindCall),
					typeArgumentPosition);
				final constructConstraint = c.getTypeParameterConstraintForPositionAcrossSignatures(c.getSignaturesOfType(uninstantiatedType, SignatureKindConstruct),
					typeArgumentPosition);

				// An instantiation expression instantiates both call and construct signatures, so
				// if both exist type arguments must be assignable to both constraints.
				if ((constructConstraint.flags & TypeFlagsNever) != 0) {
					return callConstraint;
				}
				if ((callConstraint.flags & TypeFlagsNever) != 0) {
					return constructConstraint;
				}
				return c.getIntersectionType([callConstraint, constructConstraint]);
			}

			if (Ast.IsTypeReferenceType(node.Parent)) {
				final typeParameters = c.getTypeParametersForTypeReferenceOrImport(node.Parent);
				if (Core.len(typeParameters) == 0) {
					return null;
				}
				if (typeArgumentPosition >= typeParameters.length) {
					return null;
				}
				final relevantTypeParameter = typeParameters[typeArgumentPosition];
				final constraint = c.getConstraintOfTypeParameter(relevantTypeParameter);
				if (constraint != null) {
					return c.instantiateType(constraint, Checker.newTypeMapper(typeParameters, c.getEffectiveTypeArguments(node.Parent, typeParameters)));
				}
			}
		}
		return null;
	}

	public static function IsTypeInvalidDueToUnionDiscriminant(c:Checker, contextualType:Type, obj:Node):Bool {
		final properties = obj.Properties();
		return Core.Some(properties, (property:Node) -> {
			var nameType:Type = null;
			final propertyName = property.Name();
			if (propertyName != null) {
				if (Ast.IsJsxNamespacedName(propertyName)) {
					nameType = c.getStringLiteralType(propertyName.Text());
				} else {
					nameType = c.getLiteralTypeFromPropertyName(propertyName);
				}
			}
			var name = "";
			if (nameType != null && Checker.isTypeUsableAsPropertyName(nameType)) {
				name = Checker.getPropertyNameFromType(nameType);
			}
			var expected:Type = null;
			if (name != "") {
				expected = c.getTypeOfPropertyOfType(contextualType, name);
			}
			return expected != null && Checker.isLiteralType(expected) && !c.isTypeAssignableTo(c.getTypeOfNode(property), expected);
		});
	}

	// Unlike `getExportsOfModule`, this includes properties of an `export =` value.
	public static function GetExportsAndPropertiesOfModule(c:Checker, moduleSymbol:Symbol):Array<Symbol> {
		var exports = c.getExportsOfModuleAsArray(moduleSymbol);
		final exportEquals = c.resolveExternalModuleSymbol(moduleSymbol, false /*dontResolveAlias*/);
		if (exportEquals != moduleSymbol) {
			final t = c.getTypeOfSymbol(exportEquals);
			if (c.shouldTreatPropertiesOfExternalModuleAsExports(t)) {
				final props = c.getPropertiesOfType(t);
				if (Core.len(props) > 0) {
					exports = exports == null ? props.copy() : exports.concat(props);
				}
			}
		}
		return exports;
	}

	static function getExportsOfModuleAsArray(c:Checker, moduleSymbol:Symbol):Array<Symbol> {
		return Checker.symbolsToArray(c.getExportsOfModule(moduleSymbol));
	}

	// Returns all the properties of the Jsx.IntrinsicElements interface.
	public static function GetJsxIntrinsicTagNamesAt(c:Checker, location:Node):Array<Symbol> {
		final intrinsics = c.getJsxType(Checker.JsxNames.IntrinsicElements, location);
		if (intrinsics == null) {
			return null;
		}
		return c.GetPropertiesOfType(intrinsics);
	}

	public static function GetContextualTypeForJsxAttribute(c:Checker, attribute:JsxAttributeLike):Type {
		return c.getContextualTypeForJsxAttribute(attribute, ContextFlagsNone);
	}

	public static function GetConstantValue(c:Checker, node:Node):Any {
		if (node.Kind == KindEnumMember) {
			return c.getEnumMemberValue(node).Value;
		}

		if (c.symbolNodeLinks.Get(node).resolvedSymbol == null) {
			c.checkExpressionCached(node); // ensure cached resolved symbol is set
		}
		var symbol = c.symbolNodeLinks.Get(node).resolvedSymbol;
		if (symbol == null && Ast.IsEntityNameExpression(node)) {
			symbol = c.resolveEntityName(node, SymbolFlagsValue, true, /*ignoreErrors*/ false, /*dontResolveAlias*/ null /*location*/);
		}
		if (symbol != null && (symbol.Flags & SymbolFlagsEnumMember) != 0) {
			// inline property\index accesses only for const enums
			final member = symbol.ValueDeclaration;
			if (Ast.IsEnumConst(member.Parent)) {
				return c.getEnumMemberValue(member).Value;
			}
		}

		return null;
	}

	static function getResolvedSignatureWorker(c:Checker, node:Node, checkMode:CheckMode, argumentCount:Int):Pair<Signature, Array<Signature>> {
		final parsedNode = Printer.NewEmitContext().ParseNode(node);
		c.apparentArgumentCount = argumentCount; // PORT: pointer
		final candidatesOutArray:Array<Signature> = []; // PORT: pointer — the callee fills this array in place
		var res:Signature = null;
		if (parsedNode != null) {
			res = c.getResolvedSignature(parsedNode, candidatesOutArray, checkMode);
		}
		c.apparentArgumentCount = null;
		return new Pair(res, candidatesOutArray);
	}

	public static function GetCandidateSignaturesForStringLiteralCompletions(c:Checker, call:CallLikeExpression, editingArgument:Node):Array<Signature> {
		// first, get candidates when inference is blocked from the source node.
		var candidates = Checker.runWithInferenceBlockedFromSourceNode(c, editingArgument, () -> {
			final blockedInferenceCandidates = c.getResolvedSignatureWorker(call, CheckModeNormal, 0).b;
			return blockedInferenceCandidates;
		});
		final candidatesSet = Collections.NewSetFromItems(...(candidates != null ? candidates : []));

		// next, get candidates where the source node is considered for inference.
		final otherCandidates = Checker.runWithoutResolvedSignatureCaching(c, editingArgument, () -> {
			final inferenceCandidates = c.getResolvedSignatureWorker(call, CheckModeNormal, 0).b;
			return inferenceCandidates;
		});

		if (otherCandidates != null) {
			for (candidate in otherCandidates) {
				if (candidatesSet.Has(candidate)) {
					continue;
				}
				if (candidates == null) {
					candidates = [];
				}
				candidates.push(candidate);
			}
		}

		return candidates;
	}

	// GetTypeAtPosition returns the type of a parameter at a given index in a signature.
	public static function GetTypeAtPosition(c:Checker, s:Signature, pos:Int):Type {
		return c.getTypeAtPosition(s, pos);
	}

	public static function GetTypeParameterAtPosition(c:Checker, s:Signature, pos:Int):Type {
		final t = c.getTypeAtPosition(s, pos);
		if (t.IsIndex() && Checker.isThisTypeParameter(t.AsIndexType().target)) {
			final constraint = c.getBaseConstraintOfType(t.AsIndexType().target);
			if (constraint != null) {
				return c.getIndexType(constraint);
			}
		}
		return t;
	}

	// GetContextualTypeForArrayLiteralAtPosition returns the contextual type for an element at the given position
	// in an array with the given contextual type.
	public static function GetContextualTypeForArrayLiteralAtPosition(c:Checker, contextualArrayType:Type, arrayLiteral:Node, position:Int):Type {
		if (contextualArrayType == null) {
			return null;
		}
		var firstSpreadIndex = -1;
		var lastSpreadIndex = -1;
		var elementIndex = 0;
		final elements = arrayLiteral.Elements();
		if (elements != null) {
			for (i in 0...elements.length) {
				final elem = elements[i];
				if (elem.Pos() < position) {
					elementIndex++;
				}
				if (Ast.IsSpreadElement(elem)) {
					if (firstSpreadIndex == -1) {
						firstSpreadIndex = i;
					}
					lastSpreadIndex = i;
				}
			}
		}
		// The array may be incomplete, so we don't know its final length.
		return c.getContextualTypeForElementExpression(contextualArrayType, elementIndex, -1, /*length*/ firstSpreadIndex, lastSpreadIndex);
	}

	public static function GetFirstTypeArgumentFromKnownType(c:Checker, t:Type):Type {
		if ((t.objectFlags & ObjectFlagsReference) != 0 && t.symbol != null && Checker.isKnownGenericTypeName(t.symbol.Name)) {
			final symbol = c.getGlobalSymbol(t.symbol.Name, SymbolFlagsType, null);
			if (symbol != null && symbol == t.Target().symbol) {
				return Core.FirstOrNil(c.getTypeArguments(t));
			}
		}
		if (t.alias != null && Checker.isKnownGenericTypeName(t.alias.symbol.Name)) {
			final symbol = c.getGlobalSymbol(t.alias.symbol.Name, SymbolFlagsType, null);
			if (symbol != null && symbol == t.alias.symbol) {
				return Core.FirstOrNil(t.alias.typeArguments);
			}
		}
		return null;
	}

	// Gets all symbols for one property. Does not get symbols for every property.
	public static function GetPropertySymbolsFromContextualType(c:Checker, node:Node, contextualType:Type, unionSymbolOk:Bool):Array<Symbol> {
		final name = Ast.GetTextOfPropertyName(node.Name());
		if (name == "") {
			return null;
		}
		if ((contextualType.flags & TypeFlagsUnion) == 0) {
			final symbol = c.getPropertyOfType(contextualType, name);
			if (symbol != null) {
				return [symbol];
			}
			return null;
		}
		var filteredTypes = contextualType.Types();
		if (Ast.IsObjectLiteralExpression(node.Parent) || Ast.IsJsxAttributes(node.Parent)) {
			filteredTypes = Core.Filter(filteredTypes, (t:Type) -> {
				return !c.IsTypeInvalidDueToUnionDiscriminant(t, node.Parent);
			});
		}
		final discriminatedPropertySymbols = Core.MapNonNil(filteredTypes, (t:Type) -> {
			return c.getPropertyOfType(t, name);
		});
		if (unionSymbolOk && (Core.len(discriminatedPropertySymbols) == 0 || Core.len(discriminatedPropertySymbols) == Core.len(contextualType.Types()))) {
			final symbol = c.getPropertyOfType(contextualType, name);
			if (symbol != null) {
				return [symbol];
			}
		}
		if (Core.len(filteredTypes) == 0 && Core.len(discriminatedPropertySymbols) == 0) {
			// Bad discriminant -- do again without discriminating
			return Core.MapNonNil(contextualType.Types(), (t:Type) -> {
				return c.getPropertyOfType(t, name);
			});
		}
		// by eliminating duplicates we might even end up with a single symbol
		// that helps with displaying better quick infos on properties of union types
		return Core.Deduplicate(discriminatedPropertySymbols);
	}

	// Gets the property symbol corresponding to the property in destructuring assignment
	// 'property1' from
	//
	//	for ( { property1: a } of elems) {
	//	}
	//
	// 'property1' at location 'a' from:
	//
	//	[a] = [ property1, property2 ]
	public static function GetPropertySymbolOfDestructuringAssignment(c:Checker, location:Node):Symbol {
		if (Ast.IsArrayLiteralOrObjectLiteralDestructuringPattern(location.Parent.Parent)) {
			// Get the type of the object or array literal and then look for property of given name in the type
			final typeOfObjectLiteral = c.getTypeOfAssignmentPattern(location.Parent.Parent);
			if (typeOfObjectLiteral != null) {
				return c.getPropertyOfType(typeOfObjectLiteral, location.Text());
			}
		}
		return null;
	}

	// Gets the type of object literal or array literal of destructuring assignment.
	// { a } from
	//
	//	for ( { a } of elems) {
	//	}
	//
	// [ a ] from
	//
	//	[a] = [ some array ...]
	static function getTypeOfAssignmentPattern(c:Checker, expr:Node):Type {
		// If this is from "for of"
		//     for ( { a } of elems) {
		//     }
		if (Ast.IsForOfStatement(expr.Parent)) {
			final iteratedType = c.checkRightHandSideOfForOf(expr.Parent);
			return c.checkDestructuringAssignment(expr, Core.OrElse(iteratedType, c.errorType), CheckModeNormal, false);
		}
		// If this is from "for" initializer
		//     for ({a } = elems[0];.....) { }
		if (Ast.IsBinaryExpression(expr.Parent)) {
			final iteratedType = c.getTypeOfExpression(expr.Parent.AsBinaryExpression().Right);
			return c.checkDestructuringAssignment(expr, Core.OrElse(iteratedType, c.errorType), CheckModeNormal, false);
		}
		// If this is from nested object binding pattern
		//     for ({ skills: { primary, secondary } } = multiRobot, i = 0; i < 1; i++) {
		if (Ast.IsPropertyAssignment(expr.Parent)) {
			final node = expr.Parent.Parent;
			final typeOfParentObjectLiteral = Core.OrElse(c.getTypeOfAssignmentPattern(node), c.errorType);
			final propertyIndex = Slices.Index(node.Properties(), expr.Parent);
			return c.checkObjectLiteralDestructuringPropertyAssignment(node, typeOfParentObjectLiteral, propertyIndex, null, false);
		}
		// Array literal assignment - array destructuring pattern
		final node = expr.Parent;
		//    [{ property1: p1, property2 }] = elems;
		final typeOfArrayLiteral = Core.OrElse(c.getTypeOfAssignmentPattern(node), c.errorType);
		final elementType = Core.OrElse(c.checkIteratedTypeOrElementType(IterationUseDestructuring, typeOfArrayLiteral, c.undefinedType, expr.Parent),
			c.errorType);
		return c.checkArrayLiteralDestructuringElementAssignment(node, typeOfArrayLiteral, Slices.Index(node.Elements(), expr), elementType, CheckModeNormal);
	}

	public static function GetSignatureFromDeclaration(c:Checker, node:Node):Signature {
		return c.getSignatureFromDeclaration(node);
	}

	// IsLibSymbolForHoverVerbosity returns true if a symbol is declared in a lib file.
	public static function IsLibSymbolForHoverVerbosity(c:Checker, symbol:Symbol):Bool {
		if (symbol == null) {
			return false;
		}
		if (symbol.Declarations != null) {
			for (decl in symbol.Declarations) {
				final sf = Ast.GetSourceFileOfNode(decl);
				if (sf != null && c.program.IsSourceFileDefaultLibrary(sf.Path())) {
					return true;
				}
			}
		}
		return false;
	}

	// IsLibTypeForHoverVerbosity returns true if a type is declared in a lib file.
	// Don't expand types like Array or Promise, instead treating them as opaque.
	public static function IsLibTypeForHoverVerbosity(c:Checker, t:Type):Bool {
		var symbol:Symbol = null;
		if ((t.objectFlags & ObjectFlagsReference) != 0) {
			symbol = t.Target().Symbol();
		} else {
			symbol = t.Symbol();
		}
		if (c.IsLibSymbolForHoverVerbosity(symbol)) {
			return true;
		}
		return Checker.isTupleType(t);
	}
}
