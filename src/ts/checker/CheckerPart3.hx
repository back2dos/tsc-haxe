package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/checker.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Part of checker.go, Go lines 7980-11981 (4002 lines): the Checker methods of this range as static extension
// (receiver first, PORTING.md §2; `using ts.checker.CheckerPart3` in import.hx). Inside class Checker call them as `this.m(...)`.
@:allow(ts.checker)
class CheckerPart3 {

	static function isTemplateLiteralContext(c:Checker, node:Node):Bool {
		final parent = node.Parent;
		return Ast.IsParenthesizedExpression(parent) && c.isTemplateLiteralContext(parent)
			|| Ast.IsElementAccessExpression(parent) && parent.AsElementAccessExpression().ArgumentExpression == node;
	}

	static function isTemplateLiteralContextualType(c:Checker, t:Type):Bool {
		return t.flags & (TypeFlagsStringLiteral | TypeFlagsTemplateLiteral) != 0
			|| t.flags & TypeFlagsInstantiableNonPrimitive != 0
				&& c.maybeTypeOfKind(Core.OrElse(c.getBaseConstraintOfType(t), c.unknownType), TypeFlagsStringLike);
	}

	static function checkRegularExpressionLiteral(c:Checker, node:Node):Type {
		final nodeLinks = c.nodeLinks.Get(node);
		if (nodeLinks.flags & NodeCheckFlagsTypeChecked == 0) {
			nodeLinks.flags |= NodeCheckFlagsTypeChecked;
			c.checkGrammarRegularExpressionLiteral(node.AsRegularExpressionLiteral());
		}
		return c.globalRegExpType;
	}

	static function checkArrayLiteral(c:Checker, node:Node, checkMode:CheckMode):Type {
		final elements = node.Elements();
		final elementTypes:Array<Type> = [for (_ in 0...Core.len(elements)) null];
		final elementInfos:Array<TupleElementInfo> = [for (_ in 0...Core.len(elements)) null];
		c.pushCachedContextualType(node);
		final inDestructuringPattern = Ast.IsAssignmentTarget(node);
		final inConstContext = c.isConstContext(node);
		final contextualType = c.getApparentTypeOfContextualType(node, ContextFlagsNone);
		final inTupleContext = Checker.isSpreadIntoCallOrNew(node) || contextualType != null && Checker.someType(contextualType, (t:Type) -> {
			return c.isTupleLikeType(t)
				|| c.isGenericMappedType(t) && t.AsMappedType().nameType == null
					&& c.getHomomorphicTypeVariable(Core.OrElse(t.AsMappedType().target, t)) != null;
		});
		var hasOmittedExpression = false;
		if (elements != null) {
			for (i in 0...elements.length) {
				final e = elements[i];
				if (Ast.IsSpreadElement(e)) {
					final spreadType = c.checkExpressionEx(e.Expression(), checkMode);
					if (c.isArrayLikeType(spreadType)) {
						elementTypes[i] = spreadType;
						elementInfos[i] = TupleNormalizer.newTupleElementInfo(ElementFlagsVariadic, null);
					} else if (inDestructuringPattern) {
						// Given the following situation:
						//    var c: {};
						//    [...c] = ["", 0];
						//
						// c is represented in the tree as a spread element in an array literal.
						// But c really functions as a rest element, and its purpose is to provide
						// a contextual type for the right hand side of the assignment. Therefore,
						// instead of calling checkExpression on "...c", which will give an error
						// if c is not iterable/array-like, we need to act as if we are trying to
						// get the contextual element type from it. So we do something similar to
						// getContextualTypeForElementExpression, which will crucially not error
						// if there is no index type / iterated type.
						var restElementType = c.getIndexTypeOfType(spreadType, c.numberType);
						if (restElementType == null) {
							restElementType = c.getIteratedTypeOrElementType(IterationUseDestructuring, spreadType, c.undefinedType, null /*errorNode*/,
								false /*checkAssignability*/);
							if (restElementType == null) {
								restElementType = c.unknownType;
							}
						}
						elementTypes[i] = restElementType;
						elementInfos[i] = TupleNormalizer.newTupleElementInfo(ElementFlagsRest, null);
					} else {
						elementTypes[i] = c.checkIteratedTypeOrElementType(IterationUseSpread, spreadType, c.undefinedType, e.Expression());
						elementInfos[i] = TupleNormalizer.newTupleElementInfo(ElementFlagsRest, null);
					}
				} else if (c.exactOptionalPropertyTypes && Ast.IsOmittedExpression(e)) {
					hasOmittedExpression = true;
					elementTypes[i] = c.undefinedOrMissingType;
					elementInfos[i] = TupleNormalizer.newTupleElementInfo(ElementFlagsOptional, null);
				} else {
					final t = c.checkExpressionForMutableLocation(e, checkMode);
					elementTypes[i] = c.addOptionalityEx(t, true /*isProperty*/, hasOmittedExpression);
					elementInfos[i] = TupleNormalizer.newTupleElementInfo(Core.IfElse(hasOmittedExpression, ElementFlagsOptional, ElementFlagsRequired), null);
					if (inTupleContext && checkMode & CheckModeInferential != 0 && checkMode & CheckModeSkipContextSensitive == 0 && c.isContextSensitive(e)) {
						final inferenceContext = c.getInferenceContext(node);
						// In CheckMode.Inferential we should always have an inference context
						c.addIntraExpressionInferenceSite(inferenceContext, e, t);
					}
				}
			}
		}
		c.popContextualType();
		if (inDestructuringPattern) {
			return c.createTupleTypeEx(elementTypes, elementInfos, false);
		}
		if (checkMode & CheckModeForceTuple != 0 || inConstContext || inTupleContext) {
			return c.createArrayLiteralType(c.createTupleTypeEx(elementTypes, elementInfos,
				inConstContext && !(contextualType != null && Checker.someType(contextualType, c.isMutableArrayLikeType)) /*readonly*/));
		}
		var elementType:Type = null;
		if (elementTypes.length != 0) {
			for (i in 0...elementTypes.length) {
				final e = elementTypes[i];
				if (elementInfos[i].flags & ElementFlagsVariadic != 0) {
					elementTypes[i] = Core.OrElse(c.getIndexedAccessTypeOrUndefined(e, c.numberType, AccessFlagsNone, null, null), c.anyType);
				}
			}
			elementType = c.getUnionTypeEx(elementTypes, UnionReductionSubtype, null, null);
		} else {
			elementType = Core.IfElse(c.strictNullChecks, c.implicitNeverType, c.undefinedWideningType);
		}
		return c.createArrayLiteralType(c.createArrayTypeEx(elementType, inConstContext));
	}

	static function createArrayLiteralType(c:Checker, t:Type):Type {
		if (t.objectFlags & ObjectFlagsReference == 0) {
			return t;
		}
		final key = CachedTypeKey.keyOf(CachedTypeKindArrayLiteralType, t.id);
		if (c.cachedTypes.exists(key)) {
			return c.cachedTypes.get(key);
		}
		final literalType = c.cloneTypeReference(t);
		literalType.objectFlags |= ObjectFlagsArrayLiteral | ObjectFlagsContainsObjectOrArrayLiteral;
		c.cachedTypes.set(key, literalType);
		return literalType;
	}

	static function checkQualifiedName(c:Checker, node:Node, checkMode:CheckMode):Type {
		final left = node.AsQualifiedName().Left;
		var leftType:Type = null;
		if (Ast.IsPartOfTypeQuery(node) && Ast.IsThisIdentifier(left)) {
			leftType = c.checkNonNullType(c.checkThisExpression(left), left);
		} else {
			leftType = c.checkNonNullExpression(left);
		}
		return c.checkPropertyAccessExpressionOrQualifiedName(node, left, leftType, node.AsQualifiedName().Right, checkMode, false);
	}

	static function checkIndexedAccess(c:Checker, node:Node, checkMode:CheckMode):Type {
		if (node.Flags & NodeFlagsOptionalChain != 0) {
			return c.checkElementAccessChain(node, checkMode);
		}
		return c.checkElementAccessExpression(node, c.checkNonNullExpression(node.Expression()), checkMode);
	}

	static function checkElementAccessChain(c:Checker, node:Node, checkMode:CheckMode):Type {
		final exprType = c.checkExpression(node.Expression());
		final nonOptionalType = c.getOptionalExpressionType(exprType, node.Expression());
		return c.propagateOptionalTypeMarker(c.checkElementAccessExpression(node, c.checkNonNullType(nonOptionalType, node.Expression()), checkMode), node,
			nonOptionalType != exprType);
	}

	static function checkElementAccessExpression(c:Checker, node:Node, exprType:Type, checkMode:CheckMode):Type {
		var objectType = exprType;
		if (Checker.getAssignmentTargetKind(node) != AssignmentKindNone || c.isMethodAccessForCall(node)) {
			objectType = c.getWidenedType(objectType);
		}
		final indexExpression = node.AsElementAccessExpression().ArgumentExpression;
		final indexType = c.checkExpression(indexExpression);
		if (c.isErrorType(objectType) || objectType == c.silentNeverType) {
			return objectType;
		}
		if (Checker.isConstEnumObjectType(objectType) && !Ast.IsStringLiteralLike(indexExpression)) {
			c.error(indexExpression, Diagnostics.A_const_enum_member_can_only_be_accessed_using_a_string_literal);
			return c.errorType;
		}
		var effectiveIndexType = indexType;
		if (c.isForInVariableForNumericPropertyNames(indexExpression)) {
			effectiveIndexType = c.numberType;
		}
		final assignmentTargetKind = Checker.getAssignmentTargetKind(node);
		var accessFlags:AccessFlags = 0;
		if (assignmentTargetKind == AssignmentKindNone) {
			accessFlags = AccessFlagsExpressionPosition;
		} else {
			accessFlags = AccessFlagsWriting
				| Core.IfElse(assignmentTargetKind == AssignmentKindCompound, AccessFlagsExpressionPosition, (0 : AccessFlags))
				| Core.IfElse(c.isGenericObjectType(objectType) && !Checker.isThisTypeParameter(objectType), AccessFlagsNoIndexSignatures, (0 : AccessFlags));
		}
		final indexedAccessType = Core.OrElse(c.getIndexedAccessTypeOrUndefined(objectType, effectiveIndexType, accessFlags, node, null), c.errorType);
		return c.checkIndexedAccessIndexType(c.getFlowTypeOfAccessExpression(node, c.getResolvedSymbolOrNil(node), indexedAccessType, indexExpression,
			checkMode), node);
	}

	// Return true if given node is an expression consisting of an identifier (possibly parenthesized)
	// that references a for-in variable for an object with numeric property names.
	static function isForInVariableForNumericPropertyNames(c:Checker, expr:Node):Bool {
		final e = Ast.SkipParentheses(expr);
		if (Ast.IsIdentifier(e)) {
			final symbol = c.getResolvedSymbol(e);
			if (symbol.Flags & SymbolFlagsVariable != 0) {
				var child = expr;
				var node = expr.Parent;
				while (node != null) {
					if (Ast.IsForInStatement(node) && child == node.AsForInOrOfStatement().Statement && c.getForInVariableSymbol(node) == symbol
						&& c.hasNumericPropertyNames(c.getTypeOfExpression(node.Expression()))) {
						return true;
					}
					child = node;
					node = node.Parent;
				}
			}
		}
		return false;
	}

	// Return the symbol of the for-in variable declared or referenced by the given for-in statement.
	static function getForInVariableSymbol(c:Checker, node:Node):Symbol {
		final initializer = node.Initializer();
		if (Ast.IsVariableDeclarationList(initializer)) {
			final declarations = initializer.AsVariableDeclarationList().Declarations.Nodes;
			if (Core.len(declarations) > 0) {
				final variable = declarations[0];
				if (variable != null && !Ast.IsBindingPattern(variable.Name())) {
					return c.getSymbolOfDeclaration(variable);
				}
			}
		} else if (Ast.IsIdentifier(initializer)) {
			return c.getResolvedSymbol(initializer);
		}
		return null;
	}

	// Return true if the given type is considered to have numeric property names.
	static function hasNumericPropertyNames(c:Checker, t:Type):Bool {
		return Core.len(c.getIndexInfosOfType(t)) == 1 && c.getIndexInfoOfType(t, c.numberType) != null;
	}

	static function checkIndexedAccessIndexType(c:Checker, t:Type, accessNode:Node):Type {
		if (t.flags & TypeFlagsIndexedAccess == 0) {
			return t;
		}
		// Check if the index type is assignable to 'keyof T' for the object type.
		final objectType = t.AsIndexedAccessType().objectType;
		final indexType = t.AsIndexedAccessType().indexType;
		// skip index type deferral on remapping mapped types
		var objectIndexType:Type = null;
		if (c.isGenericMappedType(objectType) && c.getMappedTypeNameTypeKind(objectType) == MappedTypeNameTypeKindRemapping) {
			objectIndexType = c.getIndexTypeForMappedType(objectType, IndexFlagsNone);
		} else {
			objectIndexType = c.getIndexTypeEx(objectType, IndexFlagsNone);
		}
		final hasNumberIndexInfo = c.getIndexInfoOfType(objectType, c.numberType) != null;
		if (Checker.everyType(indexType, (t:Type) -> {
			return c.isTypeAssignableTo(t, objectIndexType) || hasNumberIndexInfo && c.isApplicableIndexType(t, c.numberType);
		})) {
			if (accessNode.Kind == KindElementAccessExpression && Ast.IsAssignmentTarget(accessNode) && objectType.objectFlags & ObjectFlagsMapped != 0
				&& Checker.getMappedTypeModifiers(objectType) & MappedTypeModifiersIncludeReadonly != 0) {
				c.error(accessNode, Diagnostics.Index_signature_in_type_0_only_permits_reading, c.TypeToString(objectType));
			}
			return t;
		}
		if (c.isGenericObjectType(objectType)) {
			final propertyName = c.getPropertyNameFromIndex(indexType, accessNode);
			if (propertyName != Ast.InternalSymbolNameMissing) {
				final propertySymbol = c.getConstituentProperty(objectType, propertyName);
				if (propertySymbol != null && Checker.getDeclarationModifierFlagsFromSymbol(propertySymbol) & ModifierFlagsNonPublicAccessibilityModifier != 0) {
					c.error(accessNode, Diagnostics.Private_or_protected_member_0_cannot_be_accessed_on_a_type_parameter, propertyName);
					return c.errorType;
				}
			}
		}
		c.error(accessNode, Diagnostics.Type_0_cannot_be_used_to_index_type_1, c.TypeToString(indexType), c.TypeToString(objectType));
		return c.errorType;
	}

	static function getConstituentProperty(c:Checker, objectType:Type, propertyName:std.String):Symbol {
		for (t in c.getApparentType(objectType).Distributed()) {
			final prop = c.getPropertyOfType(t, propertyName);
			if (prop != null) {
				return prop;
			}
		}
		return null;
	}

	static function checkImportCallExpression(c:Checker, node:Node):Type {
		// Check grammar of dynamic import
		c.checkGrammarImportCallExpression(node);
		final args = node.Arguments();
		if (Core.len(args) == 0) {
			return c.createPromiseReturnType(node, c.anyType);
		}
		final specifier = args[0];
		final specifierType = c.checkExpressionCached(specifier);
		var optionsType:Type = null;
		if (args.length > 1) {
			optionsType = c.checkExpressionCached(args[1]);
		}
		// Even though multiple arguments is grammatically incorrect, type-check extra arguments for completion
		for (i in 2...args.length) {
			c.checkExpressionCached(args[i]);
		}
		if (specifierType.flags & TypeFlagsNullable != 0 || !c.isTypeAssignableTo(specifierType, c.stringType)) {
			c.error(specifier, Diagnostics.Dynamic_import_s_specifier_must_be_of_type_string_but_here_has_type_0, c.TypeToString(specifierType));
		}
		if (optionsType != null) {
			final importCallOptionsType = c.getGlobalImportCallOptionsTypeChecked();
			if (importCallOptionsType != c.emptyObjectType) {
				c.checkTypeAssignableTo(optionsType, c.getNullableType(importCallOptionsType, TypeFlagsUndefined), args[1], null);
			}
			if (Ast.IsObjectLiteralExpression(args[1])) {
				for (prop in args[1].AsObjectLiteralExpression().Properties.Nodes) {
					if (Ast.IsPropertyAssignment(prop) && Ast.IsIdentifier(prop.Name()) && prop.Name().Text() == "assert") {
						c.error(prop.Name(), Diagnostics.Import_assertions_have_been_replaced_by_import_attributes_Use_with_instead_of_assert);
						break;
					}
				}
			}
		}
		// resolveExternalModuleName will return undefined if the moduleReferenceExpression is not a string literal
		final moduleSymbol = c.resolveExternalModuleName(node, specifier, false /*ignoreErrors*/);
		if (moduleSymbol != null) {
			final esModuleSymbol = c.resolveExternalModuleSymbol(moduleSymbol, true /*dontResolveAlias*/);
			if (esModuleSymbol != null) {
				var syntheticType = c.getTypeWithSyntheticDefaultOnly(c.getTypeOfSymbol(esModuleSymbol), esModuleSymbol, moduleSymbol, specifier);
				if (syntheticType == null) {
					syntheticType = c.getTypeWithSyntheticDefaultImportType(c.getTypeOfSymbol(esModuleSymbol), esModuleSymbol, moduleSymbol, specifier);
				}
				return c.createPromiseReturnType(node, syntheticType);
			}
		}
		return c.createPromiseReturnType(node, c.anyType);
	}

	/**
	 * Syntactically and semantically checks a call or new expression.
	 * @param node The call/new expression to be checked.
	 * @returns On success, the expression's signature's return type. On failure, anyType.
	 */
	static function checkCallExpression(c:Checker, node:Node, checkMode:CheckMode):Type {
		c.checkGrammarTypeArguments(node, node.TypeArgumentList());
		final signature = c.getResolvedSignature(node, null /*candidatesOutArray*/, checkMode);
		if (signature == c.resolvingSignature) {
			// CheckMode.SkipGenericFunctions is enabled and this is a call to a generic function that
			// returns a function type. We defer checking and return silentNeverType.
			return c.silentNeverType;
		}
		c.checkDeprecatedSignature(signature, node);
		if (node.Expression().Kind == KindSuperKeyword) {
			return c.voidType;
		}
		if (Ast.IsNewExpression(node)) {
			final declaration = signature.declaration;
			if (declaration != null && !Ast.IsConstructorDeclaration(declaration) && !Ast.IsConstructSignatureDeclaration(declaration)
				&& !Ast.IsConstructorTypeNode(declaration)) {
				// When resolved signature is a call signature (and not a construct signature) the result type is any
				if (c.noImplicitAny) {
					c.error(node, Diagnostics.X_new_expression_whose_target_lacks_a_construct_signature_implicitly_has_an_any_type);
				}
				return c.anyType;
			}
		}
		if (Ast.IsInJSFile(node) && c.isCommonJSRequire(node)) {
			return c.resolveExternalModuleTypeByLiteral(node.Arguments()[0]);
		}
		final returnType = c.getReturnTypeOfSignature(signature);
		// Treat any call to the global 'Symbol' function that is part of a const variable or readonly property
		// as a fresh unique symbol literal type.
		if (returnType.flags & TypeFlagsESSymbolLike != 0 && c.isSymbolOrSymbolForCall(node)) {
			return c.getESSymbolLikeTypeForNode(Ast.WalkUpParenthesizedExpressions(node.Parent));
		}
		if (Ast.IsCallExpression(node) && node.QuestionDotToken() == null && Ast.IsExpressionStatement(node.Parent)
			&& returnType.flags & TypeFlagsVoid != 0 && c.getTypePredicateOfSignature(signature) != null) {
			if (!Ast.IsDottedName(node.Expression())) {
				c.error(node.Expression(), Diagnostics.Assertions_require_the_call_target_to_be_an_identifier_or_qualified_name);
			} else if (c.getEffectsSignature(node) == null) {
				final diagnostic = c.error(node.Expression(),
					Diagnostics.Assertions_require_every_name_in_the_call_target_to_be_declared_with_an_explicit_type_annotation);
				c.getTypeOfDottedName(node.Expression(), diagnostic);
			}
		}
		return returnType;
	}

	static function checkDeprecatedSignature(c:Checker, sig:Signature, node:Node):Void {
		if (sig.flags & SignatureFlagsIsSignatureCandidateForOverloadFailure != 0) {
			return;
		}
		if (sig.declaration != null && c.IsDeprecatedDeclaration(sig.declaration)) {
			final suggestionNode = c.getDeprecatedSuggestionNode(node);
			final name = Checker.tryGetPropertyAccessOrIdentifierToString(Ast.GetInvokedExpression(node));
			c.addDeprecatedSuggestionWithSignature(suggestionNode, sig.declaration, name, c.signatureToString(sig));
		}
	}

	static function addDeprecatedSuggestionWithSignature(c:Checker, location:Node, declaration:Node, deprecatedEntity:std.String, signatureString:std.String):Diagnostic {
		final message = Core.IfElse(deprecatedEntity != "", Diagnostics.The_signature_0_of_1_is_deprecated, Diagnostics.X_0_is_deprecated);
		final diagnostic = Checker.NewDiagnosticForNode(location, message, signatureString, deprecatedEntity);
		return c.addDeprecatedSuggestionWorker([declaration], diagnostic);
	}

	static function isSymbolOrSymbolForCall(c:Checker, node:Node):Bool {
		if (!Ast.IsCallExpression(node)) {
			return false;
		}
		var left = node.Expression();
		if (Ast.IsPropertyAccessExpression(left) && left.Name().Text() == "for") {
			left = left.Expression();
		}
		if (!Ast.IsIdentifier(left) || left.Text() != "Symbol") {
			return false;
		}
		// make sure `Symbol` is the global symbol
		final globalESSymbol = c.getGlobalESSymbolConstructorSymbolOrNil();
		if (globalESSymbol == null) {
			return false;
		}
		return globalESSymbol == c.resolveName(left, "Symbol", SymbolFlagsValue, null /*nameNotFoundMessage*/, false /*isUse*/, false);
	}

	/**
	 * Resolve a signature of a given call-like expression.
	 * @param node a call-like expression to try resolve a signature for
	 * @param candidatesOutArray an array of signature to be filled in by the function. It is passed by signature help in the language service;
	 *    the function will fill it up with appropriate candidate signatures
	 * @return a signature of the call-like expression or undefined if one can't be found
	 */
	static function getResolvedSignature(c:Checker, node:Node, candidatesOutArray:Array<Signature>, checkMode:CheckMode):Signature {
		final links = c.signatureLinks.Get(node);
		// If getResolvedSignature has already been called, we will have cached the resolvedSignature.
		// However, it is possible that either candidatesOutArray was not passed in the first time,
		// or that a different candidatesOutArray was passed in. Therefore, we need to redo the work
		// to correctly fill the candidatesOutArray.
		final cached = links.resolvedSignature;
		if (cached != null && cached != c.resolvingSignature && candidatesOutArray == null) {
			return cached;
		}
		final saveResolutionStart = c.resolutionStart;
		if (cached == null) {
			// If we haven't already done so, temporarily reset the resolution stack. This allows us to
			// handle "inverted" situations where, for example, an API client asks for the type of a symbol
			// containined in a function call argument whose contextual type depends on the symbol itself
			// through resolution of the containing function call. By resetting the resolution stack we'll
			// retry the symbol type resolution with the resolvingSignature marker in place to suppress
			// the contextual type circularity.
			c.resolutionStart = Core.len(c.typeResolutions);
		}
		links.resolvedSignature = c.resolvingSignature;
		var result = c.resolveSignature(node, candidatesOutArray, checkMode);
		c.resolutionStart = saveResolutionStart;
		// When CheckMode.SkipGenericFunctions is set we use resolvingSignature to indicate that call
		// resolution should be deferred.
		if (result != c.resolvingSignature) {
			// if the signature resolution originated on a node that itself depends on the contextual type
			// then it's possible that the resolved signature might not be the same as the one that would be computed in source order
			// since resolving such signature leads to resolving the potential outer signature, its arguments and thus the very same signature
			// it's possible that this inner resolution sets the resolvedSignature first.
			// In such a case we ignore the local result and reuse the correct one that was cached.
			if (links.resolvedSignature != c.resolvingSignature) {
				result = links.resolvedSignature;
			}
			// If signature resolution originated in control flow type analysis (for example to compute the
			// assigned type in a flow assignment) we don't cache the result as it may be based on temporary
			// types from the control flow analysis.
			if (Core.len(c.flowLoopStack) == 0) {
				links.resolvedSignature = result;
			} else {
				links.resolvedSignature = cached;
			}
		}
		return result;
	}

	static function resolveSignature(c:Checker, node:Node, candidatesOutArray:Array<Signature>, checkMode:CheckMode):Signature {
		switch (node.Kind) {
			case KindCallExpression:
				return c.resolveCallExpression(node, candidatesOutArray, checkMode);
			case KindNewExpression:
				return c.resolveNewExpression(node, candidatesOutArray, checkMode);
			case KindTaggedTemplateExpression:
				return c.resolveTaggedTemplateExpression(node, candidatesOutArray, checkMode);
			case KindDecorator:
				return c.resolveDecorator(node, candidatesOutArray, checkMode);
			case KindJsxOpeningFragment, KindJsxOpeningElement, KindJsxSelfClosingElement:
				return c.resolveJsxOpeningLikeElement(node, candidatesOutArray, checkMode);
			case KindBinaryExpression:
				return c.resolveInstanceofExpression(node, candidatesOutArray, checkMode);
			default:
		}
		throw "Unhandled case in resolveSignature";
	}

	static function resolveCallExpression(c:Checker, node:Node, candidatesOutArray:Array<Signature>, checkMode:CheckMode):Signature {
		if (node.Expression().Kind == KindSuperKeyword) {
			final superType = c.checkSuperExpression(node.Expression());
			if (Checker.IsTypeAny(superType)) {
				final args = node.Arguments();
				if (args != null) {
					for (arg in args) {
						// Still visit arguments so they get marked for visibility, etc
						c.checkExpression(arg);
					}
				}
				return c.anySignature;
			}
			if (!c.isErrorType(superType)) {
				// In super call, the candidate signatures are the matching arity signatures of the base constructor function instantiated
				// with the type arguments specified in the extends clause.
				final baseTypeNode = Ast.GetExtendsHeritageClauseElement(Ast.GetContainingClass(node));
				if (baseTypeNode != null) {
					final baseConstructors = c.getInstantiatedConstructorsForTypeArguments(superType, baseTypeNode.TypeArguments(), baseTypeNode);
					return c.resolveCall(node, baseConstructors, candidatesOutArray, checkMode, SignatureFlagsNone, null);
				}
			}
			return c.resolveUntypedCall(node);
		}
		if (Ast.IsImportCall(node)) {
			return c.resolveUntypedCall(node);
		}
		var callChainFlags:SignatureFlags = 0;
		var funcType = c.checkExpression(node.Expression());
		if (Checker.isCallChain(node)) {
			final nonOptionalType = c.getOptionalExpressionType(funcType, node.Expression());
			if (nonOptionalType == funcType) {
				callChainFlags = SignatureFlagsNone;
			} else if (Ast.IsOutermostOptionalChain(node)) {
				callChainFlags = SignatureFlagsIsOuterCallChain;
			} else {
				callChainFlags = SignatureFlagsIsInnerCallChain;
			}
			funcType = nonOptionalType;
		} else {
			callChainFlags = SignatureFlagsNone;
		}
		funcType = c.checkNonNullTypeWithReporter(funcType, node.Expression(), reportCannotInvokePossiblyNullOrUndefinedError);
		if (funcType == c.silentNeverType) {
			return c.silentNeverSignature;
		}
		final apparentType = c.getApparentType(funcType);
		if (c.isErrorType(apparentType)) {
			// Another error has already been reported
			return c.resolveErrorCall(node);
		}
		// Technically, this signatures list may be incomplete. We are taking the apparent type,
		// but we are not including call signatures that may have been added to the Object or
		// Function interface, since they have none by default. This is a bit of a leap of faith
		// that the user will not add any.
		final callSignatures = c.getSignaturesOfType(apparentType, SignatureKindCall);
		final numConstructSignatures = Core.len(c.getSignaturesOfType(apparentType, SignatureKindConstruct));
		// TS 1.0 Spec: 4.12
		// In an untyped function call no TypeArgs are permitted, Args can be any argument list, no contextual
		// types are provided for the argument expressions, and the result is always of type Any.
		if (c.isUntypedFunctionCall(funcType, apparentType, Core.len(callSignatures), numConstructSignatures)) {
			// The unknownType indicates that an error already occurred (and was reported).  No
			// need to report another error in this case.
			if (!c.isErrorType(funcType) && node.TypeArguments() != null) {
				c.error(node, Diagnostics.Untyped_function_calls_may_not_accept_type_arguments);
			}
			return c.resolveUntypedCall(node);
		}
		// If FuncExpr's apparent type(section 3.8.1) is a function type, the call is a typed function call.
		// TypeScript employs overload resolution in typed function calls in order to support functions
		// with multiple call signatures.
		if (Core.len(callSignatures) == 0) {
			if (numConstructSignatures != 0) {
				c.error(node, Diagnostics.Value_of_type_0_is_not_callable_Did_you_mean_to_include_new, c.TypeToString(funcType));
			} else {
				var relatedInformation:Diagnostic = null;
				if (Core.len(node.Arguments()) == 1) {
					final text = Ast.GetSourceFileOfNode(node).Text();
					final options = new SkipTriviaOptions();
					options.StopAfterLineBreak = true;
					// PORT: byte. Go tests the UTF-8 byte before the position; only ASCII line breaks can match there.
					final ch = StringTools.fastCodeAt(text, Scanner.SkipTriviaEx(text, node.Expression().End(), options) - 1);
					if (ch < 0x80 && Stringutil.IsLineBreak(ch)) {
						relatedInformation = Checker.createDiagnosticForNode(node.Expression(), Diagnostics.Are_you_missing_a_semicolon);
					}
				}
				c.invocationError(node.Expression(), apparentType, SignatureKindCall, relatedInformation);
			}
			return c.resolveErrorCall(node);
		}
		// When a call to a generic function is an argument to an outer call to a generic function for which
		// inference is in process, we have a choice to make. If the inner call relies on inferences made from
		// its contextual type to its return type, deferring the inner call processing allows the best possible
		// contextual type to accumulate. But if the outer call relies on inferences made from the return type of
		// the inner call, the inner call should be processed early. There's no sure way to know which choice is
		// right (only a full unification algorithm can determine that), so we resort to the following heuristic:
		// If no type arguments are specified in the inner call and at least one call signature is generic and
		// returns a function type, we choose to defer processing. This narrowly permits function composition
		// operators to flow inferences through return types, but otherwise processes calls right away. We
		// use the resolvingSignature singleton to indicate that we deferred processing. This result will be
		// propagated out and eventually turned into silentNeverType (a type that is assignable to anything and
		// from which we never make inferences).
		if (checkMode & CheckModeSkipGenericFunctions != 0 && Core.len(node.TypeArguments()) == 0
			&& Core.Some(callSignatures, c.isGenericFunctionReturningFunction)) {
			c.skippedGenericFunction(node, checkMode);
			return c.resolvingSignature;
		}
		return c.resolveCall(node, callSignatures, candidatesOutArray, checkMode, callChainFlags, null);
	}

	static function resolveNewExpression(c:Checker, node:Node, candidatesOutArray:Array<Signature>, checkMode:CheckMode):Signature {
		var expressionType = c.checkNonNullExpression(node.Expression());
		if (expressionType == c.silentNeverType) {
			return c.silentNeverSignature;
		}
		// If expressionType's apparent type(section 3.8.1) is an object type with one or
		// more construct signatures, the expression is processed in the same manner as a
		// function call, but using the construct signatures as the initial set of candidate
		// signatures for overload resolution. The result type of the function call becomes
		// the result type of the operation.
		expressionType = c.getApparentType(expressionType);
		if (c.isErrorType(expressionType)) {
			// Another error has already been reported
			return c.resolveErrorCall(node);
		}
		// TS 1.0 spec: 4.11
		// If expressionType is of type Any, Args can be any argument
		// list and the result of the operation is of type Any.
		if (Checker.IsTypeAny(expressionType)) {
			if (Core.len(node.TypeArguments()) != 0) {
				c.error(node, Diagnostics.Untyped_function_calls_may_not_accept_type_arguments);
			}
			return c.resolveUntypedCall(node);
		}
		// Technically, this signatures list may be incomplete. We are taking the apparent type,
		// but we are not including construct signatures that may have been added to the Object or
		// Function interface, since they have none by default. This is a bit of a leap of faith
		// that the user will not add any.
		final constructSignatures = c.getSignaturesOfType(expressionType, SignatureKindConstruct);
		if (Core.len(constructSignatures) != 0) {
			if (!c.isConstructorAccessible(node, constructSignatures[0])) {
				return c.resolveErrorCall(node);
			}
			// If the expression is a class of abstract type, or an abstract construct signature,
			// then it cannot be instantiated.
			// In the case of a merged class-module or class-interface declaration,
			// only the class declaration node will have the Abstract flag set.
			if (Checker.someSignature(constructSignatures, (sig:Signature) -> {
				return sig.flags & SignatureFlagsAbstract != 0;
			})) {
				c.error(node, Diagnostics.Cannot_create_an_instance_of_an_abstract_class);
				return c.resolveErrorCall(node);
			}
			if (expressionType.symbol != null) {
				final valueDecl = Ast.GetClassLikeDeclarationOfSymbol(expressionType.symbol);
				if (valueDecl != null && Ast.HasModifier(valueDecl, ModifierFlagsAbstract)) {
					c.error(node, Diagnostics.Cannot_create_an_instance_of_an_abstract_class);
					return c.resolveErrorCall(node);
				}
			}
			return c.resolveCall(node, constructSignatures, candidatesOutArray, checkMode, SignatureFlagsNone, null);
		}
		// If expressionType's apparent type is an object type with no construct signatures but
		// one or more call signatures, the expression is processed as a function call. A compile-time
		// error occurs if the result of the function call is not Void. The type of the result of the
		// operation is Any. It is an error to have a Void this type.
		final callSignatures = c.getSignaturesOfType(expressionType, SignatureKindCall);
		if (Core.len(callSignatures) != 0) {
			final signature = c.resolveCall(node, callSignatures, candidatesOutArray, checkMode, SignatureFlagsNone, null);
			if (!c.noImplicitAny) {
				if (signature.declaration != null && c.getReturnTypeOfSignature(signature) != c.voidType) {
					c.error(node, Diagnostics.Only_a_void_function_can_be_called_with_the_new_keyword);
				}
				if (c.getThisTypeOfSignature(signature) == c.voidType) {
					c.error(node, Diagnostics.A_function_that_is_called_with_the_new_keyword_cannot_have_a_this_type_that_is_void);
				}
			}
			return signature;
		}
		c.invocationError(node.Expression(), expressionType, SignatureKindConstruct, null);
		return c.resolveErrorCall(node);
	}

	static function isConstructorAccessible(c:Checker, node:Node, signature:Signature):Bool {
		if (signature == null || signature.declaration == null) {
			return true;
		}
		final declaration = signature.declaration;
		final modifiers = Checker.getSelectedModifierFlags(declaration, ModifierFlagsNonPublicAccessibilityModifier);
		// (1) Public constructors and (2) constructor functions are always accessible.
		if (modifiers == 0 || !Ast.IsConstructorDeclaration(declaration)) {
			return true;
		}
		final declaringClassDeclaration = Ast.GetClassLikeDeclarationOfSymbol(declaration.Parent.Symbol());
		final declaringClass = c.getDeclaredTypeOfSymbol(declaration.Parent.Symbol());
		// A private or protected constructor can only be instantiated within its own class (or a subclass, for protected)
		if (!c.isNodeWithinClass(node, declaringClassDeclaration)) {
			final containingClass = Ast.GetContainingClass(node);
			if (containingClass != null && modifiers & ModifierFlagsProtected != 0) {
				final containingType = c.getDeclaredTypeOfSymbol(containingClass.Symbol());
				if (c.typeHasProtectedAccessibleBase(declaration.Parent.Symbol(), containingType)) {
					return true;
				}
			}
			if (modifiers & ModifierFlagsPrivate != 0) {
				c.error(node, Diagnostics.Constructor_of_class_0_is_private_and_only_accessible_within_the_class_declaration, c.TypeToString(declaringClass));
			}
			if (modifiers & ModifierFlagsProtected != 0) {
				c.error(node, Diagnostics.Constructor_of_class_0_is_protected_and_only_accessible_within_the_class_declaration, c.TypeToString(declaringClass));
			}
			return false;
		}
		return true;
	}

	static function typeHasProtectedAccessibleBase(c:Checker, target:Symbol, t:Type):Bool {
		final baseTypes = c.getBaseTypes(c.getTargetType(t));
		if (Core.len(baseTypes) == 0) {
			return false;
		}
		final firstBase = baseTypes[0];
		if (firstBase.flags & TypeFlagsIntersection != 0) {
			final types = firstBase.AsIntersectionType().types;
			final mixinFlags = c.findMixins(types).a;
			final members = firstBase.Types();
			for (i in 0...members.length) {
				final intersectionMember = members[i];
				// We want to ignore mixin ctors
				if (!mixinFlags[i]) {
					if (intersectionMember.objectFlags & (ObjectFlagsClass | ObjectFlagsInterface) != 0) {
						if (intersectionMember.symbol == target) {
							return true;
						}
						if (c.typeHasProtectedAccessibleBase(target, intersectionMember)) {
							return true;
						}
					}
				}
			}
			return false;
		}
		if (firstBase.symbol == target) {
			return true;
		}
		return c.typeHasProtectedAccessibleBase(target, firstBase);
	}

	static function resolveTaggedTemplateExpression(c:Checker, node:Node, candidatesOutArray:Array<Signature>, checkMode:CheckMode):Signature {
		final tag = node.AsTaggedTemplateExpression().Tag;
		final tagType = c.checkExpression(tag);
		final apparentType = c.getApparentType(tagType);
		if (c.isErrorType(apparentType)) {
			// Another error has already been reported
			return c.resolveErrorCall(node);
		}
		final callSignatures = c.getSignaturesOfType(apparentType, SignatureKindCall);
		final numConstructSignatures = Core.len(c.getSignaturesOfType(apparentType, SignatureKindConstruct));
		if (c.isUntypedFunctionCall(tagType, apparentType, Core.len(callSignatures), numConstructSignatures)) {
			return c.resolveUntypedCall(node);
		}
		if (Core.len(callSignatures) == 0) {
			if (Ast.IsArrayLiteralExpression(node.Parent)) {
				c.error(tag,
					Diagnostics.It_is_likely_that_you_are_missing_a_comma_to_separate_these_two_template_expressions_They_form_a_tagged_template_expression_which_cannot_be_invoked);
				return c.resolveErrorCall(node);
			}
			c.invocationError(tag, apparentType, SignatureKindCall, null);
			return c.resolveErrorCall(node);
		}
		return c.resolveCall(node, callSignatures, candidatesOutArray, checkMode, SignatureFlagsNone, null);
	}

	static function resolveDecorator(c:Checker, node:Node, candidatesOutArray:Array<Signature>, checkMode:CheckMode):Signature {
		if (!Ast.CanHaveDecorators(node.Parent)) {
			return c.resolveErrorCall(node);
		}
		final funcType = c.checkExpression(node.Expression());
		final apparentType = c.getApparentType(funcType);
		if (c.isErrorType(apparentType)) {
			return c.resolveErrorCall(node);
		}
		final callSignatures = c.getSignaturesOfType(apparentType, SignatureKindCall);
		final numConstructSignatures = Core.len(c.getSignaturesOfType(apparentType, SignatureKindConstruct));
		if (c.isUntypedFunctionCall(funcType, apparentType, Core.len(callSignatures), numConstructSignatures)) {
			return c.resolveUntypedCall(node);
		}
		if (c.isPotentiallyUncalledDecorator(node, callSignatures) && !Ast.IsParenthesizedExpression(node.Expression())) {
			final nodeStr = Scanner.GetTextOfNode(node.Expression());
			c.error(node, Diagnostics.X_0_accepts_too_few_arguments_to_be_used_as_a_decorator_here_Did_you_mean_to_call_it_first_and_write_0, nodeStr);
			return c.resolveErrorCall(node);
		}
		final headMessage = c.getDiagnosticHeadMessageForDecoratorResolution(node);
		if (Core.len(callSignatures) == 0) {
			final diag = Ast.NewDiagnosticChain(c.invocationErrorDetails(node.Expression(), apparentType, SignatureKindCall), headMessage);
			c.addDiagnostic(diag);
			c.invocationErrorRecovery(apparentType, SignatureKindCall, diag);
			return c.resolveErrorCall(node);
		}
		final decoratorSignature = c.getDecoratorCallSignature(node);
		if (decoratorSignature == null) {
			return c.resolveErrorCall(node);
		}
		return c.resolveCall(node, callSignatures, candidatesOutArray, checkMode, SignatureFlagsNone, headMessage);
	}

	// Sometimes, we have a decorator that could accept zero arguments,
	// but is receiving too many arguments as part of the decorator invocation.
	// In those cases, a user may have meant to *call* the expression before using it as a decorator.
	static function isPotentiallyUncalledDecorator(c:Checker, decorator:Node, signatures:Array<Signature>):Bool {
		return Core.len(signatures) != 0 && Core.Every(signatures, (sig:Signature) -> {
			return sig.minArgumentCount == 0 && !Checker.signatureHasRestParameter(sig)
				&& Core.len(sig.parameters) < c.getDecoratorArgumentCount(decorator, sig);
		});
	}

	// Gets the localized diagnostic head message to use for errors when resolving a decorator as a call expression.
	static function getDiagnosticHeadMessageForDecoratorResolution(c:Checker, node:Node):Message {
		switch (node.Parent.Kind) {
			case KindClassDeclaration, KindClassExpression:
				return Diagnostics.Unable_to_resolve_signature_of_class_decorator_when_called_as_an_expression;
			case KindParameter:
				return Diagnostics.Unable_to_resolve_signature_of_parameter_decorator_when_called_as_an_expression;
			case KindPropertyDeclaration:
				return Diagnostics.Unable_to_resolve_signature_of_property_decorator_when_called_as_an_expression;
			case KindMethodDeclaration, KindGetAccessor, KindSetAccessor:
				return Diagnostics.Unable_to_resolve_signature_of_method_decorator_when_called_as_an_expression;
			default:
		}
		throw "Unhandled case in getDiagnosticHeadMessageForDecoratorResolution";
	}

	static function resolveInstanceofExpression(c:Checker, node:Node, candidatesOutArray:Array<Signature>, checkMode:CheckMode):Signature {
		// if rightType is an object type with a custom `[Symbol.hasInstance]` method, then it is potentially
		// valid on the right-hand side of the `instanceof` operator. This allows normal `object` types to
		// participate in `instanceof`, as per Step 2 of https://tc39.es/ecma262/#sec-instanceofoperator.
		final right = node.AsBinaryExpression().Right;
		final rightType = c.checkExpression(right);
		if (!Checker.IsTypeAny(rightType)) {
			final hasInstanceMethodType = c.getSymbolHasInstanceMethodOfObjectType(rightType);
			if (hasInstanceMethodType != null) {
				final apparentType = c.getApparentType(hasInstanceMethodType);
				if (c.isErrorType(apparentType)) {
					return c.resolveErrorCall(node);
				}
				final callSignatures = c.getSignaturesOfType(apparentType, SignatureKindCall);
				final constructSignatures = c.getSignaturesOfType(apparentType, SignatureKindConstruct);
				if (c.isUntypedFunctionCall(hasInstanceMethodType, apparentType, Core.len(callSignatures), Core.len(constructSignatures))) {
					return c.resolveUntypedCall(node);
				}
				if (Core.len(callSignatures) != 0) {
					return c.resolveCall(node, callSignatures, candidatesOutArray, checkMode, SignatureFlagsNone, null);
				}
			} else if (!(c.typeHasCallOrConstructSignatures(rightType) || c.isTypeSubtypeOf(rightType, c.globalFunctionType))) {
				c.error(right,
					Diagnostics.The_right_hand_side_of_an_instanceof_expression_must_be_either_of_type_any_a_class_function_or_other_type_assignable_to_the_Function_interface_type_or_an_object_type_with_a_Symbol_hasInstance_method);
				return c.resolveErrorCall(node);
			}
		}
		// fall back to a default signature
		return c.anySignature;
	}

	static function resolveCall(c:Checker, node:Node, signatures:Array<Signature>, candidatesOutArray:Array<Signature>, checkMode:CheckMode, callChainFlags:SignatureFlags, headMessage:Message):Signature {
		final isTaggedTemplate = node.Kind == KindTaggedTemplateExpression;
		final isDecorator = node.Kind == KindDecorator;
		final isJsxOpeningOrSelfClosingElement = Ast.IsJsxOpeningLikeElement(node);
		final isInstanceof = node.Kind == KindBinaryExpression;
		final reportErrors = !c.isInferencePartiallyBlocked && candidatesOutArray == null;
		final s = new CallState();
		s.node = node;
		if (!isDecorator && !isInstanceof && !Checker.isSuperCall(node) && !Ast.IsJsxOpeningFragment(node)) {
			s.typeArguments = node.TypeArguments();
			// We already perform checking on the type arguments on the class declaration itself.
			if (isTaggedTemplate || isJsxOpeningOrSelfClosingElement || node.Expression().Kind != KindSuperKeyword) {
				c.checkSourceElements(s.typeArguments);
			}
		}
		s.candidates = c.reorderCandidates(signatures, callChainFlags);
		if (candidatesOutArray != null) {
			// PORT: pointer. Go `*candidatesOutArray = s.candidates` shares the slice; here the caller's array gets
			// the contents now and is refreshed below where Go writes into s.candidates.
			candidatesOutArray.resize(0);
			for (sig in s.candidates) {
				candidatesOutArray.push(sig);
			}
		}

		if (Core.len(s.candidates) == 0) {
			// In Strada we would error here, but no known repro doesn't have at least
			// one other error in this codepath. Just return instead. See #54442
			return c.unknownSignature;
		}

		s.args = c.getEffectiveCallArguments(node);
		// The excludeArgument array contains true for each context sensitive argument (an argument
		// is context sensitive it is susceptible to a one-time permanent contextual typing).
		//
		// The idea is that we will perform type argument inference & assignability checking once
		// without using the susceptible parameters that are functions, and once more for those
		// parameters, contextually typing each as we go along.
		//
		// For a tagged template, then the first argument be 'undefined' if necessary because it
		// represents a TemplateStringsArray.
		//
		// For a decorator, no arguments are susceptible to contextual typing due to the fact
		// decorators are applied to a declaration by the emitter, and not to an expression.
		s.isSingleNonGenericCandidate = s.candidates.length == 1 && Core.len(s.candidates[0].typeParameters) == 0;
		if (!isDecorator && !s.isSingleNonGenericCandidate && Core.Some(s.args, c.isContextSensitive)) {
			s.argCheckMode = CheckModeSkipContextSensitive;
		} else {
			s.argCheckMode = CheckModeNormal;
		}
		// The following variables are captured and modified by calls to chooseOverload.
		// If overload resolution or type argument inference fails, we want to report the
		// best error possible. The best error is one which says that an argument was not
		// assignable to a parameter. This implies that everything else about the overload
		// was fine. So if there is any overload that is only incorrect because of an
		// argument, we will report an error on that one.
		//
		//     function foo(s: string): void;
		//     function foo(n: number): void; // Report argument error on this overload
		//     function foo(): void;
		//     foo(true);
		//
		// If none of the overloads even made it that far, there are two possibilities.
		// There was a problem with type arguments for some overload, in which case
		// report an error on that. Or none of the overloads even had correct arity,
		// in which case give an arity error.
		//
		//     function foo<T extends string>(x: T): void; // Report type argument error
		//     function foo(): void;
		//     foo<number>(0);
		//
		// If we are in signature help, a trailing comma indicates that we intend to provide another argument,
		// so we will only accept overloads with arity at least 1 higher than the current number of provided arguments.
		s.signatureHelpTrailingComma = checkMode & CheckModeIsForSignatureHelp != 0 && Ast.IsCallExpression(node) && node.ArgumentList().HasTrailingComma();
		// Section 4.12.1:
		// if the candidate list contains one or more signatures for which the type of each argument
		// expression is a subtype of each corresponding parameter type, the return type of the first
		// of those signatures becomes the return type of the function call.
		// Otherwise, the return type of the first signature in the candidate list becomes the return
		// type of the function call.
		//
		// Whether the call is an error is determined by assignability of the arguments. The subtype pass
		// is just important for choosing the best signature. So in the case where there is only one
		// signature, the subtype pass is useless. So skipping it is an optimization.
		var result:Signature = null;
		if (s.candidates.length > 1) {
			result = c.chooseOverload(s, c.subtypeRelation);
		}
		if (result == null) {
			result = c.chooseOverload(s, c.assignableRelation);
		}
		if (candidatesOutArray != null) {
			// PORT: pointer. chooseOverload may have replaced an element of s.candidates (visible through the shared Go slice).
			for (i in 0...s.candidates.length) {
				candidatesOutArray[i] = s.candidates[i];
			}
		}
		if (result != null) {
			return result;
		}
		result = c.getCandidateForOverloadFailure(s.node, s.candidates, s.args, candidatesOutArray != null, checkMode);
		if (candidatesOutArray != null) {
			// PORT: pointer. pickLongestCandidateSignature may have replaced an element of s.candidates.
			for (i in 0...s.candidates.length) {
				candidatesOutArray[i] = s.candidates[i];
			}
		}
		// Preemptively cache the result; getResolvedSignature will do this after we return, but
		// we need to ensure that the result is present for the error checks below so that if
		// this signature is encountered again, we handle the circularity (rather than producing a
		// different result which may produce no errors and assert). Callers of getResolvedSignature
		// don't hit this issue because they only observe this result after it's had a chance to
		// be cached, but the error reporting code below executes before getResolvedSignature sets
		// resolvedSignature.
		c.signatureLinks.Get(node).resolvedSignature = result;
		// No signatures were applicable. Now report errors based on the last applicable signature with
		// no arguments excluded from assignability checks.
		// If candidate is undefined, it means that no candidates had a suitable arity. In that case,
		// skip the checkApplicableSignature check.
		if (reportErrors) {
			// If the call expression is a synthetic call to a `[Symbol.hasInstance]` method then we will produce a head
			// message when reporting diagnostics that explains how we got to `right[Symbol.hasInstance](left)` from
			// `left instanceof right`, as it pertains to "Argument" related messages reported for the call.
			if (headMessage == null && isInstanceof) {
				headMessage = Diagnostics.The_left_hand_side_of_an_instanceof_expression_must_be_assignable_to_the_first_argument_of_the_right_hand_side_s_Symbol_hasInstance_method;
			}
			c.reportCallResolutionErrors(node, s, signatures, headMessage);
		}
		return result;
	}

	static function reorderCandidates(c:Checker, signatures:Array<Signature>, callChainFlags:SignatureFlags):Array<Signature> {
		var lastParent:Node = null;
		var lastSymbol:Symbol = null;
		var index = 0;
		var cutoffIndex = 0;
		var spliceIndex = 0;
		var specializedIndex = -1;
		final result:Array<Signature> = [];
		if (signatures != null) {
			for (sig in signatures) {
				var signature = sig;
				var symbol:Symbol = null;
				var parent:Node = null;
				if (signature.declaration != null) {
					symbol = c.getSymbolOfDeclaration(signature.declaration);
					parent = signature.declaration.Parent;
				}
				if (lastSymbol == null || symbol == lastSymbol) {
					if (lastParent != null && parent == lastParent) {
						index = index + 1;
					} else {
						lastParent = parent;
						index = cutoffIndex;
					}
				} else {
					// current declaration belongs to a different symbol
					// set cutoffIndex so re-orderings in the future won't change result set from 0 to cutoffIndex
					index = result.length;
					cutoffIndex = result.length;
					lastParent = parent;
				}
				lastSymbol = symbol;
				// specialized signatures always need to be placed before non-specialized signatures regardless
				// of the cutoff position; see GH#1133
				if (Checker.signatureHasLiteralTypes(signature)) {
					specializedIndex++;
					spliceIndex = specializedIndex;
					// The cutoff index always needs to be greater than or equal to the specialized signature index
					// in order to prevent non-specialized signatures from being added before a specialized
					// signature.
					cutoffIndex++;
				} else {
					spliceIndex = index;
				}
				if (callChainFlags != 0) {
					signature = c.getOptionalCallSignature(signature, callChainFlags);
				}
				result.insert(spliceIndex, signature);
			}
		}
		return result;
	}

	static function getOptionalCallSignature(c:Checker, signature:Signature, callChainFlags:SignatureFlags):Signature {
		if (signature.flags & SignatureFlagsCallChainFlags == callChainFlags) {
			return signature;
		}
		final key = CachedSignatureKey.keyOf(signature,
			Core.IfElse(callChainFlags == SignatureFlagsIsInnerCallChain, Checker.SignatureKeyInner, Checker.SignatureKeyOuter));
		final cached = c.cachedSignatures.get(key);
		if (cached != null) {
			return cached;
		}
		final result = c.cloneSignature(signature);
		result.flags |= callChainFlags;
		c.cachedSignatures.set(key, result);
		return result;
	}

	static function chooseOverload(c:Checker, s:CallState, relation:Relation):Signature {
		s.candidatesForArgumentError = null;
		s.candidateForArgumentArityError = null;
		s.candidateForTypeArgumentError = null;
		if (s.isSingleNonGenericCandidate) {
			final candidate = s.candidates[0];
			if (Core.len(s.typeArguments) != 0 || !c.hasCorrectArity(s.node, s.args, candidate, s.signatureHelpTrailingComma)) {
				return null;
			}
			if (!c.isSignatureApplicable(s.node, s.args, candidate, relation, CheckModeNormal, false /*reportErrors*/, null /*diagnosticOutput*/)) {
				s.candidatesForArgumentError = [candidate];
				return null;
			}
			return candidate;
		}
		for (candidateIndex in 0...s.candidates.length) {
			final candidate = s.candidates[candidateIndex];
			if (!c.hasCorrectTypeArgumentArity(candidate, s.typeArguments) || !c.hasCorrectArity(s.node, s.args, candidate, s.signatureHelpTrailingComma)) {
				continue;
			}
			var checkCandidate:Signature = null;
			var inferenceContext:InferenceContext = null;
			if (Core.len(candidate.typeParameters) != 0) {
				var typeArgumentTypes:Array<Type> = null;
				if (Core.len(s.typeArguments) != 0) {
					typeArgumentTypes = c.checkTypeArguments(candidate, s.typeArguments, false /*reportErrors*/, null);
					if (typeArgumentTypes == null) {
						s.candidateForTypeArgumentError = candidate;
						continue;
					}
				} else {
					inferenceContext = c.newInferenceContext(candidate.typeParameters, candidate,
						Core.IfElse(Ast.IsInJSFile(s.node), InferenceFlagsAnyDefault, InferenceFlagsNone) /*flags*/, null);
					typeArgumentTypes = c.inferTypeArguments(s.node, candidate, s.args, s.argCheckMode | CheckModeSkipGenericFunctions, inferenceContext);
					if (inferenceContext.flags & InferenceFlagsSkippedGenericFunction != 0) {
						s.argCheckMode |= CheckModeSkipGenericFunctions;
					}
				}
				var inferredTypeParameters:Array<Type> = null;
				if (inferenceContext != null) {
					inferredTypeParameters = inferenceContext.inferredTypeParameters;
				}
				checkCandidate = c.getSignatureInstantiation(candidate, typeArgumentTypes, Ast.IsInJSFile(candidate.declaration), inferredTypeParameters);
				// If the original signature has a generic rest type, instantiation may produce a
				// signature with different arity and we need to perform another arity check.
				if (c.getNonArrayRestType(candidate) != null && !c.hasCorrectArity(s.node, s.args, checkCandidate, s.signatureHelpTrailingComma)) {
					s.candidateForArgumentArityError = checkCandidate;
					continue;
				}
			} else {
				checkCandidate = candidate;
			}
			if (!c.isSignatureApplicable(s.node, s.args, checkCandidate, relation, s.argCheckMode, false /*reportErrors*/, null /*diagnosticOutput*/)) {
				// Give preference to error candidates that have no rest parameters (as they are more specific)
				if (s.candidatesForArgumentError == null) {
					s.candidatesForArgumentError = [];
				}
				s.candidatesForArgumentError.push(checkCandidate);
				continue;
			}
			if (s.argCheckMode != 0) {
				// If one or more context sensitive arguments were excluded, we start including
				// them now (and keeping do so for any subsequent candidates) and perform a second
				// round of type inference and applicability checking for this particular candidate.
				s.argCheckMode = CheckModeNormal;
				if (inferenceContext != null) {
					final typeArgumentTypes = c.inferTypeArguments(s.node, candidate, s.args, s.argCheckMode, inferenceContext);
					checkCandidate = c.getSignatureInstantiation(candidate, typeArgumentTypes, Ast.IsInJSFile(candidate.declaration),
						inferenceContext.inferredTypeParameters);
					// If the original signature has a generic rest type, instantiation may produce a
					// signature with different arity and we need to perform another arity check.
					if (c.getNonArrayRestType(candidate) != null && !c.hasCorrectArity(s.node, s.args, checkCandidate, s.signatureHelpTrailingComma)) {
						s.candidateForArgumentArityError = checkCandidate;
						continue;
					}
				}
				if (!c.isSignatureApplicable(s.node, s.args, checkCandidate, relation, s.argCheckMode, false /*reportErrors*/, null /*diagnosticOutput*/)) {
					// Give preference to error candidates that have no rest parameters (as they are more specific)
					if (s.candidatesForArgumentError == null) {
						s.candidatesForArgumentError = [];
					}
					s.candidatesForArgumentError.push(checkCandidate);
					continue;
				}
			}
			s.candidates[candidateIndex] = checkCandidate;
			return checkCandidate;
		}
		return null;
	}

	static function hasCorrectArity(c:Checker, node:Node, args:Array<Node>, signature:Signature, signatureHelpTrailingComma:Bool):Bool {
		if (Ast.IsJsxOpeningFragment(node)) {
			return true;
		}
		var argCount = 0;
		var callIsIncomplete = false;
		// In incomplete call we want to be lenient when we have too few arguments
		var effectiveParameterCount = c.getParameterCount(signature);
		var effectiveMinimumArguments = c.getMinArgumentCount(signature);
		if (Ast.IsTaggedTemplateExpression(node)) {
			argCount = Core.len(args);
			final template = node.AsTaggedTemplateExpression().Template;
			if (Ast.IsTemplateExpression(template)) {
				// If a tagged template expression lacks a tail literal, the call is incomplete.
				// Specifically, a template only can end in a TemplateTail or a Missing literal.
				final lastSpan = Core.LastOrNil(template.AsTemplateExpression().TemplateSpans.Nodes);
				// we should always have at least one span.
				callIsIncomplete = Ast.NodeIsMissing(lastSpan.AsTemplateSpan().Literal) || Ast.IsUnterminatedLiteral(lastSpan.AsTemplateSpan().Literal);
			} else {
				// If the template didn't end in a backtick, or its beginning occurred right prior to EOF,
				// then this might actually turn out to be a TemplateHead in the future;
				// so we consider the call to be incomplete.
				callIsIncomplete = Ast.IsUnterminatedLiteral(template);
			}
		} else if (Ast.IsDecorator(node)) {
			argCount = c.getDecoratorArgumentCount(node, signature);
		} else if (Ast.IsBinaryExpression(node)) {
			argCount = 1;
		} else if (Ast.IsJsxOpeningLikeElement(node)) {
			callIsIncomplete = node.Attributes().End() == node.End();
			if (callIsIncomplete) {
				return true;
			}
			argCount = Core.IfElse(effectiveMinimumArguments == 0, Core.len(args), 1);
			effectiveParameterCount = Core.IfElse(Core.len(args) == 0, effectiveParameterCount, 1); // class may have argumentless ctor functions - still resolve ctor and compare vs props member type
			effectiveMinimumArguments = imin(effectiveMinimumArguments, 1); // sfc may specify context argument - handled by framework and not typechecked
		} else if (Ast.IsNewExpression(node) && node.ArgumentList() == null) {
			// This only happens when we have something of the form: 'new C'
			return c.getMinArgumentCount(signature) == 0;
		} else {
			if (signatureHelpTrailingComma) {
				argCount = Core.len(args) + 1;
			} else {
				argCount = Core.len(args);
			}
			// If we are missing the close parenthesis, the call is incomplete.
			callIsIncomplete = node.ArgumentList().End() == node.End();
			// If a spread argument is present, check that it corresponds to a rest parameter or at least that it's in the valid range.
			final spreadArgIndex = c.getSpreadArgumentIndex(args);
			if (spreadArgIndex >= 0) {
				return spreadArgIndex >= c.getMinArgumentCount(signature)
					&& (c.hasEffectiveRestParameter(signature) || spreadArgIndex < c.getParameterCount(signature));
			}
		}
		// Too many arguments implies incorrect arity.
		if (!c.hasEffectiveRestParameter(signature) && argCount > effectiveParameterCount) {
			return false;
		}
		// If the call is incomplete, we should skip the lower bound check.
		// JSX signatures can have extra parameters provided by the library which we don't check
		if (callIsIncomplete || argCount >= effectiveMinimumArguments) {
			return true;
		}
		for (i in argCount...effectiveMinimumArguments) {
			final t = c.getTypeAtPosition(signature, i);
			if (c.filterType(t, Checker.acceptsVoid).flags & TypeFlagsNever != 0) {
				return false;
			}
		}
		return true;
	}

	static function getDecoratorArgumentCount(c:Checker, node:Node, signature:Signature):Int {
		if (c.compilerOptions.ExperimentalDecorators.IsTrue()) {
			return c.getLegacyDecoratorArgumentCount(node, signature);
		}
		return imin(imax(c.getParameterCount(signature), 1), 2);
	}

	/**
	 * Returns the argument count for a decorator node that works like a function invocation.
	 */
	static function getLegacyDecoratorArgumentCount(c:Checker, node:Node, signature:Signature):Int {
		switch (node.Parent.Kind) {
			case KindClassDeclaration, KindClassExpression:
				return 1;
			case KindPropertyDeclaration:
				if (Ast.HasAccessorModifier(node.Parent)) {
					return 3;
				}
				return 2;
			case KindMethodDeclaration, KindGetAccessor, KindSetAccessor:
				// For decorators with only two parameters we supply only two arguments
				if (Core.len(signature.parameters) <= 2) {
					return 2;
				}
				return 3;
			case KindParameter:
				return 3;
			default:
		}
		throw "Unhandled case in getLegacyDecoratorArgumentCount";
	}

	static function hasCorrectTypeArgumentArity(c:Checker, signature:Signature, typeArguments:Array<Node>):Bool {
		// If the user supplied type arguments, but the number of type arguments does not match
		// the declared number of type parameters, the call has an incorrect arity.
		final numTypeParameters = Core.len(signature.typeParameters);
		final minTypeArgumentCount = c.getMinTypeArgumentCount(signature.typeParameters);
		return Core.len(typeArguments) == 0 || Core.len(typeArguments) >= minTypeArgumentCount && Core.len(typeArguments) <= numTypeParameters;
	}

	static function checkTypeArguments(c:Checker, signature:Signature, typeArgumentNodes:Array<Node>, reportErrors:Bool, headMessage:Message):Array<Type> {
		final isJavaScript = Ast.IsInJSFile(signature.declaration);
		final typeParameters = signature.typeParameters;
		final typeArgumentTypes = c.fillMissingTypeArguments(Core.Map(typeArgumentNodes, c.getTypeFromTypeNode), typeParameters,
			c.getMinTypeArgumentCount(typeParameters), isJavaScript);
		var mapper:TypeMapper = null;
		for (i in 0...Core.len(typeArgumentNodes)) {
			Debug.Assert(typeParameters[i] != null, "Should not call checkTypeArguments with too many type arguments");
			final constraint = c.getConstraintOfTypeParameter(typeParameters[i]);
			if (constraint != null) {
				final typeArgumentHeadMessage = Core.OrElse(headMessage, Diagnostics.Type_0_does_not_satisfy_the_constraint_1);
				if (mapper == null) {
					mapper = Checker.newTypeMapper(typeParameters, typeArgumentTypes);
				}
				final typeArgument = typeArgumentTypes[i];
				var errorNode:Node = null;
				if (reportErrors) {
					errorNode = typeArgumentNodes[i];
				}
				final diags:Array<Diagnostic> = [];
				if (!c.checkTypeAssignableToEx(typeArgument, c.getTypeWithThisArgument(c.instantiateType(constraint, mapper), typeArgument, false), errorNode,
					typeArgumentHeadMessage, diags)) {
					if (diags.length != 0) {
						var diagnostic = diags[0];
						if (headMessage != null) {
							diagnostic = Ast.NewDiagnosticChain(diagnostic, Diagnostics.Type_0_does_not_satisfy_the_constraint_1);
						}
						c.addDiagnostic(diagnostic);
					}
					return null;
				}
			}
		}
		return typeArgumentTypes;
	}

	static function isSignatureApplicable(c:Checker, node:Node, args:Array<Node>, signature:Signature, relation:Relation, checkMode:CheckMode, reportErrors:Bool, diagnosticOutput:Array<Diagnostic>):Bool {
		if (Ast.IsJsxCallLike(node)) {
			return c.checkApplicableSignatureForJsxCallLikeElement(node, signature, relation, checkMode, reportErrors, diagnosticOutput);
		}
		final thisType = c.getThisTypeOfSignature(signature);
		if (thisType != null && thisType != c.voidType
			&& !(Ast.IsNewExpression(node) || Ast.IsCallExpression(node) && Ast.IsSuperProperty(node.Expression()))) {
			// If the called expression is not of the form `x.f` or `x["f"]`, then sourceType = voidType
			// If the signature's 'this' type is voidType, then the check is skipped -- anything is compatible.
			// If the expression is a new expression or super call expression, then the check is skipped.
			final thisArgumentNode = c.getThisArgumentOfCall(node);
			final thisArgumentType = c.getThisArgumentType(thisArgumentNode);
			var errorNode:Node = null;
			if (reportErrors) {
				errorNode = thisArgumentNode;
				if (errorNode == null) {
					errorNode = node;
				}
			}
			final headMessage = Diagnostics.The_this_context_of_type_0_is_not_assignable_to_method_s_this_of_type_1;
			if (!c.checkTypeRelatedToEx(thisArgumentType, thisType, relation, errorNode, headMessage, diagnosticOutput)) {
				return false;
			}
		}
		final headMessage = Diagnostics.Argument_of_type_0_is_not_assignable_to_parameter_of_type_1;
		final restType = c.getNonArrayRestType(signature);
		var argCount = 0;
		if (restType != null) {
			argCount = imin(c.getParameterCount(signature) - 1, Core.len(args));
		} else {
			argCount = Core.len(args);
		}
		for (i in 0...argCount) {
			final arg = args[i];
			if (!Ast.IsOmittedExpression(arg)) {
				final paramType = c.getTypeAtPosition(signature, i);
				final argType = c.checkExpressionWithContextualType(arg, paramType, null /*inferenceContext*/, checkMode);
				// If one or more arguments are still excluded (as indicated by CheckMode.SkipContextSensitive),
				// we obtain the regular type of any object literal arguments because we may not have inferred complete
				// parameter types yet and therefore excess property checks may yield false positives (see #17041).
				var checkArgType:Type = null;
				if (checkMode & CheckModeSkipContextSensitive != 0) {
					checkArgType = c.getRegularTypeOfObjectLiteral(argType);
				} else {
					checkArgType = argType;
				}
				final effectiveCheckArgumentNode = c.getEffectiveCheckNode(arg);
				if (!c.checkTypeRelatedToAndOptionallyElaborate(checkArgType, paramType, relation, Core.IfElse(reportErrors, effectiveCheckArgumentNode, null),
					effectiveCheckArgumentNode, headMessage, diagnosticOutput)) {
					c.maybeAddMissingAwaitInfo(arg, checkArgType, paramType, relation, reportErrors, diagnosticOutput);
					return false;
				}
			}
		}
		if (restType != null) {
			final spreadType = c.getSpreadArgumentType(args, argCount, Core.len(args), restType, null /*context*/, checkMode);
			final restArgCount = Core.len(args) - argCount;
			var errorNode:Node = null;
			if (reportErrors) {
				switch (restArgCount) {
					case 0:
						errorNode = node;
					case 1:
						errorNode = c.getEffectiveCheckNode(args[argCount]);
					default:
						errorNode = c.createSyntheticExpression(node, spreadType, false, null);
						errorNode.Loc = Core.NewTextRange(args[argCount].Pos(), args[args.length - 1].End());
				}
			}
			if (!c.checkTypeRelatedToEx(spreadType, restType, relation, errorNode, headMessage, diagnosticOutput)) {
				c.maybeAddMissingAwaitInfo(errorNode, spreadType, restType, relation, reportErrors, diagnosticOutput);
				return false;
			}
		}
		return true;
	}

	static function maybeAddMissingAwaitInfo(c:Checker, errorNode:Node, source:Type, target:Type, relation:Relation, reportErrors:Bool, diagnosticOutput:Array<Diagnostic>):Void {
		if (errorNode != null && reportErrors && diagnosticOutput != null && diagnosticOutput.length != 0) {
			// Bail if target is Promise-like---something else is wrong
			if (c.getAwaitedTypeOfPromise(target) != null) {
				return;
			}
			final awaitedTypeOfSource = c.getAwaitedTypeOfPromise(source);
			if (awaitedTypeOfSource != null && c.isTypeRelatedTo(awaitedTypeOfSource, target, relation)) {
				diagnosticOutput[0].AddRelatedInfo(Checker.NewDiagnosticForNode(errorNode, Diagnostics.Did_you_forget_to_use_await));
			}
		}
	}

	// Returns the `this` argument node in calls like `x.f(...)` and `x[f](...)`. `nil` otherwise.
	static function getThisArgumentOfCall(c:Checker, node:Node):Node {
		if (Ast.IsBinaryExpression(node)) {
			return node.AsBinaryExpression().Right;
		}
		var expression:Node = null;
		if (Ast.IsCallExpression(node)) {
			expression = node.Expression();
		} else if (Ast.IsTaggedTemplateExpression(node)) {
			expression = node.AsTaggedTemplateExpression().Tag;
		} else if (Ast.IsDecorator(node) && !c.legacyDecorators) {
			expression = node.Expression();
		}
		if (expression != null) {
			final callee = Ast.SkipOuterExpressions(expression, OEKAll);
			if (Ast.IsAccessExpression(callee)) {
				return callee.Expression();
			}
		}
		return null;
	}

	static function getThisArgumentType(c:Checker, node:Node):Type {
		if (node == null) {
			return c.voidType;
		}
		final thisArgumentType = c.checkExpression(node);
		if (Ast.IsOptionalChainRoot(node.Parent)) {
			return c.GetNonNullableType(thisArgumentType);
		} else if (Ast.IsOptionalChain(node.Parent)) {
			return c.removeOptionalTypeMarker(thisArgumentType);
		}
		return thisArgumentType;
	}

	static function getEffectiveCheckNode(c:Checker, argument:Node):Node {
		final flags = Core.IfElse(Ast.IsInJSFile(argument), OEKParentheses | OEKSatisfies | OEKExcludeJSDocTypeAssertion, OEKParentheses | OEKSatisfies);
		return Ast.SkipOuterExpressions(argument, flags);
	}

	static function inferTypeArguments(c:Checker, node:Node, signature:Signature, args:Array<Node>, checkMode:CheckMode, context:InferenceContext):Array<Type> {
		if (Ast.IsJsxOpeningLikeElement(node)) {
			return c.inferJsxTypeArguments(node, signature, checkMode, context);
		}
		// If a contextual type is available, infer from that type to the return type of the call expression. For
		// example, given a 'function wrap<T, U>(cb: (x: T) => U): (x: T) => U' and a call expression
		// 'let f: (x: string) => number = wrap(s => s.length)', we infer from the declared type of 'f' to the
		// return type of 'wrap'.
		if (!Ast.IsDecorator(node) && !Ast.IsBinaryExpression(node)) {
			final skipBindingPatterns = Core.Every(signature.typeParameters, (p:Type) -> {
				return c.getDefaultFromTypeParameter(p) != null;
			});
			final contextualType = c.getContextualType(node, Core.IfElse(skipBindingPatterns, ContextFlagsSkipBindingPatterns, ContextFlagsNone));
			if (contextualType != null) {
				final inferenceTargetType = c.getReturnTypeOfSignature(signature);
				if (c.couldContainTypeVariables(inferenceTargetType)) {
					final outerContext = c.getInferenceContext(node);
					final isFromBindingPattern = !skipBindingPatterns && c.getContextualType(node, ContextFlagsSkipBindingPatterns) != contextualType;
					// A return type inference from a binding pattern can be used in instantiating the contextual
					// type of an argument later in inference, but cannot stand on its own as the final return type.
					// It is incorporated into `context.returnMapper` which is used in `instantiateContextualType`,
					// but doesn't need to go into `context.inferences`. This allows a an array binding pattern to
					// produce a tuple for `T` in
					//   declare function f<T>(cb: () => T): T;
					//   const [e1, e2, e3] = f(() => [1, "hi", true]);
					// but does not produce any inference for `T` in
					//   declare function f<T>(): T;
					//   const [e1, e2, e3] = f();
					if (!isFromBindingPattern) {
						// We clone the inference context to avoid disturbing a resolution in progress for an
						// outer call expression. Effectively we just want a snapshot of whatever has been
						// inferred for any outer call expression so far.
						final outerMapper = c.getMapperFromContext(c.cloneInferenceContext(outerContext, InferenceFlagsNoDefault));
						final instantiatedType = c.instantiateType(contextualType, outerMapper);
						// If the contextual type is a generic function type with a single call signature, we
						// instantiate the type with its own type parameters and type arguments. This ensures that
						// the type parameters are not erased to type any during type inference such that they can
						// be inferred as actual types from the contextual type. For example:
						//   declare function arrayMap<T, U>(f: (x: T) => U): (a: T[]) => U[];
						//   const boxElements: <A>(a: A[]) => { value: A }[] = arrayMap(value => ({ value }));
						// Above, the type of the 'value' parameter is inferred to be 'A'.
						final contextualSignature = c.getSingleCallSignature(instantiatedType);
						var inferenceSourceType:Type = null;
						if (contextualSignature != null && Core.len(contextualSignature.typeParameters) != 0) {
							inferenceSourceType = c.getOrCreateTypeFromSignature(c.getSignatureInstantiationWithoutFillingInTypeArguments(contextualSignature,
								contextualSignature.typeParameters));
						} else {
							inferenceSourceType = instantiatedType;
						}
						// Inferences made from return types have lower priority than all other inferences.
						c.inferTypes(context.inferences, inferenceSourceType, inferenceTargetType, InferencePriorityReturnType, false);
					}
					// Create a type mapper for instantiating generic contextual types using the inferences made
					// from the return type. We need a separate inference pass here because (a) instantiation of
					// the source type uses the outer context's return mapper (which excludes inferences made from
					// outer arguments), and (b) we don't want any further inferences going into this context.
					// We use `createOuterReturnMapper` to ensure that all occurrences of outer type parameters are
					// replaced with inferences produced from the outer return type or preceding outer arguments.
					// This protects against circular inferences, i.e. avoiding situations where inferences reference
					// type parameters for which the inferences are being made.
					final returnContext = c.newInferenceContext(signature.typeParameters, signature, context.flags, null);
					var outerReturnMapper:TypeMapper = null;
					if (outerContext != null) {
						outerReturnMapper = c.createOuterReturnMapper(outerContext);
					}
					final returnSourceType = c.instantiateType(contextualType, outerReturnMapper);
					c.inferTypes(returnContext.inferences, returnSourceType, inferenceTargetType, InferencePriorityNone, false);
					if (Core.Some(returnContext.inferences, Checker.hasInferenceCandidates)) {
						context.returnMapper = c.getMapperFromContext(c.cloneInferredPartOfContext(returnContext));
					} else {
						context.returnMapper = null;
					}
				}
			}
		}
		final restType = c.getNonArrayRestType(signature);
		var argCount = Core.len(args);
		if (restType != null) {
			argCount = imin(c.getParameterCount(signature) - 1, argCount);
		}
		if (restType != null && restType.flags & TypeFlagsTypeParameter != 0) {
			final info = Core.Find(context.inferences, (info:InferenceInfo) -> {
				return info.typeParameter == restType;
			});
			if (info != null) {
				if (Core.FindIndex(args.slice(argCount), Checker.isSpreadArgument) < 0) {
					info.impliedArity = Core.len(args) - argCount;
				}
			}
		}
		final thisType = c.getThisTypeOfSignature(signature);
		if (thisType != null && c.couldContainTypeVariables(thisType)) {
			final thisArgumentNode = c.getThisArgumentOfCall(node);
			c.inferTypes(context.inferences, c.getThisArgumentType(thisArgumentNode), thisType, InferencePriorityNone, false);
		}
		for (i in 0...argCount) {
			final arg = args[i];
			if (arg.Kind != KindOmittedExpression) {
				final paramType = c.getTypeAtPosition(signature, i);
				if (c.couldContainTypeVariables(paramType)) {
					final argType = c.checkExpressionWithContextualType(arg, paramType, context, checkMode);
					c.inferTypes(context.inferences, argType, paramType, InferencePriorityNone, false);
				}
			}
		}
		if (restType != null && c.couldContainTypeVariables(restType)) {
			final spreadType = c.getSpreadArgumentType(args, argCount, Core.len(args), restType, context, checkMode);
			c.inferTypes(context.inferences, spreadType, restType, InferencePriorityNone, false);
		}
		return c.getInferredTypes(context);
	}

	// No signature was applicable. We have already reported the errors for the invalid signature.
	static function getCandidateForOverloadFailure(c:Checker, node:Node, candidates:Array<Signature>, args:Array<Node>, hasCandidatesOutArray:Bool, checkMode:CheckMode):Signature {
		// Else should not have called this.
		c.checkNodeDeferred(node);
		// Normally we will combine overloads. Skip this if they have type parameters since that's hard to combine.
		// Don't do this if there is a `candidatesOutArray`,
		// because then we want the chosen best candidate to be one of the overloads, not a combination.
		if (hasCandidatesOutArray || Core.len(candidates) == 1 || Core.Some(candidates, (s:Signature) -> {
			return Core.len(s.typeParameters) != 0;
		})) {
			return c.pickLongestCandidateSignature(node, candidates, args, checkMode);
		}
		return c.createUnionOfSignaturesForOverloadFailure(candidates);
	}

	static function pickLongestCandidateSignature(c:Checker, node:Node, candidates:Array<Signature>, args:Array<Node>, checkMode:CheckMode):Signature {
		// Pick the longest signature. This way we can get a contextual type for cases like:
		//     declare function f(a: { xa: number; xb: number; }, b: number);
		//     f({ |
		// Also, use explicitly-supplied type arguments if they are provided, so we can get a contextual signature in cases like:
		//     declare function f<T>(k: keyof T);
		//     f<Foo>("
		var argCount = Core.len(args);
		if (c.apparentArgumentCount != null) {
			argCount = c.apparentArgumentCount;
		}
		final bestIndex = c.getLongestCandidateIndex(candidates, argCount);
		final candidate = candidates[bestIndex];
		final typeParameters = candidate.typeParameters;
		if (Core.len(typeParameters) == 0) {
			return candidate;
		}
		var typeArgumentNodes:Array<Node> = null;
		if (c.callLikeExpressionMayHaveTypeArguments(node)) {
			typeArgumentNodes = node.TypeArguments();
		}
		var instantiated:Signature = null;
		if (Core.len(typeArgumentNodes) != 0) {
			instantiated = c.createSignatureInstantiation(candidate, c.getTypeArgumentsFromNodes(typeArgumentNodes, typeParameters));
		} else {
			instantiated = c.inferSignatureInstantiationForOverloadFailure(node, typeParameters, candidate, args, checkMode);
		}
		candidates[bestIndex] = instantiated;
		return instantiated;
	}

	static function getLongestCandidateIndex(c:Checker, candidates:Array<Signature>, argsCount:Int):Int {
		var maxParamsIndex = -1;
		var maxParams = -1;
		for (i in 0...Core.len(candidates)) {
			final candidate = candidates[i];
			final paramCount = c.getParameterCount(candidate);
			if (c.hasEffectiveRestParameter(candidate) || paramCount >= argsCount) {
				return i;
			}
			if (paramCount > maxParams) {
				maxParams = paramCount;
				maxParamsIndex = i;
			}
		}
		return maxParamsIndex;
	}

	static function getTypeArgumentsFromNodes(c:Checker, typeArgumentNodes:Array<Node>, typeParameters:Array<Type>):Array<Type> {
		if (Core.len(typeArgumentNodes) > Core.len(typeParameters)) {
			typeArgumentNodes = typeArgumentNodes.slice(0, Core.len(typeParameters));
		}
		final typeArguments = Core.Map(typeArgumentNodes, c.getTypeFromTypeNode);
		while (Core.len(typeArguments) < Core.len(typeParameters)) {
			var t = c.getDefaultFromTypeParameter(typeParameters[Core.len(typeArguments)]);
			if (t == null) {
				t = c.getConstraintOfTypeParameter(typeParameters[Core.len(typeArguments)]);
				if (t == null) {
					t = c.unknownType;
				}
			}
			typeArguments.push(t);
		}
		return typeArguments;
	}

	static function inferSignatureInstantiationForOverloadFailure(c:Checker, node:Node, typeParameters:Array<Type>, candidate:Signature, args:Array<Node>, checkMode:CheckMode):Signature {
		final inferenceContext = c.newInferenceContext(typeParameters, candidate, Core.IfElse(Ast.IsInJSFile(node), InferenceFlagsAnyDefault, InferenceFlagsNone),
			null);
		final typeArgumentTypes = c.inferTypeArguments(node, candidate, args, checkMode | CheckModeSkipContextSensitive | CheckModeSkipGenericFunctions,
			inferenceContext);
		return c.createSignatureInstantiation(candidate, typeArgumentTypes);
	}

	static function createUnionOfSignaturesForOverloadFailure(c:Checker, candidates:Array<Signature>):Signature {
		final thisParameters = Core.MapNonNil(candidates, (c:Signature) -> {
			return c.thisParameter;
		});
		var thisParameter:Symbol = null;
		if (Core.len(thisParameters) != 0) {
			thisParameter = c.createCombinedSymbolFromTypes(thisParameters, Core.Map(thisParameters, c.getTypeOfParameter));
		}
		final mm = Checker.minAndMax(candidates, Checker.getNonRestParameterCount);
		final minArgumentCount = mm.a;
		final maxNonRestParam = mm.b;
		final parameters:Array<Symbol> = [];
		for (i in 0...maxNonRestParam) {
			final symbols = Core.MapNonNil(candidates, (s:Signature) -> {
				if (Checker.signatureHasRestParameter(s)) {
					if (i < Core.len(s.parameters) - 1) {
						return s.parameters[i];
					}
					return Core.LastOrNil(s.parameters);
				}
				if (i < Core.len(s.parameters)) {
					return s.parameters[i];
				}
				return null;
			});
			parameters.push(c.createCombinedSymbolFromTypes(symbols, Core.MapNonNil(candidates, (s:Signature) -> {
				return c.tryGetTypeAtPosition(s, i);
			})));
		}
		final restParameterSymbols = Core.MapNonNil(candidates, (s:Signature) -> {
			if (Checker.signatureHasRestParameter(s)) {
				return Core.LastOrNil(s.parameters);
			}
			return null;
		});
		var flags = SignatureFlagsIsSignatureCandidateForOverloadFailure;
		if (Core.len(restParameterSymbols) != 0) {
			final t = c.createArrayType(c.getUnionTypeEx(Core.MapNonNil(candidates, c.tryGetRestTypeOfSignature), UnionReductionSubtype, null, null));
			parameters.push(c.createCombinedSymbolForOverloadFailure(restParameterSymbols, t));
			flags |= SignatureFlagsHasRestParameter;
		}
		if (Core.Some(candidates, Checker.signatureHasLiteralTypes)) {
			flags |= SignatureFlagsHasLiteralTypes;
		}
		return c.newSignature(flags, candidates[0].declaration, null, thisParameter, parameters, c.getIntersectionType(Core.Map(candidates, c.getReturnTypeOfSignature)),
			null, minArgumentCount);
	}

	static function createCombinedSymbolFromTypes(c:Checker, sources:Array<Symbol>, types:Array<Type>):Symbol {
		return c.createCombinedSymbolForOverloadFailure(sources, c.getUnionTypeEx(types, UnionReductionSubtype, null, null));
	}

	static function createCombinedSymbolForOverloadFailure(c:Checker, sources:Array<Symbol>, t:Type):Symbol {
		// This function is currently only used for erroneous overloads, so it's good enough to just use the first source.
		return c.createSymbolWithType(Core.FirstOrNil(sources), t);
	}

	static function getRestTypeOfSignature(c:Checker, signature:Signature):Type {
		return Core.OrElse(c.tryGetRestTypeOfSignature(signature), c.anyType);
	}

	static function tryGetRestTypeOfSignature(c:Checker, signature:Signature):Type {
		if (!Checker.signatureHasRestParameter(signature)) {
			return null;
		}
		var restType = c.getTypeOfSymbol(signature.parameters[signature.parameters.length - 1]);
		if (Checker.isTupleType(restType)) {
			restType = c.getRestTypeOfTupleType(restType);
			if (restType == null) {
				return null;
			}
		}
		return c.getIndexTypeOfType(restType, c.numberType);
	}

	static function reportCallResolutionErrors(c:Checker, node:Node, s:CallState, signatures:Array<Signature>, headMessage:Message):Void {
		if (Core.len(s.candidatesForArgumentError) != 0) {
			final last = s.candidatesForArgumentError[s.candidatesForArgumentError.length - 1];
			final diags:Array<Diagnostic> = [];
			c.isSignatureApplicable(s.node, s.args, last, c.assignableRelation, CheckModeNormal, true /*reportErrors*/, diags);
			for (d in diags) {
				var diagnostic = d;
				if (s.candidatesForArgumentError.length > 1) {
					diagnostic = Ast.NewDiagnosticChain(diagnostic, Diagnostics.The_last_overload_gave_the_following_error);
					diagnostic = Ast.NewDiagnosticChain(diagnostic, Diagnostics.No_overload_matches_this_call);
				}
				if (headMessage != null) {
					diagnostic = Ast.NewDiagnosticChain(diagnostic, headMessage);
				}
				if (last.declaration != null && s.candidatesForArgumentError.length > 1) {
					diagnostic.AddRelatedInfo(Checker.NewDiagnosticForNode(last.declaration, Diagnostics.The_last_overload_is_declared_here));
				}
				c.addImplementationSuccessElaboration(s, last, diagnostic);
				c.addDiagnostic(diagnostic);
			}
		} else if (s.candidateForArgumentArityError != null) {
			c.addDiagnostic(c.getArgumentArityError(s.node, [s.candidateForArgumentArityError], s.args, headMessage));
		} else if (s.candidateForTypeArgumentError != null) {
			c.checkTypeArguments(s.candidateForTypeArgumentError, s.node.TypeArguments(), true /*reportErrors*/, headMessage);
		} else if (!Ast.IsJsxOpeningFragment(node)) {
			final signaturesWithCorrectTypeArgumentArity = Core.Filter(signatures, (sig:Signature) -> {
				return c.hasCorrectTypeArgumentArity(sig, s.typeArguments);
			});
			if (Core.len(signaturesWithCorrectTypeArgumentArity) == 0) {
				c.addDiagnostic(c.getTypeArgumentArityError(s.node, signatures, s.typeArguments, headMessage));
			} else {
				c.addDiagnostic(c.getArgumentArityError(s.node, signaturesWithCorrectTypeArgumentArity, s.args, headMessage));
			}
		}
	}

	static function addImplementationSuccessElaboration(c:Checker, s:CallState, failed:Signature, diagnostic:Diagnostic):Void {
		if (failed.declaration != null && failed.declaration.Symbol() != null) {
			final declarations = failed.declaration.Symbol().Declarations;
			if (Core.len(declarations) > 1) {
				final implementation = Core.Find(declarations, (d:Node) -> {
					return Ast.IsFunctionLikeDeclaration(d) && Ast.NodeIsPresent(d.Body());
				});
				if (implementation != null) {
					final candidate = c.getSignatureFromDeclaration(implementation);
					// PORT: Go `localState := *s` copies the struct value.
					final localState = new CallState();
					localState.node = s.node;
					localState.typeArguments = s.typeArguments;
					localState.args = s.args;
					localState.candidates = s.candidates;
					localState.argCheckMode = s.argCheckMode;
					localState.isSingleNonGenericCandidate = s.isSingleNonGenericCandidate;
					localState.signatureHelpTrailingComma = s.signatureHelpTrailingComma;
					localState.candidatesForArgumentError = s.candidatesForArgumentError;
					localState.candidateForArgumentArityError = s.candidateForArgumentArityError;
					localState.candidateForTypeArgumentError = s.candidateForTypeArgumentError;
					localState.candidates = [candidate];
					localState.isSingleNonGenericCandidate = Core.len(candidate.typeParameters) == 0;
					if (c.chooseOverload(localState, c.assignableRelation) != null) {
						diagnostic.AddRelatedInfo(Checker.NewDiagnosticForNode(implementation,
							Diagnostics.The_call_would_have_succeeded_against_this_implementation_but_implementation_signatures_of_overloads_are_not_externally_visible));
					}
				}
			}
		}
	}

	static function getArgumentArityError(c:Checker, node:Node, signatures:Array<Signature>, args:Array<Node>, headMessage:Message):Diagnostic {
		final spreadIndex = c.getSpreadArgumentIndex(args);
		if (spreadIndex > -1) {
			return Checker.NewDiagnosticForNode(args[spreadIndex], Diagnostics.A_spread_argument_must_either_have_a_tuple_type_or_be_passed_to_a_rest_parameter);
		}
		var minCount = MAX_INT; // smallest parameter count
		var maxCount = MIN_INT; // largest parameter count
		var maxBelow = MIN_INT; // largest parameter count that is smaller than the number of arguments
		var minAbove = MAX_INT; // smallest parameter count that is larger than the number of arguments
		var closestSignature:Signature = null;
		final argsLen = Core.len(args);
		for (sig in signatures) {
			final minParameter = c.getMinArgumentCount(sig);
			final maxParameter = c.getParameterCount(sig);
			// smallest/largest parameter counts
			if (minParameter < minCount) {
				minCount = minParameter;
				closestSignature = sig;
			}
			maxCount = imax(maxCount, maxParameter);
			// shortest parameter count *longer than the call*/longest parameter count *shorter than the call*
			if (minParameter < argsLen && minParameter > maxBelow) {
				maxBelow = minParameter;
			}
			if (argsLen < maxParameter && maxParameter < minAbove) {
				minAbove = maxParameter;
			}
		}
		final hasRestParameter = Core.Some(signatures, c.hasEffectiveRestParameter);
		var parameterRange = "";
		if (hasRestParameter) {
			parameterRange = Std.string(minCount);
		} else if (minCount < maxCount) {
			parameterRange = Std.string(minCount) + "-" + Std.string(maxCount);
		} else {
			parameterRange = Std.string(minCount);
		}
		final isVoidPromiseError = !hasRestParameter && parameterRange == "1" && argsLen == 0 && c.isPromiseResolveArityError(node);
		final errorNode = Checker.getErrorNodeForCallNode(node);
		if (isVoidPromiseError && Ast.IsInJSFile(node)) {
			return Checker.NewDiagnosticForNode(errorNode,
				Diagnostics.Expected_1_argument_but_got_0_new_Promise_needs_a_JSDoc_hint_to_produce_a_resolve_that_can_be_called_without_arguments);
		}
		var message:Message = null;
		if (Ast.IsDecorator(node)) {
			if (hasRestParameter) {
				message = Diagnostics.The_runtime_will_invoke_the_decorator_with_1_arguments_but_the_decorator_expects_at_least_0;
			} else {
				message = Diagnostics.The_runtime_will_invoke_the_decorator_with_1_arguments_but_the_decorator_expects_0;
			}
		} else if (hasRestParameter) {
			message = Diagnostics.Expected_at_least_0_arguments_but_got_1;
		} else if (isVoidPromiseError) {
			message = Diagnostics.Expected_0_arguments_but_got_1_Did_you_forget_to_include_void_in_your_type_argument_to_Promise;
		} else {
			message = Diagnostics.Expected_0_arguments_but_got_1;
		}
		if (minCount < argsLen && argsLen < maxCount) {
			// between min and max, but with no matching overload
			var diagnostic = Checker.NewDiagnosticForNode(errorNode,
				Diagnostics.No_overload_expects_0_arguments_but_overloads_do_exist_that_expect_either_1_or_2_arguments, argsLen, maxBelow, minAbove);
			if (headMessage != null) {
				diagnostic = Ast.NewDiagnosticChain(diagnostic, headMessage);
			}
			return diagnostic;
		} else if (argsLen < minCount) {
			// too short: put the error span on the call expression, not any of the args
			var diagnostic = Checker.NewDiagnosticForNode(errorNode, message, parameterRange, argsLen);
			if (headMessage != null) {
				diagnostic = Ast.NewDiagnosticChain(diagnostic, headMessage);
			}
			var parameter:Node = null;
			if (closestSignature != null && closestSignature.declaration != null) {
				parameter = Core.ElementOrNil(closestSignature.declaration.Parameters(), argsLen + Core.IfElse(closestSignature.thisParameter != null, 1, 0));
			}
			if (parameter != null) {
				var related:Diagnostic = null;
				if (Ast.IsBindingPattern(parameter.Name())) {
					related = Checker.NewDiagnosticForNode(parameter, Diagnostics.An_argument_matching_this_binding_pattern_was_not_provided);
				} else if (Checker.isRestParameter(parameter)) {
					related = Checker.NewDiagnosticForNode(parameter, Diagnostics.Arguments_for_the_rest_parameter_0_were_not_provided, parameter.Name().Text());
				} else {
					related = Checker.NewDiagnosticForNode(parameter, Diagnostics.An_argument_for_0_was_not_provided, parameter.Name().Text());
				}
				diagnostic.AddRelatedInfo(related);
			}
			return diagnostic;
		} else {
			// Guard against out-of-bounds access when maxCount >= len(args).
			// This can happen when we reach this fallback error path but the argument
			// count actually matches the parameter count (e.g., due to trailing commas
			// causing signature resolution to fail for other reasons).
			if (maxCount >= argsLen) {
				var diagnostic = Checker.NewDiagnosticForNode(errorNode, message, parameterRange, argsLen);
				if (headMessage != null) {
					diagnostic = Ast.NewDiagnosticChain(diagnostic, headMessage);
				}
				return diagnostic;
			}
			final sourceFile = Ast.GetSourceFileOfNode(node);
			var pos = args[maxCount].Pos();
			var end = args[args.length - 1].End();
			if (end == pos) {
				end++;
			}
			pos = Scanner.SkipTrivia(sourceFile.Text(), pos);
			if (end < pos) {
				end = pos;
			}
			var diagnostic = Ast.NewDiagnostic(sourceFile, Core.NewTextRange(pos, end), message, parameterRange, argsLen);
			if (headMessage != null) {
				diagnostic = Ast.NewDiagnosticChain(diagnostic, headMessage);
			}
			return diagnostic;
		}
	}

	static function isPromiseResolveArityError(c:Checker, node:Node):Bool {
		if (!Ast.IsCallExpression(node) || !Ast.IsIdentifier(node.Expression())) {
			return false;
		}
		final symbol = c.resolveName(node.Expression(), node.Expression().Text(), SymbolFlagsValue, null /*nameNotFoundMessage*/, false /*isUse*/, false);
		if (symbol == null) {
			return false;
		}
		final decl = symbol.ValueDeclaration;
		if (decl == null || !Ast.IsParameterDeclaration(decl) || !Ast.IsFunctionExpressionOrArrowFunction(decl.Parent)
			|| !Ast.IsNewExpression(decl.Parent.Parent) || !Ast.IsIdentifier(decl.Parent.Parent.Expression())) {
			return false;
		}
		final globalPromiseSymbol = c.getGlobalPromiseConstructorSymbolOrNil();
		if (globalPromiseSymbol == null) {
			return false;
		}
		final constructorSymbol = c.getResolvedSymbol(decl.Parent.Parent.Expression());
		return constructorSymbol == globalPromiseSymbol;
	}

	static function getTypeArgumentArityError(c:Checker, node:Node, signatures:Array<Signature>, typeArguments:Array<Node>, headMessage:Message):Diagnostic {
		var diagnostic:Diagnostic = null;
		final argCount = Core.len(typeArguments);
		final sourceFile = Ast.GetSourceFileOfNode(node);
		final typeArgumentList = node.TypeArgumentList();
		final loc = Core.NewTextRange(Scanner.SkipTrivia(sourceFile.Text(), typeArgumentList.Loc.Pos()), typeArgumentList.Loc.End());
		if (Core.len(signatures) == 1) {
			// No overloads exist
			final sig = signatures[0];
			final minCount = c.getMinTypeArgumentCount(sig.typeParameters);
			final maxCount = Core.len(sig.typeParameters);
			var expected = Std.string(minCount);
			if (minCount < maxCount) {
				expected = expected + "-" + Std.string(maxCount);
			}
			diagnostic = Ast.NewDiagnostic(sourceFile, loc, Diagnostics.Expected_0_type_arguments_but_got_1, expected, argCount);
		} else {
			// Overloads exist
			var belowArgCount = MIN_INT;
			var aboveArgCount = MAX_INT;
			for (sig in signatures) {
				final minCount = c.getMinTypeArgumentCount(sig.typeParameters);
				final maxCount = Core.len(sig.typeParameters);
				if (minCount > argCount) {
					aboveArgCount = imin(aboveArgCount, minCount);
				} else if (maxCount < argCount) {
					belowArgCount = imax(belowArgCount, maxCount);
				}
			}
			if (belowArgCount != MIN_INT && aboveArgCount != MAX_INT) {
				diagnostic = Ast.NewDiagnostic(sourceFile, loc,
					Diagnostics.No_overload_expects_0_type_arguments_but_overloads_do_exist_that_expect_either_1_or_2_type_arguments, argCount, belowArgCount,
					aboveArgCount);
			} else {
				diagnostic = Ast.NewDiagnostic(sourceFile, loc, Diagnostics.Expected_0_type_arguments_but_got_1,
					Core.IfElse(belowArgCount == MIN_INT, aboveArgCount, belowArgCount), argCount);
			}
		}
		if (headMessage != null) {
			diagnostic = Ast.NewDiagnosticChain(diagnostic, headMessage);
		}
		return diagnostic;
	}

	static function reportCannotInvokePossiblyNullOrUndefinedError(c:Checker, node:Node, facts:TypeFacts):Void {
		c.error(node, Core.IfElse(facts & TypeFactsIsUndefined != 0,
			Core.IfElse(facts & TypeFactsIsNull != 0, Diagnostics.Cannot_invoke_an_object_which_is_possibly_null_or_undefined,
				Diagnostics.Cannot_invoke_an_object_which_is_possibly_undefined),
			Diagnostics.Cannot_invoke_an_object_which_is_possibly_null));
	}

	static function resolveUntypedCall(c:Checker, node:Node):Signature {
		if (c.callLikeExpressionMayHaveTypeArguments(node)) {
			// Check type arguments even though we will give an error that untyped calls may not accept type arguments.
			// This gets us diagnostics for the type arguments and marks them as referenced.
			c.checkSourceElements(node.TypeArguments());
		}
		switch (node.Kind) {
			case KindTaggedTemplateExpression:
				c.checkExpression(node.AsTaggedTemplateExpression().Template);
			case KindJsxOpeningElement, KindJsxSelfClosingElement:
				c.checkExpression(node.Attributes());
			case KindBinaryExpression:
				c.checkExpression(node.AsBinaryExpression().Left);
			case KindCallExpression, KindNewExpression:
				final args = node.Arguments();
				if (args != null) {
					for (argument in args) {
						c.checkExpression(argument);
					}
				}
			default:
		}
		return c.anySignature;
	}

	static function resolveErrorCall(c:Checker, node:Node):Signature {
		c.resolveUntypedCall(node);
		return c.unknownSignature;
	}

	/**
	 * TS 1.0 spec: 4.12
	 * If FuncExpr is of type Any, or of an object type that has no call or construct signatures
	 * but is a subtype of the Function interface, the call is an untyped function call.
	 */
	static function isUntypedFunctionCall(c:Checker, funcType:Type, apparentFuncType:Type, numCallSignatures:Int, numConstructSignatures:Int):Bool {
		// We exclude union types because we may have a union of function types that happen to have no common signatures.
		return Checker.IsTypeAny(funcType) || Checker.IsTypeAny(apparentFuncType) && funcType.flags & TypeFlagsTypeParameter != 0
			|| numCallSignatures == 0 && numConstructSignatures == 0 && apparentFuncType.flags & TypeFlagsUnion == 0
				&& c.getReducedType(apparentFuncType).flags & TypeFlagsNever == 0 && c.isTypeAssignableTo(funcType, c.globalFunctionType);
	}

	static function invocationErrorDetails(c:Checker, errorTarget:Node, apparentType:Type, kind:SignatureKind):Diagnostic {
		var diagnostic:Diagnostic = null;
		final isCall = kind == SignatureKindCall;
		final awaitedType = c.getAwaitedType(apparentType);
		final maybeMissingAwait = awaitedType != null && Core.len(c.getSignaturesOfType(awaitedType, kind)) > 0;
		var target = errorTarget;
		if (Ast.IsPropertyAccessExpression(errorTarget) && Ast.IsCallExpression(errorTarget.Parent)) {
			target = errorTarget.Name();
		}
		if (apparentType.flags & TypeFlagsUnion != 0) {
			final types = apparentType.Types();
			var hasSignatures = false;
			for (constituent in types) {
				final signatures = c.getSignaturesOfType(constituent, kind);
				if (Core.len(signatures) != 0) {
					hasSignatures = true;
					if (diagnostic != null) {
						// Bail early if we already have an error, no chance of "No constituent of type is callable"
						break;
					}
				} else {
					// Error on the first non callable constituent only
					if (diagnostic == null) {
						diagnostic = Checker.NewDiagnosticForNode(target,
							Core.IfElse(isCall, Diagnostics.Type_0_has_no_call_signatures, Diagnostics.Type_0_has_no_construct_signatures),
							c.TypeToString(constituent));
						diagnostic = Checker.NewDiagnosticChainForNode(diagnostic, target,
							Core.IfElse(isCall, Diagnostics.Not_all_constituents_of_type_0_are_callable, Diagnostics.Not_all_constituents_of_type_0_are_constructable),
							c.TypeToString(apparentType));
					}
					if (hasSignatures) {
						// Bail early if we already found a signature, no chance of "No constituent of type is callable"
						break;
					}
				}
			}
			if (!hasSignatures) {
				diagnostic = Checker.NewDiagnosticForNode(target,
					Core.IfElse(isCall, Diagnostics.No_constituent_of_type_0_is_callable, Diagnostics.No_constituent_of_type_0_is_constructable),
					c.TypeToString(apparentType));
			}
			if (diagnostic == null) {
				diagnostic = Checker.NewDiagnosticForNode(target,
					Core.IfElse(isCall, Diagnostics.Each_member_of_the_union_type_0_has_signatures_but_none_of_those_signatures_are_compatible_with_each_other,
						Diagnostics.Each_member_of_the_union_type_0_has_construct_signatures_but_none_of_those_signatures_are_compatible_with_each_other),
					c.TypeToString(apparentType));
			}
		} else {
			diagnostic = Checker.NewDiagnosticChainForNode(diagnostic, target,
				Core.IfElse(isCall, Diagnostics.Type_0_has_no_call_signatures, Diagnostics.Type_0_has_no_construct_signatures), c.TypeToString(apparentType));
		}
		var headMessage = Core.IfElse(isCall, Diagnostics.This_expression_is_not_callable, Diagnostics.This_expression_is_not_constructable);
		// Diagnose get accessors incorrectly called as functions
		if (Ast.IsCallExpression(errorTarget.Parent) && Core.len(errorTarget.Parent.Arguments()) == 0) {
			final resolvedSymbol = c.getResolvedSymbolOrNil(errorTarget);
			if (resolvedSymbol != null && resolvedSymbol.Flags & SymbolFlagsGetAccessor != 0) {
				headMessage = Diagnostics.This_expression_is_not_callable_because_it_is_a_get_accessor_Did_you_mean_to_use_it_without;
			}
		}
		diagnostic = Checker.NewDiagnosticChainForNode(diagnostic, target, headMessage);
		if (maybeMissingAwait) {
			diagnostic.AddRelatedInfo(Checker.NewDiagnosticForNode(errorTarget, Diagnostics.Did_you_forget_to_use_await));
		}
		return diagnostic;
	}

	static function invocationError(c:Checker, errorTarget:Node, apparentType:Type, kind:SignatureKind, relatedInformation:Diagnostic):Void {
		final diagnostic = c.invocationErrorDetails(errorTarget, apparentType, kind);
		if (relatedInformation != null) {
			diagnostic.AddRelatedInfo(relatedInformation);
		}
		c.addDiagnostic(diagnostic);
		c.invocationErrorRecovery(apparentType, kind, diagnostic);
	}

	static function invocationErrorRecovery(c:Checker, apparentType:Type, kind:SignatureKind, diagnostic:Diagnostic):Void {
		if (apparentType.symbol == null) {
			return;
		}
		final importNode = c.exportTypeLinks.Get(apparentType.symbol).originatingImport;
		// Create a diagnostic on the originating import if possible onto which we can attach a quickfix
		//  An import call expression cannot be rewritten into another form to correct the error - the only solution is to use `.default` at the use-site
		if (importNode != null && !Ast.IsImportCall(importNode)) {
			final sigs = c.getSignaturesOfType(c.getTypeOfSymbol(c.exportTypeLinks.Get(apparentType.symbol).target), kind);
			if (Core.len(sigs) == 0) {
				return;
			}
			diagnostic.AddRelatedInfo(Checker.NewDiagnosticForNode(importNode,
				Diagnostics.Type_originates_at_this_import_A_namespace_style_import_cannot_be_called_or_constructed_and_will_cause_a_failure_at_runtime_Consider_using_a_default_import_or_import_require_here_instead));
		}
	}

	static function isGenericFunctionReturningFunction(c:Checker, signature:Signature):Bool {
		return Core.len(signature.typeParameters) != 0 && c.isFunctionType(c.getReturnTypeOfSignature(signature));
	}

	static function skippedGenericFunction(c:Checker, node:Node, checkMode:CheckMode):Void {
		if (checkMode & CheckModeInferential != 0) {
			// We have skipped a generic function during inferential typing. Obtain the inference context and
			// indicate this has occurred such that we know a second pass of inference is be needed.
			final context = c.getInferenceContext(node);
			context.flags |= InferenceFlagsSkippedGenericFunction;
		}
	}

	static function checkTaggedTemplateExpression(c:Checker, node:Node):Type {
		if (!c.checkGrammarTaggedTemplateChain(node.AsTaggedTemplateExpression())) {
			c.checkGrammarTypeArguments(node, node.TypeArgumentList());
		}
		final signature = c.getResolvedSignature(node, null, CheckModeNormal);
		c.checkDeprecatedSignature(signature, node);
		return c.getReturnTypeOfSignature(signature);
	}

	static function checkParenthesizedExpression(c:Checker, node:Node, checkMode:CheckMode):Type {
		return c.checkExpressionEx(node.Expression(), checkMode);
	}

	static function checkClassExpression(c:Checker, node:Node):Type {
		c.checkClassLikeDeclaration(node);
		c.checkNodeDeferred(node);
		c.checkClassExpressionExternalHelpers(node);
		return c.getTypeOfSymbol(c.getSymbolOfDeclaration(node));
	}

	static function getFirstTransformableStaticClassElement(c:Checker, node:Node):Node {
		final willTransformStaticElementsOfDecoratedClass = !c.legacyDecorators
			&& c.languageVersion < Checker.LanguageFeatureMinimumTarget.ClassAndClassElementDecorators
			&& Ast.ClassOrConstructorParameterIsDecorated(false, node);
		final willTransformPrivateElementsOrClassStaticBlocks = c.languageVersion < Checker.LanguageFeatureMinimumTarget.PrivateNamesAndClassStaticBlocks
			|| c.languageVersion < Checker.LanguageFeatureMinimumTarget.ClassAndClassElementDecorators;
		final willTransformInitializers = !c.emitStandardClassFields;
		if (willTransformStaticElementsOfDecoratedClass || willTransformPrivateElementsOrClassStaticBlocks) {
			final members = node.Members();
			if (members != null) {
				for (member in members) {
					if (willTransformStaticElementsOfDecoratedClass && Ast.ClassElementOrClassElementParameterIsDecorated(false, member, node)) {
						final firstDecorator = Core.FirstOrNil(node.Decorators());
						if (firstDecorator != null) {
							return firstDecorator;
						}
						return node;
					} else if (willTransformPrivateElementsOrClassStaticBlocks) {
						if (Ast.IsClassStaticBlockDeclaration(member)) {
							return member;
						} else if (Ast.IsStatic(member)
							&& (Ast.IsPrivateIdentifierClassElementDeclaration(member) || willTransformInitializers && Ast.IsInitializedProperty(member))) {
							return member;
						}
					}
				}
			}
		}
		return null;
	}

	static function checkClassExpressionExternalHelpers(c:Checker, node:ClassExpressionNode):Void {
		if (node.Name() != null) {
			return;
		}
		final parent = Checker.walkUpOuterExpressions(node);
		if (!Ast.IsNamedEvaluationSource(parent)) {
			return;
		}

		final willTransformESDecorators = !c.legacyDecorators && c.languageVersion < Checker.LanguageFeatureMinimumTarget.ClassAndClassElementDecorators;
		var location:Node = null;
		if (willTransformESDecorators && Ast.ClassOrConstructorParameterIsDecorated(false, node)) {
			location = node;
			final firstDecorator = Core.FirstOrNil(node.Decorators());
			if (firstDecorator != null) {
				location = firstDecorator;
			}
		} else {
			location = c.getFirstTransformableStaticClassElement(node);
		}

		if (location != null) {
			c.checkExternalEmitHelpers(location, ExternalEmitHelpersSetFunctionName);
			if ((Ast.IsPropertyAssignment(parent) || Ast.IsPropertyDeclaration(parent) || Ast.IsBindingElement(parent))
				&& Ast.IsComputedPropertyName(parent.Name())) {
				c.checkExternalEmitHelpers(location, ExternalEmitHelpersPropKey);
			}
		}
	}

	static function checkClassExpressionDeferred(c:Checker, node:Node):Void {
		c.checkSourceElements(node.Members());
		c.registerForUnusedIdentifiersCheck(node);
	}

	static function checkFunctionExpressionOrObjectLiteralMethod(c:Checker, node:Node, checkMode:CheckMode):Type {
		c.checkNodeDeferred(node);
		if (Ast.IsFunctionExpression(node)) {
			c.checkCollisionsForDeclarationName(node, node.Name());
		}
		if (checkMode & CheckModeSkipContextSensitive != 0 && c.isContextSensitive(node)) {
			// Skip parameters, return signature with return type that retains noncontextual parts so inferences can still be drawn in an early stage
			if (node.Type() == null && !Ast.HasContextSensitiveParameters(node)) {
				// Return plain anyFunctionType if there is no possibility we'll make inferences from the return type
				final contextualSignature = c.getContextualSignature(node);
				if (contextualSignature != null && c.couldContainTypeVariables(c.getReturnTypeOfSignature(contextualSignature))) {
					if (c.contextFreeTypes.exists(node)) {
						return c.contextFreeTypes.get(node);
					}
					final returnType = c.getReturnTypeFromBody(node, checkMode);
					final returnOnlySignature = c.newSignature(SignatureFlagsIsNonInferrable, null, null /*typeParameters*/, null /*thisParameter*/, null, returnType,
						null /*resolvedTypePredicate*/, 0);
					final returnOnlyType = c.newAnonymousType(node.Symbol(), null, [returnOnlySignature], null, null);
					returnOnlyType.objectFlags |= ObjectFlagsNonInferrableType;
					c.contextFreeTypes.set(node, returnOnlyType);
					return returnOnlyType;
				}
			}
			return c.anyFunctionType;
		}
		// Grammar checking
		final hasGrammarError = c.checkGrammarFunctionLikeDeclaration(node);
		if (!hasGrammarError && Ast.IsFunctionExpression(node)) {
			c.checkGrammarForGenerator(node);
		}
		if (node.FunctionLikeData().FullSignature != null) {
			if (c.getContextualCallSignature(c.getTypeFromTypeNode(node.FunctionLikeData().FullSignature), node) == null) {
				c.error(node.FunctionLikeData().FullSignature,
					Diagnostics.A_JSDoc_type_tag_on_a_function_must_have_a_signature_with_the_correct_number_of_arguments);
			}
		}
		c.contextuallyCheckFunctionExpressionOrObjectLiteralMethod(node, checkMode);
		return c.getTypeOfSymbol(c.getSymbolOfDeclaration(node));
	}

	static function contextuallyCheckFunctionExpressionOrObjectLiteralMethod(c:Checker, node:Node, checkMode:CheckMode):Void {
		final links = c.nodeLinks.Get(node);
		// Check if function expression is contextually typed and assign parameter types if so.
		if (links.flags & NodeCheckFlagsContextChecked == 0) {
			final contextualSignature = c.getContextualSignature(node);
			// If a type check is started at a function expression that is an argument of a function call, obtaining the
			// contextual type may recursively get back to here during overload resolution of the call. If so, we will have
			// already assigned contextual types.
			if (links.flags & NodeCheckFlagsContextChecked == 0) {
				links.flags |= NodeCheckFlagsContextChecked;
				final signature = Core.FirstOrNil(c.getSignaturesOfType(c.getTypeOfSymbol(c.getSymbolOfDeclaration(node)), SignatureKindCall));
				if (signature == null) {
					return;
				}
				if (c.isContextSensitive(node)) {
					if (contextualSignature != null) {
						final inferenceContext = c.getInferenceContext(node);
						var instantiatedContextualSignature:Signature = null;
						if (checkMode & CheckModeInferential != 0) {
							c.inferFromAnnotatedParametersAndReturn(signature, contextualSignature, inferenceContext);
							final restType = c.getEffectiveRestType(contextualSignature);
							if (restType != null && restType.flags & TypeFlagsTypeParameter != 0) {
								instantiatedContextualSignature = c.instantiateSignature(contextualSignature, inferenceContext.nonFixingMapper);
							}
						}
						if (instantiatedContextualSignature == null) {
							if (inferenceContext != null) {
								instantiatedContextualSignature = c.instantiateSignature(contextualSignature, inferenceContext.mapper);
							} else {
								instantiatedContextualSignature = contextualSignature;
							}
						}
						c.assignContextualParameterTypes(signature, instantiatedContextualSignature);
					} else {
						// Force resolution of all parameter types such that the absence of a contextual type is consistently reflected.
						c.assignNonContextualParameterTypes(signature);
					}
				} else if (contextualSignature != null && node.TypeParameters() == null
					&& Core.len(contextualSignature.parameters) > Core.len(node.Parameters())) {
					final inferenceContext = c.getInferenceContext(node);
					if (checkMode & CheckModeInferential != 0) {
						c.inferFromAnnotatedParametersAndReturn(signature, contextualSignature, inferenceContext);
					}
				}
				if (contextualSignature != null && c.getReturnTypeFromAnnotation(node) == null && signature.resolvedReturnType == null) {
					final returnType = c.getReturnTypeFromBody(node, checkMode);
					if (signature.resolvedReturnType == null) {
						signature.resolvedReturnType = returnType;
					}
				}
				c.checkSignatureDeclaration(node);
			}
		}
	}

	static function checkFunctionExpressionOrObjectLiteralMethodDeferred(c:Checker, node:Node):Void {
		final functionFlags = Ast.GetFunctionFlags(node);
		final returnType = c.getReturnTypeFromAnnotation(node);
		c.checkAllCodePathsInNonVoidFunctionReturnOrThrow(node, returnType);
		final body = node.Body();
		if (body != null) {
			if (node.Type() == null) {
				// There are some checks that are only performed in getReturnTypeFromBody, that may produce errors
				// we need. An example is the noImplicitAny errors resulting from widening the return expression
				// of a function. Because checking of function expression bodies is deferred, there was never an
				// appropriate time to do this during the main walk of the file (see the comment at the top of
				// checkFunctionExpressionBodies). So it must be done now.
				c.getReturnTypeOfSignature(c.getSignatureFromDeclaration(node));
			}
			if (Ast.IsBlock(body)) {
				c.checkSourceElement(body);
			} else {
				// From within an async function you can return either a non-promise value or a promise. Any
				// Promise/A+ compatible implementation will always assimilate any foreign promise, so we
				// should not be checking assignability of a promise to the return type. Instead, we need to
				// check assignability of the awaited type of the expression body against the promised type of
				// its return type annotation.
				final exprType = c.checkExpression(body);
				if (returnType != null) {
					final returnOrPromisedType = c.unwrapReturnType(returnType, functionFlags);
					if (returnOrPromisedType != null) {
						c.checkReturnExpression(node, returnOrPromisedType, body, body, exprType, false);
					}
				}
			}
		}
	}

	static function inferFromAnnotatedParametersAndReturn(c:Checker, sig:Signature, context:Signature, inferenceContext:InferenceContext):Void {
		final length = Core.len(sig.parameters) - Core.IfElse(Checker.signatureHasRestParameter(sig), 1, 0);
		for (i in 0...length) {
			final declaration = sig.parameters[i].ValueDeclaration;
			final typeNode = declaration.Type();
			if (typeNode != null) {
				final source = c.addOptionalityEx(c.getTypeFromTypeNode(typeNode), false /*isProperty*/, Checker.isOptionalDeclaration(declaration));
				final target = c.getTypeAtPosition(context, i);
				c.inferTypes(inferenceContext.inferences, source, target, InferencePriorityNone, false);
			}
		}
		final declaration = sig.Declaration();
		if (declaration != null) {
			final returnTypeNode = declaration.Type();
			if (returnTypeNode != null) {
				final source = c.getTypeFromTypeNode(returnTypeNode);
				final target = c.getReturnTypeOfSignature(context);
				c.inferTypes(inferenceContext.inferences, source, target, InferencePriorityNone, false);
			}
		}
	}

	// Return the contextual signature for a given expression node. A contextual type provides a
	// contextual signature if it has a single call signature and if that call signature is non-generic.
	// If the contextual type is a union type, get the signature from each type possible and if they are
	// all identical ignoring their return type, the result is same signature but with return type as
	// union type of return types from these signatures
	static function getContextualSignature(c:Checker, node:Node):Signature {
		final t = c.getApparentTypeOfContextualType(node, ContextFlagsSignature);
		if (t == null) {
			return null;
		}
		if (t.flags & TypeFlagsUnion == 0) {
			return c.getContextualCallSignature(t, node);
		}
		var signatureList:Array<Signature> = null;
		final types = t.Types();
		for (current in types) {
			final signature = c.getContextualCallSignature(current, node);
			if (signature != null) {
				if (Core.len(signatureList) != 0
					&& c.compareSignaturesIdentical(signatureList[0], signature, false /*partialMatch*/, true /*ignoreThisTypes*/, true /*ignoreReturnTypes*/,
						c.compareTypesIdentical) == TernaryFalse) {
					// Signatures aren't identical, do not use
					return null;
				}
				// Use this signature for contextual union signature
				if (signatureList == null) {
					signatureList = [];
				}
				signatureList.push(signature);
			}
		}
		switch (Core.len(signatureList)) {
			case 0:
				return null;
			case 1:
				return signatureList[0];
			default:
		}
		// Result is union of signatures collected (return type is union of return types of this signature set)
		return c.createUnionSignature(signatureList[0], signatureList);
	}

	static function createUnionSignature(c:Checker, sig:Signature, unionSignatures:Array<Signature>):Signature {
		final result = c.cloneSignature(sig);
		final composite = new CompositeSignature();
		composite.isUnion = true;
		composite.signatures = unionSignatures;
		result.composite = composite;
		result.target = null;
		result.mapper = null;
		return result;
	}

	// If the given type is an object or union type with a single signature, and if that signature has at
	// least as many parameters as the given function, return the signature. Otherwise return undefined.
	static function getContextualCallSignature(c:Checker, t:Type, node:Node):Signature {
		final signatures = c.getSignaturesOfType(t, SignatureKindCall);
		final applicableByArity = Core.Filter(signatures, (s:Signature) -> {
			return !c.isAritySmaller(s, node);
		});
		if (Core.len(applicableByArity) == 1) {
			return applicableByArity[0];
		}
		return c.getIntersectedSignatures(applicableByArity);
	}

	static function getIntersectedSignatures(c:Checker, signatures:Array<Signature>):Signature {
		if (!c.noImplicitAny) {
			return null;
		}
		var combined:Signature = null;
		if (signatures != null) {
			for (sig in signatures) {
				if (combined == sig || combined == null) {
					combined = sig;
				} else if (c.compareTypeParametersIdentical(combined.typeParameters, sig.typeParameters)) {
					combined = c.combineUnionOrIntersectionMemberSignatures(combined, sig, false /*isUnion*/);
				} else {
					return null;
				}
			}
		}
		return combined;
	}

	/** If the contextual signature has fewer parameters than the function expression, do not use it */
	static function isAritySmaller(c:Checker, signature:Signature, target:Node):Bool {
		final parameters = target.Parameters();
		var targetParameterCount = 0;
		while (targetParameterCount < Core.len(parameters)) {
			final param = parameters[targetParameterCount];
			if (param.Initializer() != null || param.QuestionToken() != null || Checker.hasDotDotDotToken(param)) {
				break;
			}
			targetParameterCount++;
		}
		if (Core.len(parameters) != 0 && Ast.IsThisParameter(parameters[0])) {
			targetParameterCount--;
		}
		return !c.hasEffectiveRestParameter(signature) && c.getParameterCount(signature) < targetParameterCount;
	}

	static function assignContextualParameterTypes(c:Checker, sig:Signature, context:Signature):Void {
		if (Core.len(context.typeParameters) != 0) {
			if (Core.len(sig.typeParameters) != 0) {
				// This signature has already has a contextual inference performed and cached on it
				return;
			}
			sig.typeParameters = context.typeParameters;
		}
		if (context.thisParameter != null) {
			final parameter = sig.thisParameter;
			if (parameter == null || parameter.ValueDeclaration != null && parameter.ValueDeclaration.Type() == null) {
				if (parameter == null) {
					sig.thisParameter = c.createSymbolWithType(context.thisParameter, null /*type*/);
				}
				c.assignParameterType(sig.thisParameter, c.getTypeOfSymbol(context.thisParameter));
			}
		}
		final length = Core.len(sig.parameters) - Core.IfElse(Checker.signatureHasRestParameter(sig), 1, 0);
		for (i in 0...length) {
			final parameter = sig.parameters[i];
			final declaration = parameter.ValueDeclaration;
			if (declaration.Type() == null) {
				var t = c.tryGetTypeAtPosition(context, i);
				if (t != null && declaration.Initializer() != null) {
					var initializerType = c.checkDeclarationInitializer(declaration, CheckModeNormal, null);
					if (!c.isTypeAssignableTo(initializerType, t)) {
						initializerType = c.widenTypeInferredFromInitializer(declaration, initializerType);
						if (c.isTypeAssignableTo(t, initializerType)) {
							t = initializerType;
						}
					}
				}
				c.assignParameterType(parameter, t);
			}
		}
		if (Checker.signatureHasRestParameter(sig)) {
			// parameter might be a transient symbol generated by use of `arguments` in the function body.
			final parameter = Core.LastOrNil(sig.parameters);
			if (parameter.ValueDeclaration != null && parameter.ValueDeclaration.Type() == null
				|| parameter.ValueDeclaration == null && parameter.CheckFlags & CheckFlagsDeferredType != 0) {
				final contextualParameterType = c.getRestTypeAtPosition(context, length, false);
				c.assignParameterType(parameter, contextualParameterType);
			}
		}
	}

	static function assignNonContextualParameterTypes(c:Checker, signature:Signature):Void {
		if (signature.thisParameter != null) {
			c.assignParameterType(signature.thisParameter, null);
		}
		if (signature.parameters != null) {
			for (parameter in signature.parameters) {
				c.assignParameterType(parameter, null);
			}
		}
	}

	static function assignParameterType(c:Checker, parameter:Symbol, contextualType:Type):Void {
		final links = c.valueSymbolLinks.Get(parameter);
		if (links.resolvedType != null) {
			return;
		}
		final declaration = parameter.ValueDeclaration;
		var t = contextualType;
		if (t == null) {
			if (declaration != null) {
				t = c.getWidenedTypeForVariableLikeDeclaration(declaration, true /*reportErrors*/);
			} else {
				t = c.getTypeOfSymbol(parameter);
			}
		}
		links.resolvedType = c.addOptionalityEx(t, false, declaration != null && declaration.Initializer() == null && Checker.isOptionalDeclaration(declaration));
		if (declaration != null && !Ast.IsIdentifier(declaration.Name())) {
			// if inference didn't come up with anything but unknown, fall back to the binding pattern if present.
			if (links.resolvedType == c.unknownType) {
				links.resolvedType = c.getTypeFromBindingPattern(declaration.Name(), false, false);
			}
			c.assignBindingElementTypes(declaration.Name(), links.resolvedType);
		}
	}

	// When contextual typing assigns a type to a parameter that contains a binding pattern, we also need to push
	// the destructured type into the contained binding elements.
	static function assignBindingElementTypes(c:Checker, pattern:Node, parentType:Type):Void {
		final elements = pattern.Elements();
		if (elements != null) {
			for (element in elements) {
				final name = element.Name();
				if (name != null) {
					final t = c.getBindingElementTypeFromParentType(element, parentType, false /*noTupleBoundsCheck*/);
					if (Ast.IsIdentifier(name)) {
						c.valueSymbolLinks.Get(c.getSymbolOfDeclaration(element)).resolvedType = t;
					} else {
						c.assignBindingElementTypes(name, t);
					}
				}
			}
		}
	}

	static function checkCollisionsForDeclarationName(c:Checker, node:Node, name:Node):Void {
		if (name == null) {
			return;
		}
		c.checkCollisionWithRequireExportsInGeneratedCode(node, name);
		c.checkCollisionWithGlobalObjectInGeneratedCode(node, name);
		c.checkCollisionWithGlobalPromiseInGeneratedCode(node, name);
		c.recordPotentialCollisionWithWeakMapSetInGeneratedCode(node, name);
		c.recordPotentialCollisionWithReflectInGeneratedCode(node, name);
		if (Ast.IsClassLike(node)) {
			c.checkTypeNameIsReserved(name, Diagnostics.Class_name_cannot_be_0);
			if (node.Flags & NodeFlagsAmbient == 0) {
				c.checkClassNameCollisionWithObject(name);
			}
		} else if (Ast.IsEnumDeclaration(node)) {
			c.checkTypeNameIsReserved(name, Diagnostics.Enum_name_cannot_be_0);
		}
	}

	static function checkCollisionWithRequireExportsInGeneratedCode(c:Checker, node:Node, name:Node):Void {
		// No need to check for require or exports for ES6 modules and later
		if (c.program.GetEmitModuleFormatOfFile(hasFileName(Ast.GetSourceFileOfNode(node))) >= ModuleKindES2015) {
			return;
		}
		if (name == null || !c.needCollisionCheckForIdentifier(node, name, "require") && !c.needCollisionCheckForIdentifier(node, name, "exports")) {
			return;
		}
		// Uninstantiated modules shouldnt do this check
		if (Ast.IsModuleDeclaration(node) && Ast.GetModuleInstanceState(node) != ModuleInstanceStateInstantiated) {
			return;
		}
		// In case of variable declaration, node.parent is variable statement so look at the variable statement's parent
		final parent = Ast.GetDeclarationContainer(node);
		if (Ast.IsSourceFile(parent) && Ast.IsExternalOrCommonJSModule(parent.AsSourceFile())) {
			// If the declaration happens to be in external module, report error that require and exports are reserved keywords
			c.errorSkippedOnNoEmit(name, Diagnostics.Duplicate_identifier_0_Compiler_reserves_name_1_in_top_level_scope_of_a_module,
				Scanner.DeclarationNameToString(name), Scanner.DeclarationNameToString(name));
		}
	}

	static function checkCollisionWithGlobalObjectInGeneratedCode(c:Checker, node:Node, name:Node):Void {
		if (name == null || Ast.IsClassLike(node) || !c.needCollisionCheckForIdentifier(node, name, "Object")) {
			return;
		}
		// Uninstantiated modules shouldn't do this check
		if (Ast.IsModuleDeclaration(node) && Ast.GetModuleInstanceState(node) != ModuleInstanceStateInstantiated) {
			return;
		}
		// In case of variable declaration, node.parent is variable statement so look at the variable statement's parent
		final parent = Ast.GetDeclarationContainer(node);
		if (Ast.IsSourceFile(parent) && Ast.IsExternalOrCommonJSModule(parent.AsSourceFile())
			&& c.program.GetEmitModuleFormatOfFile(hasFileName(parent.AsSourceFile())) == ModuleKindCommonJS) {
			// If the declaration happens to be in external module, report error that Object is a reserved identifier.
			c.errorSkippedOnNoEmit(name, Diagnostics.Duplicate_identifier_0_Compiler_reserves_name_1_in_top_level_scope_of_a_module,
				Scanner.DeclarationNameToString(name), Scanner.DeclarationNameToString(name));
		}
	}

	static function needCollisionCheckForIdentifier(c:Checker, node:Node, identifier:Node, name:std.String):Bool {
		if (identifier != null && identifier.Text() != name) {
			return false;
		}
		switch (node.Kind) {
			case KindPropertyDeclaration, KindPropertySignature, KindMethodDeclaration, KindMethodSignature, KindGetAccessor, KindSetAccessor,
				KindPropertyAssignment:
				// it is ok to have member named '_super', '_this', `Promise`, etc. - member access is always qualified
				return false;
			default:
		}
		if (node.Flags & NodeFlagsAmbient != 0) {
			// ambient context - no codegen impact
			return false;
		}
		if (Ast.IsImportClause(node) || Ast.IsImportEqualsDeclaration(node) || Ast.IsImportSpecifier(node)) {
			// type-only imports do not require collision checks against runtime values.
			if (Ast.IsTypeOnlyImportOrExportDeclaration(node)) {
				return false;
			}
		}
		final root = Ast.GetRootDeclaration(node);
		if (Ast.IsParameterDeclaration(root) && Ast.NodeIsMissing(root.Parent.Body())) {
			// just an overload - no codegen impact
			return false;
		}
		return true;
	}

	static function setNodeLinksForPrivateIdentifierScope(c:Checker, node:Node):Void {
		final name = node.Name();
		if (Ast.IsPrivateIdentifier(name)) {
			if (c.languageVersion < Checker.LanguageFeatureMinimumTarget.PrivateNamesAndClassStaticBlocks
				|| c.languageVersion < Checker.LanguageFeatureMinimumTarget.ClassAndClassElementDecorators
				|| !c.compilerOptions.GetUseDefineForClassFields()) {
				var lexicalScope = Ast.GetEnclosingBlockScopeContainer(node);
				while (lexicalScope != null) {
					c.nodeLinks.Get(lexicalScope).flags |= NodeCheckFlagsContainsClassWithPrivateIdentifiers;
					lexicalScope = Ast.GetEnclosingBlockScopeContainer(lexicalScope);
				}
			}
		}
	}

	static function recordPotentialCollisionWithWeakMapSetInGeneratedCode(c:Checker, node:Node, name:Node):Void {
		if (c.languageVersion <= ScriptTargetES2021
			&& (c.needCollisionCheckForIdentifier(node, name, "WeakMap") || c.needCollisionCheckForIdentifier(node, name, "WeakSet"))) {
			c.addDeferredDiagnostic(() -> {
				c.checkWeakMapSetCollision(node);
			});
		}
	}

	static function checkWeakMapSetCollision(c:Checker, node:Node):Void {
		final enclosingBlockScope = Ast.GetEnclosingBlockScopeContainer(node);
		if (c.nodeLinks.Get(enclosingBlockScope).flags & NodeCheckFlagsContainsClassWithPrivateIdentifiers != 0) {
			final name = node.Name();
			if (name != null && Ast.IsIdentifier(name)) {
				c.errorSkippedOnNoEmit(node, Diagnostics.Compiler_reserves_name_0_when_emitting_private_identifier_downlevel, name.Text());
			}
		}
	}

	static function checkCollisionWithGlobalPromiseInGeneratedCode(c:Checker, node:Node, name:Node):Void {
		if (name == null || c.languageVersion >= ScriptTargetES2017 || !c.needCollisionCheckForIdentifier(node, name, "Promise")) {
			return;
		}
		// Uninstantiated modules shouldn't do this check
		if (Ast.IsModuleDeclaration(node) && Ast.GetModuleInstanceState(node) != ModuleInstanceStateInstantiated) {
			return;
		}
		// In case of variable declaration, node.parent is variable statement so look at the variable statement's parent
		final parent = Ast.GetDeclarationContainer(node);
		if (Ast.IsSourceFile(parent) && Ast.IsExternalOrCommonJSModule(parent.AsSourceFile()) && parent.Flags & NodeFlagsHasAsyncFunctions != 0) {
			// If the declaration happens to be in external module, report error that Promise is a reserved identifier.
			c.errorSkippedOnNoEmit(name, Diagnostics.Duplicate_identifier_0_Compiler_reserves_name_1_in_top_level_scope_of_a_module_containing_async_functions,
				Scanner.DeclarationNameToString(name), Scanner.DeclarationNameToString(name));
		}
	}

	static function recordPotentialCollisionWithReflectInGeneratedCode(c:Checker, node:Node, name:Node):Void {
		if (name != null && c.languageVersion <= ScriptTargetES2021 && c.needCollisionCheckForIdentifier(node, name, "Reflect")) {
			c.addDeferredDiagnostic(() -> {
				c.checkReflectCollision(node);
			});
		}
	}

	static function checkReflectCollision(c:Checker, node:Node):Void {
		var hasCollision = false;
		if (Ast.IsClassExpression(node)) {
			// ClassExpression names don't contribute to their containers, but do matter for any of their block-scoped members.
			final members = node.Members();
			if (members != null) {
				for (member in members) {
					if (c.nodeLinks.Get(member).flags & NodeCheckFlagsContainsSuperPropertyInStaticInitializer != 0) {
						hasCollision = true;
						break;
					}
				}
			}
		} else if (Ast.IsFunctionExpression(node)) {
			// FunctionExpression names don't contribute to their containers, but do matter for their contents
			if (c.nodeLinks.Get(node).flags & NodeCheckFlagsContainsSuperPropertyInStaticInitializer != 0) {
				hasCollision = true;
			}
		} else {
			final container = Ast.GetEnclosingBlockScopeContainer(node);
			if (container != null && c.nodeLinks.Get(container).flags & NodeCheckFlagsContainsSuperPropertyInStaticInitializer != 0) {
				hasCollision = true;
			}
		}
		if (hasCollision) {
			final name = node.Name();
			if (name != null && Ast.IsIdentifier(name)) {
				c.errorSkippedOnNoEmit(node, Diagnostics.Duplicate_identifier_0_Compiler_reserves_name_1_when_emitting_super_references_in_static_initializers,
					Scanner.DeclarationNameToString(name), "Reflect");
			}
		}
	}

	static function checkClassNameCollisionWithObject(c:Checker, name:Node):Void {
		if (name.Text() == "Object" && c.program.GetEmitModuleFormatOfFile(hasFileName(Ast.GetSourceFileOfNode(name))) < ModuleKindES2015) {
			c.error(name, Diagnostics.Class_name_cannot_be_Object_when_targeting_ES5_and_above_with_module_0, c.moduleKind.String());
		}
	}

	static function checkTypeOfExpression(c:Checker, node:Node):Type {
		c.checkExpression(node.Expression());
		return c.typeofType;
	}

	static function checkNonNullAssertion(c:Checker, node:Node):Type {
		if (node.Flags & NodeFlagsOptionalChain != 0) {
			return c.checkNonNullChain(node);
		}
		return c.GetNonNullableType(c.checkExpression(node.Expression()));
	}

	static function checkNonNullChain(c:Checker, node:Node):Type {
		final leftType = c.checkExpression(node.Expression());
		final nonOptionalType = c.getOptionalExpressionType(leftType, node.Expression());
		return c.propagateOptionalTypeMarker(c.GetNonNullableType(nonOptionalType), node, nonOptionalType != leftType);
	}

	static function checkExpressionWithTypeArguments(c:Checker, node:Node):Type {
		c.checkGrammarExpressionWithTypeArguments(node);
		c.checkSourceElements(node.TypeArguments());
		if (Ast.IsExpressionWithTypeArguments(node)) {
			final parent = Ast.WalkUpParenthesizedExpressions(node.Parent);
			if (Ast.IsBinaryExpression(parent) && parent.AsBinaryExpression().OperatorToken.Kind == KindInstanceOfKeyword
				&& Checker.isNodeDescendantOf(node, parent.AsBinaryExpression().Right)) {
				c.error(node, Diagnostics.The_right_hand_side_of_an_instanceof_expression_must_not_be_an_instantiation_expression);
			}
		}
		var exprType:Type = null;
		if (Ast.IsExpressionWithTypeArguments(node)) {
			exprType = c.checkExpression(node.Expression());
		} else {
			final exprName = node.AsTypeQueryNode().ExprName;
			if (Ast.IsThisIdentifier(exprName)) {
				exprType = c.checkThisExpression(node.AsTypeQueryNode().ExprName);
			} else {
				exprType = c.checkExpression(node.AsTypeQueryNode().ExprName);
			}
		}
		return c.getInstantiationExpressionType(exprType, node);
	}

	static function getInstantiationExpressionType(c:Checker, exprType:Type, node:Node):Type {
		final typeArguments = node.TypeArgumentList();
		if (exprType == c.silentNeverType || c.isErrorType(exprType) || typeArguments == null) {
			return exprType;
		}
		final key = InstantiationExpressionKey.keyOf(Ast.GetNodeId(node), exprType.id);
		final cached = c.instantiationExpressionTypes.get(key);
		if (cached != null) {
			return cached;
		}
		var hasSomeApplicableSignature = false;
		var nonApplicableType:Type = null;
		final getInstantiatedSignatures = (signatures:Array<Signature>) -> {
			final applicableSignatures = Core.Filter(signatures, (sig:Signature) -> {
				return Core.len(sig.typeParameters) != 0 && c.hasCorrectTypeArgumentArity(sig, typeArguments.Nodes);
			});
			return Core.SameMap(applicableSignatures, (sig:Signature) -> {
				final typeArgumentTypes = c.checkTypeArguments(sig, typeArguments.Nodes, true /*reportErrors*/, null);
				if (typeArgumentTypes != null) {
					return c.getSignatureInstantiation(sig, typeArgumentTypes, Ast.IsInJSFile(sig.declaration), null);
				}
				return sig;
			});
		};
		var getInstantiatedType:(Type) -> Type = null;
		getInstantiatedType = (t:Type) -> {
			var hasSignatures = false;
			var hasApplicableSignature = false;
			var getInstantiatedTypePart:(Type) -> Type = null;
			getInstantiatedTypePart = (t:Type) -> {
				if (t.flags & TypeFlagsObject != 0) {
					final resolved = c.resolveStructuredTypeMembers(t);
					final callSignatures = getInstantiatedSignatures(resolved.CallSignatures());
					final constructSignatures = getInstantiatedSignatures(resolved.ConstructSignatures());
					hasSignatures = hasSignatures || Core.len(resolved.CallSignatures()) != 0 || Core.len(resolved.ConstructSignatures()) != 0;
					hasApplicableSignature = hasApplicableSignature || Core.len(callSignatures) != 0 || Core.len(constructSignatures) != 0;
					if (!Core.Same(callSignatures, resolved.CallSignatures()) || !Core.Same(constructSignatures, resolved.ConstructSignatures())) {
						final result = c.newObjectType(ObjectFlagsAnonymous | (Checker.ObjectFlagsInstantiationExpressionType : ObjectFlags),
							c.newSymbol(SymbolFlagsNone, Ast.InternalSymbolNameInstantiationExpression));
						c.setStructuredTypeMembers(result, resolved.members, callSignatures, constructSignatures, resolved.indexInfos);
						result.AsInstantiationExpressionType().node = node;
						return result;
					}
				} else if (t.flags & TypeFlagsInstantiableNonPrimitive != 0) {
					final constraint = c.getBaseConstraintOfType(t);
					if (constraint != null) {
						final instantiated = getInstantiatedTypePart(constraint);
						if (instantiated != constraint) {
							return instantiated;
						}
					}
				} else if (t.flags & TypeFlagsUnion != 0) {
					return c.mapType(t, getInstantiatedType);
				} else if (t.flags & TypeFlagsIntersection != 0) {
					return c.getIntersectionType(Core.SameMap(t.AsIntersectionType().types, getInstantiatedTypePart));
				}
				return t;
			};
			final result = getInstantiatedTypePart(t);
			hasSomeApplicableSignature = hasSomeApplicableSignature || hasApplicableSignature;
			if (hasSignatures && !hasApplicableSignature) {
				if (nonApplicableType == null) {
					nonApplicableType = t;
				}
			}
			return result;
		};
		final result = getInstantiatedType(exprType);
		c.instantiationExpressionTypes.set(key, result);
		var errorType:Type = null;
		if (hasSomeApplicableSignature) {
			errorType = nonApplicableType;
		} else {
			errorType = exprType;
		}
		if (errorType != null) {
			final sourceFile = Ast.GetSourceFileOfNode(node);
			final loc = Core.NewTextRange(Scanner.SkipTrivia(sourceFile.Text(), typeArguments.Pos()), typeArguments.End());
			c.addDiagnostic(Ast.NewDiagnostic(sourceFile, loc, Diagnostics.Type_0_has_no_signatures_for_which_the_type_argument_list_is_applicable,
				c.TypeToString(errorType)));
		}
		return result;
	}

	static function checkSatisfiesExpression(c:Checker, node:Node):Type {
		final typeNode = node.Type();
		c.checkSourceElement(typeNode);
		final exprType = c.checkExpression(node.Expression());
		final targetType = c.getTypeFromTypeNode(typeNode);
		if (c.isErrorType(targetType)) {
			return targetType;
		}
		c.checkTypeAssignableToAndOptionallyElaborate(exprType, targetType, node, node.Expression(), Diagnostics.Type_0_does_not_satisfy_the_expected_type_1,
			null);
		return exprType;
	}

	static function checkMetaProperty(c:Checker, node:Node):Type {
		c.checkGrammarMetaProperty(node.AsMetaProperty());
		switch (node.AsMetaProperty().KeywordToken) {
			case KindNewKeyword:
				return c.checkNewTargetMetaProperty(node);
			case KindImportKeyword:
				if (node.Name().Text() == "defer") {
					Debug.Assert(!Ast.IsCallExpression(node.Parent) || node.Parent.Expression() != node,
						"Trying to get the type of `import.defer` in `import.defer(...)`");
					return c.errorType;
				}
				return c.checkImportMetaProperty(node);
			default:
		}
		throw "Unhandled case in checkMetaProperty";
	}

	static function checkNewTargetMetaProperty(c:Checker, node:Node):Type {
		final container = Ast.GetNewTargetContainer(node);
		if (container == null) {
			c.error(node, Diagnostics.Meta_property_0_is_only_allowed_in_the_body_of_a_function_declaration_function_expression_or_constructor, "new.target");
			return c.errorType;
		}
		if (Ast.IsConstructorDeclaration(container)) {
			final symbol = c.getSymbolOfDeclaration(container.Parent);
			return c.getTypeOfSymbol(symbol);
		}
		final symbol = c.getSymbolOfDeclaration(container);
		return c.getTypeOfSymbol(symbol);
	}

	static function checkImportMetaProperty(c:Checker, node:Node):Type {
		if (ModuleKindNode16 <= c.moduleKind && c.moduleKind <= ModuleKindNodeNext) {
			final sourceFileMetaData = c.program.GetSourceFileMetaData(Ast.GetSourceFileOfNode(node).Path());
			if (sourceFileMetaData.ImpliedNodeFormat != ModuleKindESNext) {
				c.error(node, Diagnostics.The_import_meta_meta_property_is_not_allowed_in_files_which_will_build_into_CommonJS_output);
			}
		} else if (c.moduleKind < ModuleKindES2020 && c.moduleKind != ModuleKindSystem) {
			c.error(node,
				Diagnostics.The_import_meta_meta_property_is_only_allowed_when_the_module_option_is_es2020_es2022_esnext_system_node16_node18_node20_or_nodenext);
		}
		final file = Ast.GetSourceFileOfNode(node);
		Debug.Assert(file.Flags & NodeFlagsPossiblyContainsImportMeta != 0, "Containing file is missing import meta node flag.");
		if (node.Name().Text() == "meta") {
			return c.getGlobalImportMetaType();
		}
		return c.errorType;
	}

	static function checkMetaPropertyKeyword(c:Checker, node:Node):Type {
		// !!! This is effectively a helper for GetSymbolAtLocation and GetTypeAtLocation
		return c.errorType;
	}

	static function checkDeleteExpression(c:Checker, node:Node):Type {
		c.checkExpression(node.Expression());
		final expr = Ast.SkipParentheses(node.Expression());
		if (!Ast.IsAccessExpression(expr)) {
			c.error(expr, Diagnostics.The_operand_of_a_delete_operator_must_be_a_property_reference);
			return c.booleanType;
		}
		if (Ast.IsPropertyAccessExpression(expr) && Ast.IsPrivateIdentifier(expr.Name())) {
			c.error(expr, Diagnostics.The_operand_of_a_delete_operator_cannot_be_a_private_identifier);
		}
		final symbol = c.getExportSymbolOfValueSymbolIfExported(c.getResolvedSymbolOrNil(expr));
		if (symbol != null) {
			if (c.isReadonlySymbol(symbol)) {
				c.error(expr, Diagnostics.The_operand_of_a_delete_operator_cannot_be_a_read_only_property);
			} else {
				c.checkDeleteExpressionMustBeOptional(expr, symbol);
			}
		}
		return c.booleanType;
	}

	static function checkDeleteExpressionMustBeOptional(c:Checker, expr:Node, symbol:Symbol):Void {
		final t = c.getTypeOfSymbol(symbol);
		if (c.strictNullChecks && t.flags & (TypeFlagsAnyOrUnknown | TypeFlagsNever) == 0) {
			var isOptional = false;
			if (c.exactOptionalPropertyTypes) {
				isOptional = symbol.Flags & SymbolFlagsOptional != 0;
			} else {
				isOptional = c.hasTypeFacts(t, TypeFactsIsUndefined);
			}
			if (!isOptional) {
				c.error(expr, Diagnostics.The_operand_of_a_delete_operator_must_be_optional);
			}
		}
	}

	static function checkVoidExpression(c:Checker, node:Node):Type {
		c.checkNodeDeferred(node);
		return c.undefinedWideningType;
	}

	static function checkAwaitExpression(c:Checker, node:Node):Type {
		c.checkGrammarAwaitOrAwaitUsing(node);
		final operandType = c.checkExpression(node.Expression());
		final awaitedType = c.checkAwaitedType(operandType, true /*withAlias*/, node,
			Diagnostics.Type_of_await_operand_must_either_be_a_valid_promise_or_must_not_contain_a_callable_then_member);
		if (awaitedType == operandType && !c.isErrorType(awaitedType) && operandType.flags & TypeFlagsAnyOrUnknown == 0) {
			c.addErrorOrSuggestion(false, Checker.createDiagnosticForNode(node, Diagnostics.X_await_has_no_effect_on_the_type_of_this_expression));
		}
		return awaitedType;
	}

	static function checkPrefixUnaryExpression(c:Checker, node:Node):Type {
		final expr = node.AsPrefixUnaryExpression();
		final operandType = c.checkExpression(expr.Operand);
		if (operandType == c.silentNeverType) {
			return c.silentNeverType;
		}
		switch (expr.Operand.Kind) {
			case KindNumericLiteral:
				switch (expr.Operator) {
					case KindMinusToken:
						return c.getFreshTypeOfLiteralType(c.getNumberLiteralType(-Jsnum.FromString(expr.Operand.Text())));
					case KindPlusToken:
						return c.getFreshTypeOfLiteralType(c.getNumberLiteralType(Jsnum.FromString(expr.Operand.Text())));
					default:
				}
			case KindBigIntLiteral:
				if (expr.Operator == KindMinusToken) {
					return c.getFreshTypeOfLiteralType(c.getBigIntLiteralType(Jsnum.NewPseudoBigInt(Jsnum.ParsePseudoBigInt(expr.Operand.Text()), true /*negative*/)));
				}
			default:
		}
		switch (expr.Operator) {
			case KindPlusToken, KindMinusToken, KindTildeToken:
				c.checkNonNullType(operandType, expr.Operand);
				if (c.maybeTypeOfKindConsideringBaseConstraint(operandType, TypeFlagsESSymbolLike)) {
					c.error(expr.Operand, Diagnostics.The_0_operator_cannot_be_applied_to_type_symbol, Scanner.TokenToString(expr.Operator));
				}
				if (expr.Operator == KindPlusToken) {
					if (c.maybeTypeOfKindConsideringBaseConstraint(operandType, TypeFlagsBigIntLike)) {
						c.error(expr.Operand, Diagnostics.Operator_0_cannot_be_applied_to_type_1, Scanner.TokenToString(expr.Operator),
							c.TypeToString(c.getBaseTypeOfLiteralType(operandType)));
					}
					return c.numberType;
				}
				return c.getUnaryResultType(operandType);
			case KindExclamationToken:
				c.checkTruthinessOfType(operandType, expr.Operand);
				final facts = c.getTypeFacts(operandType, TypeFactsTruthy | TypeFactsFalsy);
				if (facts == TypeFactsTruthy) {
					return c.falseType;
				} else if (facts == TypeFactsFalsy) {
					return c.trueType;
				} else {
					return c.booleanType;
				}
			case KindPlusPlusToken, KindMinusMinusToken:
				final ok = c.checkArithmeticOperandType(expr.Operand, c.checkNonNullType(operandType, expr.Operand),
					Diagnostics.An_arithmetic_operand_must_be_of_type_any_number_bigint_or_an_enum_type, false);
				if (ok) {
					// run check only if former checks succeeded to avoid reporting cascading errors
					c.checkReferenceExpression(expr.Operand, Diagnostics.The_operand_of_an_increment_or_decrement_operator_must_be_a_variable_or_a_property_access,
						Diagnostics.The_operand_of_an_increment_or_decrement_operator_may_not_be_an_optional_property_access);
				}
				return c.getUnaryResultType(operandType);
			default:
		}
		return c.errorType;
	}

	static function checkPostfixUnaryExpression(c:Checker, node:Node):Type {
		final expr = node.AsPostfixUnaryExpression();
		final operandType = c.checkExpression(expr.Operand);
		if (operandType == c.silentNeverType) {
			return c.silentNeverType;
		}
		final ok = c.checkArithmeticOperandType(expr.Operand, c.checkNonNullType(operandType, expr.Operand),
			Diagnostics.An_arithmetic_operand_must_be_of_type_any_number_bigint_or_an_enum_type, false);
		if (ok) {
			// run check only if former checks succeeded to avoid reporting cascading errors
			c.checkReferenceExpression(expr.Operand, Diagnostics.The_operand_of_an_increment_or_decrement_operator_must_be_a_variable_or_a_property_access,
				Diagnostics.The_operand_of_an_increment_or_decrement_operator_may_not_be_an_optional_property_access);
		}
		return c.getUnaryResultType(operandType);
	}

	static function getUnaryResultType(c:Checker, operandType:Type):Type {
		if (c.maybeTypeOfKind(operandType, TypeFlagsBigIntLike)) {
			if (c.isTypeAssignableToKind(operandType, TypeFlagsAnyOrUnknown) || c.maybeTypeOfKind(operandType, TypeFlagsNumberLike)) {
				return c.numberOrBigIntType;
			}
			return c.bigintType;
		}
		// If it's not a bigint type, implicit coercion will result in a number
		return c.numberType;
	}

	static function checkConditionalExpression(c:Checker, node:Node, checkMode:CheckMode):Type {
		final cond = node.AsConditionalExpression();
		final t = c.checkTruthinessExpression(cond.Condition, checkMode);
		c.checkTestingKnownTruthyCallableOrAwaitableOrEnumMemberType(cond.Condition, t, cond.WhenTrue);
		final type1 = c.checkExpressionEx(cond.WhenTrue, checkMode);
		final type2 = c.checkExpressionEx(cond.WhenFalse, checkMode);
		return c.getUnionTypeEx([type1, type2], UnionReductionSubtype, null, null);
	}

	static function checkTruthinessExpression(c:Checker, node:Node, checkMode:CheckMode):Type {
		return c.checkTruthinessOfType(c.checkExpressionEx(node, checkMode), node);
	}

	static function checkSpreadExpression(c:Checker, node:Node, checkMode:CheckMode):Type {
		final arrayOrIterableType = c.checkExpressionEx(node.Expression(), checkMode);
		return c.checkIteratedTypeOrElementType(IterationUseSpread, arrayOrIterableType, c.undefinedType, node.Expression());
	}

	static function checkYieldExpression(c:Checker, node:Node):Type {
		c.checkGrammarYieldExpression(node);
		final fn = Ast.GetContainingFunction(node);
		if (fn == null) {
			return c.anyType;
		}
		final functionFlags = Ast.GetFunctionFlags(fn);
		if (functionFlags & FunctionFlagsGenerator == 0) {
			// If the user's code is syntactically correct, the func should always have a star. After all, we are in a yield context.
			return c.anyType;
		}
		final isAsync = (functionFlags & FunctionFlagsAsync) != 0;
		if (node.AsYieldExpression().AsteriskToken != null) {
			// Async generator functions prior to ES2018 require the __await, __asyncDelegator,
			// and __asyncValues helpers
			if (isAsync && c.languageVersion < Checker.LanguageFeatureMinimumTarget.AsyncGenerators) {
				c.checkExternalEmitHelpers(node, ExternalEmitHelpersAsyncDelegatorIncludes);
			}
		}
		// There is no point in doing an assignability check if the function
		// has no explicit return type because the return type is directly computed
		// from the yield expressions.
		var returnType = c.getReturnTypeFromAnnotation(fn);
		if (returnType != null && returnType.flags & TypeFlagsUnion != 0) {
			returnType = c.filterType(returnType, (t:Type) -> {
				return c.checkGeneratorInstantiationAssignabilityToReturnType(t, functionFlags, null /*errorNode*/);
			});
		}
		var iterationTypes = new IterationTypes();
		if (returnType != null) {
			iterationTypes = c.getIterationTypesOfGeneratorFunctionReturnType(returnType, isAsync);
		}
		final signatureYieldType = Core.OrElse(iterationTypes.yieldType, c.anyType);
		final signatureNextType = Core.OrElse(iterationTypes.nextType, c.anyType);
		var yieldExpressionType:Type = null;
		if (node.Expression() != null) {
			yieldExpressionType = c.checkExpression(node.Expression());
		} else {
			yieldExpressionType = c.undefinedWideningType;
		}
		final yieldedType = c.getYieldedTypeOfYieldExpression(node, yieldExpressionType, signatureNextType, isAsync);
		if (returnType != null && yieldedType != null) {
			c.checkTypeAssignableToAndOptionallyElaborate(yieldedType, signatureYieldType, Core.OrElse(node.Expression(), node), node.Expression(), null, null);
		}
		if (node.AsYieldExpression().AsteriskToken != null) {
			final use = Core.IfElse(isAsync, IterationUseAsyncYieldStar, IterationUseYieldStar);
			return Core.OrElse(c.getIterationTypeOfIterable(use, IterationTypeKindReturn, yieldExpressionType, node.Expression()), c.anyType);
		}
		if (returnType != null) {
			return Core.OrElse(c.getIterationTypeOfGeneratorFunctionReturnType(IterationTypeKindNext, returnType, isAsync), c.anyType);
		}
		var t = c.getContextualIterationType(IterationTypeKindNext, fn);
		if (t == null) {
			t = c.anyType;
			if (c.noImplicitAny && !Checker.expressionResultIsUnused(node)) {
				final contextualType = c.getContextualType(node, ContextFlagsNone);
				if (contextualType == null || Checker.IsTypeAny(contextualType)) {
					c.error(node,
						Diagnostics.X_yield_expression_implicitly_results_in_an_any_type_because_its_containing_generator_lacks_a_return_type_annotation);
				}
			}
		}
		return t;
	}

	static function getYieldedTypeOfYieldExpression(c:Checker, node:Node, expressionType:Type, sentType:Type, isAsync:Bool):Type {
		final errorNode = Core.OrElse(node.Expression(), node);
		final isYieldStar = node.AsYieldExpression().AsteriskToken != null;
		// A `yield*` expression effectively yields everything that its operand yields
		var yieldedType = expressionType;
		if (isYieldStar) {
			yieldedType = c.checkIteratedTypeOrElementType(Core.IfElse(isAsync, IterationUseAsyncYieldStar, IterationUseYieldStar), expressionType, sentType,
				errorNode);
		}
		if (!isAsync) {
			return yieldedType;
		}
		return c.getAwaitedTypeEx(yieldedType, errorNode, Core.IfElse(isYieldStar,
			Diagnostics.Type_of_iterated_elements_of_a_yield_Asterisk_operand_must_either_be_a_valid_promise_or_must_not_contain_a_callable_then_member,
			Diagnostics.Type_of_yield_operand_in_an_async_generator_must_either_be_a_valid_promise_or_must_not_contain_a_callable_then_member));
	}

	static function checkSyntheticExpression(c:Checker, node:Node):Type {
		final t:Type = cast node.AsSyntheticExpression().Type;
		if (node.AsSyntheticExpression().IsSpread) {
			return c.getIndexedAccessType(t, c.numberType);
		}
		return t;
	}

	static function checkIdentifier(c:Checker, node:Node, checkMode:CheckMode):Type {
		if (Ast.IsThisInTypeQuery(node)) {
			return c.checkThisExpression(node);
		}
		final symbol = c.getResolvedSymbol(node);
		if (symbol == c.unknownSymbol) {
			return c.errorType;
		}
		if (symbol == c.argumentsSymbol) {
			if (c.isInPropertyInitializerOrClassStaticBlock(node, true /*ignoreArrowFunctions*/)) {
				c.error(node, Diagnostics.X_arguments_cannot_be_referenced_in_property_initializers_or_class_static_initialization_blocks);
				return c.errorType;
			}
			return c.getTypeOfSymbol(symbol);
		}
		if (Checker.shouldMarkIdentifierAliasReferenced(node)) {
			c.markLinkedReferences(node, ReferenceHintIdentifier, null /*propSymbol*/, null /*parentType*/);
		}
		final localOrExportSymbol = c.getExportSymbolOfValueSymbolIfExported(symbol);
		final targetSymbol = c.resolveAliasWithDeprecationCheck(localOrExportSymbol, node);
		if (Core.len(targetSymbol.Declarations) != 0 && c.isDeprecatedSymbol(targetSymbol) && c.isUncalledFunctionReference(node, targetSymbol)) {
			c.addDeprecatedSuggestion(node, targetSymbol.Declarations, node.Text());
		}
		var declaration = localOrExportSymbol.ValueDeclaration;
		final immediateDeclaration = declaration;
		// If the identifier is declared in a binding pattern for which we're currently computing the implied type and the
		// reference occurs with the same binding pattern, return the non-inferrable any type. This for example occurs in
		// 'const [a, b = a + 1] = [2]' when we're computing the contextual type for the array literal '[2]'.
		if (declaration != null && declaration.Kind == KindBindingElement && Slices.Contains(c.contextualBindingPatterns, declaration.Parent)
			&& Ast.FindAncestor(node, (parent:Node) -> {
				return parent == declaration.Parent;
			}) != null) {
			return c.nonInferrableAnyType;
		}
		var t = c.getNarrowedTypeOfSymbol(localOrExportSymbol, node);
		final assignmentKind = Checker.getAssignmentTargetKind(node);
		if (assignmentKind != AssignmentKindNone) {
			if (localOrExportSymbol.Flags & SymbolFlagsVariable == 0 && !(Ast.IsInJSFile(node) && localOrExportSymbol.Flags & SymbolFlagsValueModule != 0)) {
				var assignmentError:Message = null;
				if (localOrExportSymbol.Flags & SymbolFlagsEnum != 0) {
					assignmentError = Diagnostics.Cannot_assign_to_0_because_it_is_an_enum;
				} else if (localOrExportSymbol.Flags & SymbolFlagsClass != 0) {
					assignmentError = Diagnostics.Cannot_assign_to_0_because_it_is_a_class;
				} else if (localOrExportSymbol.Flags & SymbolFlagsModule != 0) {
					assignmentError = Diagnostics.Cannot_assign_to_0_because_it_is_a_namespace;
				} else if (localOrExportSymbol.Flags & SymbolFlagsFunction != 0) {
					assignmentError = Diagnostics.Cannot_assign_to_0_because_it_is_a_function;
				} else if (localOrExportSymbol.Flags & SymbolFlagsAlias != 0) {
					assignmentError = Diagnostics.Cannot_assign_to_0_because_it_is_an_import;
				} else {
					assignmentError = Diagnostics.Cannot_assign_to_0_because_it_is_not_a_variable;
				}
				c.error(node, assignmentError, c.symbolToString(symbol));
				return c.errorType;
			}
			if (c.isReadonlySymbol(localOrExportSymbol)) {
				if (localOrExportSymbol.Flags & SymbolFlagsVariable != 0) {
					c.error(node, Diagnostics.Cannot_assign_to_0_because_it_is_a_constant, c.symbolToString(symbol));
				} else {
					c.error(node, Diagnostics.Cannot_assign_to_0_because_it_is_a_read_only_property, c.symbolToString(symbol));
				}
				return c.errorType;
			}
		}
		final isAlias = localOrExportSymbol.Flags & SymbolFlagsAlias != 0;
		// We only narrow variables and parameters occurring in a non-assignment position. For all other
		// entities we simply return the declared type.
		if (localOrExportSymbol.Flags & SymbolFlagsVariable != 0) {
			if (assignmentKind == AssignmentKindDefinite) {
				if (Checker.isInCompoundLikeAssignment(node)) {
					return c.getBaseTypeOfLiteralType(t);
				}
				return t;
			}
		} else if (isAlias) {
			declaration = c.getDeclarationOfAliasSymbol(symbol);
		} else {
			return t;
		}
		if (declaration == null) {
			return t;
		}
		t = c.getNarrowableTypeForReference(t, node, checkMode);
		// The declaration container is the innermost function that encloses the declaration of the variable
		// or parameter. The flow container is the innermost function starting with which we analyze the control
		// flow graph to determine the control flow based type.
		final isParameter = Ast.GetRootDeclaration(declaration).Kind == KindParameter;
		final declarationContainer = c.getControlFlowContainer(declaration);
		var flowContainer = c.getControlFlowContainer(node);
		final isOuterVariable = flowContainer != declarationContainer;
		final isSpreadDestructuringAssignmentTarget = node.Parent != null && node.Parent.Parent != null && Ast.IsSpreadAssignment(node.Parent)
			&& c.isDestructuringAssignmentTarget(node.Parent.Parent);
		final isModuleExports = symbol.Flags & SymbolFlagsModuleExports != 0;
		final typeIsAutomatic = t == c.autoType || t == c.autoArrayType;
		final isAutomaticTypeInNonNull = typeIsAutomatic && node.Parent.Kind == KindNonNullExpression;
		// When the control flow originates in a function expression, arrow function, method, or accessor, and
		// we are referencing a closed-over const variable or parameter or mutable local variable past its last
		// assignment, we extend the origin of the control flow analysis to include the immediately enclosing
		// control flow container.
		while (flowContainer != declarationContainer
			&& (Ast.IsFunctionExpressionOrArrowFunction(flowContainer) || Ast.IsObjectLiteralOrClassExpressionMethodOrAccessor(flowContainer))
			&& (c.isConstantVariable(localOrExportSymbol) && t != c.autoArrayType
				|| c.isParameterOrMutableLocalVariable(localOrExportSymbol) && c.isPastLastAssignment(localOrExportSymbol, node))) {
			flowContainer = c.getControlFlowContainer(flowContainer);
		}
		// We only look for uninitialized variables in strict null checking mode, and only when we can analyze
		// the entire control flow graph from the variable's declaration (i.e. when the flow container and
		// declaration container are the same).
		final isNeverInitialized = immediateDeclaration != null && Ast.IsVariableDeclaration(immediateDeclaration)
			&& !Ast.IsForInOrOfStatement(immediateDeclaration.Parent.Parent) && immediateDeclaration.Initializer() == null
			&& immediateDeclaration.AsVariableDeclaration().ExclamationToken == null && c.isMutableLocalVariableDeclaration(immediateDeclaration)
			&& !c.isSymbolAssignedDefinitely(symbol);
		final assumeInitialized = isParameter
			|| isAlias
			|| (isOuterVariable && !isNeverInitialized)
			|| isSpreadDestructuringAssignmentTarget
			|| isModuleExports
			|| c.isSameScopedBindingElement(node, declaration)
			|| t != c.autoType && t != c.autoArrayType
				&& (!c.strictNullChecks || t.flags & (TypeFlagsAnyOrUnknown | TypeFlagsVoid) != 0 || Checker.IsInTypeQuery(node) || c.isInAmbientOrTypeNode(node)
					|| node.Parent.Kind == KindExportSpecifier)
			|| Ast.IsNonNullExpression(node.Parent)
			|| Ast.IsVariableDeclaration(declaration) && declaration.AsVariableDeclaration().ExclamationToken != null
			|| declaration.Flags & NodeFlagsAmbient != 0;
		var initialType:Type = null;
		if (isAutomaticTypeInNonNull) {
			initialType = c.undefinedType;
		} else if (assumeInitialized && isParameter) {
			initialType = c.removeOptionalityFromDeclaredType(t, declaration);
		} else if (assumeInitialized) {
			initialType = t;
		} else if (typeIsAutomatic) {
			initialType = c.undefinedType;
		} else {
			initialType = c.getOptionalType(t, false /*isProperty*/);
		}
		var flowType:Type = null;
		if (isAutomaticTypeInNonNull) {
			flowType = c.GetNonNullableType(c.getFlowTypeOfReferenceEx(node, t, initialType, flowContainer, null));
		} else {
			flowType = c.getFlowTypeOfReferenceEx(node, t, initialType, flowContainer, null);
		}
		// A variable is considered uninitialized when it is possible to analyze the entire control flow graph
		// from declaration to use, and when the variable's declared type doesn't include undefined but the
		// control flow based type does include undefined.
		if (!c.isEvolvingArrayOperationTarget(node) && (t == c.autoType || t == c.autoArrayType)) {
			if (flowType == c.autoType || flowType == c.autoArrayType) {
				if (c.noImplicitAny) {
					c.error(Ast.GetNameOfDeclaration(declaration), Diagnostics.Variable_0_implicitly_has_type_1_in_some_locations_where_its_type_cannot_be_determined,
						c.symbolToString(symbol), c.TypeToString(flowType));
					c.error(node, Diagnostics.Variable_0_implicitly_has_an_1_type, c.symbolToString(symbol), c.TypeToString(flowType));
				}
				return c.convertAutoToAny(flowType);
			}
		} else if (!assumeInitialized && !c.containsUndefinedType(t) && c.containsUndefinedType(flowType)) {
			c.error(node, Diagnostics.Variable_0_is_used_before_being_assigned, c.symbolToString(symbol));
			// Return the declared type to reduce follow-on errors
			return t;
		}
		if (assignmentKind != AssignmentKindNone) {
			// Identifier is target of a compound assignment
			return c.getBaseTypeOfLiteralType(flowType);
		}
		return flowType;
	}

	static function isSameScopedBindingElement(c:Checker, node:Node, declaration:Node):Bool {
		if (Ast.IsBindingElement(declaration)) {
			final bindingElement = Ast.FindAncestor(node, Ast.IsBindingElement);
			return bindingElement != null && Ast.GetRootDeclaration(bindingElement) == Ast.GetRootDeclaration(declaration);
		}
		return false;
	}

	// Remove undefined from the annotated type of a parameter when there is an initializer (that doesn't include undefined)
	static function removeOptionalityFromDeclaredType(c:Checker, declaredType:Type, declaration:Node):Type {
		final removeUndefined = c.strictNullChecks && Ast.IsParameterDeclaration(declaration) && declaration.Initializer() != null
			&& c.hasTypeFacts(declaredType, TypeFactsIsUndefined) && !c.parameterInitializerContainsUndefined(declaration);
		if (removeUndefined) {
			return c.getTypeWithFacts(declaredType, TypeFactsNEUndefined);
		}
		return declaredType;
	}

	static function parameterInitializerContainsUndefined(c:Checker, declaration:Node):Bool {
		final links = c.nodeLinks.Get(declaration);
		if (links.flags & NodeCheckFlagsInitializerIsUndefinedComputed == 0) {
			if (!c.pushTypeResolution((cast declaration : TypeSystemEntity) /* PORT: Go TypeSystemEntity is `any`; Node does not declare it */,
				TypeSystemPropertyNameInitializerIsUndefined)) {
				c.reportCircularityError(declaration.Symbol());
				return true;
			}
			final containsUndefined = c.hasTypeFacts(c.checkDeclarationInitializer(declaration, CheckModeNormal, null), TypeFactsIsUndefined);
			if (!c.popTypeResolution()) {
				c.reportCircularityError(declaration.Symbol());
				return true;
			}
			if (links.flags & NodeCheckFlagsInitializerIsUndefinedComputed == 0) {
				links.flags |= NodeCheckFlagsInitializerIsUndefinedComputed
					| Core.IfElse(containsUndefined, NodeCheckFlagsInitializerIsUndefined, (0 : NodeCheckFlags));
			}
		}
		return links.flags & NodeCheckFlagsInitializerIsUndefined != 0;
	}

	static function isInAmbientOrTypeNode(c:Checker, node:Node):Bool {
		return node.Flags & NodeFlagsAmbient != 0 || Ast.FindAncestor(node, (n:Node) -> {
			return Ast.IsInterfaceDeclaration(n) || Ast.IsTypeAliasDeclaration(n) || Ast.IsJSTypeAliasDeclaration(n) || Ast.IsTypeLiteralNode(n);
		}) != null;
	}

	static function checkPropertyAccessExpression(c:Checker, node:Node, checkMode:CheckMode, writeOnly:Bool):Type {
		if (node.Flags & NodeFlagsOptionalChain != 0) {
			return c.checkPropertyAccessChain(node, checkMode);
		}
		final expr = node.Expression();
		return c.checkPropertyAccessExpressionOrQualifiedName(node, expr, c.checkNonNullExpression(expr), node.AsPropertyAccessExpression().Name(), checkMode,
			writeOnly);
	}

	static function checkPropertyAccessChain(c:Checker, node:Node, checkMode:CheckMode):Type {
		final leftType = c.checkExpression(node.Expression());
		final nonOptionalType = c.getOptionalExpressionType(leftType, node.Expression());
		return c.propagateOptionalTypeMarker(c.checkPropertyAccessExpressionOrQualifiedName(node, node.Expression(),
			c.checkNonNullType(nonOptionalType, node.Expression()), node.Name(), checkMode, false), node, nonOptionalType != leftType);
	}

	static function checkPropertyAccessExpressionOrQualifiedName(c:Checker, node:Node, left:Node, leftType:Type, right:Node, checkMode:CheckMode, writeOnly:Bool):Type {
		final parentSymbol = c.getResolvedSymbolOrNil(left);
		final assignmentKind = Checker.getAssignmentTargetKind(node);
		var widenedType = leftType;
		if (assignmentKind != AssignmentKindNone || c.isMethodAccessForCall(node)) {
			widenedType = c.getWidenedType(leftType);
		}
		final apparentType = c.getApparentType(widenedType);
		final isAnyLike = Checker.IsTypeAny(apparentType) || apparentType == c.silentNeverType;
		var prop:Symbol = null;
		if (Ast.IsPrivateIdentifier(right)) {
			if (c.languageVersion < Checker.LanguageFeatureMinimumTarget.PrivateNamesAndClassStaticBlocks
				|| c.languageVersion < Checker.LanguageFeatureMinimumTarget.ClassAndClassElementDecorators
				|| !c.compilerOptions.GetUseDefineForClassFields()) {
				if (assignmentKind != AssignmentKindNone) {
					c.checkExternalEmitHelpers(node, ExternalEmitHelpersClassPrivateFieldSet);
				}
				if (assignmentKind != AssignmentKindDefinite) {
					c.checkExternalEmitHelpers(node, ExternalEmitHelpersClassPrivateFieldGet);
				}
			}
			final lexicallyScopedSymbol = c.lookupSymbolForPrivateIdentifierDeclaration(right.Text(), right);
			if (assignmentKind != AssignmentKindNone && lexicallyScopedSymbol != null && lexicallyScopedSymbol.ValueDeclaration != null
				&& Ast.IsMethodDeclaration(lexicallyScopedSymbol.ValueDeclaration)) {
				c.grammarErrorOnNode(right, Diagnostics.Cannot_assign_to_private_method_0_Private_methods_are_not_writable, right.Text());
			}
			if (isAnyLike) {
				if (lexicallyScopedSymbol != null) {
					if (c.isErrorType(apparentType)) {
						return c.errorType;
					}
					return apparentType;
				}
				if (Checker.getContainingClassExcludingClassDecorators(right) == null) {
					c.grammarErrorOnNode(right, Diagnostics.Private_identifiers_are_not_allowed_outside_class_bodies);
					return c.anyType;
				}
			}
			if (lexicallyScopedSymbol != null) {
				prop = c.getPrivateIdentifierPropertyOfType(leftType, lexicallyScopedSymbol);
			}
			if (prop == null) {
				// Check for private-identifier-specific shadowing and lexical-scoping errors.
				if (c.checkPrivateIdentifierPropertyAccess(leftType, right, lexicallyScopedSymbol)) {
					return c.errorType;
				}
				final containingClass = Checker.getContainingClassExcludingClassDecorators(right);
				if (containingClass != null && Ast.IsPlainJSFile(Ast.GetSourceFileOfNode(containingClass), c.compilerOptions.CheckJs)) {
					c.grammarErrorOnNode(right, Diagnostics.Private_field_0_must_be_declared_in_an_enclosing_class, right.Text());
				}
			} else {
				final isSetonlyAccessor = prop.Flags & SymbolFlagsSetAccessor != 0 && prop.Flags & SymbolFlagsGetAccessor == 0;
				if (isSetonlyAccessor && assignmentKind != AssignmentKindDefinite) {
					c.error(node, Diagnostics.Private_accessor_was_defined_without_a_getter);
				}
			}
		} else {
			if (isAnyLike) {
				if (Ast.IsIdentifier(left) && parentSymbol != null) {
					c.markLinkedReferences(node, ReferenceHintProperty, null /*propSymbol*/, leftType);
				}
				if (c.isErrorType(apparentType)) {
					return c.errorType;
				}
				return apparentType;
			}
			prop = c.getPropertyOfTypeEx(apparentType, right.Text(), Checker.isConstEnumObjectType(apparentType) /*skipObjectFunctionPropertyAugment*/,
				node.Kind == KindQualifiedName /*includeTypeOnlyMembers*/);
		}
		c.markLinkedReferences(node, ReferenceHintProperty, prop, leftType);
		var propType:Type = null;
		if (prop == null) {
			var indexInfo:IndexInfo = null;
			if (!Ast.IsPrivateIdentifier(right)
				&& (assignmentKind == AssignmentKindNone || !c.isGenericObjectType(leftType) || Checker.isThisTypeParameter(leftType))) {
				indexInfo = c.getApplicableIndexInfoForName(apparentType, right.Text());
			}
			if (indexInfo == null) {
				final isUncheckedJS = c.isUncheckedJSSuggestion(node, leftType.symbol, true /*excludeClasses*/);
				if (!isUncheckedJS && c.isJSLiteralType(leftType)) {
					return c.anyType;
				}
				if (leftType.symbol == c.globalThisSymbol) {
					final globalSymbol = c.globalThisSymbol.Exports != null ? c.globalThisSymbol.Exports.get(right.Text()) : null;
					if (globalSymbol != null && globalSymbol.Flags & SymbolFlagsBlockScoped != 0) {
						c.error(right, Diagnostics.Property_0_does_not_exist_on_type_1, right.Text(), c.TypeToString(leftType));
					} else if (c.noImplicitAny) {
						c.error(right, Diagnostics.Element_implicitly_has_an_any_type_because_type_0_has_no_index_signature, c.TypeToString(leftType));
					}
					return c.anyType;
				}
				if (right.Text() != "" && !c.checkAndReportErrorForExtendingInterface(node)) {
					c.reportNonexistentProperty(right, Core.IfElse(Checker.isThisTypeParameter(leftType), apparentType, leftType), isUncheckedJS);
				}
				return c.errorType;
			}
			if (indexInfo.isReadonly && (Ast.IsAssignmentTarget(node) || Checker.isDeleteTarget(node))) {
				c.error(node, Diagnostics.Index_signature_in_type_0_only_permits_reading, c.TypeToString(apparentType));
			}
			propType = indexInfo.valueType;
			if (c.compilerOptions.NoUncheckedIndexedAccess == TSTrue && Checker.getAssignmentTargetKind(node) != AssignmentKindDefinite) {
				propType = c.getUnionType([propType, c.missingType]);
			}
			if (c.compilerOptions.NoPropertyAccessFromIndexSignature == TSTrue && Ast.IsPropertyAccessExpression(node)) {
				c.error(right, Diagnostics.Property_0_comes_from_an_index_signature_so_it_must_be_accessed_with_0, right.Text());
			}
			if (indexInfo.declaration != null && c.IsDeprecatedDeclaration(indexInfo.declaration)) {
				c.addDeprecatedSuggestion(right, [indexInfo.declaration], right.Text());
			}
		} else {
			final targetPropSymbol = c.resolveAliasWithDeprecationCheck(prop, right);
			if (c.isDeprecatedSymbol(targetPropSymbol) && c.isUncalledFunctionReference(node, targetPropSymbol) && targetPropSymbol.Declarations != null) {
				c.addDeprecatedSuggestion(right, targetPropSymbol.Declarations, right.Text());
			}
			c.checkPropertyNotUsedBeforeDeclaration(prop, node, right);
			c.markPropertyAsReferenced(prop, node, c.isSelfTypeAccess(left, parentSymbol));
			c.symbolNodeLinks.Get(node).resolvedSymbol = prop;
			c.checkPropertyAccessibility(node, left.Kind == KindSuperKeyword, Ast.IsWriteAccess(node), apparentType, prop);
			if (c.isAssignmentToReadonlyEntity(node, prop, assignmentKind)) {
				c.error(right, Diagnostics.Cannot_assign_to_0_because_it_is_a_read_only_property, right.Text());
				return c.errorType;
			}
			if (c.isThisPropertyAccessInConstructor(node, prop)) {
				propType = c.autoType;
			} else if (writeOnly || Ast.IsWriteOnlyAccess(node)) {
				propType = c.getWriteTypeOfSymbol(prop);
			} else {
				propType = c.getTypeOfSymbol(prop);
			}
		}
		return c.getFlowTypeOfAccessExpression(node, prop, propType, right, checkMode);
	}

	static function getFlowTypeOfAccessExpression(c:Checker, node:Node, prop:Symbol, propType:Type, errorNode:Node, checkMode:CheckMode):Type {
		// Only compute control flow type if this is a property access expression that isn't an
		// assignment target, and the referenced property was declared as a variable, property,
		// accessor, or optional method.
		final assignmentKind = Checker.getAssignmentTargetKind(node);
		if (assignmentKind == AssignmentKindDefinite) {
			return c.removeMissingType(propType, prop != null && prop.Flags & SymbolFlagsOptional != 0);
		}
		if (prop != null && prop.Flags & (SymbolFlagsVariable | SymbolFlagsProperty | SymbolFlagsAccessor) == 0
			&& !(prop.Flags & SymbolFlagsMethod != 0 && propType.flags & TypeFlagsUnion != 0)) {
			return propType;
		}
		if (propType == c.autoType) {
			return c.getFlowTypeOfProperty(node, prop);
		}
		propType = c.getNarrowableTypeForReference(propType, node, checkMode);
		// If strict null checks and strict property initialization checks are enabled, if we have
		// a this.xxx property access, if the property is an instance property without an initializer,
		// and if we are in a constructor of the same class as the property declaration, assume that
		// the property is uninitialized at the top of the control flow.
		var assumeUninitialized = false;
		if (c.strictNullChecks && prop != null) {
			final declaration = prop.ValueDeclaration;
			if (declaration != null) {
				if (c.strictPropertyInitialization && Ast.IsAccessExpression(node) && node.Expression().Kind == KindThisKeyword
					&& c.isPropertyWithoutInitializer(declaration) && !Ast.IsStatic(declaration)) {
					final flowContainer = c.getControlFlowContainer(node);
					if (Ast.IsConstructorDeclaration(flowContainer) && flowContainer.Parent == declaration.Parent && declaration.Flags & NodeFlagsAmbient == 0) {
						assumeUninitialized = true;
					}
				} else if (Ast.IsBinaryExpression(declaration) && Ast.IsPropertyAccessExpression(declaration.AsBinaryExpression().Left)
					&& c.getControlFlowContainer(node) == c.getControlFlowContainer(declaration)) {
					assumeUninitialized = true;
				}
			}
		}
		final flowType = c.getFlowTypeOfReferenceEx(node, propType, c.addOptionalityEx(propType, false /*isProperty*/, assumeUninitialized), null, null);
		if (assumeUninitialized && !c.containsUndefinedType(propType) && c.containsUndefinedType(flowType)) {
			c.error(errorNode, Diagnostics.Property_0_is_used_before_being_assigned, c.symbolToString(prop));
			// Return the declared type to reduce follow-on errors
			return propType;
		}
		if (assignmentKind != AssignmentKindNone) {
			return c.getBaseTypeOfLiteralType(flowType);
		}
		return flowType;
	}

	static function getControlFlowContainer(c:Checker, node:Node):Node {
		return Ast.FindAncestor(node.Parent, (node:Node) -> {
			return Ast.IsFunctionLike(node) && Ast.GetImmediatelyInvokedFunctionExpression(node) == null || Ast.IsModuleBlock(node) || Ast.IsSourceFile(node)
				|| Ast.IsPropertyDeclaration(node);
		});
	}

	static function getFlowTypeOfProperty(c:Checker, reference:Node, prop:Symbol):Type {
		var initialType = c.undefinedType;
		if (prop != null && prop.ValueDeclaration != null
			&& (!c.isAutoTypedProperty(prop) || prop.ValueDeclaration.ModifierFlags() & ModifierFlagsAmbient != 0)) {
			final baseType = c.getTypeOfPropertyInBaseClass(prop);
			if (baseType != null) {
				initialType = baseType;
			}
		}
		return c.getFlowTypeOfReferenceEx(reference, c.autoType, initialType, null, null);
	}

	// Return the inherited type of the given property or undefined if property doesn't exist in a base class.
	static function getTypeOfPropertyInBaseClass(c:Checker, property:Symbol):Type {
		final classType = c.getDeclaringClass(property);
		if (classType != null) {
			final baseClassTypes = c.getBaseTypes(classType);
			if (Core.len(baseClassTypes) > 0) {
				return c.getTypeOfPropertyOfType(baseClassTypes[0], property.Name);
			}
		}
		return null;
	}

	static function isMethodAccessForCall(c:Checker, node:Node):Bool {
		while (Ast.IsParenthesizedExpression(node.Parent)) {
			node = node.Parent;
		}
		return Ast.IsCallOrNewExpression(node.Parent) && node.Parent.Expression() == node;
	}

	// Lookup the private identifier lexically.
	static function lookupSymbolForPrivateIdentifierDeclaration(c:Checker, propName:std.String, location:Node):Symbol {
		var containingClass = Checker.getContainingClassExcludingClassDecorators(location);
		while (containingClass != null) {
			final symbol = containingClass.Symbol();
			final name = Binder.GetSymbolNameForPrivateIdentifier(symbol, propName);
			var prop = symbol.Members != null ? symbol.Members.get(name) : null;
			if (prop != null) {
				return prop;
			}
			prop = symbol.Exports != null ? symbol.Exports.get(name) : null;
			if (prop != null) {
				return prop;
			}
			containingClass = Ast.GetContainingClass(containingClass);
		}
		return null;
	}

	static function getPrivateIdentifierPropertyOfType(c:Checker, leftType:Type, lexicallyScopedIdentifier:Symbol):Symbol {
		return c.getPropertyOfType(leftType, lexicallyScopedIdentifier.Name);
	}

	static function checkPrivateIdentifierPropertyAccess(c:Checker, leftType:Type, right:Node, lexicallyScopedIdentifier:Symbol):Bool {
		// Either the identifier could not be looked up in the lexical scope OR the lexically scoped identifier did not exist on the type.
		// Find a private identifier with the same description on the type.
		final properties = c.getPropertiesOfType(leftType);
		var propertyOnType:Symbol = null;
		if (properties != null) {
			for (symbol in properties) {
				final decl = symbol.ValueDeclaration;
				if (decl != null && decl.Name() != null && Ast.IsPrivateIdentifier(decl.Name()) && decl.Name().Text() == right.Text()) {
					propertyOnType = symbol;
					break;
				}
			}
		}
		final diagName = Scanner.DeclarationNameToString(right);
		if (propertyOnType != null) {
			final typeValueDecl = propertyOnType.ValueDeclaration;
			final typeClass = Ast.GetContainingClass(typeValueDecl);
			// We found a private identifier property with the same description.
			// Either:
			// - There is a lexically scoped private identifier AND it shadows the one we found on the type.
			// - It is an attempt to access the private identifier outside of the class.
			if (lexicallyScopedIdentifier != null && lexicallyScopedIdentifier.ValueDeclaration != null) {
				final lexicalValueDecl = lexicallyScopedIdentifier.ValueDeclaration;
				final lexicalClass = Ast.GetContainingClass(lexicalValueDecl);
				if (Ast.FindAncestor(lexicalClass, (n:Node) -> {
					return typeClass == n;
				}) != null) {
					final diagnostic = c.error(right,
						Diagnostics.The_property_0_cannot_be_accessed_on_type_1_within_this_class_because_it_is_shadowed_by_another_private_identifier_with_the_same_spelling,
						diagName, c.TypeToString(leftType));
					diagnostic.AddRelatedInfo(Checker.createDiagnosticForNode(lexicalValueDecl, Diagnostics.The_shadowing_declaration_of_0_is_defined_here, diagName));
					diagnostic.AddRelatedInfo(Checker.createDiagnosticForNode(typeValueDecl,
						Diagnostics.The_declaration_of_0_that_you_probably_intended_to_use_is_defined_here, diagName));
					return true;
				}
			}
			c.error(right, Diagnostics.Property_0_is_not_accessible_outside_class_1_because_it_has_a_private_identifier, diagName,
				c.SymbolToString(typeClass.Symbol()));
			return true;
		}
		return false;
	}

	static function reportNonexistentProperty(c:Checker, propNode:Node, containingType:Type, isUncheckedJS:Bool):Void {
		final key = NonExistentPropertyKey.keyOf(c, propNode, containingType, isUncheckedJS);
		if (c.nonExistentProperties.Has(key)) {
			return;
		}
		c.nonExistentProperties.Add(key);
		final links = c.nodeLinks.Get(propNode);
		if (links.flags & NodeCheckFlagsTypeChecked != 0) {
			return; // error already made/in progress
		}
		links.flags |= NodeCheckFlagsTypeChecked;
		if (Ast.IsJSDocNameReferenceContext(propNode)) {
			return;
		}
		var diagnostic:Diagnostic = null;
		if (!Ast.IsPrivateIdentifier(propNode) && containingType.flags & TypeFlagsUnion != 0 && containingType.flags & TypeFlagsPrimitive == 0) {
			for (subtype in containingType.Types()) {
				if (c.getPropertyOfType(subtype, propNode.Text()) == null && c.getApplicableIndexInfoForName(subtype, propNode.Text()) == null) {
					diagnostic = Checker.NewDiagnosticChainForNode(diagnostic, propNode, Diagnostics.Property_0_does_not_exist_on_type_1,
						Scanner.DeclarationNameToString(propNode), c.TypeToString(subtype));
					break;
				}
			}
		}
		if (c.typeHasStaticProperty(propNode.Text(), containingType)) {
			final propName = Scanner.DeclarationNameToString(propNode);
			final typeName = c.TypeToString(containingType);
			diagnostic = Checker.NewDiagnosticChainForNode(diagnostic, propNode,
				Diagnostics.Property_0_does_not_exist_on_type_1_Did_you_mean_to_access_the_static_member_2_instead, propName, typeName, typeName + "." + propName);
		} else {
			final promisedType = c.GetPromisedTypeOfPromise(containingType);
			if (promisedType != null && c.getPropertyOfType(promisedType, propNode.Text()) != null) {
				diagnostic = Checker.NewDiagnosticChainForNode(diagnostic, propNode, Diagnostics.Property_0_does_not_exist_on_type_1,
					Scanner.DeclarationNameToString(propNode), c.TypeToString(containingType));
				diagnostic.AddRelatedInfo(Checker.NewDiagnosticForNode(propNode, Diagnostics.Did_you_forget_to_use_await));
			} else {
				final missingProperty = Scanner.DeclarationNameToString(propNode);
				final container = c.TypeToString(containingType);
				final libSuggestion = c.getSuggestedLibForNonExistentProperty(missingProperty, containingType);
				if (libSuggestion != "") {
					diagnostic = Checker.NewDiagnosticChainForNode(diagnostic, propNode,
						Diagnostics.Property_0_does_not_exist_on_type_1_Do_you_need_to_change_your_target_library_Try_changing_the_lib_compiler_option_to_2_or_later,
						missingProperty, container, libSuggestion);
				} else {
					final suggestion = c.getSuggestedSymbolForNonexistentProperty(propNode, containingType);
					if (suggestion != null) {
						final suggestedName = Ast.SymbolName(suggestion);
						final message = Core.IfElse(isUncheckedJS, Diagnostics.Property_0_may_not_exist_on_type_1_Did_you_mean_2,
							Diagnostics.Property_0_does_not_exist_on_type_1_Did_you_mean_2);
						diagnostic = Checker.NewDiagnosticChainForNode(diagnostic, propNode, message, missingProperty, container, suggestedName);
						if (suggestion.ValueDeclaration != null) {
							diagnostic.AddRelatedInfo(Checker.NewDiagnosticForNode(suggestion.ValueDeclaration, Diagnostics.X_0_is_declared_here, suggestedName));
						}
					} else {
						diagnostic = c.elaborateNeverIntersection(diagnostic, propNode, containingType);
						var message:Message = null;
						if (c.containerSeemsToBeEmptyDomElement(containingType)) {
							message = Diagnostics.Property_0_does_not_exist_on_type_1_Try_changing_the_lib_compiler_option_to_include_dom;
						} else {
							message = Diagnostics.Property_0_does_not_exist_on_type_1;
						}
						diagnostic = Checker.NewDiagnosticChainForNode(diagnostic, propNode, message, missingProperty, container);
					}
				}
			}
		}
		c.addErrorOrSuggestion(!isUncheckedJS || diagnostic.Code() != Diagnostics.Property_0_may_not_exist_on_type_1_Did_you_mean_2.Code(), diagnostic);
	}

	static function getSuggestedLibForNonExistentProperty(c:Checker, missingProperty:std.String, containingType:Type):std.String {
		final container = c.getApparentType(containingType).symbol;
		if (container != null) {
			final featureMap = Checker.getFeatureMap();
			if (featureMap.exists(container.Name)) {
				final typeFeatures = featureMap.get(container.Name);
				for (entry in typeFeatures) {
					if (Slices.Contains(entry.props, missingProperty)) {
						return entry.lib;
					}
				}
			}
		}
		return "";
	}

	static function getSuggestedSymbolForNonexistentProperty(c:Checker, name:Node, containingType:Type):Symbol {
		var props = c.getPropertiesOfType(containingType);
		final parent = name.Parent;
		if (Ast.IsPropertyAccessExpression(parent)) {
			props = Core.Filter(props, (prop:Symbol) -> {
				return c.isValidPropertyAccessForCompletions(parent, containingType, prop);
			});
		}
		// PORT: slices.Values(props) as an iter.Seq (yield-func form).
		final ps = props;
		return c.getSpellingSuggestionForName(name.Text(), (yield:(Symbol) -> Bool) -> {
			if (ps != null) {
				for (p in ps) {
					if (!yield(p)) {
						return;
					}
				}
			}
		}, SymbolFlagsValue);
	}

	// Checks if an existing property access is valid for completions purposes.
	// @param node a property access-like node where we want to check if we can access a property.
	// This node does not need to be an access of the property we are checking.
	// e.g. in completions, this node will often be an incomplete property access node, as in `foo.`.
	// Besides providing a location (i.e. scope) used to check property accessibility, we use this node for
	// computing whether this is a `super` property access.
	// @param type the type whose property we are checking.
	// @param property the accessed property's symbol.
	static function isValidPropertyAccessForCompletions(c:Checker, node:Node, t:Type, property:Symbol):Bool {
		return c.isPropertyAccessible(node, Ast.IsPropertyAccessExpression(node) && node.Expression().Kind == KindSuperKeyword, false /*isWrite*/, t, property);
		// Previously we validated the 'this' type of methods but this adversely affected performance. See #31377 for more context.
	}

	// Checks if a property can be accessed in a location.
	// The location is given by the `node` parameter.
	// The node does not need to be a property access.
	// @param node location where to check property accessibility
	// @param isSuper whether to consider this a `super` property access, e.g. `super.foo`.
	// @param isWrite whether this is a write access, e.g. `++foo.x`.
	// @param containingType type where the property comes from.
	// @param property property symbol.
	static function isPropertyAccessible(c:Checker, node:Node, isSuper:Bool, isWrite:Bool, containingType:Type, property:Symbol):Bool {
		// Short-circuiting for improved performance.
		if (Checker.IsTypeAny(containingType)) {
			return true;
		}
		// A #private property access in an optional chain is an error dealt with by the parser.
		// The checker does not check for it, so we need to do our own check here.
		if (property.ValueDeclaration != null && Ast.IsPrivateIdentifierClassElementDeclaration(property.ValueDeclaration)) {
			final declClass = Ast.GetContainingClass(property.ValueDeclaration);
			return !Ast.IsOptionalChain(node) && Ast.IsNodeDescendantOf(node, declClass);
		}
		return c.checkPropertyAccessibilityAtLocation(node, isSuper, isWrite, containingType, property, null);
	}

	static function containerSeemsToBeEmptyDomElement(c:Checker, containingType:Type):Bool {
		return !Slices.Contains(c.compilerOptions.Lib, "lib.dom.d.ts") && Checker.everyContainedType(containingType, Checker.hasCommonDomTypeName)
			&& c.isEmptyObjectType(containingType);
	}

	static function checkAndReportErrorForExtendingInterface(c:Checker, errorLocation:Node):Bool {
		final expression = c.getEntityNameForExtendingInterface(errorLocation);
		if (expression != null && c.resolveEntityName(expression, SymbolFlagsInterface, true /*ignoreErrors*/, false, null) != null) {
			c.error(errorLocation, Diagnostics.Cannot_extend_an_interface_0_Did_you_mean_implements, Scanner.GetTextOfNode(expression));
			return true;
		}
		return false;
	}

	/**
	 * Climbs up parents to an ExpressionWithTypeArguments, and returns its expression,
	 * but returns undefined if that expression is not an EntityNameExpression.
	 */
	static function getEntityNameForExtendingInterface(c:Checker, node:Node):Node {
		switch (node.Kind) {
			case KindIdentifier, KindPropertyAccessExpression:
				if (node.Parent != null) {
					return c.getEntityNameForExtendingInterface(node.Parent);
				}
			case KindExpressionWithTypeArguments:
				if (Ast.IsEntityNameExpression(node.Expression())) {
					return node.Expression();
				}
			default:
		}
		return null;
	}

	static function isUncalledFunctionReference(c:Checker, node:Node, symbol:Symbol):Bool {
		if (symbol.Flags & (SymbolFlagsFunction | SymbolFlagsMethod) != 0) {
			var parent = Ast.FindAncestor(node.Parent, (n:Node) -> {
				return !Ast.IsAccessExpression(n);
			});
			if (parent == null) {
				parent = node.Parent;
			}
			if (Ast.IsCallLikeExpression(parent)) {
				return Ast.IsCallOrNewExpression(parent) && Ast.IsIdentifier(node) && c.hasMatchingArgument(parent, node);
			}
			return Core.Every(symbol.Declarations, (d:Node) -> {
				return !Ast.IsFunctionLike(d) || c.IsDeprecatedDeclaration(d);
			});
		}
		return true;
	}

	static function checkPropertyNotUsedBeforeDeclaration(c:Checker, prop:Symbol, node:Node, right:Node):Void {
		final valueDeclaration = prop.ValueDeclaration;
		if (valueDeclaration == null || Ast.GetSourceFileOfNode(node).IsDeclarationFile) {
			return;
		}
		var diagnostic:Diagnostic = null;
		final declarationName = right.Text();
		if (c.isInPropertyInitializerOrClassStaticBlock(node, false /*ignoreArrowFunctions*/)
			&& !c.isOptionalPropertyDeclaration(valueDeclaration)
			&& !(Ast.IsAccessExpression(node) && Ast.IsAccessExpression(node.Expression()))
			&& !c.isBlockScopedNameDeclaredBeforeUse(valueDeclaration, right)
			&& !(Ast.IsMethodDeclaration(valueDeclaration) && c.getCombinedModifierFlagsCached(valueDeclaration) & ModifierFlagsStatic != 0)
			&& (c.compilerOptions.GetUseDefineForClassFields() || !c.isPropertyDeclaredInAncestorClass(prop))) {
			diagnostic = c.error(right, Diagnostics.Property_0_is_used_before_its_initialization, declarationName);
		} else if (Ast.IsClassDeclaration(valueDeclaration) && !Ast.IsTypeReferenceNode(node.Parent) && valueDeclaration.Flags & NodeFlagsAmbient == 0
			&& !c.isBlockScopedNameDeclaredBeforeUse(valueDeclaration, right)) {
			diagnostic = c.error(right, Diagnostics.Class_0_used_before_its_declaration, declarationName);
		}
		if (diagnostic != null) {
			diagnostic.AddRelatedInfo(Checker.NewDiagnosticForNode(valueDeclaration, Diagnostics.X_0_is_declared_here, declarationName));
		}
	}

	static function isOptionalPropertyDeclaration(c:Checker, node:Node):Bool {
		return Ast.IsPropertyDeclaration(node) && !Ast.HasAccessorModifier(node) && Ast.IsQuestionToken(node.PostfixToken());
	}

	static function isPropertyDeclaredInAncestorClass(c:Checker, prop:Symbol):Bool {
		if (prop.Parent.Flags & SymbolFlagsClass != 0) {
			final baseTypes = c.getBaseTypes(c.getDeclaredTypeOfSymbol(prop.Parent));
			if (Core.len(baseTypes) != 0) {
				final superProperty = c.getPropertyOfType(baseTypes[0], prop.Name);
				return superProperty != null && superProperty.ValueDeclaration != null;
			}
		}
		return false;
	}

	/**
	 * Check whether the requested property access is valid.
	 * Returns true if node is a valid property access, and false otherwise.
	 * @param node The node to be checked.
	 * @param isSuper True if the access is from `super.`.
	 * @param type The type of the object whose property is being accessed. (Not the type of the property.)
	 * @param prop The symbol for the property being accessed.
	 */
	static function checkPropertyAccessibility(c:Checker, node:Node, isSuper:Bool, writing:Bool, t:Type, prop:Symbol):Bool {
		return c.checkPropertyAccessibilityEx(node, isSuper, writing, t, prop, true /*reportError*/);
	}

	static function checkPropertyAccessibilityEx(c:Checker, node:Node, isSuper:Bool, writing:Bool, t:Type, prop:Symbol, reportError:Bool):Bool {
		var errorNode:Node = null;
		if (reportError) {
			switch (node.Kind) {
				case KindPropertyAccessExpression:
					errorNode = node.AsPropertyAccessExpression().Name();
				case KindQualifiedName:
					errorNode = node.AsQualifiedName().Right;
				case KindImportType:
					errorNode = node;
				case KindBindingElement:
					errorNode = Checker.getBindingElementPropertyName(node);
				default:
					errorNode = node.Name();
			}
		}
		return c.checkPropertyAccessibilityAtLocation(node, isSuper, writing, t, prop, errorNode);
	}

	/**
	 * Check whether the requested property can be accessed at the requested location.
	 * Returns true if node is a valid property access, and false otherwise.
	 * @param location The location node where we want to check if the property is accessible.
	 * @param isSuper True if the access is from `super.`.
	 * @param writing True if this is a write property access, false if it is a read property access.
	 * @param containingType The type of the object whose property is being accessed. (Not the type of the property.)
	 * @param prop The symbol for the property being accessed.
	 * @param errorNode The node where we should report an invalid property access error, or undefined if we should not report errors.
	 */
	static function checkPropertyAccessibilityAtLocation(c:Checker, location:Node, isSuper:Bool, writing:Bool, containingType:Type, prop:Symbol, errorNode:Node):Bool {
		final flags = Checker.getDeclarationModifierFlagsFromSymbolEx(prop, writing);
		if (isSuper) {
			// TS 1.0 spec (April 2014): 4.8.2
			// - In a constructor, instance member function, instance member accessor, or
			//   instance member variable initializer where this references a derived class instance,
			//   a super property access is permitted and must specify a public instance member function of the base class.
			// - In a static member function or static member accessor
			//   where this references the constructor function object of a derived class,
			//   a super property access is permitted and must specify a public static member function of the base class.
			if (flags & ModifierFlagsAbstract != 0) {
				// A method cannot be accessed in a super property access if the method is abstract.
				// This error could mask a private property access error. But, a member
				// cannot simultaneously be private and abstract, so this will trigger an
				// additional error elsewhere.
				if (errorNode != null) {
					c.error(errorNode, Diagnostics.Abstract_method_0_in_class_1_cannot_be_accessed_via_super_expression, c.symbolToString(prop),
						c.TypeToString(c.getDeclaringClass(prop)));
				}
				return false;
			}
			// A class field cannot be accessed via super.* from a derived class.
			// This is true for both [[Set]] (old) and [[Define]] (ES spec) semantics.
			if (flags & ModifierFlagsStatic == 0 && Core.Some(prop.Declarations, Checker.isClassInstanceProperty)) {
				if (errorNode != null) {
					c.error(errorNode, Diagnostics.Class_field_0_defined_by_the_parent_class_is_not_accessible_in_the_child_class_via_super, c.symbolToString(prop));
				}
				return false;
			}
		}
		// Referencing abstract properties within their own constructors is not allowed
		if (flags & ModifierFlagsAbstract != 0 && c.symbolHasNonMethodDeclaration(prop)
			&& (Checker.isThisProperty(location) || Checker.isThisInitializedObjectBindingExpression(location)
				|| Ast.IsObjectBindingPattern(location.Parent) && Checker.isThisInitializedDeclaration(location.Parent.Parent))) {
			final parentSymbol = c.getParentOfSymbol(prop);
			if (parentSymbol != null && parentSymbol.Flags & SymbolFlagsClass != 0 && c.isNodeUsedDuringClassInitialization(location)) {
				if (errorNode != null) {
					c.error(errorNode, Diagnostics.Abstract_property_0_in_class_1_cannot_be_accessed_in_the_constructor, c.symbolToString(prop),
						c.symbolToString(parentSymbol));
				}
				return false;
			}
		}
		// Public properties are otherwise accessible.
		if (flags & ModifierFlagsNonPublicAccessibilityModifier == 0) {
			return true;
		}
		// Property is known to be private or protected at this point
		// Private property is accessible if the property is within the declaring class
		if (flags & ModifierFlagsPrivate != 0) {
			final declaringClassDeclaration = Ast.GetClassLikeDeclarationOfSymbol(c.getParentOfSymbol(prop));
			if (!c.isNodeWithinClass(location, declaringClassDeclaration)) {
				if (errorNode != null) {
					c.error(errorNode, Diagnostics.Property_0_is_private_and_only_accessible_within_class_1, c.symbolToString(prop),
						c.TypeToString(c.getDeclaringClass(prop)));
				}
				return false;
			}
			return true;
		}
		// Property is known to be protected at this point
		// All protected properties of a supertype are accessible in a super access
		if (isSuper) {
			return true;
		}
		// Find the first enclosing class that has the declaring classes of the protected constituents
		// of the property as base classes
		var enclosingClass:Type = null;
		var container = Ast.GetContainingClass(location);
		while (container != null) {
			final class_ = c.getDeclaredTypeOfSymbol(c.getSymbolOfDeclaration(container));
			if (c.isClassDerivedFromDeclaringClasses(class_, prop, writing)) {
				enclosingClass = class_;
				break;
			}
			container = Ast.GetContainingClass(container);
		}
		// A protected property is accessible if the property is within the declaring class or classes derived from it
		if (enclosingClass == null) {
			// allow PropertyAccessibility if context is in function with this parameter
			// static member access is disallowed
			final class_ = c.getEnclosingClassFromThisParameter(location);
			if (class_ != null && c.isClassDerivedFromDeclaringClasses(class_, prop, writing)) {
				enclosingClass = class_;
			}
			if (flags & ModifierFlagsStatic != 0 || enclosingClass == null) {
				if (errorNode != null) {
					var class_ = c.getDeclaringClass(prop);
					if (class_ == null) {
						class_ = containingType;
					}
					c.error(errorNode, Diagnostics.Property_0_is_protected_and_only_accessible_within_class_1_and_its_subclasses, c.symbolToString(prop),
						c.TypeToString(class_));
				}
				return false;
			}
		}
		// No further restrictions for static properties
		if (flags & ModifierFlagsStatic != 0) {
			return true;
		}
		if (containingType.flags & TypeFlagsTypeParameter != 0) {
			// get the original type -- represented as the type constraint of the 'this' type
			if (containingType.AsTypeParameter().isThisType) {
				containingType = c.getConstraintOfTypeParameter(containingType);
			} else {
				containingType = c.getBaseConstraintOfType(containingType);
			}
		}
		if (containingType == null || !c.hasBaseType(containingType, enclosingClass)) {
			if (errorNode != null && containingType != null) {
				c.error(errorNode, Diagnostics.Property_0_is_protected_and_only_accessible_through_an_instance_of_class_1_This_is_an_instance_of_class_2,
					c.symbolToString(prop), c.TypeToString(enclosingClass), c.TypeToString(containingType));
			}
			return false;
		}
		return true;
	}

	static function symbolHasNonMethodDeclaration(c:Checker, symbol:Symbol):Bool {
		return c.forEachProperty(symbol, (prop:Symbol) -> {
			return prop.Flags & SymbolFlagsMethod == 0;
		});
	}

	// Invoke the callback for each underlying property symbol of the given symbol and return the first
	// value that isn't undefined.
	static function forEachProperty(c:Checker, prop:Symbol, callback:(p:Symbol) -> Bool):Bool {
		if (prop.CheckFlags & CheckFlagsSynthetic == 0) {
			return callback(prop);
		}
		for (t in c.valueSymbolLinks.Get(prop).containingType.Types()) {
			final p = c.getPropertyOfType(t, prop.Name);
			if (p != null && c.forEachProperty(p, callback)) {
				return true;
			}
		}
		return false;
	}

	// Return the declaring class type of a property or undefined if property not declared in class
	static function getDeclaringClass(c:Checker, prop:Symbol):Type {
		if (prop.Parent != null && prop.Parent.Flags & SymbolFlagsClass != 0) {
			return c.getDeclaredTypeOfSymbol(c.getParentOfSymbol(prop));
		}
		return null;
	}

	// Return true if source property is a valid override of protected parts of target property.
	static function isValidOverrideOf(c:Checker, sourceProp:Symbol, targetProp:Symbol):Bool {
		return !c.forEachProperty(targetProp, (tp:Symbol) -> {
			if (Checker.getDeclarationModifierFlagsFromSymbol(tp) & ModifierFlagsProtected != 0) {
				return !c.isPropertyInClassDerivedFrom(sourceProp, c.getDeclaringClass(tp));
			}
			return false;
		});
	}

	// Return true if some underlying source property is declared in a class that derives
	// from the given base class.
	static function isPropertyInClassDerivedFrom(c:Checker, prop:Symbol, baseClass:Type):Bool {
		return c.forEachProperty(prop, (sp:Symbol) -> {
			final sourceClass = c.getDeclaringClass(sp);
			if (sourceClass != null) {
				return c.hasBaseType(sourceClass, baseClass);
			}
			return false;
		});
	}

	static function isNodeUsedDuringClassInitialization(c:Checker, node:Node):Bool {
		return Ast.FindAncestorOrQuit(node, (element:Node) -> {
			if (Ast.IsConstructorDeclaration(element) && Ast.NodeIsPresent(element.Body()) || Ast.IsPropertyDeclaration(element)) {
				return FindAncestorTrue;
			} else if (Ast.IsClassLike(element) || Ast.IsFunctionLikeDeclaration(element)) {
				return FindAncestorQuit;
			}
			return FindAncestorFalse;
		}) != null;
	}

	static function isNodeWithinClass(c:Checker, node:Node, classDeclaration:Node):Bool {
		return c.forEachEnclosingClass(node, (n:Node) -> {
			return n == classDeclaration;
		});
	}

	static function forEachEnclosingClass(c:Checker, node:Node, callback:(node:Node) -> Bool):Bool {
		var containingClass = Ast.GetContainingClass(node);
		while (containingClass != null) {
			final result = callback(containingClass);
			if (result) {
				return true;
			}
			containingClass = Ast.GetContainingClass(containingClass);
		}
		return false;
	}

	// Return true if the given class derives from each of the declaring classes of the protected
	// constituents of the given property.
	static function isClassDerivedFromDeclaringClasses(c:Checker, checkClass:Type, prop:Symbol, writing:Bool):Bool {
		return !c.forEachProperty(prop, (p:Symbol) -> {
			if (Checker.getDeclarationModifierFlagsFromSymbolEx(p, writing) & ModifierFlagsProtected != 0) {
				return !c.hasBaseType(checkClass, c.getDeclaringClass(p));
			}
			return false;
		});
	}

	static function getEnclosingClassFromThisParameter(c:Checker, node:Node):Type {
		// 'this' type for a node comes from, in priority order...
		// 1. The type of a syntactic 'this' parameter in the enclosing function scope
		final thisParameter = Checker.getThisParameterFromNodeContext(node);
		var thisType:Type = null;
		if (thisParameter != null && thisParameter.Type() != null) {
			thisType = c.getTypeFromTypeNode(thisParameter.Type());
		}
		if (thisType != null) {
			// 2. The constraint of a type parameter used for an explicit 'this' parameter
			if (thisType.flags & TypeFlagsTypeParameter != 0) {
				thisType = c.getConstraintOfTypeParameter(thisType);
			}
		} else {
			// 3. The 'this' parameter of a contextual type
			final thisContainer = Ast.GetThisContainer(node, false /*includeArrowFunctions*/, false /*includeClassComputedPropertyName*/);
			if (thisContainer != null && Ast.IsFunctionLike(thisContainer)) {
				thisType = c.getContextualThisParameterType(thisContainer);
			}
		}
		if (thisType != null && thisType.objectFlags & (ObjectFlagsClassOrInterface | ObjectFlagsReference) != 0) {
			return Checker.getTargetType(thisType);
		}
		return null;
	}
	// PORT: Go builtins min/max on int.
	static inline function imin(a:Int, b:Int):Int {
		return a < b ? a : b;
	}

	static inline function imax(a:Int, b:Int):Int {
		return a > b ? a : b;
	}

	// PORT: Go math.MaxInt / math.MinInt (int is 32-bit here, PORTING.md §3).
	static inline final MAX_INT:Int = 0x7FFFFFFF;
	static inline final MIN_INT:Int = -0x7FFFFFFF - 1;

	// PORT: *ast.SourceFile passed where Go converts it to ast.HasFileName (structural interface);
	// Haxe uses the cached adapter of modulespecifiers (same as CheckerPart2).
	static inline function hasFileName(file:SourceFile):HasFileName {
		return ts.modulespecifiers.Types.SourceFileAdapter.Of(file);
	}

}
