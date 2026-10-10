package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/checker.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// Part of checker.go, Go lines 23932-27915 (3984 lines): the Checker methods of this range as static extension
// (receiver first, PORTING.md §2; `using ts.checker.CheckerPart7` in import.hx). Inside class Checker call them as `this.m(...)`.
@:allow(ts.checker)
class CheckerPart7 {

	static function evaluateEntity(c:Checker, expr:Node, location:Node):Result {
		switch (expr.Kind) {
			case KindIdentifier | KindPropertyAccessExpression:
				final symbol = c.resolveEntityName(expr, SymbolFlagsValue, true /*ignoreErrors*/, false, null);
				if (symbol == null) {
					return Evaluator.NewResult(null, false, false, false);
				}
				if (expr.Kind == KindIdentifier) {
					if (Ast.IsInfinityOrNaNString(expr.Text()) && (symbol == c.getGlobalSymbol(expr.Text(), SymbolFlagsValue, null /*diagnostic*/))) {
						// Technically we resolved a global lib file here, but the decision to treat this as numeric
						// is more predicated on the fact that the single-file resolution *didn't* resolve to a
						// different meaning of `Infinity` or `NaN`. Transpilers handle this no problem.
						return Evaluator.NewResult(Jsnum.FromString(expr.Text()), false, false, false);
					}
				}
				if ((symbol.Flags & SymbolFlagsEnumMember) != 0) {
					if (location != null) {
						return c.evaluateEnumMember(expr, symbol, location);
					}
					return c.getEnumMemberValue(symbol.ValueDeclaration);
				}
				if (c.isConstantVariable(symbol)) {
					final declaration = symbol.ValueDeclaration;
					if (declaration != null && Ast.IsVariableDeclaration(declaration) && declaration.Type() == null && declaration.Initializer() != null
						&& (location == null || declaration != location && c.isBlockScopedNameDeclaredBeforeUse(declaration, location))) {
						final result = c.evaluate(declaration.Initializer(), declaration);
						if (location != null && Ast.GetSourceFileOfNode(location) != Ast.GetSourceFileOfNode(declaration)) {
							return Evaluator.NewResult(result.Value, false, true, true);
						}
						return Evaluator.NewResult(result.Value, result.IsSyntacticallyString, result.ResolvedOtherFiles, true /*hasExternalReferences*/);
					}
				}
				return Evaluator.NewResult(null, false, false, false);
			case KindElementAccessExpression:
				final root = expr.Expression();
				if (Ast.IsEntityNameExpression(root) && Ast.IsStringLiteralLike(expr.AsElementAccessExpression().ArgumentExpression)) {
					final rootSymbol = c.resolveEntityName(root, SymbolFlagsValue, true /*ignoreErrors*/, false, null);
					if (rootSymbol != null && (rootSymbol.Flags & SymbolFlagsEnum) != 0) {
						final name = expr.AsElementAccessExpression().ArgumentExpression.Text();
						final member = symbolTableGet(rootSymbol.Exports, name);
						if (member != null) {
							if (location != null) {
								return c.evaluateEnumMember(expr, member, location);
							}
							return c.getEnumMemberValue(member.ValueDeclaration);
						}
					}
				}
				return Evaluator.NewResult(null, false, false, false);
			default:
		}
		throw "Unhandled case in evaluateEntity";
	}

	static function evaluateEnumMember(c:Checker, expr:Node, symbol:Symbol, location:Node):Result {
		final declaration = symbol.ValueDeclaration;
		if (declaration == null || declaration == location) {
			c.error(expr, Diagnostics.Property_0_is_used_before_being_assigned, c.symbolToString(symbol));
			return Evaluator.NewResult(null, false, false, false);
		}
		if (!c.isBlockScopedNameDeclaredBeforeUse(declaration, location)) {
			c.error(expr, Diagnostics.A_member_initializer_in_a_enum_declaration_cannot_reference_members_declared_after_it_including_members_defined_in_other_enums);
			return Evaluator.NewResult((0.0 : Number), false, false, false);
		}
		final value = c.getEnumMemberValue(declaration);
		if (location.Parent != declaration.Parent) {
			return Evaluator.NewResult(value.Value, value.IsSyntacticallyString, value.ResolvedOtherFiles, true /*hasExternalReferences*/);
		}
		return value;
	}

	static function getDeclaredTypeOfAlias(c:Checker, symbol:Symbol):Type {
		final links = c.declaredTypeLinks.Get(symbol);
		if (links.declaredType == null) {
			links.declaredType = c.getDeclaredTypeOfSymbol(c.resolveAlias(symbol));
		}
		return links.declaredType;
	}

	static function getTypeFromTypeQueryNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			// TypeScript 1.0 spec (April 2014): 3.6.3
			// The expression is processed as an identifier expression (section 4.3)
			// or property access expression(section 4.10),
			// the widened type(section 3.9) of which becomes the result.
			final t = c.checkExpressionWithTypeArguments(node);
			links.resolvedType = c.getRegularTypeOfLiteralType(c.getWidenedType(t));
		}
		return links.resolvedType;
	}

	static function getTypeFromArrayOrTupleTypeNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			final target = c.getArrayOrTupleTargetType(node);
			if (target == c.emptyGenericType) {
				links.resolvedType = c.emptyObjectType;
			} else if (!(node.Kind == KindTupleType && Core.Some(node.Elements(), e -> c.isVariadicTupleElement(e))) && c.isDeferredTypeReferenceNode(node, false)) {
				if (node.Kind == KindTupleType && Core.len(node.Elements()) == 0) {
					links.resolvedType = target;
				} else {
					links.resolvedType = c.createDeferredTypeReference(target, node, null /*mapper*/, null /*alias*/);
				}
			} else {
				var elementTypes:Array<Type>;
				if (node.Kind == KindArrayType) {
					elementTypes = [c.getTypeFromTypeNode(node.AsArrayTypeNode().ElementType)];
				} else {
					elementTypes = Core.Map(node.Elements(), n -> c.getTypeFromTypeNode(n));
				}
				if ((target.objectFlags & ObjectFlagsTuple) != 0) {
					links.resolvedType = c.createNormalizedTupleTypeEx(target, elementTypes, ObjectFlagsFromTypeNode);
				} else {
					links.resolvedType = c.createTypeReferenceEx(target, elementTypes, ObjectFlagsFromTypeNode);
				}
			}
		}
		return links.resolvedType;
	}

	static function isVariadicTupleElement(c:Checker, node:Node):Bool {
		return (c.getTupleElementFlags(node) & ElementFlagsVariadic) != 0;
	}

	static function getArrayOrTupleTargetType(c:Checker, node:Node):Type {
		final readonly = c.isReadonlyTypeOperator(node.Parent);
		final elementType = c.getArrayElementTypeNode(node);
		if (elementType != null) {
			if (readonly) {
				return c.globalReadonlyArrayType;
			}
			return c.globalArrayType;
		}
		return c.getTupleTargetType(Core.Map(node.Elements(), n -> c.getTupleElementInfo(n)), readonly);
	}

	static function isReadonlyTypeOperator(c:Checker, node:Node):Bool {
		return Ast.IsTypeOperatorNode(node) && node.AsTypeOperatorNode().Operator == KindReadonlyKeyword;
	}

	static function getTypeFromNamedTupleTypeNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			if (node.AsNamedTupleMember().DotDotDotToken != null) {
				links.resolvedType = c.getTypeFromRestTypeNode(node);
			} else {
				links.resolvedType = c.addOptionalityEx(c.getTypeFromTypeNode(node.Type()), true /*isProperty*/, node.QuestionToken() != null);
			}
		}
		return links.resolvedType;
	}

	static function getTypeFromRestTypeNode(c:Checker, node:Node):Type {
		var typeNode = node.Type();
		final elementTypeNode = c.getArrayElementTypeNode(typeNode);
		if (elementTypeNode != null) {
			typeNode = elementTypeNode;
		}
		return c.getTypeFromTypeNode(typeNode);
	}

	static function getArrayElementTypeNode(c:Checker, node:Node):Node {
		switch (node.Kind) {
			case KindParenthesizedType:
				return c.getArrayElementTypeNode(node.Type());
			case KindTupleType:
				if (Core.len(node.Elements()) == 1) {
					node = node.Elements()[0];
					if (node.Kind == KindRestType) {
						return c.getArrayElementTypeNode(node.Type());
					}
					if (node.Kind == KindNamedTupleMember && node.AsNamedTupleMember().DotDotDotToken != null) {
						return c.getArrayElementTypeNode(node.Type());
					}
				}
			case KindArrayType:
				return node.AsArrayTypeNode().ElementType;
			default:
		}
		return null;
	}

	static function getTypeFromOptionalTypeNode(c:Checker, node:Node):Type {
		return c.addOptionalityEx(c.getTypeFromTypeNode(node.Type()), true /*isProperty*/, true /*isOptional*/);
	}

	static function getTypeFromUnionTypeNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			final alias = c.getAliasForTypeNode(node);
			links.resolvedType = c.getUnionTypeEx(Core.Map(node.AsUnionTypeNode().Types.Nodes, n -> c.getTypeFromTypeNode(n)), UnionReductionLiteral, alias, null /*origin*/);
		}
		return links.resolvedType;
	}

	static function getTypeFromIntersectionTypeNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			final alias = c.getAliasForTypeNode(node);
			final types = Core.Map(node.AsIntersectionTypeNode().Types.Nodes, n -> c.getTypeFromTypeNode(n));
			// We perform no supertype reduction for X & {} or {} & X, where X is one of string, number, bigint,
			// or a pattern literal template type. This enables union types like "a" | "b" | string & {} or
			// "aa" | "ab" | `a${string}` which preserve the literal types for purposes of statement completion.
			var noSupertypeReduction = false;
			if (Core.len(types) == 2) {
				final emptyIndex = types.indexOf(c.emptyTypeLiteralType);
				if (emptyIndex >= 0) {
					final t = types[1 - emptyIndex];
					noSupertypeReduction = (t.flags & (TypeFlagsString | TypeFlagsNumber | TypeFlagsBigInt)) != 0
						|| (t.flags & TypeFlagsTemplateLiteral) != 0 && c.isPatternLiteralType(t);
				}
			}
			links.resolvedType = c.getIntersectionTypeEx(types, noSupertypeReduction ? IntersectionFlagsNoSupertypeReduction : IntersectionFlagsNone, alias);
		}
		return links.resolvedType;
	}

	static function getTypeFromTemplateTypeNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			final spans = node.AsTemplateLiteralTypeNode().TemplateSpans;
			final texts:Array<std.String> = [for (_ in 0...spans.Nodes.length + 1) ""];
			final types:Array<Type> = [for (_ in 0...spans.Nodes.length) null];
			texts[0] = node.AsTemplateLiteralTypeNode().Head.Text();
			for (i in 0...spans.Nodes.length) {
				final span = spans.Nodes[i];
				texts[i + 1] = span.AsTemplateLiteralTypeSpan().Literal.Text();
				types[i] = c.getTypeFromTypeNode(span.Type());
			}
			links.resolvedType = c.getTemplateLiteralType(texts, types);
		}
		return links.resolvedType;
	}

	static function getTypeFromMappedTypeNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			final t = c.newObjectType(ObjectFlagsMapped, node.Symbol());
			t.AsMappedType().declaration = node.AsMappedTypeNode();
			t.alias = c.getAliasForTypeNode(node);
			links.resolvedType = t;
			// Eagerly resolve the constraint type which forces an error if the constraint type circularly
			// references itself through one or more type aliases.
			c.getConstraintTypeFromMappedType(t);
		}
		return links.resolvedType;
	}

	static function getTypeFromConditionalTypeNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			final checkType = c.getTypeFromTypeNode(node.AsConditionalTypeNode().CheckType);
			final alias = c.getAliasForTypeNode(node);
			final allOuterTypeParameters = c.getOuterTypeParameters(node, true /*includeThisTypes*/);
			var outerTypeParameters:Array<Type>;
			if (alias != null && Core.len(alias.typeArguments) != 0) {
				outerTypeParameters = allOuterTypeParameters;
			} else {
				outerTypeParameters = Core.Filter(allOuterTypeParameters, tp -> c.isTypeParameterPossiblyReferenced(tp, node));
			}
			final root = new ConditionalRoot();
			root.node = node.AsConditionalTypeNode();
			root.checkType = checkType;
			root.extendsType = c.getTypeFromTypeNode(node.AsConditionalTypeNode().ExtendsType);
			root.isDistributive = (checkType.flags & TypeFlagsTypeParameter) != 0;
			root.inferTypeParameters = c.getInferTypeParameters(node);
			root.outerTypeParameters = outerTypeParameters;
			root.instantiations = null;
			root.alias = alias;
			links.resolvedType = c.getConditionalType(root, null /*mapper*/, false /*forConstraint*/, null);
			if (outerTypeParameters != null) {
				root.instantiations = new StringMap<Type>();
				root.instantiations.set(Checker.getConditionalTypeKey(outerTypeParameters, null /*alias*/, false /*forConstraint*/).Key(), links.resolvedType);
			}
		}
		return links.resolvedType;
	}

	static function getConditionalType(c:Checker, root:ConditionalRoot, mapper:TypeMapper, forConstraint:Bool, alias:TypeAlias):Type {
		var result:Type = null;
		var extraTypes:Array<Type> = null;
		var tailCount = 0;
		// We loop here for an immediately nested conditional type in the false position, effectively treating
		// types of the form 'A extends B ? X : C extends D ? Y : E extends F ? Z : ...' as a single construct for
		// purposes of resolution. We also loop here when resolution of a conditional type ends in resolution of
		// another (or, through recursion, possibly the same) conditional type. In the potentially tail-recursive
		// cases we increment the tail recursion counter and stop after 1000 iterations.
		while (true) {
			if (tailCount == 1000) {
				c.error(c.currentNode, Diagnostics.Type_instantiation_is_excessively_deep_and_possibly_infinite);
				return c.errorType;
			}
			final checkType = c.instantiateType(c.getActualTypeVariable(root.checkType), mapper);
			final extendsType = c.instantiateType(root.extendsType, mapper);
			if (checkType == c.errorType || extendsType == c.errorType) {
				return c.errorType;
			}
			if (checkType == c.wildcardType || extendsType == c.wildcardType) {
				return c.wildcardType;
			}
			final checkTypeNode = Ast.SkipTypeParentheses(root.node.CheckType);
			final extendsTypeNode = Ast.SkipTypeParentheses(root.node.ExtendsType);
			// When the check and extends types are simple tuple types of the same arity, we defer resolution of the
			// conditional type when any tuple elements are generic. This is such that non-distributable conditional
			// types can be written `[X] extends [Y] ? ...` and be deferred similarly to `X extends Y ? ...`.
			final checkTuples = c.isSimpleTupleType(checkTypeNode) && c.isSimpleTupleType(extendsTypeNode)
				&& Core.len(checkTypeNode.Elements()) == Core.len(extendsTypeNode.Elements());
			final checkTypeDeferred = c.isDeferredType(checkType, checkTuples);
			var combinedMapper:TypeMapper = null;
			if (Core.len(root.inferTypeParameters) != 0) {
				// When we're looking at making an inference for an infer type, when we get its constraint, it'll automagically be
				// instantiated with the context, so it doesn't need the mapper for the inference context - however the constraint
				// may refer to another _root_, _uncloned_ `infer` type parameter [1], or to something mapped by `mapper` [2].
				// [1] Eg, if we have `Foo<T, U extends T>` and `Foo<number, infer B>` - `B` is constrained to `T`, which, in turn, has been instantiated
				// as `number`
				// Conversely, if we have `Foo<infer A, infer B>`, `B` is still constrained to `T` and `T` is instantiated as `A`
				// [2] Eg, if we have `Foo<T, U extends T>` and `Foo<Q, infer B>` where `Q` is mapped by `mapper` into `number` - `B` is constrained to `T`
				// which is in turn instantiated as `Q`, which is in turn instantiated as `number`.
				// So we need to:
				//    * combine `context.nonFixingMapper` with `mapper` so their constraints can be instantiated in the context of `mapper` (otherwise they'd only get inference context information)
				//    * incorporate all of the component mappers into the combined mapper for the true and false members
				// This means we have two mappers that need applying:
				//    * The original `mapper` used to create this conditional
				//    * The mapper that maps the infer type parameter to its inference result (`context.mapper`)
				final context = c.newInferenceContext(root.inferTypeParameters, null /*signature*/, InferenceFlagsNone, null);
				if (mapper != null) {
					context.nonFixingMapper = c.combineTypeMappers(context.nonFixingMapper, mapper);
				}
				if (!checkTypeDeferred) {
					// We don't want inferences from constraints as they may cause us to eagerly resolve the
					// conditional type instead of deferring resolution. Also, we always want strict function
					// types rules (i.e. proper contravariance) for inferences.
					c.inferTypes(context.inferences, checkType, extendsType, InferencePriorityNoConstraints | InferencePriorityAlwaysStrict, false);
				}
				// It's possible for 'infer T' type parameters to be given uninstantiated constraints when the
				// those type parameters are used in type references (see getInferredTypeParameterConstraint). For
				// that reason we need context.mapper to be first in the combined mapper. See #42636 for examples.
				if (mapper != null) {
					combinedMapper = c.combineTypeMappers(context.mapper, mapper);
				} else {
					combinedMapper = context.mapper;
				}
			}
			// Instantiate the extends type including inferences for 'infer T' type parameters
			var inferredExtendsType:Type;
			if (combinedMapper != null) {
				inferredExtendsType = c.instantiateType(root.extendsType, combinedMapper);
			} else {
				inferredExtendsType = extendsType;
			}
			// We attempt to resolve the conditional type only when the check and extends types are non-generic
			if (!checkTypeDeferred && !c.isDeferredType(inferredExtendsType, checkTuples)) {
				// Return falseType for a definitely false extends check. We check an instantiations of the two
				// types with type parameters mapped to the wildcard type, the most permissive instantiations
				// possible (the wildcard type is assignable to and from all types). If those are not related,
				// then no instantiations will be and we can just return the false branch type.
				if ((inferredExtendsType.flags & TypeFlagsAnyOrUnknown) == 0
					&& ((checkType.flags & TypeFlagsAny) != 0
						|| !c.isTypeAssignableTo(c.getPermissiveInstantiation(checkType), c.getPermissiveInstantiation(inferredExtendsType)))) {
					// Return union of trueType and falseType for 'any' since it matches anything. Furthermore, for a
					// distributive conditional type applied to the constraint of a type variable, include trueType if
					// there are possible values of the check type that are also possible values of the extends type.
					// We use a reverse assignability check as it is less expensive than the comparable relationship
					// and avoids false positives of a non-empty intersection check.
					if ((checkType.flags & TypeFlagsAny) != 0
						|| forConstraint && (inferredExtendsType.flags & TypeFlagsNever) == 0
						&& Checker.someType(c.getPermissiveInstantiation(inferredExtendsType), t -> c.isTypeAssignableTo(t, c.getPermissiveInstantiation(checkType)))) {
						if (extraTypes == null) {
							extraTypes = [];
						}
						extraTypes.push(c.instantiateType(c.getTypeFromTypeNode(root.node.TrueType), Core.OrElse(combinedMapper, mapper)));
					}
					// If falseType is an immediately nested conditional type that isn't distributive or has an
					// identical checkType, switch to that type and loop.
					final falseType = c.getTypeFromTypeNode(root.node.FalseType);
					if ((falseType.flags & TypeFlagsConditional) != 0) {
						final newRoot = falseType.AsConditionalType().root;
						if (newRoot.node.Parent == root.node.AsNode() && (!newRoot.isDistributive || newRoot.checkType == root.checkType)) {
							root = newRoot;
							continue;
						}
						final tail = c.getTailRecursionRoot(falseType, mapper);
						final newRoot = tail.a;
						if (newRoot != null) {
							root = newRoot;
							mapper = tail.b;
							alias = null;
							if (newRoot.alias != null) {
								tailCount++;
							}
							continue;
						}
					}
					result = c.instantiateType(falseType, mapper);
					break;
				}
				// Return trueType for a definitely true extends check. We check instantiations of the two
				// types with type parameters mapped to their restrictive form, i.e. a form of the type parameter
				// that has no constraint. This ensures that, for example, the type
				//   type Foo<T extends { x: any }> = T extends { x: string } ? string : number
				// doesn't immediately resolve to 'string' instead of being deferred.
				if ((inferredExtendsType.flags & TypeFlagsAnyOrUnknown) != 0
					|| c.isTypeAssignableTo(c.getRestrictiveInstantiation(checkType), c.getRestrictiveInstantiation(inferredExtendsType))) {
					final trueType = c.getTypeFromTypeNode(root.node.TrueType);
					final trueMapper = Core.OrElse(combinedMapper, mapper);
					final tail = c.getTailRecursionRoot(trueType, trueMapper);
					final newRoot = tail.a;
					if (newRoot != null) {
						root = newRoot;
						mapper = tail.b;
						alias = null;
						if (newRoot.alias != null) {
							tailCount++;
						}
						continue;
					}
					result = c.instantiateType(trueType, trueMapper);
					break;
				}
			}
			// Return a deferred type for a check that is neither definitely true nor definitely false
			result = c.newConditionalType(root, mapper, combinedMapper);
			if (alias != null) {
				result.alias = alias;
			} else {
				result.alias = c.instantiateTypeAlias(root.alias, mapper);
			}
			break;
		}
		if (extraTypes != null) {
			extraTypes.push(result);
			return c.getUnionType(extraTypes);
		}
		return result;
	}

	// We tail-recurse for generic conditional types that (a) have not already been evaluated and cached, and
	// (b) are non distributive, have a check type that is unaffected by instantiation, or have a non-union check
	// type. Note that recursion is possible only through aliased conditional types, so we only increment the tail
	// recursion counter for those.
	static function getTailRecursionRoot(c:Checker, newType:Type, newMapper:TypeMapper):Pair<ConditionalRoot, TypeMapper> {
		if ((newType.flags & TypeFlagsConditional) != 0 && newMapper != null) {
			final newRoot = newType.AsConditionalType().root;
			if (Core.len(newRoot.outerTypeParameters) != 0) {
				final typeParamMapper = c.combineTypeMappers(newType.AsConditionalType().mapper, newMapper);
				final typeArguments = Core.Map(newRoot.outerTypeParameters, t -> typeParamMapper.Map(t));
				final newRootMapper = Checker.newTypeMapper(newRoot.outerTypeParameters, typeArguments);
				var newCheckType:Type = null;
				if (newRoot.isDistributive) {
					newCheckType = newRootMapper.Map(newRoot.checkType);
				}
				if (newCheckType == null || newCheckType == newRoot.checkType || (newCheckType.flags & (TypeFlagsUnion | TypeFlagsNever)) == 0) {
					return new Pair<ConditionalRoot, TypeMapper>(newRoot, newRootMapper);
				}
			}
		}
		return new Pair<ConditionalRoot, TypeMapper>(null, null);
	}

	static function isSimpleTupleType(c:Checker, node:Node):Bool {
		return Ast.IsTupleTypeNode(node) && Core.len(node.Elements()) > 0 && !Core.Some(node.Elements(), (e:Node) -> {
			return Ast.IsOptionalTypeNode(e) || Ast.IsRestTypeNode(e)
				|| Ast.IsNamedTupleMember(e) && (e.QuestionToken() != null || e.AsNamedTupleMember().DotDotDotToken != null);
		});
	}

	static function isDeferredType(c:Checker, t:Type, checkTuples:Bool):Bool {
		return c.isGenericType(t) || checkTuples && Checker.isTupleType(t) && Core.Some(c.getElementTypes(t), e -> c.isGenericType(e));
	}

	static function getPermissiveInstantiation(c:Checker, t:Type):Type {
		if ((t.flags & (TypeFlagsPrimitive | TypeFlagsAnyOrUnknown | TypeFlagsNever)) != 0) {
			return t;
		}
		final key = CachedTypeKey.keyOf(CachedTypeKindPermissiveInstantiation, t.id);
		final cached = c.cachedTypes.get(key);
		if (cached != null) {
			return cached;
		}
		final result = c.instantiateType(t, c.permissiveMapper);
		c.cachedTypes.set(key, result);
		return result;
	}

	static function getRestrictiveInstantiation(c:Checker, t:Type):Type {
		if ((t.flags & (TypeFlagsPrimitive | TypeFlagsAnyOrUnknown | TypeFlagsNever)) != 0) {
			return t;
		}
		final key = CachedTypeKey.keyOf(CachedTypeKindRestrictiveInstantiation, t.id);
		final cached = c.cachedTypes.get(key);
		if (cached != null) {
			return cached;
		}
		final result = c.instantiateType(t, c.restrictiveMapper);
		c.cachedTypes.set(key, result);
		// We set the following so we don't attempt to set the restrictive instance of a restrictive instance
		// which is redundant - we'll produce new type identities, but all type params have already been mapped.
		// This also gives us a way to detect restrictive instances upon comparisons and _disable_ the "distributeive constraint"
		// assignability check for them, which is distinctly unsafe, as once you have a restrctive instance, all the type parameters
		// are constrained to `unknown` and produce tons of false positives/negatives!
		c.cachedTypes.set(CachedTypeKey.keyOf(CachedTypeKindRestrictiveInstantiation, result.id), result);
		return result;
	}

	static function getRestrictiveTypeParameter(c:Checker, t:Type):Type {
		if (t.AsTypeParameter().constraint == null && c.getConstraintDeclaration(t) == null || t.AsTypeParameter().constraint == c.noConstraintType) {
			return t;
		}
		final key = CachedTypeKey.keyOf(CachedTypeKindRestrictiveTypeParameter, t.id);
		final cached = c.cachedTypes.get(key);
		if (cached != null) {
			return cached;
		}
		final result = c.newTypeParameter(t.symbol);
		result.AsTypeParameter().constraint = c.noConstraintType;
		c.cachedTypes.set(key, result);
		return result;
	}

	static function restrictiveMapperWorker(c:Checker, t:Type):Type {
		if ((t.flags & TypeFlagsTypeParameter) != 0) {
			return c.getRestrictiveTypeParameter(t);
		}
		return t;
	}

	static function permissiveMapperWorker(c:Checker, t:Type):Type {
		if ((t.flags & TypeFlagsTypeParameter) != 0) {
			return c.wildcardType;
		}
		return t;
	}

	static function getTrueTypeFromConditionalType(c:Checker, t:Type):Type {
		final d = t.AsConditionalType();
		if (d.resolvedTrueType == null) {
			d.resolvedTrueType = c.instantiateType(c.getTypeFromTypeNode(d.root.node.TrueType), d.mapper);
		}
		return d.resolvedTrueType;
	}

	static function getFalseTypeFromConditionalType(c:Checker, t:Type):Type {
		final d = t.AsConditionalType();
		if (d.resolvedFalseType == null) {
			d.resolvedFalseType = c.instantiateType(c.getTypeFromTypeNode(d.root.node.FalseType), d.mapper);
		}
		return d.resolvedFalseType;
	}

	static function getInferredTrueTypeFromConditionalType(c:Checker, t:Type):Type {
		final d = t.AsConditionalType();
		if (d.resolvedInferredTrueType == null) {
			if (d.combinedMapper != null) {
				d.resolvedInferredTrueType = c.instantiateType(c.getTypeFromTypeNode(d.root.node.TrueType), d.combinedMapper);
			} else {
				d.resolvedInferredTrueType = c.getTrueTypeFromConditionalType(t);
			}
		}
		return d.resolvedInferredTrueType;
	}

	static function getTypeFromInferTypeNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			links.resolvedType = c.getDeclaredTypeOfTypeParameter(c.getSymbolOfDeclaration(node.AsInferTypeNode().TypeParameter));
		}
		return links.resolvedType;
	}

	static function getTypeFromImportTypeNode(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node);
		if (links.resolvedType == null) {
			final n = node.AsImportTypeNode();
			if (!Ast.IsLiteralImportTypeNode(node)) {
				c.error(n.Argument, Diagnostics.String_literal_expected);
				c.symbolNodeLinks.Get(node).resolvedSymbol = c.unknownSymbol;
				links.resolvedType = c.errorType;
				return links.resolvedType;
			}
			final targetMeaning:SymbolFlags = n.IsTypeOf ? SymbolFlagsValue : SymbolFlagsType;
			// TODO: Future work: support unions/generics/whatever via a deferred import-type
			final innerModuleSymbol = c.resolveExternalModuleName(node, n.Argument.AsLiteralTypeNode().Literal, false /*ignoreErrors*/);
			if (innerModuleSymbol == null) {
				c.symbolNodeLinks.Get(node).resolvedSymbol = c.unknownSymbol;
				links.resolvedType = c.errorType;
				return links.resolvedType;
			}
			final moduleSymbol = c.resolveExternalModuleSymbol(innerModuleSymbol, false /*dontResolveAlias*/);
			if (!Ast.NodeIsMissing(n.Qualifier)) {
				final nameChain = c.getIdentifierChain(n.Qualifier);
				var currentNamespace = moduleSymbol;
				for (i in 0...nameChain.length) {
					final current = nameChain[i];
					var meaning = SymbolFlagsNamespace;
					if (i == nameChain.length - 1) {
						meaning = targetMeaning;
					}
					// typeof a.b.c is normally resolved using `checkExpression` which in turn defers to `checkQualifiedName`
					// That, in turn, ultimately uses `getPropertyOfType` on the type of the symbol, which differs slightly from
					// the `exports` lookup process that only looks up namespace members which is used for most type references
					final mergedResolvedSymbol = c.getMergedSymbol(c.resolveSymbol(currentNamespace));
					var symbolFromVariable:Symbol = null;
					var symbolFromModule:Symbol = null;
					if (n.IsTypeOf) {
						symbolFromVariable = c.getPropertyOfTypeEx(c.getTypeOfSymbol(mergedResolvedSymbol), current.Text(), false /*skipObjectFunctionPropertyAugment*/, true /*includeTypeOnlyMembers*/);
					} else {
						symbolFromModule = c.getSymbol(c.getExportsOfSymbol(mergedResolvedSymbol), current.Text(), meaning);
						if (symbolFromModule == null) {
							// a CommonJS module might have typedefs exported alongside an export=
							// !!!
							final immediateModuleSymbol = c.resolveExternalModuleSymbol(innerModuleSymbol, true /*dontResolveAlias*/);
							if (immediateModuleSymbol != null && Core.Some(immediateModuleSymbol.Declarations, (d:Node) -> {
								return Ast.GetAssignmentDeclarationKind(d) == JSDeclarationKindModuleExports;
							})) {
								symbolFromModule = c.getSymbol(c.getExportsOfSymbol(immediateModuleSymbol.Parent), current.Text(), meaning);
							}
						}
					}
					final next = Core.OrElse(symbolFromModule, symbolFromVariable);
					if (next == null) {
						c.error(current, Diagnostics.Namespace_0_has_no_exported_member_1, c.getFullyQualifiedName(currentNamespace, null), Scanner.DeclarationNameToString(current));
						links.resolvedType = c.errorType;
						return links.resolvedType;
					}
					c.symbolNodeLinks.Get(current).resolvedSymbol = next;
					c.symbolNodeLinks.Get(current.Parent).resolvedSymbol = next;
					currentNamespace = next;
				}
				links.resolvedType = c.resolveImportSymbolType(node, currentNamespace, targetMeaning);
			} else {
				if ((c.getSymbolFlags(moduleSymbol) & targetMeaning) != 0) {
					links.resolvedType = c.resolveImportSymbolType(node, moduleSymbol, targetMeaning);
				} else {
					final message = targetMeaning == SymbolFlagsValue
						? Diagnostics.Module_0_does_not_refer_to_a_value_but_is_used_as_a_value_here
						: Diagnostics.Module_0_does_not_refer_to_a_type_but_is_used_as_a_type_here_Did_you_mean_typeof_import_0;
					c.error(node, message, n.Argument.AsLiteralTypeNode().Literal.Text());
					c.symbolNodeLinks.Get(node).resolvedSymbol = c.unknownSymbol;
					links.resolvedType = c.errorType;
				}
			}
		}
		return links.resolvedType;
	}

	static function getIdentifierChain(c:Checker, node:Node):Array<Node> {
		if (Ast.IsIdentifier(node)) {
			return [node];
		}
		// PORT: Go append on the fresh result of the recursive call; the callee owns it.
		final chain = c.getIdentifierChain(node.AsQualifiedName().Left);
		chain.push(node.AsQualifiedName().Right);
		return chain;
	}

	static function resolveImportSymbolType(c:Checker, node:Node, symbol:Symbol, meaning:SymbolFlags):Type {
		final resolvedSymbol = c.resolveSymbol(symbol);
		c.symbolNodeLinks.Get(node).resolvedSymbol = resolvedSymbol;
		if (meaning == SymbolFlagsValue) {
			// intentionally doesn't use resolved symbol so type is cached as expected on the alias
			return c.getInstantiationExpressionType(c.getTypeOfSymbol(symbol), node);
		}
		// getTypeReferenceType doesn't handle aliases - it must get the resolved symbol
		return c.getTypeReferenceType(node, resolvedSymbol);
	}

	static function createTypeFromGenericGlobalType(c:Checker, genericGlobalType:Type, typeArguments:Array<Type>):Type {
		if (genericGlobalType != c.emptyGenericType) {
			return c.createTypeReference(genericGlobalType, typeArguments);
		}
		return c.emptyObjectType;
	}

	static function getGlobalStrictFunctionType(c:Checker, name:std.String):Type {
		if (c.strictBindCallApply) {
			return c.getGlobalType(name, 0 /*arity*/, true /*reportErrors*/);
		}
		return c.globalFunctionType;
	}

	static function getGlobalImportMetaExpressionType(c:Checker):Type {
		if (c.deferredGlobalImportMetaExpressionType == null) {
			// Create a synthetic type `ImportMetaExpression { meta: MetaProperty }`
			final symbol = c.newSymbol(SymbolFlagsNone, "ImportMetaExpression");
			final importMetaType = c.getGlobalImportMetaType();
			final metaPropertySymbol = c.newSymbolEx(SymbolFlagsProperty, "meta", CheckFlagsReadonly);
			metaPropertySymbol.Parent = symbol;
			c.valueSymbolLinks.Get(metaPropertySymbol).resolvedType = importMetaType;
			final members = Checker.createSymbolTable([metaPropertySymbol]);
			symbol.Members = members;
			c.deferredGlobalImportMetaExpressionType = c.newAnonymousType(symbol, members, null, null, null);
		}
		return c.deferredGlobalImportMetaExpressionType;
	}

	static function createIterableType(c:Checker, iteratedType:Type):Type {
		return c.createTypeFromGenericGlobalType(c.getGlobalIterableTypeChecked(), [iteratedType, c.voidType, c.undefinedType]);
	}

	static function createArrayType(c:Checker, elementType:Type):Type {
		return c.createArrayTypeEx(elementType, false /*readonly*/);
	}

	static function createArrayTypeEx(c:Checker, elementType:Type, readonly:Bool):Type {
		return c.createTypeFromGenericGlobalType(readonly ? c.globalReadonlyArrayType : c.globalArrayType, [elementType]);
	}

	static function getTupleElementFlags(c:Checker, node:Node):ElementFlags {
		switch (node.Kind) {
			case KindOptionalType:
				return ElementFlagsOptional;
			case KindRestType:
				return c.getArrayElementTypeNode(node.Type()) != null ? ElementFlagsRest : ElementFlagsVariadic;
			case KindNamedTupleMember:
				final named = node.AsNamedTupleMember();
				if (named.QuestionToken != null) {
					return ElementFlagsOptional;
				} else if (named.DotDotDotToken != null) {
					return c.getArrayElementTypeNode(named.Type) != null ? ElementFlagsRest : ElementFlagsVariadic;
				}
				return ElementFlagsRequired;
			default:
		}
		return ElementFlagsRequired;
	}

	static function getTupleElementInfo(c:Checker, node:Node):TupleElementInfo {
		final info = new TupleElementInfo();
		info.flags = c.getTupleElementFlags(node);
		info.labeledDeclaration = Ast.IsNamedTupleMember(node) || Ast.IsParameterDeclaration(node) ? node : null;
		return info;
	}

	static function createTupleType(c:Checker, elementTypes:Array<Type>):Type {
		final elementInfos = Core.Map(elementTypes, (_:Type) -> {
			final info = new TupleElementInfo();
			info.flags = ElementFlagsRequired;
			return info;
		});
		return c.createTupleTypeEx(elementTypes, elementInfos, false /*readonly*/);
	}

	static function createTupleTypeEx(c:Checker, elementTypes:Array<Type>, elementInfos:Array<TupleElementInfo>, readonly:Bool):Type {
		final tupleTarget = c.getTupleTargetType(elementInfos, readonly);
		if (tupleTarget == c.emptyGenericType) {
			return c.emptyObjectType;
		} else if (Core.len(elementTypes) != 0) {
			return c.createNormalizedTypeReference(tupleTarget, elementTypes);
		}
		return tupleTarget;
	}

	static function getTupleTargetType(c:Checker, elementInfos:Array<TupleElementInfo>, readonly:Bool):Type {
		if (Core.len(elementInfos) == 1 && (elementInfos[0].flags & ElementFlagsRest) != 0) {
			// [...X[]] is equivalent to just X[]
			if (readonly) {
				return c.globalReadonlyArrayType;
			}
			return c.globalArrayType;
		}
		final key = Checker.getTupleKey(elementInfos, readonly).Key();
		var t = c.tupleTypes.get(key);
		if (t == null) {
			t = c.createTupleTargetType(elementInfos, readonly);
			c.tupleTypes.set(key, t);
		}
		return t;
	}

	// We represent tuple types as type references to synthesized generic interface types created by
	// this function. The types are of the form:
	//
	//	interface Tuple<T0, T1, T2, ...> extends Array<T0 | T1 | T2 | ...> { 0: T0, 1: T1, 2: T2, ... }
	//
	// Note that the generic type created by this function has no symbol associated with it. The same
	// is true for each of the synthesized type parameters.
	static function createTupleTargetType(c:Checker, elementInfos:Array<TupleElementInfo>, readonly:Bool):Type {
		final arity = Core.len(elementInfos);
		var minLength = 0;
		for (e in rangeOf(elementInfos)) {
			if ((e.flags & (ElementFlagsRequired | ElementFlagsVariadic)) != 0) {
				minLength++;
			}
		}
		var typeParameters:Array<Type> = null;
		final members = new SymbolTable();
		var membersLen = 0; // PORT: Go len(members); StringMap has no O(1) size.
		var combinedFlags = ElementFlagsNone;
		if (arity != 0) {
			typeParameters = [];
			for (i in 0...arity) {
				final typeParameter = c.newTypeParameter(null);
				typeParameters.push(typeParameter);
				final flags = elementInfos[i].flags;
				combinedFlags |= flags;
				if ((combinedFlags & ElementFlagsVariable) == 0) {
					final property = c.newSymbolEx(SymbolFlagsProperty | ((flags & ElementFlagsOptional) != 0 ? SymbolFlagsOptional : SymbolFlagsNone), Std.string(i),
						readonly ? CheckFlagsReadonly : (0 : CheckFlags));
					c.valueSymbolLinks.Get(property).resolvedType = typeParameter;
					// c.valueSymbolLinks.get(property).tupleLabelDeclaration = elementInfos[i].labeledDeclaration
					if (!members.exists(property.Name)) {
						membersLen++;
					}
					members.set(property.Name, property);
				}
			}
		}
		final fixedLength = membersLen;
		final lengthSymbol = c.newSymbolEx(SymbolFlagsProperty, "length", readonly ? CheckFlagsReadonly : (0 : CheckFlags));
		if ((combinedFlags & ElementFlagsVariable) != 0) {
			c.valueSymbolLinks.Get(lengthSymbol).resolvedType = c.numberType;
		} else {
			var literalTypes:Array<Type> = null;
			var i = minLength;
			while (i <= arity) {
				if (literalTypes == null) {
					literalTypes = [];
				}
				literalTypes.push(c.getNumberLiteralType((i : Float)));
				i++;
			}
			c.valueSymbolLinks.Get(lengthSymbol).resolvedType = c.getUnionType(literalTypes);
		}
		members.set(lengthSymbol.Name, lengthSymbol);
		final t = c.newObjectType(ObjectFlagsTuple | ObjectFlagsReference, null);
		final d = t.AsTupleType();
		d.thisType = c.newTypeParameter(null);
		d.thisType.AsTypeParameter().isThisType = true;
		d.thisType.AsTypeParameter().constraint = t;
		if (typeParameters == null) {
			typeParameters = [];
		}
		typeParameters.push(d.thisType);
		d.allTypeParameters = typeParameters;
		d.instantiations = new StringMap<Type>();
		d.instantiations.set(Checker.getTypeListKey(d.TypeParameters()).Key(), t);
		d.target = t;
		d.resolvedTypeArguments = d.TypeParameters();
		d.declaredMembersResolved = true;
		d.declaredMembers = members;
		d.elementInfos = elementInfos;
		d.minLength = minLength;
		d.fixedLength = fixedLength;
		d.combinedFlags = combinedFlags;
		d.readonly = readonly;
		return t;
	}

	static function getElementTypeOfSliceOfTupleType(c:Checker, t:Type, index:Int, endSkipCount:Int, writing:Bool, noReductions:Bool):Type {
		final length = c.getTypeReferenceArity(t) - endSkipCount;
		final elementInfos = t.TargetTupleType().elementInfos;
		if (index < length) {
			final typeArguments = c.getTypeArguments(t);
			var elementTypes:Array<Type> = null;
			for (i in index...length) {
				var e = typeArguments[i];
				if ((elementInfos[i].flags & ElementFlagsVariadic) != 0) {
					e = c.getIndexedAccessType(e, c.numberType);
				}
				if (elementTypes == null) {
					elementTypes = [];
				}
				elementTypes.push(e);
			}
			if (writing) {
				return c.getIntersectionType(elementTypes);
			}
			return c.getUnionTypeEx(elementTypes, noReductions ? UnionReductionNone : UnionReductionLiteral, null, null);
		}
		return null;
	}

	static function getRestTypeOfTupleType(c:Checker, t:Type):Type {
		return c.getElementTypeOfSliceOfTupleType(t, t.TargetTupleType().fixedLength, 0, false, false);
	}

	static function getTupleElementTypeOutOfStartCount(c:Checker, t:Type, index:Number, undefinedLikeType:Type):Type {
		return c.mapType(t, (t:Type) -> {
			final restType = c.getRestTypeOfTupleType(t);
			if (restType == null) {
				return c.undefinedType;
			}
			if (undefinedLikeType != null && (index : Float) >= (Checker.getTotalFixedElementCount(t.TargetTupleType()) : Float)) {
				return c.getUnionType([restType, undefinedLikeType]);
			}
			return restType;
		});
	}

	static function isGenericType(c:Checker, t:Type):Bool {
		return c.getGenericObjectFlags(t) != 0;
	}

	static function isGenericObjectType(c:Checker, t:Type):Bool {
		return (c.getGenericObjectFlags(t) & ObjectFlagsIsGenericObjectType) != 0;
	}

	static function isGenericIndexType(c:Checker, t:Type):Bool {
		return (c.getGenericObjectFlags(t) & ObjectFlagsIsGenericIndexType) != 0;
	}

	static function getGenericObjectFlags(c:Checker, t:Type):ObjectFlags {
		var combinedFlags:ObjectFlags = ObjectFlagsNone;
		if ((t.flags & (TypeFlagsUnionOrIntersection | TypeFlagsSubstitution)) != 0) {
			if ((t.objectFlags & ObjectFlagsIsGenericTypeComputed) == 0) {
				if ((t.flags & TypeFlagsUnionOrIntersection) != 0) {
					for (u in t.Types()) {
						combinedFlags |= c.getGenericObjectFlags(u);
					}
				} else {
					combinedFlags = c.getGenericObjectFlags(t.AsSubstitutionType().baseType) | c.getGenericObjectFlags(t.AsSubstitutionType().constraint);
				}
				t.objectFlags |= ObjectFlagsIsGenericTypeComputed | combinedFlags;
			}
			return t.objectFlags & ObjectFlagsIsGenericType;
		}
		if ((t.flags & TypeFlagsInstantiableNonPrimitive) != 0 || c.isGenericMappedType(t) || c.isGenericTupleType(t)) {
			combinedFlags |= ObjectFlagsIsGenericObjectType;
		}
		if ((t.flags & (TypeFlagsInstantiableNonPrimitive | TypeFlagsIndex)) != 0 || c.isGenericStringLikeType(t)) {
			combinedFlags |= ObjectFlagsIsGenericIndexType;
		}
		return combinedFlags;
	}

	static function isGenericTupleType(c:Checker, t:Type):Bool {
		return Checker.isTupleType(t) && (t.TargetTupleType().combinedFlags & ElementFlagsVariadic) != 0;
	}

	static function isGenericMappedType(c:Checker, t:Type):Bool {
		if ((t.objectFlags & ObjectFlagsMapped) != 0) {
			final constraint = c.getConstraintTypeFromMappedType(t);
			if (c.isGenericIndexType(constraint)) {
				return true;
			}
			// A mapped type is generic if the 'as' clause references generic types other than the iteration type.
			// To determine this, we substitute the constraint type (that we now know isn't generic) for the iteration
			// type and check whether the resulting type is generic.
			final nameType = c.getNameTypeFromMappedType(t);
			if (nameType != null && c.isGenericIndexType(c.instantiateType(nameType, Checker.newSimpleTypeMapper(c.getTypeParameterFromMappedType(t), constraint)))) {
				return true;
			}
		}
		return false;
	}

	/**
	 * A union type which is reducible upon instantiation (meaning some members are removed under certain instantiations)
	 * must be kept generic, as that instantiation information needs to flow through the type system. By replacing all
	 * type parameters in the union with a special never type that is treated as a literal in `getReducedType`, we can cause
	 * the `getReducedType` logic to reduce the resulting type if possible (since only intersections with conflicting
	 * literal-typed properties are reducible).
	 */
	static function isGenericReducibleType(c:Checker, t:Type):Bool {
		return (t.flags & TypeFlagsUnion) != 0 && (t.objectFlags & ObjectFlagsContainsIntersections) != 0 && Core.Some(t.Types(), u -> c.isGenericReducibleType(u))
			|| (t.flags & TypeFlagsIntersection) != 0 && c.isReducibleIntersection(t);
	}

	static function isReducibleIntersection(c:Checker, t:Type):Bool {
		final d = t.AsIntersectionType();
		if (d.uniqueLiteralFilledInstantiation == null) {
			d.uniqueLiteralFilledInstantiation = c.instantiateType(t, c.uniqueLiteralMapper);
		}
		return c.getReducedType(d.uniqueLiteralFilledInstantiation) != d.uniqueLiteralFilledInstantiation;
	}

	static function getUniqueLiteralTypeForTypeParameter(c:Checker, t:Type):Type {
		if ((t.flags & TypeFlagsTypeParameter) != 0) {
			return c.uniqueLiteralType;
		}
		return t;
	}

	static function getConditionalFlowTypeOfType(c:Checker, t:Type, node:Node):Type {
		var constraints:Array<Type> = null;
		var covariant = true;
		while (node != null && !Ast.IsStatement(node) && node.Kind != KindJSDoc) {
			final parent = node.Parent;
			// only consider variance flipped by parameter locations - `keyof` types would usually be considered variance inverting, but
			// often get used in indexed accesses where they behave sortof invariantly, but our checking is lax
			if (Ast.IsParameterDeclaration(parent)) {
				covariant = !covariant;
			}
			// Always substitute on type parameters, regardless of variance, since even
			// in contravariant positions, they may rely on substituted constraints to be valid
			if ((covariant || (t.flags & TypeFlagsTypeVariable) != 0) && Ast.IsConditionalTypeNode(parent) && node == parent.AsConditionalTypeNode().TrueType) {
				final constraint = c.getImpliedConstraint(t, parent.AsConditionalTypeNode().CheckType, parent.AsConditionalTypeNode().ExtendsType);
				if (constraint != null) {
					if (constraints == null) {
						constraints = [];
					}
					constraints.push(constraint);
				}
			} else if ((t.flags & TypeFlagsTypeParameter) != 0 && Ast.IsMappedTypeNode(parent) && parent.AsMappedTypeNode().NameType == null && node == parent.Type()) {
				final mappedType = c.getTypeFromTypeNode(parent);
				if (c.getTypeParameterFromMappedType(mappedType) == c.getActualTypeVariable(t)) {
					final typeParameter = c.getHomomorphicTypeVariable(mappedType);
					if (typeParameter != null) {
						final constraint = c.getConstraintOfTypeParameter(typeParameter);
						if (constraint != null && Checker.everyType(constraint, u -> c.isArrayOrTupleType(u))) {
							if (constraints == null) {
								constraints = [];
							}
							constraints.push(c.getUnionType([c.numberType, c.numericStringType]));
						}
					}
				}
			}
			node = parent;
		}
		if (Core.len(constraints) != 0) {
			return c.getSubstitutionType(t, c.getIntersectionType(constraints));
		}
		return t;
	}

	static function getImpliedConstraint(c:Checker, t:Type, checkNode:Node, extendsNode:Node):Type {
		if (Checker.isUnaryTupleTypeNode(checkNode) && Checker.isUnaryTupleTypeNode(extendsNode)) {
			return c.getImpliedConstraint(t, checkNode.Elements()[0], extendsNode.Elements()[0]);
		} else if (c.getActualTypeVariable(c.getTypeFromTypeNode(checkNode)) == c.getActualTypeVariable(t)) {
			return c.getTypeFromTypeNode(extendsNode);
		}
		return null;
	}

	static function newType(c:Checker, flags:TypeFlags, objectFlags:ObjectFlags, data:TypeData):Type {
		c.TypeCount++;
		final t = data.AsType();
		t.flags = flags;
		t.objectFlags = objectFlags & ~(ObjectFlagsCouldContainTypeVariablesComputed | ObjectFlagsCouldContainTypeVariables | ObjectFlagsMembersResolved);
		t.id = c.TypeCount;
		t.checker = c;
		t.data = data;
		if (c.tracer != null) {
			c.tracer.RecordType(t);
		}
		return t;
	}

	static function newIntrinsicType(c:Checker, flags:TypeFlags, intrinsicName:std.String):Type {
		return c.newIntrinsicTypeEx(flags, intrinsicName, ObjectFlagsNone);
	}

	static function newIntrinsicTypeEx(c:Checker, flags:TypeFlags, intrinsicName:std.String, objectFlags:ObjectFlags):Type {
		final data = new IntrinsicType();
		data.intrinsicName = intrinsicName;
		return c.newType(flags, objectFlags, data);
	}

	static function createWideningType(c:Checker, nonWideningType:Type):Type {
		if (c.strictNullChecks) {
			return nonWideningType;
		}
		final t = c.newIntrinsicType(nonWideningType.flags, nonWideningType.AsIntrinsicType().intrinsicName);
		t.objectFlags |= ObjectFlagsContainsWideningType;
		return t;
	}

	static function createUnknownUnionType(c:Checker):Type {
		if (c.strictNullChecks) {
			return c.getUnionType([c.undefinedType, c.nullType, c.unknownEmptyObjectType]);
		}
		return c.unknownType;
	}

	static function newLiteralType(c:Checker, flags:TypeFlags, value:Any, regularType:Type):Type {
		final data = new LiteralType();
		data.value = value;
		final t = c.newType(flags, ObjectFlagsNone, data);
		if (regularType != null) {
			data.regularType = regularType;
		} else {
			data.regularType = t;
		}
		return t;
	}

	static function newUniqueESSymbolType(c:Checker, symbol:Symbol, name:std.String):Type {
		final data = new UniqueESSymbolType();
		data.name = name;
		final t = c.newType(TypeFlagsUniqueESSymbol, ObjectFlagsNone, data);
		t.symbol = symbol;
		return t;
	}

	static function newObjectType(c:Checker, objectFlags:ObjectFlags, symbol:Symbol):Type {
		var data:TypeData;
		if (objectFlags & ObjectFlagsClassOrInterface != 0) {
			data = new InterfaceType();
		} else if (objectFlags & ObjectFlagsTuple != 0) {
			data = new TupleType();
		} else if (objectFlags & ObjectFlagsReference != 0) {
			data = new TypeReference();
		} else if (objectFlags & ObjectFlagsMapped != 0) {
			data = new MappedType();
		} else if (objectFlags & ObjectFlagsReverseMapped != 0) {
			data = new ReverseMappedType();
		} else if (objectFlags & ObjectFlagsEvolvingArray != 0) {
			data = new EvolvingArrayType();
		} else if (objectFlags & ObjectFlagsInstantiationExpressionType != 0) {
			data = new InstantiationExpressionType();
		} else if (objectFlags & ObjectFlagsAnonymous != 0) {
			data = new ObjectType();
		} else {
			throw "Unhandled case in newObjectType";
		}
		final t = c.newType(TypeFlagsObject, objectFlags, data);
		t.symbol = symbol;
		return t;
	}

	static function newAnonymousType(c:Checker, symbol:Symbol, members:SymbolTable, callSignatures:Array<Signature>, constructSignatures:Array<Signature>, indexInfos:Array<IndexInfo>):Type {
		final t = c.newObjectType(ObjectFlagsAnonymous, symbol);
		c.setStructuredTypeMembers(t, members, callSignatures, constructSignatures, indexInfos);
		return t;
	}

	static function tryCreateTypeReference(c:Checker, target:Type, typeArguments:Array<Type>):Type {
		if (Core.len(typeArguments) != 0 && target == c.emptyGenericType) {
			return c.unknownType;
		}
		return c.createTypeReference(target, typeArguments);
	}

	static function createTypeReference(c:Checker, target:Type, typeArguments:Array<Type>):Type {
		return c.createTypeReferenceEx(target, typeArguments, ObjectFlagsNone);
	}

	static function createTypeReferenceEx(c:Checker, target:Type, typeArguments:Array<Type>, objectFlags:ObjectFlags):Type {
		final id = Checker.getTypeListKey(typeArguments).Key();
		final intf = target.AsInterfaceType();
		final cached = intf.instantiations.get(id);
		if (cached != null) {
			return cached;
		}
		final t = c.newObjectType(ObjectFlagsReference | objectFlags | c.getPropagatingFlagsOfTypes(typeArguments, TypeFlagsNone), target.symbol);
		final d = t.AsTypeReference();
		d.target = target;
		d.resolvedTypeArguments = typeArguments;
		intf.instantiations.set(id, t);
		return t;
	}

	static function createDeferredTypeReference(c:Checker, target:Type, node:Node, mapper:TypeMapper, alias:TypeAlias):Type {
		if (alias == null) {
			alias = c.getAliasForTypeNode(node);
			if (alias != null && mapper != null) {
				alias.typeArguments = c.instantiateTypes(alias.typeArguments, mapper);
			}
		}
		final t = c.newObjectType(ObjectFlagsReference, target.symbol);
		t.alias = alias;
		final d = t.AsTypeReference();
		d.target = target;
		d.mapper = mapper;
		d.node = node;
		return t;
	}

	static function cloneTypeReference(c:Checker, source:Type):Type {
		final t = c.newObjectType(ObjectFlagsReference, source.symbol);
		t.objectFlags = source.objectFlags & ~ObjectFlagsMembersResolved;
		t.AsTypeReference().target = source.AsTypeReference().target;
		t.AsTypeReference().resolvedTypeArguments = source.AsTypeReference().resolvedTypeArguments;
		return t;
	}

	static function setStructuredTypeMembers(c:Checker, t:Type, members:SymbolTable, callSignatures:Array<Signature>, constructSignatures:Array<Signature>, indexInfos:Array<IndexInfo>):Void {
		t.objectFlags |= ObjectFlagsMembersResolved;
		final data = t.AsStructuredType();
		data.members = members;
		data.properties = c.getNamedMembers(members, t.symbol);
		if (Core.len(callSignatures) != 0) {
			if (Core.len(constructSignatures) != 0) {
				data.signatures = Core.Concatenate(callSignatures, constructSignatures);
			} else {
				// PORT: slices.Clip only limits capacity; Haxe arrays have none.
				data.signatures = callSignatures;
			}
			data.callSignatureCount = callSignatures.length;
		} else {
			if (Core.len(constructSignatures) != 0) {
				data.signatures = constructSignatures;
			} else {
				data.signatures = null;
			}
			data.callSignatureCount = 0;
		}
		data.indexInfos = indexInfos;
	}

	static function newTypeParameter(c:Checker, symbol:Symbol):Type {
		final t = c.newType(TypeFlagsTypeParameter, ObjectFlagsNone, new TypeParameter());
		t.symbol = symbol;
		return t;
	}

	// This function is used to propagate certain flags when creating new object type references and union types.
	// It is only necessary to do so if a constituent type might be the undefined type, the null type, the type
	// of an object literal or a non-inferrable type. This is because there are operations in the type checker
	// that care about the presence of such types at arbitrary depth in a containing type.
	static function getPropagatingFlagsOfTypes(c:Checker, types:Array<Type>, excludeKinds:TypeFlags):ObjectFlags {
		var result:ObjectFlags = ObjectFlagsNone;
		if (types != null) {
			for (t in types) {
				if (t.flags & excludeKinds == 0) {
					result |= t.objectFlags;
				}
			}
		}
		return result & ObjectFlagsPropagatingFlags;
	}

	static function newUnionType(c:Checker, objectFlags:ObjectFlags, types:Array<Type>):Type {
		final data = new UnionType();
		data.types = types;
		return c.newType(TypeFlagsUnion, objectFlags, data);
	}

	static function newIntersectionType(c:Checker, objectFlags:ObjectFlags, types:Array<Type>):Type {
		final data = new IntersectionType();
		data.types = types;
		return c.newType(TypeFlagsIntersection, objectFlags, data);
	}

	static function newIndexedAccessType(c:Checker, objectType:Type, indexType:Type, accessFlags:AccessFlags):Type {
		final data = new IndexedAccessType();
		data.objectType = objectType;
		data.indexType = indexType;
		data.accessFlags = accessFlags;
		return c.newType(TypeFlagsIndexedAccess, ObjectFlagsNone, data);
	}

	static function newIndexType(c:Checker, target:Type, indexFlags:IndexFlags):Type {
		final data = new IndexType();
		data.target = target;
		data.indexFlags = indexFlags;
		return c.newType(TypeFlagsIndex, ObjectFlagsNone, data);
	}

	static function newTemplateLiteralType(c:Checker, texts:Array<std.String>, types:Array<Type>):Type {
		final data = new TemplateLiteralType();
		data.texts = texts;
		data.types = types;
		return c.newType(TypeFlagsTemplateLiteral, ObjectFlagsNone, data);
	}

	static function newStringMappingType(c:Checker, symbol:Symbol, target:Type):Type {
		final data = new StringMappingType();
		data.target = target;
		final t = c.newType(TypeFlagsStringMapping, ObjectFlagsNone, data);
		t.symbol = symbol;
		return t;
	}

	static function newConditionalType(c:Checker, root:ConditionalRoot, mapper:TypeMapper, combinedMapper:TypeMapper):Type {
		final data = new ConditionalType();
		data.root = root;
		data.checkType = c.instantiateType(root.checkType, mapper);
		data.extendsType = c.instantiateType(root.extendsType, mapper);
		data.mapper = mapper;
		data.combinedMapper = combinedMapper;
		return c.newType(TypeFlagsConditional, ObjectFlagsNone, data);
	}

	static function newSubstitutionType(c:Checker, baseType:Type, constraint:Type):Type {
		final data = new SubstitutionType();
		data.baseType = baseType;
		data.constraint = constraint;
		return c.newType(TypeFlagsSubstitution, ObjectFlagsNone, data);
	}

	static function newSignature(c:Checker, flags:SignatureFlags, declaration:Node, typeParameters:Array<Type>, thisParameter:Symbol, parameters:Array<Symbol>, resolvedReturnType:Type, resolvedTypePredicate:TypePredicate, minArgumentCount:Int):Signature {
		c.SignatureCount++;
		final sig = c.signatureArena.New();
		sig.id = c.SignatureCount;
		sig.flags = flags;
		sig.declaration = declaration;
		sig.typeParameters = typeParameters;
		sig.parameters = parameters;
		sig.thisParameter = thisParameter;
		sig.resolvedReturnType = resolvedReturnType;
		sig.resolvedTypePredicate = resolvedTypePredicate;
		sig.minArgumentCount = minArgumentCount;
		sig.resolvedMinArgumentCount = -1;
		return sig;
	}

	static function newIndexInfo(c:Checker, keyType:Type, valueType:Type, isReadonly:Bool, declaration:Node, components:Array<Node>):IndexInfo {
		final info = c.indexInfoArena.New();
		info.keyType = keyType;
		info.valueType = valueType;
		info.isReadonly = isReadonly;
		info.declaration = declaration;
		info.components = components;
		return info;
	}

	static function getRegularTypeOfLiteralType(c:Checker, t:Type):Type {
		if (t.flags & TypeFlagsFreshable != 0) {
			return t.AsLiteralType().regularType;
		}
		if (t.flags & TypeFlagsUnion != 0) {
			final u = t.AsUnionType();
			if (u.regularType == null) {
				u.regularType = c.mapType(t, t -> c.getRegularTypeOfLiteralType(t));
			}
			return u.regularType;
		}
		return t;
	}

	static function getFreshTypeOfLiteralType(c:Checker, t:Type):Type {
		if (t.flags & TypeFlagsFreshable != 0) {
			final d = t.AsLiteralType();
			if (d.freshType == null) {
				final f = c.newLiteralType(t.flags, d.value, t);
				f.symbol = t.symbol;
				f.AsLiteralType().freshType = f;
				d.freshType = f;
			}
			return d.freshType;
		}
		return t;
	}

	static function getStringLiteralType(c:Checker, value:std.String):Type {
		var t = c.stringLiteralTypes.get(value);
		if (t == null) {
			t = c.newLiteralType(TypeFlagsStringLiteral, value, null);
			c.stringLiteralTypes.set(value, t);
		}
		return t;
	}

	static function getNumberLiteralType(c:Checker, value:Number):Type {
		// NaN cannot be used as a Go map key because NaN != NaN in IEEE 754,
		// so Go map lookups for NaN always miss. Cache NaN type separately.
		if (value.IsNaN()) {
			if (c.nanType == null) {
				c.nanType = c.newLiteralType(TypeFlagsNumberLiteral, value, null);
			}
			return c.nanType;
		}
		final key = Checker.numberLiteralKey(value);
		var t = c.numberLiteralTypes.get(key);
		if (t == null) {
			t = c.newLiteralType(TypeFlagsNumberLiteral, value, null);
			c.numberLiteralTypes.set(key, t);
		}
		return t;
	}

	static function getBigIntLiteralType(c:Checker, value:PseudoBigInt):Type {
		final key = value.String();
		var t = c.bigintLiteralTypes.get(key);
		if (t == null) {
			t = c.newLiteralType(TypeFlagsBigIntLiteral, value, null);
			c.bigintLiteralTypes.set(key, t);
		}
		return t;
	}

	// text is a valid bigint string excluding a trailing `n`, but including a possible prefix `-`.
	// Use `isValidBigIntString(text, roundTripOnly)` before calling this function.
	static function parseBigIntLiteralType(c:Checker, text:std.String):Type {
		return c.getBigIntLiteralType(Jsnum.ParseValidBigInt(text));
	}

	static function getEnumLiteralType(c:Checker, value:Any, enumSymbol:Symbol, symbol:Symbol):Type {
		var flags:TypeFlags;
		// PORT: Go type switch on value (string | jsnum.Number).
		if (Std.isOfType(value, std.String)) {
			flags = TypeFlagsEnumLiteral | TypeFlagsStringLiteral;
		} else if (Std.isOfType(value, Float)) {
			final v:Number = (value : Float);
			flags = TypeFlagsEnumLiteral | TypeFlagsNumberLiteral;
			// NaN cannot be used as a Go map key because NaN != NaN in IEEE 754,
			// so Go map lookups for NaN always miss. Cache NaN enum types separately by enum symbol.
			if (v.IsNaN()) {
				var t = c.enumNaNLiteralTypes.get(enumSymbol);
				if (t == null) {
					t = c.newLiteralType(flags, value, null);
					t.symbol = symbol;
					c.enumNaNLiteralTypes.set(enumSymbol, t);
				}
				return t;
			}
		} else {
			throw "Unhandled case in getEnumLiteralType";
		}
		final key = EnumLiteralKey.keyOf(c, enumSymbol, value);
		var t = c.enumLiteralTypes.get(key);
		if (t == null) {
			t = c.newLiteralType(flags, value, null);
			t.symbol = symbol;
			c.enumLiteralTypes.set(key, t);
		}
		return t;
	}

	static function isUnitLikeType(c:Checker, t:Type):Bool {
		// Intersections that reduce to 'never' (e.g. 'T & null' where 'T extends {}') are not unit types.
		t = c.getBaseConstraintOrType(t);
		// Scan intersections such that tagged literal types are considered unit types.
		if (t.flags & TypeFlagsIntersection != 0) {
			return Core.Some(t.AsIntersectionType().types, Checker.fn_isUnitType);
		}
		return Checker.isUnitType(t);
	}

	static function extractUnitType(c:Checker, t:Type):Type {
		if (t.flags & TypeFlagsIntersection != 0) {
			final u = Core.Find(t.AsIntersectionType().types, Checker.fn_isUnitType);
			if (u != null) {
				return u;
			}
		}
		return t;
	}

	static function getBaseTypeOfLiteralType(c:Checker, t:Type):Type {
		if (t.flags & TypeFlagsEnumLike != 0) {
			return c.getBaseTypeOfEnumLikeType(t);
		} else if (t.flags & (TypeFlagsStringLiteral | TypeFlagsTemplateLiteral | TypeFlagsStringMapping) != 0) {
			return c.stringType;
		} else if (t.flags & TypeFlagsNumberLiteral != 0) {
			return c.numberType;
		} else if (t.flags & TypeFlagsBigIntLiteral != 0) {
			return c.bigintType;
		} else if (t.flags & TypeFlagsBooleanLiteral != 0) {
			return c.booleanType;
		} else if (t.flags & TypeFlagsUnion != 0) {
			return c.getBaseTypeOfLiteralTypeUnion(t);
		}
		return t;
	}

	// This like getBaseTypeOfLiteralType, but instead treats enum literals as strings/numbers instead
	// of returning their enum base type (which depends on the types of other literals in the enum).
	static function getBaseTypeOfLiteralTypeForComparison(c:Checker, t:Type):Type {
		if (t.flags & (TypeFlagsStringLiteral | TypeFlagsTemplateLiteral | TypeFlagsStringMapping) != 0) {
			return c.stringType;
		} else if (t.flags & (TypeFlagsNumberLiteral | TypeFlagsEnum) != 0) {
			return c.numberType;
		} else if (t.flags & TypeFlagsBigIntLiteral != 0) {
			return c.bigintType;
		} else if (t.flags & TypeFlagsBooleanLiteral != 0) {
			return c.booleanType;
		} else if (t.flags & TypeFlagsUnion != 0) {
			return c.mapType(t, t -> c.getBaseTypeOfLiteralTypeForComparison(t));
		}
		return t;
	}

	static function getBaseTypeOfEnumLikeType(c:Checker, t:Type):Type {
		if (t.flags & TypeFlagsEnumLike != 0 && t.symbol.Flags & SymbolFlagsEnumMember != 0) {
			return c.getDeclaredTypeOfSymbol(c.getParentOfSymbol(t.symbol));
		}
		return t;
	}

	static function getBaseTypeOfLiteralTypeUnion(c:Checker, t:Type):Type {
		final key = CachedTypeKey.keyOf(CachedTypeKindLiteralUnionBaseType, t.id);
		if (c.cachedTypes.exists(key)) {
			return c.cachedTypes.get(key);
		}
		final result = c.mapType(t, t -> c.getBaseTypeOfLiteralType(t));
		c.cachedTypes.set(key, result);
		return result;
	}

	static function getWidenedLiteralType(c:Checker, t:Type):Type {
		if (t.flags & TypeFlagsEnumLike != 0 && Checker.isFreshLiteralType(t)) {
			return c.getBaseTypeOfEnumLikeType(t);
		} else if (t.flags & TypeFlagsStringLiteral != 0 && Checker.isFreshLiteralType(t)) {
			return c.stringType;
		} else if (t.flags & TypeFlagsNumberLiteral != 0 && Checker.isFreshLiteralType(t)) {
			return c.numberType;
		} else if (t.flags & TypeFlagsBigIntLiteral != 0 && Checker.isFreshLiteralType(t)) {
			return c.bigintType;
		} else if (t.flags & TypeFlagsBooleanLiteral != 0 && Checker.isFreshLiteralType(t)) {
			return c.booleanType;
		} else if (t.flags & TypeFlagsUnion != 0) {
			return c.mapType(t, t -> c.getWidenedLiteralType(t));
		}
		return t;
	}

	static function getWidenedUniqueESSymbolType(c:Checker, t:Type):Type {
		if (t.flags & TypeFlagsUniqueESSymbol != 0) {
			return c.esSymbolType;
		} else if (t.flags & TypeFlagsUnion != 0) {
			return c.mapType(t, t -> c.getWidenedUniqueESSymbolType(t));
		}
		return t;
	}

	static function getWidenedLiteralLikeTypeForContextualType(c:Checker, t:Type, contextualType:Type):Type {
		if (!c.isLiteralOfContextualType(t, contextualType)) {
			t = c.getWidenedUniqueESSymbolType(c.getWidenedLiteralType(t));
		}
		return c.getRegularTypeOfLiteralType(t);
	}

	static function isLiteralOfContextualType(c:Checker, candidateType:Type, contextualType:Type):Bool {
		if (contextualType != null) {
			if (contextualType.flags & TypeFlagsUnionOrIntersection != 0) {
				return Core.Some(contextualType.Types(), (t:Type) -> c.isLiteralOfContextualType(candidateType, t));
			}
			if (contextualType.flags & TypeFlagsInstantiableNonPrimitive != 0) {
				// If the contextual type is a type variable constrained to a primitive type, consider
				// this a literal context for literals of that primitive type. For example, given a
				// type parameter 'T extends string', infer string literal types for T.
				var constraint = c.getBaseConstraintOfType(contextualType);
				if (constraint == null) {
					constraint = c.unknownType;
				}
				return c.maybeTypeOfKind(constraint, TypeFlagsString) && c.maybeTypeOfKind(candidateType, TypeFlagsStringLiteral)
					|| c.maybeTypeOfKind(constraint, TypeFlagsNumber) && c.maybeTypeOfKind(candidateType, TypeFlagsNumberLiteral)
					|| c.maybeTypeOfKind(constraint, TypeFlagsBigInt) && c.maybeTypeOfKind(candidateType, TypeFlagsBigIntLiteral)
					|| c.maybeTypeOfKind(constraint, TypeFlagsESSymbol) && c.maybeTypeOfKind(candidateType, TypeFlagsUniqueESSymbol)
					|| c.isLiteralOfContextualType(candidateType, constraint);
			}
			// If the contextual type is a literal of a particular primitive type, we consider this a
			// literal context for all literals of that primitive type.
			return contextualType.flags & (TypeFlagsStringLiteral | TypeFlagsIndex | TypeFlagsTemplateLiteral | TypeFlagsStringMapping) != 0
				&& c.maybeTypeOfKind(candidateType, TypeFlagsStringLiteral)
				|| contextualType.flags & TypeFlagsNumberLiteral != 0 && c.maybeTypeOfKind(candidateType, TypeFlagsNumberLiteral)
				|| contextualType.flags & TypeFlagsBigIntLiteral != 0 && c.maybeTypeOfKind(candidateType, TypeFlagsBigIntLiteral)
				|| contextualType.flags & TypeFlagsBooleanLiteral != 0 && c.maybeTypeOfKind(candidateType, TypeFlagsBooleanLiteral)
				|| contextualType.flags & TypeFlagsUniqueESSymbol != 0 && c.maybeTypeOfKind(candidateType, TypeFlagsUniqueESSymbol);
		}
		return false;
	}

	static function mapTypeWithAlias(c:Checker, t:Type, f:(t:Type) -> Type, alias:TypeAlias):Type {
		if (t.flags & TypeFlagsUnion != 0 && alias != null) {
			return c.getUnionTypeEx(Core.Map(t.Types(), f), UnionReductionLiteral, alias, null);
		}
		return c.mapType(t, f);
	}

	static function mapType(c:Checker, t:Type, f:(Type) -> Type):Type {
		return c.mapTypeEx(t, f, false /*noReductions*/);
	}

	static function mapTypeEx(c:Checker, t:Type, f:(Type) -> Type, noReductions:Bool):Type {
		if (t.flags & TypeFlagsNever != 0) {
			return t;
		}
		if (t.flags & TypeFlagsUnion == 0) {
			return f(t);
		}
		final u = t.AsUnionType();
		var types = u.types;
		if (u.origin != null && u.origin.flags & TypeFlagsUnion != 0) {
			types = u.origin.Types();
		}
		final mappedTypes:Array<Type> = [];
		var changed = false;
		if (types != null) {
			for (s in types) {
				var mapped:Type;
				if (s.flags & TypeFlagsUnion != 0) {
					mapped = c.mapTypeEx(s, f, noReductions);
				} else {
					mapped = f(s);
				}
				if (mapped != s) {
					changed = true;
				}
				if (mapped != null) {
					mappedTypes.push(mapped);
				}
			}
		}
		if (changed) {
			if (mappedTypes.length == 0) {
				return null;
			}
			// PORT: slices.Clone(mappedTypes) — mappedTypes is already a fresh array owned by this call.
			return c.getUnionTypeEx(mappedTypes, Core.IfElse(noReductions, UnionReductionNone, UnionReductionLiteral), null /*alias*/, null /*origin*/);
		}
		return t;
	}

	static function getUnionOrIntersectionType(c:Checker, types:Array<Type>, isUnion:Bool, unionReduction:UnionReduction):Type {
		if (isUnion) {
			return c.getUnionTypeEx(types, unionReduction, null, null);
		}
		return c.getIntersectionType(types);
	}

	static function getUnionType(c:Checker, types:Array<Type>):Type {
		return c.getUnionTypeEx(types, UnionReductionLiteral, null /*alias*/, null /*origin*/);
	}

	// We sort and deduplicate the constituent types based on object identity. If the subtypeReduction
	// flag is specified we also reduce the constituent type set to only include types that aren't subtypes
	// of other types. Subtype reduction is expensive for large union types and is possible only when union
	// types are known not to circularly reference themselves (as is the case with union types created by
	// expression constructs such as array literals and the || and ?: operators). Named types can
	// circularly reference themselves and therefore cannot be subtype reduced during their declaration.
	// For example, "type Item = string | (() => Item" is a named type that circularly references itself.
	static function getUnionTypeEx(c:Checker, types:Array<Type>, unionReduction:UnionReduction, alias:TypeAlias, origin:Type):Type {
		if (Core.len(types) == 0) {
			return c.neverType;
		}
		if (types.length == 1) {
			return types[0];
		}
		// We optimize for the common case of unioning a union type with some other type (such as `undefined`).
		if (types.length == 2 && origin == null && (types[0].flags & TypeFlagsUnion != 0 || types[1].flags & TypeFlagsUnion != 0)) {
			var id1 = types[0].id;
			var id2 = types[1].id;
			if (id1 > id2) {
				final tmp = id1;
				id1 = id2;
				id2 = tmp;
			}
			final key = UnionOfUnionKey.keyOf(id1, id2, unionReduction, Checker.getAliasKey(alias));
			var t = c.unionOfUnionTypes.get(key);
			if (t == null) {
				t = c.getUnionTypeWorker(types, unionReduction, alias, null /*origin*/);
				c.unionOfUnionTypes.set(key, t);
			}
			return t;
		}
		return c.getUnionTypeWorker(types, unionReduction, alias, origin);
	}

	static function getUnionTypeWorker(c:Checker, types:Array<Type>, unionReduction:UnionReduction, alias:TypeAlias, origin:Type):Type {
		final r = c.addTypesToUnion([], 0, types);
		var typeSet = r.a;
		final includes = r.b;
		if (unionReduction != UnionReductionNone) {
			if (includes & TypeFlagsAnyOrUnknown != 0) {
				if (includes & TypeFlagsAny != 0) {
					if (includes & TypeFlagsIncludesWildcard != 0) {
						return c.wildcardType;
					} else if (includes & TypeFlagsIncludesError != 0) {
						return c.errorType;
					}
					return c.anyType;
				}
				return c.unknownType;
			}
			if (includes & TypeFlagsUndefined != 0) {
				// If type set contains both undefinedType and missingType, remove missingType
				if (typeSet.length >= 2 && typeSet[0] == c.undefinedType && typeSet[1] == c.missingType) {
					typeSet.splice(1, 1);
				}
			}
			if (includes & (TypeFlagsEnum | TypeFlagsLiteral | TypeFlagsUniqueESSymbol | TypeFlagsTemplateLiteral | TypeFlagsStringMapping) != 0
				|| includes & TypeFlagsVoid != 0 && includes & TypeFlagsUndefined != 0) {
				typeSet = c.removeRedundantLiteralTypes(typeSet, includes, (unionReduction : Int) & (UnionReductionSubtype : Int) != 0);
			}
			if (includes & TypeFlagsStringLiteral != 0 && includes & (TypeFlagsTemplateLiteral | TypeFlagsStringMapping) != 0) {
				typeSet = c.removeStringLiteralsMatchedByTemplateLiterals(typeSet);
			}
			if (includes & TypeFlagsIncludesConstrainedTypeVariable != 0) {
				typeSet = c.removeConstrainedTypeVariables(typeSet);
			}
			if (unionReduction == UnionReductionSubtype) {
				typeSet = c.removeSubtypes(typeSet, includes & TypeFlagsObject != 0);
				if (typeSet == null) {
					return c.errorType;
				}
			}
			if (Core.len(typeSet) == 0) {
				if (includes & TypeFlagsNull != 0) {
					if (includes & TypeFlagsIncludesNonWideningType != 0) {
						return c.nullType;
					}
					return c.nullWideningType;
				} else if (includes & TypeFlagsUndefined != 0) {
					if (includes & TypeFlagsIncludesNonWideningType != 0) {
						return c.undefinedType;
					}
					return c.undefinedWideningType;
				}
				return c.neverType;
			}
		}
		if (origin == null && includes & TypeFlagsUnion != 0) {
			final namedUnions = c.addNamedUnions(null, types);
			var reducedTypes:Array<Type> = null;
			for (t in typeSet) {
				if (!Core.Some(namedUnions, (u:Type) -> Checker.containsType(u.Types(), t))) {
					if (reducedTypes == null) {
						reducedTypes = [];
					}
					reducedTypes.push(t);
				}
			}
			if (alias == null && Core.len(namedUnions) == 1 && Core.len(reducedTypes) == 0) {
				return namedUnions[0];
			}
			// We create a denormalized origin type only when the union was created from one or more named unions
			// (unions with alias symbols or origins) and when there is no overlap between those named unions.
			var namedTypesCount = 0;
			if (namedUnions != null) {
				for (u in namedUnions) {
					namedTypesCount += Core.len(u.Types());
				}
			}
			if (namedTypesCount + Core.len(reducedTypes) == typeSet.length) {
				if (namedUnions != null) {
					for (t in namedUnions) {
						reducedTypes = Checker.insertType(reducedTypes, t).value;
					}
				}
				origin = c.newUnionType(ObjectFlagsNone, reducedTypes);
			}
		}
		final objectFlags:ObjectFlags = Core.IfElse(includes & TypeFlagsNotPrimitiveUnion != 0, ObjectFlagsNone, ObjectFlagsPrimitiveUnion)
			| Core.IfElse(includes & TypeFlagsIntersection != 0, ObjectFlagsContainsIntersections, ObjectFlagsNone);
		return c.getUnionTypeFromSortedList(typeSet, objectFlags, alias, origin);
	}

	// This function assumes the constituent type list is sorted and deduplicated.
	static function getUnionTypeFromSortedList(c:Checker, types:Array<Type>, precomputedObjectFlags:ObjectFlags, alias:TypeAlias, origin:Type):Type {
		if (Core.len(types) == 0) {
			return c.neverType;
		}
		if (types.length == 1) {
			return types[0];
		}
		final key = Checker.getUnionKey(types, origin, alias).Key();
		var t = c.unionTypes.get(key);
		if (t == null) {
			t = c.newUnionType(precomputedObjectFlags | c.getPropagatingFlagsOfTypes(types, TypeFlagsNullable), types);
			t.AsUnionType().origin = origin;
			t.alias = alias;
			if (types.length == 2 && types[0].flags & TypeFlagsBooleanLiteral != 0 && types[1].flags & TypeFlagsBooleanLiteral != 0) {
				t.flags |= TypeFlagsBoolean;
			}
			c.unionTypes.set(key, t);
		}
		return t;
	}

	public static function UnionTypes(c:Checker):(yield:(Type) -> Bool) -> Void {
		// PORT: Go `maps.Values(c.unionTypes)` as the iter.Seq form; Go map order is random, StringMap order is used.
		final m = c.unionTypes;
		return function(yield_:(Type) -> Bool):Void {
			if (m != null) {
				for (t in m) {
					if (!yield_(t)) {
						return;
					}
				}
			}
		};
	}

	static function addTypesToUnion(c:Checker, typeSet:Array<Type>, includes:TypeFlags, types:Array<Type>):Pair<Array<Type>, TypeFlags> {
		var lastType:Type = null;
		if (types != null) {
			for (t in types) {
				if (t != lastType) {
					if (t.flags & TypeFlagsUnion != 0) {
						final u = t.AsUnionType();
						if (t.alias != null || u.origin != null) {
							includes |= TypeFlagsUnion;
						}
						final r = c.addTypesToUnion(typeSet, includes, u.types);
						typeSet = r.a;
						includes = r.b;
					} else {
						final r = c.addTypeToUnion(typeSet, includes, t);
						typeSet = r.a;
						includes = r.b;
					}
					lastType = t;
				}
			}
		}
		return new Pair<Array<Type>, TypeFlags>(typeSet, includes);
	}

	static function addTypeToUnion(c:Checker, typeSet:Array<Type>, includes:TypeFlags, t:Type):Pair<Array<Type>, TypeFlags> {
		final flags = t.flags;
		// We ignore 'never' types in unions
		if (flags & TypeFlagsNever == 0) {
			includes |= flags & TypeFlagsIncludesMask;
			if (flags & TypeFlagsInstantiable != 0) {
				includes |= TypeFlagsIncludesInstantiable;
			}
			if (flags & TypeFlagsIntersection != 0 && t.objectFlags & ObjectFlagsIsConstrainedTypeVariable != 0) {
				includes |= TypeFlagsIncludesConstrainedTypeVariable;
			}
			if (t == c.wildcardType) {
				includes |= TypeFlagsIncludesWildcard;
			}
			if (c.isErrorType(t)) {
				includes |= TypeFlagsIncludesError;
			}
			if (!c.strictNullChecks && flags & TypeFlagsNullable != 0) {
				if (t.objectFlags & ObjectFlagsContainsWideningType == 0) {
					includes |= TypeFlagsIncludesNonWideningType;
				}
			} else {
				final r = Slices.BinarySearchFuncInline(typeSet, t, (a, b) -> Checker.CompareTypes(a, b)) /* PORT: perf */;
				if (!r.ok) {
					// PORT: slices.Insert into the typeSet this union build owns (in place).
					if (typeSet == null) {
						typeSet = [];
					}
					typeSet.insert(r.value, t);
				}
			}
		}
		return new Pair<Array<Type>, TypeFlags>(typeSet, includes);
	}

	static function addNamedUnions(c:Checker, namedUnions:Array<Type>, types:Array<Type>):Array<Type> {
		if (types != null) {
			for (t in types) {
				if (t.flags & TypeFlagsUnion != 0) {
					final u = t.AsUnionType();
					if (t.alias != null || u.origin != null && u.origin.flags & TypeFlagsUnion == 0) {
						namedUnions = Core.AppendIfUnique(namedUnions, t);
					} else if (u.origin != null && u.origin.flags & TypeFlagsUnion != 0) {
						namedUnions = c.addNamedUnions(namedUnions, u.origin.Types());
					}
				}
			}
		}
		return namedUnions;
	}

	static function removeRedundantLiteralTypes(c:Checker, types:Array<Type>, includes:TypeFlags, reduceVoidUndefined:Bool):Array<Type> {
		var i = Core.len(types);
		while (i > 0) {
			i--;
			final t = types[i];
			final flags = t.flags;
			final remove = flags & (TypeFlagsStringLiteral | TypeFlagsTemplateLiteral | TypeFlagsStringMapping) != 0 && includes & TypeFlagsString != 0
				|| flags & TypeFlagsNumberLiteral != 0 && includes & TypeFlagsNumber != 0
				|| flags & TypeFlagsBigIntLiteral != 0 && includes & TypeFlagsBigInt != 0
				|| flags & TypeFlagsUniqueESSymbol != 0 && includes & TypeFlagsESSymbol != 0
				|| reduceVoidUndefined && flags & TypeFlagsUndefined != 0 && includes & TypeFlagsVoid != 0
				|| Checker.isFreshLiteralType(t) && Checker.containsType(types, t.AsLiteralType().regularType);
			if (remove) {
				types.splice(i, 1);
			}
		}
		return types;
	}

	static function removeStringLiteralsMatchedByTemplateLiterals(c:Checker, types:Array<Type>):Array<Type> {
		final templates = Core.Filter(types, (t:Type) -> c.isPatternLiteralType(t));
		if (Core.len(templates) != 0) {
			var i = types.length;
			while (i > 0) {
				i--;
				final t = types[i];
				if (t.flags & TypeFlagsStringLiteral != 0 && Core.Some(templates, (template:Type) -> c.isTypeMatchedByTemplateLiteralOrStringMapping(t, template))) {
					types.splice(i, 1);
				}
			}
		}
		return types;
	}

	static function isTypeMatchedByTemplateLiteralOrStringMapping(c:Checker, t:Type, template:Type):Bool {
		if (template.flags & TypeFlagsTemplateLiteral != 0) {
			return c.isTypeMatchedByTemplateLiteralType(t, template.AsTemplateLiteralType(), c.compareTypesAssignable);
		}
		return c.isMemberOfStringMapping(t, template);
	}

	static function removeConstrainedTypeVariables(c:Checker, types:Array<Type>):Array<Type> {
		var typeVariables:Array<Type> = null;
		// First collect a list of the type variables occurring in constraining intersections.
		for (t in rangeOf(types)) {
			if (t.flags & TypeFlagsIntersection != 0 && t.objectFlags & ObjectFlagsIsConstrainedTypeVariable != 0) {
				var index = 0;
				if (t.AsIntersectionType().types[0].flags & TypeFlagsTypeVariable == 0) {
					index = 1;
				}
				typeVariables = Core.AppendIfUnique(typeVariables, t.AsIntersectionType().types[index]);
			}
		}
		// For each type variable, check if the constraining intersections for that type variable fully
		// cover the constraint of the type variable; if so, remove the constraining intersections and
		// substitute the type variable.
		for (typeVariable in rangeOf(typeVariables)) {
			var primitives:Array<Type> = null;
			// First collect the primitive types from the constraining intersections.
			for (t in rangeOf(types)) {
				if (t.flags & TypeFlagsIntersection != 0 && t.objectFlags & ObjectFlagsIsConstrainedTypeVariable != 0) {
					var index = 0;
					if (t.AsIntersectionType().types[0].flags & TypeFlagsTypeVariable == 0) {
						index = 1;
					}
					if (t.AsIntersectionType().types[index] == typeVariable) {
						primitives = Checker.insertType(primitives, t.AsIntersectionType().types[1 - index]).value;
					}
				}
			}
			// If every constituent in the type variable's constraint is covered by an intersection of the type
			// variable and that constituent, remove those intersections and substitute the type variable.
			final constraint = c.getBaseConstraintOfType(typeVariable);
			if (Checker.everyType(constraint, (t:Type) -> Checker.containsType(primitives, t))) {
				var i = Core.len(types);
				while (i > 0) {
					i--;
					final t = types[i];
					if (t.flags & TypeFlagsIntersection != 0 && t.objectFlags & ObjectFlagsIsConstrainedTypeVariable != 0) {
						var index = 0;
						if (t.AsIntersectionType().types[0].flags & TypeFlagsTypeVariable == 0) {
							index = 1;
						}
						if (t.AsIntersectionType().types[index] == typeVariable && Checker.containsType(primitives, t.AsIntersectionType().types[1 - index])) {
							types.splice(i, 1);
						}
					}
				}
				types = Checker.insertType(types, typeVariable).value;
			}
		}
		return types;
	}

	static function removeSubtypes(c:Checker, types:Array<Type>, hasObjectTypes:Bool):Array<Type> {
		// [] and [T] immediately reduce to [] and [T] respectively
		if (Core.len(types) < 2) {
			return types;
		}
		final key = Checker.getTypeListKey(types).Key();
		final cached = c.subtypeReductionCache.get(key);
		if (cached != null) {
			return cached;
		}
		// We assume that redundant primitive types have already been removed from the types array and that there
		// are no any and unknown types in the array. Thus, the only possible supertypes for primitive types are empty
		// object types, and if none of those are present we can exclude primitive types from the subtype check.
		final hasEmptyObject = hasObjectTypes && Core.Some(types, (t:Type) -> {
			return t.flags & TypeFlagsObject != 0 && !c.isGenericMappedType(t) && c.isEmptyResolvedType(c.resolveStructuredTypeMembers(t));
		});
		// PORT: the Find predicate does not depend on the loop; created once (PORTING.md §7a).
		final isUnitTypedProperty = (p:Symbol) -> Checker.isUnitType(c.getTypeOfSymbol(p));
		final length = types.length;
		var i = length;
		var count = 0;
		while (i > 0) {
			i--;
			final source = types[i];
			if (hasEmptyObject || source.flags & TypeFlagsStructuredOrInstantiable != 0) {
				// A type parameter with a union constraint may be a subtype of some union, but not a subtype of the
				// individual constituents of that union. For example, `T extends A | B` is a subtype of `A | B`, but not
				// a subtype of just `A` or just `B`. When we encounter such a type parameter, we therefore check if the
				// type parameter is a subtype of a union of all the other types.
				if (source.flags & TypeFlagsTypeParameter != 0 && c.getBaseConstraintOrType(source).flags & TypeFlagsUnion != 0) {
					if (c.isTypeRelatedTo(source, c.getUnionType(Core.Map(types, (t:Type) -> {
						if (t == source) {
							return c.neverType;
						}
						return t;
					})), c.strictSubtypeRelation)) {
						types.splice(i, 1);
					}
					continue;
				}
				// Find the first property with a unit type, if any. When constituents have a property by the same name
				// but of a different unit type, we can quickly disqualify them from subtype checks. This helps subtype
				// reduction of large discriminated union types.
				var keyProperty:Symbol = null;
				var keyPropertyType:Type = null;
				if (source.flags & (TypeFlagsObject | TypeFlagsIntersection | TypeFlagsInstantiableNonPrimitive) != 0) {
					keyProperty = Core.Find(c.getPropertiesOfType(source), isUnitTypedProperty);
				}
				if (keyProperty != null) {
					keyPropertyType = c.getRegularTypeOfLiteralType(c.getTypeOfSymbol(keyProperty));
				}
				for (target in types) {
					if (source != target) {
						if (count == 100000) {
							// After 100000 subtype checks we estimate the remaining amount of work by assuming the
							// same ratio of checks per element. If the estimated number of remaining type checks is
							// greater than 1M we deem the union type too complex to represent. This for example
							// caps union types at 1000 unique object types.
							final estimatedCount = Std.int(count / (length - i)) * length;
							if (estimatedCount > 1000000) {
								final tr = c.tracer;
								if (tr != null) {
									final args = new StringMap<Any>();
									args.set("estimatedCount", estimatedCount);
									tr.Instant(PhaseCheckTypes, "removeSubtypes_DepthLimit", args);
								}
								c.error(c.currentNode, Diagnostics.Expression_produces_a_union_type_that_is_too_complex_to_represent);
								return null;
							}
						}
						count++;
						if (keyProperty != null && target.flags & (TypeFlagsObject | TypeFlagsIntersection | TypeFlagsInstantiableNonPrimitive) != 0) {
							final t = c.getTypeOfPropertyOfType(target, keyProperty.Name);
							if (t != null && Checker.isUnitType(t) && c.getRegularTypeOfLiteralType(t) != keyPropertyType) {
								continue;
							}
						}
						if ((source == c.emptyObjectType || source == c.unknownEmptyObjectType) && target.symbol != null && c.IsEmptyAnonymousObjectType(target)) {
							continue;
						}
						if (c.isTypeRelatedTo(source, target, c.strictSubtypeRelation) && (c.getTargetType(source).objectFlags & ObjectFlagsClass == 0
							|| c.getTargetType(target).objectFlags & ObjectFlagsClass == 0
							|| c.isTypeDerivedFrom(source, target))) {
							types.splice(i, 1);
							break;
						}
					}
				}
			}
		}
		c.subtypeReductionCache.set(key, types);
		return types;
	}

	static function intersectTypes(c:Checker, type1:Type, type2:Type):Type {
		if (type1 == null) {
			return type2;
		} else if (type2 == null) {
			return type1;
		}
		return c.getIntersectionType([type1, type2]);
	}

	// We normalize combinations of intersection and union types based on the distributive property of the '&'
	// operator. Specifically, because X & (A | B) is equivalent to X & A | X & B, we can transform intersection
	// types with union type constituents into equivalent union types with intersection type constituents and
	// effectively ensure that union types are always at the top level in type representations.
	//
	// We do not perform structural deduplication on intersection types. Intersection types are created only by the &
	// type operator and we can't reduce those because we want to support recursive intersection types. For example,
	// a type alias of the form "type List<T> = T & { next: List<T> }" cannot be reduced during its declaration.
	// Also, unlike union types, the order of the constituent types is preserved in order that overload resolution
	// for intersections of types with signatures can be deterministic.
	static function getIntersectionType(c:Checker, types:Array<Type>):Type {
		return c.getIntersectionTypeEx(types, IntersectionFlagsNone, null /*alias*/);
	}

	static function getIntersectionTypeEx(c:Checker, types:Array<Type>, flags:IntersectionFlags, alias:TypeAlias):Type {
		final orderedTypes = new OrderedSet<Type>();
		orderedTypes.values = [];
		final includes = c.addTypesToIntersection(orderedTypes, 0, types);
		var typeSet = orderedTypes.values;
		var objectFlags:ObjectFlags = ObjectFlagsNone;
		// An intersection type is considered empty if it contains
		// the type never, or
		// more than one unit type or,
		// an object type and a nullable type (null or undefined), or
		// a string-like type and a type known to be non-string-like, or
		// a number-like type and a type known to be non-number-like, or
		// a symbol-like type and a type known to be non-symbol-like, or
		// a void-like type and a type known to be non-void-like, or
		// a non-primitive type and a type known to be primitive.
		if ((includes & TypeFlagsNever) != 0) {
			if (Slices.Contains(typeSet, c.silentNeverType)) {
				return c.silentNeverType;
			}
			return c.neverType;
		}
		if (c.strictNullChecks && (includes & TypeFlagsNullable) != 0 && (includes & (TypeFlagsObject | TypeFlagsNonPrimitive | TypeFlagsIncludesEmptyObject)) != 0
			|| (includes & TypeFlagsNonPrimitive) != 0 && (includes & (TypeFlagsDisjointDomains & ~TypeFlagsNonPrimitive)) != 0
			|| (includes & TypeFlagsStringLike) != 0 && (includes & (TypeFlagsDisjointDomains & ~TypeFlagsStringLike)) != 0
			|| (includes & TypeFlagsNumberLike) != 0 && (includes & (TypeFlagsDisjointDomains & ~TypeFlagsNumberLike)) != 0
			|| (includes & TypeFlagsBigIntLike) != 0 && (includes & (TypeFlagsDisjointDomains & ~TypeFlagsBigIntLike)) != 0
			|| (includes & TypeFlagsESSymbolLike) != 0 && (includes & (TypeFlagsDisjointDomains & ~TypeFlagsESSymbolLike)) != 0
			|| (includes & TypeFlagsVoidLike) != 0 && (includes & (TypeFlagsDisjointDomains & ~TypeFlagsVoidLike)) != 0) {
			return c.neverType;
		}
		if ((includes & (TypeFlagsTemplateLiteral | TypeFlagsStringMapping)) != 0 && (includes & TypeFlagsStringLiteral) != 0) {
			final r = c.extractRedundantTemplateLiterals(typeSet);
			typeSet = r.value;
			if (r.ok) {
				return c.neverType;
			}
		}
		if ((includes & TypeFlagsAny) != 0) {
			if ((includes & TypeFlagsIncludesWildcard) != 0) {
				return c.wildcardType;
			} else if ((includes & TypeFlagsIncludesError) != 0) {
				return c.errorType;
			}
			return c.anyType;
		}
		if (!c.strictNullChecks && (includes & TypeFlagsNullable) != 0) {
			if ((includes & TypeFlagsIncludesEmptyObject) != 0) {
				return c.neverType;
			} else if ((includes & TypeFlagsUndefined) != 0) {
				return c.undefinedType;
			}
			return c.nullType;
		}
		if ((includes & TypeFlagsString) != 0 && (includes & (TypeFlagsStringLiteral | TypeFlagsTemplateLiteral | TypeFlagsStringMapping)) != 0
			|| (includes & TypeFlagsNumber) != 0 && (includes & TypeFlagsNumberLiteral) != 0
			|| (includes & TypeFlagsBigInt) != 0 && (includes & TypeFlagsBigIntLiteral) != 0
			|| (includes & TypeFlagsESSymbol) != 0 && (includes & TypeFlagsUniqueESSymbol) != 0
			|| (includes & TypeFlagsVoid) != 0 && (includes & TypeFlagsUndefined) != 0
			|| (includes & TypeFlagsIncludesEmptyObject) != 0 && (includes & TypeFlagsDefinitelyNonNullable) != 0) {
			if ((flags & IntersectionFlagsNoSupertypeReduction) == 0) {
				typeSet = c.removeRedundantSupertypes(typeSet, includes);
			}
		}
		if ((includes & TypeFlagsIncludesMissingType) != 0) {
			typeSet[Slices.Index(typeSet, c.undefinedType)] = c.missingType;
		}
		if (Core.len(typeSet) == 0) {
			return c.unknownType;
		}
		if (typeSet.length == 1) {
			return typeSet[0];
		}
		if (typeSet.length == 2 && (flags & IntersectionFlagsNoConstraintReduction) == 0) {
			var typeVarIndex = 0;
			if ((typeSet[0].flags & TypeFlagsTypeVariable) == 0) {
				typeVarIndex = 1;
			}
			final typeVariable = typeSet[typeVarIndex];
			final primitiveType = typeSet[1 - typeVarIndex];
			if ((typeVariable.flags & TypeFlagsTypeVariable) != 0
				&& ((primitiveType.flags & (TypeFlagsPrimitive | TypeFlagsNonPrimitive)) != 0 && !c.isGenericStringLikeType(primitiveType)
					|| (includes & TypeFlagsIncludesEmptyObject) != 0)) {
				// We have an intersection T & P or P & T, where T is a type variable and P is a primitive type, the object type, or {}.
				final constraint = c.getBaseConstraintOfType(typeVariable);
				// Check that T's constraint is similarly composed of primitive types, the object type, or {}.
				if (constraint != null && Checker.everyType(constraint, c.isPrimitiveOrObjectOrEmptyType)) {
					// If T's constraint is a subtype of P, simply return T. For example, given `T extends "a" | "b"`,
					// the intersection `T & string` reduces to just T.
					if (c.isTypeStrictSubtypeOf(constraint, primitiveType)) {
						return typeVariable;
					}
					if (!((constraint.flags & TypeFlagsUnion) != 0 && Checker.someType(constraint, (n:Type) -> c.isTypeStrictSubtypeOf(n, primitiveType)))) {
						// No constituent of T's constraint is a subtype of P. If P is also not a subtype of T's constraint,
						// then the constraint and P are unrelated, and the intersection reduces to never. For example, given
						// `T extends "a" | "b"`, the intersection `T & number` reduces to never.
						if (!c.isTypeStrictSubtypeOf(primitiveType, constraint)) {
							return c.neverType;
						}
					}
					// Some constituent of T's constraint is a subtype of P, or P is a subtype of T's constraint. Thus,
					// the intersection further constrains the type variable. For example, given `T extends string | number`,
					// the intersection `T & "a"` is marked as a constrained type variable. Likewise, given `T extends "a" | 1`,
					// the intersection `T & number` is marked as a constrained type variable.
					objectFlags = ObjectFlagsIsConstrainedTypeVariable;
				}
			}
		}
		final key = Checker.getIntersectionKey(typeSet, flags, alias).Key();
		var result = c.intersectionTypes.get(key);
		if (result == null) {
			if ((includes & TypeFlagsUnion) != 0) {
				final r = c.intersectUnionsOfPrimitiveTypes(typeSet);
				typeSet = r.value;
				final reduced = r.ok;
				if (reduced) {
					// When the intersection creates a reduced set (which might mean that *all* union types have
					// disappeared), we restart the operation to get a new set of combined flags. Once we have
					// reduced we'll never reduce again, so this occurs at most once.
					result = c.getIntersectionTypeEx(typeSet, flags, alias);
				} else if (Core.Every(typeSet, Checker.isUnionWithUndefined)) {
					var containedUndefinedType = c.undefinedType;
					if (Core.Some(typeSet, c.containsMissingType)) {
						containedUndefinedType = c.missingType;
					}
					c.filterTypes(typeSet, Checker.isNotUndefinedType);
					result = c.getUnionTypeEx([c.getIntersectionTypeEx(typeSet, flags, null /*alias*/), containedUndefinedType], UnionReductionLiteral, alias, null /*origin*/);
				} else if (Core.Every(typeSet, Checker.isUnionWithNull)) {
					c.filterTypes(typeSet, Checker.isNotNullType);
					result = c.getUnionTypeEx([c.getIntersectionTypeEx(typeSet, flags, null /*alias*/), c.nullType], UnionReductionLiteral, alias, null /*origin*/);
				} else if (typeSet.length >= 3 && Core.len(types) > 2) {
					// When we have three or more constituents, more than two inputs (to head off infinite reexpansion), some of which are unions, we employ a "divide and conquer" strategy
					// where A & B & C & D is processed as (A & B) & (C & D). Since intersections of unions often produce far smaller
					// unions of intersections than the full cartesian product (due to some intersections becoming `never`), this can
					// dramatically reduce the overall work.
					final middle = Std.int(typeSet.length / 2);
					result = c.getIntersectionTypeEx([
						c.getIntersectionTypeEx(typeSet.slice(0, middle), flags, null /*alias*/),
						c.getIntersectionTypeEx(typeSet.slice(middle), flags, null /*alias*/),
					], flags, alias);
				} else {
					// We are attempting to construct a type of the form X & (A | B) & (C | D). Transform this into a type of
					// the form X & A & C | X & A & D | X & B & C | X & B & D. If the estimated size of the resulting union type
					// exceeds 100000 constituents, report an error.
					if (!c.checkCrossProductUnion(typeSet)) {
						return c.errorType;
					}
					final constituents = c.getCrossProductIntersections(typeSet, flags);
					// We attach a denormalized origin type when at least one constituent of the cross-product union is an
					// intersection (i.e. when the intersection didn't just reduce one or more unions to smaller unions) and
					// the denormalized origin has fewer constituents than the union itself.
					var origin:Type = null;
					if (Core.Some(constituents, Checker.isIntersectionType) && Checker.getConstituentCountOfTypes(constituents) > Checker.getConstituentCountOfTypes(typeSet)) {
						origin = c.newIntersectionType(ObjectFlagsNone, typeSet);
					}
					result = c.getUnionTypeEx(constituents, UnionReductionLiteral, alias, origin);
				}
			} else {
				result = c.newIntersectionType(objectFlags | c.getPropagatingFlagsOfTypes(types, TypeFlagsNullable /*excludeKinds*/), typeSet);
				result.alias = alias;
			}
			c.intersectionTypes.set(key, result);
		}
		return result;
	}

	// Add the given types to the given type set. Order is preserved, freshness is removed from literal
	// types, duplicates are removed, and nested types of the given kind are flattened into the set.
	static function addTypesToIntersection(c:Checker, typeSet:OrderedSet<Type>, includes:TypeFlags, types:Array<Type>):TypeFlags {
		if (types != null) {
			for (t in types) {
				includes = c.addTypeToIntersection(typeSet, includes, c.getRegularTypeOfLiteralType(t));
			}
		}
		return includes;
	}

	static function addTypeToIntersection(c:Checker, typeSet:OrderedSet<Type>, includes:TypeFlags, t:Type):TypeFlags {
		final flags = t.flags;
		if ((flags & TypeFlagsIntersection) != 0) {
			return c.addTypesToIntersection(typeSet, includes, t.Types());
		}
		if (c.IsEmptyAnonymousObjectType(t)) {
			if ((includes & TypeFlagsIncludesEmptyObject) == 0) {
				includes |= TypeFlagsIncludesEmptyObject;
				typeSet.add(t);
			}
		} else {
			if ((flags & TypeFlagsAnyOrUnknown) != 0) {
				if (t == c.wildcardType) {
					includes |= TypeFlagsIncludesWildcard;
				}
				if (c.isErrorType(t)) {
					includes |= TypeFlagsIncludesError;
				}
			} else if (c.strictNullChecks || (flags & TypeFlagsNullable) == 0) {
				if (t == c.missingType) {
					includes |= TypeFlagsIncludesMissingType;
					t = c.undefinedType;
				}
				if (!typeSet.contains(t)) {
					if ((t.flags & TypeFlagsUnit) != 0 && (includes & TypeFlagsUnit) != 0) {
						// We have seen two distinct unit types which means we should reduce to an
						// empty intersection. Adding TypeFlags.NonPrimitive causes that to happen.
						includes |= TypeFlagsNonPrimitive;
					}
					typeSet.add(t);
				}
			}
			includes |= flags & TypeFlagsIncludesMask;
		}
		return includes;
	}

	static function removeRedundantSupertypes(c:Checker, types:Array<Type>, includes:TypeFlags):Array<Type> {
		var i = Core.len(types);
		while (i > 0) {
			i--;
			final t = types[i];
			final remove = (t.flags & TypeFlagsString) != 0 && (includes & (TypeFlagsStringLiteral | TypeFlagsTemplateLiteral | TypeFlagsStringMapping)) != 0
				|| (t.flags & TypeFlagsNumber) != 0 && (includes & TypeFlagsNumberLiteral) != 0
				|| (t.flags & TypeFlagsBigInt) != 0 && (includes & TypeFlagsBigIntLiteral) != 0
				|| (t.flags & TypeFlagsESSymbol) != 0 && (includes & TypeFlagsUniqueESSymbol) != 0
				|| (t.flags & TypeFlagsVoid) != 0 && (includes & TypeFlagsUndefined) != 0
				|| c.IsEmptyAnonymousObjectType(t) && (includes & TypeFlagsDefinitelyNonNullable) != 0;
			if (remove) {
				// PORT: slices.Delete in place (the slice is owned by the caller's typeSet).
				types.splice(i, 1);
			}
		}
		return types;
	}

	/**
	 * Returns true if the intersection of the template literals and string literals is the empty set,
	 * for example `get${string}` & "setX", and should reduce to never.
	 */
	static function extractRedundantTemplateLiterals(c:Checker, types:Array<Type>):ValueOk<Array<Type>> {
		final literals = Core.Filter(types, (t:Type) -> (t.flags & TypeFlagsStringLiteral) != 0);
		var i = Core.len(types);
		while (i > 0) {
			i--;
			final t = types[i];
			if ((t.flags & (TypeFlagsTemplateLiteral | TypeFlagsStringMapping)) == 0) {
				continue;
			}
			if (literals != null) {
				for (t2 in literals) {
					if (c.isTypeSubtypeOf(t2, t)) {
						// For example, `get${T}` & "getX" is just "getX", and Lowercase<string> & "foo" is just "foo"
						// PORT: slices.Delete in place.
						types.splice(i, 1);
						break;
					}
					if (c.isPatternLiteralType(t)) {
						return new ValueOk<Array<Type>>(types, true);
					}
				}
			}
		}
		return new ValueOk<Array<Type>>(types, false);
	}

	// If the given list of types contains more than one union of primitive types, replace the
	// first with a union containing an intersection of those primitive types, then remove the
	// other unions and return true. Otherwise, do nothing and return false.
	static function intersectUnionsOfPrimitiveTypes(c:Checker, types:Array<Type>):ValueOk<Array<Type>> {
		final index = Core.FindIndex(types, Checker.isPrimitiveUnion);
		if (index < 0) {
			return new ValueOk<Array<Type>>(types, false);
		}
		// Remove all but the first union of primitive types and collect them in
		// the unionTypes array.
		var i = index + 1;
		// PORT: Go `types[index:i:i]` has capacity 1, so the appends below copy; a fresh array here.
		final unionTypes = [types[index]];
		while (i < types.length) {
			final t = types[i];
			if ((t.objectFlags & ObjectFlagsPrimitiveUnion) != 0) {
				unionTypes.push(t);
				// PORT: slices.Delete in place.
				types.splice(i, 1);
			} else {
				i++;
			}
		}
		// Return false if there was only one union of primitive types
		if (unionTypes.length == 1) {
			return new ValueOk<Array<Type>>(types, false);
		}
		// We have more than one union of primitive types, now intersect them. For each
		// type in each union we check if the type is matched in every union and if so
		// we include it in the result.
		var checked:Array<Type> = null;
		var result:Array<Type> = null;
		for (u in unionTypes) {
			for (t in rangeOf(u.Types())) {
				final ins = Checker.insertType(checked, t);
				checked = ins.value;
				if (ins.ok) {
					if (c.eachUnionContains(unionTypes, t)) {
						// undefinedType/missingType are always sorted first so we leverage that here
						if (t == c.undefinedType && Core.len(result) != 0 && result[0] == c.missingType) {
							continue;
						}
						if (t == c.missingType && Core.len(result) != 0 && result[0] == c.undefinedType) {
							result[0] = c.missingType;
							continue;
						}
						result = Checker.insertType(result, t).value;
					}
				}
			}
		}
		// Finally replace the first union with the result
		types[index] = c.getUnionTypeFromSortedList(result, ObjectFlagsPrimitiveUnion, null /*alias*/, null /*origin*/);
		return new ValueOk<Array<Type>>(types, true);
	}

	// Check that the given type has a match in every union. A given type is matched by
	// an identical type, and a literal type is additionally matched by its corresponding
	// primitive type, and missingType is matched by undefinedType (and vice versa).
	static function eachUnionContains(c:Checker, unionTypes:Array<Type>, t:Type):Bool {
		for (u in rangeOf(unionTypes)) {
			final types = u.Types();
			if (!Checker.containsType(types, t)) {
				if (t == c.missingType) {
					return Checker.containsType(types, c.undefinedType);
				}
				if (t == c.undefinedType) {
					return Checker.containsType(types, c.missingType);
				}
				var primitive:Type = null;
				if ((t.flags & TypeFlagsStringLiteral) != 0) {
					primitive = c.stringType;
				} else if ((t.flags & (TypeFlagsEnum | TypeFlagsNumberLiteral)) != 0) {
					primitive = c.numberType;
				} else if ((t.flags & TypeFlagsBigIntLiteral) != 0) {
					primitive = c.bigintType;
				} else if ((t.flags & TypeFlagsUniqueESSymbol) != 0) {
					primitive = c.esSymbolType;
				}
				if (primitive == null || !Checker.containsType(types, primitive)) {
					return false;
				}
			}
		}
		return true;
	}

	static function getCrossProductIntersections(c:Checker, types:Array<Type>, flags:IntersectionFlags):Array<Type> {
		final count = c.getCrossProductUnionSize(types);
		var intersections:Array<Type> = null;
		for (i in 0...count) {
			final constituents = Slices.Clone(types);
			var n = i;
			var j = Core.len(types) - 1;
			while (j >= 0) {
				if ((types[j].flags & TypeFlagsUnion) != 0) {
					final sourceTypes = types[j].Types();
					final length = sourceTypes.length;
					constituents[j] = sourceTypes[n % length];
					n = Std.int(n / length);
				}
				j--;
			}
			final t = c.getIntersectionTypeEx(constituents, flags, null /*alias*/);
			if ((t.flags & TypeFlagsNever) == 0) {
				if (intersections == null) {
					intersections = [];
				}
				intersections.push(t);
			}
		}
		return intersections;
	}

	static function filterTypes(c:Checker, types:Array<Type>, predicate:(Type) -> Bool):Void {
		if (types != null) {
			for (i in 0...types.length) {
				types[i] = c.filterType(types[i], predicate);
			}
		}
	}

	public static function IsEmptyAnonymousObjectType(c:Checker, t:Type):Bool {
		return (t.objectFlags & ObjectFlagsAnonymous) != 0
			&& ((t.objectFlags & ObjectFlagsMembersResolved) != 0 && c.isEmptyResolvedType(t.AsStructuredType())
				|| t.symbol != null && (t.symbol.Flags & SymbolFlagsTypeLiteral) != 0 && symbolTableLen(c.getMembersOfSymbol(t.symbol)) == 0);
	}

	static function isEmptyResolvedType(c:Checker, t:StructuredType):Bool {
		return t.AsType() != c.anyFunctionType && Core.len(t.properties) == 0 && Core.len(t.signatures) == 0 && Core.len(t.indexInfos) == 0;
	}

	static function isEmptyObjectType(c:Checker, t:Type):Bool {
		if ((t.flags & TypeFlagsObject) != 0) {
			return !c.isGenericMappedType(t) && c.isEmptyResolvedType(c.resolveStructuredTypeMembers(t));
		} else if ((t.flags & TypeFlagsNonPrimitive) != 0) {
			return true;
		} else if ((t.flags & TypeFlagsUnion) != 0) {
			return Core.Some(t.Types(), c.isEmptyObjectType);
		} else if ((t.flags & TypeFlagsIntersection) != 0) {
			return Core.Every(t.Types(), c.isEmptyObjectType);
		}
		return false;
	}

	static function isPatternLiteralPlaceholderType(c:Checker, t:Type):Bool {
		if ((t.flags & TypeFlagsIntersection) != 0) {
			// Return true if the intersection consists of one or more placeholders and zero or
			// more object type tags.
			var seenPlaceholder = false;
			for (s in rangeOf(t.Types())) {
				if ((s.flags & (TypeFlagsLiteral | TypeFlagsNullable)) != 0 || c.isPatternLiteralPlaceholderType(s)) {
					seenPlaceholder = true;
				} else if ((s.flags & TypeFlagsObject) == 0) {
					return false;
				}
			}
			return seenPlaceholder;
		}
		return (t.flags & (TypeFlagsAny | TypeFlagsString | TypeFlagsNumber | TypeFlagsBigInt)) != 0 || c.isPatternLiteralType(t);
	}

	static function isPatternLiteralType(c:Checker, t:Type):Bool {
		// A pattern literal type is a template literal or a string mapping type that contains only
		// non-generic pattern literal placeholders.
		return (t.flags & TypeFlagsTemplateLiteral) != 0 && Core.Every(t.AsTemplateLiteralType().types, c.isPatternLiteralPlaceholderType)
			|| (t.flags & TypeFlagsStringMapping) != 0 && c.isPatternLiteralPlaceholderType(t.Target());
	}

	static function isGenericStringLikeType(c:Checker, t:Type):Bool {
		return (t.flags & (TypeFlagsTemplateLiteral | TypeFlagsStringMapping)) != 0 && !c.isPatternLiteralType(t);
	}

	static function filterType(c:Checker, t:Type, f:(Type) -> Bool):Type {
		if ((t.flags & TypeFlagsUnion) != 0) {
			final types = t.Types();
			final filtered = Core.Filter(types, f);
			if (Core.Same(types, filtered)) {
				return t;
			}
			final origin = t.AsUnionType().origin;
			var newOrigin:Type = null;
			if (origin != null && (origin.flags & TypeFlagsUnion) != 0) {
				// If the origin type is a (denormalized) union type, filter its non-union constituents. If that ends
				// up removing a smaller number of types than in the normalized constituent set (meaning some of the
				// filtered types are within nested unions in the origin), then we can't construct a new origin type.
				// Otherwise, if we have exactly one type left in the origin set, return that as the filtered type.
				// Otherwise, construct a new filtered origin type.
				final originTypes = origin.Types();
				final originFiltered = Core.Filter(originTypes, (u:Type) -> (u.flags & TypeFlagsUnion) != 0 || f(u));
				if (Core.len(originTypes) - Core.len(originFiltered) == Core.len(types) - Core.len(filtered)) {
					if (Core.len(originFiltered) == 1) {
						return originFiltered[0];
					}
					newOrigin = c.newUnionType(ObjectFlagsNone, originFiltered);
				}
			}
			// filtering could remove intersections so `ContainsIntersections` might be forwarded "incorrectly"
			// it is purely an optimization hint so there is no harm in accidentally forwarding it
			return c.getUnionTypeFromSortedList(filtered, t.AsUnionType().objectFlags & (ObjectFlagsPrimitiveUnion | ObjectFlagsContainsIntersections), null /*alias*/, newOrigin);
		}
		if ((t.flags & TypeFlagsNever) != 0 || f(t)) {
			return t;
		}
		return c.neverType;
	}

	static function removeType(c:Checker, t:Type, targetType:Type):Type {
		return c.filterType(t, (t:Type) -> t != targetType);
	}

	static function isErrorType(c:Checker, t:Type):Bool {
		// The only 'any' types that have alias symbols are those manufactured by getTypeFromTypeAliasReference for
		// a reference to an unresolved symbol. We want those to behave like the errorType.
		return t == c.errorType || (t.flags & TypeFlagsAny) != 0 && t.alias != null;
	}

	static function checkCrossProductUnion(c:Checker, types:Array<Type>):Bool {
		final size = c.getCrossProductUnionSize(types);
		if (size >= 100000) {
			final tr = c.tracer;
			if (tr != null) {
				final args = new StringMap<Any>();
				args.set("size", size);
				tr.Instant(PhaseCheckTypes, "checkCrossProductUnion_DepthLimit", args);
			}
			c.error(c.currentNode, Diagnostics.Expression_produces_a_union_type_that_is_too_complex_to_represent);
			return false;
		}
		return true;
	}

	static function getCrossProductUnionSize(c:Checker, types:Array<Type>):Int {
		var size = 1;
		for (t in rangeOf(types)) {
			if ((t.flags & TypeFlagsUnion) != 0) {
				final n = t.Types().length;
				// Cap the result to avoid integer overflow when computing the cross product of many large unions.
				// In TypeScript, number overflow produces Infinity which naturally exceeds the limit check;
				// in Go, we must guard against int wrapping to zero or negative.
				// PORT: Go math.MaxInt is 64-bit; Int is 32-bit here (PORTING.md §3). Any capped size exceeds the 100,000 limit either way.
				if (n > 0 && size > Std.int(MAX_INT / n)) {
					return MAX_INT;
				}
				size *= n;
			} else if ((t.flags & TypeFlagsNever) != 0) {
				return 0;
			}
		}
		return size;
	}

	static function getIndexType(c:Checker, t:Type):Type {
		return c.getIndexTypeEx(t, IndexFlagsNone);
	}

	static function getIndexTypeEx(c:Checker, t:Type, indexFlags:IndexFlags):Type {
		t = c.getReducedType(t);
		if (c.isNoInferType(t)) {
			return c.getNoInferType(c.getIndexTypeEx(t.AsSubstitutionType().baseType, indexFlags));
		} else if (c.shouldDeferIndexType(t, indexFlags)) {
			return c.getIndexTypeForGenericType(t, indexFlags);
		} else if ((t.flags & TypeFlagsUnion) != 0) {
			return c.getIntersectionType(Core.Map(t.Types(), (t:Type) -> c.getIndexTypeEx(t, indexFlags)));
		} else if ((t.flags & TypeFlagsIntersection) != 0) {
			return c.getUnionType(Core.Map(t.Types(), (t:Type) -> c.getIndexTypeEx(t, indexFlags)));
		} else if ((t.objectFlags & ObjectFlagsMapped) != 0) {
			return c.getIndexTypeForMappedType(t, indexFlags);
		} else if (t == c.wildcardType) {
			return c.wildcardType;
		} else if ((t.flags & TypeFlagsUnknown) != 0) {
			return c.neverType;
		} else if ((t.flags & (TypeFlagsAny | TypeFlagsNever)) != 0) {
			return c.stringNumberSymbolType;
		}
		final include:TypeFlags = (Core.IfElse((indexFlags & IndexFlagsNoIndexSignatures) != 0, TypeFlagsStringLiteral, TypeFlagsStringLike) : TypeFlags)
			| (Core.IfElse((indexFlags & IndexFlagsStringsOnly) != 0, TypeFlagsNone, TypeFlagsNumberLike | TypeFlagsESSymbolLike) : TypeFlags);
		return c.getLiteralTypeFromProperties(t, include, indexFlags == IndexFlagsNone);
	}

	static function getExtractStringType(c:Checker, t:Type):Type {
		final extractTypeAlias = c.getGlobalExtractSymbol();
		if (extractTypeAlias != null) {
			return c.getTypeAliasInstantiation(extractTypeAlias, [t, c.stringType], null);
		}
		return c.stringType;
	}

	static function getLiteralTypeFromProperties(c:Checker, t:Type, include:TypeFlags, includeOrigin:Bool):Type {
		final key = PropertiesTypesKey.keyOf(t.id, include, includeOrigin, (t.objectFlags & ObjectFlagsUnresolvedMembers) != 0);
		if (c.propertiesTypes.exists(key)) {
			return c.propertiesTypes.get(key);
		}
		var origin:Type = null;
		if (includeOrigin && (t.objectFlags & (ObjectFlagsClassOrInterface | ObjectFlagsReference)) != 0 || t.alias != null) {
			origin = c.newIndexType(t, IndexFlagsNone);
		}
		final props = c.getPropertiesOfType(t);
		final indexInfos = c.getIndexInfosOfType(t);
		final types:Array<Type> = [];
		for (prop in rangeOf(props)) {
			types.push(c.getLiteralTypeFromProperty(prop, include, false));
		}
		for (info in rangeOf(indexInfos)) {
			if (info != c.enumNumberIndexInfo && c.isKeyTypeIncluded(info.keyType, include)) {
				if (info.keyType == c.stringType && (include & TypeFlagsNumber) != 0) {
					types.push(c.stringOrNumberType);
				} else {
					types.push(info.keyType);
				}
			}
		}
		final result = c.getUnionTypeEx(types, UnionReductionLiteral, null, origin);
		c.propertiesTypes.set(key, result);
		return result;
	}

	static function getLiteralTypeFromProperty(c:Checker, prop:Symbol, include:TypeFlags, includeNonPublic:Bool):Type {
		if (includeNonPublic || (Checker.getDeclarationModifierFlagsFromSymbol(prop) & ModifierFlagsNonPublicAccessibilityModifier) == 0) {
			var t = c.valueSymbolLinks.Get(c.getLateBoundSymbol(prop)).nameType;
			if (t == null) {
				if (prop.Name == Ast.InternalSymbolNameDefault) {
					t = c.getStringLiteralType("default");
				} else {
					final name = Ast.GetNameOfDeclaration(prop.ValueDeclaration);
					if (name != null) {
						t = c.getLiteralTypeFromPropertyName(name);
					}
					if (t == null && !Checker.IsKnownSymbol(prop)) {
						t = c.getStringLiteralType(Ast.SymbolName(prop));
					}
				}
			}
			if (t != null && (t.flags & include) != 0) {
				return t;
			}
		}
		return c.neverType;
	}

	static function getLiteralTypeFromPropertyName(c:Checker, name:Node):Type {
		if (Ast.IsPrivateIdentifier(name)) {
			return c.neverType;
		}
		if (Ast.IsNumericLiteral(name)) {
			return c.getRegularTypeOfLiteralType(c.checkExpression(name));
		}
		if (Ast.IsComputedPropertyName(name)) {
			return c.getRegularTypeOfLiteralType(c.checkComputedPropertyName(name));
		}
		final propertyName = Ast.GetPropertyNameForPropertyNameNode(name);
		if (propertyName != Ast.InternalSymbolNameMissing) {
			return c.getStringLiteralType(propertyName);
		}
		if (Ast.IsExpression(name)) {
			return c.getRegularTypeOfLiteralType(c.checkExpression(name));
		}
		return c.neverType;
	}

	static function isKeyTypeIncluded(c:Checker, keyType:Type, include:TypeFlags):Bool {
		return (keyType.flags & include) != 0
			|| (keyType.flags & TypeFlagsIntersection) != 0 && Core.Some(keyType.Types(), (t:Type) -> c.isKeyTypeIncluded(t, include));
	}

	static function checkComputedPropertyName(c:Checker, node:Node):Type {
		final links = c.typeNodeLinks.Get(node.Expression());
		if (links.resolvedType == null) {
			if ((Ast.IsTypeLiteralNode(node.Parent.Parent) || Ast.IsClassLike(node.Parent.Parent) || Ast.IsInterfaceDeclaration(node.Parent.Parent))
				&& Ast.IsBinaryExpression(node.Expression()) && node.Expression().AsBinaryExpression().OperatorToken.Kind == KindInKeyword
				&& !Ast.IsAccessor(node.Parent)) {
				links.resolvedType = c.errorType;
				return links.resolvedType;
			}
			links.resolvedType = c.checkExpression(node.Expression());
			// This will allow types number, string, symbol or any. It will also allow enums, the unknown
			// type, and any union of these types (like string | number).
			if ((links.resolvedType.flags & TypeFlagsNullable) != 0
				|| !c.isTypeAssignableToKind(links.resolvedType, TypeFlagsStringLike | TypeFlagsNumberLike | TypeFlagsESSymbolLike)
				&& !c.isTypeAssignableTo(links.resolvedType, c.stringNumberSymbolType)) {
				c.error(node, Diagnostics.A_computed_property_name_must_be_of_type_string_number_symbol_or_any);
			}
		}
		return links.resolvedType;
	}

	static function isNoInferType(c:Checker, t:Type):Bool {
		// A NoInfer<T> type is represented as a substitution type with a TypeFlags.Unknown constraint.
		return (t.flags & TypeFlagsSubstitution) != 0 && (t.AsSubstitutionType().constraint.flags & TypeFlagsUnknown) != 0;
	}

	static function getSubstitutionIntersection(c:Checker, t:Type):Type {
		if (c.isNoInferType(t)) {
			return t.AsSubstitutionType().baseType;
		}
		return c.getIntersectionType([t.AsSubstitutionType().constraint, t.AsSubstitutionType().baseType]);
	}

	static function shouldDeferIndexType(c:Checker, t:Type, indexFlags:IndexFlags):Bool {
		return (t.flags & TypeFlagsInstantiableNonPrimitive) != 0
			|| c.isGenericTupleType(t)
			|| c.isGenericMappedType(t) && c.getNameTypeFromMappedType(t) != null
			|| (t.flags & TypeFlagsUnion) != 0 && (indexFlags & IndexFlagsNoReducibleCheck) == 0 && c.isGenericReducibleType(t)
			|| (t.flags & TypeFlagsIntersection) != 0 && c.maybeTypeOfKind(t, TypeFlagsInstantiable) && Core.Some(t.Types(), c.IsEmptyAnonymousObjectType);
	}

	static function getMappedTypeNameTypeKind(c:Checker, t:Type):MappedTypeNameTypeKind {
		final nameType = c.getNameTypeFromMappedType(t);
		if (nameType == null) {
			return MappedTypeNameTypeKindNone;
		}
		if (c.isTypeAssignableTo(nameType, c.getTypeParameterFromMappedType(t))) {
			return MappedTypeNameTypeKindFiltering;
		}
		return MappedTypeNameTypeKindRemapping;
	}

	static function getIndexTypeForGenericType(c:Checker, t:Type, indexFlags:IndexFlags):Type {
		final key = CachedTypeKey.keyOf(Core.IfElse((indexFlags & IndexFlagsStringsOnly) != 0, CachedTypeKindStringIndexType, CachedTypeKindIndexType), t.id);
		final cached = c.cachedTypes.get(key);
		if (cached != null) {
			return cached;
		}
		final indexType = c.newIndexType(t, indexFlags & IndexFlagsStringsOnly);
		c.cachedTypes.set(key, indexType);
		return indexType;
	}

	// This roughly mirrors `resolveMappedTypeMembers` in the nongeneric case, except only reports a union of the keys calculated,
	// rather than manufacturing the properties. We can't just fetch the `constraintType` since that would ignore mappings
	// and mapping the `constraintType` directly ignores how mapped types map _properties_ and not keys (thus ignoring subtype
	// reduction in the constraintType) when possible.
	// @param noIndexSignatures Indicates if _string_ index signatures should be elided. (other index signatures are always reported)
	static function getIndexTypeForMappedType(c:Checker, t:Type, indexFlags:IndexFlags):Type {
		final typeParameter = c.getTypeParameterFromMappedType(t);
		final constraintType = c.getConstraintTypeFromMappedType(t);
		final nameType = c.getNameTypeFromMappedType(Core.OrElse(t.AsMappedType().target, t));
		if (nameType == null && (indexFlags & IndexFlagsNoIndexSignatures) == 0) {
			// no mapping and no filtering required, just quickly bail to returning the constraint in the common case
			return constraintType;
		}
		var keyTypes:Array<Type> = null;
		final addMemberForKeyType = (keyType:Type) -> {
			var propNameType = keyType;
			if (nameType != null) {
				propNameType = c.instantiateType(nameType, Checker.appendTypeMapping(t.AsMappedType().mapper, typeParameter, keyType));
			}
			// `keyof` currently always returns `string | number` for concrete `string` index signatures - the below ternary keeps that behavior for mapped types
			// See `getLiteralTypeFromProperties` where there's a similar ternary to cause the same behavior.
			if (keyTypes == null) {
				keyTypes = [];
			}
			keyTypes.push(Core.IfElse(propNameType == c.stringType, c.stringOrNumberType, propNameType));
		};
		// Calling getApparentType on the `T` of a `keyof T` in the constraint type of a generic mapped type can
		// trigger a circularity. For example, `T extends { [P in keyof T & string as Captitalize<P>]: any }` is
		// a circular definition. For this reason, we only eagerly manifest the keys if the constraint is non-generic.
		if (c.isGenericIndexType(constraintType)) {
			if (c.isMappedTypeWithKeyofConstraintDeclaration(t)) {
				// We have a generic index and a homomorphic mapping and a key remapping - we need to defer
				// the whole `keyof whatever` for later since it's not safe to resolve the shape of modifier type.
				return c.getIndexTypeForGenericType(t, indexFlags);
			}
			// Include the generic component in the resulting type.
			Checker.forEachType(constraintType, addMemberForKeyType);
		} else if (c.isMappedTypeWithKeyofConstraintDeclaration(t)) {
			final modifiersType = c.getApparentType(c.getModifiersTypeFromMappedType(t));
			// The 'T' in 'keyof T'
			c.forEachMappedTypePropertyKeyTypeAndIndexSignatureKeyType(modifiersType, TypeFlagsStringOrNumberLiteralOrUnique, (indexFlags & IndexFlagsStringsOnly) != 0, addMemberForKeyType);
		} else {
			Checker.forEachType(c.getLowerBoundOfKeyType(constraintType), addMemberForKeyType);
		}
		// We had to pick apart the constraintType to potentially map/filter it - compare the final resulting list with the
		// original constraintType, so we can return the union that preserves aliases/origin data if possible.
		var result:Type;
		if ((indexFlags & IndexFlagsNoIndexSignatures) != 0) {
			result = c.filterType(c.getUnionType(keyTypes), (t:Type) -> (t.flags & (TypeFlagsAny | TypeFlagsString)) == 0);
		} else {
			result = c.getUnionType(keyTypes);
		}
		if ((result.flags & TypeFlagsUnion) != 0 && (constraintType.flags & TypeFlagsUnion) != 0
			&& Checker.getTypeListKey(result.Types()).Key() == Checker.getTypeListKey(constraintType.Types()).Key()) {
			return constraintType;
		}
		return result;
	}

	static function getIndexedAccessType(c:Checker, objectType:Type, indexType:Type):Type {
		return c.getIndexedAccessTypeEx(objectType, indexType, AccessFlagsNone, null, null);
	}

	static function getIndexedAccessTypeEx(c:Checker, objectType:Type, indexType:Type, accessFlags:AccessFlags, accessNode:Node, alias:TypeAlias):Type {
		var result = c.getIndexedAccessTypeOrUndefined(objectType, indexType, accessFlags, accessNode, alias);
		if (result == null) {
			result = Core.IfElse(accessNode != null, c.errorType, c.unknownType);
		}
		return result;
	}

	static function getIndexedAccessTypeOrUndefined(c:Checker, objectType:Type, indexType:Type, accessFlags:AccessFlags, accessNode:Node, alias:TypeAlias):Type {
		if (objectType == c.wildcardType || indexType == c.wildcardType) {
			return c.wildcardType;
		}
		objectType = c.getReducedType(objectType);
		// If the object type has a string index signature and no other members we know that the result will
		// always be the type of that index signature and we can simplify accordingly.
		if (c.isStringIndexSignatureOnlyType(objectType) && (indexType.flags & TypeFlagsNullable) == 0 && c.isTypeAssignableToKind(indexType, TypeFlagsString | TypeFlagsNumber)) {
			indexType = c.stringType;
		}
		// In noUncheckedIndexedAccess mode, indexed access operations that occur in an expression in a read position and resolve to
		// an index signature have 'undefined' included in their type.
		if (c.compilerOptions.NoUncheckedIndexedAccess == TSTrue && (accessFlags & AccessFlagsExpressionPosition) != 0) {
			accessFlags |= AccessFlagsIncludeUndefined;
		}
		// If the index type is generic, or if the object type is generic and doesn't originate in an expression and
		// the operation isn't exclusively indexing the fixed (non-variadic) portion of a tuple type, we are performing
		// a higher-order index access where we cannot meaningfully access the properties of the object type. Note that
		// for a generic T and a non-generic K, we eagerly resolve T[K] if it originates in an expression. This is to
		// preserve backwards compatibility. For example, an element access 'this["foo"]' has always been resolved
		// eagerly using the constraint type of 'this' at the given location.
		if (c.shouldDeferIndexedAccessType(objectType, indexType, accessNode)) {
			if ((objectType.flags & TypeFlagsAnyOrUnknown) != 0) {
				return objectType;
			}
			// Defer the operation by creating an indexed access type.
			final persistentAccessFlags = accessFlags & AccessFlagsPersistent;
			final key = Checker.getIndexedAccessKey(objectType, indexType, accessFlags, alias).Key();
			var t = c.indexedAccessTypes.get(key);
			if (t == null) {
				t = c.newIndexedAccessType(objectType, indexType, persistentAccessFlags);
				t.alias = alias;
				c.indexedAccessTypes.set(key, t);
			}
			return t;
		}
		// In the following we resolve T[K] to the type of the property in T selected by K.
		// We treat boolean as different from other unions to improve errors;
		// skipping straight to getPropertyTypeForIndexType gives errors with 'boolean' instead of 'true'.
		final apparentObjectType = c.getReducedApparentType(objectType);
		if ((indexType.flags & TypeFlagsUnion) != 0 && (indexType.flags & TypeFlagsBoolean) == 0) {
			var propTypes:Array<Type> = null;
			var wasMissingProp = false;
			for (t in rangeOf(indexType.Types())) {
				final propType = c.getPropertyTypeForIndexType(objectType, apparentObjectType, t, indexType, accessNode,
					accessFlags | (Core.IfElse(wasMissingProp, AccessFlagsSuppressNoImplicitAnyError, 0) : AccessFlags));
				if (propType != null) {
					if (propTypes == null) {
						propTypes = [];
					}
					propTypes.push(propType);
				} else if (accessNode == null) {
					// If there's no error node, we can immediately stop, since error reporting is off
					return null;
				} else {
					// Otherwise we set a flag and return at the end of the loop so we still mark all errors
					wasMissingProp = true;
				}
			}
			if (wasMissingProp) {
				return null;
			}
			if ((accessFlags & AccessFlagsWriting) != 0) {
				return c.getIntersectionTypeEx(propTypes, IntersectionFlagsNone, alias);
			}
			return c.getUnionTypeEx(propTypes, UnionReductionLiteral, alias, null);
		}
		return c.getPropertyTypeForIndexType(objectType, apparentObjectType, indexType, indexType, accessNode, accessFlags | AccessFlagsCacheSymbol | AccessFlagsReportDeprecated);
	}

	static function getPropertyTypeForIndexType(c:Checker, originalObjectType:Type, objectType:Type, indexType:Type, fullIndexType:Type, accessNode:Node, accessFlags:AccessFlags):Type {
		var accessExpression:Node = null;
		if (accessNode != null && Ast.IsElementAccessExpression(accessNode)) {
			accessExpression = accessNode;
		}
		var propName = "";
		var hasPropName = false;
		if (!(accessNode != null && Ast.IsPrivateIdentifier(accessNode))) {
			propName = c.getPropertyNameFromIndex(indexType, accessNode);
			hasPropName = propName != Ast.InternalSymbolNameMissing;
		}
		if (hasPropName) {
			if (accessFlags & AccessFlagsContextual != 0) {
				var t = c.getTypeOfPropertyOfContextualType(objectType, propName);
				if (t == null) {
					t = c.anyType;
				}
				return t;
			}
			final prop = c.getPropertyOfType(objectType, propName);
			if (prop != null) {
				if (accessFlags & AccessFlagsReportDeprecated != 0 && accessNode != null && Core.len(prop.Declarations) != 0 && c.isDeprecatedSymbol(prop)
					&& c.isUncalledFunctionReference(accessNode, prop)) {
					var deprecatedNode:Node = null;
					if (accessExpression != null) {
						deprecatedNode = accessExpression.AsElementAccessExpression().ArgumentExpression;
					} else if (Ast.IsIndexedAccessTypeNode(accessNode)) {
						deprecatedNode = accessNode.AsIndexedAccessTypeNode().IndexType;
					} else {
						deprecatedNode = accessNode;
					}
					c.addDeprecatedSuggestion(deprecatedNode, prop.Declarations, propName);
				}
				if (accessExpression != null) {
					c.markPropertyAsReferenced(prop, accessExpression, c.isSelfTypeAccess(accessExpression.Expression(), objectType.symbol));
					if (c.isAssignmentToReadonlyEntity(accessExpression, prop, Checker.getAssignmentTargetKind(accessExpression))) {
						c.error(accessExpression.AsElementAccessExpression().ArgumentExpression, Diagnostics.Cannot_assign_to_0_because_it_is_a_read_only_property,
							c.symbolToString(prop));
						return null;
					}
					if (accessFlags & AccessFlagsCacheSymbol != 0) {
						c.symbolNodeLinks.Get(accessNode).resolvedSymbol = prop;
					}
					if (c.isThisPropertyAccessInConstructor(accessExpression, prop)) {
						return c.autoType;
					}
				}
				var propType:Type = null;
				if (accessFlags & AccessFlagsWriting != 0) {
					propType = c.getWriteTypeOfSymbol(prop);
				} else {
					propType = c.getTypeOfSymbol(prop);
				}
				if (accessExpression != null && Checker.getAssignmentTargetKind(accessExpression) != AssignmentKindDefinite) {
					return c.getFlowTypeOfReference(accessExpression, propType);
				} else if (accessNode != null && Ast.IsIndexedAccessTypeNode(accessNode) && c.containsMissingType(propType)) {
					return c.getUnionType([propType, c.undefinedType]);
				} else {
					return propType;
				}
			}
			if (Checker.everyType(objectType, Checker.isTupleType) && Checker.isNumericLiteralName(propName)) {
				final index:Number = Jsnum.FromString(propName);
				if (accessNode != null && Checker.everyType(objectType, (t:Type) -> {
					return t.TargetTupleType().combinedFlags & ElementFlagsVariable == 0;
				}) && accessFlags & AccessFlagsAllowMissing == 0) {
					final indexNode = Checker.getIndexNodeForAccessExpression(accessNode);
					if (Checker.isTupleType(objectType)) {
						if (index < 0) {
							c.error(indexNode, Diagnostics.A_tuple_type_cannot_be_indexed_with_a_negative_value);
							return c.undefinedType;
						}
						c.error(indexNode, Diagnostics.Tuple_type_0_of_length_1_has_no_element_at_index_2, c.TypeToString(objectType), c.getTypeReferenceArity(objectType),
							propName);
					} else {
						c.error(indexNode, Diagnostics.Property_0_does_not_exist_on_type_1, propName, c.TypeToString(objectType));
					}
				}
				if (index >= 0) {
					c.errorIfWritingToReadonlyIndex(c.getIndexInfoOfType(objectType, c.numberType), objectType, accessExpression);
					return c.getTupleElementTypeOutOfStartCount(objectType, index, Core.IfElse(accessFlags & AccessFlagsIncludeUndefined != 0, c.missingType, null));
				}
			}
		}
		if (indexType.flags & TypeFlagsNullable == 0 && c.isTypeAssignableToKind(indexType, TypeFlagsStringLike | TypeFlagsNumberLike | TypeFlagsESSymbolLike)) {
			if (objectType.flags & (TypeFlagsAny | TypeFlagsNever) != 0) {
				return objectType;
			}
			// If no index signature is applicable, we default to the string index signature. In effect, this means the string
			// index signature applies even when accessing with a symbol-like type.
			var indexInfo = c.getApplicableIndexInfo(objectType, indexType);
			if (indexInfo == null) {
				indexInfo = c.getIndexInfoOfType(objectType, c.stringType);
			}
			if (indexInfo != null) {
				if (accessFlags & AccessFlagsNoIndexSignatures != 0 && indexInfo.keyType != c.numberType) {
					if (accessExpression != null) {
						if (accessFlags & AccessFlagsWriting != 0) {
							c.error(accessExpression, Diagnostics.Type_0_is_generic_and_can_only_be_indexed_for_reading, c.TypeToString(originalObjectType));
						} else {
							c.error(accessExpression, Diagnostics.Type_0_cannot_be_used_to_index_type_1, c.TypeToString(indexType), c.TypeToString(originalObjectType));
						}
					}
					return null;
				}
				if (accessNode != null && indexInfo.keyType == c.stringType && !c.isTypeAssignableToKind(indexType, TypeFlagsString | TypeFlagsNumber)) {
					final indexNode = Checker.getIndexNodeForAccessExpression(accessNode);
					c.error(indexNode, Diagnostics.Type_0_cannot_be_used_as_an_index_type, c.TypeToString(indexType));
					if (accessFlags & AccessFlagsIncludeUndefined != 0) {
						return c.getUnionType([indexInfo.valueType, c.missingType]);
					} else {
						return indexInfo.valueType;
					}
				}
				c.errorIfWritingToReadonlyIndex(indexInfo, objectType, accessExpression);
				// When accessing an enum object with its own type,
				// e.g. E[E.A] for enum E { A }, undefined shouldn't
				// be included in the result type
				if (accessFlags & AccessFlagsIncludeUndefined != 0
					&& !(objectType.symbol != null
						&& objectType.symbol.Flags & (SymbolFlagsRegularEnum | SymbolFlagsConstEnum) != 0
						&& (indexType.symbol != null
							&& indexType.flags & TypeFlagsEnumLiteral != 0
							&& c.getParentOfSymbol(indexType.symbol) == objectType.symbol))) {
					return c.getUnionType([indexInfo.valueType, c.missingType]);
				}
				return indexInfo.valueType;
			}
			if (indexType.flags & TypeFlagsNever != 0) {
				return c.neverType;
			}
			if (c.isJSLiteralType(objectType)) {
				return c.anyType;
			}
			if (accessExpression != null && !Checker.isConstEnumObjectType(objectType)) {
				if (Checker.isObjectLiteralType(objectType)) {
					if (c.noImplicitAny && indexType.flags & (TypeFlagsStringLiteral | TypeFlagsNumberLiteral) != 0) {
						c.addDiagnostic(Checker.createDiagnosticForNode(accessExpression, Diagnostics.Property_0_does_not_exist_on_type_1, indexType.AsLiteralType().value,
							c.TypeToString(objectType)));
						return c.undefinedType;
					} else if (indexType.flags & (TypeFlagsNumber | TypeFlagsString) != 0) {
						final types:Array<Type> = [];
						for (prop in rangeOf(objectType.AsStructuredType().properties)) {
							types.push(c.getTypeOfSymbol(prop));
						}
						types.push(c.undefinedType);
						return c.getUnionType(types);
					}
				}
				if (objectType.symbol == c.globalThisSymbol && hasPropName && symbolTableGet(c.globalThisSymbol.Exports, propName) != null
					&& symbolTableGet(c.globalThisSymbol.Exports, propName).Flags & SymbolFlagsBlockScoped != 0) {
					c.error(accessExpression, Diagnostics.Property_0_does_not_exist_on_type_1, propName, c.TypeToString(objectType));
				} else if (c.noImplicitAny && accessFlags & AccessFlagsSuppressNoImplicitAnyError == 0) {
					if (hasPropName && c.typeHasStaticProperty(propName, objectType)) {
						final typeName = c.TypeToString(objectType);
						c.error(accessExpression, Diagnostics.Property_0_does_not_exist_on_type_1_Did_you_mean_to_access_the_static_member_2_instead, propName /* as string */,
							typeName, typeName + "[" + Scanner.GetTextOfNode(accessExpression.AsElementAccessExpression().ArgumentExpression) + "]");
					} else if (c.getIndexTypeOfType(objectType, c.numberType) != null) {
						c.error(accessExpression.AsElementAccessExpression().ArgumentExpression,
							Diagnostics.Element_implicitly_has_an_any_type_because_index_expression_is_not_of_type_number);
					} else {
						var suggestion = "";
						if (hasPropName) {
							suggestion = c.getSuggestionForNonexistentProperty(propName, objectType);
						}
						if (suggestion != "") {
							c.error(accessExpression.AsElementAccessExpression().ArgumentExpression, Diagnostics.Property_0_does_not_exist_on_type_1_Did_you_mean_2,
								propName /* as string */, c.TypeToString(objectType), suggestion);
						} else {
							suggestion = c.getSuggestionForNonexistentIndexSignature(objectType, accessExpression, indexType);
							if (suggestion != "") {
								c.error(accessExpression, Diagnostics.Element_implicitly_has_an_any_type_because_type_0_has_no_index_signature_Did_you_mean_to_call_1,
									c.TypeToString(objectType), suggestion);
							} else {
								var diagnostic:Diagnostic = null;
								if (indexType.flags & TypeFlagsEnumLiteral != 0) {
									diagnostic = Checker.NewDiagnosticForNode(accessExpression, Diagnostics.Property_0_does_not_exist_on_type_1,
										"[" + c.TypeToString(indexType) + "]", c.TypeToString(objectType));
								} else if (indexType.flags & TypeFlagsUniqueESSymbol != 0) {
									final symbolName = c.getFullyQualifiedName(indexType.symbol, accessExpression);
									diagnostic = Checker.NewDiagnosticForNode(accessExpression, Diagnostics.Property_0_does_not_exist_on_type_1, "[" + symbolName + "]",
										c.TypeToString(objectType));
								} else if (indexType.flags & TypeFlagsStringLiteral != 0) {
									diagnostic = Checker.NewDiagnosticForNode(accessExpression, Diagnostics.Property_0_does_not_exist_on_type_1,
										indexType.AsLiteralType().value, c.TypeToString(objectType));
								} else if (indexType.flags & TypeFlagsNumberLiteral != 0) {
									diagnostic = Checker.NewDiagnosticForNode(accessExpression, Diagnostics.Property_0_does_not_exist_on_type_1,
										indexType.AsLiteralType().value, c.TypeToString(objectType));
								} else if (indexType.flags & (TypeFlagsNumber | TypeFlagsString) != 0) {
									diagnostic = Checker.NewDiagnosticForNode(accessExpression, Diagnostics.No_index_signature_with_a_parameter_of_type_0_was_found_on_type_1,
										c.TypeToString(indexType), c.TypeToString(objectType));
								}
								c.addDiagnostic(Checker.NewDiagnosticChainForNode(diagnostic, accessExpression,
									Diagnostics.Element_implicitly_has_an_any_type_because_expression_of_type_0_can_t_be_used_to_index_type_1, c.TypeToString(fullIndexType),
									c.TypeToString(objectType)));
							}
						}
					}
				}
				return null;
			}
		}
		if (accessFlags & AccessFlagsAllowMissing != 0 && Checker.isObjectLiteralType(objectType)) {
			return c.undefinedType;
		}
		if (c.isJSLiteralType(objectType)) {
			return c.anyType;
		}
		if (accessNode != null) {
			final indexNode = Checker.getIndexNodeForAccessExpression(accessNode);
			if (indexNode.Kind != KindBigIntLiteral && indexType.flags & (TypeFlagsStringLiteral | TypeFlagsNumberLiteral) != 0) {
				c.error(indexNode, Diagnostics.Property_0_does_not_exist_on_type_1, indexType.AsLiteralType().value, c.TypeToString(objectType));
			} else if (indexType.flags & (TypeFlagsString | TypeFlagsNumber) != 0) {
				c.error(indexNode, Diagnostics.Type_0_has_no_matching_index_signature_for_type_1, c.TypeToString(objectType), c.TypeToString(indexType));
			} else {
				var typeString = "";
				if (indexNode.Kind == KindBigIntLiteral) {
					typeString = "bigint";
				} else {
					typeString = c.TypeToString(indexType);
				}
				c.error(indexNode, Diagnostics.Type_0_cannot_be_used_as_an_index_type, typeString);
			}
		}
		if (Checker.IsTypeAny(indexType)) {
			return indexType;
		}
		return null;
	}

	static function typeHasStaticProperty(c:Checker, propName:std.String, containingType:Type):Bool {
		if (containingType.symbol != null) {
			final prop = c.getPropertyOfType(c.getTypeOfSymbol(containingType.symbol), propName);
			return prop != null && prop.ValueDeclaration != null && Ast.IsStatic(prop.ValueDeclaration);
		}
		return false;
	}

	static function getSuggestionForNonexistentProperty(c:Checker, name:std.String, containingType:Type):std.String {
		final symbol = c.getSpellingSuggestionForName(name, valuesOf(c.getPropertiesOfType(containingType)), SymbolFlagsValue);
		if (symbol != null) {
			return symbol.Name;
		}
		return "";
	}

	static function getSuggestionForNonexistentIndexSignature(c:Checker, objectType:Type, expr:Node, keyedType:Type):std.String {
		// check if object type has setter or getter
		final hasProp = (name:std.String) -> {
			final prop = c.getPropertyOfObjectType(objectType, name);
			if (prop != null) {
				final s = c.getSingleCallSignature(c.getTypeOfSymbol(prop));
				return s != null && c.getMinArgumentCount(s) >= 1 && c.isTypeAssignableTo(keyedType, c.getTypeAtPosition(s, 0));
			}
			return false;
		};
		final suggestedMethod = Core.IfElse(Ast.IsAssignmentTarget(expr), "set", "get");
		if (!hasProp(suggestedMethod)) {
			return "";
		}
		final suggestion = Checker.tryGetPropertyAccessOrIdentifierToString(expr.Expression());
		if (suggestion == "") {
			return suggestedMethod;
		}
		return suggestion + "." + suggestedMethod;
	}

	static function getSuggestedTypeForNonexistentStringLiteralType(c:Checker, source:Type, target:Type):Type {
		final candidates = Core.FilterSeq(target.Types(), (t:Type) -> t.flags & TypeFlagsStringLiteral != 0);
		return Core.GetSpellingSuggestion(Checker.getStringLiteralValue(source), candidates, Checker.getStringLiteralValue, Checker.CompareTypes);
	}

	static function errorIfWritingToReadonlyIndex(c:Checker, indexInfo:IndexInfo, objectType:Type, accessExpression:Node):Void {
		if (indexInfo != null && indexInfo.isReadonly && accessExpression != null
			&& (Ast.IsAssignmentTarget(accessExpression) || Checker.isDeleteTarget(accessExpression))) {
			c.error(accessExpression, Diagnostics.Index_signature_in_type_0_only_permits_reading, c.TypeToString(objectType));
		}
	}

	static function isSelfTypeAccess(c:Checker, name:Node, parent:Symbol):Bool {
		return name.Kind == KindThisKeyword
			|| parent != null && Ast.IsEntityNameExpression(name) && parent == c.getResolvedSymbol(Ast.GetFirstIdentifier(name));
	}

	static function isAssignmentToReadonlyEntity(c:Checker, expr:Node, symbol:Symbol, assignmentKind:AssignmentKind):Bool {
		if (assignmentKind == AssignmentKindNone) {
			// no assignment means it doesn't matter whether the entity is readonly
			return false;
		}
		if (Ast.IsAccessExpression(expr)) {
			final node = Ast.SkipParentheses(expr.Expression());
			if (Ast.IsIdentifier(node)) {
				final expressionSymbol = c.getResolvedSymbol(node);
				// CommonJS module.exports is never readonly
				if (expressionSymbol.Flags & SymbolFlagsModuleExports != 0) {
					return false;
				}
			}
		}
		if (c.isReadonlySymbol(symbol)) {
			// Allow assignments to readonly properties within constructors of the same class declaration.
			if (symbol.Flags & SymbolFlagsProperty != 0 && Ast.IsAccessExpression(expr) && expr.Expression().Kind == KindThisKeyword) {
				// Look for if this is the constructor for the class that `symbol` is a property of.
				final ctor = c.getControlFlowContainer(expr);
				if (ctor == null || !Ast.IsConstructorDeclaration(ctor)) {
					return true;
				}
				if (symbol.ValueDeclaration != null) {
					final isAssignmentDeclaration = Ast.IsBinaryExpression(symbol.ValueDeclaration);
					final isLocalPropertyDeclaration = ctor.Parent == symbol.ValueDeclaration.Parent;
					final isLocalParameterProperty = ctor == symbol.ValueDeclaration.Parent;
					final isLocalThisPropertyAssignment = isAssignmentDeclaration && symbol.Parent.ValueDeclaration == ctor.Parent;
					final isLocalThisPropertyAssignmentConstructorFunction = isAssignmentDeclaration && symbol.Parent.ValueDeclaration == ctor;
					final isWriteableSymbol = isLocalPropertyDeclaration || isLocalParameterProperty || isLocalThisPropertyAssignment
						|| isLocalThisPropertyAssignmentConstructorFunction;
					return !isWriteableSymbol;
				}
			}
			return true;
		}
		if (Ast.IsAccessExpression(expr)) {
			// references through namespace import should be readonly
			final node = Ast.SkipParentheses(expr.Expression());
			if (Ast.IsIdentifier(node)) {
				final expressionSymbol = c.getResolvedSymbol(node);
				if (expressionSymbol.Flags & SymbolFlagsAlias != 0) {
					final declaration = c.getDeclarationOfAliasSymbol(expressionSymbol);
					return declaration != null && Ast.IsNamespaceImport(declaration);
				}
			}
		}
		return false;
	}

	static function isThisPropertyAccessInConstructor(c:Checker, node:Node, prop:Symbol):Bool {
		var constructor:Node = null;
		final r = c.isConstructorDeclaredThisProperty(prop);
		if (r.a == thisAssignmentDeclarationConstructor) {
			constructor = r.b;
		} else if (Checker.isThisProperty(node) && c.isAutoTypedProperty(prop)) {
			constructor = c.getDeclaringConstructor(prop);
		}
		return Ast.GetThisContainer(node, true /*includeArrowFunctions*/, false /*includeClassComputedPropertyName*/) == constructor;
	}

	static function isAutoTypedProperty(c:Checker, symbol:Symbol):Bool {
		// A property is auto-typed when its declaration has no type annotation or initializer and we're in
		// noImplicitAny mode or a .js file.
		final declaration = symbol.ValueDeclaration;
		return declaration != null && Ast.IsPropertyDeclaration(declaration) && declaration.Type() == null && declaration.Initializer() == null && c.noImplicitAny;
	}

	static function getDeclaringConstructor(c:Checker, symbol:Symbol):Node {
		for (declaration in rangeOf(symbol.Declarations)) {
			final container = Ast.GetThisContainer(declaration, false /*includeArrowFunctions*/, false /*includeClassComputedPropertyName*/);
			if (container != null && Ast.IsConstructorDeclaration(container)) {
				return container;
			}
		}
		return null;
	}

	static function getPropertyNameFromIndex(c:Checker, indexType:Type, accessNode:Node):std.String {
		if (Checker.isTypeUsableAsPropertyName(indexType)) {
			return Checker.getPropertyNameFromType(indexType);
		}
		if (accessNode != null && Ast.IsPropertyName(accessNode)) {
			return Ast.GetPropertyNameForPropertyNameNode(accessNode);
		}
		return Ast.InternalSymbolNameMissing;
	}

	static function isStringIndexSignatureOnlyTypeWorker(c:Checker, t:Type):Bool {
		return t.flags & TypeFlagsObject != 0 && !c.isGenericMappedType(t) && Core.len(c.getPropertiesOfType(t)) == 0 && Core.len(c.getIndexInfosOfType(t)) == 1
			&& c.getIndexInfoOfType(t, c.stringType) != null
			|| t.flags & TypeFlagsUnionOrIntersection != 0 && Core.Every(t.Types(), c.isStringIndexSignatureOnlyType);
	}

	static function shouldDeferIndexedAccessType(c:Checker, objectType:Type, indexType:Type, accessNode:Node):Bool {
		if (c.isGenericIndexType(indexType)) {
			return true;
		}
		if (accessNode != null && !Ast.IsIndexedAccessTypeNode(accessNode)) {
			return c.isGenericTupleType(objectType) && !Checker.indexTypeLessThan(indexType, Checker.getTotalFixedElementCount(objectType.TargetTupleType()));
		}
		return c.isGenericObjectType(objectType)
			&& !(Checker.isTupleType(objectType) && Checker.indexTypeLessThan(indexType, Checker.getTotalFixedElementCount(objectType.TargetTupleType())))
			|| c.isGenericReducibleType(objectType);
	}

	static function getNoInferType(c:Checker, t:Type):Type {
		if (c.isNoInferTargetType(t)) {
			return c.getOrCreateSubstitutionType(t, c.unknownType);
		}
		return t;
	}

	static function isNoInferTargetType(c:Checker, t:Type):Bool {
		// This is effectively a more conservative and predictable form of couldContainTypeVariables. We want to
		// preserve NoInfer<T> only for types that could contain type variables, but we don't want to exhaustively
		// examine all object type members.
		return t.flags & TypeFlagsUnionOrIntersection != 0 && someNoInferTargetType(c, t.AsUnionOrIntersectionType().types)
			|| t.flags & TypeFlagsSubstitution != 0 && !c.isNoInferType(t) && c.isNoInferTargetType(t.AsSubstitutionType().baseType)
			|| t.flags & TypeFlagsObject != 0 && !c.IsEmptyAnonymousObjectType(t)
			|| t.flags & (TypeFlagsInstantiable & ~TypeFlagsSubstitution) != 0 && !c.isPatternLiteralType(t);
	}

	static function getSubstitutionType(c:Checker, baseType:Type, constraint:Type):Type {
		if (constraint.flags & TypeFlagsAnyOrUnknown != 0 || constraint == baseType || baseType.flags & TypeFlagsAny != 0) {
			return baseType;
		}
		return c.getOrCreateSubstitutionType(baseType, constraint);
	}

	static function getOrCreateSubstitutionType(c:Checker, baseType:Type, constraint:Type):Type {
		final key = SubstitutionTypeKey.keyOf(baseType.id, constraint.id);
		final cached = c.substitutionTypes.get(key);
		if (cached != null) {
			return cached;
		}
		final result = c.newSubstitutionType(baseType, constraint);
		c.substitutionTypes.set(key, result);
		return result;
	}

	static function getBaseConstraintOrType(c:Checker, t:Type):Type {
		final constraint = c.getBaseConstraintOfType(t);
		if (constraint != null) {
			return constraint;
		}
		return t;
	}

	static function getBaseConstraintOfType(c:Checker, t:Type):Type {
		if (t.flags & (TypeFlagsInstantiableNonPrimitive | TypeFlagsUnionOrIntersection | TypeFlagsTemplateLiteral | TypeFlagsStringMapping | TypeFlagsIndex) != 0
			|| c.isGenericTupleType(t)) {
			final constraint = c.getResolvedBaseConstraint(t, null);
			if (constraint != c.noConstraintType && constraint != c.circularConstraintType) {
				return constraint;
			}
			return null;
		}
		return null;
	}

	static function getResolvedBaseConstraint(c:Checker, t:Type, stack:Array<RecursionId>):Type {
		final constrained = t.AsConstrainedType();
		if (constrained == null) {
			return t;
		}
		if (constrained.resolvedBaseConstraint != null) {
			return constrained.resolvedBaseConstraint;
		}
		if (!c.pushTypeResolution(t, TypeSystemPropertyNameResolvedBaseConstraint)) {
			return c.circularConstraintType;
		}
		var constraint:Type = null;
		// We always explore at least 10 levels of nested constraints. Thereafter, we continue to explore
		// up to 50 levels of nested constraints provided there are no "deeply nested" types on the stack
		// (i.e. no types for which five instantiations have been recorded on the stack). If we reach 50
		// levels of nesting, we are presumably exploring a repeating pattern with a long cycle that hasn't
		// yet triggered the deeply nested limiter. We have no test cases that actually get to 50 levels of
		// nesting, so it is effectively just a safety stop.
		final identity = Checker.getRecursionIdentity(t);
		if (Core.len(stack) < 10 || Core.len(stack) < 50 && !containsRecursionId(stack, identity)) {
			// PORT: Go `append(stack, identity)` gives the callee its own view of the stack; callees only read
			// the stack below their own length, so push before and pop after the call (no copy per level).
			if (stack == null) {
				stack = [];
			}
			stack.push(identity);
			constraint = c.computeBaseConstraint(c.getSimplifiedType(t, false /*writing*/), stack);
			stack.pop();
		}
		if (!c.popTypeResolution()) {
			if (t.flags & TypeFlagsTypeParameter != 0) {
				final errorNode = c.getConstraintDeclaration(t);
				if (errorNode != null) {
					final diagnostic = c.error(errorNode, Diagnostics.Type_parameter_0_has_a_circular_constraint, c.TypeToString(t));
					if (c.currentNode != null && !Checker.isNodeDescendantOf(errorNode, c.currentNode) && !Checker.isNodeDescendantOf(c.currentNode, errorNode)) {
						diagnostic.AddRelatedInfo(Checker.NewDiagnosticForNode(c.currentNode, Diagnostics.Circularity_originates_in_type_at_this_location));
					}
				}
			}
			constraint = c.circularConstraintType;
		}
		if (constraint == null) {
			constraint = c.noConstraintType;
		}
		if (constrained.resolvedBaseConstraint == null) {
			constrained.resolvedBaseConstraint = constraint;
		}
		return constraint;
	}

	static function computeBaseConstraint(c:Checker, t:Type, stack:Array<RecursionId>):Type {
		if (t.flags & TypeFlagsTypeParameter != 0) {
			final constraint = c.getConstraintFromTypeParameter(t);
			if (t.AsTypeParameter().isThisType) {
				return constraint;
			}
			return c.getNextBaseConstraint(constraint, stack);
		} else if (t.flags & TypeFlagsUnionOrIntersection != 0) {
			final types = t.Types();
			final constraints:Array<Type> = [];
			var different = false;
			for (s in rangeOf(types)) {
				final constraint = c.getNextBaseConstraint(s, stack);
				if (constraint != null) {
					if (constraint != s) {
						different = true;
					}
					constraints.push(constraint);
				} else {
					different = true;
				}
			}
			if (!different) {
				return t;
			}
			if (t.flags & TypeFlagsUnion != 0 && constraints.length == Core.len(types)) {
				return c.getUnionType(constraints);
			} else if (t.flags & TypeFlagsIntersection != 0 && constraints.length != 0) {
				return c.getIntersectionType(constraints);
			}
			return null;
		} else if (t.flags & TypeFlagsIndex != 0) {
			if (c.isGenericMappedType(t.AsIndexType().target)) {
				final mappedType = t.AsIndexType().target;
				if (c.getNameTypeFromMappedType(mappedType) != null && !c.isMappedTypeWithKeyofConstraintDeclaration(mappedType)) {
					return c.getNextBaseConstraint(c.getIndexTypeForMappedType(mappedType, IndexFlagsNone), stack);
				}
			}
			return c.stringNumberSymbolType;
		} else if (t.flags & TypeFlagsTemplateLiteral != 0) {
			final types = t.Types();
			final constraints:Array<Type> = [];
			for (s in rangeOf(types)) {
				final constraint = c.getNextBaseConstraint(s, stack);
				if (constraint != null) {
					constraints.push(constraint);
				}
			}
			if (constraints.length == Core.len(types)) {
				return c.getTemplateLiteralType(t.AsTemplateLiteralType().texts, constraints);
			}
			return c.stringType;
		} else if (t.flags & TypeFlagsStringMapping != 0) {
			final constraint = c.getNextBaseConstraint(t.Target(), stack);
			if (constraint != null && constraint != t.Target()) {
				return c.getStringMappingType(t.symbol, constraint);
			}
			return c.stringType;
		} else if (t.flags & TypeFlagsIndexedAccess != 0) {
			if (c.isMappedTypeGenericIndexedAccess(t)) {
				// For indexed access types of the form { [P in K]: E }[X], where K is non-generic and X is generic,
				// we substitute an instantiation of E where P is replaced with X.
				return c.getNextBaseConstraint(c.substituteIndexedMappedType(t.AsIndexedAccessType().objectType, t.AsIndexedAccessType().indexType), stack);
			}
			final baseObjectType = c.getNextBaseConstraint(t.AsIndexedAccessType().objectType, stack);
			final baseIndexType = c.getNextBaseConstraint(t.AsIndexedAccessType().indexType, stack);
			if (baseObjectType == null || baseIndexType == null) {
				return null;
			}
			return c.getNextBaseConstraint(c.getIndexedAccessTypeOrUndefined(baseObjectType, baseIndexType, t.AsIndexedAccessType().accessFlags, null, null), stack);
		} else if (t.flags & TypeFlagsConditional != 0) {
			if (c.conditionalConstraintDepth >= 100) {
				return null;
			}
			c.conditionalConstraintDepth++;
			final constraint = c.getConstraintFromConditionalType(t);
			c.conditionalConstraintDepth--;
			return c.getNextBaseConstraint(constraint, stack);
		} else if (t.flags & TypeFlagsSubstitution != 0) {
			return c.getNextBaseConstraint(c.getSubstitutionIntersection(t), stack);
		} else if (c.isGenericTupleType(t)) {
			// We substitute constraints for variadic elements only when the constraints are array types or
			// non-variadic tuple types as we want to avoid further (possibly unbounded) recursion.
			final elementTypes = c.getElementTypes(t);
			final elementInfos = t.TargetTupleType().elementInfos;
			final newElements:Array<Type> = [];
			for (i in 0...Core.len(elementTypes)) {
				final v = elementTypes[i];
				var newElement = v;
				if (v.flags & TypeFlagsTypeParameter != 0 && elementInfos[i].flags & ElementFlagsVariadic != 0) {
					final constraint = c.getNextBaseConstraint(v, stack);
					if (constraint != null && constraint != v && Checker.everyType(constraint, (n:Type) -> c.isArrayOrTupleType(n) && !c.isGenericTupleType(n))) {
						newElement = constraint;
					}
				}
				newElements.push(newElement);
			}
			return c.createTupleTypeEx(newElements, elementInfos, t.TargetTupleType().readonly);
		}
		return t;
	}

	static function getNextBaseConstraint(c:Checker, t:Type, stack:Array<RecursionId>):Type {
		if (t == null) {
			return null;
		}
		final constraint = c.getResolvedBaseConstraint(t, stack);
		if (constraint == c.noConstraintType || constraint == c.circularConstraintType) {
			return null;
		}
		return constraint;
	}

	// Return true if type might be of the given kind. A union or intersection type might be of a given
	// kind if at least one constituent type is of the given kind.
	static function maybeTypeOfKind(c:Checker, t:Type, kind:TypeFlags):Bool {
		if (t.flags & kind != 0) {
			return true;
		}
		if (t.flags & TypeFlagsUnionOrIntersection != 0) {
			for (t in rangeOf(t.Types())) {
				if (c.maybeTypeOfKind(t, kind)) {
					return true;
				}
			}
		}
		return false;
	}

	static function maybeTypeOfKindConsideringBaseConstraint(c:Checker, t:Type, kind:TypeFlags):Bool {
		if (c.maybeTypeOfKind(t, kind)) {
			return true;
		}
		final baseConstraint = c.getBaseConstraintOrType(t);
		return baseConstraint != null && c.maybeTypeOfKind(baseConstraint, kind);
	}

	static function allTypesAssignableToKind(c:Checker, source:Type, kind:TypeFlags):Bool {
		return c.allTypesAssignableToKindEx(source, kind, false);
	}

	static function allTypesAssignableToKindEx(c:Checker, source:Type, kind:TypeFlags, strict:Bool):Bool {
		if (source.flags & TypeFlagsUnion != 0) {
			// PORT: core.Every with a closure → loop (same short-circuit order, no closure allocation).
			for (subType in rangeOf(source.Types())) {
				if (!c.allTypesAssignableToKindEx(subType, kind, strict)) {
					return false;
				}
			}
			return true;
		}
		return c.isTypeAssignableToKindEx(source, kind, strict);
	}

	static function isTypeAssignableToKind(c:Checker, source:Type, kind:TypeFlags):Bool {
		return c.isTypeAssignableToKindEx(source, kind, false);
	}

	static function isTypeAssignableToKindEx(c:Checker, source:Type, kind:TypeFlags, strict:Bool):Bool {
		if (source.flags & kind != 0) {
			return true;
		}
		if (strict && source.flags & (TypeFlagsAnyOrUnknown | TypeFlagsVoid | TypeFlagsUndefined | TypeFlagsNull) != 0) {
			return false;
		}
		return kind & TypeFlagsNumberLike != 0 && c.isTypeAssignableTo(source, c.numberType)
			|| kind & TypeFlagsBigIntLike != 0 && c.isTypeAssignableTo(source, c.bigintType)
			|| kind & TypeFlagsStringLike != 0 && c.isTypeAssignableTo(source, c.stringType)
			|| kind & TypeFlagsBooleanLike != 0 && c.isTypeAssignableTo(source, c.booleanType)
			|| kind & TypeFlagsVoid != 0 && c.isTypeAssignableTo(source, c.voidType)
			|| kind & TypeFlagsNever != 0 && c.isTypeAssignableTo(source, c.neverType)
			|| kind & TypeFlagsNull != 0 && c.isTypeAssignableTo(source, c.nullType)
			|| kind & TypeFlagsUndefined != 0 && c.isTypeAssignableTo(source, c.undefinedType)
			|| kind & TypeFlagsESSymbol != 0 && c.isTypeAssignableTo(source, c.esSymbolType)
			|| kind & TypeFlagsNonPrimitive != 0 && c.isTypeAssignableTo(source, c.nonPrimitiveType);
	}

	static function compareProperties(c:Checker, sourceProp:Symbol, targetProp:Symbol, compareTypes:(source:Type, target:Type) -> Ternary):Ternary {
		// Two members are considered identical when
		// - they are public properties with identical names, optionality, and types,
		// - they are private or protected properties originating in the same declaration and having identical types
		if (sourceProp == targetProp) {
			return TernaryTrue;
		}
		final sourcePropAccessibility = Checker.getDeclarationModifierFlagsFromSymbol(sourceProp) & ModifierFlagsNonPublicAccessibilityModifier;
		final targetPropAccessibility = Checker.getDeclarationModifierFlagsFromSymbol(targetProp) & ModifierFlagsNonPublicAccessibilityModifier;
		if (sourcePropAccessibility != targetPropAccessibility) {
			return TernaryFalse;
		}
		if (sourcePropAccessibility != ModifierFlagsNone) {
			if (c.getTargetSymbol(sourceProp) != c.getTargetSymbol(targetProp)) {
				return TernaryFalse;
			}
		} else {
			if ((sourceProp.Flags & SymbolFlagsOptional) != (targetProp.Flags & SymbolFlagsOptional)) {
				return TernaryFalse;
			}
		}
		if (c.isReadonlySymbol(sourceProp) != c.isReadonlySymbol(targetProp)) {
			return TernaryFalse;
		}
		return compareTypes(c.getNonMissingTypeOfSymbol(sourceProp), c.getNonMissingTypeOfSymbol(targetProp));
	}

	static function markPropertyAsReferenced(c:Checker, prop:Symbol, nodeForCheckWriteOnly:Node, isSelfTypeAccess:Bool):Void {
		if (prop.Flags & SymbolFlagsClassMember == 0 || prop.ValueDeclaration == null) {
			return;
		}
		final hasPrivateModifier = Ast.HasModifier(prop.ValueDeclaration, ModifierFlagsPrivate);
		final hasPrivateIdentifier = prop.ValueDeclaration.Name() != null && Ast.IsPrivateIdentifier(prop.ValueDeclaration.Name());
		if (!hasPrivateModifier && !hasPrivateIdentifier) {
			return;
		}
		if (nodeForCheckWriteOnly != null && Ast.IsWriteOnlyAccess(nodeForCheckWriteOnly) && prop.Flags & SymbolFlagsSetAccessor == 0) {
			return;
		}
		if (isSelfTypeAccess) {
			// Find any FunctionLikeDeclaration because those create a new 'this' binding. But this should only matter for methods (or getters/setters).
			final containingMethod = Ast.FindAncestor(nodeForCheckWriteOnly, Ast.IsFunctionLikeDeclaration);
			if (containingMethod != null && containingMethod.Symbol() == prop) {
				return;
			}
		}
		var target = prop;
		if (prop.CheckFlags & CheckFlagsInstantiated != 0) {
			target = c.valueSymbolLinks.Get(prop).target;
		}
		c.symbolReferenceLinks.Get(target).referenceKinds |= SymbolFlagsAll;
	}

	static function expandSignatureParametersWithTupleMembers(c:Checker, signature:Signature, restType:TypeReference, restIndex:Int, restSymbol:Symbol):Array<Symbol> {
		final elementTypes = c.getTypeArguments(restType.AsType());
		final elementInfos = restType.TargetTupleType().elementInfos;
		final associatedNames = c.getUniqAssociatedNamesFromTupleType(restType, restSymbol);
		final expanded:Array<Symbol> = signature.parameters.slice(0, restIndex);
		for (i in 0...Core.len(elementTypes)) {
			final t = elementTypes[i];
			final flags = elementInfos[i].flags;
			var checkFlags = CheckFlagsNone;
			if (flags & ElementFlagsVariable != 0) {
				checkFlags = CheckFlagsRestParameter;
			} else if (flags & ElementFlagsOptional != 0) {
				checkFlags = CheckFlagsOptionalParameter;
			}
			final symbol = c.newSymbolEx(SymbolFlagsFunctionScopedVariable, associatedNames[i], checkFlags);
			final links = c.valueSymbolLinks.Get(symbol);
			if (flags & ElementFlagsRest != 0) {
				links.resolvedType = c.createArrayType(t);
			} else {
				links.resolvedType = t;
			}
			expanded.push(symbol);
		}
		return expanded;
	}

	static function getUniqAssociatedNamesFromTupleType(c:Checker, t:TypeReference, restSymbol:Symbol):Array<std.String> {
		final elementInfos = t.TargetTupleType().elementInfos;
		final names:Array<std.String> = [for (_ in 0...Core.len(elementInfos)) ""];
		final counters = new StringMap<Int>();
		for (i in 0...Core.len(elementInfos)) {
			final info = elementInfos[i];
			names[i] = c.getTupleElementLabel(info, restSymbol, i);
			// count duplicates using negative values
			counters.set(names[i], stringIntMapGet(counters, names[i]) - 1);
		}
		for (i in 0...names.length) {
			final name = names[i];
			if (stringIntMapGet(counters, name) == -1) {
				continue;
			}
			while (true) {
				if (stringIntMapGet(counters, name) < 0) {
					// switch to a positive suffix counter
					counters.set(name, 0);
				}
				counters.set(name, stringIntMapGet(counters, name) + 1);
				// PORT: strconv.Itoa → Std.string (go.Strconv has no Itoa).
				final candidateName = name + "_" + Std.string(stringIntMapGet(counters, name));
				if (stringIntMapGet(counters, candidateName) == 0) {
					names[i] = candidateName;
					break;
				}
			}
		}
		return names;
	}

	static function isUnknownLikeUnionType(c:Checker, t:Type):Bool {
		if (c.strictNullChecks && t.flags & TypeFlagsUnion != 0) {
			if (t.objectFlags & ObjectFlagsIsUnknownLikeUnionComputed == 0) {
				t.objectFlags |= ObjectFlagsIsUnknownLikeUnionComputed;
				final types = t.Types();
				if (Core.len(types) >= 3 && types[0].flags & TypeFlagsUndefined != 0 && types[1].flags & TypeFlagsNull != 0
					&& someEmptyAnonymousObjectType(c, types)) {
					t.objectFlags |= ObjectFlagsIsUnknownLikeUnion;
				}
			}
			return t.objectFlags & ObjectFlagsIsUnknownLikeUnion != 0;
		}
		return false;
	}

	static function containsUndefinedType(c:Checker, t:Type):Bool {
		if (t.flags & TypeFlagsUnion != 0) {
			t = t.Types()[0];
		}
		return t.flags & TypeFlagsUndefined != 0;
	}

	static function typeHasCallOrConstructSignatures(c:Checker, t:Type):Bool {
		return t.flags & TypeFlagsStructuredType != 0 && Core.len(c.resolveStructuredTypeMembers(t).signatures) != 0;
	}

	static function getNormalizedType(c:Checker, t:Type, writing:Bool):Type {
		while (true) {
			var n:Type = null;
			if (Checker.isFreshLiteralType(t)) {
				n = t.AsLiteralType().regularType;
			} else if (c.isGenericTupleType(t)) {
				n = c.getNormalizedTupleType(t, writing);
			} else if (t.objectFlags & ObjectFlagsReference != 0) {
				if (t.AsTypeReference().node != null) {
					n = c.createTypeReference(t.Target(), c.getTypeArguments(t));
				} else {
					n = c.getSingleBaseForNonAugmentingSubtype(t);
					if (n == null) {
						n = t;
					}
				}
			} else if (t.flags & TypeFlagsUnionOrIntersection != 0) {
				n = c.getNormalizedUnionOrIntersectionType(t, writing);
			} else if (t.flags & TypeFlagsSubstitution != 0) {
				if (writing) {
					n = t.AsSubstitutionType().baseType;
				} else {
					n = c.getSubstitutionIntersection(t);
				}
			} else if (t.flags & TypeFlagsSimplifiable != 0) {
				n = c.getSimplifiedType(t, writing);
			} else {
				return t;
			}
			if (n == t) {
				return n;
			}
			t = n;
		}
	}

	static function getSimplifiedType(c:Checker, t:Type, writing:Bool):Type {
		if (t.flags & TypeFlagsIndexedAccess != 0) {
			return c.getSimplifiedIndexedAccessType(t, writing);
		} else if (t.flags & TypeFlagsConditional != 0) {
			return c.getSimplifiedConditionalType(t, writing);
		}
		return t;
	}

	// Transform an indexed access to a simpler form, if possible. Return the simpler form, or return
	// the type itself if no transformation is possible. The writing flag indicates that the type is
	// the target of an assignment.
	static function getSimplifiedIndexedAccessType(c:Checker, t:Type, writing:Bool):Type {
		final key = CachedTypeKey.keyOf(Core.IfElse(writing, CachedTypeKindIndexedAccessForWriting, CachedTypeKindIndexedAccessForReading), t.id);
		final cached = c.cachedTypes.get(key);
		if (cached != null) {
			return Core.IfElse(cached == c.circularConstraintType, t, cached);
		}
		c.cachedTypes.set(key, t);
		var result = c.getSimplifiedIndexedAccessTypeWorker(t, writing);
		if (result != t) {
			// If the simplification is a union type that includes t, remove t from the type.
			result = c.removeType(result, t);
			c.cachedTypes.set(key, result);
		}
		return result;
	}

	static function getSimplifiedIndexedAccessTypeWorker(c:Checker, t:Type, writing:Bool):Type {
		// We recursively simplify the object type as it may in turn be an indexed access type. For example, with
		// '{ [P in T]: { [Q in U]: number } }[T][U]' we want to first simplify the inner indexed access type.
		final objectType = c.getSimplifiedType(t.AsIndexedAccessType().objectType, writing);
		final indexType = c.getSimplifiedType(t.AsIndexedAccessType().indexType, writing);
		// T[A | B] -> T[A] | T[B] (reading)
		// T[A | B] -> T[A] & T[B] (writing)
		final distributedOverIndex = c.distributeObjectOverIndexType(objectType, indexType, writing);
		if (distributedOverIndex != null) {
			return distributedOverIndex;
		}
		// Only do the inner distributions if the index can no longer be instantiated to cause index distribution again
		if (indexType.flags & TypeFlagsInstantiable == 0) {
			// (T | U)[K] -> T[K] | U[K] (reading)
			// (T | U)[K] -> T[K] & U[K] (writing)
			// (T & U)[K] -> T[K] & U[K]
			final distributedOverObject = c.distributeIndexOverObjectType(objectType, indexType, writing);
			if (distributedOverObject != null) {
				return distributedOverObject;
			}
		}
		// So ultimately (reading):
		// ((A & B) | C)[K1 | K2] -> ((A & B) | C)[K1] | ((A & B) | C)[K2] -> (A & B)[K1] | C[K1] | (A & B)[K2] | C[K2] -> (A[K1] & B[K1]) | C[K1] | (A[K2] & B[K2]) | C[K2]
		// A generic tuple type indexed by a number exists only when the index type doesn't select a
		// fixed element. We simplify to either the combined type of all elements (when the index type
		// the actual number type) or to the combined type of all non-fixed elements.
		if (c.isGenericTupleType(objectType) && indexType.flags & TypeFlagsNumberLike != 0) {
			final elementType = c.getElementTypeOfSliceOfTupleType(objectType, Core.IfElse(indexType.flags & TypeFlagsNumber != 0, 0, objectType.TargetTupleType().fixedLength),
				0 /*endSkipCount*/, writing, false);
			if (elementType != null) {
				return elementType;
			}
		}
		// If the object type is a mapped type { [P in K]: E }, where K is generic, or { [P in K as N]: E }, where
		// K is generic and N is assignable to P, instantiate E using a mapper that substitutes the index type for P.
		// For example, for an index access { [P in K]: Box<T[P]> }[X], we construct the type Box<T[X]>.
		if (c.isGenericMappedType(objectType)) {
			if (c.getMappedTypeNameTypeKind(objectType) != MappedTypeNameTypeKindRemapping) {
				return c.mapType(c.substituteIndexedMappedType(objectType, t.AsIndexedAccessType().indexType), (t:Type) -> {
					return c.getSimplifiedType(t, writing);
				});
			}
		}
		return t;
	}

	static function distributeObjectOverIndexType(c:Checker, objectType:Type, indexType:Type, writing:Bool):Type {
		// T[A | B] -> T[A] | T[B] (reading)
		// T[A | B] -> T[A] & T[B] (writing)
		if (indexType.flags & TypeFlagsUnion != 0) {
			final types = Core.Map(indexType.Types(), (t:Type) -> {
				return c.getSimplifiedType(c.getIndexedAccessType(objectType, t), writing);
			});
			if (writing) {
				return c.getIntersectionType(types);
			}
			return c.getUnionType(types);
		}
		return null;
	}

	static function distributeIndexOverObjectType(c:Checker, objectType:Type, indexType:Type, writing:Bool):Type {
		// (T | U)[K] -> T[K] | U[K] (reading)
		// (T | U)[K] -> T[K] & U[K] (writing)
		// (T & U)[K] -> T[K] & U[K]
		if (objectType.flags & TypeFlagsUnion != 0 || objectType.flags & TypeFlagsIntersection != 0 && !c.shouldDeferIndexType(objectType, IndexFlagsNone)) {
			final types = Core.Map(objectType.Types(), (t:Type) -> {
				return c.getSimplifiedType(c.getIndexedAccessType(t, indexType), writing);
			});
			if (objectType.flags & TypeFlagsIntersection != 0 || writing) {
				return c.getIntersectionType(types);
			}
			return c.getUnionType(types);
		}
		return null;
	}

	static function getSimplifiedConditionalType(c:Checker, t:Type, writing:Bool):Type {
		final checkType = t.AsConditionalType().checkType;
		final extendsType = t.AsConditionalType().extendsType;
		final trueType = c.getTrueTypeFromConditionalType(t);
		final falseType = c.getFalseTypeFromConditionalType(t);
		// Simplifications for types of the form `T extends U ? T : never` and `T extends U ? never : T`.
		if (falseType.flags & TypeFlagsNever != 0 && c.getActualTypeVariable(trueType) == c.getActualTypeVariable(checkType)) {
			if (checkType.flags & TypeFlagsAny != 0 || c.isTypeAssignableTo(c.getRestrictiveInstantiation(checkType), c.getRestrictiveInstantiation(extendsType))) {
				return c.getSimplifiedType(trueType, writing);
			} else if (c.isIntersectionEmpty(checkType, extendsType)) {
				return c.neverType;
			}
		} else if (trueType.flags & TypeFlagsNever != 0 && c.getActualTypeVariable(falseType) == c.getActualTypeVariable(checkType)) {
			if (checkType.flags & TypeFlagsAny == 0 && c.isTypeAssignableTo(c.getRestrictiveInstantiation(checkType), c.getRestrictiveInstantiation(extendsType))) {
				return c.neverType;
			} else if (checkType.flags & TypeFlagsAny != 0 || c.isIntersectionEmpty(checkType, extendsType)) {
				return c.getSimplifiedType(falseType, writing);
			}
		}
		return t;
	}

	// Invokes union simplification logic to determine if an intersection is considered empty as a union constituent
	static function isIntersectionEmpty(c:Checker, type1:Type, type2:Type):Bool {
		return c.getUnionType([c.intersectTypes(type1, type2), c.neverType]).flags & TypeFlagsNever != 0;
	}

	static function getSimplifiedTypeOrConstraint(c:Checker, t:Type):Type {
		final simplified = c.getSimplifiedType(t, false /*writing*/);
		if (simplified != t) {
			return simplified;
		}
		return c.getConstraintOfType(t);
	}

	static function getNormalizedUnionOrIntersectionType(c:Checker, t:Type, writing:Bool):Type {
		final reduced = c.getReducedType(t);
		if (reduced != t) {
			return reduced;
		}
		if (t.flags & TypeFlagsIntersection != 0 && c.shouldNormalizeIntersection(t)) {
			// Normalization handles cases like
			// Partial<T>[K] & ({} | null) ==>
			// Partial<T>[K] & {} | Partial<T>[K} & null ==>
			// (T[K] | undefined) & {} | (T[K] | undefined) & null ==>
			// T[K] & {} | undefined & {} | T[K] & null | undefined & null ==>
			// T[K] & {} | T[K] & null
			final types = t.Types();
			final normalizedTypes = Core.SameMap(types, (u:Type) -> c.getNormalizedType(u, writing));
			if (!Core.Same(normalizedTypes, types)) {
				return c.getIntersectionType(normalizedTypes);
			}
		}
		return t;
	}

	static function shouldNormalizeIntersection(c:Checker, t:Type):Bool {
		var hasInstantiable = false;
		var hasNullableOrEmpty = false;
		for (t in rangeOf(t.Types())) {
			hasInstantiable = hasInstantiable || t.flags & TypeFlagsInstantiable != 0;
			hasNullableOrEmpty = hasNullableOrEmpty || t.flags & TypeFlagsNullable != 0 || c.IsEmptyAnonymousObjectType(t);
			if (hasInstantiable && hasNullableOrEmpty) {
				return true;
			}
		}
		return false;
	}

	static function getNormalizedTupleType(c:Checker, t:Type, writing:Bool):Type {
		final elements = c.getElementTypes(t);
		final normalizedElements = Core.SameMap(elements, (t:Type) -> {
			if (t.flags & TypeFlagsSimplifiable != 0) {
				return c.getSimplifiedType(t, writing);
			}
			return t;
		});
		if (!Core.Same(elements, normalizedElements)) {
			return c.createNormalizedTupleType(t.Target(), normalizedElements);
		}
		return t;
	}

	// --- private helpers (P7) ---

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

	// PORT: Go math.MaxInt (int is 32-bit here, PORTING.md §3).
	static inline final MAX_INT:Int = 0x7FFFFFFF;

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

	// PORT: Go `slices.Contains(stack, identity)` on []RecursionId: Go `==` compares the contained `any` values.
	static function containsRecursionId(stack:Array<RecursionId>, identity:RecursionId):Bool {
		if (stack != null) {
			for (id in stack) {
				if (id.value == identity.value) {
					return true;
				}
			}
		}
		return false;
	}

	// PORT: Go `counters[name]` on a map[string]int: a missing key reads as 0.
	static inline function stringIntMapGet(m:StringMap<Int>, key:std.String):Int {
		final v = m.get(key);
		return v == null ? 0 : v;
	}

	// PORT: Go `core.Some(types, c.isNoInferTargetType)` as a loop (no bound-method allocation).
	static function someNoInferTargetType(c:Checker, types:Array<Type>):Bool {
		if (types != null) {
			for (t in types) {
				if (c.isNoInferTargetType(t)) {
					return true;
				}
			}
		}
		return false;
	}

	// PORT: Go `core.Some(types, c.IsEmptyAnonymousObjectType)` as a loop (no bound-method allocation).
	static function someEmptyAnonymousObjectType(c:Checker, types:Array<Type>):Bool {
		if (types != null) {
			for (t in types) {
				if (c.IsEmptyAnonymousObjectType(t)) {
					return true;
				}
			}
		}
		return false;
	}
}
