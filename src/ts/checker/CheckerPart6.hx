package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/checker.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Part of checker.go, Go lines 19956-23931 (3976 lines): the Checker methods of this range as static extension
// (receiver first, PORTING.md §2; `using ts.checker.CheckerPart6` in import.hx). Inside class Checker call them as `this.m(...)`.
@:allow(ts.checker)
class CheckerPart6 {

	static function getNonCircularReturnTypeOfSignature(c:Checker, sig:Signature):Type {
		if (c.isResolvingReturnTypeOfSignature(sig)) {
			return c.anyType;
		}
		return c.getReturnTypeOfSignature(sig);
	}

	static function getReturnTypeFromAnnotation(c:Checker, declaration:Node):Type {
		if (Ast.IsConstructorDeclaration(declaration)) {
			return c.getDeclaredTypeOfClassOrInterface(c.getMergedSymbol(declaration.Parent.Symbol()));
		}
		final returnType = declaration.Type();
		if (returnType != null) {
			return c.getTypeFromTypeNode(returnType);
		}
		if (Ast.IsGetAccessorDeclaration(declaration) && c.hasBindableName(declaration)) {
			return c.getAnnotatedAccessorType(Ast.GetDeclarationOfKind(c.getSymbolOfDeclaration(declaration), KindSetAccessor));
		}
		return c.getReturnTypeOfFullSignature(declaration);
	}

	static function getSignatureOfFullSignatureType(c:Checker, node:Node):Signature {
		if (Ast.IsInJSFile(node) && (Ast.IsFunctionDeclaration(node) || Ast.IsMethodDeclaration(node) || Ast.IsFunctionExpressionOrArrowFunction(node)) && node.FunctionLikeData().FullSignature != null) {
			return c.getSingleCallSignature(c.getTypeFromTypeNode(node.FunctionLikeData().FullSignature));
		}
		return null;
	}

	static function getParameterTypeOfFullSignature(c:Checker, node:Node, parameter:ParameterDeclarationNode):Type {
		final signature = c.getSignatureOfFullSignatureType(node);
		if (signature != null) {
			final pos = Slices.Index(node.Parameters(), parameter);
			if (parameter.AsParameterDeclaration().DotDotDotToken != null) {
				return c.getRestTypeAtPosition(signature, pos, false /*readonly*/);
			} else {
				return c.getTypeAtPosition(signature, pos);
			}
		}
		return null;
	}

	static function getReturnTypeOfFullSignature(c:Checker, node:Node):Type {
		final signature = c.getSignatureOfFullSignatureType(node);
		if (signature != null) {
			return c.getReturnTypeOfSignature(signature);
		}
		return null;
	}

	static function getAnnotatedAccessorType(c:Checker, accessor:Node):Type {
		final node = c.getAnnotatedAccessorTypeNode(accessor);
		if (node != null) {
			return c.getTypeFromTypeNode(node);
		}
		return null;
	}

	static function getAnnotatedAccessorTypeNode(c:Checker, accessor:Node):Node {
		if (accessor != null) {
			switch (accessor.Kind) {
				case KindGetAccessor | KindPropertyDeclaration:
					return accessor.Type();
				case KindSetAccessor:
					return Checker.getEffectiveSetAccessorTypeAnnotationNode(accessor);
				default:
			}
		}
		return null;
	}

	static function getReturnTypeFromBody(c:Checker, fn:Node, checkMode:CheckMode):Type {
		final body = fn.Body();
		if (body == null) {
			return c.errorType;
		}
		final functionFlags = Ast.GetFunctionFlags(fn);
		final isAsync = (functionFlags & FunctionFlagsAsync) != 0;
		final isGenerator = (functionFlags & FunctionFlagsGenerator) != 0;
		var returnType:Type = null;
		var yieldType:Type = null;
		var nextType:Type = null;
		var fallbackReturnType:Type = c.voidType;
		if (!Ast.IsBlock(body)) {
			returnType = c.checkExpressionCachedEx(body, checkMode & ~CheckModeSkipGenericFunctions);
			if (c.isConstContext(body)) {
				returnType = c.getRegularTypeOfLiteralType(returnType);
			}
			if (isAsync) {
				// From within an async function you can return either a non-promise value or a promise. Any
				// Promise/A+ compatible implementation will always assimilate any foreign promise, so the
				// return type of the body should be unwrapped to its awaited type, which we will wrap in
				// the native Promise<T> type later in this function.
				returnType = c.unwrapAwaitedType(c.checkAwaitedType(returnType, false /*withAlias*/, fn /*errorNode*/, Diagnostics.The_return_type_of_an_async_function_must_either_be_a_valid_promise_or_must_not_contain_a_callable_then_member));
			}
		} else if (isGenerator) {
			final r = c.checkAndAggregateReturnExpressionTypes(fn, checkMode);
			final returnTypes = r.value;
			final isNeverReturning = r.ok;
			if (isNeverReturning) {
				fallbackReturnType = c.neverType;
			} else if (Core.len(returnTypes) != 0) {
				returnType = c.getUnionTypeEx(returnTypes, UnionReductionSubtype, null, null);
			}
			final yn = c.checkAndAggregateYieldOperandTypes(fn, checkMode);
			final yieldTypes = yn.a;
			final nextTypes = yn.b;
			if (Core.len(yieldTypes) != 0) {
				yieldType = c.getUnionTypeEx(yieldTypes, UnionReductionSubtype, null, null);
			}
			if (Core.len(nextTypes) != 0) {
				nextType = c.getIntersectionType(nextTypes);
			}
		} else {
			final r = c.checkAndAggregateReturnExpressionTypes(fn, checkMode);
			final types = r.value;
			final isNeverReturning = r.ok;
			if (isNeverReturning) {
				// For an async function, the return type will not be never, but rather a Promise for never.
				if ((functionFlags & FunctionFlagsAsync) != 0) {
					return c.createPromiseReturnType(fn, c.neverType);
				}
				// Normal function
				return c.neverType;
			}
			if (Core.len(types) == 0) {
				// For an async function, the return type will not be void/undefined, but rather a Promise for void/undefined.
				final contextualReturnType = c.getContextualReturnType(fn, ContextFlagsNone);
				var returnType:Type;
				if (contextualReturnType != null && Checker.someType(Core.OrElse(c.unwrapReturnType(contextualReturnType, functionFlags), c.voidType), function(t:Type):Bool {
					return (t.flags & TypeFlagsUndefined) != 0;
				})) {
					returnType = c.undefinedType;
				} else {
					returnType = c.voidType;
				}
				if ((functionFlags & FunctionFlagsAsync) != 0) {
					return c.createPromiseReturnType(fn, returnType);
				}
				// Normal function
				return returnType;
			}
			// Return a union of the return expression types.
			returnType = c.getUnionTypeEx(types, UnionReductionSubtype, null, null);
		}
		if (returnType != null || yieldType != null || nextType != null) {
			if (yieldType != null) {
				c.reportErrorsFromWidening(fn, yieldType, WideningKindGeneratorYield);
			}
			if (returnType != null) {
				c.reportErrorsFromWidening(fn, returnType, WideningKindFunctionReturn);
			}
			if (nextType != null) {
				c.reportErrorsFromWidening(fn, nextType, WideningKindGeneratorNext);
			}
			if (returnType != null && Checker.isUnitType(returnType) || yieldType != null && Checker.isUnitType(yieldType) || nextType != null && Checker.isUnitType(nextType)) {
				final contextualSignature = c.getContextualSignatureForFunctionLikeDeclaration(fn);
				var contextualType:Type = null;
				if (contextualSignature == null) {
					// No contextual type
				} else if (contextualSignature == c.getSignatureFromDeclaration(fn)) {
					if (!isGenerator) {
						contextualType = returnType;
					}
				} else {
					contextualType = c.instantiateContextualType(c.getReturnTypeOfSignature(contextualSignature), fn, ContextFlagsNone);
				}
				if (isGenerator) {
					yieldType = c.getWidenedLiteralLikeTypeForContextualIterationTypeIfNeeded(yieldType, contextualType, IterationTypeKindYield, isAsync);
					returnType = c.getWidenedLiteralLikeTypeForContextualIterationTypeIfNeeded(returnType, contextualType, IterationTypeKindReturn, isAsync);
					nextType = c.getWidenedLiteralLikeTypeForContextualIterationTypeIfNeeded(nextType, contextualType, IterationTypeKindNext, isAsync);
				} else {
					returnType = c.getWidenedLiteralLikeTypeForContextualReturnTypeIfNeeded(returnType, contextualType, isAsync);
				}
			}
			if (yieldType != null) {
				yieldType = c.getWidenedType(yieldType);
			}
			if (returnType != null) {
				returnType = c.getWidenedType(returnType);
			}
			if (nextType != null) {
				nextType = c.getWidenedType(nextType);
			}
		}
		if (returnType == null) {
			returnType = fallbackReturnType;
		}
		if (isGenerator) {
			if (yieldType == null) {
				yieldType = c.neverType;
			}
			if (nextType == null) {
				nextType = c.getContextualIterationType(IterationTypeKindNext, fn);
				if (nextType == null) {
					nextType = c.unknownType;
				}
			}
			return c.createGeneratorType(yieldType, returnType, nextType, isAsync);
		}
		// From within an async function you can return either a non-promise value or a promise. Any
		// Promise/A+ compatible implementation will always assimilate any foreign promise, so the
		// return type of the body is awaited type of the body, wrapped in a native Promise<T> type.
		if (isAsync) {
			return c.createPromiseType(returnType);
		}
		return returnType;
	}

	// Returns the aggregated list of return types, plus a bool indicating a never-returning function.
	static function checkAndAggregateReturnExpressionTypes(c:Checker, fn:Node, checkMode:CheckMode):ValueOk<Array<Type>> {
		final functionFlags = Ast.GetFunctionFlags(fn);
		var aggregatedTypes:Array<Type> = null;
		var hasReturnWithNoExpression = c.functionHasImplicitReturn(fn);
		var hasReturnOfTypeNever = false;
		Ast.ForEachReturnStatement(fn.Body(), function(returnStatement:Node):Bool {
			var expr = returnStatement.Expression();
			if (expr == null) {
				hasReturnWithNoExpression = true;
				return false;
			}
			expr = Ast.SkipParentheses(expr);
			// Bare calls to this same function don't contribute to inference
			// and `return await` is also safe to unwrap here
			if ((functionFlags & FunctionFlagsAsync) != 0 && Ast.IsAwaitExpression(expr)) {
				expr = Ast.SkipParentheses(expr.Expression());
			}
			if (Ast.IsCallExpression(expr) && Ast.IsIdentifier(expr.Expression()) && c.checkExpressionCached(expr.Expression()).symbol == c.getMergedSymbol(fn.Symbol())
				&& (!Ast.IsFunctionExpressionOrArrowFunction(fn.Symbol().ValueDeclaration) || c.isConstantReference(expr.Expression()))) {
				hasReturnOfTypeNever = true;
				return false;
			}
			var t = c.checkExpressionCachedEx(expr, checkMode & ~CheckModeSkipGenericFunctions);
			if ((functionFlags & FunctionFlagsAsync) != 0) {
				// From within an async function you can return either a non-promise value or a promise. Any
				// Promise/A+ compatible implementation will always assimilate any foreign promise, so the
				// return type of the body should be unwrapped to its awaited type, which should be wrapped in
				// the native Promise<T> type by the caller.
				t = c.unwrapAwaitedType(c.checkAwaitedType(t, false /*withAlias*/, fn, Diagnostics.The_return_type_of_an_async_function_must_either_be_a_valid_promise_or_must_not_contain_a_callable_then_member));
			}
			if ((t.flags & TypeFlagsNever) != 0) {
				hasReturnOfTypeNever = true;
			}
			if (c.isConstContext(expr)) {
				t = c.getRegularTypeOfLiteralType(t);
			}
			aggregatedTypes = Core.AppendIfUnique(aggregatedTypes, t);
			return false;
		});
		if (Core.len(aggregatedTypes) == 0 && !hasReturnWithNoExpression && (hasReturnOfTypeNever || Checker.mayReturnNever(fn))) {
			return new ValueOk<Array<Type>>(null, true);
		}
		if (c.strictNullChecks && Core.len(aggregatedTypes) != 0 && hasReturnWithNoExpression) {
			aggregatedTypes = Core.AppendIfUnique(aggregatedTypes, c.undefinedType);
		}
		return new ValueOk<Array<Type>>(aggregatedTypes, false);
	}

	static function functionHasImplicitReturn(c:Checker, fn:Node):Bool {
		final endFlowNode = fn.BodyData().EndFlowNode;
		return endFlowNode != null && c.isReachableFlowNode(endFlowNode);
	}

	static function checkAndAggregateYieldOperandTypes(c:Checker, fn:Node, checkMode:CheckMode):Pair<Array<Type>, Array<Type>> {
		var yieldTypes:Array<Type> = null;
		var nextTypes:Array<Type> = null;
		final isAsync = (Ast.GetFunctionFlags(fn) & FunctionFlagsAsync) != 0;
		Checker.forEachYieldExpression(fn.Body(), function(yieldExpr:Node):Bool {
			var yieldExprType = c.undefinedWideningType;
			if (yieldExpr.Expression() != null) {
				yieldExprType = c.checkExpressionEx(yieldExpr.Expression(), checkMode & ~CheckModeSkipGenericFunctions);
			}
			if (yieldExpr.Expression() != null && c.isConstContext(yieldExpr.Expression())) {
				yieldExprType = c.getRegularTypeOfLiteralType(yieldExprType);
			}
			yieldTypes = Core.AppendIfUnique(yieldTypes, c.getYieldedTypeOfYieldExpression(yieldExpr, yieldExprType, c.anyType, isAsync));
			var nextType:Type;
			if (yieldExpr.AsYieldExpression().AsteriskToken != null) {
				final iterationTypes = c.getIterationTypesOfIterable(yieldExprType, Core.IfElse(isAsync, IterationUseAsyncYieldStar, IterationUseYieldStar), yieldExpr.Expression());
				nextType = iterationTypes.nextType;
			} else {
				nextType = c.getContextualType(yieldExpr, ContextFlagsNone);
			}
			if (nextType != null) {
				nextTypes = Core.AppendIfUnique(nextTypes, nextType);
			}
			return false;
		});
		return new Pair<Array<Type>, Array<Type>>(yieldTypes, nextTypes);
	}

	static function createPromiseType(c:Checker, promisedType:Type):Type {
		// creates a `Promise<T>` type where `T` is the promisedType argument
		final globalPromiseType = c.getGlobalPromiseTypeChecked();
		if (globalPromiseType != c.emptyGenericType) {
			// if the promised type is itself a promise, get the underlying type; otherwise, fallback to the promised type
			// Unwrap an `Awaited<T>` to `T` to improve inference.
			promisedType = Core.OrElse(c.getAwaitedTypeNoAlias(c.unwrapAwaitedType(promisedType)), c.unknownType);
			return c.createTypeReference(globalPromiseType, [promisedType]);
		}
		return c.unknownType;
	}

	static function createPromiseLikeType(c:Checker, promisedType:Type):Type {
		// creates a `PromiseLike<T>` type where `T` is the promisedType argument
		final globalPromiseLikeType = c.getGlobalPromiseLikeType();
		if (globalPromiseLikeType != c.emptyGenericType) {
			// if the promised type is itself a promise, get the underlying type; otherwise, fallback to the promised type
			// Unwrap an `Awaited<T>` to `T` to improve inference.
			promisedType = Core.OrElse(c.getAwaitedTypeNoAlias(c.unwrapAwaitedType(promisedType)), c.unknownType);
			return c.createTypeReference(globalPromiseLikeType, [promisedType]);
		}
		return c.unknownType;
	}

	static function createPromiseReturnType(c:Checker, fn:Node, promisedType:Type):Type {
		final promiseType = c.createPromiseType(promisedType);
		if (promiseType == c.unknownType) {
			c.error(fn, Core.IfElse(Ast.IsImportCall(fn),
				Diagnostics.A_dynamic_import_call_returns_a_Promise_Make_sure_you_have_a_declaration_for_Promise_or_include_ES2015_in_your_lib_option,
				Diagnostics.An_async_function_or_method_must_return_a_Promise_Make_sure_you_have_a_declaration_for_Promise_or_include_ES2015_in_your_lib_option));
			return c.errorType;
		}
		if (c.getGlobalPromiseConstructorSymbol() == null) {
			c.error(fn, Core.IfElse(Ast.IsImportCall(fn),
				Diagnostics.A_dynamic_import_call_in_ES5_requires_the_Promise_constructor_Make_sure_you_have_a_declaration_for_the_Promise_constructor_or_include_ES2015_in_your_lib_option,
				Diagnostics.An_async_function_or_method_in_ES5_requires_the_Promise_constructor_Make_sure_you_have_a_declaration_for_the_Promise_constructor_or_include_ES2015_in_your_lib_option));
		}
		return promiseType;
	}

	static function unwrapReturnType(c:Checker, returnType:Type, functionFlags:FunctionFlags):Type {
		final isGenerator = (functionFlags & FunctionFlagsGenerator) != 0;
		final isAsync = (functionFlags & FunctionFlagsAsync) != 0;
		if (isGenerator) {
			final returnIterationType = c.getIterationTypeOfGeneratorFunctionReturnType(IterationTypeKindReturn, returnType, isAsync);
			if (returnIterationType == null) {
				return c.errorType;
			}
			if (isAsync) {
				return c.getAwaitedTypeNoAlias(c.unwrapAwaitedType(returnIterationType));
			}
			return returnIterationType;
		}
		if (isAsync) {
			return Core.OrElse(c.getAwaitedTypeNoAlias(returnType), c.errorType);
		}
		return returnType;
	}

	static function getWidenedLiteralLikeTypeForContextualReturnTypeIfNeeded(c:Checker, t:Type, contextualSignatureReturnType:Type, isAsync:Bool):Type {
		if (t != null && Checker.isUnitType(t)) {
			var contextualType:Type = null;
			if (contextualSignatureReturnType == null) {
				// No contextual type
			} else if (isAsync) {
				contextualType = c.GetPromisedTypeOfPromise(contextualSignatureReturnType);
			} else {
				contextualType = contextualSignatureReturnType;
			}
			t = c.getWidenedLiteralLikeTypeForContextualType(t, contextualType);
		}
		return t;
	}

	static function getWidenedLiteralLikeTypeForContextualIterationTypeIfNeeded(c:Checker, t:Type, contextualSignatureReturnType:Type, kind:IterationTypeKind, isAsyncGenerator:Bool):Type {
		if (t != null && Checker.isUnitType(t)) {
			var contextualType:Type = null;
			if (contextualSignatureReturnType != null) {
				contextualType = c.getIterationTypeOfGeneratorFunctionReturnType(kind, contextualSignatureReturnType, isAsyncGenerator);
			}
			t = c.getWidenedLiteralLikeTypeForContextualType(t, contextualType);
		}
		return t;
	}

	static function createGeneratorType(c:Checker, yieldType:Type, returnType:Type, nextType:Type, isAsyncGenerator:Bool):Type {
		final resolver = Core.IfElse(isAsyncGenerator, c.asyncIterationTypesResolver, c.syncIterationTypesResolver);
		final globalGeneratorType = resolver.getGlobalGeneratorType();
		yieldType = Core.OrElse(resolver.resolveIterationType(yieldType, null /*errorNode*/), c.unknownType);
		returnType = Core.OrElse(resolver.resolveIterationType(returnType, null /*errorNode*/), c.unknownType);
		if (globalGeneratorType == c.emptyGenericType) {
			// Fall back to the global IterableIterator type.
			final globalIterableIteratorType = resolver.getGlobalIterableIteratorType();
			if (globalIterableIteratorType != c.emptyGenericType) {
				return c.createTypeFromGenericGlobalType(globalIterableIteratorType, [yieldType, returnType, nextType]);
			}
			// The global Generator type doesn't exist, so report an error
			resolver.getGlobalIterableIteratorTypeChecked();
			return c.emptyObjectType;
		}
		return c.createTypeFromGenericGlobalType(globalGeneratorType, [yieldType, returnType, nextType]);
	}

	static function reportErrorsFromWidening(c:Checker, declaration:Node, t:Type, wideningKind:WideningKind):Void {
		if (c.noImplicitAny && (t.objectFlags & ObjectFlagsContainsWideningType) != 0) {
			if (wideningKind == WideningKindNormal || Ast.IsFunctionLikeDeclaration(declaration) && c.shouldReportErrorsFromWideningWithContextualSignature(declaration, wideningKind)) {
				// Report implicit any error within type if possible, otherwise report error on declaration
				if (!c.reportWideningErrorsInType(t)) {
					c.reportImplicitAny(declaration, t, wideningKind);
				}
			}
		}
	}

	static function shouldReportErrorsFromWideningWithContextualSignature(c:Checker, declaration:Node, wideningKind:WideningKind):Bool {
		final signature = c.getContextualSignatureForFunctionLikeDeclaration(declaration);
		if (signature == null) {
			return true;
		}
		var returnType = c.getReturnTypeOfSignature(signature);
		final flags = Ast.GetFunctionFlags(declaration);
		switch (wideningKind) {
			case WideningKindFunctionReturn:
				if ((flags & FunctionFlagsGenerator) != 0) {
					returnType = Core.OrElse(c.getIterationTypeOfGeneratorFunctionReturnType(IterationTypeKindReturn, returnType, (flags & FunctionFlagsAsync) != 0), returnType);
				} else if ((flags & FunctionFlagsAsync) != 0) {
					returnType = Core.OrElse(c.getAwaitedTypeNoAlias(returnType), returnType);
				}
				return c.isGenericType(returnType);
			case WideningKindGeneratorYield:
				final yieldType = c.getIterationTypeOfGeneratorFunctionReturnType(IterationTypeKindYield, returnType, (flags & FunctionFlagsAsync) != 0);
				return yieldType != null && c.isGenericType(yieldType);
			case WideningKindGeneratorNext:
				final nextType = c.getIterationTypeOfGeneratorFunctionReturnType(IterationTypeKindNext, returnType, (flags & FunctionFlagsAsync) != 0);
				return nextType != null && c.isGenericType(nextType);
			default:
		}
		return false;
	}

	// Reports implicit any errors that occur as a result of widening 'null' and 'undefined'
	// to 'any'. A call to reportWideningErrorsInType is normally accompanied by a call to
	// getWidenedType. But in some cases getWidenedType is called without reporting errors
	// (type argument inference is an example).
	//
	// The return value indicates whether an error was in fact reported. The particular circumstances
	// are on a best effort basis. Currently, if the null or undefined that causes widening is inside
	// an object literal property (arbitrarily deeply), this function reports an error. If no error is
	// reported, reportImplicitAnyError is a suitable fallback to report a general error.
	static function reportWideningErrorsInType(c:Checker, t:Type):Bool {
		var errorReported = false;
		if ((t.objectFlags & ObjectFlagsContainsWideningType) != 0) {
			if ((t.flags & TypeFlagsUnion) != 0) {
				if (Core.Some(t.Types(), function(t:Type):Bool return c.isEmptyObjectType(t))) {
					errorReported = true;
				} else {
					for (s in rangeOf(t.Types())) {
						errorReported = errorReported || c.reportWideningErrorsInType(s);
					}
				}
			} else if (c.isArrayOrTupleType(t)) {
				for (s in rangeOf(c.getTypeArguments(t))) {
					errorReported = errorReported || c.reportWideningErrorsInType(s);
				}
			} else if (Checker.isObjectLiteralType(t)) {
				for (p in rangeOf(c.getPropertiesOfObjectType(t))) {
					final s = c.getTypeOfSymbol(p);
					if ((s.objectFlags & ObjectFlagsContainsWideningType) != 0) {
						errorReported = c.reportWideningErrorsInType(s);
						if (!errorReported) {
							// we need to account for property types coming from object literal type normalization in unions
							final valueDeclaration = Core.Find(p.Declarations, function(d:Node):Bool {
								final valueDeclaration = d.Symbol().ValueDeclaration;
								return valueDeclaration != null && valueDeclaration.Parent == t.symbol.ValueDeclaration;
							});
							if (valueDeclaration != null) {
								c.error(valueDeclaration, Diagnostics.Object_literal_s_property_0_implicitly_has_an_1_type, c.symbolToString(p), c.TypeToString(c.getWidenedType(s)));
								errorReported = true;
							}
						}
					}
				}
			}
		}
		return errorReported;
	}

	static function getTypePredicateFromBody(c:Checker, fn:Node):TypePredicate {
		switch (fn.Kind) {
			case KindConstructor | KindGetAccessor | KindSetAccessor:
				return null;
			default:
		}
		final functionFlags = Ast.GetFunctionFlags(fn);
		if (functionFlags != FunctionFlagsNormal) {
			return null;
		}
		// Only attempt to infer a type predicate if there's exactly one return.
		var singleReturn:Node = null;
		final body = fn.Body();
		if (body != null && !Ast.IsBlock(body)) {
			// arrow function
			singleReturn = body;
		} else {
			final bailedEarly = Ast.ForEachReturnStatement(body, function(returnStatement:Node):Bool {
				if (singleReturn != null || returnStatement.Expression() == null) {
					return true;
				}
				singleReturn = returnStatement.Expression();
				return false;
			});
			if (bailedEarly || singleReturn == null || c.functionHasImplicitReturn(fn)) {
				return null;
			}
		}
		return c.checkIfExpressionRefinesAnyParameter(fn, singleReturn);
	}

	static function checkIfExpressionRefinesAnyParameter(c:Checker, fn:Node, expr:Node):TypePredicate {
		expr = Ast.SkipParentheses(expr);
		final returnType = c.checkExpressionCached(expr);
		if ((returnType.flags & TypeFlagsBoolean) == 0) {
			return null;
		}
		final params = rangeOf(fn.Parameters());
		for (i in 0...params.length) {
			final param = params[i];
			final initType = c.getTypeOfSymbol(param.Symbol());
			if (initType == null || (initType.flags & TypeFlagsBoolean) != 0 || !Ast.IsIdentifier(param.Name()) || c.isSymbolAssigned(param.Symbol()) || Checker.isRestParameter(param)) {
				// Refining "x: boolean" to "x is true" or "x is false" isn't useful.
				continue;
			}
			final trueType = c.checkIfExpressionRefinesParameter(fn, expr, param, initType);
			if (trueType != null) {
				return c.newTypePredicate(TypePredicateKindIdentifier, param.Name().Text(), i, trueType);
			}
		}
		return null;
	}

	static function checkIfExpressionRefinesParameter(c:Checker, fn:Node, expr:Node, param:Node, initType:Type):Type {
		var antecedent = Checker.getFlowNodeOfNode(expr);
		if (antecedent == null && Ast.IsReturnStatement(expr.Parent)) {
			antecedent = Checker.getFlowNodeOfNode(expr.Parent);
		}
		if (antecedent == null) {
			antecedent = new FlowNode();
			antecedent.Flags = FlowFlagsStart;
		}
		final trueCondition = new FlowNode();
		trueCondition.Flags = FlowFlagsTrueCondition;
		trueCondition.Node = expr;
		trueCondition.Antecedent = antecedent;
		final trueType = c.getFlowTypeOfReferenceEx(param.Name(), initType, initType, fn, trueCondition);
		if (trueType == initType) {
			return null;
		}
		// "x is T" means that x is T if and only if it returns true. If it returns false then x is not T.
		// This means that if the function is called with an argument of type trueType, there can't be anything left in the `else` branch. It must reduce to `never`.
		final falseCondition = new FlowNode();
		falseCondition.Flags = FlowFlagsFalseCondition;
		falseCondition.Node = expr;
		falseCondition.Antecedent = antecedent;
		final falseSubtype = c.getReducedType(c.getFlowTypeOfReferenceEx(param.Name(), initType, trueType, fn, falseCondition));
		if ((falseSubtype.flags & TypeFlagsNever) != 0) {
			return trueType;
		}
		return null;
	}

	static function addOptionalTypeMarker(c:Checker, t:Type):Type {
		if (c.strictNullChecks) {
			return c.getUnionType([t, c.optionalType]);
		}
		return t;
	}

	static function instantiateSignature(c:Checker, sig:Signature, m:TypeMapper):Signature {
		return c.instantiateSignatureEx(sig, m, m == c.permissiveMapper /*eraseTypeParameters*/);
	}

	static function instantiateSignatureEx(c:Checker, sig:Signature, m:TypeMapper, eraseTypeParameters:Bool):Signature {
		var freshTypeParameters:Array<Type> = null;
		if (Core.len(sig.typeParameters) != 0 && !eraseTypeParameters) {
			// First create a fresh set of type parameters, then include a mapping from the old to the
			// new type parameters in the mapper function. Finally store this mapper in the new type
			// parameters such that we can use it when instantiating constraints.
			freshTypeParameters = Core.Map(sig.typeParameters, function(tp:Type):Type return c.cloneTypeParameter(tp));
			m = c.combineTypeMappers(Checker.newTypeMapper(sig.typeParameters, freshTypeParameters), m);
			for (tp in freshTypeParameters) {
				tp.AsTypeParameter().mapper = m;
			}
		}
		// Don't compute resolvedReturnType and resolvedTypePredicate now,
		// because using `mapper` now could trigger inferences to become fixed. (See `createInferenceContext`.)
		// See GH#17600.
		final result = c.newSignature(sig.flags & SignatureFlagsPropagatingFlags, sig.declaration, freshTypeParameters,
			c.instantiateSymbol(sig.thisParameter, m), c.instantiateSymbols(sig.parameters, m),
			null /*resolvedReturnType*/, null /*resolvedTypePredicate*/, sig.minArgumentCount);
		result.target = sig;
		result.mapper = m;
		return result;
	}

	static function instantiateIndexInfo(c:Checker, info:IndexInfo, m:TypeMapper):IndexInfo {
		final newValueType = c.instantiateType(info.valueType, m);
		if (newValueType == info.valueType) {
			return info;
		}
		return c.newIndexInfo(info.keyType, newValueType, info.isReadonly, info.declaration, info.components);
	}

	static function resolveAnonymousTypeMembers(c:Checker, t:Type):Void {
		final d = t.AsObjectType();
		if (d.target != null) {
			c.setStructuredTypeMembers(t, null, null, null, null);
			final members = c.createInstantiatedSymbolTable(c.getPropertiesOfObjectType(d.target), d.mapper);
			final callSignatures = c.instantiateSignatures(c.getSignaturesOfType(d.target, SignatureKindCall), d.mapper);
			final constructSignatures = c.instantiateSignatures(c.getSignaturesOfType(d.target, SignatureKindConstruct), d.mapper);
			final indexInfos = c.instantiateIndexInfos(c.getIndexInfosOfType(d.target), d.mapper);
			c.setStructuredTypeMembers(t, members, callSignatures, constructSignatures, indexInfos);
			return;
		}
		final symbol = c.getMergedSymbol(t.symbol);
		if ((symbol.Flags & SymbolFlagsTypeLiteral) != 0) {
			c.setStructuredTypeMembers(t, null, null, null, null);
			final members = c.getMembersOfSymbol(symbol);
			final callSignatures = c.getSignaturesOfSymbol(symbolTableGet(members, Ast.InternalSymbolNameCall));
			final constructSignatures = c.getSignaturesOfSymbol(symbolTableGet(members, Ast.InternalSymbolNameNew));
			final indexInfos = c.getIndexInfosOfSymbol(symbol);
			c.setStructuredTypeMembers(t, members, callSignatures, constructSignatures, indexInfos);
			return;
		}
		// Combinations of function, class, enum and module
		var members = c.getExportsOfSymbol(symbol);
		var indexInfos:Array<IndexInfo> = null;
		if (symbol == c.globalThisSymbol) {
			final varsOnly = new SymbolTable();
			if (members != null) {
				for (p in members) {
					if ((p.Flags & SymbolFlagsBlockScoped) == 0 && !((p.Flags & SymbolFlagsValueModule) != 0 && Core.len(p.Declarations) != 0 && Core.Every(p.Declarations, Ast.IsAmbientModule))) {
						varsOnly.set(p.Name, p);
					}
				}
			}
			members = varsOnly;
		}
		var baseConstructorIndexInfo:IndexInfo = null;
		c.setStructuredTypeMembers(t, members, null, null, null);
		if ((symbol.Flags & SymbolFlagsClass) != 0) {
			final classType = c.getDeclaredTypeOfClassOrInterface(symbol);
			final baseConstructorType = c.getBaseConstructorTypeOfClass(classType);
			if ((baseConstructorType.flags & (TypeFlagsObject | TypeFlagsIntersection | TypeFlagsTypeVariable)) != 0) {
				members = cloneSymbolTable(members);
				c.addInheritedMembers(members, c.getPropertiesOfType(baseConstructorType));
				c.setStructuredTypeMembers(t, members, null, null, null);
			} else if (baseConstructorType == c.anyType) {
				baseConstructorIndexInfo = c.anyBaseTypeIndexInfo;
			}
		}
		final indexSymbol = symbolTableGet(members, Ast.InternalSymbolNameIndex);
		if (indexSymbol != null) {
			indexInfos = c.getIndexInfosOfIndexSymbol(indexSymbol, symbolTableValuesArray(members));
		} else {
			if (baseConstructorIndexInfo != null) {
				indexInfos = appendOne(indexInfos, baseConstructorIndexInfo);
			}
			if ((symbol.Flags & SymbolFlagsEnum) != 0 && ((c.getDeclaredTypeOfSymbol(symbol).flags & TypeFlagsEnum) != 0 || Core.Some(d.properties, function(prop:Symbol):Bool {
				return (c.getTypeOfSymbol(prop).flags & TypeFlagsNumberLike) != 0;
			}))) {
				indexInfos = appendOne(indexInfos, c.enumNumberIndexInfo);
			}
		}
		d.indexInfos = indexInfos;
		// We resolve the members before computing the signatures because a signature may use
		// typeof with a qualified name expression that circularly references the type we are
		// in the process of resolving (see issue #6072). The temporarily empty signature list
		// will never be observed because a qualified name can't reference signatures.
		if ((symbol.Flags & (SymbolFlagsFunction | SymbolFlagsMethod)) != 0) {
			d.signatures = c.getSignaturesOfSymbol(symbol);
			d.callSignatureCount = Core.len(d.signatures);
		}
		// And likewise for construct signatures for classes
		if ((symbol.Flags & SymbolFlagsClass) != 0) {
			final classType = c.getDeclaredTypeOfClassOrInterface(symbol);
			var constructSignatures = c.getSignaturesOfSymbol(symbolTableGet(symbol.Members, Ast.InternalSymbolNameConstructor));
			if (Core.len(constructSignatures) == 0) {
				constructSignatures = c.getDefaultConstructSignatures(classType);
			}
			d.signatures = appendAll(d.signatures, constructSignatures);
		}
	}

	static function createInstantiatedSymbolTable(c:Checker, symbols:Array<Symbol>, m:TypeMapper):SymbolTable {
		if (Core.len(symbols) == 0) {
			return null;
		}
		final result = new SymbolTable();
		for (symbol in symbols) {
			result.set(symbol.Name, c.instantiateSymbol(symbol, m));
		}
		return result;
	}

	static function instantiateSymbolTable(c:Checker, symbols:SymbolTable, m:TypeMapper):SymbolTable {
		if (symbolTableLen(symbols) == 0) {
			return null;
		}
		final result = new SymbolTable();
		for (id => symbol in symbols) {
			if (c.isNamedMember(symbol, id)) {
				result.set(id, c.instantiateSymbol(symbol, m));
			}
		}
		return result;
	}

	static function instantiateSymbol(c:Checker, symbol:Symbol, m:TypeMapper):Symbol {
		if (symbol == null) {
			return null;
		}
		final links = c.valueSymbolLinks.Get(symbol);
		if (m != null && m.MapsThisOnly() && Checker.isThisless(symbol)) {
			return symbol;
		}
		// If the type of the symbol is already resolved, and if that type could not possibly
		// be affected by instantiation, simply return the symbol itself.
		if (links.resolvedType != null && !c.couldContainTypeVariables(links.resolvedType)) {
			if ((symbol.Flags & SymbolFlagsSetAccessor) == 0) {
				return symbol;
			}
			// If we're a setter, check writeType.
			if (links.writeType != null && !c.couldContainTypeVariables(links.writeType)) {
				return symbol;
			}
		}
		if ((symbol.CheckFlags & CheckFlagsInstantiated) != 0) {
			// If symbol being instantiated is itself a instantiation, fetch the original target and combine the
			// type mappers. This ensures that original type identities are properly preserved and that aliases
			// always reference a non-aliases.
			symbol = links.target;
			m = c.combineTypeMappers(links.mapper, m);
		}
		// Keep the flags from the symbol we're instantiating.  Mark that is instantiated, and
		// also transient so that we can just store data on it directly.
		final result = c.newSymbol(symbol.Flags, symbol.Name);
		result.CheckFlags = CheckFlagsInstantiated | (symbol.CheckFlags & (CheckFlagsReadonly | CheckFlagsLate | CheckFlagsOptionalParameter | CheckFlagsRestParameter));
		result.Declarations = symbol.Declarations;
		result.Parent = symbol.Parent;
		result.ValueDeclaration = symbol.ValueDeclaration;
		final resultLinks = c.valueSymbolLinks.Get(result);
		resultLinks.target = symbol;
		resultLinks.mapper = m;
		resultLinks.nameType = links.nameType;
		return result;
	}

	static function getDefaultConstructSignatures(c:Checker, classType:Type):Array<Signature> {
		final baseConstructorType = c.getBaseConstructorTypeOfClass(classType);
		final baseSignatures = c.getSignaturesOfType(baseConstructorType, SignatureKindConstruct);
		final declaration = Ast.GetClassLikeDeclarationOfSymbol(classType.symbol);
		final isAbstract = declaration != null && Ast.HasSyntacticModifier(declaration, ModifierFlagsAbstract);
		if (Core.len(baseSignatures) == 0) {
			final flags = Core.IfElse(isAbstract, SignatureFlagsConstruct | SignatureFlagsAbstract, SignatureFlagsConstruct);
			return [c.newSignature(flags, null, classType.AsInterfaceType().LocalTypeParameters(), null, null, classType, null, 0)];
		}
		final baseTypeNode = Checker.getBaseTypeNodeOfClass(classType);
		final isJavaScript = declaration != null && Ast.IsInJSFile(declaration);
		final typeArguments = c.getTypeArgumentsFromNode(baseTypeNode);
		final typeArgCount = Core.len(typeArguments);
		var result:Array<Signature> = null;
		for (baseSig in baseSignatures) {
			final minTypeArgumentCount = c.getMinTypeArgumentCount(baseSig.typeParameters);
			final typeParamCount = Core.len(baseSig.typeParameters);
			if (isJavaScript || typeArgCount >= minTypeArgumentCount && typeArgCount <= typeParamCount) {
				var sig:Signature;
				if (typeParamCount != 0) {
					sig = c.createSignatureInstantiation(baseSig, c.fillMissingTypeArguments(typeArguments, baseSig.typeParameters, minTypeArgumentCount, isJavaScript));
				} else {
					sig = c.cloneSignature(baseSig);
				}
				sig.typeParameters = classType.AsInterfaceType().LocalTypeParameters();
				sig.resolvedReturnType = classType;
				if (isAbstract) {
					sig.flags |= SignatureFlagsAbstract;
				} else {
					sig.flags &= ~SignatureFlagsAbstract;
				}
				result = appendOne(result, sig);
			}
		}
		return result;
	}

	static function resolveMappedTypeMembers(c:Checker, t:Type):Void {
		final members = new SymbolTable();
		var indexInfos:Array<IndexInfo> = null;
		// Resolve upfront such that recursive references see an empty object type.
		c.setStructuredTypeMembers(t, null, null, null, null);
		// In { [P in K]: T }, we refer to P as the type parameter type, K as the constraint type,
		// and T as the template type.
		final typeParameter = c.getTypeParameterFromMappedType(t);
		final constraintType = c.getConstraintTypeFromMappedType(t);
		final mappedType = Core.OrElse(t.AsMappedType().target, t);
		final nameType = c.getNameTypeFromMappedType(mappedType);
		final shouldLinkPropDeclarations = c.getMappedTypeNameTypeKind(mappedType) != MappedTypeNameTypeKindRemapping;
		final templateType = c.getTemplateTypeFromMappedType(mappedType);
		final modifiersType = c.getApparentType(c.getModifiersTypeFromMappedType(t));
		// The 'T' in 'keyof T'
		final templateModifiers = Checker.getMappedTypeModifiers(t);
		final include = TypeFlagsStringOrNumberLiteralOrUnique;
		final addMemberForKeyTypeWorker = function(keyType:Type, propNameType:Type):Void {
			// If the current iteration type constituent is a string literal type, create a property.
			// Otherwise, for type string create a string index signature.
			if (Checker.isTypeUsableAsPropertyName(propNameType)) {
				final propName = Checker.getPropertyNameFromType(propNameType);
				// String enum members from separate enums with identical values
				// are distinct types with the same property name. Make the resulting
				// property symbol's name type be the union of those enum member types.
				final existingProp = members.get(propName);
				if (existingProp != null) {
					final valueLinks = c.valueSymbolLinks.Get(existingProp);
					valueLinks.nameType = c.getUnionType([valueLinks.nameType, propNameType]);
					final mappedLinks = c.mappedSymbolLinks.Get(existingProp);
					mappedLinks.keyType = c.getUnionType([mappedLinks.keyType, keyType]);
				} else {
					var modifiersProp:Symbol = null;
					if (Checker.isTypeUsableAsPropertyName(keyType)) {
						modifiersProp = c.getPropertyOfType(modifiersType, Checker.getPropertyNameFromType(keyType));
					}
					final isOptional = (templateModifiers & MappedTypeModifiersIncludeOptional) != 0 || (templateModifiers & MappedTypeModifiersExcludeOptional) == 0 && modifiersProp != null && (modifiersProp.Flags & SymbolFlagsOptional) != 0;
					final isReadonly = (templateModifiers & MappedTypeModifiersIncludeReadonly) != 0 || (templateModifiers & MappedTypeModifiersExcludeReadonly) == 0 && modifiersProp != null && c.isReadonlySymbol(modifiersProp);
					final stripOptional = c.strictNullChecks && !isOptional && modifiersProp != null && (modifiersProp.Flags & SymbolFlagsOptional) != 0;
					var lateFlag:CheckFlags = CheckFlagsNone;
					if (modifiersProp != null) {
						lateFlag = modifiersProp.CheckFlags & CheckFlagsLate;
					}
					final prop = c.newSymbol(SymbolFlagsProperty | Core.IfElse(isOptional, SymbolFlagsOptional, SymbolFlagsNone), propName);
					prop.CheckFlags = lateFlag | CheckFlagsMapped | Core.IfElse(isReadonly, CheckFlagsReadonly, CheckFlagsNone) | Core.IfElse(stripOptional, CheckFlagsStripOptional, CheckFlagsNone);
					final valueLinks = c.valueSymbolLinks.Get(prop);
					valueLinks.containingType = t;
					valueLinks.nameType = propNameType;
					final mappedLinks = c.mappedSymbolLinks.Get(prop);
					mappedLinks.keyType = keyType;
					if (modifiersProp != null) {
						mappedLinks.syntheticOrigin = modifiersProp;
						if (shouldLinkPropDeclarations) {
							prop.Declarations = modifiersProp.Declarations;
						}
					}
					members.set(propName, prop);
				}
			} else if (c.isValidIndexKeyType(propNameType) || (propNameType.flags & (TypeFlagsAny | TypeFlagsEnum)) != 0) {
				var indexKeyType = propNameType;
				if ((propNameType.flags & (TypeFlagsAny | TypeFlagsString)) != 0) {
					indexKeyType = c.stringType;
				} else if ((propNameType.flags & (TypeFlagsNumber | TypeFlagsEnum)) != 0) {
					indexKeyType = c.numberType;
				}
				final propType = c.instantiateType(templateType, Checker.appendTypeMapping(t.AsMappedType().mapper, typeParameter, keyType));
				final modifiersIndexInfo = c.getApplicableIndexInfo(modifiersType, propNameType);
				final isReadonly = (templateModifiers & MappedTypeModifiersIncludeReadonly) != 0 || (templateModifiers & MappedTypeModifiersExcludeReadonly) == 0 && modifiersIndexInfo != null && modifiersIndexInfo.isReadonly;
				final indexInfo = c.newIndexInfo(indexKeyType, propType, isReadonly, null, null);
				indexInfos = c.appendIndexInfo(indexInfos, indexInfo, true /*union*/);
			}
		};
		final addMemberForKeyType = function(keyType:Type):Void {
			var propNameType = keyType;
			if (nameType != null) {
				propNameType = c.instantiateType(nameType, Checker.appendTypeMapping(t.AsMappedType().mapper, typeParameter, keyType));
			}
			Checker.forEachType(propNameType, function(t:Type):Void {
				addMemberForKeyTypeWorker(keyType, t);
			});
		};
		if (c.isMappedTypeWithKeyofConstraintDeclaration(t)) {
			// We have a { [P in keyof T]: X }
			c.forEachMappedTypePropertyKeyTypeAndIndexSignatureKeyType(modifiersType, include, false /*stringsOnly*/, addMemberForKeyType);
		} else {
			Checker.forEachType(c.getLowerBoundOfKeyType(constraintType), addMemberForKeyType);
		}
		c.setStructuredTypeMembers(t, members, null, null, indexInfos);
	}

	static function getTypeOfMappedSymbol(c:Checker, symbol:Symbol):Type {
		final links = c.valueSymbolLinks.Get(symbol);
		if (links.resolvedType == null) {
			final mappedType = links.containingType;
			if (!c.pushTypeResolution(entity(symbol), TypeSystemPropertyNameType)) {
				mappedType.AsMappedType().containsError = true;
				return c.errorType;
			}
			final templateType = c.getTemplateTypeFromMappedType(Core.OrElse(mappedType.AsMappedType().target, mappedType));
			final mapper = Checker.appendTypeMapping(mappedType.AsMappedType().mapper, c.getTypeParameterFromMappedType(mappedType), c.mappedSymbolLinks.Get(symbol).keyType);
			var propType = c.instantiateType(templateType, mapper);
			// When creating an optional property in strictNullChecks mode, if 'undefined' isn't assignable to the
			// type, we include 'undefined' in the type. Similarly, when creating a non-optional property in strictNullChecks
			// mode, if the underlying property is optional we remove 'undefined' from the type.
			if (c.strictNullChecks && (symbol.Flags & SymbolFlagsOptional) != 0 && !c.maybeTypeOfKind(propType, TypeFlagsUndefined | TypeFlagsVoid)) {
				propType = c.getOptionalType(propType, true /*isProperty*/);
			} else if ((symbol.CheckFlags & CheckFlagsStripOptional) != 0) {
				propType = c.removeMissingOrUndefinedType(propType);
			}
			if (c.popTypeResolution()) {
				if (links.resolvedType == null) {
					links.resolvedType = propType;
				}
			} else {
				if (links.resolvedType == null) {
					links.resolvedType = c.errorType;
				}
				c.error(c.currentNode, Diagnostics.Type_of_property_0_circularly_references_itself_in_mapped_type_1, c.symbolToString(symbol), c.TypeToString(mappedType));
			}
		}
		return links.resolvedType;
	}

	// Return the lower bound of the key type in a mapped type. Intuitively, the lower
	// bound includes those keys that are known to always be present, for example because
	// because of constraints on type parameters (e.g. 'keyof T' for a constrained T).
	static function getLowerBoundOfKeyType(c:Checker, t:Type):Type {
		if ((t.flags & TypeFlagsIndex) != 0) {
			final t = c.getApparentType(t.AsIndexType().target);
			if (c.isGenericTupleType(t)) {
				return c.getKnownKeysOfTupleType(t);
			}
			return c.getIndexType(t);
		} else if ((t.flags & TypeFlagsConditional) != 0) {
			if (t.AsConditionalType().root.isDistributive) {
				final checkType = t.AsConditionalType().checkType;
				final constraint = c.getLowerBoundOfKeyType(checkType);
				if (constraint != checkType) {
					return c.getConditionalTypeInstantiation(t, Checker.prependTypeMapping(t.AsConditionalType().root.checkType, constraint, t.AsConditionalType().mapper), false /*forConstraint*/, null);
				}
			}
			return t;
		} else if ((t.flags & TypeFlagsUnion) != 0) {
			return c.mapTypeEx(t, function(t:Type):Type return c.getLowerBoundOfKeyType(t), true /*noReductions*/);
		} else if ((t.flags & TypeFlagsIntersection) != 0) {
			// Similarly to getTypeFromIntersectionTypeNode, we preserve the special string & {}, number & {},
			// and bigint & {} intersections that are used to prevent subtype reduction in union types.
			final types = t.Types();
			if (types.length == 2 && (types[0].flags & (TypeFlagsString | TypeFlagsNumber | TypeFlagsBigInt)) != 0 && types[1] == c.emptyTypeLiteralType) {
				return t;
			}
			return c.getIntersectionType(Core.SameMap(t.Types(), function(t:Type):Type return c.getLowerBoundOfKeyType(t)));
		}
		return t;
	}

	static function resolveUnionTypeMembers(c:Checker, t:Type):Void {
		// The members and properties collections are empty for union types. To get all properties of a union
		// type use getPropertiesOfType (only the language service uses this).
		var callSignatures = c.getUnionSignatures(Core.Map(t.Types(), function(t:Type):Array<Signature> {
			if (t == c.globalFunctionType) {
				return [c.unknownSignature];
			}
			return c.getSignaturesOfType(t, SignatureKindCall);
		}));
		if (Core.len(callSignatures) == 0) {
			callSignatures = c.getArrayMemberCallSignatures(t);
		}
		final constructSignatures = c.getUnionSignatures(Core.Map(t.Types(), function(t:Type):Array<Signature> {
			return c.getSignaturesOfType(t, SignatureKindConstruct);
		}));
		final indexInfos = c.getUnionIndexInfos(t.Types());
		c.setStructuredTypeMembers(t, null, callSignatures, constructSignatures, indexInfos);
	}

	static function getArrayMemberCallSignatures(c:Checker, t:Type):Array<Signature> {
		// Check if union is exclusively instantiations of a member of the global Array or ReadonlyArray type.
		var memberName = "";
		final types = t.Types();
		for (i in 0...types.length) {
			final t = types[i];
			if ((t.objectFlags & ObjectFlagsInstantiated) == 0 || t.symbol == null || t.symbol.Parent == null || !c.isArrayOrTupleSymbol(t.symbol.Parent)) {
				return null;
			}
			if (i == 0) {
				memberName = t.symbol.Name;
			} else if (memberName != t.symbol.Name) {
				return null;
			}
		}
		// Transform the type from `(A[] | B[])["member"]` to `(A | B)[]["member"]` (since we pretend array is covariant anyway).
		final arrayArg = c.mapType(t, function(t:Type):Type {
			return t.Mapper().Map((c.isReadonlyArraySymbol(t.symbol.Parent) ? c.globalReadonlyArrayType : c.globalArrayType).AsInterfaceType().TypeParameters()[0]);
		});
		final arrayType = c.createArrayTypeEx(arrayArg, Checker.someType(t, function(t:Type):Bool {
			return c.isReadonlyArraySymbol(t.symbol.Parent);
		}));
		return c.getSignaturesOfType(c.getTypeOfPropertyOfType(arrayType, memberName), SignatureKindCall);
	}

	static function isArrayOrTupleSymbol(c:Checker, symbol:Symbol):Bool {
		if (symbol == null || c.globalArrayType.symbol == null || c.globalReadonlyArrayType.symbol == null) {
			return false;
		}
		return c.getSymbolIfSameReference(symbol, c.globalArrayType.symbol) != null || c.getSymbolIfSameReference(symbol, c.globalReadonlyArrayType.symbol) != null;
	}

	static function isReadonlyArraySymbol(c:Checker, symbol:Symbol):Bool {
		if (symbol == null || c.globalReadonlyArrayType.symbol == null) {
			return false;
		}
		return c.getSymbolIfSameReference(symbol, c.globalReadonlyArrayType.symbol) != null;
	}

	// The signatures of a union type are those signatures that are present in each of the constituent types.
	// Generic signatures must match exactly, but non-generic signatures are allowed to have extra optional
	// parameters and may differ in return types. When signatures differ in return types, the resulting return
	// type is the union of the constituent return types.
	static function getUnionSignatures(c:Checker, signatureLists:Array<Array<Signature>>):Array<Signature> {
		var result:Array<Signature> = null;
		var indexWithLengthOverOne = 0;
		var countLengthOverOne = 0;
		for (i in 0...signatureLists.length) {
			if (Core.len(signatureLists[i]) == 0) {
				return null;
			}
			if (signatureLists[i].length > 1) {
				indexWithLengthOverOne = i;
				countLengthOverOne++;
			}
			for (signature in signatureLists[i]) {
				// Only process signatures with parameter lists that aren't already in the result list
				if (result == null || c.findMatchingSignature(result, signature, false /*partialMatch*/, false /*ignoreThisTypes*/, true /*ignoreReturnTypes*/) == null) {
					final unionSignatures = c.findMatchingSignatures(signatureLists, signature, i);
					if (unionSignatures != null) {
						var s = signature;
						// Union the result types when more than one signature matches
						if (unionSignatures.length > 1) {
							var thisParameter = signature.thisParameter;
							final firstThisParameterOfUnionSignatures = Core.FirstNonNil(unionSignatures, function(sig:Signature):Symbol {
								return sig.thisParameter;
							});
							if (firstThisParameterOfUnionSignatures != null) {
								final thisType = c.getIntersectionType(Core.MapNonNil(unionSignatures, function(sig:Signature):Type {
									if (sig.thisParameter != null) {
										return c.getTypeOfSymbol(sig.thisParameter);
									}
									return null;
								}));
								thisParameter = c.createSymbolWithType(firstThisParameterOfUnionSignatures, thisType);
							}
							s = c.createUnionSignature(signature, unionSignatures);
							s.thisParameter = thisParameter;
						}
						if (result == null) {
							result = [];
						}
						result.push(s);
					}
				}
			}
		}
		if (Core.len(result) == 0 && countLengthOverOne <= 1) {
			// No sufficiently similar signature existed to subsume all the other signatures in the union - time to see if we can make a single
			// signature that handles all of them. We only do this when there are overloads in only one constituent. (Overloads are conditional in
			// nature and having overloads in multiple constituents would necessitate making a power set of signatures from the type, whose
			// ordering would be non-obvious)
			final masterList = signatureLists[indexWithLengthOverOne];
			var results:Array<Signature> = masterList.copy();
			for (signatures in signatureLists) {
				if (!Core.Same(signatures, masterList)) {
					final signature = signatures[0];
					Debug.Assert(signature != null, "getUnionSignatures bails early on empty signature lists and should not have empty lists on second pass");
					if (Core.len(signature.typeParameters) != 0 && Core.Some(results, function(s:Signature):Bool {
						return Core.len(s.typeParameters) != 0 && !c.compareTypeParametersIdentical(signature.typeParameters, s.typeParameters);
					})) {
						results = null;
					} else {
						results = Core.Map(results, function(sig:Signature):Signature {
							return c.combineUnionOrIntersectionMemberSignatures(sig, signature, true /*isUnion*/);
						});
					}
					if (results == null) {
						break;
					}
				}
			}
			result = results;
		}
		return result;
	}

	static function combineUnionOrIntersectionMemberSignatures(c:Checker, left:Signature, right:Signature, isUnion:Bool):Signature {
		var typeParams = left.typeParameters;
		if (Core.len(typeParams) == 0) {
			typeParams = right.typeParameters;
		}
		var paramMapper:TypeMapper = null;
		if (Core.len(left.typeParameters) != 0 && Core.len(right.typeParameters) != 0) {
			// We just use the type parameter defaults from the first signature
			paramMapper = Checker.newTypeMapper(right.typeParameters, left.typeParameters);
		}
		var flags:SignatureFlags = (left.flags | right.flags) & (SignatureFlagsPropagatingFlags & ~SignatureFlagsHasRestParameter);
		final declaration = left.declaration;
		final params = c.combineUnionOrIntersectionParameters(left, right, paramMapper, isUnion);
		final lastParam = Core.LastOrNil(params);
		if (lastParam != null && (lastParam.CheckFlags & CheckFlagsRestParameter) != 0) {
			flags |= SignatureFlagsHasRestParameter;
		}
		final thisParam = c.combineUnionOrIntersectionThisParam(left.thisParameter, right.thisParameter, paramMapper, isUnion);
		final minArgCount = left.minArgumentCount > right.minArgumentCount ? left.minArgumentCount : right.minArgumentCount;
		final result = c.newSignature(flags, declaration, typeParams, thisParam, params, null, null, minArgCount);
		var leftSignatures:Array<Signature>;
		if (left.composite != null && left.composite.isUnion) {
			leftSignatures = left.composite.signatures;
		} else {
			leftSignatures = [left];
		}
		final composite = new CompositeSignature();
		composite.isUnion = isUnion;
		// PORT: Go `append(leftSignatures, right)` must not mutate left.composite.signatures; copy first.
		final compositeSignatures = leftSignatures != null ? leftSignatures.copy() : [];
		compositeSignatures.push(right);
		composite.signatures = compositeSignatures;
		result.composite = composite;
		if (paramMapper != null) {
			if (left.composite != null && left.composite.isUnion == isUnion && left.mapper != null) {
				result.mapper = c.combineTypeMappers(left.mapper, paramMapper);
			} else {
				result.mapper = paramMapper;
			}
		} else if (left.composite != null && left.composite.isUnion == isUnion) {
			result.mapper = left.mapper;
		}
		return result;
	}

	static function combineUnionOrIntersectionParameters(c:Checker, left:Signature, right:Signature, mapper:TypeMapper, isUnion:Bool):Array<Symbol> {
		final leftCount = c.getParameterCount(left);
		final rightCount = c.getParameterCount(right);
		var longestCount:Int;
		var longest:Signature;
		var shorter:Signature;
		if (leftCount >= rightCount) {
			longestCount = leftCount;
			longest = left;
			shorter = right;
		} else {
			longestCount = rightCount;
			longest = right;
			shorter = left;
		}
		final eitherHasEffectiveRest = c.hasEffectiveRestParameter(left) || c.hasEffectiveRestParameter(right);
		final needsExtraRestElement = eitherHasEffectiveRest && !c.hasEffectiveRestParameter(longest);
		final params:Array<Symbol> = [for (_ in 0...(longestCount + (needsExtraRestElement ? 1 : 0))) null];
		for (i in 0...longestCount) {
			var longestParamType = c.tryGetTypeAtPosition(longest, i);
			if (longest == right) {
				longestParamType = c.instantiateType(longestParamType, mapper);
			}
			var shorterParamType = Core.OrElse(c.tryGetTypeAtPosition(shorter, i), c.unknownType);
			if (shorter == right) {
				shorterParamType = c.instantiateType(shorterParamType, mapper);
			}
			final combinedParamType = c.getUnionOrIntersectionType([longestParamType, shorterParamType], !isUnion, UnionReductionLiteral);
			final isRestParam = eitherHasEffectiveRest && !needsExtraRestElement && i == (longestCount - 1);
			final isOptional = i >= c.getMinArgumentCount(longest) && i >= c.getMinArgumentCount(shorter);
			var leftName = "";
			var rightName = "";
			if (i < leftCount) {
				leftName = c.getParameterNameAtPosition(left, i);
			}
			if (i < rightCount) {
				rightName = c.getParameterNameAtPosition(right, i);
			}
			var paramName = "";
			if (leftName == rightName) {
				paramName = leftName;
			} else if (leftName == "") {
				paramName = rightName;
			} else if (rightName == "") {
				paramName = leftName;
			}
			if (paramName == "") {
				paramName = "arg" + Std.string(i);
			}
			final paramSymbol = c.newSymbolEx(SymbolFlagsFunctionScopedVariable | ((isOptional && !isRestParam) ? SymbolFlagsOptional : SymbolFlagsNone), paramName,
				isRestParam ? CheckFlagsRestParameter : (isOptional ? CheckFlagsOptionalParameter : CheckFlagsNone));
			final links = c.valueSymbolLinks.Get(paramSymbol);
			if (isRestParam) {
				links.resolvedType = c.createArrayType(combinedParamType);
			} else {
				links.resolvedType = combinedParamType;
			}
			params[i] = paramSymbol;
		}
		if (needsExtraRestElement) {
			final restParamSymbol = c.newSymbolEx(SymbolFlagsFunctionScopedVariable, "args", CheckFlagsRestParameter);
			final links = c.valueSymbolLinks.Get(restParamSymbol);
			links.resolvedType = c.createArrayType(c.getTypeAtPosition(shorter, longestCount));
			if (shorter == right) {
				links.resolvedType = c.instantiateType(links.resolvedType, mapper);
			}
			params[longestCount] = restParamSymbol;
		}
		return params;
	}

	static function combineUnionOrIntersectionThisParam(c:Checker, left:Symbol, right:Symbol, mapper:TypeMapper, isUnion:Bool):Symbol {
		if (left == null) {
			return right;
		}
		if (right == null) {
			return left;
		}
		// A signature `this` type might be a read or a write position... It's very possible that it should be invariant
		// and we should refuse to merge signatures if there are `this` types and they do not match. However, so as to be
		// permissive when calling, for now, we'll intersect the `this` types just like we do for param types in union signatures.
		final thisType = c.getUnionOrIntersectionType([c.getTypeOfSymbol(left), c.instantiateType(c.getTypeOfSymbol(right), mapper)], !isUnion, UnionReductionLiteral);
		return c.createSymbolWithType(left, thisType);
	}

	static function resolveIntersectionTypeMembers(c:Checker, t:Type):Void {
		// The members and properties collections are empty for intersection types. To get all properties of an
		// intersection type use getPropertiesOfType (only the language service uses this).
		var callSignatures:Array<Signature> = null;
		var constructSignatures:Array<Signature> = null;
		var indexInfos:Array<IndexInfo> = null;
		final types = t.Types();
		final mixins = c.findMixins(types);
		final mixinFlags = mixins.a;
		final mixinCount = mixins.b;
		for (i in 0...types.length) {
			final t = types[i];
			// When an intersection type contains mixin constructor types, the construct signatures from
			// those types are discarded and their return types are mixed into the return types of all
			// other construct signatures in the intersection type. For example, the intersection type
			// '{ new(...args: any[]) => A } & { new(s: string) => B }' has a single construct signature
			// 'new(s: string) => A & B'.
			if (!mixinFlags[i]) {
				var signatures = c.getSignaturesOfType(t, SignatureKindConstruct);
				if (Core.len(signatures) != 0 && mixinCount > 0) {
					signatures = Core.Map(signatures, function(s:Signature):Signature {
						final clone = c.cloneSignature(s);
						clone.resolvedReturnType = c.includeMixinType(c.getReturnTypeOfSignature(s), types, mixinFlags, i);
						return clone;
					});
				}
				constructSignatures = c.appendSignatures(constructSignatures, signatures);
			}
			callSignatures = c.appendSignatures(callSignatures, c.getSignaturesOfType(t, SignatureKindCall));
			for (info in rangeOf(c.getIndexInfosOfType(t))) {
				indexInfos = c.appendIndexInfo(indexInfos, info, false /*union*/);
			}
		}
		c.setStructuredTypeMembers(t, null, callSignatures, constructSignatures, indexInfos);
	}

	static function appendSignatures(c:Checker, signatures:Array<Signature>, newSignatures:Array<Signature>):Array<Signature> {
		for (sig in rangeOf(newSignatures)) {
			if (Core.len(signatures) == 0 || Core.Every(signatures, function(s:Signature):Bool {
				return c.compareSignaturesIdentical(s, sig, false /*partialMatch*/, false /*ignoreThisTypes*/, false /*ignoreReturnTypes*/, c.compareTypesIdentical) == TernaryFalse;
			})) {
				if (signatures == null) {
					signatures = [];
				}
				signatures.push(sig);
			}
		}
		return signatures;
	}

	static function appendIndexInfo(c:Checker, indexInfos:Array<IndexInfo>, newInfo:IndexInfo, union:Bool):Array<IndexInfo> {
		if (indexInfos != null) {
			for (i in 0...indexInfos.length) {
				final info = indexInfos[i];
				if (info.keyType == newInfo.keyType) {
					var valueType:Type;
					var isReadonly:Bool;
					if (union) {
						valueType = c.getUnionType([info.valueType, newInfo.valueType]);
						isReadonly = info.isReadonly || newInfo.isReadonly;
					} else {
						valueType = c.getIntersectionType([info.valueType, newInfo.valueType]);
						isReadonly = info.isReadonly && newInfo.isReadonly;
					}
					indexInfos[i] = c.newIndexInfo(info.keyType, valueType, isReadonly, null, null);
					return indexInfos;
				}
			}
		}
		if (indexInfos == null) {
			return [newInfo];
		}
		indexInfos.push(newInfo);
		return indexInfos;
	}

	static function findMixins(c:Checker, types:Array<Type>):Pair<Array<Bool>, Int> {
		final mixinFlags = Core.Map(types, function(t:Type):Bool {
			return c.isMixinConstructorType(t);
		});
		var constructorTypeCount = 0;
		var mixinCount = 0;
		var firstMixinIndex = -1;
		for (i in 0...Core.len(types)) {
			final t = types[i];
			if (Core.len(c.getSignaturesOfType(t, SignatureKindConstruct)) > 0) {
				constructorTypeCount++;
			}
			if (mixinFlags[i]) {
				if (firstMixinIndex < 0) {
					firstMixinIndex = i;
				}
				mixinCount++;
			}
		}
		if (constructorTypeCount > 0 && constructorTypeCount == mixinCount) {
			mixinFlags[firstMixinIndex] = false;
			mixinCount--;
		}
		return new Pair(mixinFlags, mixinCount);
	}

	static function includeMixinType(c:Checker, t:Type, types:Array<Type>, mixinFlags:Array<Bool>, index:Int):Type {
		var mixedTypes:Array<Type> = null;
		for (i in 0...Core.len(types)) {
			if (i == index) {
				if (mixedTypes == null) {
					mixedTypes = [];
				}
				mixedTypes.push(t);
			} else if (mixinFlags[i]) {
				if (mixedTypes == null) {
					mixedTypes = [];
				}
				mixedTypes.push(c.getReturnTypeOfSignature(c.getSignaturesOfType(types[i], SignatureKindConstruct)[0]));
			}
		}
		return c.getIntersectionType(mixedTypes);
	}

	/**
	 * If the given type is an object type and that type has a property by the given name,
	 * return the symbol for that property. Otherwise return undefined.
	 */
	static function getPropertyOfObjectType(c:Checker, t:Type, name:std.String):Symbol {
		if ((t.flags & TypeFlagsObject) != 0) {
			final resolved = c.resolveStructuredTypeMembers(t);
			final symbol = symbolTableGet(resolved.members, name);
			if (symbol != null && c.symbolIsValue(symbol)) {
				return symbol;
			}
		}
		return null;
	}

	static function getPropertyOfUnionOrIntersectionType(c:Checker, t:Type, name:std.String, skipObjectFunctionPropertyAugment:Bool):Symbol {
		final prop = c.getUnionOrIntersectionProperty(t, name, skipObjectFunctionPropertyAugment);
		// We need to filter out partial properties in union types
		if (prop != null && (prop.CheckFlags & CheckFlagsReadPartial) != 0) {
			return null;
		}
		return prop;
	}

	// Return the symbol for a given property in a union or intersection type, or undefined if the property
	// does not exist in any constituent type. Note that the returned property may only be present in some
	// constituents, in which case the isPartial flag is set when the containing type is union type. We need
	// these partial properties when identifying discriminant properties, but otherwise they are filtered out
	// and do not appear to be present in the union type.
	static function getUnionOrIntersectionProperty(c:Checker, t:Type, name:std.String, skipObjectFunctionPropertyAugment:Bool):Symbol {
		final d = t.AsUnionOrIntersectionType();
		var cache:SymbolTable;
		if (skipObjectFunctionPropertyAugment) {
			cache = Ast.GetSymbolTable(() -> d.propertyCacheWithoutFunctionPropertyAugment, m -> d.propertyCacheWithoutFunctionPropertyAugment = m);
		} else {
			cache = Ast.GetSymbolTable(() -> d.propertyCache, m -> d.propertyCache = m);
		}
		final cached = cache.get(name);
		if (cached != null) {
			return cached;
		}
		final prop = c.createUnionOrIntersectionProperty(t, name, skipObjectFunctionPropertyAugment);
		if (prop != null) {
			cache.set(name, prop);
			// Propagate an entry from the non-augmented cache to the augmented cache unless the property is partial.
			if (skipObjectFunctionPropertyAugment && (prop.CheckFlags & CheckFlagsPartial) == 0) {
				final augmentedCache = Ast.GetSymbolTable(() -> d.propertyCache, m -> d.propertyCache = m);
				if (augmentedCache.get(name) == null) {
					augmentedCache.set(name, prop);
				}
			}
		}
		return prop;
	}

	static function createUnionOrIntersectionProperty(c:Checker, containingType:Type, name:std.String, skipObjectFunctionPropertyAugment:Bool):Symbol {
		var propFlags:SymbolFlags = SymbolFlagsNone;
		var singleProp:Symbol = null;
		final propSet = new ts.collections.OrderedSet<Symbol>();
		var indexTypes:Array<Type> = null;
		final isUnion = (containingType.flags & TypeFlagsUnion) != 0;
		// Flags we want to propagate to the result if they exist in all source symbols
		var checkFlags:CheckFlags = CheckFlagsNone;
		var optionalFlag:SymbolFlags = SymbolFlagsNone;
		if (!isUnion) {
			checkFlags = CheckFlagsReadonly;
			optionalFlag = SymbolFlagsOptional;
		}
		var syntheticFlag:CheckFlags = CheckFlagsSyntheticMethod;
		var mergedInstantiations = false;
		for (current in containingType.Types()) {
			final t = c.getApparentType(current);
			if (!c.isErrorType(t) && (t.flags & TypeFlagsNever) == 0) {
				final prop = c.getPropertyOfTypeEx(t, name, skipObjectFunctionPropertyAugment, false);
				var modifiers:ModifierFlags = ModifierFlagsNone;
				if (prop != null) {
					modifiers = Checker.getDeclarationModifierFlagsFromSymbol(prop);
					if ((prop.Flags & SymbolFlagsClassMember) != 0) {
						if (isUnion) {
							optionalFlag |= (prop.Flags & SymbolFlagsOptional);
						} else {
							optionalFlag &= prop.Flags;
						}
					}
					if (singleProp == null) {
						singleProp = prop;
						propFlags = (prop.Flags & SymbolFlagsAccessor) != 0 ? (prop.Flags & SymbolFlagsAccessor) : SymbolFlagsProperty;
					} else if (prop != singleProp) {
						final isInstantiation = c.getTargetSymbol(prop) == c.getTargetSymbol(singleProp);
						// If the symbols are instances of one another with identical types - consider the symbols
						// equivalent and just use the first one, which thus allows us to avoid eliding private
						// members when intersecting a (this-)instantiations of a class with its raw base or another instance
						if (isInstantiation && c.compareProperties(singleProp, prop, Checker.compareTypesEqual) == TernaryTrue) {
							// If we merged instantiations of a generic type, we replicate the symbol parent resetting behavior we used
							// to do when we recorded multiple distinct symbols so that we still get, eg, `Array<T>.length` printed
							// back and not `Array<string>.length` when we're looking at a `.length` access on a `string[] | number[]`
							mergedInstantiations = singleProp.Parent != null && Core.len(c.getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(singleProp.Parent)) != 0;
						} else {
							if (propSet.Size() == 0) {
								propSet.Add(singleProp);
							}
							propSet.Add(prop);
						}
						// classes created by mixins are represented as intersections
						// and overriding a property in a derived class redefines it completely at runtime
						// so a get accessor can't be merged with a set accessor in a base class,
						// for that reason the accessor flags are only used when they are the same in all constituents
						if ((propFlags & SymbolFlagsAccessor) != 0 && ((prop.Flags & SymbolFlagsAccessor) != (propFlags & SymbolFlagsAccessor))) {
							propFlags = (propFlags & ~SymbolFlagsAccessor) | SymbolFlagsProperty;
						}
					}
					if (isUnion && c.isReadonlySymbol(prop)) {
						checkFlags |= CheckFlagsReadonly;
					} else if (!isUnion && !c.isReadonlySymbol(prop)) {
						checkFlags = checkFlags & ~CheckFlagsReadonly;
					}
					if ((modifiers & ModifierFlagsNonPublicAccessibilityModifier) == 0) {
						checkFlags |= CheckFlagsContainsPublic;
					}
					if ((modifiers & ModifierFlagsProtected) != 0) {
						checkFlags |= CheckFlagsContainsProtected;
					}
					if ((modifiers & ModifierFlagsPrivate) != 0) {
						checkFlags |= CheckFlagsContainsPrivate;
					}
					if ((modifiers & ModifierFlagsStatic) != 0) {
						checkFlags |= CheckFlagsContainsStatic;
					}
					if (!Checker.isPrototypeProperty(prop)) {
						syntheticFlag = CheckFlagsSyntheticProperty;
					}
				} else if (isUnion) {
					var indexInfo:IndexInfo = null;
					if (!Checker.isLateBoundName(name)) {
						indexInfo = c.getApplicableIndexInfoForName(t, name);
					}
					if (indexInfo != null) {
						propFlags = (propFlags & ~SymbolFlagsAccessor) | SymbolFlagsProperty;
						checkFlags |= CheckFlagsWritePartial | (indexInfo.isReadonly ? CheckFlagsReadonly : CheckFlagsNone);
						if (indexTypes == null) {
							indexTypes = [];
						}
						if (Checker.isTupleType(t)) {
							var indexType = c.getRestTypeOfTupleType(t);
							if (indexType == null) {
								indexType = c.undefinedType;
							}
							indexTypes.push(indexType);
						} else {
							indexTypes.push(indexInfo.valueType);
						}
					} else if (Checker.isObjectLiteralType(t) && (t.objectFlags & ObjectFlagsContainsSpread) == 0) {
						checkFlags |= CheckFlagsWritePartial;
						if (indexTypes == null) {
							indexTypes = [];
						}
						indexTypes.push(c.undefinedType);
					} else {
						checkFlags |= CheckFlagsReadPartial;
					}
				}
			}
		}
		if (singleProp == null || (isUnion
			&& (propSet.Size() != 0 || (checkFlags & CheckFlagsPartial) != 0)
			&& (checkFlags & (CheckFlagsContainsPrivate | CheckFlagsContainsProtected)) != 0
			&& !(propSet.Size() != 0 && c.hasCommonDeclaration(propSet)))) {
			// No property was found, or, in a union, a property has a private or protected declaration in one
			// constituent, but is missing or has a different declaration in another constituent.
			return null;
		}
		if (propSet.Size() == 0 && (checkFlags & CheckFlagsReadPartial) == 0 && Core.len(indexTypes) == 0) {
			if (!mergedInstantiations) {
				return singleProp;
			}
			// No symbol from a union/intersection should have a `.parent` set (since unions/intersections don't act as symbol parents)
			// Unless that parent is "reconstituted" from the "first value declaration" on the symbol (which is likely different than its instantiated parent!)
			// They also have a `.containingType` set, which affects some services endpoints behavior, like `getRootSymbol`
			var singlePropType:Type = null;
			var singlePropMapper:TypeMapper = null;
			if ((singleProp.Flags & SymbolFlagsTransient) != 0) {
				final links = c.valueSymbolLinks.Get(singleProp);
				singlePropType = links.resolvedType;
				singlePropMapper = links.mapper;
			}
			final clone = c.createSymbolWithType(singleProp, singlePropType);
			if (singleProp.ValueDeclaration != null) {
				clone.Parent = singleProp.ValueDeclaration.Symbol().Parent;
			}
			final links = c.valueSymbolLinks.Get(clone);
			links.containingType = containingType;
			links.mapper = singlePropMapper;
			links.writeType = c.getWriteTypeOfSymbol(singleProp);
			return clone;
		}
		if (propSet.Size() == 0) {
			propSet.Add(singleProp);
		}
		var declarations:Array<Node> = null;
		var firstType:Type = null;
		var nameType:Type = null;
		var propTypes:Array<Type> = null;
		var writeTypes:Array<Type> = null;
		var firstValueDeclaration:Node = null;
		var hasNonUniformValueDeclaration = false;
		for (prop in propSet.Values()) {
			if (firstValueDeclaration == null) {
				firstValueDeclaration = prop.ValueDeclaration;
			} else if (prop.ValueDeclaration != null && prop.ValueDeclaration != firstValueDeclaration) {
				hasNonUniformValueDeclaration = true;
			}
			if (Core.len(prop.Declarations) != 0) {
				if (declarations == null) {
					declarations = [];
				}
				for (d in prop.Declarations) {
					declarations.push(d);
				}
			}
			final t = c.getTypeOfSymbol(prop);
			if (firstType == null) {
				firstType = t;
				nameType = c.valueSymbolLinks.Get(prop).nameType;
			}
			final writeType = c.getWriteTypeOfSymbol(prop);
			if (writeTypes != null || writeType != t) {
				if (writeTypes == null) {
					writeTypes = propTypes != null ? propTypes.copy() : [];
				}
				writeTypes.push(writeType);
			}
			if (t != firstType) {
				checkFlags |= CheckFlagsHasNonUniformType;
			}
			if (Checker.isLiteralType(t) || c.isPatternLiteralType(t)) {
				checkFlags |= CheckFlagsHasLiteralType;
			}
			if ((t.flags & TypeFlagsNever) != 0 && t != c.uniqueLiteralType) {
				checkFlags |= CheckFlagsHasNeverType;
			}
			if (propTypes == null) {
				propTypes = [];
			}
			propTypes.push(t);
		}
		if (Core.len(indexTypes) != 0) {
			if (propTypes == null) {
				propTypes = [];
			}
			for (it in indexTypes) {
				propTypes.push(it);
			}
		}
		final result = c.newSymbolEx(propFlags | optionalFlag, name, checkFlags | syntheticFlag);
		result.Declarations = declarations;
		if (!hasNonUniformValueDeclaration && firstValueDeclaration != null) {
			result.ValueDeclaration = firstValueDeclaration;
			// Inherit information about parent type.
			result.Parent = firstValueDeclaration.Symbol().Parent;
		}
		final links = c.valueSymbolLinks.Get(result);
		links.containingType = containingType;
		links.nameType = nameType;
		if (Core.len(propTypes) > 2) {
			// When `propTypes` has the potential to explode in size when normalized, defer normalization until absolutely needed
			result.CheckFlags |= CheckFlagsDeferredType;
			final deferred = c.deferredSymbolLinks.Get(result);
			deferred.parent = containingType;
			deferred.constituents = propTypes;
			deferred.writeConstituents = writeTypes;
			return result;
		}
		if (isUnion) {
			links.resolvedType = c.getUnionType(propTypes);
		} else {
			links.resolvedType = c.getIntersectionType(propTypes);
		}
		if (writeTypes != null) {
			if (isUnion) {
				links.writeType = c.getUnionType(writeTypes);
			} else {
				links.writeType = c.getIntersectionType(writeTypes);
			}
		}
		return result;
	}

	static function getTargetSymbol(c:Checker, s:Symbol):Symbol {
		// if symbol is instantiated its flags are not copied from the 'target'
		// so we'll need to get back original 'target' symbol to work with correct set of flags
		// NOTE: cast to TransientSymbol should be safe because only TransientSymbols have CheckFlags.Instantiated
		if (s != null && (s.CheckFlags & CheckFlagsInstantiated) != 0) {
			return c.valueSymbolLinks.Get(s).target;
		}
		return s;
	}

	static function hasCommonDeclaration(c:Checker, symbols:ts.collections.OrderedSet<Symbol>):Bool {
		final commonDeclarations = new Set<Node>();
		for (symbol in symbols.Values()) {
			if (Core.len(symbol.Declarations) == 0) {
				return false;
			}
			if (commonDeclarations.Len() == 0) {
				for (d in symbol.Declarations) {
					commonDeclarations.Add(d);
				}
				continue;
			}
			// PORT: Go deletes the current key while ranging over the map; iterate over a snapshot of the keys.
			final keys = [for (d in commonDeclarations.Keys().keys()) d];
			for (d in keys) {
				if (symbol.Declarations.indexOf(d) < 0) {
					commonDeclarations.Delete(d);
				}
			}
			if (commonDeclarations.Len() == 0) {
				return false;
			}
		}
		return commonDeclarations.Len() != 0;
	}

	static function createSymbolWithType(c:Checker, source:Symbol, t:Type):Symbol {
		final symbol = c.newSymbolEx(source.Flags, source.Name, source.CheckFlags & CheckFlagsReadonly);
		symbol.Declarations = source.Declarations;
		symbol.Parent = source.Parent;
		symbol.ValueDeclaration = source.ValueDeclaration;
		final links = c.valueSymbolLinks.Get(symbol);
		links.resolvedType = t;
		links.target = source;
		links.nameType = c.valueSymbolLinks.Get(source).nameType;
		return symbol;
	}

	static function isMappedTypeGenericIndexedAccess(c:Checker, t:Type):Bool {
		if ((t.flags & TypeFlagsIndexedAccess) != 0) {
			final objectType = t.AsIndexedAccessType().objectType;
			return (objectType.objectFlags & ObjectFlagsMapped) != 0 && !c.isGenericMappedType(objectType) && c.isGenericIndexType(t.AsIndexedAccessType().indexType)
				&& (Checker.getMappedTypeModifiers(objectType) & MappedTypeModifiersExcludeOptional) == 0 && objectType.AsMappedType().declaration.NameType == null;
		}
		return false;
	}

	/**
	 * For a type parameter, return the base constraint of the type parameter. For the string, number,
	 * boolean, and symbol primitive types, return the corresponding object types. Otherwise return the
	 * type itself.
	 */
	static function getApparentType(c:Checker, t:Type):Type {
		final originalType = t;
		if ((t.flags & TypeFlagsInstantiable) != 0) {
			t = c.getBaseConstraintOfType(t);
			if (t == null) {
				t = c.unknownType;
			}
		}
		if ((t.objectFlags & ObjectFlagsMapped) != 0) {
			return c.getApparentTypeOfMappedType(t);
		} else if ((t.objectFlags & ObjectFlagsReference) != 0 && t != originalType) {
			return c.getTypeWithThisArgument(t, originalType, false /*needsApparentType*/);
		} else if ((t.flags & TypeFlagsIntersection) != 0) {
			return c.getApparentTypeOfIntersectionType(t, originalType);
		} else if ((t.flags & TypeFlagsStringLike) != 0) {
			return c.globalStringType;
		} else if ((t.flags & TypeFlagsNumberLike) != 0) {
			return c.globalNumberType;
		} else if ((t.flags & TypeFlagsBigIntLike) != 0) {
			return c.getGlobalBigIntType();
		} else if ((t.flags & TypeFlagsBooleanLike) != 0) {
			return c.globalBooleanType;
		} else if ((t.flags & TypeFlagsESSymbolLike) != 0) {
			return c.getGlobalESSymbolType();
		} else if ((t.flags & TypeFlagsNonPrimitive) != 0) {
			return c.emptyObjectType;
		} else if ((t.flags & TypeFlagsIndex) != 0) {
			return c.stringNumberSymbolType;
		} else if ((t.flags & TypeFlagsUnknown) != 0 && !c.strictNullChecks) {
			return c.emptyObjectType;
		}
		return t;
	}

	static function getApparentTypeOfMappedType(c:Checker, t:Type):Type {
		final m = t.AsMappedType();
		if (m.resolvedApparentType == null) {
			m.resolvedApparentType = c.getResolvedApparentTypeOfMappedType(t);
		}
		return m.resolvedApparentType;
	}

	static function getResolvedApparentTypeOfMappedType(c:Checker, t:Type):Type {
		final target = t.AsMappedType().target != null ? t.AsMappedType().target : t;
		final typeVariable = c.getHomomorphicTypeVariable(target);
		if (typeVariable != null && target.AsMappedType().declaration.NameType == null) {
			// We have a homomorphic mapped type or an instantiation of a homomorphic mapped type, i.e. a type
			// of the form { [P in keyof T]: X }. Obtain the modifiers type (the T of the keyof T), and if it is
			// another generic mapped type, recursively obtain its apparent type. Otherwise, obtain its base
			// constraint. Then, if every constituent of the base constraint is an array or tuple type, apply
			// this mapped type to the base constraint. It is safe to recurse when the modifiers type is a
			// mapped type because we protect again circular constraints in getTypeFromMappedTypeNode.
			final modifiersType = c.getModifiersTypeFromMappedType(t);
			var baseConstraint:Type;
			if (c.isGenericMappedType(modifiersType)) {
				baseConstraint = c.getApparentTypeOfMappedType(modifiersType);
			} else {
				baseConstraint = c.getBaseConstraintOfType(modifiersType);
			}
			if (baseConstraint != null && Checker.everyType(baseConstraint, function(t:Type):Bool {
				return c.isArrayOrTupleType(t) || c.isArrayOrTupleOrIntersection(t);
			})) {
				return c.instantiateType(target, Checker.prependTypeMapping(typeVariable, baseConstraint, t.AsMappedType().mapper));
			}
		}
		return t;
	}

	static function getApparentTypeOfIntersectionType(c:Checker, t:Type, thisArgument:Type):Type {
		if (t == thisArgument) {
			final d = t.AsIntersectionType();
			if (d.resolvedApparentType == null) {
				d.resolvedApparentType = c.getTypeWithThisArgument(t, thisArgument, true /*needApparentType*/);
			}
			return d.resolvedApparentType;
		}
		final key = CachedTypeKey.keyOf(CachedTypeKindApparentType, thisArgument.id);
		var result = c.cachedTypes.get(key);
		if (result == null) {
			result = c.getTypeWithThisArgument(t, thisArgument, true /*needApparentType*/);
			c.cachedTypes.set(key, result);
		}
		return result;
	}

	/**
	 * Return the reduced form of the given type. For a union type, it is a union of the normalized constituent types.
	 * For an intersection of types containing one or more mututally exclusive discriminant properties, it is 'never'.
	 * For all other types, it is simply the type itself. Discriminant properties are considered mutually exclusive when
	 * no constituent property has type 'never', but the intersection of the constituent property types is 'never'.
	 */
	static function getReducedType(c:Checker, t:Type):Type {
		if ((t.flags & TypeFlagsUnion) != 0) {
			if ((t.objectFlags & ObjectFlagsContainsIntersections) != 0) {
				final cachedReducedType = t.AsUnionType().resolvedReducedType;
				if (cachedReducedType != null) {
					return cachedReducedType;
				}
				final reducedType = c.getReducedUnionType(t);
				t.AsUnionType().resolvedReducedType = reducedType;
				return reducedType;
			}
		} else if ((t.flags & TypeFlagsIntersection) != 0) {
			if ((t.objectFlags & ObjectFlagsIsNeverIntersectionComputed) == 0) {
				t.objectFlags |= ObjectFlagsIsNeverIntersectionComputed;
				if (Core.Some(c.getPropertiesOfUnionOrIntersectionType(t), function(prop:Symbol):Bool {
					return c.isNeverReducedProperty(prop);
				})) {
					t.objectFlags |= ObjectFlagsIsNeverIntersection;
				}
			}
			if ((t.objectFlags & ObjectFlagsIsNeverIntersection) != 0) {
				return c.neverType;
			}
		}
		return t;
	}

	static function getReducedUnionType(c:Checker, unionType:Type):Type {
		final reducedTypes = Core.SameMap(unionType.Types(), function(t:Type):Type {
			return c.getReducedType(t);
		});
		if (Core.Same(reducedTypes, unionType.Types())) {
			return unionType;
		}
		final reduced = c.getUnionType(reducedTypes);
		if ((reduced.flags & TypeFlagsUnion) != 0) {
			reduced.AsUnionType().resolvedReducedType = reduced;
		}
		return reduced;
	}

	static function isNeverReducedProperty(c:Checker, prop:Symbol):Bool {
		return c.isDiscriminantWithNeverType(prop) || Checker.isConflictingPrivateProperty(prop);
	}

	static function getReducedApparentType(c:Checker, t:Type):Type {
		// Since getApparentType may return a non-reduced union or intersection type, we need to perform
		// type reduction both before and after obtaining the apparent type. For example, given a type parameter
		// 'T extends A | B', the type 'T & X' becomes 'A & X | B & X' after obtaining the apparent type, and
		// that type may need further reduction to remove empty intersections.
		return c.getReducedType(c.getApparentType(c.getReducedType(t)));
	}

	static function elaborateNeverIntersection(c:Checker, chain:Diagnostic, node:Node, t:Type):Diagnostic {
		if ((t.flags & TypeFlagsIntersection) != 0 && (t.objectFlags & ObjectFlagsIsNeverIntersection) != 0) {
			final neverProp = Core.Find(c.getPropertiesOfUnionOrIntersectionType(t), function(prop:Symbol):Bool {
				return c.isDiscriminantWithNeverType(prop);
			});
			if (neverProp != null) {
				return Checker.NewDiagnosticChainForNode(chain, node, Diagnostics.The_intersection_0_was_reduced_to_never_because_property_1_has_conflicting_types_in_some_constituents, c.typeToStringEx(t, null, TypeFormatFlagsNoTypeReduction, null), c.symbolToString(neverProp));
			}
			final privateProp = Core.Find(c.getPropertiesOfUnionOrIntersectionType(t), function(prop:Symbol):Bool {
				return Checker.isConflictingPrivateProperty(prop);
			});
			if (privateProp != null) {
				return Checker.NewDiagnosticChainForNode(chain, node, Diagnostics.The_intersection_0_was_reduced_to_never_because_property_1_exists_in_multiple_constituents_and_is_private_in_some, c.typeToStringEx(t, null, TypeFormatFlagsNoTypeReduction, null), c.symbolToString(privateProp));
			}
		}
		return chain;
	}

	static function isDiscriminantWithNeverType(c:Checker, prop:Symbol):Bool {
		// Return true for a synthetic non-optional property with non-uniform types, where at least one is
		// a literal type and none is never, that reduces to never.
		return (prop.Flags & SymbolFlagsOptional) == 0 && (prop.CheckFlags & (CheckFlagsNonUniformAndLiteral | CheckFlagsHasNeverType)) == CheckFlagsNonUniformAndLiteral && (c.getTypeOfSymbol(prop).flags & TypeFlagsNever) != 0;
	}

	static function getTypeArguments(c:Checker, t:Type):Array<Type> {
		final d = t.AsTypeReference();
		if (d.resolvedTypeArguments == null) {
			final n = d.target.AsInterfaceType();
			if (!c.pushTypeResolution(t, TypeSystemPropertyNameResolvedTypeArguments)) {
				return [for (_ in 0...Core.len(n.TypeParameters())) c.errorType];
			}
			var typeArguments:Array<Type> = null;
			final node = t.AsTypeReference().node;
			if (node != null) {
				switch (node.Kind) {
					case KindTypeReference:
						// PORT: Go `append(n.OuterTypeParameters(), ...)`; OuterTypeParameters returns a fresh (clipped) slice.
						typeArguments = appendTypes(n.OuterTypeParameters(), c.getEffectiveTypeArguments(node, n.LocalTypeParameters()));
					case KindArrayType:
						typeArguments = [c.getTypeFromTypeNode(node.AsArrayTypeNode().ElementType)];
					case KindTupleType:
						typeArguments = Core.Map(node.Elements(), function(e:Node):Type {
							return c.getTypeFromTypeNode(e);
						});
					default:
						throw "Unhandled case in getTypeArguments";
				}
			}
			if (c.popTypeResolution()) {
				if (d.resolvedTypeArguments == null) {
					d.resolvedTypeArguments = c.instantiateTypes(typeArguments, d.mapper);
				}
			} else {
				if (d.resolvedTypeArguments == null) {
					d.resolvedTypeArguments = [for (_ in 0...Core.len(n.TypeParameters())) c.errorType];
				}
				final errorNode = node != null ? node : c.currentNode;
				if (d.target.symbol != null) {
					c.error(errorNode, Diagnostics.Type_arguments_for_0_circularly_reference_themselves, c.symbolToString(d.target.symbol));
				} else {
					c.error(errorNode, Diagnostics.Tuple_type_arguments_circularly_reference_themselves);
				}
			}
		}
		return d.resolvedTypeArguments;
	}

	static function getEffectiveTypeArguments(c:Checker, node:Node, typeParameters:Array<Type>):Array<Type> {
		return c.fillMissingTypeArguments(Core.Map(node.TypeArguments(), function(n:Node):Type {
			return c.getTypeFromTypeNode(n);
		}), typeParameters, c.getMinTypeArgumentCount(typeParameters), Ast.IsInJSFile(node));
	}

	// Gets the minimum number of type arguments needed to satisfy all non-optional type parameters.
	static function getMinTypeArgumentCount(c:Checker, typeParameters:Array<Type>):Int {
		var minTypeArgumentCount = 0;
		for (i in 0...Core.len(typeParameters)) {
			final typeParameter = typeParameters[i];
			if (!c.hasTypeParameterDefault(typeParameter)) {
				minTypeArgumentCount = i + 1;
			}
		}
		return minTypeArgumentCount;
	}

	static function hasTypeParameterDefault(c:Checker, t:Type):Bool {
		return t.symbol != null && Core.Some(t.symbol.Declarations, function(d:Node):Bool {
			return Ast.IsTypeParameterDeclaration(d) && d.AsTypeParameterDeclaration().DefaultType != null;
		});
	}

	static function fillMissingTypeArguments(c:Checker, typeArguments:Array<Type>, typeParameters:Array<Type>, minTypeArgumentCount:Int, isJavaScriptImplicitAny:Bool):Array<Type> {
		final numTypeParameters = Core.len(typeParameters);
		if (numTypeParameters == 0) {
			return null;
		}
		final numTypeArguments = Core.len(typeArguments);
		if (isJavaScriptImplicitAny || numTypeArguments < numTypeParameters) {
			// PORT: Go `make` + `copy` (copy stops at the shorter length).
			final result:Array<Type> = [for (i in 0...numTypeParameters) i < numTypeArguments ? typeArguments[i] : null];
			// Map invalid forward references in default types to the error type
			for (i in numTypeArguments...numTypeParameters) {
				result[i] = c.errorType;
			}
			final baseDefaultType = c.getDefaultTypeArgumentType(isJavaScriptImplicitAny);
			for (i in numTypeArguments...numTypeParameters) {
				var defaultType = c.getDefaultFromTypeParameter(typeParameters[i]);

				if (isJavaScriptImplicitAny && defaultType != null && (c.isTypeIdenticalTo(defaultType, c.unknownType) || c.isTypeIdenticalTo(defaultType, c.emptyObjectType))) {
					defaultType = c.anyType;
				}

				if (defaultType != null) {
					result[i] = c.instantiateType(defaultType, Checker.newTypeMapper(typeParameters, result));
				} else {
					result[i] = baseDefaultType;
				}
			}
			return result;
		}
		return typeArguments;
	}

	static function getDefaultTypeArgumentType(c:Checker, isInJavaScriptFile:Bool):Type {
		if (isInJavaScriptFile) {
			return c.anyType;
		}
		return c.unknownType;
	}

	// Gets the default type for a type parameter. If the type parameter is the result of an instantiation,
	// this gets the instantiated default type of its target. If the type parameter has no default type or
	// the default is circular, `undefined` is returned.
	static function getDefaultFromTypeParameter(c:Checker, t:Type):Type {
		if ((t.flags & TypeFlagsTypeParameter) == 0) {
			return null;
		}
		final defaultType = c.getResolvedTypeParameterDefault(t);
		if (defaultType != c.noConstraintType && defaultType != c.circularConstraintType) {
			return defaultType;
		}
		return null;
	}

	static function getResolvedTypeParameterDefault(c:Checker, t:Type):Type {
		final d = t.AsTypeParameter();
		if (d.resolvedDefaultType == null) {
			if (d.target != null) {
				final targetDefault = c.getResolvedTypeParameterDefault(d.target);
				if (targetDefault != null) {
					d.resolvedDefaultType = c.instantiateType(targetDefault, d.mapper);
				} else {
					d.resolvedDefaultType = c.noConstraintType;
				}
			} else {
				// To block recursion, set the initial value to the resolvingDefaultType.
				d.resolvedDefaultType = c.resolvingDefaultType;
				var defaultType = c.noConstraintType;
				if (t.symbol != null) {
					final defaultDeclaration = Core.FirstNonNil(t.symbol.Declarations, function(decl:Node):Node {
						if (Ast.IsTypeParameterDeclaration(decl)) {
							return decl.AsTypeParameterDeclaration().DefaultType;
						}
						return null;
					});
					if (defaultDeclaration != null) {
						defaultType = c.getTypeFromTypeNode(defaultDeclaration);
					}
				}
				if (d.resolvedDefaultType == c.resolvingDefaultType) {
					// If we have not been called recursively, set the correct default type.
					d.resolvedDefaultType = defaultType;
				}
			}
		} else if (d.resolvedDefaultType == c.resolvingDefaultType) {
			// If we are called recursively for this type parameter, mark the default as circular.
			d.resolvedDefaultType = c.circularConstraintType;
		}
		return d.resolvedDefaultType;
	}

	static function getDefaultOrUnknownFromTypeParameter(c:Checker, t:Type):Type {
		final result = c.getDefaultFromTypeParameter(t);
		return result != null ? result : c.unknownType;
	}

	static function getNamedMembers(c:Checker, members:SymbolTable, container:Symbol):Array<Symbol> {
		if (symbolTableLen(members) == 0) {
			return null;
		}
		// For classes and interfaces, we store explicitly declared members ahead of inherited members. This ensures we process
		// explicitly declared members first in type relations, which is beneficial because explicitly declared members are more
		// likely to contain discriminating differences. See for example https://github.com/microsoft/typescript-go/issues/1968.
		var result:Array<Symbol> = [];
		var containedCount = 0;
		if (container != null && (container.Flags & (SymbolFlagsClass | SymbolFlagsInterface)) != 0) {
			for (id => symbol in members) {
				if (c.isNamedMember(symbol, id) && c.isDeclarationContainedBy(symbol, container)) {
					result.push(symbol);
				}
			}
			containedCount = result.length;
		}
		for (id => symbol in members) {
			if (c.isNamedMember(symbol, id) && (container == null || (container.Flags & (SymbolFlagsClass | SymbolFlagsInterface)) == 0 || !c.isDeclarationContainedBy(symbol, container))) {
				result.push(symbol);
			}
		}
		// PORT: Go sorts the two sub-slices in place (shared backing array); sort copies and join them.
		final head = result.slice(0, containedCount);
		final tail = result.slice(containedCount);
		c.sortSymbols(head);
		c.sortSymbols(tail);
		result = head.concat(tail);
		return result;
	}

	static function isDeclarationContainedBy(c:Checker, symbol:Symbol, container:Symbol):Bool {
		final declaration = symbol.ValueDeclaration;
		if (declaration != null) {
			for (d in rangeOf(container.Declarations)) {
				if (declaration.Loc.ContainedBy(d.Loc)) {
					return true;
				}
			}
		}
		return false;
	}

	static function isNamedMember(c:Checker, symbol:Symbol, id:std.String):Bool {
		return !Checker.isReservedMemberName(id) && c.symbolIsValue(symbol);
	}

	static function symbolIsValue(c:Checker, symbol:Symbol):Bool {
		return c.symbolIsValueEx(symbol, false /*includeTypeOnlyMembers*/);
	}

	static function symbolIsValueEx(c:Checker, symbol:Symbol, includeTypeOnlyMembers:Bool):Bool {
		return (symbol.Flags & SymbolFlagsValue) != 0
			|| (symbol.Flags & SymbolFlagsAlias) != 0
			&& (c.getSymbolFlagsEx(symbol, !includeTypeOnlyMembers, false /*excludeLocalMeanings*/) & SymbolFlagsValue) != 0;
	}

	static function instantiateType(c:Checker, t:Type, m:TypeMapper):Type {
		return c.instantiateTypeWithAlias(t, m, null /*alias*/);
	}

	static function instantiateTypeWithAlias(c:Checker, t:Type, m:TypeMapper, alias:TypeAlias):Type {
		// Check for type variables in the alias, so things like `type Brand<T> = number & {}` can potentially be copied with new alias type args, despite them being unreferenced.
		// This is the behavior most people using aliases expect, and prevents the cache from leaking type parameters outside their scope of validity.
		// tests/cases/compiler/declarationEmitArrowFunctionNoRenaming.ts contains an example of this, which previously only worked in strada via some input node reuse logic instead.
		if (t == null || m == null || !(c.couldContainTypeVariables(t) || (t.alias != null && Core.len(t.alias.typeArguments) > 0 && Core.Some(t.alias.typeArguments, c.couldContainTypeVariables)))) {
			return t;
		}
		if (c.instantiationDepth == 100 || c.instantiationCount >= 5000000) {
			// We have reached 100 recursive type instantiations, or 5M type instantiations caused by the same statement
			// or expression. There is a very high likelihood we're dealing with a combination of infinite generic types
			// that perpetually generate new type identities, so we stop the recursion here by yielding the error type.
			final tr = c.tracer;
			if (tr != null) {
				final args = new StringMap<Any>();
				args.set("typeId", t.id);
				args.set("instantiationDepth", c.instantiationDepth);
				args.set("instantiationCount", c.instantiationCount);
				tr.Instant(PhaseCheckTypes, "instantiateType_DepthLimit", args);
			}
			c.error(c.currentNode, Diagnostics.Type_instantiation_is_excessively_deep_and_possibly_infinite);
			return c.errorType;
		}
		final index = c.findActiveMapper(m);
		if (index == -1) {
			c.pushActiveMapper(m);
		}
		final b = new KeyBuilder();
		b.writeType(t);
		b.writeAlias(alias);
		final key = b.hash().Key();
		final cache = c.activeTypeMappersCaches[index != -1 ? index : c.activeTypeMappersCaches.length - 1];
		if (cache.exists(key)) {
			return cache.get(key);
		}
		c.TotalInstantiationCount++;
		c.instantiationCount++;
		c.instantiationDepth++;
		final result = c.instantiateTypeWorker(t, m, alias);
		if (index == -1) {
			c.popActiveMapper();
		} else {
			cache.set(key, result);
		}
		c.instantiationDepth--;
		return result;
	}

	static function pushActiveMapper(c:Checker, mapper:TypeMapper):Void {
		if (c.activeMappers == null) {
			c.activeMappers = [];
		}
		c.activeMappers.push(mapper);

		// PORT: Go reuses an emptied map left in the slice capacity by popActiveMapper; Haxe arrays have no
		// spare capacity, so a new (empty) map is appended. Same observable state.
		if (c.activeTypeMappersCaches == null) {
			c.activeTypeMappersCaches = [];
		}
		c.activeTypeMappersCaches.push(new StringMap<Type>());
	}

	static function popActiveMapper(c:Checker):Void {
		c.activeMappers.pop();

		// Clear the map, but leave it in the list for later reuse.
		// PORT: the map is dropped instead (see pushActiveMapper).
		c.activeTypeMappersCaches.pop();
	}

	static function findActiveMapper(c:Checker, mapper:TypeMapper):Int {
		return Core.FindLastIndex(c.activeMappers, (m:TypeMapper) -> m == mapper);
	}

	static function clearActiveMapperCaches(c:Checker):Void {
		for (cache in rangeOf(c.activeTypeMappersCaches)) {
			cache.clear();
		}
	}

	// Return true if the given type could possibly reference a type parameter for which
	// we perform type inference (i.e. a type parameter of a generic function). We cache
	// results for union and intersection types for performance reasons.
	static function couldContainTypeVariablesWorker(c:Checker, t:Type):Bool {
		if ((t.flags & TypeFlagsStructuredOrInstantiable) == 0) {
			return false;
		}
		final objectFlags = t.objectFlags;
		if ((objectFlags & ObjectFlagsCouldContainTypeVariablesComputed) != 0) {
			return (objectFlags & ObjectFlagsCouldContainTypeVariables) != 0;
		}
		final result = (t.flags & TypeFlagsInstantiable) != 0
			|| (t.flags & TypeFlagsObject) != 0 && !c.isNonGenericTopLevelType(t) && ((objectFlags & ObjectFlagsReference) != 0 && (t.AsTypeReference().node != null || Core.Some(c.getTypeArguments(t), c.couldContainTypeVariables))
				|| (objectFlags & ObjectFlagsAnonymous) != 0 && t.symbol != null && (t.symbol.Flags & (SymbolFlagsFunction | SymbolFlagsMethod | SymbolFlagsClass | SymbolFlagsTypeLiteral | SymbolFlagsObjectLiteral)) != 0 && t.symbol.Declarations != null
				|| (objectFlags & (ObjectFlagsMapped | ObjectFlagsReverseMapped | (Checker.ObjectFlagsObjectRestType : ObjectFlags) | (Checker.ObjectFlagsInstantiationExpressionType : ObjectFlags))) != 0)
			|| (t.flags & TypeFlagsUnionOrIntersection) != 0 && (t.flags & TypeFlagsEnumLiteral) == 0 && !c.isNonGenericTopLevelType(t) && Core.Some(t.Types(), c.couldContainTypeVariables);
		t.objectFlags |= ObjectFlagsCouldContainTypeVariablesComputed | (result ? ObjectFlagsCouldContainTypeVariables : ObjectFlagsNone);
		return result;
	}

	static function isNonGenericTopLevelType(c:Checker, t:Type):Bool {
		if (t.alias != null && Core.len(t.alias.typeArguments) == 0) {
			var declaration = Ast.GetDeclarationOfKind(t.alias.symbol, KindTypeAliasDeclaration);
			if (declaration == null) {
				declaration = Ast.GetDeclarationOfKind(t.alias.symbol, KindJSTypeAliasDeclaration);
			}
			return declaration != null && Ast.FindAncestorOrQuit(declaration.Parent, (n:Node) -> {
				switch (n.Kind) {
					case KindSourceFile:
						return FindAncestorTrue;
					case KindModuleDeclaration:
						return FindAncestorFalse;
					default:
				}
				return FindAncestorQuit;
			}) != null;
		}
		return false;
	}

	static function instantiateTypeWorker(c:Checker, t:Type, m:TypeMapper, alias:TypeAlias):Type {
		final flags = t.flags;
		if ((flags & TypeFlagsTypeParameter) != 0) {
			return m.Map(t);
		} else if ((flags & TypeFlagsObject) != 0) {
			final objectFlags = t.objectFlags;
			if ((objectFlags & (ObjectFlagsReference | ObjectFlagsAnonymous | ObjectFlagsMapped)) != 0) {
				if ((objectFlags & ObjectFlagsReference) != 0 && t.AsTypeReference().node == null) {
					final resolvedTypeArguments = t.AsTypeReference().resolvedTypeArguments;
					final newTypeArguments = c.instantiateTypes(resolvedTypeArguments, m);
					if (Core.Same(newTypeArguments, resolvedTypeArguments)) {
						return t;
					}
					return c.createNormalizedTypeReference(t.Target(), newTypeArguments);
				}
				if ((objectFlags & ObjectFlagsReverseMapped) != 0) {
					return c.instantiateReverseMappedType(t, m);
				}
				return c.getObjectTypeInstantiation(t, m, alias);
			}
			return t;
		} else if ((flags & TypeFlagsUnionOrIntersection) != 0) {
			var source = t;
			if ((t.flags & TypeFlagsUnion) != 0) {
				final origin = t.AsUnionType().origin;
				if (origin != null && (origin.flags & TypeFlagsUnionOrIntersection) != 0) {
					source = origin;
				}
			}
			final types = source.Types();
			final newTypes = c.instantiateTypes(types, m);
			if (Core.Same(newTypes, types) && alias.Symbol() == t.alias.Symbol()) {
				return t;
			}
			if (alias == null) {
				alias = c.instantiateTypeAlias(t.alias, m);
			}
			if ((source.flags & TypeFlagsIntersection) != 0) {
				return c.getIntersectionTypeEx(newTypes, IntersectionFlagsNone, alias);
			}
			return c.getUnionTypeEx(newTypes, UnionReductionLiteral, alias, null /*origin*/);
		} else if ((flags & TypeFlagsIndex) != 0) {
			return c.getIndexType(c.instantiateType(t.Target(), m));
		} else if ((flags & TypeFlagsIndexedAccess) != 0) {
			if (alias == null) {
				alias = c.instantiateTypeAlias(t.alias, m);
			}
			final d = t.AsIndexedAccessType();
			return c.getIndexedAccessTypeEx(c.instantiateType(d.objectType, m), c.instantiateType(d.indexType, m), d.accessFlags, null /*accessNode*/, alias);
		} else if ((flags & TypeFlagsTemplateLiteral) != 0) {
			return c.getTemplateLiteralType(t.AsTemplateLiteralType().texts, c.instantiateTypes(t.AsTemplateLiteralType().types, m));
		} else if ((flags & TypeFlagsStringMapping) != 0) {
			return c.getStringMappingType(t.symbol, c.instantiateType(t.AsStringMappingType().target, m));
		} else if ((flags & TypeFlagsConditional) != 0) {
			return c.getConditionalTypeInstantiation(t, c.combineTypeMappers(t.AsConditionalType().mapper, m), false /*forConstraint*/, alias);
		} else if ((flags & TypeFlagsSubstitution) != 0) {
			final newBaseType = c.instantiateType(t.AsSubstitutionType().baseType, m);
			if (c.isNoInferType(t)) {
				return c.getNoInferType(newBaseType);
			}
			final newConstraint = c.instantiateType(t.AsSubstitutionType().constraint, m);
			// A substitution type originates in the true branch of a conditional type and can be resolved
			// to just the base type in the same cases as the conditional type resolves to its true branch
			// (because the base type is then known to satisfy the constraint).
			if ((newBaseType.flags & TypeFlagsTypeVariable) != 0 && c.isGenericType(newConstraint)) {
				return c.getSubstitutionType(newBaseType, newConstraint);
			}
			if ((newConstraint.flags & TypeFlagsAnyOrUnknown) != 0 || c.isTypeAssignableTo(c.getRestrictiveInstantiation(newBaseType), c.getRestrictiveInstantiation(newConstraint))) {
				return newBaseType;
			}
			if ((newBaseType.flags & TypeFlagsTypeVariable) != 0) {
				return c.getSubstitutionType(newBaseType, newConstraint);
			}
			return c.getIntersectionType([newConstraint, newBaseType]);
		}
		return t;
	}

	// Handles instantiation of the following object types:
	// AnonymousType (ObjectFlagsAnonymous|ObjectFlagsSingleSignatureType)
	// TypeReference with node != nil (ObjectFlagsReference)
	// InstantiationExpressionType (ObjectFlagsInstantiationExpressionType)
	// MappedType (ObjectFlagsMapped)
	static function getObjectTypeInstantiation(c:Checker, t:Type, m:TypeMapper, alias:TypeAlias):Type {
		var declaration:Node;
		var target:Type;
		var typeParameters:Array<Type>;
		if ((t.objectFlags & ObjectFlagsReference) != 0) { // Deferred type reference
			declaration = t.AsTypeReference().node;
		} else if ((t.objectFlags & (Checker.ObjectFlagsInstantiationExpressionType : ObjectFlags)) != 0) {
			declaration = t.AsInstantiationExpressionType().node;
		} else {
			declaration = t.symbol.Declarations[0];
		}
		final links = c.typeNodeLinks.Get(declaration);
		if ((t.objectFlags & ObjectFlagsReference) != 0) { // Deferred type reference
			target = links.resolvedType;
		} else if ((t.objectFlags & ObjectFlagsInstantiated) != 0) {
			target = t.Target();
		} else {
			target = t;
		}
		typeParameters = links.outerTypeParameters;
		if (typeParameters == null) {
			// The first time an anonymous type is instantiated we compute and store a list of the type
			// parameters that are in scope (and therefore potentially referenced). For type literals that
			// aren't the right hand side of a generic type alias declaration we optimize by reducing the
			// set of type parameters to those that are possibly referenced in the literal.
			typeParameters = c.getOuterTypeParameters(declaration, true /*includeThisTypes*/);
			if (Core.len(target.alias.TypeArguments()) == 0) {
				if ((t.objectFlags & (ObjectFlagsReference | (Checker.ObjectFlagsInstantiationExpressionType : ObjectFlags))) != 0) {
					typeParameters = Core.Filter(typeParameters, (tp:Type) -> {
						return c.isTypeParameterPossiblyReferenced(tp, declaration);
					});
				} else if ((target.symbol.Flags & (SymbolFlagsMethod | SymbolFlagsTypeLiteral)) != 0) {
					typeParameters = Core.Filter(typeParameters, (tp:Type) -> {
						return Core.Some(t.symbol.Declarations, (d:Node) -> {
							return c.isTypeParameterPossiblyReferenced(tp, d);
						});
					});
				}
			}
			if (typeParameters == null) {
				typeParameters = [];
			}
			links.outerTypeParameters = typeParameters;
		}
		if (typeParameters.length == 0) {
			return t;
		}
		// We are instantiating an anonymous type that has one or more type parameters in scope. Apply the
		// mapper to the type parameters to produce the effective list of type arguments, and compute the
		// instantiation cache key from the type IDs of the type arguments.
		final combinedMapper = c.combineTypeMappers(t.Mapper(), m);
		final typeArguments:Array<Type> = [];
		for (i in 0...typeParameters.length) {
			typeArguments.push(combinedMapper.Map(typeParameters[i]));
		}
		var newAlias = alias;
		if (newAlias == null) {
			newAlias = c.instantiateTypeAlias(t.alias, m);
		}
		final data = target.AsObjectType();
		final key = Checker.getTypeInstantiationKey(typeArguments, newAlias, (t.objectFlags & (Checker.ObjectFlagsSingleSignatureType : ObjectFlags)) != 0).Key();
		if (data.instantiations == null) {
			data.instantiations = new StringMap<Type>();
			data.instantiations.set(Checker.getTypeInstantiationKey(typeParameters, target.alias, false).Key(), target);
		}
		var result = data.instantiations.get(key);
		if (result == null) {
			var newMapper = Checker.newTypeMapper(typeParameters, typeArguments);
			if ((target.objectFlags & (Checker.ObjectFlagsSingleSignatureType : ObjectFlags)) != 0 && m != null) {
				newMapper = c.combineTypeMappers(newMapper, m);
			}
			if ((target.objectFlags & ObjectFlagsReference) != 0) {
				result = c.createDeferredTypeReference(t.Target(), t.AsTypeReference().node, newMapper, newAlias);
			} else if ((target.objectFlags & ObjectFlagsMapped) != 0) {
				result = c.instantiateMappedType(target, newMapper, newAlias);
			} else {
				result = c.instantiateAnonymousType(target, newMapper, newAlias);
			}
			data.instantiations.set(key, result);
			if ((result.flags & TypeFlagsObjectFlagsType) != 0 && (result.objectFlags & ObjectFlagsCouldContainTypeVariablesComputed) == 0) {
				// if `result` is one of the object types we tried to make (it may not be, due to how `instantiateMappedType` works), we can carry forward the type variable containment check from the input type arguments
				final resultCouldContainObjectFlags = Core.Some(typeArguments, c.couldContainTypeVariables);
				if ((result.objectFlags & ObjectFlagsCouldContainTypeVariablesComputed) == 0) {
					if ((result.objectFlags & (ObjectFlagsMapped | ObjectFlagsAnonymous | ObjectFlagsReference)) != 0) {
						result.objectFlags |= ObjectFlagsCouldContainTypeVariablesComputed | (resultCouldContainObjectFlags ? ObjectFlagsCouldContainTypeVariables : ObjectFlagsNone);
					} else {
						// If none of the type arguments for the outer type parameters contain type variables, it follows
						// that the instantiated type doesn't reference type variables.
						// Intrinsics have `CouldContainTypeVariablesComputed` pre-set, so this should only cover unions and intersections resulting from `instantiateMappedType`
						result.objectFlags |= (!resultCouldContainObjectFlags ? ObjectFlagsCouldContainTypeVariablesComputed : ObjectFlagsNone);
					}
				}
			}
		}
		return result;
	}

	static function isTypeParameterPossiblyReferenced(c:Checker, tp:Type, node:Node):Bool {
		var containsReference:(Node) -> Bool = null;
		containsReference = (node:Node) -> {
			switch (node.Kind) {
				case KindThisType:
					return tp.AsTypeParameter().isThisType;
				case KindTypeReference:
					// use worker because we're looking for === equality
					if (!tp.AsTypeParameter().isThisType && Core.len(node.TypeArguments()) == 0 && c.getSymbolFromTypeReference(node) == tp.symbol) {
						return true;
					}
				case KindTypeQuery:
					final entityName = node.AsTypeQueryNode().ExprName;
					final firstIdentifier = Ast.GetFirstIdentifier(entityName);
					if (!Ast.IsThisIdentifier(firstIdentifier)) {
						final firstIdentifierSymbol = c.getResolvedSymbol(firstIdentifier);
						final tpDeclaration = tp.symbol.Declarations[0]; // There is exactly one declaration, otherwise `containsReference` is not called
						var tpScope:Node = null;
						if (Ast.IsTypeParameterDeclaration(tpDeclaration)) {
							tpScope = tpDeclaration.Parent; // Type parameter is a regular type parameter, e.g. foo<T>
						} else if (tp.AsTypeParameter().isThisType) {
							tpScope = tpDeclaration; // Type parameter is the this type, and its declaration is the class declaration.
						}
						if (tpScope != null) {
							return Core.Some(firstIdentifierSymbol.Declarations, (d:Node) -> Checker.isNodeDescendantOf(d, tpScope))
								|| Core.Some(node.TypeArguments(), containsReference);
						}
					}
					return true;
				case KindMethodDeclaration | KindMethodSignature:
					final returnType = node.Type();
					return returnType == null && node.Body() != null
						|| Core.Some(node.TypeParameters(), containsReference)
						|| Core.Some(node.Parameters(), containsReference)
						|| returnType != null && containsReference(returnType);
				default:
			}
			return node.ForEachChild(containsReference);
		};
		// If the type parameter doesn't have exactly one declaration, if there are intervening statement blocks
		// between the node and the type parameter declaration, if the node contains actual references to the
		// type parameter, or if the node contains type queries that we can't prove couldn't contain references to the type parameter,
		// we consider the type parameter possibly referenced.
		if (tp.symbol != null && Core.len(tp.symbol.Declarations) == 1) {
			final container = tp.symbol.Declarations[0].Parent;
			var n = node;
			while (n != container) {
				if (n == null || Ast.IsBlock(n) || Ast.IsConditionalTypeNode(n) && containsReference(n.AsConditionalTypeNode().ExtendsType)) {
					return true;
				}
				n = n.Parent;
			}
			return containsReference(node);
		}
		return true;
	}

	static function instantiateAnonymousType(c:Checker, t:Type, m:TypeMapper, alias:TypeAlias):Type {
		final result = c.newObjectType((t.objectFlags & ~(ObjectFlagsCouldContainTypeVariablesComputed | ObjectFlagsCouldContainTypeVariables)) | ObjectFlagsInstantiated, t.symbol);
		if ((t.objectFlags & ObjectFlagsMapped) != 0) {
			result.AsMappedType().declaration = t.AsMappedType().declaration;
			// C.f. instantiateSignature
			final origTypeParameter = c.getTypeParameterFromMappedType(t);
			final freshTypeParameter = c.cloneTypeParameter(origTypeParameter);
			result.AsMappedType().typeParameter = freshTypeParameter;
			m = c.combineTypeMappers(Checker.newSimpleTypeMapper(origTypeParameter, freshTypeParameter), m);
			freshTypeParameter.AsTypeParameter().mapper = m;
		} else if ((t.objectFlags & (Checker.ObjectFlagsInstantiationExpressionType : ObjectFlags)) != 0) {
			result.AsInstantiationExpressionType().node = t.AsInstantiationExpressionType().node;
		}
		if (alias == null) {
			alias = c.instantiateTypeAlias(t.alias, m);
		}
		result.alias = alias;
		if (alias != null && Core.len(alias.typeArguments) != 0) {
			result.objectFlags |= c.getPropagatingFlagsOfTypes(result.alias.typeArguments, TypeFlagsNone);
		}
		final d = result.AsObjectType();
		d.target = t;
		d.mapper = m;
		return result;
	}

	static function getConditionalTypeInstantiation(c:Checker, t:Type, mapper:TypeMapper, forConstraint:Bool, alias:TypeAlias):Type {
		final root = t.AsConditionalType().root;
		if (Core.len(root.outerTypeParameters) != 0) {
			// We are instantiating a conditional type that has one or more type parameters in scope. Apply the
			// mapper to the type parameters to produce the effective list of type arguments, and compute the
			// instantiation cache key from the type IDs of the type arguments.
			final typeArguments = Core.Map(root.outerTypeParameters, mapper.Map);
			final key = Checker.getConditionalTypeKey(typeArguments, alias, forConstraint).Key();
			var result = root.instantiations.get(key);
			if (result == null) {
				final newMapper = Checker.newTypeMapper(root.outerTypeParameters, typeArguments);
				final checkType = root.checkType;
				var distributionType:Type = null;
				if (root.isDistributive) {
					distributionType = c.getReducedType(newMapper.Map(checkType));
				}
				// Distributive conditional types are distributed over union types. For example, when the
				// distributive conditional type T extends U ? X : Y is instantiated with A | B for T, the
				// result is (A extends U ? X : Y) | (B extends U ? X : Y).
				if (distributionType != null && checkType != distributionType && (distributionType.flags & (TypeFlagsUnion | TypeFlagsNever)) != 0) {
					result = c.mapTypeWithAlias(distributionType, (t:Type) -> {
						return c.getConditionalType(root, Checker.prependTypeMapping(checkType, t, newMapper), forConstraint, null);
					}, alias);
				} else {
					result = c.getConditionalType(root, newMapper, forConstraint, alias);
				}
				root.instantiations.set(key, result);
			}
			return result;
		}
		return t;
	}

	static function cloneTypeParameter(c:Checker, tp:Type):Type {
		final result = c.newTypeParameter(tp.symbol);
		result.AsTypeParameter().target = tp;
		return result;
	}

	static function getHomomorphicTypeVariable(c:Checker, t:Type):Type {
		final constraintType = c.getConstraintTypeFromMappedType(t);
		if ((constraintType.flags & TypeFlagsIndex) != 0) {
			final typeVariable = c.getActualTypeVariable(constraintType.AsIndexType().target);
			if ((typeVariable.flags & TypeFlagsTypeParameter) != 0) {
				return typeVariable;
			}
		}
		return null;
	}

	static function instantiateMappedType(c:Checker, t:Type, m:TypeMapper, alias:TypeAlias):Type {
		// For a homomorphic mapped type { [P in keyof T]: X }, where T is some type variable, the mapping
		// operation depends on T as follows:
		// * If T is a primitive type no mapping is performed and the result is simply T.
		// * If T is a union type we distribute the mapped type over the union.
		// * If T is an array we map to an array where the element type has been transformed.
		// * If T is a tuple we map to a tuple where the element types have been transformed.
		// * If T is an intersection of array or tuple types we map to an intersection of transformed array or tuple types.
		// * Otherwise we map to an object type where the type of each property has been transformed.
		// For example, when T is instantiated to a union type A | B, we produce { [P in keyof A]: X } |
		// { [P in keyof B]: X }, and when when T is instantiated to a union type A | undefined, we produce
		// { [P in keyof A]: X } | undefined.
		final d = t.AsMappedType();
		final typeVariable = c.getHomomorphicTypeVariable(t);
		var instantiateConstituent:(Type) -> Type = null;
		instantiateConstituent = (s:Type) -> {
			if ((s.flags & (TypeFlagsAnyOrUnknown | TypeFlagsInstantiableNonPrimitive | TypeFlagsObject | TypeFlagsIntersection)) == 0 || s == c.wildcardType || c.isErrorType(s)) {
				return s;
			}
			if (d.declaration.NameType == null) {
				if (c.isArrayType(s) || (s.flags & TypeFlagsAny) != 0 && c.findResolutionCycleStartIndex(typeVariable, TypeSystemPropertyNameResolvedBaseConstraint) < 0 && c.hasArrayOrTypeTypeConstraint(typeVariable)) {
					return c.instantiateMappedArrayType(s, t, Checker.prependTypeMapping(typeVariable, s, m));
				}
				if (Checker.isTupleType(s)) {
					return c.instantiateMappedTupleType(s, t, typeVariable, m);
				}
				if (c.isArrayOrTupleOrIntersection(s)) {
					return c.getIntersectionType(Core.Map(s.Types(), instantiateConstituent));
				}
			}
			return c.instantiateAnonymousType(t, Checker.prependTypeMapping(typeVariable, s, m), null);
		};
		if (typeVariable != null) {
			final mappedTypeVariable = c.instantiateType(typeVariable, m);
			if (typeVariable != mappedTypeVariable) {
				return c.mapTypeWithAlias(c.getReducedType(mappedTypeVariable), instantiateConstituent, alias);
			}
		}
		// If the constraint type of the instantiation is the wildcard type, return the wildcard type.
		if (c.instantiateType(c.getConstraintTypeFromMappedType(t), m) == c.wildcardType) {
			return c.wildcardType;
		}
		return c.instantiateAnonymousType(t, m, alias);
	}

	static function hasArrayOrTypeTypeConstraint(c:Checker, typeVariable:Type):Bool {
		final constraint = c.getConstraintOfTypeParameter(typeVariable);
		return constraint != null && Checker.everyType(constraint, c.isArrayOrTupleType);
	}

	static function instantiateMappedArrayType(c:Checker, arrayType:Type, mappedType:Type, m:TypeMapper):Type {
		final elementType = c.instantiateMappedTypeTemplate(mappedType, c.numberType, true /*isOptional*/, m);
		if (c.isErrorType(elementType)) {
			return c.errorType;
		}
		return c.createArrayTypeEx(elementType, Checker.getModifiedReadonlyState(c.isReadonlyArrayType(arrayType), Checker.getMappedTypeModifiers(mappedType)));
	}

	static function instantiateMappedTupleType(c:Checker, tupleType:Type, mappedType:Type, typeVariable:Type, m:TypeMapper):Type {
		// We apply the mapped type's template type to each of the fixed part elements. For variadic elements, we
		// apply the mapped type itself to the variadic element type. For other elements in the variable part of the
		// tuple, we surround the element type with an array type and apply the mapped type to that. This ensures
		// that we get sequential property key types for the fixed part of the tuple, and property key type number
		// for the remaining elements. For example
		//
		//   type Keys<T> = { [K in keyof T]: K };
		//   type Foo<T extends any[]> = Keys<[string, string, ...T, string]>; // ["0", "1", ...Keys<T>, number]
		//
		final elementInfos = tupleType.TargetTupleType().elementInfos;
		final fixedLength = tupleType.TargetTupleType().fixedLength;
		var fixedMapper = m;
		if (fixedLength != 0) {
			fixedMapper = Checker.prependTypeMapping(typeVariable, tupleType, m);
		}
		final modifiers = Checker.getMappedTypeModifiers(mappedType);
		final elementTypes = c.getElementTypes(tupleType);
		final newElementTypes:Array<Type> = [];
		final newElementInfos = cloneElementInfos(elementInfos);
		for (i in 0...Core.len(elementTypes)) {
			final e = elementTypes[i];
			final flags = elementInfos[i].flags;
			var mapped:Type;
			if (i < fixedLength) {
				mapped = c.instantiateMappedTypeTemplate(mappedType, c.getStringLiteralType(Std.string(i)), (flags & ElementFlagsOptional) != 0, fixedMapper);
			} else if ((flags & ElementFlagsVariadic) != 0) {
				mapped = c.instantiateType(mappedType, Checker.prependTypeMapping(typeVariable, e, m));
			} else {
				mapped = c.getElementTypeOfArrayType(c.instantiateType(mappedType, Checker.prependTypeMapping(typeVariable, c.createArrayType(e), m)));
				if (mapped == null) {
					mapped = c.unknownType;
				}
			}
			if ((modifiers & MappedTypeModifiersIncludeOptional) != 0) {
				if ((flags & ElementFlagsRequired) != 0) {
					newElementInfos[i].flags = ElementFlagsOptional;
				}
			} else if ((modifiers & MappedTypeModifiersExcludeOptional) != 0) {
				if ((flags & ElementFlagsOptional) != 0) {
					newElementInfos[i].flags = ElementFlagsRequired;
				}
			}
			newElementTypes.push(mapped);
		}
		final newReadonly = Checker.getModifiedReadonlyState(tupleType.TargetTupleType().readonly, Checker.getMappedTypeModifiers(mappedType));
		if (newElementTypes.indexOf(c.errorType) >= 0) {
			return c.errorType;
		}
		return c.createTupleTypeEx(newElementTypes, newElementInfos, newReadonly);
	}

	static function instantiateMappedTypeTemplate(c:Checker, t:Type, key:Type, isOptional:Bool, m:TypeMapper):Type {
		final templateMapper = Checker.appendTypeMapping(m, c.getTypeParameterFromMappedType(t), key);
		final propType = c.instantiateType(c.getTemplateTypeFromMappedType(Core.OrElse(t.AsMappedType().target, t)), templateMapper);
		final modifiers = Checker.getMappedTypeModifiers(t);
		if (c.strictNullChecks && (modifiers & MappedTypeModifiersIncludeOptional) != 0 && !c.maybeTypeOfKind(propType, TypeFlagsUndefined | TypeFlagsVoid)) {
			return c.getOptionalType(propType, true /*isProperty*/);
		} else if (c.strictNullChecks && (modifiers & MappedTypeModifiersExcludeOptional) != 0 && isOptional) {
			return c.getTypeWithFacts(propType, TypeFactsNEUndefined);
		} else {
			return propType;
		}
	}

	static function getTypeParameterFromMappedType(c:Checker, t:Type):Type {
		final m = t.AsMappedType();
		if (m.typeParameter == null) {
			m.typeParameter = c.getDeclaredTypeOfTypeParameter(c.getSymbolOfDeclaration(m.declaration.TypeParameter));
		}
		return m.typeParameter;
	}

	static function getConstraintTypeFromMappedType(c:Checker, t:Type):Type {
		final m = t.AsMappedType();
		if (m.constraintType == null) {
			m.constraintType = Core.OrElse(c.getConstraintOfTypeParameter(c.getTypeParameterFromMappedType(t)), c.errorType);
		}
		return m.constraintType;
	}

	static function getNameTypeFromMappedType(c:Checker, t:Type):Type {
		final m = t.AsMappedType();
		if (m.declaration.NameType == null) {
			return null;
		}
		if (m.nameType == null) {
			m.nameType = c.instantiateType(c.getTypeFromTypeNode(m.declaration.NameType), m.mapper);
		}
		return m.nameType;
	}

	static function getTemplateTypeFromMappedType(c:Checker, t:Type):Type {
		final m = t.AsMappedType();
		if (m.templateType == null) {
			if (m.declaration.Type != null) {
				m.templateType = c.instantiateType(c.addOptionalityEx(c.getTypeFromTypeNode(m.declaration.Type) /*isProperty*/, true, (Checker.getMappedTypeModifiers(t) & MappedTypeModifiersIncludeOptional) != 0), m.mapper);
			} else {
				m.templateType = c.errorType;
			}
		}
		return m.templateType;
	}

	static function isMappedTypeWithKeyofConstraintDeclaration(c:Checker, t:Type):Bool {
		final constraintDeclaration = c.getConstraintDeclarationForMappedType(t);
		return Ast.IsTypeOperatorNode(constraintDeclaration) && constraintDeclaration.AsTypeOperatorNode().Operator == KindKeyOfKeyword;
	}

	static function getConstraintDeclarationForMappedType(c:Checker, t:Type):Node {
		return t.AsMappedType().declaration.TypeParameter.AsTypeParameterDeclaration().Constraint;
	}

	static function getApparentMappedTypeKeys(c:Checker, nameType:Type, targetType:Type):Type {
		final modifiersType = c.getApparentType(c.getModifiersTypeFromMappedType(targetType));
		var mappedKeys:Array<Type> = null;
		c.forEachMappedTypePropertyKeyTypeAndIndexSignatureKeyType(modifiersType, TypeFlagsStringOrNumberLiteralOrUnique, false, (t:Type) -> {
			if (mappedKeys == null) {
				mappedKeys = [];
			}
			mappedKeys.push(c.instantiateType(nameType, Checker.appendTypeMapping(targetType.Mapper(), c.getTypeParameterFromMappedType(targetType), t)));
		});
		return c.getUnionType(mappedKeys);
	}

	static function forEachMappedTypePropertyKeyTypeAndIndexSignatureKeyType(c:Checker, t:Type, include:TypeFlags, stringsOnly:Bool, cb:(keyType:Type) -> Void):Void {
		for (prop in rangeOf(c.getPropertiesOfType(t))) {
			cb(c.getLiteralTypeFromProperty(prop, include, false));
		}
		if ((t.flags & TypeFlagsAny) != 0) {
			cb(c.stringType);
		} else {
			for (info in rangeOf(c.getIndexInfosOfType(t))) {
				if (!stringsOnly || (info.keyType.flags & (TypeFlagsString | TypeFlagsTemplateLiteral)) != 0) {
					cb(info.keyType);
				}
			}
		}
	}

	static function instantiateReverseMappedType(c:Checker, t:Type, m:TypeMapper):Type {
		final r = t.AsReverseMappedType();
		final innerMappedType = c.instantiateType(r.mappedType, m);
		if ((innerMappedType.objectFlags & ObjectFlagsMapped) == 0) {
			return t;
		}
		final innerIndexType = c.instantiateType(r.constraintType, m);
		if ((innerIndexType.flags & TypeFlagsIndex) == 0) {
			return t;
		}
		final instantiated = c.inferTypeForHomomorphicMappedType(c.instantiateType(r.source, m), innerMappedType, innerIndexType);
		if (instantiated != null) {
			return instantiated;
		}
		return t;
		// Nested invocation of `inferTypeForHomomorphicMappedType` or the `source` instantiated into something unmappable
	}

	static function instantiateTypeAlias(c:Checker, alias:TypeAlias, m:TypeMapper):TypeAlias {
		if (alias == null) {
			return null;
		}
		final result = new TypeAlias();
		result.symbol = alias.symbol;
		result.typeArguments = c.instantiateTypes(alias.typeArguments, m);
		return result;
	}

	static function instantiateTypes(c:Checker, types:Array<Type>, m:TypeMapper):Array<Type> {
		return Checker.instantiateList(c, types, m, instantiateTypeFn);
	}

	static function instantiateSymbols(c:Checker, symbols:Array<Symbol>, m:TypeMapper):Array<Symbol> {
		return Checker.instantiateList(c, symbols, m, instantiateSymbolFn);
	}

	static function instantiateSignatures(c:Checker, signatures:Array<Signature>, m:TypeMapper):Array<Signature> {
		return Checker.instantiateList(c, signatures, m, instantiateSignatureFn);
	}

	static function instantiateIndexInfos(c:Checker, indexInfos:Array<IndexInfo>, m:TypeMapper):Array<IndexInfo> {
		return Checker.instantiateList(c, indexInfos, m, instantiateIndexInfoFn);
	}

	static function tryGetTypeFromTypeNode(c:Checker, node:Node):Type {
		final typeNode = node.Type();
		if (typeNode != null) {
			return c.getTypeFromTypeNode(typeNode);
		}
		return null;
	}

	static function getTypeFromTypeNode(c:Checker, node:Node):Type {
		return c.getConditionalFlowTypeOfType(c.getTypeFromTypeNodeWorker(node), node);
	}

	static function getTypeFromTypeNodeWorker(c:Checker, node:Node):Type {
		switch (node.Kind) {
			case KindAnyKeyword | KindJSDocAllType:
				return c.anyType;
			case KindJSDocNonNullableType:
				return c.getTypeFromTypeNode(node.Type());
			case KindJSDocNullableType:
				final t = c.getTypeFromTypeNode(node.Type());
				if (c.strictNullChecks) {
					return c.getNullableType(t, TypeFlagsNull);
				} else {
					return t;
				}
			case KindJSDocVariadicType:
				return c.createArrayType(c.getTypeFromTypeNode(node.AsJSDocVariadicType().Type));
			case KindJSDocOptionalType:
				return c.addOptionality(c.getTypeFromTypeNode(node.Type()));
			case KindUnknownKeyword:
				return c.unknownType;
			case KindStringKeyword:
				return c.stringType;
			case KindNumberKeyword:
				return c.numberType;
			case KindBigIntKeyword:
				return c.bigintType;
			case KindBooleanKeyword:
				return c.booleanType;
			case KindSymbolKeyword:
				return c.esSymbolType;
			case KindVoidKeyword:
				return c.voidType;
			case KindUndefinedKeyword:
				return c.undefinedType;
			case KindNullKeyword:
				return c.nullType;
			case KindNeverKeyword:
				return c.neverType;
			case KindObjectKeyword:
				return c.nonPrimitiveType;
			case KindIntrinsicKeyword:
				return c.intrinsicMarkerType;
			case KindThisType | KindThisKeyword:
				return c.getTypeFromThisTypeNode(node);
			case KindLiteralType:
				return c.getTypeFromLiteralTypeNode(node);
			case KindTypeReference | KindExpressionWithTypeArguments:
				return c.getTypeFromTypeReference(node);
			case KindTypePredicate:
				if (node.AsTypePredicateNode().AssertsModifier != null) {
					return c.voidType;
				}
				return c.booleanType;
			case KindTypeQuery:
				return c.getTypeFromTypeQueryNode(node);
			case KindArrayType | KindTupleType:
				return c.getTypeFromArrayOrTupleTypeNode(node);
			case KindOptionalType:
				return c.getTypeFromOptionalTypeNode(node);
			case KindUnionType:
				return c.getTypeFromUnionTypeNode(node);
			case KindIntersectionType:
				return c.getTypeFromIntersectionTypeNode(node);
			case KindNamedTupleMember:
				return c.getTypeFromNamedTupleTypeNode(node);
			case KindParenthesizedType:
				return c.getTypeFromTypeNode(node.Type());
			case KindRestType:
				return c.getTypeFromRestTypeNode(node);
			case KindFunctionType | KindConstructorType | KindTypeLiteral:
				return c.getTypeFromTypeLiteralOrFunctionOrConstructorTypeNode(node);
			case KindTypeOperator:
				return c.getTypeFromTypeOperatorNode(node);
			case KindIndexedAccessType:
				return c.getTypeFromIndexedAccessTypeNode(node);
			case KindTemplateLiteralType:
				return c.getTypeFromTemplateTypeNode(node);
			case KindMappedType:
				return c.getTypeFromMappedTypeNode(node);
			case KindConditionalType:
				return c.getTypeFromConditionalTypeNode(node);
			case KindInferType:
				return c.getTypeFromInferTypeNode(node);
			case KindImportType:
				return c.getTypeFromImportTypeNode(node);
			default:
				return c.errorType;
		}
	}

	static function getTypeFromThisTypeNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			links.resolvedType = c.getThisType(node);
		}
		return links.resolvedType;
	}

	static function getThisType(c:Checker, node:Node):Type {
		final container = Ast.GetThisContainer(node /*includeArrowFunctions*/, false /*includeClassComputedPropertyName*/, false);
		if (container != null) {
			final parent = container.Parent;
			if (parent != null && (Ast.IsClassLike(parent) || Ast.IsInterfaceDeclaration(parent))) {
				if (!Ast.IsStatic(container) && (!Ast.IsConstructorDeclaration(container) || Checker.isNodeDescendantOf(node, container.Body()))) {
					return Core.Coalesce(c.getDeclaredTypeOfClassOrInterface(c.getSymbolOfDeclaration(parent)).AsInterfaceType().thisType, c.errorType);
				}
			}
		}
		c.error(node, Diagnostics.A_this_type_is_available_only_in_a_non_static_member_of_a_class_or_interface);
		return c.errorType;
	}

	static function getTypeFromLiteralTypeNode(c:Checker, node:Node):Type {
		if (node.AsLiteralTypeNode().Literal.Kind == KindNullKeyword) {
			return c.nullType;
		}
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			links.resolvedType = c.getRegularTypeOfLiteralType(c.checkExpression(node.AsLiteralTypeNode().Literal));
		}
		return links.resolvedType;
	}

	static function getTypeFromTypeLiteralOrFunctionOrConstructorTypeNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			// Deferred resolution of members is handled by resolveObjectTypeMembers
			final alias = c.getAliasForTypeNode(node);
			final sym = node.Symbol();
			if (sym == null || symbolTableLen(c.getMembersOfSymbol(sym)) == 0 && alias == null) {
				links.resolvedType = c.emptyTypeLiteralType;
			} else {
				final t = c.newObjectType(ObjectFlagsAnonymous, node.Symbol());
				t.alias = alias;
				links.resolvedType = t;
			}
		}
		return links.resolvedType;
	}

	static function getTypeFromIndexedAccessTypeNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			final objectType = c.getTypeFromTypeNode(node.AsIndexedAccessTypeNode().ObjectType);
			final indexType = c.getTypeFromTypeNode(node.AsIndexedAccessTypeNode().IndexType);
			final potentialAlias = c.getAliasForTypeNode(node);
			links.resolvedType = c.getIndexedAccessTypeEx(objectType, indexType, AccessFlagsNone, node, potentialAlias);
		}
		return links.resolvedType;
	}

	static function getTypeFromTypeOperatorNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			final argType = node.Type();
			switch (node.AsTypeOperatorNode().Operator) {
				case KindKeyOfKeyword:
					links.resolvedType = c.getIndexType(c.getTypeFromTypeNode(argType));
				case KindUniqueKeyword:
					if (argType.Kind == KindSymbolKeyword) {
						links.resolvedType = c.getESSymbolLikeTypeForNode(Ast.WalkUpParenthesizedTypes(node.Parent));
					} else {
						links.resolvedType = c.errorType;
					}
				case KindReadonlyKeyword:
					links.resolvedType = c.getTypeFromTypeNode(argType);
				default:
					throw "Unhandled case in getTypeFromTypeOperatorNode";
			}
		}
		return links.resolvedType;
	}

	static function getESSymbolLikeTypeForNode(c:Checker, node:Node):Type {
		if (Checker.isValidESSymbolDeclaration(node)) {
			final symbol = c.getSymbolOfNode(node);
			if (symbol != null) {
				var uniqueType = c.uniqueESSymbolTypes.get(symbol);
				if (uniqueType == null) {
					final b = new StringBuf();
					b.add(Ast.InternalSymbolNamePrefix);
					b.addChar('@'.code);
					b.add(symbol.Name);
					b.addChar('@'.code);
					b.add(Std.string(Ast.GetSymbolId(symbol)));
					uniqueType = c.newUniqueESSymbolType(symbol, b.toString());
					c.uniqueESSymbolTypes.set(symbol, uniqueType);
				}
				return uniqueType;
			}
		}
		return c.esSymbolType;
	}

	static function getTypeFromTypeReference(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			// Cache both the resolved symbol and the resolved type. The resolved symbol is needed when we check the
			// type reference in checkTypeReferenceNode.
			// handle LS queries on the `const` in `x as const` by resolving to the type of `x`
			if (Checker.isConstTypeReference(node) && Ast.IsAssertionExpression(node.Parent)) {
				links.resolvedType = c.checkExpressionCached(node.Parent.Expression());
			} else {
				final t = c.getIntendedTypeFromJSDocTypeReference(node);
				if (t != null) {
					links.resolvedType = t;
				} else {
					links.resolvedType = c.getTypeReferenceType(node, c.getSymbolFromTypeReference(node));
				}
			}
		}
		return links.resolvedType;
	}

	static function getIntendedTypeFromJSDocTypeReference(c:Checker, node:Node):Type {
		if ((node.Flags & NodeFlagsJSDoc) != 0 && Ast.IsTypeReferenceNode(node)) {
			final typeName = node.AsTypeReferenceNode().TypeName;
			if (Ast.IsIdentifier(typeName)) {
				final typeArgs = node.TypeArguments();
				switch (typeName.Text()) {
					case "String":
						c.checkNoTypeArguments(node, null);
						return c.stringType;
					case "Number":
						c.checkNoTypeArguments(node, null);
						return c.numberType;
					case "BigInt":
						c.checkNoTypeArguments(node, null);
						return c.bigintType;
					case "Boolean":
						c.checkNoTypeArguments(node, null);
						return c.booleanType;
					case "Void":
						c.checkNoTypeArguments(node, null);
						return c.voidType;
					case "Undefined":
						c.checkNoTypeArguments(node, null);
						return c.undefinedType;
					case "Null":
						c.checkNoTypeArguments(node, null);
						return c.nullType;
					case "Function" | "function":
						c.checkNoTypeArguments(node, null);
						return c.globalFunctionType;
					case "array":
						if (Core.len(typeArgs) == 0 && !c.noImplicitAny) {
							return c.anyArrayType;
						}
					case "promise":
						if (Core.len(typeArgs) == 0 && !c.noImplicitAny) {
							return c.createPromiseType(c.anyType);
						}
					case "Object":
						if (Core.len(typeArgs) == 2) {
							final recordSymbol = c.getGlobalRecordSymbol();
							if (recordSymbol != null) {
								final indexType = c.getTypeFromTypeNode(typeArgs[0]);
								if (c.isValidIndexKeyType(indexType)) {
									return c.getTypeAliasInstantiation(recordSymbol, [indexType, c.getTypeFromTypeNode(typeArgs[1])], null);
								}
							}
							return c.anyType;
						}
						if (!c.noImplicitAny) {
							c.checkNoTypeArguments(node, null);
							return c.anyType;
						}
					default:
				}
			}
		}
		return null;
	}

	static function getSymbolFromTypeReference(c:Checker, node:Node):Symbol {
		final links = c.symbolNodeLinks.Get(node);
		if (links.resolvedSymbol == null) {
			if (Checker.isConstTypeReference(node) && Ast.IsAssertionExpression(node.Parent)) {
				links.resolvedSymbol = c.unknownSymbol;
			} else {
				links.resolvedSymbol = c.resolveTypeReferenceName(node, SymbolFlagsType, false /*ignoreErrors*/);
			}
		}
		return links.resolvedSymbol;
	}

	static function resolveTypeReferenceName(c:Checker, typeReference:Node, meaning:SymbolFlags, ignoreErrors:Bool):Symbol {
		final name = Checker.getTypeReferenceName(typeReference);
		if (name == null) {
			return c.unknownSymbol;
		}
		final symbol = c.resolveEntityName(name, meaning, ignoreErrors, false /*dontResolveAlias*/, null /*location*/);
		if (symbol != null && symbol != c.unknownSymbol) {
			return symbol;
		}
		if (ignoreErrors) {
			return c.unknownSymbol;
		}
		return c.getUnresolvedSymbolForEntityName(name);
	}

	static function getUnresolvedSymbolForEntityName(c:Checker, name:Node):Symbol {
		var identifier:Node;
		switch (name.Kind) {
			case KindQualifiedName:
				identifier = name.AsQualifiedName().Right;
			case KindPropertyAccessExpression:
				identifier = name.Name();
			default:
				identifier = name;
		}
		final text = identifier.Text();
		if (text != "") {
			var parentSymbol:Symbol = null;
			switch (name.Kind) {
				case KindQualifiedName:
					parentSymbol = c.getUnresolvedSymbolForEntityName(name.AsQualifiedName().Left);
				case KindPropertyAccessExpression:
					parentSymbol = c.getUnresolvedSymbolForEntityName(name.Expression());
				default:
			}
			var path:std.String;
			if (parentSymbol != null) {
				path = Checker.getSymbolPath(parentSymbol) + "." + text;
			} else {
				path = text;
			}
			var result = c.unresolvedSymbols.get(path);
			if (result == null) {
				result = c.newSymbolEx(SymbolFlagsTypeAlias, text, CheckFlagsUnresolved);
				c.unresolvedSymbols.set(path, result);
				result.Parent = parentSymbol;
				c.typeAliasLinks.Get(result).declaredType = c.unresolvedType;
			}
			return result;
		}
		return c.unknownSymbol;
	}

	static function getTypeReferenceType(c:Checker, node:Node, symbol:Symbol):Type {
		if (symbol == c.unknownSymbol) {
			return c.errorType;
		}
		if ((symbol.Flags & (SymbolFlagsClass | SymbolFlagsInterface)) != 0) {
			return c.getTypeFromClassOrInterfaceReference(node, symbol);
		}
		if ((symbol.Flags & SymbolFlagsTypeAlias) != 0) {
			return c.getTypeFromTypeAliasReference(node, symbol);
		}
		// Get type from reference to named type that cannot be generic (enum or type parameter)
		final res = c.tryGetDeclaredTypeOfSymbol(symbol);
		if (res != null && c.checkNoTypeArguments(node, symbol)) {
			return c.getRegularTypeOfLiteralType(res);
		}

		// !!! Resolving values as types for JS
		return c.errorType;
	}

	/**
	 * Get type from type-reference that reference to class or interface
	 */
	static function getTypeFromClassOrInterfaceReference(c:Checker, node:Node, symbol:Symbol):Type {
		final t = c.getDeclaredTypeOfClassOrInterface(c.getMergedSymbol(symbol));
		final d = t.AsInterfaceType();
		final typeParameters = d.LocalTypeParameters();
		if (Core.len(typeParameters) != 0) {
			final numTypeArguments = Core.len(node.TypeArguments());
			final minTypeArgumentCount = c.getMinTypeArgumentCount(typeParameters);
			final isJs = Ast.IsInJSFile(node);
			final isJsImplicitAny = !c.noImplicitAny && isJs;
			if (!isJsImplicitAny && (numTypeArguments < minTypeArgumentCount || numTypeArguments > typeParameters.length)) {
				var message:Message;

				final missingAugmentsTag = isJs && Ast.IsExpressionWithTypeArguments(node) && !Ast.IsJSDocAugmentsTag(node.Parent);
				if (missingAugmentsTag) {
					message = Diagnostics.Expected_0_type_arguments_provide_these_with_an_extends_tag;
					if (minTypeArgumentCount < typeParameters.length) {
						message = Diagnostics.Expected_0_1_type_arguments_provide_these_with_an_extends_tag;
					}
				} else {
					message = Diagnostics.Generic_type_0_requires_1_type_argument_s;
					if (minTypeArgumentCount < typeParameters.length) {
						message = Diagnostics.Generic_type_0_requires_between_1_and_2_type_arguments;
					}
				}
				final typeStr = c.TypeToStringEx(t, null /*enclosingDeclaration*/, TypeFormatFlagsWriteArrayAsGenericType, null);
				c.error(node, message, typeStr, minTypeArgumentCount, typeParameters.length);
				if (!isJs) {
					// TODO: Adopt same permissive behavior in TS as in JS to reduce follow-on editing experience failures (requires editing fillMissingTypeArguments)
					return c.errorType;
				}
			}
			if (node.Kind == KindTypeReference && c.isDeferredTypeReferenceNode(node, numTypeArguments != typeParameters.length)) {
				return c.createDeferredTypeReference(t, node, null /*mapper*/, null /*alias*/);
			}
			// In a type reference, the outer type parameters of the referenced class or interface are automatically
			// supplied as type arguments and the type reference only specifies arguments for the local type parameters
			// of the class or interface.
			final localTypeArguments = c.fillMissingTypeArguments(c.getTypeArgumentsFromNode(node), typeParameters, minTypeArgumentCount, isJs);
			final typeArguments = appendAll(d.OuterTypeParameters(), localTypeArguments);
			return c.createTypeReferenceEx(t, typeArguments, ObjectFlagsFromTypeNode);
		}
		if (c.checkNoTypeArguments(node, symbol)) {
			return t;
		}
		return c.errorType;
	}

	static function getTypeArgumentsFromNode(c:Checker, node:Node):Array<Type> {
		return Core.Map(node.TypeArguments(), n -> c.getTypeFromTypeNode(n));
	}

	static function checkNoTypeArguments(c:Checker, node:Node, symbol:Symbol):Bool {
		if (Core.len(node.TypeArguments()) != 0) {
			var typeName:std.String;
			if (symbol != null) {
				typeName = c.symbolToString(symbol);
			} else {
				typeName = Scanner.DeclarationNameToString(node.AsTypeReferenceNode().TypeName);
			}
			c.error(node, Diagnostics.Type_0_is_not_generic, typeName);
			return false;
		}
		return true;
	}

	// Return true if the given type reference node is directly aliased or if it needs to be deferred
	// because it is possibly contained in a circular chain of eagerly resolved types.
	static function isDeferredTypeReferenceNode(c:Checker, node:Node, hasDefaultTypeArguments:Bool):Bool {
		if (c.getAliasSymbolForTypeNode(node) != null) {
			return true;
		}
		if (c.isResolvedByTypeAlias(node)) {
			switch (node.Kind) {
				case KindArrayType:
					return c.mayResolveTypeAlias(node.AsArrayTypeNode().ElementType);
				case KindTupleType:
					return Core.Some(node.Elements(), n -> c.mayResolveTypeAlias(n));
				case KindTypeReference:
					return hasDefaultTypeArguments || Core.Some(node.TypeArguments(), n -> c.mayResolveTypeAlias(n));
				default:
			}
			throw "Unhandled case in isDeferredTypeReferenceNode";
		}
		return false;
	}

	// Return true when the given node is transitively contained in type constructs that eagerly
	// resolve their constituent types. We include SyntaxKind.TypeReference because type arguments
	// of type aliases are eagerly resolved.
	static function isResolvedByTypeAlias(c:Checker, node:Node):Bool {
		final parent = node.Parent;
		switch (parent.Kind) {
			case KindParenthesizedType | KindNamedTupleMember | KindTypeReference | KindUnionType | KindIntersectionType | KindIndexedAccessType
				| KindConditionalType | KindTypeOperator | KindArrayType | KindTupleType:
				return c.isResolvedByTypeAlias(parent);
			case KindTypeAliasDeclaration | KindJSTypeAliasDeclaration:
				return true;
			default:
		}
		return false;
	}

	// Return true if resolving the given node (i.e. getTypeFromTypeNode) possibly causes resolution
	// of a type alias.
	static function mayResolveTypeAlias(c:Checker, node:Node):Bool {
		switch (node.Kind) {
			case KindTypeReference:
				return (c.resolveTypeReferenceName(node, SymbolFlagsType, false).Flags & SymbolFlagsTypeAlias) != 0;
			case KindTypeQuery:
				return true;
			case KindTypeOperator:
				return node.AsTypeOperatorNode().Operator != KindUniqueKeyword && c.mayResolveTypeAlias(node.Type());
			case KindParenthesizedType | KindOptionalType | KindNamedTupleMember:
				return c.mayResolveTypeAlias(node.Type());
			case KindRestType:
				return node.Type().Kind != KindArrayType || c.mayResolveTypeAlias(node.Type().AsArrayTypeNode().ElementType);
			case KindUnionType:
				return Core.Some(node.AsUnionTypeNode().Types.Nodes, n -> c.mayResolveTypeAlias(n));
			case KindIntersectionType:
				return Core.Some(node.AsIntersectionTypeNode().Types.Nodes, n -> c.mayResolveTypeAlias(n));
			case KindIndexedAccessType:
				return c.mayResolveTypeAlias(node.AsIndexedAccessTypeNode().ObjectType) || c.mayResolveTypeAlias(node.AsIndexedAccessTypeNode().IndexType);
			case KindConditionalType:
				return c.mayResolveTypeAlias(node.AsConditionalTypeNode().CheckType) || c.mayResolveTypeAlias(node.AsConditionalTypeNode().ExtendsType)
					|| c.mayResolveTypeAlias(node.AsConditionalTypeNode().TrueType) || c.mayResolveTypeAlias(node.AsConditionalTypeNode().FalseType);
			default:
		}
		return false;
	}

	static function createNormalizedTypeReference(c:Checker, target:Type, typeArguments:Array<Type>):Type {
		if ((target.objectFlags & ObjectFlagsTuple) != 0) {
			return c.createNormalizedTupleType(target, typeArguments);
		}
		return c.createTypeReference(target, typeArguments);
	}

	static function createNormalizedTupleTypeEx(c:Checker, target:Type, elementTypes:Array<Type>, objectFlags:ObjectFlags):Type {
		final d = target.AsTupleType();
		if ((d.combinedFlags & ElementFlagsNonRequired) == 0) {
			// No need to normalize when we only have regular required elements
			return c.createTypeReferenceEx(target, elementTypes, objectFlags);
		}
		if ((d.combinedFlags & ElementFlagsVariadic) != 0) {
			for (i in 0...Core.len(elementTypes)) {
				final e = elementTypes[i];
				if (i < Core.len(d.elementInfos) && (d.elementInfos[i].flags & ElementFlagsVariadic) != 0 && (e.flags & (TypeFlagsNever | TypeFlagsUnion)) != 0) {
					// Transform [A, ...(X | Y | Z)] into [A, ...X] | [A, ...Y] | [A, ...Z]
					final checkTypes = Core.MapIndex(elementTypes, function(t:Type, i:Int):Type {
						if (i < Core.len(d.elementInfos) && (d.elementInfos[i].flags & ElementFlagsVariadic) != 0) {
							return t;
						}
						return c.unknownType;
					});
					if (c.checkCrossProductUnion(checkTypes)) {
						return c.mapType(e, function(t:Type):Type {
							return c.createNormalizedTupleTypeEx(target, Core.ReplaceElement(elementTypes, i, t), objectFlags);
						});
					}
				}
			}
		}
		// We have optional, rest, or variadic elements that may need normalizing. Normalization ensures that all variadic
		// elements are generic and that the tuple type has one of the following layouts, disregarding variadic elements:
		// (1) Zero or more required elements, followed by zero or more optional elements, followed by zero or one rest element.
		// (2) Zero or more required elements, followed by a rest element, followed by zero or more required elements.
		// In either layout, zero or more generic variadic elements may be present at any location.
		// Note that the element types may contain an extra 'this' type argument that we want to ignore during normalization
		// and then just append to the normalized element types.
		final n = new TupleNormalizer();
		// PORT: Go `elementTypes[:len(d.elementInfos)]` (a nil slice stays nil).
		final head = elementTypes != null ? elementTypes.slice(0, Core.len(d.elementInfos)) : null;
		if (!n.normalize(c, head, d.elementInfos)) {
			return c.errorType;
		}
		if (Core.len(elementTypes) > Core.len(d.elementInfos)) {
			if (n.types == null) {
				n.types = [];
			}
			n.types.push(elementTypes[Core.len(d.elementInfos)]);
		}
		final tupleTarget = c.getTupleTargetType(n.infos, d.readonly);
		if (tupleTarget == c.emptyGenericType) {
			return c.emptyObjectType;
		} else if (Core.len(n.types) != 0) {
			return c.createTypeReferenceEx(tupleTarget, n.types, objectFlags);
		}
		return tupleTarget;
	}

	static function createNormalizedTupleType(c:Checker, target:Type, elementTypes:Array<Type>):Type {
		return c.createNormalizedTupleTypeEx(target, elementTypes, ObjectFlagsNone);
	}

	static function getElementTypes(c:Checker, t:Type):Array<Type> {
		final typeArguments = c.getTypeArguments(t);
		final arity = c.getTypeReferenceArity(t);
		if (Core.len(typeArguments) == arity) {
			return typeArguments;
		}
		return typeArguments.slice(0, arity);
	}

	static function getTypeReferenceArity(c:Checker, t:Type):Int {
		return Core.len(t.TargetInterfaceType().TypeParameters());
	}

	static function isArrayType(c:Checker, t:Type):Bool {
		return (t.objectFlags & ObjectFlagsReference) != 0 && (t.Target() == c.globalArrayType || t.Target() == c.globalReadonlyArrayType);
	}

	static function isReadonlyArrayType(c:Checker, t:Type):Bool {
		return (t.objectFlags & ObjectFlagsReference) != 0 && t.Target() == c.globalReadonlyArrayType;
	}

	static function isArrayOrTupleType(c:Checker, t:Type):Bool {
		return c.isArrayType(t) || Checker.isTupleType(t);
	}

	static function isMutableArrayOrTuple(c:Checker, t:Type):Bool {
		return c.isArrayType(t) && !c.isReadonlyArrayType(t) || Checker.isTupleType(t) && !t.TargetTupleType().readonly;
	}

	static function getElementTypeOfArrayType(c:Checker, t:Type):Type {
		if (c.isArrayType(t)) {
			return c.getTypeArguments(t)[0];
		}
		return null;
	}

	static function isArrayLikeType(c:Checker, t:Type):Bool {
		// A type is array-like if it is a reference to the global Array or global ReadonlyArray type,
		// or if it is not the undefined or null type and if it is assignable to ReadonlyArray<any>
		return c.isArrayType(t) || (t.flags & TypeFlagsNullable) == 0 && c.isTypeAssignableTo(t, c.anyReadonlyArrayType);
	}

	static function isMutableArrayLikeType(c:Checker, t:Type):Bool {
		// A type is mutable-array-like if it is a reference to the global Array type, or if it is not the
		// any, undefined or null type and if it is assignable to Array<any>
		return c.isMutableArrayOrTuple(t) || (t.flags & (TypeFlagsAny | TypeFlagsNullable)) == 0 && c.isTypeAssignableTo(t, c.anyArrayType);
	}

	static function isEmptyArrayLiteralType(c:Checker, t:Type):Bool {
		final elementType = c.getElementTypeOfArrayType(t);
		return elementType != null && c.isEmptyLiteralType(elementType);
	}

	static function isEmptyLiteralType(c:Checker, t:Type):Bool {
		if (c.strictNullChecks) {
			return t == c.implicitNeverType;
		}
		return t == c.undefinedWideningType;
	}

	static function isTupleLikeType(c:Checker, t:Type):Bool {
		if (Checker.isTupleType(t) || c.getPropertyOfType(t, "0") != null) {
			return true;
		}
		if (c.isArrayLikeType(t)) {
			final lengthType = c.getTypeOfPropertyOfType(t, "length");
			if (lengthType != null) {
				return Checker.everyType(lengthType, t -> (t.flags & TypeFlagsNumberLiteral) != 0);
			}
		}
		return false;
	}

	static function isArrayOrTupleLikeType(c:Checker, t:Type):Bool {
		return c.isArrayLikeType(t) || c.isTupleLikeType(t);
	}

	static function isArrayOrTupleOrIntersection(c:Checker, t:Type):Bool {
		return (t.flags & TypeFlagsIntersection) != 0 && Core.Every(t.Types(), t -> c.isArrayOrTupleType(t));
	}

	static function getTupleElementType(c:Checker, t:Type, index:Int):Type {
		final propType = c.getTypeOfPropertyOfType(t, Std.string(index));
		if (propType != null) {
			return propType;
		}
		if (Checker.everyType(t, Checker.isTupleType)) {
			return c.getTupleElementTypeOutOfStartCount(t, ((index : Float) : Number),
				c.compilerOptions.NoUncheckedIndexedAccess == TSTrue ? c.undefinedType : null);
		}
		return null;
	}

	/**
	 * Get type from reference to type alias. When a type alias is generic, the declared type of the type alias may include
	 * references to the type parameters of the alias. We replace those with the actual type arguments by instantiating the
	 * declared type. Instantiations are cached using the type identities of the type arguments as the key.
	 */
	static function getTypeFromTypeAliasReference(c:Checker, node:Node, symbol:Symbol):Type {
		final typeArguments = node.TypeArguments();
		if ((symbol.CheckFlags & CheckFlagsUnresolved) != 0) {
			final alias = new TypeAlias();
			alias.symbol = symbol;
			alias.typeArguments = Core.Map(typeArguments, n -> c.getTypeFromTypeNode(n));
			final key = Checker.getAliasKey(alias).Key();
			var errorType = c.errorTypes.get(key);
			if (errorType == null) {
				errorType = c.newIntrinsicType(TypeFlagsAny, "error");
				errorType.alias = alias;
				c.errorTypes.set(key, errorType);
			}
			return errorType;
		}
		final t = c.getDeclaredTypeOfSymbol(symbol);
		final typeParameters = c.typeAliasLinks.Get(symbol).typeParameters;
		if (Core.len(typeParameters) != 0) {
			final numTypeArguments = Core.len(typeArguments);
			final minTypeArgumentCount = c.getMinTypeArgumentCount(typeParameters);
			if (numTypeArguments < minTypeArgumentCount || numTypeArguments > typeParameters.length) {
				final message = minTypeArgumentCount == typeParameters.length ? Diagnostics.Generic_type_0_requires_1_type_argument_s : Diagnostics.Generic_type_0_requires_between_1_and_2_type_arguments;
				c.error(node, message, c.symbolToString(symbol), minTypeArgumentCount, typeParameters.length);
				return c.errorType;
			}
			// We refrain from associating a local type alias with an instantiation of a top-level type alias
			// because the local alias may end up being referenced in an inferred return type where it is not
			// accessible--which in turn may lead to a large structural expansion of the type when generating
			// a .d.ts file. See #43622 for an example.
			final aliasSymbol = c.getAliasSymbolForTypeNode(node);
			var newAliasSymbol:Symbol = null;
			if (aliasSymbol != null && (Checker.isLocalTypeAlias(symbol) || !Checker.isLocalTypeAlias(aliasSymbol))) {
				newAliasSymbol = aliasSymbol;
			}
			var aliasTypeArguments:Array<Type> = null;
			if (newAliasSymbol != null) {
				aliasTypeArguments = c.getTypeArgumentsForAliasSymbol(newAliasSymbol);
			} else if (Ast.IsTypeReferenceType(node)) {
				final aliasSymbol = c.resolveTypeReferenceName(node, SymbolFlagsAlias, true /*ignoreErrors*/);
				// refers to an alias import/export/reexport - by making sure we use the target as an aliasSymbol,
				// we ensure the exported symbol is used to refer to the type when it is reserialized later
				if (aliasSymbol != null && aliasSymbol != c.unknownSymbol) {
					final resolved = c.resolveAlias(aliasSymbol);
					if (resolved != null && (resolved.Flags & SymbolFlagsTypeAlias) != 0) {
						newAliasSymbol = resolved;
						aliasTypeArguments = c.getTypeArgumentsFromNode(node);
					}
				}
			}
			var newAlias:TypeAlias = null;
			if (newAliasSymbol != null) {
				newAlias = new TypeAlias();
				newAlias.symbol = newAliasSymbol;
				newAlias.typeArguments = aliasTypeArguments;
			}
			return c.getTypeAliasInstantiation(symbol, c.getTypeArgumentsFromNode(node), newAlias);
		}
		if (c.checkNoTypeArguments(node, symbol)) {
			return t;
		}
		return c.errorType;
	}

	static function getTypeAliasInstantiation(c:Checker, symbol:Symbol, typeArguments:Array<Type>, alias:TypeAlias):Type {
		final t = c.getDeclaredTypeOfSymbol(symbol);
		if (t == c.intrinsicMarkerType) {
			if (Checker.intrinsicTypeKinds.exists(symbol.Name) && Core.len(typeArguments) == 1) {
				final typeKind = Checker.intrinsicTypeKinds.get(symbol.Name);
				switch (typeKind) {
					case IntrinsicTypeKindNoInfer:
						return c.getNoInferType(typeArguments[0]);
					default:
						return c.getStringMappingType(symbol, typeArguments[0]);
				}
			}
		}
		final links = c.typeAliasLinks.Get(symbol);
		final typeParameters = links.typeParameters;
		final key = Checker.getTypeAliasInstantiationKey(typeArguments, alias).Key();
		var instantiation = links.instantiations.get(key);
		if (instantiation == null) {
			final mapper = Checker.newTypeMapper(typeParameters,
				c.fillMissingTypeArguments(typeArguments, typeParameters, c.getMinTypeArgumentCount(typeParameters), Ast.IsInJSFile(symbol.ValueDeclaration)));
			instantiation = c.instantiateTypeWithAlias(t, mapper, alias);
			links.instantiations.set(key, instantiation);
		}
		return instantiation;
	}

	static function getDeclaredTypeOfSymbol(c:Checker, symbol:Symbol):Type {
		var result = c.tryGetDeclaredTypeOfSymbol(symbol);
		if (result == null) {
			result = c.errorType;
		}
		return result;
	}

	static function tryGetDeclaredTypeOfSymbol(c:Checker, symbol:Symbol):Type {
		if ((symbol.Flags & (SymbolFlagsClass | SymbolFlagsInterface)) != 0) {
			return c.getDeclaredTypeOfClassOrInterface(symbol);
		} else if ((symbol.Flags & SymbolFlagsTypeParameter) != 0) {
			return c.getDeclaredTypeOfTypeParameter(symbol);
		} else if ((symbol.Flags & SymbolFlagsTypeAlias) != 0) {
			return c.getDeclaredTypeOfTypeAlias(symbol);
		} else if ((symbol.Flags & SymbolFlagsEnum) != 0) {
			return c.getDeclaredTypeOfEnum(symbol);
		} else if ((symbol.Flags & SymbolFlagsEnumMember) != 0) {
			return c.getDeclaredTypeOfEnumMember(symbol);
		} else if ((symbol.Flags & SymbolFlagsAlias) != 0) {
			return c.getDeclaredTypeOfAlias(symbol);
		}
		return null;
	}

	static function getAliasForTypeNode(c:Checker, node:Node):TypeAlias {
		final symbol = c.getAliasSymbolForTypeNode(node);
		if (symbol != null) {
			final alias = new TypeAlias();
			alias.symbol = symbol;
			alias.typeArguments = c.getTypeArgumentsForAliasSymbol(symbol);
			return alias;
		}
		return null;
	}

	static function getAliasSymbolForTypeNode(c:Checker, node:Node):Symbol {
		var host = node.Parent;
		while (Ast.IsParenthesizedTypeNode(host) || Ast.IsTypeOperatorNode(host) && host.AsTypeOperatorNode().Operator == KindReadonlyKeyword) {
			host = host.Parent;
		}
		if (Checker.isTypeAlias(host)) {
			return c.getSymbolOfDeclaration(host);
		}
		return null;
	}

	static function getTypeArgumentsForAliasSymbol(c:Checker, symbol:Symbol):Array<Type> {
		if (symbol != null) {
			return c.getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(symbol);
		}
		return null;
	}

	static function getOuterTypeParametersOfClassOrInterface(c:Checker, symbol:Symbol):Array<Type> {
		var declaration = symbol.ValueDeclaration;
		if ((symbol.Flags & (SymbolFlagsClass | SymbolFlagsFunction)) == 0) {
			declaration = Core.Find(symbol.Declarations, function(d:Node):Bool {
				if (Ast.IsInterfaceDeclaration(d)) {
					return true;
				}
				if (!Ast.IsVariableDeclaration(d)) {
					return false;
				}
				final initializer = d.Initializer();
				return initializer != null && Ast.IsFunctionExpressionOrArrowFunction(initializer);
			});
		}
		Debug.Assert(declaration != null, "Class was missing valueDeclaration -OR- non-class had no interface declarations");
		return c.getOuterTypeParameters(declaration, false /*includeThisTypes*/);
	}

	// Return the outer type parameters of a node or undefined if the node has no outer type parameters.
	static function getOuterTypeParameters(c:Checker, node:Node, includeThisTypes:Bool):Array<Type> {
		while (true) {
			node = node.Parent;
			if (node == null) {
				return null;
			}
			final kind = node.Kind;
			switch (kind) {
				case KindClassDeclaration | KindClassExpression | KindInterfaceDeclaration | KindCallSignature | KindConstructSignature
					| KindMethodSignature | KindFunctionType | KindConstructorType | KindFunctionDeclaration | KindMethodDeclaration
					| KindFunctionExpression | KindArrowFunction | KindTypeAliasDeclaration | KindJSTypeAliasDeclaration | KindMappedType
					| KindConditionalType:
					final outerTypeParameters = c.getOuterTypeParameters(node, includeThisTypes);
					if ((kind == KindFunctionExpression || kind == KindArrowFunction || Ast.IsObjectLiteralMethod(node)) && c.isContextSensitive(node)) {
						final signature = Core.FirstOrNil(c.getSignaturesOfType(c.getTypeOfSymbol(c.getSymbolOfDeclaration(node)), SignatureKindCall));
						if (signature != null && Core.len(signature.typeParameters) != 0) {
							return appendAll(outerTypeParameters, signature.typeParameters);
						}
					}
					if (kind == KindMappedType) {
						return appendAll(outerTypeParameters,
							[c.getDeclaredTypeOfTypeParameter(c.getSymbolOfDeclaration(node.AsMappedTypeNode().TypeParameter))]);
					}
					if (kind == KindConditionalType) {
						return appendAll(outerTypeParameters, c.getInferTypeParameters(node));
					}
					final outerAndOwnTypeParameters = c.appendTypeParameters(outerTypeParameters, node.TypeParameters());
					var thisType:Type = null;
					if (includeThisTypes && (kind == KindClassDeclaration || kind == KindClassExpression || kind == KindInterfaceDeclaration)) {
						thisType = c.getDeclaredTypeOfClassOrInterface(c.getSymbolOfDeclaration(node)).AsInterfaceType().thisType;
					}
					if (thisType != null) {
						return appendAll(outerAndOwnTypeParameters, [thisType]);
					}
					return outerAndOwnTypeParameters;
				default:
			}
		}
	}

	static function getInferTypeParameters(c:Checker, node:Node):Array<Type> {
		var result:Array<Type> = null;
		final locals = node.Locals();
		if (locals != null) {
			for (symbol in locals) {
				if ((symbol.Flags & SymbolFlagsTypeParameter) != 0) {
					if (result == null) {
						result = [];
					}
					result.push(c.getDeclaredTypeOfSymbol(symbol));
				}
			}
		}
		return result;
	}

	// The local type parameters are the combined set of type parameters from all declarations of the class,
	// interface, or type alias.
	static function getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(c:Checker, symbol:Symbol):Array<Type> {
		return c.appendLocalTypeParametersOfClassOrInterfaceOrTypeAlias(null, symbol);
	}

	static function appendLocalTypeParametersOfClassOrInterfaceOrTypeAlias(c:Checker, types:Array<Type>, symbol:Symbol):Array<Type> {
		for (node in rangeOf(symbol.Declarations)) {
			if (Ast.NodeKindIs(node, KindInterfaceDeclaration, KindClassDeclaration, KindClassExpression) || Checker.isTypeAlias(node)) {
				types = c.appendTypeParameters(types, node.TypeParameters());
			}
		}
		return types;
	}

	// Appends the type parameters given by a list of declarations to a set of type parameters and returns the resulting set.
	// The function allocates a new array if the input type parameter set is undefined, but otherwise it modifies the set
	// in-place and returns the same array.
	static function appendTypeParameters(c:Checker, typeParameters:Array<Type>, declarations:Array<Node>):Array<Type> {
		for (declaration in rangeOf(declarations)) {
			typeParameters = Core.AppendIfUnique(typeParameters, c.getDeclaredTypeOfTypeParameter(c.getSymbolOfDeclaration(declaration)));
		}
		return typeParameters;
	}

	static function getDeclaredTypeOfTypeParameter(c:Checker, symbol:Symbol):Type {
		final links = c.declaredTypeLinks.Get(symbol);
		if (links.declaredType == null) {
			links.declaredType = c.newTypeParameter(symbol);
		}
		return links.declaredType;
	}

	static function getDeclaredTypeOfTypeAlias(c:Checker, symbol:Symbol):Type {
		final links = c.typeAliasLinks.Get(symbol);
		if (links.declaredType == null) {
			// Note that we use the links object as the target here because the symbol object is used as the unique
			// identity for resolution of the 'type' property in SymbolLinks.
			if (!c.pushTypeResolution(entity(symbol), TypeSystemPropertyNameDeclaredType)) {
				return c.errorType;
			}
			final declaration = Core.Find(symbol.Declarations, Ast.IsTypeOrJSTypeAliasDeclaration);
			final typeNode = declaration.Type();
			var t = c.getTypeFromTypeNode(typeNode);
			if (c.popTypeResolution()) {
				final typeParameters = c.getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(symbol);
				if (Core.len(typeParameters) != 0) {
					// Initialize the instantiation cache for generic type aliases. The declared type corresponds to
					// an instantiation of the type alias with the type parameters supplied as type arguments.
					links.typeParameters = typeParameters;
					links.instantiations = new StringMap<Type>();
					links.instantiations.set(Checker.getTypeListKey(typeParameters).Key(), t);
				}
				if (t == c.intrinsicMarkerType && symbol.Name == "BuiltinIteratorReturn") {
					t = c.getBuiltinIteratorReturnType();
				}
			} else {
				var errorNode = declaration.Name();
				if (errorNode == null) {
					errorNode = declaration;
				}
				c.error(errorNode, Diagnostics.Type_alias_0_circularly_references_itself, c.symbolToString(symbol));
				t = c.errorType;
			}
			if (links.declaredType == null) {
				links.declaredType = t;
			}
		}
		return links.declaredType;
	}

	static function getDeclaredTypeOfEnum(c:Checker, symbol:Symbol):Type {
		final links = c.declaredTypeLinks.Get(symbol);
		if (!(links.declaredType != null)) {
			var memberTypeList:Array<Type> = null;
			for (declaration in rangeOf(symbol.Declarations)) {
				if (declaration.Kind == KindEnumDeclaration) {
					for (member in rangeOf(declaration.Members())) {
						if (c.hasBindableName(member)) {
							final memberSymbol = c.getSymbolOfDeclaration(member);
							final value = c.getEnumMemberValue(member).Value;
							var memberType:Type;
							if (value != null) {
								memberType = c.getEnumLiteralType(value, symbol, memberSymbol);
							} else {
								memberType = c.createComputedEnumType(memberSymbol);
							}
							c.declaredTypeLinks.Get(memberSymbol).declaredType = c.getFreshTypeOfLiteralType(memberType);
							if (memberTypeList == null) {
								memberTypeList = [];
							}
							memberTypeList.push(memberType);
						}
					}
				}
			}
			var enumType:Type;
			if (Core.len(memberTypeList) != 0) {
				final alias = new TypeAlias();
				alias.symbol = symbol;
				enumType = c.getUnionTypeEx(memberTypeList, UnionReductionLiteral, alias, null /*origin*/);
			} else {
				enumType = c.createComputedEnumType(symbol);
			}
			if ((enumType.flags & TypeFlagsUnion) != 0) {
				enumType.flags |= TypeFlagsEnumLiteral;
				enumType.symbol = symbol;
			}
			links.declaredType = enumType;
		}
		return links.declaredType;
	}

	static function getEnumMemberValue(c:Checker, node:Node):Result {
		c.computeEnumMemberValues(node.Parent);
		// PORT: Go zero struct evaluator.Result{} for a member that was never computed (links field starts nil).
		final value = c.enumMemberLinks.Get(node).value;
		return value != null ? value : new Result();
	}

	static function createComputedEnumType(c:Checker, symbol:Symbol):Type {
		final regularType = c.newLiteralType(TypeFlagsEnum, null, null);
		regularType.symbol = symbol;
		final freshType = c.newLiteralType(TypeFlagsEnum, null, regularType);
		freshType.symbol = symbol;
		regularType.AsLiteralType().freshType = freshType;
		freshType.AsLiteralType().freshType = freshType;
		return regularType;
	}

	static function getDeclaredTypeOfEnumMember(c:Checker, symbol:Symbol):Type {
		final links = c.declaredTypeLinks.Get(symbol);
		if (!(links.declaredType != null)) {
			final enumType = c.getDeclaredTypeOfEnum(c.getParentOfSymbol(symbol));
			if (links.declaredType == null) {
				links.declaredType = enumType;
			}
		}
		return links.declaredType;
	}

	static function computeEnumMemberValues(c:Checker, node:Node):Void {
		final nodeLinks = c.nodeLinks.Get(node);
		if (!((nodeLinks.flags & NodeCheckFlagsEnumValuesComputed) != 0)) {
			nodeLinks.flags |= NodeCheckFlagsEnumValuesComputed;
			// PORT: pointer — Go `*jsnum.Number` (nil = no auto value) → Null<Number>.
			var autoValue:Null<Number> = 0.0;
			var previous:Node = null;
			for (member in rangeOf(node.Members())) {
				final result = c.computeEnumMemberValue(member, autoValue, previous);
				c.enumMemberLinks.Get(member).value = result;
				// PORT: Go `result.Value.(jsnum.Number)`; a jsnum.Number in `any` is a raw Float (PORTING.md §3).
				if (Std.isOfType(result.Value, Float)) {
					final value:Number = (result.Value : Float);
					final nextValue:Number = value + 1;
					autoValue = nextValue;
				} else {
					autoValue = null;
				}
				previous = member;
			}
		}
	}

	static function computeEnumMemberValue(c:Checker, member:Node, autoValue:Null<Number>, previous:Node):Result {
		if (Ast.IsComputedNonLiteralName(member.Name())) {
			c.error(member.Name(), Diagnostics.Computed_property_names_are_not_allowed_in_enums);
		} else if (Ast.IsBigIntLiteral(member.Name())) {
			c.error(member.Name(), Diagnostics.An_enum_member_cannot_have_a_numeric_name);
		} else {
			final text = Ast.GetTextOfPropertyName(member.Name());
			if (Checker.isNumericLiteralName(text) && !Ast.IsInfinityOrNaNString(text)) {
				c.error(member.Name(), Diagnostics.An_enum_member_cannot_have_a_numeric_name);
			}
		}
		if (member.Initializer() != null) {
			return c.computeConstantEnumMemberValue(member);
		}
		// In ambient non-const numeric enum declarations, enum members without initializers are
		// considered computed members (as opposed to having auto-incremented values).
		if ((member.Parent.Flags & NodeFlagsAmbient) != 0 && !Ast.IsEnumConst(member.Parent)) {
			return Evaluator.NewResult(null, false, false, false);
		}
		// If the member declaration specifies no value, the member is considered a constant enum member.
		// If the member is the first member in the enum declaration, it is assigned the value zero.
		// Otherwise, it is assigned the value of the immediately preceding member plus one, and an error
		// occurs if the immediately preceding member is not a constant enum member.
		if (autoValue == null) {
			c.error(member.Name(), Diagnostics.Enum_member_must_have_initializer);
			return Evaluator.NewResult(null, false, false, false);
		}
		if (c.compilerOptions.GetIsolatedModules() && previous != null && previous.Initializer() != null) {
			final prevValue = c.getEnumMemberValue(previous);
			final prevIsNum = Std.isOfType(prevValue.Value, Float);
			if (!prevIsNum || prevValue.ResolvedOtherFiles) {
				c.error(member.Name(), Diagnostics.Enum_member_following_a_non_literal_numeric_member_must_have_an_initializer_when_isolatedModules_is_enabled);
			}
		}
		// PORT: the jsnum.Number goes into `any` as a raw Float (PORTING.md §3).
		final av:Number = autoValue;
		return Evaluator.NewResult((av : Float), false, false, false);
	}

	static function computeConstantEnumMemberValue(c:Checker, member:Node):Result {
		final isConstEnum = Ast.IsEnumConst(member.Parent);
		final initializer = member.Initializer();
		final result = c.evaluate(initializer, member);
		if (result.Value != null) {
			if (isConstEnum) {
				// PORT: Go `result.Value.(jsnum.Number)`; a jsnum.Number in `any` is a raw Float (PORTING.md §3).
				if (Std.isOfType(result.Value, Float)) {
					final numValue:Number = (result.Value : Float);
					if (numValue.IsInf() || numValue.IsNaN()) {
						c.error(initializer, numValue.IsNaN() ? Diagnostics.X_const_enum_member_initializer_was_evaluated_to_disallowed_value_NaN : Diagnostics.X_const_enum_member_initializer_was_evaluated_to_a_non_finite_value);
					}
				}
			}
			if (c.compilerOptions.GetIsolatedModules()) {
				if (Std.isOfType(result.Value, std.String) && !result.IsSyntacticallyString) {
					final memberName = member.Parent.Name().Text() + "." + member.Name().Text();
					c.error(initializer, Diagnostics.X_0_has_a_string_type_but_must_have_syntactically_recognizable_string_syntax_when_isolatedModules_is_enabled, memberName);
				}
			}
		} else if (isConstEnum) {
			c.error(initializer, Diagnostics.X_const_enum_member_initializers_must_be_constant_expressions);
		} else if ((member.Parent.Flags & NodeFlagsAmbient) != 0) {
			c.error(initializer, Diagnostics.In_ambient_enum_declarations_member_initializer_must_be_constant_expression);
		} else {
			c.checkTypeAssignableTo(c.checkExpression(initializer), c.numberType, initializer, Diagnostics.Type_0_is_not_assignable_to_type_1_as_required_for_computed_enum_member_values);
		}
		return result;
	}

	// --- private helpers (P6) ---

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
		for (_ in table) {
			n++;
		}
		return n;
	}

	// PORT: Go `maps.Clone` of an ast.SymbolTable: nil stays nil.
	static function cloneSymbolTable(m:SymbolTable):SymbolTable {
		return m != null ? m.copy() : null;
	}

	// PORT: Go `slices.Collect(maps.Values(table))` on a possibly-nil ast.SymbolTable (nil for an empty table).
	static function symbolTableValuesArray(table:SymbolTable):Array<Symbol> {
		var result:Array<Symbol> = null;
		if (table != null) {
			for (s in table) {
				if (result == null) {
					result = [];
				}
				result.push(s);
			}
		}
		return result;
	}

	// PORT: Go `append(s, x)` on a possibly-nil slice that the caller owns (nil becomes a new array).
	static function appendOne<T>(s:Null<Array<T>>, x:T):Array<T> {
		final result = s != null ? s : [];
		result.push(x);
		return result;
	}

	// PORT: Go TypeSystemEntity is `any`; the skeleton's empty interface is not declared by Symbol/Type/Signature,
	// so the value is passed through an unchecked cast (as in CheckerPart5.hx / Relater.hx).
	static inline function entity(o:Dynamic):TypeSystemEntity {
		return cast o;
	}

	// PORT: Go `append(s1, s2...)`: s1 unchanged when s2 is empty (nil stays nil), otherwise a new array.
	static function appendAll<T>(s1:Null<Array<T>>, s2:Null<Array<T>>):Null<Array<T>> {
		if (s2 == null || s2.length == 0) {
			return s1;
		}
		return s1 != null ? s1.concat(s2) : s2.copy();
	}

	// PORT: Go `append(a, b...)` for []*Type where `a` is not shared: nil + empty stays nil.
	static function appendTypes(a:Array<Type>, b:Array<Type>):Array<Type> {
		if (Core.len(b) == 0) {
			return a;
		}
		return a == null ? b.copy() : a.concat(b);
	}

	// PORT: Go untyped consts (types.go) that are Int statics on Checker; typed local copies, like CheckerPart4/Relater.
	static inline final ObjectFlagsContainsSpread:ObjectFlags = 1 << 22;
	static inline final ObjectFlagsContainsIntersections:ObjectFlags = 1 << 25;
	static inline final ObjectFlagsIsNeverIntersectionComputed:ObjectFlags = 1 << 25;
	static inline final ObjectFlagsIsNeverIntersection:ObjectFlags = 1 << 26;

	// PORT: Go `slices.Clone` of a []TupleElementInfo (value elements): each element is copied.
	static function cloneElementInfos(infos:Array<TupleElementInfo>):Array<TupleElementInfo> {
		if (infos == null) {
			return null;
		}
		final result:Array<TupleElementInfo> = [];
		for (info in infos) {
			final copy = new TupleElementInfo();
			copy.flags = info.flags;
			copy.labeledDeclaration = info.labeledDeclaration;
			result.push(copy);
		}
		return result;
	}

	// PORT: Go method expressions `(*Checker).instantiateX` passed to instantiateList; created once (PORTING.md §7a).
	static final instantiateTypeFn:(c:Checker, value:Type, m:TypeMapper) -> Type = (c:Checker, value:Type, m:TypeMapper) -> instantiateType(c, value, m);
	static final instantiateSymbolFn:(c:Checker, value:Symbol, m:TypeMapper) -> Symbol = (c:Checker, value:Symbol, m:TypeMapper) -> instantiateSymbol(c, value, m);
	static final instantiateSignatureFn:(c:Checker, value:Signature, m:TypeMapper) -> Signature = (c:Checker, value:Signature, m:TypeMapper) -> instantiateSignature(c, value, m);
	static final instantiateIndexInfoFn:(c:Checker, value:IndexInfo, m:TypeMapper) -> IndexInfo = (c:Checker, value:IndexInfo, m:TypeMapper) -> instantiateIndexInfo(c, value, m);
}
