package ts.collections;

// Port of internal/collections: package-level funcs. Types are in one module per Go file.
//
// PORT: the collection classes are NOT @:generic: Haxe cannot build `Map<K, V>` inside a
// class generic over K, even with @:generic (Haxe 4.3.7 / 5.0.0-preview.1). They store Go maps
// in go.GoMap, which picks StringMap / IntMap / ObjectMap from the first key at run time.
// Size hints have no Haxe equivalent and are ignored. Go explicit type arguments
// (`NewSetWithSizeHint[string](n)`) come from the expected type in Haxe:
// `final s:Set<String> = Collections.NewSetWithSizeHint(n);`.
class Collections {
	// --- multimap.go ---

	public static function NewMultiMapWithSizeHint<K, V>(hint:Int):MultiMap<K, V> {
		final m = new MultiMap<K, V>();
		m.M = new GoMap<K, Array<V>>();
		return m;
	}

	public static function GroupBy<K, V>(items:Null<Array<V>>, groupId:(V) -> K):MultiMap<K, V> {
		final m = new MultiMap<K, V>();
		if (items != null) {
			for (item in items) {
				m.Add(groupId(item), item);
			}
		}
		return m;
	}

	// --- ordered_map.go ---

	// NewOrderedMapWithSizeHint creates a new OrderedMap with a hint for the number of elements it will contain.
	// PORT: `zero` is the Go zero value of V (see OrderedMap.hx).
	public static function NewOrderedMapWithSizeHint<K, V>(hint:Int, ?zero:V):OrderedMap<K, V> {
		final m = newMapWithSizeHint(hint, zero);
		return m;
	}

	static function newMapWithSizeHint<K, V>(hint:Int, ?zero:V):OrderedMap<K, V> {
		return new OrderedMap<K, V>(zero);
	}

	// PORT: `zero` is the Go zero value of V (see OrderedMap.hx).
	public static function NewOrderedMapFromList<K, V>(items:Null<Array<MapEntry<K, V>>>, ?zero:V):OrderedMap<K, V> {
		final mp:OrderedMap<K, V> = NewOrderedMapWithSizeHint(items == null ? 0 : items.length, zero);
		if (items != null) {
			for (item in items) {
				mp.Set(item.Key, item.Value);
			}
		}
		return mp;
	}

	public static function DiffOrderedMaps<K, V>(m1:Null<OrderedMap<K, V>>, m2:Null<OrderedMap<K, V>>, onAdded:(key:K, value:V) -> Void,
			onRemoved:(key:K, value:V) -> Void, onModified:(key:K, oldValue:V, newValue:V) -> Void):Void {
		DiffOrderedMapsFunc(m1, m2, (a:V, b:V) -> {
			return a == b;
		}, onAdded, onRemoved, onModified);
	}

	public static function DiffOrderedMapsFunc<K, V>(m1:Null<OrderedMap<K, V>>, m2:Null<OrderedMap<K, V>>, equalValues:(a:V, b:V) -> Bool,
			onAdded:(key:K, value:V) -> Void, onRemoved:(key:K, value:V) -> Void, onModified:(key:K, oldValue:V, newValue:V) -> Void):Void {
		for (k => v2 in m2.Entries()) {
			if (!m1.Has(k)) { // PORT: Go `_, ok := m1.Get(k)`; Has avoids the result object.
				onAdded(k, v2);
			}
		}
		for (k => v1 in m1.Entries()) {
			final r = m2.Get(k);
			if (r.ok) {
				final v2 = r.value;
				if (!equalValues(v1, v2)) {
					onModified(k, v1, v2);
				}
			} else {
				onRemoved(k, v1);
			}
		}
	}

	// --- ordered_set.go ---

	// NewOrderedSetWithSizeHint creates a new OrderedSet with a hint for the number of elements it will contain.
	public static function NewOrderedSetWithSizeHint<T>(hint:Int):OrderedSet<T> {
		final s = new OrderedSet<T>();
		s.m = newMapWithSizeHint(hint, false);
		return s;
	}

	// --- set.go ---

	// NewSetWithSizeHint creates a new Set with a hint for the number of elements it will contain.
	public static function NewSetWithSizeHint<T>(hint:Int):Set<T> {
		final s = new Set<T>();
		s.M = new GoMap<T, Bool>();
		return s;
	}

	public static function NewSetFromItems<T>(...items:T):Set<T> {
		final s = new Set<T>();
		for (item in items) {
			s.Add(item);
		}
		return s;
	}
}
