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
	#if tshx_parallel
	static final insertMutex = new sys.thread.Mutex();
	#end

	public function new(factory:() -> V) {
		this.arena = new Arena<V>(factory);
	}

	// PORT: perf — inline: the key's first entry (most often this store's: the last one to add a link to the key)
	public inline function Get(key:K):V {
		final h:LinkHolder = cast key;
		final e = h.links;
		final self:LinkStore<Dynamic, Dynamic> = cast this;
		return e != null && e.store == self ? cast e.value : getSlow(key);
	}

	function getSlow(key:K):V {
		final h:LinkHolder = cast key;
		final self:LinkStore<Dynamic, Dynamic> = cast this; // (a reference comparison, not Dynamic equality)
		var e = h.links;
		while (e != null) {
			if (e.store == self)
				return cast e.value;
			e = e.next;
		}
		final value = arena.New();
		#if tshx_parallel
		// PORT: hxmc (-D tshx-parallel) — the key's list is shared by the stores of all checkers: the
		// entry is complete before it is published, readers need no lock (entries never change)
		#if (target.name == "hxmc")
		// PORT: perf — no lock: the entry is prepended by a compare-and-swap of the key's list head (each
		// checker's store is used by one thread at a time; a failed swap means another checker prepended)
		final e = new LinkEntry(self, value, null);
		do
			e.next = h.links
		while (!casLinks(h, e.next, e));
		#else
		insertMutex.acquire();
		h.links = new LinkEntry(self, value, h.links);
		insertMutex.release();
		#end
		#else
		h.links = new LinkEntry(self, value, h.links);
		#end
		return value;
	}

	public function Has(key:K):Bool {
		final h:LinkHolder = cast key;
		final self:LinkStore<Dynamic, Dynamic> = cast this; // (a reference comparison, not Dynamic equality)
		var e = h.links;
		while (e != null) {
			if (e.store == self)
				return true;
			e = e.next;
		}
		return false;
	}

	#if (tshx_parallel && target.name == "hxmc")
	// h.links from expected to e, atomically (and remembered when e is young and h is not: the write barrier)
	@:hxmc.unsafe static function casLinks(h:LinkHolder, expected:LinkEntry, e:LinkEntry):Bool {
		final p = hxmc.unsafe.Mem.addr(h).add(hxmc.unsafe.Struct.fieldOffset(h, "links"));
		final ei = hxmc.unsafe.Mem.addr(expected).toI64();
		final o = hxmc.unsafe.Atomic.cas64(p, ei, hxmc.unsafe.Mem.addr(e).toI64());
		if (o != ei)
			return false;
		hxmc.rt.C.Leaf.rt_barrier_range(h, p, 1);
		return true;
	}
	#end

	public function TryGet(key:K):Null<V> {
		final h:LinkHolder = cast key;
		final self:LinkStore<Dynamic, Dynamic> = cast this; // (a reference comparison, not Dynamic equality)
		var e = h.links;
		while (e != null) {
			if (e.store == self)
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
	public final store:LinkStore<Dynamic, Dynamic>;
	public final value:Dynamic;
	public var next:LinkEntry; // (set before the entry is published)

	public function new(store:LinkStore<Dynamic, Dynamic>, value:Dynamic, next:LinkEntry) {
		this.store = store;
		this.value = value;
		this.next = next;
	}
}
