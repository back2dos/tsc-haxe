package ts.json;

// Port of internal/json.
// PORT: Go wraps the reflection-based go-json-experiment library. In scope, only packagejson,
// sourcemap, buildinfo and jsnum use it. We map it to haxe.Json; each call site decodes its own
// types from the Dynamic value. Go `[]byte` in/out → String.
class Json {
	public static function Marshal(value:Any):String {
		return haxe.Json.stringify(value);
	}

	public static function MarshalIndent(value:Any, prefix:String, indent:String):String {
		if (prefix == "" && indent == "")
			return Marshal(value);
		if (prefix != "")
			throw "Json.MarshalIndent: prefix not supported"; // PORT: unused in scope
		return haxe.Json.stringify(value, null, indent);
	}

	// PORT: Go fills `out`; we return the decoded value. Throws on invalid input (Go returns err).
	public static function Unmarshal(text:String):Dynamic {
		return haxe.Json.parse(text);
	}

	// --- Go-compatible ordered marshalling (added for tsoptions; not in Go's internal/json) ---
	//
	// PORT: haxe.Json cannot reproduce Go's output (key order is undefined on hxcpp, escaping and
	// number formatting differ). These functions marshal an ordered value tree exactly like
	// go-json-experiment (json v2) with the defaults of internal/json:
	//   null → null; Bool; Int; Float (Go float64 formatting, see FormatFloat); String (see Quote);
	//   Array<Dynamic> → array (Go marshals nil slices as [], so callers pass [] for them);
	//   ts.collections.OrderedMap<String, Dynamic> → object in insertion order;
	//   OrderedMarshaler → the tree returned by MarshalJSONValue() (Go structs with json tags).
	// A null OrderedMap value inside a tree is `null` (Go nil pointer / nil interface).

	public static function MarshalOrdered(value:Dynamic):String {
		final b = new StringBuf();
		appendOrdered(b, value, "", "", 0);
		return b.toString();
	}

	// Go json.MarshalIndent: prefix starts every line after the first, indent per level.
	public static function MarshalIndentOrdered(value:Dynamic, prefix:String, indent:String):String {
		if (prefix == "" && indent == "")
			return MarshalOrdered(value);
		final b = new StringBuf();
		appendOrdered(b, value, prefix, indent, 0);
		return b.toString();
	}

	static function appendNewline(b:StringBuf, prefix:String, indent:String, depth:Int):Void {
		b.add("\n");
		b.add(prefix);
		for (_ in 0...depth)
			b.add(indent);
	}

	static function appendOrdered(b:StringBuf, value:Dynamic, prefix:String, indent:String, depth:Int):Void {
		final multiline = prefix != "" || indent != "";
		if (value == null) {
			b.add("null");
		} else if (Std.isOfType(value, OrderedMarshaler)) {
			appendOrdered(b, (value : OrderedMarshaler).MarshalJSONValue(), prefix, indent, depth);
		} else if (Std.isOfType(value, Bool)) {
			b.add((value : Bool) ? "true" : "false");
		} else if (Std.isOfType(value, std.String)) {
			b.add(Quote(value));
		} else if (Std.isOfType(value, Int)) {
			b.add(Std.string((value : Int)));
		} else if (Std.isOfType(value, Float)) {
			b.add(FormatFloat((value : Float)));
		} else if (Std.isOfType(value, Array)) {
			final a:Array<Dynamic> = value;
			if (a.length == 0) {
				b.add("[]");
				return;
			}
			b.add("[");
			for (i in 0...a.length) {
				if (i > 0)
					b.add(",");
				if (multiline)
					appendNewline(b, prefix, indent, depth + 1);
				appendOrdered(b, a[i], prefix, indent, depth + 1);
			}
			if (multiline)
				appendNewline(b, prefix, indent, depth);
			b.add("]");
		} else if (Std.isOfType(value, ts.collections.OrderedMap)) {
			final m:ts.collections.OrderedMap<Dynamic, Dynamic> = value;
			if (m.Size() == 0) {
				b.add("{}");
				return;
			}
			b.add("{");
			var first = true;
			for (k => v in m.Entries()) {
				if (!first)
					b.add(",");
				first = false;
				if (multiline)
					appendNewline(b, prefix, indent, depth + 1);
				b.add(Quote(Std.isOfType(k, std.String) ? (k : std.String) : Std.string(k)));
				b.add(multiline ? ": " : ":");
				appendOrdered(b, v, prefix, indent, depth + 1);
			}
			if (multiline)
				appendNewline(b, prefix, indent, depth);
			b.add("}");
		} else {
			throw "json: cannot marshal " + Std.string(value);
		}
	}

	// Go JSON string quoting: `"` and `\` are escaped, \b \t \n \f \r use the short form, other
	// control characters are \u00xx (lowercase hex). `<`, `>`, `&`, DEL, U+2028 and U+2029 are
	// written as is.
	public static function Quote(s:String):String {
		final b = new StringBuf();
		b.add('"');
		var start = 0;
		for (i in 0...s.length) {
			final c = StringTools.fastCodeAt(s, i);
			if (c >= 0x20 && c != '"'.code && c != "\\".code)
				continue;
			if (i > start)
				b.add(s.substring(start, i));
			start = i + 1;
			switch (c) {
				case '"'.code:
					b.add('\\"');
				case "\\".code:
					b.add("\\\\");
				case 0x08:
					b.add("\\b");
				case 0x09:
					b.add("\\t");
				case 0x0A:
					b.add("\\n");
				case 0x0C:
					b.add("\\f");
				case 0x0D:
					b.add("\\r");
				default:
					b.add("\\u00");
					b.add(StringTools.hex(c >> 4).toLowerCase());
					b.add(StringTools.hex(c & 0xF).toLowerCase());
			}
		}
		if (start < s.length)
			b.add(s.substring(start));
		b.add('"');
		return b.toString();
	}

	// Go JSON float64 formatting: shortest round-trip digits, 'f' format for 1e-6 <= |f| < 1e21,
	// else 'e' format with a one-digit negative exponent cleaned up (1e-07 → 1e-7).
	public static function FormatFloat(f:Float):String {
		if (Math.isNaN(f) || !Math.isFinite(f))
			throw "json: unsupported value: " + Std.string(f);
		final abs = Math.abs(f);
		var fmt = "f".code;
		if (abs != 0 && (abs < 1e-6 || abs >= 1e21))
			fmt = "e".code;
		var s = go.Strconv.FormatFloat(f, fmt, -1, 64);
		if (fmt == "e".code) {
			// clean up e-09 to e-9
			final n = s.length;
			if (n >= 4 && s.charAt(n - 4) == "e" && s.charAt(n - 3) == "-" && s.charAt(n - 2) == "0") {
				s = s.substring(0, n - 2) + s.charAt(n - 1);
			}
		}
		return s;
	}

	// --- Go-compatible ordered unmarshalling (added for execute/incremental; not in Go's internal/json) ---
	//
	// PORT: json.Unmarshal into Go `any` / structs keeps object member order where the Go target is
	// ordered (collections.OrderedMap). haxe.Json does not keep key order on hxcpp. This decoder
	// returns a value tree: object → ts.collections.OrderedMap<String, Dynamic> (document order),
	// array → Array<Dynamic>, number → Float (Go float64), string, Bool, null.
	// Invalid JSON (syntax error, trailing data, duplicate object member names as in json v2)
	// throws a String (Go returns an error).
	public static function UnmarshalOrdered(text:String):Dynamic {
		final d = new OrderedDecoder(text);
		d.skipSpace();
		final v = d.value();
		d.skipSpace();
		if (d.pos != text.length)
			throw "json: invalid character after top-level value";
		return v;
	}

}

// PORT: a Go value with its own JSON form (a struct with json tags): MarshalJSONValue returns
// the ordered tree (see Json.MarshalOrdered) to marshal in its place.
interface OrderedMarshaler {
	function MarshalJSONValue():Dynamic;
}

// PORT: recursive-descent JSON decoder for Json.UnmarshalOrdered (RFC 8259 syntax).
private class OrderedDecoder {
	final s:String;
	public var pos:Int = 0;

	public function new(s:String) {
		this.s = s;
	}

	inline function peek():Int {
		return pos < s.length ? StringTools.fastCodeAt(s, pos) : -1;
	}

	public function skipSpace():Void {
		while (pos < s.length) {
			final c = StringTools.fastCodeAt(s, pos);
			if (c == " ".code || c == "\t".code || c == "\n".code || c == "\r".code)
				pos++;
			else
				break;
		}
	}

	function fail(msg:String):Dynamic {
		throw "json: " + msg + " at offset " + pos;
	}

	public function value():Dynamic {
		final c = peek();
		switch (c) {
			case "{".code:
				pos++;
				final m = new ts.collections.OrderedMap<String, Dynamic>();
				skipSpace();
				if (peek() == "}".code) {
					pos++;
					return m;
				}
				while (true) {
					skipSpace();
					if (peek() != '"'.code)
						return fail("expected object member name");
					final k = string();
					if (m.Has(k))
						return fail("duplicate object member name " + Json.Quote(k));
					skipSpace();
					if (peek() != ":".code)
						return fail("expected ':'");
					pos++;
					skipSpace();
					m.Set(k, value());
					skipSpace();
					final e = peek();
					pos++;
					if (e == "}".code)
						return m;
					if (e != ",".code)
						return fail("expected ',' or '}'");
				}
			case "[".code:
				pos++;
				final a:Array<Dynamic> = [];
				skipSpace();
				if (peek() == "]".code) {
					pos++;
					return a;
				}
				while (true) {
					skipSpace();
					a.push(value());
					skipSpace();
					final e = peek();
					pos++;
					if (e == "]".code)
						return a;
					if (e != ",".code)
						return fail("expected ',' or ']'");
				}
			case '"'.code:
				return string();
			case "t".code:
				return literal("true", true);
			case "f".code:
				return literal("false", false);
			case "n".code:
				return literal("null", null);
			default:
				if (c == "-".code || (c >= "0".code && c <= "9".code))
					return number();
				return fail("invalid character");
		}
	}

	function literal(word:String, v:Dynamic):Dynamic {
		if (s.substr(pos, word.length) != word)
			return fail("invalid literal");
		pos += word.length;
		return v;
	}

	function digits():Int {
		final start = pos;
		while (pos < s.length) {
			final c = StringTools.fastCodeAt(s, pos);
			if (c < "0".code || c > "9".code)
				break;
			pos++;
		}
		return pos - start;
	}

	function number():Float {
		final start = pos;
		if (peek() == "-".code)
			pos++;
		if (peek() == "0".code) {
			pos++;
		} else if (digits() == 0) {
			return fail("invalid number");
		}
		if (peek() == ".".code) {
			pos++;
			if (digits() == 0)
				return fail("invalid number");
		}
		if (peek() == "e".code || peek() == "E".code) {
			pos++;
			if (peek() == "+".code || peek() == "-".code)
				pos++;
			if (digits() == 0)
				return fail("invalid number");
		}
		return Std.parseFloat(s.substring(start, pos));
	}

	function hex4():Int {
		if (pos + 4 > s.length)
			return fail("invalid escape");
		var v = 0;
		for (i in 0...4) {
			final c = StringTools.fastCodeAt(s, pos + i);
			var d:Int;
			if (c >= "0".code && c <= "9".code)
				d = c - "0".code;
			else if (c >= "a".code && c <= "f".code)
				d = c - "a".code + 10;
			else if (c >= "A".code && c <= "F".code)
				d = c - "A".code + 10;
			else
				return fail("invalid escape");
			v = (v << 4) | d;
		}
		pos += 4;
		return v;
	}

	function string():String {
		pos++; // opening quote
		final b = new StringBuf();
		var start = pos;
		while (true) {
			if (pos >= s.length)
				return fail("unterminated string");
			final c = StringTools.fastCodeAt(s, pos);
			if (c == '"'.code) {
				b.add(s.substring(start, pos));
				pos++;
				return b.toString();
			}
			if (c < 0x20)
				return fail("invalid control character in string");
			if (c != "\\".code) {
				pos++;
				continue;
			}
			b.add(s.substring(start, pos));
			pos++;
			final e = peek();
			pos++;
			switch (e) {
				case '"'.code:
					b.add('"');
				case "\\".code:
					b.add("\\");
				case "/".code:
					b.add("/");
				case "b".code:
					b.add("\x08");
				case "f".code:
					b.add("\x0C");
				case "n".code:
					b.add("\n");
				case "r".code:
					b.add("\r");
				case "t".code:
					b.add("\t");
				case "u".code:
					var r = hex4();
					// Combine a surrogate pair into one code point before appending (PORTING §5).
					if (r >= 0xD800 && r < 0xDC00 && s.substr(pos, 2) == "\\u") {
						final save = pos;
						pos += 2;
						final r2 = hex4();
						if (r2 >= 0xDC00 && r2 < 0xE000) {
							r = 0x10000 + ((r - 0xD800) << 10) + (r2 - 0xDC00);
						} else {
							pos = save;
						}
					}
					if (r >= 0xD800 && r < 0xE000)
						r = 0xFFFD; // Go replaces an invalid surrogate with U+FFFD
					b.add(go.Utf16.RuneString(r));
				default:
					return fail("invalid escape");
			}
			start = pos;
		}
	}
}
