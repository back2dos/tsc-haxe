package go;

// Shim for Go package regexp.
// PORT: Go's RE2 syntax is not translated. `MustCompile` takes an EReg pattern that the porter
// wrote to behave like the Go pattern on JS RegExp and on hxcpp PCRE2 alike:
//   - no `\d`, `\s`, `\w`, `\b` (PCRE2 on hxcpp is Unicode-aware, JS and Go are ASCII-only):
//     write `[0-9]`, `[\t\n\f\r ]` (Go `\s`), ...
//   - no `$` (PCRE2 also matches before a final "\n"): write `(?![\s\S])` for Go `$` / `\z`.
//   - no `i` flag (case folding differs on all three): spell out both cases; Go `(?i)` also
//     folds k to U+212A and s to U+017F.
class Regexp {
	final re:EReg;

	function new(re:EReg) {
		this.re = re;
	}

	public static function MustCompile(expr:String):Regexp {
		return new Regexp(new EReg(expr, "g"));
	}

	// Regexp.MatchString
	public function MatchString(s:String):Bool {
		return re.match(s);
	}

	// Regexp.FindStringSubmatch: null when there is no match; unmatched groups are "".
	public function FindStringSubmatch(s:String):Null<Array<String>> {
		if (!re.match(s))
			return null;
		final result:Array<String> = [];
		var i = 0;
		while (true) {
			var m:Null<String>;
			try {
				m = re.matched(i);
			} catch (e:Dynamic) {
				break;
			}
			result.push(m == null ? "" : m);
			i++;
		}
		return result;
	}

	// Regexp.FindAllStringIndex. Returns pairs [start, end] in UTF-16 code units.
	public function FindAllStringIndex(s:String, n:Int):Null<Array<Array<Int>>> {
		if (n < 0)
			n = s.length + 1;
		var result:Null<Array<Array<Int>>> = null;
		var pos = 0;
		var i = 0;
		var prevMatchEnd = -1;
		final end = s.length;
		while (i < n && pos <= end) {
			if (!re.matchSub(s, pos))
				break;
			final p = re.matchedPos();
			final m0 = p.pos;
			final m1 = p.pos + p.len;
			var accept = true;
			if (m1 == pos) {
				// We've found an empty match.
				if (m0 == prevMatchEnd) {
					// We don't allow an empty match right
					// after a previous match, so ignore it.
					accept = false;
				}
				// Advance by one rune.
				if (pos < end) {
					final c = StringTools.fastCodeAt(s, pos);
					if (c >= 0xD800 && c <= 0xDBFF && pos + 1 < end) {
						final d = StringTools.fastCodeAt(s, pos + 1);
						pos += (d >= 0xDC00 && d <= 0xDFFF) ? 2 : 1;
					} else {
						pos += 1;
					}
				} else {
					pos = end + 1;
				}
			} else {
				pos = m1;
			}
			prevMatchEnd = m1;
			if (accept) {
				if (result == null)
					result = [];
				result.push([m0, m1]);
				i++;
			}
		}
		return result;
	}

	// Regexp.Split
	public function Split(s:String, n:Int):Null<Array<String>> {
		if (n == 0)
			return null;

		if (s.length == 0)
			return [""]; // PORT: Go checks len(re.expr) > 0; all ported patterns are non-empty.

		final matches = FindAllStringIndex(s, n);
		final strings:Array<String> = [];

		var beg = 0;
		var end = 0;
		if (matches != null) {
			for (match in matches) {
				if (n > 0 && strings.length == n - 1)
					break;

				end = match[0];
				if (match[1] != 0)
					strings.push(s.substring(beg, end));
				beg = match[1];
			}
		}

		if (end != s.length)
			strings.push(s.substring(beg));

		return strings;
	}

	// Regexp.ReplaceAllStringFunc. Only for patterns that cannot match the empty string.
	public function ReplaceAllStringFunc(src:String, repl:String->String):String {
		return re.map(src, (r) -> repl(r.matched(0)));
	}
}
