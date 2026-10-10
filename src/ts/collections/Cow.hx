package ts.collections;

// Port of cow.go.

// CopyOnWriteMap is a map that defers cloning of an inherited backing map
// until the first mutation, and supports nested scopes that share the parent's
// map for reads but get their own clone on write.
//
// The zero value is an empty map ready to use.
// PORT: Go zero value → `new CopyOnWriteMap<K, V>(zero)`; `zero` is the Go zero value of V
// returned by Get for a missing key (default null, see OrderedMap.hx).
class CopyOnWriteMap<K, V> {
	var m:Null<GoMap<K, V>> = null;
	var owned:Bool = false;

	// PORT: Go zero value of V.
	final zero:Null<V>;

	public function new(?zero:V) {
		this.zero = zero;
	}

	// Get returns the value for k and whether it was present.
	public function Get(k:K):ValueOk<V> {
		if (m != null && m.exists(k))
			return new ValueOk<V>(m.get(k), true);
		return new ValueOk<V>(zero, false);
	}

	// Has reports whether k is in the map.
	public function Has(k:K):Bool {
		return m != null && m.exists(k);
	}

	// Set assigns v to k, cloning the inherited backing map first if necessary.
	public function Set(k:K, v:V):Void {
		this.ensureOwned();
		m.set(k, v);
	}

	function ensureOwned():Void {
		if (owned) {
			return;
		}
		if (m == null) {
			m = new GoMap<K, V>();
		} else {
			m = Maps.Clone(m);
		}
		owned = true;
	}

	// EnterScope returns a function that restores this map to its current state.
	// While the scope is active, the map shares its current backing storage with
	// the parent scope: reads see the inherited entries, and the first mutation
	// transparently clones the storage so the parent's view is not modified.
	public function EnterScope():() -> Void {
		// saved := *c
		final savedM = m;
		final savedOwned = owned;
		owned = false;
		return () -> {
			m = savedM;
			owned = savedOwned;
		};
	}
}

// PORT: Go `struct{}` values → Bool (always true).
class CopyOnWriteSet<K> {
	var m:CopyOnWriteMap<K, Bool> = new CopyOnWriteMap<K, Bool>(false);

	public function new() {}

	// Has reports whether k is in the set.
	public function Has(k:K):Bool {
		// PORT: Go `_, ok := c.m.Get(k)`; Has avoids the result object.
		return m.Has(k);
	}

	// Set adds k to the set, cloning the inherited backing map first if necessary.
	public function Add(k:K):Void {
		m.Set(k, true);
	}

	// EnterScope returns a function that restores this set to its current state.
	// While the scope is active, the set shares its current backing storage with
	// the parent scope: reads see the inherited entries, and the first mutation
	// transparently clones the storage so the parent's view is not modified.
	public function EnterScope():() -> Void {
		return m.EnterScope();
	}
}
