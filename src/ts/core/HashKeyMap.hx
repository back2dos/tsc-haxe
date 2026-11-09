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
	// per entry: the key's units two per Int, and the value. The first C entries in flat arrays (room = cap / 2
	// entries while that is at most C, then C), the later ones in chunks of C entries (chunkKeys[k], chunkVals[k]:
	// entries (k + 1) * C ...), which a growth does not copy: only the index is made again (no old copies of the
	// big maps' keys and values left as garbage in the old space, which no major collection frees)
	var keys:MapSlots<Int>;
	var vals:RefSlots;
	var chunkKeys:Array<MapSlots<Int>>;
	var chunkVals:Array<RefSlots>;
	var used:Int;
	var mask:Int; // cap - 1
	var long:haxe.ds.StringMap<T>; // the keys of more than 8 units

	static inline final W = 4; // Ints per entry in keys
	static inline final SHIFT = 10;
	static inline final C = 1 << SHIFT; // entries in the flat arrays at most, and per chunk

	inline function keysOf(e:Int):MapSlots<Int> {
		return e < C ? keys : chunkKeys[(e >> SHIFT) - 1];
	}

	inline function valsOf(e:Int):RefSlots {
		return e < C ? vals : chunkVals[(e >> SHIFT) - 1];
	}

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
			final slots = this.slots, mask = this.mask;
			var i = h & mask;
			while (true) {
				final e = slots[2 * i + 1];
				if (e == 0)
					break;
				if (slots[2 * i] == tag(h, n)) {
					final keys = keysOf(e - 1), o = W * ((e - 1) & (C - 1));
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
		return e < 0 ? null : valsOf(e)[e & (C - 1)];
	}

	// get of the packed key (Checker.packedTypesKeyA: a header unit h0 and k <= 3 ids as two units each) without the
	// key string: its unit pairs computed from the ids
	public function getPacked(h0:Int, k:Int, id0:Int, id1:Int, id2:Int):Null<T> {
		final n = 1 + 2 * k;
		if (k < 3)
			id2 = 0;
		if (k < 2)
			id1 = 0;
		if (k < 1)
			id0 = 0;
		final a = h0 | ((id0 & 0xFFFF) << 16), b = (id0 >>> 16) | ((id1 & 0xFFFF) << 16), c = (id1 >>> 16) | ((id2 & 0xFFFF) << 16),
			d = id2 >>> 16;
		final e = find(n, a, b, c, d, mix(n, a, b, c, d));
		return e < 0 ? null : valsOf(e)[e & (C - 1)];
	}

	public function exists(k:String):Bool {
		final n = Str.len(k);
		if (n > 8)
			return long != null && long.exists(k);
		final a = pair(k, n, 0), b = pair(k, n, 2), c = pair(k, n, 4), d = pair(k, n, 6);
		return find(n, a, b, c, d, mix(n, a, b, c, d)) >= 0;
	}

	public inline function set(k:String, v:T):Void {
		setNew(k, v);
	}

	// set, and whether the key is new (PORT: perf — Go's len(m) before and after, in one lookup)
	public function setNew(k:String, v:T):Bool {
		final n = Str.len(k);
		if (n > 8) {
			if (long == null)
				long = new haxe.ds.StringMap<T>();
			final isNew = !long.exists(k);
			long.set(k, v);
			return isNew;
		}
		final a = pair(k, n, 0), b = pair(k, n, 2), c = pair(k, n, 4), d = pair(k, n, 6);
		final h = mix(n, a, b, c, d);
		final e = find(n, a, b, c, d, h);
		if (e >= 0) {
			valsOf(e)[e & (C - 1)] = v;
			return false;
		}
		if (used >= (mask + 1) >> 1)
			rebuild(mask < 0 ? 8 : 2 * (mask + 1));
		add(n, a, b, c, d, h, v);
		return true;
	}

	public function iterator():Iterator<T> {
		final values:Array<T> = [for (j in 0...used) (valsOf(j)[j & (C - 1)] : T)];
		if (long != null) {
			for (v in long) {
				values.push(v);
			}
		}
		return values.iterator();
	}

	// appends an entry (there is room for it in the index) and indexes it
	function add(n:Int, a:Int, b:Int, c:Int, d:Int, h:Int, v:Dynamic):Void {
		final e = used++;
		if (e >= C && (e & (C - 1)) == 0) {
			if (chunkKeys == null) {
				chunkKeys = [];
				chunkVals = [];
			}
			chunkKeys.push(new MapSlots<Int>(W * C));
			chunkVals.push(new RefSlots(C));
		}
		final keys = keysOf(e), o = W * (e & (C - 1));
		keys[o] = a;
		keys[o + 1] = b;
		keys[o + 2] = c;
		keys[o + 3] = d;
		valsOf(e)[e & (C - 1)] = v;
		index(tag(h, n), e, h);
	}

	inline function index(t:Int, e:Int, h:Int):Void {
		final slots = this.slots, mask = this.mask;
		var i = h & mask;
		while (slots[2 * i + 1] != 0)
			i = (i + 1) & mask;
		slots[2 * i] = t;
		slots[2 * i + 1] = e + 1;
	}

	// the index with cap slots (room for cap / 2 entries); the flat arrays grown up to C entries (the chunks stay)
	function rebuild(cap:Int):Void {
		final oslots = slots, ocap = mask + 1;
		final room = cap >> 1, flat = room < C ? room : C;
		if (keys == null || flat > ocap >> 1) {
			final okeys = keys, ovals = vals, on = used < C ? used : C;
			keys = new MapSlots<Int>(W * flat);
			vals = new RefSlots(flat);
			for (j in 0...on) {
				final o = W * j;
				keys[o] = okeys[o];
				keys[o + 1] = okeys[o + 1];
				keys[o + 2] = okeys[o + 2];
				keys[o + 3] = okeys[o + 3];
				vals[j] = ovals[j];
			}
		}
		slots = new MapSlots<Int>(2 * cap);
		mask = cap - 1;
		// the entries indexed again from the old index (its tags keep their lengths; the hash from the key)
		for (i in 0...(used > 0 ? ocap : 0)) {
			final e1 = oslots[2 * i + 1];
			if (e1 != 0) {
				final e = e1 - 1, t = oslots[2 * i], n = t & 15;
				final keys = keysOf(e), o = W * (e & (C - 1));
				index(t, e, mix(n, keys[o], keys[o + 1], keys[o + 2], keys[o + 3]));
			}
		}
	}
}
#else
typedef HashKeyMap<T> = haxe.ds.StringMap<T>;
#end
