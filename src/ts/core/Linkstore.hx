package ts.core;

// Port of linkstore.go.

// Links store
// PORT: PORTING.md §4a — built with a factory for the Go zero value of V:
// `new LinkStore<K, V>(() -> new V())`. Get creates the value on first access, like Go.
// Go `map[K]*V` → go.IdentityMap<K, V> (every K is a pointer type: Node, Symbol, SourceFile).
class LinkStore<K, V> {
	var entries:Null<IdentityMap<K, V>> = null;
	final arena:Arena<V>;

	public function new(factory:() -> V) {
		this.arena = new Arena<V>(factory);
	}

	public function Get(key:K):V {
		var value = entries == null ? null : entries.get(key);
		if (value != null) {
			return value;
		}
		if (entries == null) {
			entries = new IdentityMap<K, V>();
		}
		value = arena.New();
		entries.set(key, value);
		return value;
	}

	public function Has(key:K):Bool {
		return entries != null && entries.exists(key);
	}

	public function TryGet(key:K):Null<V> {
		return entries == null ? null : entries.get(key);
	}
}
