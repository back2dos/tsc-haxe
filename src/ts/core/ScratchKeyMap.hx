package ts.core;

// PORT: perf — a map from three Ints to an Int that keeps its table when cleared (Go's clear(m) keeps the buckets),
// for scratch maps emptied and filled again per use (the inference visited map: Go's map[InferenceKey]
// InferencePriority, a struct key; a key string per lookup on the other targets). Entries are numbered in insertion
// order and keep their number until clear: index finds a key's entry (-1: none), add appends one (the key must not be
// there), valueAt / setValueAt read and write its value. On hxmc: an open-addressing index of (hash, entry + 1)
// pairs and the entries' keys and values in Int arrays; clear empties the slots of the entries, and drops a table
// grown past BIG slots. Elsewhere: a StringMap of the entry numbers by key string.
#if (target.name == "hxmc")
import hxmc.rt.MapSlots;

class ScratchKeyMap {
	var slots:MapSlots<Int>; // cap slots of two: the key's hash and its entry + 1 (0: empty)
	var ents:MapSlots<Int>; // per entry (room = cap / 2): a, b, c, value
	var used:Int;
	var mask:Int; // cap - 1

	static inline final BIG = 1024;

	public function new() {
		used = 0;
		mask = -1;
	}

	static inline function hashOf(a:Int, b:Int, c:Int):Int {
		var h = (a ^ 0x165667B1) * 0x9E3779B1;
		h = (h ^ (h >>> 15) ^ b) * 0x85EBCA6B;
		h = (h ^ (h >>> 13) ^ c) * 0xC2B2AE35;
		return h ^ (h >>> 16);
	}

	public function index(a:Int, b:Int, c:Int):Int {
		if (used == 0)
			return -1;
		final slots = this.slots, ents = this.ents, mask = this.mask, h = hashOf(a, b, c);
		var i = h & mask;
		while (true) {
			final e = slots[2 * i + 1];
			if (e == 0)
				return -1;
			if (slots[2 * i] == h) {
				final o = 4 * (e - 1);
				if (ents[o] == a && ents[o + 1] == b && ents[o + 2] == c)
					return e - 1;
			}
			i = (i + 1) & mask;
		}
	}

	public inline function valueAt(e:Int):Int
		return ents[4 * e + 3];

	public inline function setValueAt(e:Int, v:Int):Void
		ents[4 * e + 3] = v;

	public function add(a:Int, b:Int, c:Int, v:Int):Int {
		if (used >= (mask + 1) >> 1)
			grow();
		return put(a, b, c, v, hashOf(a, b, c));
	}

	inline function put(a:Int, b:Int, c:Int, v:Int, h:Int):Int {
		final slots = this.slots, ents = this.ents, mask = this.mask;
		final e = used++;
		final o = 4 * e;
		ents[o] = a;
		ents[o + 1] = b;
		ents[o + 2] = c;
		ents[o + 3] = v;
		var i = h & mask;
		while (slots[2 * i + 1] != 0)
			i = (i + 1) & mask;
		slots[2 * i] = h;
		slots[2 * i + 1] = e + 1;
		return e;
	}

	function grow():Void {
		final oents = ents, on = used;
		final cap = mask < 0 ? 16 : 2 * (mask + 1);
		slots = new MapSlots<Int>(2 * cap);
		ents = new MapSlots<Int>(4 * (cap >> 1));
		used = 0;
		mask = cap - 1;
		for (j in 0...on) {
			final o = 4 * j;
			final a = oents[o], b = oents[o + 1], c = oents[o + 2];
			put(a, b, c, oents[o + 3], hashOf(a, b, c));
		}
	}

	public function clear():Void {
		if (used == 0)
			return;
		if (mask + 1 > BIG) {
			slots = null;
			ents = null;
			used = 0;
			mask = -1;
			return;
		}
		final slots = this.slots, ents = this.ents, mask = this.mask;
		for (j in 0...used) {
			final o = 4 * j;
			var i = hashOf(ents[o], ents[o + 1], ents[o + 2]) & mask;
			while (slots[2 * i + 1] != j + 1)
				i = (i + 1) & mask;
			slots[2 * i + 1] = 0;
		}
		used = 0;
	}
}
#else
class ScratchKeyMap {
	var byKey = new haxe.ds.StringMap<Int>();
	var values:Array<Int> = [];

	public function new() {}

	public function index(a:Int, b:Int, c:Int):Int {
		final e = byKey.get(go.MapKey.i3(a, b, c));
		return e == null ? -1 : e;
	}

	public inline function valueAt(e:Int):Int
		return values[e];

	public inline function setValueAt(e:Int, v:Int):Void
		values[e] = v;

	public function add(a:Int, b:Int, c:Int, v:Int):Int {
		final e = values.length;
		values.push(v);
		byKey.set(go.MapKey.i3(a, b, c), e);
		return e;
	}

	public function clear():Void {
		byKey.clear();
		values.resize(0);
	}
}
#end
