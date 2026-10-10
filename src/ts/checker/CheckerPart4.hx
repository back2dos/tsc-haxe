package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/checker.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Part of checker.go, Go lines 11982-15980 (3999 lines): the Checker methods of this range as static extension
// (receiver first, PORTING.md §2; `using ts.checker.CheckerPart4` in import.hx). Inside class Checker call them as `this.m(...)`.
@:allow(ts.checker)
class CheckerPart4 {

	static function getContextualThisParameterType(c:Checker, fn:Node):Type {
		if (Ast.IsArrowFunction(fn)) {
			return null;
		}
		if (c.isContextSensitiveFunctionOrObjectLiteralMethod(fn)) {
			final contextualSignature = c.getContextualSignature(fn);
			if (contextualSignature != null) {
				final thisParameter = contextualSignature.thisParameter;
				if (thisParameter != null) {
					return c.getTypeOfSymbol(thisParameter);
				}
			}
		}
		final inJs = Ast.IsInJSFile(fn);
		if (c.noImplicitThis || inJs) {
			final containingLiteral = Checker.getContainingObjectLiteral(fn);
			if (containingLiteral != null) {
				// We have an object literal method. Check if the containing object literal has a contextual type
				// that includes a ThisType<T>. If so, T is the contextual type for 'this'. We continue looking in
				// any directly enclosing object literals.
				final contextualType = c.getApparentTypeOfContextualType(containingLiteral, ContextFlagsNone);
				var thisType = c.getThisTypeOfObjectLiteralFromContextualType(containingLiteral, contextualType);
				if (thisType != null) {
					return c.instantiateType(thisType, c.getMapperFromContext(c.getInferenceContext(containingLiteral)));
				}
				// There was no contextual ThisType<T> for the containing object literal, so the contextual type
				// for 'this' is the non-null form of the contextual type for the containing object literal or
				// the type of the object literal itself.
				if (contextualType != null) {
					thisType = c.GetNonNullableType(contextualType);
				} else {
					thisType = c.checkExpressionCached(containingLiteral);
				}
				return c.getWidenedType(thisType);
			}
			// In an assignment of the form 'obj.xxx = function(...)' or 'obj[xxx] = function(...)', the
			// contextual type for 'this' is 'obj'.
			final parent = Ast.WalkUpParenthesizedExpressions(fn.Parent);
			if (Ast.IsAssignmentExpression(parent, false)) {
				final target = parent.AsBinaryExpression().Left;
				if (Ast.IsAccessExpression(target)) {
					final expression = target.Expression();
					// Don't contextually type `this` as `exports` in `exports.Point = function(x, y) { this.x = x; this.y = y; }`
					if (inJs && Ast.IsIdentifier(expression)) {
						final sourceFile = Ast.GetSourceFileOfNode(parent);
						if (sourceFile.CommonJSModuleIndicator != null && (c.getResolvedSymbol(expression).Flags & SymbolFlagsModuleExports) != 0) {
							return null;
						}
					}
					return c.getWidenedType(c.checkExpressionCached(expression));
				}
			}
		}
		return null;
	}

	static function checkThisExpression(c:Checker, node:Node):Type {
		// Stop at the first arrow function so that we can
		// tell whether 'this' needs to be captured.
		var container = Ast.GetThisContainer(node, true /*includeArrowFunctions*/, true /*includeClassComputedPropertyName*/);
		var capturedByArrowFunction = false;
		var thisInComputedPropertyName = false;
		if (Ast.IsConstructorDeclaration(container)) {
			c.checkThisBeforeSuper(node, container, Diagnostics.X_super_must_be_called_before_accessing_this_in_the_constructor_of_a_derived_class);
		}
		while (true) {
			// Now skip arrow functions to get the "real" owner of 'this'.
			if (Ast.IsArrowFunction(container)) {
				container = Ast.GetThisContainer(container, false /*includeArrowFunctions*/, !thisInComputedPropertyName);
				capturedByArrowFunction = true;
			}
			if (Ast.IsComputedPropertyName(container)) {
				container = Ast.GetThisContainer(container, !capturedByArrowFunction, false /*includeClassComputedPropertyName*/);
				thisInComputedPropertyName = true;
				continue;
			}
			break;
		}
		c.checkThisInStaticClassFieldInitializerInDecoratedClass(node, container);
		if (thisInComputedPropertyName) {
			c.error(node, Diagnostics.X_this_cannot_be_referenced_in_a_computed_property_name);
		} else {
			switch (container.Kind) {
				case KindModuleDeclaration:
					c.error(node, Diagnostics.X_this_cannot_be_referenced_in_a_module_or_namespace_body);
					// do not return here so in case if lexical this is captured - it will be reflected in flags on NodeLinks
				case KindEnumDeclaration:
					c.error(node, Diagnostics.X_this_cannot_be_referenced_in_current_location);
					// do not return here so in case if lexical this is captured - it will be reflected in flags on NodeLinks
				default:
			}
		}
		final t = c.tryGetThisTypeAtEx(node, true /*includeGlobalThis*/, container);
		if (c.noImplicitThis) {
			final globalThisType = c.getTypeOfSymbol(c.globalThisSymbol);
			if (t == globalThisType && capturedByArrowFunction) {
				c.error(node, Diagnostics.The_containing_arrow_function_captures_the_global_value_of_this);
			} else if (t == null) {
				// With noImplicitThis, functions may not reference 'this' if it has type 'any'
				final diag = c.error(node, Diagnostics.X_this_implicitly_has_type_any_because_it_does_not_have_a_type_annotation);
				if (!Ast.IsSourceFile(container)) {
					final outsideThis = c.tryGetThisTypeAt(container);
					if (outsideThis != null && outsideThis != globalThisType) {
						diag.AddRelatedInfo(Checker.createDiagnosticForNode(container, Diagnostics.An_outer_value_of_this_is_shadowed_by_this_container));
					}
				}
			}
		}
		if (t == null) {
			return c.anyType;
		}
		return t;
	}

	static function tryGetThisTypeAt(c:Checker, node:Node):Type {
		return c.tryGetThisTypeAtEx(node, true /*includeGlobalThis*/, null /*container*/);
	}

	public static function TryGetThisTypeAtEx(c:Checker, node:Node, includeGlobalThis:Bool, container:Node):Type {
		final reparsed = Ast.GetReparsedNodeForNode(node);
		if ((reparsed.Flags & NodeFlagsJSDoc) != 0 && (reparsed.Flags & NodeFlagsReparsed) == 0) {
			return null; // Binder doesn't process non-reparsed JSDoc nodes
		}
		return c.tryGetThisTypeAtEx(reparsed, includeGlobalThis, Ast.GetReparsedNodeForNode(container));
	}

	static function tryGetThisTypeAtEx(c:Checker, node:Node, includeGlobalThis:Bool, container:Node):Type {
		if (container == null) {
			container = c.getThisContainer(node, false /*includeArrowFunctions*/, false /*includeClassComputedPropertyName*/);
		}
		if (Ast.IsFunctionLike(container) && (!c.isInParameterInitializerBeforeContainingFunction(node) || Ast.GetThisParameter(container) != null)) {
			var sig = c.getSignatureOfFullSignatureType(container);
			if (sig == null) {
				sig = c.getSignatureFromDeclaration(container);
			}
			var thisType = c.getThisTypeOfSignature(sig);
			// Note: a parameter initializer should refer to class-this unless function-this is explicitly annotated.
			// If this is a function in a JS file, it might be a class method.
			if (thisType == null) {
				thisType = c.getContextualThisParameterType(container);
			}
			if (thisType != null) {
				return c.getFlowTypeOfReference(node, thisType);
			}
		}
		if (container.Parent != null && Ast.IsClassLike(container.Parent)) {
			final symbol = c.getSymbolOfDeclaration(container.Parent);
			var t:Type;
			if (Ast.IsStatic(container)) {
				t = c.getTypeOfSymbol(symbol);
			} else {
				t = c.getDeclaredTypeOfSymbol(symbol).AsInterfaceType().thisType;
			}
			return c.getFlowTypeOfReference(node, t);
		}
		if (Ast.IsSourceFile(container)) {
			// look up in the source file's locals or exports
			if (container.AsSourceFile().ExternalModuleIndicator != null) {
				// TODO: Maybe issue a better error than 'object is possibly undefined'
				return c.undefinedType;
			}
			if (includeGlobalThis) {
				return c.getTypeOfSymbol(c.globalThisSymbol);
			}
		}
		return null;
	}

	static function getThisContainer(c:Checker, node:Node, includeArrowFunctions:Bool, includeClassComputedPropertyName:Bool):Node {
		while (true) {
			node = node.Parent;
			if (node == null) {
				// If we never pass in a SourceFile, this should be unreachable, since we'll stop when we reach that.
				throw "No parent in getThisContainer";
			}
			switch (node.Kind) {
				case KindComputedPropertyName:
					// If the grandparent node is an object literal (as opposed to a class),
					// then the computed property is not a 'this' container.
					// A computed property name in a class needs to be a this container
					// so that we can error on it.
					if (includeClassComputedPropertyName && Ast.IsClassLike(node.Parent.Parent)) {
						return node;
					}
					// If this is a computed property, then the parent should not
					// make it a this container. The parent might be a property
					// in an object literal, like a method or accessor. But in order for
					// such a parent to be a this container, the reference must be in
					// the *body* of the container.
					node = node.Parent.Parent;
				case KindDecorator:
					// Decorators are always applied outside of the body of a class or method.
					if (node.Parent.Kind == KindParameter && Ast.IsClassElement(node.Parent.Parent)) {
						// If the decorator's parent is a Parameter, we resolve the this container from
						// the grandparent class declaration.
						node = node.Parent.Parent;
					} else if (Ast.IsClassElement(node.Parent)) {
						// If the decorator's parent is a class element, we resolve the 'this' container
						// from the parent class declaration.
						node = node.Parent;
					}
				case KindArrowFunction:
					// PORT: Go `continue` when !includeArrowFunctions, else `fallthrough` into the container case.
					if (includeArrowFunctions) {
						return node;
					}
				case KindFunctionDeclaration | KindFunctionExpression | KindModuleDeclaration | KindClassStaticBlockDeclaration
					| KindPropertyDeclaration | KindPropertySignature | KindMethodDeclaration | KindMethodSignature | KindConstructor
					| KindGetAccessor | KindSetAccessor | KindCallSignature | KindConstructSignature | KindIndexSignature
					| KindEnumDeclaration | KindSourceFile:
					return node;
				default:
			}
		}
	}

	static function isInParameterInitializerBeforeContainingFunction(c:Checker, node:Node):Bool {
		var inBindingInitializer = false;
		while (node.Parent != null && !Ast.IsFunctionLike(node.Parent)) {
			if (Ast.IsParameterDeclaration(node.Parent)) {
				if (inBindingInitializer || node.Parent.Initializer() == node) {
					return true;
				}
			}

			if (Ast.IsBindingElement(node.Parent) && node.Parent.Initializer() == node) {
				inBindingInitializer = true;
			}

			node = node.Parent;
		}

		return false;
	}

	static function checkThisInStaticClassFieldInitializerInDecoratedClass(c:Checker, thisExpression:Node, container:Node):Void {
		if (Ast.IsPropertyDeclaration(container) && Ast.HasStaticModifier(container) && c.legacyDecorators) {
			final initializer = container.Initializer();
			if (initializer != null && initializer.Loc.ContainsInclusive(thisExpression.Pos()) && Ast.HasDecorators(container.Parent)) {
				c.error(thisExpression, Diagnostics.Cannot_use_this_in_a_static_property_initializer_of_a_decorated_class);
			}
		}
	}

	static function checkThisBeforeSuper(c:Checker, node:Node, container:Node, diagnosticMessage:Message):Void {
		final containingClassDecl = container.Parent;
		final baseTypeNode = Ast.GetExtendsHeritageClauseElement(containingClassDecl);
		// If a containing class does not have extends clause or the class extends null
		// skip checking whether super statement is called before "this" accessing.
		if (baseTypeNode != null && !c.classDeclarationExtendsNull(containingClassDecl)) {
			if (node.FlowNodeData() != null && !c.isPostSuperFlowNode(node.FlowNodeData().FlowNode, false /*noCacheCheck*/)) {
				c.error(node, diagnosticMessage);
			}
		}
	}

	/**
	 * Check if the given class-declaration extends null then return true.
	 * Otherwise, return false
	 * @param classDecl a class declaration to check if it extends null
	 */
	static function classDeclarationExtendsNull(c:Checker, classDecl:Node):Bool {
		final classSymbol = c.getSymbolOfDeclaration(classDecl);
		final classInstanceType = c.getDeclaredTypeOfSymbol(classSymbol);
		final baseConstructorType = c.getBaseConstructorTypeOfClass(classInstanceType);
		return baseConstructorType == c.nullWideningType;
	}

	static function checkAssertion(c:Checker, node:Node, checkMode:CheckMode):Type {
		if (node.Kind == KindTypeAssertionExpression) {
			if (c.shouldCheckErasableSyntax(node)) {
				c.addDiagnostic(Ast.NewDiagnostic(Ast.GetSourceFileOfNode(node),
					Core.NewTextRange(Scanner.SkipTrivia(Ast.GetSourceFileOfNode(node).Text(), node.Pos()), node.Expression().Pos()),
					Diagnostics.This_syntax_is_not_allowed_when_erasableSyntaxOnly_is_enabled));
			}
		}
		final typeNode = node.Type();
		final exprType = c.checkExpressionEx(node.Expression(), checkMode);
		if (Checker.isConstTypeReference(typeNode)) {
			if (!c.isValidConstAssertionArgument(node.Expression())) {
				c.error(node.Expression(), Diagnostics.A_const_assertion_can_only_be_applied_to_references_to_enum_members_or_string_number_boolean_array_or_object_literals);
			}
			return c.getRegularTypeOfLiteralType(exprType);
		}
		final links = c.assertionLinks.Get(node);
		links.exprType = exprType;
		c.checkSourceElement(typeNode);
		c.checkNodeDeferred(node);
		return c.getTypeFromTypeNode(typeNode);
	}

	static function checkAssertionDeferred(c:Checker, node:Node):Void {
		final typeNode = node.Type();
		final exprType = c.getRegularTypeOfObjectLiteral(c.getBaseTypeOfLiteralType(c.assertionLinks.Get(node).exprType));
		final targetType = c.getTypeFromTypeNode(typeNode);
		if (!c.isErrorType(targetType)) {
			final widenedType = c.getWidenedType(exprType);
			if (!c.isTypeComparableTo(targetType, widenedType)) {
				var errNode = node;
				if ((typeNode.Flags & NodeFlagsReparsed) != 0) {
					errNode = typeNode;
				}
				c.checkTypeComparableTo(exprType, targetType, errNode,
					Diagnostics.Conversion_of_type_0_to_type_1_may_be_a_mistake_because_neither_type_sufficiently_overlaps_with_the_other_If_this_was_intentional_convert_the_expression_to_unknown_first);
			}
		}
	}

	static function checkBinaryExpression(c:Checker, node:Node, checkMode:CheckMode):Type {
		final binary = node.AsBinaryExpression();
		return c.checkBinaryLikeExpression(binary.Left, binary.OperatorToken, binary.Right, checkMode, node);
	}

	static function checkBinaryLikeExpression(c:Checker, left:Node, operatorToken:Node, right:Node, checkMode:CheckMode, errorNode:Node):Type {
		final operator_ = operatorToken.Kind;
		if (operator_ == KindEqualsToken && (left.Kind == KindObjectLiteralExpression || left.Kind == KindArrayLiteralExpression)) {
			return c.checkDestructuringAssignment(left, c.checkExpressionEx(right, checkMode), checkMode, right.Kind == KindThisKeyword);
		}
		var leftType = c.checkExpressionEx(left, checkMode);
		var rightType = c.checkExpressionEx(right, checkMode);
		if (Ast.IsLogicalOrCoalescingBinaryOperator(operator_)) {
			var parent = left.Parent.Parent;
			while (Ast.IsParenthesizedExpression(parent) || Ast.IsLogicalOrCoalescingBinaryExpression(parent)) {
				parent = parent.Parent;
			}
			if (operator_ == KindAmpersandAmpersandToken || Ast.IsIfStatement(parent)) {
				var body:Node = null;
				if (Ast.IsIfStatement(parent)) {
					body = parent.AsIfStatement().ThenStatement;
				}
				c.checkTestingKnownTruthyCallableOrAwaitableOrEnumMemberType(left, leftType, body);
			}
			if (Ast.IsLogicalBinaryOperator(operator_)) {
				c.checkTruthinessOfType(leftType, left);
			}
		}
		switch (operator_) {
			case KindAsteriskToken | KindAsteriskAsteriskToken | KindAsteriskEqualsToken | KindAsteriskAsteriskEqualsToken
				| KindSlashToken | KindSlashEqualsToken | KindPercentToken | KindPercentEqualsToken | KindMinusToken
				| KindMinusEqualsToken | KindLessThanLessThanToken | KindLessThanLessThanEqualsToken | KindGreaterThanGreaterThanToken
				| KindGreaterThanGreaterThanEqualsToken | KindGreaterThanGreaterThanGreaterThanToken | KindGreaterThanGreaterThanGreaterThanEqualsToken
				| KindBarToken | KindBarEqualsToken | KindCaretToken | KindCaretEqualsToken | KindAmpersandToken | KindAmpersandEqualsToken:
				if (leftType == c.silentNeverType || rightType == c.silentNeverType) {
					return c.silentNeverType;
				}
				leftType = c.checkNonNullType(leftType, left);
				rightType = c.checkNonNullType(rightType, right);
				// if a user tries to apply a bitwise operator to 2 boolean operands
				// try and return them a helpful suggestion
				if ((leftType.flags & TypeFlagsBooleanLike) != 0 && (rightType.flags & TypeFlagsBooleanLike) != 0) {
					final suggestedOperator = c.getSuggestedBooleanOperator(operator_);
					if (suggestedOperator != KindUnknown) {
						c.error(operatorToken, Diagnostics.The_0_operator_is_not_allowed_for_boolean_types_Consider_using_1_instead, Scanner.TokenToString(operatorToken.Kind),
							Scanner.TokenToString(suggestedOperator));
						return c.numberType;
					}
				}
				// otherwise just check each operand separately and report errors as normal
				final leftOk = c.checkArithmeticOperandType(left, leftType,
					Diagnostics.The_left_hand_side_of_an_arithmetic_operation_must_be_of_type_any_number_bigint_or_an_enum_type, true /*isAwaitValid*/);
				final rightOk = c.checkArithmeticOperandType(right, rightType,
					Diagnostics.The_right_hand_side_of_an_arithmetic_operation_must_be_of_type_any_number_bigint_or_an_enum_type, true /*isAwaitValid*/);
				var resultType:Type = null;
				// If both are any or unknown, allow operation; assume it will resolve to number
				if (c.isTypeAssignableToKind(leftType, TypeFlagsAnyOrUnknown) && c.isTypeAssignableToKind(rightType, TypeFlagsAnyOrUnknown)
					|| !c.maybeTypeOfKind(leftType, TypeFlagsBigIntLike) && !c.maybeTypeOfKind(rightType, TypeFlagsBigIntLike)) {
					resultType = c.numberType;
				} else if (c.bothAreBigIntLike(leftType, rightType)) {
					switch (operator_) {
						case KindGreaterThanGreaterThanGreaterThanToken | KindGreaterThanGreaterThanGreaterThanEqualsToken:
							c.reportOperatorError(leftType, operator_, rightType, errorNode, null);
						case KindAsteriskAsteriskToken | KindAsteriskAsteriskEqualsToken:
							if ((c.languageVersion : Int) < (ScriptTargetES2016 : Int)) {
								c.error(errorNode, Diagnostics.Exponentiation_cannot_be_performed_on_bigint_values_unless_the_target_option_is_set_to_es2016_or_later);
							}
						default:
					}
					resultType = c.bigintType;
				} else {
					// PORT: Go method value `c.bothAreBigIntLike` as an explicit closure.
					c.reportOperatorError(leftType, operator_, rightType, errorNode, (l, r) -> c.bothAreBigIntLike(l, r));
					resultType = c.errorType;
				}
				if (leftOk && rightOk) {
					c.checkAssignmentOperator(left, operator_, right, leftType, resultType);
					switch (operator_) {
						case KindLessThanLessThanToken | KindLessThanLessThanEqualsToken | KindGreaterThanGreaterThanToken
							| KindGreaterThanGreaterThanEqualsToken | KindGreaterThanGreaterThanGreaterThanToken
							| KindGreaterThanGreaterThanGreaterThanEqualsToken:
							final rhsEval = c.evaluate(right, right);
							// PORT: Go `rhsEval.Value.(jsnum.Number)`; a jsnum.Number in `any` is a raw Float (PORTING.md §3).
							if (Std.isOfType(rhsEval.Value, Float)) {
								final numValue:Number = (rhsEval.Value : Float);
								if (numValue.Abs() >= 32) {
									// Elevate from suggestion to error within an enum member
									// PORT: Go formats the jsnum.Number argument with Number.String() (fmt.Sprint); pass that string.
									c.errorOrSuggestion(Ast.IsEnumMember(Ast.WalkUpParenthesizedExpressions(right.Parent.Parent)), errorNode,
										Diagnostics.This_operation_can_be_simplified_This_shift_is_identical_to_0_1_2, Scanner.GetTextOfNode(left),
										Scanner.TokenToString(operator_), ts.jsnum.String_.String(numValue.Remainder(32)));
								}
							}
						default:
					}
				}
				return resultType;
			case KindPlusToken | KindPlusEqualsToken:
				if (leftType == c.silentNeverType || rightType == c.silentNeverType) {
					return c.silentNeverType;
				}
				if (!c.isTypeAssignableToKind(leftType, TypeFlagsStringLike) && !c.isTypeAssignableToKind(rightType, TypeFlagsStringLike)) {
					leftType = c.checkNonNullType(leftType, left);
					rightType = c.checkNonNullType(rightType, right);
				}
				var resultType:Type = null;
				if (c.isTypeAssignableToKindEx(leftType, TypeFlagsNumberLike, true /*strict*/)
					&& c.isTypeAssignableToKindEx(rightType, TypeFlagsNumberLike, true /*strict*/)) {
					// Operands of an enum type are treated as having the primitive type Number.
					// If both operands are of the Number primitive type, the result is of the Number primitive type.
					resultType = c.numberType;
				} else if (c.isTypeAssignableToKindEx(leftType, TypeFlagsBigIntLike, true /*strict*/)
					&& c.isTypeAssignableToKindEx(rightType, TypeFlagsBigIntLike, true /*strict*/)) {
					// If both operands are of the BigInt primitive type, the result is of the BigInt primitive type.
					resultType = c.bigintType;
				} else if (c.isTypeAssignableToKindEx(leftType, TypeFlagsStringLike, true /*strict*/)
					|| c.isTypeAssignableToKindEx(rightType, TypeFlagsStringLike, true /*strict*/)) {
					// If one or both operands are of the String primitive type, the result is of the String primitive type.
					resultType = c.stringType;
				} else if (Checker.IsTypeAny(leftType) || Checker.IsTypeAny(rightType)) {
					// Otherwise, the result is of type Any.
					// NOTE: unknown type here denotes error type. Old compiler treated this case as any type so do we.
					if (c.isErrorType(leftType) || c.isErrorType(rightType)) {
						resultType = c.errorType;
					} else {
						resultType = c.anyType;
					}
				}
				// Symbols are not allowed at all in arithmetic expressions
				if (resultType != null && !c.checkForDisallowedESSymbolOperand(left, right, leftType, rightType, operator_)) {
					return resultType;
				}
				if (resultType == null) {
					// Types that have a reasonably good chance of being a valid operand type.
					// If both types have an awaited type of one of these, we'll assume the user
					// might be missing an await without doing an exhaustive check that inserting
					// await(s) will actually be a completely valid binary expression.
					final closeEnoughKind = TypeFlagsNumberLike | TypeFlagsBigIntLike | TypeFlagsStringLike | TypeFlagsAnyOrUnknown;
					c.reportOperatorError(leftType, operator_, rightType, errorNode, function(left:Type, right:Type):Bool {
						return c.isTypeAssignableToKind(left, closeEnoughKind) && c.isTypeAssignableToKind(right, closeEnoughKind);
					});
					return c.anyType;
				}
				if (operator_ == KindPlusEqualsToken) {
					c.checkAssignmentOperator(left, operator_, right, leftType, resultType);
				}
				return resultType;
			case KindLessThanToken | KindGreaterThanToken | KindLessThanEqualsToken | KindGreaterThanEqualsToken:
				if (c.checkForDisallowedESSymbolOperand(left, right, leftType, rightType, operator_)) {
					leftType = c.getBaseTypeOfLiteralTypeForComparison(c.checkNonNullType(leftType, left));
					rightType = c.getBaseTypeOfLiteralTypeForComparison(c.checkNonNullType(rightType, right));
					c.reportOperatorErrorUnless(leftType, operator_, rightType, errorNode, function(left:Type, right:Type):Bool {
						if (Checker.IsTypeAny(left) || Checker.IsTypeAny(right)) {
							return true;
						}
						final leftAssignableToNumber = c.isTypeAssignableTo(left, c.numberOrBigIntType);
						final rightAssignableToNumber = c.isTypeAssignableTo(right, c.numberOrBigIntType);
						return leftAssignableToNumber && rightAssignableToNumber
							|| !leftAssignableToNumber && !rightAssignableToNumber && c.areTypesComparable(left, right);
					});
				}
				return c.booleanType;
			case KindEqualsEqualsToken | KindExclamationEqualsToken | KindEqualsEqualsEqualsToken | KindExclamationEqualsEqualsToken:
				// We suppress errors in CheckMode.TypeOnly (meaning the invocation came from getTypeOfExpression). During
				// control flow analysis it is possible for operands to temporarily have narrower types, and those narrower
				// types may cause the operands to not be comparable. We don't want such errors reported (see #46475).
				if ((checkMode & CheckModeTypeOnly) == 0) {
					if ((Checker.isLiteralExpressionOfObject(left) || Checker.isLiteralExpressionOfObject(right))
						// only report for === and !== in JS, not == or !=
						&& (!Ast.IsInJSFile(left) || (operator_ == KindEqualsEqualsEqualsToken || operator_ == KindExclamationEqualsEqualsToken))) {
						final eqType = operator_ == KindEqualsEqualsToken || operator_ == KindEqualsEqualsEqualsToken;
						c.error(errorNode, Diagnostics.This_condition_will_always_return_0_since_JavaScript_compares_objects_by_reference_not_value,
							Core.IfElse(eqType, "false", "true"));
					}
					c.checkNaNEquality(errorNode, operator_, left, right);
					c.reportOperatorErrorUnless(leftType, operator_, rightType, errorNode, function(left:Type, right:Type):Bool {
						return c.isTypeEqualityComparableTo(left, right) || c.isTypeEqualityComparableTo(right, left);
					});
				}
				return c.booleanType;
			case KindInstanceOfKeyword:
				return c.checkInstanceOfExpression(left, right, leftType, rightType, checkMode);
			case KindInKeyword:
				return c.checkInExpression(left, right, leftType, rightType);
			case KindAmpersandAmpersandToken | KindAmpersandAmpersandEqualsToken:
				var resultType = leftType;
				if (c.hasTypeFacts(leftType, TypeFactsTruthy)) {
					var t = leftType;
					if (!c.strictNullChecks) {
						t = c.getBaseTypeOfLiteralType(rightType);
					}
					resultType = c.getUnionType([c.extractDefinitelyFalsyTypes(t), rightType]);
				}
				if (operator_ == KindAmpersandAmpersandEqualsToken) {
					c.checkAssignmentOperator(left, operator_, right, leftType, rightType);
				}
				return resultType;
			case KindBarBarToken | KindBarBarEqualsToken:
				var resultType = leftType;
				if (c.hasTypeFacts(leftType, TypeFactsFalsy)) {
					resultType = c.getUnionTypeEx([c.GetNonNullableType(c.removeDefinitelyFalsyTypes(leftType)), rightType], UnionReductionSubtype, null, null);
				}
				if (operator_ == KindBarBarEqualsToken) {
					c.checkAssignmentOperator(left, operator_, right, leftType, rightType);
				}
				return resultType;
			case KindQuestionQuestionToken | KindQuestionQuestionEqualsToken:
				if (operator_ == KindQuestionQuestionToken) {
					c.checkNullishCoalesceOperands(left, right);
				}
				var resultType = leftType;
				if (c.hasTypeFacts(leftType, TypeFactsEQUndefinedOrNull)) {
					resultType = c.getUnionTypeEx([c.GetNonNullableType(leftType), rightType], UnionReductionSubtype, null, null);
				}
				if (operator_ == KindQuestionQuestionEqualsToken) {
					c.checkAssignmentOperator(left, operator_, right, leftType, rightType);
				}
				return resultType;
			case KindEqualsToken:
				c.checkAssignmentOperator(left, operator_, right, leftType, rightType);
				return rightType;
			case KindCommaToken:
				if (!c.compilerOptions.AllowUnreachableCode.IsTrue() && c.isSideEffectFree(left) && !c.isIndirectCall(left.Parent)) {
					final sf = Ast.GetSourceFileOfNode(left);
					final start = Scanner.SkipTrivia(sf.Text(), left.Pos());
					final isInDiag2657 = Core.Some(sf.Diagnostics(), function(d:Diagnostic):Bool {
						if (d.Code() != Diagnostics.JSX_expressions_must_have_one_parent_element.Code()) {
							return false;
						}
						return d.Loc().Contains(start);
					});
					if (!isInDiag2657) {
						c.error(left, Diagnostics.Left_side_of_comma_operator_is_unused_and_has_no_side_effects);
					}
				}
				return rightType;
			default:
		}
		throw "Unhandled case in checkBinaryLikeExpression";
	}

	static function checkDestructuringAssignment(c:Checker, node:Node, sourceType:Type, checkMode:CheckMode, rightIsThis:Bool):Type {
		var target:Node;
		if (Ast.IsShorthandPropertyAssignment(node)) {
			final initializer = node.AsShorthandPropertyAssignment().ObjectAssignmentInitializer;
			if (initializer != null) {
				// In strict null checking mode, if a default value of a non-undefined type is specified, remove
				// undefined from the final type.
				if (c.strictNullChecks && !c.hasTypeFacts(c.checkExpression(initializer), TypeFactsIsUndefined)) {
					sourceType = c.getTypeWithFacts(sourceType, TypeFactsNEUndefined);
				}
				c.checkBinaryLikeExpression(node.Name(), node.AsShorthandPropertyAssignment().EqualsToken, initializer, checkMode, null);
			}
			target = node.Name();
		} else {
			target = node;
		}
		if (Ast.IsBinaryExpression(target) && target.AsBinaryExpression().OperatorToken.Kind == KindEqualsToken) {
			c.checkBinaryExpression(target, checkMode);
			target = target.AsBinaryExpression().Left;
			// A default value is specified, so remove undefined from the final type.
			if (c.strictNullChecks) {
				sourceType = c.getTypeWithFacts(sourceType, TypeFactsNEUndefined);
			}
		}
		if (Ast.IsObjectLiteralExpression(target)) {
			return c.checkObjectLiteralAssignment(target, sourceType, rightIsThis);
		}
		if (Ast.IsArrayLiteralExpression(target)) {
			return c.checkArrayLiteralAssignment(target, sourceType, checkMode);
		}
		return c.checkReferenceAssignment(target, sourceType, checkMode);
	}

	static function checkObjectLiteralAssignment(c:Checker, node:Node, sourceType:Type, rightIsThis:Bool):Type {
		final properties = node.PropertyList();
		if (c.strictNullChecks && properties.Nodes.length == 0) {
			return c.checkNonNullType(sourceType, node);
		}
		for (i in 0...properties.Nodes.length) {
			c.checkObjectLiteralDestructuringPropertyAssignment(node, sourceType, i, properties, rightIsThis);
		}
		return sourceType;
	}

	// Note: If property cannot be a SpreadAssignment, then allProperties does not need to be provided
	static function checkObjectLiteralDestructuringPropertyAssignment(c:Checker, node:Node, objectLiteralType:Type, propertyIndex:Int, allProperties:NodeList, rightIsThis:Bool):Type {
		final properties = node.Properties();
		final property = properties[propertyIndex];
		if (Ast.IsPropertyAssignment(property) || Ast.IsShorthandPropertyAssignment(property)) {
			final name = property.Name();
			final exprType = c.getLiteralTypeFromPropertyName(name);
			if (Checker.isTypeUsableAsPropertyName(exprType)) {
				final text = Checker.getPropertyNameFromType(exprType);
				final prop = c.getPropertyOfType(objectLiteralType, text);
				if (prop != null) {
					c.markPropertyAsReferenced(prop, property, rightIsThis);
					c.checkPropertyAccessibility(property, false /*isSuper*/, true /*writing*/, objectLiteralType, prop);
				}
			}
			final elementType = c.getIndexedAccessTypeEx(objectLiteralType, exprType,
				AccessFlagsExpressionPosition | Core.IfElse(c.hasDefaultValue(property), AccessFlagsAllowMissing, (0 : AccessFlags)), name, null);
			final t = c.getFlowTypeOfDestructuring(property, elementType);
			var expr = property;
			if (Ast.IsPropertyAssignment(property)) {
				expr = property.Initializer();
			}
			return c.checkDestructuringAssignment(expr, t, CheckModeNormal, false);
		}
		if (Ast.IsSpreadAssignment(property)) {
			if (propertyIndex < properties.length - 1) {
				c.error(property, Diagnostics.A_rest_element_must_be_last_in_a_destructuring_pattern);
				return null;
			}
			if ((c.languageVersion : Int) < (Checker.LanguageFeatureMinimumTarget.ObjectSpreadRest : Int)) {
				c.checkExternalEmitHelpers(property, ExternalEmitHelpersRest);
			}
			var nonRestNames:Array<Node> = null;
			if (allProperties != null) {
				for (otherProperty in allProperties.Nodes) {
					if (!Ast.IsSpreadAssignment(otherProperty)) {
						if (nonRestNames == null) {
							nonRestNames = [];
						}
						nonRestNames.push(otherProperty.Name());
					}
				}
			}
			final t = c.getRestType(objectLiteralType, nonRestNames, objectLiteralType.symbol);
			c.checkGrammarForDisallowedTrailingComma(allProperties, Diagnostics.A_rest_parameter_or_binding_pattern_may_not_have_a_trailing_comma);
			return c.checkDestructuringAssignment(property.Expression(), t, CheckModeNormal, false);
		}
		c.error(property, Diagnostics.Property_assignment_expected);
		return null;
	}

	static function checkArrayLiteralAssignment(c:Checker, node:Node, sourceType:Type, checkMode:CheckMode):Type {
		final elements = node.Elements();
		// This elementType will be used if the specific property corresponding to this index is not
		// present (aka the tuple element property). This call also checks that the parentType is in
		// fact an iterable or array (depending on target language).
		final possiblyOutOfBoundsType = Core.OrElse(c.checkIteratedTypeOrElementType(IterationUseDestructuring | IterationUsePossiblyOutOfBounds, sourceType,
			c.undefinedType, node), c.errorType);
		var inBoundsType = Core.IfElse(c.compilerOptions.NoUncheckedIndexedAccess == TSTrue, null, possiblyOutOfBoundsType);
		for (i in 0...elements.length) {
			var t = possiblyOutOfBoundsType;
			if (elements[i].Kind == KindSpreadElement) {
				if (inBoundsType == null) {
					inBoundsType = Core.OrElse(c.checkIteratedTypeOrElementType(IterationUseDestructuring, sourceType, c.undefinedType, node), c.errorType);
				}
				t = inBoundsType;
			}
			c.checkArrayLiteralDestructuringElementAssignment(node, sourceType, i, t, checkMode);
		}
		return sourceType;
	}

	static function checkArrayLiteralDestructuringElementAssignment(c:Checker, node:Node, sourceType:Type, elementIndex:Int, elementType:Type, checkMode:CheckMode):Type {
		final elements = node.ElementList();
		final element = elements.Nodes[elementIndex];
		if (!Ast.IsOmittedExpression(element)) {
			if (!Ast.IsSpreadElement(element)) {
				final indexType = c.getNumberLiteralType((elementIndex : Number));
				if (c.isArrayLikeType(sourceType)) {
					// We create a synthetic expression so that getIndexedAccessType doesn't get confused
					// when the element is a SyntaxKind.ElementAccessExpression.
					final accessFlags = AccessFlagsExpressionPosition | Core.IfElse(c.hasDefaultValue(element), AccessFlagsAllowMissing, (0 : AccessFlags));
					final elementType = Core.OrElse(c.getIndexedAccessTypeOrUndefined(sourceType, indexType, accessFlags,
						c.createSyntheticExpression(element, indexType, false, null), null), c.errorType);
					var assignedType = elementType;
					if (c.hasDefaultValue(element)) {
						assignedType = c.getTypeWithFacts(elementType, TypeFactsNEUndefined);
					}
					final t = c.getFlowTypeOfDestructuring(element, assignedType);
					return c.checkDestructuringAssignment(element, t, checkMode, false);
				}
				return c.checkDestructuringAssignment(element, elementType, checkMode, false);
			}
			if (elementIndex < elements.Nodes.length - 1) {
				c.error(element, Diagnostics.A_rest_element_must_be_last_in_a_destructuring_pattern);
			} else {
				final restExpression = element.Expression();
				if (Ast.IsBinaryExpression(restExpression) && restExpression.AsBinaryExpression().OperatorToken.Kind == KindEqualsToken) {
					c.error(restExpression.AsBinaryExpression().OperatorToken, Diagnostics.A_rest_element_cannot_have_an_initializer);
				} else {
					c.checkGrammarForDisallowedTrailingComma(elements, Diagnostics.A_rest_parameter_or_binding_pattern_may_not_have_a_trailing_comma);
					var t:Type;
					if (Checker.everyType(sourceType, Checker.isTupleType)) {
						t = c.mapType(sourceType, function(t:Type):Type {
							return c.sliceTupleType(t, elementIndex, 0);
						});
					} else {
						t = c.createArrayType(elementType);
					}
					return c.checkDestructuringAssignment(restExpression, t, checkMode, false);
				}
			}
		}
		return null;
	}

	static function checkReferenceAssignment(c:Checker, target:Node, sourceType:Type, checkMode:CheckMode):Type {
		final targetType = c.checkExpressionEx(target, checkMode);
		final message = Core.IfElse(Ast.IsSpreadAssignment(target.Parent),
			Diagnostics.The_target_of_an_object_rest_assignment_must_be_a_variable_or_a_property_access,
			Diagnostics.The_left_hand_side_of_an_assignment_expression_must_be_a_variable_or_a_property_access);
		final optionalMessage = Core.IfElse(Ast.IsSpreadAssignment(target.Parent),
			Diagnostics.The_target_of_an_object_rest_assignment_may_not_be_an_optional_property_access,
			Diagnostics.The_left_hand_side_of_an_assignment_expression_may_not_be_an_optional_property_access);
		if (c.checkReferenceExpression(target, message, optionalMessage)) {
			c.checkTypeAssignableToAndOptionallyElaborate(sourceType, targetType, target, target, null, null);
		}
		return sourceType;
	}

	static function reportOperatorError(c:Checker, leftType:Type, operator_:Kind, rightType:Type, errorNode:Node, isRelated:(left:Type, right:Type) -> Bool):Void {
		var wouldWorkWithAwait = false;
		if (isRelated != null) {
			final awaitedLeftType = c.getAwaitedTypeNoAlias(leftType);
			final awaitedRightType = c.getAwaitedTypeNoAlias(rightType);
			wouldWorkWithAwait = !(awaitedLeftType == leftType && awaitedRightType == rightType) && awaitedLeftType != null && awaitedRightType != null
				&& isRelated(awaitedLeftType, awaitedRightType);
		}
		var effectiveLeft = leftType;
		var effectiveRight = rightType;
		if (!wouldWorkWithAwait && isRelated != null) {
			final r = c.getBaseTypesIfUnrelated(leftType, rightType, isRelated);
			effectiveLeft = r.a;
			effectiveRight = r.b;
		}
		final names = c.getTypeNamesForErrorDisplay(effectiveLeft, effectiveRight);
		final leftStr = names.a;
		final rightStr = names.b;
		switch (operator_) {
			case KindEqualsEqualsEqualsToken | KindEqualsEqualsToken | KindExclamationEqualsEqualsToken | KindExclamationEqualsToken:
				c.errorAndMaybeSuggestAwait(errorNode, wouldWorkWithAwait,
					Diagnostics.This_comparison_appears_to_be_unintentional_because_the_types_0_and_1_have_no_overlap, leftStr, rightStr);
			default:
				c.errorAndMaybeSuggestAwait(errorNode, wouldWorkWithAwait, Diagnostics.Operator_0_cannot_be_applied_to_types_1_and_2,
					Scanner.TokenToString(operator_), leftStr, rightStr);
		}
	}

	static function reportOperatorErrorUnless(c:Checker, leftType:Type, operator_:Kind, rightType:Type, errorNode:Node, typesAreCompatible:(left:Type, right:Type) -> Bool):Void {
		if (!typesAreCompatible(leftType, rightType)) {
			c.reportOperatorError(leftType, operator_, rightType, errorNode, typesAreCompatible);
		}
	}

	static function getBaseTypesIfUnrelated(c:Checker, leftType:Type, rightType:Type, isRelated:(left:Type, right:Type) -> Bool):Pair<Type, Type> {
		var effectiveLeft = leftType;
		var effectiveRight = rightType;
		final leftBase = c.getBaseTypeOfLiteralType(leftType);
		final rightBase = c.getBaseTypeOfLiteralType(rightType);
		if (!isRelated(leftBase, rightBase)) {
			effectiveLeft = leftBase;
			effectiveRight = rightBase;
		}
		return new Pair(effectiveLeft, effectiveRight);
	}

	static function checkAssignmentOperator(c:Checker, left:Node, operator_:Kind, right:Node, leftType:Type, rightType:Type):Void {
		if (Ast.IsAssignmentOperator(operator_)) {
			// We ignore assignments of undefined to CommonJS exports when there are multiple assignment declarations
			if (Ast.IsDeclarationNode(left.Parent) && Ast.GetAssignmentDeclarationKind(left.Parent) == JSDeclarationKindExportsProperty) {
				final symbol = c.symbolNodeLinks.Get(left).resolvedSymbol;
				if (symbol != null && Core.len(symbol.Declarations) > 1 && (rightType.flags & TypeFlagsUndefined) != 0) {
					return;
				}
			}
			// getters can be a subtype of setters, so to check for assignability we use the setter's type instead
			if (Ast.IsCompoundAssignment(operator_) && Ast.IsPropertyAccessExpression(left)) {
				leftType = c.checkPropertyAccessExpression(left, CheckModeNormal, true /*writeOnly*/);
			}
			if (c.checkReferenceExpression(left, Diagnostics.The_left_hand_side_of_an_assignment_expression_must_be_a_variable_or_a_property_access,
				Diagnostics.The_left_hand_side_of_an_assignment_expression_may_not_be_an_optional_property_access)) {
				var headMessage:Message = null;
				if (c.exactOptionalPropertyTypes && Ast.IsPropertyAccessExpression(left) && c.maybeTypeOfKind(rightType, TypeFlagsUndefined)) {
					final target = c.getTypeOfPropertyOfType(c.getTypeOfExpression(left.Expression()), left.Name().Text());
					if (c.isExactOptionalPropertyMismatch(rightType, target)) {
						headMessage = Diagnostics.Type_0_is_not_assignable_to_type_1_with_exactOptionalPropertyTypes_Colon_true_Consider_adding_undefined_to_the_type_of_the_target;
					}
				}
				// to avoid cascading errors check assignability only if 'isReference' check succeeded and no errors were reported
				c.checkTypeAssignableToAndOptionallyElaborate(rightType, leftType, left, right, headMessage, null);
			}
		}
	}

	static function bothAreBigIntLike(c:Checker, left:Type, right:Type):Bool {
		return c.isTypeAssignableToKind(left, TypeFlagsBigIntLike) && c.isTypeAssignableToKind(right, TypeFlagsBigIntLike);
	}

	static function getSuggestedBooleanOperator(c:Checker, operator_:Kind):Kind {
		switch (operator_) {
			case KindBarToken | KindBarEqualsToken:
				return KindBarBarToken;
			case KindCaretToken | KindCaretEqualsToken:
				return KindExclamationEqualsEqualsToken;
			case KindAmpersandToken | KindAmpersandEqualsToken:
				return KindAmpersandAmpersandToken;
			default:
		}
		return KindUnknown;
	}

	static function checkArithmeticOperandType(c:Checker, operand:Node, t:Type, diagnostic:Message, isAwaitValid:Bool):Bool {
		if (!c.isTypeAssignableTo(t, c.numberOrBigIntType)) {
			var awaitedType:Type = null;
			if (isAwaitValid) {
				awaitedType = c.getAwaitedTypeOfPromise(t);
			}
			c.errorAndMaybeSuggestAwait(operand, awaitedType != null && c.isTypeAssignableTo(awaitedType, c.numberOrBigIntType), diagnostic);
			return false;
		}
		return true;
	}

	// Return true if there was no error, false if there was an error.
	static function checkForDisallowedESSymbolOperand(c:Checker, left:Node, right:Node, leftType:Type, rightType:Type, operator_:Kind):Bool {
		var offendingSymbolOperand:Node = null;
		if (c.maybeTypeOfKindConsideringBaseConstraint(leftType, TypeFlagsESSymbolLike)) {
			offendingSymbolOperand = left;
		} else if (c.maybeTypeOfKindConsideringBaseConstraint(rightType, TypeFlagsESSymbolLike)) {
			offendingSymbolOperand = right;
		}
		if (offendingSymbolOperand != null) {
			c.error(offendingSymbolOperand, Diagnostics.The_0_operator_cannot_be_applied_to_type_symbol, Scanner.TokenToString(operator_));
			return false;
		}
		return true;
	}

	static function checkNaNEquality(c:Checker, errorNode:Node, operator_:Kind, left:Expression, right:Expression):Void {
		final isLeftNaN = c.isGlobalNaN(Ast.SkipParentheses(left));
		final isRightNaN = c.isGlobalNaN(Ast.SkipParentheses(right));
		if (isLeftNaN || isRightNaN) {
			final err = c.error(errorNode, Diagnostics.This_condition_will_always_return_0,
				Scanner.TokenToString(Core.IfElse(operator_ == KindEqualsEqualsEqualsToken || operator_ == KindEqualsEqualsToken, KindFalseKeyword, KindTrueKeyword)));
			if (isLeftNaN && isRightNaN) {
				return;
			}
			var operatorString = "";
			if (operator_ == KindExclamationEqualsEqualsToken || operator_ == KindExclamationEqualsToken) {
				operatorString = Scanner.TokenToString(KindExclamationToken);
			}
			var location = left;
			if (isLeftNaN) {
				location = right;
			}
			final expression = Ast.SkipParentheses(location);
			var entityName = "...";
			if (Ast.IsEntityNameExpression(expression)) {
				entityName = Checker.entityNameToString(expression);
			}
			final suggestion = operatorString + "Number.isNaN(" + entityName + ")";
			err.AddRelatedInfo(Checker.createDiagnosticForNode(location, Diagnostics.Did_you_mean_0, suggestion));
		}
	}

	static function isGlobalNaN(c:Checker, expr:Expression):Bool {
		if (Ast.IsIdentifier(expr) && expr.Text() == "NaN") {
			final globalNaNSymbol = c.getGlobalNaNSymbolOrNil();
			return globalNaNSymbol != null && globalNaNSymbol == c.getResolvedSymbol(expr);
		}
		return false;
	}

	static function isTypeEqualityComparableTo(c:Checker, source:Type, target:Type):Bool {
		return (target.flags & TypeFlagsNullable) != 0 || c.isTypeComparableTo(source, target);
	}

	static function checkTruthinessOfType(c:Checker, t:Type, node:Node):Type {
		if ((t.flags & TypeFlagsVoid) != 0) {
			c.error(node, Diagnostics.An_expression_of_type_void_cannot_be_tested_for_truthiness);
			return t;
		}
		final semantics = c.getSyntacticTruthySemantics(node);
		if (semantics != PredicateSemanticsSometimes) {
			c.error(node, Core.IfElse(semantics == PredicateSemanticsAlways, Diagnostics.This_kind_of_expression_is_always_truthy, Diagnostics.This_kind_of_expression_is_always_falsy));
		}
		return t;
	}

	static function getSyntacticTruthySemantics(c:Checker, node:Node):PredicateSemantics {
		node = Ast.SkipOuterExpressions(node, OEKAll);
		switch (node.Kind) {
			case KindNumericLiteral:
				// Allow `while(0)` or `while(1)`
				if (node.Text() == "0" || node.Text() == "1") {
					return PredicateSemanticsSometimes;
				}
				return PredicateSemanticsAlways;
			case KindArrayLiteralExpression | KindArrowFunction | KindBigIntLiteral | KindClassExpression | KindFunctionExpression
				| KindJsxElement | KindJsxSelfClosingElement | KindObjectLiteralExpression | KindRegularExpressionLiteral:
				return PredicateSemanticsAlways;
			case KindVoidExpression | KindNullKeyword:
				return PredicateSemanticsNever;
			case KindNoSubstitutionTemplateLiteral | KindStringLiteral:
				if (node.Text() != "") {
					return PredicateSemanticsAlways;
				}
				return PredicateSemanticsNever;
			case KindConditionalExpression:
				return c.getSyntacticTruthySemantics(node.AsConditionalExpression().WhenTrue) | c.getSyntacticTruthySemantics(node.AsConditionalExpression().WhenFalse);
			case KindIdentifier:
				if (c.getResolvedSymbol(node) == c.undefinedSymbol) {
					return PredicateSemanticsNever;
				}
			default:
		}
		return PredicateSemanticsSometimes;
	}

	static function checkNullishCoalesceOperands(c:Checker, left:Node, right:Node):Void {
		if (Ast.IsBinaryExpression(left.Parent.Parent)) {
			final grandparentLeft = left.Parent.Parent.AsBinaryExpression().Left;
			final grandparentOperatorToken = left.Parent.Parent.AsBinaryExpression().OperatorToken;
			if (Ast.IsBinaryExpression(grandparentLeft) && grandparentOperatorToken.Kind == KindBarBarToken) {
				c.grammarErrorOnNode(grandparentLeft, Diagnostics.X_0_and_1_operations_cannot_be_mixed_without_parentheses, Scanner.TokenToString(KindQuestionQuestionToken),
					Scanner.TokenToString(grandparentOperatorToken.Kind));
			}
		} else if (Ast.IsBinaryExpression(left)) {
			final operatorToken = left.AsBinaryExpression().OperatorToken;
			if (operatorToken.Kind == KindBarBarToken || operatorToken.Kind == KindAmpersandAmpersandToken) {
				c.grammarErrorOnNode(left, Diagnostics.X_0_and_1_operations_cannot_be_mixed_without_parentheses, Scanner.TokenToString(operatorToken.Kind),
					Scanner.TokenToString(KindQuestionQuestionToken));
			}
		} else if (Ast.IsBinaryExpression(right)) {
			final operatorToken = right.AsBinaryExpression().OperatorToken;
			if (operatorToken.Kind == KindAmpersandAmpersandToken) {
				c.grammarErrorOnNode(right, Diagnostics.X_0_and_1_operations_cannot_be_mixed_without_parentheses, Scanner.TokenToString(KindQuestionQuestionToken),
					Scanner.TokenToString(operatorToken.Kind));
			}
		}
		c.checkNullishCoalesceOperandLeft(left);
	}

	static function checkNullishCoalesceOperandLeft(c:Checker, left:Node):Void {
		final leftTarget = Ast.SkipOuterExpressions(left, OEKAll);
		final nullishSemantics = c.getSyntacticNullishnessSemantics(leftTarget);
		if (nullishSemantics != PredicateSemanticsSometimes) {
			if (nullishSemantics == PredicateSemanticsAlways) {
				c.error(leftTarget, Diagnostics.This_expression_is_always_nullish);
			} else {
				c.error(leftTarget, Diagnostics.Right_operand_of_is_unreachable_because_the_left_operand_is_never_nullish);
			}
		}
	}

	static function getSyntacticNullishnessSemantics(c:Checker, node:Node):PredicateSemantics {
		node = Ast.SkipOuterExpressions(node, OEKAll);
		switch (node.Kind) {
			case KindAwaitExpression | KindCallExpression | KindTaggedTemplateExpression | KindElementAccessExpression | KindMetaProperty | KindNewExpression
				| KindPropertyAccessExpression | KindYieldExpression | KindThisKeyword:
				return PredicateSemanticsSometimes;
			case KindBinaryExpression:
				// List of operators that can produce null/undefined:
				// || ||= && &&=
				switch (node.AsBinaryExpression().OperatorToken.Kind) {
					case KindBarBarToken | KindBarBarEqualsToken | KindAmpersandAmpersandToken | KindAmpersandAmpersandEqualsToken:
						return PredicateSemanticsSometimes;
					// For these operator kinds, the right operand is effectively controlling
					case KindCommaToken | KindEqualsToken | KindQuestionQuestionToken | KindQuestionQuestionEqualsToken:
						return c.getSyntacticNullishnessSemantics(node.AsBinaryExpression().Right);
					default:
				}
				return PredicateSemanticsNever;
			case KindConditionalExpression:
				return c.getSyntacticNullishnessSemantics(node.AsConditionalExpression().WhenTrue) | c.getSyntacticNullishnessSemantics(node.AsConditionalExpression().WhenFalse);
			case KindNullKeyword:
				return PredicateSemanticsAlways;
			case KindIdentifier:
				if (c.getResolvedSymbol(node) == c.undefinedSymbol) {
					return PredicateSemanticsAlways;
				}
				return PredicateSemanticsSometimes;
			default:
		}
		return PredicateSemanticsNever;
	}

	/**
	 * This is a *shallow* check: An expression is side-effect-free if the
	 * evaluation of the expression *itself* cannot produce side effects.
	 * For example, x++ / 3 is side-effect free because the / operator
	 * does not have side effects.
	 * The intent is to "smell test" an expression for correctness in positions where
	 * its value is discarded (e.g. the left side of the comma operator).
	 */
	static function isSideEffectFree(c:Checker, node:Node):Bool {
		node = Ast.SkipParentheses(node);
		switch (node.Kind) {
			case KindIdentifier | KindStringLiteral | KindRegularExpressionLiteral | KindTaggedTemplateExpression | KindTemplateExpression
				| KindNoSubstitutionTemplateLiteral | KindNumericLiteral | KindBigIntLiteral | KindTrueKeyword | KindFalseKeyword
				| KindNullKeyword | KindUndefinedKeyword | KindFunctionExpression | KindClassExpression | KindArrowFunction
				| KindArrayLiteralExpression | KindObjectLiteralExpression | KindTypeOfExpression | KindNonNullExpression | KindJsxSelfClosingElement
				| KindJsxElement:
				return true;
			case KindConditionalExpression:
				return c.isSideEffectFree(node.AsConditionalExpression().WhenTrue) && c.isSideEffectFree(node.AsConditionalExpression().WhenFalse);
			case KindBinaryExpression:
				if (Ast.IsAssignmentOperator(node.AsBinaryExpression().OperatorToken.Kind)) {
					return false;
				}
				return c.isSideEffectFree(node.AsBinaryExpression().Left) && c.isSideEffectFree(node.AsBinaryExpression().Right);
			case KindPrefixUnaryExpression:
				// Unary operators ~, !, +, and - have no side effects.
				// The rest do.
				switch (node.AsPrefixUnaryExpression().Operator) {
					case KindExclamationToken | KindPlusToken | KindMinusToken | KindTildeToken:
						return true;
					default:
				}
			default:
		}
		return false;
	}

	// Return true for "indirect calls", (i.e. `(0, x.f)(...)` or `(0, eval)(...)`), which prevents passing `this`.
	static function isIndirectCall(c:Checker, node:Node):Bool {
		final left = node.AsBinaryExpression().Left;
		final right = node.AsBinaryExpression().Right;
		return Ast.IsParenthesizedExpression(node.Parent) && Ast.IsNumericLiteral(left) && left.Text() == "0"
			&& (Ast.IsCallExpression(node.Parent.Parent) && node.Parent.Parent.Expression() == node.Parent
				|| Ast.IsTaggedTemplateExpression(node.Parent.Parent))
			&& (Ast.IsAccessExpression(right) || Ast.IsIdentifier(right) && right.Text() == "eval");
	}

	static function checkInstanceOfExpression(c:Checker, left:Expression, right:Expression, leftType:Type, rightType:Type, checkMode:CheckMode):Type {
		if (leftType == c.silentNeverType || rightType == c.silentNeverType) {
			return c.silentNeverType;
		}
		// TypeScript 1.0 spec (April 2014): 4.15.4
		// The instanceof operator requires the left operand to be of type Any, an object type, or a type parameter type,
		// and the right operand to be of type Any, a subtype of the 'Function' interface type, or have a call or construct signature.
		// The result is always of the Boolean primitive type.
		// NOTE: do not raise error if leftType is unknown as related error was already reported
		if (!Checker.IsTypeAny(leftType) && c.allTypesAssignableToKind(leftType, TypeFlagsPrimitive)) {
			c.error(left, Diagnostics.The_left_hand_side_of_an_instanceof_expression_must_be_of_type_any_an_object_type_or_a_type_parameter);
		}
		final signature = c.getResolvedSignature(left.Parent, null /*candidatesOutArray*/, checkMode);
		if (signature == c.resolvingSignature) {
			// CheckMode.SkipGenericFunctions is enabled and this is a call to a generic function that
			// returns a function type. We defer checking and return silentNeverType.
			return c.silentNeverType;
		}
		// If rightType has a `[Symbol.hasInstance]` method that is not `(value: unknown) => boolean`, we
		// must check the expression as if it were a call to `right[Symbol.hasInstance](left)`. The call to
		// `getResolvedSignature`, below, will check that leftType is assignable to the type of the first
		// parameter.
		final returnType = c.getReturnTypeOfSignature(signature);
		// We also verify that the return type of the `[Symbol.hasInstance]` method is assignable to
		// `boolean`. According to the spec, the runtime will actually perform `ToBoolean` on the result,
		// but this is more type-safe.
		c.checkTypeAssignableTo(returnType, c.booleanType, right,
			Diagnostics.An_object_s_Symbol_hasInstance_method_must_return_a_boolean_value_for_it_to_be_used_on_the_right_hand_side_of_an_instanceof_expression);
		return c.booleanType;
	}

	static function checkInExpression(c:Checker, left:Expression, right:Expression, leftType:Type, rightType:Type):Type {
		if (leftType == c.silentNeverType || rightType == c.silentNeverType) {
			return c.silentNeverType;
		}
		if (Ast.IsPrivateIdentifier(left)) {
			if ((c.languageVersion : Int) < (Checker.LanguageFeatureMinimumTarget.PrivateNamesAndClassStaticBlocks : Int)
				|| (c.languageVersion : Int) < (Checker.LanguageFeatureMinimumTarget.ClassAndClassElementDecorators : Int)
				|| !c.compilerOptions.GetUseDefineForClassFields()) {
				c.checkExternalEmitHelpers(left, ExternalEmitHelpersClassPrivateFieldIn);
			}
			// Unlike in 'checkPrivateIdentifierExpression' we now have access to the RHS type
			// which provides us with the opportunity to emit more detailed errors
			if (c.symbolNodeLinks.Get(left).resolvedSymbol == null && Ast.GetContainingClass(left) != null) {
				final isUncheckedJS = c.isUncheckedJSSuggestion(left, rightType.symbol, true /*excludeClasses*/);
				c.reportNonexistentProperty(left, rightType, isUncheckedJS);
			}
		} else {
			// The type of the left operand must be assignable to string, number, or symbol.
			c.checkTypeAssignableTo(c.checkNonNullType(leftType, left), c.stringNumberSymbolType, left, null);
		}
		// The type of the right operand must be assignable to 'object'.
		if (c.checkTypeAssignableTo(c.checkNonNullType(rightType, right), c.nonPrimitiveType, right, null)) {
			// The {} type is assignable to the object type, yet {} might represent a primitive type. Here we
			// detect and error on {} that results from narrowing the unknown type, as well as intersections
			// that include {} (we know that the other types in such intersections are assignable to object
			// since we already checked for that).
			if (c.hasEmptyObjectIntersection(rightType)) {
				c.error(right, Diagnostics.Type_0_may_represent_a_primitive_value_which_is_not_permitted_as_the_right_operand_of_the_in_operator,
					c.TypeToString(rightType));
			}
		}
		// The result is always of the Boolean primitive type.
		return c.booleanType;
	}

	static function hasEmptyObjectIntersection(c:Checker, t:Type):Bool {
		return Checker.someType(t, function(t:Type):Bool {
			return t == c.unknownEmptyObjectType || (t.flags & TypeFlagsIntersection) != 0 && c.IsEmptyAnonymousObjectType(c.getBaseConstraintOrType(t));
		});
	}

	static function getExactOptionalUnassignableProperties(c:Checker, source:Type, target:Type):Array<Symbol> {
		if (Checker.isTupleType(source) && Checker.isTupleType(target)) {
			return null;
		}
		return Core.Filter(c.getPropertiesOfType(target), function(targetProp:Symbol):Bool {
			return c.isExactOptionalPropertyMismatch(c.getTypeOfPropertyOfType(source, targetProp.Name), c.getTypeOfSymbol(targetProp));
		});
	}

	static function isExactOptionalPropertyMismatch(c:Checker, source:Type, target:Type):Bool {
		return source != null && target != null && c.maybeTypeOfKind(source, TypeFlagsUndefined) && c.containsMissingType(target);
	}

	static function checkReferenceExpression(c:Checker, expr:Node, invalidReferenceMessage:Message, invalidOptionalChainMessage:Message):Bool {
		// References are combinations of identifiers, parentheses, and property accesses.
		final node = Ast.SkipOuterExpressions(expr, OEKAssertions | OEKParentheses);
		if (node.Kind != KindIdentifier && !Ast.IsAccessExpression(node)) {
			c.error(expr, invalidReferenceMessage);
			return false;
		}
		if ((node.Flags & NodeFlagsOptionalChain) != 0) {
			c.error(expr, invalidOptionalChainMessage);
			return false;
		}
		return true;
	}

	static function checkObjectLiteral(c:Checker, node:Node, checkMode:CheckMode):Type {
		// Expando object literals have empty properties but filled exports
		if (Core.len(node.Properties()) == 0 && node.Symbol() != null && node.Symbol().Exports != null && node.Symbol().Exports.keys().hasNext()) {
			final result = c.newAnonymousType(node.Symbol(), node.Symbol().Exports, null, null, null);
			if (Ast.IsInJSFile(node) && !Ast.IsInJsonFile(node)) {
				result.objectFlags |= ObjectFlagsJSLiteral;
			}
			return result;
		}
		final inDestructuringPattern = Ast.IsAssignmentTarget(node);
		// Grammar checking
		c.checkGrammarObjectLiteralExpression(node.AsObjectLiteralExpression(), inDestructuringPattern);
		var allPropertiesTable:SymbolTable = null;
		if (c.strictNullChecks) {
			allPropertiesTable = new SymbolTable();
		}
		var propertiesTable = new SymbolTable();
		var propertiesArray:Array<Symbol> = null;
		var spread = c.emptyObjectType;
		c.pushCachedContextualType(node);
		final contextualType = c.getApparentTypeOfContextualType(node, ContextFlagsNone);
		var contextualTypeHasPattern = false;
		if (contextualType != null) {
			final pattern = c.patternForType.get(contextualType);
			if (pattern != null && (Ast.IsObjectBindingPattern(pattern) || Ast.IsObjectLiteralExpression(pattern))) {
				contextualTypeHasPattern = true;
			}
		}
		final inConstContext = c.isConstContext(node);
		var checkFlags:CheckFlags = 0;
		if (inConstContext) {
			checkFlags = CheckFlagsReadonly;
		}
		var objectFlags:ObjectFlags = ObjectFlagsFreshLiteral;
		var patternWithComputedProperties = false;
		var hasComputedStringProperty = false;
		var hasComputedNumberProperty = false;
		var hasComputedSymbolProperty = false;
		// Spreads may cause an early bail; ensure computed names are always checked (this is cached)
		// As otherwise they may not be checked until exports for the type at this position are retrieved,
		// which may never occur.
		for (elem in rangeOf(node.Properties())) {
			if (elem.Name() != null && Ast.IsComputedPropertyName(elem.Name())) {
				c.checkComputedPropertyName(elem.Name());
			}
		}
		var offset = 0;
		final createObjectLiteralType = function():Type {
			var indexInfos:Array<IndexInfo> = null;
			final isReadonly = c.isConstContext(node);
			if (hasComputedStringProperty) {
				if (indexInfos == null) indexInfos = [];
				indexInfos.push(c.getObjectLiteralIndexInfo(isReadonly, propertiesArray.slice(offset), c.stringType));
			}
			if (hasComputedNumberProperty) {
				if (indexInfos == null) indexInfos = [];
				indexInfos.push(c.getObjectLiteralIndexInfo(isReadonly, propertiesArray.slice(offset), c.numberType));
			}
			if (hasComputedSymbolProperty) {
				if (indexInfos == null) indexInfos = [];
				indexInfos.push(c.getObjectLiteralIndexInfo(isReadonly, propertiesArray.slice(offset), c.esSymbolType));
			}
			final result = c.newAnonymousType(node.Symbol(), propertiesTable, null, null, indexInfos);
			result.objectFlags |= objectFlags | ObjectFlagsObjectLiteral | ObjectFlagsContainsObjectOrArrayLiteral;
			if (contextualType == null && Ast.IsInJSFile(node) && !Ast.IsInJsonFile(node)) {
				result.objectFlags |= ObjectFlagsJSLiteral;
			}
			if (patternWithComputedProperties) {
				result.objectFlags |= ObjectFlagsObjectLiteralPatternWithComputedProperties;
			}
			if (inDestructuringPattern) {
				c.patternForType.set(result, node);
			}
			return result;
		};
		for (memberDecl in rangeOf(node.Properties())) {
			var member = c.getSymbolOfDeclaration(memberDecl);
			var computedNameType:Type = null;
			if (memberDecl.Name() != null && memberDecl.Name().Kind == KindComputedPropertyName) {
				computedNameType = c.checkComputedPropertyName(memberDecl.Name());
			}
			if (Ast.IsPropertyAssignment(memberDecl) || Ast.IsShorthandPropertyAssignment(memberDecl) || Ast.IsObjectLiteralMethod(memberDecl)) {
				var t:Type = null;
				switch (memberDecl.Kind) {
					case KindPropertyAssignment:
						t = c.checkPropertyAssignment(memberDecl, checkMode);
					case KindShorthandPropertyAssignment:
						t = c.checkShorthandPropertyAssignment(memberDecl, inDestructuringPattern, checkMode);
					default:
						t = c.checkObjectLiteralMethod(memberDecl, checkMode);
				}
				objectFlags |= t.objectFlags & ObjectFlagsPropagatingFlags;
				var nameType:Type = null;
				if (computedNameType != null && Checker.isTypeUsableAsPropertyName(computedNameType)) {
					nameType = computedNameType;
				}
				var prop:Symbol = null;
				if (nameType != null) {
					prop = c.newSymbolEx(SymbolFlagsProperty | member.Flags, Checker.getPropertyNameFromType(nameType), checkFlags | CheckFlagsLate);
				} else {
					prop = c.newSymbolEx(SymbolFlagsProperty | member.Flags, member.Name, checkFlags);
				}
				final links = c.valueSymbolLinks.Get(prop);
				if (nameType != null) {
					links.nameType = nameType;
				}
				if (inDestructuringPattern && c.hasDefaultValue(memberDecl)) {
					// If object literal is an assignment pattern and if the assignment pattern specifies a default value
					// for the property, make the property optional.
					prop.Flags |= SymbolFlagsOptional;
				} else if (contextualTypeHasPattern && (contextualType.objectFlags & ObjectFlagsObjectLiteralPatternWithComputedProperties) == 0) {
					// If object literal is contextually typed by the implied type of a binding pattern, and if the
					// binding pattern specifies a default value for the property, make the property optional.
					final impliedProp = c.getPropertyOfType(contextualType, member.Name);
					if (impliedProp != null) {
						prop.Flags |= impliedProp.Flags & SymbolFlagsOptional;
					} else if (c.getIndexInfoOfType(contextualType, c.stringType) == null) {
						c.error(memberDecl.Name(), Diagnostics.Object_literal_may_only_specify_known_properties_and_0_does_not_exist_in_type_1, c.symbolToString(member),
							c.TypeToString(contextualType));
					}
				}
				prop.Declarations = member.Declarations;
				prop.Parent = member.Parent;
				prop.ValueDeclaration = member.ValueDeclaration;
				links.resolvedType = t;
				links.target = member;
				member = prop;
				if (allPropertiesTable != null) {
					allPropertiesTable.set(prop.Name, prop);
				}
				if (contextualType != null && (checkMode & CheckModeInferential) != 0 && (checkMode & CheckModeSkipContextSensitive) == 0
					&& (Ast.IsPropertyAssignment(memberDecl) || Ast.IsMethodDeclaration(memberDecl)) && c.isContextSensitive(memberDecl)) {
					final inferenceContext = c.getInferenceContext(node);
					// In CheckMode.Inferential we should always have an inference context
					var inferenceNode = memberDecl;
					if (Ast.IsPropertyAssignment(memberDecl)) {
						inferenceNode = memberDecl.Initializer();
					}
					c.addIntraExpressionInferenceSite(inferenceContext, inferenceNode, t);
				}
			} else if (memberDecl.Kind == KindSpreadAssignment) {
				if (Core.len(propertiesArray) > 0) {
					spread = c.getSpreadType(spread, createObjectLiteralType(), node.Symbol(), objectFlags, inConstContext);
					propertiesArray = null;
					propertiesTable = new SymbolTable();
					hasComputedStringProperty = false;
					hasComputedNumberProperty = false;
					hasComputedSymbolProperty = false;
				}
				final t = c.getReducedType(c.checkExpressionEx(memberDecl.Expression(), checkMode & CheckModeInferential));
				if (c.isValidSpreadType(t)) {
					final mergedType = c.tryMergeUnionOfObjectTypeAndEmptyObject(t, inConstContext);
					if (allPropertiesTable != null) {
						c.checkSpreadPropOverrides(mergedType, allPropertiesTable, memberDecl);
					}
					offset = Core.len(propertiesArray);
					if (c.isErrorType(spread)) {
						continue;
					}
					spread = c.getSpreadType(spread, mergedType, node.Symbol(), objectFlags, inConstContext);
				} else {
					c.error(memberDecl, Diagnostics.Spread_types_may_only_be_created_from_object_types);
					spread = c.errorType;
				}
				continue;
			} else {
				// TypeScript 1.0 spec (April 2014)
				// A get accessor declaration is processed in the same manner as
				// an ordinary function declaration(section 6.1) with no parameters.
				// A set accessor declaration is processed in the same manner
				// as an ordinary function declaration with a single parameter and a Void return type.
				Debug.Assert(memberDecl.Kind == KindGetAccessor || memberDecl.Kind == KindSetAccessor);
				c.checkNodeDeferred(memberDecl);
			}
			if (computedNameType != null && (computedNameType.flags & TypeFlagsStringOrNumberLiteralOrUnique) == 0) {
				if (c.isTypeAssignableTo(computedNameType, c.stringNumberSymbolType)) {
					if (c.isTypeAssignableTo(computedNameType, c.numberType)) {
						hasComputedNumberProperty = true;
					} else if (c.isTypeAssignableTo(computedNameType, c.esSymbolType)) {
						hasComputedSymbolProperty = true;
					} else {
						hasComputedStringProperty = true;
					}
					if (inDestructuringPattern) {
						patternWithComputedProperties = true;
					}
				}
			} else {
				propertiesTable.set(member.Name, member);
			}
			if (propertiesArray == null) {
				propertiesArray = [];
			}
			propertiesArray.push(member);
		}
		c.popContextualType();
		if (c.isErrorType(spread)) {
			return c.errorType;
		}
		if (spread != c.emptyObjectType) {
			if (Core.len(propertiesArray) > 0) {
				spread = c.getSpreadType(spread, createObjectLiteralType(), node.Symbol(), objectFlags, inConstContext);
				propertiesArray = null;
				propertiesTable = new SymbolTable();
				hasComputedStringProperty = false;
				hasComputedNumberProperty = false;
			}
			// remap the raw emptyObjectType fed in at the top into a fresh empty object literal type, unique to this use site
			return c.mapType(spread, function(t:Type):Type {
				if (t == c.emptyObjectType) {
					return createObjectLiteralType();
				}
				return t;
			});
		}
		return createObjectLiteralType();
	}

	static function checkSpreadPropOverrides(c:Checker, t:Type, props:SymbolTable, spread:Node):Void {
		for (right in rangeOf(c.getPropertiesOfType(t))) {
			if ((right.Flags & SymbolFlagsOptional) == 0 && (right.CheckFlags & CheckFlagsPartial) == 0) {
				final left = symbolTableGet(props, right.Name);
				if (left != null) {
					final diagnostic = c.error(left.ValueDeclaration, Diagnostics.X_0_is_specified_more_than_once_so_this_usage_will_be_overwritten, left.Name);
					diagnostic.AddRelatedInfo(Checker.NewDiagnosticForNode(spread, Diagnostics.This_spread_always_overwrites_this_property));
				}
			}
		}
	}

	/**
	 * Since the source of spread types are object literals, which are not binary,
	 * this function should be called in a left folding style, with left = previous result of getSpreadType
	 * and right = the new element to be spread.
	 */
	static function getSpreadType(c:Checker, left:Type, right:Type, symbol:Symbol, objectFlags:ObjectFlags, readonly:Bool):Type {
		if ((left.flags & TypeFlagsAny) != 0 || (right.flags & TypeFlagsAny) != 0) {
			return c.anyType;
		}
		if ((left.flags & TypeFlagsUnknown) != 0 || (right.flags & TypeFlagsUnknown) != 0) {
			return c.unknownType;
		}
		if ((left.flags & TypeFlagsNever) != 0) {
			return right;
		}
		if ((right.flags & TypeFlagsNever) != 0) {
			return left;
		}
		left = c.tryMergeUnionOfObjectTypeAndEmptyObject(left, readonly);
		if ((left.flags & TypeFlagsUnion) != 0) {
			if (c.checkCrossProductUnion([left, right])) {
				return c.mapType(left, function(t:Type):Type {
					return c.getSpreadType(t, right, symbol, objectFlags, readonly);
				});
			}
			return c.errorType;
		}
		right = c.tryMergeUnionOfObjectTypeAndEmptyObject(right, readonly);
		if ((right.flags & TypeFlagsUnion) != 0) {
			if (c.checkCrossProductUnion([left, right])) {
				return c.mapType(right, function(t:Type):Type {
					return c.getSpreadType(left, t, symbol, objectFlags, readonly);
				});
			}
			return c.errorType;
		}
		if ((right.flags & (TypeFlagsBooleanLike | TypeFlagsNumberLike | TypeFlagsBigIntLike | TypeFlagsStringLike | TypeFlagsEnumLike | TypeFlagsNonPrimitive | TypeFlagsIndex)) != 0) {
			return left;
		}
		if (c.isGenericObjectType(left) || c.isGenericObjectType(right)) {
			if (c.isEmptyObjectType(left)) {
				return right;
			}
			// When the left type is an intersection, we may need to merge the last constituent of the
			// intersection with the right type. For example when the left type is 'T & { a: string }'
			// and the right type is '{ b: string }' we produce 'T & { a: string, b: string }'.
			if ((left.flags & TypeFlagsIntersection) != 0) {
				final types = left.Types();
				final lastLeft = types[types.length - 1];
				if (c.isNonGenericObjectType(lastLeft) && c.isNonGenericObjectType(right)) {
					final newTypes = types.copy();
					newTypes[newTypes.length - 1] = c.getSpreadType(lastLeft, right, symbol, objectFlags, readonly);
					return c.getIntersectionType(newTypes);
				}
			}
			return c.getIntersectionType([left, right]);
		}
		final members = new SymbolTable();
		final skippedPrivateMembers = new Set<std.String>();
		var indexInfos:Array<IndexInfo> = null;
		if (left == c.emptyObjectType) {
			indexInfos = c.getIndexInfosOfType(right);
		} else {
			indexInfos = c.getUnionIndexInfos([left, right]);
		}
		for (rightProp in rangeOf(c.getPropertiesOfType(right))) {
			if ((Checker.getDeclarationModifierFlagsFromSymbol(rightProp) & (ModifierFlagsPrivate | ModifierFlagsProtected)) != 0) {
				skippedPrivateMembers.Add(rightProp.Name);
			} else if (c.isSpreadableProperty(rightProp)) {
				members.set(rightProp.Name, c.getSpreadSymbol(rightProp, readonly));
			}
		}

		for (leftProp in rangeOf(c.getPropertiesOfType(left))) {
			if (skippedPrivateMembers.Has(leftProp.Name) || !c.isSpreadableProperty(leftProp)) {
				continue;
			}
			if (members.get(leftProp.Name) != null) {
				final rightProp = members.get(leftProp.Name);
				final rightType = c.getTypeOfSymbol(rightProp);
				if ((rightProp.Flags & SymbolFlagsOptional) != 0) {
					final declarations = Core.Concatenate(leftProp.Declarations, rightProp.Declarations);
					final flags = SymbolFlagsProperty | (leftProp.Flags & SymbolFlagsOptional);
					final result = c.newSymbol(flags, leftProp.Name);
					final links = c.valueSymbolLinks.Get(result);
					// Optimization: avoid calculating the union type if spreading into the exact same type.
					// This is common, e.g. spreading one options bag into another where the bags have the
					// same type, or have properties which overlap. If the unions are large, it may turn out
					// to be expensive to perform subtype reduction.
					final leftType = c.getTypeOfSymbol(leftProp);
					final leftTypeWithoutUndefined = c.removeMissingOrUndefinedType(leftType);
					final rightTypeWithoutUndefined = c.removeMissingOrUndefinedType(rightType);
					if (leftTypeWithoutUndefined == rightTypeWithoutUndefined) {
						links.resolvedType = leftType;
					} else {
						links.resolvedType = c.getUnionTypeEx([leftType, rightTypeWithoutUndefined], UnionReductionSubtype, null, null);
					}
					c.spreadLinks.Get(result).leftSpread = leftProp;
					c.spreadLinks.Get(result).rightSpread = rightProp;
					result.Declarations = declarations;
					links.nameType = c.valueSymbolLinks.Get(leftProp).nameType;
					members.set(leftProp.Name, result);
				}
			} else {
				members.set(leftProp.Name, c.getSpreadSymbol(leftProp, readonly));
			}
		}
		final spreadIndexInfos = Core.SameMap(indexInfos, function(info:IndexInfo):IndexInfo {
			return c.getIndexInfoWithReadonly(info, readonly);
		});
		final spread = c.newAnonymousType(symbol, members, null, null, spreadIndexInfos);
		spread.objectFlags |= ObjectFlagsObjectLiteral | ObjectFlagsContainsObjectOrArrayLiteral | ObjectFlagsContainsSpread | objectFlags;
		return spread;
	}

	static function getIndexInfoWithReadonly(c:Checker, info:IndexInfo, readonly:Bool):IndexInfo {
		if (info.isReadonly != readonly) {
			return c.newIndexInfo(info.keyType, info.valueType, readonly, info.declaration, info.components);
		}
		return info;
	}

	static function isValidSpreadType(c:Checker, t:Type):Bool {
		final s = c.removeDefinitelyFalsyTypes(c.mapType(t, t -> c.getBaseConstraintOrType(t)));
		return (s.flags & (TypeFlagsAny | TypeFlagsNonPrimitive | TypeFlagsObject | TypeFlagsInstantiableNonPrimitive)) != 0
			|| (s.flags & TypeFlagsUnionOrIntersection) != 0 && Core.Every(s.Types(), t -> c.isValidSpreadType(t));
	}

	static function getUnionIndexInfos(c:Checker, types:Array<Type>):Array<IndexInfo> {
		final sourceInfos = c.getIndexInfosOfType(types[0]);
		var result:Array<IndexInfo> = null;
		for (info in rangeOf(sourceInfos)) {
			final indexType = info.keyType;
			if (Core.Every(types, function(t:Type):Bool {
				return c.getIndexInfoOfType(t, indexType) != null;
			})) {
				final valueType = c.getUnionType(Core.Map(types, function(t:Type):Type {
					return c.getIndexTypeOfType(t, indexType);
				}));
				final isReadonly = Core.Some(types, function(t:Type):Bool {
					return c.getIndexInfoOfType(t, indexType).isReadonly;
				});
				if (result == null) {
					result = [];
				}
				result.push(c.newIndexInfo(indexType, valueType, isReadonly, null, null));
			}
		}
		return result;
	}

	static function isNonGenericObjectType(c:Checker, t:Type):Bool {
		return (t.flags & TypeFlagsObject) != 0 && !c.isGenericMappedType(t);
	}

	static function tryMergeUnionOfObjectTypeAndEmptyObject(c:Checker, t:Type, readonly:Bool):Type {
		if ((t.flags & TypeFlagsUnion) == 0) {
			return t;
		}
		if (Core.Every(t.Types(), t -> c.isEmptyObjectTypeOrSpreadsIntoEmptyObject(t))) {
			final empty = Core.Find(t.Types(), t -> c.isEmptyObjectType(t));
			if (empty != null) {
				return empty;
			}
			return c.emptyObjectType;
		}
		final firstType = Core.Find(t.Types(), function(t:Type):Bool {
			return !c.isEmptyObjectTypeOrSpreadsIntoEmptyObject(t);
		});
		if (firstType == null) {
			return t;
		}
		final secondType = Core.Find(t.Types(), function(t:Type):Bool {
			return t != firstType && !c.isEmptyObjectTypeOrSpreadsIntoEmptyObject(t);
		});
		if (secondType != null) {
			return t;
		}
		// gets the type as if it had been spread, but where everything in the spread is made optional
		final members = new SymbolTable();
		for (prop in rangeOf(c.getPropertiesOfType(firstType))) {
			if ((Checker.getDeclarationModifierFlagsFromSymbol(prop) & (ModifierFlagsPrivate | ModifierFlagsProtected)) != 0) {
				// do nothing, skip privates
			} else if (c.isSpreadableProperty(prop)) {
				final isSetonlyAccessor = (prop.Flags & SymbolFlagsSetAccessor) != 0 && (prop.Flags & SymbolFlagsGetAccessor) == 0;
				final flags = SymbolFlagsProperty | SymbolFlagsOptional;
				final result = c.newSymbolEx(flags, prop.Name, (prop.CheckFlags & CheckFlagsLate) | Core.IfElse(readonly, CheckFlagsReadonly, (0 : CheckFlags)));
				final links = c.valueSymbolLinks.Get(result);
				if (isSetonlyAccessor) {
					links.resolvedType = c.undefinedType;
				} else {
					links.resolvedType = c.addOptionalityEx(c.getTypeOfSymbol(prop), true /*isProperty*/, true /*isOptional*/);
				}
				result.Declarations = prop.Declarations;
				links.nameType = c.valueSymbolLinks.Get(prop).nameType;
				c.mappedSymbolLinks.Get(result).syntheticOrigin = prop;
				members.set(prop.Name, result);
			}
		}
		final spread = c.newAnonymousType(firstType.symbol, members, null, null, c.getIndexInfosOfType(firstType));
		spread.objectFlags |= ObjectFlagsObjectLiteral | ObjectFlagsContainsObjectOrArrayLiteral;
		return spread;
	}

	// We approximate own properties as non-methods plus methods that are inside the object literal
	static function isSpreadableProperty(c:Checker, prop:Symbol):Bool {
		return !Core.Some(prop.Declarations, d -> Ast.IsPrivateIdentifierClassElementDeclaration(d))
			&& (prop.Flags & (SymbolFlagsMethod | SymbolFlagsGetAccessor | SymbolFlagsSetAccessor)) == 0
			|| !Core.Some(prop.Declarations, function(d:Node):Bool {
				return d.Parent != null && Ast.IsClassLike(d.Parent);
			});
	}

	static function getSpreadSymbol(c:Checker, prop:Symbol, readonly:Bool):Symbol {
		final isSetonlyAccessor = (prop.Flags & SymbolFlagsSetAccessor) != 0 && (prop.Flags & SymbolFlagsGetAccessor) == 0;
		if (!isSetonlyAccessor && readonly == c.isReadonlySymbol(prop)) {
			return prop;
		}
		final flags = SymbolFlagsProperty | (prop.Flags & SymbolFlagsOptional);
		final result = c.newSymbolEx(flags, prop.Name, (prop.CheckFlags & CheckFlagsLate) | Core.IfElse(readonly, CheckFlagsReadonly, (0 : CheckFlags)));
		final links = c.valueSymbolLinks.Get(result);
		if (isSetonlyAccessor) {
			links.resolvedType = c.undefinedType;
		} else {
			links.resolvedType = c.getTypeOfSymbol(prop);
		}
		result.Declarations = prop.Declarations;
		links.nameType = c.valueSymbolLinks.Get(prop).nameType;
		c.mappedSymbolLinks.Get(result).syntheticOrigin = prop;
		return result;
	}

	static function isEmptyObjectTypeOrSpreadsIntoEmptyObject(c:Checker, t:Type):Bool {
		return c.isEmptyObjectType(t)
			|| (t.flags & (TypeFlagsNull | TypeFlagsUndefined | TypeFlagsBooleanLike | TypeFlagsNumberLike | TypeFlagsBigIntLike | TypeFlagsStringLike
				| TypeFlagsEnumLike | TypeFlagsNonPrimitive | TypeFlagsIndex)) != 0;
	}

	static function hasDefaultValue(c:Checker, node:Node):Bool {
		return Ast.IsBindingElement(node) && node.Initializer() != null
			|| Ast.IsPropertyAssignment(node) && c.hasDefaultValue(node.Initializer())
			|| Ast.IsShorthandPropertyAssignment(node) && node.AsShorthandPropertyAssignment().ObjectAssignmentInitializer != null
			|| Ast.IsBinaryExpression(node) && node.AsBinaryExpression().OperatorToken.Kind == KindEqualsToken;
	}

	static function isConstContext(c:Checker, node:Node):Bool {
		final parent = node.Parent;
		return Ast.IsConstAssertion(parent)
			|| c.isValidConstAssertionArgument(node) && c.isConstTypeVariable(c.getContextualType(node, ContextFlagsNone), 0)
			|| (Ast.IsParenthesizedExpression(parent) || Ast.IsArrayLiteralExpression(parent) || Ast.IsSpreadElement(parent)) && c.isConstContext(parent)
			|| (Ast.IsPropertyAssignment(parent) || Ast.IsShorthandPropertyAssignment(parent) || Ast.IsTemplateSpan(parent)) && c.isConstContext(parent.Parent);
	}

	static function isValidConstAssertionArgument(c:Checker, node:Node):Bool {
		switch (node.Kind) {
			case KindStringLiteral | KindNoSubstitutionTemplateLiteral | KindNumericLiteral | KindBigIntLiteral | KindTrueKeyword | KindFalseKeyword
				| KindArrayLiteralExpression | KindObjectLiteralExpression | KindTemplateExpression:
				return true;
			case KindParenthesizedExpression:
				return c.isValidConstAssertionArgument(node.Expression());
			case KindPrefixUnaryExpression:
				final op = node.AsPrefixUnaryExpression().Operator;
				final arg = node.AsPrefixUnaryExpression().Operand;
				return op == KindMinusToken && (arg.Kind == KindNumericLiteral || arg.Kind == KindBigIntLiteral)
					|| op == KindPlusToken && arg.Kind == KindNumericLiteral;
			case KindPropertyAccessExpression | KindElementAccessExpression:
				final expr = Ast.SkipParentheses(node.Expression());
				var symbol:Symbol = null;
				if (Ast.IsEntityNameExpression(expr)) {
					symbol = c.resolveEntityName(expr, SymbolFlagsValue, true /*ignoreErrors*/, false, null);
				}
				return symbol != null && (symbol.Flags & SymbolFlagsEnum) != 0;
			default:
		}
		return false;
	}

	static function isConstTypeVariable(c:Checker, t:Type, depth:Int):Bool {
		if (depth >= 5 || t == null) {
			return false;
		}
		if ((t.flags & TypeFlagsTypeParameter) != 0) {
			return t.symbol != null && Core.Some(t.symbol.Declarations, d -> Ast.HasSyntacticModifier(d, ModifierFlagsConst));
		} else if ((t.flags & TypeFlagsUnionOrIntersection) != 0) {
			return Core.Some(t.Types(), s -> c.isConstTypeVariable(s, depth));
		} else if ((t.flags & TypeFlagsIndexedAccess) != 0) {
			return c.isConstTypeVariable(t.AsIndexedAccessType().objectType, depth + 1);
		} else if ((t.flags & TypeFlagsConditional) != 0) {
			return c.isConstTypeVariable(c.getConstraintOfConditionalType(t), depth + 1);
		} else if ((t.flags & TypeFlagsSubstitution) != 0) {
			return c.isConstTypeVariable(t.AsSubstitutionType().baseType, depth);
		} else if ((t.objectFlags & ObjectFlagsMapped) != 0) {
			final typeVariable = c.getHomomorphicTypeVariable(t);
			return typeVariable != null && c.isConstTypeVariable(typeVariable, depth);
		} else if (c.isGenericTupleType(t)) {
			final elementTypes = rangeOf(c.getElementTypes(t));
			for (i in 0...elementTypes.length) {
				final s = elementTypes[i];
				if ((t.TargetTupleType().elementInfos[i].flags & ElementFlagsVariadic) != 0 && c.isConstTypeVariable(s, depth)) {
					return true;
				}
			}
		}
		return false;
	}

	static function checkPropertyAssignment(c:Checker, node:Node, checkMode:CheckMode):Type {
		// Do not use hasDynamicName here, because that returns false for well known symbols.
		// We want to perform checkComputedPropertyName for all computed properties, including
		// well known symbols.
		if (Ast.IsComputedPropertyName(node.Name())) {
			c.checkComputedPropertyName(node.Name());
		}
		final initializerType = c.checkExpressionForMutableLocation(node.Initializer(), checkMode);
		if (node.Type() != null) {
			final t = c.getTypeFromTypeNode(node.Type());
			c.checkTypeAssignableToAndOptionallyElaborate(initializerType, t, node, node.Initializer(), null /*headMessage*/, null);
			return t;
		}
		return initializerType;
	}

	static function checkShorthandPropertyAssignment(c:Checker, node:Node, inDestructuringPattern:Bool, checkMode:CheckMode):Type {
		var expr:Node = null;
		if (!inDestructuringPattern) {
			expr = node.AsShorthandPropertyAssignment().ObjectAssignmentInitializer;
		}
		if (expr == null) {
			expr = node.Name();
		}
		final expressionType = c.checkExpressionForMutableLocation(expr, checkMode);
		if (node.Type() != null) {
			final t = c.getTypeFromTypeNode(node.Type());
			c.checkTypeAssignableToAndOptionallyElaborate(expressionType, t, node, expr, null /*headMessage*/, null);
			return t;
		}
		return expressionType;
	}

	static function isInPropertyInitializerOrClassStaticBlock(c:Checker, node:Node, ignoreArrowFunctions:Bool):Bool {
		return Ast.FindAncestorOrQuit(node, function(node:Node):ts.ast.Utilities.FindAncestorResult {
			switch (node.Kind) {
				case KindPropertyDeclaration | KindClassStaticBlockDeclaration:
					return FindAncestorTrue;
				case KindTypeQuery | KindJsxClosingElement:
					return FindAncestorQuit;
				case KindArrowFunction:
					return Core.IfElse(ignoreArrowFunctions, FindAncestorFalse, FindAncestorQuit);
				case KindBlock:
					return Core.IfElse(Ast.IsFunctionLikeDeclaration(node.Parent) && node.Parent.Kind != KindArrowFunction, FindAncestorQuit, FindAncestorFalse);
				default:
					return FindAncestorFalse;
			}
		}) != null;
	}

	static function getNarrowedTypeOfSymbol(c:Checker, symbol:Symbol, location:Node):Type {
		var t = c.getTypeOfSymbol(symbol);
		final declaration = symbol.ValueDeclaration;
		if (declaration != null) {
			// If we have a non-rest binding element with no initializer declared as a const variable or a const-like
			// parameter (a parameter for which there are no assignments in the function body), and if the parent type
			// for the destructuring is a union type, one or more of the binding elements may represent discriminant
			// properties, and we want the effects of conditional checks on such discriminants to affect the types of
			// other binding elements from the same destructuring. Consider:
			//
			//   type Action =
			//       | { kind: 'A', payload: number }
			//       | { kind: 'B', payload: string };
			//
			//   function f({ kind, payload }: Action) {
			//       if (kind === 'A') {
			//           payload.toFixed();
			//       }
			//       if (kind === 'B') {
			//           payload.toUpperCase();
			//       }
			//   }
			//
			// Above, we want the conditional checks on 'kind' to affect the type of 'payload'. To facilitate this, we use
			// the binding pattern AST instance for '{ kind, payload }' as a pseudo-reference and narrow this reference
			// as if it occurred in the specified location. We then recompute the narrowed binding element type by
			// destructuring from the narrowed parent type.
			if (Ast.IsBindingElement(declaration) && declaration.Initializer() == null && !Checker.hasDotDotDotToken(declaration)
				&& Core.len(declaration.Parent.Elements()) >= 2) {
				final parent = declaration.Parent.Parent;
				final rootDeclaration = Ast.GetRootDeclaration(parent);
				if (Ast.IsVariableDeclaration(rootDeclaration) && (c.getCombinedNodeFlagsCached(rootDeclaration) & NodeFlagsConstant) != 0
					|| Ast.IsParameterDeclaration(rootDeclaration)) {
					final links = c.nodeLinks.Get(parent);
					if ((links.flags & NodeCheckFlagsInCheckIdentifier) == 0) {
						links.flags |= NodeCheckFlagsInCheckIdentifier;
						final parentType = c.getTypeForBindingElementParent(parent, CheckModeNormal);
						var parentTypeConstraint:Type = null;
						if (parentType != null) {
							parentTypeConstraint = c.mapType(parentType, t -> c.getBaseConstraintOrType(t));
						}
						if (parentTypeConstraint != null && (parentTypeConstraint.flags & TypeFlagsUnion) != 0
							&& !(Ast.IsParameterDeclaration(rootDeclaration) && c.isSomeSymbolAssigned(rootDeclaration))) {
							final pattern = declaration.Parent;
							final narrowedType = c.getFlowTypeOfReferenceEx(pattern, parentTypeConstraint, parentTypeConstraint, null /*flowContainer*/,
								Checker.getFlowNodeOfNode(location));
							if ((narrowedType.flags & TypeFlagsNever) != 0) {
								t = c.neverType;
							} else {
								// Destructurings are validated against the parent type elsewhere. Here we disable tuple bounds
								// checks because the narrowed type may have lower arity than the full parent type. For example,
								// for the declaration [x, y]: [1, 2] | [3], we may have narrowed the parent type to just [3].
								t = c.getBindingElementTypeFromParentType(declaration, narrowedType, true /*noTupleBoundsCheck*/);
							}
						}
						links.flags &= ~NodeCheckFlagsInCheckIdentifier;
					}
				}
				// If we have a const-like parameter with no type annotation or initializer, and if the parameter is contextually
				// typed by a signature with a single rest parameter of a union of tuple types, one or more of the parameters may
				// represent discriminant tuple elements, and we want the effects of conditional checks on such discriminants to
				// affect the types of other parameters in the same parameter list. Consider:
				//
				//   type Action = [kind: 'A', payload: number] | [kind: 'B', payload: string];
				//
				//   const f: (...args: Action) => void = (kind, payload) => {
				//       if (kind === 'A') {
				//           payload.toFixed();
				//       }
				//       if (kind === 'B') {
				//           payload.toUpperCase();
				//       }
				//   }
				//
				// Above, we want the conditional checks on 'kind' to affect the type of 'payload'. To facilitate this, we use
				// the arrow function AST node for '(kind, payload) => ...' as a pseudo-reference and narrow this reference as
				// if it occurred in the specified location. We then recompute the narrowed parameter type by indexing into the
				// narrowed tuple type.
			} else if (Ast.IsParameterDeclaration(declaration) && declaration.Type() == null && declaration.Initializer() == null
				&& !Checker.hasDotDotDotToken(declaration)) {
				final fn = declaration.Parent;
				if (Core.len(fn.Parameters()) >= 2 && c.isContextSensitiveFunctionOrObjectLiteralMethod(fn)) {
					final contextualSignature = c.getContextualSignature(fn);
					if (contextualSignature != null && Core.len(contextualSignature.parameters) == 1 && Checker.signatureHasRestParameter(contextualSignature)) {
						var mapper:TypeMapper = null;
						final context = c.getInferenceContext(fn);
						if (context != null) {
							mapper = context.nonFixingMapper;
						}
						final restType = c.getReducedApparentType(c.instantiateType(c.getTypeOfSymbol(contextualSignature.parameters[0]), mapper));
						if ((restType.flags & TypeFlagsUnion) != 0 && Checker.everyType(restType, Checker.isTupleType)
							&& !Core.Some(fn.Parameters(), p -> c.isSomeSymbolAssigned(p))) {
							final narrowedType = c.getFlowTypeOfReferenceEx(fn, restType, restType, null /*flowContainer*/, Checker.getFlowNodeOfNode(location));
							final index = Slices.Index(fn.Parameters(), declaration) - Core.IfElse(Ast.GetThisParameter(fn) != null, 1, 0);
							t = c.getIndexedAccessType(narrowedType, c.getNumberLiteralType((index : Float)));
						}
					}
				}
			}
		}
		return t;
	}

	static function isReadonlyAssignmentDeclaration(c:Checker, node:Node):Bool {
		if (!Ast.IsCallExpression(node)) {
			return false;
		}
		final propertyDescriptorType = c.checkExpressionCached(node.Arguments()[2]);
		final valueType = c.getTypeOfPropertyOfType(propertyDescriptorType, "value");
		if (valueType != null) {
			final writableProp = c.getPropertyOfType(propertyDescriptorType, "writable");
			if (writableProp != null) {
				var writableType:Type = null;
				if (writableProp.ValueDeclaration != null && Ast.IsPropertyAssignment(writableProp.ValueDeclaration)) {
					writableType = c.checkExpression(writableProp.ValueDeclaration.Initializer());
				} else {
					writableType = c.getTypeOfSymbol(writableProp);
				}
				return (writableType.flags & TypeFlagsBooleanLiteral) != 0 && Checker.getBooleanLiteralValue(writableType) == false;
			}
			return true;
		}
		return c.getTypeOfPropertyOfType(propertyDescriptorType, "set") == null;
	}

	static function isReadonlySymbol(c:Checker, symbol:Symbol):Bool {
		// The following symbols are considered read-only:
		// Properties with a 'readonly' modifier
		// Variables declared with 'const'
		// Get accessors without matching set accessors
		// Enum members
		// Object.defineProperty assignments with writable false or no setter
		// Unions and intersections of the above (unions and intersections eagerly set isReadonly on creation)
		return (symbol.CheckFlags & CheckFlagsReadonly) != 0
			|| (symbol.Flags & SymbolFlagsProperty) != 0 && (Checker.getDeclarationModifierFlagsFromSymbol(symbol) & ModifierFlagsReadonly) != 0
			|| (symbol.Flags & SymbolFlagsVariable) != 0 && (c.getDeclarationNodeFlagsFromSymbol(symbol) & NodeFlagsConstant) != 0
			|| (symbol.Flags & SymbolFlagsAccessor) != 0 && (symbol.Flags & SymbolFlagsSetAccessor) == 0
			|| (symbol.Flags & SymbolFlagsEnumMember) != 0
			|| Core.Some(symbol.Declarations, d -> c.isReadonlyAssignmentDeclaration(d));
	}

	static function checkObjectLiteralMethod(c:Checker, node:Node, checkMode:CheckMode):Type {
		// Grammar checking
		c.checkGrammarMethod(node);
		// Do not use hasDynamicName here, because that returns false for well known symbols.
		// We want to perform checkComputedPropertyName for all computed properties, including
		// well known symbols.
		if (Ast.IsComputedPropertyName(node.Name())) {
			c.checkComputedPropertyName(node.Name());
		}
		final uninstantiatedType = c.checkFunctionExpressionOrObjectLiteralMethod(node, checkMode);
		return c.instantiateTypeWithSingleGenericCallSignature(node, uninstantiatedType, checkMode);
	}

	static function checkExpressionForMutableLocation(c:Checker, node:Node, checkMode:CheckMode):Type {
		final t = c.checkExpressionEx(node, checkMode);
		if (c.isConstContext(node)) {
			return c.getRegularTypeOfLiteralType(t);
		} else if (Checker.isTypeAssertion(node)) {
			return t;
		} else {
			return c.getWidenedLiteralLikeTypeForContextualType(t,
				c.instantiateContextualType(c.getContextualType(node, ContextFlagsNone), node, ContextFlagsNone));
		}
	}

	static function getResolvedSymbol(c:Checker, node:Node):Symbol {
		final links = c.symbolNodeLinks.Get(node);
		if (links.resolvedSymbol == null) {
			var symbol:Symbol = null;
			if (!Ast.NodeIsMissing(node)) {
				symbol = c.resolveName(node, node.Text(), SymbolFlagsValue | SymbolFlagsExportValue, c.getCannotFindNameDiagnosticForName(node),
					!Ast.IsWriteOnlyAccess(node), false /*excludeGlobals*/);
			}
			links.resolvedSymbol = Core.OrElse(symbol, c.unknownSymbol);
		}
		return links.resolvedSymbol;
	}

	static function getResolvedSymbolOrNil(c:Checker, node:Node):Symbol {
		return c.symbolNodeLinks.Get(node).resolvedSymbol;
	}

	static function getReferencedValueOrAliasSymbol(c:Checker, reference:Node):Symbol {
		final resolvedSymbol = c.symbolNodeLinks.Get(reference).resolvedSymbol;
		if (resolvedSymbol != null && resolvedSymbol != c.unknownSymbol) {
			return resolvedSymbol;
		}
		return c.resolveName(reference, reference.Text(), SymbolFlagsValue | SymbolFlagsExportValue | SymbolFlagsAlias, null, true /*isUse*/,
			false /*excludeGlobals*/);
	}

	static function getCannotFindNameDiagnosticForName(c:Checker, node:Node):Message {
		switch (node.Text()) {
			case "document" | "console":
				return Diagnostics.Cannot_find_name_0_Do_you_need_to_change_your_target_library_Try_changing_the_lib_compiler_option_to_include_dom;
			case "$":
				return Core.IfElse(c.compilerOptions.UsesWildcardTypes(),
					Diagnostics.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_jQuery_Try_npm_i_save_dev_types_Slashjquery,
					Diagnostics.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_jQuery_Try_npm_i_save_dev_types_Slashjquery_and_then_add_jquery_to_the_types_field_in_your_tsconfig);
			case "beforeEach" | "describe" | "suite" | "it" | "test":
				return Core.IfElse(c.compilerOptions.UsesWildcardTypes(),
					Diagnostics.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_a_test_runner_Try_npm_i_save_dev_types_Slashjest_or_npm_i_save_dev_types_Slashmocha,
					Diagnostics.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_a_test_runner_Try_npm_i_save_dev_types_Slashjest_or_npm_i_save_dev_types_Slashmocha_and_then_add_jest_or_mocha_to_the_types_field_in_your_tsconfig);
			case "process" | "require" | "Buffer" | "module" | "NodeJS":
				return Core.IfElse(c.compilerOptions.UsesWildcardTypes(),
					Diagnostics.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_node_Try_npm_i_save_dev_types_Slashnode,
					Diagnostics.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_node_Try_npm_i_save_dev_types_Slashnode_and_then_add_node_to_the_types_field_in_your_tsconfig);
			case "Bun":
				return Core.IfElse(c.compilerOptions.UsesWildcardTypes(),
					Diagnostics.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_Bun_Try_npm_i_save_dev_types_Slashbun,
					Diagnostics.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_Bun_Try_npm_i_save_dev_types_Slashbun_and_then_add_bun_to_the_types_field_in_your_tsconfig);
			case "Map" | "Set" | "Promise" | "ast.Symbol" | "WeakMap" | "WeakSet" | "Iterator" | "AsyncIterator" | "SharedArrayBuffer" | "Atomics"
				| "AsyncIterable" | "AsyncIterableIterator" | "AsyncGenerator" | "AsyncGeneratorFunction" | "BigInt" | "Reflect" | "BigInt64Array"
				| "BigUint64Array":
				return Diagnostics.Cannot_find_name_0_Do_you_need_to_change_your_target_library_Try_changing_the_lib_compiler_option_to_1_or_later;
			case "await":
				if (Ast.IsCallExpression(node.Parent)) {
					return Diagnostics.Cannot_find_name_0_Did_you_mean_to_write_this_in_an_async_function;
				}
				// PORT: Go `fallthrough` into the default case (duplicated body).
				if (node.Parent.Kind == KindShorthandPropertyAssignment) {
					return Diagnostics.No_value_exists_in_scope_for_the_shorthand_property_0_Either_declare_one_or_provide_an_initializer;
				}
				return Diagnostics.Cannot_find_name_0;
			default:
				if (node.Parent.Kind == KindShorthandPropertyAssignment) {
					return Diagnostics.No_value_exists_in_scope_for_the_shorthand_property_0_Either_declare_one_or_provide_an_initializer;
				}
				return Diagnostics.Cannot_find_name_0;
		}
	}

	public static function GetDiagnostics(c:Checker, ctx:Context, sourceFile:SourceFile):Array<Diagnostic> {
		return c.getDiagnostics(ctx, sourceFile, c.diagnostics);
	}

	public static function GetSuggestionDiagnostics(c:Checker, ctx:Context, sourceFile:SourceFile):Array<Diagnostic> {
		return c.getDiagnostics(ctx, sourceFile, c.suggestionDiagnostics);
	}

	static function getDiagnostics(c:Checker, ctx:Context, sourceFile:SourceFile, collection:DiagnosticsCollection):Array<Diagnostic> {
		c.checkNotCanceled();
		final checkUnused = c.compilerOptions.NoUnusedLocals.IsTrue() || c.compilerOptions.NoUnusedParameters.IsTrue()
			|| collection == c.suggestionDiagnostics;
		c.checkSourceFile(ctx, sourceFile, checkUnused);
		if (c.wasCanceled) {
			return null;
		}
		return collection.GetDiagnosticsForFile(sourceFile.FileName());
	}

	public static function GetGlobalDiagnostics(c:Checker):Array<Diagnostic> {
		c.checkNotCanceled();
		return c.diagnostics.GetGlobalDiagnostics();
	}

	static function addDeferredDiagnostic(c:Checker, callback:() -> Void):Void {
		if (c.saveDeferredDiagnostics) {
			if (c.deferredDiagnosticCallbacks == null) {
				c.deferredDiagnosticCallbacks = [];
			}
			c.deferredDiagnosticCallbacks.push(callback);
		}
	}

	static function produceDeferredDiagnostics(c:Checker):Void {
		for (cb in rangeOf(c.deferredDiagnosticCallbacks)) {
			cb();
		}
		c.deferredDiagnosticCallbacks = null;
	}

	static function addDiagnostic(c:Checker, diagnostic:Diagnostic):Void {
		// Discard diagnostics created while at the maximum number of recursive TypeToString invocations.
		if (c.serializationLevel < Checker.maxSerializationLevel) {
			c.diagnostics.Add(diagnostic);
		}
	}

	static function addSuggestionDiagnostic(c:Checker, diagnostic:Diagnostic):Void {
		// Discard diagnostics created while at the maximum number of recursive TypeToString invocations.
		if (c.serializationLevel < Checker.maxSerializationLevel) {
			c.suggestionDiagnostics.Add(diagnostic);
		}
	}

	static function error(c:Checker, location:Node, message:Message, ...args:Any):Diagnostic {
		final diagnostic = Checker.NewDiagnosticForNode(location, message, ...args);
		c.addDiagnostic(diagnostic);
		return diagnostic;
	}

	static function errorSkippedOnNoEmit(c:Checker, location:Node, message:Message, ...args:Any):Diagnostic {
		final diagnostic = c.error(location, message, ...args);
		diagnostic.SetSkippedOnNoEmit();
		return diagnostic;
	}

	static function errorOrSuggestion(c:Checker, isError:Bool, location:Node, message:Message, ...args:Any):Void {
		c.addErrorOrSuggestion(isError, Checker.NewDiagnosticForNode(location, message, ...args));
	}

	static function errorAndMaybeSuggestAwait(c:Checker, location:Node, maybeMissingAwait:Bool, message:Message, ...args:Any):Diagnostic {
		final diagnostic = c.error(location, message, ...args);
		if (maybeMissingAwait) {
			diagnostic.AddRelatedInfo(Checker.createDiagnosticForNode(location, Diagnostics.Did_you_forget_to_use_await));
		}
		return diagnostic;
	}

	static function addErrorOrSuggestion(c:Checker, isError:Bool, diagnostic:Diagnostic):Void {
		if (isError) {
			c.addDiagnostic(diagnostic);
		} else {
			final suggestion = diagnostic.Clone(); // PORT: Go struct copy `*diagnostic` (Diagnostic.Clone is that copy)
			suggestion.SetCategory(CategorySuggestion);
			c.addSuggestionDiagnostic(suggestion);
		}
	}

	public static function IsDeprecatedDeclaration(c:Checker, declaration:Node):Bool {
		return Ast.IsDeprecatedDeclarationWithCachedFlags(declaration, c.getCombinedNodeFlagsCached(declaration));
	}

	static function addDeprecatedSuggestion(c:Checker, location:Node, declarations:Array<Node>, deprecatedEntity:std.String):Diagnostic {
		final diagnostic = Checker.NewDiagnosticForNode(location, Diagnostics.X_0_is_deprecated, deprecatedEntity);
		return c.addDeprecatedSuggestionWorker(declarations, diagnostic);
	}

	static function addDeprecatedSuggestionWorker(c:Checker, declarations:Array<Node>, diagnostic:Diagnostic):Diagnostic {
		for (declaration in rangeOf(declarations)) {
			final deprecatedTag = Ast.GetJSDocDeprecatedTag(declaration);
			if (deprecatedTag != null) {
				diagnostic.AddRelatedInfo(Checker.NewDiagnosticForNode(deprecatedTag, Diagnostics.The_declaration_was_marked_as_deprecated_here));
				break;
			}
		}
		c.addSuggestionDiagnostic(diagnostic);
		return diagnostic;
	}

	static function isDeprecatedSymbol(c:Checker, symbol:Symbol):Bool {
		final parentSymbol = c.getParentOfSymbol(symbol);
		if (parentSymbol != null && Core.len(symbol.Declarations) > 1) {
			if ((parentSymbol.Flags & SymbolFlagsInterface) != 0) {
				return Core.Some(symbol.Declarations, d -> c.IsDeprecatedDeclaration(d));
			} else {
				return Core.Every(symbol.Declarations, d -> c.IsDeprecatedDeclaration(d));
			}
		}
		return symbol.ValueDeclaration != null && c.IsDeprecatedDeclaration(symbol.ValueDeclaration)
			|| Core.len(symbol.Declarations) != 0 && Core.Every(symbol.Declarations, d -> c.IsDeprecatedDeclaration(d));
	}

	static function hasParseDiagnostics(c:Checker, sourceFile:SourceFile):Bool {
		return Core.len(sourceFile.Diagnostics()) > 0;
	}

	static function newSymbol(c:Checker, flags:SymbolFlags, name:std.String):Symbol {
		c.SymbolCount++;
		final result = c.symbolArena.New();
		result.Flags = flags | SymbolFlagsTransient;
		result.Name = name;
		return result;
	}

	static function newSymbolEx(c:Checker, flags:SymbolFlags, name:std.String, checkFlags:CheckFlags):Symbol {
		final result = c.newSymbol(flags, name);
		result.CheckFlags = checkFlags;
		return result;
	}

	static function newParameter(c:Checker, name:std.String, t:Type):Symbol {
		final symbol = c.newSymbol(SymbolFlagsFunctionScopedVariable, name);
		c.valueSymbolLinks.Get(symbol).resolvedType = t;
		return symbol;
	}

	static function newProperty(c:Checker, name:std.String, t:Type):Symbol {
		final symbol = c.newSymbol(SymbolFlagsProperty, name);
		c.valueSymbolLinks.Get(symbol).resolvedType = t;
		return symbol;
	}

	static function combineSymbolTables(c:Checker, first:SymbolTable, second:SymbolTable):SymbolTable {
		if (symbolTableLen(first) == 0) {
			return second;
		}
		if (symbolTableLen(second) == 0) {
			return first;
		}
		final combined = new SymbolTable();
		c.mergeSymbolTable(combined, first, false, null);
		c.mergeSymbolTable(combined, second, false, null);
		return combined;
	}

	static function mergeSymbolTable(c:Checker, target:SymbolTable, source:SymbolTable, unidirectional:Bool, mergedParent:Symbol):Void {
		// PORT: Go map iteration order is random; upstream does not depend on it (PORTING.md §3).
		if (source == null) {
			return;
		}
		for (id => sourceSymbol in source) {
			final targetSymbol = target.get(id);
			var merged:Symbol = null;
			if (targetSymbol != null) {
				merged = c.mergeSymbol(targetSymbol, sourceSymbol, unidirectional);
			} else {
				merged = c.getMergedSymbol(sourceSymbol);
			}
			if (mergedParent != null && targetSymbol != null) {
				// If a merge was performed on the target symbol, set its parent to the merged parent that initiated the merge
				// of its exports. Otherwise, `merged` came only from `sourceSymbol` and can keep its parent:
				//
				// // a.ts
				// export interface A { x: number; }
				//
				// // b.ts
				// declare module "./a" {
				//   interface A { y: number; }
				//   interface B {}
				// }
				//
				// When merging the module augmentation into a.ts, the symbol for `A` will itself be merged, so its parent
				// should be the merged module symbol. But the symbol for `B` has only one declaration, so its parent should
				// be the module augmentation symbol, which contains its only declaration.
				if ((merged.Flags & SymbolFlagsTransient) != 0) {
					merged.Parent = mergedParent;
				}
			}
			target.set(id, merged);
		}
	}

	/**
	 * Note: if target is transient, then it is mutable, and mergeSymbol with both mutate and return it.
	 * If target is not transient, mergeSymbol will produce a transient clone, mutate that and return it.
	 */
	static function mergeSymbol(c:Checker, target:Symbol, source:Symbol, unidirectional:Bool):Symbol {
		var target = target;
		if ((target.Flags & Checker.getExcludedSymbolFlags(source.Flags)) == 0 || ((source.Flags | target.Flags) & SymbolFlagsAssignment) != 0) {
			if (source == target) {
				// This can happen when an export assigned namespace exports something also erroneously exported at the top level
				// See `declarationFileNoCrashOnExtraExportModifier` for an example
				return target;
			}
			if ((target.Flags & SymbolFlagsTransient) == 0) {
				final resolvedTarget = c.resolveSymbol(target);
				if (resolvedTarget == c.unknownSymbol) {
					return source;
				}
				if ((resolvedTarget.Flags & Checker.getExcludedSymbolFlags(source.Flags)) == 0
					|| ((source.Flags | resolvedTarget.Flags) & SymbolFlagsAssignment) != 0) {
					target = c.cloneSymbol(resolvedTarget);
				} else {
					c.reportMergeSymbolError(target, source);
					return source;
				}
			}
			// Javascript static-property-assignment declarations always merge, even though they are also values
			if ((source.Flags & SymbolFlagsValueModule) != 0 && (target.Flags & SymbolFlagsValueModule) != 0
				&& (target.Flags & SymbolFlagsConstEnumOnlyModule) != 0 && (source.Flags & SymbolFlagsConstEnumOnlyModule) == 0) {
				// reset flag when merging instantiated module into value module that has only const enums
				target.Flags &= ~SymbolFlagsConstEnumOnlyModule;
			}
			var sourceFlags = source.Flags;
			if ((target.Flags & SymbolFlagsConstEnumOnlyModule) == 0) {
				sourceFlags &= ~SymbolFlagsConstEnumOnlyModule;
			}
			target.Flags |= sourceFlags;
			if (source.ValueDeclaration != null) {
				Binder.SetValueDeclaration(target, source.ValueDeclaration);
			}
			// PORT: Go `append(target.Declarations, source.Declarations...)` may share a backing array; build a new array so
			// no other holder of the old slice sees the appended elements.
			if (Core.len(source.Declarations) != 0) {
				target.Declarations = target.Declarations != null ? target.Declarations.concat(source.Declarations) : source.Declarations.copy();
			}
			if (source.Members != null) {
				final t = target;
				c.mergeSymbolTable(Ast.GetSymbolTable(() -> t.Members, m -> t.Members = m), source.Members, unidirectional, null);
			}
			if (source.Exports != null) {
				final t = target;
				c.mergeSymbolTable(Ast.GetSymbolTable(() -> t.Exports, m -> t.Exports = m), source.Exports, unidirectional, target);
			}
			if (!unidirectional) {
				c.recordMergedSymbol(target, source);
			}
		} else if ((target.Flags & SymbolFlagsNamespaceModule) != 0) {
			// Do not report an error when merging `var globalThis` with the built-in `globalThis`,
			// as we will already report a "Declaration name conflicts..." error, and this error
			// won't make much sense.
			if (target != c.globalThisSymbol) {
				c.error(Ast.GetNameOfDeclaration(Checker.getFirstDeclaration(source)),
					Diagnostics.Cannot_augment_module_0_with_value_exports_because_it_resolves_to_a_non_module_entity, c.symbolToString(target));
			}
		} else {
			c.reportMergeSymbolError(target, source);
		}
		return target;
	}

	static function reportMergeSymbolError(c:Checker, target:Symbol, source:Symbol):Void {
		final isEitherEnum = (target.Flags & SymbolFlagsEnum) != 0 || (source.Flags & SymbolFlagsEnum) != 0;
		final isEitherBlockScoped = (target.Flags & SymbolFlagsBlockScopedVariable) != 0 || (source.Flags & SymbolFlagsBlockScopedVariable) != 0;
		var message:Message = null;
		if (isEitherEnum) {
			message = Diagnostics.Enum_declarations_can_only_merge_with_namespace_or_other_enum_declarations;
		} else if (isEitherBlockScoped) {
			message = Diagnostics.Cannot_redeclare_block_scoped_variable_0;
		} else {
			message = Diagnostics.Duplicate_identifier_0;
		}
		final sourceSymbolFile = Ast.GetSourceFileOfNode(Checker.getFirstDeclaration(source));
		final targetSymbolFile = Ast.GetSourceFileOfNode(Checker.getFirstDeclaration(target));
		final isSourcePlainJS = Ast.IsPlainJSFile(sourceSymbolFile, c.compilerOptions.CheckJs);
		final isTargetPlainJS = Ast.IsPlainJSFile(targetSymbolFile, c.compilerOptions.CheckJs);
		final symbolName = c.symbolToString(source);
		if (!isSourcePlainJS) {
			c.addDuplicateDeclarationErrorsForSymbols(source, message, symbolName, target);
		}
		if (!isTargetPlainJS) {
			c.addDuplicateDeclarationErrorsForSymbols(target, message, symbolName, source);
		}
	}

	static function addDuplicateDeclarationErrorsForSymbols(c:Checker, target:Symbol, message:Message, symbolName:std.String, source:Symbol):Void {
		for (node in rangeOf(target.Declarations)) {
			c.addDuplicateDeclarationError(node, message, symbolName, source.Declarations);
		}
	}

	static function addDuplicateDeclarationError(c:Checker, node:Node, message:Message, symbolName:std.String, relatedNodes:Array<Node>):Void {
		var errorNode = Checker.getAdjustedNodeForError(node);
		if (errorNode == null) {
			errorNode = node;
		}
		final err = c.lookupOrIssueError(errorNode, message, symbolName);
		for (relatedNode in rangeOf(relatedNodes)) {
			final adjustedNode = Checker.getAdjustedNodeForError(relatedNode);
			if (adjustedNode == errorNode) {
				continue;
			}
			final leadingMessage = Checker.createDiagnosticForNode(adjustedNode, Diagnostics.X_0_was_also_declared_here, symbolName);
			final followOnMessage = Checker.createDiagnosticForNode(adjustedNode, Diagnostics.X_and_here);
			if (Core.len(err.RelatedInformation()) >= 5 || Core.Some(err.RelatedInformation(), function(d:Diagnostic):Bool {
				return Ast.CompareDiagnostics(d, followOnMessage) == 0 || Ast.CompareDiagnostics(d, leadingMessage) == 0;
			})) {
				continue;
			}
			if (Core.len(err.RelatedInformation()) == 0) {
				err.AddRelatedInfo(leadingMessage);
			} else {
				err.AddRelatedInfo(followOnMessage);
			}
		}
	}

	static function lookupOrIssueError(c:Checker, location:Node, message:Message, ...args:Any):Diagnostic {
		final diagnostic = Checker.NewDiagnosticForNode(location, message, ...args);
		final existing = c.diagnostics.Lookup(diagnostic);
		if (existing != null) {
			return existing;
		}
		c.addDiagnostic(diagnostic);
		return diagnostic;
	}

	static function cloneSymbol(c:Checker, symbol:Symbol):Symbol {
		final result = c.newSymbol(symbol.Flags, symbol.Name);
		// Force reallocation if anything is ever appended to declarations
		// PORT: Go full slice expression `s[0:len:len]`; mergeSymbol builds a new array on append, so sharing is safe.
		result.Declarations = symbol.Declarations;
		result.Parent = symbol.Parent;
		result.ValueDeclaration = symbol.ValueDeclaration;
		result.Members = symbol.Members != null ? symbol.Members.copy() : null;
		result.Exports = symbol.Exports != null ? symbol.Exports.copy() : null;
		c.recordMergedSymbol(result, symbol);
		return result;
	}

	static function getMergedSymbol(c:Checker, symbol:Symbol):Symbol {
		if (symbol != null) {
			final merged = c.mergedSymbols.get(symbol);
			if (merged != null) {
				return merged;
			}
		}
		return symbol;
	}

	static function getParentOfSymbol(c:Checker, symbol:Symbol):Symbol {
		if (symbol.Parent != null) {
			return c.getMergedSymbol(c.getLateBoundSymbol(symbol.Parent));
		}
		return null;
	}

	static function recordMergedSymbol(c:Checker, target:Symbol, source:Symbol):Void {
		c.mergedSymbols.set(source, target);
	}

	static function getSymbolIfSameReference(c:Checker, s1:Symbol, s2:Symbol):Symbol {
		if (c.getMergedSymbol(c.resolveSymbol(c.getMergedSymbol(s1))) == c.getMergedSymbol(c.resolveSymbol(c.getMergedSymbol(s2)))) {
			return s1;
		}
		return null;
	}

	static function getExportSymbolOfValueSymbolIfExported(c:Checker, symbol:Symbol):Symbol {
		if (symbol != null && (symbol.Flags & SymbolFlagsExportValue) != 0 && symbol.ExportSymbol != null) {
			symbol = symbol.ExportSymbol;
		}
		return c.getMergedSymbol(symbol);
	}

	static function getSymbolOfDeclaration(c:Checker, node:Node):Symbol {
		final symbol = node.Symbol();
		if (symbol != null) {
			return c.getMergedSymbol(c.getLateBoundSymbol(symbol));
		}
		return null;
	}

	// Get the merged symbol for a node. If you know the node is a `Declaration`, it is more type safe to
	// use use `getSymbolOfDeclaration` instead.
	static function getSymbolOfNode(c:Checker, node:Node):Symbol {
		final data = node.DeclarationData();
		if (data != null && data.Symbol != null) {
			return c.getMergedSymbol(c.getLateBoundSymbol(data.Symbol));
		}
		return null;
	}

	static function getLateBoundSymbol(c:Checker, symbol:Symbol):Symbol {
		if ((symbol.Flags & SymbolFlagsClassMember) == 0 || symbol.Name != Ast.InternalSymbolNameComputed) {
			return symbol;
		}
		final links = c.lateBoundLinks.Get(symbol);
		if (links.lateSymbol == null && Core.Some(symbol.Declarations, d -> c.hasLateBindableName(d))) {
			// force late binding of members/exports. This will set the late-bound symbol
			final parent = c.getMergedSymbol(symbol.Parent);
			if (Core.Some(symbol.Declarations, Ast.HasStaticModifier)) {
				c.getExportsOfSymbol(parent);
			} else {
				c.getMembersOfSymbol(parent);
			}
		}
		if (links.lateSymbol == null) {
			links.lateSymbol = symbol;
		}
		return links.lateSymbol;
	}

	static function resolveSymbol(c:Checker, symbol:Symbol):Symbol {
		return c.resolveSymbolEx(symbol, false /*dontResolveAlias*/);
	}

	static function resolveSymbolEx(c:Checker, symbol:Symbol, dontResolveAlias:Bool):Symbol {
		if (!dontResolveAlias && Ast.IsNonLocalAlias(symbol, SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace)) {
			return c.resolveAlias(symbol);
		}
		return symbol;
	}

	static function getTargetOfImportEqualsDeclaration(c:Checker, node:Node):Symbol {
		// Node is ImportEqualsDeclaration | VariableDeclaration
		if (Ast.IsVariableDeclaration(node) || node.AsImportEqualsDeclaration().ModuleReference.Kind == KindExternalModuleReference) {
			var moduleReference = Checker.getExternalModuleRequireArgument(node);
			if (moduleReference == null) {
				moduleReference = Ast.GetExternalModuleImportEqualsDeclarationExpression(node);
			}
			final immediate = c.resolveExternalModuleName(node, moduleReference, false /*ignoreErrors*/);
			final resolved = c.resolveExternalModuleSymbol(immediate, true /*dontResolveAlias*/);
			if (resolved != null && (ModuleKindNode20 : Int) <= (c.moduleKind : Int) && (c.moduleKind : Int) <= (ModuleKindNodeNext : Int)) {
				final moduleExports = c.getExportOfModule(resolved, Ast.InternalSymbolNameModuleExports, node, true /*dontResolveAlias*/);
				if (moduleExports != null) {
					return moduleExports;
				}
			}
			c.markSymbolOfAliasDeclarationIfTypeOnly(node, null);
			return resolved;
		}
		final resolved = c.getSymbolOfPartOfRightHandSideOfImportEquals(node.AsImportEqualsDeclaration().ModuleReference);
		c.checkAndReportErrorForResolvingImportAliasToTypeOnlySymbol(node, resolved);
		return resolved;
	}

	static function resolveExternalModuleTypeByLiteral(c:Checker, name:Node):Type {
		final moduleSym = c.resolveExternalModuleName(name, name, false /*ignoreErrors*/);
		if (moduleSym != null) {
			final resolvedModuleSymbol = c.resolveExternalModuleSymbol(moduleSym, false /*dontResolveAlias*/);
			if (resolvedModuleSymbol != null) {
				return c.getTypeOfSymbol(resolvedModuleSymbol);
			}
		}
		return c.anyType;
	}

	// This function is only for imports with entity names
	static function getSymbolOfPartOfRightHandSideOfImportEquals(c:Checker, entityName:Node):Symbol {
		// There are three things we might try to look for. In the following examples,
		// the search term is enclosed in |...|:
		//
		//     import a = |b|; // Namespace
		//     import a = |b.c|; // Value, type, namespace
		//     import a = |b.c|.d; // Namespace
		if (entityName.Kind == KindIdentifier && Ast.IsRightSideOfQualifiedNameOrPropertyAccess(entityName)) {
			entityName = entityName.Parent; // QualifiedName
		}
		// Check for case 1 and 3 in the above example
		if (entityName.Kind == KindIdentifier || entityName.Parent.Kind == KindQualifiedName) {
			return c.resolveEntityName(entityName, SymbolFlagsNamespace, false /*ignoreErrors*/, true /*dontResolveAlias*/, null /*location*/);
		}
		// Case 2 in above example
		// entityName.kind could be a QualifiedName or a Missing identifier
		Debug.Assert(entityName.Parent.Kind == KindImportEqualsDeclaration);
		return c.resolveEntityName(entityName, SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace, false /*ignoreErrors*/, true /*dontResolveAlias*/, null /*location*/);
	}

	static function checkAndReportErrorForResolvingImportAliasToTypeOnlySymbol(c:Checker, node:Node, resolved:Symbol):Void {
		final decl = node.AsImportEqualsDeclaration();
		var name = decl.ModuleReference;
		while (true) {
			final typeOnlyDeclaration = c.getTypeOnlyDeclarationOfEntityName(name);
			if (typeOnlyDeclaration != null) {
				final isExport = Ast.NodeKindIs(typeOnlyDeclaration, KindExportSpecifier, KindExportDeclaration);
				final message = Core.IfElse(isExport,
					Diagnostics.An_import_alias_cannot_reference_a_declaration_that_was_exported_using_export_type,
					Diagnostics.An_import_alias_cannot_reference_a_declaration_that_was_imported_using_import_type);
				final relatedMessage = Core.IfElse(isExport,
					Diagnostics.X_0_was_exported_here,
					Diagnostics.X_0_was_imported_here);
				// TODO: how to get name for export *?
				var name = "*";
				if (!Ast.IsExportDeclaration(typeOnlyDeclaration)) {
					name = typeOnlyDeclaration.Name().Text();
				}
				c.error(decl.ModuleReference, message).AddRelatedInfo(Checker.createDiagnosticForNode(typeOnlyDeclaration, relatedMessage, name));
				break;
			}
			if (Ast.IsIdentifier(name)) {
				break;
			}
			name = name.AsQualifiedName().Left;
		}
	}

	static function getTypeOnlyDeclarationOfEntityName(c:Checker, name:Node):Node {
		final symbol = c.resolveEntityName(name, SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace, true /*ignoreErrors*/, true /*dontResolveAlias*/, null /*location*/);
		if (symbol != null) {
			return c.getTypeOnlyAliasDeclaration(symbol);
		}
		return null;
	}

	static function getTargetOfImportClause(c:Checker, node:Node):Symbol {
		final moduleSymbol = c.resolveExternalModuleName(node, Checker.getModuleSpecifierFromNode(node.Parent), false /*ignoreErrors*/);
		if (moduleSymbol != null) {
			return c.getTargetOfModuleDefault(moduleSymbol, node, true /*dontResolveAlias*/);
		}
		return null;
	}

	static function getTargetOfModuleDefault(c:Checker, moduleSymbol:Symbol, node:Node, dontResolveAlias:Bool):Symbol {
		final file = Core.Find(moduleSymbol.Declarations, Ast.IsSourceFile);
		final specifier = c.getModuleSpecifierForImportOrExport(node);
		var exportDefaultSymbol:Symbol = null;
		var exportModuleDotExportsSymbol:Symbol = null;
		if (Checker.isShorthandAmbientModuleSymbol(moduleSymbol)) {
			// !!! exportDefaultSymbol = moduleSymbol
			// Does nothing?
		} else if (file != null && specifier != null
			&& (ModuleKindNode20 : Int) <= (c.moduleKind : Int) && (c.moduleKind : Int) <= (ModuleKindNodeNext : Int)
			&& c.getEmitSyntaxForModuleSpecifierExpression(specifier) == ModuleKindCommonJS
			&& c.program.GetImpliedNodeFormatForEmit(hasFileName(file.AsSourceFile())) == ModuleKindESNext) {
			exportModuleDotExportsSymbol = c.resolveExportByName(moduleSymbol, Ast.InternalSymbolNameModuleExports, node, dontResolveAlias);
		}
		if (exportModuleDotExportsSymbol != null) {
			// We have a transpiled default import where the `require` resolves to an ES module with a `module.exports` named
			// export. With `esModuleInterop` (always enabled), this will work:
			//
			// const dep_1 = __importDefault(require("./dep.mjs")); // wraps like { default: require("./dep.mjs") }
			// dep_1.default; // require("./dep.mjs") -> the `module.exports` export value
			c.markSymbolOfAliasDeclarationIfTypeOnly(node, null);
			return exportModuleDotExportsSymbol;
		} else {
			exportDefaultSymbol = c.resolveExportByName(moduleSymbol, Ast.InternalSymbolNameDefault, node, dontResolveAlias);
		}
		if (specifier == null) {
			return exportDefaultSymbol;
		}
		final hasDefaultOnly = c.isOnlyImportableAsDefault(specifier, moduleSymbol);
		final hasSyntheticDefault = c.canHaveSyntheticDefault(file, moduleSymbol, dontResolveAlias, specifier);
		if (exportDefaultSymbol == null && !hasSyntheticDefault && !hasDefaultOnly) {
			if (Ast.IsImportClause(node)) {
				c.reportNonDefaultExport(moduleSymbol, node);
			} else {
				var name:Node = null;
				if (Ast.IsImportOrExportSpecifier(node)) {
					name = node.PropertyNameOrName();
				} else {
					name = node.Name();
				}
				c.errorNoModuleMemberSymbol(moduleSymbol, moduleSymbol, node, name);
			}
		} else if (hasSyntheticDefault || hasDefaultOnly) {
			// per emit behavior, a synthetic default overrides a "real" .default member if `__esModule` is not present
			var resolved = c.resolveExternalModuleSymbol(moduleSymbol, dontResolveAlias);
			if (resolved == null) {
				resolved = c.resolveSymbolEx(moduleSymbol, dontResolveAlias);
			}
			c.markSymbolOfAliasDeclarationIfTypeOnly(node, null);
			return resolved;
		}
		c.markSymbolOfAliasDeclarationIfTypeOnly(node, null);
		return exportDefaultSymbol;
	}

	static function reportNonDefaultExport(c:Checker, moduleSymbol:Symbol, node:Node):Void {
		if (moduleSymbol.Exports != null && moduleSymbol.Exports.get(node.Symbol().Name) != null) {
			c.error(node, Diagnostics.Module_0_has_no_default_export_Did_you_mean_to_use_import_1_from_0_instead, c.symbolToString(moduleSymbol), c.symbolToString(node.Symbol()));
		} else {
			final diagnostic = c.error(node.Name(), Diagnostics.Module_0_has_no_default_export, c.symbolToString(moduleSymbol));
			var exportStar:Symbol = null;
			if (moduleSymbol.Exports != null) {
				exportStar = moduleSymbol.Exports.get(Ast.InternalSymbolNameExportStar);
			}
			if (exportStar != null) {
				final defaultExport = Core.Find(exportStar.Declarations, function(decl:Node):Bool {
					if (!(Ast.IsExportDeclaration(decl) && decl.ModuleSpecifier() != null)) {
						return false;
					}
					final resolvedExternalModuleName = c.resolveExternalModuleName(decl, decl.ModuleSpecifier(), false /*ignoreErrors*/);
					return resolvedExternalModuleName != null && symbolTableGet(resolvedExternalModuleName.Exports, Ast.InternalSymbolNameDefault) != null;
				});
				if (defaultExport != null) {
					diagnostic.AddRelatedInfo(Checker.createDiagnosticForNode(defaultExport, Diagnostics.X_export_Asterisk_does_not_re_export_a_default));
				}
			}
		}
	}

	static function resolveExportByName(c:Checker, moduleSymbol:Symbol, name:std.String, sourceNode:Node, dontResolveAlias:Bool):Symbol {
		final exportValue = symbolTableGet(moduleSymbol.Exports, Ast.InternalSymbolNameExportEquals);
		var exportSymbol:Symbol = null;
		if (exportValue != null) {
			exportSymbol = c.getPropertyOfTypeEx(c.getTypeOfSymbol(exportValue), name, true /*skipObjectFunctionPropertyAugment*/, false /*includeTypeOnlyMembers*/);
		} else {
			exportSymbol = symbolTableGet(moduleSymbol.Exports, name);
		}
		final resolved = c.resolveSymbolEx(exportSymbol, dontResolveAlias);
		c.markSymbolOfAliasDeclarationIfTypeOnly(sourceNode, null);
		return resolved;
	}

	static function getTargetOfNamespaceImport(c:Checker, node:Node):Symbol {
		final moduleSpecifier = c.getModuleSpecifierForImportOrExport(node);
		final immediate = c.resolveExternalModuleName(node, moduleSpecifier, false /*ignoreErrors*/);
		final resolved = c.resolveESModuleSymbol(immediate, node, moduleSpecifier);
		c.markSymbolOfAliasDeclarationIfTypeOnly(node, null);
		return resolved;
	}

	static function getTargetOfNamespaceExport(c:Checker, node:Node):Symbol {
		final moduleSpecifier = c.getModuleSpecifierForImportOrExport(node);
		if (moduleSpecifier != null) {
			final immediate = c.resolveExternalModuleName(node, moduleSpecifier, false /*ignoreErrors*/);
			final resolved = c.resolveESModuleSymbol(immediate, node, moduleSpecifier);
			c.markSymbolOfAliasDeclarationIfTypeOnly(node, null);
			return resolved;
		}
		return null;
	}

	static function getTargetOfImportSpecifier(c:Checker, node:Node):Symbol {
		final name = node.PropertyNameOrName();
		if (Ast.IsImportSpecifier(node) && Ast.ModuleExportNameIsDefault(name)) {
			final specifier = c.getModuleSpecifierForImportOrExport(node);
			if (specifier != null) {
				final moduleSymbol = c.resolveExternalModuleName(node, specifier, false /*ignoreErrors*/);
				if (moduleSymbol != null) {
					return c.getTargetOfModuleDefault(moduleSymbol, node, true /*dontResolveAlias*/);
				}
			}
		}
		var root = node.Parent.Parent.Parent; // ImportDeclaration
		if (Ast.IsBindingElement(node)) {
			root = Ast.GetRootDeclaration(node);
		}
		final resolved = c.getExternalModuleMember(root, node, true /*dontResolveAlias*/);
		c.markSymbolOfAliasDeclarationIfTypeOnly(node, null);
		return resolved;
	}

	static function getExternalModuleMember(c:Checker, node:Node, specifier:Node, dontResolveAlias:Bool):Symbol {
		// node is ImportDeclaration | ExportDeclaration | VariableDeclaration
		// specifier is ImportSpecifier | ExportSpecifier | BindingElement | PropertyAccessExpression
		var moduleSpecifier = Checker.getExternalModuleRequireArgument(node);
		if (moduleSpecifier == null) {
			moduleSpecifier = Ast.GetExternalModuleName(node);
		}
		final moduleSymbol = c.resolveExternalModuleName(node, moduleSpecifier, false /*ignoreErrors*/);
		var name:Node = null;
		if (!Ast.IsPropertyAccessExpression(specifier)) {
			name = specifier.PropertyNameOrName();
		} else {
			name = specifier.Name();
		}
		if (!Ast.IsIdentifier(name) && !Ast.IsStringLiteral(name)) {
			return null;
		}
		final nameText = name.Text();
		final targetSymbol = c.resolveESModuleSymbol(moduleSymbol, specifier, moduleSpecifier);
		if (targetSymbol != null) {
			// Note: The empty string is a valid module export name:
			//
			//   import { "" as foo } from "./foo";
			//   export { foo as "" };
			//
			if (nameText != "" || name.Kind == KindStringLiteral) {
				if (Checker.isShorthandAmbientModuleSymbol(moduleSymbol)) {
					return moduleSymbol;
				}
				var symbolFromVariable:Symbol = null;
				// First check if module was specified with "export=". If so, get the member from the resolved type
				if (moduleSymbol != null && symbolTableGet(moduleSymbol.Exports, Ast.InternalSymbolNameExportEquals) != null) {
					symbolFromVariable = c.getPropertyOfTypeEx(c.getTypeOfSymbol(targetSymbol), nameText, true /*skipObjectFunctionPropertyAugment*/, false /*includeTypeOnlyMembers*/);
				} else {
					symbolFromVariable = c.getPropertyOfVariable(targetSymbol, nameText);
				}
				// if symbolFromVariable is export - get its final target
				symbolFromVariable = c.resolveSymbolEx(symbolFromVariable, dontResolveAlias);
				var exportContainer = targetSymbol;
				if (moduleSymbol != null && symbolTableGet(moduleSymbol.Exports, Ast.InternalSymbolNameExportEquals) != null) {
					// For `export =` modules, supplemental type/namespace exports live on the original module symbol.
					exportContainer = moduleSymbol;
				}
				var symbolFromModule = c.getExportOfModule(exportContainer, nameText, specifier, dontResolveAlias);
				if (symbolFromModule == null && nameText == Ast.InternalSymbolNameDefault) {
					final file = Core.Find(moduleSymbol.Declarations, Ast.IsSourceFile);
					if (c.isOnlyImportableAsDefault(moduleSpecifier, moduleSymbol) || c.canHaveSyntheticDefault(file, moduleSymbol, dontResolveAlias, moduleSpecifier)) {
						symbolFromModule = c.resolveExternalModuleSymbol(moduleSymbol, dontResolveAlias);
						if (symbolFromModule == null) {
							symbolFromModule = c.resolveSymbolEx(moduleSymbol, dontResolveAlias);
						}
					}
				}
				var symbol = symbolFromVariable;
				if (symbolFromModule != null) {
					symbol = symbolFromModule;
					if (symbolFromVariable != null) {
						symbol = c.combineValueAndTypeSymbols(symbolFromVariable, symbolFromModule);
					}
				}
				if (Ast.IsImportOrExportSpecifier(specifier) && c.isOnlyImportableAsDefault(moduleSpecifier, moduleSymbol) && nameText != Ast.InternalSymbolNameDefault) {
					c.error(name, Diagnostics.Named_imports_from_a_JSON_file_into_an_ECMAScript_module_are_not_allowed_when_module_is_set_to_0, c.moduleKind.String());
				} else if (symbol == null) {
					c.errorNoModuleMemberSymbol(moduleSymbol, targetSymbol, node, name);
				}
				return symbol;
			}
		}
		return null;
	}

	static function getPropertyOfVariable(c:Checker, symbol:Symbol, name:std.String):Symbol {
		if ((symbol.Flags & SymbolFlagsVariable) != 0) {
			final typeAnnotation = symbol.ValueDeclaration.Type();
			if (typeAnnotation != null) {
				return c.resolveSymbol(c.getPropertyOfType(c.getTypeFromTypeNode(typeAnnotation), name));
			}
		}
		return null;
	}

	// This function creates a synthetic symbol that combines the value side of one symbol with the
	// type/namespace side of another symbol. Consider this example:
	//
	//	declare module graphics {
	//	    interface Point {
	//	        x: number;
	//	        y: number;
	//	    }
	//	}
	//	declare var graphics: {
	//	    Point: new (x: number, y: number) => graphics.Point;
	//	}
	//	declare module "graphics" {
	//	    export = graphics;
	//	}
	//
	// An 'import { Point } from "graphics"' needs to create a symbol that combines the value side 'Point'
	// property with the type/namespace side interface 'Point'.
	static function combineValueAndTypeSymbols(c:Checker, valueSymbol:Symbol, typeSymbol:Symbol):Symbol {
		if (valueSymbol == c.unknownSymbol && typeSymbol == c.unknownSymbol) {
			return c.unknownSymbol;
		}
		if ((typeSymbol.Flags & SymbolFlagsValue) != 0) {
			return typeSymbol;
		}
		if ((valueSymbol.Flags & (SymbolFlagsType | SymbolFlagsNamespace)) != 0) {
			return valueSymbol;
		}
		final result = c.newSymbol(valueSymbol.Flags | typeSymbol.Flags, valueSymbol.Name);
		Debug.Assert(Core.len(valueSymbol.Declarations) > 0 || Core.len(typeSymbol.Declarations) > 0);
		result.Declarations = compactNodes(Slices.Concat(valueSymbol.Declarations, typeSymbol.Declarations));
		result.Parent = valueSymbol.Parent;
		if (result.Parent == null) {
			result.Parent = typeSymbol.Parent;
		}
		result.ValueDeclaration = valueSymbol.ValueDeclaration;
		result.Members = cloneSymbolTable(typeSymbol.Members);
		result.Exports = cloneSymbolTable(valueSymbol.Exports);
		return result;
	}

	static function getExportOfModule(c:Checker, symbol:Symbol, nameText:std.String, specifier:Node, dontResolveAlias:Bool):Symbol {
		if ((symbol.Flags & SymbolFlagsModule) != 0) {
			final exportSymbol = symbolTableGet(c.getExportsOfSymbol(symbol), nameText);
			final resolved = c.resolveSymbolEx(exportSymbol, dontResolveAlias);
			final typeOnlyExportStarMap = c.moduleSymbolLinks.Get(symbol).typeOnlyExportStarMap;
			final exportStarDeclaration = typeOnlyExportStarMap != null ? typeOnlyExportStarMap.get(nameText) : null;
			c.markSymbolOfAliasDeclarationIfTypeOnly(specifier, exportStarDeclaration);
			return resolved;
		}
		return null;
	}

	static function isOnlyImportableAsDefault(c:Checker, usage:Node, resolvedModule:Symbol):Bool {
		// In Node.js, JSON modules don't get named exports
		if ((ModuleKindNode16 : Int) <= (c.moduleKind : Int) && (c.moduleKind : Int) <= (ModuleKindNodeNext : Int)) {
			final usageMode = c.getEmitSyntaxForModuleSpecifierExpression(usage);
			if (usageMode == ModuleKindESNext) {
				if (resolvedModule == null) {
					resolvedModule = c.resolveExternalModuleName(usage, usage, true /*ignoreErrors*/);
				}
				var targetFile:SourceFile = null;
				if (resolvedModule != null) {
					targetFile = Ast.GetSourceFileOfModule(resolvedModule);
				}
				return targetFile != null && (Ast.IsJsonSourceFile(targetFile) || Tspath.GetDeclarationFileExtension(targetFile.FileName()) == ".d.json.ts");
			}
		}
		return false;
	}

	static function canHaveSyntheticDefault(c:Checker, file:Node, moduleSymbol:Symbol, dontResolveAlias:Bool, usage:Node):Bool {
		var usageMode:ResolutionMode = ModuleKindNone;
		if (file != null) {
			usageMode = c.getEmitSyntaxForModuleSpecifierExpression(usage);
		}
		if (file != null && usageMode != ModuleKindNone) {
			final targetMode = c.program.GetImpliedNodeFormatForEmit(hasFileName(file.AsSourceFile()));
			if (usageMode == ModuleKindESNext && targetMode == ModuleKindCommonJS && (ModuleKindNode16 : Int) <= (c.moduleKind : Int) && (c.moduleKind : Int) <= (ModuleKindNodeNext : Int)) {
				// In Node.js, CommonJS modules always have a synthetic default when imported into ESM
				return true;
			}
			if (usageMode == ModuleKindESNext && targetMode == ModuleKindESNext) {
				// No matter what the `module` setting is, if we're confident that both files
				// are ESM, there cannot be a synthetic default.
				return false;
			}
			// For other files (not node16/nodenext with impliedNodeFormat), check if we can determine
			// the module format from project references
			if (targetMode == ModuleKindNone && file.AsSourceFile().IsDeclarationFile) {
				// Try to get the project reference - try both source file mapping and output file mapping
				// since declaration files can be mapped either way depending on how they're resolved
				if (c.program.GetRedirectForResolution(hasFileName(file.AsSourceFile())) != null || c.program.GetProjectReferenceFromOutputDts(file.AsSourceFile().Path()) != null) {
					// This is a declaration file from a project reference, so we can determine
					// its module format from the referenced project's options
					final targetModuleKind = c.program.GetEmitModuleFormatOfFile(hasFileName(file.AsSourceFile()));
					if (usageMode == ModuleKindESNext && (ModuleKindES2015 : Int) <= (targetModuleKind : Int) && (targetModuleKind : Int) <= (ModuleKindESNext : Int)) {
						return false;
					}
				}
			}
		}
		// Declaration files (and ambient modules)
		if (file == null || file.AsSourceFile().IsDeclarationFile) {
			// Definitely cannot have a synthetic default if they have a syntactic default member specified
			final defaultExportSymbol = c.resolveExportByName(moduleSymbol, Ast.InternalSymbolNameDefault /*sourceNode*/, null /*dontResolveAlias*/, true); // Dont resolve alias because we want the immediately exported symbol's declaration
			if (defaultExportSymbol != null && Core.Some(defaultExportSymbol.Declarations, Checker.isSyntacticDefault)) {
				return false;
			}
			// It _might_ still be incorrect to assume there is no __esModule marker on the import at runtime, even if there is no `default` member
			// So we check a bit more,
			if (c.resolveExportByName(moduleSymbol, "__esModule", null /*sourceNode*/, dontResolveAlias) != null) {
				// If there is an `__esModule` specified in the declaration (meaning someone explicitly added it or wrote it in their code),
				// it definitely is a module and does not have a synthetic default
				return false;
			}
			// There are _many_ declaration files not written with esmodules in mind that still get compiled into a format with __esModule set
			// Meaning there may be no default at runtime - however to be on the permissive side, we allow access to a synthetic default member
			// as there is no marker to indicate if the accompanying JS has `__esModule` or not, or is even native esm
			return true;
		}
		// TypeScript files never have a synthetic default (as they are always emitted with an __esModule marker) _unless_ they contain an export= statement
		if (!Ast.IsInJSFile(file)) {
			return Checker.hasExportAssignmentSymbol(moduleSymbol);
		}

		// JS files have a synthetic default if they do not contain ES2015+ module syntax (export = is not valid in js) _and_ do not have an __esModule marker
		return (file.AsSourceFile().ExternalModuleIndicator == null || file.AsSourceFile().ExternalModuleIndicator == file) && c.resolveExportByName(moduleSymbol, "__esModule", null /*sourceNode*/, dontResolveAlias) == null;
	}

	static function getEmitSyntaxForModuleSpecifierExpression(c:Checker, usage:Node):ResolutionMode {
		if (Ast.IsStringLiteralLike(usage)) {
			return c.program.GetEmitSyntaxForUsageLocation(hasFileName(Ast.GetSourceFileOfNode(usage)), usage);
		}
		return ModuleKindNone;
	}

	static function errorNoModuleMemberSymbol(c:Checker, moduleSymbol:Symbol, targetSymbol:Symbol, node:Node, name:Node):Void {
		if (c.compilerOptions.NoCheck.IsTrue()) {
			return;
		}
		final moduleName = c.getFullyQualifiedName(moduleSymbol, node);
		final declarationName = Scanner.DeclarationNameToString(name);
		var suggestion:Symbol = null;
		if (Ast.IsIdentifier(name)) {
			suggestion = c.getSuggestedSymbolForNonexistentModule(name, targetSymbol);
		}
		if (suggestion != null) {
			final suggestionName = c.symbolToString(suggestion);
			final diagnostic = c.error(name, Diagnostics.X_0_has_no_exported_member_named_1_Did_you_mean_2, moduleName, declarationName, suggestionName);
			if (suggestion.ValueDeclaration != null) {
				diagnostic.AddRelatedInfo(Checker.createDiagnosticForNode(suggestion.ValueDeclaration, Diagnostics.X_0_is_declared_here, suggestionName));
			}
		} else {
			if (symbolTableGet(moduleSymbol.Exports, Ast.InternalSymbolNameDefault) != null) {
				c.error(name, Diagnostics.Module_0_has_no_exported_member_1_Did_you_mean_to_use_import_1_from_0_instead, moduleName, declarationName);
			} else {
				c.reportNonExportedMember(name, declarationName, moduleSymbol, moduleName);
			}
		}
	}

	static function reportNonExportedMember(c:Checker, name:Node, declarationName:std.String, moduleSymbol:Symbol, moduleName:std.String):Void {
		var localSymbol:Symbol = null;
		final locals = moduleSymbol.ValueDeclaration.Locals();
		if (locals != null) {
			localSymbol = locals.get(name.Text());
		}
		final exports = moduleSymbol.Exports;
		if (localSymbol != null) {
			final exportedEqualsSymbol = symbolTableGet(exports, Ast.InternalSymbolNameExportEquals);
			if (exportedEqualsSymbol != null) {
				if (c.getSymbolIfSameReference(exportedEqualsSymbol, localSymbol) != null) {
					c.reportInvalidImportEqualsExportMember(name, declarationName, moduleName);
				} else {
					c.error(name, Diagnostics.Module_0_has_no_exported_member_1, moduleName, declarationName);
				}
			} else {
				final exportedSymbol = findInSymbolTable(exports, function(symbol:Symbol):Bool {
					return c.getSymbolIfSameReference(symbol, localSymbol) != null;
				});
				var diagnostic:Diagnostic = null;
				if (exportedSymbol != null) {
					diagnostic = c.error(name, Diagnostics.Module_0_declares_1_locally_but_it_is_exported_as_2, moduleName, declarationName, c.symbolToString(exportedSymbol));
				} else {
					diagnostic = c.error(name, Diagnostics.Module_0_declares_1_locally_but_it_is_not_exported, moduleName, declarationName);
				}
				final decls = rangeOf(localSymbol.Declarations);
				for (i in 0...decls.length) {
					final decl = decls[i];
					diagnostic.AddRelatedInfo(Checker.createDiagnosticForNode(decl, Core.IfElse(i == 0, Diagnostics.X_0_is_declared_here, Diagnostics.X_and_here), declarationName));
				}
			}
		} else {
			c.error(name, Diagnostics.Module_0_has_no_exported_member_1, moduleName, declarationName);
		}
	}

	static function reportInvalidImportEqualsExportMember(c:Checker, name:Node, declarationName:std.String, moduleName:std.String):Void {
		if ((c.moduleKind : Int) >= (ModuleKindES2015 : Int)) {
			c.error(name, Diagnostics.X_0_can_only_be_imported_by_using_a_default_import, declarationName);
		} else if (Ast.IsInJSFile(name)) {
			c.error(name, Diagnostics.X_0_can_only_be_imported_by_using_a_require_call_or_by_using_a_default_import, declarationName);
		} else {
			c.error(name, Diagnostics.X_0_can_only_be_imported_by_using_import_1_require_2_or_a_default_import, declarationName, declarationName, moduleName);
		}
	}

	static function getTargetOfExportSpecifier(c:Checker, node:Node, meaning:SymbolFlags, dontResolveAlias:Bool):Symbol {
		final name = node.PropertyNameOrName();
		if (Ast.ModuleExportNameIsDefault(name)) {
			final specifier = c.getModuleSpecifierForImportOrExport(node);
			if (specifier != null) {
				final moduleSymbol = c.resolveExternalModuleName(node, specifier, false /*ignoreErrors*/);
				if (moduleSymbol != null) {
					return c.getTargetOfModuleDefault(moduleSymbol, node, dontResolveAlias);
				}
			}
		}
		final exportDeclaration = node.Parent.Parent;
		var resolved:Symbol = null;
		if (exportDeclaration.ModuleSpecifier() != null) {
			resolved = c.getExternalModuleMember(exportDeclaration, node, dontResolveAlias);
		} else if (Ast.IsStringLiteral(name)) {
			resolved = null;
		} else {
			resolved = c.resolveEntityName(name, meaning, false /*ignoreErrors*/, dontResolveAlias, null /*location*/);
		}
		c.markSymbolOfAliasDeclarationIfTypeOnly(node, null);
		return resolved;
	}

	static function getTargetOfExportAssignment(c:Checker, node:Node):Symbol {
		final resolved = c.getTargetOfAliasLikeExpression(node.Expression());
		c.markSymbolOfAliasDeclarationIfTypeOnly(node, null);
		return resolved;
	}

	static function getTargetOfBinaryExpression(c:Checker, node:Node):Symbol {
		final resolved = c.getTargetOfAliasLikeExpression(node.AsBinaryExpression().Right);
		c.markSymbolOfAliasDeclarationIfTypeOnly(node, null);
		return resolved;
	}

	static function getTargetOfAliasLikeExpression(c:Checker, expression:Node):Symbol {
		if (Ast.IsClassExpression(expression)) {
			return c.checkExpressionCached(expression).symbol;
		}
		if (!Ast.IsEntityName(expression) && !Ast.IsEntityNameExpression(expression)) {
			return null;
		}
		final aliasLike = c.resolveEntityName(expression, SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace, true /*ignoreErrors*/, true /*dontResolveAlias*/, null /*location*/);
		if (aliasLike != null) {
			return aliasLike;
		}
		c.checkExpressionCached(expression);
		return c.getResolvedSymbolOrNil(expression);
	}

	static function getTargetOfNamespaceExportDeclaration(c:Checker, node:Node):Symbol {
		if (Ast.CanHaveSymbol(node.Parent)) {
			final resolved = c.resolveExternalModuleSymbol(node.Parent.Symbol(), true /*dontResolveAlias*/);
			c.markSymbolOfAliasDeclarationIfTypeOnly(node, null);
			return resolved;
		}
		return null;
	}

	static function getTargetOfAccessExpression(c:Checker, node:Node):Symbol {
		if (Ast.IsBinaryExpression(node.Parent)) {
			final expr = node.Parent.AsBinaryExpression();
			if (expr.Left == node && expr.OperatorToken.Kind == KindEqualsToken) {
				return c.getTargetOfAliasLikeExpression(expr.Right);
			}
		}
		return null;
	}

	static function getModuleSpecifierForImportOrExport(c:Checker, node:Node):Node {
		switch (node.Kind) {
			case KindImportClause:
				return Checker.getModuleSpecifierFromNode(node.Parent);
			case KindImportEqualsDeclaration:
				if (Ast.IsExternalModuleReference(node.AsImportEqualsDeclaration().ModuleReference)) {
					return node.AsImportEqualsDeclaration().ModuleReference.Expression();
				} else {
					return null;
				}
			case KindNamespaceImport:
				return Checker.getModuleSpecifierFromNode(node.Parent.Parent);
			case KindImportSpecifier:
				return Checker.getModuleSpecifierFromNode(node.Parent.Parent.Parent);
			case KindNamespaceExport:
				return Checker.getModuleSpecifierFromNode(node.Parent);
			case KindExportSpecifier:
				return Checker.getModuleSpecifierFromNode(node.Parent.Parent);
			default:
		}
		throw "Unhandled case in getModuleSpecifierForImportOrExport";
	}

	static function markSymbolOfAliasDeclarationIfTypeOnly(c:Checker, aliasDeclaration:Node, exportStarDeclaration:Node):Bool {
		if (aliasDeclaration == null || !Ast.IsDeclarationNode(aliasDeclaration)) {
			return false;
		}
		// If the declaration itself is type-only, mark it and return. No need to check what it resolves to.
		final sourceSymbol = c.getSymbolOfDeclaration(aliasDeclaration);
		final links = c.aliasSymbolLinks.Get(sourceSymbol);
		if (links.typeOnlyDeclaration == null && Ast.IsTypeOnlyImportOrExportDeclaration(aliasDeclaration)) {
			links.typeOnlyDeclaration = aliasDeclaration;
			return true;
		}
		if (links.typeOnlyDeclaration == null && exportStarDeclaration != null) {
			links.typeOnlyDeclaration = exportStarDeclaration;
			return true;
		}
		return links.typeOnlyDeclaration != null;
	}

	static function resolveExternalModuleName(c:Checker, location:Node, moduleReferenceExpression:Node, ignoreErrors:Bool):Symbol {
		var errorMessage = c.getCannotResolveModuleNameErrorForSpecificModule(moduleReferenceExpression);
		if (errorMessage == null) {
			errorMessage = Diagnostics.Cannot_find_module_0_or_its_corresponding_type_declarations;
		}
		ignoreErrors = ignoreErrors || c.compilerOptions.NoCheck.IsTrue();
		return c.resolveExternalModuleNameWorker(location, moduleReferenceExpression, Core.IfElse(ignoreErrors, null, errorMessage), ignoreErrors, false /*isForAugmentation*/);
	}

	static function getCannotResolveModuleNameErrorForSpecificModule(c:Checker, moduleName:Node):Message {
		if (Ast.IsStringLiteral(moduleName)) {
			if (Core.NodeCoreModules().get(moduleName.Text()) == true) {
				if (c.compilerOptions.UsesWildcardTypes()) {
					return Diagnostics.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_node_Try_npm_i_save_dev_types_Slashnode;
				}
				return Diagnostics.Cannot_find_name_0_Do_you_need_to_install_type_definitions_for_node_Try_npm_i_save_dev_types_Slashnode_and_then_add_node_to_the_types_field_in_your_tsconfig;
			}
		}
		return null;
	}

	static function resolveExternalModuleNameWorker(c:Checker, location:Node, moduleReferenceExpression:Node, moduleNotFoundError:Message, ignoreErrors:Bool, isForAugmentation:Bool):Symbol {
		if (Ast.IsStringLiteralLike(moduleReferenceExpression)) {
			return c.resolveExternalModule(location, moduleReferenceExpression.Text(), moduleNotFoundError, Core.IfElse(!ignoreErrors, moduleReferenceExpression, null), isForAugmentation);
		}
		return null;
	}

	static function getExternalModuleFileFromDeclaration(c:Checker, declaration:Node):SourceFile {
		var specifier:Node = null;
		if (declaration.Kind == KindModuleDeclaration) {
			if (Ast.IsStringLiteral(declaration.Name())) {
				specifier = declaration.Name();
			}
		} else {
			specifier = Ast.GetExternalModuleName(declaration);
		}
		final moduleSymbol = c.resolveExternalModuleNameWorker(specifier, specifier /*moduleNotFoundError*/, null, false, false); // TODO: GH#18217
		if (moduleSymbol == null) {
			return null;
		}
		final decl = Ast.GetDeclarationOfKind(moduleSymbol, KindSourceFile);
		if (decl == null) {
			return null;
		}
		return decl.AsSourceFile();
	}

	static function resolveExternalModule(c:Checker, location:Node, moduleReference:std.String, moduleNotFoundError:Message, errorNode:Node, isForAugmentation:Bool):Symbol {
		if (errorNode != null && StringTools.startsWith(moduleReference, "@types/")) {
			final withoutAtTypePrefix = moduleReference.substring("@types/".length);
			c.error(errorNode, Diagnostics.Cannot_import_type_declaration_files_Consider_importing_0_instead_of_1, withoutAtTypePrefix, moduleReference);
		}
		final ambientModule = c.tryFindAmbientModule(moduleReference, true /*withAugmentations*/);
		if (ambientModule != null) {
			return ambientModule;
		}

		final importingSourceFile = Ast.GetSourceFileOfNode(location);
		var contextSpecifier:Node = null;
		var mode:ResolutionMode = ModuleKindNone;

		if (Ast.IsStringLiteralLike(location) || location.Parent != null && Ast.IsModuleDeclaration(location.Parent) && location.Parent.AsModuleDeclaration().Name() == location) {
			contextSpecifier = location;
		} else if (Ast.IsModuleDeclaration(location)) {
			contextSpecifier = location.AsModuleDeclaration().Name();
		} else if (Ast.IsLiteralImportTypeNode(location)) {
			contextSpecifier = location.AsImportTypeNode().Argument.AsLiteralTypeNode().Literal;
		} else if (Ast.IsVariableDeclarationInitializedToBareOrAccessedRequire(location)) {
			contextSpecifier = Ast.GetModuleSpecifierOfBareOrAccessedRequire(location);
		} else {
			var ancestor = Ast.FindAncestor(location, Ast.IsImportCall);
			if (ancestor != null) {
				contextSpecifier = ancestor.Arguments()[0];
			}

			if (ancestor == null) {
				ancestor = Ast.FindAncestor(location, Ast.IsImportDeclarationOrJSImportDeclaration);
				if (ancestor != null) {
					contextSpecifier = ancestor.ModuleSpecifier();
				}
			}
			if (ancestor == null) {
				ancestor = Ast.FindAncestor(location, Ast.IsExportDeclaration);
				if (ancestor != null) {
					contextSpecifier = ancestor.ModuleSpecifier();
				}
			}
			if (ancestor == null) {
				ancestor = Ast.FindAncestor(location, Ast.IsImportEqualsDeclaration);
				if (ancestor != null) {
					final moduleRefrence = ancestor.AsImportEqualsDeclaration().ModuleReference;
					if (moduleRefrence.Kind == KindExternalModuleReference) {
						contextSpecifier = moduleRefrence.Expression();
					}
				}
			}
		}

		if (contextSpecifier != null && Ast.IsStringLiteralLike(contextSpecifier)) {
			mode = c.program.GetModeForUsageLocation(hasFileName(importingSourceFile), contextSpecifier);
		} else {
			mode = c.program.GetDefaultResolutionModeForFile(hasFileName(importingSourceFile));
		}

		final resolvedModule = c.program.GetResolvedModule(hasFileName(importingSourceFile), moduleReference, mode);

		var resolutionDiagnostic:Message = null;
		if (errorNode != null && resolvedModule.IsResolved()) {
			resolutionDiagnostic = Module.GetResolutionDiagnostic(c.compilerOptions, resolvedModule, importingSourceFile);
		}

		var sourceFile:SourceFile = null;
		if (resolvedModule.IsResolved() && (resolutionDiagnostic == null || resolutionDiagnostic == Diagnostics.Module_0_was_resolved_to_1_but_jsx_is_not_set)) {
			sourceFile = c.program.GetSourceFileForResolvedModule(resolvedModule.ResolvedFileName);
		}

		if (sourceFile != null) {
			// If there's a resolutionDiagnostic we need to report it even if a sourceFile is found.
			if (resolutionDiagnostic != null) {
				c.error(errorNode, resolutionDiagnostic, moduleReference, resolvedModule.ResolvedFileName);
			}

			if (errorNode != null) {
				if (resolvedModule.ResolvedUsingTsExtension && Tspath.IsDeclarationFileName(moduleReference)) {
					if (Ast.FindAncestor(location, Ast.IsEmittableImport) != null) {
						final tsExtension = Tspath.TryExtractTSExtension(moduleReference);
						if (tsExtension == "") {
							throw "should be able to extract TS extension from string that passes IsDeclarationFileName";
						}
						c.error(errorNode,
							Diagnostics.A_declaration_file_cannot_be_imported_without_import_type_Did_you_mean_to_import_an_implementation_file_0_instead,
							c.getSuggestedImportSource(moduleReference, tsExtension, mode));
					}
				} else if (resolvedModule.ResolvedUsingTsExtension && !c.compilerOptions.AllowImportingTsExtensionsFrom(importingSourceFile.FileName())) {
					if (Ast.FindAncestor(location, Ast.IsEmittableImport) != null) {
						var tsExtension = Tspath.TryExtractTSExtension(moduleReference);
						if (tsExtension == "") {
							// Fallback: do a best-effort extraction using strings.Contains.
							// This handles cases where a wildcard pattern matches a TS extension that's
							// not at the end of the module specifier, e.g., "#/foo.ts.omg" through "#/*.omg": "./src/*"
							for (ext in Tspath.SupportedTSExtensionsFlat) {
								if (moduleReference.indexOf(ext) >= 0) {
									tsExtension = ext;
									break;
								}
							}
						}
						if (tsExtension == "") {
							throw "should be able to extract TS extension from string when resolvedUsingTsExtension is true";
						}
						c.error(errorNode, Diagnostics.An_import_path_can_only_end_with_a_0_extension_when_allowImportingTsExtensions_is_enabled, tsExtension);
					}
				} else if (c.compilerOptions.RewriteRelativeImportExtensions.IsTrue()
					&& (location.Flags & NodeFlagsAmbient) == 0
					&& !Tspath.IsDeclarationFileName(moduleReference)
					&& !Ast.IsLiteralImportTypeNode(location)
					&& !Ast.IsPartOfTypeOnlyImportOrExportDeclaration(location)) {
					final shouldRewrite = Core.ShouldRewriteModuleSpecifier(moduleReference, c.compilerOptions);
					if (!resolvedModule.ResolvedUsingTsExtension && shouldRewrite) {
						final relativeToSourceFile = Tspath.GetRelativePathFromFile(Tspath.GetNormalizedAbsolutePath(importingSourceFile.FileName(),
							c.program.GetCurrentDirectory()),
							resolvedModule.ResolvedFileName, new ComparePathsOptions(c.program.UseCaseSensitiveFileNames(), c.program.GetCurrentDirectory()));
						c.error(errorNode,
							Diagnostics.This_relative_import_path_is_unsafe_to_rewrite_because_it_looks_like_a_file_name_but_actually_resolves_to_0,
							relativeToSourceFile);
					} else if (resolvedModule.ResolvedUsingTsExtension && !shouldRewrite && c.program.SourceFileMayBeEmitted(sourceFile, false)) {
						c.error(errorNode,
							Diagnostics.This_import_uses_a_0_extension_to_resolve_to_an_input_TypeScript_file_but_will_not_be_rewritten_during_emit_because_it_is_not_a_relative_path,
							Tspath.GetAnyExtensionFromPath(moduleReference, null, false));
					} else if (resolvedModule.ResolvedUsingTsExtension && shouldRewrite) {
						final redirect = c.program.GetRedirectForResolution(hasFileName(sourceFile));
						if (redirect != null) {
							final ownRootDir = c.program.CommonSourceDirectory();
							final otherRootDir = redirect.CommonSourceDirectory();

							final compareOptions = new ComparePathsOptions(c.program.UseCaseSensitiveFileNames(), c.program.GetCurrentDirectory());

							final rootDirPath = Tspath.GetRelativePathFromDirectory(ownRootDir, otherRootDir, compareOptions);

							// Get outDir paths, defaulting to root directories if not specified
							var ownOutDir = c.compilerOptions.OutDir;
							if (ownOutDir == "") {
								ownOutDir = ownRootDir;
							}
							var otherOutDir = redirect.CompilerOptions().OutDir;
							if (otherOutDir == "") {
								otherOutDir = otherRootDir;
							}
							final outDirPath = Tspath.GetRelativePathFromDirectory(ownOutDir, otherOutDir, compareOptions);

							if (rootDirPath != outDirPath) {
								c.error(errorNode,
									Diagnostics.This_import_path_is_unsafe_to_rewrite_because_it_resolves_to_another_project_and_the_relative_path_between_the_projects_output_files_is_not_the_same_as_the_relative_path_between_its_input_files);
							}
						}
					}
				}
			}

			if (sourceFile.Symbol != null) {
				if (errorNode != null) {
					if (resolvedModule.IsExternalLibraryImport && !Checker.resolutionExtensionIsTSOrJson(resolvedModule.Extension)) {
						c.errorOnImplicitAnyModule(false /*isError*/, errorNode, mode, resolvedModule, moduleReference);
					}
					if (c.moduleKind == ModuleKindNode16 || c.moduleKind == ModuleKindNode18) {
						final isSyncImport = c.program.GetDefaultResolutionModeForFile(hasFileName(importingSourceFile)) == ModuleKindCommonJS
							&& Ast.FindAncestor(location, Ast.IsImportCall) == null
							|| Ast.FindAncestor(location, Ast.IsImportEqualsDeclaration) != null;
						final overrideHost = Ast.FindAncestor(location, Ast.IsResolutionModeOverrideHost);
						if (isSyncImport && c.program.GetDefaultResolutionModeForFile(hasFileName(sourceFile)) == ModuleKindESNext
							&& !Ast.HasResolutionModeOverride(overrideHost)) {
							if (Ast.FindAncestorKind(location, KindImportEqualsDeclaration) != null) {
								// ImportEquals in an ESM file resolving to another ESM file
								c.error(errorNode,
									Diagnostics.Module_0_cannot_be_imported_using_this_construct_The_specifier_only_resolves_to_an_ES_module_which_cannot_be_imported_with_require_Use_an_ECMAScript_import_instead,
									moduleReference);
							} else {
								// CJS file resolving to an ESM file
								var diagnosticDetails:Diagnostic = null;
								final ext = Tspath.TryGetExtensionFromPath(importingSourceFile.FileName());
								if (ext == Tspath.ExtensionTs || ext == Tspath.ExtensionJs || ext == Tspath.ExtensionTsx || ext == Tspath.ExtensionJsx) {
									diagnosticDetails = c.createModeMismatchDetails(importingSourceFile, errorNode);
								}

								var message:Message = null;
								if (overrideHost != null && overrideHost.Kind == KindImportDeclaration && overrideHost.ImportClause() != null
									&& overrideHost.ImportClause().IsTypeOnly()) {
									message = Diagnostics.Type_only_import_of_an_ECMAScript_module_from_a_CommonJS_module_must_have_a_resolution_mode_attribute;
								} else if (overrideHost != null && overrideHost.Kind == KindImportType) {
									message = Diagnostics.Type_import_of_an_ECMAScript_module_from_a_CommonJS_module_must_have_a_resolution_mode_attribute;
								} else {
									message = Diagnostics.The_current_file_is_a_CommonJS_module_whose_imports_will_produce_require_calls_however_the_referenced_file_is_an_ECMAScript_module_and_cannot_be_imported_with_require_Consider_writing_a_dynamic_import_0_call_instead;
								}

								c.addDiagnostic(Checker.NewDiagnosticChainForNode(diagnosticDetails, errorNode, message, moduleReference));
							}
						}
					}
				}
				return c.getMergedSymbol(sourceFile.Symbol);
			}
			if (errorNode != null && moduleNotFoundError != null && !Checker.isSideEffectImport(errorNode)) {
				c.error(errorNode, Diagnostics.File_0_is_not_a_module, resolvedModule.ResolvedFileName);
			}
			return null;
		}

		if (Core.len(c.patternAmbientModules) != 0) {
			final pattern = Core.FindBestPatternMatch(c.patternAmbientModules, (v:PatternAmbientModule) -> v.Pattern, moduleReference);
			if (pattern != null) {
				final augmentation = symbolTableGet(c.patternAmbientModuleAugmentations, moduleReference);
				if (augmentation != null) {
					return c.getMergedSymbol(augmentation);
				}
				return c.getMergedSymbol(pattern.Symbol);
			}
		}

		if (errorNode == null) {
			return null;
		}

		if (resolvedModule.IsResolved() && !Checker.resolutionExtensionIsTSOrJson(resolvedModule.Extension) && resolutionDiagnostic == null
			|| resolutionDiagnostic == Diagnostics.Could_not_find_a_declaration_file_for_module_0_1_implicitly_has_an_any_type) {
			if (isForAugmentation) {
				c.error(errorNode,
					Diagnostics.Invalid_module_name_in_augmentation_Module_0_resolves_to_an_untyped_module_at_1_which_cannot_be_augmented,
					moduleReference, resolvedModule.ResolvedFileName);
			} else {
				c.errorOnImplicitAnyModule(c.noImplicitAny && moduleNotFoundError != null, errorNode, mode, resolvedModule, moduleReference);
			}
			return null;
		}

		if (moduleNotFoundError != null) {
			// See if this was possibly a projectReference redirect
			if (resolvedModule.IsResolved()) {
				final redirect = c.program.GetProjectReferenceFromSource(Tspath.ToPath(resolvedModule.ResolvedFileName, c.program.GetCurrentDirectory(),
					c.program.UseCaseSensitiveFileNames()));
				if (redirect != null && redirect.OutputDts != "") {
					c.error(errorNode, Diagnostics.Output_file_0_has_not_been_built_from_source_file_1, redirect.OutputDts, resolvedModule.ResolvedFileName);
					return null;
				}
			}

			if (resolutionDiagnostic != null) {
				c.error(errorNode, resolutionDiagnostic, moduleReference, resolvedModule.ResolvedFileName);
			} else {
				final isExtensionlessRelativePathImport = Tspath.PathIsRelative(moduleReference) && !Tspath.HasExtension(moduleReference);
				final resolutionIsNode16OrNext = c.moduleResolutionKind == ModuleResolutionKindNode16
					|| c.moduleResolutionKind == ModuleResolutionKindNodeNext;
				if (!c.compilerOptions.GetResolveJsonModule() && Tspath.FileExtensionIs(moduleReference, Tspath.ExtensionJson)) {
					c.error(errorNode, Diagnostics.Cannot_find_module_0_Consider_using_resolveJsonModule_to_import_module_with_json_extension, moduleReference);
				} else if (mode == Core.ResolutionModeESM && resolutionIsNode16OrNext && isExtensionlessRelativePathImport) {
					final absoluteRef = Tspath.GetNormalizedAbsolutePath(moduleReference, Tspath.GetDirectoryPath(importingSourceFile.FileName()));
					final suggestedExt = c.getSuggestedImportExtension(absoluteRef);
					if (suggestedExt != "") {
						c.error(errorNode,
							Diagnostics.Relative_import_paths_need_explicit_file_extensions_in_ECMAScript_imports_when_moduleResolution_is_node16_or_nodenext_Did_you_mean_0,
							moduleReference + suggestedExt);
					} else {
						c.error(errorNode,
							Diagnostics.Relative_import_paths_need_explicit_file_extensions_in_ECMAScript_imports_when_moduleResolution_is_node16_or_nodenext_Consider_adding_an_extension_to_the_import_path);
					}
				} else if (resolvedModule != null && resolvedModule.AlternateResult != "") {
					final errorInfo = c.createModuleNotFoundChain(resolvedModule, errorNode, moduleReference, mode, moduleReference);
					c.addDiagnostic(Checker.NewDiagnosticChainForNode(errorInfo, errorNode, moduleNotFoundError, moduleReference));
				} else {
					c.error(errorNode, moduleNotFoundError, moduleReference);
				}
			}
		}

		return null;
	}

	static function getSuggestedImportSource(c:Checker, moduleReference:std.String, tsExtension:std.String, mode:ResolutionMode):std.String {
		final importSourceWithoutExtension = Tspath.RemoveExtension(moduleReference, tsExtension);

		// Direct users to import source with .js extension if outputting an ES module.
		// @see https://github.com/microsoft/TypeScript/issues/42151
		if (c.moduleKind.IsNonNodeESM() || mode == ModuleKindESNext) {
			final preferTs = Tspath.IsDeclarationFileName(moduleReference) && c.compilerOptions.GetAllowImportingTsExtensions();
			var ext:std.String;
			if (tsExtension == Tspath.ExtensionMts || tsExtension == Tspath.ExtensionDmts) {
				ext = Core.IfElse(preferTs, ".mts", ".mjs");
			} else if (tsExtension == Tspath.ExtensionCts || tsExtension == Tspath.ExtensionDcts) {
				ext = Core.IfElse(preferTs, ".cts", ".cjs");
			} else {
				ext = Core.IfElse(preferTs, ".ts", ".js");
			}

			return importSourceWithoutExtension + ext;
		}

		return importSourceWithoutExtension;
	}

	static function getSuggestedImportExtension(c:Checker, extensionlessImportPath:std.String):std.String {
		if (c.program.FileExists(extensionlessImportPath + ".mts")) {
			return ".mjs";
		} else if (c.program.FileExists(extensionlessImportPath + ".ts")) {
			return ".js";
		} else if (c.program.FileExists(extensionlessImportPath + ".cts")) {
			return ".cjs";
		} else if (c.program.FileExists(extensionlessImportPath + ".mjs")) {
			return ".mjs";
		} else if (c.program.FileExists(extensionlessImportPath + ".js")) {
			return ".js";
		} else if (c.program.FileExists(extensionlessImportPath + ".cjs")) {
			return ".cjs";
		} else if (c.program.FileExists(extensionlessImportPath + ".tsx")) {
			return Core.IfElse(c.compilerOptions.Jsx == JsxEmitPreserve, ".jsx", ".js");
		} else if (c.program.FileExists(extensionlessImportPath + ".jsx")) {
			return ".jsx";
		} else if (c.program.FileExists(extensionlessImportPath + ".json")) {
			return ".json";
		}
		return "";
	}

	static function errorOnImplicitAnyModule(c:Checker, isError:Bool, errorNode:Node, mode:ResolutionMode, resolvedModule:ResolvedModule, moduleReference:std.String):Void {
		if (Checker.isSideEffectImport(errorNode)) {
			return;
		}

		var errorInfo:Diagnostic = null;
		if (!Tspath.IsExternalModuleNameRelative(moduleReference) && resolvedModule.PackageId.Name != "") {
			errorInfo = c.createModuleNotFoundChain(resolvedModule, errorNode, moduleReference, mode, resolvedModule.PackageId.Name);
		}
		c.addErrorOrSuggestion(isError,
			Checker.NewDiagnosticChainForNode(errorInfo, errorNode, Diagnostics.Could_not_find_a_declaration_file_for_module_0_1_implicitly_has_an_any_type,
				moduleReference, resolvedModule.ResolvedFileName));
	}

	static function createModuleNotFoundChain(c:Checker, resolvedModule:ResolvedModule, errorNode:Node, moduleReference:std.String, mode:ResolutionMode, packageName:std.String):Diagnostic {
		// Store the original packageName for repopulateInfo before any modifications
		var storedPackageName = packageName;
		if (storedPackageName == moduleReference) {
			storedPackageName = "";
		}

		final details = Checker.CreateModuleNotFoundChain(c.program, Ast.GetSourceFileOfNode(errorNode), moduleReference, mode, packageName);
		final result = Checker.NewDiagnosticForNode(errorNode, details.Message, ...rangeOf(details.Args));
		final info = new RepopulateDiagnosticInfo();
		info.Kind = RepopulateModuleNotFound;
		info.ModuleReference = moduleReference;
		info.Mode = mode;
		info.PackageName = storedPackageName;
		result.SetRepopulateInfo(info);
		return result;
	}

	static function createModeMismatchDetails(c:Checker, sourceFile:SourceFile, errorNode:Node):Diagnostic {
		final details = Checker.CreateModeMismatchDetails(c.program, sourceFile);
		final result = Checker.NewDiagnosticForNode(errorNode, details.Message, ...rangeOf(details.Args));
		final info = new RepopulateDiagnosticInfo();
		info.Kind = RepopulateModeMismatch;
		result.SetRepopulateInfo(info);
		return result;
	}

	static function tryFindAmbientModule(c:Checker, moduleName:std.String, withAugmentations:Bool):Symbol {
		if (Tspath.IsExternalModuleNameRelative(moduleName)) {
			return null;
		}
		final symbol = c.getSymbol(c.globals, "\"" + moduleName + "\"", SymbolFlagsValueModule);
		// merged symbol is module declaration symbol combined with all augmentations
		if (withAugmentations) {
			return c.getMergedSymbol(symbol);
		}
		return symbol;
	}

	public static function GetAmbientModules(c:Checker):Array<Symbol> {
		// PORT: sync.Once → flag in the `ambientModulesOnce` field.
		if (c.ambientModulesOnce == null) {
			c.ambientModulesOnce = true;
			if (c.globals != null) {
				for (sym => global in c.globals) {
					if (StringTools.startsWith(sym, "\"") && StringTools.endsWith(sym, "\"")) {
						if (c.ambientModules == null) {
							c.ambientModules = [];
						}
						c.ambientModules.push(global);
					}
				}
			}
		}
		return c.ambientModules;
	}

	static function resolveExternalModuleSymbol(c:Checker, moduleSymbol:Symbol, dontResolveAlias:Bool):Symbol {
		if (moduleSymbol != null) {
			final exportEquals = c.resolveSymbolEx(symbolTableGet(moduleSymbol.Exports, Ast.InternalSymbolNameExportEquals), dontResolveAlias);
			if (exportEquals != null) {
				return c.getMergedSymbol(exportEquals);
			}
		}
		return moduleSymbol;
	}

	// Resolves the given external module symbol, possibly removing call and construct signatures or creating a
	// wrapper module with a synthetic default.
	static function resolveESModuleSymbol(c:Checker, moduleSymbol:Symbol, node:Node, moduleSpecifier:Node):Symbol {
		var symbol = c.resolveExternalModuleSymbol(moduleSymbol, true /*dontResolveAlias*/);
		if (Ast.IsNonLocalAlias(symbol, SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace)) {
			// When the module has an export= with a pure alias, we transitively resolve and propagate any typeOnlyDeclaration
			symbol = c.getMergedSymbol(c.resolveIndirectionAlias(c.getSymbolOfDeclaration(node), symbol));
		}
		if (symbol != null) {
			final referenceParent = moduleSpecifier.Parent;
			var namespaceImport:Node = null;
			if (Ast.IsImportDeclaration(referenceParent)) {
				namespaceImport = Ast.GetNamespaceDeclarationNode(referenceParent);
			}
			if (namespaceImport != null || Ast.IsImportCall(referenceParent)) {
				var reference:Node;
				if (Ast.IsImportCall(referenceParent)) {
					reference = referenceParent.Arguments()[0];
				} else {
					reference = referenceParent.ModuleSpecifier();
				}
				final typ = c.getTypeOfSymbol(symbol);
				final defaultOnlyType = c.getTypeWithSyntheticDefaultOnly(typ, symbol, moduleSymbol, reference);
				if (defaultOnlyType != null) {
					return c.cloneTypeAsModuleType(symbol, defaultOnlyType, referenceParent);
				}

				final targetFile = Core.Find(moduleSymbol.Declarations, Ast.IsSourceFile);
				final usageMode = c.getEmitSyntaxForModuleSpecifierExpression(reference);
				var exportModuleDotExportsSymbol:Symbol = null;
				if (namespaceImport != null && targetFile != null
					&& (ModuleKindNode20 : Int) <= (c.moduleKind : Int) && (c.moduleKind : Int) <= (ModuleKindNodeNext : Int)
					&& usageMode == ModuleKindCommonJS
					&& c.program.GetImpliedNodeFormatForEmit(hasFileName(targetFile.AsSourceFile())) == ModuleKindESNext) {
					exportModuleDotExportsSymbol = c.getExportOfModule(symbol, Ast.InternalSymbolNameModuleExports, namespaceImport, true /*dontResolveAlias*/);
				}
				if (exportModuleDotExportsSymbol != null) {
					if (c.hasSignatures(typ)) {
						return c.cloneTypeAsModuleType(exportModuleDotExportsSymbol, typ, referenceParent);
					}
					return exportModuleDotExportsSymbol;
				}

				final isEsmCjsRef = targetFile != null
					&& Checker.isESMFormatImportImportingCommonjsFormatFile(usageMode, c.program.GetImpliedNodeFormatForEmit(hasFileName(targetFile.AsSourceFile())));
				if (c.hasSignatures(typ)
					|| c.getPropertyOfTypeEx(typ, Ast.InternalSymbolNameDefault, true /*skipObjectFunctionPropertyAugment*/, false /*includeTypeOnlyMembers*/) != null
					|| isEsmCjsRef) {
					var moduleType:Type;
					if ((typ.Flags() & TypeFlagsStructuredType) != 0) {
						moduleType = c.getTypeWithSyntheticDefaultImportType(typ, symbol, moduleSymbol, reference);
					} else {
						moduleType = c.createDefaultPropertyWrapperForModule(symbol, symbol.Parent, null);
					}
					return c.cloneTypeAsModuleType(symbol, moduleType, referenceParent);
				}
			}
		}
		return symbol;
	}

	static function hasSignatures(c:Checker, t:Type):Bool {
		return Core.len(c.getSignaturesOfStructuredType(t, SignatureKindCall)) > 0 || Core.len(c.getSignaturesOfStructuredType(t, SignatureKindConstruct)) > 0;
	}

	static function getTypeWithSyntheticDefaultOnly(c:Checker, t:Type, symbol:Symbol, originalSymbol:Symbol, moduleSpecifier:Node):Type {
		final hasDefaultOnly = c.isOnlyImportableAsDefault(moduleSpecifier, null);
		if (hasDefaultOnly && t != null && !c.isErrorType(t)) {
			final key = CachedTypeKey.keyOf(CachedTypeKindDefaultOnlyType, t.id);
			final cached = c.cachedTypes.get(key);
			if (cached != null) {
				return cached;
			}
			final result = c.createDefaultPropertyWrapperForModule(symbol, originalSymbol, null);
			c.cachedTypes.set(key, result);
			return result;
		}
		return null;
	}

	static function getTypeWithSyntheticDefaultImportType(c:Checker, t:Type, symbol:Symbol, originalSymbol:Symbol, moduleSpecifier:Node):Type {
		if (t != null && !c.isErrorType(t)) {
			final key = CachedTypeKey.keyOf(CachedTypeKindSyntheticType, t.id);
			final cached = c.cachedTypes.get(key);
			if (cached != null) {
				return cached;
			}
			final file = Core.Find(originalSymbol.Declarations, Ast.IsSourceFile);
			final hasSyntheticDefault = c.canHaveSyntheticDefault(file, originalSymbol, false /*dontResolveAlias*/, moduleSpecifier);
			var syntheticType:Type;
			if (hasSyntheticDefault) {
				final anonymousSymbol = c.newSymbol(SymbolFlagsTypeLiteral, Ast.InternalSymbolNameType);
				final defaultContainingObject = c.createDefaultPropertyWrapperForModule(symbol, originalSymbol, anonymousSymbol);
				c.valueSymbolLinks.Get(anonymousSymbol).resolvedType = defaultContainingObject;
				if (c.isValidSpreadType(t)) {
					syntheticType = c.getSpreadType(t, defaultContainingObject, anonymousSymbol, 0 /*objectFlags*/, false /*readonly*/);
				} else {
					syntheticType = defaultContainingObject;
				}
			} else {
				syntheticType = t;
			}
			c.cachedTypes.set(key, syntheticType);
			return syntheticType;
		}
		return t;
	}

	static function isCommonJSRequire(c:Checker, node:Node):Bool {
		if (!Ast.IsRequireCall(node, true /*requireStringLiteralLikeArgument*/)) {
			return false;
		}
		if (!Ast.IsIdentifier(node.Expression())) {
			throw "Expected identifier for require call";
		}
		// Make sure require is not a local function
		final resolvedRequire = c.resolveName(node.Expression(), node.Expression().Text(), SymbolFlagsValue, null /*nameNotFoundMessage*/, true /*isUse*/,
			false /*excludeGlobals*/);
		if (resolvedRequire == c.requireSymbol) {
			return true;
		}
		// project includes symbol named 'require' - make sure that it is ambient and local non-alias
		if (resolvedRequire == null || (resolvedRequire.Flags & SymbolFlagsAlias) != 0) {
			return false;
		}

		var targetDeclarationKind:Kind;
		if ((resolvedRequire.Flags & SymbolFlagsFunction) != 0) {
			targetDeclarationKind = KindFunctionDeclaration;
		} else if ((resolvedRequire.Flags & SymbolFlagsVariable) != 0) {
			targetDeclarationKind = KindVariableDeclaration;
		} else {
			targetDeclarationKind = KindUnknown;
		}
		if (targetDeclarationKind != KindUnknown) {
			final decl = Ast.GetDeclarationOfKind(resolvedRequire, targetDeclarationKind);
			// function/variable declaration should be ambient
			return decl != null && (decl.Flags & NodeFlagsAmbient) != 0;
		}
		return false;
	}

	static function createDefaultPropertyWrapperForModule(c:Checker, symbol:Symbol, originalSymbol:Symbol, anonymousSymbol:Symbol):Type {
		final memberTable:SymbolTable = new SymbolTable();
		final newSymbol = c.newSymbol(SymbolFlagsAlias, Ast.InternalSymbolNameDefault);
		newSymbol.Parent = originalSymbol;
		c.valueSymbolLinks.Get(newSymbol).nameType = c.getStringLiteralType("default");
		c.aliasSymbolLinks.Get(newSymbol).aliasTarget = c.resolveSymbol(symbol);
		memberTable.set(Ast.InternalSymbolNameDefault, newSymbol);
		return c.newAnonymousType(anonymousSymbol, memberTable, null, null, null);
	}

	static function cloneTypeAsModuleType(c:Checker, symbol:Symbol, moduleType:Type, referenceParent:Node):Symbol {
		final result = c.newSymbol(symbol.Flags, symbol.Name);
		result.Declarations = Slices.Clone(symbol.Declarations);
		result.ValueDeclaration = symbol.ValueDeclaration;
		result.Members = cloneSymbolTable(symbol.Members);
		result.Exports = cloneSymbolTable(symbol.Exports);
		result.Parent = symbol.Parent;
		final links = c.exportTypeLinks.Get(result);
		links.target = symbol;
		links.originatingImport = referenceParent;
		final resolvedModuleType = c.resolveStructuredTypeMembers(moduleType);
		c.valueSymbolLinks.Get(result).resolvedType = c.newAnonymousType(result, resolvedModuleType.members, null, null, resolvedModuleType.indexInfos);
		return result;
	}

	static function getTargetOfAliasDeclaration(c:Checker, node:Node):Symbol {
		if (node == null) {
			return null;
		}
		switch (node.Kind) {
			case KindImportEqualsDeclaration | KindVariableDeclaration:
				return c.getTargetOfImportEqualsDeclaration(node);
			case KindImportClause:
				return c.getTargetOfImportClause(node);
			case KindNamespaceImport:
				return c.getTargetOfNamespaceImport(node);
			case KindNamespaceExport:
				return c.getTargetOfNamespaceExport(node);
			case KindImportSpecifier | KindBindingElement:
				return c.getTargetOfImportSpecifier(node);
			case KindExportSpecifier:
				return c.getTargetOfExportSpecifier(node, SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace, true /*dontRecursivelyResolve*/);
			case KindExportAssignment:
				return c.getTargetOfExportAssignment(node);
			case KindBinaryExpression:
				return c.getTargetOfBinaryExpression(node);
			case KindNamespaceExportDeclaration:
				return c.getTargetOfNamespaceExportDeclaration(node);
			case KindShorthandPropertyAssignment:
				return c.resolveEntityName(node.AsShorthandPropertyAssignment().Name(), SymbolFlagsValue | SymbolFlagsType | SymbolFlagsNamespace,
					true /*ignoreErrors*/, true /*dontRecursivelyResolve*/, null /*location*/);
			case KindPropertyAssignment:
				return c.getTargetOfAliasLikeExpression(node.Initializer());
			case KindElementAccessExpression | KindPropertyAccessExpression:
				return c.getTargetOfAccessExpression(node);
			default:
		}
		throw "Unhandled case in getTargetOfAliasDeclaration: " + node.Kind.String();
	}

	/**
	 * Resolves a qualified name and any involved aliases.
	 */
	static function resolveEntityName(c:Checker, name:Node, meaning:SymbolFlags, ignoreErrors:Bool, dontResolveAlias:Bool, location:Node):Symbol {
		if (Ast.NodeIsMissing(name)) {
			return null;
		}
		var symbol:Symbol = null;
		switch (name.Kind) {
			case KindIdentifier:
				var message:Message = null;
				if (!ignoreErrors) {
					if (meaning == SymbolFlagsNamespace || Ast.NodeIsSynthesized(name)) {
						message = Diagnostics.Cannot_find_namespace_0;
					} else {
						message = c.getCannotFindNameDiagnosticForName(Ast.GetFirstIdentifier(name));
					}
				}
				var resolveLocation = location;
				if (resolveLocation == null) {
					resolveLocation = name;
				}
				if (meaning == SymbolFlagsNamespace) {
					symbol = c.getMergedSymbol(c.resolveName(resolveLocation, name.Text(), meaning, null, true /*isUse*/, false /*excludeGlobals*/));
					if (symbol == null) {
						final alias = c.getMergedSymbol(c.resolveName(resolveLocation, name.Text(), SymbolFlagsAlias, null, true /*isUse*/, false /*excludeGlobals*/));
						if (alias != null && alias.Name == Ast.InternalSymbolNameExportEquals) {
							// resolve typedefs exported from commonjs, stored on the module symbol
							symbol = alias.Parent;
						}
					}
					if (symbol == null && message != null) {
						c.resolveName(resolveLocation, name.Text(), meaning, message, true /*isUse*/, false /*excludeGlobals*/);
					}
				} else {
					symbol = c.getMergedSymbol(c.resolveName(resolveLocation, name.Text(), meaning, message, true /*isUse*/, false /*excludeGlobals*/));
				}
			case KindQualifiedName:
				final qualified = name.AsQualifiedName();
				symbol = c.resolveQualifiedName(name, qualified.Left, qualified.Right, meaning, ignoreErrors, location);
			case KindPropertyAccessExpression:
				final access = name.AsPropertyAccessExpression();
				symbol = c.resolveQualifiedName(name, access.Expression, access.Name(), meaning, ignoreErrors, location);
			default:
				throw "Unknown entity name kind";
		}
		if (symbol != null && symbol != c.unknownSymbol) {
			if (!Ast.NodeIsSynthesized(name) && Ast.IsEntityName(name)
				&& ((symbol.Flags & SymbolFlagsAlias) != 0 || name.Parent != null && name.Parent.Kind == KindExportAssignment)) {
				c.markSymbolOfAliasDeclarationIfTypeOnly(Checker.getAliasDeclarationFromName(name), null);
			}
			// We know a symbol with the given meaning exists along the alias chain, so resolve until we find it.
			while ((symbol.Flags & meaning) == 0 && !dontResolveAlias && (symbol.Flags & SymbolFlagsAlias) != 0) {
				symbol = c.resolveAlias(symbol);
			}
		}
		return symbol;
	}

	static function resolveQualifiedName(c:Checker, name:Node, left:Node, right:Node, meaning:SymbolFlags, ignoreErrors:Bool, location:Node):Symbol {
		var namespace = c.resolveEntityName(left, SymbolFlagsNamespace, ignoreErrors, false /*dontResolveAlias*/, location);
		if (namespace == null || Ast.NodeIsMissing(right)) {
			return null;
		}
		if (namespace == c.unknownSymbol) {
			return namespace;
		}
		if (namespace.ValueDeclaration != null
			&& Ast.IsInJSFile(namespace.ValueDeclaration)
			&& c.compilerOptions.GetModuleResolutionKind() != ModuleResolutionKindBundler
			&& Ast.IsVariableDeclaration(namespace.ValueDeclaration)
			&& namespace.ValueDeclaration.Initializer() != null
			&& c.isCommonJSRequire(namespace.ValueDeclaration.Initializer())) {
			final moduleName = namespace.ValueDeclaration.Initializer().Arguments()[0];
			final moduleSym = c.resolveExternalModuleName(moduleName, moduleName, false /*ignoreErrors*/);
			if (moduleSym != null) {
				final resolvedModuleSymbol = c.resolveExternalModuleSymbol(moduleSym, false /*dontResolveAlias*/);
				if (resolvedModuleSymbol != null) {
					namespace = resolvedModuleSymbol;
				}
			}
		}
		final text = right.Text();
		var symbol = c.getMergedSymbol(c.getSymbol(c.getExportsOfSymbol(namespace), text, meaning));
		if (symbol == null && (namespace.Flags & SymbolFlagsAlias) != 0) {
			// `namespace` can be resolved further if there was a symbol merge with a re-export
			symbol = c.getMergedSymbol(c.getSymbol(c.getExportsOfSymbol(c.resolveAlias(namespace)), text, meaning));
		}
		if (symbol == null) {
			if (!ignoreErrors) {
				final namespaceName = c.getFullyQualifiedName(namespace, null /*containingLocation*/);
				final declarationName = Scanner.DeclarationNameToString(right);
				final suggestionForNonexistentModule = c.getSuggestedSymbolForNonexistentModule(right, namespace);
				if (suggestionForNonexistentModule != null) {
					c.error(right, Diagnostics.X_0_has_no_exported_member_named_1_Did_you_mean_2, namespaceName, declarationName,
						c.symbolToString(suggestionForNonexistentModule));
					return null;
				}
				var containingQualifiedName:Node = null;
				if (Ast.IsQualifiedName(name)) {
					containingQualifiedName = Checker.getContainingQualifiedNameNode(name);
				}
				final canSuggestTypeof = c.globalObjectType != null && (meaning & SymbolFlagsType) != 0 && containingQualifiedName != null
					&& !Ast.IsTypeOfExpression(containingQualifiedName.Parent) && c.tryGetQualifiedNameAsValue(containingQualifiedName) != null;
				if (canSuggestTypeof) {
					c.error(containingQualifiedName, Diagnostics.X_0_refers_to_a_value_but_is_being_used_as_a_type_here_Did_you_mean_typeof_0,
						Checker.entityNameToString(containingQualifiedName));
					return null;
				}
				if ((meaning & SymbolFlagsNamespace) != 0) {
					if (Ast.IsQualifiedName(name.Parent)) {
						final exportedTypeSymbol = c.getMergedSymbol(c.getSymbol(c.getExportsOfSymbol(namespace), text, SymbolFlagsType));
						if (exportedTypeSymbol != null) {
							final qualified = name.Parent.AsQualifiedName();
							c.error(qualified.Right,
								Diagnostics.Cannot_access_0_1_because_0_is_a_type_but_not_a_namespace_Did_you_mean_to_retrieve_the_type_of_the_property_1_in_0_with_0_1,
								c.symbolToString(exportedTypeSymbol), qualified.Right.Text());
							return null;
						}
					}
				}
				c.error(right, Diagnostics.Namespace_0_has_no_exported_member_1, namespaceName, declarationName);
			}
		}
		return symbol;
	}

	static function tryGetQualifiedNameAsValue(c:Checker, node:Node):Symbol {
		final id = Ast.GetFirstIdentifier(node);
		var symbol = c.resolveName(id, id.Text(), SymbolFlagsValue, null /*nameNotFoundMessage*/, true /*isUse*/, false /*excludeGlobals*/);
		if (symbol == null) {
			return null;
		}
		var n = id;
		while (Ast.IsQualifiedName(n.Parent)) {
			final t = c.getTypeOfSymbol(symbol);
			symbol = c.getPropertyOfType(t, n.Parent.AsQualifiedName().Right.Text());
			if (symbol == null) {
				return null;
			}
			n = n.Parent;
		}
		return symbol;
	}

	static function getSuggestedSymbolForNonexistentModule(c:Checker, name:Node, targetModule:Symbol):Symbol {
		return c.getSpellingSuggestionForName(name.Text(), symbolTableValues(c.getExportsOfModule(targetModule)), SymbolFlagsModuleMember);
	}

	static function getFullyQualifiedName(c:Checker, symbol:Symbol, containingLocation:Node):std.String {
		if (symbol.Parent != null) {
			return c.getFullyQualifiedName(symbol.Parent, containingLocation) + "." + c.symbolToString(symbol);
		}
		return c.symbolToStringEx(symbol, containingLocation, SymbolFlagsAll, SymbolFormatFlagsDoNotIncludeSymbolChain | SymbolFormatFlagsAllowAnyNodeKind);
	}

	static function getExportsOfSymbol(c:Checker, symbol:Symbol):SymbolTable {
		if ((symbol.Flags & SymbolFlagsLateBindingContainer) != 0) {
			return c.getResolvedMembersOrExportsOfSymbol(symbol, MembersOrExportsResolutionKindResolvedExports);
		}
		if ((symbol.Flags & SymbolFlagsModule) != 0) {
			return c.getExportsOfModule(symbol);
		}
		return symbol.Exports;
	}

	static function getResolvedMembersOrExportsOfSymbol(c:Checker, symbol:Symbol, resolutionKind:MembersOrExportsResolutionKind):SymbolTable {
		final links = c.membersAndExportsLinks.Get(symbol);
		if (links[(resolutionKind : Int)] == null) {
			final isStatic = resolutionKind == MembersOrExportsResolutionKindResolvedExports;
			var earlySymbols = symbol.Exports;
			if (!isStatic) {
				earlySymbols = symbol.Members;
			} else if ((symbol.Flags & SymbolFlagsModule) != 0) {
				earlySymbols = c.getExportsOfModuleWorker(symbol).a;
			}
			links[(resolutionKind : Int)] = earlySymbols;
			// fill in any as-yet-unresolved late-bound members.
			var lateSymbols:SymbolTable = null;
			for (decl in rangeOf(symbol.Declarations)) {
				for (member in rangeOf(Checker.getMembersOfDeclaration(decl))) {
					if (isStatic == Ast.HasStaticModifier(member)) {
						if (c.hasLateBindableName(member)) {
							if (lateSymbols == null) {
								lateSymbols = new SymbolTable();
							}
							c.lateBindMember(symbol, earlySymbols, lateSymbols, member);
						} else if (c.hasLateBindableIndexSignature(member)) {
							if (lateSymbols == null) {
								lateSymbols = new SymbolTable();
							}
							c.lateBindIndexSignature(symbol, earlySymbols, lateSymbols, member /* as LateBoundDeclaration | LateBoundBinaryExpressionDeclaration */);
						}
					}
				}
			}
			if (isStatic) {
				final assignmentSymbol = symbolTableGet(symbol.Exports, Ast.InternalSymbolNameAssignmentDeclaration);
				if (assignmentSymbol != null) {
					for (member in rangeOf(assignmentSymbol.Declarations)) {
						if (c.hasLateBindableName(member)) {
							if (lateSymbols == null) {
								lateSymbols = new SymbolTable();
							}
							c.lateBindMember(symbol, earlySymbols, lateSymbols, member);
						}
					}
				}
			}
			links[(resolutionKind : Int)] = c.combineSymbolTables(earlySymbols, lateSymbols);
		}
		return links[(resolutionKind : Int)];
	}

	// Performs late-binding of a dynamic member. This performs the same function for
	// late-bound members that `declareSymbol` in binder.ts performs for early-bound
	// members.
	//
	// If a symbol is a dynamic name from a computed property, we perform an additional "late"
	// binding phase to attempt to resolve the name for the symbol from the type of the computed
	// property's expression. If the type of the expression is a string-literal, numeric-literal,
	// or unique symbol type, we can use that type as the name of the symbol.
	//
	// For example, given:
	//
	//	const x = Symbol();
	//
	//	interface I {
	//	  [x]: number;
	//	}
	//
	// The binder gives the property `[x]: number` a special symbol with the name "__computed".
	// In the late-binding phase we can type-check the expression `x` and see that it has a
	// unique symbol type which we can then use as the name of the member. This allows users
	// to define custom symbols that can be used in the members of an object type.
	//
	// @param parent The containing symbol for the member.
	// @param earlySymbols The early-bound symbols of the parent.
	// @param lateSymbols The late-bound symbols of the parent.
	// @param decl The member to bind.
	static function lateBindMember(c:Checker, parent:Symbol, earlySymbols:SymbolTable, lateSymbols:SymbolTable, decl:Node):Symbol {
		Debug.Assert(decl.Symbol() != null, "The member is expected to have a symbol.");
		final links = c.symbolNodeLinks.Get(decl);
		if (links.resolvedSymbol == null) {
			// In the event we attempt to resolve the late-bound name of this member recursively,
			// fall back to the early-bound name of this member.
			links.resolvedSymbol = decl.Symbol();
			var declName:Node;
			if (Ast.IsBinaryExpression(decl)) {
				declName = decl.AsBinaryExpression().Left;
			} else {
				declName = decl.Name();
			}
			var t:Type;
			if (Ast.IsElementAccessExpression(declName)) {
				t = c.checkExpressionCached(declName.AsElementAccessExpression().ArgumentExpression);
			} else {
				t = c.checkComputedPropertyName(declName);
			}
			if (Checker.isTypeUsableAsPropertyName(t)) {
				final memberName = Checker.getPropertyNameFromType(t);
				final symbolFlags = decl.Symbol().Flags;
				// Get or add a late-bound symbol for the member. This allows us to merge late-bound accessor declarations.
				var lateSymbol = lateSymbols.get(memberName);
				if (lateSymbol == null) {
					lateSymbol = c.newSymbolEx(SymbolFlagsNone, memberName, CheckFlagsLate);
					lateSymbols.set(memberName, lateSymbol);
				}
				// Report an error if there's a symbol declaration with the same name and conflicting flags.
				final earlySymbol = symbolTableGet(earlySymbols, memberName);
				if ((lateSymbol.Flags & Checker.getExcludedSymbolFlags(symbolFlags)) != 0) {
					// If we have an existing early-bound member, combine its declarations so that we can
					// report an error at each declaration.
					var declarations:Array<Node>;
					if (earlySymbol != null) {
						declarations = Core.Concatenate(earlySymbol.Declarations, lateSymbol.Declarations);
					} else {
						declarations = lateSymbol.Declarations;
					}
					var name = memberName;
					if ((t.flags & TypeFlagsUniqueESSymbol) != 0) {
						name = Scanner.DeclarationNameToString(declName);
					}
					for (d in rangeOf(declarations)) {
						c.error(Core.OrElse(Ast.GetNameOfDeclaration(d), d), Diagnostics.Duplicate_identifier_0, name);
					}
					c.error(Core.OrElse(declName, decl), Diagnostics.Duplicate_identifier_0, name);
					if ((lateSymbol.Flags & SymbolFlagsAccessor) != 0 && (lateSymbol.Flags & SymbolFlagsAccessor) != (symbolFlags & SymbolFlagsAccessor)) {
						lateSymbol.Flags |= SymbolFlagsAccessor;
					}
					lateSymbol = c.newSymbolEx(SymbolFlagsNone, memberName, CheckFlagsLate);
				}
				c.valueSymbolLinks.Get(lateSymbol).nameType = t;
				c.addDeclarationToLateBoundSymbol(lateSymbol, decl, symbolFlags);
				if (lateSymbol.Parent == null) {
					lateSymbol.Parent = parent;
				}
				links.resolvedSymbol = lateSymbol;
			}
		}
		return links.resolvedSymbol;
	}

	// --- private helpers (P4) ---

	// PORT: Go `range` over a possibly-nil slice (PORTING.md §3): a nil slice iterates zero times.
	static inline function rangeOf<T>(a:Null<Array<T>>):Array<T> {
		return a != null ? a : [];
	}

	// PORT: Go `slices.Values(s)` as the checker's iter.Seq form `(yield) -> Void`.
	static function valuesOf<T>(s:Null<Array<T>>):(yield:(T) -> Bool) -> Void {
		return function(yield_:(T) -> Bool):Void {
			if (s != null) {
				for (v in s) {
					if (!yield_(v)) {
						return;
					}
				}
			}
		};
	}

	// PORT: Go map lookup `table[name]` on a possibly-nil ast.SymbolTable (nil map reads as empty).
	static inline function symbolTableGet(table:SymbolTable, name:std.String):Symbol {
		return table != null ? table.get(name) : null;
	}
	// PORT: Go untyped const `ObjectFlagsContainsSpread = 1 << 22` (types.go) is not in the ObjectFlags enum of
	// Types.hx (the skeleton put the untyped consts as Int statics on Checker); typed local copy, like Relater.hx.
	static inline final ObjectFlagsContainsSpread:ObjectFlags = 1 << 22;
	
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
	
	// PORT: *ast.SourceFile passed where Go converts it to ast.HasFileName (structural interface);
	// Haxe uses the cached adapter of modulespecifiers.
	static inline function hasFileName(file:SourceFile):HasFileName {
		return ts.modulespecifiers.Types.SourceFileAdapter.Of(file);
	}
	
	// PORT: Go `slices.Compact` (drops consecutive equal elements) on a []*ast.Node; nil stays nil.
	static function compactNodes(s:Array<Node>):Array<Node> {
		if (s == null || s.length < 2) {
			return s;
		}
		final result = [s[0]];
		for (i in 1...s.length) {
			if (s[i] != s[i - 1]) {
				result.push(s[i]);
			}
		}
		return result;
	}
	
	// PORT: Go `maps.Clone` of an ast.SymbolTable: nil stays nil.
	static function cloneSymbolTable(m:SymbolTable):SymbolTable {
		return m != null ? m.copy() : null;
	}
	
	// PORT: Go `findInMap(exports, ...)` on an ast.SymbolTable (Checker.findInMap takes a GoMap).
	// Go map iteration order is random; the first match in StringMap order is returned.
	static function findInSymbolTable(m:SymbolTable, predicate:(Symbol) -> Bool):Symbol {
		if (m != null) {
			for (value in m) {
				if (predicate(value)) {
					return value;
				}
			}
		}
		return null;
	}
	
	// PORT: Go `maps.Values(table)` on an ast.SymbolTable as the checker's iter.Seq form `(yield) -> Void`.
	static function symbolTableValues(table:SymbolTable):(yield:(Symbol) -> Bool) -> Void {
		return function(yield_:(Symbol) -> Bool):Void {
			if (table != null) {
				for (s in table) {
					if (!yield_(s)) {
						return;
					}
				}
			}
		};
	}
	
}
