package ts.collections;

// Port of ordered_map.go (types and methods; package-level funcs are in Collections.hx).
//
// PORT: zero value — Haxe cannot produce Go's `var zero V` for a type parameter (JS has no
// types at run time). The constructor takes the zero value of V: `new OrderedMap<K, V>(zero)`.
// It defaults to null, which is the Go zero value for pointers, slices, maps and `any`.
// For V = String / Int / Float / Bool pass "" / 0 / 0.0 / false where Go code reads the zero
// value of a missing key (Get, GetOrZero, Delete). The zero value of K (EntryAt out of range)
// is always null.
//
// PORT: nil receiver — Keys, Values, Entries, Size and Clone are `inline` and test
// `this == null`, like the Go `m == nil` checks. A Go zero-value `OrderedMap[K, V]` (field or
// local var) is `new OrderedMap<K, V>()` in Haxe.
//
// PORT: iter.Seq / iter.Seq2 — Keys() and Values() return a live index-based iterator object
// (`for (k in m.Keys())`); Entries() returns an iterator for `for (k => v in m.Entries())`.
// Like Go they read the current keys on each step, so items added during iteration are seen.
// Use `Slices.Collect(m.Keys())` for Go `slices.Collect`.
//
// PORT: `_ noCopy` is a `go vet` marker only; omitted.
class OrderedMap<K, V> {
	var keys:Null<Array<K>> = null;
	var mp:Null<GoMap<K, V>> = null;

	// PORT: Go zero value of V (see above).
	final zero:Null<V>;

	public function new(?zero:V) {
		this.zero = zero;
	}

	// Set sets a key-value pair in the map.
	public function Set(key:K, value:V):Void {
		if (mp == null) {
			mp = new GoMap<K, V>();
		}

		if (!mp.exists(key)) {
			if (keys == null)
				keys = [];
			keys.push(key);
		}
		mp.set(key, value);
	}

	// Get retrieves a value from the map.
	public function Get(key:K):ValueOk<V> {
		if (mp != null && mp.exists(key))
			return new ValueOk<V>(mp.get(key), true);
		return new ValueOk<V>(zero, false);
	}

	// GetOrZero retrieves a value from the map, or returns the zero value of the value type if the key is not present.
	public function GetOrZero(key:K):V {
		if (mp != null) {
			final v = mp.get(key);
			if (v != null || mp.exists(key))
				return v;
		}
		return zero;
	}

	// EntryAt retrieves the key-value pair at the specified index.
	public function EntryAt(index:Int):Triple<K, V, Bool> {
		if (index < 0 || index >= len(keys)) {
			final zero:K = null;
			final zeroV = this.zero;
			return new Triple<K, V, Bool>(zero, zeroV, false);
		}

		final key = keys[index];
		final value = mp.get(key);
		return new Triple<K, V, Bool>(key, value, true);
	}

	// Has returns true if the map contains the key.
	public function Has(key:K):Bool {
		return mp != null && mp.exists(key);
	}

	// Delete removes a key-value pair from the map.
	public function Delete(key:K):ValueOk<V> {
		if (mp == null || !mp.exists(key)) {
			return new ValueOk<V>(zero, false);
		}
		final v = mp.get(key);

		mp.remove(key);
		final i = keys.indexOf(key);
		// If we're just removing the first or last element, avoid shifting everything around.
		final end = keys.length - 1;
		if (i == 0) {
			keys.shift();
		} else if (i == end) {
			keys.pop();
		} else {
			keys.splice(i, 1);
		}

		return new ValueOk<V>(v, true);
	}

	// Keys returns an iterator over the keys in the map.
	// A slice of the keys can be obtained by calling `slices.Collect`.
	public inline function Keys():OrderedMapKeys<K, V> {
		return new OrderedMapKeys<K, V>(this);
	}

	// Values returns an iterator over the values in the map.
	// A slice of the values can be obtained by calling `slices.Collect`.
	public inline function Values():OrderedMapValues<K, V> {
		return new OrderedMapValues<K, V>(this);
	}

	// Entries returns an iterator over the key-value pairs in the map.
	public inline function Entries():OrderedMapEntries<K, V> {
		return new OrderedMapEntries<K, V>(this);
	}

	// Clear removes all key-value pairs from the map.
	// The space allocated for the map will be reused.
	public function Clear():Void {
		if (keys != null)
			keys.resize(0);
		if (mp != null)
			mp.clear();
	}

	// Size returns the number of key-value pairs in the map.
	public inline function Size():Int {
		return this == null ? 0 : len(keys);
	}

	// Clone returns a shallow copy of the map.
	public inline function Clone():Null<OrderedMap<K, V>> {
		return this == null ? null : this.clone();
	}

	@:allow(ts.collections)
	function clone():OrderedMap<K, V> {
		final m2 = new OrderedMap<K, V>(zero);
		m2.keys = keys == null ? null : keys.copy();
		m2.mp = Maps.Clone(mp);
		return m2;
	}

	// PORT: Go implements json.MarshalerTo with a token Encoder. Here the encoder is a StringBuf
	// that receives compact JSON. Keys are written in insertion order. Values: nested
	// OrderedMaps and arrays are encoded recursively, everything else with ts.json.Json.Marshal.
	public function MarshalJSONTo(enc:StringBuf):Null<Error> {
		enc.add("{");

		if (keys != null) {
			for (i in 0...keys.length) {
				final k = keys[i];
				// TODO: is this needed? Can we just MarshalEncode k directly?
				final keyString = resolveKeyName(k);
				if (keyString.err != null) {
					return keyString.err;
				}

				if (i > 0)
					enc.add(",");
				enc.add(Json.Marshal(keyString.value));
				enc.add(":");

				final err = marshalEncode(enc, mp.get(k));
				if (err != null) {
					return err;
				}
			}
		}

		enc.add("}");
		return null;
	}

	// PORT: json.MarshalEncode for a value inside an OrderedMap (see MarshalJSONTo).
	static function marshalEncode(enc:StringBuf, v:Dynamic):Null<Error> {
		if (Std.isOfType(v, OrderedMap)) {
			final m:OrderedMap<Dynamic, Dynamic> = v;
			return m.MarshalJSONTo(enc);
		}
		if (Std.isOfType(v, Array)) {
			final a:Array<Dynamic> = v;
			enc.add("[");
			for (i in 0...a.length) {
				if (i > 0)
					enc.add(",");
				final err = marshalEncode(enc, a[i]);
				if (err != null)
					return err;
			}
			enc.add("]");
			return null;
		}
		enc.add(Json.Marshal(v));
		return null;
	}

	// PORT: Go uses reflect; encoding.TextMarshaler keys are not supported.
	static function resolveKeyName(k:Any):ValueError<String> {
		if (Std.isOfType(k, String)) {
			return new ValueError<String>(k, null);
		}
		if (Std.isOfType(k, Int)) {
			return new ValueError<String>(Std.string(k), null);
		}
		throw "unexpected map key type";
	}

	// PORT: Go implements json.UnmarshalerFrom with a token Decoder. Here `dec` is the JSON text
	// of the value. The top-level object is scanned here so keys keep document order (haxe.Json
	// does not keep object key order on hxcpp, and lists integer-like keys first on JS); each
	// member value is decoded with ts.json.Json.Unmarshal (nested objects come back as anonymous
	// structures, like Go `any` → map[string]any). Keys are stored as Strings: K must be String
	// (Go reports an error for e.g. K = int; type parameters are erased in Haxe).
	// Invalid JSON returns an error (Go: the decoder's syntax error).
	public function UnmarshalJSONFrom(dec:String):Null<Error> {
		final d = new ObjectScanner(dec);
		d.skipSpace();
		if (StringTools.startsWith(dec.substr(d.pos), "null")) { // json.Null.Kind()
			// By convention, to approximate the behavior of Unmarshal itself,
			// Unmarshalers implement UnmarshalJSON([]byte("null")) as a no-op.
			// https://pkg.go.dev/encoding/json#Unmarshaler
			// TODO: reconsider
			return null;
		}
		if (d.peek() != "{".code) { // json.ObjectStart.Kind()
			return Errors.New("cannot unmarshal non-object JSON value into Map");
		}
		d.pos++;
		d.skipSpace();
		if (d.peek() == "}".code) // json.ObjectEnd.Kind()
			return null;
		while (true) {
			d.skipSpace();
			final rawKey = d.value();
			d.skipSpace();
			if (rawKey == null || StringTools.fastCodeAt(rawKey, 0) != '"'.code || d.peek() != ":".code)
				return Errors.New("json: invalid object member in Map");
			d.pos++;
			d.skipSpace();
			final rawValue = d.value();
			if (rawValue == null)
				return Errors.New("json: invalid value in Map");
			var key:K;
			var value:V;
			try {
				key = cast Json.Unmarshal(rawKey);
				value = Json.Unmarshal(rawValue);
			} catch (e:Dynamic) {
				return Errors.New("json: " + Std.string(e));
			}
			this.Set(key, value);
			d.skipSpace();
			final c = d.peek();
			d.pos++;
			if (c == "}".code)
				break;
			if (c != ",".code)
				return Errors.New("json: expected ',' or '}' in Map");
		}
		return null;
	}

	// PORT: len() of a possibly-nil slice.
	static inline function len<T>(s:Null<Array<T>>):Int {
		return s == null ? 0 : s.length;
	}

	@:allow(ts.collections)
	inline function keyAt(i:Int):K {
		return keys[i];
	}

	@:allow(ts.collections)
	inline function valueOf(key:K):V {
		return mp.get(key);
	}
}

// Go `MapEntry[K, V]`.
class MapEntry<K, V> {
	public var Key:K;
	public var Value:V;

	public function new(Key:K, Value:V) {
		this.Key = Key;
		this.Value = Value;
	}
}

// PORT: iter.Seq[K] returned by OrderedMap.Keys.
class OrderedMapKeys<K, V> {
	final m:Null<OrderedMap<K, V>>;
	var i:Int = 0;

	public inline function new(m:Null<OrderedMap<K, V>>) {
		this.m = m;
	}

	public inline function hasNext():Bool {
		return m != null && i < m.Size();
	}

	public inline function next():K {
		return m.keyAt(i++);
	}
}

// PORT: iter.Seq[V] returned by OrderedMap.Values.
class OrderedMapValues<K, V> {
	final m:Null<OrderedMap<K, V>>;
	var i:Int = 0;

	public inline function new(m:Null<OrderedMap<K, V>>) {
		this.m = m;
	}

	public inline function hasNext():Bool {
		return m != null && i < m.Size();
	}

	public inline function next():V {
		return m.valueOf(m.keyAt(i++));
	}
}

// PORT: iter.Seq2[K, V] returned by OrderedMap.Entries. Use `for (k => v in m.Entries())`.
// next() returns the iterator itself with `key` / `value` set (no allocation per entry);
// do not keep the returned object.
class OrderedMapEntries<K, V> {
	final m:Null<OrderedMap<K, V>>;
	var i:Int = 0;

	public var key:K;
	public var value:V;

	public inline function new(m:Null<OrderedMap<K, V>>) {
		this.m = m;
	}

	public inline function hasNext():Bool {
		return m != null && i < m.Size();
	}

	public inline function next():OrderedMapEntries<K, V> {
		key = m.keyAt(i++);
		value = m.valueOf(key);
		return this;
	}
}

// PORT: minimal stand-in for the json.Decoder tokens used by OrderedMap.UnmarshalJSONFrom:
// finds the extent of one JSON value (strings and nesting aware) without decoding it.
private class ObjectScanner {
	final s:String;

	public var pos:Int = 0;

	public function new(s:String) {
		this.s = s;
	}

	public inline function peek():Int {
		return pos < s.length ? StringTools.fastCodeAt(s, pos) : -1;
	}

	public function skipSpace():Void {
		while (pos < s.length) {
			final c = StringTools.fastCodeAt(s, pos);
			if (c != " ".code && c != "\t".code && c != "\n".code && c != "\r".code)
				break;
			pos++;
		}
	}

	// Returns the raw text of the value at pos and moves past it; null at end of input.
	public function value():Null<String> {
		final start = pos;
		var depth = 0;
		while (pos < s.length) {
			final c = StringTools.fastCodeAt(s, pos);
			if (c == '"'.code) {
				pos++;
				while (pos < s.length) {
					final q = StringTools.fastCodeAt(s, pos);
					pos++;
					if (q == "\\".code)
						pos++;
					else if (q == '"'.code)
						break;
				}
				if (depth == 0)
					return s.substring(start, pos);
				continue;
			}
			if (c == "{".code || c == "[".code) {
				depth++;
			} else if (c == "}".code || c == "]".code) {
				if (depth == 0)
					break;
				depth--;
				if (depth == 0) {
					pos++;
					return s.substring(start, pos);
				}
			} else if (depth == 0 && (c == ",".code || c == ":".code || c == " ".code || c == "\t".code || c == "\n".code
				|| c == "\r".code)) {
				break;
			}
			pos++;
		}
		return pos > start ? s.substring(start, pos) : null;
	}
}
