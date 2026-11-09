package ts.core;

// PORT: perf — an Int-keyed map that keeps its table when cleared (Go's clear(m) keeps the map's buckets), for
// scratch maps that are emptied and filled again many times (the checker's pooled active-mapper caches). Only get,
// set and clear (no removal, no iteration). On hxmc: an open-addressing index of (key, entry + 1) pairs and the
// entries' keys and values; clear empties the slots of the entries (found again by their keys), so it costs the
// entries, not the table, and a table grown past BIG slots is dropped instead (as tsrs's pooled maps that one
// instantiation grew too far). Elsewhere: an IntMap.
#if (target.name == "hxmc")
import hxmc.rt.MapSlots;
import hxmc.rt.MapSlots.RefSlots;

class ScratchIntMap<T> {
	var slots:MapSlots<Int>; // cap slots of two: the key and its entry + 1 (0: empty)
	var keys:MapSlots<Int>; // per entry (room = cap / 2)
	var vals:RefSlots;
	var used:Int;
	var mask:Int; // cap - 1

	static inline final BIG = 16384;

	public function new() {
		used = 0;
		mask = -1;
	}

	static inline function hashOf(k:Int):Int {
		final h = k * 0x9E3779B1;
		return h ^ (h >>> 16);
	}

	public function get(k:Int):Null<T> {
		if (used == 0)
			return null;
		final slots = this.slots, mask = this.mask;
		var i = hashOf(k) & mask;
		while (true) {
			final e = slots[2 * i + 1];
			if (e == 0)
				return null;
			if (slots[2 * i] == k)
				return vals[e - 1];
			i = (i + 1) & mask;
		}
	}

	public function set(k:Int, v:T):Void {
		if (used != 0) {
			final slots = this.slots, mask = this.mask;
			var i = hashOf(k) & mask;
			while (true) {
				final e = slots[2 * i + 1];
				if (e == 0)
					break;
				if (slots[2 * i] == k) {
					vals[e - 1] = v;
					return;
				}
				i = (i + 1) & mask;
			}
		}
		if (used >= (mask + 1) >> 1)
			grow();
		add(k, v);
	}

	inline function add(k:Int, v:Dynamic):Void {
		final slots = this.slots, mask = this.mask;
		final e = used++;
		keys[e] = k;
		vals[e] = v;
		var i = hashOf(k) & mask;
		while (slots[2 * i + 1] != 0)
			i = (i + 1) & mask;
		slots[2 * i] = k;
		slots[2 * i + 1] = e + 1;
	}

	function grow():Void {
		final okeys = keys, ovals = vals, on = used;
		final cap = mask < 0 ? 8 : 2 * (mask + 1);
		slots = new MapSlots<Int>(2 * cap);
		keys = new MapSlots<Int>(cap >> 1);
		vals = new RefSlots(cap >> 1);
		used = 0;
		mask = cap - 1;
		for (j in 0...on)
			add(okeys[j], ovals[j]);
	}

	public function clear():Void {
		if (used == 0)
			return;
		if (mask + 1 > BIG) {
			slots = null;
			keys = null;
			vals = null;
			used = 0;
			mask = -1;
			return;
		}
		final slots = this.slots, mask = this.mask;
		for (j in 0...used) {
			var i = hashOf(keys[j]) & mask;
			while (slots[2 * i + 1] != j + 1)
				i = (i + 1) & mask;
			slots[2 * i + 1] = 0;
			vals[j] = null;
		}
		used = 0;
	}
}
#else
abstract ScratchIntMap<T>(haxe.ds.IntMap<T>) {
	public inline function new() {
		this = new haxe.ds.IntMap<T>();
	}

	public inline function get(k:Int):Null<T>
		return this.get(k);

	public inline function set(k:Int, v:T):Void
		this.set(k, v);

	public inline function clear():Void
		this.clear();
}
#end
