package ts.collections;

// Port of set.go.
// Go `map[T]struct{}` → GoMap<T, Bool> (value always true).
// PORT: nil receiver — Go methods that check `s == nil` are `inline` here and test
// `this == null`, so `s.Has(x)` on a null Set works like Go on a nil *Set. Only call them
// directly (not as closures). A Go zero-value `Set[T]` (struct field or local var) is
// `new Set<T>()` in Haxe; M stays null until the first Add, like Go's nil map.
class Set<T> {
	public var M:Null<GoMap<T, Bool>> = null;

	public function new() {}

	public inline function Has(key:T):Bool {
		return this == null ? false : M != null && M.exists(key);
	}

	public function Add(key:T):Void {
		if (M == null) {
			M = new GoMap<T, Bool>();
		}
		M.set(key, true);
	}

	public function Delete(key:T):Void {
		if (M != null)
			M.remove(key);
	}

	public inline function Len():Int {
		return this == null ? 0 : (M == null ? 0 : M.length());
	}

	// PORT: Go returns the map itself (nil for a nil Set or nil map). Haxe cannot range over
	// null, so an empty map is returned instead of nil. Iterate with `for (k in s.Keys().keys())`.
	public inline function Keys():GoMap<T, Bool> {
		return this == null || M == null ? new GoMap<T, Bool>() : M;
	}

	public inline function Clear():Void {
		if (this != null && M != null)
			M.clear();
	}

	// Returns true if the key was not already present in the set.
	public function AddIfAbsent(key:T):Bool {
		if (this.Has(key)) {
			return false;
		}
		this.Add(key);
		return true;
	}

	public inline function Clone():Null<Set<T>> {
		return this == null ? null : clone();
	}

	// PORT: non-nil part of Clone (keeps the inline nil check small).
	function clone():Set<T> {
		final clone = new Set<T>();
		clone.M = Maps.Clone(M);
		return clone;
	}

	public inline function Union(other:Null<Set<T>>):Void {
		if (!(this.Len() == 0 && other.Len() == 0)) {
			if (this == null) {
				throw "cannot modify nil Set";
			}
			union(other);
		}
	}

	// PORT: non-nil part of Union.
	function union(other:Set<T>):Void {
		if (M == null) {
			M = Maps.Clone(other.M);
			return;
		}
		Maps.Copy(M, other.M);
	}

	public inline function UnionedWith(other:Null<Set<T>>):Null<Set<T>> {
		return unionedWith(this, other);
	}

	// PORT: body of UnionedWith with an explicit (possibly null) receiver.
	static function unionedWith<T>(s:Null<Set<T>>, other:Null<Set<T>>):Null<Set<T>> {
		if (s == null && other == null) {
			return null;
		}
		var result = s.Clone();
		if (other != null) {
			if (result == null) {
				result = new Set<T>();
			}
			if (result.M == null) {
				result.M = new GoMap<T, Bool>();
			}
			Maps.Copy(result.M, other.M);
		}
		return result;
	}

	public inline function Equals(other:Null<Set<T>>):Bool {
		return equals(this, other);
	}

	// PORT: body of Equals with an explicit (possibly null) receiver.
	static function equals<T>(s:Null<Set<T>>, other:Null<Set<T>>):Bool {
		if (s == other) {
			return true;
		}
		if (s == null || other == null) {
			return false;
		}
		return Maps.Equal(s.M, other.M);
	}

	public inline function IsSubsetOf(other:Null<Set<T>>):Bool {
		return this == null ? true : isSubsetOf(other);
	}

	// PORT: non-nil part of IsSubsetOf.
	function isSubsetOf(other:Null<Set<T>>):Bool {
		if (M != null) {
			for (key in M.keys()) {
				if (!other.Has(key)) {
					return false;
				}
			}
		}
		return true;
	}

	public inline function Intersects(other:Null<Set<T>>):Bool {
		return this == null || other == null ? false : intersects(other);
	}

	// PORT: non-nil part of Intersects.
	function intersects(other:Set<T>):Bool {
		if (M != null) {
			for (key in M.keys()) {
				if (other.Has(key)) {
					return true;
				}
			}
		}
		return false;
	}
}
