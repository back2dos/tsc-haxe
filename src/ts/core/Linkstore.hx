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
// PORT: perf — the list is intrusive: every value class extends LinkEntry (its store and the next
// entry), so a link is one object (no separate entry: 32 B less per link, one load less per lookup).
class LinkStore<K, V:LinkEntry> {
	final arena:Arena<V>;
	// PORT: perf — the value for a key, when it depends on the key (a subclass with more fields for some keys)
	final forKey:Null<K->V>;
	#if tshx_parallel
	static final insertMutex = new sys.thread.Mutex();
	#end

	public function new(factory:() -> V, ?forKey:K->V) {
		this.arena = new Arena<V>(factory);
		this.forKey = forKey;
	}

	// PORT: perf — inline: the key's first entry (most often this store's: the last one to add a link to the key)
	public inline function Get(key:K):V {
		final h:LinkHolder = cast key;
		final e = h.links;
		final self:LinkStore<Dynamic, Dynamic> = cast this;
		return e != null && e.linkStore == self ? cast e : getSlow(key);
	}

	function getSlow(key:K):V {
		final h:LinkHolder = cast key;
		final self:LinkStore<Dynamic, Dynamic> = cast this; // (a reference comparison, not Dynamic equality)
		var e = h.links;
		while (e != null) {
			if (e.linkStore == self)
				return cast e;
			e = e.linkNext;
		}
		final value:LinkEntry = forKey != null ? forKey(key) : arena.New();
		value.linkStore = self;
		#if tshx_parallel
		// PORT: hxmc (-D tshx-parallel) — the key's list is shared by the stores of all checkers: the
		// entry is complete before it is published, readers need no lock (entries never change)
		#if (target.name == "hxmc")
		// PORT: perf — no lock: the entry is prepended by a compare-and-swap of the key's list head (each
		// checker's store is used by one thread at a time; a failed swap means another checker prepended)
		final e = value;
		do
			e.linkNext = h.links
		while (!casLinks(h, e.linkNext, e));
		#else
		insertMutex.acquire();
		value.linkNext = h.links;
		h.links = value;
		insertMutex.release();
		#end
		#else
		value.linkNext = h.links;
		h.links = value;
		#end
		return cast value;
	}

	public function Has(key:K):Bool {
		final h:LinkHolder = cast key;
		final self:LinkStore<Dynamic, Dynamic> = cast this; // (a reference comparison, not Dynamic equality)
		var e = h.links;
		while (e != null) {
			if (e.linkStore == self)
				return true;
			e = e.linkNext;
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

	// TryGet, inline (the rare fields of AST nodes, tools/gen/ast/GenAst.hx RARE_FIELDS: the key's list most often has
	// no entry of this store)
	public inline function TryGetInline(key:K):Null<V> {
		final h:LinkHolder = cast key;
		final self:LinkStore<Dynamic, Dynamic> = cast this; // (a reference comparison, not Dynamic equality)
		var e = h.links;
		while (e != null && e.linkStore != self)
			e = e.linkNext;
		return cast e;
	}

	public function TryGet(key:K):Null<V> {
		final h:LinkHolder = cast key;
		final self:LinkStore<Dynamic, Dynamic> = cast this; // (a reference comparison, not Dynamic equality)
		var e = h.links;
		while (e != null) {
			if (e.linkStore == self)
				return cast e;
			e = e.linkNext;
		}
		return null;
	}
}

// PORT: perf — what a LinkStore key is (ast.NodeDefault, ast.Symbol): its links (see LinkStore).
class LinkHolder {
	public var links:LinkEntry = null;

	public function new() {}
}

// The base class of a LinkStore's values: the store whose value this is and the key's next link (both set by
// LinkStore.getSlow before the entry is published, never changed after).
class LinkEntry {
	public var linkStore:LinkStore<Dynamic, Dynamic> = null;
	public var linkNext:LinkEntry = null;

	public function new() {}
}

// PORT: perf — the entry of a node's or symbol's id (Ast.GetNodeId, Ast.GetSymbolId: few have one, so it is no field)
class IdLink extends LinkEntry {
	public var id:Int = 0;

	public function new() {
		super();
	}
}
