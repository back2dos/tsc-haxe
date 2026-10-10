package go;

import haxe.Constraints.IMap;

// Go builtin `map[K]V` for code that is generic over K.
// PORT: Haxe `Map<K, V>` cannot be constructed inside a class or function body that is generic
// over K — not even with @:generic (tested on Haxe 4.3.7 and 5.0.0-preview.1: "Abstract
// haxe.ds.Map has no @:to function that accepts haxe.IMap<G.K, G.V>"). GoMap picks the backing
// map at run time from the first key that is stored:
//   String (and abstracts over String)  → haxe.ds.StringMap
//   Int (and abstracts over Int)        → haxe.ds.IntMap
//   anything else (class instances)     → haxe.ds.ObjectMap, keyed by identity like Go *T
// Not supported (throw): null keys, Float keys with a fraction, Bool keys, struct-valued keys
// (Go compares structs by value; encode them as a String key instead).
// The map is created lazily: an empty GoMap behaves like a Go nil map for reads.
// Unlike Go, iteration order is deterministic; upstream never depends on map order.
class GoMap<K, V> {
	var m:Null<IMap<K, V>> = null;
	var n:Int = 0;

	public function new() {}

	// len(m)
	public inline function length():Int {
		return n;
	}

	// _, ok := m[key]
	public inline function exists(key:K):Bool {
		return m != null && m.exists(key);
	}

	// m[key]; null when absent (Go returns the zero value).
	public inline function get(key:K):Null<V> {
		return m == null ? null : m.get(key);
	}

	// m[key] = value
	public function set(key:K, value:V):Void {
		if (m == null)
			m = newBacking(key);
		if (!m.exists(key))
			n++;
		m.set(key, value);
	}

	// delete(m, key); returns whether the key was present.
	public function remove(key:K):Bool {
		if (m == null || !m.remove(key))
			return false;
		n--;
		return true;
	}

	// for k := range m
	public function keys():Iterator<K> {
		return m == null ? cast EmptyIterator.instance : m.keys();
	}

	// for _, v := range m
	public function iterator():Iterator<V> {
		return m == null ? cast EmptyIterator.instance : m.iterator();
	}

	// clear(m)
	public function clear():Void {
		if (m != null)
			m.clear();
		n = 0;
	}

	// maps.Clone for a non-nil map.
	public function copy():GoMap<K, V> {
		final c = new GoMap<K, V>();
		if (m != null) {
			c.m = m.copy();
			c.n = n;
		}
		return c;
	}

	static function newBacking<K, V>(key:K):IMap<K, V> {
		final k:Any = key;
		if (k == null)
			throw "GoMap: null key not supported";
		if (Std.isOfType(k, String))
			return cast new haxe.ds.StringMap<V>();
		if (Std.isOfType(k, Int))
			return cast new haxe.ds.IntMap<V>();
		if (Std.isOfType(k, Float) || Std.isOfType(k, Bool))
			throw "GoMap: key type not supported: " + Std.string(k);
		return cast new haxe.ds.ObjectMap<{}, V>();
	}
}

private class EmptyIterator {
	public static final instance = new EmptyIterator();

	function new() {}

	public inline function hasNext():Bool {
		return false;
	}

	public inline function next():Dynamic {
		return null;
	}
}
