package ts.core;

// PORT: perf — the maps keyed by a checker.CacheHashKey (Go: map[CacheHashKey]V, a 128-bit value key).
// On hxmc a CacheHashKey's Key() is a string of 8 16-bit units (6 for idsKey); a StringMap keeps one such
// string per entry (36 B: 4.8M of them on t3code-server) and loads it to compare on every lookup. HashKeyMap
// keeps the units of each key in its own int arrays instead (no string kept, a lookup compares ints in the
// map's arrays). Keys of more than 8 units (none of CacheHashKey's) go to a StringMap. Elsewhere it is a
// StringMap. Only get, set, exists and the values in insertion order (the short keys' first): the checker does
// not remove from these maps.
#if (target.name == "hxmc")
import hxmc.rt.MapSlots;
import hxmc.rt.MapSlots.RefSlots;
import hxmc.rt.Str;

class HashKeyMap<T> {
	// the index: cap slots of two elements (the key's tag: its hash with its length in the low 4 bits; its entry + 1,
	// 0 an empty slot)
	var slots:MapSlots<Int>;
	// per entry (room = cap / 2 entries): the key's units two per Int
	var keys:MapSlots<Int>;
	var vals:RefSlots;
	var used:Int;
	var mask:Int; // cap - 1
	var long:haxe.ds.StringMap<T>; // the keys of more than 8 units

	static inline final W = 4; // Ints per entry in keys

	public function new() {
		used = 0;
		mask = -1; // no arrays: the first set grows the table
	}

	static inline function pair(k:String, n:Int, i:Int):Int {
		return (i < n ? Str.unit(k, i) : 0) | ((i + 1 < n ? Str.unit(k, i + 1) : 0) << 16);
	}

	static inline function mix(n:Int, a:Int, b:Int, c:Int, d:Int):Int {
		var h = (n + 1) * 0x9E3779B1;
		h = (h ^ a) * 0x85EBCA6B;
		h = (h ^ (h >>> 15) ^ b) * 0xC2B2AE35;
		h = (h ^ (h >>> 13) ^ c) * 0x27D4EB2F;
		h = (h ^ (h >>> 16) ^ d) * 0x165667B1;
		return h ^ (h >>> 15);
	}

	static inline function tag(h:Int, n:Int):Int {
		return (h & ~15) | n;
	}

	// the entry of the key (n, a, b, c, d) with hash h, or -1
	inline function find(n:Int, a:Int, b:Int, c:Int, d:Int, h:Int):Int {
		var r = -1;
		if (used != 0) {
			final slots = this.slots, keys = this.keys, mask = this.mask;
			var i = h & mask;
			while (true) {
				final e = slots[2 * i + 1];
				if (e == 0)
					break;
				if (slots[2 * i] == tag(h, n)) {
					final o = W * (e - 1);
					if (keys[o] == a && keys[o + 1] == b && keys[o + 2] == c && keys[o + 3] == d) {
						r = e - 1;
						break;
					}
				}
				i = (i + 1) & mask;
			}
		}
		return r;
	}

	public function get(k:String):Null<T> {
		final n = Str.len(k);
		if (n > 8)
			return long == null ? null : long.get(k);
		final a = pair(k, n, 0), b = pair(k, n, 2), c = pair(k, n, 4), d = pair(k, n, 6);
		final e = find(n, a, b, c, d, mix(n, a, b, c, d));
		return e < 0 ? null : vals[e];
	}

	public function exists(k:String):Bool {
		final n = Str.len(k);
		if (n > 8)
			return long != null && long.exists(k);
		final a = pair(k, n, 0), b = pair(k, n, 2), c = pair(k, n, 4), d = pair(k, n, 6);
		return find(n, a, b, c, d, mix(n, a, b, c, d)) >= 0;
	}

	public function set(k:String, v:T):Void {
		final n = Str.len(k);
		if (n > 8) {
			if (long == null)
				long = new haxe.ds.StringMap<T>();
			long.set(k, v);
			return;
		}
		final a = pair(k, n, 0), b = pair(k, n, 2), c = pair(k, n, 4), d = pair(k, n, 6);
		final h = mix(n, a, b, c, d);
		final e = find(n, a, b, c, d, h);
		if (e >= 0) {
			vals[e] = v;
			return;
		}
		if (used >= (mask + 1) >> 1)
			rebuild(mask < 0 ? 8 : 2 * (mask + 1));
		add(n, a, b, c, d, h, v);
	}

	public function iterator():Iterator<T> {
		final values:Array<T> = [for (j in 0...used) (vals[j] : T)];
		if (long != null) {
			for (v in long) {
				values.push(v);
			}
		}
		return values.iterator();
	}

	// appends an entry (there is room for it) and indexes it
	function add(n:Int, a:Int, b:Int, c:Int, d:Int, h:Int, v:Dynamic):Void {
		final slots = this.slots, keys = this.keys, mask = this.mask;
		final e = used++;
		final o = W * e;
		keys[o] = a;
		keys[o + 1] = b;
		keys[o + 2] = c;
		keys[o + 3] = d;
		vals[e] = v;
		var i = h & mask;
		while (slots[2 * i + 1] != 0)
			i = (i + 1) & mask;
		slots[2 * i] = tag(h, n);
		slots[2 * i + 1] = e + 1;
	}

	// the table with cap slots (room for cap / 2 entries), the entries added again
	function rebuild(cap:Int):Void {
		final oslots = slots, okeys = keys, ovals = vals, on = used, ocap = mask + 1;
		// the entries' lengths, from the old index's tags (the entries are added again in their order)
		final lengths = new MapSlots<Int>(on > 0 ? on : 1);
		for (i in 0...(on > 0 ? ocap : 0)) {
			final e = oslots[2 * i + 1];
			if (e != 0) {
				lengths[e - 1] = oslots[2 * i] & 15;
			}
		}
		final room = cap >> 1;
		slots = new MapSlots<Int>(2 * cap);
		keys = new MapSlots<Int>(W * room);
		vals = new RefSlots(room);
		used = 0;
		mask = cap - 1;
		for (j in 0...on) {
			final o = W * j;
			final n = lengths[j], a = okeys[o], b = okeys[o + 1], c = okeys[o + 2], d = okeys[o + 3];
			add(n, a, b, c, d, mix(n, a, b, c, d), ovals[j]);
		}
	}
}
#else
typedef HashKeyMap<T> = haxe.ds.StringMap<T>;
#end
