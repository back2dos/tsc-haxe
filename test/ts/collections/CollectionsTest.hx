package ts.collections;

import go.Slices;
import ts.json.Json;
import ts.collections.Cow;
import ts.collections.Multimap;
import ts.collections.OrderedMap;
import ts.collections.Syncmap;
import ts.collections.Syncset;

// Port of ordered_map_test.go, ordered_set_test.go and syncmap_test.go, plus extra checks
// (marked "extra") for the Haxe-specific parts: GoMap key kinds, nil receivers, iterators, JSON.
class CollectionsTest {
	public static function run() {
		// --- ordered_map_test.go ---

		T.run("TestOrderedMap", () -> {
			// PORT: zero value of V = string is "" (see OrderedMap.hx).
			final m = new OrderedMap<Int, String>("");

			T.isTrue(!m.Has(1));

			final N = 1000;
			final start = 1;
			final end = start + N;

			// Seed the map with ascending keys and values for easier testing.
			for (i in start...end) {
				m.Set(i, padInt(i));
			}

			T.eq(m.Size(), N);

			// Attempt to overwrite existing keys in reverse order.
			var i = end - 1;
			while (i >= start) {
				m.Set(i, padInt(i));
				i--;
			}

			T.eq(m.Size(), N);

			for (i in start...end) {
				final r = m.Get(i);
				T.isTrue(r.ok);
				T.eq(r.value, padInt(i));
			}

			for (k => v in m.Entries()) {
				T.eq(v, padInt(k));
			}

			final keys = Slices.Collect(m.Keys());
			T.eq(keys.length, N);
			T.isTrue(isSortedInt(keys));

			final values = Slices.Collect(m.Values());
			T.eq(values.length, N);
			T.isTrue(isSortedString(values));

			var firstKey = 0;
			for (k in m.Keys()) {
				firstKey = k;
				break;
			}
			T.eq(firstKey, start);

			var firstValue = "";
			for (v in m.Values()) {
				firstValue = v;
				break;
			}
			T.eq(firstValue, padInt(start));

			for (k => v in m.Entries()) {
				firstKey = k;
				firstValue = v;
				break;
			}

			T.eq(firstKey, start);
			T.eq(firstValue, padInt(start));

			for (i in start + 1...end) {
				var r = m.Delete(i);
				T.isTrue(r.ok);
				T.eq(r.value, padInt(i));
				T.isTrue(!m.Has(i));

				r = m.Get(i);
				T.isTrue(!r.ok);
				T.eq(r.value, "");

				r = m.Delete(i);
				T.isTrue(!r.ok);
				T.eq(r.value, "");
			}

			T.eq(m.Size(), 1);
			T.isTrue(m.Has(start));

			final r = m.Delete(start);
			T.isTrue(r.ok);
			T.eq(r.value, padInt(start));

			T.eq(m.Size(), 0);
		});

		T.run("TestOrderedMapClone", () -> {
			final m = new OrderedMap<Int, String>("");
			m.Set(1, "one");
			m.Set(2, "two");

			final clone = m.Clone();

			T.isTrue(clone != m);
			T.eq(clone.Size(), 2);
			T.eq(str(Slices.Collect(clone.Keys())), str([1, 2]));
			T.eq(str(Slices.Collect(clone.Values())), str(["one", "two"]));

			final r = clone.Get(1);
			T.isTrue(r.ok);
			T.eq(r.value, "one");

			m.Delete(1);

			T.eq(m.Size(), 1);
			T.eq(clone.Size(), 2);
			T.eq(str(Slices.Collect(clone.Keys())), str([1, 2]));
			T.eq(str(Slices.Collect(clone.Values())), str(["one", "two"]));
		});

		T.run("TestOrderedMapClear", () -> {
			final m = new OrderedMap<Int, String>("");
			m.Set(1, "one");
			m.Set(2, "two");

			m.Clear();

			T.eq(m.Size(), 0);
		});

		T.run("TestOrderedMapWithSizeHint", () -> {
			// PORT: Go measures allocations (testing.AllocsPerRun); not portable. The functional part is kept.
			final N = 1024;
			final m:OrderedMap<Int, Int> = Collections.NewOrderedMapWithSizeHint(N, 0);
			for (i in 0...N) {
				m.Set(i, i);
			}
			T.eq(m.Size(), N);
		});

		T.run("TestOrderedMapUnmarshalJSON", () -> {
			// t.Run("UnmarshalJSONV2", ...)
			final m = new OrderedMap<String, Any>();
			var err = m.UnmarshalJSONFrom('{"a": 1, "b": "two", "c": { "d": 4 } }');
			T.isTrue(err == null);

			T.eq(m.Size(), 3);
			T.isTrue((m.GetOrZero("a") : Float) == 1.0);

			err = m.UnmarshalJSONFrom('null');
			T.isTrue(err == null);

			err = m.UnmarshalJSONFrom('"foo"');
			T.isTrue(err != null && err.Error().indexOf("cannot unmarshal non-object JSON value into Map") >= 0);

			// PORT: skipped row — `OrderedMap[int, any]` must fail to unmarshal string keys. Type
			// parameters are erased in Haxe, UnmarshalJSONFrom supports K = String only.
		});

		// --- ordered_set_test.go ---

		T.run("TestOrderedSet", () -> {
			final s = new OrderedSet<Int>();

			s.Add(1);
			s.Add(2);
			s.Add(3);

			T.isTrue(s.Has(1));
			T.isTrue(s.Has(2));
			T.isTrue(s.Has(3));

			T.isTrue(s.Delete(2));

			final values = Slices.Collect(s.Values());
			T.eq(values.length, 2);
			T.isTrue(isSortedInt(values));

			s.Clear();

			T.eq(s.Size(), 0);
			T.isTrue(!s.Has(1));
			T.isTrue(!s.Has(2));
			T.isTrue(!s.Has(3));

			final s2 = s.Clone();
			T.isTrue(s != s2);
			T.eq(s2.Size(), 0);
		});

		T.run("TestOrderedSetWithSizeHint", () -> {
			// PORT: Go measures allocations (testing.AllocsPerRun); not portable. The functional part is kept.
			final N = 1024;
			final m:OrderedSet<Int> = Collections.NewOrderedSetWithSizeHint(N);
			for (i in 0...N) {
				m.Add(i);
			}
			T.eq(m.Size(), N);
		});

		// --- syncmap_test.go ---

		T.run("TestSyncMapWithNil", () -> {
			final m = new SyncMap<String, Any>();

			final got1 = m.Load("foo");
			T.isTrue(!got1.ok);
			T.eq(got1.value, null);

			m.Store("foo", null);

			final got2 = m.Load("foo");
			T.isTrue(got2.ok);
			T.eq(got2.value, null);

			final too = m.LoadOrStore("too", null);
			T.isTrue(!too.ok);
			T.eq(too.value, null);

			m.Range((k:String, v:Any) -> {
				return true;
			});
		});

		// --- extra ---

		T.run("ExtraOrderedMapOrderAfterDelete", () -> {
			final m = new OrderedMap<String, Int>(0);
			for (k in ["c", "a", "d", "b", "e"])
				m.Set(k, k.charCodeAt(0));
			m.Delete("c"); // first
			m.Delete("e"); // last
			m.Delete("d"); // middle
			m.Set("c", 1); // re-added at the end
			m.Set("a", 7); // overwrite keeps position
			T.eq(str(Slices.Collect(m.Keys())), str(["a", "b", "c"]));
			T.eq(str(Slices.Collect(m.Values())), str([7, "b".code, 1]));
			T.eq(m.GetOrZero("zz"), 0);
			final e = m.EntryAt(1);
			T.isTrue(e.c);
			T.eq(e.a, "b");
			T.eq(e.b, "b".code);
			final e2 = m.EntryAt(3);
			T.isTrue(!e2.c);
			T.eq(e2.b, 0);
			// Items added during iteration are visited (Go comment in Keys).
			final seen:Array<String> = [];
			for (k in m.Keys()) {
				seen.push(k);
				if (k == "a")
					m.Set("z", 0);
			}
			T.eq(str(seen), str(["a", "b", "c", "z"]));
		});

		T.run("ExtraOrderedMapNilReceiver", () -> {
			final m:OrderedMap<String, Int> = null;
			T.eq(m.Size(), 0);
			T.isTrue(m.Clone() == null);
			var n = 0;
			for (_ in m.Keys())
				n++;
			for (_ in m.Values())
				n++;
			for (_ => _ in m.Entries())
				n++;
			T.eq(n, 0);
			T.isTrue(Slices.Collect(m.Keys()) == null);
		});

		T.run("ExtraOrderedMapFromListAndDiff", () -> {
			final m1 = Collections.NewOrderedMapFromList([new MapEntry("a", 1), new MapEntry("b", 2), new MapEntry("c", 3)], 0);
			final m2 = Collections.NewOrderedMapFromList([new MapEntry("b", 2), new MapEntry("c", 4), new MapEntry("d", 5)], 0);
			final log:Array<String> = [];
			Collections.DiffOrderedMaps(m1, m2, (k, v) -> log.push('+$k=$v'), (k, v) -> log.push('-$k=$v'), (k, a, b) -> log.push('~$k=$a>$b'));
			T.eq(log.join(" "), "+d=5 -a=1 ~c=3>4");
		});

		T.run("ExtraOrderedMapMarshalJSON", () -> {
			final inner = new OrderedMap<String, Any>();
			inner.Set("z", true);
			inner.Set("y", null);
			final m = new OrderedMap<String, Any>();
			m.Set("10", 1);
			m.Set("b", "two\"");
			m.Set("2", [1, 2]);
			m.Set("a", inner);
			m.Set("arr", ([inner, "x"] : Array<Any>));
			final b = new StringBuf();
			T.isTrue(m.MarshalJSONTo(b) == null);
			T.eq(b.toString(), '{"10":1,"b":"two\\"","2":[1,2],"a":{"z":true,"y":null},"arr":[{"z":true,"y":null},"x"]}');
			final mi = new OrderedMap<Int, String>("");
			mi.Set(3, "x");
			mi.Set(1, "y");
			final b2 = new StringBuf();
			mi.MarshalJSONTo(b2);
			T.eq(b2.toString(), '{"3":"x","1":"y"}');
		});

		T.run("ExtraOrderedMapUnmarshalOrder", () -> {
			// Document order, also for integer-like keys (JS objects list those first).
			final m = new OrderedMap<String, Any>();
			T.isTrue(m.UnmarshalJSONFrom(' { "z" : 1, "b\\"q": [1, {"x": "}"}], "10": {"a": [] }, "a": "s,:" , "1": null, "m": -2.5e1 } ') == null);
			T.eq(str(Slices.Collect(m.Keys())), str(["z", "b\"q", "10", "a", "1", "m"]));
			T.eq(m.GetOrZero("a"), "s,:");
			T.isTrue(m.Has("1") && m.GetOrZero("1") == null);
			T.isTrue((m.GetOrZero("m") : Float) == -25.0);
			final arr:Array<Dynamic> = m.GetOrZero("b\"q");
			T.eq(arr.length, 2);
			T.eq(arr[1].x, "}");
			final e = new OrderedMap<String, Any>();
			T.isTrue(e.UnmarshalJSONFrom("{}") == null);
			T.eq(e.Size(), 0);
			T.isTrue(e.UnmarshalJSONFrom('{"a" 1}') != null);
			T.isTrue(e.UnmarshalJSONFrom('{"a": tru}') != null);
			T.isTrue(e.UnmarshalJSONFrom('{"a": 1') != null);
		});

		T.run("ExtraSetKeyKinds", () -> {
			// String keys
			final s = new Set<String>();
			T.isTrue(!s.Has("a"));
			s.Add("a");
			s.Add("a" + "b");
			T.isTrue(s.Has("ab"));
			T.isTrue(s.Has("a"));
			T.eq(s.Len(), 2);
			// String keys that look like Object.prototype members
			s.Add("__proto__");
			s.Add("constructor");
			T.isTrue(s.Has("__proto__") && s.Has("constructor") && !s.Has("toString"));
			T.eq(s.Len(), 4);
			// Int keys
			final si = new Set<Int>();
			si.Add(0);
			si.Add(-5);
			si.Add(0x7FFFFFFF);
			T.isTrue(si.Has(0) && si.Has(-5) && si.Has(0x7FFFFFFF) && !si.Has(1));
			T.eq(si.Len(), 3);
			si.Delete(0);
			T.isTrue(!si.Has(0));
			T.eq(si.Len(), 2);
			// Class-instance keys: identity, like Go *T
			final a = new Node(1);
			final a2 = new Node(1);
			final so = new Set<Node>();
			so.Add(a);
			T.isTrue(so.Has(a));
			T.isTrue(!so.Has(a2));
			so.Add(a2);
			so.Add(a);
			T.eq(so.Len(), 2);
			// Abstract over String (like tspath.Path) and enum abstract over Int
			final sp = new Set<Path>();
			sp.Add(new Path("/a"));
			T.isTrue(sp.Has(new Path("/" + "a")));
			final sk = new Set<Kind>();
			sk.Add(Kind.B);
			T.isTrue(sk.Has(Kind.B) && !sk.Has(Kind.A));
			// OrderedMap with class keys
			final om = new OrderedMap<Node, String>("");
			om.Set(a2, "a2");
			om.Set(a, "a");
			T.eq(om.GetOrZero(a), "a");
			T.eq(om.GetOrZero(new Node(1)), "");
			T.eq(Slices.Collect(om.Keys())[0], a2);
		});

		T.run("ExtraSetNilReceiver", () -> {
			final n:Set<String> = null;
			T.isTrue(!n.Has("x"));
			T.eq(n.Len(), 0);
			n.Clear();
			T.isTrue(n.Clone() == null);
			T.eq(n.Keys().length(), 0);
			T.isTrue(n.IsSubsetOf(null));
			T.isTrue(!n.Intersects(null));
			T.isTrue(n.Equals(null));
			T.isTrue(n.UnionedWith(null) == null);
			n.Union(new Set<String>()); // both empty: no panic in Go
			var panicked = false;
			try n.Union(Collections.NewSetFromItems("a")) catch (e:Dynamic) panicked = true;
			T.isTrue(panicked);
			final u = n.UnionedWith(Collections.NewSetFromItems("a"));
			T.isTrue(u.Has("a"));
			// zero-value Set (M == null)
			final z = new Set<String>();
			T.isTrue(z.M == null);
			T.isTrue(!z.Has("x"));
			T.eq(z.Len(), 0);
			T.isTrue(z.Equals(new Set<String>()));
			T.isTrue(z.Equals(Collections.NewSetWithSizeHint(4)));
		});

		T.run("ExtraSetOps", () -> {
			final a = Collections.NewSetFromItems("x", "y");
			final b = Collections.NewSetFromItems("y", "z");
			final items = ["x"];
			final c = Collections.NewSetFromItems(...items);
			T.isTrue(c.IsSubsetOf(a));
			T.isTrue(!a.IsSubsetOf(c));
			T.isTrue(a.Intersects(b));
			T.isTrue(!c.Intersects(b));
			T.isTrue(c.AddIfAbsent("q"));
			T.isTrue(!c.AddIfAbsent("q"));
			final u = a.UnionedWith(b);
			T.eq(u.Len(), 3);
			T.eq(a.Len(), 2);
			final cl = a.Clone();
			cl.Add("w");
			T.isTrue(!a.Has("w"));
			T.isTrue(!a.Equals(cl));
			cl.Delete("w");
			T.isTrue(a.Equals(cl));
			final e = new Set<String>();
			e.Union(b);
			T.isTrue(e.Equals(b));
			e.Union(a);
			T.eq(e.Len(), 3);
			var n = 0;
			for (k in e.Keys().keys())
				n++;
			T.eq(n, 3);
			e.Clear();
			T.eq(e.Len(), 0);
		});

		T.run("ExtraMultiMap", () -> {
			final m = Collections.GroupBy(["apple", "avocado", "banana", "blueberry", "cherry"], (s:String) -> s.charAt(0));
			T.eq(m.Len(), 3);
			T.eq(str(m.Get("a")), str(["apple", "avocado"]));
			T.isTrue(m.Get("z") == null);
			m.Remove("b", "banana");
			T.eq(str(m.Get("b")), str(["blueberry"]));
			m.Remove("b", "blueberry");
			T.isTrue(!m.Has("b"));
			m.Remove("c", "nope");
			T.eq(m.Len(), 2);
			var keys = 0;
			for (_ in m.Keys())
				keys++;
			var vals = 0;
			for (v in m.Values())
				vals += v.length;
			T.eq(keys, 2);
			T.eq(vals, 3);
			m.RemoveAll("a");
			T.eq(m.Len(), 1);
			m.Clear();
			T.eq(m.Len(), 0);
			final z = new MultiMap<Int, Node>();
			T.eq(z.Len(), 0);
			T.isTrue(!z.Has(1));
			for (_ in z.Keys())
				T.fail("empty");
			final h:MultiMap<String, Int> = Collections.NewMultiMapWithSizeHint(4);
			h.Add("x", 1);
			T.eq(h.Len(), 1);
		});

		T.run("ExtraCopyOnWrite", () -> {
			final c = new CopyOnWriteMap<String, Int>(0);
			T.isTrue(!c.Get("a").ok);
			T.eq(c.Get("a").value, 0);
			c.Set("a", 1);
			final restore = c.EnterScope();
			T.eq(c.Get("a").value, 1);
			c.Set("b", 2);
			c.Set("a", 3);
			T.isTrue(c.Has("b"));
			final restore2 = c.EnterScope();
			c.Set("c", 4);
			restore2();
			T.isTrue(!c.Has("c"));
			T.eq(c.Get("a").value, 3);
			restore();
			T.isTrue(!c.Has("b"));
			T.eq(c.Get("a").value, 1);

			final s = new CopyOnWriteSet<Node>();
			final n1 = new Node(1);
			final n2 = new Node(2);
			s.Add(n1);
			final r = s.EnterScope();
			s.Add(n2);
			T.isTrue(s.Has(n1) && s.Has(n2));
			r();
			T.isTrue(s.Has(n1) && !s.Has(n2));
		});

		T.run("ExtraSyncMapSet", () -> {
			final m = new SyncMap<String, Int>(0);
			T.eq(m.Load("x").value, 0);
			final r = m.LoadOrStore("x", 5);
			T.isTrue(!r.ok);
			T.eq(r.value, 5);
			final r2 = m.LoadOrStore("x", 6);
			T.isTrue(r2.ok);
			T.eq(r2.value, 5);
			m.Store("y", 7);
			T.eq(m.Size(), 2);
			final cl = m.Clone();
			m.Delete("x");
			T.eq(m.Size(), 1);
			T.eq(cl.Size(), 2);
			T.eq(cl.ToMap().get("x"), 5);
			var visited = 0;
			cl.Range((k, v) -> {
				visited++;
				return false;
			});
			T.eq(visited, 1);
			var keys = 0;
			for (_ in cl.Keys())
				keys++;
			T.eq(keys, 2);
			m.Clear();
			T.eq(m.Size(), 0);

			final s = new SyncSet<String>();
			T.isTrue(s.IsEmpty());
			T.isTrue(s.AddIfAbsent("a"));
			T.isTrue(!s.AddIfAbsent("a"));
			s.Add("b");
			T.isTrue(s.Has("b"));
			T.isTrue(!s.IsEmpty());
			T.eq(s.Size(), 2);
			final sl = s.ToSlice();
			sl.sort(Reflect.compare);
			T.eq(str(sl), str(["a", "b"]));
			s.Delete("a");
			T.isTrue(!s.Has("a"));
			var n = 0;
			s.Range(k -> {
				n++;
				return true;
			});
			for (_ in s.Keys())
				n++;
			T.eq(n, 2);
		});
	}

	static function padInt(n:Int):String {
		return StringTools.lpad(Std.string(n), " ", 10);
	}

	static function isSortedInt(a:Array<Int>):Bool {
		for (i in 1...a.length)
			if (a[i] < a[i - 1])
				return false;
		return true;
	}

	static function isSortedString(a:Array<String>):Bool {
		for (i in 1...a.length)
			if (a[i] < a[i - 1])
				return false;
		return true;
	}

	static function str(a:Null<Array<Dynamic>>):String {
		return a == null ? "nil" : "[" + a.join(",") + "]";
	}
}

private class Node {
	public final n:Int;

	public function new(n:Int) {
		this.n = n;
	}
}

private abstract Path(String) to String {
	public inline function new(s:String) {
		this = s;
	}
}

private enum abstract Kind(Int) to Int {
	var A = 1;
	var B = 2;
}
