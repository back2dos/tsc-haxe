package ts.collections;

// Port of multimap.go (types and methods; NewMultiMapWithSizeHint and GroupBy are in Collections.hx).
// A Go zero-value `MultiMap[K, V]` is `new MultiMap<K, V>()`.
class MultiMap<K, V> {
	public var M:Null<GoMap<K, Array<V>>> = null;

	public function new() {}

	public function Has(key:K):Bool {
		return M != null && M.exists(key);
	}

	// Returns null (Go nil slice) for a missing key.
	public function Get(key:K):Null<Array<V>> {
		return M == null ? null : M.get(key);
	}

	public function Add(key:K, value:V):Void {
		if (M == null) {
			M = new GoMap<K, Array<V>>();
		}
		// PORT: Go `append` may reuse the backing array; here the stored array is always
		// extended in place, so a slice obtained earlier from Get also grows.
		var values = M.get(key);
		if (values == null) {
			values = [];
			M.set(key, values);
		}
		values.push(value);
	}

	public function Remove(key:K, value:V):Void {
		if (M != null && M.exists(key)) {
			final values = M.get(key);
			final i = values.indexOf(value);
			if (i >= 0) {
				if (values.length == 1) {
					M.remove(key);
				} else {
					values.splice(i, 1);
					M.set(key, values);
				}
			}
		}
	}

	public function RemoveAll(key:K):Void {
		if (M != null)
			M.remove(key);
	}

	public function Len():Int {
		return M == null ? 0 : M.length();
	}

	public function Keys():Iterator<K> {
		return Maps.Keys(M);
	}

	public function Values():Iterator<Array<V>> {
		return Maps.Values(M);
	}

	public function Clear():Void {
		if (M != null)
			M.clear();
	}
}
