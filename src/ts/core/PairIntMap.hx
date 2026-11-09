package ts.core;

// PORT: perf — a map from a pair of Ints (a key value of two words: no key object or string) to a non-negative Int,
// for the checker's relation caches (Go's map[CacheHashKey]RelationComparisonResult). Open addressing with linear
// probing, each slot three Ints (a, b, value + 1; 0: empty), removal by backward shift (no tombstones), clear keeps
// the table. get returns -1 for a missing key. Nothing iterates it.
#if (target.name == "hxmc")
import hxmc.rt.MapSlots;

class PairIntMap {
	var slots:MapSlots<Int>;
	var used:Int;
	var mask:Int; // cap - 1

	public function new() {
		used = 0;
		mask = -1;
	}

	public inline function size():Int
		return used;

	static inline function hashOf(a:Int, b:Int):Int {
		var h = a * 0x9E3779B1;
		h = (h ^ (h >>> 15) ^ b) * 0x85EBCA6B;
		return h ^ (h >>> 13);
	}

	public function get(a:Int, b:Int):Int {
		if (used == 0)
			return -1;
		final slots = this.slots, mask = this.mask;
		var i = hashOf(a, b) & mask;
		while (true) {
			final o = 3 * i;
			final v = slots[o + 2];
			if (v == 0)
				return -1;
			if (slots[o] == a && slots[o + 1] == b)
				return v - 1;
			i = (i + 1) & mask;
		}
	}

	// sets the key's value (v >= 0); whether the key is new
	public function set(a:Int, b:Int, v:Int):Bool {
		if (used != 0) {
			final slots = this.slots, mask = this.mask;
			var i = hashOf(a, b) & mask;
			while (true) {
				final o = 3 * i;
				final w = slots[o + 2];
				if (w == 0)
					break;
				if (slots[o] == a && slots[o + 1] == b) {
					slots[o + 2] = v + 1;
					return false;
				}
				i = (i + 1) & mask;
			}
		}
		if (used >= (mask + 1) >> 1)
			grow();
		put(a, b, v + 1);
		used++;
		return true;
	}

	inline function put(a:Int, b:Int, v1:Int):Void {
		final slots = this.slots, mask = this.mask;
		var i = hashOf(a, b) & mask;
		while (slots[3 * i + 2] != 0)
			i = (i + 1) & mask;
		final o = 3 * i;
		slots[o] = a;
		slots[o + 1] = b;
		slots[o + 2] = v1;
	}

	function grow():Void {
		final os = slots, ocap = mask + 1;
		final cap = mask < 0 ? 16 : 2 * ocap;
		slots = new MapSlots<Int>(3 * cap);
		mask = cap - 1;
		for (i in 0...(os == null ? 0 : ocap)) {
			final o = 3 * i;
			if (os[o + 2] != 0)
				put(os[o], os[o + 1], os[o + 2]);
		}
	}

	public function remove(a:Int, b:Int):Void {
		if (used == 0)
			return;
		final slots = this.slots, mask = this.mask;
		var i = hashOf(a, b) & mask;
		while (true) {
			final o = 3 * i;
			if (slots[o + 2] == 0)
				return;
			if (slots[o] == a && slots[o + 1] == b)
				break;
			i = (i + 1) & mask;
		}
		// backward shift: move later slots of the chain whose home is not cyclically in (i, j]
		var j = i;
		while (true) {
			j = (j + 1) & mask;
			final oj = 3 * j;
			if (slots[oj + 2] == 0)
				break;
			final home = hashOf(slots[oj], slots[oj + 1]) & mask;
			if (i <= j ? (i < home && home <= j) : (i < home || home <= j))
				continue;
			final oi = 3 * i;
			slots[oi] = slots[oj];
			slots[oi + 1] = slots[oj + 1];
			slots[oi + 2] = slots[oj + 2];
			i = j;
		}
		slots[3 * i + 2] = 0;
		used--;
	}

	public function clear():Void {
		if (used == 0)
			return;
		final slots = this.slots;
		for (i in 0...mask + 1)
			slots[3 * i + 2] = 0;
		used = 0;
	}
}
#end
