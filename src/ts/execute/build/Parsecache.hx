package ts.execute.build;

// Port of parseCache.go.
// PORT: single-threaded port: the per-entry sync.Mutex is dropped.
class ParseCacheEntry<V> {
	public var value:Null<V> = null;

	public function new() {}
}

// PORT: Go `parseCache[K comparable, V comparable]` with a SyncMap keyed by K. K is a tspath.Path or
// an ast.SourceFileParseOptions struct; struct keys are encoded as a String (PORTING.md §4a), so the
// cache takes a `keyOf` function that maps K to its map key.
class ParseCache<K, V> {
	var entries:StringMap<ParseCacheEntry<V>> = new StringMap();
	final keyOf:(K) -> std.String;

	public function new(keyOf:(K) -> std.String) {
		this.keyOf = keyOf;
	}

	public function loadOrStore(key:K, parse:(K) -> V, allowZero:Bool):V {
		var newEntry = new ParseCacheEntry<V>();
		final k = this.keyOf(key);
		final entry = this.entries.get(k);
		if (entry != null) {
			if (allowZero || entry.value != null) {
				return entry.value;
			}
			newEntry = entry;
		} else {
			this.entries.set(k, newEntry);
		}
		newEntry.value = parse(key);
		return newEntry.value;
	}

	public function store(key:K, value:V):Void {
		final e = new ParseCacheEntry<V>();
		e.value = value;
		this.entries.set(this.keyOf(key), e);
	}

	public function delete(key:K):Void {
		this.entries.remove(this.keyOf(key));
	}

	public function reset():Void {
		this.entries = new StringMap();
	}
}
