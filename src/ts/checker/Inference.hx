package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/inference.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).
//
// PORT: method values. Go passes method expressions `(*Checker).isTypeOrBaseIdenticalTo`, … and
// `(*Checker).inferToConditionalType`, …; here each one is a static final function value `fn_<name>`
// created once (PORTING.md §7a).

@:allow(ts.checker)
class InferenceKey {
	var s:TypeId = 0;
	var t:TypeId = 0;

	public function new() {}

	// PORT: struct map key (map[InferenceKey]…), same convention as the key types in Checker.hx.
	public static inline function keyOf(s:TypeId, t:TypeId):std.String {
		return s + ":" + t;
	}

	public function Key():std.String {
		return keyOf(s, t);
	}
}

@:allow(ts.checker)
class InferenceState {
	var inferences:Array<InferenceInfo> = null;
	var originalSource:Type = null;
	var originalTarget:Type = null;
	var priority:InferencePriority = 0;
	var inferencePriority:InferencePriority = 0;
	var contravariant:Bool = false;
	var bivariant:Bool = false;
	var expandingFlags:ExpandingFlags = 0;
	var propagationType:Type = null;
	var visited:StringMap<InferencePriority> /* key: checker.InferenceKey */ = null;
	var sourceStack:Array<Type> = null;
	var targetStack:Array<Type> = null;
	var next:InferenceState = null;
	var depth:Int = 0;

	public function new() {}
}

// Methods of inference.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Inference {
	static final fn_isTypeOrBaseIdenticalTo:(c:Checker, s:Type, t:Type) -> Bool = (c, s, t) -> c.isTypeOrBaseIdenticalTo(s, t);
	static final fn_isTypeCloselyMatchedBy:(c:Checker, s:Type, t:Type) -> Bool = (c, s, t) -> c.isTypeCloselyMatchedBy(s, t);
	static final fn_isTypeIdenticalTo:(c:Checker, s:Type, t:Type) -> Bool = (c, s, t) -> c.isTypeIdenticalTo(s, t);
	static final fn_isTypeStrictSubtypeOf:(c:Checker, s:Type, t:Type) -> Bool = (c, s, t) -> c.isTypeStrictSubtypeOf(s, t);
	static final fn_isTypeSubtypeOf:(c:Checker, s:Type, t:Type) -> Bool = (c, s, t) -> c.isTypeSubtypeOf(s, t);
	static final fn_inferToConditionalType:(c:Checker, n:InferenceState, source:Type, target:Type) -> Void = (c, n, s, t) -> c.inferToConditionalType(n, s, t);
	static final fn_inferFromGenericMappedTypes:(c:Checker, n:InferenceState, source:Type, target:Type) -> Void = (c, n, s, t) -> c.inferFromGenericMappedTypes(n, s,
		t);
	static final fn_inferFromObjectTypes:(c:Checker, n:InferenceState, source:Type, target:Type) -> Void = (c, n, s, t) -> c.inferFromObjectTypes(n, s, t);

	// Go builtin min on InferencePriority (a signed Int; InferencePriorityCircularity is -1).
	static inline function minPriority(a:InferencePriority, b:InferencePriority):InferencePriority {
		return (a : Int) < (b : Int) ? a : b;
	}

	static function getInferenceState(c:Checker):InferenceState {
		var n = c.freeinferenceState;
		if (n == null) {
			n = new InferenceState();
		}
		c.freeinferenceState = n.next;
		return n;
	}

	static function putInferenceState(c:Checker, n:InferenceState):Void {
		final visited = n.visited;
		if (visited != null) {
			visited.clear();
		}
		final sourceStack = n.sourceStack;
		if (sourceStack != null) {
			sourceStack.resize(0);
		}
		final targetStack = n.targetStack;
		if (targetStack != null) {
			targetStack.resize(0);
		}
		// PORT: Go keeps `n.inferences[:0]` (capacity only). The array belongs to the caller of inferTypes,
		// so it must not be truncated here; it is dropped instead.
		n.inferences = null;
		n.originalSource = null;
		n.originalTarget = null;
		n.priority = 0;
		n.inferencePriority = 0;
		n.contravariant = false;
		n.bivariant = false;
		n.expandingFlags = 0;
		n.propagationType = null;
		n.visited = visited;
		n.sourceStack = sourceStack;
		n.targetStack = targetStack;
		n.next = c.freeinferenceState;
		n.depth = 0;
		c.freeinferenceState = n;
	}

	static function inferTypes(c:Checker, inferences:Array<InferenceInfo>, originalSource:Type, originalTarget:Type, priority:InferencePriority, contravariant:Bool):Void {
		final n = c.getInferenceState();
		n.inferences = inferences;
		n.originalSource = originalSource;
		n.originalTarget = originalTarget;
		n.priority = priority;
		n.inferencePriority = InferencePriorityMaxValue;
		n.contravariant = contravariant;
		c.inferFromTypes(n, originalSource, originalTarget);
		c.putInferenceState(n);
	}

	static function inferFromTypes(c:Checker, n:InferenceState, source:Type, target:Type):Void {
		if (!c.couldContainTypeVariables(target) || c.isNoInferType(target)) {
			return;
		}
		if (source == c.wildcardType || source == c.blockedStringType) {
			// We are inferring from an 'any' type. We want to infer this type for every type parameter
			// referenced in the target type, so we record it as the propagation type and infer from the
			// target to itself. Then, as we find candidates we substitute the propagation type.
			final savePropagationType = n.propagationType;
			n.propagationType = source;
			c.inferFromTypes(n, target, target);
			n.propagationType = savePropagationType;
			return;
		}
		if (source.alias != null && target.alias != null && source.alias.symbol == target.alias.symbol) {
			if (Core.len(source.alias.typeArguments) != 0 || Core.len(target.alias.typeArguments) != 0) {
				// Source and target are types originating in the same generic type alias declaration.
				// Simply infer from source type arguments to target type arguments, with defaults applied.
				final params = c.typeAliasLinks.Get(source.alias.symbol).typeParameters;
				final minParams = c.getMinTypeArgumentCount(params);
				final nodeIsInJsFile = Ast.IsInJSFile(source.alias.symbol.ValueDeclaration);
				final sourceTypes = c.fillMissingTypeArguments(source.alias.typeArguments, params, minParams, nodeIsInJsFile);
				final targetTypes = c.fillMissingTypeArguments(target.alias.typeArguments, params, minParams, nodeIsInJsFile);
				c.inferFromTypeArguments(n, sourceTypes, targetTypes, c.getAliasVariances(source.alias.symbol));
			}
			// And if there weren't any type arguments, there's no reason to run inference as the types must be the same.
			return;
		}
		if (source == target && (source.flags & TypeFlagsUnionOrIntersection) != 0) {
			// When source and target are the same union or intersection type, just relate each constituent
			// type to itself.
			for (t in source.Types()) {
				c.inferFromTypes(n, t, t);
			}
			return;
		}
		if ((target.flags & TypeFlagsUnion) != 0) {
			var sourceTypes:Array<Type>;
			if ((source.flags & TypeFlagsUnion) != 0) {
				sourceTypes = source.Types();
			} else {
				sourceTypes = [source];
			}
			// First, infer between identically matching source and target constituents and remove the
			// matching types.
			final temp = c.inferFromMatchingTypes(n, sourceTypes, target.Distributed(), fn_isTypeOrBaseIdenticalTo);
			// Next, infer between closely matching source and target constituents and remove
			// the matching types. Types closely match when they are instantiations of the same
			// object type or instantiations of the same type alias.
			final matched = c.inferFromMatchingTypes(n, temp.a, temp.b, fn_isTypeCloselyMatchedBy);
			final sources = matched.a;
			final targets = matched.b;
			if (Core.len(targets) == 0) {
				return;
			}
			target = c.getUnionType(targets);
			if (Core.len(sources) == 0) {
				// All source constituents have been matched and there is nothing further to infer from.
				// However, simply making no inferences is undesirable because it could ultimately mean
				// inferring a type parameter constraint. Instead, make a lower priority inference from
				// the full source to whatever remains in the target. For example, when inferring from
				// string to 'string | T', make a lower priority inference of string for T.
				c.inferWithPriority(n, source, target, InferencePriorityNakedTypeVariable);
				return;
			}
			source = c.getUnionType(sources);
		} else if ((target.flags & TypeFlagsIntersection) != 0 && !Core.Every(target.Types(), t -> c.isNonGenericObjectType(t))) {
			// We reduce intersection types unless they're simple combinations of object types. For example,
			// when inferring from 'string[] & { extra: any }' to 'string[] & T' we want to remove string[] and
			// infer { extra: any } for T. But when inferring to 'string[] & Iterable<T>' we want to keep the
			// string[] on the source side and infer string for T.
			if ((source.flags & TypeFlagsUnion) == 0) {
				var sourceTypes:Array<Type>;
				if ((source.flags & TypeFlagsIntersection) != 0) {
					sourceTypes = source.Types();
				} else {
					sourceTypes = [source];
				}
				// Infer between identically matching source and target constituents and remove the matching types.
				final matched = c.inferFromMatchingTypes(n, sourceTypes, target.Types(), fn_isTypeIdenticalTo);
				final sources = matched.a;
				final targets = matched.b;
				if (Core.len(sources) == 0 || Core.len(targets) == 0) {
					return;
				}
				source = c.getIntersectionType(sources);
				target = c.getIntersectionType(targets);
			}
		}
		if ((target.flags & (TypeFlagsIndexedAccess | TypeFlagsSubstitution)) != 0) {
			if (c.isNoInferType(target)) {
				return;
			}
			target = c.getActualTypeVariable(target);
		}
		if ((target.flags & TypeFlagsTypeVariable) != 0) {
			// Skip inference if the source is "blocked", which is used by the language service to
			// prevent inference on nodes currently being edited.
			if (c.isFromInferenceBlockedSource(source)) {
				return;
			}
			final inference = Checker.getInferenceInfoForType(n, target);
			if (inference != null) {
				// If target is a type parameter, make an inference, unless the source type contains
				// a "non-inferrable" type. Types with this flag set are markers used to prevent inference.
				//
				// For example:
				//     - anyFunctionType is a wildcard type that's used to avoid contextually typing functions;
				//       it's internal, so should not be exposed to the user by adding it as a candidate.
				//     - autoType (and autoArrayType) is a special "any" used in control flow; like anyFunctionType,
				//       it's internal and should not be observable.
				//     - silentNeverType is returned by getInferredType when instantiating a generic function for
				//       inference (and a type variable has no mapping).
				//
				// This flag is infectious; if we produce Box<never> (where never is silentNeverType), Box<never> is
				// also non-inferrable.
				//
				// As a special case, also ignore nonInferrableAnyType, which is a special form of the any type
				// used as a stand-in for binding elements when they are being inferred.
				if ((source.objectFlags & ObjectFlagsNonInferrableType) != 0 || source == c.nonInferrableAnyType) {
					return;
				}
				if (!inference.isFixed) {
					final candidate = Core.OrElse(n.propagationType, source);
					if (candidate == c.blockedStringType) {
						return;
					}
					if ((n.priority : Int) < (inference.priority : Int)) {
						inference.candidates = null;
						inference.candidateDepths = null;
						inference.contraCandidates = null;
						inference.topLevel = true;
						inference.priority = n.priority;
					}
					if (n.priority == inference.priority) {
						// We make contravariant inferences only if we are in a pure contravariant position,
						// i.e. only if we have not descended into a bivariant position.
						if (n.contravariant && !n.bivariant) {
							if (!Slices.Contains(inference.contraCandidates, candidate)) {
								if (inference.contraCandidates == null) {
									inference.contraCandidates = [];
								}
								inference.contraCandidates.push(candidate);
								Checker.clearCachedInferences(n.inferences);
							}
						} else {
							var index = Slices.Index(inference.candidates, candidate);
							if (index < 0 || inference.candidateDepths[index] < n.depth) {
								// Candidate isn't present or is present with lower depth
								if (index >= 0) {
									// Remove candidate with lower depth
									inference.candidates.splice(index, 1);
									inference.candidateDepths.splice(index, 1);
								}
								index = 0;
								while (index < Core.len(inference.candidateDepths)) {
									if (inference.candidateDepths[index] < n.depth) {
										break;
									}
									index++;
								}
								// Insert candidate at end or immediately before first candidate with lower depth.
								// This ensures candidates with the highest depth are stored first.
								if (inference.candidates == null) {
									inference.candidates = [];
								}
								if (inference.candidateDepths == null) {
									inference.candidateDepths = [];
								}
								inference.candidates.insert(index, candidate);
								inference.candidateDepths.insert(index, n.depth);
								Checker.clearCachedInferences(n.inferences);
							}
						}
					}
					if ((n.priority & InferencePriorityReturnType) == 0 && (target.flags & TypeFlagsTypeParameter) != 0 && inference.topLevel
						&& !c.isTypeParameterAtTopLevel(n.originalTarget, target, 0)) {
						inference.topLevel = false;
						Checker.clearCachedInferences(n.inferences);
					}
				}
				n.inferencePriority = minPriority(n.inferencePriority, n.priority);
				return;
			}
			// Infer to the simplified version of an indexed access, if possible, to (hopefully) expose more bare type parameters to the inference engine
			final simplified = c.getSimplifiedType(target, false /*writing*/);
			if (simplified != target) {
				c.inferFromTypes(n, source, simplified);
			} else if ((target.flags & TypeFlagsIndexedAccess) != 0) {
				final indexType = c.getSimplifiedType(target.AsIndexedAccessType().indexType, false /*writing*/);
				// Generally simplifications of instantiable indexes are avoided to keep relationship checking correct, however if our target is an access, we can consider
				// that key of that access to be "instantiated", since we're looking to find the infernce goal in any way we can.
				if ((indexType.flags & TypeFlagsInstantiable) != 0) {
					final simplified = c.distributeIndexOverObjectType(c.getSimplifiedType(target.AsIndexedAccessType().objectType, false /*writing*/), indexType,
						false /*writing*/);
					if (simplified != null && simplified != target) {
						c.inferFromTypes(n, source, simplified);
					}
				}
			}
		}
		if ((source.objectFlags & ObjectFlagsReference) != 0 && (target.objectFlags & ObjectFlagsReference) != 0
			&& (source.AsTypeReference().target == target.AsTypeReference().target || c.isArrayType(source) && c.isArrayType(target))
			&& !(source.AsTypeReference().node != null && target.AsTypeReference().node != null)) {
			// If source and target are references to the same generic type, infer from type arguments
			c.inferFromTypeArguments(n, c.getTypeArguments(source), c.getTypeArguments(target), c.getVariances(source.AsTypeReference().target));
		} else if ((source.flags & TypeFlagsIndex) != 0 && (target.flags & TypeFlagsIndex) != 0) {
			c.inferFromContravariantTypes(n, source.AsIndexType().target, target.AsIndexType().target);
		} else if ((Checker.isLiteralType(source) || (source.flags & TypeFlagsString) != 0) && (target.flags & TypeFlagsIndex) != 0) {
			final empty = c.createEmptyObjectTypeFromStringLiteral(source);
			c.inferFromContravariantTypesWithPriority(n, empty, target.AsIndexType().target, InferencePriorityLiteralKeyof);
		} else if ((source.flags & TypeFlagsIndexedAccess) != 0 && (target.flags & TypeFlagsIndexedAccess) != 0) {
			c.inferFromTypes(n, source.AsIndexedAccessType().objectType, target.AsIndexedAccessType().objectType);
			c.inferFromTypes(n, source.AsIndexedAccessType().indexType, target.AsIndexedAccessType().indexType);
		} else if ((source.flags & TypeFlagsStringMapping) != 0 && (target.flags & TypeFlagsStringMapping) != 0) {
			if (source.symbol == target.symbol) {
				c.inferFromTypes(n, source.AsStringMappingType().target, target.AsStringMappingType().target);
			}
		} else if ((source.flags & TypeFlagsSubstitution) != 0) {
			c.inferFromTypes(n, source.AsSubstitutionType().baseType, target);
			// Make substitute inference at a lower priority
			c.inferWithPriority(n, c.getSubstitutionIntersection(source), target, InferencePrioritySubstituteSource);
		} else if ((target.flags & TypeFlagsConditional) != 0) {
			c.invokeOnce(n, source, target, fn_inferToConditionalType);
		} else if ((target.flags & TypeFlagsUnionOrIntersection) != 0) {
			c.inferToMultipleTypes(n, source, target.Types(), target.flags);
		} else if ((source.flags & TypeFlagsUnion) != 0) {
			// Source is a union or intersection type, infer from each constituent type
			for (sourceType in source.Types()) {
				c.inferFromTypes(n, sourceType, target);
			}
		} else if ((target.flags & TypeFlagsTemplateLiteral) != 0) {
			c.inferToTemplateLiteralType(n, source, target.AsTemplateLiteralType());
		} else {
			source = c.getReducedType(source);
			if (c.isGenericMappedType(source) && c.isGenericMappedType(target)) {
				c.invokeOnce(n, source, target, fn_inferFromGenericMappedTypes);
			}
			if (!((n.priority & InferencePriorityNoConstraints) != 0 && (source.flags & (TypeFlagsIntersection | TypeFlagsInstantiable)) != 0)) {
				final apparentSource = c.getApparentType(source);
				// getApparentType can return _any_ type, since an indexed access or conditional may simplify to any other type.
				// If that occurs and it doesn't simplify to an object or intersection, we'll need to restart `inferFromTypes`
				// with the simplified source.
				if (apparentSource != source && (apparentSource.flags & (TypeFlagsObject | TypeFlagsIntersection)) == 0) {
					c.inferFromTypes(n, apparentSource, target);
					return;
				}
				source = apparentSource;
			}
			if ((source.flags & (TypeFlagsObject | TypeFlagsIntersection)) != 0) {
				c.invokeOnce(n, source, target, fn_inferFromObjectTypes);
			}
		}
	}

	static function inferFromTypeArguments(c:Checker, n:InferenceState, sourceTypes:Array<Type>, targetTypes:Array<Type>, variances:Array<VarianceFlags>):Void {
		n.depth++;
		final count = Std.int(std.Math.min(Core.len(sourceTypes), Core.len(targetTypes)));
		for (i in 0...count) {
			if (i < Core.len(variances) && (variances[i] & VarianceFlagsVarianceMask) == VarianceFlagsContravariant) {
				c.inferFromContravariantTypes(n, sourceTypes[i], targetTypes[i]);
			} else {
				c.inferFromTypes(n, sourceTypes[i], targetTypes[i]);
			}
		}
		n.depth--;
	}

	static function inferWithPriority(c:Checker, n:InferenceState, source:Type, target:Type, newPriority:InferencePriority):Void {
		final savePriority = n.priority;
		n.priority |= newPriority;
		c.inferFromTypes(n, source, target);
		n.priority = savePriority;
	}

	static function inferFromContravariantTypesWithPriority(c:Checker, n:InferenceState, source:Type, target:Type, newPriority:InferencePriority):Void {
		final savePriority = n.priority;
		n.priority |= newPriority;
		c.inferFromContravariantTypes(n, source, target);
		n.priority = savePriority;
	}

	static function inferFromContravariantTypes(c:Checker, n:InferenceState, source:Type, target:Type):Void {
		n.contravariant = !n.contravariant;
		c.inferFromTypes(n, source, target);
		n.contravariant = !n.contravariant;
	}

	static function inferFromContravariantTypesIfStrictFunctionTypes(c:Checker, n:InferenceState, source:Type, target:Type):Void {
		if (c.strictFunctionTypes || (n.priority & InferencePriorityAlwaysStrict) != 0) {
			c.inferFromContravariantTypes(n, source, target);
		} else {
			c.inferFromTypes(n, source, target);
		}
	}

	// Ensure an inference action is performed only once for the given source and target types.
	// This includes two things:
	// Avoiding inferring between the same pair of source and target types,
	// and avoiding circularly inferring between source and target types.
	// For an example of the last, consider if we are inferring between source type
	// `type Deep<T> = { next: Deep<Deep<T>> }` and target type `type Loop<U> = { next: Loop<U> }`.
	// We would then infer between the types of the `next` property: `Deep<Deep<T>>` = `{ next: Deep<Deep<Deep<T>>> }` and `Loop<U>` = `{ next: Loop<U> }`.
	// We will then infer again between the types of the `next` property:
	// `Deep<Deep<Deep<T>>>` and `Loop<U>`, and so on, such that we would be forever inferring
	// between instantiations of the same types `Deep` and `Loop`.
	// In particular, we would be inferring from increasingly deep instantiations of `Deep` to `Loop`,
	// such that we would go on inferring forever, even though we would never infer
	// between the same pair of types.
	static function invokeOnce(c:Checker, n:InferenceState, source:Type, target:Type, action:(c:Checker, n:InferenceState, source:Type, target:Type) -> Void):Void {
		final key = InferenceKey.keyOf(source.id, target.id);
		if (n.visited != null && n.visited.exists(key)) {
			final status = n.visited.get(key);
			n.inferencePriority = minPriority(n.inferencePriority, status);
			return;
		}
		if (n.visited == null) {
			n.visited = new StringMap<InferencePriority>();
		}
		n.visited.set(key, InferencePriorityCircularity);
		final saveInferencePriority = n.inferencePriority;
		n.inferencePriority = InferencePriorityMaxValue;
		// We stop inferring and report a circularity if we encounter duplicate recursion identities on both
		// the source side and the target side.
		final saveExpandingFlags = n.expandingFlags;
		if (n.sourceStack == null) {
			n.sourceStack = [];
		}
		if (n.targetStack == null) {
			n.targetStack = [];
		}
		n.sourceStack.push(source);
		n.targetStack.push(target);
		if (c.isDeeplyNestedType(source, n.sourceStack, 2)) {
			n.expandingFlags |= ExpandingFlagsSource;
		}
		if (c.isDeeplyNestedType(target, n.targetStack, 2)) {
			n.expandingFlags |= ExpandingFlagsTarget;
		}
		if (n.expandingFlags != ExpandingFlagsBoth) {
			action(c, n, source, target);
		} else {
			n.inferencePriority = InferencePriorityCircularity;
		}
		n.targetStack.resize(n.targetStack.length - 1);
		n.sourceStack.resize(n.sourceStack.length - 1);
		n.expandingFlags = saveExpandingFlags;
		n.visited.set(key, n.inferencePriority);
		n.inferencePriority = minPriority(n.inferencePriority, saveInferencePriority);
	}

	static function inferFromMatchingTypes(c:Checker, n:InferenceState, sources:Array<Type>, targets:Array<Type>,
			matches:(c:Checker, s:Type, t:Type) -> Bool):Pair<Array<Type>, Array<Type>> {
		var matchedSources:Array<Type> = null;
		var matchedTargets:Array<Type> = null;
		if (targets != null) {
			for (t in targets) {
				if (sources != null) {
					for (s in sources) {
						if (matches(c, s, t)) {
							c.inferFromTypes(n, s, t);
							matchedSources = Core.AppendIfUnique(matchedSources, s);
							matchedTargets = Core.AppendIfUnique(matchedTargets, t);
						}
					}
				}
			}
		}
		if (Core.len(matchedSources) != 0) {
			sources = Core.Filter(sources, t -> !Slices.Contains(matchedSources, t));
		}
		if (Core.len(matchedTargets) != 0) {
			targets = Core.Filter(targets, t -> !Slices.Contains(matchedTargets, t));
		}
		return new Pair(sources, targets);
	}

	static function inferToMultipleTypes(c:Checker, n:InferenceState, source:Type, targets:Array<Type>, targetFlags:TypeFlags):Void {
		var typeVariableCount = 0;
		if ((targetFlags & TypeFlagsUnion) != 0) {
			var nakedTypeVariable:Type = null;
			var sources:Array<Type>;
			if ((source.flags & TypeFlagsUnion) != 0) {
				sources = source.Types();
			} else {
				sources = [source];
			}
			final matched = [for (_ in 0...sources.length) false];
			var inferenceCircularity = false;
			// First infer to types that are not naked type variables. For each source type we
			// track whether inferences were made from that particular type to some target with
			// equal priority (i.e. of equal quality) to what we would infer for a naked type
			// parameter.
			for (t in targets) {
				if (Checker.getInferenceInfoForType(n, t) != null) {
					nakedTypeVariable = t;
					typeVariableCount++;
				} else {
					for (i in 0...sources.length) {
						final saveInferencePriority = n.inferencePriority;
						n.inferencePriority = InferencePriorityMaxValue;
						c.inferFromTypes(n, sources[i], t);
						if (n.inferencePriority == n.priority) {
							matched[i] = true;
						}
						inferenceCircularity = inferenceCircularity || n.inferencePriority == InferencePriorityCircularity;
						n.inferencePriority = minPriority(n.inferencePriority, saveInferencePriority);
					}
				}
			}
			if (typeVariableCount == 0) {
				// If every target is an intersection of types containing a single naked type variable,
				// make a lower priority inference to that type variable. This handles inferring from
				// 'A | B' to 'T & (X | Y)' where we want to infer 'A | B' for T.
				final intersectionTypeVariable = Checker.getSingleTypeVariableFromIntersectionTypes(n, targets);
				if (intersectionTypeVariable != null) {
					c.inferWithPriority(n, source, intersectionTypeVariable, InferencePriorityNakedTypeVariable);
				}
				return;
			}
			// If the target has a single naked type variable and no inference circularities were
			// encountered above (meaning we explored the types fully), create a union of the source
			// types from which no inferences have been made so far and infer from that union to the
			// naked type variable.
			if (typeVariableCount == 1 && !inferenceCircularity) {
				var unmatched:Array<Type> = null;
				for (i in 0...sources.length) {
					final s = sources[i];
					if (!matched[i]) {
						if (unmatched == null) {
							unmatched = [];
						}
						unmatched.push(s);
					}
				}
				if (Core.len(unmatched) != 0) {
					c.inferFromTypes(n, c.getUnionType(unmatched), nakedTypeVariable);
					return;
				}
			}
		} else {
			// We infer from types that are not naked type variables first so that inferences we
			// make from nested naked type variables and given slightly higher priority by virtue
			// of being first in the candidates array.
			for (t in targets) {
				if (Checker.getInferenceInfoForType(n, t) != null) {
					typeVariableCount++;
				} else {
					c.inferFromTypes(n, source, t);
				}
			}
		}
		// Inferences directly to naked type variables are given lower priority as they are
		// less specific. For example, when inferring from Promise<string> to T | Promise<T>,
		// we want to infer string for T, not Promise<string> | string. For intersection types
		// we only infer to single naked type variables.
		if ((targetFlags & TypeFlagsIntersection) != 0 && typeVariableCount == 1 || (targetFlags & TypeFlagsIntersection) == 0 && typeVariableCount > 0) {
			for (t in targets) {
				if (Checker.getInferenceInfoForType(n, t) != null) {
					c.inferWithPriority(n, source, t, InferencePriorityNakedTypeVariable);
				}
			}
		}
	}

	static function inferToMultipleTypesWithPriority(c:Checker, n:InferenceState, source:Type, targets:Array<Type>, targetFlags:TypeFlags, newPriority:InferencePriority):Void {
		final savePriority = n.priority;
		n.priority |= newPriority;
		c.inferToMultipleTypes(n, source, targets, targetFlags);
		n.priority = savePriority;
	}

	static function inferToConditionalType(c:Checker, n:InferenceState, source:Type, target:Type):Void {
		if ((source.flags & TypeFlagsConditional) != 0) {
			c.inferFromTypes(n, source.AsConditionalType().checkType, target.AsConditionalType().checkType);
			c.inferFromTypes(n, source.AsConditionalType().extendsType, target.AsConditionalType().extendsType);
			c.inferFromTypes(n, c.getTrueTypeFromConditionalType(source), c.getTrueTypeFromConditionalType(target));
			c.inferFromTypes(n, c.getFalseTypeFromConditionalType(source), c.getFalseTypeFromConditionalType(target));
		} else {
			final targetTypes = [c.getTrueTypeFromConditionalType(target), c.getFalseTypeFromConditionalType(target)];
			c.inferToMultipleTypesWithPriority(n, source, targetTypes, target.flags, Core.IfElse(n.contravariant, InferencePriorityContravariantConditional, 0));
		}
	}

	static function inferToTemplateLiteralType(c:Checker, n:InferenceState, source:Type, target:TemplateLiteralType):Void {
		final matches = c.inferTypesFromTemplateLiteralType(source, target);
		final types = target.types;
		// When the target template literal contains only placeholders (meaning that inference is intended to extract
		// single characters and remainder strings) and inference fails to produce matches, we want to infer 'never' for
		// each placeholder such that instantiation with the inferred value(s) produces 'never', a type for which an
		// assignment check will fail. If we make no inferences, we'll likely end up with the constraint 'string' which,
		// upon instantiation, would collapse all the placeholders to just 'string', and an assignment check might
		// succeed. That would be a pointless and confusing outcome.
		if (Core.len(matches) != 0 || Core.Every(target.texts, s -> s == "")) {
			for (i in 0...Core.len(types)) {
				final target = types[i];
				var source:Type;
				if (Core.len(matches) != 0) {
					source = matches[i];
				} else {
					source = c.neverType;
				}
				// If we are inferring from a string literal type to a type variable whose constraint includes one of the
				// allowed template literal placeholder types, infer from a literal type corresponding to the constraint.
				if ((source.flags & TypeFlagsStringLiteral) != 0 && (target.flags & TypeFlagsTypeVariable) != 0) {
					final inferenceContext = Checker.getInferenceInfoForType(n, target);
					if (inferenceContext != null) {
						final constraint = c.getBaseConstraintOfType(inferenceContext.typeParameter);
						if (constraint != null && !Checker.IsTypeAny(constraint)) {
							var allTypeFlags:TypeFlags = TypeFlagsNone;
							for (t in constraint.Distributed()) {
								allTypeFlags |= t.flags;
							}
							// If the constraint contains `string`, we don't need to look for a more preferred type
							if ((allTypeFlags & TypeFlagsString) == 0) {
								final str = Checker.getStringLiteralValue(source);
								// If the type contains `number` or a number literal and the string isn't a valid number, exclude numbers
								if ((allTypeFlags & TypeFlagsNumberLike) != 0 && !Checker.isValidNumberString(str, true /*roundTripOnly*/)) {
									allTypeFlags = allTypeFlags & ~TypeFlagsNumberLike;
								}
								// If the type contains `bigint` or a bigint literal and the string isn't a valid bigint, exclude bigints
								if ((allTypeFlags & TypeFlagsBigIntLike) != 0 && !Checker.isValidBigIntString(str, true /*roundTripOnly*/)) {
									allTypeFlags = allTypeFlags & ~TypeFlagsBigIntLike;
								}
								final choose = function(left:Type, right:Type):Type {
									if ((right.flags & allTypeFlags) == 0) {
										return left;
									} else if ((left.flags & TypeFlagsString) != 0) {
										return left;
									} else if ((right.flags & TypeFlagsString) != 0) {
										return source;
									} else if ((left.flags & TypeFlagsTemplateLiteral) != 0) {
										return left;
									} else if ((right.flags & TypeFlagsTemplateLiteral) != 0
										&& c.isTypeMatchedByTemplateLiteralType(source, right.AsTemplateLiteralType(), c.compareTypesAssignable)) {
										return source;
									} else if ((left.flags & TypeFlagsStringMapping) != 0) {
										return left;
									} else if ((right.flags & TypeFlagsStringMapping) != 0 && str == Checker.applyStringMapping(right.symbol, str)) {
										return source;
									} else if ((left.flags & TypeFlagsStringLiteral) != 0) {
										return left;
									} else if ((right.flags & TypeFlagsStringLiteral) != 0 && Checker.getStringLiteralValue(right) == str) {
										return right;
									} else if ((left.flags & TypeFlagsNumber) != 0) {
										return left;
									} else if ((right.flags & TypeFlagsNumber) != 0) {
										return c.getNumberLiteralType(Jsnum.FromString(str));
									} else if ((left.flags & TypeFlagsEnum) != 0) {
										return left;
									} else if ((right.flags & TypeFlagsEnum) != 0) {
										return c.getNumberLiteralType(Jsnum.FromString(str));
									} else if ((left.flags & TypeFlagsNumberLiteral) != 0) {
										return left;
									} else if ((right.flags & TypeFlagsNumberLiteral) != 0
										&& (Checker.getNumberLiteralValue(right) : Float) == (Jsnum.FromString(str) : Float)) {
										return right;
									} else if ((left.flags & TypeFlagsBigInt) != 0) {
										return left;
									} else if ((right.flags & TypeFlagsBigInt) != 0) {
										return c.parseBigIntLiteralType(str);
									} else if ((left.flags & TypeFlagsBigIntLiteral) != 0) {
										return left;
									} else if ((right.flags & TypeFlagsBigIntLiteral) != 0
										&& Checker.pseudoBigIntToString(Checker.getBigIntLiteralValue(right)) == str) {
										return right;
									} else if ((left.flags & TypeFlagsBoolean) != 0) {
										return left;
									} else if ((right.flags & TypeFlagsBoolean) != 0) {
										if (str == "true") {
											return c.trueType;
										} else if (str == "false") {
											return c.falseType;
										} else {
											return c.booleanType;
										}
									} else if ((left.flags & TypeFlagsBooleanLiteral) != 0) {
										return left;
									} else if ((right.flags & TypeFlagsBooleanLiteral) != 0
										&& Core.IfElse(Checker.getBooleanLiteralValue(right), "true", "false") == str) {
										return right;
									} else if ((left.flags & TypeFlagsUndefined) != 0) {
										return left;
									} else if ((right.flags & TypeFlagsUndefined) != 0 && right.AsIntrinsicType().intrinsicName == str) {
										return right;
									} else if ((left.flags & TypeFlagsNull) != 0) {
										return left;
									} else if ((right.flags & TypeFlagsNull) != 0 && right.AsIntrinsicType().intrinsicName == str) {
										return right;
									} else {
										return left;
									}
								};
								var matchingType = c.neverType;
								for (t in constraint.Distributed()) {
									matchingType = choose(matchingType, t);
								}
								if ((matchingType.flags & TypeFlagsNever) == 0) {
									c.inferFromTypes(n, matchingType, target);
									continue;
								}
							}
						}
					}
				}
				c.inferFromTypes(n, source, target);
			}
		}
	}

	static function inferFromGenericMappedTypes(c:Checker, n:InferenceState, source:Type, target:Type):Void {
		// The source and target types are generic types { [P in S]: X } and { [P in T]: Y }, so we infer
		// from S to T and from X to Y.
		c.inferFromTypes(n, c.getConstraintTypeFromMappedType(source), c.getConstraintTypeFromMappedType(target));
		c.inferFromTypes(n, c.getTemplateTypeFromMappedType(source), c.getTemplateTypeFromMappedType(target));
		final sourceNameType = c.getNameTypeFromMappedType(source);
		final targetNameType = c.getNameTypeFromMappedType(target);
		if (sourceNameType != null && targetNameType != null) {
			c.inferFromTypes(n, sourceNameType, targetNameType);
		}
	}

	static function inferFromObjectTypes(c:Checker, n:InferenceState, source:Type, target:Type):Void {
		if ((source.objectFlags & ObjectFlagsReference) != 0 && (target.objectFlags & ObjectFlagsReference) != 0
			&& (source.Target() == target.Target() || c.isArrayType(source) && c.isArrayType(target))) {
			// If source and target are references to the same generic type, infer from type arguments
			c.inferFromTypeArguments(n, c.getTypeArguments(source), c.getTypeArguments(target), c.getVariances(source.Target()));
			return;
		}
		if (c.isGenericMappedType(source) && c.isGenericMappedType(target)) {
			c.inferFromGenericMappedTypes(n, source, target);
		}
		if ((target.objectFlags & ObjectFlagsMapped) != 0 && target.AsMappedType().declaration.NameType == null) {
			final constraintType = c.getConstraintTypeFromMappedType(target);
			if (c.inferToMappedType(n, source, target, constraintType)) {
				return;
			}
		}
		// Infer from the members of source and target only if the two types are possibly related
		if (c.typesDefinitelyUnrelated(source, target)) {
			return;
		}
		if (c.isArrayOrTupleType(source)) {
			if (Checker.isTupleType(target)) {
				final sourceArity = c.getTypeReferenceArity(source);
				final targetArity = c.getTypeReferenceArity(target);
				final elementTypes = c.getTypeArguments(target);
				final elementInfos = target.TargetTupleType().elementInfos;
				// When source and target are tuple types with the same structure (fixed, variadic, and rest are matched
				// to the same kind in each position), simply infer between the element types.
				if (Checker.isTupleType(source) && c.isTupleTypeStructureMatching(source, target)) {
					for (i in 0...targetArity) {
						c.inferFromTypes(n, c.getTypeArguments(source)[i], elementTypes[i]);
					}
					return;
				}
				var startLength = 0;
				var endLength = 0;
				if (Checker.isTupleType(source)) {
					startLength = Std.int(std.Math.min(source.TargetTupleType().fixedLength, target.TargetTupleType().fixedLength));
					if ((target.TargetTupleType().combinedFlags & ElementFlagsVariable) != 0) {
						endLength = Std.int(std.Math.min(Checker.getEndElementCount(source.TargetTupleType(), ElementFlagsFixed),
							Checker.getEndElementCount(target.TargetTupleType(), ElementFlagsFixed)));
					}
				}
				// Infer between starting fixed elements.
				for (i in 0...startLength) {
					c.inferFromTypes(n, c.getTypeArguments(source)[i], elementTypes[i]);
				}
				if (!Checker.isTupleType(source)
					|| sourceArity - startLength - endLength == 1 && (source.TargetTupleType().elementInfos[startLength].flags & ElementFlagsRest) != 0) {
					// Single rest element remains in source, infer from that to every element in target
					final restType = c.getTypeArguments(source)[startLength];
					for (i in startLength...targetArity - endLength) {
						var t = restType;
						if ((elementInfos[i].flags & ElementFlagsVariadic) != 0) {
							t = c.createArrayType(t);
						}
						c.inferFromTypes(n, t, elementTypes[i]);
					}
				} else {
					final middleLength = targetArity - startLength - endLength;
					if (middleLength == 2) {
						if ((elementInfos[startLength].flags & elementInfos[startLength + 1].flags & ElementFlagsVariadic) != 0) {
							// Middle of target is [...T, ...U] and source is tuple type
							final targetInfo = Checker.getInferenceInfoForType(n, elementTypes[startLength]);
							if (targetInfo != null && targetInfo.impliedArity >= 0) {
								// Infer slices from source based on implied arity of T.
								c.inferFromTypes(n, c.sliceTupleType(source, startLength, endLength + sourceArity - targetInfo.impliedArity), elementTypes[startLength]);
								c.inferFromTypes(n, c.sliceTupleType(source, startLength + targetInfo.impliedArity, endLength), elementTypes[startLength + 1]);
							}
						} else if ((elementInfos[startLength].flags & ElementFlagsVariadic) != 0 && (elementInfos[startLength + 1].flags & ElementFlagsRest) != 0) {
							// Middle of target is [...T, ...rest] and source is tuple type
							// if T is constrained by a fixed-size tuple we might be able to use its arity to infer T
							final info = Checker.getInferenceInfoForType(n, elementTypes[startLength]);
							if (info != null) {
								final constraint = c.getBaseConstraintOfType(info.typeParameter);
								if (constraint != null && Checker.isTupleType(constraint) && (constraint.TargetTupleType().combinedFlags & ElementFlagsVariable) == 0) {
									final impliedArity = constraint.TargetTupleType().fixedLength;
									c.inferFromTypes(n, c.sliceTupleType(source, startLength, sourceArity - (startLength + impliedArity)), elementTypes[startLength]);
									final restType = c.getElementTypeOfSliceOfTupleType(source, startLength + impliedArity, endLength, false, false);
									if (restType != null) {
										c.inferFromTypes(n, restType, elementTypes[startLength + 1]);
									}
								}
							}
						} else if ((elementInfos[startLength].flags & ElementFlagsRest) != 0 && (elementInfos[startLength + 1].flags & ElementFlagsVariadic) != 0) {
							// Middle of target is [...rest, ...T] and source is tuple type
							// if T is constrained by a fixed-size tuple we might be able to use its arity to infer T
							final info = Checker.getInferenceInfoForType(n, elementTypes[startLength + 1]);
							if (info != null) {
								final constraint = c.getBaseConstraintOfType(info.typeParameter);
								if (constraint != null && Checker.isTupleType(constraint) && (constraint.TargetTupleType().combinedFlags & ElementFlagsVariable) == 0) {
									final impliedArity = constraint.TargetTupleType().fixedLength;
									final endIndex = sourceArity - Checker.getEndElementCount(target.TargetTupleType(), ElementFlagsFixed);
									final startIndex = endIndex - impliedArity;
									if (startIndex >= startLength) {
										final trailingSlice = c.createTupleTypeEx(c.getTypeArguments(source).slice(startIndex, endIndex),
											source.TargetTupleType().elementInfos.slice(startIndex, endIndex), false /*readonly*/);
										final restType = c.getElementTypeOfSliceOfTupleType(source, startLength, endLength + impliedArity, false, false);
										if (restType != null) {
											c.inferFromTypes(n, restType, elementTypes[startLength]);
										}
										c.inferFromTypes(n, trailingSlice, elementTypes[startLength + 1]);
									}
								}
							}
						}
					} else if (middleLength == 1 && (elementInfos[startLength].flags & ElementFlagsVariadic) != 0) {
						// Middle of target is exactly one variadic element. Infer the slice between the fixed parts in the source.
						// If target ends in optional element(s), make a lower priority a speculative inference.
						final priority = Core.IfElse((elementInfos[targetArity - 1].flags & ElementFlagsOptional) != 0, InferencePrioritySpeculativeTuple, 0);
						final sourceSlice = c.sliceTupleType(source, startLength, endLength);
						c.inferWithPriority(n, sourceSlice, elementTypes[startLength], priority);
					} else if (middleLength == 1 && (elementInfos[startLength].flags & ElementFlagsRest) != 0) {
						// Middle of target is exactly one rest element. If middle of source is not empty, infer union of middle element types.
						final restType = c.getElementTypeOfSliceOfTupleType(source, startLength, endLength, false, false);
						if (restType != null) {
							c.inferFromTypes(n, restType, elementTypes[startLength]);
						}
					}
				}
				// Infer between ending fixed elements
				for (i in 0...endLength) {
					c.inferFromTypes(n, c.getTypeArguments(source)[sourceArity - i - 1], elementTypes[targetArity - i - 1]);
				}
				return;
			}
			if (c.isArrayType(target)) {
				c.inferFromIndexTypes(n, source, target);
				return;
			}
		}
		c.inferFromProperties(n, source, target);
		c.inferFromSignatures(n, source, target, SignatureKindCall);
		c.inferFromSignatures(n, source, target, SignatureKindConstruct);
		c.inferFromIndexTypes(n, source, target);
	}

	static function inferFromProperties(c:Checker, n:InferenceState, source:Type, target:Type):Void {
		final properties = c.getPropertiesOfObjectType(target);
		if (properties != null) {
			for (targetProp in properties) {
				final sourceProp = c.getPropertyOfType(source, targetProp.Name);
				if (sourceProp != null && !Core.Some(sourceProp.Declarations, node -> c.isSkipDirectInferenceNode(node))) {
					c.inferFromTypes(n, c.removeMissingType(c.getTypeOfSymbol(sourceProp), (sourceProp.Flags & SymbolFlagsOptional) != 0),
						c.removeMissingType(c.getTypeOfSymbol(targetProp), (targetProp.Flags & SymbolFlagsOptional) != 0));
				}
			}
		}
	}

	static function inferFromSignatures(c:Checker, n:InferenceState, source:Type, target:Type, kind:SignatureKind):Void {
		final sourceSignatures = c.getSignaturesOfType(source, kind);
		final sourceLen = Core.len(sourceSignatures);
		if (sourceLen > 0) {
			// We match source and target signatures from the bottom up, and if the source has fewer signatures
			// than the target, we infer from the first source signature to the excess target signatures.
			final targetSignatures = c.getSignaturesOfType(target, kind);
			final targetLen = Core.len(targetSignatures);
			for (i in 0...targetLen) {
				final sourceIndex = Std.int(std.Math.max(sourceLen - targetLen + i, 0));
				c.inferFromSignature(n, c.getBaseSignature(sourceSignatures[sourceIndex]), c.getErasedSignature(targetSignatures[i]));
			}
		}
	}

	static function inferFromSignature(c:Checker, n:InferenceState, source:Signature, target:Signature):Void {
		if ((source.flags & SignatureFlagsIsNonInferrable) == 0) {
			final saveBivariant = n.bivariant;
			var kind = KindUnknown;
			if (target.declaration != null) {
				kind = target.declaration.Kind;
			}
			// Once we descend into a bivariant signature we remain bivariant for all nested inferences
			n.bivariant = n.bivariant || kind == KindMethodDeclaration || kind == KindMethodSignature || kind == KindConstructor;
			c.applyToParameterTypes(source, target, (s, t) -> c.inferFromContravariantTypesIfStrictFunctionTypes(n, s, t));
			n.bivariant = saveBivariant;
		}
		c.applyToReturnTypes(source, target, (s, t) -> c.inferFromTypes(n, s, t));
	}

	static function applyToParameterTypes(c:Checker, source:Signature, target:Signature, callback:(s:Type, t:Type) -> Void):Void {
		final sourceCount = c.getParameterCount(source);
		final targetCount = c.getParameterCount(target);
		final sourceRestType = c.getEffectiveRestType(source);
		final targetRestType = c.getEffectiveRestType(target);
		var targetNonRestCount = targetCount;
		if (targetRestType != null) {
			targetNonRestCount--;
		}
		var paramCount = targetNonRestCount;
		if (sourceRestType == null) {
			paramCount = Std.int(std.Math.min(sourceCount, targetNonRestCount));
		}
		final sourceThisType = c.getThisTypeOfSignature(source);
		if (sourceThisType != null) {
			final targetThisType = c.getThisTypeOfSignature(target);
			if (targetThisType != null) {
				callback(sourceThisType, targetThisType);
			}
		}
		for (i in 0...paramCount) {
			callback(c.getTypeAtPosition(source, i), c.getTypeAtPosition(target, i));
		}
		if (targetRestType != null) {
			callback(c.getRestTypeAtPosition(source, paramCount,
				c.isConstTypeVariable(targetRestType, 0) && !Checker.someType(targetRestType, t -> c.isMutableArrayLikeType(t)) /*readonly*/),
				targetRestType);
		}
	}

	static function applyToReturnTypes(c:Checker, source:Signature, target:Signature, callback:(s:Type, t:Type) -> Void):Void {
		final targetTypePredicate = c.getTypePredicateOfSignature(target);
		if (targetTypePredicate != null) {
			final sourceTypePredicate = c.getTypePredicateOfSignature(source);
			if (sourceTypePredicate != null && c.typePredicateKindsMatch(sourceTypePredicate, targetTypePredicate) && sourceTypePredicate.t != null
				&& targetTypePredicate.t != null) {
				callback(sourceTypePredicate.t, targetTypePredicate.t);
				return;
			}
		}
		final targetReturnType = c.getReturnTypeOfSignature(target);
		if (c.couldContainTypeVariables(targetReturnType)) {
			callback(c.getReturnTypeOfSignature(source), targetReturnType);
		}
	}

	static function inferFromIndexTypes(c:Checker, n:InferenceState, source:Type, target:Type):Void {
		// Inferences across mapped type index signatures are pretty much the same a inferences to homomorphic variables
		var priority = InferencePriorityNone;
		if ((source.objectFlags & target.objectFlags & ObjectFlagsMapped) != 0) {
			priority = InferencePriorityHomomorphicMappedType;
		}
		final indexInfos = c.getIndexInfosOfType(target);
		if (c.isObjectTypeWithInferableIndex(source)) {
			if (indexInfos != null) {
				for (targetInfo in indexInfos) {
					var propTypes:Array<Type> = null;
					final props = c.getPropertiesOfType(source);
					if (props != null) {
						for (prop in props) {
							if (c.isApplicableIndexType(c.getLiteralTypeFromProperty(prop, TypeFlagsStringOrNumberLiteralOrUnique, false), targetInfo.keyType)) {
								var propType = c.getTypeOfSymbol(prop);
								if ((prop.Flags & SymbolFlagsOptional) != 0) {
									propType = c.removeMissingOrUndefinedType(propType);
								}
								if (propTypes == null) {
									propTypes = [];
								}
								propTypes.push(propType);
							}
						}
					}
					final sourceInfos = c.getIndexInfosOfType(source);
					if (sourceInfos != null) {
						for (info in sourceInfos) {
							if (c.isApplicableIndexType(info.keyType, targetInfo.keyType)) {
								if (propTypes == null) {
									propTypes = [];
								}
								propTypes.push(info.valueType);
							}
						}
					}
					if (Core.len(propTypes) != 0) {
						c.inferWithPriority(n, c.getUnionType(propTypes), targetInfo.valueType, priority);
					}
				}
			}
		}
		if (indexInfos != null) {
			for (targetInfo in indexInfos) {
				final sourceInfo = c.getApplicableIndexInfo(source, targetInfo.keyType);
				if (sourceInfo != null) {
					c.inferWithPriority(n, sourceInfo.valueType, targetInfo.valueType, priority);
				}
			}
		}
	}

	static function inferToMappedType(c:Checker, n:InferenceState, source:Type, target:Type, constraintType:Type):Bool {
		if ((constraintType.flags & TypeFlagsUnion) != 0 || (constraintType.flags & TypeFlagsIntersection) != 0) {
			var result = false;
			for (t in constraintType.Types()) {
				result = Core.OrElse(c.inferToMappedType(n, source, target, t), result);
			}
			return result;
		}
		if ((constraintType.flags & TypeFlagsIndex) != 0) {
			// We're inferring from some source type S to a homomorphic mapped type { [P in keyof T]: X },
			// where T is a type variable. Use inferTypeForHomomorphicMappedType to infer a suitable source
			// type and then make a secondary inference from that type to T. We make a secondary inference
			// such that direct inferences to T get priority over inferences to Partial<T>, for example.
			final inference = Checker.getInferenceInfoForType(n, constraintType.AsIndexType().target);
			if (inference != null && !inference.isFixed && !c.isFromInferenceBlockedSource(source)) {
				final inferredType = c.inferTypeForHomomorphicMappedType(source, target, constraintType);
				if (inferredType != null) {
					// We assign a lower priority to inferences made from types containing non-inferrable
					// types because we may only have a partial result (i.e. we may have failed to make
					// reverse inferences for some properties).
					c.inferWithPriority(n, inferredType, inference.typeParameter,
						Core.IfElse((source.objectFlags & ObjectFlagsNonInferrableType) != 0, InferencePriorityPartialHomomorphicMappedType,
							InferencePriorityHomomorphicMappedType));
				}
			}
			return true;
		}
		if ((constraintType.flags & TypeFlagsTypeParameter) != 0) {
			// We're inferring from some source type S to a mapped type { [P in K]: X }, where K is a type
			// parameter. First infer from 'keyof S' to K.
			c.inferWithPriority(n, c.getIndexTypeEx(source, Core.IfElse(c.patternForType.get(source) != null, IndexFlagsNoIndexSignatures, IndexFlagsNone)),
				constraintType, InferencePriorityMappedTypeConstraint);
			// If K is constrained to a type C, also infer to C. Thus, for a mapped type { [P in K]: X },
			// where K extends keyof T, we make the same inferences as for a homomorphic mapped type
			// { [P in keyof T]: X }. This enables us to make meaningful inferences when the target is a
			// Pick<T, K>.
			final extendedConstraint = c.getConstraintOfType(constraintType);
			if (extendedConstraint != null && c.inferToMappedType(n, source, target, extendedConstraint)) {
				return true;
			}
			// If no inferences can be made to K's constraint, infer from a union of the property types
			// in the source to the template type X.
			final propTypes = Core.Map(c.getPropertiesOfType(source), s -> c.getTypeOfSymbol(s));
			final indexTypes = Core.Map(c.getIndexInfosOfType(source), function(info:IndexInfo):Type {
				if (info != c.enumNumberIndexInfo) {
					return info.valueType;
				}
				return c.neverType;
			});
			c.inferFromTypes(n, c.getUnionType(Core.Concatenate(propTypes, indexTypes)), c.getTemplateTypeFromMappedType(target));
			return true;
		}
		return false;
	}

	// Infer a suitable input type for a homomorphic mapped type { [P in keyof T]: X }. We construct
	// an object type with the same set of properties as the source type, where the type of each
	// property is computed by inferring from the source property type to X for the type
	// variable T[P] (i.e. we treat the type T[P] as the type variable we're inferring for).
	static function inferTypeForHomomorphicMappedType(c:Checker, source:Type, target:Type, constraint:Type):Type {
		final key = ReverseMappedTypeKey.keyOf(source.id, target.id, constraint.id);
		final cached = c.reverseHomomorphicMappedCache.get(key);
		if (cached != null) {
			return cached;
		}
		final t = c.createReverseMappedType(source, target, constraint);
		c.reverseHomomorphicMappedCache.set(key, t);
		return t;
	}

	static function createReverseMappedType(c:Checker, source:Type, target:Type, constraint:Type):Type {
		// We consider a source type reverse mappable if it has a string index signature or if
		// it has one or more properties and is of a partially inferable type.
		if (!(c.getIndexInfoOfType(source, c.stringType) != null || Core.len(c.getPropertiesOfType(source)) != 0 && c.isPartiallyInferableType(source))) {
			return null;
		}
		// For arrays and tuples we infer new arrays and tuples where the reverse mapping has been
		// applied to the element type(s).
		if (c.isArrayType(source)) {
			final elementType = c.inferReverseMappedType(c.getTypeArguments(source)[0], target, constraint);
			if (elementType == null) {
				return null;
			}
			return c.createArrayTypeEx(elementType, c.isReadonlyArrayType(source));
		}
		if (Checker.isTupleType(source)) {
			final elementTypes = Core.Map(c.getElementTypes(source), function(t:Type):Type {
				return c.inferReverseMappedType(t, target, constraint);
			});
			if (!Core.Every(elementTypes, t -> t != null)) {
				return null;
			}
			var elementInfos = source.TargetTupleType().elementInfos;
			if ((Checker.getMappedTypeModifiers(target) & MappedTypeModifiersIncludeOptional) != 0) {
				elementInfos = Core.SameMap(elementInfos, function(info:TupleElementInfo):TupleElementInfo {
					if ((info.flags & ElementFlagsOptional) != 0) {
						final result = new TupleElementInfo();
						result.flags = ElementFlagsRequired;
						result.labeledDeclaration = info.labeledDeclaration;
						return result;
					}
					return info;
				});
			}
			return c.createTupleTypeEx(elementTypes, elementInfos, source.TargetTupleType().readonly);
		}
		// For all other object types we infer a new object type where the reverse mapping has been
		// applied to the type of each property.
		final reversed = c.newObjectType(ObjectFlagsReverseMapped | ObjectFlagsAnonymous, null /*symbol*/);
		reversed.AsReverseMappedType().source = source;
		reversed.AsReverseMappedType().mappedType = target;
		reversed.AsReverseMappedType().constraintType = constraint;
		return reversed;
	}

	// We consider a type to be partially inferable if it isn't marked non-inferable or if it is
	// an object literal type with at least one property of an inferable type. For example, an object
	// literal { a: 123, b: x => true } is marked non-inferable because it contains a context sensitive
	// arrow function, but is considered partially inferable because property 'a' has an inferable type.
	static function isPartiallyInferableType(c:Checker, t:Type):Bool {
		return (t.objectFlags & ObjectFlagsNonInferrableType) == 0
			|| Checker.isObjectLiteralType(t) && Core.Some(c.getPropertiesOfType(t), function(prop:Symbol):Bool {
				return c.isPartiallyInferableType(c.getTypeOfSymbol(prop));
			})
			|| Checker.isTupleType(t) && Core.Some(c.getElementTypes(t), t -> c.isPartiallyInferableType(t));
	}

	static function inferReverseMappedType(c:Checker, source:Type, target:Type, constraint:Type):Type {
		final key = ReverseMappedTypeKey.keyOf(source.id, target.id, constraint.id);
		if (c.reverseMappedCache.exists(key)) {
			return Core.OrElse(c.reverseMappedCache.get(key), c.unknownType);
		}
		if (c.reverseMappedSourceStack == null) {
			c.reverseMappedSourceStack = [];
		}
		if (c.reverseMappedTargetStack == null) {
			c.reverseMappedTargetStack = [];
		}
		c.reverseMappedSourceStack.push(source);
		c.reverseMappedTargetStack.push(target);
		final saveExpandingFlags = c.reverseExpandingFlags;
		if (c.isDeeplyNestedType(source, c.reverseMappedSourceStack, 2)) {
			c.reverseExpandingFlags |= ExpandingFlagsSource;
		}
		if (c.isDeeplyNestedType(target, c.reverseMappedTargetStack, 2)) {
			c.reverseExpandingFlags |= ExpandingFlagsTarget;
		}
		var t:Type = null;
		if (c.reverseExpandingFlags != ExpandingFlagsBoth) {
			t = c.inferReverseMappedTypeWorker(source, target, constraint);
		}
		c.reverseMappedSourceStack.resize(c.reverseMappedSourceStack.length - 1);
		c.reverseMappedTargetStack.resize(c.reverseMappedTargetStack.length - 1);
		c.reverseExpandingFlags = saveExpandingFlags;
		c.reverseMappedCache.set(key, t);
		return t;
	}

	static function inferReverseMappedTypeWorker(c:Checker, source:Type, target:Type, constraint:Type):Type {
		final typeParameter = c.getIndexedAccessType(constraint.AsIndexType().target, c.getTypeParameterFromMappedType(target));
		final templateType = c.getTemplateTypeFromMappedType(target);
		final inference = Checker.newInferenceInfo(typeParameter);
		c.inferTypes([inference], source, templateType, InferencePriorityNone, false);
		return c.getWidenedType(Core.OrElse(c.getTypeFromInference(inference), c.unknownType));
	}

	static function resolveReverseMappedTypeMembers(c:Checker, t:Type):Void {
		final r = t.AsReverseMappedType();
		final indexInfo = c.getIndexInfoOfType(r.source, c.stringType);
		final modifiers = Checker.getMappedTypeModifiers(r.mappedType);
		final readonlyMask = (modifiers & MappedTypeModifiersIncludeReadonly) == 0;
		final optionalMask:SymbolFlags = Core.IfElse((modifiers & MappedTypeModifiersIncludeOptional) != 0, 0, SymbolFlagsOptional);
		var indexInfos:Array<IndexInfo> = null;
		if (indexInfo != null) {
			indexInfos = [
				c.newIndexInfo(c.stringType, Core.OrElse(c.inferReverseMappedType(indexInfo.valueType, r.mappedType, r.constraintType), c.unknownType),
					readonlyMask && indexInfo.isReadonly, null, null)
			];
		}
		final members:SymbolTable = new StringMap<Symbol>();
		final limitedConstraint = c.getLimitedConstraint(t);
		final props = c.getPropertiesOfType(r.source);
		if (props != null) {
			for (prop in props) {
				// In case of a reverse mapped type with an intersection constraint, if we were able to
				// extract the filtering type literals we skip those properties that are not assignable to them,
				// because the extra properties wouldn't get through the application of the mapped type anyway
				if (limitedConstraint != null) {
					final propertyNameType = c.getLiteralTypeFromProperty(prop, TypeFlagsStringOrNumberLiteralOrUnique, false);
					if (!c.isTypeAssignableTo(propertyNameType, limitedConstraint)) {
						continue;
					}
				}
				final checkFlags = CheckFlagsReverseMapped | Core.IfElse(readonlyMask && c.isReadonlySymbol(prop), CheckFlagsReadonly, 0);
				final inferredProp = c.newSymbolEx(SymbolFlagsProperty | (prop.Flags & optionalMask), prop.Name, checkFlags);
				inferredProp.Declarations = prop.Declarations;
				c.valueSymbolLinks.Get(inferredProp).nameType = c.valueSymbolLinks.Get(prop).nameType;
				final links = c.ReverseMappedSymbolLinks.Get(inferredProp);
				links.propertyType = c.getTypeOfSymbol(prop);
				final constraintTarget = r.constraintType.AsIndexType().target;
				if ((constraintTarget.flags & TypeFlagsIndexedAccess) != 0
					&& (constraintTarget.AsIndexedAccessType().objectType.flags & TypeFlagsTypeParameter) != 0
					&& (constraintTarget.AsIndexedAccessType().indexType.flags & TypeFlagsTypeParameter) != 0) {
					// A reverse mapping of `{[K in keyof T[K_1]]: T[K_1]}` is the same as that of `{[K in keyof T]: T}`, since all we care about is
					// inferring to the "type parameter" (or indexed access) shared by the constraint and template. So, to reduce the number of
					// type identities produced, we simplify such indexed access occurrences
					final newTypeParam = constraintTarget.AsIndexedAccessType().objectType;
					final newMappedType = c.replaceIndexedAccess(r.mappedType, constraintTarget, newTypeParam);
					links.mappedType = newMappedType;
					links.constraintType = c.getIndexType(newTypeParam);
				} else {
					links.mappedType = r.mappedType;
					links.constraintType = r.constraintType;
				}
				members.set(prop.Name, inferredProp);
			}
		}
		c.setStructuredTypeMembers(t, members, null, null, indexInfos);
	}

	static function getTypeOfReverseMappedSymbol(c:Checker, symbol:Symbol):Type {
		final links = c.valueSymbolLinks.Get(symbol);
		if (links.resolvedType == null) {
			final reverseLinks = c.ReverseMappedSymbolLinks.Get(symbol);
			links.resolvedType = Core.OrElse(c.inferReverseMappedType(reverseLinks.propertyType, reverseLinks.mappedType, reverseLinks.constraintType), c.unknownType);
		}
		return links.resolvedType;
	}

	// If the original mapped type had an intersection constraint we extract its components,
	// and we make an attempt to do so even if the intersection has been reduced to a union.
	// This entire process allows us to possibly retrieve the filtering type literals.
	// e.g. { [K in keyof U & ("a" | "b") ] } -> "a" | "b"
	static function getLimitedConstraint(c:Checker, t:Type):Type {
		final constraint = c.getConstraintTypeFromMappedType(t.AsReverseMappedType().mappedType);
		if (!((constraint.flags & TypeFlagsUnion) != 0 || (constraint.flags & TypeFlagsIntersection) != 0)) {
			return null;
		}
		var origin = constraint;
		if ((constraint.flags & TypeFlagsUnion) != 0) {
			origin = constraint.AsUnionType().origin;
		}
		if (origin == null || (origin.flags & TypeFlagsIntersection) == 0) {
			return null;
		}
		final constraintType = t.AsReverseMappedType().constraintType;
		final limitedConstraint = c.getIntersectionType(Core.Filter(origin.Types(), t -> t != constraintType));
		if (limitedConstraint != c.neverType) {
			return limitedConstraint;
		}
		return null;
	}

	static function replaceIndexedAccess(c:Checker, instantiable:Type, t:Type, replacement:Type):Type {
		// map type.indexType to 0
		// map type.objectType to `[TReplacement]`
		// thus making the indexed access `[TReplacement][0]` or `TReplacement`
		return c.instantiateType(instantiable,
			Checker.newTypeMapper([t.AsIndexedAccessType().indexType, t.AsIndexedAccessType().objectType],
				[c.getNumberLiteralType(0), c.createTupleType([replacement])]));
	}

	static function typesDefinitelyUnrelated(c:Checker, source:Type, target:Type):Bool {
		// Two tuple types with incompatible arities are definitely unrelated.
		// Two object types that each have a property that is unmatched in the other are definitely unrelated.
		if (Checker.isTupleType(source) && Checker.isTupleType(target)) {
			return Checker.tupleTypesDefinitelyUnrelated(source, target);
		}
		return c.getUnmatchedProperty(source, target, false /*requireOptionalProperties*/, true /*matchDiscriminantProperties*/) != null
			&& c.getUnmatchedProperty(target, source, false /*requireOptionalProperties*/, false /*matchDiscriminantProperties*/) != null;
	}

	static function isTupleTypeStructureMatching(c:Checker, t1:Type, t2:Type):Bool {
		if (c.getTypeReferenceArity(t1) != c.getTypeReferenceArity(t2)) {
			return false;
		}
		final elementInfos = t1.TargetTupleType().elementInfos;
		for (i in 0...Core.len(elementInfos)) {
			final e = elementInfos[i];
			if ((e.flags & ElementFlagsVariable) != (t2.TargetTupleType().elementInfos[i].flags & ElementFlagsVariable)) {
				return false;
			}
		}
		return true;
	}

	static function isTypeOrBaseIdenticalTo(c:Checker, s:Type, t:Type):Bool {
		if (t == c.missingType) {
			return s == t;
		}
		return c.isTypeIdenticalTo(s, t)
			|| (t.flags & TypeFlagsString) != 0 && (s.flags & TypeFlagsStringLiteral) != 0
			|| (t.flags & TypeFlagsNumber) != 0 && (s.flags & TypeFlagsNumberLiteral) != 0;
	}

	static function isTypeCloselyMatchedBy(c:Checker, s:Type, t:Type):Bool {
		return (s.flags & TypeFlagsObject) != 0 && (t.flags & TypeFlagsObject) != 0 && s.symbol != null && s.symbol == t.symbol
			|| s.alias != null && t.alias != null && Core.len(s.alias.typeArguments) != 0 && s.alias.symbol == t.alias.symbol;
	}

	// Create an object with properties named in the string literal type. Every property has type `any`.
	static function createEmptyObjectTypeFromStringLiteral(c:Checker, t:Type):Type {
		final members:SymbolTable = new StringMap<Symbol>();
		for (t in t.Distributed()) {
			if ((t.flags & TypeFlagsStringLiteral) == 0) {
				continue;
			}
			final name = Checker.getStringLiteralValue(t);
			final literalProp = c.newSymbol(SymbolFlagsProperty, name);
			c.valueSymbolLinks.Get(literalProp).resolvedType = c.anyType;
			if (t.symbol != null) {
				literalProp.Declarations = t.symbol.Declarations;
				literalProp.ValueDeclaration = t.symbol.ValueDeclaration;
			}
			members.set(name, literalProp);
		}
		var indexInfos:Array<IndexInfo> = null;
		if ((t.flags & TypeFlagsString) != 0) {
			indexInfos = [c.newIndexInfo(c.stringType, c.emptyObjectType, false /*isReadonly*/, null, null)];
		}
		return c.newAnonymousType(null, members, null, null, indexInfos);
	}

	static function newInferenceContext(c:Checker, typeParameters:Array<Type>, signature:Signature, flags:InferenceFlags, compareTypes:TypeComparer):InferenceContext {
		if (compareTypes == null) {
			compareTypes = c.compareTypesAssignable;
		}
		return c.newInferenceContextWorker(Core.Map(typeParameters, Checker.newInferenceInfo), signature, flags, compareTypes);
	}

	static function cloneInferenceContext(c:Checker, n:InferenceContext, extraFlags:InferenceFlags):InferenceContext {
		if (n == null) {
			return null;
		}
		return c.newInferenceContextWorker(Core.Map(n.inferences, Checker.cloneInferenceInfo), n.signature, n.flags | extraFlags, n.compareTypes);
	}

	static function cloneInferredPartOfContext(c:Checker, n:InferenceContext):InferenceContext {
		final inferences = Core.Filter(n.inferences, Checker.hasInferenceCandidates);
		if (Core.len(inferences) == 0) {
			return null;
		}
		return c.newInferenceContextWorker(Core.Map(inferences, Checker.cloneInferenceInfo), n.signature, n.flags, n.compareTypes);
	}

	static function newInferenceContextWorker(c:Checker, inferences:Array<InferenceInfo>, signature:Signature, flags:InferenceFlags, compareTypes:TypeComparer):InferenceContext {
		final n = new InferenceContext();
		n.inferences = inferences;
		n.signature = signature;
		n.flags = flags;
		n.compareTypes = compareTypes;
		n.mapper = c.newInferenceTypeMapper(n, true /*fixing*/);
		n.nonFixingMapper = c.newInferenceTypeMapper(n, false /*fixing*/);
		return n;
	}

	static function addIntraExpressionInferenceSite(c:Checker, n:InferenceContext, node:Node, t:Type):Void {
		final site = new IntraExpressionInferenceSite();
		site.node = node;
		site.t = t;
		if (n.intraExpressionInferenceSites == null) {
			n.intraExpressionInferenceSites = [];
		}
		n.intraExpressionInferenceSites.push(site);
	}

	// We collect intra-expression inference sites within object and array literals to handle cases where
	// inferred types flow between context sensitive element expressions. For example:
	//
	//	declare function foo<T>(arg: [(n: number) => T, (x: T) => void]): void;
	//	foo([_a => 0, n => n.toFixed()]);
	//
	// Above, both arrow functions in the tuple argument are context sensitive, thus both are omitted from the
	// pass that collects inferences from the non-context sensitive parts of the arguments. In the subsequent
	// pass where nothing is omitted, we need to commit to an inference for T in order to contextually type the
	// parameter in the second arrow function, but we want to first infer from the return type of the first
	// arrow function. This happens automatically when the arrow functions are discrete arguments (because we
	// infer from each argument before processing the next), but when the arrow functions are elements of an
	// object or array literal, we need to perform intra-expression inferences early.
	static function inferFromIntraExpressionSites(c:Checker, n:InferenceContext):Void {
		if (n.intraExpressionInferenceSites != null) {
			for (site in n.intraExpressionInferenceSites) {
				var contextualType:Type;
				if (Ast.IsMethodDeclaration(site.node)) {
					contextualType = c.getContextualTypeForObjectLiteralMethod(site.node, ContextFlagsNoConstraints);
				} else {
					contextualType = c.getContextualType(site.node, ContextFlagsNoConstraints);
				}
				if (contextualType != null) {
					c.inferTypes(n.inferences, site.t, contextualType, InferencePriorityNone, false);
				}
			}
		}
		n.intraExpressionInferenceSites = null;
	}

	static function getInferredType(c:Checker, n:InferenceContext, index:Int):Type {
		final inference = n.inferences[index];
		if (inference.inferredType == null) {
			if (inference.typeParameter == c.errorType) {
				return inference.typeParameter;
			}
			var inferredType:Type = null;
			var fallbackType:Type = null;
			if (n.signature != null) {
				var inferredCovariantType:Type = null;
				if (Core.len(inference.candidates) != 0) {
					inferredCovariantType = c.getCovariantInference(inference, n.signature);
				}
				var inferredContravariantType:Type = null;
				if (Core.len(inference.contraCandidates) != 0) {
					inferredContravariantType = c.getContravariantInference(inference);
				}
				if (inferredCovariantType != null || inferredContravariantType != null) {
					// If we have both co- and contra-variant inferences, we prefer the co-variant inference if it is not 'never',
					// all co-variant inferences are assignable to it (i.e. it isn't one of a conflicting set of candidates), it is
					// assignable to some contra-variant inference, and no other type parameter is constrained to this type parameter
					// and has inferences that would conflict. Otherwise, we prefer the contra-variant inference.
					// Similarly ignore co-variant `any` inference when both are available as almost everything is assignable to it
					// and it would spoil the overall inference.
					final preferCovariantType = inferredCovariantType != null
						&& (inferredContravariantType == null
							|| (inferredCovariantType.flags & (TypeFlagsNever | TypeFlagsAny)) == 0
							&& Core.Some(inference.contraCandidates, t -> c.isTypeAssignableTo(inferredCovariantType, t))
							&& Core.Every(n.inferences, function(other:InferenceInfo):Bool {
								return other != inference && c.getConstraintOfTypeParameter(other.typeParameter) != inference.typeParameter
									|| Core.Every(other.candidates, t -> c.isTypeAssignableTo(t, inferredCovariantType));
							}));
					if (preferCovariantType) {
						inferredType = inferredCovariantType;
						fallbackType = inferredContravariantType;
					} else {
						inferredType = inferredContravariantType;
						fallbackType = inferredCovariantType;
					}
				} else if ((n.flags & InferenceFlagsNoDefault) != 0) {
					// We use silentNeverType as the wildcard that signals no inferences.
					inferredType = c.silentNeverType;
				} else {
					// Infer either the default or the empty object type when no inferences were
					// made. It is important to remember that in this case, inference still
					// succeeds, meaning there is no error for not having inference candidates. An
					// inference error only occurs when there are *conflicting* candidates, i.e.
					// candidates with no common supertype.
					final defaultType = c.getDefaultFromTypeParameter(inference.typeParameter);
					if (defaultType != null) {
						// Instantiate the default type. Any forward reference to a type
						// parameter should be instantiated to the empty object type.
						inferredType = c.instantiateType(defaultType, Checker.mergeTypeMappers(c.newBackreferenceMapper(n, index), n.nonFixingMapper));
					}
				}
			} else {
				inferredType = c.getTypeFromInference(inference);
			}
			inference.inferredType = inferredType;
			if (inference.inferredType == null) {
				inference.inferredType = Core.IfElse((n.flags & InferenceFlagsAnyDefault) != 0, c.anyType, c.unknownType);
			}
			final constraint = c.getConstraintOfTypeParameter(inference.typeParameter);
			if (constraint != null) {
				final instantiatedConstraint = c.instantiateType(constraint, n.nonFixingMapper);
				if (inferredType != null) {
					final constraintWithThis = c.getTypeWithThisArgument(instantiatedConstraint, inferredType, false);
					if (n.compareTypes(inferredType, constraintWithThis, false) == TernaryFalse) {
						var filteredByConstraint:Type = null;
						if (inference.priority == InferencePriorityReturnType) {
							// If we have a pure return type inference, we may succeed by removing constituents of the inferred type
							// that aren't assignable to the constraint type (pure return type inferences are speculation anyway).
							filteredByConstraint = c.mapType(inferredType, function(t:Type):Type {
								return Core.IfElse(n.compareTypes(t, constraintWithThis, false) != TernaryFalse, t, c.neverType);
							});
						}
						inferredType = Core.IfElse(filteredByConstraint != null && (filteredByConstraint.flags & TypeFlagsNever) == 0, filteredByConstraint, null);
					}
				}
				if (inferredType == null) {
					// If the fallback type satisfies the constraint, we pick it. Otherwise, we pick the constraint.
					inferredType = Core.IfElse(fallbackType != null
						&& n.compareTypes(fallbackType, c.getTypeWithThisArgument(instantiatedConstraint, fallbackType, false), false) != TernaryFalse,
						fallbackType, instantiatedConstraint);
				}
				inference.inferredType = inferredType;
			}
			c.clearActiveMapperCaches();
		}
		return inference.inferredType;
	}

	static function getInferredTypes(c:Checker, n:InferenceContext):Array<Type> {
		final result = new Array<Type>();
		result.resize(n.inferences.length);
		for (i in 0...n.inferences.length) {
			result[i] = c.getInferredType(n, i);
		}
		return result;
	}

	static function getMapperFromContext(c:Checker, n:InferenceContext):TypeMapper {
		if (n == null) {
			return null;
		}
		return n.mapper;
	}

	// Return a type mapper that combines the context's return mapper with a mapper that erases any additional type parameters
	// to their inferences at the time of creation.
	static function createOuterReturnMapper(c:Checker, context:InferenceContext):TypeMapper {
		if (context.outerReturnMapper == null) {
			var mapper = c.cloneInferenceContext(context, InferenceFlagsNone).mapper;
			if (context.returnMapper != null) {
				mapper = Checker.newMergedTypeMapper(context.returnMapper, mapper);
			}
			context.outerReturnMapper = mapper;
		}
		return context.outerReturnMapper;
	}

	static function getCovariantInference(c:Checker, inference:InferenceInfo, signature:Signature):Type {
		// Extract all object and array literal types and replace them with a single widened and normalized type.
		final candidates = c.unionObjectAndArrayLiteralCandidates(inference.candidates);
		// We widen inferred literal types if
		// all inferences were made to top-level occurrences of the type parameter, and
		// the type parameter has no constraint or its constraint includes no primitive or literal types, and
		// the type parameter was fixed during inference or does not occur at top-level in the return type.
		final primitiveConstraint = c.hasPrimitiveConstraint(inference.typeParameter) || c.isConstTypeVariable(inference.typeParameter, 0);
		final widenLiteralTypes = !primitiveConstraint && inference.topLevel
			&& (inference.isFixed || !c.isTypeParameterAtTopLevelInReturnType(signature, inference.typeParameter));
		var baseCandidates:Array<Type>;
		if (primitiveConstraint) {
			baseCandidates = Core.SameMap(candidates, t -> c.getRegularTypeOfLiteralType(t));
		} else if (widenLiteralTypes) {
			baseCandidates = Core.SameMap(candidates, t -> c.getWidenedLiteralType(t));
		} else {
			baseCandidates = candidates;
		}
		// If all inferences were made from a position that implies a combined result, infer a union type.
		// Otherwise, infer a common supertype.
		var unwidenedType:Type;
		if ((inference.priority & InferencePriorityPriorityImpliesCombination) != 0) {
			unwidenedType = c.getUnionTypeEx(baseCandidates, UnionReductionSubtype, null, null);
		} else {
			unwidenedType = c.getCommonSupertype(baseCandidates);
		}
		return c.getWidenedType(unwidenedType);
	}

	static function getContravariantInference(c:Checker, inference:InferenceInfo):Type {
		if ((inference.priority & InferencePriorityPriorityImpliesCombination) != 0) {
			return c.getIntersectionType(inference.contraCandidates);
		}
		return c.getCommonSubtype(inference.contraCandidates);
	}

	static function unionObjectAndArrayLiteralCandidates(c:Checker, candidates:Array<Type>):Array<Type> {
		if (Core.len(candidates) > 1) {
			final objectLiterals = Core.Filter(candidates, Checker.isObjectOrArrayLiteralType);
			if (Core.len(objectLiterals) != 0) {
				final literalsType = c.getUnionTypeEx(objectLiterals, UnionReductionSubtype, null, null);
				final nonLiteralTypes = Core.Filter(candidates, t -> !Checker.isObjectOrArrayLiteralType(t));
				return Core.Concatenate(nonLiteralTypes, [literalsType]);
			}
		}
		return candidates;
	}

	static function hasPrimitiveConstraint(c:Checker, t:Type):Bool {
		var constraint = c.getConstraintOfTypeParameter(t);
		if (constraint != null) {
			if ((constraint.flags & TypeFlagsConditional) != 0) {
				constraint = c.getDefaultConstraintOfConditionalType(constraint);
			}
			return c.maybeTypeOfKind(constraint, TypeFlagsPrimitive | TypeFlagsIndex | TypeFlagsTemplateLiteral | TypeFlagsStringMapping);
		}
		return false;
	}

	static function isTypeParameterAtTopLevel(c:Checker, t:Type, tp:Type, depth:Int):Bool {
		return t == tp
			|| (t.flags & TypeFlagsUnionOrIntersection) != 0 && Core.Some(t.Types(), t -> c.isTypeParameterAtTopLevel(t, tp, depth))
			|| depth < 3 && (t.flags & TypeFlagsConditional) != 0
			&& (c.isTypeParameterAtTopLevel(c.getTrueTypeFromConditionalType(t), tp, depth + 1)
				|| c.isTypeParameterAtTopLevel(c.getFalseTypeFromConditionalType(t), tp, depth + 1));
	}

	static function isTypeParameterAtTopLevelInReturnType(c:Checker, signature:Signature, typeParameter:Type):Bool {
		final typePredicate = c.getTypePredicateOfSignature(signature);
		if (typePredicate != null) {
			return typePredicate.t != null && c.isTypeParameterAtTopLevel(typePredicate.t, typeParameter, 0);
		}
		return c.isTypeParameterAtTopLevel(c.getReturnTypeOfSignature(signature), typeParameter, 0);
	}

	static function getTypeFromInference(c:Checker, inference:InferenceInfo):Type {
		if (Core.len(inference.candidates) != 0) {
			return c.getUnionTypeEx(inference.candidates, UnionReductionSubtype, null, null);
		} else if (Core.len(inference.contraCandidates) != 0) {
			return c.getIntersectionType(inference.contraCandidates);
		}
		return null;
	}

	static function getCommonSupertype(c:Checker, types:Array<Type>):Type {
		if (Core.len(types) == 1) {
			return types[0];
		}
		// Remove nullable types from each of the candidates.
		var primaryTypes = types;
		if (c.strictNullChecks) {
			primaryTypes = Core.SameMap(types, function(t:Type):Type {
				return c.filterType(t, u -> (u.flags & TypeFlagsNullable) == 0);
			});
		}
		// When the candidate types are all literal types with the same base type, return a union
		// of those literal types. Otherwise, return the leftmost type for which no type to the
		// right is a supertype.
		var supertype:Type;
		if (c.literalTypesWithSameBaseType(primaryTypes)) {
			supertype = c.getUnionType(primaryTypes);
		} else {
			supertype = c.getSingleCommonSupertype(primaryTypes);
		}
		// Add any nullable types that occurred in the candidates back to the result.
		if (Core.Same(primaryTypes, types)) {
			return supertype;
		}
		return c.getNullableType(supertype, c.getCombinedTypeFlags(types) & TypeFlagsNullable);
	}

	static function getSingleCommonSupertype(c:Checker, types:Array<Type>):Type {
		// First, find the leftmost type for which no type to the right is a strict supertype, and if that
		// type is a strict supertype of all other candidates, return it. Otherwise, return the leftmost type
		// for which no type to the right is a (regular) supertype.
		final candidate = c.findLeftmostType(types, fn_isTypeStrictSubtypeOf);
		if (Core.Every(types, t -> t == candidate || c.isTypeStrictSubtypeOf(t, candidate))) {
			return candidate;
		}
		return c.findLeftmostType(types, fn_isTypeSubtypeOf);
	}

	static function findLeftmostType(c:Checker, types:Array<Type>, f:(c:Checker, s:Type, t:Type) -> Bool):Type {
		var candidate:Type = null;
		if (types != null) {
			for (t in types) {
				if (candidate == null || f(c, candidate, t)) {
					candidate = t;
				}
			}
		}
		return candidate;
	}

	// Return the leftmost type for which no type to the right is a subtype.
	static function getCommonSubtype(c:Checker, types:Array<Type>):Type {
		var subtype:Type = null;
		if (types != null) {
			for (t in types) {
				if (subtype == null || c.isTypeSubtypeOf(t, subtype)) {
					subtype = t;
				}
			}
		}
		return subtype;
	}

	static function getCombinedTypeFlags(c:Checker, types:Array<Type>):TypeFlags {
		var flags:TypeFlags = TypeFlagsNone;
		if (types != null) {
			for (t in types) {
				if ((t.flags & TypeFlagsUnion) != 0) {
					flags |= c.getCombinedTypeFlags(t.Types());
				} else {
					flags |= t.flags;
				}
			}
		}
		return flags;
	}

	static function literalTypesWithSameBaseType(c:Checker, types:Array<Type>):Bool {
		var commonBaseType:Type = null;
		if (types != null) {
			for (t in types) {
				if ((t.flags & TypeFlagsNever) == 0) {
					final baseType = c.getBaseTypeOfLiteralType(t);
					if (commonBaseType == null) {
						commonBaseType = baseType;
					}
					if (baseType == t || baseType != commonBaseType) {
						return false;
					}
				}
			}
		}
		return true;
	}

	static function isFromInferenceBlockedSource(c:Checker, t:Type):Bool {
		return t.symbol != null && Core.Some(t.symbol.Declarations, node -> c.isSkipDirectInferenceNode(node));
	}

	static function isSkipDirectInferenceNode(c:Checker, node:Node):Bool {
		return c.skipDirectInferenceNodes.Has(node);
	}

	static function mergeInferences(c:Checker, target:Array<InferenceInfo>, source:Array<InferenceInfo>):Void {
		for (i in 0...Core.len(target)) {
			if (!Checker.hasInferenceCandidates(target[i]) && Checker.hasInferenceCandidates(source[i])) {
				target[i] = source[i];
			}
		}
	}
}
