package go;

// Shims for Go package maps, on go.GoMap. A nil map is `null` and behaves like an empty one.
class Maps {
	// maps.Clone: nil → nil.
	public static function Clone<K, V>(m:Null<GoMap<K, V>>):Null<GoMap<K, V>> {
		if (m == null)
			return null;
		return m.copy();
	}

	// maps.Copy: copies all key/value pairs of src into dst (dst must be non-nil unless src is empty).
	public static function Copy<K, V>(dst:GoMap<K, V>, src:Null<GoMap<K, V>>):Void {
		if (src == null)
			return;
		for (k in src.keys())
			dst.set(k, src.get(k));
	}

	// maps.Equal: same length and same key/value pairs (values compared with ==).
	public static function Equal<K, V>(m1:Null<GoMap<K, V>>, m2:Null<GoMap<K, V>>):Bool {
		final len1 = m1 == null ? 0 : m1.length();
		final len2 = m2 == null ? 0 : m2.length();
		if (len1 != len2)
			return false;
		if (len1 == 0)
			return true;
		for (k in m1.keys()) {
			if (!m2.exists(k) || m1.get(k) != m2.get(k))
				return false;
		}
		return true;
	}

	// maps.Keys (iter.Seq) → Iterator.
	public static function Keys<K, V>(m:Null<GoMap<K, V>>):Iterator<K> {
		if (m == null)
			return new GoMap<K, V>().keys();
		return m.keys();
	}

	// maps.Values (iter.Seq) → Iterator.
	public static function Values<K, V>(m:Null<GoMap<K, V>>):Iterator<V> {
		if (m == null)
			return new GoMap<K, V>().iterator();
		return m.iterator();
	}
}
