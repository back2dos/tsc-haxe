package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/checker.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Part of checker.go, Go lines 27916-31926 (4011 lines): the Checker methods of this range as static extension
// (receiver first, PORTING.md §2; `using ts.checker.CheckerPart8` in import.hx). Inside class Checker call them as `this.m(...)`.
@:allow(ts.checker)
class CheckerPart8 {

	static function getSingleBaseForNonAugmentingSubtype(c:Checker, t:Type):Type {
		if ((t.objectFlags & ObjectFlagsReference) == 0 || (t.Target().objectFlags & ObjectFlagsClassOrInterface) == 0) {
			return null;
		}
		final key = CachedTypeKey.keyOf(CachedTypeKindEquivalentBaseType, t.id);
		if ((t.objectFlags & ObjectFlagsIdenticalBaseTypeCalculated) != 0) {
			return c.cachedTypes.get(key);
		}
		t.objectFlags |= ObjectFlagsIdenticalBaseTypeCalculated;
		final target = t.Target();
		if ((target.objectFlags & ObjectFlagsClass) != 0) {
			final baseTypeNode = Checker.getBaseTypeNodeOfClass(target);
			// A base type expression may circularly reference the class itself (e.g. as an argument to function call), so we only
			// check for base types specified as simple qualified names.
			if (baseTypeNode != null && !Ast.IsIdentifier(baseTypeNode.Expression()) && !Ast.IsPropertyAccessExpression(baseTypeNode.Expression())) {
				return null;
			}
		}
		final bases = c.getBaseTypes(target);
		if (Core.len(bases) != 1) {
			return null;
		}
		if (symbolTableLen(c.getMembersOfSymbol(t.symbol)) != 0) {
			// If the interface has any members, they may subtype members in the base, so we should do a full structural comparison
			return null;
		}
		var instantiatedBase:Type = null;
		final typeParameters = target.AsInterfaceType().TypeParameters();
		if (Core.len(typeParameters) == 0) {
			instantiatedBase = bases[0];
		} else {
			instantiatedBase = c.instantiateType(bases[0], Checker.newTypeMapper(typeParameters, c.getTypeArguments(t).slice(0, typeParameters.length)));
		}
		if (Core.len(c.getTypeArguments(t)) > Core.len(typeParameters)) {
			instantiatedBase = c.getTypeWithThisArgument(instantiatedBase, Core.LastOrNil(c.getTypeArguments(t)), false);
		}
		c.cachedTypes.set(key, instantiatedBase);
		return instantiatedBase;
	}

	static function getModifiersTypeFromMappedType(c:Checker, t:Type):Type {
		final m = t.AsMappedType();
		if (m.modifiersType == null) {
			if (c.isMappedTypeWithKeyofConstraintDeclaration(t)) {
				// If the constraint declaration is a 'keyof T' node, the modifiers type is T. We check
				// AST nodes here because, when T is a non-generic type, the logic below eagerly resolves
				// 'keyof T' to a literal union type and we can't recover T from that type.
				m.modifiersType = c.instantiateType(c.getTypeFromTypeNode(c.getConstraintDeclarationForMappedType(t).Type()), m.mapper);
			} else {
				// Otherwise, get the declared constraint type, and if the constraint type is a type parameter,
				// get the constraint of that type parameter. If the resulting type is an indexed type 'keyof T',
				// the modifiers type is T. Otherwise, the modifiers type is unknown.
				final declaredType = c.getTypeFromMappedTypeNode(m.declaration.AsNode());
				final constraint = c.getConstraintTypeFromMappedType(declaredType);
				var extendedConstraint = constraint;
				if (constraint != null && (constraint.flags & TypeFlagsTypeParameter) != 0) {
					extendedConstraint = c.getConstraintOfTypeParameter(constraint);
				}
				if (extendedConstraint != null && (extendedConstraint.flags & TypeFlagsIndex) != 0) {
					m.modifiersType = c.instantiateType(extendedConstraint.AsIndexType().target, m.mapper);
				} else {
					m.modifiersType = c.unknownType;
				}
			}
		}
		return m.modifiersType;
	}

	static function extractTypesOfKind(c:Checker, t:Type, kind:TypeFlags):Type {
		return c.filterType(t, t -> (t.flags & kind) != 0);
	}

	static function getRegularTypeOfObjectLiteral(c:Checker, t:Type):Type {
		if (!(Checker.isObjectLiteralType(t) && (t.objectFlags & ObjectFlagsFreshLiteral) != 0)) {
			return t;
		}
		final key = CachedTypeKey.keyOf(CachedTypeKindRegularObjectLiteral, t.id);
		final cached = c.cachedTypes.get(key);
		if (cached != null) {
			return cached;
		}
		final resolved = c.resolveStructuredTypeMembers(t);
		final members = c.transformTypeOfMembers(t, fn_getRegularTypeOfObjectLiteral(c));
		final regular = c.newAnonymousType(t.symbol, members, resolved.CallSignatures(), resolved.ConstructSignatures(), resolved.indexInfos);
		regular.flags = resolved.flags;
		regular.objectFlags |= (resolved.objectFlags & ~ObjectFlagsFreshLiteral);
		c.cachedTypes.set(key, regular);
		return regular;
	}

	static function transformTypeOfMembers(c:Checker, t:Type, f:(propertyType:Type) -> Type):SymbolTable {
		final members = new SymbolTable();
		for (p in rangeOf(c.getPropertiesOfObjectType(t))) {
			var property = p;
			final original = c.getTypeOfSymbol(property);
			final updated = f(original);
			if (updated != original) {
				property = c.createSymbolWithType(property, updated);
			}
			members.set(property.Name, property);
		}
		return members;
	}

	static function markLinkedReferences(c:Checker, location:Node, hint:ReferenceHint, propSymbol:Symbol, parentType:Type):Void {
		if (!c.canCollectSymbolAliasAccessibilityData) {
			return;
		}
		if ((location.Flags & NodeFlagsAmbient) != 0 && !Ast.IsPropertySignatureDeclaration(location) && !Ast.IsPropertyDeclaration(location)) {
			// References within types and declaration files are never going to contribute to retaining a JS import,
			// except for properties (which can be decorated).
			return;
		}
		switch (hint) {
			case ReferenceHintIdentifier:
				c.markIdentifierAliasReferenced(location);
			case ReferenceHintProperty:
				c.markPropertyAliasReferenced(location, propSymbol, parentType);
			case ReferenceHintExportAssignment:
				c.markExportAssignmentAliasReferenced(location);
			case ReferenceHintJsx:
				c.markJsxAliasReferenced(location);
			case ReferenceHintExportImportEquals:
				c.markImportEqualsAliasReferenced(location);
			case ReferenceHintExportSpecifier:
				c.markExportSpecifierAliasReferenced(location);
			case ReferenceHintDecorator:
				c.markDecoratorAliasReferenced(location);
			case ReferenceHintUnspecified:
				if (Ast.IsJsxTagName(location) && Checker.isJsxIntrinsicTagName(location)) {
					return; // builtin JSX tag names aren't real type refs by most metrics, but are expressions, so must be filtered
				}
				if (Ast.FindAncestor(location, n -> Ast.IsMetaProperty(n)) != null) {
					return; // identifiers in meta properties shouldn't be resolved, but are expressions, so must be filtered
				}
				// Identifiers in expression contexts are emitted, so we need to follow their referenced aliases and mark them as used
				// Some non-expression identifiers are also treated as expression identifiers for this purpose, eg, `a` in `b = {a}` or `q` in `import r = q`
				// This is the exception, rather than the rule - most non-expression identifiers are declaration names.
				if (Ast.IsIdentifier(location)
					&& (Ast.IsExpressionNode(location)
						|| Ast.IsShorthandPropertyAssignment(location.Parent)
						|| (Ast.IsImportEqualsDeclaration(location.Parent)
							&& location.Parent.AsImportEqualsDeclaration().ModuleReference == location))
					&& Checker.shouldMarkIdentifierAliasReferenced(location)) {
					if (Ast.IsPropertyAccessOrQualifiedName(location.Parent)) {
						var left:Node = null;
						if (Ast.IsPropertyAccessExpression(location.Parent)) {
							left = location.Parent.Expression();
						} else {
							left = location.Parent.AsQualifiedName().Left;
						}
						if (left != location) {
							return; // Only mark the LHS (the RHS is a property lookup)
						}
					}
					c.markIdentifierAliasReferenced(location);
					return;
				}
				if (Ast.IsPropertyAccessOrQualifiedName(location)) {
					var topProp = location;
					while (Ast.IsPropertyAccessOrQualifiedName(topProp)) {
						if (Ast.IsPartOfTypeNode(topProp)) {
							return;
						}
						topProp = topProp.Parent;
					}
					c.markPropertyAliasReferenced(location, null /*propSymbol*/, null /*parentType*/);
					return;
				}
				if (Ast.IsExportAssignment(location)) {
					c.markExportAssignmentAliasReferenced(location);
					return;
				}
				if (Ast.IsJsxOpeningLikeElement(location) || Ast.IsJsxOpeningFragment(location)) {
					c.markJsxAliasReferenced(location);
					return;
				}
				if (Ast.IsImportEqualsDeclaration(location)) {
					if (Checker.isInternalModuleImportEqualsDeclaration(location) || c.checkExternalImportOrExportDeclaration(location)) {
						c.markImportEqualsAliasReferenced(location);
						return;
					}
					return;
				}
				if (Ast.IsExportSpecifier(location)) {
					c.markExportSpecifierAliasReferenced(location);
					return;
				}
				if (!c.compilerOptions.EmitDecoratorMetadata.IsTrue()) {
					return;
				}
				if (!Ast.CanHaveDecorators(location) || !Ast.HasDecorators(location) || location.Modifiers() == null
					|| !Ast.NodeCanBeDecorated(c.legacyDecorators, location, location.Parent, location.Parent.Parent)) {
					return;
				}

				c.markDecoratorAliasReferenced(location);
				return;
			default:
				throw "Unhandled reference hint";
		}
	}

	static function markIdentifierAliasReferenced(c:Checker, location:IdentifierNode):Void {
		final symbol = c.getResolvedSymbol(location);
		if (symbol != null && symbol != c.argumentsSymbol && symbol != c.unknownSymbol && !Ast.IsThisInTypeQuery(location)) {
			c.markAliasReferenced(symbol, location);
		}
	}

	static function markPropertyAliasReferenced(c:Checker, location:Node, propSymbol:Symbol, parentType:Type):Void {
		if (Checker.isPartOfImportEqualsModuleReference(location)) {
			return;
		}
		var left:Node = null;
		if (Ast.IsPropertyAccessExpression(location)) {
			left = location.Expression();
		} else {
			left = location.AsQualifiedName().Left;
		}
		if (Ast.IsThisIdentifier(left) || !Ast.IsIdentifier(left)) {
			return;
		}
		final parentSymbol = c.getResolvedSymbol(left);
		if (parentSymbol == null || parentSymbol == c.unknownSymbol) {
			return;
		}
		// In `Foo.Bar.Baz`, 'Foo' is not referenced if 'Bar' is a const enum or a module containing only const enums.
		// `Foo` is also not referenced in `enum FooCopy { Bar = Foo.Bar }`, because the enum member value gets inlined
		// here even if `Foo` is not a const enum.
		//
		// The exceptions are:
		//   1. if 'isolatedModules' is enabled, because the const enum value will not be inlined, and
		//   2. if 'preserveConstEnums' is enabled and the expression is itself an export, e.g. `export = Foo.Bar.Baz`.
		//
		// The property lookup is deferred as much as possible, in as many situations as possible, to avoid alias marking
		// pulling on types/symbols it doesn't strictly need to.
		if (c.compilerOptions.GetIsolatedModules() || (c.compilerOptions.ShouldPreserveConstEnums() && Checker.isExportOrExportExpression(location))) {
			c.markAliasReferenced(parentSymbol, location);
			return;
		}
		// Hereafter, this relies on type checking - but every check prior to this only used symbol information
		var leftType = parentType;
		if (leftType == null) {
			leftType = c.checkExpressionCached(left);
		}
		if (Checker.IsTypeAny(leftType) || leftType == c.silentNeverType) {
			c.markAliasReferenced(parentSymbol, location);
			return;
		}
		var prop = propSymbol;
		if (prop == null && parentType == null) {
			var right:Node = null;
			if (Ast.IsPropertyAccessExpression(location)) {
				right = location.AsPropertyAccessExpression().Name();
			} else {
				right = location.AsQualifiedName().Right;
			}
			var lexicallyScopedSymbol:Symbol = null;
			if (Ast.IsPrivateIdentifier(right)) {
				lexicallyScopedSymbol = c.lookupSymbolForPrivateIdentifierDeclaration(right.Text(), right);
			}
			final assignmentKind = Checker.getAssignmentTargetKind(location);
			var apparentType:Type = null;
			if (assignmentKind != AssignmentKindNone || c.isMethodAccessForCall(location)) {
				apparentType = c.getApparentType(c.getWidenedType(leftType));
			} else {
				apparentType = c.getApparentType(leftType);
			}
			if (Ast.IsPrivateIdentifier(right)) {
				if (lexicallyScopedSymbol != null) {
					prop = c.getPrivateIdentifierPropertyOfType(apparentType, lexicallyScopedSymbol);
				}
			} else {
				prop = c.getPropertyOfType(apparentType, right.Text());
			}
		}
		if (!(prop != null
			&& (Checker.isConstEnumOrConstEnumOnlyModule(prop) || (prop.Flags & SymbolFlagsEnumMember) != 0 && location.Parent.Kind == KindEnumMember))) {
			c.markAliasReferenced(parentSymbol, location);
		}
	}

	static function markExportAssignmentAliasReferenced(c:Checker, location:Node):Void {
		final id = location.Expression();
		if (Ast.IsIdentifier(id)) {
			final sym = c.getExportSymbolOfValueSymbolIfExported(c.resolveEntityName(id, SymbolFlagsAll, true /*ignoreErrors*/, true /*dontResolveAlias*/, location));
			if (sym != null) {
				c.markAliasReferenced(sym, id);
			}
		}
	}

	static function markJsxAliasReferenced(c:Checker, node:Node):Void {
		if (c.getJsxNamespaceContainerForImplicitImport(node) != null) {
			return;
		}
		// The reactNamespace/jsxFactory's root symbol should be marked as 'used' so we don't incorrectly elide its import.
		// And if there is no reactNamespace/jsxFactory's symbol in scope when targeting React emit, we should issue an error.
		final jsxFactoryRefErr:Message = c.compilerOptions.Jsx == JsxEmitReact ? Diagnostics.This_JSX_tag_requires_0_to_be_in_scope_but_it_could_not_be_found : null;
		final jsxFactoryNamespace = c.getJsxNamespace(node);
		var jsxFactoryLocation = node;
		if (Ast.IsJsxOpeningLikeElement(node)) {
			jsxFactoryLocation = node.TagName();
		}
		final shouldFactoryRefErr = c.compilerOptions.Jsx != JsxEmitPreserve && c.compilerOptions.Jsx != JsxEmitReactNative;
		// #38720/60122, allow null as jsxFragmentFactory
		var jsxFactorySym:Symbol = null;
		if (!(Ast.IsJsxOpeningFragment(node) && jsxFactoryNamespace == "null")) {
			var flags:SymbolFlags = SymbolFlagsValue;
			if (!shouldFactoryRefErr) {
				flags &= ~SymbolFlagsEnum;
			}
			jsxFactorySym = c.resolveName(jsxFactoryLocation, jsxFactoryNamespace, flags, jsxFactoryRefErr, true /*isUse*/, false /*excludeGlobals*/);
		}
		if (jsxFactorySym != null) {
			// Mark local symbol as referenced here because it might not have been marked
			// if jsx emit was not jsxFactory as there wont be error being emitted
			c.symbolReferenced(jsxFactorySym, SymbolFlagsAll);
			// If react/jsxFactory symbol is alias, mark it as referenced
			if (c.canCollectSymbolAliasAccessibilityData && (jsxFactorySym.Flags & SymbolFlagsAlias) != 0 && c.getTypeOnlyAliasDeclaration(jsxFactorySym) == null) {
				c.markAliasSymbolAsReferenced(jsxFactorySym);
			}
		}
		// if JsxFragment, additionally mark jsx pragma as referenced, since `getJsxNamespace` above would have resolved to only the fragment factory if they are distinct
		if (Ast.IsJsxOpeningFragment(node)) {
			final file = Ast.GetSourceFileOfNode(node);
			final entity = c.getJsxFactoryEntity(file.AsNode());
			if (entity != null) {
				final localJsxNamespace = Ast.GetFirstIdentifier(entity).Text();
				var flags:SymbolFlags = SymbolFlagsValue;
				if (!shouldFactoryRefErr) {
					flags &= ~SymbolFlagsEnum;
				}
				c.resolveName(jsxFactoryLocation, localJsxNamespace, flags, jsxFactoryRefErr, true /*isUse*/, false /*excludeGlobals*/);
			}
		}
	}

	static function markImportEqualsAliasReferenced(c:Checker, location:Node):Void {
		if (Ast.HasSyntacticModifier(location, ModifierFlagsExport)) {
			c.markExportAsReferenced(location);
		}
	}

	static function markExportSpecifierAliasReferenced(c:Checker, location:ExportSpecifierNode):Void {
		if (location.Parent.Parent.ModuleSpecifier() == null && !location.IsTypeOnly() && !location.Parent.Parent.IsTypeOnly()) {
			final exportedName = location.PropertyNameOrName();
			if (exportedName.Kind == KindStringLiteral) {
				return; // Skip for invalid syntax like this: export { "x" }
			}
			final symbol = c.resolveName(exportedName, exportedName.Text(), SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace | SymbolFlagsAlias, null /*nameNotFoundMessage*/, true /*isUse*/, false /*excludeGlobals*/);
			if (symbol != null
				&& (symbol == c.undefinedSymbol || symbol == c.globalThisSymbol
					|| symbol.Declarations != null && Ast.IsGlobalSourceFile(Ast.GetDeclarationContainer(symbol.Declarations[0])))) {
				// Do nothing, non-local symbol
			} else {
				var target = symbol;
				if (target != null && (target.Flags & SymbolFlagsAlias) != 0) {
					target = c.resolveAlias(target);
				}
				if (target == null || (c.getSymbolFlags(target) & SymbolFlagsValue) != 0) {
					c.markExportAsReferenced(location); // marks export as used
					c.markIdentifierAliasReferenced(exportedName); // marks target of export as used
				}
			}
		}
	}

	static function checkExternalEmitHelpers(c:Checker, location:Node, helpers:ExternalEmitHelpers):Void {
		if (!c.compilerOptions.ImportHelpers.IsTrue()) {
			return;
		}
		final sourceFile = Ast.GetSourceFileOfNode(location);
		if (!Ast.IsEffectiveExternalModule(sourceFile, c.compilerOptions) || (location.Flags & NodeFlagsAmbient) != 0) {
			return;
		}
		final helpersModule = c.resolveHelpersModule(sourceFile, location);
		if (helpersModule == c.unknownSymbol) {
			return;
		}
		final links = c.sourceFileLinks.Get(sourceFile);
		if ((links.requestedExternalEmitHelpers & helpers) != helpers) {
			final uncheckedHelpers = helpers & ~links.requestedExternalEmitHelpers;
			// PORT: Go `for helper := First; helper <= Last; helper <<= 1` with `continue` → while loop that advances first.
			var next:Int = (ExternalEmitHelpersFirstEmitHelper : Int);
			while (next <= (ExternalEmitHelpersLastEmitHelper : Int)) {
				final helper:ExternalEmitHelpers = next;
				next <<= 1;
				if ((uncheckedHelpers & helper) == 0) {
					continue;
				}
				for (name in c.getHelperNames(helper)) {
					final symbol = c.resolveSymbol(c.getSymbol(c.getExportsOfModule(helpersModule), name, SymbolFlagsValue));
					if (symbol == null) {
						c.error(location, Diagnostics.This_syntax_requires_an_imported_helper_named_1_which_does_not_exist_in_0_Consider_upgrading_your_version_of_0, Checker.externalHelpersModuleNameText, name);
					} else if ((helper & ExternalEmitHelpersClassPrivateFieldGet) != 0) {
						if (!c.hasSignatureWithArityGreaterThan(symbol, 3)) {
							c.error(location, Diagnostics.This_syntax_requires_an_imported_helper_named_1_with_2_parameters_which_is_not_compatible_with_the_one_in_0_Consider_upgrading_your_version_of_0, Checker.externalHelpersModuleNameText, name, 4);
						}
					} else if ((helper & ExternalEmitHelpersClassPrivateFieldSet) != 0) {
						if (!c.hasSignatureWithArityGreaterThan(symbol, 4)) {
							c.error(location, Diagnostics.This_syntax_requires_an_imported_helper_named_1_with_2_parameters_which_is_not_compatible_with_the_one_in_0_Consider_upgrading_your_version_of_0, Checker.externalHelpersModuleNameText, name, 5);
						}
					}
				}
			}
		}
		links.requestedExternalEmitHelpers |= helpers;
	}

	static function hasSignatureWithArityGreaterThan(c:Checker, symbol:Symbol, arity:Int):Bool {
		for (signature in rangeOf(c.getSignaturesOfSymbol(symbol))) {
			if (c.getParameterCount(signature) > arity) {
				return true;
			}
		}
		return false;
	}

	static function getHelperNames(c:Checker, helper:ExternalEmitHelpers):Array<std.String> {
		switch (helper) {
			case ExternalEmitHelpersRest:
				return ["__rest"];
			case ExternalEmitHelpersDecorate:
				if (c.legacyDecorators) {
					return ["__decorate"];
				}
				return ["__esDecorate", "__runInitializers"];
			case ExternalEmitHelpersMetadata:
				return ["__metadata"];
			case ExternalEmitHelpersParam:
				return ["__param"];
			case ExternalEmitHelpersAwaiter:
				return ["__awaiter"];
			case ExternalEmitHelpersAwait:
				return ["__await"];
			case ExternalEmitHelpersAsyncGenerator:
				return ["__asyncGenerator"];
			case ExternalEmitHelpersAsyncDelegator:
				return ["__asyncDelegator"];
			case ExternalEmitHelpersAsyncValues:
				return ["__asyncValues"];
			case ExternalEmitHelpersExportStar:
				return ["__exportStar"];
			case ExternalEmitHelpersImportStar:
				return ["__importStar"];
			case ExternalEmitHelpersImportDefault:
				return ["__importDefault"];
			case ExternalEmitHelpersMakeTemplateObject:
				return ["__makeTemplateObject"];
			case ExternalEmitHelpersClassPrivateFieldGet:
				return ["__classPrivateFieldGet"];
			case ExternalEmitHelpersClassPrivateFieldSet:
				return ["__classPrivateFieldSet"];
			case ExternalEmitHelpersClassPrivateFieldIn:
				return ["__classPrivateFieldIn"];
			case ExternalEmitHelpersSetFunctionName:
				return ["__setFunctionName"];
			case ExternalEmitHelpersPropKey:
				return ["__propKey"];
			case ExternalEmitHelpersAddDisposableResourceAndDisposeResources:
				return ["__addDisposableResource", "__disposeResources"];
			case ExternalEmitHelpersRewriteRelativeImportExtension:
				return ["__rewriteRelativeImportExtension"];
			default:
				throw "Unrecognized helper";
		}
	}

	static function resolveHelpersModule(c:Checker, file:SourceFile, errorNode:Node):Symbol {
		final links = c.sourceFileLinks.Get(file);
		if (links.externalHelpersModule == null) {
			final location = c.program.GetImportHelpersImportSpecifier(file.Path());
			var helpersModule = c.resolveExternalModule(location, Checker.externalHelpersModuleNameText, Diagnostics.This_syntax_requires_an_imported_helper_but_module_0_cannot_be_found, errorNode, false /*isForAugmentation*/);
			if (helpersModule == null) {
				helpersModule = c.unknownSymbol;
			}
			links.externalHelpersModule = helpersModule;
		}
		return links.externalHelpersModule;
	}

	static function markDecoratorAliasReferenced(c:Checker, node:Node):Void {
		if (c.compilerOptions.EmitDecoratorMetadata.IsFalseOrUnknown()) {
			return;
		}
		final firstDecorator = Core.FirstOrNil(node.Decorators());
		if (firstDecorator == null) {
			return;
		}

		c.checkExternalEmitHelpers(firstDecorator, ExternalEmitHelpersMetadata);

		// we only need to perform these checks if we are emitting serialized type metadata for the target of a decorator.
		switch (node.Kind) {
			case KindClassDeclaration:
				final ctor = Ast.GetFirstConstructorWithBody(node);
				if (ctor != null) {
					for (p in rangeOf(ctor.Parameters())) {
						c.markDecoratorMedataDataTypeNodeAsReferenced(c.getParameterTypeNodeForDecoratorCheck(p));
					}
				}
			case KindGetAccessor, KindSetAccessor:
				var otherKind = KindSetAccessor;
				if (node.Kind == KindSetAccessor) {
					otherKind = KindGetAccessor;
				}
				final otherAccessor = Ast.GetDeclarationOfKind(c.getSymbolOfDeclaration(node), otherKind);
				var annotation = c.getAnnotatedAccessorTypeNode(node);
				if (annotation == null && otherAccessor != null) {
					annotation = c.getAnnotatedAccessorTypeNode(otherAccessor);
				}
				c.markDecoratorMedataDataTypeNodeAsReferenced(annotation);
			case KindMethodDeclaration:
				for (p in rangeOf(node.Parameters())) {
					c.markDecoratorMedataDataTypeNodeAsReferenced(c.getParameterTypeNodeForDecoratorCheck(p));
				}
				c.markDecoratorMedataDataTypeNodeAsReferenced(node.Type());
			case KindPropertyDeclaration:
				c.markDecoratorMedataDataTypeNodeAsReferenced(node.Type());
			case KindParameter:
				c.markDecoratorMedataDataTypeNodeAsReferenced(c.getParameterTypeNodeForDecoratorCheck(node));
				final containingSignature = node.Parent;
				for (p in rangeOf(containingSignature.Parameters())) {
					c.markDecoratorMedataDataTypeNodeAsReferenced(c.getParameterTypeNodeForDecoratorCheck(p));
				}
				c.markDecoratorMedataDataTypeNodeAsReferenced(containingSignature.Type());
			default:
		}
	}

	static function getParameterTypeNodeForDecoratorCheck(c:Checker, node:ParameterDeclarationNode):Node {
		final typeNode = node.Type();
		if (node.AsParameterDeclaration().DotDotDotToken != null) {
			return Ast.GetRestParameterElementType(typeNode);
		}
		return typeNode;
	}

	static function markDecoratorMedataDataTypeNodeAsReferenced(c:Checker, node:Node):Void {
		final entityName = c.getEntityNameForDecoratorMetadata(node);
		if (entityName != null && Ast.IsEntityName(entityName)) {
			c.markEntityNameOrEntityExpressionAsReference(entityName, true);
		}
	}

	static function getEntityNameForDecoratorMetadata(c:Checker, node:Node):Node {
		if (node == null) {
			return node;
		}
		switch (node.Kind) {
			case KindIntersectionType:
				return c.getEntityNameForDecoratorMetadataFromTypeList(node.AsIntersectionTypeNode().Types.Nodes);
			case KindUnionType:
				return c.getEntityNameForDecoratorMetadataFromTypeList(node.AsUnionTypeNode().Types.Nodes);
			case KindConditionalType:
				return c.getEntityNameForDecoratorMetadataFromTypeList([node.AsConditionalTypeNode().TrueType, node.AsConditionalTypeNode().FalseType]);
			case KindParenthesizedType:
				return c.getEntityNameForDecoratorMetadata(node.AsParenthesizedTypeNode().Type);
			case KindNamedTupleMember:
				return c.getEntityNameForDecoratorMetadata(node.AsNamedTupleMember().Type);
			case KindTypeReference:
				return node.AsTypeReferenceNode().TypeName;
			default:
		}
		return null;
	}

	static function getEntityNameForDecoratorMetadataFromTypeList(c:Checker, typeNodes:Array<Node>):Node {
		var commonEntityName:Node = null;
		for (typeNode in rangeOf(typeNodes)) {
			if (typeNode.Kind == KindNeverKeyword) {
				continue; // Always elide `never` from the union/intersection if possible
			}
			if (!c.strictNullChecks
				&& (typeNode.Kind == KindLiteralType && typeNode.AsLiteralTypeNode().Literal.Kind == KindNullKeyword || typeNode.Kind == KindUndefinedKeyword)) {
				continue; // Elide null and undefined from unions for metadata, just like what we did prior to the implementation of strict null checks
			}
			final individualEntityName = c.getEntityNameForDecoratorMetadata(typeNode);
			if (individualEntityName == null) {
				// Individual is something like string number
				// So it would be serialized to either that type or object
				// Safe to return here
				return null;
			}

			if (commonEntityName == null) {
				commonEntityName = individualEntityName;
			} else {
				// Note this is in sync with the transformation that happens for type node.
				// Keep this in sync with serializeUnionOrIntersectionType
				// Verify if they refer to same entity and is identifier
				// return undefined if they dont match because we would emit object
				if (!Ast.IsIdentifier(commonEntityName) || !Ast.IsIdentifier(individualEntityName)
					|| commonEntityName.AsIdentifier().Text != individualEntityName.AsIdentifier().Text) {
					return null;
				}
			}
		}
		return commonEntityName;
	}

	static function markAliasReferenced(c:Checker, symbol:Symbol, location:Node):Void {
		if (!c.canCollectSymbolAliasAccessibilityData) {
			return;
		}
		if (Ast.IsNonLocalAlias(symbol, SymbolFlagsValue /*excludes*/) && !Checker.IsInTypeQuery(location)) {
			final target = c.resolveAlias(symbol);
			if ((c.getSymbolFlagsEx(symbol, true /*excludeTypeOnlyMeanings*/, false /*excludeLocalMeanings*/) & (SymbolFlagsValue | SymbolFlagsExportValue)) != 0) {
				// An alias resolving to a const enum cannot be elided if (1) 'isolatedModules' is enabled
				// (because the const enum value will not be inlined), or if (2) the alias is an export
				// of a const enum declaration that will be preserved.
				if (c.compilerOptions.GetIsolatedModules()
					|| c.compilerOptions.ShouldPreserveConstEnums() && Checker.isExportOrExportExpression(location)
					|| !Checker.isConstEnumOrConstEnumOnlyModule(c.getExportSymbolOfValueSymbolIfExported(target))) {
					c.markAliasSymbolAsReferenced(symbol);
				}
			}
		}
	}

	// When an alias symbol is referenced, we need to mark the entity it references as referenced and in turn repeat that until
	// we reach a non-alias or an exported entity (which is always considered referenced). We do this by checking the target of
	// the alias as an expression (which recursively takes us back here if the target references another alias).
	static function markAliasSymbolAsReferenced(c:Checker, symbol:Symbol):Void {
		final links = c.aliasSymbolLinks.Get(symbol);
		if (!links.referenced) {
			links.referenced = true;
			final node = c.getDeclarationOfAliasSymbol(symbol);
			if (node == null) {
				throw "Unexpected nil in markAliasSymbolAsReferenced";
			}
			// We defer checking of the reference of an `import =` until the import itself is referenced,
			// This way a chain of imports can be elided if ultimately the final input is only used in a type
			// position.
			if (Ast.IsImportEqualsDeclaration(node) && node.AsImportEqualsDeclaration().ModuleReference.Kind != KindExternalModuleReference) {
				if ((c.getSymbolFlags(c.resolveSymbol(symbol)) & SymbolFlagsValue) != 0) {
					// import foo = <symbol>
					final left = Ast.GetFirstIdentifier(node.AsImportEqualsDeclaration().ModuleReference);
					c.markIdentifierAliasReferenced(left);
				}
			}
		}
	}

	static function markExportAsReferenced(c:Checker, node:Node):Void {
		final symbol = c.getSymbolOfDeclaration(node);
		final target = c.resolveAlias(symbol);
		if (target != null) {
			final markAlias = target == c.unknownSymbol
				|| ((c.getSymbolFlagsEx(symbol, true /*excludeTypeOnlyMeanings*/, false /*excludeLocalMeanings*/) & SymbolFlagsValue) != 0
					&& !Checker.isConstEnumOrConstEnumOnlyModule(target));
			if (markAlias) {
				c.markAliasSymbolAsReferenced(symbol);
			}
		}
	}

	static function markEntityNameOrEntityExpressionAsReference(c:Checker, typeName:Node, forDecoratorMetadata:Bool):Void {
		if (typeName == null) {
			return;
		}

		final rootName = Ast.GetFirstIdentifier(typeName);
		final meaning:SymbolFlags = (typeName.Kind == KindIdentifier ? SymbolFlagsType : SymbolFlagsNamespace) | SymbolFlagsAlias;
		final rootSymbol = c.resolveName(rootName, rootName.Text(), meaning, null /*nameNotFoundMessage*/, true /*isUse*/, false /*excludeGlobals*/);

		if (rootSymbol != null && (rootSymbol.Flags & SymbolFlagsAlias) != 0) {
			if (c.canCollectSymbolAliasAccessibilityData
				&& c.symbolIsValue(rootSymbol)
				&& !Checker.isConstEnumOrConstEnumOnlyModule(c.resolveAlias(rootSymbol))
				&& c.getTypeOnlyAliasDeclaration(rootSymbol) == null) {
				c.markAliasSymbolAsReferenced(rootSymbol);
			} else if (forDecoratorMetadata
				&& c.compilerOptions.GetIsolatedModules()
				&& (c.compilerOptions.GetEmitModuleKind() : Int) >= (ModuleKindES2015 : Int)
				&& !c.symbolIsValue(rootSymbol)
				&& !Core.Some(rootSymbol.Declarations, n -> Ast.IsTypeOnlyImportOrExportDeclaration(n))) {
				final diag = c.error(typeName,
					Diagnostics.A_type_referenced_in_a_decorated_signature_must_be_imported_with_import_type_or_a_namespace_import_when_isolatedModules_and_emitDecoratorMetadata_are_enabled);
				var aliasDeclaration:Node = null;
				for (decl in rangeOf(rootSymbol.Declarations)) {
					if (Ast.IsAliasSymbolDeclaration(decl)) {
						aliasDeclaration = decl;
						break;
					}
				}
				if (aliasDeclaration != null) {
					diag.SetRelatedInfo([Checker.createDiagnosticForNode(aliasDeclaration, Diagnostics.X_0_was_imported_here, rootName.Text())]);
				}
			}
		}
	}

	// If a TypeNode can be resolved to a value symbol imported from an external module, it is
	// marked as referenced to prevent import elision.
	static function markTypeNodeAsReferenced(c:Checker, node:TypeNode):Void {
		if (node != null) {
			c.markEntityNameOrEntityExpressionAsReference(Checker.getEntityNameFromTypeNode(node), false /*forDecoratorMetadata*/);
		}
	}

	public static function GetPromisedTypeOfPromise(c:Checker, t:Type):Type {
		return c.getPromisedTypeOfPromiseEx(t, null, null);
	}

	// Gets the "promised type" of a promise.
	// @param type The type of the promise.
	// @remarks The "promised type" of a type is the type of the "value" parameter of the "onfulfilled" callback.
	// PORT: pointer. Go `thisTypeForErrorOut **Type` → a one-element array (null for Go nil); signature fixed (all callers are in this module).
	static function getPromisedTypeOfPromiseEx(c:Checker, t:Type, errorNode:Node, thisTypeForErrorOut:Array<Type>):Type {
		//  { // type
		//      then( // thenFunction
		//          onfulfilled: ( // onfulfilledParameterType
		//              value: T // valueParameterType
		//          ) => any
		//      ): any;
		//  }
		if (Checker.IsTypeAny(t)) {
			return null;
		}
		final key = CachedTypeKey.keyOf(CachedTypeKindPromisedTypeOfPromise, t.id);
		final cached = c.cachedTypes.get(key);
		if (cached != null) {
			return cached;
		}
		if (c.isReferenceToType(t, c.getGlobalPromiseType())) {
			final result = c.getTypeArguments(t)[0];
			c.cachedTypes.set(key, result);
			return result;
		}
		// primitives with a `{ then() }` won't be unwrapped/adopted.
		if (c.allTypesAssignableToKind(c.getBaseConstraintOrType(t), TypeFlagsPrimitive | TypeFlagsNever)) {
			return null;
		}
		final thenFunction = c.getTypeOfPropertyOfType(t, "then");
		// TODO: GH#18217
		if (Checker.IsTypeAny(thenFunction)) {
			return null;
		}
		var thenSignatures:Array<Signature> = null;
		if (thenFunction != null) {
			thenSignatures = c.getSignaturesOfType(thenFunction, SignatureKindCall);
		}
		if (Core.len(thenSignatures) == 0) {
			if (errorNode != null) {
				c.error(errorNode, Diagnostics.A_promise_must_have_a_then_method);
			}
			return null;
		}
		var thisTypeForError:Type = null;
		final candidates:Array<Signature> = [];
		for (thenSignature in thenSignatures) {
			final thisType = c.getThisTypeOfSignature(thenSignature);
			if (thisType != null && thisType != c.voidType && !c.isTypeRelatedTo(t, thisType, c.subtypeRelation)) {
				thisTypeForError = thisType;
			} else {
				candidates.push(thenSignature);
			}
		}
		if (candidates.length == 0) {
			Debug.Assert(thisTypeForError != null);
			if (thisTypeForErrorOut != null) {
				thisTypeForErrorOut[0] = thisTypeForError;
			}
			if (errorNode != null) {
				c.error(errorNode, Diagnostics.The_this_context_of_type_0_is_not_assignable_to_method_s_this_of_type_1, c.TypeToString(t), c.TypeToString(thisTypeForError));
			}
			return null;
		}
		final getTypeOfFirstParameterOfSignature = (s:Signature) -> c.getTypeOfFirstParameterOfSignature(s);
		final onfulfilledParameterType = c.getTypeWithFacts(c.getUnionType(Core.Map(candidates, getTypeOfFirstParameterOfSignature)), TypeFactsNEUndefinedOrNull);
		if (Checker.IsTypeAny(onfulfilledParameterType)) {
			return null;
		}
		final onfulfilledParameterSignatures = c.getSignaturesOfType(onfulfilledParameterType, SignatureKindCall);
		if (Core.len(onfulfilledParameterSignatures) == 0) {
			if (errorNode != null) {
				c.error(errorNode, Diagnostics.The_first_parameter_of_the_then_method_of_a_promise_must_be_a_callback);
			}
			return null;
		}
		final result = c.getUnionTypeEx(Core.Map(onfulfilledParameterSignatures, getTypeOfFirstParameterOfSignature), UnionReductionSubtype, null, null);
		c.cachedTypes.set(key, result);
		return result;
	}

	static function getTypeOfFirstParameterOfSignature(c:Checker, signature:Signature):Type {
		return c.getTypeOfFirstParameterOfSignatureWithFallback(signature, c.neverType);
	}

	static function getTypeOfFirstParameterOfSignatureWithFallback(c:Checker, signature:Signature, fallbackType:Type):Type {
		if (Core.len(signature.parameters) > 0) {
			return c.getTypeAtPosition(signature, 0);
		}
		return fallbackType;
	}

	// Return -1, 0, or 1, for stripped, unchanged, or added optionality respectively. When a homomorphic mapped type doesn't
	// modify optionality, recursively consult the optionality of the type being mapped over to see if it strips or adds optionality.
	// For intersections, return -1 or 1 when all constituents strip or add optionality, otherwise return 0.
	static function getCombinedMappedTypeOptionality(c:Checker, t:Type):Int {
		if ((t.objectFlags & ObjectFlagsMapped) != 0) {
			final optionality = Checker.getMappedTypeOptionality(t);
			if (optionality != 0) {
				return optionality;
			}
			return c.getCombinedMappedTypeOptionality(c.getModifiersTypeFromMappedType(t));
		}
		if ((t.flags & TypeFlagsIntersection) != 0) {
			final types = t.Types();
			final optionality = c.getCombinedMappedTypeOptionality(types[0]);
			for (i in 1...types.length) {
				if (c.getCombinedMappedTypeOptionality(types[i]) != optionality) {
					return 0;
				}
			}
			return optionality;
		}
		return 0;
	}

	static function getOptionalExpressionType(c:Checker, exprType:Type, expression:Node):Type {
		if (Ast.IsExpressionOfOptionalChainRoot(expression)) {
			return c.GetNonNullableType(exprType);
		} else if (Ast.IsOptionalChain(expression)) {
			return c.removeOptionalTypeMarker(exprType);
		} else {
			return exprType;
		}
	}

	static function removeOptionalTypeMarker(c:Checker, t:Type):Type {
		if (c.strictNullChecks) {
			return c.removeType(t, c.optionalType);
		}
		return t;
	}

	static function propagateOptionalTypeMarker(c:Checker, t:Type, node:Node, wasOptional:Bool):Type {
		if (wasOptional) {
			if (Ast.IsOutermostOptionalChain(node)) {
				return c.getOptionalType(t, false);
			}
			return c.addOptionalTypeMarker(t);
		}
		return t;
	}

	static function removeMissingType(c:Checker, t:Type, isOptional:Bool):Type {
		if (c.exactOptionalPropertyTypes && isOptional) {
			return c.removeType(t, c.missingType);
		}
		return t;
	}

	static function removeMissingOrUndefinedType(c:Checker, t:Type):Type {
		if (c.exactOptionalPropertyTypes) {
			return c.removeType(t, c.missingType);
		}
		return c.getTypeWithFacts(t, TypeFactsNEUndefined);
	}

	static function removeDefinitelyFalsyTypes(c:Checker, t:Type):Type {
		return c.filterType(t, t -> c.hasTypeFacts(t, TypeFactsTruthy));
	}

	static function extractDefinitelyFalsyTypes(c:Checker, t:Type):Type {
		return c.mapType(t, t -> c.getDefinitelyFalsyPartOfType(t));
	}

	static function getDefinitelyFalsyPartOfType(c:Checker, t:Type):Type {
		if ((t.flags & TypeFlagsString) != 0) {
			return c.emptyStringType;
		} else if ((t.flags & TypeFlagsNumber) != 0) {
			return c.zeroType;
		} else if ((t.flags & TypeFlagsBigInt) != 0) {
			return c.zeroBigIntType;
		} else if (t == c.regularFalseType || t == c.falseType
			|| (t.flags & (TypeFlagsVoid | TypeFlagsUndefined | TypeFlagsNull | TypeFlagsAnyOrUnknown)) != 0
			|| (t.flags & TypeFlagsStringLiteral) != 0 && Checker.getStringLiteralValue(t) == ""
			|| (t.flags & TypeFlagsNumberLiteral) != 0 && (Checker.getNumberLiteralValue(t) : Float) == 0
			|| (t.flags & TypeFlagsBigIntLiteral) != 0 && Checker.isZeroBigInt(t)) {
			return t;
		}
		return c.neverType;
	}

	static function getConstraintDeclaration(c:Checker, t:Type):Node {
		if (t.symbol != null) {
			for (d in rangeOf(t.symbol.Declarations)) {
				if (Ast.IsTypeParameterDeclaration(d)) {
					final constraint = d.AsTypeParameterDeclaration().Constraint;
					if (constraint != null) {
						return constraint;
					}
				}
			}
		}
		return null;
	}

	static function getTemplateLiteralType(c:Checker, texts:Array<std.String>, types:Array<Type>):Type {
		final unionIndex = Core.FindIndex(types, t -> (t.flags & (TypeFlagsNever | TypeFlagsUnion)) != 0);
		if (unionIndex >= 0) {
			if (!c.checkCrossProductUnion(types)) {
				return c.errorType;
			}
			return c.mapType(types[unionIndex], t -> c.getTemplateLiteralType(texts, Core.ReplaceElement(types, unionIndex, t)));
		}
		if (Slices.Contains(types, c.wildcardType)) {
			return c.wildcardType;
		}
		// PORT: Go nil slices; both are non-empty wherever they are used below (the empty case returns early).
		final newTypes:Array<Type> = [];
		final newTexts:Array<std.String> = [];
		var sb = new StringBuf();
		sb.add(texts[0]);
		var addSpans:(Array<std.String>, Array<Type>) -> Bool = null;
		addSpans = function(texts:Array<std.String>, types:Array<Type>):Bool {
			for (i in 0...Core.len(types)) {
				final t = types[i];
				if ((t.flags & (TypeFlagsLiteral | TypeFlagsNull | TypeFlagsUndefined)) != 0) {
					sb.add(c.getTemplateStringForType(t));
					sb.add(texts[i + 1]);
				} else if ((t.flags & TypeFlagsTemplateLiteral) != 0) {
					sb.add(t.AsTemplateLiteralType().texts[0]);
					if (!addSpans(t.AsTemplateLiteralType().texts, t.AsTemplateLiteralType().types)) {
						return false;
					}
					sb.add(texts[i + 1]);
				} else if (c.isGenericIndexType(t) || c.isPatternLiteralPlaceholderType(t)) {
					newTypes.push(t);
					newTexts.push(Stringutil.CombineSurrogatePairs(sb.toString()));
					sb = new StringBuf();
					sb.add(texts[i + 1]);
				} else {
					return false;
				}
			}
			return true;
		};
		if (!addSpans(texts, types)) {
			return c.stringType;
		}
		if (newTypes.length == 0) {
			return c.getStringLiteralType(Stringutil.CombineSurrogatePairs(sb.toString()));
		}
		newTexts.push(Stringutil.CombineSurrogatePairs(sb.toString()));
		if (Core.Every(newTexts, t -> t == "")) {
			if (Core.Every(newTypes, t -> (t.flags & TypeFlagsString) != 0)) {
				return c.stringType;
			}
			// Normalize `${Mapping<xxx>}` into Mapping<xxx>
			if (newTypes.length == 1 && c.isPatternLiteralType(newTypes[0])) {
				return newTypes[0];
			}
		}
		final key = Checker.getTemplateTypeKey(newTexts, newTypes).Key();
		var t = c.templateLiteralTypes.get(key);
		if (t == null) {
			t = c.newTemplateLiteralType(newTexts, newTypes);
			c.templateLiteralTypes.set(key, t);
		}
		return t;
	}

	static function getTemplateStringForType(c:Checker, t:Type):std.String {
		if ((t.flags & (TypeFlagsStringLiteral | TypeFlagsNumberLiteral | TypeFlagsBooleanLiteral | TypeFlagsBigIntLiteral)) != 0) {
			return Evaluator.AnyToString(t.AsLiteralType().value);
		} else if ((t.flags & TypeFlagsNullable) != 0) {
			return t.AsIntrinsicType().intrinsicName;
		}
		return "";
	}

	static function getStringMappingType(c:Checker, symbol:Symbol, t:Type):Type {
		if ((t.flags & (TypeFlagsUnion | TypeFlagsNever)) != 0) {
			return c.mapType(t, t -> c.getStringMappingType(symbol, t));
		} else if ((t.flags & TypeFlagsStringLiteral) != 0) {
			return c.getStringLiteralType(Checker.applyStringMapping(symbol, Checker.getStringLiteralValue(t)));
		} else if ((t.flags & TypeFlagsTemplateLiteral) != 0) {
			final mapped = c.applyTemplateStringMapping(symbol, t.AsTemplateLiteralType().texts, t.AsTemplateLiteralType().types);
			return c.getTemplateLiteralType(mapped.a, mapped.b);
		} else if ((t.flags & TypeFlagsStringMapping) != 0 && symbol == t.symbol) {
			return t;
		} else if ((t.flags & (TypeFlagsAny | TypeFlagsString | TypeFlagsStringMapping)) != 0 || c.isGenericIndexType(t)) {
			return c.getStringMappingTypeForGenericType(symbol, t);
		} else if (c.isPatternLiteralPlaceholderType(t)) {
			return c.getStringMappingTypeForGenericType(symbol, c.getTemplateLiteralType(["", ""], [t]));
		} else {
			return t;
		}
	}

	static function applyTemplateStringMapping(c:Checker, symbol:Symbol, texts:Array<std.String>, types:Array<Type>):Pair<Array<std.String>, Array<Type>> {
		final kind:IntrinsicTypeKind = Checker.intrinsicTypeKinds.exists(symbol.Name) ? Checker.intrinsicTypeKinds.get(symbol.Name) : IntrinsicTypeKindUnknown;
		switch (kind) {
			case IntrinsicTypeKindUppercase, IntrinsicTypeKindLowercase:
				return new Pair(Core.Map(texts, t -> Checker.applyStringMapping(symbol, t)), Core.Map(types, t -> c.getStringMappingType(symbol, t)));
			case IntrinsicTypeKindCapitalize, IntrinsicTypeKindUncapitalize:
				if (texts[0] != "") {
					final newTexts = texts.copy();
					newTexts[0] = Checker.applyStringMapping(symbol, newTexts[0]);
					return new Pair(newTexts, types);
				}
				final newTypes = types.copy();
				newTypes[0] = c.getStringMappingType(symbol, newTypes[0]);
				return new Pair(texts, newTypes);
			default:
		}
		return new Pair(texts, types);
	}

	static function getStringMappingTypeForGenericType(c:Checker, symbol:Symbol, t:Type):Type {
		final key = StringMappingKey.keyOf(c, symbol, t);
		var result = c.stringMappingTypes.get(key);
		if (result == null) {
			result = c.newStringMappingType(symbol, t);
			c.stringMappingTypes.set(key, result);
		}
		return result;
	}

	// Given an indexed access on a mapped type of the form { [P in K]: E }[X], return an instantiation of E where P is
	// replaced with X. Since this simplification doesn't account for mapped type modifiers, add 'undefined' to the
	// resulting type if the mapped type includes a '?' modifier or if the modifiers type indicates that some properties
	// are optional. If the modifiers type is generic, conservatively estimate optionality by recursively looking for
	// mapped types that include '?' modifiers.
	static function substituteIndexedMappedType(c:Checker, objectType:Type, index:Type):Type {
		final mapper = Checker.newSimpleTypeMapper(c.getTypeParameterFromMappedType(objectType), index);
		final templateMapper = c.combineTypeMappers(objectType.AsMappedType().mapper, mapper);
		final instantiatedTemplateType = c.instantiateType(c.getTemplateTypeFromMappedType(Core.OrElse(objectType.AsMappedType().target, objectType)), templateMapper);
		var isOptional = Checker.getMappedTypeOptionality(objectType) > 0;
		if (!isOptional) {
			if (c.isGenericType(objectType)) {
				isOptional = c.getCombinedMappedTypeOptionality(c.getModifiersTypeFromMappedType(objectType)) > 0;
			} else {
				isOptional = c.couldAccessOptionalProperty(objectType, index);
			}
		}
		return c.addOptionalityEx(instantiatedTemplateType, true /*isProperty*/, isOptional);
	}

	// Return true if an indexed access with the given object and index types could access an optional property.
	static function couldAccessOptionalProperty(c:Checker, objectType:Type, indexType:Type):Bool {
		final indexConstraint = c.getBaseConstraintOfType(indexType);
		return indexConstraint != null && Core.Some(c.getPropertiesOfType(objectType), p -> {
			return (p.Flags & SymbolFlagsOptional) != 0
				&& c.isTypeAssignableTo(c.getLiteralTypeFromProperty(p, TypeFlagsStringOrNumberLiteralOrUnique, false), indexConstraint);
		});
	}

	static function getTypeOfPropertyOrIndexSignatureOfType(c:Checker, t:Type, name:std.String):Type {
		final propType = c.getTypeOfPropertyOfType(t, name);
		if (propType != null) {
			return propType;
		}
		final indexInfo = c.getApplicableIndexInfoForName(t, name);
		if (indexInfo != null) {
			return c.addOptionalityEx(indexInfo.valueType, true /*isProperty*/, true /*isOptional*/);
		}
		return null;
	}

	/**
	 * Whoa! Do you really want to use this function?
	 *
	 * Unless you're trying to get the *non-apparent* type for a
	 * value-literal type or you're authoring relevant portions of this algorithm,
	 * you probably meant to use 'getApparentTypeOfContextualType'.
	 * Otherwise this may not be very useful.
	 *
	 * In cases where you *are* working on this function, you should understand
	 * when it is appropriate to use 'getContextualType' and 'getApparentTypeOfContextualType'.
	 *
	 *   - Use 'getContextualType' when you are simply going to propagate the result to the expression.
	 *   - Use 'getApparentTypeOfContextualType' when you're going to need the members of the type.
	 *
	 * @param node the expression whose contextual type will be returned.
	 * @returns the contextual type of an expression.
	 */
	static function getContextualType(c:Checker, node:Node, contextFlags:ContextFlags):Type {
		if ((node.Flags & NodeFlagsInWithStatement) != 0) {
			// We cannot answer semantic questions within a with block, do not proceed any further
			return null;
		}
		// Cached contextual types are obtained with no ContextFlags, so we can only consult them for
		// requests with no ContextFlags.
		final index = c.findContextualNode(node, contextFlags == ContextFlagsNone /*includeCaches*/);
		if (index >= 0) {
			return c.contextualInfos[index].t;
		}
		final parent = node.Parent;
		switch (parent.Kind) {
			case KindVariableDeclaration | KindParameter | KindPropertyDeclaration | KindPropertySignature | KindBindingElement:
				return c.getContextualTypeForInitializerExpression(node, contextFlags);
			case KindArrowFunction | KindReturnStatement:
				return c.getContextualTypeForReturnExpression(node, contextFlags);
			case KindYieldExpression:
				return c.getContextualTypeForYieldOperand(parent, contextFlags);
			case KindAwaitExpression:
				return c.getContextualTypeForAwaitOperand(parent, contextFlags);
			case KindCallExpression | KindNewExpression:
				return c.getContextualTypeForArgument(parent, node);
			case KindDecorator:
				return c.getContextualTypeForDecorator(parent);
			case KindTypeAssertionExpression | KindAsExpression:
				if (Ast.IsConstAssertion(parent)) {
					return c.getContextualType(parent, contextFlags);
				}
				return c.getTypeFromTypeNode(parent.Type());
			case KindBinaryExpression:
				return c.getContextualTypeForBinaryOperand(node, contextFlags);
			case KindPropertyAssignment | KindShorthandPropertyAssignment:
				return c.getContextualTypeForObjectLiteralElement(parent, contextFlags);
			case KindSpreadAssignment:
				return c.getContextualType(parent.Parent, contextFlags);
			case KindArrayLiteralExpression:
				final t = c.getApparentTypeOfContextualType(parent, contextFlags);
				final elementIndex = Ast.IndexOfNode(parent.Elements(), node);
				if (elementIndex < 0) {
					return null;
				}
				final spread = c.getSpreadIndices(parent);
				final firstSpreadIndex = spread.a;
				final lastSpreadIndex = spread.b;
				return c.getContextualTypeForElementExpression(t, elementIndex, Core.len(parent.Elements()), firstSpreadIndex, lastSpreadIndex);
			case KindConditionalExpression:
				return c.getContextualTypeForConditionalOperand(node, contextFlags);
			case KindTemplateSpan:
				return c.getContextualTypeForSubstitutionExpression(parent.Parent, node);
			case KindParenthesizedExpression:
				return c.getContextualType(parent, contextFlags);
			case KindNonNullExpression:
				return c.getContextualType(parent, contextFlags);
			case KindSatisfiesExpression:
				return c.getTypeFromTypeNode(parent.Type());
			case KindExportAssignment:
				return c.tryGetTypeFromTypeNode(parent);
			case KindJsxExpression:
				return c.getContextualTypeForJsxExpression(parent, contextFlags);
			case KindJsxAttribute | KindJsxSpreadAttribute:
				return c.getContextualTypeForJsxAttribute(parent, contextFlags);
			case KindJsxOpeningElement | KindJsxSelfClosingElement:
				return c.getContextualJsxElementAttributesType(parent, contextFlags);
			case KindImportAttribute:
				return c.getContextualImportAttributeType(parent);
			default:
		}
		return null;
	}

	// In a variable, parameter or property declaration with a type annotation,
	// the contextual type of an initializer expression is the type of the variable, parameter or property.
	//
	// Otherwise, in a parameter declaration of a contextually typed function expression,
	// the contextual type of an initializer expression is the contextual type of the parameter.
	//
	// Otherwise, in a variable or parameter declaration with a binding pattern name,
	// the contextual type of an initializer expression is the type implied by the binding pattern.
	//
	// Otherwise, in a binding pattern inside a variable or parameter declaration,
	// the contextual type of an initializer expression is the type annotation of the containing declaration, if present.
	static function getContextualTypeForInitializerExpression(c:Checker, node:Node, contextFlags:ContextFlags):Type {
		final declaration = node.Parent;
		final initializer = declaration.Initializer();
		if (node == initializer) {
			final result = c.getContextualTypeForVariableLikeDeclaration(declaration, contextFlags);
			if (result != null) {
				return result;
			}
			if ((contextFlags & ContextFlagsSkipBindingPatterns) == 0 && Ast.IsBindingPattern(declaration.Name()) && Core.len(declaration.Name().Elements()) > 0) {
				return c.getTypeFromBindingPattern(declaration.Name(), true /*includePatternInType*/, false /*reportErrors*/);
			}
		}
		return null;
	}

	static function getContextualTypeForVariableLikeDeclaration(c:Checker, declaration:Node, contextFlags:ContextFlags):Type {
		final typeNode = declaration.Type();
		if (typeNode != null) {
			return c.getTypeFromTypeNode(typeNode);
		}
		switch (declaration.Kind) {
			case KindParameter:
				return c.getContextuallyTypedParameterType(declaration);
			case KindBindingElement:
				return c.getContextualTypeForBindingElement(declaration, contextFlags);
			case KindPropertyDeclaration:
				if (Ast.IsStatic(declaration)) {
					return c.getContextualTypeForStaticPropertyDeclaration(declaration, contextFlags);
				}
			default:
		}
		// By default, do nothing and return nil - only the above cases have context implied by a parent
		return null;
	}

	// Return contextual type of parameter or undefined if no contextual type is available
	static function getContextuallyTypedParameterType(c:Checker, parameter:Node):Type {
		final fn = parameter.Parent;
		if (!c.isContextSensitiveFunctionOrObjectLiteralMethod(fn)) {
			return null;
		}
		final iife = Ast.GetImmediatelyInvokedFunctionExpression(fn);
		if (iife != null) {
			final args = c.getEffectiveCallArguments(iife);
			final indexOfParameter = Slices.Index(fn.Parameters(), parameter);
			if (Checker.hasDotDotDotToken(parameter)) {
				return c.getSpreadArgumentType(args, indexOfParameter, Core.len(args), c.anyType, null /*context*/, CheckModeNormal);
			}
			final links = c.signatureLinks.Get(iife);
			final cached = links.resolvedSignature;
			links.resolvedSignature = c.anySignature;
			var t:Type;
			if (indexOfParameter < Core.len(args)) {
				t = c.getWidenedLiteralType(c.checkExpression(args[indexOfParameter]));
			} else if (parameter.Initializer() != null) {
				t = null;
			} else {
				t = c.undefinedWideningType;
			}
			links.resolvedSignature = cached;
			return t;
		}
		final contextualSignature = c.getContextualSignature(fn);
		if (contextualSignature != null) {
			final index = Slices.Index(fn.Parameters(), parameter) - Core.IfElse(Ast.GetThisParameter(fn) != null, 1, 0);
			if (Checker.hasDotDotDotToken(parameter) && Core.LastOrNil(fn.Parameters()) == parameter) {
				return c.getRestTypeAtPosition(contextualSignature, index, false);
			}
			return c.tryGetTypeAtPosition(contextualSignature, index);
		}
		return null;
	}

	static function isContextSensitiveFunctionOrObjectLiteralMethod(c:Checker, fn:Node):Bool {
		return (Ast.IsFunctionExpressionOrArrowFunction(fn) || Ast.IsObjectLiteralMethod(fn)) && c.isContextSensitiveFunctionLikeDeclaration(fn);
	}

	static function getSpreadArgumentType(c:Checker, args:Array<Node>, index:Int, argCount:Int, restType:Type, context:InferenceContext, checkMode:CheckMode):Type {
		final inConstContext = c.isConstTypeVariable(restType, 0);
		if (argCount > 0 && index >= argCount - 1) {
			var arg = args[argCount - 1];
			if (Checker.isSpreadArgument(arg)) {
				// We are inferring from a spread expression in the last argument position, i.e. both the parameter
				// and the argument are ...x forms.
				var spreadType:Type;
				if (Ast.IsSyntheticExpression(arg)) {
					spreadType = (arg.AsSyntheticExpression().Type : Type);
				} else {
					spreadType = c.checkExpressionWithContextualType(arg.Expression(), restType, context, checkMode);
				}
				if (c.isArrayLikeType(spreadType)) {
					return c.getMutableArrayOrTupleType(spreadType);
				}
				if (Ast.IsSpreadElement(arg)) {
					arg = arg.Expression();
				}
				return c.createArrayTypeEx(c.checkIteratedTypeOrElementType(IterationUseSpread, spreadType, c.undefinedType, arg), inConstContext);
			}
		}
		var types:Array<Type> = null;
		var infos:Array<TupleElementInfo> = null;
		for (i in index...argCount) {
			final arg = args[i];
			var t:Type = null;
			final info = new TupleElementInfo();
			if (Checker.isSpreadArgument(arg)) {
				var spreadType:Type;
				if (Ast.IsSyntheticExpression(arg)) {
					spreadType = (arg.AsSyntheticExpression().Type : Type);
				} else {
					spreadType = c.checkExpression(arg.Expression());
				}
				if (c.isArrayLikeType(spreadType)) {
					t = spreadType;
					info.flags = ElementFlagsVariadic;
				} else {
					if (Ast.IsSpreadElement(arg)) {
						t = c.checkIteratedTypeOrElementType(IterationUseSpread, spreadType, c.undefinedType, arg.Expression());
					} else {
						t = c.checkIteratedTypeOrElementType(IterationUseSpread, spreadType, c.undefinedType, arg);
					}
					info.flags = ElementFlagsRest;
				}
			} else {
				var contextualType:Type;
				if (Checker.isTupleType(restType)) {
					contextualType = Core.OrElse(c.getContextualTypeForElementExpression(restType, i - index, argCount - index, -1, -1), c.unknownType);
				} else {
					contextualType = c.getIndexedAccessTypeEx(restType, c.getNumberLiteralType(((i - index) : Number)), AccessFlagsContextual, null, null);
				}
				final argType = c.checkExpressionWithContextualType(arg, contextualType, context, checkMode);
				final hasPrimitiveContextualType = inConstContext
					|| c.maybeTypeOfKind(contextualType, TypeFlagsPrimitive | TypeFlagsIndex | TypeFlagsTemplateLiteral | TypeFlagsStringMapping);
				if (hasPrimitiveContextualType) {
					t = c.getRegularTypeOfLiteralType(argType);
				} else {
					t = c.getWidenedLiteralType(argType);
				}
				info.flags = ElementFlagsRequired;
			}
			if (Ast.IsSyntheticExpression(arg) && arg.AsSyntheticExpression().TupleNameSource != null) {
				info.labeledDeclaration = arg.AsSyntheticExpression().TupleNameSource;
			}
			if (types == null) {
				types = [];
				infos = [];
			}
			types.push(t);
			infos.push(info);
		}
		return c.createTupleTypeEx(types, infos, inConstContext && !Checker.someType(restType, t -> c.isMutableArrayLikeType(t)));
	}

	static function getMutableArrayOrTupleType(c:Checker, t:Type):Type {
		if ((t.flags & TypeFlagsUnion) != 0) {
			return c.mapType(t, t -> c.getMutableArrayOrTupleType(t));
		} else if ((t.flags & TypeFlagsAny) != 0 || c.isMutableArrayOrTuple(c.getBaseConstraintOrType(t))) {
			return t;
		} else if (Checker.isTupleType(t)) {
			return c.createTupleTypeEx(c.getElementTypes(t), t.TargetTupleType().elementInfos, false /*readonly*/);
		}
		final info = new TupleElementInfo();
		info.flags = ElementFlagsVariadic;
		return c.createTupleTypeEx([t], [info], false);
	}

	static function getContextualTypeForBindingElement(c:Checker, declaration:Node, contextFlags:ContextFlags):Type {
		final name = declaration.PropertyNameOrName();
		if (Ast.IsBindingPattern(name) || Ast.IsComputedNonLiteralName(name)) {
			return null;
		}
		final parent = declaration.Parent.Parent;
		var parentType = c.getContextualTypeForVariableLikeDeclaration(parent, contextFlags);
		if (parentType == null) {
			if (!Ast.IsBindingElement(parent) && parent.Initializer() != null) {
				parentType = c.checkDeclarationInitializer(parent, Core.IfElse(Checker.hasDotDotDotToken(declaration), CheckModeRestBindingElement, CheckModeNormal), null);
			}
		}
		if (parentType == null) {
			return null;
		}
		if (Ast.IsArrayBindingPattern(parent.Name())) {
			final index = Slices.Index(declaration.Parent.Elements(), declaration);
			if (index < 0) {
				return null;
			}
			return c.getContextualTypeForElementExpression(parentType, index, -1, -1, -1);
		}
		final nameType = c.getLiteralTypeFromPropertyName(name);
		if (Checker.isTypeUsableAsPropertyName(nameType)) {
			return c.getTypeOfPropertyOfType(parentType, Checker.getPropertyNameFromType(nameType));
		}
		return null;
	}

	static function getContextualTypeForStaticPropertyDeclaration(c:Checker, declaration:Node, contextFlags:ContextFlags):Type {
		if (Ast.IsExpression(declaration.Parent)) {
			final parentType = c.getContextualType(declaration.Parent, contextFlags);
			if (parentType != null) {
				return c.getTypeOfPropertyOfContextualType(parentType, c.getSymbolOfDeclaration(declaration).Name);
			}
		}
		return null;
	}

	static function getContextualTypeForReturnExpression(c:Checker, node:Node, contextFlags:ContextFlags):Type {
		final fn = Ast.GetContainingFunction(node);
		if (fn != null) {
			var contextualReturnType = c.getContextualReturnType(fn, contextFlags);
			if (contextualReturnType != null) {
				final functionFlags = Ast.GetFunctionFlags(fn);
				if ((functionFlags & FunctionFlagsGenerator) != 0) {
					final isAsyncGenerator = (functionFlags & FunctionFlagsAsync) != 0;
					if ((contextualReturnType.flags & TypeFlagsUnion) != 0) {
						contextualReturnType = c.filterType(contextualReturnType, function(t:Type):Bool {
							return c.getIterationTypeOfGeneratorFunctionReturnType(IterationTypeKindReturn, t, isAsyncGenerator) != null;
						});
					}
					final iterationReturnType = c.getIterationTypeOfGeneratorFunctionReturnType(IterationTypeKindReturn, contextualReturnType, (functionFlags & FunctionFlagsAsync) != 0);
					if (iterationReturnType == null) {
						return null;
					}
					contextualReturnType = iterationReturnType;
					// falls through to unwrap Promise for AsyncGenerators
				}
				if ((functionFlags & FunctionFlagsAsync) != 0) {
					// Get the awaited type without the `Awaited<T>` alias
					final contextualAwaitedType = c.mapType(contextualReturnType, t -> c.getAwaitedTypeNoAlias(t));
					if (contextualAwaitedType == null) {
						return null;
					}
					return c.getUnionType([contextualAwaitedType, c.createPromiseLikeType(contextualAwaitedType)]);
				}
				// Regular function or Generator function
				return contextualReturnType;
			}
		}
		return null;
	}

	static function getContextualIterationType(c:Checker, kind:IterationTypeKind, functionDecl:Node):Type {
		final isAsync = (Ast.GetFunctionFlags(functionDecl) & FunctionFlagsAsync) != 0;
		final contextualReturnType = c.getContextualReturnType(functionDecl, ContextFlagsNone);
		if (contextualReturnType != null) {
			return c.getIterationTypeOfGeneratorFunctionReturnType(kind, contextualReturnType, isAsync);
		}
		return null;
	}

	static function getContextualReturnType(c:Checker, functionDecl:Node, contextFlags:ContextFlags):Type {
		// If the containing function has a return type annotation, is a constructor, or is a get accessor whose
		// corresponding set accessor has a type annotation, return statements in the function are contextually typed
		final returnType = c.getReturnTypeFromAnnotation(functionDecl);
		if (returnType != null) {
			return returnType;
		}
		// Otherwise, if the containing function is contextually typed by a function type with exactly one call signature
		// and that call signature is non-generic, return statements are contextually typed by the return type of the signature
		final signature = c.getContextualSignatureForFunctionLikeDeclaration(functionDecl);
		if (signature != null && !c.isResolvingReturnTypeOfSignature(signature)) {
			final returnType = c.getReturnTypeOfSignature(signature);
			final functionFlags = Ast.GetFunctionFlags(functionDecl);
			if ((functionFlags & FunctionFlagsGenerator) != 0) {
				return c.filterType(returnType, function(t:Type):Bool {
					return (t.flags & (TypeFlagsAnyOrUnknown | TypeFlagsVoid | TypeFlagsInstantiableNonPrimitive)) != 0
						|| c.checkGeneratorInstantiationAssignabilityToReturnType(t, functionFlags, null /*errorNode*/);
				});
			}
			if ((functionFlags & FunctionFlagsAsync) != 0) {
				return c.filterType(returnType, function(t:Type):Bool {
					return (t.flags & (TypeFlagsAnyOrUnknown | TypeFlagsVoid | TypeFlagsInstantiableNonPrimitive)) != 0 || c.getAwaitedTypeOfPromise(t) != null;
				});
			}
			return returnType;
		}
		final iife = Ast.GetImmediatelyInvokedFunctionExpression(functionDecl);
		if (iife != null) {
			return c.getContextualType(iife, contextFlags);
		}
		return null;
	}

	static function checkGeneratorInstantiationAssignabilityToReturnType(c:Checker, returnType:Type, functionFlags:FunctionFlags, errorNode:Node):Bool {
		// Naively, one could check that Generator<any, any, any> is assignable to the return type annotation.
		// However, that would not catch the error in the following case.
		//
		//    interface BadGenerator extends Iterable<number>, Iterator<string> { }
		//    function* g(): BadGenerator { } // Iterable and Iterator have different types!
		//
		final generatorYieldType = Core.OrElse(c.getIterationTypeOfGeneratorFunctionReturnType(IterationTypeKindYield, returnType, (functionFlags & FunctionFlagsAsync) != 0), c.anyType);
		final generatorReturnType = Core.OrElse(c.getIterationTypeOfGeneratorFunctionReturnType(IterationTypeKindReturn, returnType, (functionFlags & FunctionFlagsAsync) != 0), generatorYieldType);
		final generatorNextType = Core.OrElse(c.getIterationTypeOfGeneratorFunctionReturnType(IterationTypeKindNext, returnType, (functionFlags & FunctionFlagsAsync) != 0), c.unknownType);
		final generatorInstantiation = c.createGeneratorType(generatorYieldType, generatorReturnType, generatorNextType, (functionFlags & FunctionFlagsAsync) != 0);
		return c.checkTypeAssignableTo(generatorInstantiation, returnType, errorNode, null);
	}

	static function getContextualSignatureForFunctionLikeDeclaration(c:Checker, node:Node):Signature {
		// Only function expressions, arrow functions, and object literal methods are contextually typed.
		if (Ast.IsFunctionExpressionOrArrowFunction(node) || Ast.IsObjectLiteralMethod(node)) {
			return c.getContextualSignature(node);
		}
		return null;
	}

	static function getContextualTypeForYieldOperand(c:Checker, node:Node, contextFlags:ContextFlags):Type {
		final fn = Ast.GetContainingFunction(node);
		if (fn != null) {
			final functionFlags = Ast.GetFunctionFlags(fn);
			var contextualReturnType = c.getContextualReturnType(fn, contextFlags);
			if (contextualReturnType != null) {
				final isAsyncGenerator = (functionFlags & FunctionFlagsAsync) != 0;
				final isYieldStar = node.AsYieldExpression().AsteriskToken != null;
				if (!isYieldStar && (contextualReturnType.flags & TypeFlagsUnion) != 0) {
					contextualReturnType = c.filterType(contextualReturnType, function(t:Type):Bool {
						return c.getIterationTypeOfGeneratorFunctionReturnType(IterationTypeKindReturn, t, isAsyncGenerator) != null;
					});
				}
				if (isYieldStar) {
					final iterationTypes = c.getIterationTypesOfGeneratorFunctionReturnType(contextualReturnType, isAsyncGenerator);
					final yieldType = Core.OrElse(iterationTypes.yieldType, c.silentNeverType);
					final returnType = Core.OrElse(c.getContextualType(node, contextFlags), c.silentNeverType);
					final nextType = Core.OrElse(iterationTypes.nextType, c.unknownType);
					final generatorType = c.createGeneratorType(yieldType, returnType, nextType, false /*isAsyncGenerator*/);
					if (isAsyncGenerator) {
						final asyncGeneratorType = c.createGeneratorType(yieldType, returnType, nextType, true /*isAsyncGenerator*/);
						return c.getUnionType([generatorType, asyncGeneratorType]);
					}
					return generatorType;
				}
				return c.getIterationTypeOfGeneratorFunctionReturnType(IterationTypeKindYield, contextualReturnType, isAsyncGenerator);
			}
		}
		return null;
	}

	static function getContextualTypeForAwaitOperand(c:Checker, node:Node, contextFlags:ContextFlags):Type {
		final contextualType = c.getContextualType(node, contextFlags);
		if (contextualType != null) {
			final contextualAwaitedType = c.getAwaitedTypeNoAlias(contextualType);
			if (contextualAwaitedType != null) {
				return c.getUnionType([contextualAwaitedType, c.createPromiseLikeType(contextualAwaitedType)]);
			}
		}
		return null;
	}

	// In a typed function call, an argument or substitution expression is contextually typed by the type of the corresponding parameter.
	static function getContextualTypeForArgument(c:Checker, callTarget:Node, arg:Node):Type {
		final args = c.getEffectiveCallArguments(callTarget);
		final argIndex = Slices.Index(args, arg);
		// -1 for e.g. the expression of a CallExpression, or the tag of a TaggedTemplateExpression
		if (argIndex == -1) {
			return null;
		}
		return c.getContextualTypeForArgumentAtIndex(callTarget, argIndex);
	}

	static function getContextualTypeForArgumentAtIndex(c:Checker, callTarget:Node, argIndex:Int):Type {
		if (Ast.IsImportCall(callTarget)) {
			if (argIndex == 0) {
				return c.stringType;
			} else if (argIndex == 1) {
				return c.getGlobalImportCallOptionsType();
			} else {
				return c.anyType;
			}
		}
		// If we're already in the process of resolving the given signature, don't resolve again as
		// that could cause infinite recursion. Instead, return anySignature.
		var signature:Signature;
		if (c.signatureLinks.Get(callTarget).resolvedSignature == c.resolvingSignature) {
			signature = c.resolvingSignature;
		} else {
			signature = c.getResolvedSignature(callTarget, null, CheckModeNormal);
		}
		if (Ast.IsJsxOpeningLikeElement(callTarget) && argIndex == 0) {
			return c.getEffectiveFirstArgumentForJsxSignature(signature, callTarget);
		}
		final restIndex = Core.len(signature.parameters) - 1;
		if (Checker.signatureHasRestParameter(signature) && argIndex >= restIndex) {
			return c.getIndexedAccessTypeEx(c.getTypeOfSymbol(signature.parameters[restIndex]), c.getNumberLiteralType(((argIndex - restIndex) : Number)), AccessFlagsContextual, null, null);
		}
		return c.getTypeAtPosition(signature, argIndex);
	}

	static function getContextualTypeForDecorator(c:Checker, decorator:Node):Type {
		final signature = c.getDecoratorCallSignature(decorator);
		if (signature != null) {
			return c.getOrCreateTypeFromSignature(signature);
		}
		return null;
	}

	static function getContextualTypeForBinaryOperand(c:Checker, node:Node, contextFlags:ContextFlags):Type {
		final binary = node.Parent.AsBinaryExpression();
		final t = binary.Type;
		if (t != null) {
			return c.getTypeFromTypeNode(t);
		}
		switch (binary.OperatorToken.Kind) {
			case KindEqualsToken | KindAmpersandAmpersandEqualsToken | KindBarBarEqualsToken | KindQuestionQuestionEqualsToken:
				// In an assignment expression, the right operand is contextually typed by the type of the left operand
				// unless it's an assignment declaration.
				if (node == binary.Right) {
					final target = Ast.GetLeftmostExpression(binary.Left, false);
					if (!(Ast.IsIdentifier(target) && (c.getResolvedSymbol(target).Flags & SymbolFlagsModuleExports) != 0)) {
						return c.getContextualTypeForAssignmentExpression(binary);
					}
				}
			case KindBarBarToken | KindQuestionQuestionToken:
				// When an || expression has a contextual type, the operands are contextually typed by that type, except
				// when that type originates in a binding pattern, the right operand is contextually typed by the type of
				// the left operand. When an || expression has no contextual type, the right operand is contextually typed
				// by the type of the left operand, except for the special case of Javascript declarations of the form
				// `namespace.prop = namespace.prop || {}`.
				final t = c.getContextualType(binary.AsNode(), contextFlags);
				if (node == binary.Right && (t == null || c.patternForType.get(t) != null)) {
					return c.getTypeOfExpression(binary.Left);
				}
				return t;
			case KindAmpersandAmpersandToken | KindCommaToken:
				if (node == binary.Right) {
					return c.getContextualType(binary.AsNode(), contextFlags);
				}
			default:
		}
		return null;
	}

	static function getContextualTypeForAssignmentExpression(c:Checker, binary:BinaryExpression):Type {
		final left = binary.Left;
		if (Ast.IsAccessExpression(left)) {
			final expr = left.Expression();
			switch (expr.Kind) {
				case KindIdentifier:
					final symbol = c.getExportSymbolOfValueSymbolIfExported(c.getResolvedSymbol(expr));
					if ((symbol.Flags & SymbolFlagsModuleExports) != 0) {
						// No contextual type for an expression of the form 'module.exports = expr'.
						return null;
					}
					if (binary.Symbol != null) {
						// We have an assignment declaration (a binary expression with a symbol assigned by the binder) of the form
						// 'F.id = expr' or 'F[xxx] = expr'. If 'F' is declared as a variable with a type annotation, we can obtain a
						// contextual type from the annotated type without triggering a circularity. Otherwise, the assignment
						// declaration has no contextual type.
						if (symbol.ValueDeclaration != null && Ast.IsVariableDeclaration(symbol.ValueDeclaration)) {
							final typeNode = symbol.ValueDeclaration.Type();
							if (typeNode != null) {
								if (Ast.IsPropertyAccessExpression(left)) {
									return c.getTypeOfPropertyOfContextualType(c.getTypeFromTypeNode(typeNode), left.Name().Text());
								}
								final nameType = c.checkExpressionCached(left.AsElementAccessExpression().ArgumentExpression);
								if (Checker.isTypeUsableAsPropertyName(nameType)) {
									return c.getTypeOfPropertyOfContextualTypeEx(c.getTypeFromTypeNode(typeNode), Checker.getPropertyNameFromType(nameType), nameType);
								}
								return c.getTypeOfExpression(left);
							}
						}
						return null;
					}
				case KindPropertyAccessExpression | KindElementAccessExpression:
					if (binary.Symbol != null) {
						return null;
					}
				case KindThisKeyword:
					var symbol:Symbol = null;
					final thisType = c.getTypeOfExpression(expr);
					if (Ast.IsPropertyAccessExpression(left)) {
						final name = left.Name();
						if (Ast.IsPrivateIdentifier(name)) {
							if (thisType.symbol != null) {
								symbol = c.getPropertyOfType(thisType, Binder.GetSymbolNameForPrivateIdentifier(thisType.symbol, name.Text()));
							}
						} else {
							symbol = c.getPropertyOfType(thisType, name.Text());
						}
					} else {
						final propType = c.checkExpressionCached(left.AsElementAccessExpression().ArgumentExpression);
						if (Checker.isTypeUsableAsPropertyName(propType)) {
							symbol = c.getPropertyOfType(thisType, Checker.getPropertyNameFromType(propType));
						}
					}
					if (symbol != null) {
						final d = symbol.ValueDeclaration;
						if (d != null && (Ast.IsPropertyDeclaration(d) || Ast.IsPropertySignatureDeclaration(d)) && d.Type() == null && d.Initializer() == null) {
							// No contextual type for 'this.xxx = expr', where xxx is declared as a property with no type annotation or initializer.
							return null;
						}
					}
					if (binary.Symbol != null && binary.Symbol.ValueDeclaration != null && binary.Symbol.ValueDeclaration.Type() == null) {
						// We have an assignment declaration 'this.xxx = expr' with no (synthetic) type annotation
						if (!Ast.IsObjectLiteralMethod(c.getThisContainer(expr, false, false))) {
							return null;
						}
						// and now for one single case of object literal methods
						final name = Ast.GetElementOrPropertyAccessName(left);
						if (name == null) {
							return null;
						} else {
							// !!! contextual typing for `this` in object literals
							return null;
						}
					}
				default:
			}
		}
		return c.getTypeOfExpression(left);
	}

	static function getContextualTypeForObjectLiteralElement(c:Checker, element:Node, contextFlags:ContextFlags):Type {
		final t = element.Type();
		if (t != null && !Ast.IsObjectLiteralMethod(element)) {
			return c.getTypeFromTypeNode(t);
		}
		final objectLiteral = element.Parent;
		final t = c.getApparentTypeOfContextualType(objectLiteral, contextFlags);
		if (t != null) {
			if (c.hasBindableName(element)) {
				// For a (non-symbol) computed property, there is no reason to look up the name
				// in the type. It will just be "__computed", which does not appear in any
				// SymbolTable.
				final symbol = c.getSymbolOfDeclaration(element);
				return c.getTypeOfPropertyOfContextualTypeEx(t, symbol.Name, c.valueSymbolLinks.Get(symbol).nameType);
			}
			if (Ast.HasDynamicName(element)) {
				final name = Ast.GetNameOfDeclaration(element);
				if (name != null && Ast.IsComputedPropertyName(name)) {
					final exprType = c.checkExpression(name.Expression());
					if (Checker.isTypeUsableAsPropertyName(exprType)) {
						final propType = c.getTypeOfPropertyOfContextualType(t, Checker.getPropertyNameFromType(exprType));
						if (propType != null) {
							return propType;
						}
					}
				}
			}
			if (element.Name() != null) {
				final nameType = c.getLiteralTypeFromPropertyName(element.Name());
				// We avoid calling getApplicableIndexInfo here because it performs potentially expensive intersection reduction.
				return c.mapTypeEx(t, function(t:Type):Type {
					final indexInfo = c.findApplicableIndexInfo(c.getIndexInfosOfStructuredType(t), nameType);
					if (indexInfo == null) {
						return null;
					}
					return indexInfo.valueType;
				}, true /*noReductions*/);
			}
		}
		return null;
	}

	// In an object literal contextually typed by a type T, the contextual type of a property assignment is the type of
	// the matching property in T, if one exists. Otherwise, it is the type of the numeric index signature in T, if one
	// exists. Otherwise, it is the type of the string index signature in T, if one exists.
	static function getContextualTypeForObjectLiteralMethod(c:Checker, node:Node, contextFlags:ContextFlags):Type {
		if ((node.Flags & NodeFlagsInWithStatement) != 0) {
			// We cannot answer semantic questions within a with block, do not proceed any further
			return null;
		}
		return c.getContextualTypeForObjectLiteralElement(node, contextFlags);
	}

	static function getContextualTypeForElementExpression(c:Checker, t:Type, index:Int, length:Int, firstSpreadIndex:Int, lastSpreadIndex:Int):Type {
		if (t == null) {
			return null;
		}
		return c.mapTypeEx(t, function(t:Type):Type {
			if (Checker.isTupleType(t)) {
				// If index is before any spread element and within the fixed part of the contextual tuple type, return
				// the type of the contextual tuple element.
				if ((firstSpreadIndex < 0 || index < firstSpreadIndex) && index < t.TargetTupleType().fixedLength) {
					return c.removeMissingType(c.getTypeArguments(t)[index], (t.TargetTupleType().elementInfos[index].flags & ElementFlagsOptional) != 0);
				}
				// When the length is known and the index is after all spread elements we compute the offset from the element
				// to the end and the number of ending fixed elements in the contextual tuple type.
				var offset = 0;
				if (length >= 0 && (lastSpreadIndex < 0 || index > lastSpreadIndex)) {
					offset = length - index;
				}
				var fixedEndLength = 0;
				if (offset > 0 && (t.TargetTupleType().combinedFlags & ElementFlagsVariable) != 0) {
					fixedEndLength = Checker.getEndElementCount(t.TargetTupleType(), ElementFlagsFixed);
				}
				// If the offset is within the ending fixed part of the contextual tuple type, return the type of the contextual
				// tuple element.
				if (offset > 0 && offset <= fixedEndLength) {
					return c.getTypeArguments(t)[c.getTypeReferenceArity(t) - offset];
				}
				// Return a union of the possible contextual element types with no subtype reduction.
				var tupleIndex = t.TargetTupleType().fixedLength;
				if (firstSpreadIndex >= 0) {
					tupleIndex = imin(tupleIndex, firstSpreadIndex);
				}
				var endSkipCount = fixedEndLength;
				if (length >= 0 && lastSpreadIndex >= 0) {
					endSkipCount = imin(fixedEndLength, length - lastSpreadIndex);
				}
				return c.getElementTypeOfSliceOfTupleType(t, tupleIndex, endSkipCount, false /*writing*/, true /*noReductions*/);
			}
			// If element index is known and a contextual property with that name exists, return it. Otherwise return the
			// iterated or element type of the contextual type.
			if (firstSpreadIndex < 0 || index < firstSpreadIndex) {
				final propType = c.getTypeOfPropertyOfContextualType(t, Std.string(index));
				if (propType != null) {
					return propType;
				}
			}
			return c.getIteratedTypeOrElementType(IterationUseElement, t, c.undefinedType, null /*errorNode*/, false /*checkAssignability*/);
		}, true /*noReductions*/);
	}

	// In a contextually typed conditional expression, the true/false expressions are contextually typed by the same type.
	static function getContextualTypeForConditionalOperand(c:Checker, node:Node, contextFlags:ContextFlags):Type {
		final conditional = node.Parent.AsConditionalExpression();
		if (node == conditional.WhenTrue || node == conditional.WhenFalse) {
			return c.getContextualType(node.Parent, contextFlags);
		}
		return null;
	}

	static function getContextualTypeForSubstitutionExpression(c:Checker, template:Node, substitutionExpression:Node):Type {
		if (Ast.IsTaggedTemplateExpression(template.Parent)) {
			return c.getContextualTypeForArgument(template.Parent, substitutionExpression);
		}
		return null;
	}

	static function getContextualImportAttributeType(c:Checker, node:Node):Type {
		return c.getTypeOfPropertyOfContextualType(c.getGlobalImportAttributesType(), node.Name().Text());
	}

	// Returns the effective arguments for an expression that works like a function invocation.
	static function getEffectiveCallArguments(c:Checker, node:Node):Array<Node> {
		if (Ast.IsJsxOpeningFragment(node)) {
			// This attributes Type does not include a children property yet, the same way a fragment created with <React.Fragment> does not at this stage
			return [c.createSyntheticExpression(node, c.emptyFreshJsxObjectType, false, null)];
		} else if (Ast.IsTaggedTemplateExpression(node)) {
			final template = node.AsTaggedTemplateExpression().Template;
			final firstArg = c.createSyntheticExpression(template, c.getGlobalTemplateStringsArrayType(), false, null);
			if (!Ast.IsTemplateExpression(template)) {
				return [firstArg];
			}
			final spans = template.AsTemplateExpression().TemplateSpans.Nodes;
			final args:Array<Node> = [for (_ in 0...(Core.len(spans) + 1)) null];
			args[0] = firstArg;
			for (i in 0...Core.len(spans)) {
				final span = spans[i];
				args[i + 1] = span.Expression();
			}
			return args;
		} else if (Ast.IsDecorator(node)) {
			return c.getEffectiveDecoratorArguments(node);
		} else if (Ast.IsBinaryExpression(node)) {
			// Handles instanceof operator
			return [node.AsBinaryExpression().Left];
		} else if (Ast.IsJsxOpeningLikeElement(node)) {
			if (Core.len(node.Attributes().Properties()) != 0 || (Ast.IsJsxOpeningElement(node) && Core.len(node.Parent.Children().Nodes) != 0)) {
				return [node.Attributes()];
			}
			return null;
		} else {
			final args = node.Arguments();
			final spreadIndex = c.getSpreadArgumentIndex(args);
			if (spreadIndex >= 0) {
				// Create synthetic arguments from spreads of tuple types.
				// PORT: Go `slices.Clip(args[:spreadIndex])` then append: a fresh array, the node's arguments stay untouched.
				final effectiveArgs = args.slice(0, spreadIndex);
				for (i in spreadIndex...args.length) {
					final arg = args[i];
					var spreadType:Type = null;
					// We can call checkExpressionCached because spread expressions never have a contextual type.
					if (Ast.IsSpreadElement(arg)) {
						if (Core.len(c.flowLoopStack) != 0) {
							spreadType = c.checkExpression(arg.Expression());
						} else {
							spreadType = c.checkExpressionCached(arg.Expression());
						}
					}
					if (spreadType != null && Checker.isTupleType(spreadType)) {
						final elementTypes = c.getElementTypes(spreadType);
						for (i in 0...Core.len(elementTypes)) {
							final t = elementTypes[i];
							final elementInfos = spreadType.TargetTupleType().elementInfos;
							final flags = elementInfos[i].flags;
							var syntheticType = t;
							if ((flags & ElementFlagsRest) != 0) {
								syntheticType = c.createArrayType(t);
							}
							final syntheticArg = c.createSyntheticExpression(arg, syntheticType, (flags & ElementFlagsVariable) != 0, elementInfos[i].labeledDeclaration);
							effectiveArgs.push(syntheticArg);
						}
					} else {
						effectiveArgs.push(arg);
					}
				}
				return effectiveArgs;
			}
			return args;
		}
	}

	static function getSpreadArgumentIndex(c:Checker, args:Array<Node>):Int {
		return Core.FindIndex(args, fn_isSpreadArgument);
	}

	static function createSyntheticExpression(c:Checker, parent:Node, t:Type, isSpread:Bool, tupleNameSource:Node):Node {
		final result = c.factory.NewSyntheticExpression(t, isSpread, tupleNameSource);
		result.Loc = parent.Loc;
		result.Parent = parent;
		return result;
	}

	static function getSpreadIndices(c:Checker, node:Node):Pair<Int, Int> {
		final links = c.arrayLiteralLinks.Get(node);
		if (!links.indicesComputed) {
			var first = -1;
			var last = -1;
			final elements = node.Elements();
			for (i in 0...Core.len(elements)) {
				final element = elements[i];
				if (Ast.IsSpreadElement(element)) {
					if (first < 0) {
						first = i;
					}
					last = i;
				}
			}
			links.firstSpreadIndex = first;
			links.lastSpreadIndex = last;
			links.indicesComputed = true;
		}
		return new Pair(links.firstSpreadIndex, links.lastSpreadIndex);
	}

	// Returns the synthetic argument list for a decorator invocation.
	static function getEffectiveDecoratorArguments(c:Checker, node:Node):Array<Node> {
		final expr = node.Expression();
		final signature = c.getDecoratorCallSignature(node);
		if (signature != null) {
			final args:Array<Node> = [for (_ in 0...Core.len(signature.parameters)) null];
			for (i in 0...Core.len(signature.parameters)) {
				final param = signature.parameters[i];
				args[i] = c.createSyntheticExpression(expr, c.getTypeOfSymbol(param), false, null);
			}
			return args;
		}
		throw "Decorator signature not found";
	}

	static function getDecoratorCallSignature(c:Checker, decorator:Node):Signature {
		if (c.legacyDecorators) {
			return c.getLegacyDecoratorCallSignature(decorator);
		}
		return c.getESDecoratorCallSignature(decorator);
	}

	static function getLegacyDecoratorCallSignature(c:Checker, decorator:Node):Signature {
		final node = decorator.Parent;
		final links = c.signatureLinks.Get(node);
		if (links.decoratorSignature == null) {
			links.decoratorSignature = c.anySignature;
			// PORT: Go `break` inside the switch cases → if/else (PORTING.md §4).
			switch (node.Kind) {
				case KindClassDeclaration | KindClassExpression:
					// For a class decorator, the `target` is the type of the class (e.g. the
					// "static" or "constructor" side of the class).
					final targetType = c.getTypeOfSymbol(c.getSymbolOfDeclaration(node));
					final targetParam = c.newParameter("target", targetType);
					links.decoratorSignature = c.newCallSignature(null, null, [targetParam], c.getUnionType([targetType, c.voidType]));
				case KindParameter:
					if (!Ast.IsConstructorDeclaration(node.Parent)
						&& !(Ast.IsMethodDeclaration(node.Parent) || (Ast.IsSetAccessorDeclaration(node.Parent) && Ast.IsClassLike(node.Parent.Parent)))) {
						// break
					} else if (Ast.GetThisParameter(node.Parent) == node) {
						// break
					} else {
						final index = Slices.Index(node.Parent.Parameters(), node) - Core.IfElse(Ast.GetThisParameter(node.Parent) != null, 1, 0);
						Debug.Assert(index >= 0);
						// A parameter declaration decorator will have three arguments (see `ParameterDecorator` in
						// core.d.ts).
						var targetType:Type;
						var keyType:Type;
						if (Ast.IsConstructorDeclaration(node.Parent)) {
							targetType = c.getTypeOfSymbol(c.getSymbolOfDeclaration(node.Parent.Parent));
							keyType = c.undefinedType;
						} else {
							targetType = c.getParentTypeOfClassElement(node.Parent);
							keyType = c.getClassElementPropertyKeyType(node.Parent);
						}
						final indexType = c.getNumberLiteralType((index : Number));
						final targetParam = c.newParameter("target", targetType);
						final keyParam = c.newParameter("propertyKey", keyType);
						final indexParam = c.newParameter("parameterIndex", indexType);
						links.decoratorSignature = c.newCallSignature(null, null, [targetParam, keyParam, indexParam], c.voidType);
					}
				case KindMethodDeclaration | KindGetAccessor | KindSetAccessor | KindPropertyDeclaration:
					if (Ast.IsClassLike(node.Parent)) {
						// A method or accessor declaration decorator will have either two or three arguments (see
						// `PropertyDecorator` and `MethodDecorator` in core.d.ts).
						final targetType = c.getParentTypeOfClassElement(node);
						final targetParam = c.newParameter("target", targetType);
						final keyType = c.getClassElementPropertyKeyType(node);
						final keyParam = c.newParameter("propertyKey", keyType);
						var returnType = c.voidType;
						if (!Ast.IsPropertyDeclaration(node)) {
							returnType = c.newTypedPropertyDescriptorType(c.getTypeOfNode(node));
						}
						final hasPropDesc = !Ast.IsPropertyDeclaration(node) || Ast.HasAccessorModifier(node);
						if (hasPropDesc) {
							final descriptorType = c.newTypedPropertyDescriptorType(c.getTypeOfNode(node));
							final descriptorParam = c.newParameter("descriptor", descriptorType);
							links.decoratorSignature = c.newCallSignature(null, null, [targetParam, keyParam, descriptorParam], c.getUnionType([returnType, c.voidType]));
						} else {
							links.decoratorSignature = c.newCallSignature(null, null, [targetParam, keyParam], c.getUnionType([returnType, c.voidType]));
						}
					}
				default:
			}
		}
		if (links.decoratorSignature == c.anySignature) {
			return null;
		}
		return links.decoratorSignature;
	}

	static function getESDecoratorCallSignature(c:Checker, decorator:Node):Signature {
		// We are considering a future change that would allow the type of a decorator to affect the type of the
		// class and its members, such as a `@Stringify` decorator changing the type of a `number` field to `string`, or
		// a `@Callable` decorator adding a call signature to a `class`. The type arguments for the various context
		// types may eventually change to reflect such mutations.
		//
		// In some cases we describe such potential mutations as coming from a "prior decorator application". It is
		// important to note that, while decorators are *evaluated* left to right, they are *applied* right to left
		// to preserve f ৹ g -> f(g(x)) application order. In these cases, a "prior" decorator usually means the
		// next decorator following this one in document order.
		//
		// The "original type" of a class or member is the type it was declared as, or the type we infer from
		// initializers, before _any_ decorators are applied.
		//
		// The type of a class or member that is a result of a prior decorator application represents the
		// "current type", i.e., the type for the declaration at the time the decorator is _applied_.
		//
		// The type of a class or member that is the result of the application of *all* relevant decorators is the
		// "final type".
		//
		// Any decorator that allows mutation or replacement will also refer to an "input type" and an
		// "output type". The "input type" corresponds to the "current type" of the declaration, while the
		// "output type" will become either the "input type/current type" for a subsequent decorator application,
		// or the "final type" for the decorated declaration.
		//
		// It is important to understand decorator application order as it relates to how the "current", "input",
		// "output", and "final" types will be determined:
		//
		//  @E2 @E1 class SomeClass {
		//      @A2 @A1 static f() {}
		//      @B2 @B1 g() {}
		//      @C2 @C1 static x;
		//      @D2 @D1 y;
		//  }
		//
		// Per [the specification][1], decorators are applied in the following order:
		//
		// 1. For each static method (incl. get/set methods and `accessor` fields), in document order:
		//    a. Apply each decorator for that method, in reverse order (`A1`, `A2`).
		// 2. For each instance method (incl. get/set methods and `accessor` fields), in document order:
		//    a. Apply each decorator for that method, in reverse order (`B1`, `B2`).
		// 3. For each static field (excl. auto-accessors), in document order:
		//    a. Apply each decorator for that field, in reverse order (`C1`, `C2`).
		// 4. For each instance field (excl. auto-accessors), in document order:
		//    a. Apply each decorator for that field, in reverse order (`D1`, `D2`).
		// 5. Apply each decorator for the class, in reverse order (`E1`, `E2`).
		//
		// As a result, "current" types at each decorator application are as follows:
		// - For `A1`, the "current" types of the class and method are their "original" types.
		// - For `A2`, the "current type" of the method is the "output type" of `A1`, and the "current type" of the
		//   class is the type of `SomeClass` where `f` is the "output type" of `A1`. This becomes the "final type"
		//   of `f`.
		// - For `B1`, the "current type" of the method is its "original type", and the "current type" of the class
		//   is the type of `SomeClass` where `f` now has its "final type".
		// - etc.
		//
		// [1]: https://arai-a.github.io/ecma262-compare/?pr=2417&id=sec-runtime-semantics-classdefinitionevaluation
		//
		// This seems complicated at first glance, but is not unlike our existing inference for functions:
		//
		//  declare function pipe<Original, A1, A2, B1, B2, C1, C2, D1, D2, E1, E2>(
		//      original: Original,
		//      a1: (input: Original, context: Context<E2>) => A1,
		//      a2: (input: A1, context: Context<E2>) => A2,
		//      b1: (input: A2, context: Context<E2>) => B1,
		//      b2: (input: B1, context: Context<E2>) => B2,
		//      c1: (input: B2, context: Context<E2>) => C1,
		//      c2: (input: C1, context: Context<E2>) => C2,
		//      d1: (input: C2, context: Context<E2>) => D1,
		//      d2: (input: D1, context: Context<E2>) => D2,
		//      e1: (input: D2, context: Context<E2>) => E1,
		//      e2: (input: E1, context: Context<E2>) => E2,
		//  ): E2;

		// When a decorator is applied, it is passed two arguments: "target", which is a value representing the
		// thing being decorated (constructors for classes, functions for methods/accessors, `undefined` for fields,
		// and a `{ get, set }` object for auto-accessors), and "context", which is an object that provides
		// reflection information about the decorated element, as well as the ability to add additional "extra"
		// initializers. In most cases, the "target" argument corresponds to the "input type" in some way, and the
		// return value similarly corresponds to the "output type" (though if the "output type" is `void` or
		// `undefined` then the "output type" is the "input type").
		final node = decorator.Parent;
		final links = c.signatureLinks.Get(node);
		if (links.decoratorSignature == null) {
			links.decoratorSignature = c.anySignature;
			// PORT: Go `break` inside the switch cases → if/else (PORTING.md §4).
			switch (node.Kind) {
				case KindClassDeclaration | KindClassExpression:
					// Class decorators have a `context` of `ClassDecoratorContext<Class>`, where the `Class` type
					// argument will be the "final type" of the class after all decorators are applied.
					final targetType = c.getTypeOfSymbol(c.getSymbolOfDeclaration(node));
					final contextType = c.newClassDecoratorContextType(targetType);
					links.decoratorSignature = c.newESDecoratorCallSignature(targetType, contextType, targetType);
				case KindMethodDeclaration | KindGetAccessor | KindSetAccessor:
					if (Ast.IsClassLike(node.Parent)) {
						// Method decorators have a `context` of `ClassMethodDecoratorContext<This, Value>`, where the
						// `Value` type argument corresponds to the "final type" of the method.
						//
						// Getter decorators have a `context` of `ClassGetterDecoratorContext<This, Value>`, where the
						// `Value` type argument corresponds to the "final type" of the value returned by the getter.
						//
						// Setter decorators have a `context` of `ClassSetterDecoratorContext<This, Value>`, where the
						// `Value` type argument corresponds to the "final type" of the parameter of the setter.
						//
						// In all three cases, the `This` type argument is the "final type" of either the class or
						// instance, depending on whether the member was `static`.
						var valueType:Type;
						if (Ast.IsMethodDeclaration(node)) {
							valueType = c.getOrCreateTypeFromSignature(c.getSignatureFromDeclaration(node));
						} else {
							valueType = c.getTypeOfNode(node);
						}
						var thisType:Type;
						if (Ast.HasStaticModifier(node)) {
							thisType = c.getTypeOfSymbol(c.getSymbolOfDeclaration(node.Parent));
						} else {
							thisType = c.getDeclaredTypeOfClassOrInterface(c.getSymbolOfDeclaration(node.Parent));
						}
						// We wrap the "input type", if necessary, to match the decoration target. For getters this is
						// something like `() => inputType`, for setters it's `(value: inputType) => void` and for
						// methods it is just the input type.
						var targetType:Type;
						if (Ast.IsGetAccessorDeclaration(node)) {
							targetType = c.newGetterFunctionType(valueType);
						} else if (Ast.IsSetAccessorDeclaration(node)) {
							targetType = c.newSetterFunctionType(valueType);
						} else {
							targetType = valueType;
						}
						final contextType = c.newClassMemberDecoratorContextTypeForNode(node, thisType, valueType);
						links.decoratorSignature = c.newESDecoratorCallSignature(targetType, contextType, targetType);
					}
				case KindPropertyDeclaration:
					if (Ast.IsClassLike(node.Parent)) {
						// Field decorators have a `context` of `ClassFieldDecoratorContext<This, Value>` and
						// auto-accessor decorators have a `context` of `ClassAccessorDecoratorContext<This, Value>. In
						// both cases, the `This` type argument is the "final type" of either the class or instance,
						// depending on whether the member was `static`, and the `Value` type argument corresponds to
						// the "final type" of the value stored in the field.
						final valueType = c.getTypeOfNode(node);
						var thisType:Type;
						if (Ast.HasStaticModifier(node)) {
							thisType = c.getTypeOfSymbol(c.getSymbolOfDeclaration(node.Parent));
						} else {
							thisType = c.getDeclaredTypeOfClassOrInterface(c.getSymbolOfDeclaration(node.Parent));
						}
						// The `target` of an auto-accessor decorator is a `{ get, set }` object, representing the
						// runtime-generated getter and setter that are added to the class/prototype. The `target` of a
						// regular field decorator is always `undefined` as it isn't installed until it is initialized.
						var targetType:Type;
						if (Ast.HasAccessorModifier(node)) {
							targetType = c.newClassAccessorDecoratorTargetType(thisType, valueType);
						} else {
							targetType = c.undefinedType;
						}
						// We wrap the "output type" depending on the declaration. For auto-accessors, we wrap the
						// "output type" in a `ClassAccessorDecoratorResult<This, In, Out>` type, which allows for
						// mutation of the runtime-generated getter and setter, as well as the injection of an
						// initializer mutator. For regular fields, we wrap the "output type" in an initializer mutator.
						var returnType:Type;
						if (Ast.HasAccessorModifier(node)) {
							returnType = c.newClassAccessorDecoratorResultType(thisType, valueType);
						} else {
							returnType = c.newClassFieldDecoratorInitializerMutatorType(thisType, valueType);
						}
						final contextType = c.newClassMemberDecoratorContextTypeForNode(node, thisType, valueType);
						links.decoratorSignature = c.newESDecoratorCallSignature(targetType, contextType, returnType);
					}
				default:
			}
		}
		if (links.decoratorSignature == c.anySignature) {
			return null;
		}
		return links.decoratorSignature;
	}

	static function newClassDecoratorContextType(c:Checker, classType:Type):Type {
		return c.tryCreateTypeReference(c.getGlobalClassDecoratorContextType(), [classType]);
	}

	static function newClassMethodDecoratorContextType(c:Checker, classType:Type, valueType:Type):Type {
		return c.tryCreateTypeReference(c.getGlobalClassMethodDecoratorContextType(), [classType, valueType]);
	}

	static function newClassGetterDecoratorContextType(c:Checker, classType:Type, valueType:Type):Type {
		return c.tryCreateTypeReference(c.getGlobalClassGetterDecoratorContextType(), [classType, valueType]);
	}

	static function newClassSetterDecoratorContextType(c:Checker, classType:Type, valueType:Type):Type {
		return c.tryCreateTypeReference(c.getGlobalClassSetterDecoratorContextType(), [classType, valueType]);
	}

	static function newClassAccessorDecoratorContextType(c:Checker, thisType:Type, valueType:Type):Type {
		return c.tryCreateTypeReference(c.getGlobalClassAccessorDecoratorContextType(), [thisType, valueType]);
	}

	static function newClassFieldDecoratorContextType(c:Checker, thisType:Type, valueType:Type):Type {
		return c.tryCreateTypeReference(c.getGlobalClassFieldDecoratorContextType(), [thisType, valueType]);
	}

	// Gets a type like `{ name: "foo", private: false, static: true }` that is used to provided member-specific
	// details that will be intersected with a decorator context type.
	static function getClassMemberDecoratorContextOverrideType(c:Checker, nameType:Type, isPrivate:Bool, isStatic:Bool):Type {
		final kind = isPrivate ? (isStatic ? CachedTypeKindDecoratorContextPrivateStatic : CachedTypeKindDecoratorContextPrivate) : (isStatic ? CachedTypeKindDecoratorContextStatic : CachedTypeKindDecoratorContext);
		final key = CachedTypeKey.keyOf(kind, nameType.id);
		final cached = c.cachedTypes.get(key);
		if (cached != null) {
			return cached;
		}
		final members = new SymbolTable();
		members.set("name", c.newProperty("name", nameType));
		members.set("private", c.newProperty("private", isPrivate ? c.trueType : c.falseType));
		members.set("static", c.newProperty("static", isStatic ? c.trueType : c.falseType));
		final overrideType = c.newAnonymousType(null, members, null, null, null);
		c.cachedTypes.set(key, overrideType);
		return overrideType;
	}

	static function newClassMemberDecoratorContextTypeForNode(c:Checker, node:Node, thisType:Type, valueType:Type):Type {
		final isStatic = Ast.HasStaticModifier(node);
		final isPrivate = Ast.IsPrivateIdentifier(node.Name());
		var nameType:Type = null;
		if (isPrivate) {
			nameType = c.getStringLiteralType(node.Name().Text());
		} else {
			nameType = c.getLiteralTypeFromPropertyName(node.Name());
		}
		var contextType:Type = null;
		if (Ast.IsMethodDeclaration(node)) {
			contextType = c.newClassMethodDecoratorContextType(thisType, valueType);
		} else if (Ast.IsGetAccessorDeclaration(node)) {
			contextType = c.newClassGetterDecoratorContextType(thisType, valueType);
		} else if (Ast.IsSetAccessorDeclaration(node)) {
			contextType = c.newClassSetterDecoratorContextType(thisType, valueType);
		} else if (Ast.IsAutoAccessorPropertyDeclaration(node)) {
			contextType = c.newClassAccessorDecoratorContextType(thisType, valueType);
		} else if (Ast.IsPropertyDeclaration(node)) {
			contextType = c.newClassFieldDecoratorContextType(thisType, valueType);
		} else {
			throw "Unhandled case in createClassMemberDecoratorContextTypeForNode";
		}
		final overrideType = c.getClassMemberDecoratorContextOverrideType(nameType, isPrivate, isStatic);
		return c.getIntersectionType([contextType, overrideType]);
	}

	static function newClassAccessorDecoratorTargetType(c:Checker, thisType:Type, valueType:Type):Type {
		return c.tryCreateTypeReference(c.getGlobalClassAccessorDecoratorTargetType(), [thisType, valueType]);
	}

	static function newClassAccessorDecoratorResultType(c:Checker, thisType:Type, valueType:Type):Type {
		return c.tryCreateTypeReference(c.getGlobalClassAccessorDecoratorResultType(), [thisType, valueType]);
	}

	static function newClassFieldDecoratorInitializerMutatorType(c:Checker, thisType:Type, valueType:Type):Type {
		final thisParam = c.newParameter("this", thisType);
		final valueParam = c.newParameter("value", valueType);
		return c.newFunctionType(null, thisParam, [valueParam], valueType);
	}

	// Creates a call signature for an ES Decorator. This method is used by the semantics of
	// `getESDecoratorCallSignature`, which you should probably be using instead.
	static function newESDecoratorCallSignature(c:Checker, targetType:Type, contextType:Type, nonOptionalReturnType:Type):Signature {
		final targetParam = c.newParameter("target", targetType);
		final contextParam = c.newParameter("context", contextType);
		final returnType = c.getUnionType([nonOptionalReturnType, c.voidType]);
		return c.newCallSignature(null, null /*thisParameter*/, [targetParam, contextParam], returnType);
	}

	// Creates a synthetic `FunctionType`
	static function newFunctionType(c:Checker, typeParameters:Array<Type>, thisParameter:Symbol, parameters:Array<Symbol>, returnType:Type):Type {
		final signature = c.newCallSignature(typeParameters, thisParameter, parameters, returnType);
		return c.getOrCreateTypeFromSignature(signature);
	}

	static function newGetterFunctionType(c:Checker, t:Type):Type {
		return c.newFunctionType(null, null /*thisParameter*/, null, t);
	}

	static function newSetterFunctionType(c:Checker, t:Type):Type {
		final valueParam = c.newParameter("value", t);
		return c.newFunctionType(null, null /*thisParameter*/, [valueParam], c.voidType);
	}

	// Creates a synthetic `Signature` corresponding to a call signature.
	static function newCallSignature(c:Checker, typeParameters:Array<Type>, thisParameter:Symbol, parameters:Array<Symbol>, returnType:Type):Signature {
		final decl = c.factory.NewFunctionTypeNode(null, null, c.factory.NewKeywordTypeNode(KindAnyKeyword));
		return c.newSignature(SignatureFlagsNone, decl, typeParameters, thisParameter, parameters, returnType, null, Core.len(parameters));
	}

	static function newTypedPropertyDescriptorType(c:Checker, propertyType:Type):Type {
		return c.createTypeFromGenericGlobalType(c.getGlobalTypedPropertyDescriptorType(), [propertyType]);
	}

	static function getParentTypeOfClassElement(c:Checker, node:Node):Type {
		final classSymbol = c.getSymbolOfNode(node.Parent);
		if (Ast.IsStatic(node)) {
			return c.getTypeOfSymbol(classSymbol);
		}
		return c.getDeclaredTypeOfSymbol(classSymbol);
	}

	static function getClassElementPropertyKeyType(c:Checker, element:Node):Type {
		final name = element.Name();
		switch (name.Kind) {
			case KindIdentifier | KindNumericLiteral | KindStringLiteral:
				return c.getStringLiteralType(name.Text());
			case KindComputedPropertyName:
				final nameType = c.checkComputedPropertyName(name);
				if (c.isTypeAssignableToKind(nameType, TypeFlagsESSymbolLike)) {
					return nameType;
				}
				return c.stringType;
			default:
		}
		return c.errorType;
	}

	static function getTypeOfPropertyOfContextualType(c:Checker, t:Type, name:std.String):Type {
		return c.getTypeOfPropertyOfContextualTypeEx(t, name, null);
	}

	static function getTypeOfPropertyOfContextualTypeEx(c:Checker, t:Type, name:std.String, nameType:Type):Type {
		return c.mapTypeEx(t, function(t:Type):Type {
			if ((t.flags & TypeFlagsIntersection) != 0) {
				var types:Array<Type> = null;
				var indexInfoCandidates:Array<Type> = null;
				var ignoreIndexInfos = false;
				for (constituentType in t.Types()) {
					if ((constituentType.flags & TypeFlagsObject) == 0) {
						continue;
					}
					if (c.isGenericMappedType(constituentType) && c.getMappedTypeNameTypeKind(constituentType) != MappedTypeNameTypeKindRemapping) {
						final substitutedType = c.getIndexedMappedTypeSubstitutedTypeOfContextualType(constituentType, name, nameType);
						types = c.appendContextualPropertyTypeConstituent(types, substitutedType);
						continue;
					}
					final propertyType = c.getTypeOfConcretePropertyOfContextualType(constituentType, name);
					if (propertyType == null) {
						if (!ignoreIndexInfos) {
							if (indexInfoCandidates == null) {
								indexInfoCandidates = [];
							}
							indexInfoCandidates.push(constituentType);
						}
						continue;
					}
					ignoreIndexInfos = true;
					indexInfoCandidates = null;
					types = c.appendContextualPropertyTypeConstituent(types, propertyType);
				}
				for (candidate in rangeOf(indexInfoCandidates)) {
					final indexInfoType = c.getTypeFromIndexInfosOfContextualType(candidate, name, nameType);
					types = c.appendContextualPropertyTypeConstituent(types, indexInfoType);
				}
				if (Core.len(types) == 0) {
					return null;
				}
				if (Core.len(types) == 1) {
					return types[0];
				}
				return c.getIntersectionType(types);
			}
			if ((t.flags & TypeFlagsObject) == 0) {
				return null;
			}
			if (c.isGenericMappedType(t) && c.getMappedTypeNameTypeKind(t) != MappedTypeNameTypeKindRemapping) {
				return c.getIndexedMappedTypeSubstitutedTypeOfContextualType(t, name, nameType);
			}
			final result = c.getTypeOfConcretePropertyOfContextualType(t, name);
			if (result != null) {
				return result;
			}
			return c.getTypeFromIndexInfosOfContextualType(t, name, nameType);
		}, true /*noReductions*/);
	}

	static function getIndexedMappedTypeSubstitutedTypeOfContextualType(c:Checker, t:Type, name:std.String, nameType:Type):Type {
		var propertyNameType = nameType;
		if (propertyNameType == null) {
			propertyNameType = c.getStringLiteralType(name);
		}
		final constraint = c.getConstraintTypeFromMappedType(t);
		// special case for conditional types pretending to be negated types
		if ((t.AsMappedType().nameType != null && c.isExcludedMappedPropertyName(t.AsMappedType().nameType, propertyNameType)) || c.isExcludedMappedPropertyName(constraint, propertyNameType)) {
			return null;
		}
		final constraintOfConstraint = c.getBaseConstraintOrType(constraint);
		if (!c.isTypeAssignableTo(propertyNameType, constraintOfConstraint)) {
			return null;
		}
		return c.substituteIndexedMappedType(t, propertyNameType);
	}

	static function isExcludedMappedPropertyName(c:Checker, t:Type, propertyNameType:Type):Bool {
		if ((t.flags & TypeFlagsConditional) != 0) {
			return (c.getReducedType(c.getTrueTypeFromConditionalType(t)).flags & TypeFlagsNever) != 0
				&& c.getActualTypeVariable(c.getFalseTypeFromConditionalType(t)) == c.getActualTypeVariable(t.AsConditionalType().checkType)
				&& c.isTypeAssignableTo(propertyNameType, t.AsConditionalType().extendsType);
		}
		if ((t.flags & TypeFlagsIntersection) != 0) {
			return Core.Some(t.Types(), function(t:Type):Bool {
				return c.isExcludedMappedPropertyName(t, propertyNameType);
			});
		}
		return false;
	}

	static function getTypeOfConcretePropertyOfContextualType(c:Checker, t:Type, name:std.String):Type {
		final prop = c.getPropertyOfType(t, name);
		if (prop == null || c.isCircularMappedProperty(prop)) {
			return null;
		}
		return c.removeMissingType(c.getTypeOfSymbol(prop), (prop.Flags & SymbolFlagsOptional) != 0);
	}

	static function getTypeFromIndexInfosOfContextualType(c:Checker, t:Type, name:std.String, nameType:Type):Type {
		if (Checker.isTupleType(t) && Checker.isNumericLiteralName(name) && (Jsnum.FromString(name) : Float) >= 0) {
			final restType = c.getElementTypeOfSliceOfTupleType(t, t.TargetTupleType().fixedLength, 0 /*endSkipCount*/, false /*writing*/, true /*noReductions*/);
			if (restType != null) {
				return restType;
			}
		}
		if (nameType == null) {
			nameType = c.getStringLiteralType(name);
		}
		final indexInfo = c.findApplicableIndexInfo(c.getIndexInfosOfStructuredType(t), nameType);
		if (indexInfo == null) {
			return null;
		}
		return indexInfo.valueType;
	}

	static function isCircularMappedProperty(c:Checker, symbol:Symbol):Bool {
		if ((symbol.CheckFlags & CheckFlagsMapped) != 0) {
			final links = c.valueSymbolLinks.Get(symbol);
			return links.resolvedType == null && c.findResolutionCycleStartIndex(entity(symbol), TypeSystemPropertyNameType) >= 0;
		}
		return false;
	}

	static function appendContextualPropertyTypeConstituent(c:Checker, types:Array<Type>, t:Type):Array<Type> {
		// any doesn't provide any contextual information but could spoil the overall result by nullifying contextual information
		// provided by other intersection constituents so it gets replaced with `unknown` as `T & unknown` is just `T` and all
		// types computed based on the contextual information provided by other constituens are still assignable to any
		if (t == null) {
			return types;
		}
		// PORT: Go `append(types, x)`; every caller owns `types` and stores the result back, so push in place.
		if (types == null) {
			types = [];
		}
		if ((t.flags & TypeFlagsAny) != 0) {
			types.push(c.unknownType);
			return types;
		}
		types.push(t);
		return types;
	}

	// Return the contextual type for a given expression node. During overload resolution, a contextual type may temporarily
	// be "pushed" onto a node using the contextualType property.
	static function getApparentTypeOfContextualType(c:Checker, node:Node, contextFlags:ContextFlags):Type {
		var contextualType:Type = null;
		if (Ast.IsObjectLiteralMethod(node)) {
			contextualType = c.getContextualTypeForObjectLiteralMethod(node, contextFlags);
		} else {
			contextualType = c.getContextualType(node, contextFlags);
		}
		final instantiatedType = c.instantiateContextualType(contextualType, node, contextFlags);
		if (instantiatedType != null && !((contextFlags & ContextFlagsNoConstraints) != 0 && (instantiatedType.flags & TypeFlagsTypeVariable) != 0)) {
			final apparentType = c.mapTypeEx(instantiatedType, function(t:Type):Type {
				if ((t.objectFlags & ObjectFlagsMapped) != 0) {
					return t;
				}
				return c.getApparentType(t);
			}, true);
			if ((apparentType.flags & TypeFlagsUnion) != 0 && Ast.IsObjectLiteralExpression(node)) {
				return c.discriminateContextualTypeByObjectMembers(node, apparentType);
			} else if ((apparentType.flags & TypeFlagsUnion) != 0 && Ast.IsJsxAttributes(node)) {
				return c.discriminateContextualTypeByJSXAttributes(node, apparentType);
			} else {
				return apparentType;
			}
		}
		return null;
	}

	static function discriminateContextualTypeByObjectMembers(c:Checker, node:Node, contextualType:Type):Type {
		final key = DiscriminatedContextualTypeKey.keyOf(Ast.GetNodeId(node), contextualType.id);
		final cached = c.discriminatedContextualTypes.get(key);
		if (cached != null) {
			return cached;
		}
		var discriminated = c.getMatchingUnionConstituentForObjectLiteral(contextualType, node);
		if (discriminated == null) {
			final discriminantProperties = Core.Filter(node.Properties(), function(p:Node):Bool {
				final symbol = p.Symbol();
				if (symbol == null) {
					return false;
				}
				if (Ast.IsPropertyAssignment(p)) {
					return c.isPossiblyDiscriminantValue(p.Initializer()) && c.isDiscriminantProperty(contextualType, symbol.Name);
				}
				if (Ast.IsShorthandPropertyAssignment(p)) {
					return c.isDiscriminantProperty(contextualType, symbol.Name);
				}
				return false;
			});
			final discriminantMembers = Core.Filter(c.getPropertiesOfType(contextualType), function(s:Symbol):Bool {
				return (s.Flags & SymbolFlagsOptional) != 0 && symbolTableGet(node.Symbol().Members, s.Name) == null && c.isDiscriminantProperty(contextualType, s.Name);
			});
			final discriminator = new ObjectLiteralDiscriminator();
			discriminator.c = c;
			discriminator.props = discriminantProperties;
			discriminator.members = discriminantMembers;
			discriminated = c.discriminateTypeByDiscriminableItems(contextualType, discriminator);
		}
		c.discriminatedContextualTypes.set(key, discriminated);
		return discriminated;
	}

	static function getMatchingUnionConstituentForObjectLiteral(c:Checker, unionType:Type, node:Node):Type {
		final keyPropertyName = c.getKeyPropertyName(unionType);
		if (keyPropertyName != "") {
			final propNode = Core.Find(node.Properties(), function(p:Node):Bool {
				return p.Symbol() != null && Ast.IsPropertyAssignment(p) && p.Symbol().Name == keyPropertyName && c.isPossiblyDiscriminantValue(p.Initializer());
			});
			if (propNode != null) {
				final propType = c.getContextFreeTypeOfExpression(propNode.Initializer());
				return c.getConstituentTypeForKeyType(unionType, propType);
			}
		}
		return null;
	}

	// Return true if the given expression is possibly a discriminant value. We limit the kinds of
	// expressions we check to those that don't depend on their contextual type in order not to cause
	// recursive (and possibly infinite) invocations of getContextualType.
	static function isPossiblyDiscriminantValue(c:Checker, node:Node):Bool {
		switch (node.Kind) {
			case KindStringLiteral | KindNumericLiteral | KindBigIntLiteral | KindNoSubstitutionTemplateLiteral | KindTemplateExpression | KindTrueKeyword | KindFalseKeyword | KindNullKeyword | KindIdentifier | KindUndefinedKeyword:
				return true;
			case KindPropertyAccessExpression | KindParenthesizedExpression:
				return c.isPossiblyDiscriminantValue(node.Expression());
			case KindJsxExpression:
				return node.Expression() == null || c.isPossiblyDiscriminantValue(node.Expression());
			default:
		}
		return false;
	}

	// If the given contextual type contains instantiable types and if a mapper representing
	// return type inferences is available, instantiate those types using that mapper.
	static function instantiateContextualType(c:Checker, contextualType:Type, node:Node, contextFlags:ContextFlags):Type {
		if (contextualType != null && c.maybeTypeOfKind(contextualType, TypeFlagsInstantiable)) {
			final inferenceContext = c.getInferenceContext(node);
			// If no inferences have been made, and none of the type parameters for which we are inferring
			// specify default types, nothing is gained from instantiating as type parameters would just be
			// replaced with their constraints similar to the apparent type.
			if (inferenceContext != null) {
				if ((contextFlags & ContextFlagsSignature) != 0 && Core.Some(inferenceContext.inferences, fn_hasInferenceCandidatesOrDefault)) {
					// For contextual signatures we incorporate all inferences made so far, e.g. from return
					// types as well as arguments to the left in a function call.
					final t = c.instantiateInstantiableTypes(contextualType, inferenceContext.nonFixingMapper);
					if ((t.flags & TypeFlagsAnyOrUnknown) == 0) {
						return t;
					}
				}
				if (inferenceContext.returnMapper != null) {
					// For other purposes (e.g. determining whether to produce literal types) we only
					// incorporate inferences made from the return type in a function call. We remove
					// the 'boolean' type from the contextual type such that contextually typed boolean
					// literals actually end up widening to 'boolean' (see #48363).
					final t = c.instantiateInstantiableTypes(contextualType, inferenceContext.returnMapper);
					if ((t.flags & TypeFlagsAnyOrUnknown) == 0) {
						if ((t.flags & TypeFlagsUnion) != 0 && Checker.containsType(t.Types(), c.regularFalseType) && Checker.containsType(t.Types(), c.regularTrueType)) {
							return c.filterType(t, function(t:Type):Bool {
								return t != c.regularFalseType && t != c.regularTrueType;
							});
						}
						return t;
					}
				}
			}
		}
		return contextualType;
	}

	// This function is similar to instantiateType, except that (a) it only instantiates types that
	// are classified as instantiable (i.e. it doesn't instantiate object types), and (b) it performs
	// no reductions on instantiated union types.
	static function instantiateInstantiableTypes(c:Checker, t:Type, mapper:TypeMapper):Type {
		if ((t.flags & TypeFlagsInstantiable) != 0) {
			return c.instantiateType(t, mapper);
		}
		if ((t.flags & TypeFlagsUnion) != 0) {
			return c.getUnionTypeEx(Core.Map(t.Types(), function(t:Type):Type {
				return c.instantiateInstantiableTypes(t, mapper);
			}), UnionReductionNone, null, null);
		}
		if ((t.flags & TypeFlagsIntersection) != 0) {
			return c.getIntersectionType(Core.Map(t.Types(), function(t:Type):Type {
				return c.instantiateInstantiableTypes(t, mapper);
			}));
		}
		return t;
	}

	static function pushCachedContextualType(c:Checker, node:Node):Void {
		c.pushContextualType(node, c.getContextualType(node, ContextFlagsNone), true /*isCache*/);
	}

	static function pushContextualType(c:Checker, node:Node, t:Type, isCache:Bool):Void {
		final info = new ContextualInfo();
		info.node = node;
		info.t = t;
		info.isCache = isCache;
		if (c.contextualInfos == null) {
			c.contextualInfos = [];
		}
		c.contextualInfos.push(info);
	}

	static function popContextualType(c:Checker):Void {
		// PORT: Go clears the last element and reslices; pop() does both.
		c.contextualInfos.pop();
	}

	static function findContextualNode(c:Checker, node:Node, includeCaches:Bool):Int {
		for (i in 0...Core.len(c.contextualInfos)) {
			final info = c.contextualInfos[i];
			if (node == info.node && (includeCaches || !info.isCache)) {
				return i;
			}
		}
		return -1;
	}

	// Returns true if the given expression contains (at any level of nesting) a function or arrow expression
	// that is subject to contextual typing.
	static function isContextSensitive(c:Checker, node:Node):Bool {
		switch (node.Kind) {
			case KindFunctionExpression | KindArrowFunction | KindMethodDeclaration | KindFunctionDeclaration:
				return c.isContextSensitiveFunctionLikeDeclaration(node);
			case KindObjectLiteralExpression:
				return Core.Some(node.Properties(), n -> c.isContextSensitive(n));
			case KindArrayLiteralExpression:
				return Core.Some(node.Elements(), n -> c.isContextSensitive(n));
			case KindConditionalExpression:
				return c.isContextSensitive(node.AsConditionalExpression().WhenTrue) || c.isContextSensitive(node.AsConditionalExpression().WhenFalse);
			case KindBinaryExpression:
				final binary = node.AsBinaryExpression();
				return Ast.NodeKindIs(binary.OperatorToken, KindBarBarToken, KindQuestionQuestionToken) && (c.isContextSensitive(binary.Left) || c.isContextSensitive(binary.Right));
			case KindPropertyAssignment:
				return c.isContextSensitive(node.Initializer());
			case KindParenthesizedExpression:
				return c.isContextSensitive(node.Expression());
			case KindJsxAttributes:
				return Core.Some(node.Properties(), n -> c.isContextSensitive(n)) || (Ast.IsJsxOpeningElement(node.Parent) && Core.Some(node.Parent.Parent.Children().Nodes, n -> c.isContextSensitive(n)));
			case KindJsxAttribute:
				// If there is no initializer, JSX attribute has a boolean value of true which is not context sensitive.
				final initializer = node.Initializer();
				return initializer != null && c.isContextSensitive(initializer);
			case KindJsxExpression:
				// It is possible to that node.expression is undefined (e.g <div x={} />)
				final expression = node.Expression();
				return expression != null && c.isContextSensitive(expression);
			case KindYieldExpression:
				final expression = node.Expression();
				return expression != null && c.isContextSensitive(expression);
			default:
		}
		return false;
	}

	static function isContextSensitiveFunctionLikeDeclaration(c:Checker, node:Node):Bool {
		return Ast.HasContextSensitiveParameters(node) || c.hasContextSensitiveReturnExpression(node) || c.hasContextSensitiveYieldExpression(node);
	}

	static function hasContextSensitiveReturnExpression(c:Checker, node:Node):Bool {
		if (node.TypeParameters() != null || node.Type() != null) {
			return false;
		}
		final body = node.Body();
		if (body == null) {
			return false;
		}
		if (!Ast.IsBlock(body)) {
			return c.isContextSensitive(body);
		}
		return Ast.ForEachReturnStatement(body, function(statement:Node):Bool {
			return statement.Expression() != null && c.isContextSensitive(statement.Expression());
		});
	}

	static function hasContextSensitiveYieldExpression(c:Checker, node:Node):Bool {
		return (Ast.GetFunctionFlags(node) & FunctionFlagsGenerator) != 0 && node.Body() != null && Checker.forEachYieldExpression(node.Body(), n -> c.isContextSensitive(n));
	}

	static function pushInferenceContext(c:Checker, node:Node, context:InferenceContext):Void {
		final info = new InferenceContextInfo();
		info.node = node;
		info.context = context;
		if (c.inferenceContextInfos == null) {
			c.inferenceContextInfos = [];
		}
		c.inferenceContextInfos.push(info);
	}

	static function popInferenceContext(c:Checker):Void {
		// PORT: Go clears the last element and reslices; pop() does both.
		c.inferenceContextInfos.pop();
	}

	static function getInferenceContext(c:Checker, node:Node):InferenceContext {
		var i = Core.len(c.inferenceContextInfos) - 1;
		while (i >= 0) {
			if (Checker.isNodeDescendantOf(node, c.inferenceContextInfos[i].node)) {
				return c.inferenceContextInfos[i].context;
			}
			i--;
		}
		return null;
	}

	static function getTypeFacts(c:Checker, t:Type, mask:TypeFacts):TypeFacts {
		return c.getTypeFactsWorker(t, mask) & mask;
	}

	static function hasTypeFacts(c:Checker, t:Type, mask:TypeFacts):Bool {
		return c.getTypeFacts(t, mask) != 0;
	}

	static function getTypeFactsWorker(c:Checker, t:Type, callerOnlyNeeds:TypeFacts):TypeFacts {
		if ((t.flags & (TypeFlagsIntersection | TypeFlagsInstantiable)) != 0) {
			t = c.getBaseConstraintOfType(t);
			if (t == null) {
				t = c.unknownType;
			}
		}
		final flags = t.flags;
		if ((flags & (TypeFlagsString | TypeFlagsStringMapping)) != 0) {
			if (c.strictNullChecks) {
				return TypeFactsStringStrictFacts;
			}
			return TypeFactsStringFacts;
		} else if ((flags & (TypeFlagsStringLiteral | TypeFlagsTemplateLiteral)) != 0) {
			final isEmpty = (flags & TypeFlagsStringLiteral) != 0 && Checker.getStringLiteralValue(t) == "";
			if (c.strictNullChecks) {
				if (isEmpty) {
					return TypeFactsEmptyStringStrictFacts;
				}
				return TypeFactsNonEmptyStringStrictFacts;
			}
			if (isEmpty) {
				return TypeFactsEmptyStringFacts;
			}
			return TypeFactsNonEmptyStringFacts;
		} else if ((flags & (TypeFlagsNumber | TypeFlagsEnum)) != 0) {
			if (c.strictNullChecks) {
				return TypeFactsNumberStrictFacts;
			}
			return TypeFactsNumberFacts;
		} else if ((flags & TypeFlagsNumberLiteral) != 0) {
			final isZero = (Checker.getNumberLiteralValue(t) : Float) == 0;
			if (c.strictNullChecks) {
				if (isZero) {
					return TypeFactsZeroNumberStrictFacts;
				}
				return TypeFactsNonZeroNumberStrictFacts;
			}
			if (isZero) {
				return TypeFactsZeroNumberFacts;
			}
			return TypeFactsNonZeroNumberFacts;
		} else if ((flags & TypeFlagsBigInt) != 0) {
			if (c.strictNullChecks) {
				return TypeFactsBigIntStrictFacts;
			}
			return TypeFactsBigIntFacts;
		} else if ((flags & TypeFlagsBigIntLiteral) != 0) {
			final isZero = Checker.isZeroBigInt(t);
			if (c.strictNullChecks) {
				if (isZero) {
					return TypeFactsZeroBigIntStrictFacts;
				}
				return TypeFactsNonZeroBigIntStrictFacts;
			}
			if (isZero) {
				return TypeFactsZeroBigIntFacts;
			}
			return TypeFactsNonZeroBigIntFacts;
		} else if ((flags & TypeFlagsBoolean) != 0) {
			if (c.strictNullChecks) {
				return TypeFactsBooleanStrictFacts;
			}
			return TypeFactsBooleanFacts;
		} else if ((flags & TypeFlagsBooleanLike) != 0) {
			final isFalse = t == c.falseType || t == c.regularFalseType;
			if (c.strictNullChecks) {
				if (isFalse) {
					return TypeFactsFalseStrictFacts;
				}
				return TypeFactsTrueStrictFacts;
			}
			if (isFalse) {
				return TypeFactsFalseFacts;
			}
			return TypeFactsTrueFacts;
		} else if ((flags & TypeFlagsObject) != 0) {
			var possibleFacts:TypeFacts = TypeFactsNone;
			if (c.strictNullChecks) {
				possibleFacts = TypeFactsEmptyObjectStrictFacts | TypeFactsFunctionStrictFacts | TypeFactsObjectStrictFacts;
			} else {
				possibleFacts = TypeFactsEmptyObjectFacts | TypeFactsFunctionFacts | TypeFactsObjectFacts;
			}
			if ((callerOnlyNeeds & possibleFacts) == 0) {
				// If the caller doesn't care about any of the facts that we could possibly produce,
				// return zero so we can skip resolving members.
				return TypeFactsNone;
			}
			if ((t.objectFlags & ObjectFlagsAnonymous) != 0 && c.isEmptyObjectType(t)) {
				if (c.strictNullChecks) {
					return TypeFactsEmptyObjectStrictFacts;
				}
				return TypeFactsEmptyObjectFacts;
			} else if (c.isFunctionObjectType(t)) {
				if (c.strictNullChecks) {
					return TypeFactsFunctionStrictFacts;
				}
				return TypeFactsFunctionFacts;
			} else if (c.strictNullChecks) {
				return TypeFactsObjectStrictFacts;
			}
			return TypeFactsObjectFacts;
		} else if ((flags & TypeFlagsVoid) != 0) {
			return TypeFactsVoidFacts;
		} else if ((flags & TypeFlagsUndefined) != 0) {
			return TypeFactsUndefinedFacts;
		} else if ((flags & TypeFlagsNull) != 0) {
			return TypeFactsNullFacts;
		} else if ((flags & TypeFlagsESSymbolLike) != 0) {
			if (c.strictNullChecks) {
				return TypeFactsSymbolStrictFacts;
			} else {
				return TypeFactsSymbolFacts;
			}
		} else if ((flags & TypeFlagsNonPrimitive) != 0) {
			if (c.strictNullChecks) {
				return TypeFactsObjectStrictFacts;
			} else {
				return TypeFactsObjectFacts;
			}
		} else if ((flags & TypeFlagsNever) != 0) {
			return TypeFactsNone;
		} else if ((flags & TypeFlagsUnion) != 0) {
			var facts:TypeFacts = TypeFactsNone;
			for (t in t.Types()) {
				facts |= c.getTypeFactsWorker(t, callerOnlyNeeds);
			}
			return facts;
		} else if ((flags & TypeFlagsIntersection) != 0) {
			return c.getIntersectionTypeFacts(t, callerOnlyNeeds);
		}
		return TypeFactsUnknownFacts;
	}

	static function getIntersectionTypeFacts(c:Checker, t:Type, callerOnlyNeeds:TypeFacts):TypeFacts {
		// When an intersection contains a primitive type we ignore object type constituents as they are
		// presumably type tags. For example, in string & { __kind__: "name" } we ignore the object type.
		final ignoreObjects = c.maybeTypeOfKind(t, TypeFlagsPrimitive);
		// When computing the type facts of an intersection type, certain type facts are computed as `and`
		// and others are computed as `or`.
		var oredFacts = TypeFactsNone;
		var andedFacts = TypeFactsAll;
		for (t in t.Types()) {
			if (!(ignoreObjects && (t.flags & TypeFlagsObject) != 0)) {
				final f = c.getTypeFactsWorker(t, callerOnlyNeeds);
				oredFacts |= f;
				andedFacts &= f;
			}
		}
		return (oredFacts & TypeFactsOrFactsMask) | (andedFacts & TypeFactsAndFactsMask);
	}

	static function isFunctionObjectType(c:Checker, t:Type):Bool {
		if ((t.objectFlags & ObjectFlagsEvolvingArray) != 0) {
			return false;
		}
		// We do a quick check for a "bind" property before performing the more expensive subtype
		// check. This gives us a quicker out in the common case where an object type is not a function.
		final resolved = c.resolveStructuredTypeMembers(t);
		return Core.len(resolved.signatures) != 0 || (symbolTableGet(resolved.members, "bind") != null && c.isTypeSubtypeOf(t, c.globalFunctionType));
	}

	static function getTypeWithFacts(c:Checker, t:Type, include:TypeFacts):Type {
		return c.filterType(t, function(t:Type):Bool {
			return c.hasTypeFacts(t, include);
		});
	}

	// This function is similar to getTypeWithFacts, except that in strictNullChecks mode it replaces type
	// unknown with the union {} | null | undefined (and reduces that accordingly), and it intersects remaining
	// instantiable types with {}, {} | null, or {} | undefined in order to remove null and/or undefined.
	static function getAdjustedTypeWithFacts(c:Checker, t:Type, facts:TypeFacts):Type {
		final reduced = c.recombineUnknownType(c.getTypeWithFacts(c.strictNullChecks && (t.flags & TypeFlagsUnknown) != 0 ? c.unknownUnionType : t, facts));
		if (c.strictNullChecks) {
			switch (facts) {
				case TypeFactsNEUndefined:
					return c.removeNullableByIntersection(reduced, TypeFactsEQUndefined, TypeFactsEQNull, TypeFactsIsNull, c.nullType);
				case TypeFactsNENull:
					return c.removeNullableByIntersection(reduced, TypeFactsEQNull, TypeFactsEQUndefined, TypeFactsIsUndefined, c.undefinedType);
				case TypeFactsNEUndefinedOrNull | TypeFactsTruthy:
					return c.mapType(reduced, function(t:Type):Type {
						if (c.hasTypeFacts(t, TypeFactsEQUndefinedOrNull)) {
							return c.getGlobalNonNullableTypeInstantiation(t);
						}
						return t;
					});
				default:
			}
		}
		return reduced;
	}

	static function removeNullableByIntersection(c:Checker, t:Type, targetFacts:TypeFacts, otherFacts:TypeFacts, otherIncludesFacts:TypeFacts, otherType:Type):Type {
		final facts = c.getTypeFacts(t, TypeFactsEQUndefined | TypeFactsEQNull | TypeFactsIsUndefined | TypeFactsIsNull);
		// Simply return the type if it never compares equal to the target nullable.
		if ((facts & targetFacts) == 0) {
			return t;
		}
		// By default we intersect with a union of {} and the opposite nullable.
		final emptyAndOtherUnion = c.getUnionType([c.emptyObjectType, otherType]);
		// For each constituent type that can compare equal to the target nullable, intersect with the above union
		// if the type doesn't already include the opposite nullable and the constituent can compare equal to the
		// opposite nullable; otherwise, just intersect with {}.
		return c.mapType(t, function(t:Type):Type {
			if (c.hasTypeFacts(t, targetFacts)) {
				if ((facts & otherIncludesFacts) == 0 && c.hasTypeFacts(t, otherFacts)) {
					return c.getIntersectionType([t, emptyAndOtherUnion]);
				}
				return c.getIntersectionType([t, c.emptyObjectType]);
			}
			return t;
		});
	}

	static function recombineUnknownType(c:Checker, t:Type):Type {
		if (t == c.unknownUnionType) {
			return c.unknownType;
		}
		return t;
	}

	static function getGlobalNonNullableTypeInstantiation(c:Checker, t:Type):Type {
		final alias = c.getGlobalNonNullableTypeAliasOrNil();
		if (alias != null) {
			return c.getTypeAliasInstantiation(alias, [t], null);
		}
		return c.getIntersectionType([t, c.emptyObjectType]);
	}

	static function convertAutoToAny(c:Checker, t:Type):Type {
		if (t == c.autoType) {
			return c.anyType;
		} else if (t == c.autoArrayType) {
			return c.anyArrayType;
		}
		return t;
	}

	// Gets the "awaited type" of a type.
	// @param type The type to await.
	// @param withAlias When `true`, wraps the "awaited type" in `Awaited<T>` if needed.
	// @remarks The "awaited type" of an expression is its "promised type" if the expression is a
	// Promise-like type; otherwise, it is the type of the expression. This is used to reflect
	// The runtime behavior of the `await` keyword.
	static function checkAwaitedType(c:Checker, t:Type, withAlias:Bool, errorNode:Node, diagnosticMessage:Message):Type {
		var awaitedType:Type = null;
		if (withAlias) {
			awaitedType = c.getAwaitedTypeEx(t, errorNode, diagnosticMessage);
		} else {
			awaitedType = c.getAwaitedTypeNoAliasEx(t, errorNode, diagnosticMessage);
		}
		if (awaitedType != null) {
			return awaitedType;
		}
		return c.errorType;
	}

	// Gets the "awaited type" of a type.
	//
	// The "awaited type" of an expression is its "promised type" if the expression is a
	// Promise-like type; otherwise, it is the type of the expression. If the "promised
	// type" is itself a Promise-like, the "promised type" is recursively unwrapped until a
	// non-promise type is found.
	//
	// This is used to reflect the runtime behavior of the `await` keyword.
	static function getAwaitedType(c:Checker, t:Type):Type {
		return c.getAwaitedTypeEx(t, null, null);
	}

	static function getAwaitedTypeEx(c:Checker, t:Type, errorNode:Node, diagnosticMessage:Message, ...args:Any):Type {
		final awaitedType = c.getAwaitedTypeNoAliasEx(t, errorNode, diagnosticMessage, ...args);
		if (awaitedType != null) {
			return c.createAwaitedTypeIfNeeded(awaitedType);
		}
		return null;
	}

	// Gets the "awaited type" of a type without introducing an `Awaited<T>` wrapper.
	static function getAwaitedTypeNoAlias(c:Checker, t:Type):Type {
		return c.getAwaitedTypeNoAliasEx(t, null, null);
	}

	static function getAwaitedTypeNoAliasEx(c:Checker, t:Type, errorNode:Node, diagnosticMessage:Message, ...args:Any):Type {
		if (Checker.IsTypeAny(t)) {
			return t;
		}
		// If this is already an `Awaited<T>`, just return it. This avoids `Awaited<Awaited<T>>` in higher-order
		if (c.isAwaitedTypeInstantiation(t)) {
			return t;
		}
		// If we've already cached an awaited type, return a possible `Awaited<T>` for it.
		final key = CachedTypeKey.keyOf(CachedTypeKindAwaitedType, t.id);
		final cachedAwaitedType = c.cachedTypes.get(key);
		if (cachedAwaitedType != null) {
			return cachedAwaitedType;
		}
		// For a union, get a union of the awaited types of each constituent.
		if ((t.flags & TypeFlagsUnion) != 0) {
			if (Slices.Contains(c.awaitedTypeStack, t)) {
				if (errorNode != null) {
					c.error(errorNode, Diagnostics.Type_is_referenced_directly_or_indirectly_in_the_fulfillment_callback_of_its_own_then_method);
				}
				return null;
			}
			pushAwaitedTypeStack(c, t);
			final argsArray = args.toArray();
			final mapped = c.mapType(t, function(t:Type):Type {
				return c.getAwaitedTypeNoAliasEx(t, errorNode, diagnosticMessage, ...argsArray);
			});
			c.awaitedTypeStack.pop();
			c.cachedTypes.set(key, mapped);
			return mapped;
		}
		// If `type` is generic and should be wrapped in `Awaited<T>`, return it.
		if (c.isAwaitedTypeNeeded(t)) {
			c.cachedTypes.set(key, t);
			return t;
		}
		// PORT: pointer. Go `var thisTypeForError *Type` passed as `&thisTypeForError` → one-element holder.
		final thisTypeForError:Array<Type> = [null];
		final promisedType = c.getPromisedTypeOfPromiseEx(t, null /*errorNode*/, thisTypeForError);
		if (promisedType != null) {
			if (t == promisedType || Slices.Contains(c.awaitedTypeStack, promisedType)) {
				// Verify that we don't have a bad actor in the form of a promise whose
				// promised type is the same as the promise type, or a mutually recursive
				// promise. If so, we return undefined as we cannot guess the shape. If this
				// were the actual case in the JavaScript, this Promise would never resolve.
				//
				// An example of a bad actor with a singly-recursive promise type might
				// be:
				//
				//  interface BadPromise {
				//      then(
				//          onfulfilled: (value: BadPromise) => any,
				//          onrejected: (error: any) => any): BadPromise;
				//  }
				//
				// The above interface will pass the PromiseLike check, and return a
				// promised type of `BadPromise`. Since this is a self reference, we
				// don't want to keep recursing ad infinitum.
				//
				// An example of a bad actor in the form of a mutually-recursive
				// promise type might be:
				//
				//  interface BadPromiseA {
				//      then(
				//          onfulfilled: (value: BadPromiseB) => any,
				//          onrejected: (error: any) => any): BadPromiseB;
				//  }
				//
				//  interface BadPromiseB {
				//      then(
				//          onfulfilled: (value: BadPromiseA) => any,
				//          onrejected: (error: any) => any): BadPromiseA;
				//  }
				//
				if (errorNode != null) {
					c.error(errorNode, Diagnostics.Type_is_referenced_directly_or_indirectly_in_the_fulfillment_callback_of_its_own_then_method);
				}
				return null;
			}
			// Keep track of the type we're about to unwrap to avoid bad recursive promise types.
			// See the comments above for more information.
			pushAwaitedTypeStack(c, t);
			final awaitedType = c.getAwaitedTypeNoAliasEx(promisedType, errorNode, diagnosticMessage, ...args);
			c.awaitedTypeStack.pop();
			if (awaitedType == null) {
				return null;
			}
			c.cachedTypes.set(key, awaitedType);
			return awaitedType;
		}
		// The type was not a promise, so it could not be unwrapped any further.
		// As long as the type does not have a callable "then" property, it is
		// safe to return the type; otherwise, an error is reported and we return
		// undefined.
		//
		// An example of a non-promise "thenable" might be:
		//
		//  await { then(): void {} }
		//
		// The "thenable" does not match the minimal definition for a promise. When
		// a Promise/A+-compatible or ES6 promise tries to adopt this value, the promise
		// will never settle. We treat this as an error to help flag an early indicator
		// of a runtime problem. If the user wants to return this value from an async
		// function, they would need to wrap it in some other value. If they want it to
		// be treated as a promise, they can cast to <any>.
		if (c.isThenableType(t)) {
			if (errorNode != null) {
				var diagnostic:Diagnostic = null;
				if (thisTypeForError[0] != null) {
					diagnostic = Checker.NewDiagnosticForNode(errorNode, Diagnostics.The_this_context_of_type_0_is_not_assignable_to_method_s_this_of_type_1, c.TypeToString(t), c.TypeToString(thisTypeForError[0]));
				}
				c.addDiagnostic(Checker.NewDiagnosticChainForNode(diagnostic, errorNode, diagnosticMessage, ...args));
			}
			return null;
		}
		c.cachedTypes.set(key, t);
		return t;
	}

	static function isAwaitedTypeInstantiation(c:Checker, t:Type):Bool {
		if ((t.flags & TypeFlagsConditional) != 0) {
			final awaitedSymbol = c.getGlobalAwaitedSymbolOrNil();
			return awaitedSymbol != null && t.alias != null && t.alias.symbol == awaitedSymbol && Core.len(t.alias.typeArguments) == 1;
		}
		return false;
	}

	static function isAwaitedTypeNeeded(c:Checker, t:Type):Bool {
		// If this is already an `Awaited<T>`, we shouldn't wrap it. This helps to avoid `Awaited<Awaited<T>>` in higher-order.
		if (Checker.IsTypeAny(t) || c.isAwaitedTypeInstantiation(t)) {
			return false;
		}
		// We only need `Awaited<T>` if `T` contains possibly non-primitive types.
		if (c.isGenericObjectType(t)) {
			final baseConstraint = c.getBaseConstraintOfType(t);
			// We only need `Awaited<T>` if `T` is a type variable that has no base constraint, or the base constraint of `T` is `any`, `unknown`, `{}`, `object`,
			// or is promise-like.
			if (baseConstraint != null) {
				return (baseConstraint.flags & TypeFlagsAnyOrUnknown) != 0 || c.isEmptyObjectType(baseConstraint) || Checker.someType(baseConstraint, t -> c.isThenableType(t));
			}
			return c.maybeTypeOfKind(t, TypeFlagsTypeVariable);
		}
		return false;
	}

	static function createAwaitedTypeIfNeeded(c:Checker, t:Type):Type {
		// We wrap type `T` in `Awaited<T>` based on the following conditions:
		// - `T` is not already an `Awaited<U>`, and
		// - `T` is generic, and
		// - One of the following applies:
		//   - `T` has no base constraint, or
		//   - The base constraint of `T` is `any`, `unknown`, `object`, or `{}`, or
		//   - The base constraint of `T` is an object type with a callable `then` method.
		if (c.isAwaitedTypeNeeded(t)) {
			final awaitedType = c.tryCreateAwaitedType(t);
			if (awaitedType != null) {
				return awaitedType;
			}
		}
		return t;
	}

	static function tryCreateAwaitedType(c:Checker, t:Type):Type {
		// Nothing to do if `Awaited<T>` doesn't exist
		final awaitedSymbol = c.getGlobalAwaitedSymbol();
		if (awaitedSymbol != null) {
			// Unwrap unions that may contain `Awaited<T>`, otherwise its possible to manufacture an `Awaited<Awaited<T> | U>` where
			// an `Awaited<T | U>` would suffice.
			return c.getTypeAliasInstantiation(awaitedSymbol, [c.unwrapAwaitedType(t)], null);
		}
		return null;
	}

	// For a generic `Awaited<T>`, gets `T`.
	static function unwrapAwaitedType(c:Checker, t:Type):Type {
		if ((t.flags & TypeFlagsUnion) != 0) {
			return c.mapType(t, t -> c.unwrapAwaitedType(t));
		} else if (c.isAwaitedTypeInstantiation(t)) {
			return t.alias.typeArguments[0];
		}
		return t;
	}

	static function isThenableType(c:Checker, t:Type):Bool {
		if (c.allTypesAssignableToKind(c.getBaseConstraintOrType(t), TypeFlagsPrimitive | TypeFlagsNever)) {
			// primitive types cannot be considered "thenable" since they are not objects.
			return false;
		}
		final thenFunction = c.getTypeOfPropertyOfType(t, "then");
		return thenFunction != null && Core.len(c.getSignaturesOfType(c.getTypeWithFacts(thenFunction, TypeFactsNEUndefinedOrNull), SignatureKindCall)) != 0;
	}

	static function getAwaitedTypeOfPromise(c:Checker, t:Type):Type {
		return c.getAwaitedTypeOfPromiseEx(t, null, null);
	}

	static function getAwaitedTypeOfPromiseEx(c:Checker, t:Type, errorNode:Node, diagnosticMessage:Message, ...args:Any):Type {
		final promisedType = c.getPromisedTypeOfPromiseEx(t, errorNode, null);
		if (promisedType != null) {
			return c.getAwaitedTypeEx(promisedType, errorNode, diagnosticMessage, ...args);
		}
		return null;
	}

	// Check if a parameter or catch variable (or their bindings elements) is assigned anywhere
	static function isSomeSymbolAssigned(c:Checker, rootDeclaration:Node):Bool {
		return c.isSomeSymbolAssignedWorker(rootDeclaration.Name());
	}

	static function isSomeSymbolAssignedWorker(c:Checker, node:Node):Bool {
		if (node.Kind == KindIdentifier) {
			return c.isSymbolAssigned(c.getSymbolOfDeclaration(node.Parent));
		}
		return Core.Some(node.Elements(), function(e:Node):Bool {
			return e.Name() != null && c.isSomeSymbolAssignedWorker(e.Name());
		});
	}

	static function getTargetType(c:Checker, t:Type):Type {
		if ((t.objectFlags & ObjectFlagsReference) != 0) {
			return t.AsTypeReference().target;
		}
		return t;
	}

	static function getNarrowableTypeForReference(c:Checker, t:Type, reference:Node, checkMode:CheckMode):Type {
		if (c.isNoInferType(t)) {
			t = t.AsSubstitutionType().baseType;
		}
		// When the type of a reference is or contains an instantiable type with a union type constraint, and
		// when the reference is in a constraint position (where it is known we'll obtain the apparent type) or
		// has a contextual type containing no top-level instantiables (meaning constraints will determine
		// assignability), we substitute constraints for all instantiables in the type of the reference to give
		// control flow analysis an opportunity to narrow it further. For example, for a reference of a type
		// parameter type 'T extends string | undefined' with a contextual type 'string', we substitute
		// 'string | undefined' to give control flow analysis the opportunity to narrow to type 'string'.
		final substituteConstraints = (checkMode & CheckModeInferential) == 0 && Checker.someType(t, t -> c.isGenericTypeWithUnionConstraint(t)) && (c.isConstraintPosition(t, reference) || c.hasContextualTypeWithNoGenericTypes(reference, checkMode));
		if (substituteConstraints) {
			return c.mapType(t, t -> c.getBaseConstraintOrType(t));
		}
		return t;
	}

	static function isConstraintPosition(c:Checker, t:Type, node:Node):Bool {
		final parent = node.Parent;
		// In an element access obj[x], we consider obj to be in a constraint position, except when obj is of
		// a generic type without a nullable constraint and x is a generic type. This is because when both obj
		// and x are of generic types T and K, we want the resulting type to be T[K].
		return Ast.IsPropertyAccessExpression(parent) || Ast.IsQualifiedName(parent) ||
			((Ast.IsCallExpression(parent) || Ast.IsNewExpression(parent)) && parent.Expression() == node) ||
			(Ast.IsElementAccessExpression(parent) && parent.Expression() == node && !(Checker.someType(t, t -> c.isGenericTypeWithoutNullableConstraint(t)) && c.isGenericIndexType(c.getTypeOfExpression(parent.AsElementAccessExpression().ArgumentExpression))));
	}

	static function isGenericTypeWithUnionConstraint(c:Checker, t:Type):Bool {
		if ((t.flags & TypeFlagsIntersection) != 0) {
			return Core.Some(t.AsIntersectionType().types, t -> c.isGenericTypeWithUnionConstraint(t));
		}
		return (t.flags & TypeFlagsInstantiable) != 0 && (c.getBaseConstraintOrType(t).flags & (TypeFlagsNullable | TypeFlagsUnion)) != 0;
	}

	static function isGenericTypeWithoutNullableConstraint(c:Checker, t:Type):Bool {
		if ((t.flags & TypeFlagsIntersection) != 0) {
			return Core.Some(t.AsIntersectionType().types, t -> c.isGenericTypeWithoutNullableConstraint(t));
		}
		return (t.flags & TypeFlagsInstantiable) != 0 && !c.maybeTypeOfKind(c.getBaseConstraintOrType(t), TypeFlagsNullable);
	}

	static function hasContextualTypeWithNoGenericTypes(c:Checker, node:Node, checkMode:CheckMode):Bool {
		// Computing the contextual type for a child of a JSX element involves resolving the type of the
		// element's tag name, so we exclude that here to avoid circularities.
		// If check mode has `CheckMode.RestBindingElement`, we skip binding pattern contextual types,
		// as we want the type of a rest element to be generic when possible.
		if ((Ast.IsIdentifier(node) || Ast.IsPropertyAccessExpression(node) || Ast.IsElementAccessExpression(node)) &&
			!((Ast.IsJsxOpeningElement(node.Parent) || Ast.IsJsxSelfClosingElement(node.Parent)) && node.Parent.TagName() == node)) {
			final contextualType = c.getContextualType(node, Core.IfElse((checkMode & CheckModeRestBindingElement) != 0, ContextFlagsSkipBindingPatterns, ContextFlagsNone));
			if (contextualType != null) {
				return !c.isGenericType(contextualType);
			}
		}
		return false;
	}

	static function getNonUndefinedType(c:Checker, t:Type):Type {
		var typeOrConstraint = t;
		if (Checker.someType(t, t -> c.isGenericTypeWithUndefinedConstraint(t))) {
			typeOrConstraint = c.mapType(t, function(t:Type):Type {
				if ((t.flags & TypeFlagsInstantiable) != 0) {
					return c.getBaseConstraintOrType(t);
				}
				return t;
			});
		}
		return c.getTypeWithFacts(typeOrConstraint, TypeFactsNEUndefined);
	}

	static function isGenericTypeWithUndefinedConstraint(c:Checker, t:Type):Bool {
		if ((t.flags & TypeFlagsInstantiable) != 0) {
			final constraint = c.getBaseConstraintOfType(t);
			if (constraint != null) {
				return c.maybeTypeOfKind(constraint, TypeFlagsUndefined);
			}
		}
		return false;
	}

	static function getActualTypeVariable(c:Checker, t:Type):Type {
		if ((t.flags & TypeFlagsSubstitution) != 0) {
			return c.getActualTypeVariable(t.AsSubstitutionType().baseType);
		}
		if ((t.flags & TypeFlagsIndexedAccess) != 0 && ((t.AsIndexedAccessType().objectType.flags & TypeFlagsSubstitution) != 0 || (t.AsIndexedAccessType().indexType.flags & TypeFlagsSubstitution) != 0)) {
			return c.getIndexedAccessType(c.getActualTypeVariable(t.AsIndexedAccessType().objectType), c.getActualTypeVariable(t.AsIndexedAccessType().indexType));
		}
		return t;
	}

	public static function GetSymbolAtLocation(c:Checker, node:Node):Symbol {
		// !!!
		// const node = getParseTreeNode(nodeIn);

		// set ignoreErrors: true because any lookups invoked by the API shouldn't cause any new errors
		return c.getSymbolAtLocation(Ast.GetReparsedNodeForNode(node), true /*ignoreErrors*/);
	}

	// Returns the symbol associated with a given AST node. Do *not* use this function in the checker itself! It should
	// be used only by the language service and external tools. The semantics of the function are deliberately "fuzzy"
	// and aim to just return *some* symbol for the node. To obtain the symbol associated with a node for type checking
	// purposes, use appropriate function for the context, e.g. `getResolvedSymbol` for an expression identifier,
	// `getSymbolOfDeclaration` for a declaration, etc.
	static function getSymbolAtLocation(c:Checker, node:Node, ignoreErrors:Bool):Symbol {
		if (Ast.IsSourceFile(node)) {
			if (Ast.IsExternalOrCommonJSModule(node.AsSourceFile())) {
				return c.getMergedSymbol(node.Symbol());
			}
			return null;
		}
		final parent = node.Parent;
		final grandParent = parent.Parent;

		if ((node.Flags & NodeFlagsInWithStatement) != 0) {
			// We cannot answer semantic questions within a with block, do not proceed any further
			return null;
		}

		if (Ast.IsDeclarationNameOrImportPropertyName(node)) {
			// This is a declaration, call getSymbolOfNode
			final parentSymbol = c.getSymbolOfDeclaration(parent);
			if (Ast.IsImportOrExportSpecifier(parent) && parent.PropertyName() == node) {
				return c.getImmediateAliasedSymbol(parentSymbol);
			}
			return parentSymbol;
		} else if (Ast.IsLiteralComputedPropertyDeclarationName(node)) {
			return c.getSymbolOfDeclaration(grandParent);
		}

		if (Ast.IsIdentifier(node)) {
			if (Checker.isInRightSideOfImportOrExportAssignment(node)) {
				return c.getSymbolOfNameOrPropertyAccessExpression(node);
			} else if (Ast.IsBindingElement(parent) && Ast.IsObjectBindingPattern(grandParent) && node == parent.PropertyName()) {
				final typeOfPattern = c.getTypeOfNode(grandParent);
				final propertyDeclaration = c.getPropertyOfType(typeOfPattern, node.Text());
				if (propertyDeclaration != null) {
					return propertyDeclaration;
				}
			} else if (Ast.IsMetaProperty(parent) && parent.Name() == node) {
				final metaProp = parent.AsMetaProperty();
				if (metaProp.KeywordToken == KindNewKeyword && node.Text() == "target") {
					// `target` in `new.target`
					return c.checkNewTargetMetaProperty(parent).symbol;
				}
				// The `meta` in `import.meta` could be given `getTypeOfNode(parent).symbol` (the `ImportMeta` interface symbol), but
				// we have a fake expression type made for other reasons already, whose transient `meta`
				// member should more exactly be the kind of (declarationless) symbol we want.
				// (See #44364 and #45031 for relevant implementation PRs)
				if (metaProp.KeywordToken == KindImportKeyword && node.Text() == "meta") {
					return symbolTableGet(c.getGlobalImportMetaExpressionType().AsObjectType().members, "meta");
				}
				// no other meta properties are valid syntax, thus no others should have symbols
				return null;
			} else if (Ast.IsJSDocParameterTag(parent) && parent.Name() == node) {
				final fn = Ast.GetNodeAtPosition(Ast.GetSourceFileOfNode(node), node.Pos(), false);
				if (fn != null && Ast.IsFunctionLike(fn)) {
					for (param in rangeOf(fn.Parameters())) {
						if (Ast.IsIdentifier(param.Name()) && param.Name().Text() == node.Text()) {
							return c.getSymbolOfNode(param);
						}
					}
				}
			}
		}

		// PORT: Go `fallthrough` chains → local functions for the shared case tails.
		final caseThisType = function():Symbol {
			return c.getTypeFromThisTypeNode(node).symbol;
		};
		final caseThisKeyword = function():Symbol {
			final container = c.getThisContainer(node, false /*includeArrowFunctions*/, false /*includeClassComputedPropertyName*/);
			if (Ast.IsFunctionLike(container)) {
				final sig = c.getSignatureFromDeclaration(container);
				if (sig.thisParameter != null) {
					return sig.thisParameter;
				}
			}
			if (Ast.IsInExpressionContext(node)) {
				return c.checkExpression(node).symbol;
			}
			return caseThisType();
		};
		final caseNumericLiteral = function():Symbol {
			// index access
			var objectType:Type = null;
			if (Ast.IsElementAccessExpression(parent)) {
				if (parent.AsElementAccessExpression().ArgumentExpression == node) {
					objectType = c.getTypeOfExpression(parent.Expression());
				}
			} else if (Ast.IsLiteralTypeNode(parent) && Ast.IsIndexedAccessTypeNode(grandParent)) {
				objectType = c.getTypeFromTypeNode(grandParent.AsIndexedAccessTypeNode().ObjectType);
			}

			if (objectType != null) {
				return c.getPropertyOfType(objectType, node.Text());
			}
			return null;
		};
		final caseNewKeyword = function():Symbol {
			if (Ast.IsMetaProperty(parent)) {
				return c.checkMetaPropertyKeyword(parent).symbol;
			}
			return null;
		};

		switch (node.Kind) {
			case KindIdentifier | KindPrivateIdentifier | KindPropertyAccessExpression | KindQualifiedName:
				if (!Ast.IsThisInTypeQuery(node)) {
					return c.getSymbolOfNameOrPropertyAccessExpression(node);
				}
				return caseThisKeyword();
			case KindThisKeyword:
				return caseThisKeyword();
			case KindThisType:
				return caseThisType();
			case KindSuperKeyword:
				return c.checkExpression(node).symbol;
			case KindConstructorKeyword:
				// constructor keyword for an overload, should take us to the definition if it exist
				final constructorDeclaration = parent;
				if (constructorDeclaration != null && constructorDeclaration.Kind == KindConstructor) {
					return constructorDeclaration.Parent.Symbol();
				}
				return null;
			case KindStringLiteral | KindNoSubstitutionTemplateLiteral:
				// 1). import x = require("./mo/*gotToDefinitionHere*/d")
				// 2). External module name in an import declaration
				// 3). Require in Javascript
				// 4). type A = import("./f/*gotToDefinitionHere*/oo")
				if ((Ast.IsExternalModuleImportEqualsDeclaration(grandParent) && Ast.GetExternalModuleImportEqualsDeclarationExpression(grandParent) == node) ||
					((parent.Kind == KindImportDeclaration || parent.Kind == KindJSImportDeclaration || parent.Kind == KindExportDeclaration) && Ast.GetExternalModuleName(parent) == node) ||
					Ast.IsVariableDeclarationInitializedToRequire(grandParent) || Ast.IsImportCall(parent) ||
					(Ast.IsLiteralTypeNode(parent) && Ast.IsLiteralImportTypeNode(grandParent) && grandParent.AsImportTypeNode().Argument == parent)) {
					return c.resolveExternalModuleName(node, node, ignoreErrors);
				}
				if (Ast.IsCallExpression(parent) && Ast.IsBindableObjectDefinePropertyCall(parent) && parent.Arguments()[1] == node) {
					return c.getSymbolOfDeclaration(parent);
				}
				return caseNumericLiteral();
			case KindNumericLiteral:
				return caseNumericLiteral();
			case KindDefaultKeyword | KindFunctionKeyword | KindEqualsGreaterThanToken | KindClassKeyword:
				return c.getSymbolOfNode(node.Parent);
			case KindImportType:
				if (Ast.IsLiteralImportTypeNode(node)) {
					return c.getSymbolAtLocation(node.AsImportTypeNode().Argument.AsLiteralTypeNode().Literal, ignoreErrors);
				}
				return null;
			case KindExportKeyword:
				if (Ast.IsExportAssignment(parent)) {
					if (parent.Symbol() == null) {
						throw "Symbol should be defined";
					}
					return parent.Symbol();
				}
				return null;
			case KindImportKeyword:
				if (Ast.IsMetaProperty(node.Parent) && node.Parent.Text() == "defer") {
					return null;
				}
				return caseNewKeyword();
			case KindNewKeyword:
				return caseNewKeyword();
			case KindInstanceOfKeyword:
				if (Ast.IsBinaryExpression(parent)) {
					final t = c.getTypeOfExpression(parent.AsBinaryExpression().Right);
					final hasInstanceMethodType = c.getSymbolHasInstanceMethodOfObjectType(t);
					if (hasInstanceMethodType != null && hasInstanceMethodType.symbol != null) {
						return hasInstanceMethodType.symbol;
					}
					return t.symbol;
				}
				return null;
			case KindMetaProperty:
				return c.checkExpression(node).symbol;
			case KindJsxNamespacedName:
				if (Ast.IsJsxTagName(node) && Checker.isJsxIntrinsicTagName(node)) {
					final symbol = c.getIntrinsicTagSymbol(node.Parent);
					if (symbol == c.unknownSymbol) {
						return null;
					}
					return symbol;
				}
				return null;
			default:
				return null;
		}
	}

	static function getIndexSignaturesAtLocation(c:Checker, node:Node):Array<Node> {
		var signatures:Array<Node> = null;
		if (Ast.IsIdentifier(node) && Ast.IsPropertyAccessExpression(node.Parent) && node.Parent.Name() == node) {
			final keyType = c.getLiteralTypeFromPropertyName(node);
			final objectType = c.getTypeOfExpression(node.Parent.Expression());
			for (t in rangeOf(objectType.Distributed())) {
				for (info in rangeOf(c.getApplicableIndexInfos(t, keyType))) {
					if (info.declaration != null) {
						signatures = Core.AppendIfUnique(signatures, info.declaration);
					}
				}
			}
		}
		return signatures;
	}

	static function getSymbolOfNameOrPropertyAccessExpression(c:Checker, name:Node):Symbol {
		if (Ast.IsDeclarationName(name)) {
			return c.getSymbolOfNode(name.Parent);
		}
		if (name.Parent.Kind == KindExportAssignment && Ast.IsEntityNameExpression(name)) {
			// Even an entity name expression that doesn't resolve as an entityname may still typecheck as a property access expression
			final success = c.resolveEntityName(name,
				/*all meanings*/ SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace | SymbolFlagsAlias,
				true /*ignoreErrors*/, false /*dontResolveAlias*/, null /*location*/);
			if (success != null && success != c.unknownSymbol) {
				return success;
			}
		} else if (Ast.IsEntityName(name) && Checker.isInRightSideOfImportOrExportAssignment(name)) {
			// Since we already checked for ExportAssignment, this really could only be an Import
			final importEqualsDeclaration = Ast.FindAncestorKind(name, KindImportEqualsDeclaration);
			if (importEqualsDeclaration == null) {
				throw "ImportEqualsDeclaration should be defined";
			}
			return c.getSymbolOfPartOfRightHandSideOfImportEquals(name);
		}

		if (Ast.IsEntityName(name)) {
			final possibleImportNode = Checker.isImportTypeQualifierPart(name);
			if (possibleImportNode != null) {
				c.getTypeFromTypeNode(possibleImportNode);
				final sym = c.getResolvedSymbolOrNil(name);
				return Core.IfElse(sym == c.unknownSymbol, null, sym);
			}
		}

		while (Ast.IsRightSideOfQualifiedNameOrPropertyAccess(name)) {
			name = name.Parent;
		}

		if (Checker.isInNameOfExpressionWithTypeArguments(name)) {
			var meaning:SymbolFlags = SymbolFlagsNone;
			if (name.Parent.Kind == KindExpressionWithTypeArguments) {
				// An 'ExpressionWithTypeArguments' may appear in type space (interface Foo extends Bar<T>),
				// value space (return foo<T>), or both(class Foo extends Bar<T>); ensure the meaning matches.
				meaning = Core.IfElse(Ast.IsPartOfTypeNode(name), SymbolFlagsType, SymbolFlagsValue);

				// In a class 'extends' clause we are also looking for a value.
				if (Ast.IsExpressionWithTypeArgumentsInClassExtendsClause(name.Parent)) {
					meaning = meaning | SymbolFlagsValue;
				}
			} else {
				meaning = SymbolFlagsNamespace;
			}

			meaning = meaning | SymbolFlagsAlias;
			var entityNameSymbol:Symbol = null;
			if (Ast.IsEntityNameExpression(name)) {
				entityNameSymbol = c.resolveEntityName(name, meaning, true /*ignoreErrors*/, false /*dontResolveAlias*/, null /*location*/);
			}
			if (entityNameSymbol != null) {
				return entityNameSymbol;
			}
		}

		if (Ast.IsExpressionNode(name)) {
			if (Ast.NodeIsMissing(name)) {
				// Missing entity name.
				return null;
			}
			final isJSDoc = Ast.IsJSDocNameReferenceContext(name);
			if (Ast.IsIdentifier(name)) {
				if (Ast.IsJsxTagName(name) && Checker.isJsxIntrinsicTagName(name)) {
					final symbol = c.getIntrinsicTagSymbol(name.Parent);
					return Core.IfElse(symbol == c.unknownSymbol, null, symbol);
				}
				final meaning = Core.IfElse(isJSDoc, SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace, SymbolFlagsValue);
				var location:Node = null;
				if (isJSDoc) {
					location = Ast.GetHostSignatureFromJSDoc(name);
				}
				var result = c.resolveEntityName(name, meaning, true /*ignoreErrors*/, true /*dontResolveAlias*/, location);
				if (result == null && isJSDoc) {
					final container = Ast.FindAncestor(name, n -> Ast.IsClassOrInterfaceLike(n));
					if (container != null) {
						final symbol = c.getSymbolOfDeclaration(container);
						// Handle unqualified references to class static members and class or interface instance members
						result = c.getMergedSymbol(c.getSymbol(c.getExportsOfSymbol(symbol), name.Text(), meaning));
						if (result == null) {
							result = c.getPropertyOfType(c.getDeclaredTypeOfSymbol(symbol), name.Text());
						}
					}
				}
				return result;
			} else if (Ast.IsPrivateIdentifier(name)) {
				return c.getSymbolForPrivateIdentifierExpression(name);
			} else if (Ast.IsPropertyAccessExpression(name) || Ast.IsQualifiedName(name)) {
				final links = c.symbolNodeLinks.Get(name);
				if (links.resolvedSymbol != null) {
					return links.resolvedSymbol;
				}
				if (Ast.IsPropertyAccessExpression(name)) {
					c.checkPropertyAccessExpression(name, CheckModeNormal, false /*writeOnly*/);
					if (links.resolvedSymbol == null && !Ast.IsPrivateIdentifier(name.Name())) {
						links.resolvedSymbol = c.getApplicableIndexSymbol(c.checkExpressionCached(name.Expression()), c.getLiteralTypeFromPropertyName(name.Name()));
					}
				} else {
					c.checkQualifiedName(name, CheckModeNormal);
				}
				if (links.resolvedSymbol == null && isJSDoc && Ast.IsQualifiedName(name)) {
					return c.resolveJSDocMemberName(name);
				}
				return links.resolvedSymbol;
			}
		} else if (Ast.IsEntityName(name) && Checker.isTypeReferenceIdentifier(name)) {
			final meaning = Core.IfElse(name.Parent.Kind == KindTypeReference, SymbolFlagsType, SymbolFlagsNamespace);
			final symbol = c.resolveEntityName(name, meaning, true /*ignoreErrors*/, true /*dontResolveAlias*/, null /*location*/);
			if (symbol != null && symbol != c.unknownSymbol) {
				return symbol;
			}
			return c.getUnresolvedSymbolForEntityName(name);
		}

		if (name.Parent.Kind == KindTypePredicate) {
			return c.resolveEntityName(name,
				SymbolFlagsFunctionScopedVariable, /*meaning*/
				true, /*ignoreErrors*/
				false, /*dontResolveAlias*/
				null /*location*/);
		}
		return null;
	}

	static function isThisPropertyAndThisTyped(c:Checker, node:Node):Bool {
		if (node.Expression().Kind == KindThisKeyword) {
			final container = c.getThisContainer(node, false /*includeArrowFunctions*/, false /*includeClassComputedPropertyName*/);
			if (Ast.IsFunctionLike(container)) {
				final containingLiteral = Checker.getContainingObjectLiteral(container);
				if (containingLiteral != null) {
					final contextualType = c.getApparentTypeOfContextualType(containingLiteral, ContextFlagsNone);
					final t = c.getThisTypeOfObjectLiteralFromContextualType(containingLiteral, contextualType);
					return t != null && !Checker.IsTypeAny(t);
				}
			}
		}
		return false;
	}

	static function getTypeOfNode(c:Checker, node:Node):Type {
		if (Ast.IsSourceFile(node) && !Ast.IsExternalOrCommonJSModule(node.AsSourceFile())) {
			return c.errorType;
		}

		if ((node.Flags & NodeFlagsInWithStatement) != 0) {
			// We cannot answer semantic questions within a with block, do not proceed any further
			return c.errorType;
		}

		final r = Ast.TryGetClassImplementingOrExtendingExpressionWithTypeArguments(node);
		final classDecl = r.a;
		final isImplements = r.b;
		var classType:Type = null;
		if (classDecl != null) {
			classType = c.getDeclaredTypeOfClassOrInterface(c.getSymbolOfDeclaration(classDecl));
		}

		if (Ast.IsPartOfTypeNode(node)) {
			final typeFromTypeNode = c.getTypeFromTypeNode(node);
			if (classType != null) {
				return c.getTypeWithThisArgument(typeFromTypeNode, classType.AsInterfaceType().thisType, false /*needApparentType*/);
			}
			return typeFromTypeNode;
		}

		if (Ast.IsExpressionNode(node)) {
			return c.getRegularTypeOfExpression(node);
		}

		if (classType != null && !isImplements) {
			// A SyntaxKind.ExpressionWithTypeArguments is considered a type node, except when it occurs in the
			// extends clause of a class. We handle that case here.
			final baseType = Core.FirstOrNil(c.getBaseTypes(classType));
			if (baseType != null) {
				return c.getTypeWithThisArgument(baseType, classType.AsInterfaceType().thisType, false /*needApparentType*/);
			}
			return c.errorType;
		}

		if (Ast.IsTypeDeclaration(node)) {
			// In this case, we call getSymbolOfDeclaration instead of getSymbolAtLocation because it is a declaration
			final symbol = c.getSymbolOfDeclaration(node);
			return c.getDeclaredTypeOfSymbol(symbol);
		}

		if (Ast.IsTypeDeclarationName(node)) {
			final symbol = c.getSymbolAtLocation(node, false /*ignoreErrors*/);
			if (symbol != null) {
				return c.getDeclaredTypeOfSymbol(symbol);
			}
			return c.errorType;
		}

		if (Ast.IsBindingElement(node)) {
			final t = c.getTypeForVariableLikeDeclaration(node, true /*includeOptionality*/, CheckModeNormal);
			if (t != null) {
				return t;
			}
			return c.errorType;
		}

		if (Ast.IsDeclaration(node)) {
			// In this case, we call getSymbolOfDeclaration instead of getSymbolLAtocation because it is a declaration
			final symbol = c.getSymbolOfDeclaration(node);
			if (symbol != null) {
				return c.getTypeOfSymbol(symbol);
			}
			return c.errorType;
		}

		if (Ast.IsDeclarationNameOrImportPropertyName(node)) {
			final symbol = c.getSymbolAtLocation(node, false /*ignoreErrors*/);
			if (symbol != null) {
				return c.getTypeOfSymbol(symbol);
			}
			return c.errorType;
		}

		if (Ast.IsBindingPattern(node)) {
			final t = c.getTypeForVariableLikeDeclaration(node.Parent, true /*includeOptionality*/, CheckModeNormal);
			if (t != null) {
				return t;
			}
			return c.errorType;
		}

		if (Checker.isInRightSideOfImportOrExportAssignment(node)) {
			final symbol = c.getSymbolAtLocation(node, false /*ignoreErrors*/);
			if (symbol != null) {
				final declaredType = c.getDeclaredTypeOfSymbol(symbol);
				if (!c.isErrorType(declaredType)) {
					return declaredType;
				}
				return c.getTypeOfSymbol(symbol);
			}
		}

		if (Ast.IsMetaProperty(node.Parent) && node.Parent.AsMetaProperty().KeywordToken == node.Kind) {
			return c.checkMetaPropertyKeyword(node.Parent);
		}

		if (Ast.IsImportAttributes(node)) {
			return c.getGlobalImportAttributesType();
		}

		return c.errorType;
	}

	static function getThisTypeOfObjectLiteralFromContextualType(c:Checker, containingLiteral:Node, contextualType:Type):Type {
		var literal = containingLiteral;
		var t = contextualType;
		while (t != null) {
			final thisType = c.getThisTypeFromContextualType(t);
			if (thisType != null) {
				return thisType;
			}
			if (literal.Parent.Kind != KindPropertyAssignment) {
				break;
			}
			literal = literal.Parent.Parent;
			t = c.getApparentTypeOfContextualType(literal, ContextFlagsNone);
		}
		return null;
	}

	static function getThisTypeFromContextualType(c:Checker, t:Type):Type {
		return c.mapType(t, function(t:Type):Type {
			if ((t.flags & TypeFlagsIntersection) != 0) {
				for (t in t.AsIntersectionType().types) {
					final typeArg = c.getThisTypeArgument(t);
					if (typeArg != null) {
						return typeArg;
					}
				}
				return null;
			} else {
				return c.getThisTypeArgument(t);
			}
		});
	}

	static function getThisTypeArgument(c:Checker, t:Type):Type {
		if ((t.objectFlags & ObjectFlagsReference) != 0 && t.AsTypeReference().target == c.globalThisType) {
			return c.getTypeArguments(t)[0];
		}
		return null;
	}

	static function getApplicableIndexInfos(c:Checker, t:Type, keyType:Type):Array<IndexInfo> {
		return Core.Filter(c.getIndexInfosOfType(t), function(info:IndexInfo):Bool {
			return c.isApplicableIndexType(keyType, info.keyType);
		});
	}

	static function getApplicableIndexSymbol(c:Checker, t:Type, keyType:Type):Symbol {
		final info = c.getApplicableIndexInfo(t, keyType);
		if (info != null && info != c.anyBaseTypeIndexInfo) {
			if (info.indexSymbol == null) {
				var declarations:Array<Node> = null;
				if (info.declaration != null) {
					declarations = [info.declaration];
				} else {
					for (info in rangeOf(c.getIndexInfosOfType(t))) {
						if (info.declaration != null && c.isApplicableIndexType(keyType, info.keyType)) {
							if (declarations == null) {
								declarations = [];
							}
							declarations.push(info.declaration);
						}
					}
				}
				if (Core.len(declarations) != 0) {
					final symbol = c.newSymbol(SymbolFlagsProperty, Ast.InternalSymbolNameIndex);
					symbol.CheckFlags |= CheckFlagsIndexSymbol;
					symbol.Declarations = declarations;
					symbol.ValueDeclaration = declarations[0];
					symbol.Parent = t.symbol;
					final links = c.valueSymbolLinks.Get(symbol);
					links.resolvedType = info.valueType;
					info.indexSymbol = symbol;
				}
			}
			return info.indexSymbol;
		}
		return null;
	}

	static function getRegularTypeOfExpression(c:Checker, expr:Node):Type {
		if (Ast.IsRightSideOfQualifiedNameOrPropertyAccess(expr)) {
			expr = expr.Parent;
		}
		return c.getRegularTypeOfLiteralType(c.getTypeOfExpression(expr));
	}

	static function containsArgumentsReference(c:Checker, node:Node):Bool {
		if (node.Body() == null) {
			return false;
		}

		if (c.cachedArgumentsReferenced.exists(node)) {
			return c.cachedArgumentsReferenced.get(node);
		}

		var visit:(Node) -> Bool = null;
		visit = function(node:Node):Bool {
			if (node == null) {
				return false;
			}
			switch (node.Kind) {
				case KindIdentifier:
					return node.Text() == c.argumentsSymbol.Name && c.IsArgumentsSymbol(c.getResolvedSymbol(node));
				case KindPropertyDeclaration | KindMethodDeclaration | KindGetAccessor | KindSetAccessor:
					if (Ast.IsComputedPropertyName(node.Name())) {
						return visit(node.Name());
					}
				case KindPropertyAccessExpression | KindElementAccessExpression:
					return visit(node.Expression());
				case KindPropertyAssignment:
					return visit(node.Initializer());
				default:
			}
			if (Checker.nodeStartsNewLexicalEnvironment(node) || Ast.IsPartOfTypeNode(node)) {
				return false;
			}
			return node.ForEachChild(visit);
		};

		final containsArguments = visit(node.Body());
		c.cachedArgumentsReferenced.set(node, containsArguments);
		return containsArguments;
	}

	public static function GetTypeAtLocation(c:Checker, node:Node):Type {
		return c.getTypeOfNode(Ast.GetReparsedNodeForNode(node));
	}

	public static function GetEmitResolver(c:Checker):EmitResolver {
		// PORT: sync.Once → lazy field with a null check (PORTING.md §4).
		if (c.emitResolver == null) {
			c.emitResolver = Checker.newEmitResolver(c);
		}

		return c.emitResolver;
	}

	public static function GetAliasedSymbol(c:Checker, symbol:Symbol):Symbol {
		return c.resolveAlias(symbol);
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
	
	// PORT: Go TypeSystemEntity is `any`; the skeleton's empty interface is not declared by Symbol/Type/Signature,
	// so the value is passed through an unchecked cast (as in Relater.hx).
	static inline function entity(o:Dynamic):TypeSystemEntity {
		return cast o;
	}
	
	// PORT: Go method value `c.getRegularTypeOfObjectLiteral` (recursive transform callback).
	static inline function fn_getRegularTypeOfObjectLiteral(c:Checker):(Type) -> Type {
		return t -> c.getRegularTypeOfObjectLiteral(t);
	}
	
	// PORT: Go builtin `min` on ints.
	static inline function imin(a:Int, b:Int):Int {
		return a < b ? a : b;
	}
	
	// PORT: method values created once (PORTING.md §7a).
	static final fn_isSpreadArgument:(Node) -> Bool = arg -> Checker.isSpreadArgument(arg);
	
	// PORT: method values created once (PORTING.md §7a).
	static final fn_hasInferenceCandidatesOrDefault:(InferenceInfo) -> Bool = info -> Checker.hasInferenceCandidatesOrDefault(info);
	
	// PORT: Go `c.awaitedTypeStack = append(c.awaitedTypeStack, t)` on a possibly-nil slice.
	static inline function pushAwaitedTypeStack(c:Checker, t:Type):Void {
		if (c.awaitedTypeStack == null) {
			c.awaitedTypeStack = [];
		}
		c.awaitedTypeStack.push(t);
	}
	
}
