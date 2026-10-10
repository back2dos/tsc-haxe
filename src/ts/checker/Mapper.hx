package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/mapper.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

enum abstract TypeMapperKind(Int) from Int to Int {
	var TypeMapperKindUnknown = 0;
	var TypeMapperKindSimple = 1;
	var TypeMapperKindArray = 2;
	var TypeMapperKindMerged = 3;
}

@:allow(ts.checker)
class TypeMapper implements TypeMapperData {
	var data:TypeMapperData = null;

	public function new() {}

	public function Map(t:Type):Type {
		return data.Map(t);
	}

	public function Kind():TypeMapperKind {
		return data.Kind();
	}

	public function MapsThisOnly():Bool {
		return data.MapsThisOnly();
	}
}

interface TypeMapperData {
	function Kind():TypeMapperKind;
	function Map(t:Type):Type;
	function MapsThisOnly():Bool;
}

class TypeMapperBase extends TypeMapper {
	public function new() {
		super();
	}

	public override function Map(t:Type):Type {
		return t;
	}

	public override function Kind():TypeMapperKind {
		return TypeMapperKindUnknown;
	}

	public override function MapsThisOnly():Bool {
		return false;
	}
}

@:allow(ts.checker)
class SimpleTypeMapper extends TypeMapperBase {
	var source:Type = null;
	var target:Type = null;

	public function new() {
		super();
	}

	public override function Map(t:Type):Type {
		if (t == source) {
			return target;
		}
		return t;
	}

	public override function Kind():TypeMapperKind {
		return TypeMapperKindSimple;
	}

	public override function MapsThisOnly():Bool {
		return Checker.isThisTypeParameter(source);
	}
}

@:allow(ts.checker)
class ArrayTypeMapper extends TypeMapperBase {
	var sources:Array<Type> = null;
	var targets:Array<Type> = null;

	public function new() {
		super();
	}

	public override function Map(t:Type):Type {
		if (sources != null) {
			for (i in 0...sources.length) {
				if (t == sources[i]) {
					return targets[i];
				}
			}
		}
		return t;
	}

	public override function Kind():TypeMapperKind {
		return TypeMapperKindArray;
	}

	public override function MapsThisOnly():Bool {
		return Core.len(sources) == 1 && Checker.isThisTypeParameter(sources[0]);
	}
}

@:allow(ts.checker)
class ArrayToSingleTypeMapper extends TypeMapperBase {
	var sources:Array<Type> = null;
	var target:Type = null;

	public function new() {
		super();
	}

	public override function Map(t:Type):Type {
		if (sources != null && sources.indexOf(t) >= 0) {
			return target;
		}
		return t;
	}

	public override function MapsThisOnly():Bool {
		return Core.len(sources) == 1 && Checker.isThisTypeParameter(sources[0]);
	}
}

@:allow(ts.checker)
class DeferredTypeMapper extends TypeMapperBase {
	var sources:Array<Type> = null;
	var targets:Array<() -> Type> = null;

	public function new() {
		super();
	}

	public override function Map(t:Type):Type {
		if (sources != null) {
			for (i in 0...sources.length) {
				if (t == sources[i]) {
					return targets[i]();
				}
			}
		}
		return t;
	}

	public override function MapsThisOnly():Bool {
		return Core.len(sources) == 1 && Checker.isThisTypeParameter(sources[0]);
	}
}

@:allow(ts.checker)
class FunctionTypeMapper extends TypeMapperBase {
	var fn:(Type) -> Type = null;

	public function new() {
		super();
	}

	public override function Map(t:Type):Type {
		return fn(t);
	}
}

@:allow(ts.checker)
class MergedTypeMapper extends TypeMapperBase {
	var m1:TypeMapper = null;
	var m2:TypeMapper = null;

	public function new() {
		super();
	}

	public override function Map(t:Type):Type {
		return m2.Map(m1.Map(t));
	}

	public override function Kind():TypeMapperKind {
		return TypeMapperKindMerged;
	}
}

@:allow(ts.checker)
class CompositeTypeMapper extends TypeMapperBase {
	var c:Checker = null;
	var m1:TypeMapper = null;
	var m2:TypeMapper = null;

	public function new() {
		super();
	}

	public override function Map(t:Type):Type {
		final t1 = m1.Map(t);
		if (t1 != t) {
			return c.instantiateType(t1, m2);
		}
		return m2.Map(t);
	}
}

@:allow(ts.checker)
class InferenceTypeMapper extends TypeMapperBase {
	var c:Checker = null;
	var n:InferenceContext = null;
	var fixing:Bool = false;

	public function new() {
		super();
	}

	public override function Map(t:Type):Type {
		final inferences = n.inferences;
		if (inferences != null) {
			for (i in 0...inferences.length) {
				final inference = inferences[i];
				if (t == inference.typeParameter) {
					if (fixing && !inference.isFixed) {
						// Before we commit to a particular inference (and thus lock out any further inferences),
						// we infer from any intra-expression inference sites we have collected.
						c.inferFromIntraExpressionSites(n);
						Checker.clearCachedInferences(n.inferences);
						inference.isFixed = true;
					}
					return c.getInferredType(n, i);
				}
			}
		}
		return t;
	}
}

// Methods of mapper.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Mapper {

	static function combineTypeMappers(c:Checker, m1:TypeMapper, m2:TypeMapper):TypeMapper {
		if (m1 != null) {
			return Checker.newCompositeTypeMapper(c, m1, m2);
		}
		return m2;
	}

	// Maps forward-references to later types parameters to the empty object type.
	// This is used during inference when instantiating type parameter defaults.
	static function newBackreferenceMapper(c:Checker, context:InferenceContext, index:Int):TypeMapper {
		final forwardInferences = context.inferences.slice(index);
		final typeParameters = Core.Map(forwardInferences, (i:InferenceInfo) -> {
			return i.typeParameter;
		});
		return Checker.newArrayToSingleTypeMapper(typeParameters, c.unknownType);
	}

	static function newInferenceTypeMapper(c:Checker, n:InferenceContext, fixing:Bool):TypeMapper {
		final m = new InferenceTypeMapper();
		m.data = m;
		m.c = c;
		m.n = n;
		m.fixing = fixing;
		return m;
	}
}
