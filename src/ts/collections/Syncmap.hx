package ts.collections;

// Port of syncmap.go.
// PORT: single-threaded port (PORTING.md §4): sync.Map → GoMap. Go zero value →
// `new SyncMap<K, V>(zero)`; `zero` is the Go zero value of V (default null, see OrderedMap.hx).
// Range order is the GoMap order (Go: unspecified).
class SyncMap<K, V> {
	var m:GoMap<K, V> = new GoMap<K, V>();

	// PORT: Go zero value of V.
	final zero:Null<V>;

	public function new(?zero:V) {
		this.zero = zero;
	}

	public function Load(key:K):ValueOk<V> {
		final ok = m.exists(key);
		final val = m.get(key);
		if (!ok || val == null) {
			return new ValueOk<V>(zero, ok);
		}
		return new ValueOk<V>(val, true);
	}

	public function Store(key:K, value:V):Void {
		m.set(key, value);
	}

	// PORT: (actual V, loaded bool) → ValueOk: value = actual, ok = loaded.
	public function LoadOrStore(key:K, value:V):ValueOk<V> {
		final loaded = m.exists(key);
		final actualAny = loaded ? m.get(key) : value;
		if (!loaded)
			m.set(key, value);
		if (actualAny == null) {
			return new ValueOk<V>(zero, loaded);
		}

		return new ValueOk<V>(actualAny, loaded);
	}

	public function Delete(key:K):Void {
		m.remove(key);
	}

	public function Clear():Void {
		m.clear();
	}

	public function Range(f:(key:K, value:V) -> Bool):Void {
		for (key in m.keys()) {
			final value = m.get(key);
			var v:V = zero;
			if (value != null) {
				v = value;
			}

			if (!f(key, v))
				break;
		}
	}

	// Size returns the approximate number of items in the map.
	// Note that this is not a precise count, as the map may be modified
	// concurrently while this method is running.
	public function Size():Int {
		// PORT: Go counts with Range; the count is exact here.
		return m.length();
	}

	public function ToMap():GoMap<K, V> {
		return m.copy();
	}

	public function Keys():Iterator<K> {
		return m.keys();
	}

	public function Clone():SyncMap<K, V> {
		final clone = new SyncMap<K, V>(zero);
		clone.m = m.copy();
		return clone;
	}
}
