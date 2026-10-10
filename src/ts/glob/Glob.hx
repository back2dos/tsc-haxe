package ts.glob;

// Port of internal/glob/glob.go.
//
// PORT: Go matches bytes of UTF-8 strings; this port matches UTF-16 code units (PORTING.md §5).
// `?`, `*` backtracking and literal prefixes work per code unit; `[x-y]` decodes a surrogate
// pair as one rune (Go: one UTF-8 rune). Results differ from Go only for non-ASCII input.

// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// A Glob is an LSP-compliant glob pattern, as defined by the spec:
// https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#documentFilter
//
// NOTE: this implementation is currently only intended for testing. In order
// to make it production ready, we'd need to:
//   - verify it against the VS Code implementation
//   - add more tests
//   - microbenchmark, likely avoiding the element interface
//   - resolve the question of what is meant by "character". If it's a UTF-16
//     code (as we suspect) it'll be a bit more work.
//
// Quoting from the spec:
// Glob patterns can have the following syntax:
//   - `*` to match one or more characters in a path segment
//   - `?` to match on one character in a path segment
//   - `**` to match any number of path segments, including none
//   - `{}` to group sub patterns into an OR expression. (e.g. `**/*.{ts,js}`
//     matches all TypeScript and JavaScript files)
//   - `[]` to declare a range of characters to match in a path segment
//     (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)
//   - `[!...]` to negate a range of characters to match in a path segment
//     (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but
//     not `example.0`)
//
// Expanding on this:
//   - '/' matches one or more literal slashes.
//   - any other character matches itself literally.
@:allow(ts.glob)
class Glob {
	var elems:Array<Element> = null; // pattern elements

	public function new() {}

	// Parse builds a Glob for the given pattern, returning an error if the pattern
	// is invalid.
	public static function Parse(pattern:String):GlobResult {
		final r = parse(pattern, false);
		return new GlobResult(r.g, r.err);
	}

	static function parse(pattern:String, nested:Bool):ParseResult {
		final g = new Glob();
		while (pattern.length > 0) {
			switch (StringTools.fastCodeAt(pattern, 0)) {
				case '/'.code:
					pattern = pattern.substring(1);
					g.elems = append(g.elems, new Slash());

				case '*'.code:
					if (pattern.length > 1 && StringTools.fastCodeAt(pattern, 1) == '*'.code) {
						if ((len(g.elems) > 0 && !Std.isOfType(g.elems[g.elems.length - 1], Slash))
							|| (pattern.length > 2 && StringTools.fastCodeAt(pattern, 2) != '/'.code)) {
							return new ParseResult(null, "", Errors.New("** may only be adjacent to '/'"));
						}
						pattern = pattern.substring(2);
						g.elems = append(g.elems, new StarStar());
					} else { // PORT: Go `break` out of the switch → else branch
						pattern = pattern.substring(1);
						g.elems = append(g.elems, new Star());
					}

				case '?'.code:
					pattern = pattern.substring(1);
					g.elems = append(g.elems, new AnyChar());

				case '{'.code:
					var gs:Array<Glob> = null;
					while (byteAt(pattern, 0) != '}'.code) {
						pattern = pattern.substring(1);
						final r = parse(pattern, true);
						if (r.err != null)
							return new ParseResult(null, "", r.err);
						if (r.rest.length == 0)
							return new ParseResult(null, "", Errors.New("unmatched '{'"));
						pattern = r.rest;
						if (gs == null)
							gs = [];
						gs.push(r.g);
					}
					pattern = pattern.substring(1);
					g.elems = append(g.elems, new Group(gs));

				case '}'.code | ','.code:
					if (nested)
						return new ParseResult(g, pattern, null);
					pattern = g.parseLiteral(pattern, false);

				case '['.code:
					pattern = pattern.substring(1);
					if (pattern.length == 0)
						return new ParseResult(null, "", errBadRange);
					var negate = false;
					if (StringTools.fastCodeAt(pattern, 0) == '!'.code) {
						pattern = pattern.substring(1);
						negate = true;
					}
					final low = readRangeRune(pattern);
					if (low.err != null)
						return new ParseResult(null, "", low.err);
					pattern = pattern.substring(low.sz);
					if (pattern.length == 0 || StringTools.fastCodeAt(pattern, 0) != '-'.code)
						return new ParseResult(null, "", errBadRange);
					pattern = pattern.substring(1);
					final high = readRangeRune(pattern);
					if (high.err != null)
						return new ParseResult(null, "", high.err);
					pattern = pattern.substring(high.sz);
					if (pattern.length == 0 || StringTools.fastCodeAt(pattern, 0) != ']'.code)
						return new ParseResult(null, "", errBadRange);
					pattern = pattern.substring(1);
					g.elems = append(g.elems, new CharRange(negate, low.r, high.r));

				default:
					pattern = g.parseLiteral(pattern, nested);
			}
		}
		return new ParseResult(g, "", null);
	}

	// helper for decoding a rune in range elements, e.g. [a-z]
	static function readRangeRune(input:String):RangeRuneResult {
		final r = Utf16.DecodeRuneInString(input, 0);
		final sz = input.length == 0 ? 0 : Utf16.RuneLen(r);
		var err:Error = null;
		if (r == Utf16.RuneError) {
			// See the documentation for DecodeRuneInString.
			// PORT: Go size 1 means invalid UTF-8; here a lone surrogate. A literal U+FFFD is valid.
			if (sz == 0)
				err = errBadRange;
			else if (StringTools.fastCodeAt(input, 0) != Utf16.RuneError)
				err = errInvalidUTF8;
		}
		return new RangeRuneResult(r, sz, err);
	}

	static final errBadRange = Errors.New("'[' patterns must be of the form [x-y]");
	static final errInvalidUTF8 = Errors.New("invalid UTF-8 encoding");

	function parseLiteral(pattern:String, nested:Bool):String {
		var specialChars:String;
		if (nested)
			specialChars = "*?{[/},";
		else
			specialChars = "*?{[/";
		var end = Strings.IndexAny(pattern, specialChars);
		if (end == -1)
			end = pattern.length;
		elems = append(elems, new Literal(pattern.substring(0, end)));
		return pattern.substring(end);
	}

	public function String():String {
		final b = new StringBuf();
		if (elems != null)
			for (e in elems)
				b.add(e.String());
		return b.toString();
	}

	// Match reports whether the input string matches the glob pattern.
	public function Match(input:String):Bool {
		return match(elems, input);
	}

	static function match(elems:Array<Element>, input:String):Bool {
		var elem:Element;
		while (len(elems) > 0) {
			elem = elems[0];
			elems = elems.slice(1);
			// PORT: Go type switch → Std.isOfType / Std.downcast.
			if (Std.isOfType(elem, Slash)) {
				if (input.length == 0 || StringTools.fastCodeAt(input, 0) != '/'.code)
					return false;
				while (byteAt(input, 0) == '/'.code)
					input = input.substring(1);
			} else if (Std.isOfType(elem, StarStar)) {
				// Special cases:
				//  - **/a matches "a"
				//  - **/ matches everything
				//
				// Note that if ** is followed by anything, it must be '/' (this is
				// enforced by Parse).
				if (elems.length > 0)
					elems = elems.slice(1);

				// A trailing ** matches anything.
				if (elems.length == 0)
					return true;

				// Backtracking: advance pattern segments until the remaining pattern
				// elements match.
				while (input.length != 0) {
					if (match(elems, input))
						return true;
					input = split(input).rest;
				}
				return false;
			} else if (Std.isOfType(elem, Literal)) {
				final lit = (cast elem : Literal).s;
				if (!StringTools.startsWith(input, lit))
					return false;
				input = input.substring(lit.length);
			} else if (Std.isOfType(elem, Star)) {
				final sp = split(input);
				final segInput = sp.first;
				input = sp.rest;

				var elemEnd = elems.length;
				for (i in 0...elems.length) {
					if (Std.isOfType(elems[i], Slash)) {
						elemEnd = i;
						break;
					}
				}
				final segElems = elems.slice(0, elemEnd);
				elems = elems.slice(elemEnd);

				// A trailing * matches the entire segment.
				if (segElems.length != 0) { // PORT: Go `break` out of the switch → if
					// Backtracking: advance characters until remaining subpattern elements
					// match.
					var matched = false;
					for (i in 0...segInput.length) {
						if (match(segElems, segInput.substring(i))) {
							matched = true;
							break;
						}
					}
					if (!matched)
						return false;
				}
			} else if (Std.isOfType(elem, AnyChar)) {
				if (input.length == 0 || StringTools.fastCodeAt(input, 0) == '/'.code)
					return false;
				input = input.substring(1);
			} else if (Std.isOfType(elem, Group)) {
				// Append remaining pattern elements to each group member looking for a
				// match.
				final g = (cast elem : Group);
				if (g.globs != null) {
					for (m in g.globs) {
						final branch:Array<Element> = [];
						if (m.elems != null)
							for (e in m.elems)
								branch.push(e);
						for (e in elems)
							branch.push(e);
						if (match(branch, input))
							return true;
					}
				}
				return false;
			} else if (Std.isOfType(elem, CharRange)) {
				final r = (cast elem : CharRange);
				if (input.length == 0 || StringTools.fastCodeAt(input, 0) == '/'.code)
					return false;
				final c = Utf16.DecodeRuneInString(input, 0);
				final sz = Utf16.RuneLen(c);
				if (c < r.low || c > r.high)
					return false;
				input = input.substring(sz);
			} else {
				throw 'segment type ${Type.getClassName(Type.getClass(elem))} not implemented';
			}
		}

		return input.length == 0;
	}

	// split returns the portion before and after the first slash
	// (or sequence of consecutive slashes). If there is no slash
	// it returns (input, nil).
	static function split(input:String):SplitResult {
		final i = input.indexOf("/");
		if (i < 0)
			return new SplitResult(input, "");
		final first = input.substring(0, i);
		for (j in i...input.length) {
			if (StringTools.fastCodeAt(input, j) != '/'.code)
				return new SplitResult(first, input.substring(j));
		}
		return new SplitResult(first, "");
	}

	// Go `len(s)` on a possibly nil slice.
	static inline function len<T>(a:Array<T>):Int {
		return a == null ? 0 : a.length;
	}

	// Go `append(s, x)` on a slice the caller owns.
	static inline function append<T>(a:Array<T>, x:T):Array<T> {
		if (a == null)
			a = [];
		a.push(x);
		return a;
	}

	// PORT: Go `s[i]` without a bounds check in the code: Go panics when out of range.
	static function byteAt(s:String, i:Int):Int {
		if (i >= s.length)
			throw 'runtime error: index out of range [$i] with length ${s.length}';
		return StringTools.fastCodeAt(s, i);
	}
}

// element holds a glob pattern element, as defined below.
// PORT: Go type names element, slash, literal, ...; Haxe type names must start upper case.
interface Element {
	function String():String;
}

// element types.

// One or more '/' separators
class Slash implements Element {
	public function new() {}

	public function String():String
		return "/";
}

// string literal, not containing /, *, ?, {}, or []
class Literal implements Element {
	public final s:String;

	public function new(s:String) {
		this.s = s;
	}

	public function String():String
		return s;
}

// *
class Star implements Element {
	public function new() {}

	public function String():String
		return "*";
}

// ?
class AnyChar implements Element {
	public function new() {}

	public function String():String
		return "?";
}

// **
class StarStar implements Element {
	public function new() {}

	public function String():String
		return "**";
}

// {foo, bar, ...} grouping
class Group implements Element {
	public final globs:Array<Glob>;

	public function new(globs:Array<Glob>) {
		this.globs = globs;
	}

	public function String():String {
		var parts:Array<String> = [];
		if (globs != null)
			for (g in globs)
				parts.push(g.String());
		return "{" + parts.join(",") + "}";
	}
}

// [a-z] character range
class CharRange implements Element {
	public final negate:Bool;
	public final low:Int;
	public final high:Int;

	public function new(negate:Bool, low:Int, high:Int) {
		this.negate = negate;
		this.low = low;
		this.high = high;
	}

	public function String():String {
		return "[" + Utf16.RuneString(low) + "-" + Utf16.RuneString(high) + "]";
	}
}

// Go multiple return value (*Glob, error) of Parse.
final class GlobResult {
	public final value:Glob;
	public final err:Null<Error>;

	public inline function new(value:Glob, err:Null<Error>) {
		this.value = value;
		this.err = err;
	}
}

// Go multiple return value (*Glob, string, error) of parse.
final class ParseResult {
	public final g:Glob;
	public final rest:String;
	public final err:Null<Error>;

	public inline function new(g:Glob, rest:String, err:Null<Error>) {
		this.g = g;
		this.rest = rest;
		this.err = err;
	}
}

// Go multiple return value (rune, int, error) of readRangeRune.
final class RangeRuneResult {
	public final r:Int;
	public final sz:Int;
	public final err:Null<Error>;

	public inline function new(r:Int, sz:Int, err:Null<Error>) {
		this.r = r;
		this.sz = sz;
		this.err = err;
	}
}

// Go multiple return value (first, rest string) of split.
final class SplitResult {
	public final first:String;
	public final rest:String;

	public inline function new(first:String, rest:String) {
		this.first = first;
		this.rest = rest;
	}
}
