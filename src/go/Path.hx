package go;

import go.Tuple.Pair;

// Shim for Go package path (slash-separated paths). Works on UTF-16 code units; only '/' and
// '.' are inspected, so the result is the same as Go's byte-wise code.
class Path {
	// path.Clean (Go lazybuf → StringBuf: same result).
	public static function Clean(path:String):String {
		if (path == "") {
			return ".";
		}
		final rooted = StringTools.fastCodeAt(path, 0) == '/'.code;
		final n = path.length;
		// out: the cleaned path as an array of code units with write index w.
		final out:Array<Int> = [];
		var w = 0;
		inline function append(c:Int) {
			if (w < out.length)
				out[w] = c;
			else
				out.push(c);
			w++;
		}
		var r = 0;
		var dotdot = 0;
		if (rooted) {
			append('/'.code);
			r = 1;
			dotdot = 1;
		}
		inline function at(i:Int):Int {
			return StringTools.fastCodeAt(path, i);
		}
		while (r < n) {
			if (at(r) == '/'.code) {
				r++;
			} else if (at(r) == '.'.code && (r + 1 == n || at(r + 1) == '/'.code)) {
				r++;
			} else if (at(r) == '.'.code && at(r + 1) == '.'.code && (r + 2 == n || at(r + 2) == '/'.code)) {
				r += 2;
				if (w > dotdot) {
					w--;
					while (w > dotdot && out[w] != '/'.code) {
						w--;
					}
				} else if (!rooted) {
					if (w > 0) {
						append('/'.code);
					}
					append('.'.code);
					append('.'.code);
					dotdot = w;
				}
			} else {
				if (rooted && w != 1 || !rooted && w != 0) {
					append('/'.code);
				}
				while (r < n && at(r) != '/'.code) {
					append(at(r));
					r++;
				}
			}
		}
		if (w == 0) {
			return ".";
		}
		// Combine surrogate pairs before appending (PORTING.md §5: build from code points).
		final b = new StringBuf();
		var i = 0;
		while (i < w) {
			final c = out[i];
			if (c >= 0xD800 && c < 0xDC00 && i + 1 < w && out[i + 1] >= 0xDC00 && out[i + 1] < 0xE000) {
				b.addChar(((c - 0xD800) << 10) + (out[i + 1] - 0xDC00) + 0x10000);
				i += 2;
			} else {
				b.add(Utf16.CodeUnitString(c));
				i++;
			}
		}
		return b.toString();
	}

	// path.Split: (dir, file)
	public static function Split(path:String):Pair<String, String> {
		final i = path.lastIndexOf("/");
		return new Pair(path.substring(0, i + 1), path.substring(i + 1));
	}

	// path.Join
	public static function Join(elem:Array<String>):String {
		var size = 0;
		for (e in elem) {
			size += e.length;
		}
		if (size == 0) {
			return "";
		}
		final buf = new StringBuf();
		var len = 0;
		for (e in elem) {
			if (len > 0 || e != "") {
				if (len > 0) {
					buf.addChar('/'.code);
					len++;
				}
				buf.add(e);
				len += e.length;
			}
		}
		return Clean(buf.toString());
	}

	// path.Ext
	public static function Ext(path:String):String {
		var i = path.length - 1;
		while (i >= 0 && StringTools.fastCodeAt(path, i) != '/'.code) {
			if (StringTools.fastCodeAt(path, i) == '.'.code) {
				return path.substring(i);
			}
			i--;
		}
		return "";
	}

	// path.Base
	public static function Base(path:String):String {
		if (path == "") {
			return ".";
		}
		while (path.length > 0 && StringTools.fastCodeAt(path, path.length - 1) == '/'.code) {
			path = path.substring(0, path.length - 1);
		}
		final i = path.lastIndexOf("/");
		if (i >= 0) {
			path = path.substring(i + 1);
		}
		if (path == "") {
			return "/";
		}
		return path;
	}

	// path.IsAbs
	public static function IsAbs(path:String):Bool {
		return path.length > 0 && StringTools.fastCodeAt(path, 0) == '/'.code;
	}

	// path.Dir
	public static function Dir(path:String):String {
		return Clean(Split(path).a);
	}
}
