package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/relater.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

enum abstract SignatureCheckMode(Int) from Int to Int {
	@:op(A | B) static function or(a:SignatureCheckMode, b:SignatureCheckMode):SignatureCheckMode;
	@:op(A & B) static function and(a:SignatureCheckMode, b:SignatureCheckMode):SignatureCheckMode;
	@:op(~A) static function not(a:SignatureCheckMode):SignatureCheckMode;

	var SignatureCheckModeNone = 0;
	var SignatureCheckModeBivariantCallback = 1 << 0;
	var SignatureCheckModeStrictCallback = 1 << 1;
	var SignatureCheckModeIgnoreReturnTypes = 1 << 2;
	var SignatureCheckModeStrictArity = 1 << 3;
	var SignatureCheckModeStrictTopSignature = 1 << 4;
	var SignatureCheckModeCallback = 3;
}

enum abstract MinArgumentCountFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:MinArgumentCountFlags, b:MinArgumentCountFlags):MinArgumentCountFlags;
	@:op(A & B) static function and(a:MinArgumentCountFlags, b:MinArgumentCountFlags):MinArgumentCountFlags;
	@:op(~A) static function not(a:MinArgumentCountFlags):MinArgumentCountFlags;

	var MinArgumentCountFlagsNone = 0;
	var MinArgumentCountFlagsStrongArityForUntypedJS = 1 << 0;
	var MinArgumentCountFlagsVoidIsNonOptional = 1 << 1;
}

enum abstract IntersectionState(Int) from Int to Int {
	@:op(A | B) static function or(a:IntersectionState, b:IntersectionState):IntersectionState;
	@:op(A & B) static function and(a:IntersectionState, b:IntersectionState):IntersectionState;
	@:op(~A) static function not(a:IntersectionState):IntersectionState;

	var IntersectionStateNone = 0;
	var IntersectionStateSource = 1 << 0; // Source type is a constituent of an outer intersection
	var IntersectionStateTarget = 1 << 1; // Target type is a constituent of an outer intersection
}

enum abstract RecursionFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:RecursionFlags, b:RecursionFlags):RecursionFlags;
	@:op(A & B) static function and(a:RecursionFlags, b:RecursionFlags):RecursionFlags;
	@:op(~A) static function not(a:RecursionFlags):RecursionFlags;

	var RecursionFlagsNone = 0;
	var RecursionFlagsSource = 1 << 0;
	var RecursionFlagsTarget = 1 << 1;
	var RecursionFlagsBoth = 3;
}

enum abstract ExpandingFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:ExpandingFlags, b:ExpandingFlags):ExpandingFlags;
	@:op(A & B) static function and(a:ExpandingFlags, b:ExpandingFlags):ExpandingFlags;
	@:op(~A) static function not(a:ExpandingFlags):ExpandingFlags;

	var ExpandingFlagsNone = 0;
	var ExpandingFlagsSource = 1 << 0;
	var ExpandingFlagsTarget = 1 << 1;
	var ExpandingFlagsBoth = 3;
}

enum abstract RelationComparisonResult(Int) from Int to Int {
	@:op(A | B) static function or(a:RelationComparisonResult, b:RelationComparisonResult):RelationComparisonResult;
	@:op(A & B) static function and(a:RelationComparisonResult, b:RelationComparisonResult):RelationComparisonResult;
	@:op(~A) static function not(a:RelationComparisonResult):RelationComparisonResult;

	var RelationComparisonResultNone = 0;
	var RelationComparisonResultSucceeded = 1 << 0;
	var RelationComparisonResultFailed = 1 << 1;
	var RelationComparisonResultReportsUnmeasurable = 1 << 3;
	var RelationComparisonResultReportsUnreliable = 1 << 4;
	var RelationComparisonResultComplexityOverflow = 1 << 5;
	var RelationComparisonResultStackDepthOverflow = 1 << 6;
	var RelationComparisonResultReportsMask = 24;
	var RelationComparisonResultOverflow = 96;
}

@:allow(ts.checker)
class DiagnosticAndArguments {
	var message:Message = null;
	var arguments:Array<Any> = null;

	public function new() {}
}

@:allow(ts.checker)
class ErrorOutputContainer {
	var errors:Array<Diagnostic> = null;
	var skipLogging:Bool = false;

	public function new() {}
}

typedef ErrorReporter = (message:Message, ...args:Any) -> Void;

// PORT: Go compares RecursionId values (`==` on a struct holding an `any`); in Haxe compare the `value` fields.
@:allow(ts.checker)
class RecursionId {
	var value:Any = null;

	public function new() {}
}

@:allow(ts.checker)
class Relation {
	var results:StringMap<RelationComparisonResult> /* key: checker.CacheHashKey */ = null;
	var count:Int = 0; // PORT: len(map) — StringMap has no O(1) size, so set() counts new keys

	public function new() {}

	// PORT: struct map key — CacheHashKey encoded with its helper CacheHashKey.Key() (PORTING §4a).
	static inline function keyString(key:CacheHashKey):std.String {
		return key.Key();
	}

	function get(key:CacheHashKey):RelationComparisonResult {
		return getByKey(keyString(key));
	}

	// PORT: get with a key already encoded by keyString (avoids re-encoding on the hot path)
	function getByKey(key:std.String):RelationComparisonResult {
		if (results == null) {
			return RelationComparisonResultNone;
		}
		final result:Null<RelationComparisonResult> = results.get(key);
		return result == null ? RelationComparisonResultNone : result;
	}

	function set(key:CacheHashKey, result:RelationComparisonResult):Void {
		setByKey(keyString(key), result);
	}

	// PORT: set with a key already encoded by keyString (avoids re-encoding on the hot path)
	function setByKey(key:std.String, result:RelationComparisonResult):Void {
		if (results == null) {
			results = new StringMap<RelationComparisonResult>();
		}
		if (!results.exists(key)) {
			count++;
		}
		results.set(key, result);
	}

	function size():Int {
		return count;
	}
}

@:allow(ts.checker)
class TypeDiscriminator implements Discriminator {
	var c:Checker = null;
	var props:Array<Symbol> = null;
	var isRelatedTo:(Type, Type) -> Ternary = null;

	public function new() {}

	public function len():Int {
		return Core.len(props);
	}

	public function name(index:Int):std.String {
		return props[index].Name;
	}

	public function matches(index:Int, t:Type):Bool {
		final propType = c.getTypeOfSymbol(props[index]);
		for (s in propType.Distributed()) {
			if (isRelatedTo(s, t) != TernaryFalse) {
				return true;
			}
		}
		return false;
	}
}

interface Discriminator {
	function len():Int;
	function matches(index:Int, t:Type):Bool;
	function name(index:Int):std.String;
}

@:allow(ts.checker)
class ErrorState {
	var errorChain:ErrorChain = null;
	var relatedInfo:Array<Diagnostic> = null;

	public function new() {}
}

@:allow(ts.checker)
class ErrorChain {
	var next:ErrorChain = null;
	var message:Message = null;
	var args:Array<Any> = null;

	public function new() {}
}

// Also holds the methods of relater.go on other receivers as statics (static extension, PORTING.md §2).
@:allow(ts.checker)
class Relater {
	var c:Checker = null;
	var relation:Relation = null;
	var errorNode:Node = null;
	var errorChain:ErrorChain = null;
	var relatedInfo:Array<Diagnostic> = null;
	// PORT: struct map key — the maybe keys are kept encoded (Relation.keyString); the skeleton's
	// Set<CacheHashKey> would compare key objects by identity.
	var maybeKeys:Array<std.String> = null;
	var maybeKeysSet:Set<std.String> = new Set<std.String>();
	var sourceStack:Array<Type> = null;
	var targetStack:Array<Type> = null;
	var maybeCount:Int = 0;
	var sourceDepth:Int = 0;
	var targetDepth:Int = 0;
	var expandingFlags:ExpandingFlags = 0;
	var overflow:Bool = false;
	var relationCount:Int = 0;
	var next:Relater = null;

	public function new() {}

	// PORT: skeleton gap — the untyped second const block of Go ObjectFlags (types.go:617-641) is missing in Types.hx;
	// the two values relater.go uses are declared here until lane O5 adds them.
	static inline final ObjectFlagsObjectRestType:ObjectFlags = 1 << 23;
	static inline final ObjectFlagsIsNeverIntersection:ObjectFlags = 1 << 26;

	// PORT: struct map key — EnumRelationKey{sourceId, targetId} encoded as a String for c.enumRelation.
	static inline function enumRelationKeyString(sourceId:SymbolId, targetId:SymbolId):std.String {
		return sourceId + ":" + targetId;
	}

	// PORT: Go `==` on `any` compares dynamic type and value; Haxe/JS `==` on Dynamic is loose ("1" == 1).
	static function anyEquals(a:Any, b:Any):Bool {
		if (Std.isOfType(a, std.String) != Std.isOfType(b, std.String)) {
			return false;
		}
		return a == b;
	}

	static function isTypeIdenticalTo(c:Checker, source:Type, target:Type):Bool {
		return c.isTypeRelatedTo(source, target, c.identityRelation);
	}

	static function compareTypesIdentical(c:Checker, source:Type, target:Type):Ternary {
		if (c.isTypeRelatedTo(source, target, c.identityRelation)) {
			return TernaryTrue;
		}
		return TernaryFalse;
	}

	static function compareTypesAssignableSimple(c:Checker, source:Type, target:Type):Ternary {
		if (c.isTypeRelatedTo(source, target, c.assignableRelation)) {
			return TernaryTrue;
		}
		return TernaryFalse;
	}

	static function compareTypesAssignableWorker(c:Checker, source:Type, target:Type, reportErrors:Bool):Ternary {
		if (c.isTypeRelatedTo(source, target, c.assignableRelation)) {
			return TernaryTrue;
		}
		return TernaryFalse;
	}

	static function compareTypesSubtypeOf(c:Checker, source:Type, target:Type):Ternary {
		if (c.isTypeRelatedTo(source, target, c.subtypeRelation)) {
			return TernaryTrue;
		}
		return TernaryFalse;
	}

	static function isTypeAssignableTo(c:Checker, source:Type, target:Type):Bool {
		return c.isTypeRelatedTo(source, target, c.assignableRelation);
	}

	static function isTypeSubtypeOf(c:Checker, source:Type, target:Type):Bool {
		return c.isTypeRelatedTo(source, target, c.subtypeRelation);
	}

	static function isTypeStrictSubtypeOf(c:Checker, source:Type, target:Type):Bool {
		return c.isTypeRelatedTo(source, target, c.strictSubtypeRelation);
	}

	static function isTypeComparableTo(c:Checker, source:Type, target:Type):Bool {
		return c.isTypeRelatedTo(source, target, c.comparableRelation);
	}

	static function areTypesComparable(c:Checker, type1:Type, type2:Type):Bool {
		return c.isTypeComparableTo(type1, type2) || c.isTypeComparableTo(type2, type1);
	}

	static function isTypeRelatedTo(c:Checker, source:Type, target:Type, relation:Relation):Bool {
		if (Checker.isFreshLiteralType(source)) {
			source = source.AsLiteralType().regularType;
		}
		if (Checker.isFreshLiteralType(target)) {
			target = target.AsLiteralType().regularType;
		}
		if (source == target) {
			return true;
		}
		if (relation != c.identityRelation) {
			if (relation == c.comparableRelation && target.flags & TypeFlagsNever == 0 && c.isSimpleTypeRelatedTo(target, source, relation, null)
				|| c.isSimpleTypeRelatedTo(source, target, relation, null)) {
				return true;
			}
		} else if (!((source.flags | target.flags) & (TypeFlagsUnionOrIntersection | TypeFlagsIndexedAccess | TypeFlagsConditional | TypeFlagsSubstitution) != 0)) {
			// We have excluded types that may simplify to other forms, so types must have identical flags
			if (source.flags != target.flags) {
				return false;
			}
			if (source.flags & TypeFlagsSingleton != 0) {
				return true;
			}
		}
		if (source.flags & TypeFlagsObject != 0 && target.flags & TypeFlagsObject != 0) {
			final id = Checker.getRelationKey(source, target, IntersectionStateNone, relation == c.identityRelation, false);
			final related = relation.get(id);
			if (related != RelationComparisonResultNone) {
				return related & RelationComparisonResultSucceeded != 0;
			}
		}
		if (source.flags & TypeFlagsStructuredOrInstantiable != 0 || target.flags & TypeFlagsStructuredOrInstantiable != 0) {
			return c.checkTypeRelatedTo(source, target, relation, null /*errorNode*/);
		}
		return false;
	}

	static function isSimpleTypeRelatedTo(c:Checker, source:Type, target:Type, relation:Relation, errorReporter:ErrorReporter):Bool {
		final s = source.flags;
		final t = target.flags;
		if (t & TypeFlagsAny != 0 || s & TypeFlagsNever != 0 || source == c.wildcardType) {
			return true;
		}
		if (t & TypeFlagsUnknown != 0 && !(relation == c.strictSubtypeRelation && s & TypeFlagsAny != 0)) {
			return true;
		}
		if (t & TypeFlagsNever != 0) {
			return false;
		}
		if (s & TypeFlagsStringLike != 0 && t & TypeFlagsString != 0) {
			return true;
		}
		if (s & TypeFlagsStringLiteral != 0 && s & TypeFlagsEnumLiteral != 0 && t & TypeFlagsStringLiteral != 0 && t & TypeFlagsEnumLiteral == 0
			&& source.AsLiteralType().value == target.AsLiteralType().value) {
			return true;
		}
		if (s & TypeFlagsNumberLike != 0 && t & TypeFlagsNumber != 0) {
			return true;
		}
		if (s & TypeFlagsNumberLiteral != 0 && s & TypeFlagsEnumLiteral != 0 && t & TypeFlagsNumberLiteral != 0 && t & TypeFlagsEnumLiteral == 0
			&& source.AsLiteralType().value == target.AsLiteralType().value) {
			return true;
		}
		if (s & TypeFlagsBigIntLike != 0 && t & TypeFlagsBigInt != 0) {
			return true;
		}
		if (s & TypeFlagsBooleanLike != 0 && t & TypeFlagsBoolean != 0) {
			return true;
		}
		if (s & TypeFlagsESSymbolLike != 0 && t & TypeFlagsESSymbol != 0) {
			return true;
		}
		if (s & TypeFlagsEnum != 0 && t & TypeFlagsEnum != 0 && source.symbol.Name == target.symbol.Name
			&& c.isEnumTypeRelatedTo(source.symbol, target.symbol, errorReporter)) {
			return true;
		}
		if (s & TypeFlagsEnumLiteral != 0 && t & TypeFlagsEnumLiteral != 0) {
			if (s & TypeFlagsUnion != 0 && t & TypeFlagsUnion != 0 && c.isEnumTypeRelatedTo(source.symbol, target.symbol, errorReporter)) {
				return true;
			}
			if (s & TypeFlagsLiteral != 0 && t & TypeFlagsLiteral != 0 && source.AsLiteralType().value == target.AsLiteralType().value
				&& c.isEnumTypeRelatedTo(source.symbol, target.symbol, errorReporter)) {
				return true;
			}
		}
		// In non-strictNullChecks mode, `undefined` and `null` are assignable to anything except `never`.
		// Since unions and intersections may reduce to `never`, we exclude them here.
		if (s & TypeFlagsUndefined != 0 && (!c.strictNullChecks && t & TypeFlagsUnionOrIntersection == 0 || t & (TypeFlagsUndefined | TypeFlagsVoid) != 0)) {
			return true;
		}
		if (s & TypeFlagsNull != 0 && (!c.strictNullChecks && t & TypeFlagsUnionOrIntersection == 0 || t & TypeFlagsNull != 0)) {
			return true;
		}
		if (s & TypeFlagsObject != 0 && t & TypeFlagsNonPrimitive != 0
			&& !(relation == c.strictSubtypeRelation && c.IsEmptyAnonymousObjectType(source) && source.objectFlags & ObjectFlagsFreshLiteral == 0)) {
			return true;
		}
		if (relation == c.assignableRelation || relation == c.comparableRelation) {
			if (s & TypeFlagsAny != 0) {
				return true;
			}
			// Type number is assignable to any computed numeric enum type or any numeric enum literal type, and
			// a numeric literal type is assignable any computed numeric enum type or any numeric enum literal type
			// with a matching value. These rules exist such that enums can be used for bit-flag purposes.
			if (s & TypeFlagsNumber != 0 && (t & TypeFlagsEnum != 0 || t & TypeFlagsNumberLiteral != 0 && t & TypeFlagsEnumLiteral != 0)) {
				return true;
			}
			if (s & TypeFlagsNumberLiteral != 0 && s & TypeFlagsEnumLiteral == 0
				&& (t & TypeFlagsEnum != 0
					|| t & TypeFlagsNumberLiteral != 0 && t & TypeFlagsEnumLiteral != 0 && source.AsLiteralType().value == target.AsLiteralType().value)) {
				return true;
			}
			// Anything is assignable to a union containing undefined, null, and {}
			if (c.isUnknownLikeUnionType(target)) {
				return true;
			}
		}
		return false;
	}

	static function isEnumTypeRelatedTo(c:Checker, source:Symbol, target:Symbol, errorReporter:ErrorReporter):Bool {
		final sourceSymbol = Core.IfElse(source.Flags & SymbolFlagsEnumMember != 0, c.getParentOfSymbol(source), source);
		final targetSymbol = Core.IfElse(target.Flags & SymbolFlagsEnumMember != 0, c.getParentOfSymbol(target), target);
		if (sourceSymbol == targetSymbol) {
			return true;
		}
		if (sourceSymbol.Name != targetSymbol.Name || sourceSymbol.Flags & SymbolFlagsRegularEnum == 0 || targetSymbol.Flags & SymbolFlagsRegularEnum == 0) {
			return false;
		}
		final key = enumRelationKeyString(Ast.GetSymbolId(sourceSymbol), Ast.GetSymbolId(targetSymbol));
		final entryValue:Null<RelationComparisonResult> = c.enumRelation.get(key);
		final entry:RelationComparisonResult = entryValue == null ? RelationComparisonResultNone : entryValue;
		if (entry != RelationComparisonResultNone && !(entry & RelationComparisonResultFailed != 0 && errorReporter != null)) {
			return entry & RelationComparisonResultSucceeded != 0;
		}
		final targetEnumType = c.getTypeOfSymbol(targetSymbol);
		final sourceProperties = c.getPropertiesOfType(c.getTypeOfSymbol(sourceSymbol));
		if (sourceProperties != null) {
			for (sourceProperty in sourceProperties) {
				if (sourceProperty.Flags & SymbolFlagsEnumMember != 0) {
					final targetProperty = c.getPropertyOfType(targetEnumType, sourceProperty.Name);
					if (targetProperty == null || targetProperty.Flags & SymbolFlagsEnumMember == 0) {
						if (errorReporter != null) {
							errorReporter(Diagnostics.Property_0_is_missing_in_type_1, c.symbolToString(sourceProperty),
								c.TypeToStringEx(c.getDeclaredTypeOfSymbol(targetSymbol), null /*enclosingDeclaration*/, TypeFormatFlagsUseFullyQualifiedType, null));
						}
						c.enumRelation.set(key, RelationComparisonResultFailed);
						return false;
					}
					final sourceValue:Any = c.getEnumMemberValue(Ast.GetDeclarationOfKind(sourceProperty, KindEnumMember)).Value;
					final targetValue:Any = c.getEnumMemberValue(Ast.GetDeclarationOfKind(targetProperty, KindEnumMember)).Value;
					if (!anyEquals(sourceValue, targetValue)) {
						// If we have 2 enums with *known* values that differ, they are incompatible.
						if (sourceValue != null && targetValue != null) {
							if (errorReporter != null) {
								errorReporter(Diagnostics.Each_declaration_of_0_1_differs_in_its_value_where_2_was_expected_but_3_was_given, c.symbolToString(targetSymbol),
									c.symbolToString(targetProperty), c.valueToString(targetValue), c.valueToString(sourceValue));
							}
							c.enumRelation.set(key, RelationComparisonResultFailed);
							return false;
						}
						// At this point we know that at least one of the values is 'undefined'.
						// This may mean that we have an opaque member from an ambient enum declaration,
						// or that we were not able to calculate it (which is basically an error).
						//
						// Either way, we can assume that it's numeric.
						// If the other is a string, we have a mismatch in types.
						final sourceIsString = Std.isOfType(sourceValue, std.String);
						final targetIsString = Std.isOfType(targetValue, std.String);
						if (sourceIsString || targetIsString) {
							if (errorReporter != null) {
								final knownStringValue:Any = sourceValue != null ? sourceValue : targetValue;
								errorReporter(Diagnostics.One_value_of_0_1_is_the_string_2_and_the_other_is_assumed_to_be_an_unknown_numeric_value,
									c.symbolToString(targetSymbol), c.symbolToString(targetProperty), c.valueToString(knownStringValue));
							}
							c.enumRelation.set(key, RelationComparisonResultFailed);
							return false;
						}
					}
				}
			}
		}
		c.enumRelation.set(key, RelationComparisonResultSucceeded);
		return true;
	}

	static function checkTypeAssignableTo(c:Checker, source:Type, target:Type, errorNode:Node, headMessage:Message):Bool {
		return c.checkTypeRelatedToEx(source, target, c.assignableRelation, errorNode, headMessage, null);
	}

	static function checkTypeAssignableToEx(c:Checker, source:Type, target:Type, errorNode:Node, headMessage:Message, diagnosticOutput:Array<Diagnostic>):Bool {
		return c.checkTypeRelatedToEx(source, target, c.assignableRelation, errorNode, headMessage, diagnosticOutput);
	}

	static function checkTypeComparableTo(c:Checker, source:Type, target:Type, errorNode:Node, headMessage:Message):Bool {
		return c.checkTypeRelatedToEx(source, target, c.comparableRelation, errorNode, headMessage, null);
	}

	static function checkTypeRelatedTo(c:Checker, source:Type, target:Type, relation:Relation, errorNode:Node):Bool {
		return c.checkTypeRelatedToEx(source, target, relation, errorNode, null, null);
	}

	// Check that source is related to target according to the given relation. When errorNode is non-nil, errors are
	// reported to the checker's diagnostic collection or through diagnosticOutput when non-nil. Callers can assume that
	// this function only reports zero or one error to diagnosticOutput (unlike checkTypeRelatedToAndOptionallyElaborate).
	static function checkTypeRelatedToEx(c:Checker, source:Type, target:Type, relation:Relation, errorNode:Node, headMessage:Message, diagnosticOutput:Array<Diagnostic>):Bool {
		final r = c.getRelater();
		r.relation = relation;
		r.errorNode = errorNode;
		r.relationCount = Std.int((16000000 - relation.size()) / 8);
		final result = r.isRelatedToEx(source, target, RecursionFlagsBoth, errorNode != null /*reportErrors*/, headMessage, IntersectionStateNone);
		if (r.overflow) {
			// Record this relation as having failed such that we don't attempt the overflowing operation again.
			final id = Checker.getRelationKey(source, target, IntersectionStateNone, relation == c.identityRelation, false /*ignoreConstraints*/);
			relation.set(id, RelationComparisonResultFailed | (r.relationCount <= 0 ? RelationComparisonResultComplexityOverflow : RelationComparisonResultStackDepthOverflow));
			final tr = c.tracer;
			if (tr != null) {
				final args = new StringMap<Any>();
				args.set("sourceId", source.id);
				args.set("targetId", target.id);
				args.set("depth", Core.len(r.sourceStack));
				args.set("targetDepth", Core.len(r.targetStack));
				tr.Instant(PhaseCheckTypes, "checkTypeRelatedTo_DepthLimit", args);
			}
			final message = r.relationCount <= 0 ? Diagnostics.Excessive_complexity_comparing_types_0_and_1 : Diagnostics.Excessive_stack_depth_comparing_types_0_and_1;
			if (errorNode == null) {
				errorNode = c.currentNode;
			}
			c.reportDiagnostic(Checker.NewDiagnosticForNode(errorNode, message, c.TypeToString(source), c.TypeToString(target)), diagnosticOutput);
		} else if (r.errorChain != null) {
			// Check if we should issue an extra diagnostic to produce a quickfix for a slightly incorrect import statement
			if (headMessage != null && errorNode != null && result == TernaryFalse && source.symbol != null && c.exportTypeLinks.Has(source.symbol)) {
				final links = c.exportTypeLinks.Get(source.symbol);
				if (links.originatingImport != null && !Ast.IsImportCall(links.originatingImport)) {
					final helpfulRetry = c.checkTypeRelatedTo(c.getTypeOfSymbol(links.target), target, relation /*errorNode*/, null);
					if (helpfulRetry) {
						// Likely an incorrect import. Issue a helpful diagnostic to produce a quickfix to change the import
						// PORT: append — copy so a saved errorState never sees the new element
						r.relatedInfo = appendDiagnostic(r.relatedInfo,
							Checker.createDiagnosticForNode(links.originatingImport,
								Diagnostics.Type_originates_at_this_import_A_namespace_style_import_cannot_be_called_or_constructed_and_will_cause_a_failure_at_runtime_Consider_using_a_default_import_or_import_require_here_instead));
					}
				}
			}
			c.reportDiagnostic(Checker.createDiagnosticChainFromErrorChain(r.errorChain, r.errorNode, r.relatedInfo), diagnosticOutput);
		}
		c.putRelater(r);
		return result != TernaryFalse;
	}

	// PORT: Go `append(s, d)` where s may share its backing array with a saved errorState; the copy keeps
	// restoreErrorState exact (a Haxe push would be visible through the saved array).
	static function appendDiagnostic(s:Array<Diagnostic>, d:Diagnostic):Array<Diagnostic> {
		if (s == null) {
			return [d];
		}
		final result = s.copy();
		result.push(d);
		return result;
	}

	static function reportDiagnostic(c:Checker, diagnostic:Diagnostic, diagnosticOutput:Array<Diagnostic>):Void {
		if (diagnostic != null) {
			if (diagnosticOutput != null) {
				diagnosticOutput.push(diagnostic);
			} else {
				c.addDiagnostic(diagnostic);
			}
		}
	}

	static function checkTypeAssignableToAndOptionallyElaborate(c:Checker, source:Type, target:Type, errorNode:Node, expr:Node, headMessage:Message, diagnosticOutput:Array<Diagnostic>):Bool {
		return c.checkTypeRelatedToAndOptionallyElaborate(source, target, c.assignableRelation, errorNode, expr, headMessage, diagnosticOutput);
	}

	static function checkTypeRelatedToAndOptionallyElaborate(c:Checker, source:Type, target:Type, relation:Relation, errorNode:Node, expr:Node, headMessage:Message, diagnosticOutput:Array<Diagnostic>):Bool {
		if (c.isTypeRelatedTo(source, target, relation)) {
			return true;
		}
		if (errorNode != null && !c.elaborateError(expr, source, target, relation, headMessage, diagnosticOutput)) {
			return c.checkTypeRelatedToEx(source, target, relation, errorNode, headMessage, diagnosticOutput);
		}
		return false;
	}

	static function elaborateError(c:Checker, node:Node, source:Type, target:Type, relation:Relation, headMessage:Message, diagnosticOutput:Array<Diagnostic>):Bool {
		if (node == null || c.isOrHasGenericConditional(target)) {
			return false;
		}
		if (c.compilerOptions.NoCheck.IsTrue()) {
			return false;
		}
		if (c.elaborateDidYouMeanToCallOrConstruct(node, source, target, relation, SignatureKindConstruct, headMessage, diagnosticOutput)
			|| c.elaborateDidYouMeanToCallOrConstruct(node, source, target, relation, SignatureKindCall, headMessage, diagnosticOutput)) {
			return true;
		}
		// PORT: switch with break/fallthrough restructured as if/else
		final kind = node.Kind;
		if (kind == KindAsExpression && Ast.IsConstAssertion(node) || kind == KindJsxExpression || kind == KindParenthesizedExpression) {
			return c.elaborateError(node.Expression(), source, target, relation, headMessage, diagnosticOutput);
		} else if (kind == KindBinaryExpression) {
			final op = node.AsBinaryExpression().OperatorToken.Kind;
			if (op == KindEqualsToken || op == KindCommaToken) {
				return c.elaborateError(node.AsBinaryExpression().Right, source, target, relation, headMessage, diagnosticOutput);
			}
		} else if (kind == KindObjectLiteralExpression) {
			return c.elaborateObjectLiteral(node, source, target, relation, diagnosticOutput);
		} else if (kind == KindArrayLiteralExpression) {
			return c.elaborateArrayLiteral(node, source, target, relation, diagnosticOutput);
		} else if (kind == KindArrowFunction) {
			return c.elaborateArrowFunction(node, source, target, relation, diagnosticOutput);
		} else if (kind == KindJsxAttributes) {
			return c.elaborateJsxComponents(node, source, target, relation, diagnosticOutput);
		}
		return false;
	}

	static function isOrHasGenericConditional(c:Checker, t:Type):Bool {
		return t.flags & TypeFlagsConditional != 0 || (t.flags & TypeFlagsIntersection != 0 && Core.Some(t.Types(), t -> c.isOrHasGenericConditional(t)));
	}

	static function elaborateDidYouMeanToCallOrConstruct(c:Checker, node:Node, source:Type, target:Type, relation:Relation, kind:SignatureKind, headMessage:Message, diagnosticOutput:Array<Diagnostic>):Bool {
		if (Core.Some(c.getSignaturesOfType(source, kind), s -> {
			final returnType = c.getReturnTypeOfSignature(s);
			return returnType.flags & (TypeFlagsAny | TypeFlagsNever) == 0 && c.checkTypeRelatedTo(returnType, target, relation, null /*errorNode*/);
		})) {
			final diags:Array<Diagnostic> = [];
			if (!c.checkTypeRelatedToEx(source, target, relation, node, headMessage, diags)) {
				final diagnostic = diags[0];
				final message = kind == SignatureKindConstruct ? Diagnostics.Did_you_mean_to_use_new_with_this_expression : Diagnostics.Did_you_mean_to_call_this_expression;
				c.reportDiagnostic(diagnostic.AddRelatedInfo(Checker.createDiagnosticForNode(node, message)), diagnosticOutput);
				return true;
			}
		}
		return false;
	}

	static function elaborateObjectLiteral(c:Checker, node:Node, source:Type, target:Type, relation:Relation, diagnosticOutput:Array<Diagnostic>):Bool {
		if (target.flags & (TypeFlagsPrimitive | TypeFlagsNever) != 0) {
			return false;
		}
		var reportedError = false;
		for (prop in node.Properties()) {
			if (Ast.IsSpreadAssignment(prop)) {
				continue;
			}
			final nameType = c.getLiteralTypeFromProperty(c.getSymbolOfDeclaration(prop), TypeFlagsStringOrNumberLiteralOrUnique, false);
			if (nameType == null || nameType.flags & TypeFlagsNever != 0) {
				continue;
			}
			switch (prop.Kind) {
				case KindSetAccessor | KindGetAccessor | KindMethodDeclaration | KindShorthandPropertyAssignment:
					reportedError = c.elaborateElement(source, target, relation, prop.Name(), null, nameType, null, null, diagnosticOutput) || reportedError;
				case KindPropertyAssignment:
					final message = Ast.IsComputedNonLiteralName(prop.Name()) ? Diagnostics.Type_of_computed_property_s_value_is_0_which_is_not_assignable_to_type_1 : null;
					reportedError = c.elaborateElement(source, target, relation, prop.Name(), prop.Initializer(), nameType, message, null, diagnosticOutput) || reportedError;
				default:
			}
		}
		return reportedError;
	}

	static function elaborateArrayLiteral(c:Checker, node:Node, source:Type, target:Type, relation:Relation, diagnosticOutput:Array<Diagnostic>):Bool {
		if (target.flags & (TypeFlagsPrimitive | TypeFlagsNever) != 0) {
			return false;
		}
		if (!c.isTupleLikeType(source)) {
			c.pushContextualType(node, target, false /*isCache*/);
			source = c.checkArrayLiteral(node, CheckModeContextual | CheckModeForceTuple);
			c.popContextualType();
			if (!c.isTupleLikeType(source)) {
				return false;
			}
		}
		var reportedError = false;
		final elements = node.Elements();
		for (i in 0...Core.len(elements)) {
			final element = elements[i];
			if (Ast.IsOmittedExpression(element) || c.isTupleLikeType(target) && c.getPropertyOfType(target, ts.jsnum.String_.String((i : Number))) == null) {
				continue;
			}
			final nameType = c.getNumberLiteralType((i : Number));
			final checkNode = c.getEffectiveCheckNode(element);
			reportedError = c.elaborateElement(source, target, relation, checkNode, checkNode, nameType, null, null, diagnosticOutput) || reportedError;
		}
		return reportedError;
	}

	static function elaborateElement(c:Checker, source:Type, target:Type, relation:Relation, prop:Node, next:Node, nameType:Type, errorMessage:Message, diagnosticFactory:(prop:Node) -> Diagnostic, diagnosticOutput:Array<Diagnostic>):Bool {
		var targetPropType = c.getBestMatchIndexedAccessTypeOrUndefined(source, target, nameType);
		if (targetPropType == null || targetPropType.flags & TypeFlagsIndexedAccess != 0) {
			// Don't elaborate on indexes on generic variables
			return false;
		}
		var sourcePropType = c.getIndexedAccessTypeOrUndefined(source, nameType, AccessFlagsNone, null, null);
		if (sourcePropType == null || c.checkTypeRelatedTo(sourcePropType, targetPropType, relation, null /*errorNode*/)) {
			// Don't elaborate on indexes on generic variables or when types match
			return false;
		}
		if (next != null && c.elaborateError(next, sourcePropType, targetPropType, relation, null /*headMessage*/, diagnosticOutput)) {
			return true;
		}
		// Issue error on the prop itself, since the prop couldn't elaborate the error
		final diags:Array<Diagnostic> = [];
		// Use the expression type, if available
		var specificSource = sourcePropType;
		if (next != null) {
			specificSource = c.checkExpressionForMutableLocationWithContextualType(next, sourcePropType);
		}
		if (diagnosticFactory != null) {
			// Use the custom diagnostic factory if provided (e.g., for JSX text children with dynamic error messages)
			diags.push(diagnosticFactory(prop));
		} else if (c.exactOptionalPropertyTypes && c.isExactOptionalPropertyMismatch(specificSource, targetPropType)) {
			diags.push(Checker.createDiagnosticForNode(prop,
				Diagnostics.Type_0_is_not_assignable_to_type_1_with_exactOptionalPropertyTypes_Colon_true_Consider_adding_undefined_to_the_type_of_the_target,
				c.TypeToString(specificSource), c.TypeToString(targetPropType)));
		} else {
			final propName = c.getPropertyNameFromIndex(nameType, null /*accessNode*/);
			final targetIsOptional = Core.OrElse(c.getPropertyOfType(target, propName), c.unknownSymbol).Flags & SymbolFlagsOptional != 0;
			final sourceIsOptional = Core.OrElse(c.getPropertyOfType(source, propName), c.unknownSymbol).Flags & SymbolFlagsOptional != 0;
			targetPropType = c.removeMissingType(targetPropType, targetIsOptional);
			sourcePropType = c.removeMissingType(sourcePropType, targetIsOptional && sourceIsOptional);
			final result = c.checkTypeRelatedToEx(specificSource, targetPropType, relation, prop, errorMessage, diags);
			if (result && specificSource != sourcePropType) {
				// If for whatever reason the expression type doesn't yield an error, make sure we still issue an error on the sourcePropType
				c.checkTypeRelatedToEx(sourcePropType, targetPropType, relation, prop, errorMessage, diags);
			}
		}
		if (diags.length == 0) {
			return false;
		}
		final diagnostic = diags[0];
		var propertyName = "";
		var targetProp:Symbol = null;
		if (Checker.isTypeUsableAsPropertyName(nameType)) {
			propertyName = Checker.getPropertyNameFromType(nameType);
			targetProp = c.getPropertyOfType(target, propertyName);
		}
		var issuedElaboration = false;
		if (targetProp == null) {
			final indexInfo = c.getApplicableIndexInfo(target, nameType);
			if (indexInfo != null && indexInfo.declaration != null && !c.program.IsSourceFileDefaultLibrary(Ast.GetSourceFileOfNode(indexInfo.declaration).Path())) {
				issuedElaboration = true;
				diagnostic.AddRelatedInfo(Checker.createDiagnosticForNode(indexInfo.declaration, Diagnostics.The_expected_type_comes_from_this_index_signature));
			}
		}
		if (!issuedElaboration && (targetProp != null && Core.len(targetProp.Declarations) != 0 || target.symbol != null && Core.len(target.symbol.Declarations) != 0)) {
			var targetNode:Node = null;
			if (targetProp != null && Core.len(targetProp.Declarations) != 0) {
				targetNode = targetProp.Declarations[0];
			} else {
				targetNode = target.symbol.Declarations[0];
			}
			if (propertyName == "" || nameType.flags & TypeFlagsUniqueESSymbol != 0) {
				propertyName = c.TypeToString(nameType);
			}
			if (!c.program.IsSourceFileDefaultLibrary(Ast.GetSourceFileOfNode(targetNode).Path())) {
				diagnostic.AddRelatedInfo(Checker.createDiagnosticForNode(targetNode, Diagnostics.The_expected_type_comes_from_property_0_which_is_declared_here_on_type_1,
					propertyName, c.TypeToString(target)));
			}
		}
		c.reportDiagnostic(diagnostic, diagnosticOutput);
		return true;
	}

	static function getBestMatchIndexedAccessTypeOrUndefined(c:Checker, source:Type, target:Type, nameType:Type):Type {
		final idx = c.getIndexedAccessTypeOrUndefined(target, nameType, AccessFlagsNone, null, null);
		if (idx != null) {
			return idx;
		}
		if (target.flags & TypeFlagsUnion != 0) {
			final best = c.getBestMatchingType(source, target, (s, t) -> c.compareTypesAssignableSimple(s, t));
			if (best != null) {
				return c.getIndexedAccessTypeOrUndefined(best, nameType, AccessFlagsNone, null, null);
			}
		}
		return null;
	}

	static function checkExpressionForMutableLocationWithContextualType(c:Checker, next:Node, sourcePropType:Type):Type {
		c.pushContextualType(next, sourcePropType, false /*isCache*/);
		final result = c.checkExpressionForMutableLocation(next, CheckModeContextual);
		c.popContextualType();
		return result;
	}

	static function elaborateArrowFunction(c:Checker, node:Node, source:Type, target:Type, relation:Relation, diagnosticOutput:Array<Diagnostic>):Bool {
		// Don't elaborate blocks or functions with annotated parameter types
		if (Ast.IsBlock(node.Body()) || Core.Some(node.Parameters(), Checker.hasType)) {
			return false;
		}
		final sourceSig = c.getSingleCallSignature(source);
		if (sourceSig == null) {
			return false;
		}
		final targetSignatures = c.getSignaturesOfType(target, SignatureKindCall);
		if (Core.len(targetSignatures) == 0) {
			return false;
		}
		final returnExpression = node.Body();
		final sourceReturn = c.getReturnTypeOfSignature(sourceSig);
		final targetReturn = c.getUnionType(Core.Map(targetSignatures, s -> c.getReturnTypeOfSignature(s)));
		if (c.checkTypeRelatedTo(sourceReturn, targetReturn, relation, null /*errorNode*/)) {
			return false;
		}
		if (returnExpression != null && c.elaborateError(returnExpression, sourceReturn, targetReturn, relation, null /*headMessage*/, diagnosticOutput)) {
			return true;
		}
		final diags:Array<Diagnostic> = [];
		c.checkTypeRelatedToEx(sourceReturn, targetReturn, relation, returnExpression, null /*headMessage*/, diags);
		if (diags.length != 0) {
			final diagnostic = diags[0];
			if (target.symbol != null && Core.len(target.symbol.Declarations) != 0) {
				diagnostic.AddRelatedInfo(Checker.createDiagnosticForNode(target.symbol.Declarations[0], Diagnostics.The_expected_type_comes_from_the_return_type_of_this_signature));
			}
			if (Ast.GetFunctionFlags(node) & FunctionFlagsAsync == 0 && c.getTypeOfPropertyOfType(sourceReturn, "then") == null
				&& c.checkTypeRelatedTo(c.createPromiseType(sourceReturn), targetReturn, relation, null /*errorNode*/)) {
				diagnostic.AddRelatedInfo(Checker.createDiagnosticForNode(node, Diagnostics.Did_you_mean_to_mark_this_function_as_async));
			}
			c.reportDiagnostic(diagnostic, diagnosticOutput);
			return true;
		}
		return false;
	}

	// A type is 'weak' if it is an object type with at least one optional property
	// and no required properties, call/construct signatures or index signatures
	static function isWeakType(c:Checker, t:Type):Bool {
		if (t.flags & TypeFlagsObject != 0) {
			final resolved = c.resolveStructuredTypeMembers(t);
			return Core.len(resolved.signatures) == 0 && Core.len(resolved.indexInfos) == 0 && Core.len(resolved.properties) > 0
				&& Core.Every(resolved.properties, p -> p.Flags & SymbolFlagsOptional != 0);
		}
		if (t.flags & TypeFlagsSubstitution != 0) {
			return c.isWeakType(t.AsSubstitutionType().baseType);
		}
		if (t.flags & TypeFlagsIntersection != 0) {
			return Core.Every(t.Types(), t -> c.isWeakType(t));
		}
		return false;
	}

	static function hasCommonProperties(c:Checker, source:Type, target:Type, isComparingJsxAttributes:Bool):Bool {
		final props = c.getPropertiesOfType(source);
		if (props != null) {
			for (prop in props) {
				if (c.isKnownProperty(target, prop.Name, isComparingJsxAttributes)) {
					return true;
				}
			}
		}
		return false;
	}

	/**
	 * Check if a property with the given name is known anywhere in the given type. In an object type, a property
	 * is considered known if
	 * 1. the object type is empty and the check is for assignability, or
	 * 2. if the object type has index signatures, or
	 * 3. if the property is actually declared in the object type
	 *    (this means that 'toString', for example, is not usually a known property).
	 * 4. In a union or intersection type,
	 *    a property is considered known if it is known in any constituent type.
	 * @param targetType a type to search a given name in
	 * @param name a property name to search
	 * @param isComparingJsxAttributes a boolean flag indicating whether we are searching in JsxAttributesType
	 */
	static function isKnownProperty(c:Checker, targetType:Type, name:std.String, isComparingJsxAttributes:Bool):Bool {
		if (targetType.flags & TypeFlagsObject != 0) {
			// For backwards compatibility a symbol-named property is satisfied by a string index signature. This
			// is incorrect and inconsistent with element access expressions, where it is an error, so eventually
			// we should remove this exception.
			if (c.getPropertyOfObjectType(targetType, name) != null || c.getApplicableIndexInfoForName(targetType, name) != null
				|| Checker.isLateBoundName(name) && c.getIndexInfoOfType(targetType, c.stringType) != null
				|| isComparingJsxAttributes && Checker.isHyphenatedJsxName(name)) {
				// For JSXAttributes, if the attribute has a hyphenated name, consider that the attribute to be known.
				return true;
			}
		}
		if (targetType.flags & TypeFlagsSubstitution != 0) {
			return c.isKnownProperty(targetType.AsSubstitutionType().baseType, name, isComparingJsxAttributes);
		}
		if (targetType.flags & TypeFlagsUnionOrIntersection != 0 && Checker.isExcessPropertyCheckTarget(targetType)) {
			for (t in targetType.Types()) {
				if (c.isKnownProperty(t, name, isComparingJsxAttributes)) {
					return true;
				}
			}
		}
		return false;
	}

	// Return true if the given type is deeply nested. We consider this to be the case when the given stack contains
	// maxDepth or more occurrences of types with the same recursion identity as the given type. The recursion identity
	// provides a shared identity for type instantiations that repeat in some (possibly infinite) pattern. For example,
	// in `type Deep<T> = { next: Deep<Deep<T>> }`, repeatedly referencing the `next` property leads to an infinite
	// sequence of ever deeper instantiations with the same recursion identity (in this case the symbol associated with
	// the object type literal).
	// A homomorphic mapped type is considered deeply nested if its target type is deeply nested, and an intersection is
	// considered deeply nested if any constituent of the intersection is deeply nested.
	// It is possible, though highly unlikely, for the deeply nested check to be true in a situation where a chain of
	// instantiations is not infinitely expanding. Effectively, we will generate a false positive when two types are
	// structurally equal to at least maxDepth levels, but unequal at some level beyond that.
	static function isDeeplyNestedType(c:Checker, t:Type, stack:Array<Type>, maxDepth:Int):Bool {
		if (Core.len(stack) >= maxDepth) {
			if (t.objectFlags & ObjectFlagsInstantiatedMapped == ObjectFlagsInstantiatedMapped) {
				t = c.getMappedTargetWithSymbol(t);
			}
			if (t.flags & TypeFlagsIntersection != 0) {
				for (t in t.Types()) {
					if (c.isDeeplyNestedType(t, stack, maxDepth)) {
						return true;
					}
				}
			}
			final identity = Checker.getRecursionIdentity(t);
			var count = 0;
			var lastTypeId:TypeId = 0;
			for (t in stack) {
				if (c.hasMatchingRecursionIdentity(t, identity)) {
					// We only count occurrences with a higher type id than the previous occurrence, since higher
					// type ids are an indicator of newer instantiations caused by recursion.
					if (t.id >= lastTypeId) {
						count++;
						if (count >= maxDepth) {
							return true;
						}
					}
					lastTypeId = t.id;
				}
			}
		}
		return false;
	}

	// Unwrap nested homomorphic mapped types and return the deepest target type that has a symbol. This better
	// preserves unique type identities for mapped types applied to explicitly written object literals. For example
	// in `Mapped<{ x: Mapped<{ x: Mapped<{ x: string }>}>}>`, each of the mapped type applications will have a
	// unique recursion identity (that of their target object type literal) and thus avoid appearing deeply nested.
	static function getMappedTargetWithSymbol(c:Checker, t:Type):Type {
		while (true) {
			if (t.objectFlags & ObjectFlagsInstantiatedMapped == ObjectFlagsInstantiatedMapped) {
				final target = c.getModifiersTypeFromMappedType(t);
				if (target != null && (target.symbol != null || target.flags & TypeFlagsIntersection != 0 && Core.Some(target.Types(), t -> t.symbol != null))) {
					t = target;
					continue;
				}
			}
			return t;
		}
	}

	static function hasMatchingRecursionIdentity(c:Checker, t:Type, identity:RecursionId):Bool {
		if (t.objectFlags & ObjectFlagsInstantiatedMapped == ObjectFlagsInstantiatedMapped) {
			t = c.getMappedTargetWithSymbol(t);
		}
		if (t.flags & TypeFlagsIntersection != 0) {
			for (t in t.Types()) {
				if (c.hasMatchingRecursionIdentity(t, identity)) {
					return true;
				}
			}
			return false;
		}
		// PORT: Go `==` on RecursionId compares the contained `any` values
		return Checker.getRecursionIdentity(t).value == identity.value;
	}

	static function getBestMatchingType(c:Checker, source:Type, target:Type, isRelatedTo:(source:Type, target:Type) -> Ternary):Type {
		var t = c.findMatchingDiscriminantType(source, target, isRelatedTo);
		if (t != null) {
			return t;
		}
		t = c.findMatchingTypeReferenceOrTypeAliasReference(source, target);
		if (t != null) {
			return t;
		}
		t = c.findBestTypeForObjectLiteral(source, target);
		if (t != null) {
			return t;
		}
		t = c.findBestTypeForInvokable(source, target, SignatureKindCall);
		if (t != null) {
			return t;
		}
		t = c.findBestTypeForInvokable(source, target, SignatureKindConstruct);
		if (t != null) {
			return t;
		}
		return c.findMostOverlappyType(source, target);
	}

	static function findMatchingTypeReferenceOrTypeAliasReference(c:Checker, source:Type, unionTarget:Type):Type {
		final sourceObjectFlags = source.objectFlags;
		if (sourceObjectFlags & (ObjectFlagsReference | ObjectFlagsAnonymous) != 0 && unionTarget.flags & TypeFlagsUnion != 0) {
			for (target in unionTarget.Types()) {
				if (target.flags & TypeFlagsObject != 0) {
					final overlapObjFlags = sourceObjectFlags & target.objectFlags;
					if (overlapObjFlags & ObjectFlagsReference != 0 && source.Target() == target.Target()) {
						return target;
					}
					if (overlapObjFlags & ObjectFlagsAnonymous != 0 && source.alias != null && target.alias != null && source.alias.symbol == target.alias.symbol) {
						return target;
					}
				}
			}
		}
		return null;
	}

	static function findBestTypeForInvokable(c:Checker, source:Type, unionTarget:Type, kind:SignatureKind):Type {
		if (Core.len(c.getSignaturesOfType(source, kind)) != 0) {
			return Core.Find(unionTarget.Types(), t -> Core.len(c.getSignaturesOfType(t, kind)) != 0);
		}
		return null;
	}

	static function findMostOverlappyType(c:Checker, source:Type, unionTarget:Type):Type {
		var bestMatch:Type = null;
		if (source.flags & (TypeFlagsPrimitive | TypeFlagsInstantiablePrimitive) == 0) {
			var matchingCount = 0;
			for (target in unionTarget.Types()) {
				if (target.flags & (TypeFlagsPrimitive | TypeFlagsInstantiablePrimitive) == 0) {
					final overlap = c.getIntersectionType([c.getIndexType(source), c.getIndexType(target)]);
					if (overlap.flags & TypeFlagsIndex != 0) {
						// perfect overlap of keys
						return target;
					} else if (Checker.isUnitType(overlap) || overlap.flags & TypeFlagsUnion != 0) {
						// We only want to account for literal types otherwise.
						// If we have a union of index types, it seems likely that we
						// needed to elaborate between two generic mapped types anyway.
						var length = 1;
						if (overlap.flags & TypeFlagsUnion != 0) {
							length = Core.CountWhere(overlap.Types(), Checker.isUnitType);
						}
						if (length >= matchingCount) {
							bestMatch = target;
							matchingCount = length;
						}
					}
				}
			}
		}
		return bestMatch;
	}

	static function findBestTypeForObjectLiteral(c:Checker, source:Type, unionTarget:Type):Type {
		if (source.objectFlags & ObjectFlagsObjectLiteral != 0 && Checker.someType(unionTarget, t -> c.isArrayLikeType(t))) {
			return Core.Find(unionTarget.Types(), t -> !c.isArrayLikeType(t));
		}
		return null;
	}

	static function shouldReportUnmatchedPropertyError(c:Checker, source:Type, target:Type):Bool {
		final typeCallSignatures = c.getSignaturesOfStructuredType(source, SignatureKindCall);
		final typeConstructSignatures = c.getSignaturesOfStructuredType(source, SignatureKindConstruct);
		final typeProperties = c.getPropertiesOfObjectType(source);
		if ((Core.len(typeCallSignatures) != 0 || Core.len(typeConstructSignatures) != 0) && Core.len(typeProperties) == 0) {
			if ((Core.len(c.getSignaturesOfType(target, SignatureKindCall)) != 0 && Core.len(typeCallSignatures) != 0)
				|| Core.len(c.getSignaturesOfType(target, SignatureKindConstruct)) != 0 && Core.len(typeConstructSignatures) != 0) {
				// target has similar signature kinds to source, still focus on the unmatched property
				return true;
			}
			return false;
		}
		return true;
	}

	static function getUnmatchedProperty(c:Checker, source:Type, target:Type, requireOptionalProperties:Bool, matchDiscriminantProperties:Bool):Symbol {
		return c.getUnmatchedPropertiesWorker(source, target, requireOptionalProperties, matchDiscriminantProperties, null);
	}

	static function getUnmatchedProperties(c:Checker, source:Type, target:Type, requireOptionalProperties:Bool, matchDiscriminantProperties:Bool):Array<Symbol> {
		// PORT: pointer — Go passes &props (nil slice); an empty array is the out-parameter, nil when nothing was found
		final props:Array<Symbol> = [];
		c.getUnmatchedPropertiesWorker(source, target, requireOptionalProperties, matchDiscriminantProperties, props);
		return props.length == 0 ? null : props;
	}

	static function getUnmatchedPropertiesWorker(c:Checker, source:Type, target:Type, requireOptionalProperties:Bool, matchDiscriminantProperties:Bool, propsOut:Array<Symbol>):Symbol {
		final properties = c.getPropertiesOfType(target);
		if (properties != null) {
			for (targetProp in properties) {
				// TODO: remove this when we support static private identifier fields and find other solutions to get privateNamesAndStaticFields test to pass
				if (Checker.isStaticPrivateIdentifierProperty(targetProp)) {
					continue;
				}
				if (requireOptionalProperties || targetProp.Flags & SymbolFlagsOptional == 0 && targetProp.CheckFlags & CheckFlagsPartial == 0) {
					final sourceProp = c.getPropertyOfType(source, targetProp.Name);
					if (sourceProp == null) {
						if (propsOut == null) {
							return targetProp;
						}
						propsOut.push(targetProp);
					} else if (matchDiscriminantProperties) {
						final targetType = c.getTypeOfSymbol(targetProp);
						if (targetType.flags & TypeFlagsUnit != 0) {
							final sourceType = c.getTypeOfSymbol(sourceProp);
							if (!(sourceType.flags & TypeFlagsAny != 0 || c.getRegularTypeOfLiteralType(sourceType) == c.getRegularTypeOfLiteralType(targetType))) {
								if (propsOut == null) {
									return targetProp;
								}
								propsOut.push(targetProp);
							}
						}
					}
				}
			}
		}
		return null;
	}

	// Keep this up-to-date with the same logic within `getApparentTypeOfContextualType`, since they should behave similarly
	static function findMatchingDiscriminantType(c:Checker, source:Type, target:Type, isRelatedTo:(source:Type, target:Type) -> Ternary):Type {
		if (target.flags & TypeFlagsUnion != 0 && source.flags & (TypeFlagsIntersection | TypeFlagsObject) != 0) {
			final match = c.getMatchingUnionConstituentForType(target, source);
			if (match != null) {
				return match;
			}
			final discriminantProperties = c.findDiscriminantProperties(c.getPropertiesOfType(source), target);
			if (Core.len(discriminantProperties) != 0) {
				final discriminator = new TypeDiscriminator();
				discriminator.c = c;
				discriminator.props = discriminantProperties;
				discriminator.isRelatedTo = isRelatedTo;
				final discriminated = c.discriminateTypeByDiscriminableItems(target, discriminator);
				if (discriminated != target) {
					return discriminated;
				}
			}
		}
		return null;
	}

	static function findDiscriminantProperties(c:Checker, sourceProperties:Array<Symbol>, target:Type):Array<Symbol> {
		var result:Array<Symbol> = null;
		if (sourceProperties != null) {
			for (sourceProperty in sourceProperties) {
				if (c.isDiscriminantProperty(target, sourceProperty.Name)) {
					if (result == null) {
						result = [];
					}
					result.push(sourceProperty);
				}
			}
		}
		return result;
	}

	static function isDiscriminantProperty(c:Checker, t:Type, name:std.String):Bool {
		if (t != null && t.flags & TypeFlagsUnion != 0) {
			final prop = c.getUnionOrIntersectionProperty(t, name, false /*skipObjectFunctionPropertyAugment*/);
			if (prop != null && prop.CheckFlags & CheckFlagsSyntheticProperty != 0) {
				if (prop.CheckFlags & CheckFlagsIsDiscriminantComputed == 0) {
					prop.CheckFlags |= CheckFlagsIsDiscriminantComputed;
					if (prop.CheckFlags & CheckFlagsNonUniformAndLiteral == CheckFlagsNonUniformAndLiteral && !c.isGenericType(c.getTypeOfSymbol(prop))) {
						prop.CheckFlags |= CheckFlagsIsDiscriminant;
					}
				}
				return prop.CheckFlags & CheckFlagsIsDiscriminant != 0;
			}
		}
		return false;
	}

	static function getMatchingUnionConstituentForType(c:Checker, unionType:Type, t:Type):Type {
		final keyPropertyName = c.getKeyPropertyName(unionType);
		if (keyPropertyName == "") {
			return null;
		}
		final propType = c.getTypeOfPropertyOfType(t, keyPropertyName);
		if (propType == null) {
			return null;
		}
		return c.getConstituentTypeForKeyType(unionType, propType);
	}

	// Return the name of a discriminant property for which it was possible and feasible to construct a map of
	// constituent types keyed by the literal types of the property by that name in each constituent type. Return
	// an empty string if no such discriminant property exists.
	static function getKeyPropertyName(c:Checker, t:Type):std.String {
		final u = t.AsUnionType();
		if (u.keyPropertyName == "") {
			final r = c.computeKeyPropertyNameAndMap(t);
			u.keyPropertyName = r.a;
			u.constituentMap = r.b;
		}
		if (u.keyPropertyName == Ast.InternalSymbolNameMissing) {
			return "";
		}
		return u.keyPropertyName;
	}

	// Given a union type for which getKeyPropertyName returned a non-empty string, return the constituent
	// that corresponds to the given key type for that property name.
	static function getConstituentTypeForKeyType(c:Checker, t:Type, keyType:Type):Type {
		final constituentMap = t.AsUnionType().constituentMap;
		final result = constituentMap == null ? null : constituentMap.get(c.getRegularTypeOfLiteralType(keyType));
		if (result != c.unknownType) {
			return result;
		}
		return null;
	}

	static function computeKeyPropertyNameAndMap(c:Checker, t:Type):Pair<std.String, IdentityMap<Type, Type>> {
		final types = t.Types();
		if (types.length < 10 || t.objectFlags & ObjectFlagsPrimitiveUnion != 0 || Core.CountWhere(types, Checker.isObjectOrInstantiableNonPrimitive) < 10) {
			return new Pair(Ast.InternalSymbolNameMissing, null);
		}
		final keyPropertyName = c.getKeyPropertyCandidateName(types);
		if (keyPropertyName == "") {
			return new Pair(Ast.InternalSymbolNameMissing, null);
		}
		final mapByKeyProperty = c.mapTypesByKeyProperty(types, keyPropertyName);
		if (mapByKeyProperty == null) {
			return new Pair(Ast.InternalSymbolNameMissing, null);
		}
		return new Pair(keyPropertyName, mapByKeyProperty);
	}

	static function getKeyPropertyCandidateName(c:Checker, types:Array<Type>):std.String {
		for (t in types) {
			if (t.flags & (TypeFlagsObject | TypeFlagsInstantiableNonPrimitive) != 0) {
				final props = c.getPropertiesOfType(t);
				if (props != null) {
					for (p in props) {
						if (Checker.isUnitType(c.getTypeOfSymbol(p))) {
							return p.Name;
						}
					}
				}
			}
		}
		return "";
	}

	// Given a set of constituent types and a property name, create and return a map keyed by the literal
	// types of the property by that name in each constituent type. No map is returned if some key property
	// has a non-literal type or if less than 10 or less than 50% of the constituents have a unique key.
	// Entries with duplicate keys have unknownType as the value.
	static function mapTypesByKeyProperty(c:Checker, types:Array<Type>, keyPropertyName:std.String):IdentityMap<Type, Type> {
		final typesByKey = new IdentityMap<Type, Type>();
		var count = 0;
		for (t in types) {
			if (t.flags & (TypeFlagsObject | TypeFlagsIntersection | TypeFlagsInstantiableNonPrimitive) != 0) {
				final discriminant = c.getTypeOfPropertyOfType(t, keyPropertyName);
				if (discriminant == null || !Checker.isLiteralType(discriminant)) {
					return null;
				}
				var duplicate = false;
				for (d in discriminant.Distributed()) {
					final key = c.getRegularTypeOfLiteralType(d);
					final existing = typesByKey.get(key);
					if (existing == null) {
						typesByKey.set(key, t);
					} else if (existing != c.unknownType) {
						typesByKey.set(key, c.unknownType);
						duplicate = true;
					}
				}
				if (!duplicate) {
					count++;
				}
			}
		}
		if (count >= 10 && count * 2 >= types.length) {
			return typesByKey;
		}
		return null;
	}

	static function discriminateTypeByDiscriminableItems(c:Checker, target:Type, discriminator:Discriminator):Type {
		final types = target.Types();
		final include:Array<Ternary> = [for (_ in 0...types.length) TernaryFalse];
		for (i in 0...types.length) {
			final t = types[i];
			if (t.flags & TypeFlagsPrimitive == 0 && c.getReducedType(t).flags & TypeFlagsNever == 0) {
				include[i] = TernaryTrue;
			}
		}
		for (n in 0...discriminator.len()) {
			// If the remaining target types include at least one with a matching discriminant, eliminate those that
			// have non-matching discriminants. This ensures that we ignore erroneous discriminators and gradually
			// refine the target set without eliminating every constituent (which would lead to `never`).
			var matched = false;
			for (i in 0...types.length) {
				if (include[i] != TernaryFalse) {
					final targetType = c.getTypeOfPropertyOrIndexSignatureOfType(types[i], discriminator.name(n));
					if (targetType != null) {
						if (discriminator.matches(n, targetType)) {
							matched = true;
						} else {
							include[i] = TernaryMaybe;
						}
					}
				}
			}
			// Turn each Ternary.Maybe into Ternary.False if there was a match. Otherwise, revert to Ternary.True.
			for (i in 0...types.length) {
				if (include[i] == TernaryMaybe) {
					if (matched) {
						include[i] = TernaryFalse;
					} else {
						include[i] = TernaryTrue;
					}
				}
			}
		}
		if (include.indexOf(TernaryFalse) >= 0) {
			var filteredTypes:Array<Type> = null;
			for (i in 0...types.length) {
				if (include[i] == TernaryTrue) {
					if (filteredTypes == null) {
						filteredTypes = [];
					}
					filteredTypes.push(types[i]);
				}
			}
			final filtered = c.getUnionTypeEx(filteredTypes, UnionReductionNone, null, null);
			if (filtered.flags & TypeFlagsNever == 0) {
				return filtered;
			}
		}
		return target;
	}

	static function filterPrimitivesIfContainsNonPrimitive(c:Checker, unionType:Type):Type {
		if (c.maybeTypeOfKind(unionType, TypeFlagsNonPrimitive)) {
			final result = c.filterType(unionType, Checker.isNonPrimitiveType);
			if (result.flags & TypeFlagsNever == 0) {
				return result;
			}
		}
		return unionType;
	}

	static function getTypeNamesForErrorDisplay(c:Checker, left:Type, right:Type):Pair<std.String, std.String> {
		var leftStr:std.String;
		if (c.symbolValueDeclarationIsContextSensitive(left.symbol)) {
			leftStr = c.typeToString(left, left.symbol.ValueDeclaration);
		} else {
			leftStr = c.TypeToString(left);
		}
		var rightStr:std.String;
		if (c.symbolValueDeclarationIsContextSensitive(right.symbol)) {
			rightStr = c.typeToString(right, right.symbol.ValueDeclaration);
		} else {
			rightStr = c.TypeToString(right);
		}
		if (leftStr == rightStr) {
			leftStr = c.getTypeNameForErrorDisplay(left);
			rightStr = c.getTypeNameForErrorDisplay(right);
		}
		return new Pair(leftStr, rightStr);
	}

	static function getTypeNameForErrorDisplay(c:Checker, t:Type):std.String {
		return c.typeToStringEx(t, null /*enclosingDeclaration*/, TypeFormatFlagsUseFullyQualifiedType, null);
	}

	static function symbolValueDeclarationIsContextSensitive(c:Checker, symbol:Symbol):Bool {
		return symbol != null && symbol.ValueDeclaration != null && Ast.IsExpression(symbol.ValueDeclaration) && !c.isContextSensitive(symbol.ValueDeclaration);
	}

	static function typeCouldHaveTopLevelSingletonTypes(c:Checker, t:Type):Bool {
		// Okay, yes, 'boolean' is a union of 'true | false', but that's not useful
		// in error reporting scenarios. If you need to use this function but that detail matters,
		// feel free to add a flag.
		if (t.flags & TypeFlagsBoolean != 0) {
			return false;
		}
		if (t.flags & TypeFlagsUnionOrIntersection != 0) {
			return Core.Some(t.Types(), t -> c.typeCouldHaveTopLevelSingletonTypes(t));
		}
		if (t.flags & TypeFlagsInstantiable != 0) {
			final constraint = c.getConstraintOfType(t);
			if (constraint != null && constraint != t) {
				return c.typeCouldHaveTopLevelSingletonTypes(constraint);
			}
		}
		return Checker.isUnitType(t) || t.flags & TypeFlagsTemplateLiteral != 0 || t.flags & TypeFlagsStringMapping != 0;
	}

	static function getVariances(c:Checker, t:Type):Array<VarianceFlags> {
		// Arrays and tuples are known to be covariant, no need to spend time computing this.
		if (t == c.globalArrayType || t == c.globalReadonlyArrayType || t.objectFlags & ObjectFlagsTuple != 0) {
			return c.arrayVariances;
		}
		return c.getVariancesWorker(t.symbol, t.AsInterfaceType().TypeParameters());
	}

	static function getAliasVariances(c:Checker, symbol:Symbol):Array<VarianceFlags> {
		return c.getVariancesWorker(symbol, c.typeAliasLinks.Get(symbol).typeParameters);
	}

	// Return an array containing the variance of each type parameter. The variance is effectively
	// a digest of the type comparisons that occur for each type argument when instantiations of the
	// generic type are structurally compared. We infer the variance information by comparing
	// instantiations of the generic type for type arguments with known relations. The function
	// returns an empty slice when invoked recursively for the given generic type.
	static function getVariancesWorker(c:Checker, symbol:Symbol, typeParameters:Array<Type>):Array<VarianceFlags> {
		final links = c.varianceLinks.Get(symbol);
		if (links.variances == null) {
			var traceArgs:StringMap<Any> = null;
			var deferred:() -> Void = null; // PORT: defer (no early return in this block)
			final tr = c.tracer;
			if (tr != null) {
				traceArgs = new StringMap<Any>();
				traceArgs.set("arity", Core.len(typeParameters));
				traceArgs.set("id", c.getDeclaredTypeOfSymbol(symbol).id);
				final popFn = tr.Push(PhaseCheckTypes, "getVariancesWorker", traceArgs, true);
				deferred = () -> {
					final formatted:Array<std.String> = [for (v in links.variances) v.String()];
					traceArgs.set("variances", formatted);
					popFn();
				};
			}
			final oldVarianceComputation = c.inVarianceComputation;
			final saveResolutionStart = c.resolutionStart;
			if (!c.inVarianceComputation) {
				c.inVarianceComputation = true;
				c.resolutionStart = Core.len(c.typeResolutions);
			}
			links.variances = [];
			final variances:Array<VarianceFlags> = [for (_ in 0...Core.len(typeParameters)) VarianceFlagsInvariant];
			for (i in 0...Core.len(typeParameters)) {
				final tp = typeParameters[i];
				final modifiers = c.getTypeParameterModifiers(tp);
				var variance:VarianceFlags = 0;
				if (modifiers & ModifierFlagsOut != 0) {
					if (modifiers & ModifierFlagsIn != 0) {
						variance = VarianceFlagsInvariant;
					} else {
						variance = VarianceFlagsCovariant;
					}
				} else if (modifiers & ModifierFlagsIn != 0) {
					variance = VarianceFlagsContravariant;
				} else {
					final saveReliabilityFlags = c.reliabilityFlags;
					c.reliabilityFlags = 0;
					// We first compare instantiations where the type parameter is replaced with
					// marker types that have a known subtype relationship. From this we can infer
					// invariance, covariance, contravariance or bivariance.
					final typeWithSuper = c.createMarkerType(symbol, tp, c.markerSuperType);
					final typeWithSub = c.createMarkerType(symbol, tp, c.markerSubType);
					final co:VarianceFlags = c.isTypeAssignableTo(typeWithSub, typeWithSuper) ? VarianceFlagsCovariant : 0;
					final contra:VarianceFlags = c.isTypeAssignableTo(typeWithSuper, typeWithSub) ? VarianceFlagsContravariant : 0;
					variance = co | contra;
					// If the instantiations appear to be related bivariantly it may be because the
					// type parameter is independent (i.e. it isn't witnessed anywhere in the generic
					// type). To determine this we compare instantiations where the type parameter is
					// replaced with marker types that are known to be unrelated.
					if (variance == VarianceFlagsBivariant && c.isTypeAssignableTo(c.createMarkerType(symbol, tp, c.markerOtherType), typeWithSuper)) {
						variance = VarianceFlagsIndependent;
					}
					if (c.reliabilityFlags & RelationComparisonResultReportsUnmeasurable != 0) {
						variance |= VarianceFlagsUnmeasurable;
					}
					if (c.reliabilityFlags & RelationComparisonResultReportsUnreliable != 0) {
						variance |= VarianceFlagsUnreliable;
					}
					c.reliabilityFlags = saveReliabilityFlags;
				}
				variances[i] = variance;
			}
			if (!oldVarianceComputation) {
				c.inVarianceComputation = false;
				c.resolutionStart = saveResolutionStart;
			}
			links.variances = variances;
			if (deferred != null) {
				deferred();
			}
		}
		return links.variances;
	}

	static function createMarkerType(c:Checker, symbol:Symbol, source:Type, target:Type):Type {
		final mapper = Checker.newSimpleTypeMapper(source, target);
		final t = c.getDeclaredTypeOfSymbol(symbol);
		if (c.isErrorType(t)) {
			return t;
		}
		var result:Type = null;
		if (symbol.Flags & SymbolFlagsTypeAlias != 0) {
			result = c.getTypeAliasInstantiation(symbol, c.instantiateTypes(c.typeAliasLinks.Get(symbol).typeParameters, mapper), null);
		} else {
			result = c.createTypeReference(t, c.instantiateTypes(t.AsInterfaceType().TypeParameters(), mapper));
		}
		c.markerTypes.Add(result);
		return result;
	}

	static function isMarkerType(c:Checker, t:Type):Bool {
		return c.markerTypes.Has(t);
	}

	static function getTypeParameterModifiers(c:Checker, tp:Type):ModifierFlags {
		var flags:ModifierFlags = 0;
		if (tp.symbol != null && tp.symbol.Declarations != null) {
			for (d in tp.symbol.Declarations) {
				flags |= d.ModifierFlags();
			}
		}
		return flags & (ModifierFlagsIn | ModifierFlagsOut | ModifierFlagsConst);
	}

	// Return true if the given type reference has a 'void' type argument for a covariant type parameter.
	// See comment at call in recursiveTypeRelatedTo for when this case matters.
	static function hasCovariantVoidArgument(c:Checker, typeArguments:Array<Type>, variances:Array<VarianceFlags>):Bool {
		for (i in 0...Core.len(variances)) {
			final v = variances[i];
			if (v & VarianceFlagsVarianceMask == VarianceFlagsCovariant && typeArguments[i].flags & TypeFlagsVoid != 0) {
				return true;
			}
		}
		return false;
	}

	static function isSignatureAssignableTo(c:Checker, source:Signature, target:Signature, ignoreReturnTypes:Bool):Bool {
		return c.compareSignaturesRelated(source, target, ignoreReturnTypes ? SignatureCheckModeIgnoreReturnTypes : SignatureCheckModeNone, false /*reportErrors*/,
			null /*errorReporter*/, (s, t, reportErrors) -> c.compareTypesAssignable(s, t, reportErrors), null /*reportUnreliableMarkers*/) != TernaryFalse;
	}

	static function compareSignaturesRelated(c:Checker, source:Signature, target:Signature, checkMode:SignatureCheckMode, reportErrors:Bool, errorReporter:ErrorReporter, compareTypes:TypeComparer, reportUnreliableMarkers:TypeMapper):Ternary {
		if (source == target) {
			return TernaryTrue;
		}
		if (!(checkMode & SignatureCheckModeStrictTopSignature != 0 && c.isTopSignature(source)) && c.isTopSignature(target)) {
			return TernaryTrue;
		}
		if (checkMode & SignatureCheckModeStrictTopSignature != 0 && c.isTopSignature(source) && !c.isTopSignature(target)) {
			return TernaryFalse;
		}
		final targetCount = c.getParameterCount(target);
		var sourceHasMoreParameters = false;
		if (!c.hasEffectiveRestParameter(target)) {
			if (checkMode & SignatureCheckModeStrictArity != 0) {
				sourceHasMoreParameters = c.hasEffectiveRestParameter(source) || c.getParameterCount(source) > targetCount;
			} else {
				sourceHasMoreParameters = c.getMinArgumentCount(source) > targetCount;
			}
		}
		if (sourceHasMoreParameters) {
			if (reportErrors && (checkMode & SignatureCheckModeStrictArity == 0)) {
				// the second condition should be redundant, because there is no error reporting when comparing signatures by strict arity
				// since it is only done for subtype reduction
				errorReporter(Diagnostics.Target_signature_provides_too_few_arguments_Expected_0_or_more_but_got_1, c.getMinArgumentCount(source), targetCount);
			}
			return TernaryFalse;
		}
		if (Core.len(source.typeParameters) != 0 && !Core.Same(source.typeParameters, target.typeParameters)) {
			target = c.getCanonicalSignature(target);
			source = c.instantiateSignatureInContextOf(source, target /*inferenceContext*/, null, compareTypes);
		}
		final sourceCount = c.getParameterCount(source);
		final sourceRestType = c.getNonArrayRestType(source);
		final targetRestType = c.getNonArrayRestType(target);
		if (sourceRestType != null || targetRestType != null) {
			c.instantiateType(sourceRestType != null ? sourceRestType : targetRestType, reportUnreliableMarkers);
		}
		var kind = KindUnknown;
		if (target.declaration != null) {
			kind = target.declaration.Kind;
		}
		final strictVariance = checkMode & SignatureCheckModeCallback == 0 && c.strictFunctionTypes && kind != KindMethodDeclaration && kind != KindMethodSignature
			&& kind != KindConstructor;
		var result:Ternary = TernaryTrue;
		final sourceThisType = c.getThisTypeOfSignature(source);
		if (sourceThisType != null && sourceThisType != c.voidType) {
			final targetThisType = c.getThisTypeOfSignature(target);
			if (targetThisType != null) {
				// void sources are assignable to anything.
				var related:Ternary = TernaryFalse;
				if (!strictVariance) {
					related = compareTypes(sourceThisType, targetThisType, false /*reportErrors*/);
				}
				if (related == TernaryFalse) {
					related = compareTypes(targetThisType, sourceThisType, reportErrors);
				}
				if (related == TernaryFalse) {
					if (reportErrors) {
						errorReporter(Diagnostics.The_this_types_of_each_signature_are_incompatible);
					}
					return TernaryFalse;
				}
				result &= related;
			}
		}
		var paramCount:Int;
		if (sourceRestType != null || targetRestType != null) {
			paramCount = sourceCount < targetCount ? sourceCount : targetCount;
		} else {
			paramCount = sourceCount > targetCount ? sourceCount : targetCount;
		}
		var restIndex:Int;
		if (sourceRestType != null || targetRestType != null) {
			restIndex = paramCount - 1;
		} else {
			restIndex = -1;
		}
		for (i in 0...paramCount) {
			var sourceType:Type;
			if (i == restIndex) {
				sourceType = c.getRestOrAnyTypeAtPosition(source, i);
			} else {
				sourceType = c.tryGetTypeAtPosition(source, i);
			}
			var targetType:Type;
			if (i == restIndex) {
				targetType = c.getRestOrAnyTypeAtPosition(target, i);
			} else {
				targetType = c.tryGetTypeAtPosition(target, i);
			}
			if (sourceType != null && targetType != null && (sourceType != targetType || checkMode & SignatureCheckModeStrictArity != 0)) {
				// In order to ensure that any generic type Foo<T> is at least co-variant with respect to T no matter
				// how Foo uses T, we need to relate parameters bi-variantly (given that parameters are input positions,
				// they naturally relate only contra-variantly). However, if the source and target parameters both have
				// function types with a single call signature, we know we are relating two callback parameters. In
				// that case it is sufficient to only relate the parameters of the signatures co-variantly because,
				// similar to return values, callback parameters are output positions. This means that a Promise<T>,
				// where T is used only in callback parameter positions, will be co-variant (as opposed to bi-variant)
				// with respect to T.
				var sourceSig:Signature = null;
				var targetSig:Signature = null;
				if (checkMode & SignatureCheckModeCallback == 0 && !c.isInstantiatedGenericParameter(source, i)) {
					sourceSig = c.getSingleCallSignature(c.GetNonNullableType(sourceType));
				}
				if (checkMode & SignatureCheckModeCallback == 0 && !c.isInstantiatedGenericParameter(target, i)) {
					targetSig = c.getSingleCallSignature(c.GetNonNullableType(targetType));
				}
				final callbacks = sourceSig != null && targetSig != null && c.getTypePredicateOfSignature(sourceSig) == null
					&& c.getTypePredicateOfSignature(targetSig) == null
					&& c.getTypeFacts(sourceType, TypeFactsIsUndefinedOrNull) == c.getTypeFacts(targetType, TypeFactsIsUndefinedOrNull);
				var related:Ternary = TernaryFalse;
				if (callbacks) {
					related = c.compareSignaturesRelated(targetSig, sourceSig,
						(checkMode & SignatureCheckModeStrictArity) | (strictVariance ? SignatureCheckModeStrictCallback : SignatureCheckModeBivariantCallback), reportErrors,
						errorReporter, compareTypes, reportUnreliableMarkers);
				} else {
					if (checkMode & SignatureCheckModeCallback == 0 && !strictVariance) {
						related = compareTypes(sourceType, targetType, false /*reportErrors*/);
					}
					if (related == TernaryFalse) {
						related = compareTypes(targetType, sourceType, reportErrors);
					}
				}
				// With strict arity, (x: number | undefined) => void is a subtype of (x?: number | undefined) => void
				if (related != TernaryFalse && checkMode & SignatureCheckModeStrictArity != 0 && i >= c.getMinArgumentCount(source) && i < c.getMinArgumentCount(target)
					&& compareTypes(sourceType, targetType, false /*reportErrors*/) != TernaryFalse) {
					related = TernaryFalse;
				}
				if (related == TernaryFalse) {
					if (reportErrors) {
						errorReporter(Diagnostics.Types_of_parameters_0_and_1_are_incompatible, c.getParameterNameAtPosition(source, i),
							c.getParameterNameAtPosition(target, i));
					}
					return TernaryFalse;
				}
				result &= related;
			}
		}
		if (checkMode & SignatureCheckModeIgnoreReturnTypes == 0) {
			// If a signature resolution is already in-flight, skip issuing a circularity error
			// here and just use the `any` type directly
			final targetReturnType = c.getNonCircularReturnTypeOfSignature(target);
			if (targetReturnType == c.voidType || targetReturnType == c.anyType) {
				return result;
			}
			final sourceReturnType = c.getNonCircularReturnTypeOfSignature(source);
			// The following block preserves behavior forbidding boolean returning functions from being assignable to type guard returning functions
			final targetTypePredicate = c.getTypePredicateOfSignature(target);
			if (targetTypePredicate != null) {
				final sourceTypePredicate = c.getTypePredicateOfSignature(source);
				if (sourceTypePredicate != null) {
					result &= c.compareTypePredicateRelatedTo(sourceTypePredicate, targetTypePredicate, reportErrors, errorReporter, compareTypes);
				} else if (targetTypePredicate.kind == TypePredicateKindIdentifier || targetTypePredicate.kind == TypePredicateKindThis) {
					if (reportErrors) {
						errorReporter(Diagnostics.Signature_0_must_be_a_type_predicate, c.signatureToString(source));
					}
					return TernaryFalse;
				}
			} else {
				// When relating callback signatures, we still need to relate return types bi-variantly as otherwise
				// the containing type wouldn't be co-variant. For example, interface Foo<T> { add(cb: () => T): void }
				// wouldn't be co-variant for T without this rule.
				var related:Ternary = TernaryFalse;
				if (checkMode & SignatureCheckModeBivariantCallback != 0) {
					related = compareTypes(targetReturnType, sourceReturnType, false /*reportErrors*/);
				}
				if (related == TernaryFalse) {
					related = compareTypes(sourceReturnType, targetReturnType, reportErrors);
				}
				result &= related;
				if (result == TernaryFalse && reportErrors) {
					// The errors reported here serve as markers that trigger error chain reduction in the (*Relater).reportError
					// method. The markers are elided in the final diagnostic chain and never actually reported.
					var message:Message;
					if (Core.len(source.parameters) == 0 && Core.len(target.parameters) == 0) {
						message = source.flags & SignatureFlagsConstruct != 0 ? Diagnostics.Construct_signatures_with_no_arguments_have_incompatible_return_types_0_and_1 : Diagnostics.Call_signatures_with_no_arguments_have_incompatible_return_types_0_and_1;
					} else {
						message = source.flags & SignatureFlagsConstruct != 0 ? Diagnostics.Construct_signature_return_types_0_and_1_are_incompatible : Diagnostics.Call_signature_return_types_0_and_1_are_incompatible;
					}
					errorReporter(message, c.TypeToString(sourceReturnType), c.TypeToString(targetReturnType));
				}
			}
		}
		return result;
	}

	static function compareTypePredicateRelatedTo(c:Checker, source:TypePredicate, target:TypePredicate, reportErrors:Bool, errorReporter:ErrorReporter, compareTypes:TypeComparer):Ternary {
		if (source.kind != target.kind) {
			if (reportErrors) {
				errorReporter(Diagnostics.A_this_based_type_guard_is_not_compatible_with_a_parameter_based_type_guard);
				errorReporter(Diagnostics.Type_predicate_0_is_not_assignable_to_1, c.typePredicateToString(source), c.typePredicateToString(target));
			}
			return TernaryFalse;
		}
		if (source.kind == TypePredicateKindIdentifier || source.kind == TypePredicateKindAssertsIdentifier) {
			if (source.parameterIndex != target.parameterIndex) {
				if (reportErrors) {
					errorReporter(Diagnostics.Parameter_0_is_not_in_the_same_position_as_parameter_1, source.parameterName, target.parameterName);
					errorReporter(Diagnostics.Type_predicate_0_is_not_assignable_to_1, c.typePredicateToString(source), c.typePredicateToString(target));
				}
				return TernaryFalse;
			}
		}
		var related:Ternary;
		if (source.t == target.t) {
			related = TernaryTrue;
		} else if (source.t != null && target.t != null) {
			related = compareTypes(source.t, target.t, reportErrors);
		} else {
			related = TernaryFalse;
		}
		if (related == TernaryFalse && reportErrors) {
			errorReporter(Diagnostics.Type_predicate_0_is_not_assignable_to_1, c.typePredicateToString(source), c.typePredicateToString(target));
		}
		return related;
	}

	// Returns true if `s` is `(...args: A) => R` where `A` is `any`, `any[]`, `never`, or `never[]`, and `R` is `any` or `unknown`.
	static function isTopSignature(c:Checker, s:Signature):Bool {
		if (Core.len(s.typeParameters) == 0 && (s.thisParameter == null || Checker.IsTypeAny(c.getTypeOfParameter(s.thisParameter))) && Core.len(s.parameters) == 1
			&& Checker.signatureHasRestParameter(s)) {
			final paramType = c.getTypeOfParameter(s.parameters[0]);
			var restType:Type;
			if (c.isArrayType(paramType)) {
				restType = c.getTypeArguments(paramType)[0];
			} else {
				restType = paramType;
			}
			return restType.flags & (TypeFlagsAny | TypeFlagsNever) != 0 && c.getReturnTypeOfSignature(s).flags & TypeFlagsAnyOrUnknown != 0;
		}
		return false;
	}

	// Return the number of parameters in a signature. The rest parameter, if present, counts as one
	// parameter. For example, the parameter count of (x: number, y: number, ...z: string[]) is 3 and
	// the parameter count of (x: number, ...args: [number, ...string[], boolean])) is also 3. In the
	// latter example, the effective rest type is [...string[], boolean].
	static function getParameterCount(c:Checker, signature:Signature):Int {
		final length = Core.len(signature.parameters);
		if (Checker.signatureHasRestParameter(signature)) {
			final restType = c.getTypeOfSymbol(signature.parameters[length - 1]);
			if (Checker.isTupleType(restType)) {
				return length + restType.TargetTupleType().fixedLength - (restType.TargetTupleType().combinedFlags & ElementFlagsVariable != 0 ? 0 : 1);
			}
		}
		return length;
	}

	static function getMinArgumentCount(c:Checker, signature:Signature):Int {
		return c.getMinArgumentCountEx(signature, MinArgumentCountFlagsNone);
	}

	static function getMinArgumentCountEx(c:Checker, signature:Signature, flags:MinArgumentCountFlags):Int {
		final strongArityForUntypedJS = flags & MinArgumentCountFlagsStrongArityForUntypedJS;
		final voidIsNonOptional = flags & MinArgumentCountFlagsVoidIsNonOptional;
		if (voidIsNonOptional != 0 || signature.resolvedMinArgumentCount == -1) {
			var minArgumentCount = -1;
			if (Checker.signatureHasRestParameter(signature)) {
				final restType = c.getTypeOfSymbol(signature.parameters[signature.parameters.length - 1]);
				if (Checker.isTupleType(restType)) {
					final firstOptionalIndex = Core.FindIndex(restType.TargetTupleType().elementInfos, info -> info.flags & ElementFlagsRequired == 0);
					var requiredCount = firstOptionalIndex;
					if (firstOptionalIndex < 0) {
						requiredCount = restType.TargetTupleType().fixedLength;
					}
					if (requiredCount > 0) {
						minArgumentCount = signature.parameters.length - 1 + requiredCount;
					}
				}
			}
			if (minArgumentCount == -1) {
				if (strongArityForUntypedJS == 0 && signature.flags & SignatureFlagsIsUntypedSignatureInJSFile != 0) {
					return 0;
				}
				minArgumentCount = signature.minArgumentCount;
			}
			if (voidIsNonOptional != 0) {
				return minArgumentCount;
			}
			var i = minArgumentCount - 1;
			while (i >= 0) {
				final t = c.getTypeAtPosition(signature, i);
				if (!Checker.someType(t, t -> t.flags & TypeFlagsVoid != 0)) {
					break;
				}
				minArgumentCount = i;
				i--;
			}
			signature.resolvedMinArgumentCount = minArgumentCount;
		}
		return signature.resolvedMinArgumentCount;
	}

	static function hasEffectiveRestParameter(c:Checker, signature:Signature):Bool {
		if (Checker.signatureHasRestParameter(signature)) {
			final restType = c.getTypeOfSymbol(signature.parameters[signature.parameters.length - 1]);
			return !Checker.isTupleType(restType) || restType.TargetTupleType().combinedFlags & ElementFlagsVariable != 0;
		}
		return false;
	}

	static function getTypeAtPosition(c:Checker, signature:Signature, pos:Int):Type {
		final t = c.tryGetTypeAtPosition(signature, pos);
		if (t != null) {
			return t;
		}
		return c.anyType;
	}

	static function tryGetTypeAtPosition(c:Checker, signature:Signature, pos:Int):Type {
		final paramCount = Core.len(signature.parameters) - (Checker.signatureHasRestParameter(signature) ? 1 : 0);
		if (pos < paramCount) {
			return c.getTypeOfParameter(signature.parameters[pos]);
		}
		if (Checker.signatureHasRestParameter(signature)) {
			// We want to return the value undefined for an out of bounds parameter position,
			// so we need to check bounds here before calling getIndexedAccessType (which
			// otherwise would return the type 'undefined').
			final restType = c.getTypeOfSymbol(signature.parameters[paramCount]);
			final index = pos - paramCount;
			if (!Checker.isTupleType(restType) || restType.TargetTupleType().combinedFlags & ElementFlagsVariable != 0
				|| index < restType.TargetTupleType().fixedLength) {
				return c.getIndexedAccessType(restType, c.getNumberLiteralType((index : Number)));
			}
		}
		return null;
	}

	// Return the rest type at the given position, transforming `any[]` into just `any`. We do this because
	// in signatures we want `any[]` in a rest position to be compatible with anything, but `any[]` isn't
	// assignable to tuple types with required elements.
	static function getRestOrAnyTypeAtPosition(c:Checker, source:Signature, pos:Int):Type {
		final restType = c.getRestTypeAtPosition(source, pos, false);
		if (restType != null) {
			final elementType = c.getElementTypeOfArrayType(restType);
			if (elementType != null && Checker.IsTypeAny(elementType)) {
				return c.anyType;
			}
		}
		return restType;
	}

	static function getRestTypeAtPosition(c:Checker, source:Signature, pos:Int, readonly:Bool):Type {
		final parameterCount = c.getParameterCount(source);
		final minArgumentCount = c.getMinArgumentCount(source);
		final restType = c.getEffectiveRestType(source);
		if (restType != null && pos >= parameterCount - 1) {
			if (pos == parameterCount - 1) {
				return restType;
			} else {
				return c.createArrayType(c.getIndexedAccessType(restType, c.numberType));
			}
		}
		final length = parameterCount - pos;
		if (length <= 0) {
			return c.createTupleTypeEx(null, null, readonly);
		}
		final types:Array<Type> = [for (_ in 0...length) null];
		final infos:Array<TupleElementInfo> = [for (_ in 0...length) null];
		for (i in 0...length) {
			var flags:ElementFlags = 0;
			if (restType == null || i < length - 1) {
				types[i] = c.getTypeAtPosition(source, i + pos);
				flags = i + pos < minArgumentCount ? ElementFlagsRequired : ElementFlagsOptional;
			} else {
				types[i] = restType;
				flags = ElementFlagsVariadic;
			}
			final info = new TupleElementInfo();
			info.flags = flags;
			info.labeledDeclaration = c.getNameableDeclarationAtPosition(source, i + pos);
			infos[i] = info;
		}
		return c.createTupleTypeEx(types, infos, readonly);
	}

	static function getNameableDeclarationAtPosition(c:Checker, signature:Signature, pos:Int):Node {
		final paramCount = Core.len(signature.parameters) - (Checker.signatureHasRestParameter(signature) ? 1 : 0);
		if (pos < paramCount) {
			final decl = signature.parameters[pos].ValueDeclaration;
			if (decl != null && c.isValidDeclarationForTupleLabel(decl)) {
				return decl;
			}
			return null;
		}
		if (Checker.signatureHasRestParameter(signature)) {
			final restParameter = signature.parameters[paramCount];
			final restType = c.getTypeOfSymbol(restParameter);
			if (Checker.isTupleType(restType)) {
				final elementInfos = restType.TargetTupleType().elementInfos;
				final index = pos - paramCount;
				if (index < Core.len(elementInfos)) {
					return elementInfos[index].labeledDeclaration;
				}
				return null;
			}
			if (restParameter.ValueDeclaration != null && c.isValidDeclarationForTupleLabel(restParameter.ValueDeclaration)) {
				return restParameter.ValueDeclaration;
			}
		}
		return null;
	}

	static function isValidDeclarationForTupleLabel(c:Checker, d:Node):Bool {
		return Ast.IsNamedTupleMember(d) || Ast.IsParameterDeclaration(d) && d.Name() != null && Ast.IsIdentifier(d.Name());
	}

	static function getNonArrayRestType(c:Checker, signature:Signature):Type {
		final restType = c.getEffectiveRestType(signature);
		if (restType != null && !c.isArrayType(restType) && !Checker.IsTypeAny(restType)) {
			return restType;
		}
		return null;
	}

	static function getEffectiveRestType(c:Checker, signature:Signature):Type {
		if (Checker.signatureHasRestParameter(signature)) {
			final restType = c.getTypeOfSymbol(signature.parameters[signature.parameters.length - 1]);
			if (!Checker.isTupleType(restType)) {
				if (Checker.IsTypeAny(restType)) {
					return c.anyArrayType;
				}
				return restType;
			}
			if (restType.TargetTupleType().combinedFlags & ElementFlagsVariable != 0) {
				return c.sliceTupleType(restType, restType.TargetTupleType().fixedLength, 0);
			}
		}
		return null;
	}

	static function sliceTupleType(c:Checker, t:Type, index:Int, endSkipCount:Int):Type {
		final target = t.TargetTupleType();
		final endIndex = c.getTypeReferenceArity(t) - (endSkipCount > 0 ? endSkipCount : 0);
		if (index > target.fixedLength) {
			final restArrayType = c.getRestArrayTypeOfTupleType(t);
			if (restArrayType != null) {
				return restArrayType;
			}
			return c.createTupleType(null);
		}
		if (index >= endIndex) {
			return c.createTupleType(null);
		}
		return c.createTupleTypeEx(c.getTypeArguments(t).slice(index, endIndex), target.elementInfos.slice(index, endIndex), false /*readonly*/);
	}

	static function getKnownKeysOfTupleType(c:Checker, t:Type):Type {
		final fixedLength = t.TargetTupleType().fixedLength;
		final keys:Array<Type> = [for (_ in 0...fixedLength + 1) null];
		for (i in 0...fixedLength) {
			keys[i] = c.getStringLiteralType(Std.string(i));
		}
		keys[fixedLength] = c.getIndexType(t.TargetTupleType().readonly ? c.globalReadonlyArrayType : c.globalArrayType);
		return c.getUnionType(keys);
	}

	static function getRestArrayTypeOfTupleType(c:Checker, t:Type):Type {
		final restType = c.getRestTypeOfTupleType(t);
		if (restType != null) {
			return c.createArrayType(restType);
		}
		return null;
	}

	static function getThisTypeOfSignature(c:Checker, signature:Signature):Type {
		if (signature.thisParameter != null) {
			return c.getTypeOfSymbol(signature.thisParameter);
		}
		return null;
	}

	static function isInstantiatedGenericParameter(c:Checker, signature:Signature, pos:Int):Bool {
		if (signature.target == null) {
			return false;
		}
		final t = c.tryGetTypeAtPosition(signature.target, pos);
		return t != null && c.isGenericType(t);
	}

	static function getParameterNameAtPosition(c:Checker, signature:Signature, pos:Int):std.String {
		final paramCount = Core.len(signature.parameters) - (Checker.signatureHasRestParameter(signature) ? 1 : 0);
		if (pos < paramCount) {
			return signature.parameters[pos].Name;
		}
		final restParameter = signature.parameters[paramCount];
		final restType = c.getTypeOfSymbol(restParameter);
		if (Checker.isTupleType(restType)) {
			final index = pos - paramCount;
			return c.getTupleElementLabel(restType.TargetTupleType().elementInfos[index], restParameter, index);
		}
		return restParameter.Name;
	}

	static function getTupleElementLabel(c:Checker, elementInfo:TupleElementInfo, restSymbol:Symbol, index:Int):std.String {
		if (elementInfo.labeledDeclaration != null) {
			return elementInfo.labeledDeclaration.Name().Text();
		}
		if (restSymbol != null && restSymbol.ValueDeclaration != null && Ast.IsParameterDeclaration(restSymbol.ValueDeclaration)) {
			return c.getTupleElementLabelFromBindingElement(restSymbol.ValueDeclaration, index, elementInfo.flags);
		}
		var rootName:std.String;
		if (restSymbol != null) {
			rootName = restSymbol.Name;
		} else {
			rootName = "arg";
		}
		return rootName + "_" + Std.string(index);
	}

	static function getTupleElementLabelFromBindingElement(c:Checker, node:Node, index:Int, elementFlags:ElementFlags):std.String {
		if (node.Name() != null) {
			switch (node.Name().Kind) {
				case KindIdentifier:
					final name = node.Name().Text();
					if (Checker.hasDotDotDotToken(node)) {
						// given
						//   (...[x, y, ...z]: [number, number, ...number[]]) => ...
						// this produces
						//   (x: number, y: number, ...z: number[]) => ...
						// which preserves rest elements of 'z'

						// given
						//   (...[x, y, ...z]: [number, number, ...[...number[], number]]) => ...
						// this produces
						//   (x: number, y: number, ...z: number[], z_1: number) => ...
						// which preserves rest elements of z but gives distinct numbers to fixed elements of 'z'
						if (elementFlags & ElementFlagsVariable != 0) {
							return name;
						}
						return name + "_" + Std.string(index);
					}
					// given
					//   (...[x]: [number]) => ...
					// this produces
					//   (x: number) => ...
					// which preserves fixed elements of 'x'

					// given
					//   (...[x]: ...number[]) => ...
					// this produces
					//   (x_0: number) => ...
					// which which numbers fixed elements of 'x' whose tuple element type is variable
					if (elementFlags & ElementFlagsFixed != 0) {
						return name;
					}
					return name + "_n";
				case KindArrayBindingPattern:
					if (Checker.hasDotDotDotToken(node)) {
						final elements = node.Name().Elements();
						final lastElement = Core.LastOrNil(elements);
						final lastElementIsBindingElementRest = lastElement != null && Ast.IsBindingElement(lastElement) && Checker.hasDotDotDotToken(lastElement);
						final elementCount = Core.len(elements) - (lastElementIsBindingElementRest ? 1 : 0);
						if (index < elementCount) {
							final element = elements[index];
							if (Ast.IsBindingElement(element)) {
								return c.getTupleElementLabelFromBindingElement(element, index, elementFlags);
							}
						} else if (lastElementIsBindingElementRest) {
							return c.getTupleElementLabelFromBindingElement(lastElement, index - elementCount, elementFlags);
						}
					}
				default:
			}
		}
		return "arg_" + Std.string(index);
	}

	static function getTypePredicateOfSignature(c:Checker, sig:Signature):TypePredicate {
		if (sig.resolvedTypePredicate == null) {
			if (sig.target != null) {
				final targetTypePredicate = c.getTypePredicateOfSignature(sig.target);
				if (targetTypePredicate != null) {
					sig.resolvedTypePredicate = c.instantiateTypePredicate(targetTypePredicate, sig.mapper);
				}
			} else if (sig.composite != null) {
				sig.resolvedTypePredicate = c.getUnionOrIntersectionTypePredicate(sig.composite.signatures, sig.composite.isUnion);
			} else {
				if (sig.declaration != null) {
					final typeNode = sig.declaration.Type();
					if (typeNode != null) {
						if (Ast.IsTypePredicateNode(typeNode)) {
							sig.resolvedTypePredicate = c.createTypePredicateFromTypePredicateNode(typeNode, sig);
						}
					} else if (Ast.IsFunctionLikeDeclaration(sig.declaration)
						&& (sig.resolvedReturnType == null || sig.resolvedReturnType.flags & TypeFlagsBoolean != 0)
						&& c.getParameterCount(sig) > 0) {
						sig.resolvedTypePredicate = c.noTypePredicate; // avoid infinite loop
						sig.resolvedTypePredicate = c.getTypePredicateFromBody(sig.declaration);
					}
				}
			}
			if (sig.resolvedTypePredicate == null) {
				sig.resolvedTypePredicate = c.noTypePredicate;
			}
		}
		if (sig.resolvedTypePredicate == c.noTypePredicate) {
			return null;
		}
		return sig.resolvedTypePredicate;
	}

	static function getUnionOrIntersectionTypePredicate(c:Checker, signatures:Array<Signature>, isUnion:Bool):TypePredicate {
		var last:TypePredicate = null;
		var types:Array<Type> = null;
		if (signatures != null) {
			for (sig in signatures) {
				final pred = c.getTypePredicateOfSignature(sig);
				if (pred != null) {
					// Constituent type predicates must all have matching kinds. We don't create composite type predicates for assertions.
					if (pred.kind != TypePredicateKindThis && pred.kind != TypePredicateKindIdentifier || last != null && !c.typePredicateKindsMatch(last, pred)) {
						return null;
					}
					last = pred;
					if (types == null) {
						types = [];
					}
					types.push(pred.t);
				} else {
					// In composite union signatures we permit and ignore signatures with a return type `false`.
					var returnType:Type = null;
					if (isUnion) {
						returnType = c.getReturnTypeOfSignature(sig);
					}
					if (returnType != c.falseType && returnType != c.regularFalseType) {
						return null;
					}
				}
			}
		}
		if (last == null) {
			return null;
		}
		final compositeType = c.getUnionOrIntersectionType(types, isUnion, UnionReductionLiteral);
		return c.newTypePredicate(last.kind, last.parameterName, last.parameterIndex, compositeType);
	}

	static function typePredicateKindsMatch(c:Checker, a:TypePredicate, b:TypePredicate):Bool {
		return a.kind == b.kind && a.parameterIndex == b.parameterIndex;
	}

	static function createTypePredicateFromTypePredicateNode(c:Checker, node:Node, signature:Signature):TypePredicate {
		final predicateNode = node.AsTypePredicateNode();
		var t:Type = null;
		if (predicateNode.Type != null) {
			t = c.getTypeFromTypeNode(predicateNode.Type);
		}
		if (Ast.IsThisTypeNode(predicateNode.ParameterName)) {
			final kind = predicateNode.AssertsModifier != null ? TypePredicateKindAssertsThis : TypePredicateKindThis;
			return c.newTypePredicate(kind, "" /*parameterName*/, 0 /*parameterIndex*/, t);
		}
		final kind = predicateNode.AssertsModifier != null ? TypePredicateKindAssertsIdentifier : TypePredicateKindIdentifier;
		final name = predicateNode.ParameterName.Text();
		final index = Core.FindIndex(signature.parameters, p -> p.Name == name);
		return c.newTypePredicate(kind, name, index, t);
	}

	static function instantiateTypePredicate(c:Checker, predicate:TypePredicate, mapper:TypeMapper):TypePredicate {
		final t = c.instantiateType(predicate.t, mapper);
		if (t == predicate.t) {
			return predicate;
		}
		return c.newTypePredicate(predicate.kind, predicate.parameterName, predicate.parameterIndex, t);
	}

	static function newTypePredicate(c:Checker, kind:TypePredicateKind, parameterName:std.String, parameterIndex:Int, t:Type):TypePredicate {
		final p = new TypePredicate();
		p.kind = kind;
		p.parameterIndex = parameterIndex;
		p.parameterName = parameterName;
		p.t = t;
		return p;
	}

	static function isResolvingReturnTypeOfSignature(c:Checker, signature:Signature):Bool {
		if (signature.composite != null && Core.Some(signature.composite.signatures, s -> c.isResolvingReturnTypeOfSignature(s))) {
			return true;
		}
		return signature.resolvedReturnType == null && c.findResolutionCycleStartIndex((cast signature : TypeSystemEntity) /* PORT: Signature does not declare TypeSystemEntity in the skeleton */, TypeSystemPropertyNameResolvedReturnType) >= 0;
	}

	static function findMatchingSignatures(c:Checker, signatureLists:Array<Array<Signature>>, signature:Signature, listIndex:Int):Array<Signature> {
		if (Core.len(signature.typeParameters) != 0) {
			// We require an exact match for generic signatures, so we only return signatures from the first
			// signature list and only if they have exact matches in the other signature lists.
			if (listIndex > 0) {
				return null;
			}
			for (i in 1...signatureLists.length) {
				if (c.findMatchingSignature(signatureLists[i], signature, false /*partialMatch*/, false /*ignoreThisTypes*/, false /*ignoreReturnTypes*/) == null) {
					return null;
				}
			}
			return [signature];
		}
		var result:Array<Signature> = null;
		for (i in 0...signatureLists.length) {
			// Allow matching non-generic signatures to have excess parameters (as a fallback if exact parameter match is not found) and different return types.
			// Prefer matching this types if possible.
			var match:Signature;
			if (i == listIndex) {
				match = signature;
			} else {
				match = c.findMatchingSignature(signatureLists[i], signature, false /*partialMatch*/, false /*ignoreThisTypes*/, true /*ignoreReturnTypes*/);
				if (match == null) {
					match = c.findMatchingSignature(signatureLists[i], signature, true /*partialMatch*/, false /*ignoreThisTypes*/, true /*ignoreReturnTypes*/);
				}
			}
			if (match == null) {
				return null;
			}
			result = Core.AppendIfUnique(result, match);
		}
		return result;
	}

	static function findMatchingSignature(c:Checker, signatureList:Array<Signature>, signature:Signature, partialMatch:Bool, ignoreThisTypes:Bool, ignoreReturnTypes:Bool):Signature {
		final compareTypes:(s:Type, t:Type) -> Ternary = partialMatch ? (s, t) -> c.compareTypesSubtypeOf(s, t) : (s, t) -> c.compareTypesIdentical(s, t);
		if (signatureList != null) {
			for (s in signatureList) {
				if (c.compareSignaturesIdentical(s, signature, partialMatch, ignoreThisTypes, ignoreReturnTypes, compareTypes) != 0) {
					return s;
				}
			}
		}
		return null;
	}

	/**
	 * See signatureRelatedTo, compareSignaturesIdentical
	 */
	static function compareSignaturesIdentical(c:Checker, source:Signature, target:Signature, partialMatch:Bool, ignoreThisTypes:Bool, ignoreReturnTypes:Bool, compareTypes:(s:Type, t:Type) -> Ternary):Ternary {
		if (source == target) {
			return TernaryTrue;
		}
		if (!c.isMatchingSignature(source, target, partialMatch)) {
			return TernaryFalse;
		}
		// Check that the two signatures have the same number of type parameters.
		if (Core.len(source.typeParameters) != Core.len(target.typeParameters)) {
			return TernaryFalse;
		}
		// Check that type parameter constraints and defaults match. If they do, instantiate the source
		// signature with the type parameters of the target signature and continue the comparison.
		if (Core.len(target.typeParameters) != 0) {
			final mapper = Checker.newTypeMapper(source.typeParameters, target.typeParameters);
			for (i in 0...target.typeParameters.length) {
				final s = source.typeParameters[i];
				final t = target.typeParameters[i];
				if (!(s == t
					|| compareTypes(c.instantiateType(c.getConstraintOrUnknownFromTypeParameter(s), mapper), c.getConstraintOrUnknownFromTypeParameter(t)) != TernaryFalse
					&& compareTypes(c.instantiateType(c.getDefaultOrUnknownFromTypeParameter(s), mapper), c.getDefaultOrUnknownFromTypeParameter(t)) != TernaryFalse)) {
					return TernaryFalse;
				}
			}
			source = c.instantiateSignatureEx(source, mapper, true /*eraseTypeParameters*/);
		}
		var result:Ternary = TernaryTrue;
		if (!ignoreThisTypes) {
			final sourceThisType = c.getThisTypeOfSignature(source);
			if (sourceThisType != null) {
				final targetThisType = c.getThisTypeOfSignature(target);
				if (targetThisType != null) {
					final related = compareTypes(sourceThisType, targetThisType);
					if (related == TernaryFalse) {
						return TernaryFalse;
					}
					result &= related;
				}
			}
		}
		for (i in 0...c.getParameterCount(target)) {
			final s = c.getTypeAtPosition(source, i);
			final t = c.getTypeAtPosition(target, i);
			final related = compareTypes(t, s);
			if (related == TernaryFalse) {
				return TernaryFalse;
			}
			result &= related;
		}
		if (!ignoreReturnTypes) {
			final sourceTypePredicate = c.getTypePredicateOfSignature(source);
			final targetTypePredicate = c.getTypePredicateOfSignature(target);
			if (sourceTypePredicate != null || targetTypePredicate != null) {
				result &= c.compareTypePredicatesIdentical(sourceTypePredicate, targetTypePredicate, compareTypes);
			} else {
				result &= compareTypes(c.getReturnTypeOfSignature(source), c.getReturnTypeOfSignature(target));
			}
		}
		return result;
	}

	static function isMatchingSignature(c:Checker, source:Signature, target:Signature, partialMatch:Bool):Bool {
		final sourceParameterCount = c.getParameterCount(source);
		final targetParameterCount = c.getParameterCount(target);
		final sourceMinArgumentCount = c.getMinArgumentCount(source);
		final targetMinArgumentCount = c.getMinArgumentCount(target);
		final sourceHasRestParameter = c.hasEffectiveRestParameter(source);
		final targetHasRestParameter = c.hasEffectiveRestParameter(target);
		// A source signature matches a target signature if the two signatures have the same number of required,
		// optional, and rest parameters.
		if (sourceParameterCount == targetParameterCount && sourceMinArgumentCount == targetMinArgumentCount && sourceHasRestParameter == targetHasRestParameter) {
			return true;
		}
		// A source signature partially matches a target signature if the target signature has no fewer required
		// parameters
		if (partialMatch && sourceMinArgumentCount <= targetMinArgumentCount) {
			return true;
		}
		return false;
	}

	static function compareTypeParametersIdentical(c:Checker, sourceParams:Array<Type>, targetParams:Array<Type>):Bool {
		if (Core.len(sourceParams) != Core.len(targetParams)) {
			return false;
		}
		final mapper = Checker.newTypeMapper(targetParams, sourceParams);
		for (i in 0...Core.len(sourceParams)) {
			final source = sourceParams[i];
			final target = targetParams[i];
			if (source == target) {
				continue;
			}
			// We instantiate the target type parameter constraints into the source types so we can recognize `<T, U extends T>` as the same as `<A, B extends A>`
			if (!c.isTypeIdenticalTo(Core.OrElse(c.getConstraintFromTypeParameter(source), c.unknownType),
				c.instantiateType(Core.OrElse(c.getConstraintFromTypeParameter(target), c.unknownType), mapper))) {
				return false;
			}
			// We don't compare defaults - we just use the type parameter defaults from the first signature that seems to match.
			// It might make sense to combine these defaults in the future, but doing so intelligently requires knowing
			// if the parameter is used covariantly or contravariantly (so we intersect if it's used like a parameter or union if used like a return type)
			// and, since it's just an inference _default_, just picking one arbitrarily works OK.
		}
		return true;
	}

	static function compareTypePredicatesIdentical(c:Checker, source:TypePredicate, target:TypePredicate, compareTypes:(s:Type, t:Type) -> Ternary):Ternary {
		if (source == null || target == null || !c.typePredicateKindsMatch(source, target)) {
			return TernaryFalse;
		} else if (source.t == target.t) {
			return TernaryTrue;
		} else if (source.t != null && target.t != null) {
			return compareTypes(source.t, target.t);
		}
		return TernaryFalse;
	}

	static function getEffectiveConstraintOfIntersection(c:Checker, types:Array<Type>, targetIsUnion:Bool):Type {
		var constraints:Array<Type> = null;
		var hasDisjointDomainType = false;
		for (t in types) {
			if (t.flags & TypeFlagsInstantiable != 0) {
				// We keep following constraints as long as we have an instantiable type that is known
				// not to be circular or infinite (hence we stop on index access types).
				var constraint = c.getConstraintOfType(t);
				while (constraint != null && constraint.flags & (TypeFlagsTypeParameter | TypeFlagsIndex | TypeFlagsConditional) != 0) {
					constraint = c.getConstraintOfType(constraint);
				}
				if (constraint != null) {
					if (constraints == null) {
						constraints = [];
					}
					constraints.push(constraint);
					if (targetIsUnion) {
						constraints.push(t);
					}
				}
			} else if (t.flags & TypeFlagsDisjointDomains != 0 || c.IsEmptyAnonymousObjectType(t)) {
				hasDisjointDomainType = true;
			}
		}
		// If the target is a union type or if we are intersecting with types belonging to one of the
		// disjoint domains, we may end up producing a constraint that hasn't been examined before.
		if (constraints != null && (targetIsUnion || hasDisjointDomainType)) {
			if (hasDisjointDomainType) {
				// We add any types belong to one of the disjoint domains because they might cause the final
				// intersection operation to reduce the union constraints.
				for (t in types) {
					if (t.flags & TypeFlagsDisjointDomains != 0 || c.IsEmptyAnonymousObjectType(t)) {
						constraints.push(t);
					}
				}
			}
			// The source types were normalized; ensure the result is normalized too.
			return c.getNormalizedType(c.getIntersectionTypeEx(constraints, IntersectionFlagsNoConstraintReduction, null), false /*writing*/);
		}
		return null;
	}

	static function templateLiteralTypesDefinitelyUnrelated(c:Checker, source:TemplateLiteralType, target:TemplateLiteralType):Bool {
		// Two template literal types with differences in their starting or ending text spans are definitely unrelated.
		final sourceStart = source.texts[0];
		final targetStart = target.texts[0];
		final sourceEnd = source.texts[source.texts.length - 1];
		final targetEnd = target.texts[target.texts.length - 1];
		final startLen = sourceStart.length < targetStart.length ? sourceStart.length : targetStart.length;
		final endLen = sourceEnd.length < targetEnd.length ? sourceEnd.length : targetEnd.length;
		return sourceStart.substring(0, startLen) != targetStart.substring(0, startLen)
			|| sourceEnd.substring(sourceEnd.length - endLen) != targetEnd.substring(targetEnd.length - endLen);
	}

	static function isTypeMatchedByTemplateLiteralType(c:Checker, source:Type, target:TemplateLiteralType, compareTypes:TypeComparer):Bool {
		final inferences = c.inferTypesFromTemplateLiteralType(source, target);
		if (inferences != null) {
			for (i in 0...inferences.length) {
				if (!c.isValidTypeForTemplateLiteralPlaceholder(inferences[i], target.types[i], compareTypes)) {
					return false;
				}
			}
			return true;
		}
		return false;
	}

	static function inferTypesFromTemplateLiteralType(c:Checker, source:Type, target:TemplateLiteralType):Array<Type> {
		if (source.flags & TypeFlagsStringLiteral != 0) {
			return c.inferFromLiteralPartsToTemplateLiteral([Checker.getStringLiteralValue(source)], null, target);
		} else if (source.flags & TypeFlagsTemplateLiteral != 0) {
			if (Slices.Equal(source.AsTemplateLiteralType().texts, target.texts)) {
				return Core.MapIndex(source.AsTemplateLiteralType().types, (s, i) -> {
					if (c.isTypeAssignableTo(c.getBaseConstraintOrType(s), c.getBaseConstraintOrType(target.types[i]))) {
						return s;
					}
					return c.getStringLikeTypeForType(s);
				});
			}
			return c.inferFromLiteralPartsToTemplateLiteral(source.AsTemplateLiteralType().texts, source.AsTemplateLiteralType().types, target);
		} else {
			return null;
		}
	}

	// This function infers from the text parts and type parts of a source literal to a target template literal. The number
	// of text parts is always one more than the number of type parts, and a source string literal is treated as a source
	// with one text part and zero type parts. The function returns an array of inferred string or template literal types
	// corresponding to the placeholders in the target template literal, or undefined if the source doesn't match the target.
	//
	// We first check that the starting source text part matches the starting target text part, and that the ending source
	// text part ends matches the ending target text part. We then iterate through the remaining target text parts, finding
	// a match for each in the source and inferring string or template literal types created from the segments of the source
	// that occur between the matches. During this iteration, seg holds the index of the current text part in the sourceTexts
	// array and pos holds the current character position in the current text part.
	//
	// Consider inference from type `<<${string}>.<${number}-${number}>>` to type `<${string}.${string}>`, i.e.
	//
	//	sourceTexts = ['<<', '>.<', '-', '>>']
	//	sourceTypes = [string, number, number]
	//	target.texts = ['<', '.', '>']
	//
	// We first match '<' in the target to the start of '<<' in the source and '>' in the target to the end of '>>' in
	// the source. The first match for the '.' in target occurs at character 1 in the source text part at index 1, and thus
	// the first inference is the template literal type `<${string}>`. The remainder of the source makes up the second
	// inference, the template literal type `<${number}-${number}>`.
	static function inferFromLiteralPartsToTemplateLiteral(c:Checker, sourceTexts:Array<std.String>, sourceTypes:Array<Type>, target:TemplateLiteralType):Array<Type> {
		final lastSourceIndex = sourceTexts.length - 1;
		final sourceStartText = sourceTexts[0];
		final sourceEndText = sourceTexts[lastSourceIndex];
		final targetTexts = target.texts;
		final lastTargetIndex = targetTexts.length - 1;
		final targetStartText = targetTexts[0];
		final targetEndText = targetTexts[lastTargetIndex];
		if (lastSourceIndex == 0 && sourceStartText.length < targetStartText.length + targetEndText.length || !StringTools.startsWith(sourceStartText, targetStartText)
			|| !StringTools.endsWith(sourceEndText, targetEndText)) {
			return null;
		}
		final remainingEndText = sourceEndText.substring(0, sourceEndText.length - targetEndText.length);
		var seg = 0;
		var pos = targetStartText.length;
		var matches:Array<Type> = null;
		final getSourceText = (index:Int) -> {
			if (index < lastSourceIndex) {
				return sourceTexts[index];
			}
			return remainingEndText;
		};
		final addMatch = (s:Int, p:Int) -> {
			var matchType:Type;
			if (s == seg) {
				matchType = c.getStringLiteralType(Stringutil.CombineSurrogatePairs(getSourceText(s).substring(pos, p)));
			} else {
				final matchTexts:Array<std.String> = [for (_ in 0...s - seg + 1) ""];
				matchTexts[0] = sourceTexts[seg].substring(pos);
				for (k in seg + 1...s) {
					matchTexts[k - seg] = sourceTexts[k];
				}
				matchTexts[s - seg] = getSourceText(s).substring(0, p);
				matchType = c.getTemplateLiteralType(matchTexts, sourceTypes.slice(seg, s));
			}
			if (matches == null) {
				matches = [];
			}
			matches.push(matchType);
			seg = s;
			pos = p;
		};
		for (i in 1...lastTargetIndex) {
			final delim = targetTexts[i];
			if (delim.length > 0) {
				var s = seg;
				var p = pos;
				while (true) {
					final text = getSourceText(s);
					final found = text.indexOf(delim, p);
					final d = found >= 0 && found >= p ? found - p : -1; // PORT: strings.Index(text[p:], delim)
					if (d >= 0) {
						p += d;
						break;
					}
					s++;
					if (s == sourceTexts.length) {
						return null;
					}
					p = 0;
				}
				addMatch(s, p);
				pos += delim.length;
			} else {
				final sourceText = getSourceText(seg);
				if (pos < sourceText.length) {
					// Consume one code point at a time, matching the string iterator
					// (`[x, ..._] = s`) rather than UTF-16 code-unit indexing (`s[0]`).
					// DecodeJSStringRune is required rather than utf8.DecodeRuneInString
					// because a lone surrogate is stored as an invalid-UTF-8 sentinel;
					// utf8 would treat that as an error and advance a single byte,
					// breaking the sentinel into stray bytes, whereas DecodeJSStringRune
					// pulls the whole sentinel off as one code point.
					//
					// This intentionally diverges from Strada, which advances one UTF-16
					// code unit at a time (`s[0]` semantics) and therefore splits a
					// supplementary code point such as an emoji into its surrogate
					// halves. If we ever need to match that, expand sourceTexts and
					// targetTexts into code-unit space up front with a SplitSurrogatePairs
					// helper (the inverse of CombineSurrogatePairs) and decode by code
					// unit here; the CombineSurrogatePairs call in addMatch already
					// recombines captured halves back into canonical form.
					final size = go.Utf16.RuneLen(Stringutil.DecodeJSStringRune(sourceText, pos));
					addMatch(seg, pos + size);
				} else if (seg < lastSourceIndex) {
					addMatch(seg + 1, 0);
				} else {
					return null;
				}
			}
		}
		addMatch(lastSourceIndex, getSourceText(lastSourceIndex).length);
		return matches;
	}

	static function getStringLikeTypeForType(c:Checker, t:Type):Type {
		if (t.flags & (TypeFlagsAny | TypeFlagsStringLike) != 0) {
			return t;
		}
		return c.getTemplateLiteralType(["", ""], [t]);
	}

	static function isValidTypeForTemplateLiteralPlaceholder(c:Checker, source:Type, target:Type, compareTypes:TypeComparer):Bool {
		if (target.flags & TypeFlagsIntersection != 0) {
			return Core.Every(target.Types(), t -> t == c.emptyTypeLiteralType || c.isValidTypeForTemplateLiteralPlaceholder(source, t, compareTypes));
		} else if (target.flags & TypeFlagsString != 0 || compareTypes(source, target, false) != TernaryFalse) {
			return true;
		} else if (source.flags & TypeFlagsStringLiteral != 0) {
			final value = Checker.getStringLiteralValue(source);
			return target.flags & TypeFlagsNumber != 0 && Checker.isValidNumberString(value, false /*roundTripOnly*/)
				|| target.flags & TypeFlagsBigInt != 0 && Checker.isValidBigIntString(value, false /*roundTripOnly*/)
				|| target.flags & (TypeFlagsBooleanLiteral | TypeFlagsNullable) != 0 && value == target.AsIntrinsicType().intrinsicName
				|| target.flags & TypeFlagsStringMapping != 0 && c.isMemberOfStringMapping(source, target)
				|| target.flags & TypeFlagsTemplateLiteral != 0 && c.isTypeMatchedByTemplateLiteralType(source, target.AsTemplateLiteralType(), compareTypes);
		} else if (source.flags & TypeFlagsTemplateLiteral != 0) {
			final texts = source.AsTemplateLiteralType().texts;
			return texts.length == 2 && texts[0] == "" && texts[1] == "" && compareTypes(source.AsTemplateLiteralType().types[0], target, false) != TernaryFalse;
		}
		return false;
	}

	static function isMemberOfStringMapping(c:Checker, source:Type, target:Type):Bool {
		if (target.flags & TypeFlagsAny != 0) {
			return true;
		} else if (target.flags & (TypeFlagsString | TypeFlagsTemplateLiteral) != 0) {
			return c.isTypeAssignableTo(source, target);
		} else if (target.flags & TypeFlagsStringMapping != 0) {
			// We need to see whether applying the same mappings of the target
			// onto the source would produce an identical type *and* that
			// it's compatible with the inner-most non-string-mapped type.
			//
			// The intuition here is that if same mappings don't affect the source at all,
			// and the source is compatible with the unmapped target, then they must
			// still reside in the same domain.
			final r = c.applyTargetStringMappingToSource(source, target);
			return r.a == source && c.isMemberOfStringMapping(source, r.b);
		}
		return false;
	}

	static function applyTargetStringMappingToSource(c:Checker, source:Type, target:Type):Pair<Type, Type> {
		var inner = target.AsStringMappingType().target;
		if (inner.flags & TypeFlagsStringMapping != 0) {
			final r = c.applyTargetStringMappingToSource(source, inner);
			source = r.a;
			inner = r.b;
		}
		return new Pair(c.getStringMappingType(target.symbol, source), inner);
	}

	static function getRelater(c:Checker):Relater {
		var r = c.freeRelater;
		if (r == null) {
			r = new Relater();
			r.c = c;
		}
		c.freeRelater = r.next;
		return r;
	}

	static function putRelater(c:Checker, r:Relater):Void {
		r.maybeKeysSet.Clear();
		// PORT: `*r = Relater{...}` — reset every field to its zero value, keeping the reusable buffers
		r.c = c;
		r.relation = null;
		r.errorNode = null;
		r.errorChain = null;
		r.relatedInfo = null;
		if (r.maybeKeys != null) {
			r.maybeKeys.resize(0);
		}
		if (r.sourceStack != null) {
			r.sourceStack.resize(0);
		}
		if (r.targetStack != null) {
			r.targetStack.resize(0);
		}
		r.maybeCount = 0;
		r.sourceDepth = 0;
		r.targetDepth = 0;
		r.expandingFlags = ExpandingFlagsNone;
		r.overflow = false;
		r.relationCount = 0;
		r.next = c.freeRelater;
		c.freeRelater = r;
	}

	function isRelatedToSimple(source:Type, target:Type):Ternary {
		return isRelatedToEx(source, target, RecursionFlagsBoth, false /*reportErrors*/, null /*headMessage*/, IntersectionStateNone);
	}

	function isRelatedToWorker(source:Type, target:Type, reportErrors:Bool):Ternary {
		return isRelatedToEx(source, target, RecursionFlagsBoth, reportErrors, null, IntersectionStateNone);
	}

	function isRelatedTo(source:Type, target:Type, recursionFlags:RecursionFlags, reportErrors:Bool):Ternary {
		return isRelatedToEx(source, target, recursionFlags, reportErrors, null, IntersectionStateNone);
	}

	function isRelatedToEx(originalSource:Type, originalTarget:Type, recursionFlags:RecursionFlags, reportErrors:Bool, headMessage:Message, intersectionState:IntersectionState):Ternary {
		if (originalSource == originalTarget) {
			return TernaryTrue;
		}
		// Before normalization: if `source` is type an object type, and `target` is primitive,
		// skip all the checks we don't need and just return `isSimpleTypeRelatedTo` result
		if (originalSource.flags & TypeFlagsObject != 0 && originalTarget.flags & TypeFlagsPrimitive != 0) {
			if (relation == c.comparableRelation && originalTarget.flags & TypeFlagsNever == 0 && c.isSimpleTypeRelatedTo(originalTarget, originalSource, relation, null)
				|| c.isSimpleTypeRelatedTo(originalSource, originalTarget, relation, reportErrors ? (m:Message, ...a:Any) -> reportError(m, ...a) : null /* PORT: explicit spreading closure for the rest-args method value */)) {
				return TernaryTrue;
			}
			if (reportErrors) {
				reportErrorResults(originalSource, originalTarget, originalSource, originalTarget, headMessage);
			}
			return TernaryFalse;
		}
		// Normalize the source and target types: Turn fresh literal types into regular literal types,
		// turn deferred type references into regular type references, simplify indexed access and
		// conditional types, and resolve substitution types to either the substitution (on the source
		// side) or the type variable (on the target side).
		final source = c.getNormalizedType(originalSource, false /*writing*/);
		var target = c.getNormalizedType(originalTarget, true /*writing*/);
		if (source == target) {
			return TernaryTrue;
		}
		if (relation == c.identityRelation) {
			if (source.flags != target.flags) {
				return TernaryFalse;
			}
			if (source.flags & TypeFlagsSingleton != 0) {
				return TernaryTrue;
			}
			traceUnionsOrIntersectionsTooLarge(source, target);
			return recursiveTypeRelatedTo(source, target, false /*reportErrors*/, IntersectionStateNone, recursionFlags);
		}
		// We fastpath comparing a type parameter to exactly its constraint, as this is _super_ common,
		// and otherwise, for type parameters in large unions, causes us to need to compare the union to itself,
		// as we break down the _target_ union first, _then_ get the source constraint - so for every
		// member of the target, we attempt to find a match in the source. This avoids that in cases where
		// the target is exactly the constraint.
		if (source.flags & TypeFlagsTypeParameter != 0 && c.getConstraintOfType(source) == target) {
			return TernaryTrue;
		}
		// See if we're relating a definitely non-nullable type to a union that includes null and/or undefined
		// plus a single non-nullable type. If so, remove null and/or undefined from the target type.
		if (source.flags & TypeFlagsDefinitelyNonNullable != 0 && target.flags & TypeFlagsUnion != 0) {
			final types = target.Types();
			var candidate:Type = null;
			if (types.length == 2 && types[0].flags & TypeFlagsNullable != 0) {
				candidate = types[1];
			} else if (types.length == 3 && types[0].flags & TypeFlagsNullable != 0 && types[1].flags & TypeFlagsNullable != 0) {
				candidate = types[2];
			}
			if (candidate != null && candidate.flags & TypeFlagsNullable == 0) {
				target = c.getNormalizedType(candidate /*writing*/, true);
				if (source == target) {
					return TernaryTrue;
				}
			}
		}
		if (relation == c.comparableRelation && target.flags & TypeFlagsNever == 0 && c.isSimpleTypeRelatedTo(target, source, relation, null)
			|| c.isSimpleTypeRelatedTo(source, target, relation, reportErrors ? (m:Message, ...a:Any) -> reportError(m, ...a) : null /* PORT: explicit spreading closure for the rest-args method value */)) {
			return TernaryTrue;
		}
		if (source.flags & TypeFlagsStructuredOrInstantiable != 0 || target.flags & TypeFlagsStructuredOrInstantiable != 0) {
			final isPerformingExcessPropertyChecks = intersectionState & IntersectionStateTarget == 0 && Checker.isObjectLiteralType(source)
				&& source.objectFlags & ObjectFlagsFreshLiteral != 0;
			if (isPerformingExcessPropertyChecks) {
				if (hasExcessProperties(source, target, reportErrors)) {
					if (reportErrors) {
						reportRelationError(headMessage, source, originalTarget.alias != null ? originalTarget : target);
					}
					return TernaryFalse;
				}
			}
			final isPerformingCommonPropertyChecks = (relation != c.comparableRelation || Checker.isUnitType(source))
				&& intersectionState & IntersectionStateTarget == 0
				&& source.flags & (TypeFlagsPrimitive | TypeFlagsObject | TypeFlagsIntersection) != 0 && source != c.globalObjectType
				&& target.flags & (TypeFlagsObject | TypeFlagsIntersection) != 0 && c.isWeakType(target)
				&& (Core.len(c.getPropertiesOfType(source)) > 0 || c.typeHasCallOrConstructSignatures(source));
			final isComparingJsxAttributes = source.objectFlags & ObjectFlagsJsxAttributes != 0;
			if (isPerformingCommonPropertyChecks && !c.hasCommonProperties(source, target, isComparingJsxAttributes)) {
				if (reportErrors) {
					final sourceString = c.TypeToString(originalSource.alias != null ? originalSource : source);
					final targetString = c.TypeToString(originalTarget.alias != null ? originalTarget : target);
					final calls = c.getSignaturesOfType(source, SignatureKindCall);
					final constructs = c.getSignaturesOfType(source, SignatureKindConstruct);
					if (Core.len(calls) > 0 && isRelatedTo(c.getReturnTypeOfSignature(calls[0]), target, RecursionFlagsSource, false /*reportErrors*/) != TernaryFalse
						|| Core.len(constructs) > 0
						&& isRelatedTo(c.getReturnTypeOfSignature(constructs[0]), target, RecursionFlagsSource, false /*reportErrors*/) != TernaryFalse) {
						reportError(Diagnostics.Value_of_type_0_has_no_properties_in_common_with_type_1_Did_you_mean_to_call_it, sourceString, targetString);
					} else {
						reportError(Diagnostics.Type_0_has_no_properties_in_common_with_type_1, sourceString, targetString);
					}
				}
				return TernaryFalse;
			}
			traceUnionsOrIntersectionsTooLarge(source, target);
			final skipCaching = source.flags & TypeFlagsUnion != 0 && source.Types().length < 4 && target.flags & TypeFlagsUnion == 0
				|| target.flags & TypeFlagsUnion != 0 && target.Types().length < 4 && source.flags & TypeFlagsStructuredOrInstantiable == 0;
			var result:Ternary;
			if (skipCaching) {
				result = unionOrIntersectionRelatedTo(source, target, reportErrors, intersectionState);
			} else {
				result = recursiveTypeRelatedTo(source, target, reportErrors, intersectionState, recursionFlags);
			}
			if (result != TernaryFalse) {
				return result;
			}
		}
		if (reportErrors) {
			reportErrorResults(originalSource, originalTarget, source, target, headMessage);
		}
		return TernaryFalse;
	}

	function hasExcessProperties(source:Type, target:Type, reportErrors:Bool):Bool {
		if (!Checker.isExcessPropertyCheckTarget(target) || !c.noImplicitAny && target.objectFlags & ObjectFlagsJSLiteral != 0) {
			// Disable excess property checks on JS literals to simulate having an implicit "index signature" - but only outside of noImplicitAny
			return false;
		}
		final isComparingJsxAttributes = source.objectFlags & ObjectFlagsJsxAttributes != 0;
		if ((relation == c.assignableRelation || relation == c.comparableRelation)
			&& (c.isTypeSubsetOf(c.globalObjectType, target) || (!isComparingJsxAttributes && c.isEmptyObjectType(target)))) {
			return false;
		}
		var reducedTarget = target;
		var checkTypes:Array<Type> = null;
		if (target.flags & TypeFlagsUnion != 0) {
			reducedTarget = c.findMatchingDiscriminantType(source, target, isRelatedToSimple);
			if (reducedTarget == null) {
				reducedTarget = c.filterPrimitivesIfContainsNonPrimitive(target);
			}
			checkTypes = reducedTarget.Distributed();
		}
		final props = c.getPropertiesOfType(source);
		if (props != null) {
			for (prop in props) {
				if (Checker.shouldCheckAsExcessProperty(prop, source.symbol) && !Checker.isIgnoredJsxProperty(source, prop)) {
					if (!c.isKnownProperty(reducedTarget, prop.Name, isComparingJsxAttributes)) {
						if (reportErrors) {
							// Report error in terms of object types in the target as those are the only ones
							// we check in isKnownProperty.
							final errorTarget = c.filterType(reducedTarget, Checker.isExcessPropertyCheckTarget);
							// We know *exactly* where things went wrong when comparing the types.
							// Use this property as the error node as this will be more helpful in
							// reasoning about what went wrong.
							if (errorNode == null) {
								throw "No errorNode in hasExcessProperties";
							}
							if (Ast.IsJsxAttributes(errorNode) || Ast.IsJsxOpeningLikeElement(errorNode) || Ast.IsJsxOpeningLikeElement(errorNode.Parent)) {
								// JsxAttributes has an object-literal flag and undergo same type-assignablity check as normal object-literal.
								// However, using an object-literal error message will be very confusing to the users so we give different a message.
								if (prop.ValueDeclaration != null && Ast.IsJsxAttribute(prop.ValueDeclaration)
									&& Ast.GetSourceFileOfNode(errorNode) == Ast.GetSourceFileOfNode(prop.ValueDeclaration.Name())) {
									// Note that extraneous children (as in `<NoChild>extra</NoChild>`) don't pass this check,
									// since `children` is a Kind.PropertySignature instead of a Kind.JsxAttribute.
									errorNode = prop.ValueDeclaration.Name();
								}
								final propName = c.symbolToString(prop);
								final suggestionSymbol = c.getSuggestedSymbolForNonexistentJSXAttribute(propName, errorTarget);
								if (suggestionSymbol != null) {
									reportError(Diagnostics.Property_0_does_not_exist_on_type_1_Did_you_mean_2, propName, c.TypeToString(errorTarget),
										c.symbolToString(suggestionSymbol));
								} else {
									reportError(Diagnostics.Property_0_does_not_exist_on_type_1, propName, c.TypeToString(errorTarget));
								}
							} else {
								// use the property's value declaration if the property is assigned inside the literal itself
								var objectLiteralDeclaration:Node = null;
								if (source.symbol != null) {
									objectLiteralDeclaration = Core.FirstOrNil(source.symbol.Declarations);
								}
								var suggestion = "";
								if (prop.ValueDeclaration != null && Ast.IsObjectLiteralElement(prop.ValueDeclaration)
									&& Ast.FindAncestor(prop.ValueDeclaration, d -> d == objectLiteralDeclaration) != null
									&& Ast.GetSourceFileOfNode(objectLiteralDeclaration) == Ast.GetSourceFileOfNode(errorNode)) {
									final name = prop.ValueDeclaration.Name();
									errorNode = name;
									if (Ast.IsIdentifier(name)) {
										suggestion = c.getSuggestionForNonexistentProperty(name.Text(), errorTarget);
									}
								}
								if (suggestion != "") {
									reportError(Diagnostics.Object_literal_may_only_specify_known_properties_but_0_does_not_exist_in_type_1_Did_you_mean_to_write_2,
										c.symbolToString(prop), c.TypeToString(errorTarget), suggestion);
								} else {
									reportError(Diagnostics.Object_literal_may_only_specify_known_properties_and_0_does_not_exist_in_type_1, c.symbolToString(prop),
										c.TypeToString(errorTarget));
								}
							}
						}
						return true;
					}
					if (checkTypes != null
						&& isRelatedTo(c.getTypeOfSymbol(prop), c.getTypeOfPropertyInTypes(checkTypes, prop.Name), RecursionFlagsBoth, reportErrors) == TernaryFalse) {
						if (reportErrors) {
							reportError(Diagnostics.Types_of_property_0_are_incompatible, c.symbolToString(prop));
						}
						return true;
					}
				}
			}
		}
		return false;
	}

	static function getTypeOfPropertyInTypes(c:Checker, types:Array<Type>, name:std.String):Type {
		var propTypes:Array<Type> = null;
		for (t in types) {
			if (propTypes == null) {
				propTypes = [];
			}
			propTypes.push(c.getTypeOfPropertyInType(t, name));
		}
		return c.getUnionType(propTypes);
	}

	static function getTypeOfPropertyInType(c:Checker, t:Type, name:std.String):Type {
		t = c.getApparentType(t);
		var prop:Symbol;
		if (t.flags & TypeFlagsUnionOrIntersection != 0) {
			prop = c.getPropertyOfUnionOrIntersectionType(t, name, false);
		} else {
			prop = c.getPropertyOfObjectType(t, name);
		}
		if (prop != null) {
			return c.getTypeOfSymbol(prop);
		}
		final indexInfo = c.getApplicableIndexInfoForName(t, name);
		if (indexInfo != null) {
			return indexInfo.valueType;
		}
		return c.undefinedType;
	}

	static function isTypeSubsetOf(c:Checker, source:Type, target:Type):Bool {
		return source == target || source.flags & TypeFlagsNever != 0 || target.flags & TypeFlagsUnion != 0 && c.isTypeSubsetOfUnion(source, target);
	}

	static function isTypeSubsetOfUnion(c:Checker, source:Type, target:Type):Bool {
		if (source.flags & TypeFlagsUnion != 0) {
			for (t in source.Types()) {
				if (!Checker.containsType(target.Types(), t)) {
					return false;
				}
			}
			return true;
		}
		if (source.flags & TypeFlagsEnumLike != 0 && c.getBaseTypeOfEnumLikeType(source) == target) {
			return true;
		}
		return Checker.containsType(target.Types(), source);
	}

	function unionOrIntersectionRelatedTo(source:Type, target:Type, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		// Note that these checks are specifically ordered to produce correct results. In particular,
		// we need to deconstruct unions before intersections (because unions are always at the top),
		// and we need to handle "each" relations before "some" relations for the same kind of type.
		if (source.flags & TypeFlagsUnion != 0) {
			if (target.flags & TypeFlagsUnion != 0) {
				// Intersections of union types are normalized into unions of intersection types, and such normalized
				// unions can get very large and expensive to relate. The following fast path checks if the source union
				// originated in an intersection. If so, and if that intersection contains the target type, then we know
				// the result to be true (for any two types A and B, A & B is related to both A and B).
				final sourceOrigin = source.AsUnionType().origin;
				if (sourceOrigin != null && sourceOrigin.flags & TypeFlagsIntersection != 0 && target.alias != null && Slices.Contains(sourceOrigin.Types(), target)) {
					return TernaryTrue;
				}
				// Similarly, in unions of unions the we preserve the original list of unions. This original list is often
				// much shorter than the normalized result, so we scan it in the following fast path.
				final targetOrigin = target.AsUnionType().origin;
				if (targetOrigin != null && targetOrigin.flags & TypeFlagsUnion != 0 && source.alias != null && Slices.Contains(targetOrigin.Types(), source)) {
					return TernaryTrue;
				}
			}
			if (relation == c.comparableRelation) {
				return someTypeRelatedToType(source, target, reportErrors && source.flags & TypeFlagsPrimitive == 0, intersectionState);
			}
			return eachTypeRelatedToType(source, target, reportErrors && source.flags & TypeFlagsPrimitive == 0, intersectionState);
		}
		if (target.flags & TypeFlagsUnion != 0) {
			return typeRelatedToSomeType(c.getRegularTypeOfObjectLiteral(source), target,
				reportErrors && source.flags & TypeFlagsPrimitive == 0 && target.flags & TypeFlagsPrimitive == 0, intersectionState);
		}
		if (target.flags & TypeFlagsIntersection != 0) {
			return typeRelatedToEachType(source, target, reportErrors, IntersectionStateTarget);
		}
		// Source is an intersection. For the comparable relation, if the target is a primitive type we hoist the
		// constraints of all non-primitive types in the source into a new intersection. We do this because the
		// intersection may further constrain the constraints of the non-primitive types. For example, given a type
		// parameter 'T extends 1 | 2', the intersection 'T & 1' should be reduced to '1' such that it doesn't
		// appear to be comparable to '2'.
		if (relation == c.comparableRelation && target.flags & TypeFlagsPrimitive != 0) {
			final constraints = Core.SameMap(source.Types(), t -> {
				if (t.flags & TypeFlagsInstantiable != 0) {
					final constraint = c.getBaseConstraintOfType(t);
					if (constraint != null) {
						return constraint;
					}
					return c.unknownType;
				}
				return t;
			});
			if (!Core.Same(constraints, source.Types())) {
				source = c.getIntersectionType(constraints);
				if (source.flags & TypeFlagsNever != 0) {
					return TernaryFalse;
				}
				if (source.flags & TypeFlagsIntersection == 0) {
					final result = isRelatedTo(source, target, RecursionFlagsSource, false /*reportErrors*/);
					if (result != TernaryFalse) {
						return result;
					}
					return isRelatedTo(target, source, RecursionFlagsSource, false /*reportErrors*/);
				}
			}
		}
		// Check to see if any constituents of the intersection are immediately related to the target.
		// Don't report errors though. Elaborating on whether a source constituent is related to the target is
		// not actually useful and leads to some confusing error messages. Instead, we rely on the caller
		// checking whether the full intersection viewed as an object is related to the target.
		return someTypeRelatedToType(source, target, false /*reportErrors*/, IntersectionStateSource);
	}

	function someTypeRelatedToType(source:Type, target:Type, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		final sourceTypes = source.Types();
		if (source.flags & TypeFlagsUnion != 0 && Checker.containsType(sourceTypes, target)) {
			return TernaryTrue;
		}
		for (i in 0...sourceTypes.length) {
			final related = isRelatedToEx(sourceTypes[i], target, RecursionFlagsSource, reportErrors && i == sourceTypes.length - 1, null /*headMessage*/, intersectionState);
			if (related != TernaryFalse) {
				return related;
			}
		}
		return TernaryFalse;
	}

	function eachTypeRelatedToType(source:Type, target:Type, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		var result:Ternary = TernaryTrue;
		final sourceTypes = source.Types();
		// We strip `undefined` from the target if the `source` trivially doesn't contain it for our correspondence-checking fastpath
		// since `undefined` is frequently added by optionality and would otherwise spoil a potentially useful correspondence
		final strippedTarget = getUndefinedStrippedTargetIfNeeded(source, target);
		var strippedTypes:Array<Type> = null;
		if (strippedTarget.flags & TypeFlagsUnion != 0) {
			strippedTypes = strippedTarget.Types();
		}
		for (i in 0...sourceTypes.length) {
			final sourceType = sourceTypes[i];
			if (strippedTarget.flags & TypeFlagsUnion != 0 && sourceTypes.length >= strippedTypes.length && sourceTypes.length % strippedTypes.length == 0) {
				// many unions are mappings of one another; in such cases, simply comparing members at the same index can shortcut the comparison
				// such unions will have identical lengths, and their corresponding elements will match up. Another common scenario is where a large
				// union has a union of objects intersected with it. In such cases, if the input was, eg `("a" | "b" | "c") & (string | boolean | {} | {whatever})`,
				// the result will have the structure `"a" | "b" | "c" | "a" & {} | "b" & {} | "c" & {} | "a" & {whatever} | "b" & {whatever} | "c" & {whatever}`
				// - the resulting union has a length which is a multiple of the original union, and the elements correspond modulo the length of the original union
				final related = isRelatedToEx(sourceType, strippedTypes[i % strippedTypes.length], RecursionFlagsBoth, false /*reportErrors*/, null /*headMessage*/,
					intersectionState);
				if (related != TernaryFalse) {
					result &= related;
					continue;
				}
			}
			final related = isRelatedToEx(sourceType, target, RecursionFlagsSource, reportErrors, null /*headMessage*/, intersectionState);
			if (related == TernaryFalse) {
				return TernaryFalse;
			}
			result &= related;
		}
		return result;
	}

	function getUndefinedStrippedTargetIfNeeded(source:Type, target:Type):Type {
		if (source.flags & TypeFlagsUnion != 0 && target.flags & TypeFlagsUnion != 0 && source.Types()[0].flags & TypeFlagsUndefined == 0
			&& target.Types()[0].flags & TypeFlagsUndefined != 0) {
			return c.extractTypesOfKind(target, ~TypeFlagsUndefined);
		}
		return target;
	}

	function typeRelatedToSomeType(source:Type, target:Type, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		final targetTypes = target.Types();
		if (target.flags & TypeFlagsUnion != 0) {
			if (Checker.containsType(targetTypes, source)) {
				return TernaryTrue;
			}
			if (relation != c.comparableRelation && target.objectFlags & ObjectFlagsPrimitiveUnion != 0 && source.flags & TypeFlagsEnumLiteral == 0
				&& (source.flags & (TypeFlagsStringLiteral | TypeFlagsBooleanLiteral | TypeFlagsBigIntLiteral) != 0
					|| (relation == c.subtypeRelation || relation == c.strictSubtypeRelation) && source.flags & TypeFlagsNumberLiteral != 0)) {
				// When relating a literal type to a union of primitive types, we know the relation is false unless
				// the union contains the base primitive type or the literal type in one of its fresh/regular forms.
				// We exclude numeric literals for non-subtype relations because numeric literals are assignable to
				// numeric enum literals with the same value. Similarly, we exclude enum literal types because
				// identically named enum types are related (see isEnumTypeRelatedTo). We exclude the comparable
				// relation in entirety because it needs to be checked in both directions.
				var alternateForm:Type;
				if (source == source.AsLiteralType().regularType) {
					alternateForm = source.AsLiteralType().freshType;
				} else {
					alternateForm = source.AsLiteralType().regularType;
				}
				var primitive:Type = null;
				if (source.flags & TypeFlagsStringLiteral != 0) {
					primitive = c.stringType;
				} else if (source.flags & TypeFlagsNumberLiteral != 0) {
					primitive = c.numberType;
				} else if (source.flags & TypeFlagsBigIntLiteral != 0) {
					primitive = c.bigintType;
				}
				if (primitive != null && Checker.containsType(targetTypes, primitive) || alternateForm != null && Checker.containsType(targetTypes, alternateForm)) {
					return TernaryTrue;
				}
				return TernaryFalse;
			}
			final match = c.getMatchingUnionConstituentForType(target, source);
			if (match != null) {
				final related = isRelatedToEx(source, match, RecursionFlagsTarget, false /*reportErrors*/, null /*headMessage*/, intersectionState);
				if (related != TernaryFalse) {
					return related;
				}
			}
		}
		for (t in targetTypes) {
			final related = isRelatedToEx(source, t, RecursionFlagsTarget, false /*reportErrors*/, null /*headMessage*/, intersectionState);
			if (related != TernaryFalse) {
				return related;
			}
		}
		if (reportErrors) {
			// Elaborate only if we can find a best matching type in the target union
			final bestMatchingType = c.getBestMatchingType(source, target, isRelatedToSimple);
			if (bestMatchingType != null) {
				isRelatedToEx(source, bestMatchingType, RecursionFlagsTarget, true /*reportErrors*/, null /*headMessage*/, intersectionState);
			}
		}
		return TernaryFalse;
	}

	function typeRelatedToEachType(source:Type, target:Type, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		var result:Ternary = TernaryTrue;
		final targetTypes = target.Types();
		for (targetType in targetTypes) {
			final related = isRelatedToEx(source, targetType, RecursionFlagsTarget, reportErrors /*headMessage*/, null, intersectionState);
			if (related == TernaryFalse) {
				return TernaryFalse;
			}
			result &= related;
		}
		return result;
	}

	function eachTypeRelatedToSomeType(source:Type, target:Type):Ternary {
		var result:Ternary = TernaryTrue;
		final sourceTypes = source.Types();
		for (sourceType in sourceTypes) {
			final related = typeRelatedToSomeType(sourceType, target, false /*reportErrors*/, IntersectionStateNone);
			if (related == TernaryFalse) {
				return TernaryFalse;
			}
			result &= related;
		}
		return result;
	}

	// Determine if possibly recursive types are related. First, check if the result is already available in the global cache.
	// Second, check if we have already started a comparison of the given two types in which case we assume the result to be true.
	// Third, check if both types are part of deeply nested chains of generic type instantiations and if so assume the types are
	// equal and infinitely expanding. Fourth, if we have reached a depth of 100 nested comparisons, assume we have runaway recursion
	// and issue an error. Otherwise, actually compare the structure of the two types.
	function recursiveTypeRelatedTo(source:Type, target:Type, reportErrors:Bool, intersectionState:IntersectionState, recursionFlags:RecursionFlags):Ternary {
		if (overflow) {
			// Note that stack depth overflows can cause _any_ relation involving structured types to become false, so it is
			// important to have well-defined behavior even in cases that shouldn't normally occur.
			return TernaryFalse;
		}
		final key = Checker.getRelationKey(source, target, intersectionState, relation == c.identityRelation, false /*ignoreConstraints*/);
		final constrained = Checker.getRelationKeyConstrained;
		final id = Relation.keyString(key); // PORT: struct map key, encoded once
		final entry = relation.getByKey(id);
		if (entry != RelationComparisonResultNone) {
			if (reportErrors && entry & RelationComparisonResultFailed != 0 && entry & RelationComparisonResultOverflow == 0) {
				// We are elaborating errors and the cached result is a failure not due to a comparison overflow,
				// so we will do the comparison again to generate an error message.
			} else {
				c.reliabilityFlags |= entry & (RelationComparisonResultReportsUnmeasurable | RelationComparisonResultReportsUnreliable);
				if (reportErrors && entry & RelationComparisonResultOverflow != 0) {
					final message = entry & RelationComparisonResultComplexityOverflow != 0 ? Diagnostics.Excessive_complexity_comparing_types_0_and_1 : Diagnostics.Excessive_stack_depth_comparing_types_0_and_1;
					reportError(message, c.TypeToString(source), c.TypeToString(target));
				}
				if (entry & RelationComparisonResultSucceeded != 0) {
					return TernaryTrue;
				}
				return TernaryFalse;
			}
		}
		if (relationCount <= 0) {
			overflow = true;
			return TernaryFalse;
		}
		// If source and target are already being compared, consider them related with assumptions
		if (maybeKeysSet.Has(id)) {
			return TernaryMaybe;
		}
		// A constrained key indicates that we have type references that reference constrained
		// type parameters. For such keys we also check against the key we would have gotten if all type parameters
		// were unconstrained.
		if (constrained) {
			final broadestEquivalentId = Checker.getRelationKey(source, target, intersectionState, relation == c.identityRelation, true /*ignoreConstraints*/);
			if (maybeKeysSet.Has(Relation.keyString(broadestEquivalentId))) {
				return TernaryMaybe;
			}
		}
		if (Core.len(sourceStack) == 100 || Core.len(targetStack) == 100) {
			overflow = true;
			return TernaryFalse;
		}
		if (maybeKeys == null) {
			maybeKeys = [];
		}
		final maybeStart = maybeKeys.length;
		maybeKeys.push(id);
		maybeKeysSet.Add(id);
		final saveExpandingFlags = expandingFlags;
		if (recursionFlags & RecursionFlagsSource != 0) {
			if (sourceStack == null) {
				sourceStack = [];
			}
			sourceStack.push(source);
			if (expandingFlags & ExpandingFlagsSource == 0 && c.isDeeplyNestedType(source, sourceStack, 3)) {
				expandingFlags |= ExpandingFlagsSource;
			}
		}
		if (recursionFlags & RecursionFlagsTarget != 0) {
			if (targetStack == null) {
				targetStack = [];
			}
			targetStack.push(target);
			if (expandingFlags & ExpandingFlagsTarget == 0 && c.isDeeplyNestedType(target, targetStack, 3)) {
				expandingFlags |= ExpandingFlagsTarget;
			}
		}
		final saveReliabilityFlags = c.reliabilityFlags;
		c.reliabilityFlags = 0;
		var result:Ternary;
		var popFn:() -> Void = null; // PORT: defer — runs before the single return below
		if (expandingFlags == ExpandingFlagsBoth) {
			final tr = c.tracer;
			if (tr != null) {
				final args = new StringMap<Any>();
				args.set("sourceId", source.id);
				args.set("targetId", target.id);
				args.set("depth", Core.len(sourceStack));
				args.set("targetDepth", Core.len(targetStack));
				tr.Instant(PhaseCheckTypes, "recursiveTypeRelatedTo_DepthLimit", args);
			}
			result = TernaryMaybe;
		} else {
			final tr = c.tracer;
			if (tr != null) {
				final args = new StringMap<Any>();
				args.set("sourceId", source.id);
				args.set("targetId", target.id);
				popFn = tr.Push(PhaseCheckTypes, "structuredTypeRelatedTo", args, false);
			}
			result = structuredTypeRelatedTo(source, target, reportErrors, intersectionState);
		}
		final propagatingVarianceFlags = c.reliabilityFlags;
		c.reliabilityFlags |= saveReliabilityFlags;
		if (recursionFlags & RecursionFlagsSource != 0) {
			sourceStack.pop();
		}
		if (recursionFlags & RecursionFlagsTarget != 0) {
			targetStack.pop();
		}
		expandingFlags = saveExpandingFlags;
		if (result != TernaryFalse) {
			if (result == TernaryTrue || (Core.len(sourceStack) == 0 && Core.len(targetStack) == 0)) {
				if (result == TernaryTrue || result == TernaryMaybe) {
					// If result is definitely true, record all maybe keys as having succeeded. Also, record Ternary.Maybe
					// results as having succeeded once we reach depth 0, but never record Ternary.Unknown results.
					resetMaybeStack(maybeStart, propagatingVarianceFlags, true);
				} else {
					resetMaybeStack(maybeStart, propagatingVarianceFlags, false);
				}
			}
			// Note: it's intentional that we don't reset in the else case;
			// we leave them on the stack such that when we hit depth zero
			// above, we can report all of them as successful.
		} else {
			// A false result goes straight into global cache (when something is false under
			// assumptions it will also be false without assumptions)
			relation.setByKey(id, RelationComparisonResultFailed | propagatingVarianceFlags);
			relationCount--;
			resetMaybeStack(maybeStart, propagatingVarianceFlags, false);
		}
		if (popFn != null) {
			popFn();
		}
		return result;
	}

	function resetMaybeStack(maybeStart:Int, propagatingVarianceFlags:RelationComparisonResult, markAllAsSucceeded:Bool):Void {
		for (i in maybeStart...maybeKeys.length) {
			maybeKeysSet.Delete(maybeKeys[i]);
			if (markAllAsSucceeded) {
				relation.setByKey(maybeKeys[i], RelationComparisonResultSucceeded | propagatingVarianceFlags);
				relationCount--;
			}
		}
		maybeKeys.resize(maybeStart);
	}

	function getErrorState():ErrorState {
		final e = new ErrorState();
		e.errorChain = errorChain;
		e.relatedInfo = relatedInfo;
		return e;
	}

	function restoreErrorState(e:ErrorState):Void {
		errorChain = e.errorChain;
		relatedInfo = e.relatedInfo;
	}

	function structuredTypeRelatedTo(source:Type, target:Type, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		final saveErrorState = getErrorState();
		var result = structuredTypeRelatedToWorker(source, target, reportErrors, intersectionState);
		if (relation != c.identityRelation) {
			// The combined constraint of an intersection type is the intersection of the constraints of
			// the constituents. When an intersection type contains instantiable types with union type
			// constraints, there are situations where we need to examine the combined constraint. One is
			// when the target is a union type. Another is when the intersection contains types belonging
			// to one of the disjoint domains. For example, given type variables T and U, each with the
			// constraint 'string | number', the combined constraint of 'T & U' is 'string | number' and
			// we need to check this constraint against a union on the target side. Also, given a type
			// variable V constrained to 'string | number', 'V & number' has a combined constraint of
			// 'string & number | number & number' which reduces to just 'number'.
			// This also handles type parameters, as a type parameter with a union constraint compared against a union
			// needs to have its constraint hoisted into an intersection with said type parameter, this way
			// the type param can be compared with itself in the target (with the influence of its constraint to match other parts)
			// For example, if `T extends 1 | 2` and `U extends 2 | 3` and we compare `T & U` to `T & U & (1 | 2 | 3)`
			if (result == TernaryFalse
				&& (source.flags & TypeFlagsIntersection != 0 || source.flags & TypeFlagsTypeParameter != 0 && target.flags & TypeFlagsUnion != 0)) {
				var sourceTypes:Array<Type>;
				if (source.flags & TypeFlagsIntersection != 0) {
					sourceTypes = source.Types();
				} else {
					sourceTypes = [source];
				}
				final constraint = c.getEffectiveConstraintOfIntersection(sourceTypes, target.flags & TypeFlagsUnion != 0);
				if (constraint != null && Checker.everyType(constraint, c -> c != source)) {
					// TODO: Stack errors so we get a pyramid for the "normal" comparison above, _and_ a second for this
					result = isRelatedToEx(constraint, target, RecursionFlagsSource, false /*reportErrors*/, null /*headMessage*/, intersectionState);
				}
			}
			// When the target is an intersection we need an extra property check in order to detect nested excess
			// properties and nested weak types. The following are motivating examples that all should be errors, but
			// aren't without this extra property check:
			//
			//   let obj: { a: { x: string } } & { c: number } = { a: { x: 'hello', y: 2 }, c: 5 };  // Nested excess property
			//
			//   declare let wrong: { a: { y: string } };
			//   let weak: { a?: { x?: number } } & { c?: string } = wrong;  // Nested weak object type
			//
			if (result != TernaryFalse && intersectionState & IntersectionStateTarget == 0 && target.flags & TypeFlagsIntersection != 0 && !c.isGenericObjectType(target)
				&& source.flags & (TypeFlagsObject | TypeFlagsIntersection) != 0) {
				// PORT: zero-value collections.Set[string]{} → null (Set methods are nil-safe)
				result &= propertiesRelatedTo(source, target, reportErrors, null /*excludedProperties*/, false /*optionalsOnly*/, IntersectionStateNone);
				if (result != 0 && Checker.isObjectLiteralType(source) && source.objectFlags & ObjectFlagsFreshLiteral != 0) {
					result &= indexSignaturesRelatedTo(source, target, false /*sourceIsPrimitive*/, reportErrors, IntersectionStateNone);
				}
				// When the source is an intersection we need an extra check of any optional properties in the target to
				// detect possible mismatched property types. For example:
				//
				//   function foo<T extends object>(x: { a?: string }, y: T & { a: boolean }) {
				//     x = y;  // Mismatched property in source intersection
				//   }
				//
			} else if (result != 0 && c.isNonGenericObjectType(target) && !c.isArrayOrTupleType(target) && isSourceIntersectionNeedingExtraCheck(source, target)) {
				result &= propertiesRelatedTo(source, target, reportErrors, null /*excludedProperties*/, true /*optionalsOnly*/, intersectionState);
			}
		}
		if (result != TernaryFalse) {
			restoreErrorState(saveErrorState);
		}
		return result;
	}

	function isSourceIntersectionNeedingExtraCheck(source:Type, target:Type):Bool {
		return source.flags & TypeFlagsIntersection != 0 && c.getApparentType(source).flags & TypeFlagsStructuredType != 0
			&& !Core.Some(source.Types(), t -> t == target || t.objectFlags & ObjectFlagsNonInferrableType != 0);
	}

	function structuredTypeRelatedToWorker(source:Type, target:Type, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		var result:Ternary = TernaryFalse;
		var varianceCheckFailed = false;
		var originalErrorChain:ErrorChain = null;
		final saveErrorState = getErrorState();
		// PORT: Go returns (Ternary, bool); the bool is passed back through relateVariancesOk
		var relateVariancesOk = false;
		final relateVariances = (sourceTypeArguments:Array<Type>, targetTypeArguments:Array<Type>, variances:Array<VarianceFlags>,
				intersectionState:IntersectionState) -> {
			result = typeArgumentsRelatedTo(sourceTypeArguments, targetTypeArguments, variances, reportErrors, intersectionState);
			if (result != TernaryFalse) {
				relateVariancesOk = true;
				return result;
			}
			if (Core.Some(variances, v -> v & VarianceFlagsAllowsStructuralFallback != 0)) {
				// If some type parameter was `Unmeasurable` or `Unreliable`, and we couldn't pass by assuming it was identical, then we
				// have to allow a structural fallback check
				// We elide the variance-based error elaborations, since those might not be too helpful, since we'll potentially
				// be assuming identity of the type parameter.
				originalErrorChain = null;
				restoreErrorState(saveErrorState);
				relateVariancesOk = false;
				return TernaryFalse;
			}
			final allowStructuralFallback = c.hasCovariantVoidArgument(targetTypeArguments, variances);
			varianceCheckFailed = !allowStructuralFallback;
			// The type arguments did not relate appropriately, but it may be because we have no variance
			// information (in which case typeArgumentsRelatedTo defaulted to covariance for all type
			// arguments). It might also be the case that the target type has a 'void' type argument for
			// a covariant type parameter that is only used in return positions within the generic type
			// (in which case any type argument is permitted on the source side). In those cases we proceed
			// with a structural comparison. Otherwise, we know for certain the instantiations aren't
			// related and we can return here.
			if (Core.len(variances) != 0 && !allowStructuralFallback) {
				// In some cases generic types that are covariant in regular type checking mode become
				// invariant in --strictFunctionTypes mode because one or more type parameters are used in
				// both co- and contravariant positions. In order to make it easier to diagnose *why* such
				// types are invariant, if any of the type parameters are invariant we reset the reported
				// errors and instead force a structural comparison (which will include elaborations that
				// reveal the reason).
				// We can switch on `reportErrors` here, since varianceCheckFailed guarantees we return `False`,
				// we can return `False` early here to skip calculating the structural error message we don't need.
				if (varianceCheckFailed && !(reportErrors && Core.Some(variances, v -> (v & VarianceFlagsVarianceMask) == VarianceFlagsInvariant))) {
					relateVariancesOk = true;
					return TernaryFalse;
				}
				// We remember the original error information so we can restore it in case the structural
				// comparison unexpectedly succeeds. This can happen when the structural comparison result
				// is a Ternary.Maybe for example caused by the recursion depth limiter.
				originalErrorChain = errorChain;
				restoreErrorState(saveErrorState);
			}
			relateVariancesOk = false;
			return TernaryFalse;
		};
		if (relation == c.identityRelation) {
			// We've already checked that source.flags and target.flags are identical
			if (source.flags & TypeFlagsUnionOrIntersection != 0) {
				var result = eachTypeRelatedToSomeType(source, target);
				if (result != TernaryFalse) {
					result &= eachTypeRelatedToSomeType(target, source);
				}
				return result;
			} else if (source.flags & TypeFlagsIndex != 0) {
				return isRelatedTo(source.Target(), target.Target(), RecursionFlagsBoth, false /*reportErrors*/);
			} else if (source.flags & TypeFlagsIndexedAccess != 0) {
				result = isRelatedTo(source.AsIndexedAccessType().objectType, target.AsIndexedAccessType().objectType, RecursionFlagsBoth, false /*reportErrors*/);
				if (result != TernaryFalse) {
					result &= isRelatedTo(source.AsIndexedAccessType().indexType, target.AsIndexedAccessType().indexType, RecursionFlagsBoth, false /*reportErrors*/);
					if (result != TernaryFalse) {
						return result;
					}
				}
			} else if (source.flags & TypeFlagsConditional != 0) {
				if (source.AsConditionalType().root.isDistributive == target.AsConditionalType().root.isDistributive) {
					result = isRelatedTo(source.AsConditionalType().checkType, target.AsConditionalType().checkType, RecursionFlagsBoth, false /*reportErrors*/);
					if (result != TernaryFalse) {
						result &= isRelatedTo(source.AsConditionalType().extendsType, target.AsConditionalType().extendsType, RecursionFlagsBoth, false /*reportErrors*/);
						if (result != TernaryFalse) {
							result &= isRelatedTo(c.getTrueTypeFromConditionalType(source), c.getTrueTypeFromConditionalType(target), RecursionFlagsBoth,
								false /*reportErrors*/);
							if (result != TernaryFalse) {
								result &= isRelatedTo(c.getFalseTypeFromConditionalType(source), c.getFalseTypeFromConditionalType(target), RecursionFlagsBoth,
									false /*reportErrors*/);
								if (result != TernaryFalse) {
									return result;
								}
							}
						}
					}
				}
			} else if (source.flags & TypeFlagsSubstitution != 0) {
				result = isRelatedTo(source.AsSubstitutionType().baseType, target.AsSubstitutionType().baseType, RecursionFlagsBoth, false /*reportErrors*/);
				if (result != TernaryFalse) {
					result &= isRelatedTo(source.AsSubstitutionType().constraint, target.AsSubstitutionType().constraint, RecursionFlagsBoth, false /*reportErrors*/);
					if (result != TernaryFalse) {
						return result;
					}
				}
			} else if (source.flags & TypeFlagsTemplateLiteral != 0) {
				if (Slices.Equal(source.AsTemplateLiteralType().texts, target.AsTemplateLiteralType().texts)) {
					result = TernaryTrue;
					final sourceTypes = source.AsTemplateLiteralType().types;
					for (i in 0...sourceTypes.length) {
						final sourceType = sourceTypes[i];
						final targetType = target.AsTemplateLiteralType().types[i];
						result &= isRelatedTo(sourceType, targetType, RecursionFlagsBoth, false /*reportErrors*/);
						if (result == TernaryFalse) {
							return result;
						}
					}
					return result;
				}
			} else if (source.flags & TypeFlagsStringMapping != 0) {
				if (source.AsStringMappingType().Symbol() == target.AsStringMappingType().Symbol()) {
					return isRelatedTo(source.AsStringMappingType().target, target.AsStringMappingType().target, RecursionFlagsBoth, false /*reportErrors*/);
				}
			}
			if (source.flags & TypeFlagsObject == 0) {
				return TernaryFalse;
			}
		} else if (source.flags & TypeFlagsUnionOrIntersection != 0 || target.flags & TypeFlagsUnionOrIntersection != 0) {
			result = unionOrIntersectionRelatedTo(source, target, reportErrors, intersectionState);
			if (result != TernaryFalse) {
				return result;
			}
			// The ordered decomposition above doesn't handle all cases. Specifically, we also need to handle:
			// Source is instantiable (e.g. source has union or intersection constraint).
			// Source is an object, target is a union (e.g. { a, b: boolean } <=> { a, b: true } | { a, b: false }).
			// Source is an intersection, target is an object (e.g. { a } & { b } <=> { a, b }).
			// Source is an intersection, target is a union (e.g. { a } & { b: boolean } <=> { a, b: true } | { a, b: false }).
			// Source is an intersection, target instantiable (e.g. string & { tag } <=> T["a"] constrained to string & { tag }).
			if (!(source.flags & TypeFlagsInstantiable != 0
				|| source.flags & TypeFlagsObject != 0 && target.flags & TypeFlagsUnion != 0
				|| source.flags & TypeFlagsIntersection != 0 && target.flags & (TypeFlagsObject | TypeFlagsUnion | TypeFlagsInstantiable) != 0)) {
				return TernaryFalse;
			}
		}
		// We limit alias variance probing to only object and conditional types since their alias behavior
		// is more predictable than other, interned types, which may or may not have an alias depending on
		// the order in which things were checked.
		if (source.flags & (TypeFlagsObject | TypeFlagsConditional) != 0 && source.alias != null && Core.len(source.alias.typeArguments) != 0
			&& target.alias != null && source.alias.symbol == target.alias.symbol && !(c.isMarkerType(source) || c.isMarkerType(target))) {
			final variances = c.getAliasVariances(source.alias.symbol);
			if (Core.len(variances) == 0) {
				return TernaryUnknown;
			}
			final params = c.typeAliasLinks.Get(source.alias.symbol).typeParameters;
			final minParams = c.getMinTypeArgumentCount(params);
			final nodeIsInJsFile = Ast.IsInJSFile(source.alias.symbol.ValueDeclaration);
			final sourceTypes = c.fillMissingTypeArguments(source.alias.typeArguments, params, minParams, nodeIsInJsFile);
			final targetTypes = c.fillMissingTypeArguments(target.alias.typeArguments, params, minParams, nodeIsInJsFile);
			final varianceResult = relateVariances(sourceTypes, targetTypes, variances, intersectionState);
			if (relateVariancesOk) {
				return varianceResult;
			}
		}
		// For a generic type T and a type U that is assignable to T, [...U] is assignable to T, U is assignable to readonly [...T],
		// and U is assignable to [...T] when U is constrained to a mutable array or tuple type.
		if (Checker.isSingleElementGenericTupleType(source) && !source.TargetTupleType().readonly) {
			result = isRelatedTo(c.getTypeArguments(source)[0], target, RecursionFlagsSource, false /*reportErrors*/);
			if (result != TernaryFalse) {
				return result;
			}
		}
		if (Checker.isSingleElementGenericTupleType(target) && (target.TargetTupleType().readonly || c.isMutableArrayOrTuple(c.getBaseConstraintOrType(source)))) {
			result = isRelatedTo(source, c.getTypeArguments(target)[0], RecursionFlagsTarget, false /*reportErrors*/);
			if (result != TernaryFalse) {
				return result;
			}
		}
		if (target.flags & TypeFlagsTypeParameter != 0) {
			// A source type { [P in Q]: X } is related to a target type T if keyof T is related to Q and X is related to T[Q].
			if (source.objectFlags & ObjectFlagsMapped != 0 && source.AsMappedType().declaration.NameType == null
				&& isRelatedTo(c.getIndexType(target), c.getConstraintTypeFromMappedType(source), RecursionFlagsBoth, false) != TernaryFalse) {
				if (Checker.getMappedTypeModifiers(source) & MappedTypeModifiersIncludeOptional == 0) {
					final templateType = c.getTemplateTypeFromMappedType(source);
					final indexedAccessType = c.getIndexedAccessType(target, c.getTypeParameterFromMappedType(source));
					result = isRelatedTo(templateType, indexedAccessType, RecursionFlagsBoth, reportErrors);
					if (result != TernaryFalse) {
						return result;
					}
				}
			}
			if (relation == c.comparableRelation && source.flags & TypeFlagsTypeParameter != 0) {
				// This is a carve-out in comparability to essentially forbid comparing a type parameter with another type parameter
				// unless one extends the other. (Remember: comparability is mostly bidirectional!)
				final constraint = c.getConstraintOfTypeParameter(source);
				if (constraint != null && Checker.someType(constraint, c -> c.flags & TypeFlagsTypeParameter != 0)) {
					return isRelatedTo(constraint, target, RecursionFlagsSource, false /*reportErrors*/);
				}
				return TernaryFalse;
			}
		} else if (target.flags & TypeFlagsIndexedAccess != 0) {
			if (source.flags & TypeFlagsIndexedAccess != 0) {
				// Relate components directly before falling back to constraint relationships
				// A type S[K] is related to a type T[J] if S is related to T and K is related to J.
				result = isRelatedTo(source.AsIndexedAccessType().objectType, target.AsIndexedAccessType().objectType, RecursionFlagsBoth, reportErrors);
				if (result != TernaryFalse) {
					result &= isRelatedTo(source.AsIndexedAccessType().indexType, target.AsIndexedAccessType().indexType, RecursionFlagsBoth, reportErrors);
				}
				if (result != TernaryFalse) {
					return result;
				}
				if (reportErrors) {
					originalErrorChain = errorChain;
				}
			}
			// A type S is related to a type T[K] if S is related to C, where C is the base
			// constraint of T[K] for writing.
			if (relation == c.assignableRelation || relation == c.comparableRelation) {
				final objectType = target.AsIndexedAccessType().objectType;
				final indexType = target.AsIndexedAccessType().indexType;
				final baseObjectType = c.getBaseConstraintOrType(objectType);
				final baseIndexType = c.getBaseConstraintOrType(indexType);
				if (!c.isGenericObjectType(baseObjectType) && !c.isGenericIndexType(baseIndexType)) {
					final accessFlags = AccessFlagsWriting | (baseObjectType != objectType ? AccessFlagsNoIndexSignatures : AccessFlagsNone);
					final constraint = c.getIndexedAccessTypeOrUndefined(baseObjectType, baseIndexType, accessFlags, null, null);
					if (constraint != null) {
						if (reportErrors && originalErrorChain != null) {
							// create a new chain for the constraint error
							restoreErrorState(saveErrorState);
						}
						result = isRelatedToEx(source, constraint, RecursionFlagsTarget, reportErrors, null /*headMessage*/, intersectionState);
						if (result != TernaryFalse) {
							return result;
						}
						// prefer the shorter chain of the constraint comparison chain, and the direct comparison chain
						if (reportErrors && originalErrorChain != null && errorChain != null) {
							if (Checker.chainDepth(originalErrorChain) <= Checker.chainDepth(errorChain)) {
								errorChain = originalErrorChain;
							}
						}
					}
				}
			}
			if (reportErrors) {
				originalErrorChain = null;
			}
		} else if (target.flags & TypeFlagsIndex != 0) {
			final targetType = target.AsIndexType().target;
			// A keyof S is related to a keyof T if T is related to S.
			if (source.flags & TypeFlagsIndex != 0) {
				result = isRelatedTo(targetType, source.AsIndexType().target, RecursionFlagsBoth, false /*reportErrors*/);
				if (result != TernaryFalse) {
					return result;
				}
			}
			if (Checker.isTupleType(targetType)) {
				// An index type can have a tuple type target when the tuple type contains variadic elements.
				// Check if the source is related to the known keys of the tuple type.
				result = isRelatedTo(source, c.getKnownKeysOfTupleType(targetType), RecursionFlagsTarget, reportErrors);
				if (result != TernaryFalse) {
					return result;
				}
			} else {
				// A type S is assignable to keyof T if S is assignable to keyof C, where C is the
				// simplified form of T or, if T doesn't simplify, the constraint of T.
				final constraint = c.getSimplifiedTypeOrConstraint(targetType);
				if (constraint != null) {
					// We require Ternary.True here such that circular constraints don't cause
					// false positives. For example, given 'T extends { [K in keyof T]: string }',
					// 'keyof T' has itself as its constraint and produces a Ternary.Maybe when
					// related to other types.
					if (isRelatedTo(source, c.getIndexTypeEx(constraint, target.AsIndexType().indexFlags | IndexFlagsNoReducibleCheck), RecursionFlagsTarget,
						reportErrors) == TernaryTrue) {
						return TernaryTrue;
					}
				} else if (c.isGenericMappedType(targetType)) {
					// generic mapped types that don't simplify or have a constraint still have a very simple set of keys we can compare against
					// - their nameType or constraintType.
					// In many ways, this comparison is a deferred version of what `getIndexTypeForMappedType` does to actually resolve the keys for _non_-generic types
					final nameType = c.getNameTypeFromMappedType(targetType);
					final constraintType = c.getConstraintTypeFromMappedType(targetType);
					var targetKeys:Type;
					if (nameType != null && c.isMappedTypeWithKeyofConstraintDeclaration(targetType)) {
						// we need to get the apparent mappings and union them with the generic mappings, since some properties may be
						// missing from the `constraintType` which will otherwise be mapped in the object
						final mappedKeys = c.getApparentMappedTypeKeys(nameType, targetType);
						// We still need to include the non-apparent (and thus still generic) keys in the target side of the comparison (in case they're in the source side)
						targetKeys = c.getUnionType([mappedKeys, nameType]);
					} else if (nameType != null) {
						targetKeys = nameType;
					} else {
						targetKeys = constraintType;
					}
					if (isRelatedTo(source, targetKeys, RecursionFlagsTarget, reportErrors) == TernaryTrue) {
						return TernaryTrue;
					}
				}
			}
		} else if (target.flags & TypeFlagsConditional != 0) {
			// If we reach 10 levels of nesting for the same conditional type, assume it is an infinitely expanding recursive
			// conditional type and bail out with a Ternary.Maybe result.
			if (c.isDeeplyNestedType(target, targetStack, 10)) {
				return TernaryMaybe;
			}
			final ct = target.AsConditionalType(); // PORT: Go name `c` clashes with the Relater field
			// We check for a relationship to a conditional type target only when the conditional type has no
			// 'infer' positions, is not distributive or is distributive but doesn't reference the check type
			// parameter in either of the result types, and the source isn't an instantiation of the same
			// conditional type (as happens when computing variance).
			if (ct.root.inferTypeParameters == null && !c.isDistributionDependent(ct.root)
				&& !(source.flags & TypeFlagsConditional != 0 && source.AsConditionalType().root == ct.root)) {
				// Check if the conditional is always true or always false but still deferred for distribution purposes.
				final skipTrue = !c.isTypeAssignableTo(c.getPermissiveInstantiation(ct.checkType), c.getPermissiveInstantiation(ct.extendsType));
				final skipFalse = !skipTrue && c.isTypeAssignableTo(c.getRestrictiveInstantiation(ct.checkType), c.getRestrictiveInstantiation(ct.extendsType));
				// TODO: Find a nice way to include potential conditional type breakdowns in error output, if they seem good (they usually don't)
				if (skipTrue) {
					result = TernaryTrue;
				} else {
					result = isRelatedToEx(source, c.getTrueTypeFromConditionalType(target), RecursionFlagsTarget, false /*reportErrors*/, null /*headMessage*/,
						intersectionState);
				}
				if (result != TernaryFalse) {
					if (skipFalse) {
						result &= TernaryTrue;
					} else {
						result &= isRelatedToEx(source, c.getFalseTypeFromConditionalType(target), RecursionFlagsTarget, false /*reportErrors*/, null /*headMessage*/,
							intersectionState);
					}
					if (result != TernaryFalse) {
						return result;
					}
				}
			}
		} else if (target.flags & TypeFlagsTemplateLiteral != 0) {
			if (source.flags & TypeFlagsTemplateLiteral != 0) {
				if (relation == c.comparableRelation) {
					if (c.templateLiteralTypesDefinitelyUnrelated(source.AsTemplateLiteralType(), target.AsTemplateLiteralType())) {
						return TernaryFalse;
					}
					return TernaryTrue;
				}
				// Report unreliable variance for type variables referenced in template literal type placeholders.
				// For example, `foo-${number}` is related to `foo-${string}` even though number isn't related to string.
				c.instantiateType(source, c.reportUnreliableMapper);
			}
			if (c.isTypeMatchedByTemplateLiteralType(source, target.AsTemplateLiteralType(), isRelatedToWorker)) {
				return TernaryTrue;
			}
		} else if (target.flags & TypeFlagsStringMapping != 0) {
			if (source.flags & TypeFlagsStringMapping == 0) {
				if (c.isMemberOfStringMapping(source, target)) {
					return TernaryTrue;
				}
			}
		} else if (c.isGenericMappedType(target) && relation != c.identityRelation) {
			// Check if source type `S` is related to target type `{ [P in Q]: T }` or `{ [P in Q as R]: T}`.
			final keysRemapped = target.AsMappedType().declaration.NameType != null;
			final templateType = c.getTemplateTypeFromMappedType(target);
			final modifiers = Checker.getMappedTypeModifiers(target);
			if (modifiers & MappedTypeModifiersExcludeOptional == 0) {
				// If the mapped type has shape `{ [P in Q]: T[P] }`,
				// source `S` is related to target if `T` = `S`, i.e. `S` is related to `{ [P in Q]: S[P] }`.
				if (!keysRemapped && templateType.flags & TypeFlagsIndexedAccess != 0 && templateType.AsIndexedAccessType().objectType == source
					&& templateType.AsIndexedAccessType().indexType == c.getTypeParameterFromMappedType(target)) {
					return TernaryTrue;
				}
				if (!c.isGenericMappedType(source)) {
					// If target has shape `{ [P in Q as R]: T}`, then its keys have type `R`.
					// If target has shape `{ [P in Q]: T }`, then its keys have type `Q`.
					var targetKeys:Type;
					if (keysRemapped) {
						targetKeys = c.getNameTypeFromMappedType(target);
					} else {
						targetKeys = c.getConstraintTypeFromMappedType(target);
					}
					// Type of the keys of source type `S`, i.e. `keyof S`.
					final sourceKeys = c.getIndexTypeEx(source, IndexFlagsNoIndexSignatures);
					final includeOptional = modifiers & MappedTypeModifiersIncludeOptional != 0;
					var filteredByApplicability:Type = null;
					if (includeOptional) {
						filteredByApplicability = c.intersectTypes(targetKeys, sourceKeys);
					}
					// A source type `S` is related to a target type `{ [P in Q]: T }` if `Q` is related to `keyof S` and `S[Q]` is related to `T`.
					// A source type `S` is related to a target type `{ [P in Q as R]: T }` if `R` is related to `keyof S` and `S[R]` is related to `T.
					// A source type `S` is related to a target type `{ [P in Q]?: T }` if some constituent `Q'` of `Q` is related to `keyof S` and `S[Q']` is related to `T`.
					// A source type `S` is related to a target type `{ [P in Q as R]?: T }` if some constituent `R'` of `R` is related to `keyof S` and `S[R']` is related to `T`.
					if (includeOptional && filteredByApplicability.flags & TypeFlagsNever == 0
						|| !includeOptional && isRelatedTo(targetKeys, sourceKeys, RecursionFlagsBoth, false) != TernaryFalse) {
						final templateType = c.getTemplateTypeFromMappedType(target);
						final typeParameter = c.getTypeParameterFromMappedType(target);
						// Fastpath: When the template type has the form `Obj[P]` where `P` is the mapped type parameter, directly compare source `S` with `Obj`
						// to avoid creating the (potentially very large) number of new intermediate types made by manufacturing `S[P]`.
						final nonNullComponent = c.extractTypesOfKind(templateType, ~TypeFlagsNullable);
						if (!keysRemapped && nonNullComponent.flags & TypeFlagsIndexedAccess != 0 && nonNullComponent.AsIndexedAccessType().indexType == typeParameter) {
							result = isRelatedTo(source, nonNullComponent.AsIndexedAccessType().objectType, RecursionFlagsTarget, reportErrors);
							if (result != TernaryFalse) {
								return result;
							}
						} else {
							// We need to compare the type of a property on the source type `S` to the type of the same property on the target type,
							// so we need to construct an indexing type representing a property, and then use indexing type to index the source type for comparison.
							// If the target type has shape `{ [P in Q]: T }`, then a property of the target has type `P`.
							// If the target type has shape `{ [P in Q]?: T }`, then a property of the target has type `P`,
							// but the property is optional, so we only want to compare properties `P` that are common between `keyof S` and `Q`.
							// If the target type has shape `{ [P in Q as R]: T }`, then a property of the target has type `R`.
							// If the target type has shape `{ [P in Q as R]?: T }`, then a property of the target has type `R`,
							// but the property is optional, so we only want to compare properties `R` that are common between `keyof S` and `R`.
							var indexingType = typeParameter;
							if (keysRemapped) {
								indexingType = Core.OrElse(filteredByApplicability, targetKeys);
							} else if (filteredByApplicability != null) {
								indexingType = c.getIntersectionType([filteredByApplicability, typeParameter]);
							}
							final indexedAccessType = c.getIndexedAccessType(source, indexingType);
							// Compare `S[indexingType]` to `T`, where `T` is the type of a property of the target type.
							result = isRelatedTo(indexedAccessType, templateType, RecursionFlagsBoth, reportErrors);
							if (result != TernaryFalse) {
								return result;
							}
						}
					}
					originalErrorChain = errorChain;
					restoreErrorState(saveErrorState);
				}
			}
		}
		if (source.flags & TypeFlagsTypeVariable != 0) {
			// IndexedAccess comparisons are handled above in the `target.flags&TypeFlagsIndexedAccess` branch
			if (source.flags & TypeFlagsIndexedAccess == 0 || target.flags & TypeFlagsIndexedAccess == 0) {
				var constraint = c.getConstraintOfType(source);
				if (constraint == null) {
					constraint = c.unknownType;
				}
				// hi-speed no-this-instantiation check (less accurate, but avoids costly `this`-instantiation when the constraint will suffice), see #28231 for report on why this is needed
				result = isRelatedToEx(constraint, target, RecursionFlagsSource, false /*reportErrors*/, null /*headMessage*/, intersectionState);
				if (result != TernaryFalse) {
					return result;
				}
				final constraintWithThis = c.getTypeWithThisArgument(constraint, source, false /*needApparentType*/);
				result = isRelatedToEx(constraintWithThis, target, RecursionFlagsSource,
					reportErrors && constraint != c.unknownType && target.flags & source.flags & TypeFlagsTypeParameter == 0, null /*headMessage*/, intersectionState);
				if (result != TernaryFalse) {
					return result;
				}
				if (c.isMappedTypeGenericIndexedAccess(source)) {
					// For an indexed access type { [P in K]: E}[X], above we have already explored an instantiation of E with X
					// substituted for P. We also want to explore type { [P in K]: E }[C], where C is the constraint of X.
					final indexConstraint = c.getConstraintOfType(source.AsIndexedAccessType().indexType);
					if (indexConstraint != null) {
						result = isRelatedTo(c.getIndexedAccessType(source.AsIndexedAccessType().objectType, indexConstraint), target, RecursionFlagsSource, reportErrors);
						if (result != TernaryFalse) {
							return result;
						}
					}
				}
			}
		} else if (source.flags & TypeFlagsIndex != 0) {
			final isDeferredMappedIndex = c.shouldDeferIndexType(source.AsIndexType().target, source.AsIndexType().indexFlags)
				&& source.AsIndexType().target.objectFlags & ObjectFlagsMapped != 0;
			result = isRelatedTo(c.stringNumberSymbolType, target, RecursionFlagsSource, reportErrors && !isDeferredMappedIndex);
			if (result != TernaryFalse) {
				return result;
			}
			if (isDeferredMappedIndex) {
				final mappedType = source.AsIndexType().target;
				final nameType = c.getNameTypeFromMappedType(mappedType);
				// Unlike on the target side, on the source side we do *not* include the generic part of the `nameType`, since that comes from a
				// (potentially anonymous) mapped type local type parameter, so that'd never assign outside the mapped type body, but we still want to
				// allow assignments of index types of identical (or similar enough) mapped types.
				// eg, `keyof {[X in keyof A]: Obj[X]}` should be assignable to `keyof {[Y in keyof A]: Tup[Y]}` because both map over the same set of keys (`keyof A`).
				// Without this source-side breakdown, a `keyof {[X in keyof A]: Obj[X]}` style type won't be assignable to anything except itself, which is much too strict.
				var sourceMappedKeys:Type;
				if (nameType != null && c.isMappedTypeWithKeyofConstraintDeclaration(mappedType)) {
					sourceMappedKeys = c.getApparentMappedTypeKeys(nameType, mappedType);
				} else if (nameType != null) {
					sourceMappedKeys = nameType;
				} else {
					sourceMappedKeys = c.getConstraintTypeFromMappedType(mappedType);
				}
				result = isRelatedTo(sourceMappedKeys, target, RecursionFlagsSource, reportErrors);
				if (result != TernaryFalse) {
					return result;
				}
			}
		} else if (source.flags & TypeFlagsConditional != 0) {
			// If we reach 10 levels of nesting for the same conditional type, assume it is an infinitely expanding recursive
			// conditional type and bail out with a Ternary.Maybe result.
			if (c.isDeeplyNestedType(source, sourceStack, 10)) {
				return TernaryMaybe;
			}
			if (target.flags & TypeFlagsConditional != 0) {
				// Two conditional types 'T1 extends U1 ? X1 : Y1' and 'T2 extends U2 ? X2 : Y2' are related if
				// one of T1 and T2 is related to the other, U1 and U2 are identical types, X1 is related to X2,
				// and Y1 is related to Y2.
				final sourceParams = source.AsConditionalType().root.inferTypeParameters;
				var sourceExtends = source.AsConditionalType().extendsType;
				var mapper:TypeMapper = null;
				if (Core.len(sourceParams) != 0) {
					// If the source has infer type parameters, we instantiate them in the context of the target
					final ctx = c.newInferenceContext(sourceParams, null /*signature*/, InferenceFlagsNone, isRelatedToWorker);
					c.inferTypes(ctx.inferences, target.AsConditionalType().extendsType, sourceExtends, InferencePriorityNoConstraints | InferencePriorityAlwaysStrict, false);
					sourceExtends = c.instantiateType(sourceExtends, ctx.mapper);
					mapper = ctx.mapper;
				}
				if (c.isTypeIdenticalTo(sourceExtends, target.AsConditionalType().extendsType)
					&& (isRelatedTo(source.AsConditionalType().checkType, target.AsConditionalType().checkType, RecursionFlagsBoth, false) != 0
						|| isRelatedTo(target.AsConditionalType().checkType, source.AsConditionalType().checkType, RecursionFlagsBoth, false) != 0)) {
					result = isRelatedTo(c.instantiateType(c.getTrueTypeFromConditionalType(source), mapper), c.getTrueTypeFromConditionalType(target), RecursionFlagsBoth,
						reportErrors);
					if (result != TernaryFalse) {
						result &= isRelatedTo(c.getFalseTypeFromConditionalType(source), c.getFalseTypeFromConditionalType(target), RecursionFlagsBoth, reportErrors);
					}
					if (result != TernaryFalse) {
						return result;
					}
				}
			}
			// conditionals can be related to one another via normal constraint, as, eg, `A extends B ? O : never` should be assignable to `O`
			// when `O` is a conditional (`never` is trivially assignable to `O`, as is `O`!).
			final defaultConstraint = c.getDefaultConstraintOfConditionalType(source);
			if (defaultConstraint != null) {
				result = isRelatedTo(defaultConstraint, target, RecursionFlagsSource, reportErrors);
				if (result != TernaryFalse) {
					return result;
				}
			}
			// conditionals aren't related to one another via distributive constraint as it is much too inaccurate and allows way
			// more assignments than are desirable (since it maps the source check type to its constraint, it loses information).
			if (target.flags & TypeFlagsConditional == 0 && c.hasNonCircularBaseConstraint(source)) {
				final distributiveConstraint = c.getConstraintOfDistributiveConditionalType(source);
				if (distributiveConstraint != null) {
					restoreErrorState(saveErrorState);
					result = isRelatedTo(distributiveConstraint, target, RecursionFlagsSource, reportErrors);
					if (result != TernaryFalse) {
						return result;
					}
				}
			}
		} else if (source.flags & TypeFlagsTemplateLiteral != 0 && target.flags & TypeFlagsObject == 0) {
			if (target.flags & TypeFlagsTemplateLiteral == 0) {
				final constraint = c.getBaseConstraintOfType(source);
				if (constraint != null && constraint != source) {
					result = isRelatedTo(constraint, target, RecursionFlagsSource, reportErrors);
					if (result != TernaryFalse) {
						return result;
					}
				}
			}
		} else if (source.flags & TypeFlagsStringMapping != 0) {
			if (target.flags & TypeFlagsStringMapping != 0) {
				if (source.AsStringMappingType().symbol != target.AsStringMappingType().symbol) {
					return TernaryFalse;
				}
				result = isRelatedTo(source.AsStringMappingType().target, target.AsStringMappingType().target, RecursionFlagsBoth, reportErrors);
				if (result != TernaryFalse) {
					return result;
				}
			} else {
				final constraint = c.getBaseConstraintOfType(source);
				if (constraint != null) {
					result = isRelatedTo(constraint, target, RecursionFlagsSource, reportErrors);
					if (result != TernaryFalse) {
						return result;
					}
				}
			}
		} else {
			// An empty object type is related to any mapped type that includes a '?' modifier.
			if (relation != c.subtypeRelation && relation != c.strictSubtypeRelation && Checker.isPartialMappedType(target) && c.isEmptyObjectType(source)) {
				return TernaryTrue;
			}
			if (c.isGenericMappedType(target)) {
				if (c.isGenericMappedType(source)) {
					result = mappedTypeRelatedTo(source, target, reportErrors);
					if (result != TernaryFalse) {
						return result;
					}
				}
				return TernaryFalse;
			}
			final sourceIsPrimitive = source.flags & TypeFlagsPrimitive != 0;
			if (relation != c.identityRelation) {
				source = c.getApparentType(source);
			} else if (c.isGenericMappedType(source)) {
				return TernaryFalse;
			}
			if (source.objectFlags & ObjectFlagsReference != 0 && target.objectFlags & ObjectFlagsReference != 0 && source.Target() == target.Target()
				&& !Checker.isTupleType(source) && !c.isMarkerType(source) && !c.isMarkerType(target)) {
				// When strictNullChecks is disabled, the element type of the empty array literal is undefinedWideningType,
				// and an empty array literal wouldn't be assignable to a `never[]` without this check.
				if (c.isEmptyArrayLiteralType(source)) {
					return TernaryTrue;
				}
				// We have type references to the same generic type, and the type references are not marker
				// type references (which are intended by be compared structurally). Obtain the variance
				// information for the type parameters and relate the type arguments accordingly.
				final variances = c.getVariances(source.Target());
				// We return Ternary.Maybe for a recursive invocation of getVariances (signaled by emptyArray). This
				// effectively means we measure variance only from type parameter occurrences that aren't nested in
				// recursive instantiations of the generic type.
				if (Core.len(variances) == 0) {
					return TernaryUnknown;
				}
				final varianceResult = relateVariances(c.getTypeArguments(source), c.getTypeArguments(target), variances, intersectionState);
				if (relateVariancesOk) {
					return varianceResult;
				}
			} else if (c.isArrayType(target)
				&& (c.isReadonlyArrayType(target) && Checker.everyType(source, t -> c.isArrayOrTupleType(t)) || Checker.everyType(source, Checker.isMutableTupleType))) {
				if (relation != c.identityRelation) {
					return isRelatedTo(c.getIndexTypeOfTypeEx(source, c.numberType, c.anyType), c.getIndexTypeOfTypeEx(target, c.numberType, c.anyType), RecursionFlagsBoth,
						reportErrors);
				}
				// By flags alone, we know that the `target` is a readonly array while the source is a normal array or tuple
				// or `target` is an array and source is a tuple - in both cases the types cannot be identical, by construction
				return TernaryFalse;
			} else if (c.isGenericTupleType(source) && Checker.isTupleType(target) && !c.isGenericTupleType(target)) {
				final constraint = c.getBaseConstraintOrType(source);
				if (constraint != source) {
					return isRelatedTo(constraint, target, RecursionFlagsSource, reportErrors);
				}
			} else if ((relation == c.subtypeRelation || relation == c.strictSubtypeRelation) && c.isEmptyObjectType(target)
				&& target.objectFlags & ObjectFlagsFreshLiteral != 0 && !c.isEmptyObjectType(source)) {
				return TernaryFalse;
			}
			// Even if relationship doesn't hold for unions, intersections, or generic type references,
			// it may hold in a structural comparison.
			// In a check of the form X = A & B, we will have previously checked if A relates to X or B relates
			// to X. Failing both of those we want to check if the aggregation of A and B's members structurally
			// relates to X. Thus, we include intersection types on the source side here.
			if (source.flags & (TypeFlagsObject | TypeFlagsIntersection) != 0 && target.flags & TypeFlagsObject != 0) {
				// Report structural errors only if we haven't reported any errors yet
				final reportStructuralErrors = reportErrors && errorChain == saveErrorState.errorChain && !sourceIsPrimitive;
				result = propertiesRelatedTo(source, target, reportStructuralErrors, null /*excludedProperties*/, false /*optionalsOnly*/, intersectionState);
				if (result != TernaryFalse) {
					result &= signaturesRelatedTo(source, target, SignatureKindCall, reportStructuralErrors, intersectionState);
					if (result != TernaryFalse) {
						result &= signaturesRelatedTo(source, target, SignatureKindConstruct, reportStructuralErrors, intersectionState);
						if (result != TernaryFalse) {
							result &= indexSignaturesRelatedTo(source, target, sourceIsPrimitive, reportStructuralErrors, intersectionState);
						}
					}
				}
				if (result != TernaryFalse) {
					if (!varianceCheckFailed) {
						return result;
					}
					if (originalErrorChain != null) {
						errorChain = originalErrorChain;
					} else if (errorChain == null) {
						errorChain = saveErrorState.errorChain;
					}
					// Use variance error (there is no structural one) and return false
				}
			}
			// If S is an object type and T is a discriminated union, S may be related to T if
			// there exists a constituent of T for every combination of the discriminants of S
			// with respect to T. We do not report errors here, as we will use the existing
			// error result from checking each constituent of the union.
			if (source.flags & (TypeFlagsObject | TypeFlagsIntersection) != 0 && target.flags & TypeFlagsUnion != 0) {
				final objectOnlyTarget = c.extractTypesOfKind(target, TypeFlagsObject | TypeFlagsIntersection | TypeFlagsSubstitution);
				if (objectOnlyTarget.flags & TypeFlagsUnion != 0) {
					final result = typeRelatedToDiscriminatedType(source, objectOnlyTarget);
					if (result != TernaryFalse) {
						return result;
					}
				}
			}
		}
		return TernaryFalse;
	}

	function typeArgumentsRelatedTo(sources:Array<Type>, targets:Array<Type>, variances:Array<VarianceFlags>, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		if (Core.len(sources) != Core.len(targets) && relation == c.identityRelation) {
			return TernaryFalse;
		}
		final length = Core.len(sources) < Core.len(targets) ? Core.len(sources) : Core.len(targets);
		var result:Ternary = TernaryTrue;
		for (i in 0...length) {
			// When variance information isn't available we default to covariance. This happens
			// in the process of computing variance information for recursive types and when
			// comparing 'this' type arguments.
			var varianceFlags = VarianceFlagsCovariant;
			if (i < Core.len(variances)) {
				varianceFlags = variances[i];
			}
			final variance = varianceFlags & VarianceFlagsVarianceMask;
			// We ignore arguments for independent type parameters (because they're never witnessed).
			if (variance != VarianceFlagsIndependent) {
				final s = sources[i];
				final t = targets[i];
				var related:Ternary;
				if (varianceFlags & VarianceFlagsUnmeasurable != 0) {
					// Even an `Unmeasurable` variance works out without a structural check if the source and target are _identical_.
					// We can't simply assume invariance, because `Unmeasurable` marks nonlinear relations, for example, a relation tainted by
					// the `-?` modifier in a mapped type (where, no matter how the inputs are related, the outputs still might not be)
					if (relation == c.identityRelation) {
						related = isRelatedTo(s, t, RecursionFlagsBoth, false /*reportErrors*/);
					} else {
						related = c.compareTypesIdentical(s, t);
					}
				} else {
					// Propagate unreliable variance flag
					if (c.inVarianceComputation && varianceFlags & VarianceFlagsUnreliable != 0) {
						c.instantiateType(s, c.reportUnreliableMapper);
					}
					if (variance == VarianceFlagsCovariant) {
						related = isRelatedToEx(s, t, RecursionFlagsBoth, reportErrors, null /*headMessage*/, intersectionState);
					} else if (variance == VarianceFlagsContravariant) {
						related = isRelatedToEx(t, s, RecursionFlagsBoth, reportErrors, null /*headMessage*/, intersectionState);
					} else if (variance == VarianceFlagsBivariant) {
						// In the bivariant case we first compare contravariantly without reporting
						// errors. Then, if that doesn't succeed, we compare covariantly with error
						// reporting. Thus, error elaboration will be based on the covariant check,
						// which is generally easier to reason about.
						related = isRelatedTo(t, s, RecursionFlagsBoth, false /*reportErrors*/);
						if (related == TernaryFalse) {
							related = isRelatedToEx(s, t, RecursionFlagsBoth, reportErrors, null /*headMessage*/, intersectionState);
						}
					} else {
						// In the invariant case we first compare covariantly, and only when that
						// succeeds do we proceed to compare contravariantly. Thus, error elaboration
						// will typically be based on the covariant check.
						related = isRelatedToEx(s, t, RecursionFlagsBoth, reportErrors, null /*headMessage*/, intersectionState);
						if (related != TernaryFalse) {
							related &= isRelatedToEx(t, s, RecursionFlagsBoth, reportErrors, null /*headMessage*/, intersectionState);
						}
					}
				}
				if (related == TernaryFalse) {
					return TernaryFalse;
				}
				result &= related;
			}
		}
		return result;
	}

	// A type [P in S]: X is related to a type [Q in T]: Y if T is related to S and X' is
	// related to Y, where X' is an instantiation of X in which P is replaced with Q. Notice
	// that S and T are contra-variant whereas X and Y are co-variant.
	function mappedTypeRelatedTo(source:Type, target:Type, reportErrors:Bool):Ternary {
		final modifiersRelated = relation == c.comparableRelation
			|| relation == c.identityRelation && Checker.getMappedTypeModifiers(source) == Checker.getMappedTypeModifiers(target)
			|| relation != c.identityRelation && c.getCombinedMappedTypeOptionality(source) <= c.getCombinedMappedTypeOptionality(target);
		if (modifiersRelated) {
			final targetConstraint = c.getConstraintTypeFromMappedType(target);
			final sourceConstraint = c.instantiateType(c.getConstraintTypeFromMappedType(source),
				c.getCombinedMappedTypeOptionality(source) < 0 ? c.reportUnmeasurableMapper : c.reportUnreliableMapper);
			final result = isRelatedTo(targetConstraint, sourceConstraint, RecursionFlagsBoth, reportErrors);
			if (result != TernaryFalse) {
				final mapper = Checker.newSimpleTypeMapper(c.getTypeParameterFromMappedType(source), c.getTypeParameterFromMappedType(target));
				if (c.instantiateType(c.getNameTypeFromMappedType(source), mapper) == c.instantiateType(c.getNameTypeFromMappedType(target), mapper)) {
					return result & isRelatedTo(c.instantiateType(c.getTemplateTypeFromMappedType(source), mapper), c.getTemplateTypeFromMappedType(target),
						RecursionFlagsBoth, reportErrors);
				}
			}
		}
		return TernaryFalse;
	}

	function typeRelatedToDiscriminatedType(source:Type, target:Type):Ternary {
		// 1. Generate the combinations of discriminant properties & types 'source' can satisfy.
		//    a. If the number of combinations is above a set limit, the comparison is too complex.
		// 2. Filter 'target' to the subset of types whose discriminants exist in the matrix.
		//    a. If 'target' does not satisfy all discriminants in the matrix, 'source' is not related.
		// 3. For each type in the filtered 'target', determine if all non-discriminant properties of
		//    'target' are related to a property in 'source'.
		//
		// NOTE: See ~/tests/cases/conformance/types/typeRelationships/assignmentCompatibility/assignmentCompatWithDiscriminatedUnion.ts
		//       for examples.
		final sourceProperties = c.getPropertiesOfType(source);
		final sourcePropertiesFiltered = c.findDiscriminantProperties(sourceProperties, target);
		if (Core.len(sourcePropertiesFiltered) == 0) {
			return TernaryFalse;
		}
		// Though we could compute the number of combinations as we generate
		// the matrix, this would incur additional memory overhead due to
		// array allocations. To reduce this overhead, we first compute
		// the number of combinations to ensure we will not surpass our
		// fixed limit before incurring the cost of any allocations:
		var numCombinations = 1;
		for (sourceProperty in sourcePropertiesFiltered) {
			numCombinations *= Checker.countTypes(c.getNonMissingTypeOfSymbol(sourceProperty));
			if (numCombinations > 25) {
				final tr = c.tracer;
				if (tr != null) {
					final args = new StringMap<Any>();
					args.set("sourceId", source.id);
					args.set("targetId", target.id);
					args.set("numCombinations", numCombinations);
					tr.Instant(PhaseCheckTypes, "typeRelatedToDiscriminatedType_DepthLimit", args);
				}
				return TernaryFalse;
			}
			if (numCombinations == 0) {
				return TernaryFalse;
			}
		}
		// Compute the set of types for each discriminant property.
		final sourceDiscriminantTypes:Array<Array<Type>> = [for (_ in 0...sourcePropertiesFiltered.length) null];
		final excludedProperties = new Set<std.String>();
		for (i in 0...sourcePropertiesFiltered.length) {
			final sourceProperty = sourcePropertiesFiltered[i];
			final sourcePropertyType = c.getNonMissingTypeOfSymbol(sourceProperty);
			sourceDiscriminantTypes[i] = sourcePropertyType.Distributed();
			excludedProperties.Add(sourceProperty.Name);
		}
		// Build the cartesian product
		final discriminantCombinations:Array<Array<Type>> = [for (_ in 0...numCombinations) null];
		for (i in 0...numCombinations) {
			final combination:Array<Type> = [for (_ in 0...sourceDiscriminantTypes.length) null];
			var n = i;
			var j = sourceDiscriminantTypes.length - 1;
			while (j >= 0) {
				final sourceTypes = sourceDiscriminantTypes[j];
				final length = sourceTypes.length;
				combination[j] = sourceTypes[n % length];
				n = Std.int(n / length);
				j--;
			}
			discriminantCombinations[i] = combination;
		}
		// Match each combination of the cartesian product of discriminant properties to one or more
		// constituents of 'target'. If any combination does not have a match then 'source' is not relatable.
		var matchingTypes:Array<Type> = null;
		for (combination in discriminantCombinations) {
			var hasMatch = false;
			for (t in target.Types()) {
				var matched = true; // PORT: label — `continue outer` becomes matched = false; break
				for (i in 0...sourcePropertiesFiltered.length) {
					final sourceProperty = sourcePropertiesFiltered[i];
					final targetProperty = c.getPropertyOfType(t, sourceProperty.Name);
					if (targetProperty == null) {
						matched = false;
						break;
					}
					if (sourceProperty == targetProperty) {
						continue;
					}
					// We compare the source property to the target in the context of a single discriminant type.
					final related = propertyRelatedTo(source, target, sourceProperty, targetProperty, _ -> combination[i], false /*reportErrors*/, IntersectionStateNone,
						c.strictNullChecks || relation == c.comparableRelation /*skipOptional*/);
					// If the target property could not be found, or if the properties were not related,
					// then this constituent is not a match.
					if (related == TernaryFalse) {
						matched = false;
						break;
					}
				}
				if (!matched) {
					continue;
				}
				matchingTypes = Core.AppendIfUnique(matchingTypes, t);
				hasMatch = true;
			}
			if (!hasMatch) {
				// We failed to match any type for this combination.
				return TernaryFalse;
			}
		}
		// Compare the remaining non-discriminant properties of each match.
		var result:Ternary = TernaryTrue;
		if (matchingTypes != null) {
			for (t in matchingTypes) {
				result &= propertiesRelatedTo(source, t /*reportErrors*/, false, excludedProperties /*optionalsOnly*/, false, IntersectionStateNone);
				if (result != TernaryFalse) {
					result &= signaturesRelatedTo(source, t, SignatureKindCall /*reportErrors*/, false, IntersectionStateNone);
					if (result != TernaryFalse) {
						result &= signaturesRelatedTo(source, t, SignatureKindConstruct /*reportErrors*/, false, IntersectionStateNone);
						if (result != TernaryFalse && !(Checker.isTupleType(source) && Checker.isTupleType(t))) {
							// Comparing numeric index types when both `source` and `type` are tuples is unnecessary as the
							// element types should be sufficiently covered by `propertiesRelatedTo`. It also causes problems
							// with index type assignability as the types for the excluded discriminants are still included
							// in the index type.
							result &= indexSignaturesRelatedTo(source, t /*sourceIsPrimitive*/, false /*reportErrors*/, false, IntersectionStateNone);
						}
					}
				}
				if (result == TernaryFalse) {
					return result;
				}
			}
		}
		return result;
	}

	function propertiesRelatedTo(source:Type, target:Type, reportErrors:Bool, excludedProperties:Set<std.String>, optionalsOnly:Bool, intersectionState:IntersectionState):Ternary {
		if (relation == c.identityRelation) {
			return propertiesIdenticalTo(source, target, excludedProperties);
		}
		var result:Ternary = TernaryTrue;
		if (Checker.isTupleType(target)) {
			if (c.isArrayOrTupleType(source)) {
				if (!target.TargetTupleType().readonly && (c.isReadonlyArrayType(source) || Checker.isTupleType(source) && source.TargetTupleType().readonly)) {
					return TernaryFalse;
				}
				final sourceArity = c.getTypeReferenceArity(source);
				final targetArity = c.getTypeReferenceArity(target);
				var sourceRest:Bool;
				if (Checker.isTupleType(source)) {
					sourceRest = source.TargetTupleType().combinedFlags & ElementFlagsRest != 0;
				} else {
					sourceRest = true;
				}
				final targetHasRestElement = target.TargetTupleType().combinedFlags & ElementFlagsVariable != 0;
				var sourceMinLength:Int;
				if (Checker.isTupleType(source)) {
					sourceMinLength = source.TargetTupleType().minLength;
				} else {
					sourceMinLength = 0;
				}
				final targetMinLength = target.TargetTupleType().minLength;
				if (!sourceRest && sourceArity < targetMinLength) {
					if (reportErrors) {
						reportError(Diagnostics.Source_has_0_element_s_but_target_requires_1, sourceArity, targetMinLength);
					}
					return TernaryFalse;
				}
				if (!targetHasRestElement && targetArity < sourceMinLength) {
					if (reportErrors) {
						reportError(Diagnostics.Source_has_0_element_s_but_target_allows_only_1, sourceMinLength, targetArity);
					}
					return TernaryFalse;
				}
				if (!targetHasRestElement && (sourceRest || targetArity < sourceArity)) {
					if (reportErrors) {
						if (sourceMinLength < targetMinLength) {
							reportError(Diagnostics.Target_requires_0_element_s_but_source_may_have_fewer, targetMinLength);
						} else {
							reportError(Diagnostics.Target_allows_only_0_element_s_but_source_may_have_more, targetArity);
						}
					}
					return TernaryFalse;
				}
				final sourceTypeArguments = c.getTypeArguments(source);
				final targetTypeArguments = c.getTypeArguments(target);
				final targetStartCount = Checker.getStartElementCount(target.TargetTupleType(), ElementFlagsNonRest);
				final targetEndCount = Checker.getEndElementCount(target.TargetTupleType(), ElementFlagsNonRest);
				var canExcludeDiscriminants = excludedProperties.Len() != 0;
				for (sourcePosition in 0...sourceArity) {
					var sourceFlags:ElementFlags;
					if (Checker.isTupleType(source)) {
						sourceFlags = source.TargetTupleType().elementInfos[sourcePosition].flags;
					} else {
						sourceFlags = ElementFlagsRest;
					}
					final sourcePositionFromEnd = sourceArity - 1 - sourcePosition;
					var targetPosition:Int;
					if (targetHasRestElement && sourcePosition >= targetStartCount) {
						targetPosition = targetArity - 1 - (sourcePositionFromEnd < targetEndCount ? sourcePositionFromEnd : targetEndCount);
					} else {
						targetPosition = sourcePosition;
					}
					var targetFlags = ElementFlagsNone;
					if (targetPosition >= 0) {
						targetFlags = target.TargetTupleType().elementInfos[targetPosition].flags;
					}
					if (targetFlags & ElementFlagsVariadic != 0 && sourceFlags & ElementFlagsVariadic == 0) {
						if (reportErrors) {
							reportError(Diagnostics.Source_provides_no_match_for_variadic_element_at_position_0_in_target, targetPosition);
						}
						return TernaryFalse;
					}
					if (sourceFlags & ElementFlagsVariadic != 0 && targetFlags & ElementFlagsVariable == 0) {
						if (reportErrors) {
							reportError(Diagnostics.Variadic_element_at_position_0_in_source_does_not_match_element_at_position_1_in_target, sourcePosition, targetPosition);
						}
						return TernaryFalse;
					}
					if (targetFlags & ElementFlagsRequired != 0 && sourceFlags & ElementFlagsRequired == 0) {
						if (reportErrors) {
							reportError(Diagnostics.Source_provides_no_match_for_required_element_at_position_0_in_target, targetPosition);
						}
						return TernaryFalse;
					}
					// We can only exclude discriminant properties if we have not yet encountered a variable-length element.
					if (canExcludeDiscriminants) {
						if (sourceFlags & ElementFlagsVariable != 0 || targetFlags & ElementFlagsVariable != 0) {
							canExcludeDiscriminants = false;
						}
						if (canExcludeDiscriminants && excludedProperties.Has(Std.string(sourcePosition))) {
							continue;
						}
					}
					final sourceType = c.removeMissingType(sourceTypeArguments[sourcePosition], sourceFlags & targetFlags & ElementFlagsOptional != 0);
					final targetType = targetTypeArguments[targetPosition];
					var targetCheckType:Type;
					if (sourceFlags & ElementFlagsVariadic != 0 && targetFlags & ElementFlagsRest != 0) {
						targetCheckType = c.createArrayType(targetType);
					} else {
						targetCheckType = c.removeMissingType(targetType, targetFlags & ElementFlagsOptional != 0);
					}
					final related = isRelatedToEx(sourceType, targetCheckType, RecursionFlagsBoth, reportErrors, null /*headMessage*/, intersectionState);
					if (related == TernaryFalse) {
						if (reportErrors && (targetArity > 1 || sourceArity > 1)) {
							if (targetHasRestElement && sourcePosition >= targetStartCount && sourcePositionFromEnd >= targetEndCount
								&& targetStartCount != sourceArity - targetEndCount - 1) {
								reportError(Diagnostics.Type_at_positions_0_through_1_in_source_is_not_compatible_with_type_at_position_2_in_target, targetStartCount,
									sourceArity - targetEndCount - 1, targetPosition);
							} else {
								reportError(Diagnostics.Type_at_position_0_in_source_is_not_compatible_with_type_at_position_1_in_target, sourcePosition, targetPosition);
							}
						}
						return TernaryFalse;
					}
					result &= related;
				}
				return result;
			}
			if (target.TargetTupleType().combinedFlags & ElementFlagsVariable != 0) {
				return TernaryFalse;
			}
		}
		final requireOptionalProperties = (relation == c.subtypeRelation || relation == c.strictSubtypeRelation) && !Checker.isObjectLiteralType(source)
			&& !c.isEmptyArrayLiteralType(source) && !Checker.isTupleType(source);
		final unmatchedProperty = c.getUnmatchedProperty(source, target, requireOptionalProperties, false /*matchDiscriminantProperties*/);
		if (unmatchedProperty != null) {
			if (reportErrors && c.shouldReportUnmatchedPropertyError(source, target)) {
				reportUnmatchedProperty(source, target, unmatchedProperty, requireOptionalProperties);
			}
			return TernaryFalse;
		}
		if (Checker.isObjectLiteralType(target)) {
			final sourceProps = Checker.excludeProperties(c.getPropertiesOfType(source), excludedProperties);
			if (sourceProps != null) {
				for (sourceProp in sourceProps) {
					if (c.getPropertyOfObjectType(target, sourceProp.Name) == null) {
						if (reportErrors) {
							reportError(Diagnostics.Property_0_does_not_exist_on_type_1, c.symbolToString(sourceProp), c.TypeToString(target));
						}
						return TernaryFalse;
					}
				}
			}
		}
		// We only call this for union target types when we're attempting to do excess property checking - in those cases, we want to get _all possible props_
		// from the target union, across all members
		final properties = c.getPropertiesOfType(target);
		final numericNamesOnly = Checker.isTupleType(source) && Checker.isTupleType(target);
		final targetProps = Checker.excludeProperties(properties, excludedProperties);
		if (targetProps != null) {
			for (targetProp in targetProps) {
				final name = targetProp.Name;
				if (targetProp.Flags & SymbolFlagsPrototype == 0 && (!numericNamesOnly || Checker.isNumericLiteralName(name) || name == "length")
					&& (!optionalsOnly || targetProp.Flags & SymbolFlagsOptional != 0)) {
					final sourceProp = c.getPropertyOfType(source, name);
					if (sourceProp != null && sourceProp != targetProp) {
						final related = propertyRelatedTo(source, target, sourceProp, targetProp, s -> c.getNonMissingTypeOfSymbol(s), reportErrors, intersectionState,
							relation == c.comparableRelation);
						if (related == TernaryFalse) {
							return TernaryFalse;
						}
						result &= related;
					}
				}
			}
		}
		return result;
	}

	function propertyRelatedTo(source:Type, target:Type, sourceProp:Symbol, targetProp:Symbol, getTypeOfSourceProperty:(sym:Symbol) -> Type, reportErrors:Bool, intersectionState:IntersectionState, skipOptional:Bool):Ternary {
		final sourcePropFlags = Checker.getDeclarationModifierFlagsFromSymbol(sourceProp);
		final targetPropFlags = Checker.getDeclarationModifierFlagsFromSymbol(targetProp);
		if (sourcePropFlags & ModifierFlagsPrivate != 0 || targetPropFlags & ModifierFlagsPrivate != 0) {
			if (sourceProp.ValueDeclaration != targetProp.ValueDeclaration) {
				if (reportErrors) {
					if (sourcePropFlags & ModifierFlagsPrivate != 0 && targetPropFlags & ModifierFlagsPrivate != 0) {
						reportError(Diagnostics.Types_have_separate_declarations_of_a_private_property_0, c.symbolToString(targetProp));
					} else {
						reportError(Diagnostics.Property_0_is_private_in_type_1_but_not_in_type_2, c.symbolToString(targetProp),
							c.TypeToString(sourcePropFlags & ModifierFlagsPrivate != 0 ? source : target),
							c.TypeToString(sourcePropFlags & ModifierFlagsPrivate != 0 ? target : source));
					}
				}
				return TernaryFalse;
			}
		} else if (targetPropFlags & ModifierFlagsProtected != 0) {
			if (!c.isValidOverrideOf(sourceProp, targetProp)) {
				if (reportErrors) {
					final sourceType = Core.OrElse(c.getDeclaringClass(sourceProp), source);
					final targetType = Core.OrElse(c.getDeclaringClass(targetProp), target);
					reportError(Diagnostics.Property_0_is_protected_but_type_1_is_not_a_class_derived_from_2, c.symbolToString(targetProp), c.TypeToString(sourceType),
						c.TypeToString(targetType));
				}
				return TernaryFalse;
			}
		} else if (sourcePropFlags & ModifierFlagsProtected != 0) {
			if (reportErrors) {
				reportError(Diagnostics.Property_0_is_protected_in_type_1_but_public_in_type_2, c.symbolToString(targetProp), c.TypeToString(source), c.TypeToString(target));
			}
			return TernaryFalse;
		}
		// Ensure {readonly a: whatever} is not a subtype of {a: whatever},
		// while {a: whatever} is a subtype of {readonly a: whatever}.
		// This ensures the subtype relationship is ordered, and preventing declaration order
		// from deciding which type "wins" in union subtype reduction.
		// They're still assignable to one another, since `readonly` doesn't affect assignability.
		// This is only applied during the strictSubtypeRelation -- currently used in subtype reduction
		if (relation == c.strictSubtypeRelation && c.isReadonlySymbol(sourceProp) && !c.isReadonlySymbol(targetProp)) {
			return TernaryFalse;
		}
		// If the target comes from a partial union prop, allow `undefined` in the target type
		final related = isPropertySymbolTypeRelated(sourceProp, targetProp, getTypeOfSourceProperty, reportErrors, intersectionState);
		if (related == TernaryFalse) {
			if (reportErrors) {
				reportError(Diagnostics.Types_of_property_0_are_incompatible, c.symbolToString(targetProp));
			}
			return TernaryFalse;
		}
		// When checking for comparability, be more lenient with optional properties.
		if (!skipOptional && sourceProp.Flags & SymbolFlagsOptional != 0 && targetProp.Flags & SymbolFlagsClassMember != 0 && targetProp.Flags & SymbolFlagsOptional == 0) {
			// TypeScript 1.0 spec (April 2014): 3.8.3
			// S is a subtype of a type T, and T is a supertype of S if ...
			// S' and T are object types and, for each member M in T..
			// M is a property and S' contains a property N where
			// if M is a required property, N is also a required property
			// (M - property in T)
			// (N - property in S)
			if (reportErrors) {
				reportError(Diagnostics.Property_0_is_optional_in_type_1_but_required_in_type_2, c.symbolToString(targetProp), c.TypeToString(source), c.TypeToString(target));
			}
			return TernaryFalse;
		}
		return related;
	}

	function isPropertySymbolTypeRelated(sourceProp:Symbol, targetProp:Symbol, getTypeOfSourceProperty:(sym:Symbol) -> Type, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		final targetIsOptional = c.strictNullChecks && targetProp.CheckFlags & CheckFlagsPartial != 0;
		final effectiveTarget = c.addOptionalityEx(c.getNonMissingTypeOfSymbol(targetProp), false /*isProperty*/, targetIsOptional);
		// source could resolve to `any` and that's not related to `unknown` target under strict subtype relation
		if (effectiveTarget.flags & (relation == c.strictSubtypeRelation ? TypeFlagsAny : TypeFlagsAnyOrUnknown) != 0) {
			return TernaryTrue;
		}
		final effectiveSource = getTypeOfSourceProperty(sourceProp);
		return isRelatedToEx(effectiveSource, effectiveTarget, RecursionFlagsBoth, reportErrors, null /*headMessage*/, intersectionState);
	}

	function reportUnmatchedProperty(source:Type, target:Type, unmatchedProperty:Symbol, requireOptionalProperties:Bool):Void {
		// give specific error in case where private names have the same description
		if (unmatchedProperty.ValueDeclaration != null && unmatchedProperty.ValueDeclaration.Name() != null
			&& Ast.IsPrivateIdentifier(unmatchedProperty.ValueDeclaration.Name()) && source.symbol != null && source.symbol.Flags & SymbolFlagsClass != 0) {
			final privateIdentifierDescription = unmatchedProperty.ValueDeclaration.Name().Text();
			final symbolTableKey = Binder.GetSymbolNameForPrivateIdentifier(source.symbol, privateIdentifierDescription);
			if (c.getPropertyOfType(source, symbolTableKey) != null) {
				reportError(Diagnostics.Property_0_in_type_1_refers_to_a_different_member_that_cannot_be_accessed_from_within_type_2, privateIdentifierDescription,
					c.SymbolToString(source.symbol), c.SymbolToString(target.symbol));
				return;
			}
		}
		final props = c.getUnmatchedProperties(source, target, requireOptionalProperties, false /*matchDiscriminantProperties*/);
		if (Core.len(props) == 1) {
			final names = c.getTypeNamesForErrorDisplay(source, target);
			final propName = c.symbolToString(unmatchedProperty);
			reportError(Diagnostics.Property_0_is_missing_in_type_1_but_required_in_type_2, propName, names.a, names.b);
			if (Core.len(unmatchedProperty.Declarations) != 0) {
				// PORT: append — copy so a saved errorState never sees the new element
				relatedInfo = appendDiagnostic(relatedInfo, Checker.createDiagnosticForNode(unmatchedProperty.Declarations[0], Diagnostics.X_0_is_declared_here, propName));
			}
		} else if (tryElaborateArrayLikeErrors(source, target, false /*reportErrors*/)) {
			final names = c.getTypeNamesForErrorDisplay(source, target);
			if (Core.len(props) > 5) {
				final propNames = Core.Map(props.slice(0, 4), p -> c.symbolToString(p)).join(", ");
				reportError(Diagnostics.Type_0_is_missing_the_following_properties_from_type_1_Colon_2_and_3_more, names.a, names.b, propNames, props.length - 4);
			} else {
				final propNames = Core.len(props) == 0 ? "" : Core.Map(props, p -> c.symbolToString(p)).join(", ");
				reportError(Diagnostics.Type_0_is_missing_the_following_properties_from_type_1_Colon_2, names.a, names.b, propNames);
			}
		}
	}

	function tryElaborateArrayLikeErrors(source:Type, target:Type, reportErrors:Bool):Bool {
		/**
		 * The spec for elaboration is:
		 * - If the source is a readonly tuple and the target is a mutable array or tuple, elaborate on mutability and skip property elaborations.
		 * - If the source is a tuple then skip property elaborations if the target is an array or tuple.
		 * - If the source is a readonly array and the target is a mutable array or tuple, elaborate on mutability and skip property elaborations.
		 * - If the source an array then skip property elaborations if the target is a tuple.
		 */
		if (Checker.isTupleType(source)) {
			if (source.TargetTupleType().readonly && c.isMutableArrayOrTuple(target)) {
				if (reportErrors) {
					reportError(Diagnostics.The_type_0_is_readonly_and_cannot_be_assigned_to_the_mutable_type_1, c.TypeToString(source), c.TypeToString(target));
				}
				return false;
			}
			return c.isArrayOrTupleType(target);
		}
		if (c.isReadonlyArrayType(source) && c.isMutableArrayOrTuple(target)) {
			if (reportErrors) {
				reportError(Diagnostics.The_type_0_is_readonly_and_cannot_be_assigned_to_the_mutable_type_1, c.TypeToString(source), c.TypeToString(target));
			}
			return false;
		}
		if (Checker.isTupleType(target)) {
			return c.isArrayType(source);
		}
		return true;
	}

	function tryElaborateErrorsForPrimitivesAndObjects(source:Type, target:Type):Void {
		if ((source == c.globalStringType && target == c.stringType) || (source == c.globalNumberType && target == c.numberType)
			|| (source == c.globalBooleanType && target == c.booleanType) || (source == c.getGlobalESSymbolType() && target == c.esSymbolType)) {
			reportError(Diagnostics.X_0_is_a_primitive_but_1_is_a_wrapper_object_Prefer_using_0_when_possible, c.TypeToString(target), c.TypeToString(source));
		}
	}

	function propertiesIdenticalTo(source:Type, target:Type, excludedProperties:Set<std.String>):Ternary {
		if (source.flags & TypeFlagsObject == 0 || target.flags & TypeFlagsObject == 0) {
			return TernaryFalse;
		}
		final sourceProperties = Checker.excludeProperties(c.getPropertiesOfObjectType(source), excludedProperties);
		final targetProperties = Checker.excludeProperties(c.getPropertiesOfObjectType(target), excludedProperties);
		if (Core.len(sourceProperties) != Core.len(targetProperties)) {
			return TernaryFalse;
		}
		var result:Ternary = TernaryTrue;
		if (sourceProperties != null) {
			for (sourceProp in sourceProperties) {
				final targetProp = c.getPropertyOfObjectType(target, sourceProp.Name);
				if (targetProp == null) {
					return TernaryFalse;
				}
				final related = c.compareProperties(sourceProp, targetProp, isRelatedToSimple);
				if (related == TernaryFalse) {
					return TernaryFalse;
				}
				result &= related;
			}
		}
		return result;
	}

	function signaturesRelatedTo(source:Type, target:Type, kind:SignatureKind, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		if (relation == c.identityRelation) {
			return signaturesIdenticalTo(source, target, kind);
		}
		// With respect to signatures, the anyFunctionType wildcard is a subtype of every other function type.
		if (source == c.anyFunctionType) {
			return TernaryTrue;
		}
		if (target == c.anyFunctionType) {
			return TernaryFalse;
		}
		final sourceSignatures = c.getSignaturesOfType(source, kind);
		final targetSignatures = c.getSignaturesOfType(target, kind);
		if (kind == SignatureKindConstruct && Core.len(sourceSignatures) != 0 && Core.len(targetSignatures) != 0) {
			final sourceIsAbstract = sourceSignatures[0].flags & SignatureFlagsAbstract != 0;
			final targetIsAbstract = targetSignatures[0].flags & SignatureFlagsAbstract != 0;
			if (sourceIsAbstract && !targetIsAbstract) {
				// An abstract constructor type is not assignable to a non-abstract constructor type
				// as it would otherwise be possible to new an abstract class. Note that the assignability
				// check we perform for an extends clause excludes construct signatures from the target,
				// so this check never proceeds.
				if (reportErrors) {
					reportError(Diagnostics.Cannot_assign_an_abstract_constructor_type_to_a_non_abstract_constructor_type);
				}
				return TernaryFalse;
			}
			if (!constructorVisibilitiesAreCompatible(sourceSignatures[0], targetSignatures[0], reportErrors)) {
				return TernaryFalse;
			}
		}
		var result:Ternary = TernaryTrue;
		if (source.objectFlags & ObjectFlagsInstantiated != 0 && target.objectFlags & ObjectFlagsInstantiated != 0 && source.symbol == target.symbol
			|| source.objectFlags & ObjectFlagsReference != 0 && target.objectFlags & ObjectFlagsReference != 0 && source.Target() == target.Target()) {
			// We have instantiations of the same anonymous type (which typically will be the type of a
			// method). Simply do a pairwise comparison of the signatures in the two signature lists instead
			// of the much more expensive N * M comparison matrix we explore below. We erase type parameters
			// as they are known to always be the same.
			for (i in 0...Core.len(targetSignatures)) {
				final related = signatureRelatedTo(sourceSignatures[i], targetSignatures[i], true /*erase*/, reportErrors, intersectionState);
				if (related == TernaryFalse) {
					return TernaryFalse;
				}
				result &= related;
			}
		} else if (Core.len(sourceSignatures) == 1 && Core.len(targetSignatures) == 1) {
			// For simple functions (functions with a single signature) we only erase type parameters for
			// the comparable relation. Otherwise, if the source signature is generic, we instantiate it
			// in the context of the target signature before checking the relationship. Ideally we'd do
			// this regardless of the number of signatures, but the potential costs are prohibitive due
			// to the quadratic nature of the logic below.
			final eraseGenerics = relation == c.comparableRelation;
			result = signatureRelatedTo(sourceSignatures[0], targetSignatures[0], eraseGenerics, reportErrors, intersectionState);
		} else if (targetSignatures != null) {
			for (t in targetSignatures) {
				final saveErrorState = getErrorState();
				// Only elaborate errors from the first failure
				var shouldElaborateErrors = reportErrors;
				var matched = false; // PORT: label — `continue outer`
				if (sourceSignatures != null) {
					for (s in sourceSignatures) {
						final related = signatureRelatedTo(s, t, true /*erase*/, shouldElaborateErrors, intersectionState);
						if (related != TernaryFalse) {
							result &= related;
							restoreErrorState(saveErrorState);
							matched = true;
							break;
						}
						shouldElaborateErrors = false;
					}
				}
				if (matched) {
					continue;
				}
				if (shouldElaborateErrors) {
					reportError(Diagnostics.Type_0_provides_no_match_for_the_signature_1, c.TypeToString(source), c.signatureToString(t));
				}
				return TernaryFalse;
			}
		}
		return result;
	}

	function constructorVisibilitiesAreCompatible(sourceSignature:Signature, targetSignature:Signature, reportErrors:Bool):Bool {
		if (sourceSignature.declaration == null || targetSignature.declaration == null) {
			return true;
		}
		final sourceAccessibility = sourceSignature.declaration.ModifierFlags() & ModifierFlagsNonPublicAccessibilityModifier;
		final targetAccessibility = targetSignature.declaration.ModifierFlags() & ModifierFlagsNonPublicAccessibilityModifier;
		// A public, protected and private signature is assignable to a private signature.
		if (targetAccessibility == ModifierFlagsPrivate) {
			return true;
		}
		// A public and protected signature is assignable to a protected signature.
		if (targetAccessibility == ModifierFlagsProtected && sourceAccessibility != ModifierFlagsPrivate) {
			return true;
		}
		// Only a public signature is assignable to public signature.
		if (targetAccessibility != ModifierFlagsProtected && sourceAccessibility == 0) {
			return true;
		}
		if (reportErrors) {
			reportError(Diagnostics.Cannot_assign_a_0_constructor_type_to_a_1_constructor_type, Checker.visibilityToString(sourceAccessibility),
				Checker.visibilityToString(targetAccessibility));
		}
		return false;
	}

	// See signatureAssignableTo, compareSignaturesIdentical
	function signatureRelatedTo(source:Signature, target:Signature, erase:Bool, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		var checkMode = SignatureCheckModeNone;
		if (relation == c.subtypeRelation) {
			checkMode = SignatureCheckModeStrictTopSignature;
		} else if (relation == c.strictSubtypeRelation) {
			checkMode = SignatureCheckModeStrictTopSignature | SignatureCheckModeStrictArity;
		}
		if (erase) {
			source = c.getErasedSignature(source);
			target = c.getErasedSignature(target);
		}
		final isRelatedToWorker = (source:Type, target:Type, reportErrors:Bool) -> {
			return isRelatedToEx(source, target, RecursionFlagsBoth, reportErrors, null /*headMessage*/, intersectionState);
		};
		// PORT: explicit spreading closure for the rest-args method value (CHECKER_LANES rule)
		return c.compareSignaturesRelated(source, target, checkMode, reportErrors, (message:Message, ...args:Any) -> reportError(message, ...args), isRelatedToWorker,
			c.reportUnreliableMapper);
	}

	function signaturesIdenticalTo(source:Type, target:Type, kind:SignatureKind):Ternary {
		final sourceSignatures = c.getSignaturesOfType(source, kind);
		final targetSignatures = c.getSignaturesOfType(target, kind);
		if (Core.len(sourceSignatures) != Core.len(targetSignatures)) {
			return TernaryFalse;
		}
		var result:Ternary = TernaryTrue;
		for (i in 0...Core.len(sourceSignatures)) {
			final related = c.compareSignaturesIdentical(sourceSignatures[i], targetSignatures[i], false /*partialMatch*/, false /*ignoreThisTypes*/,
				false /*ignoreReturnTypes*/, isRelatedToSimple);
			if (related == 0) {
				return TernaryFalse;
			}
			result &= related;
		}
		return result;
	}

	function indexSignaturesRelatedTo(source:Type, target:Type, sourceIsPrimitive:Bool, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		if (relation == c.identityRelation) {
			return indexSignaturesIdenticalTo(source, target);
		}
		final indexInfos = c.getIndexInfosOfType(target);
		final targetHasStringIndex = Core.Some(indexInfos, info -> info.keyType == c.stringType);
		var result:Ternary = TernaryTrue;
		if (indexInfos != null) {
			for (targetInfo in indexInfos) {
				var related:Ternary;
				if (relation != c.strictSubtypeRelation && !sourceIsPrimitive && targetHasStringIndex && targetInfo.valueType.flags & TypeFlagsAny != 0) {
					related = TernaryTrue;
				} else if (c.isGenericMappedType(source) && targetHasStringIndex) {
					related = isRelatedTo(c.getTemplateTypeFromMappedType(source), targetInfo.valueType, RecursionFlagsBoth, reportErrors);
				} else {
					related = typeRelatedToIndexInfo(source, targetInfo, reportErrors, intersectionState);
				}
				if (related == TernaryFalse) {
					return TernaryFalse;
				}
				result &= related;
			}
		}
		return result;
	}

	function typeRelatedToIndexInfo(source:Type, targetInfo:IndexInfo, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		final sourceInfo = c.getApplicableIndexInfo(source, targetInfo.keyType);
		if (sourceInfo != null) {
			return indexInfoRelatedTo(sourceInfo, targetInfo, reportErrors, intersectionState);
		}
		// Intersection constituents are never considered to have an inferred index signature. Also, in the strict subtype relation,
		// only fresh object literals are considered to have inferred index signatures. This ensures { [x: string]: xxx } <: {} but
		// not vice-versa. Without this rule, those types would be mutual strict subtypes.
		if (intersectionState & IntersectionStateSource == 0 && (relation != c.strictSubtypeRelation || source.objectFlags & ObjectFlagsFreshLiteral != 0)
			&& c.isObjectTypeWithInferableIndex(source)) {
			return membersRelatedToIndexInfo(source, targetInfo, reportErrors, intersectionState);
		}
		if (reportErrors) {
			reportError(Diagnostics.Index_signature_for_type_0_is_missing_in_type_1, c.TypeToString(targetInfo.keyType), c.TypeToString(source));
		}
		return TernaryFalse;
	}

	// Return true if the type was inferred from
	//   - an object literal, object type literal, enum type, or a value module and has no call or construct signatures, or
	//   - a JS expando object literal or a rest type, or
	//   - a reverse mapped type with a source for which one of the above is true.
	static function isObjectTypeWithInferableIndex(c:Checker, t:Type):Bool {
		if (t.flags & TypeFlagsIntersection != 0) {
			return Core.Every(t.Types(), t -> c.isObjectTypeWithInferableIndex(t));
		}
		return t.symbol != null && t.symbol.Flags & (SymbolFlagsObjectLiteral | SymbolFlagsTypeLiteral | SymbolFlagsEnum | SymbolFlagsValueModule) != 0
			&& t.symbol.Flags & SymbolFlagsClass == 0 && !c.typeHasCallOrConstructSignatures(t)
			|| t.objectFlags & (ObjectFlagsJSLiteral | ObjectFlagsObjectRestType) != 0
			|| t.objectFlags & ObjectFlagsReverseMapped != 0 && c.isObjectTypeWithInferableIndex(t.AsReverseMappedType().source);
	}

	function membersRelatedToIndexInfo(source:Type, targetInfo:IndexInfo, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		var result:Ternary = TernaryTrue;
		final keyType = targetInfo.keyType;
		var props:Array<Symbol>;
		if (source.flags & TypeFlagsIntersection != 0) {
			props = c.getPropertiesOfUnionOrIntersectionType(source);
		} else {
			props = c.getPropertiesOfObjectType(source);
		}
		if (props != null) {
			for (prop in props) {
				// Skip over ignored JSX and symbol-named members
				if (Checker.isIgnoredJsxProperty(source, prop)) {
					continue;
				}
				if (c.isApplicableIndexType(c.getLiteralTypeFromProperty(prop, TypeFlagsStringOrNumberLiteralOrUnique, false), keyType)) {
					final propType = c.getNonMissingTypeOfSymbol(prop);
					var t:Type;
					if (c.exactOptionalPropertyTypes || propType.flags & TypeFlagsUndefined != 0 || keyType == c.numberType || prop.Flags & SymbolFlagsOptional == 0) {
						t = propType;
					} else {
						t = c.getTypeWithFacts(propType, TypeFactsNEUndefined);
					}
					final related = isRelatedToEx(t, targetInfo.valueType, RecursionFlagsBoth, reportErrors, null /*headMessage*/, intersectionState);
					if (related == TernaryFalse) {
						if (reportErrors) {
							reportError(Diagnostics.Property_0_is_incompatible_with_index_signature, c.symbolToString(prop));
						}
						return TernaryFalse;
					}
					result &= related;
				}
			}
		}
		final infos = c.getIndexInfosOfType(source);
		if (infos != null) {
			for (info in infos) {
				if (c.isApplicableIndexType(info.keyType, keyType)) {
					final related = indexInfoRelatedTo(info, targetInfo, reportErrors, intersectionState);
					if (!(related != 0)) {
						return TernaryFalse;
					}
					result &= related;
				}
			}
		}
		return result;
	}

	function indexInfoRelatedTo(sourceInfo:IndexInfo, targetInfo:IndexInfo, reportErrors:Bool, intersectionState:IntersectionState):Ternary {
		final related = isRelatedToEx(sourceInfo.valueType, targetInfo.valueType, RecursionFlagsBoth, reportErrors, null /*headMessage*/, intersectionState);
		if (related == TernaryFalse && reportErrors) {
			if (sourceInfo.keyType == targetInfo.keyType) {
				reportError(Diagnostics.X_0_index_signatures_are_incompatible, c.TypeToString(sourceInfo.keyType));
			} else {
				reportError(Diagnostics.X_0_and_1_index_signatures_are_incompatible, c.TypeToString(sourceInfo.keyType), c.TypeToString(targetInfo.keyType));
			}
		}
		return related;
	}

	function indexSignaturesIdenticalTo(source:Type, target:Type):Ternary {
		final sourceInfos = c.getIndexInfosOfType(source);
		final targetInfos = c.getIndexInfosOfType(target);
		if (Core.len(sourceInfos) != Core.len(targetInfos)) {
			return TernaryFalse;
		}
		if (targetInfos != null) {
			for (targetInfo in targetInfos) {
				final sourceInfo = c.getIndexInfoOfType(source, targetInfo.keyType);
				if (!(sourceInfo != null && isRelatedTo(sourceInfo.valueType, targetInfo.valueType, RecursionFlagsBoth, false) != TernaryFalse
					&& sourceInfo.isReadonly == targetInfo.isReadonly)) {
					return TernaryFalse;
				}
			}
		}
		return TernaryTrue;
	}

	function reportErrorResults(originalSource:Type, originalTarget:Type, source:Type, target:Type, headMessage:Message):Void {
		final sourceHasBase = c.getSingleBaseForNonAugmentingSubtype(originalSource) != null;
		final targetHasBase = c.getSingleBaseForNonAugmentingSubtype(originalTarget) != null;
		if (originalSource.alias != null || sourceHasBase) {
			source = originalSource;
		}
		if (originalTarget.alias != null || targetHasBase) {
			target = originalTarget;
		}
		if (source.flags & TypeFlagsObject != 0 && target.flags & TypeFlagsObject != 0) {
			tryElaborateArrayLikeErrors(source, target, true /*reportErrors*/);
		}
		if (source.flags & TypeFlagsObject != 0 && target.flags & TypeFlagsPrimitive != 0) {
			tryElaborateErrorsForPrimitivesAndObjects(source, target);
		} else if (source.symbol != null && source.flags & TypeFlagsObject != 0 && c.globalObjectType == source) {
			reportError(Diagnostics.The_Object_type_is_assignable_to_very_few_other_types_Did_you_mean_to_use_the_any_type_instead);
		} else if (source.objectFlags & ObjectFlagsJsxAttributes != 0 && target.flags & TypeFlagsIntersection != 0) {
			final targetTypes = target.Types();
			final intrinsicAttributes = c.getJsxType(Checker.JsxNames.IntrinsicAttributes, errorNode);
			final intrinsicClassAttributes = c.getJsxType(Checker.JsxNames.IntrinsicClassAttributes, errorNode);
			if (!c.isErrorType(intrinsicAttributes) && !c.isErrorType(intrinsicClassAttributes)
				&& (Slices.Contains(targetTypes, intrinsicAttributes) || Slices.Contains(targetTypes, intrinsicClassAttributes))) {
				return;
			}
		} else if (originalTarget.flags & TypeFlagsIntersection != 0 && originalTarget.objectFlags & ObjectFlagsIsNeverIntersection != 0) {
			var message = Diagnostics.The_intersection_0_was_reduced_to_never_because_property_1_has_conflicting_types_in_some_constituents;
			var prop = Core.Find(c.getPropertiesOfUnionOrIntersectionType(originalTarget), p -> c.isDiscriminantWithNeverType(p));
			if (prop == null) {
				message = Diagnostics.The_intersection_0_was_reduced_to_never_because_property_1_exists_in_multiple_constituents_and_is_private_in_some;
				prop = Core.Find(c.getPropertiesOfUnionOrIntersectionType(originalTarget), Checker.isConflictingPrivateProperty);
			}
			if (prop != null) {
				reportError(message, c.typeToStringEx(originalTarget, null /*enclosingDeclaration*/, TypeFormatFlagsNoTypeReduction, null), c.symbolToString(prop));
			}
		}
		reportRelationError(headMessage, source, target);
		if (source.flags & TypeFlagsTypeParameter != 0 && source.symbol != null && Core.len(source.symbol.Declarations) != 0 && c.getConstraintOfType(source) == null) {
			final syntheticParam = c.cloneTypeParameter(source);
			syntheticParam.AsTypeParameter().constraint = c.instantiateType(target, Checker.newSimpleTypeMapper(source, syntheticParam));
			if (c.hasNonCircularBaseConstraint(syntheticParam)) {
				final targetConstraintString = c.TypeToString(target);
				// PORT: append — copy so a saved errorState never sees the new element
				relatedInfo = appendDiagnostic(relatedInfo,
					Checker.NewDiagnosticForNode(source.symbol.Declarations[0], Diagnostics.This_type_parameter_might_need_an_extends_0_constraint, targetConstraintString));
			}
		}
	}

	function reportRelationError(message:Message, source:Type, target:Type):Void {
		final names = c.getTypeNamesForErrorDisplay(source, target);
		final sourceType = names.a;
		final targetType = names.b;
		var generalizedSource = source;
		var generalizedSourceType = sourceType;
		// Don't generalize on 'never' - we really want the original type
		// to be displayed for use-cases like 'assertNever'.
		if (target.flags & TypeFlagsNever == 0 && Checker.isLiteralType(source) && !c.typeCouldHaveTopLevelSingletonTypes(target)) {
			generalizedSource = c.getBaseTypeOfLiteralType(source);
			generalizedSourceType = c.getTypeNameForErrorDisplay(generalizedSource);
		}
		// If `target` is of indexed access type (and `source` it is not), we use the object type of `target` for better error reporting
		var targetFlags:TypeFlags;
		if (target.flags & TypeFlagsIndexedAccess != 0 && source.flags & TypeFlagsIndexedAccess == 0) {
			targetFlags = target.AsIndexedAccessType().objectType.flags;
		} else {
			targetFlags = target.flags;
		}
		if (targetFlags & TypeFlagsTypeParameter != 0 && target != c.markerSuperTypeForCheck && target != c.markerSubTypeForCheck) {
			final constraint = c.getBaseConstraintOfType(target);
			if (constraint != null && c.isTypeAssignableTo(generalizedSource, constraint)) {
				reportError(Diagnostics.X_0_is_assignable_to_the_constraint_of_type_1_but_1_could_be_instantiated_with_a_different_subtype_of_constraint_2,
					generalizedSourceType, targetType, c.TypeToString(constraint));
			} else if (constraint != null && c.isTypeAssignableTo(source, constraint)) {
				reportError(Diagnostics.X_0_is_assignable_to_the_constraint_of_type_1_but_1_could_be_instantiated_with_a_different_subtype_of_constraint_2, sourceType,
					targetType, c.TypeToString(constraint));
			} else {
				errorChain = null; // Only report this error once
				reportError(Diagnostics.X_0_could_be_instantiated_with_an_arbitrary_type_which_could_be_unrelated_to_1, targetType, generalizedSourceType);
			}
		}
		if (message == null) {
			if (relation == c.comparableRelation) {
				message = Diagnostics.Type_0_is_not_comparable_to_type_1;
			} else if (sourceType == targetType) {
				message = Diagnostics.Type_0_is_not_assignable_to_type_1_Two_different_types_with_this_name_exist_but_they_are_unrelated;
			} else if (c.exactOptionalPropertyTypes && Core.len(c.getExactOptionalUnassignableProperties(source, target)) != 0) {
				message = Diagnostics.Type_0_is_not_assignable_to_type_1_with_exactOptionalPropertyTypes_Colon_true_Consider_adding_undefined_to_the_types_of_the_target_s_properties;
			} else {
				if (source.flags & TypeFlagsStringLiteral != 0 && target.flags & TypeFlagsUnion != 0) {
					final suggestedType = c.getSuggestedTypeForNonexistentStringLiteralType(source, target);
					if (suggestedType != null) {
						reportError(Diagnostics.Type_0_is_not_assignable_to_type_1_Did_you_mean_2, generalizedSourceType, targetType, c.TypeToString(suggestedType));
						return;
					}
				}
				message = Diagnostics.Type_0_is_not_assignable_to_type_1;
			}
		} else if (message == Diagnostics.Argument_of_type_0_is_not_assignable_to_parameter_of_type_1 && c.exactOptionalPropertyTypes
			&& Core.len(c.getExactOptionalUnassignableProperties(source, target)) > 0) {
			message = Diagnostics.Argument_of_type_0_is_not_assignable_to_parameter_of_type_1_with_exactOptionalPropertyTypes_Colon_true_Consider_adding_undefined_to_the_types_of_the_target_s_properties;
		}
		// PORT: switch on *Message values → if/else on identity
		final chainMessage = getChainMessage(0);
		if (chainMessage == Diagnostics.Object_literal_may_only_specify_known_properties_and_0_does_not_exist_in_type_1
			|| chainMessage == Diagnostics.Object_literal_may_only_specify_known_properties_but_0_does_not_exist_in_type_1_Did_you_mean_to_write_2) {
			// Suppress if next message is an excess property error
			return;
		} else if (chainMessage == Diagnostics.Excessive_complexity_comparing_types_0_and_1 || chainMessage == Diagnostics.Excessive_stack_depth_comparing_types_0_and_1
			|| chainMessage == Diagnostics.The_type_0_is_readonly_and_cannot_be_assigned_to_the_mutable_type_1) {
			// Suppress if next message is an excessive complexity/stack depth message for source and target or a readonly
			// vs. mutable error for source and target
			if (chainArgsMatch(generalizedSourceType, targetType)) {
				return;
			}
		} else if (chainMessage == Diagnostics.Property_0_is_missing_in_type_1_but_required_in_type_2) {
			// Suppress if next message is a missing property message for source and target and we're not
			// reporting on conversion or interface implementation
			if (!Checker.isConversionOrInterfaceImplementationMessage(message) && chainArgsMatch(null, generalizedSourceType, targetType)) {
				return;
			}
		} else if (chainMessage == Diagnostics.Type_0_is_missing_the_following_properties_from_type_1_Colon_2_and_3_more
			|| chainMessage == Diagnostics.Type_0_is_missing_the_following_properties_from_type_1_Colon_2) {
			// Suppress if next message is a missing property message for source and target and we're not
			// reporting on conversion or interface implementation
			if (!Checker.isConversionOrInterfaceImplementationMessage(message) && chainArgsMatch(generalizedSourceType, targetType)) {
				return;
			}
		}
		reportError(message, generalizedSourceType, targetType);
	}

	function reportError(message:Message, ...args:Any):Void {
		final argList:Array<Any> = args.toArray(); // PORT: Go mutates args[0] below; a Haxe Rest is read-only
		if (message == Diagnostics.Types_of_property_0_are_incompatible) {
			// Suppress if next message is an excess property error
			final chainMessage0 = getChainMessage(0);
			if (chainMessage0 == Diagnostics.Object_literal_may_only_specify_known_properties_and_0_does_not_exist_in_type_1
				|| chainMessage0 == Diagnostics.Object_literal_may_only_specify_known_properties_but_0_does_not_exist_in_type_1_Did_you_mean_to_write_2) {
				return;
			}
			// Transform a property incompatibility message for property 'x' followed by some elaboration message
			// followed by a signature return type incompatibility message into a single return type incompatibility
			// message for 'x()' or 'x(...)'
			var arg = "";
			final chainMessage1 = getChainMessage(1);
			if (chainMessage1 == Diagnostics.Call_signatures_with_no_arguments_have_incompatible_return_types_0_and_1) {
				arg = Checker.getPropertyNameArg(argList[0]) + "()";
			} else if (chainMessage1 == Diagnostics.Construct_signatures_with_no_arguments_have_incompatible_return_types_0_and_1) {
				arg = "new " + Checker.getPropertyNameArg(argList[0]) + "()";
			} else if (chainMessage1 == Diagnostics.Call_signature_return_types_0_and_1_are_incompatible) {
				arg = Checker.getPropertyNameArg(argList[0]) + "(...)";
			} else if (chainMessage1 == Diagnostics.Construct_signature_return_types_0_and_1_are_incompatible) {
				arg = "new " + Checker.getPropertyNameArg(argList[0]) + "(...)";
			}
			if (arg != "") {
				message = Diagnostics.The_types_returned_by_0_are_incompatible_between_these_types;
				argList[0] = arg;
				errorChain = errorChain.next.next;
			}
			// Transform a property incompatibility message for property 'x' followed by some elaboration message
			// followed by a property incompatibility message for property 'y' into a single property incompatibility
			// message for 'x.y'
			final chainMessage1b = getChainMessage(1);
			if (chainMessage1b == Diagnostics.Types_of_property_0_are_incompatible || chainMessage1b == Diagnostics.The_types_of_0_are_incompatible_between_these_types
				|| chainMessage1b == Diagnostics.The_types_returned_by_0_are_incompatible_between_these_types) {
				final head = Checker.getPropertyNameArg(argList[0]);
				final tail = Checker.getPropertyNameArg(errorChain.next.args[0]);
				final arg = Checker.addToDottedName(head, tail);
				errorChain = errorChain.next.next;
				if (message == Diagnostics.Types_of_property_0_are_incompatible) {
					message = Diagnostics.The_types_of_0_are_incompatible_between_these_types;
				}
				reportError(message, arg);
				return;
			}
		}
		final chain = new ErrorChain();
		chain.next = errorChain;
		chain.message = message;
		chain.args = argList;
		errorChain = chain;
	}

	function getChainMessage(index:Int):Message {
		var e = errorChain;
		while (true) {
			if (e == null) {
				return null;
			}
			if (index == 0) {
				return e.message;
			}
			e = e.next;
			index--;
		}
	}

	// Return true if the arguments of the first entry on the error chain match the
	// given arguments (where nil acts as a wildcard).
	function chainArgsMatch(...args:Any):Bool {
		for (i in 0...args.length) {
			final a = args[i];
			if (a != null && !anyEquals(a, errorChain.args[i])) {
				return false;
			}
		}
		return true;
	}

	// An object type S is considered to be derived from an object type T if
	// S is a union type and every constituent of S is derived from T,
	// T is a union type and S is derived from at least one constituent of T, or
	// S is an intersection type and some constituent of S is derived from T, or
	// S is a type variable with a base constraint that is derived from T, or
	// T is {} and S is an object-like type (ensuring {} is less derived than Object), or
	// T is one of the global types Object and Function and S is a subtype of T, or
	// T occurs directly or indirectly in an 'extends' clause of S.
	// Note that this check ignores type parameters and only considers the
	// inheritance hierarchy.
	static function isTypeDerivedFrom(c:Checker, source:Type, target:Type):Bool {
		if (source.flags & TypeFlagsUnion != 0) {
			return Core.Every(source.AsUnionType().types, t -> c.isTypeDerivedFrom(t, target));
		} else if (target.flags & TypeFlagsUnion != 0) {
			return Core.Some(target.AsUnionType().types, t -> c.isTypeDerivedFrom(source, t));
		} else if (source.flags & TypeFlagsIntersection != 0) {
			return Core.Some(source.AsIntersectionType().types, t -> c.isTypeDerivedFrom(t, target));
		} else if (source.flags & TypeFlagsInstantiableNonPrimitive != 0) {
			var constraint = c.getBaseConstraintOfType(source);
			if (constraint == null) {
				constraint = c.unknownType;
			}
			return c.isTypeDerivedFrom(constraint, target);
		} else if (c.IsEmptyAnonymousObjectType(target)) {
			return source.flags & (TypeFlagsObject | TypeFlagsNonPrimitive) != 0;
		} else if (target == c.globalObjectType) {
			return source.flags & (TypeFlagsObject | TypeFlagsNonPrimitive) != 0 && !c.IsEmptyAnonymousObjectType(source);
		} else if (target == c.globalFunctionType) {
			return source.flags & TypeFlagsObject != 0 && c.isFunctionObjectType(source);
		} else {
			return c.hasBaseType(source, c.getTargetType(target))
				|| (c.isArrayType(target) && !c.isReadonlyArrayType(target) && c.isTypeDerivedFrom(source, c.globalReadonlyArrayType));
		}
	}

	static function isDistributionDependent(c:Checker, root:ConditionalRoot):Bool {
		return root.isDistributive
			&& (c.isTypeParameterPossiblyReferenced(root.checkType, root.node.TrueType) || c.isTypeParameterPossiblyReferenced(root.checkType, root.node.FalseType));
	}

	function traceUnionsOrIntersectionsTooLarge(source:Type, target:Type):Void {
		final tr = c.tracer;
		if (tr == null) {
			return;
		}
		if (source.flags & TypeFlagsUnionOrIntersection != 0 && target.flags & TypeFlagsUnionOrIntersection != 0) {
			if (source.objectFlags & target.objectFlags & ObjectFlagsPrimitiveUnion != 0) {
				// There's a fast path for comparing primitive unions
				return;
			}
			final sourceSize = source.Types().length;
			final targetSize = target.Types().length;
			if ((sourceSize : Float) * targetSize > 1000000) { // PORT: Go int is 64-bit; Float avoids Int32 overflow
				final args = new StringMap<Any>();
				args.set("sourceId", source.id);
				args.set("sourceSize", sourceSize);
				args.set("targetId", target.id);
				args.set("targetSize", targetSize);
				tr.Instant(PhaseCheckTypes, "traceUnionsOrIntersectionsTooLarge_DepthLimit", args);
			}
		}
	}
}
