package python;

// PORT: python — the port keeps every Haxe String in UTF-16 form on Python (docs/PORTING.md §7b):
// a character above U+FFFF is stored as two surrogate code points, so `length`, `charCodeAt` and
// `substring` count UTF-16 code units as on JS, hxcpp and the JVM. Python str can hold lone
// surrogates. The std overrides in this directory (std-py/, only on the class path of Python
// builds, see go.PyTarget) convert at the I/O boundaries:
//   in  (file contents, resources, argv, environment, directory names, cwd): toU16
//   out (stdout/stderr, file contents, paths given to the OS):                fromU16
// String literals are converted by go.PyTarget after generation; String.fromCharCode and
// StringBuf.addChar write a surrogate pair for a code point above U+FFFF (StringImpl).
class U16 {
	static var astral:Dynamic = null;
	static var surrogate:Dynamic = null;

	// Native str → UTF-16 form: every character above U+FFFF becomes a surrogate pair.
	public static function toU16(s:String):String {
		if (s == null || Syntax.code("{0}.isascii()", s))
			return s;
		if (astral == null)
			astral = Syntax.code("__import__('re').compile('[\\U00010000-\\U0010ffff]')");
		return Syntax.code("{0}.sub(lambda m: (lambda c: chr(0xD7C0 + (c >> 10)) + chr(0xDC00 + (c & 0x3FF)))(ord(m.group())), {1})",
			astral, s);
	}

	// UTF-16 form → native str: surrogate pairs are combined, a lone surrogate becomes U+FFFD
	// (what node's Buffer.from writes on JS).
	public static function fromU16(s:String):String {
		if (s == null || Syntax.code("{0}.isascii()", s))
			return s;
		if (surrogate == null)
			surrogate = Syntax.code("__import__('re').compile('[\\ud800-\\udfff]')");
		if (Syntax.code("{0}.search({1}) is None", surrogate, s))
			return s;
		return Syntax.code("{0}.encode('utf-16-le', 'surrogatepass').decode('utf-16-le', 'replace')", s);
	}

	// UTF-8 bytes of a UTF-16 form string.
	public static function utf8(s:String):python.Bytes {
		return Syntax.code("{0}.encode('utf-8')", fromU16(s));
	}

	// String.fromCharCode for a code point above U+FFFF: the surrogate pair.
	public static function pair(code:Int):String {
		return Syntax.code("chr(0xD7C0 + ({0} >> 10)) + chr(0xDC00 + ({0} & 0x3FF))", code);
	}
}
