package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/pseudotypenodebuilder.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Methods of pseudotypenodebuilder.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Pseudotypenodebuilder {

	// pseudoTypeToNodeWithCheckerFallback is like pseudoTypeToNode but when the top-level pseudo type
	// is PseudoTypeInferred, it reports any error nodes and then serializes from the checker's type.
	// This avoids incorrect type output when PseudoTypeInferred would derive the type from the
	// original declaration expression in an instantiated context.
	static function pseudoTypeToNodeWithCheckerFallback(b:NodeBuilderImpl, t:PseudoType, checkerType:Type):Node {
		if (t.Kind == PseudoTypeKindInferred) {
			if (!b.ctx.suppressReportInferenceFallback) {
				final errorNodes = t.AsPseudoTypeInferred().ErrorNodes;
				if (Core.len(errorNodes) > 0) {
					for (n in errorNodes) {
						b.ctx.tracker.ReportInferenceFallback(n);
					}
				} else {
					b.ctx.tracker.ReportInferenceFallback(t.AsPseudoTypeInferred().Expression);
				}
			}
			final oldSuppress = b.ctx.suppressReportInferenceFallback;
			b.ctx.suppressReportInferenceFallback = true;
			final result = b.typeToTypeNode(checkerType);
			b.ctx.suppressReportInferenceFallback = oldSuppress;
			return result;
		} else if (t.Kind == PseudoTypeKindDirect) {
			final existing = t.AsPseudoTypeDirect().TypeNode;
			if (!b.canReuseExistingJSTypeNode(existing, checkerType)) {
				if (!b.ctx.suppressReportInferenceFallback) {
					b.ctx.tracker.ReportInferenceFallback(existing);
				}
				final oldSuppress = b.ctx.suppressReportInferenceFallback;
				b.ctx.suppressReportInferenceFallback = true;
				final result = b.typeToTypeNode(checkerType);
				b.ctx.suppressReportInferenceFallback = oldSuppress;
				return result;
			}
		}
		return b.pseudoTypeToNode(t);
	}

	// Maps a pseudochecker's pseudotypes into ast nodes and reports any inference fallback errors the pseudotype structure implies
	static function pseudoTypeToNode(b:NodeBuilderImpl, t:PseudoType):Node {
		Debug.Assert(t != null, "Attempted to serialize nil pseudotype");
		switch (t.Kind) {
			case PseudoTypeKindDirect:
				return b.reuseTypeNode(t.AsPseudoTypeDirect().TypeNode);
			case PseudoTypeKindInferred:
				final inferred = t.AsPseudoTypeInferred();
				final node = inferred.Expression;
				final errorNodes = inferred.ErrorNodes;
				if (Core.len(errorNodes) > 0) {
					for (n in errorNodes) {
						b.ctx.tracker.ReportInferenceFallback(n);
					}
				} else if (Ast.IsEntityNameExpression(node) && Ast.IsDeclaration(node.Parent)) {
					b.ctx.tracker.ReportInferenceFallback(node.Parent);
				} else {
					b.ctx.tracker.ReportInferenceFallback(node);
				}
				if (inferred.IsSignatureReturn) {
					return b.serializeReturnTypeForSignature(b.ch.getSignatureFromDeclaration(node), false);
				}
				// use symbol type from parent declaration to automatically handle expression type widening without duplicating logic
				if (Ast.IsReturnStatement(node.Parent)) {
					final enclosing = Ast.GetContainingFunction(node);
					if (Ast.IsAccessor(enclosing)) {
						return b.serializeTypeForDeclaration(enclosing, null, null, false);
					}
					return b.serializeReturnTypeForSignature(b.ch.getSignatureFromDeclaration(enclosing), false);
				}
				if (Ast.IsArrowFunction(node.Parent) && node.Parent.AsArrowFunction().Body == node) {
					return b.serializeReturnTypeForSignature(b.ch.getSignatureFromDeclaration(node.Parent), false);
				}
				if (Ast.IsDeclaration(node.Parent)) {
					return b.serializeTypeForDeclaration(node.Parent, null, null, false);
				}
				// This might be effectively unreachable. If it's not, it may need more widening rules to mirror checker behavior for whatever expressions are serialized here
				final ty = b.ch.getTypeOfExpression(node);
				return b.typeToTypeNode(ty);
			case PseudoTypeKindNoResult:
				final node = t.AsPseudoTypeNoResult().Declaration;
				b.ctx.tracker.ReportInferenceFallback(node);
				if (Ast.IsFunctionLike(node) && !Ast.IsAccessor(node)) {
					return b.serializeReturnTypeForSignature(b.ch.getSignatureFromDeclaration(node), false);
				}
				return b.serializeTypeForDeclaration(node, null, null, false);
			case PseudoTypeKindMaybeConstLocation:
				final d = t.AsPseudoTypeMaybeConstLocation();
				// see checkExpressionWithContextualType for general literal widening rules which need to be emulated here, plus
				// checkTemplateLiteralExpression for template literal widening rules if the pseudochecker ever supports literalized templates
				var isInConstContext = b.ch.isConstContext(d.Node);
				if (!isInConstContext && Pseudochecker.IsInConstContext(d.Node)) {
					// Only consult the contextual type if the pseudochecker's syntactic check also puts us in a const context.
					// getContextualType returns post-inference results at node-printing time which may not have existed
					// during initial checking (e.g. when the contextual type depends on inference), causing incorrect
					// literal type preservation.
					final contextualType = b.ch.getContextualType(d.Node, ContextFlagsNone);
					final t = b.pseudoTypeToType(d.ConstType);
					if (t != null && b.ch.isLiteralOfContextualType(t, b.ch.instantiateContextualType(contextualType, d.Node, ContextFlagsNone))) {
						isInConstContext = true;
					}
				}
				if (isInConstContext) {
					return b.pseudoTypeToNode(d.ConstType);
				} else {
					return b.pseudoTypeToNode(d.RegularType);
				}
			case PseudoTypeKindUnion:
				var res:Array<Node> = null;
				var hasElidedType = false;
				var hasUndefined = false;
				final members = t.AsPseudoTypeUnion().Types;
				var appendTypeNode:(node:Node) -> Void = null;
				appendTypeNode = (node:Node) -> {
					if (Ast.IsUnionTypeNode(node)) {
						for (node in node.AsUnionTypeNode().Types.Nodes) {
							appendTypeNode(node);
						}
						return;
					}
					if (node.Kind == KindUndefinedKeyword) {
						if (hasUndefined) {
							return;
						}
						hasUndefined = true;
					}
					if (res == null) res = [];
					res.push(node);
				};
				if (members != null) {
					for (m in members) {
						if (!b.ch.strictNullChecks) {
							if (m.Kind == PseudoTypeKindUndefined || m.Kind == PseudoTypeKindNull) {
								hasElidedType = true;
								continue;
							}
						}
						appendTypeNode(b.pseudoTypeToNode(m));
					}
				}
				if (Core.len(res) == 1) {
					return res[0];
				}
				if (Core.len(res) == 0) {
					if (hasElidedType) {
						return b.f.NewKeywordTypeNode(KindAnyKeyword);
					}
					return b.f.NewKeywordTypeNode(KindNeverKeyword);
				}
				return b.f.NewUnionTypeNode(b.f.NewNodeList(res));
			case PseudoTypeKindUndefined:
				if (!b.ch.strictNullChecks) {
					return b.f.NewKeywordTypeNode(KindAnyKeyword);
				}
				return b.f.NewKeywordTypeNode(KindUndefinedKeyword);
			case PseudoTypeKindNull:
				if (!b.ch.strictNullChecks) {
					return b.f.NewKeywordTypeNode(KindAnyKeyword);
				}
				return b.f.NewLiteralTypeNode(b.f.NewKeywordExpression(KindNullKeyword));
			case PseudoTypeKindAny:
				return b.f.NewKeywordTypeNode(KindAnyKeyword);
			case PseudoTypeKindString:
				return b.f.NewKeywordTypeNode(KindStringKeyword);
			case PseudoTypeKindNumber:
				return b.f.NewKeywordTypeNode(KindNumberKeyword);
			case PseudoTypeKindBigInt:
				return b.f.NewKeywordTypeNode(KindBigIntKeyword);
			case PseudoTypeKindBoolean:
				return b.f.NewKeywordTypeNode(KindBooleanKeyword);
			case PseudoTypeKindFalse:
				return b.f.NewLiteralTypeNode(b.f.NewKeywordExpression(KindFalseKeyword));
			case PseudoTypeKindTrue:
				return b.f.NewLiteralTypeNode(b.f.NewKeywordExpression(KindTrueKeyword));
			case PseudoTypeKindSingleCallSignature:
				final d = t.AsPseudoTypeSingleCallSignature();
				final signature = b.ch.getSignatureFromDeclaration(d.Signature);
				final expandedParams = b.ch.getExpandedParameters(signature, true /*skipUnionExpanding*/)[0];
				final cleanup = b.enterNewScope(d.Signature, expandedParams, signature.typeParameters, signature.parameters, signature.mapper);
				// PORT: defer cleanup() → called before the single return below.
				var typeParams:NodeList = null;
				if (Core.len(d.TypeParameters) > 0) {
					final res:Array<Node> = [];
					for (tp in d.TypeParameters) {
						res.push(b.reuseNode(tp.AsNode()));
					}
					typeParams = b.f.NewNodeList(res);
				}
				final params = b.pseudoParametersToNodeList(d.Parameters);
				final returnType = b.pseudoTypeToNode(d.ReturnType);
				final result = b.f.NewFunctionTypeNode(typeParams, params, returnType);
				cleanup();
				return result;
			case PseudoTypeKindTuple:
				var res:Array<Node> = null;
				final elements = t.AsPseudoTypeTuple().Elements;
				if (elements != null) {
					for (e in elements) {
						if (res == null) res = [];
						res.push(b.pseudoTypeToNode(e));
					}
				}
				// pseudo-tuples are implicitly `readonly` since they originate from `as const` contexts
				// but strada *sometimes* fails to add the `readonly` modifier to the generated node.
				final result = b.f.NewTupleTypeNode(b.f.NewNodeList(res));
				b.e.AddEmitFlags(result, EFSingleLine);
				return b.f.NewTypeOperatorNode(KindReadonlyKeyword, result);
			case PseudoTypeKindObjectLiteral:
				final elements = t.AsPseudoTypeObjectLiteral().Elements;
				if (Core.len(elements) == 0) {
					final result = b.f.NewTypeLiteralNode(b.f.NewNodeList(null));
					b.e.AddEmitFlags(result, EFSingleLine);
					return result;
				}
				// NOTE: using the checker's `isConstContext` instead of the pseudochecker's `isInConstContext`
				// results in different results here. The checker one is more "correct" but means we'll mark
				// objects in parameter positions contextually typed by const type parameters as readonly -
				// something a true syntactic ID emitter couldn't possibly know (since the signature could
				// be from across files). This can't *really* happen in any cases ID doesn't already error on, though.
				// Just something to keep in mind if the ID checker keeps growing.
				final isConst = b.ch.isConstContext(elements[0].Name.Parent.Parent);
				final newElements:Array<Node> = [];

				// Member types are serialized within an object type literal, so set the
				// corresponding flag to mirror createTypeNodeFromObjectType. This ensures
				// inaccessible `this` references inside the members are reported (TS2527).
				final restoreObjectLiteralFlags = b.saveRestoreFlags();
				b.ctx.flags |= FlagsInObjectTypeLiteral;

				for (e in elements) {
					var modifiers:ModifierList = null;
					if (isConst || (e.Kind == PseudoObjectElementKindPropertyAssignment && e.AsPseudoPropertyAssignment().Readonly)) {
						modifiers = b.f.NewModifierList([b.f.NewModifier(KindReadonlyKeyword)]);
					}
					var cleanup:() -> Void = null;
					if (e.Kind != PseudoObjectElementKindPropertyAssignment) {
						final signature = b.ch.getSignatureFromDeclaration(e.Signature());
						final expandedParams = b.ch.getExpandedParameters(signature, true /*skipUnionExpanding*/)[0];
						cleanup = b.enterNewScope(e.Signature(), expandedParams, signature.typeParameters, signature.parameters, signature.mapper);
					}
					var newProp:Node = null;
					switch (e.Kind) {
						case PseudoObjectElementKindMethod:
							final d = e.AsPseudoObjectMethod();
							var typeParams:NodeList = null;
							if (Core.len(d.TypeParameters) > 0) {
								final res:Array<Node> = [];
								for (tp in d.TypeParameters) {
									res.push(b.reuseNode(tp.AsNode()));
								}
								typeParams = b.f.NewNodeList(res);
							}
							// PORT: Go `break` out of the switch after the isConst branch → if/else.
							if (isConst) {
								newProp = b.f.NewPropertySignatureDeclaration(modifiers, b.reuseName(e.Name, false /*isMethod*/), null,
									b.f.NewFunctionTypeNode(typeParams, b.pseudoParametersToNodeList(d.Parameters), b.pseudoTypeToNode(d.ReturnType)), null);
							} else {
								newProp = b.f.NewMethodSignatureDeclaration(modifiers, b.reuseName(e.Name, true /*isMethod*/), null, typeParams,
									b.pseudoParametersToNodeList(d.Parameters), b.pseudoTypeToNode(d.ReturnType));
							}
						case PseudoObjectElementKindPropertyAssignment:
							final d = e.AsPseudoPropertyAssignment();
							newProp = b.f.NewPropertySignatureDeclaration(modifiers, b.reuseName(e.Name, false /*isMethod*/), null, b.pseudoTypeToNode(d.Type), null);
						case PseudoObjectElementKindSetAccessor:
							final d = e.AsPseudoSetAccessor();
							newProp = b.f.NewSetAccessorDeclaration(null, b.reuseName(e.Name, false /*isMethod*/), null,
								b.f.NewNodeList([b.pseudoParameterToNode(d.Parameter)]), null, null, null);
						case PseudoObjectElementKindGetAccessor:
							final d = e.AsPseudoGetAccessor();
							newProp = b.f.NewGetAccessorDeclaration(null, b.reuseName(e.Name, false /*isMethod*/), null, null, b.pseudoTypeToNode(d.Type), null,
								null);
						default:
					}
					if (b.ctx.enclosingFile == Ast.GetSourceFileOfNode(e.Name)) {
						b.e.SetCommentRange(newProp, e.Name.Parent.Loc);
					}
					newElements.push(newProp);
					if (cleanup != null) {
						cleanup();
					}
				}
				restoreObjectLiteralFlags();
				final result = b.f.NewTypeLiteralNode(b.f.NewNodeList(newElements));
				if (b.ctx.flags & FlagsMultilineObjectLiterals == 0) {
					b.e.AddEmitFlags(result, EFSingleLine);
				}
				return result;
			case PseudoTypeKindStringLiteral | PseudoTypeKindNumericLiteral | PseudoTypeKindBigIntLiteral:
				final source = t.AsPseudoTypeLiteral().Node;
				return b.f.NewLiteralTypeNode(b.reuseNode(source));
			default:
				Debug.AssertNever(t.Kind, "Unhandled pseudotype kind in pseudotype node construction");
				return null;
		}
	}

	static function pseudoParametersToNodeList(b:NodeBuilderImpl, params:Array<PseudoParameter>):NodeList {
		final res:Array<Node> = [];
		if (params != null) {
			for (p in params) {
				res.push(b.pseudoParameterToNode(p));
			}
		}
		return b.f.NewNodeList(res);
	}

	static function pseudoParameterToNode(b:NodeBuilderImpl, p:PseudoParameter):Node {
		var dotDotDot:Node = null;
		var questionMark:Node = null;
		if (p.Rest) {
			dotDotDot = b.f.NewToken(KindDotDotDotToken);
		}
		if (p.Optional) {
			questionMark = b.f.NewToken(KindQuestionToken);
		}
		final parameter = b.f.NewParameterDeclaration(null, dotDotDot,
			// matches strada behavior of always reserializing param names from scratch
			b.parameterToParameterDeclarationName(p.Name.Parent.Symbol(), p.Name.Parent), questionMark, b.pseudoTypeToNode(p.Type), null);
		final original = p.Name.Parent;
		if (Ast.IsParameterDeclaration(original)) {
			b.setCommentRange(parameter, original);
		}
		return parameter;
	}

	// see `typeNodeIsEquivalentToType` in strada, but applied more broadly here, so is setup to handle more equivalences - strada only used it via
	// the `canReuseTypeNodeAnnotation` host hook and not the `canReuseTypeNode` hook, which meant locations using the later were reliant on
	// over-invalidation by the ID inference engine to not emit incorrect types.
	static function pseudoTypeEquivalentToType(b:NodeBuilderImpl, t:PseudoType, type_:Type, isOptionalAnnotated:Bool, reportErrors:Bool):Bool {
		// if type_ resolves to an error, we charitably assume equality, since we might be in a single-file checking mode
		if (type_ != null && b.ch.isErrorType(type_)) {
			return true;
		}
		// If we can easily operate on just types, we should
		final typeFromPseudo = b.pseudoTypeToType(t); // note: cannot convert complex types like objects, which must be validated separately
		if (typeFromPseudo == type_) {
			return true;
		}
		var undefinedStripped = type_;
		if (isOptionalAnnotated) {
			undefinedStripped = b.ch.getTypeWithFacts(type_, TypeFactsNEUndefined);
		}
		if (typeFromPseudo != null && type_ != null) {
			if (isOptionalAnnotated) {
				if (undefinedStripped == typeFromPseudo) {
					return true;
				}
				if (typeFromPseudo.flags & TypeFlagsUnion != 0 && undefinedStripped.flags & TypeFlagsUnion != 0) {
					// does union comparison in general, since the unions may not be `==` identical due to aliasing and the like
					if (b.ch.compareTypesIdentical(typeFromPseudo, undefinedStripped) == TernaryTrue) {
						return true;
					}
				}
			}
			// handles freshness mismatches (e.g., fresh true vs regular true in as const)
			if (b.ch.getRegularTypeOfLiteralType(typeFromPseudo) == b.ch.getRegularTypeOfLiteralType(type_)) {
				return true;
			}
			if (typeFromPseudo.flags & TypeFlagsUnion != 0 && type_.flags & TypeFlagsUnion != 0) {
				// handles union comparison in general, since unions may not be `==` identical due to aliasing
				if (b.ch.compareTypesIdentical(typeFromPseudo, type_) == TernaryTrue) {
					return true;
				}
			}
		}
		// otherwise, fallback to actual pseudo/type cross-comparisons
		switch (t.Kind) {
			case PseudoTypeKindInferred:
				// PseudoTypeInferred with error nodes identifies specific problematic children.
				// Report fine-grained errors on them, then return false so the parent falls back
				// to checker-based serialization (avoiding issues like reusing raw JSON string
				// literal property names from the pseudochecker's AST).
				final errorNodes = t.AsPseudoTypeInferred().ErrorNodes;
				if (Core.len(errorNodes) > 0) {
					if (reportErrors) {
						for (n in errorNodes) {
							b.ctx.tracker.ReportInferenceFallback(n);
						}
					}
					return false;
				}
				if (reportErrors) {
					b.ctx.tracker.ReportInferenceFallback(t.AsPseudoTypeInferred().Expression);
				}
				return false;
			case PseudoTypeKindObjectLiteral:
				final pt = t.AsPseudoTypeObjectLiteral();
				if (type_ == null) {
					return false;
				}
				final targetProps = b.ch.getPropertiesOfType(undefinedStripped);
				// Count total declarations across all target prop symbols to handle getter/setter pairs,
				// which are two elements in pt.Elements but only one symbol in targetProps.
				var targetDeclCount = 0;
				if (targetProps != null) {
					for (prop in targetProps) {
						targetDeclCount += Core.len(prop.Declarations);
					}
				}
				if (Core.len(pt.Elements) != targetDeclCount) {
					return false;
				}
				if (pt.Elements != null) {
					for (e in pt.Elements) {
						var targetProp:Symbol = null;
						final elemSymbol = e.Name.Parent.Symbol();
						if (elemSymbol != null) {
							targetProp = b.ch.getPropertyOfType(undefinedStripped, elemSymbol.Name);
						}
						if (targetProp == null) {
							// Name lookup failed or returned no result; search target properties
							// for one whose declaration name node matches the one we have
							if (targetProps != null) {
								for (prop in targetProps) {
									if (prop.ValueDeclaration != null && prop.ValueDeclaration.Name() == e.Name) {
										targetProp = prop;
										break;
									}
								}
							}
							if (targetProp == null) {
								if (reportErrors) {
									b.ctx.tracker.ReportInferenceFallback(e.Name.Parent);
								}
								return false;
							}
						}
						final targetIsOptional = targetProp.Flags & SymbolFlagsOptional != 0;
						if (e.Optional != targetIsOptional) {
							if (reportErrors) {
								b.ctx.tracker.ReportInferenceFallback(e.Name.Parent);
							}
							return false;
						}
						var propType = b.ch.getTypeOfSymbol(targetProp);
						propType = b.ch.removeMissingType(propType, targetIsOptional);
						switch (e.Kind) {
							case PseudoObjectElementKindPropertyAssignment:
								final d = e.AsPseudoPropertyAssignment();
								if (!b.pseudoTypeEquivalentToType(d.Type, propType, e.Optional, false)) {
									if (reportErrors) {
										if (d.Type.Kind == PseudoTypeKindInferred && Core.len(d.Type.AsPseudoTypeInferred().ErrorNodes) > 0) {
											// Re-report the fine-grained error nodes; the recursive call used reportErrors=false
											for (n in d.Type.AsPseudoTypeInferred().ErrorNodes) {
												b.ctx.tracker.ReportInferenceFallback(n);
											}
										} else if (!Checker.isStructuralPseudoType(d.Type)) {
											b.ctx.tracker.ReportInferenceFallback(e.Name.Parent);
										}
									}
									return false;
								}
							case PseudoObjectElementKindMethod:
								final d = e.AsPseudoObjectMethod();
								final targetSig = b.ch.getSingleCallSignature(propType);
								if (targetSig == null) {
									// Target property type doesn't have a single call signature; can't validate
									continue;
								}
								final paramEq = b.pseudoParametersEquivalentToParameters(d.Parameters, targetSig, reportErrors, e.Name.Parent);
								if (!paramEq) {
									return false;
								}
								final targetPredicate = b.ch.getTypePredicateOfSignature(targetSig);
								if (targetPredicate != null) {
									if (!b.pseudoReturnTypeMatchesPredicate(d.ReturnType, targetPredicate)) {
										if (reportErrors) {
											b.ctx.tracker.ReportInferenceFallback(e.Name.Parent);
										}
										return false;
									}
								} else if (!b.pseudoTypeEquivalentToType(d.ReturnType, b.ch.getReturnTypeOfSignature(targetSig), false, false)) {
									if (reportErrors) {
										b.ctx.tracker.ReportInferenceFallback(e.Name.Parent);
									}
									return false;
								}
							case PseudoObjectElementKindGetAccessor:
								final d = e.AsPseudoGetAccessor();
								if (!b.pseudoTypeEquivalentToType(d.Type, propType, false, false)) {
									if (reportErrors) {
										b.ctx.tracker.ReportInferenceFallback(e.Name.Parent);
									}
									return false;
								}
							case PseudoObjectElementKindSetAccessor:
								final d = e.AsPseudoSetAccessor();
								final writeType = b.ch.getWriteTypeOfSymbol(targetProp);
								if (!b.pseudoTypeEquivalentToType(d.Parameter.Type, writeType, false, false)) {
									if (reportErrors) {
										b.ctx.tracker.ReportInferenceFallback(e.Name.Parent);
									}
									return false;
								}
							default:
						}
					}
				}
				return true;
			case PseudoTypeKindTuple:
				final pt = t.AsPseudoTypeTuple();
				if (undefinedStripped == null || !Checker.isTupleType(undefinedStripped)) {
					return false;
				}
				final tupleTarget = undefinedStripped.TargetTupleType();
				// Pseudo-tuples come from `as const` array literals, so they only ever have required elements.
				// If the target tuple has optional, rest, or variadic elements, the structures can't match.
				if (tupleTarget.combinedFlags & ElementFlagsNonRequired != 0) {
					return false;
				}
				final elementTypes = b.ch.getTypeArguments(undefinedStripped);
				if (Core.len(pt.Elements) != Core.len(elementTypes)) {
					return false;
				}
				if (pt.Elements != null) {
					for (i in 0...pt.Elements.length) {
						final elem = pt.Elements[i];
						if (!b.pseudoTypeEquivalentToType(elem, elementTypes[i], false, reportErrors)) {
							return false;
						}
					}
				}
				return true;
			case PseudoTypeKindSingleCallSignature:
				final targetSig = b.ch.getSingleCallSignature(undefinedStripped);
				if (targetSig == null) {
					return false;
				}
				final pt = t.AsPseudoTypeSingleCallSignature();
				if (Core.len(targetSig.typeParameters) != Core.len(pt.TypeParameters)) {
					if (reportErrors) {
						b.ctx.tracker.ReportInferenceFallback(pt.Signature);
					}
					return false;
				}
				final paramEq = b.pseudoParametersEquivalentToParameters(pt.Parameters, targetSig, reportErrors, pt.Signature);
				if (!paramEq) {
					return false;
				}
				final targetPredicate = b.ch.getTypePredicateOfSignature(targetSig);
				if (targetPredicate != null) {
					if (!b.pseudoReturnTypeMatchesPredicate(pt.ReturnType, targetPredicate)) {
						if (reportErrors) {
							b.ctx.tracker.ReportInferenceFallback(pt.Signature);
						}
						return false;
					}
				} else if (!b.pseudoTypeEquivalentToType(pt.ReturnType, b.ch.getReturnTypeOfSignature(targetSig), false, reportErrors)) {
					// error reported within the return type
					return false;
				}
				return true;
			case PseudoTypeKindNoResult:
				if (reportErrors) {
					b.ctx.tracker.ReportInferenceFallback(t.AsPseudoTypeNoResult().Declaration);
				}
				return false;
			default:
				return false;
		}
	}

	static function pseudoParametersEquivalentToParameters(b:NodeBuilderImpl, params:Array<PseudoParameter>, targetSig:Signature, reportErrors:Bool, nonParamErrorLocation:Node):Bool {
		if (targetSig.thisParameter != null && Core.len(params) == 0) {
			if (reportErrors) {
				b.ctx.tracker.ReportInferenceFallback(nonParamErrorLocation); // missing `this` param
			}
			return false;
		} else if (targetSig.thisParameter != null && Ast.IsThisIdentifier(params[0].Name)) {
			final targetParam = targetSig.thisParameter;
			final paramType = b.ch.getTypeOfParameter(targetParam);
			if (!b.pseudoTypeEquivalentToType(params[0].Type, paramType, params[0].Optional, false)) {
				if (reportErrors) {
					b.ctx.tracker.ReportInferenceFallback(params[0].Name.Parent);
				}
				return false;
			}
			params = params.slice(1);
		} else if (targetSig.thisParameter != null) {
			if (reportErrors) {
				b.ctx.tracker.ReportInferenceFallback(nonParamErrorLocation);
			}
			return false;
		}
		if (Core.len(targetSig.parameters) != Core.len(params)) {
			if (reportErrors) {
				b.ctx.tracker.ReportInferenceFallback(nonParamErrorLocation);
			}
			return false; // TODO: spread tuple params may mess with this check
		}
		if (params != null) {
			for (i in 0...params.length) {
				final p = params[i];
				final targetParam = targetSig.parameters[i];
				if (p.Optional != b.ch.isOptionalParameter(targetParam.ValueDeclaration)) {
					if (reportErrors) {
						b.ctx.tracker.ReportInferenceFallback(p.Name.Parent);
					}
					return false;
				}
				final paramType = b.ch.getTypeOfParameter(targetParam);
				if (!b.pseudoTypeEquivalentToType(p.Type, paramType, p.Optional, false)) {
					if (reportErrors) {
						b.ctx.tracker.ReportInferenceFallback(p.Name.Parent);
					}
					return false;
				}
			}
		}
		return true;
	}

	// pseudoReturnTypeMatchesPredicate checks if a pseudo return type (which should be a Direct type
	// wrapping a TypePredicate) matches the given type predicate from the checker.
	static function pseudoReturnTypeMatchesPredicate(b:NodeBuilderImpl, rt:PseudoType, predicate:TypePredicate):Bool {
		if (rt.Kind != PseudoTypeKindDirect) {
			return false;
		}
		final node = rt.AsPseudoTypeDirect().TypeNode;
		if (!Ast.IsTypePredicateNode(node)) {
			return false;
		}
		final tp = node.AsTypePredicateNode();
		// Check asserts modifier matches
		final isAsserts = tp.AssertsModifier != null;
		final predicateIsAsserts = predicate.kind == TypePredicateKindAssertsThis || predicate.kind == TypePredicateKindAssertsIdentifier;
		if (isAsserts != predicateIsAsserts) {
			return false;
		}
		// Check this vs identifier matches
		final isThis = Ast.IsThisTypeNode(tp.ParameterName);
		final predicateIsThis = predicate.kind == TypePredicateKindThis || predicate.kind == TypePredicateKindAssertsThis;
		if (isThis != predicateIsThis) {
			return false;
		}
		// For identifier predicates, check parameter name matches
		if (!isThis) {
			if (tp.ParameterName.Text() != predicate.parameterName) {
				return false;
			}
		}
		// Check the narrowed type, if any
		if (predicate.t != null) {
			if (tp.Type == null) {
				return false;
			}
			final predicateTypeFromNode = b.ch.getTypeFromTypeNode(tp.Type);
			if (predicateTypeFromNode != predicate.t) {
				if (b.ch.compareTypesIdentical(predicateTypeFromNode, predicate.t) != TernaryTrue) {
					return false;
				}
			}
		} else if (tp.Type != null) {
			return false;
		}
		return true;
	}

	static function pseudoTypeToType(b:NodeBuilderImpl, t:PseudoType):Type {
		// !!! TODO: only literal types currently mapped because this is only used to determine if literal contextual typing need apply to the pseudotype
		// If this is used more broadly, the implementation needs to be filled out more to handle the structural pseudotypes - signatures, objects, tuples, etc
		Debug.Assert(t != null, "Attempted to realize nil pseudotype");
		switch (t.Kind) {
			case PseudoTypeKindDirect:
				return b.ch.getTypeFromTypeNode(t.AsPseudoTypeDirect().TypeNode);
			case PseudoTypeKindInferred:
				final node = t.AsPseudoTypeInferred().Expression;
				if (t.AsPseudoTypeInferred().IsSignatureReturn) {
					return b.ch.getReturnTypeOfSignature(b.ch.getSignatureFromDeclaration(node));
				}
				final ty = b.ch.getWidenedType(b.ch.getRegularTypeOfExpression(node));
				return ty;
			case PseudoTypeKindNoResult:
				return null; // TODO: extract type selection logic from `serializeTypeForDeclaration`, not needed for current usecases but needed if completeness becomes required
			case PseudoTypeKindMaybeConstLocation:
				final d = t.AsPseudoTypeMaybeConstLocation();
				if (b.ch.isConstContext(d.Node)) {
					return b.pseudoTypeToType(d.ConstType);
				}
				return b.pseudoTypeToType(d.RegularType);
			case PseudoTypeKindUnion:
				var res:Array<Type> = null;
				var hasElidedType = false;
				final members = t.AsPseudoTypeUnion().Types;
				if (members != null) {
					for (m in members) {
						if (!b.ch.strictNullChecks) {
							if (m.Kind == PseudoTypeKindUndefined || m.Kind == PseudoTypeKindNull) {
								hasElidedType = true;
								continue;
							}
						}
						final t = b.pseudoTypeToType(m);
						if (t == null) {
							return null; // propagate failure
						}
						if (res == null) res = [];
						res.push(t);
					}
				}
				if (Core.len(res) == 1) {
					return res[0];
				}
				if (Core.len(res) == 0) {
					if (hasElidedType) {
						return b.ch.anyType;
					}
					return b.ch.neverType;
				}
				return b.ch.getUnionType(res);
			case PseudoTypeKindUndefined:
				return b.ch.undefinedWideningType;
			case PseudoTypeKindNull:
				return b.ch.nullWideningType;
			case PseudoTypeKindAny:
				return b.ch.anyType;
			case PseudoTypeKindString:
				return b.ch.stringType;
			case PseudoTypeKindNumber:
				return b.ch.numberType;
			case PseudoTypeKindBigInt:
				return b.ch.bigintType;
			case PseudoTypeKindBoolean:
				return b.ch.booleanType;
			case PseudoTypeKindFalse:
				return b.ch.falseType;
			case PseudoTypeKindTrue:
				return b.ch.trueType;
			case PseudoTypeKindStringLiteral | PseudoTypeKindNumericLiteral | PseudoTypeKindBigIntLiteral:
				final source = t.AsPseudoTypeLiteral().Node;
				return b.ch.getRegularTypeOfExpression(source); // big shortcut, uses cached expression types where possible
			case PseudoTypeKindObjectLiteral | PseudoTypeKindSingleCallSignature | PseudoTypeKindTuple:
				return null; // no simple mapping to a type, since these are structural types
			default:
				Debug.Fail("Unhandled pseudochecker.PseudoTypeKind in pseudoTypeToType");
				return null;
		}
	}
}
