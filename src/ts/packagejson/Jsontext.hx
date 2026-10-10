package ts.packagejson;

// PORT: stand-in for go-json-experiment's jsontext.Decoder, which packagejson uses through
// json.Unmarshal / json.UnmarshalDecode and the UnmarshalJSONFrom / UnmarshalJSON methods.
// ts.json.Json is a thin layer over haxe.Json, which loses object key order on hxcpp and lists
// integer-like keys first on JS; conditional exports depend on key order. So the text is read
// here into a small tree (Value) that keeps object members in document order, duplicates
// included. Each Go unmarshaler then reads its Value instead of decoder tokens / raw bytes.
//
// The grammar is strict RFC 8259 JSON, like jsontext with default options: no comments, no
// trailing commas, exactly one top-level value, control characters in strings and broken
// \u surrogate escapes are errors. Haxe strings are UTF-16, so Go's invalid-UTF-8 check is
// a check for unpaired surrogates in the input.
class Jsontext {
	// Parses `text` as a single JSON value. Returns (nil, err) on a syntax error.
	public static function Parse(text:String):ValueError<Value> {
		final d = new Decoder(text);
		try {
			d.skipSpace();
			final v = d.readValue();
			d.skipSpace();
			if (d.pos < text.length)
				d.syntaxError("invalid character after top-level value");
			return new ValueError<Value>(v, null);
		} catch (e:SyntaxError) {
			return new ValueError<Value>(null, Errors.New(e.message));
		}
	}
}

// PORT: one decoded JSON value. Kind uses the jsontext.Kind characters:
// 'n' null, 'f' false, 't' true, '"' string, '0' number, '[' array, '{' object.
class Value {
	public var Kind:Int = 0;
	// String value ('"'), or the literal text of a number ('0').
	public var Str:String = "";
	// Number value ('0').
	public var Num:Float = 0.0;
	// Array elements ('[').
	public var Items:Null<Array<Value>> = null;
	// Object member names and values in document order ('{'); duplicates are kept.
	public var Names:Null<Array<String>> = null;
	public var Members:Null<Array<Value>> = null;
	// Offsets of the value's text in the input (jsontext.Value raw bytes).
	public var Start:Int = 0;
	public var End:Int = 0;

	public function new(kind:Int) {
		this.Kind = kind;
	}
}

private class SyntaxError {
	public final message:String;

	public function new(message:String) {
		this.message = message;
	}
}

private class Decoder {
	final s:String;

	public var pos:Int = 0;

	public function new(s:String) {
		this.s = s;
	}

	public function syntaxError(msg:String):Void {
		throw new SyntaxError("jsontext: " + msg + " at offset " + pos);
	}

	inline function peek():Int {
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

	public function readValue():Value {
		final start = pos;
		final v = readValueWorker();
		v.Start = start;
		v.End = pos;
		return v;
	}

	function readValueWorker():Value {
		final c = peek();
		switch (c) {
			case "{".code:
				return readObject();
			case "[".code:
				return readArray();
			case '"'.code:
				final v = new Value('"'.code);
				v.Str = readString();
				return v;
			case "n".code:
				readLiteral("null");
				return new Value("n".code);
			case "t".code:
				readLiteral("true");
				return new Value("t".code);
			case "f".code:
				readLiteral("false");
				return new Value("f".code);
			case -1:
				syntaxError("unexpected EOF");
				return null;
			default:
				if (c == "-".code || (c >= "0".code && c <= "9".code))
					return readNumber();
				syntaxError("invalid character '" + String.fromCharCode(c) + "' at start of value");
				return null;
		}
	}

	function readLiteral(lit:String):Void {
		if (s.substr(pos, lit.length) != lit)
			syntaxError("invalid literal");
		pos += lit.length;
	}

	function readObject():Value {
		final v = new Value("{".code);
		v.Names = [];
		v.Members = [];
		pos++; // '{'
		skipSpace();
		if (peek() == "}".code) {
			pos++;
			return v;
		}
		while (true) {
			skipSpace();
			if (peek() != '"'.code)
				syntaxError("missing string for object name");
			final name = readString();
			skipSpace();
			if (peek() != ":".code)
				syntaxError("missing character ':' after object name");
			pos++;
			skipSpace();
			final member = readValue();
			v.Names.push(name);
			v.Members.push(member);
			skipSpace();
			final c = peek();
			if (c == ",".code) {
				pos++;
				continue;
			}
			if (c == "}".code) {
				pos++;
				return v;
			}
			syntaxError("missing character ',' or '}' after object value");
		}
	}

	function readArray():Value {
		final v = new Value("[".code);
		v.Items = [];
		pos++; // '['
		skipSpace();
		if (peek() == "]".code) {
			pos++;
			return v;
		}
		while (true) {
			skipSpace();
			v.Items.push(readValue());
			skipSpace();
			final c = peek();
			if (c == ",".code) {
				pos++;
				continue;
			}
			if (c == "]".code) {
				pos++;
				return v;
			}
			syntaxError("missing character ',' or ']' after array value");
		}
	}

	static inline function isDigit(c:Int):Bool {
		return c >= "0".code && c <= "9".code;
	}

	function readNumber():Value {
		final start = pos;
		if (peek() == "-".code)
			pos++;
		if (peek() == "0".code) {
			pos++;
		} else if (isDigit(peek()) && peek() != "0".code) {
			while (isDigit(peek()))
				pos++;
		} else {
			syntaxError("invalid number");
		}
		if (peek() == ".".code) {
			pos++;
			if (!isDigit(peek()))
				syntaxError("invalid number");
			while (isDigit(peek()))
				pos++;
		}
		if (peek() == "e".code || peek() == "E".code) {
			pos++;
			if (peek() == "+".code || peek() == "-".code)
				pos++;
			if (!isDigit(peek()))
				syntaxError("invalid number");
			while (isDigit(peek()))
				pos++;
		}
		final v = new Value("0".code);
		v.Str = s.substring(start, pos);
		v.Num = Std.parseFloat(v.Str);
		// Go: a number that does not fit a float64 cannot be unmarshaled.
		if (!Math.isFinite(v.Num))
			syntaxError("number out of range");
		return v;
	}

	static function hexValue(c:Int):Int {
		if (c >= "0".code && c <= "9".code)
			return c - "0".code;
		if (c >= "a".code && c <= "f".code)
			return c - "a".code + 10;
		if (c >= "A".code && c <= "F".code)
			return c - "A".code + 10;
		return -1;
	}

	// Reads 4 hex digits at pos; -1 if invalid or too short.
	function readHex4():Int {
		if (pos + 4 > s.length)
			return -1;
		var r = 0;
		for (i in 0...4) {
			final h = hexValue(StringTools.fastCodeAt(s, pos + i));
			if (h < 0)
				return -1;
			r = (r << 4) | h;
		}
		pos += 4;
		return r;
	}

	// Reads a string literal at pos (which is at the opening quote) and returns its value.
	// Escapes are decoded to code points before they are appended (PORTING.md §5).
	function readString():String {
		pos++; // opening quote
		var b:Null<StringBuf> = null;
		var runStart = pos;
		while (true) {
			if (pos >= s.length)
				syntaxError("unexpected EOF in string");
			final c = StringTools.fastCodeAt(s, pos);
			if (c == '"'.code) {
				final run = s.substring(runStart, pos);
				pos++;
				if (b == null)
					return run;
				b.add(run);
				return b.toString();
			}
			if (c < 0x20)
				syntaxError("invalid character in string (expecting non-control character)");
			if (c >= 0xD800 && c <= 0xDBFF) {
				// A valid surrogate pair stands for a valid UTF-8 sequence in Go.
				if (pos + 1 < s.length) {
					final c2 = StringTools.fastCodeAt(s, pos + 1);
					if (c2 >= 0xDC00 && c2 <= 0xDFFF) {
						pos += 2;
						continue;
					}
				}
				syntaxError("invalid UTF-8 within string");
			}
			if (c >= 0xDC00 && c <= 0xDFFF)
				syntaxError("invalid UTF-8 within string");
			if (c != "\\".code) {
				pos++;
				continue;
			}
			if (b == null)
				b = new StringBuf();
			b.add(s.substring(runStart, pos));
			pos++; // backslash
			if (pos >= s.length)
				syntaxError("unexpected EOF in string");
			final e = StringTools.fastCodeAt(s, pos);
			pos++;
			switch (e) {
				case '"'.code:
					b.addChar('"'.code);
				case "\\".code:
					b.addChar("\\".code);
				case "/".code:
					b.addChar("/".code);
				case "b".code:
					b.addChar(8);
				case "f".code:
					b.addChar(12);
				case "n".code:
					b.addChar("\n".code);
				case "r".code:
					b.addChar("\r".code);
				case "t".code:
					b.addChar("\t".code);
				case "u".code:
					final v1 = readHex4();
					if (v1 < 0)
						syntaxError("invalid escape sequence in string");
					if (v1 >= 0xD800 && v1 <= 0xDFFF) {
						// Go: a surrogate half must be followed by the other half, else it is an error.
						var ok = false;
						if (v1 <= 0xDBFF && pos + 1 < s.length && StringTools.fastCodeAt(s, pos) == "\\".code
							&& StringTools.fastCodeAt(s, pos + 1) == "u".code) {
							pos += 2;
							final v2 = readHex4();
							if (v2 >= 0xDC00 && v2 <= 0xDFFF) {
								b.addChar(0x10000 + ((v1 - 0xD800) << 10) + (v2 - 0xDC00));
								ok = true;
							}
						}
						if (!ok)
							syntaxError("invalid escape sequence in string");
					} else {
						b.addChar(v1);
					}
				default:
					syntaxError("invalid escape sequence in string");
			}
			runStart = pos;
		}
	}
}
