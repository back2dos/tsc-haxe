package go;

import haxe.ds.IntMap;
import haxe.ds.StringMap;

// go.ForIn (cpp: `for` loops over StringMap / IntMap / IdentityMap run over arrays): every loop
// statement sees the same elements in the same order as the maps' own iterators (taken here
// through comprehensions, which go.ForIn does not rewrite), for object and Int values, `v` and
// `k => v` loops, `continue`/`break`, and a map changed during the loop. Also
// go.Slices.BinarySearchFuncInline against BinarySearchFunc.
class ForInTest {
	public static function run() {
		T.run("TestForInStringMap", () -> {
			final m = new StringMap<Box>();
			final mi = new StringMap<Int>();
			for (i in 0...50) {
				m.set("k" + (i * 7 % 50), new Box(i));
				mi.set("k" + i, i * 1000);
			}
			final ref = [for (v in m) v.n].join(",");
			final got = [];
			for (v in m)
				got.push(v.n);
			T.eq(ref, got.join(","));
			final refKV = [for (k in m.keys()) k + "=" + m.get(k).n].join(",");
			final gotKV = [];
			for (k => v in m)
				gotKV.push(k + "=" + v.n);
			T.eq(refKV, gotKV.join(","));
			final refI = [for (k in mi.keys()) k + "=" + mi.get(k)].join(",");
			final gotI = [];
			var sum = 0;
			for (k => v in mi) {
				gotI.push(k + "=" + v);
				sum += v; // Int arithmetic on the loop value
			}
			T.eq(refI, gotI.join(","));
			T.eq(1225000, sum);
			final vals = [];
			for (v in mi)
				vals.push(v);
			T.eq([for (v in mi) v].join(","), vals.join(","));
			// continue / break
			var seen = 0;
			for (v in m) {
				if (v.n % 2 == 0)
					continue;
				seen++;
				if (seen == 5)
					break;
			}
			T.eq(5, seen);
			// removing entries during a k => v loop: get() sees the removal (like MapKeyValueIterator)
			final keys = [for (k in m.keys()) k];
			var nulls = 0;
			for (k => v in m) {
				if (k == keys[0])
					m.remove(keys[1]);
				if (v == null)
					nulls++;
			}
			T.eq(1, nulls);
		});
		T.run("TestForInIntMap", () -> {
			final m = new IntMap<Box>();
			for (i in 0...40)
				m.set(i * 37 % 101, new Box(i));
			final got = [];
			for (k => v in m)
				got.push(k + "=" + v.n);
			T.eq([for (k in m.keys()) k + "=" + m.get(k).n].join(","), got.join(","));
			final vs = [];
			for (v in m)
				vs.push(v.n);
			T.eq([for (v in m) v.n].join(","), vs.join(","));
		});
		T.run("TestForInIdentityMap", () -> {
			final m = new IdentityMap<Box, Int>();
			final boxes = [for (i in 0...30) new Box(i)];
			for (b in boxes)
				m.set(b, b.n * 3);
			m.remove(boxes[4]);
			final got = [];
			for (k => v in m) {
				got.push(k.n + "=" + v);
				if (k == boxes[0])
					m.set(boxes[1], -1); // a snapshot: the loop still sees the old value
			}
			T.eq([for (i in 0...30) if (i != 4) i + "=" + (i * 3)].join(","), got.join(","));
			final vs = [];
			for (v in m)
				vs.push(v);
			T.eq([for (v in m) v].join(","), vs.join(","));
		});
		T.run("TestBinarySearchFuncInline", () -> {
			final xs = [1, 3, 3, 5, 9, 12];
			for (t in [-1, 0, 1, 2, 3, 4, 5, 9, 10, 12, 13]) {
				final a = Slices.BinarySearchFunc(xs, t, (x:Int, y:Int) -> x - y);
				final b = Slices.BinarySearchFuncInline(xs, t, (x, y) -> x - y);
				T.eq(a.value, b.value);
				T.eq(a.ok, b.ok);
			}
			final e = Slices.BinarySearchFuncInline(null, 3, (x:Int, y:Int) -> x - y);
			T.eq(0, e.value);
			T.eq(false, e.ok);
		});
		T.run("TestStringsIntern", () -> {
			final a = "ab" + Std.string(Std.random(1)); // run-time string "ab0"
			final i = Strings.Intern(a);
			T.isTrue(i == "ab0");
			final m = new StringMap<Int>();
			m.set(i, 1);
			T.eq(1, m.get("ab0"));
			T.eq(1, m.get(Strings.Intern("a" + "b0")));
		});
	}
}

private class Box {
	public final n:Int;

	public function new(n:Int) {
		this.n = n;
	}
}
