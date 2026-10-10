package go;

// TestSlicesSortGolden: Go's slices.SortFunc (pdqsort), SortStableFunc and slices.Sort / sort.Strings
// must leave elements that compare equal in exactly Go's order. test/go/slices_sort.golden.txt is
// written by test/go/slices_sort_golden.go.txt (run instructions there); this file builds the same
// inputs with the same xorshift32 generator and compares line by line.
class SlicesSortTest {
	static var rng = -1831433054; // uint32 2463534242

	static function next():Int {
		rng ^= rng << 13;
		rng ^= rng >>> 17;
		rng ^= rng << 5;
		return rng;
	}

	static function rnd(k:Int):Int {
		return (next() >>> 8) % k;
	}

	static function gen(n:Int, pat:Int):Array<Rec> {
		final x = [];
		for (i in 0...n) {
			final k = switch pat {
				case 0: rnd(3);
				case 1: rnd(Std.int(n / 2) + 1);
				case 2: Std.int(i / 3);
				case 3: Std.int((n - i) / 3);
				case 4: 7;
				case 5: i % 7;
				case 6: Std.int((i < n - i ? i : n - i) / 2);
				case 7: Std.int(i / 2);
				default: rnd(n);
			}
			x.push(new Rec(k, i));
		}
		if (pat == 7 && n > 1) {
			for (_ in 0...3) {
				final a = rnd(n), b = rnd(n);
				final t = x[a];
				x[a] = x[b];
				x[b] = t;
			}
		}
		return x;
	}

	static function cmpRec(a:Rec, b:Rec):Int {
		return a.key - b.key;
	}

	static function emit(kind:String, n:Int, pat:Int, x:Array<Rec>):String {
		var h = 5381;
		for (r in x)
			h = ((h << 5) + h + r.id) | 0;
		final sb = new StringBuf();
		sb.add('$kind $n $pat ${StringTools.hex(h, 8)}');
		if (n <= 100)
			for (r in x)
				sb.add(' ${r.id}');
		return sb.toString();
	}

	public static function run() {
		T.run("TestSlicesSortGolden", () -> {
			final golden = sys.io.File.getContent("test/go/slices_sort.golden.txt").split("\n");
			if (golden[golden.length - 1] == "")
				golden.pop();
			final out = [];
			final lengths = [for (n in 0...301) n].concat([1000, 5000, 20000]);
			final cmp = cmpRec;
			for (n in lengths) {
				for (pat in 0...9) {
					final x = gen(n, pat);
					final y = x.copy();
					Slices.SortFunc(x, cmp);
					out.push(emit("U", n, pat, x));
					Slices.SortStableFunc(y, cmp);
					out.push(emit("S", n, pat, y));
				}
			}
			final negZero = 1 / std.Math.NEGATIVE_INFINITY;
			var n = 0;
			while (n <= 200) {
				final f:Array<Float> = [];
				for (_ in 0...n) {
					f.push(switch rnd(5) {
						case 0: std.Math.NaN;
						case 1: negZero;
						case 2: 0.0;
						default: rnd(5) - 2;
					});
				}
				Slices.SortFloats(f);
				final sb = new StringBuf();
				sb.add('F $n');
				for (v in f)
					sb.add(std.Math.isNaN(v) ? " N" : (v == 0 && 1 / v < 0 ? " -0" : ' ${Std.int(v)}'));
				out.push(sb.toString());
				n += 7;
			}
			final pool = ["a", "b", "", "ab", "\u{FFFF}", "\u{1F600}", "\u{E9}", "Z", "a\u{1F600}", "a\u{FFFF}"];
			n = 0;
			while (n <= 100) {
				final s = [for (_ in 0...n) pool[rnd(pool.length)]];
				Slices.SortStrings(s);
				final sb = new StringBuf();
				sb.add('T $n');
				for (v in s)
					sb.add(' ${pool.indexOf(v)}');
				out.push(sb.toString());
				n += 5;
			}
			T.eq(golden.length, out.length);
			var bad = 0;
			for (i in 0...golden.length) {
				T.checks++;
				if (golden[i] != out[i] && bad++ < 5)
					T.fail('line ${i + 1}:\n  go:   ${golden[i].substr(0, 200)}\n  haxe: ${(out[i] ?? "").substr(0, 200)}');
			}
			if (bad > 5)
				T.fail('$bad lines differ');
		});
	}
}

private class Rec {
	public final key:Int;
	public final id:Int;

	public function new(key:Int, id:Int) {
		this.key = key;
		this.id = id;
	}
}
