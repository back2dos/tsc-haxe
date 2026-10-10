package go;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
#end

// PORT: perf — `for` loops over maps on hxcpp. A Haxe `for (v in m)` / `for (k => v in m)` over a
// haxe.ds.StringMap, IntMap or go.IdentityMap calls the map's iterator through the structure type
// `Iterator<T>` / `KeyValueIterator<K, V>`, which hxcpp resolves by field name: two closure
// allocations per element, plus one anonymous `{key, value}` object per element for `k => v`
// (measured: ~6 % of all allocated bytes of a check). go.NilRange routes every `for` loop over a
// non-interval expression through these macros on cpp; they look at the static type of the
// collection and, for those maps, loop over plain arrays instead:
//   for (v in m)       → for (v in <values array>)          (StringMap, IntMap with object values; IdentityMap)
//   for (k => v in m)  → for (k in <keys array>) { var v = m.get(k); body }   (StringMap, IntMap)
//                        parallel snapshots of keys and values                   (IdentityMap)
// Same elements in the same order as the maps' own iterators (StringMap/IntMap: keys() order and a
// get() per key, like MapKeyValueIterator; IdentityMap: the snapshot its keyValueIterator copies).
// Every other collection keeps its `for` loop unchanged. On JS the loops are never rewritten.
class ForIn {
	public static macro function values(coll:Expr, v:Expr, body:Expr):Expr {
		final pos = Context.currentPos();
		switch mapKind(coll) {
			case MString(vt) if (!isBasic(vt)):
				return macro @:pos(pos) for ($v in go.ForIn.StringValues($coll)) $body;
			case MInt(vt) if (!isBasic(vt)):
				return macro @:pos(pos) for ($v in go.ForIn.IntValues($coll)) $body;
			case MIdentity:
				return macro @:pos(pos) for ($v in $coll.valuesArray()) $body;
			case _:
				return macro @:pos(pos) for ($v in $coll) $body;
		}
	}

	public static macro function keyValues(coll:Expr, k:Expr, v:Expr, body:Expr):Expr {
		final pos = Context.currentPos();
		final vname = switch v.expr {
			case EConst(CIdent(n)): n;
			case _: null;
		}
		if (vname == null)
			return macro @:pos(pos) for ($k => $v in $coll) $body;
		switch mapKind(coll) {
			case MString(vt):
				final ct = isBasic(vt) ? Context.toComplexType(vt) : null;
				return macro @:pos(pos) for ($k in go.ForIn.StringKeys($coll)) {
					var $vname:$ct = $coll.get($k);
					$body;
				};
			case MInt(vt):
				final ct = isBasic(vt) ? Context.toComplexType(vt) : null;
				return macro @:pos(pos) for ($k in go.ForIn.IntKeys($coll)) {
					var $vname:$ct = $coll.get($k);
					$body;
				};
			case MIdentity:
				final kname = switch k.expr {
					case EConst(CIdent(n)): n;
					case _: null;
				}
				if (kname == null)
					return macro @:pos(pos) for ($k => $v in $coll) $body;
				return macro @:pos(pos) {
					final __forInKeys = $coll.keysArray();
					final __forInValues = $coll.valuesArray();
					for (__forInIndex in 0...__forInKeys.length) {
						var $kname = __forInKeys[__forInIndex];
						var $vname = __forInValues[__forInIndex];
						$body;
					}
				};
			case _:
				return macro @:pos(pos) for ($k => $v in $coll) $body;
		}
	}

	#if cpp
	// Values / keys of a map as arrays, in the order of the map's iterator() / keys().
	public static inline function StringValues<T>(m:haxe.ds.StringMap<T>):Array<T> {
		final a:Array<Dynamic> = untyped __global__.__string_hash_values(@:privateAccess m.h);
		return cast a;
	}

	public static inline function StringKeys<T>(m:haxe.ds.StringMap<T>):Array<String> {
		return untyped __global__.__string_hash_keys(@:privateAccess m.h);
	}

	public static inline function IntValues<T>(m:haxe.ds.IntMap<T>):Array<T> {
		final a:Array<Dynamic> = untyped __global__.__int_hash_values(@:privateAccess m.h);
		return cast a;
	}

	public static inline function IntKeys<T>(m:haxe.ds.IntMap<T>):Array<Int> {
		return untyped __global__.__int_hash_keys(@:privateAccess m.h);
	}
	#end

	#if macro
	static function mapKind(coll:Expr):MapKind {
		final t = try Context.follow(Context.typeof(coll)) catch (_:Dynamic) return MOther;
		return switch t {
			case TInst(_.get() => c, [vt]) if (c.pack.join(".") == "haxe.ds" && c.name == "StringMap"): MString(vt);
			case TInst(_.get() => c, [vt]) if (c.pack.join(".") == "haxe.ds" && c.name == "IntMap"): MInt(vt);
			case TInst(_.get() => c, [_, _]) if (c.pack.join(".") == "go" && c.name == "IdentityMap"): MIdentity;
			case _: MOther;
		}
	}

	// Values stored unboxed by hxcpp's hash (Int, Float, Bool and abstracts over them): keep the
	// map's own iterator for them.
	static function isBasic(t:Type):Bool {
		return switch Context.followWithAbstracts(t) {
			case TAbstract(_.get() => a, _) if (a.pack.length == 0 && (a.name == "Int" || a.name == "Float" || a.name == "Bool")): true;
			case TAbstract(_.get() => a, [inner]) if (a.pack.length == 0 && a.name == "Null"): isBasic(inner);
			case _: false;
		}
	}
	#end
}

#if macro
enum MapKind {
	MString(valueType:Type);
	MInt(valueType:Type);
	MIdentity;
	MOther;
}
#end
