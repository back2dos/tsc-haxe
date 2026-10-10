package go.text.internal.language;

// PORT: a Go []byte (shared backing array, offset, length, capacity). The BCP 47 scanner of
// golang.org/x/text edits its buffer in place while it holds sub-slices (tokens) of it, so
// views must alias exactly as in Go. Out-of-range access throws, like a Go panic (the
// callers recover it as ErrSyntax, as Go does).
class ByteSlice {
	public final a:Array<Int>;
	public final off:Int;
	public final len:Int;
	public final cap:Int;

	public function new(a:Array<Int>, off:Int, len:Int, cap:Int) {
		this.a = a;
		this.off = off;
		this.len = len;
		this.cap = cap;
	}

	// make([]byte, n)
	public static function make(n:Int):ByteSlice {
		return new ByteSlice([for (_ in 0...n) 0], 0, n, n);
	}

	// make([]byte, n, c)
	public static function makeCap(n:Int, c:Int):ByteSlice {
		return new ByteSlice([for (_ in 0...c) 0], 0, n, c);
	}

	// []byte(s): the UTF-8 bytes of s.
	public static function ofString(s:String):ByteSlice {
		final b = haxe.io.Bytes.ofString(s, UTF8);
		return new ByteSlice([for (i in 0...b.length) b.get(i)], 0, b.length, b.length);
	}

	public static function ofBytes(bytes:Array<Int>):ByteSlice {
		return new ByteSlice(bytes, 0, bytes.length, bytes.length);
	}

	public inline function get(i:Int):Int {
		if (i < 0 || i >= len)
			throw "index out of range";
		return a[off + i];
	}

	public inline function set(i:Int, v:Int):Void {
		if (i < 0 || i >= len)
			throw "index out of range";
		a[off + i] = v & 0xff;
	}

	// s[lo:hi]
	public function slice(lo:Int, hi:Int):ByteSlice {
		if (lo < 0 || hi < lo || hi > cap)
			throw "slice bounds out of range";
		return new ByteSlice(a, off + lo, hi - lo, cap - lo);
	}

	// s[lo:]
	public inline function from(lo:Int):ByteSlice {
		return slice(lo, len);
	}

	// s[:hi]
	public inline function to(hi:Int):ByteSlice {
		return slice(0, hi);
	}

	// copy(dst, src) with memmove semantics; returns the number of bytes copied.
	public static function copy(dst:ByteSlice, src:ByteSlice):Int {
		final n = dst.len < src.len ? dst.len : src.len;
		final tmp = [for (i in 0...n) src.a[src.off + i]];
		for (i in 0...n)
			dst.a[dst.off + i] = tmp[i];
		return n;
	}

	// copy(dst, s) for a string source (ASCII).
	public static function copyString(dst:ByteSlice, s:String):Int {
		final n = dst.len < s.length ? dst.len : s.length;
		for (i in 0...n)
			dst.a[dst.off + i] = StringTools.fastCodeAt(s, i) & 0xff;
		return n;
	}

	// append(s, x...)
	public static function append(s:ByteSlice, x:ByteSlice):ByteSlice {
		final n = s.len + x.len;
		if (n <= s.cap) {
			final r = new ByteSlice(s.a, s.off, n, s.cap);
			copy(r.from(s.len), x);
			return r;
		}
		// PORT: Go's growth policy only changes the capacity, never the content.
		var c = s.cap * 2;
		if (c < n)
			c = n;
		final r = makeCap(n, c);
		copy(r, s);
		copy(r.from(s.len), x);
		return r;
	}

	// bytes.IndexByte
	public function indexByte(c:Int):Int {
		for (i in 0...len)
			if (a[off + i] == c)
				return i;
		return -1;
	}

	// bytes.Compare
	public static function compare(x:Null<ByteSlice>, y:Null<ByteSlice>):Int {
		final xl = x == null ? 0 : x.len;
		final yl = y == null ? 0 : y.len;
		final n = xl < yl ? xl : yl;
		for (i in 0...n) {
			final p = x.a[x.off + i];
			final q = y.a[y.off + i];
			if (p != q)
				return p < q ? -1 : 1;
		}
		return xl < yl ? -1 : (xl > yl ? 1 : 0);
	}

	// bytes.Equal
	public static function equal(x:Null<ByteSlice>, y:Null<ByteSlice>):Bool {
		return compare(x, y) == 0;
	}

	// bytes.Join
	public static function join(s:Array<ByteSlice>, sep:Int):ByteSlice {
		final out:Array<Int> = [];
		for (i in 0...s.length) {
			if (i > 0)
				out.push(sep);
			final x = s[i];
			for (k in 0...x.len)
				out.push(x.a[x.off + k]);
		}
		return ofBytes(out);
	}

	// string(b): only ASCII reaches this in the scanner; other bytes map to U+0000..U+00FF.
	public function toString():String {
		final b = new StringBuf();
		for (i in 0...len)
			b.addChar(a[off + i]);
		return b.toString();
	}
}
