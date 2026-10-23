package go;

// PORT: ts-- — KeyHasher.Sum's string from the written bytes, in a module of its own: its code differs per target,
// and haxe-in-haxe's ts-- portable mode keeps such a module per target (tsmm.Gen.platform, tools/targets.sh).
class KeySum {
	#if (target.name == "hxmc")
	public static inline function sum(b:haxe.io.Bytes, n:Int):std.String {
		// PORT: perf — hxmc's strings are 16-bit units that need not be valid UTF-16: two bytes per
		// unit and a last unit holding n's parity (injective too), no packing and no UTF-8 decoding.
		final m = (n + 1) >> 1;
		final s = hxmc.rt.Str.make(m + 1);
		final d = hxmc.rt.Str.chars(s);
		// PORT: perf — the string's hash as hxmc's StringMap computes it (FNV-1a of the units, 0 → 1), stored in
		// the string while its units are written: the key's map lookup does not hash it again
		var x = 0x811C9DC5;
		var i = 0;
		while (i + 1 < n) {
			final u = b.get(i) | (b.get(i + 1) << 8);
			d.set(i >> 1, u);
			x = (x ^ u) * 16777619;
			i += 2;
		}
		if (i < n) {
			final u = b.get(i);
			d.set(i >> 1, u);
			x = (x ^ u) * 16777619;
		}
		d.set(m, n & 1);
		x = (x ^ (n & 1)) * 16777619;
		hxmc.rt.Repr.storeHash(s, x == 0 ? 1 : x);
		return s;
	}
	#else
	static var packed:haxe.io.Bytes = null;

	public static function sum(buf:haxe.io.Bytes, n:Int):std.String {
		final m = Std.int((n * 8 + 6) / 7);
		if (packed == null || packed.length < m)
			packed = haxe.io.Bytes.alloc(m < 256 ? 256 : m * 2);
		final p = packed;
		var acc = 0;
		var bits = 0;
		var j = 0;
		for (i in 0...n) {
			acc = ((acc << 8) | buf.get(i)) & 0x7FFF; // at most 6 pending bits + 8 new ones
			bits += 8;
			while (bits >= 7) {
				bits -= 7;
				p.set(j++, (acc >> bits) & 0x7F);
			}
		}
		if (bits > 0)
			p.set(j++, (acc << (7 - bits)) & 0x7F);
		return Strings.FromASCIIBytes(p, j);
	}
	#end
}
