package ts.core;

// Port of linkstore.go.

// Links store
// PORT: PORTING.md §4a — built with a factory for the Go zero value of V:
// `new LinkStore<K, V>(() -> new V())`. Get creates the value on first access, like Go.
// PORT: perf — Go `map[K]*V` (every K is a pointer type: Node, Symbol, SourceFile). Here each key
// object is a LinkHolder that keeps its values of all stores in a short list (LinkEntry: store,
// value): a lookup reads the key, which the caller has just used, and follows a few entries,
// instead of hashing into a large table (ts6-compiler: the checker's link stores were the
// largest share of map lookups). No store iterates over its keys.
class LinkStore<K, V> {
	final arena:Arena<V>;

	public function new(factory:() -> V) {
		this.arena = new Arena<V>(factory);
	}

	public function Get(key:K):V {
		final h:LinkHolder = cast key;
		var e = h.links;
		while (e != null) {
			if (e.store == this)
				return cast e.value;
			e = e.next;
		}
		final value = arena.New();
		h.links = new LinkEntry(this, value, h.links);
		return value;
	}

	public function Has(key:K):Bool {
		final h:LinkHolder = cast key;
		var e = h.links;
		while (e != null) {
			if (e.store == this)
				return true;
			e = e.next;
		}
		return false;
	}

	public function TryGet(key:K):Null<V> {
		final h:LinkHolder = cast key;
		var e = h.links;
		while (e != null) {
			if (e.store == this)
				return cast e.value;
			e = e.next;
		}
		return null;
	}
}

// PORT: perf — what a LinkStore key is (ast.NodeDefault, ast.Symbol): its links (see LinkStore).
class LinkHolder {
	public var links:LinkEntry = null;

	public function new() {}
}

class LinkEntry {
	public final store:Dynamic;
	public final value:Dynamic;
	public final next:LinkEntry;

	public function new(store:Dynamic, value:Dynamic, next:LinkEntry) {
		this.store = store;
		this.value = value;
		this.next = next;
	}
}
