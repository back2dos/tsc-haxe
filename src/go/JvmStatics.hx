package go;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

// PORT: jvm — the JVM limits a method to 64 KB of bytecode, and Haxe puts every static
// initializer of a class into one method (<clinit>). A literal `Array<Int>` costs about 7 bytes
// per element there, so the generated tables (go.text.internal.language.Tables, Unicode tables, …)
// overflow it ("IO.Overflow(write_ui16)" from the Haxe JVM generator). On JVM only, go.NilRange
// passes every static field initializer through `rewriteStatic`: a large literal array of Int or
// String constants becomes a decode call of a compact string form (same elements, same order).
// Other targets are not changed.
class JvmStatics {
	// Chunk size in characters: a JVM string constant holds at most 65,535 bytes of modified UTF-8
	// (up to 3 bytes per UTF-16 unit).
	static inline final CHUNK = 20000;

	// Decodes comma-separated decimal Ints.
	public static function ints(chunks:Array<String>):Array<Int> {
		final s = chunks.join("");
		final a = new Array<Int>();
		if (s.length == 0)
			return a;
		var v = 0, neg = false;
		for (i in 0...s.length) {
			final c = StringTools.fastCodeAt(s, i);
			if (c == ",".code) {
				a.push(neg ? -v : v);
				v = 0;
				neg = false;
			} else if (c == "-".code) {
				neg = true;
			} else {
				v = v * 10 + (c - "0".code);
			}
		}
		a.push(neg ? -v : v);
		return a;
	}

	// Decodes length-prefixed Strings: "<length>:<text>" repeated.
	public static function strings(chunks:Array<String>):Array<String> {
		final s = chunks.join("");
		final a = new Array<String>();
		var i = 0;
		while (i < s.length) {
			var n = 0;
			while (StringTools.fastCodeAt(s, i) != ":".code) {
				n = n * 10 + (StringTools.fastCodeAt(s, i) - "0".code);
				i++;
			}
			i++;
			a.push(s.substr(i, n));
			i += n;
		}
		return a;
	}

	#if macro
	// Minimum number of elements that is rewritten.
	static inline final MIN = 32;

	public static function rewriteStatic(e:Expr):Expr {
		return switch e.expr {
			case EArrayDecl(values) if (values.length >= MIN):
				final ints = [for (v in values) intOf(v)];
				if (ints.indexOf(null) < 0)
					return macro @:pos(e.pos) go.JvmStatics.ints($v{chunks(ints.join(","))});
				final strs = [for (v in values) switch v.expr {
					case EConst(CString(s, DoubleQuotes)): s;
					case _: null;
				}];
				if (strs.indexOf(null) < 0)
					return macro @:pos(e.pos) go.JvmStatics.strings($v{chunks([for (s in strs) s.length + ":" + s].join(""))});
				e;
			case _: e;
		}
	}

	static function chunks(s:String):Array<String> {
		final out = [];
		var i = 0;
		while (i < s.length) {
			var end = i + CHUNK;
			// never cut a surrogate pair
			if (end < s.length && StringTools.fastCodeAt(s, end - 1) >= 0xD800 && StringTools.fastCodeAt(s, end - 1) <= 0xDBFF)
				end++;
			out.push(s.substring(i, end));
			i = end;
		}
		return out;
	}

	static function intOf(e:Expr):Null<String> {
		return switch e.expr {
			case EConst(CInt(v, null)): Std.string(Std.parseInt(v));
			case EUnop(OpNeg, false, {expr: EConst(CInt(v, null))}): Std.string(-Std.parseInt(v));
			case EParenthesis(inner): intOf(inner);
			case _: null;
		}
	}
	#end
}
