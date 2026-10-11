package go;

import haxe.Constraints.IMap;

// Go `map[*T]V`: a map keyed by object identity, iterated in insertion order.
// PORT: perf — replaces haxe.ds.ObjectMap (PORTING.md §7a):
//   hxcpp: ObjectMap gives every key an id through a global, mutex-protected table
//          (__hxcpp_obj_id); here the key's address is hashed directly. hxcpp's GC does not move
//          objects (HXCPP_GC_MOVING is off), and the map holds its keys strongly, so an address
//          is stable while it is a key. Iteration order never depends on addresses: entries are
//          kept in insertion order (a deleted key that is set again goes to the end).
//   JS:    a native ES6 Map (identity keys, insertion order); ObjectMap adds an `__id__` field
//          to every key object (a hidden-class change) and stores values under sparse integer keys.
//   other: keys and values in arrays in insertion order (holes for deleted entries, compacted when
//          they are more than half), plus an identity index key -> array position: on JVM a
//          java.util.IdentityHashMap (haxe.ds.ObjectMap uses equals()/hashCode()), elsewhere
//          haxe.ds.ObjectMap.
// keys()/iterator()/keyValueIterator() iterate over a snapshot (like haxe.ds.ObjectMap), so the
// map may be changed during iteration. Keys must be class instances (not null, String, Int).
class IdentityMap<K, V> implements IMap<K, V> {
	#if cpp
	// Entries in insertion order; a deleted entry has a null key (a hole).
	// PORT: perf — SlotArray, not Array<K>/Array<V>: hxcpp makes an array of a type parameter (and
	// Array<Dynamic>) a cpp.VirtualArray, with a virtual call per element read (measured 1.5 % of a
	// full emit).
	var ks:SlotArray = null;
	var vs:SlotArray = null;
	// Open addressing, linear probing: 0 = empty slot, else index into ks + 1.
	// (Measured: keys and values stored in the table itself were slower — more memory per map.)
	var slots:Array<Int> = null;
	var shift:Int = 32; // 32 - log2(slots.length)
	var used:Int = 0; // ks.length (live entries + holes)
	var count:Int = 0; // live entries
	#elseif js
	var m:js.lib.Map<K, V>;
	#else
	// Entries in insertion order; a deleted entry has a null key (a hole).
	var ks:Array<K> = [];
	var vs:Array<V> = [];
	var idx:IdentityIndex = new IdentityIndex();
	var count:Int = 0; // live entries
	#end

	public function new() {
		#if js
		m = new js.lib.Map();
		#end
	}

	// len(m)
	public inline function size():Int {
		#if js
		return m.size;
		#else
		return count;
		#end
	}

	#if !(cpp || js)
	// Removes the holes from ks/vs and renumbers the index.
	function compact():Void {
		final nk = new Array<K>(), nv = new Array<V>();
		for (i in 0...ks.length) {
			final k = ks[i];
			if (k != null) {
				idx.set(k, nk.length);
				nk.push(k);
				nv.push(vs[i]);
			}
		}
		ks = nk;
		vs = nv;
	}
	#end

	#if cpp
	// Fibonacci hash of the key's address (objects are at least 8-byte aligned).
	static inline function slotOf(k:Dynamic, shift:Int):Int {
		return untyped __cpp__("(int)(((unsigned int)(((size_t)({0}.mPtr)) >> 3) ^ (unsigned int)(((size_t)({0}.mPtr)) >> 35)) * 2654435769u >> {1})", k,
			shift);
	}

	static inline function same(a:Dynamic, b:Dynamic):Bool {
		return untyped __cpp__("({0}.mPtr == {1}.mPtr)", a, b);
	}

	// Index into ks of `k`, or -1.
	function find(k:K):Int {
		if (slots == null)
			return -1;
		final mask = slots.length - 1;
		var i = slotOf(k, shift);
		while (true) {
			final s:Int = untyped slots.__unsafe_get(i);
			if (s == 0)
				return -1;
			if (same(ks[s - 1], k))
				return s - 1;
			i = (i + 1) & mask;
		}
	}

	// Rebuilds the table with at least `cap` slots; removes the holes from ks/vs.
	function rehash(cap:Int):Void {
		if (used != count) {
			final nk = new SlotArray(), nv = new SlotArray();
			for (i in 0...used) {
				final k = ks[i];
				if (k != null) {
					nk.push(k);
					nv.push(vs[i]);
				}
			}
			ks = nk;
			vs = nv;
			used = count;
		}
		var bits = 3;
		while ((1 << bits) < cap)
			bits++;
		shift = 32 - bits;
		final n = 1 << bits, mask = n - 1;
		slots = new Array<Int>();
		slots.resize(n);
		for (j in 0...n)
			slots[j] = 0;
		for (e in 0...used) {
			var i = slotOf(ks[e], shift);
			while ((untyped slots.__unsafe_get(i) : Int) != 0)
				i = (i + 1) & mask;
			slots[i] = e + 1;
		}
	}
	#end

	public function get(k:K):Null<V> {
		#if cpp
		final e = find(k);
		return e < 0 ? null : vs[e];
		#elseif js
		return m.get(k);
		#else
		final e = idx.get(k);
		return e < 0 ? null : vs[e];
		#end
	}

	public function exists(k:K):Bool {
		#if cpp
		return find(k) >= 0;
		#elseif js
		return m.has(k);
		#else
		return idx.get(k) >= 0;
		#end
	}

	public function set(k:K, v:V):Void {
		add(k, v);
	}

	// m[k] = v; returns true when k was not in the map.
	public function add(k:K, v:V):Bool {
		#if cpp
		if (k == null)
			throw "IdentityMap: null key";
		if (slots == null) {
			ks = new SlotArray();
			vs = new SlotArray();
			rehash(8);
		}
		final mask = slots.length - 1;
		var i = slotOf(k, shift);
		while (true) {
			final s:Int = untyped slots.__unsafe_get(i);
			if (s == 0)
				break;
			if (same(ks[s - 1], k)) {
				vs[s - 1] = v;
				return false;
			}
			i = (i + 1) & mask;
		}
		ks.push(k);
		vs.push(v);
		used++;
		count++;
		slots[i] = used;
		if (used * 2 > slots.length)
			rehash(count * 4); // load ≤ 1/2 (after removing holes)
		return true;
		#elseif js
		final n = m.size;
		m.set(k, v);
		return m.size != n;
		#else
		if (k == null)
			throw "IdentityMap: null key";
		final e = idx.get(k);
		if (e >= 0) {
			vs[e] = v;
			return false;
		}
		idx.set(k, ks.length);
		ks.push(k);
		vs.push(v);
		count++;
		return true;
		#end
	}

	public function remove(k:K):Bool {
		#if cpp
		if (slots == null)
			return false;
		final mask = slots.length - 1;
		var i = slotOf(k, shift);
		while (true) {
			final s:Int = slots[i];
			if (s == 0)
				return false;
			if (same(ks[s - 1], k))
				break;
			i = (i + 1) & mask;
		}
		final e = slots[i] - 1;
		ks[e] = null;
		vs[e] = null;
		count--;
		// Backward-shift deletion: no tombstones in the table.
		var j = i;
		while (true) {
			j = (j + 1) & mask;
			final s = slots[j];
			if (s == 0)
				break;
			final h = slotOf(ks[s - 1], shift);
			// Slot j stays unless its home h lies cyclically outside (i, j].
			if ((i <= j) ? (i < h && h <= j) : (i < h || h <= j))
				continue;
			slots[i] = s;
			i = j;
		}
		slots[i] = 0;
		return true;
		#elseif js
		return m.delete(k);
		#else
		final e = idx.get(k);
		if (e < 0)
			return false;
		idx.remove(k);
		ks[e] = null;
		vs[e] = null;
		count--;
		if (count * 2 < ks.length - 8)
			compact();
		return true;
		#end
	}

	// PORT: perf — concrete iterator types (through `Iterator<T>` hxcpp calls hasNext/next by name).
	public function keys():haxe.iterators.ArrayIterator<K> {
		return keysArray().iterator();
	}

	public function iterator():haxe.iterators.ArrayIterator<V> {
		return valuesArray().iterator();
	}

	// PORT: perf — keys and values as arrays (insertion order; see go.ForIn).
	public function keysArray():Array<K> {
		#if cpp
		final a = new Array<K>();
		for (i in 0...used) {
			final k = ks[i];
			if (k != null)
				a.push(k);
		}
		return a;
		#elseif js
		return [for (k in new js.lib.HaxeIterator(m.keys())) k];
		#else
		return [for (k in ks) if (k != null) k];
		#end
	}

	public function valuesArray():Array<V> {
		#if cpp
		final a = new Array<V>();
		for (i in 0...used)
			if (ks[i] != null)
				a.push(vs[i]);
		return a;
		#elseif js
		return [for (v in new js.lib.HaxeIterator(m.values())) v];
		#else
		return [for (i in 0...ks.length) if (ks[i] != null) vs[i]];
		#end
	}

	public function keyValueIterator():KeyValueIterator<K, V> {
		return new haxe.iterators.MapKeyValueIterator(copy());
	}

	public function copy():IdentityMap<K, V> {
		final c = new IdentityMap<K, V>();
		#if cpp
		if (count > 0) {
			c.ks = new SlotArray();
			c.vs = new SlotArray();
			for (i in 0...used) {
				final k = ks[i];
				if (k != null) {
					c.ks.push(k);
					c.vs.push(vs[i]);
				}
			}
			c.used = c.count = count;
			c.rehash(count * 4);
		}
		#elseif js
		m.forEach((v, k, _) -> c.m.set(k, v));
		#else
		for (i in 0...ks.length) {
			final k = ks[i];
			if (k != null)
				c.add(k, vs[i]);
		}
		#end
		return c;
	}

	public function toString():String {
		final b = new StringBuf();
		b.add("[");
		var first = true;
		for (k in keys()) {
			if (!first)
				b.add(", ");
			first = false;
			b.add(Std.string(k));
			b.add(" => ");
			b.add(Std.string(get(k)));
		}
		b.add("]");
		return b.toString();
	}

	public function clear():Void {
		#if cpp
		ks = null;
		vs = null;
		slots = null;
		shift = 32;
		used = count = 0;
		#elseif js
		m.clear();
		#else
		ks = [];
		vs = [];
		idx = new IdentityIndex();
		count = 0;
		#end
	}
}

#if cpp
// Never instantiated: an Array of a class type is hxcpp's plain Array_obj<Dynamic>.
@:noCompletion
private class IdentityMapSlot {}

// Object array for IdentityMap's keys and values: element reads and writes without type checks
// and without cpp.VirtualArray dispatch.
private abstract SlotArray(Array<IdentityMapSlot>) {
	public inline function new() {
		this = [];
	}

	public var length(get, never):Int;

	inline function get_length():Int {
		return this.length;
	}

	@:arrayAccess
	public inline function get(i:Int):Dynamic {
		return untyped this.__unsafe_get(i);
	}

	@:arrayAccess
	public inline function set(i:Int, v:Dynamic):Dynamic {
		untyped __cpp__("{0}->__unsafe_set({1}, {2})", this, i, v);
		return v;
	}

	public inline function push(v:Dynamic):Void {
		untyped __cpp__("{0}->push({1})", this, v);
	}
}
#end

#if !(cpp || js)
// Identity index of IdentityMap: key object -> position in ks (-1 when absent).
private abstract IdentityIndex(#if jvm java.util.IdentityHashMap<Dynamic, Null<Int>> #else haxe.ds.ObjectMap<Dynamic, Int> #end) {
	public inline function new() {
		// PORT: jvm — haxe.ds.ObjectMap compares keys with equals()/hashCode(); this map uses identity.
		this = #if jvm new java.util.IdentityHashMap() #else new haxe.ds.ObjectMap() #end;
	}

	public inline function get(k:Dynamic):Int {
		final v:Null<Int> = this.get(k);
		return v == null ? -1 : v;
	}

	public inline function set(k:Dynamic, i:Int):Void {
		#if jvm
		this.put(k, i);
		#else
		this.set(k, i);
		#end
	}

	public inline function remove(k:Dynamic):Void {
		this.remove(k);
	}
}
#end
