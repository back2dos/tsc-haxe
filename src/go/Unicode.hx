package go;

// Go unicode.RangeTable. R16 / R32 are flat [Lo, Hi, Stride] triples.
final class RangeTable {
	public final R16:Array<Int>;
	public final R32:Array<Int>;
	public final LatinOffset:Int;

	public function new(R16:Array<Int>, R32:Array<Int>, LatinOffset:Int) {
		this.R16 = R16;
		this.R32 = R32;
		this.LatinOffset = LatinOffset;
	}
}

// Shims for Go package unicode. Case tables come from Go's src/unicode/tables.go
// (generated into go.UnicodeTables by tools/gen/stringutil/GenTables.hx).
class Unicode {
	public static inline final MaxRune = 0x10FFFF;
	public static inline final ReplacementChar = 0xFFFD;
	public static inline final MaxASCII = 0x7F;
	public static inline final MaxLatin1 = 0xFF;

	// unicode.Zs (Go 1.26 src/unicode/tables.go, Unicode 15.0.0)
	public static final Zs:RangeTable = new RangeTable([
		0x0020, 0x00a0, 128,
		0x1680, 0x2000, 2432,
		0x2001, 0x200a, 1,
		0x202f, 0x205f, 48,
		0x3000, 0x3000, 1,
	], [], 1);

	public static inline final UpperCase = 0;
	public static inline final LowerCase = 1;
	public static inline final TitleCase = 2;
	public static inline final MaxCase = 3;

	static inline final linearMax = 18;

	// is16 / is32 over flat triples [from, to) (in triples).
	static function isRanges(ranges:Array<Int>, from:Int, to:Int, r:Int, linear:Bool):Bool {
		if (linear) {
			var i = from;
			while (i < to) {
				final lo = ranges[i * 3];
				if (r < lo)
					return false;
				if (r <= ranges[i * 3 + 1]) {
					final stride = ranges[i * 3 + 2];
					return stride == 1 || (r - lo) % stride == 0;
				}
				i++;
			}
			return false;
		}

		// binary search over ranges
		var lo = from;
		var hi = to;
		while (lo < hi) {
			final m = (lo + hi) >>> 1;
			final rlo = ranges[m * 3];
			if (rlo <= r && r <= ranges[m * 3 + 1]) {
				final stride = ranges[m * 3 + 2];
				return stride == 1 || (r - rlo) % stride == 0;
			}
			if (r < rlo)
				hi = m;
			else
				lo = m + 1;
		}
		return false;
	}

	static inline function is16(ranges:Array<Int>, from:Int, r:Int):Bool {
		final n = Std.int(ranges.length / 3);
		return isRanges(ranges, from, n, r, n - from <= linearMax || r <= MaxLatin1);
	}

	static inline function is32(ranges:Array<Int>, r:Int):Bool {
		final n = Std.int(ranges.length / 3);
		return isRanges(ranges, 0, n, r, n <= linearMax);
	}

	// unicode.IsSpace (all such runes are in the BMP).
	public static function IsSpace(r:Int):Bool {
		if (r <= 0xFF)
			return r == 0x20 || (r >= 0x09 && r <= 0x0D) || r == 0x85 || r == 0xA0;
		return r == 0x1680 || (r >= 0x2000 && r <= 0x200A) || r == 0x2028 || r == 0x2029 || r == 0x202F || r == 0x205F || r == 0x3000;
	}

	// unicode.Is: reports whether the rune is in the specified table of ranges.
	public static function Is(rangeTab:RangeTable, r:Int):Bool {
		final r16 = rangeTab.R16;
		// Go compares as uint32 to handle negative runes; negative runes never match.
		if (r16.length > 0 && r >= 0 && r <= r16[r16.length - 2]) {
			return is16(r16, 0, r);
		}
		final r32 = rangeTab.R32;
		if (r32.length > 0 && r >= r32[0]) {
			return is32(r32, r);
		}
		return false;
	}

	// lookupCaseRange returns the index (in ranges) of the CaseRange for r, or -1.
	static function lookupCaseRange(r:Int, caseRange:Array<Int>):Int {
		var lo = 0;
		var hi = Std.int(caseRange.length / 5);
		while (lo < hi) {
			final m = (lo + hi) >>> 1;
			final crLo = caseRange[m * 5];
			if (crLo <= r && r <= caseRange[m * 5 + 1])
				return m;
			if (r < crLo)
				hi = m;
			else
				lo = m + 1;
		}
		return -1;
	}

	static function convertCase(_case:Int, r:Int, caseRange:Array<Int>, cr:Int):Int {
		final delta = caseRange[cr * 5 + 2 + _case];
		if (delta > MaxRune) {
			final lo = caseRange[cr * 5];
			return lo + (((r - lo) & ~1) | (_case & 1));
		}
		return r + delta;
	}

	// unicode.To
	public static function To(_case:Int, r:Int):Int {
		if (_case < 0 || MaxCase <= _case)
			return ReplacementChar;
		final cr = lookupCaseRange(r, UnicodeTables.CaseRanges);
		if (cr >= 0)
			return convertCase(_case, r, UnicodeTables.CaseRanges, cr);
		return r;
	}

	// unicode.ToUpper
	public static function ToUpper(r:Int):Int {
		if (r <= MaxASCII) {
			if ('a'.code <= r && r <= 'z'.code)
				r -= 'a'.code - 'A'.code;
			return r;
		}
		return To(UpperCase, r);
	}

	// unicode.ToLower
	public static function ToLower(r:Int):Int {
		if (r <= MaxASCII) {
			if ('A'.code <= r && r <= 'Z'.code)
				r += 'a'.code - 'A'.code;
			return r;
		}
		return To(LowerCase, r);
	}

	// unicode.SimpleFold
	public static function SimpleFold(r:Int):Int {
		if (r < 0 || r > MaxRune)
			return r;

		final asciiFold = UnicodeTables.asciiFold;
		if (r < asciiFold.length)
			return asciiFold[r];

		// Consult caseOrbit table for special cases.
		final caseOrbit = UnicodeTables.caseOrbit;
		var lo = 0;
		final n = caseOrbit.length >> 1;
		var hi = n;
		while (lo < hi) {
			final m = (lo + hi) >>> 1;
			if (caseOrbit[m * 2] < r)
				lo = m + 1;
			else
				hi = m;
		}
		if (lo < n && caseOrbit[lo * 2] == r)
			return caseOrbit[lo * 2 + 1];

		// No folding specified. This is a one- or two-element
		// equivalence class containing rune and ToLower(rune)
		// and ToUpper(rune) if they are different from rune.
		final cr = lookupCaseRange(r, UnicodeTables.CaseRanges);
		if (cr >= 0) {
			final l = convertCase(LowerCase, r, UnicodeTables.CaseRanges, cr);
			if (l != r)
				return l;
			return convertCase(UpperCase, r, UnicodeTables.CaseRanges, cr);
		}
		return r;
	}
}
