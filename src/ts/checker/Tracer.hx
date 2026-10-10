package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/tracer.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

// tracedTypeAdapter adapts a Type to the tracing.TracedType interface
@:allow(ts.checker)
class TracedTypeAdapter implements TracedType {
	var t:Type = null;
	var checker:Checker = null;

	public function new() {}

	public function Id():Int {
		return t.id;
	}

	public function FormatFlags():Array<std.String> {
		return Checker.FormatTypeFlags(t.flags);
	}

	public function IsConditional():Bool {
		return (t.flags & TypeFlagsConditional) != 0;
	}

	public function Symbol():Symbol {
		return t.symbol;
	}

	public function AliasSymbol():Symbol {
		if (t.alias == null) {
			return null;
		}
		return t.alias.Symbol();
	}

	public function AliasTypeArguments():Array<TracedType> {
		if (t.alias == null) {
			return null;
		}
		return Checker.wrapTypes(t.alias.TypeArguments());
	}

	public function IntrinsicName():std.String {
		if ((t.flags & TypeFlagsIntrinsic) == 0) {
			return "";
		}
		final data = Std.downcast(t.data, IntrinsicType);
		if (data == null) {
			return "";
		}
		return data.intrinsicName;
	}

	public function UnionTypes():Array<TracedType> {
		if ((t.flags & TypeFlagsUnion) == 0) {
			return null;
		}
		return Checker.wrapTypes(t.AsUnionType().types);
	}

	public function IntersectionTypes():Array<TracedType> {
		if ((t.flags & TypeFlagsIntersection) == 0) {
			return null;
		}
		return Checker.wrapTypes(t.AsIntersectionType().types);
	}

	public function IndexType():TracedType {
		if ((t.flags & TypeFlagsIndex) == 0) {
			return null;
		}
		final t = t.AsIndexType().target;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function IndexedAccessObjectType():TracedType {
		if ((t.flags & TypeFlagsIndexedAccess) == 0) {
			return null;
		}
		final t = t.AsIndexedAccessType().objectType;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function IndexedAccessIndexType():TracedType {
		if ((t.flags & TypeFlagsIndexedAccess) == 0) {
			return null;
		}
		final t = t.AsIndexedAccessType().indexType;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function ConditionalCheckType():TracedType {
		if ((t.flags & TypeFlagsConditional) == 0) {
			return null;
		}
		final t = t.AsConditionalType().checkType;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function ConditionalExtendsType():TracedType {
		if ((t.flags & TypeFlagsConditional) == 0) {
			return null;
		}
		final t = t.AsConditionalType().extendsType;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function ConditionalTrueType():TracedType {
		if ((t.flags & TypeFlagsConditional) == 0) {
			return null;
		}
		final t = t.AsConditionalType().resolvedTrueType;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function ConditionalFalseType():TracedType {
		if ((t.flags & TypeFlagsConditional) == 0) {
			return null;
		}
		final t = t.AsConditionalType().resolvedFalseType;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function SubstitutionBaseType():TracedType {
		if ((t.flags & TypeFlagsSubstitution) == 0) {
			return null;
		}
		final t = t.AsSubstitutionType().baseType;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function SubstitutionConstraintType():TracedType {
		if ((t.flags & TypeFlagsSubstitution) == 0) {
			return null;
		}
		final t = t.AsSubstitutionType().constraint;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function ReferenceTarget():TracedType {
		if ((t.flags & TypeFlagsObject) == 0 || (t.objectFlags & ObjectFlagsReference) == 0) {
			return null;
		}
		final t = t.AsTypeReference().target;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function ReferenceTypeArguments():Array<TracedType> {
		if ((t.flags & TypeFlagsObject) == 0 || (t.objectFlags & ObjectFlagsReference) == 0) {
			return null;
		}
		return Checker.wrapTypes(t.AsTypeReference().resolvedTypeArguments);
	}

	public function ReferenceNode():Node {
		if ((t.flags & TypeFlagsObject) == 0 || (t.objectFlags & ObjectFlagsReference) == 0) {
			return null;
		}
		return t.AsTypeReference().node;
	}

	public function ReverseMappedSourceType():TracedType {
		if ((t.flags & TypeFlagsObject) == 0 || (t.objectFlags & ObjectFlagsReverseMapped) == 0) {
			return null;
		}
		final t = t.AsReverseMappedType().source;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function ReverseMappedMappedType():TracedType {
		if ((t.flags & TypeFlagsObject) == 0 || (t.objectFlags & ObjectFlagsReverseMapped) == 0) {
			return null;
		}
		final t = t.AsReverseMappedType().mappedType;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function ReverseMappedConstraintType():TracedType {
		if ((t.flags & TypeFlagsObject) == 0 || (t.objectFlags & ObjectFlagsReverseMapped) == 0) {
			return null;
		}
		final t = t.AsReverseMappedType().constraintType;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function EvolvingArrayElementType():TracedType {
		if ((t.flags & TypeFlagsObject) == 0 || (t.objectFlags & ObjectFlagsEvolvingArray) == 0) {
			return null;
		}
		final t = t.AsEvolvingArrayType().elementType;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function EvolvingArrayFinalType():TracedType {
		if ((t.flags & TypeFlagsObject) == 0 || (t.objectFlags & ObjectFlagsEvolvingArray) == 0) {
			return null;
		}
		final t = t.AsEvolvingArrayType().finalArrayType;
		if (t == null) {
			return null;
		}
		return Checker.wrapType(t);
	}

	public function IsTuple():Bool {
		return (t.objectFlags & ObjectFlagsTuple) != 0;
	}

	public function Pattern():Node {
		if (checker == null) {
			return null;
		}
		return checker.patternForType.get(t);
	}

	public function RecursionIdentity():Any {
		return Checker.getRecursionIdentity(t).value;
	}

	public function Display():std.String {
		// Compute display text for types where it's valuable for trace analysis.
		// TypeScript only does this for Anonymous|Literal types, but we extend to
		// unions, intersections, and template literals since they often lack
		// firstDeclaration and the display text helps identify them.
		// Incomplete types during tracing can cause panics, which we intentionally
		// suppress (returning ""), matching TypeScript's try/catch around typeToString.
		if (checker == null) {
			return "";
		}
		if ((t.objectFlags & ObjectFlagsAnonymous) != 0
			|| (t.flags & (TypeFlagsLiteral | TypeFlagsTemplateLiteral | TypeFlagsUnion | TypeFlagsIntersection)) != 0) {
			// PORT: defer recover → try/catch
			try {
				return checker.TypeToString(t);
			} catch (e:Dynamic) {
				return "";
			}
		}
		return "";
	}
}

// Tracer records types and trace events during type checking. A nil *Tracer
// is a valid no-op, so call sites can use `if tr := c.tracer; tr != nil` to
// gate work that only matters under --generateTrace.
@:allow(ts.checker)
class Tracer {
	var tracing:ts.tracing.Tracing = null;
	var recorder:ts.tracing.Tracing.Tracer = null;
	var checkerIndex:Int = 0;

	public function new() {}

	public function RecordType(typ:Type):Void {
		recorder.RecordType(Checker.wrapType(typ));
	}

	public function Push(phase:Phase, name:std.String, args:StringMap<Any>, separateBeginAndEnd:Bool):() -> Void {
		if (!separateBeginAndEnd) {
			return tracing.Push(phase, name, copyWithCheckerIndex(args), separateBeginAndEnd);
		}

		final r = temporarilyAddCheckerIndex(args);
		final args = r.a;
		final restore = r.b;
		final pop = tracing.Push(phase, name, args, separateBeginAndEnd);
		restore();

		return () -> {
			final restoreEndArgs = temporarilyAddCheckerIndex(args).b;
			// PORT: defer
			try {
				pop();
			} catch (e:Dynamic) {
				restoreEndArgs();
				throw e;
			}
			restoreEndArgs();
		};
	}

	public function Instant(phase:Phase, name:std.String, args:StringMap<Any>):Void {
		tracing.Instant(phase, name, copyWithCheckerIndex(args));
	}

	function copyWithCheckerIndex(args:StringMap<Any>):StringMap<Any> {
		final withCheckerIndex = new StringMap<Any>();
		if (args != null) {
			for (k => v in args) {
				withCheckerIndex.set(k, v);
			}
		}
		withCheckerIndex.set("checkerId", checkerIndex);
		return withCheckerIndex;
	}

	function temporarilyAddCheckerIndex(args:StringMap<Any>):Pair<StringMap<Any>, () -> Void> {
		if (args == null) {
			args = new StringMap<Any>();
		}

		final hadPrevious = args.exists("checkerId");
		final previous = args.get("checkerId");
		args.set("checkerId", checkerIndex);

		return new Pair(args, () -> {
			if (hadPrevious) {
				args.set("checkerId", previous);
			} else {
				args.remove("checkerId");
			}
		});
	}
}
