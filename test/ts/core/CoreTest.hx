package ts.core;

import go.Context;
import go.Errors;
import go.GoMap;
import go.Tuple;
import ts.collections.Syncset;

// Test node for the TextRange inline-property check: pos/end stored as Int fields, `Loc` an
// inline property (the AST lane's planned layout).
class LocNode {
	public var pos:Int = -1;
	public var end:Int = -1;

	public var Loc(get, set):TextRange;

	public function new() {}

	inline function get_Loc():TextRange {
		return new TextRange(pos, end);
	}

	inline function set_Loc(v:TextRange):TextRange {
		pos = v.Pos();
		end = v.End();
		return v;
	}
}

// Port of bfs_test.go and pattern_test.go, plus extra checks (marked "extra") that exercise every
// public helper of core.go once and the other files. Expected values that are not obvious were
// computed by running the Go code at the pin (go run with an overlay).
class CoreTest {
	static function sortedStrings(a:Array<String>):Array<String> {
		final c = a.copy();
		c.sort((x, y) -> x < y ? -1 : (x > y ? 1 : 0));
		return c;
	}

	static function str<T>(a:Null<Array<T>>):String {
		return a == null ? "nil" : "[" + a.join(" ") + "]";
	}

	static function seq<T>(a:Array<T>):Iterator<T> {
		return a.iterator();
	}

	// NOTE (hxcpp): a generic helper returns an Array wrapped in cpp.VirtualArray; comparing the
	// call result directly with `==` compares the wrapper (false on cpp even for the same array,
	// also through a local: the analyzer propagates it). Go cannot compare slices with == either:
	// identity is checked with Core.Same (inline, which works on cpp), as upstream does.
	static function sameInGeneric<T>(s:Array<T>, f:(T) -> Bool):Bool {
		return Core.Same(Core.Filter(s, f), s);
	}

	public static function run() {
		// --- bfs_test.go ---

		T.run("TestBreadthFirstSearchParallel", () -> {
			// basic functionality
			{
				// Test basic functionality with a simple DAG
				// Graph: A -> B, A -> C, B -> D, C -> D
				final graph = ["A" => ["B", "C"], "B" => ["D"], "C" => ["D"], "D" => []];

				final children = (node:String) -> graph.get(node);

				// find specific node
				{
					final result = Core.BreadthFirstSearchParallel("A", children, (node:String) -> new Pair(node == "D", true));
					T.eq(true, result.Stopped);
					T.eq("[D B A]", str(result.Path));
				}

				// visit all nodes
				{
					var visitedNodes:Array<String> = [];
					final result = Core.BreadthFirstSearchParallel("A", children, (node:String) -> {
						visitedNodes.push(node);
						return new Pair(false, false); // Never stop early
					});

					// Should return nil since we never return true
					T.eq(false, result.Stopped);
					T.isTrue(result.Path == null, "Expected nil path when visit function never returns true");

					// Should visit all nodes exactly once
					T.eq("[A B C D]", str(sortedStrings(visitedNodes)));
				}
			}

			// early termination
			{
				// Test that nodes below the target level are not visited
				final graph = [
					"Root" => ["L1A", "L1B"],
					"L1A" => ["L2A", "L2B"],
					"L1B" => ["L2C"],
					"L2A" => ["L3A"],
					"L2B" => [],
					"L2C" => [],
					"L3A" => []
				];

				final children = (node:String) -> graph.get(node);

				final visited = new SyncSet<String>();
				Core.BreadthFirstSearchParallelEx("Root", children, (node:String) -> {
					return new Pair(node == "L2B", true); // Stop at level 2
				}, new BreadthFirstSearchOptions<String, String>(visited), Core.Identity);

				T.isTrue(visited.Has("Root"), "Expected to visit Root");
				T.isTrue(visited.Has("L1A"), "Expected to visit L1A");
				T.isTrue(visited.Has("L1B"), "Expected to visit L1B");
				T.isTrue(visited.Has("L2A"), "Expected to visit L2A");
				T.isTrue(visited.Has("L2B"), "Expected to visit L2B");
				// L2C is non-deterministic
				T.isTrue(!visited.Has("L3A"), "Expected not to visit L3A");
			}

			// returns fallback when no other result found
			{
				// Test that fallback behavior works correctly
				final graph = ["A" => ["B", "C"], "B" => ["D"], "C" => ["D"], "D" => []];

				final children = (node:String) -> graph.get(node);

				final visited = new SyncSet<String>();
				final result = Core.BreadthFirstSearchParallelEx("A", children, (node:String) -> {
					return new Pair(node == "A", false); // Record A as a fallback, but do not stop
				}, new BreadthFirstSearchOptions<String, String>(visited), Core.Identity);

				T.eq(false, result.Stopped);
				T.eq("[A]", str(result.Path));
				T.isTrue(visited.Has("B"), "Expected to visit B");
				T.isTrue(visited.Has("C"), "Expected to visit C");
				T.isTrue(visited.Has("D"), "Expected to visit D");
			}

			// returns a stop result over a fallback
			{
				// Test that a stop result is preferred over a fallback
				final graph = ["A" => ["B", "C"], "B" => ["D"], "C" => ["D"], "D" => []];

				final children = (node:String) -> graph.get(node);

				final result = Core.BreadthFirstSearchParallel("A", children, (node:String) -> {
					switch (node) {
						case "A":
							return new Pair(true, false); // Record fallback
						case "D":
							return new Pair(true, true); // Stop at D
						default:
							return new Pair(false, false);
					}
				});

				T.eq(true, result.Stopped);
				T.eq("[D B A]", str(result.Path));
			}
		});

		// extra: PreprocessLevel / BreadthFirstSearchLevel
		T.run("BreadthFirstSearchLevel (extra)", () -> {
			final graph = ["A" => ["B", "C"], "B" => ["D"], "C" => ["E"], "D" => [], "E" => []];
			final seen:Array<String> = [];
			final opts = new BreadthFirstSearchOptions<String, String>(null, (level:BreadthFirstSearchLevel<String, String>) -> {
				level.Range(n -> {
					seen.push(n);
					return true;
				});
				if (level.Has("B"))
					level.Delete("B");
			});
			final result = Core.BreadthFirstSearchParallelEx("A", n -> graph.get(n), n -> new Pair(n == "D", true), opts, Core.Identity);
			T.eq(false, result.Stopped);
			T.eq(null, result.Path);
			T.eq("[A B C E]", str(seen));
		});

		// --- pattern_test.go ---

		T.run("TestPatternOverlappingMatch", () -> {
			final p = Core.TryParsePattern("ab*ab");
			T.isTrue(!p.Matches("ab"), "expected 'ab' not to match 'ab*ab'");
			T.isTrue(p.Matches("abXab"), "expected 'abXab' to match 'ab*ab'");
			T.eq("X", p.MatchedText("abXab"));
			T.isTrue(p.Matches("abab"), "expected 'abab' to match 'ab*ab'");
			T.eq("", p.MatchedText("abab"));
		});

		T.run("Pattern (extra)", () -> {
			// Go: {"" 0} {"*" 0} {"abc" -1}
			final p1 = Core.TryParsePattern("a*b*c");
			T.isTrue(p1.Equals(new Pattern()));
			T.eq("", p1.Text);
			T.eq(0, p1.StarIndex);
			final p2 = Core.TryParsePattern("*");
			T.eq("*", p2.Text);
			T.eq(0, p2.StarIndex);
			T.isTrue(p2.IsValid());
			final p3 = Core.TryParsePattern("abc");
			T.eq(-1, p3.StarIndex);
			T.isTrue(p3.Matches("abc"));
			T.eq("", p3.MatchedText("abc"));
			var threw = false;
			try
				p3.MatchedText("x")
			catch (e:Dynamic)
				threw = true;
			T.isTrue(threw);
			final values = ["*", "a*", "ab*", "abc"];
			T.eq("ab*", Core.FindBestPatternMatch(values, Core.TryParsePattern, "abz"));
			T.eq("abc", Core.FindBestPatternMatch(values, Core.TryParsePattern, "abc"));
			T.eq("", Core.FindBestPatternMatch(["a*"], Core.TryParsePattern, "b", ""));
			T.eq(null, Core.FindBestPatternMatch(["a*"], Core.TryParsePattern, "b"));
		});

		// --- extra: core.go generic helpers ---

		T.run("Filter/Map family (extra)", () -> {
			final even = (x:Int) -> x % 2 == 0;
			final nilInts:Null<Array<Int>> = null;
			// Go: nil [] [] [2 4]
			T.eq("nil", str(Core.Filter(nilInts, even)));
			final empty:Array<Int> = [];
			T.isTrue(Core.Same(Core.Filter(empty, even), empty));
			final all = [2, 4];
			T.isTrue(Core.Same(Core.Filter(all, even), all)); // same slice when nothing is removed
			T.eq("[]", str(Core.Filter([1, 3], even)));
			T.eq("[2 4]", str(Core.Filter([2, 3, 4, 5], even)));

			T.eq("[2 4]", str([for (x in Core.FilterSeq([1, 2, 3, 4, 5], even)) x]));
			T.eq("[]", str([for (x in Core.FilterSeq(nilInts, even)) x]));

			T.eq("[1 4]", str(Core.FilterIndex([1, 2, 3, 4], (x, i, s) -> i != 1 && i != 2 && s.length == 4)));
			T.isTrue(Core.Same(Core.FilterIndex(all, (x, i, s) -> true), all));

			T.eq("nil", str(Core.Map(nilInts, x -> x + 1)));
			T.eq("[]", str(Core.Map(empty, x -> x + 1)));
			T.eq("[2 3]", str(Core.Map([1, 2], x -> x + 1)));
			T.eq("[a0 b1]", str(Core.MapIndex(["a", "b"], (x, i) -> x + i)));
			T.eq("nil", str(Core.MapIndex(nilInts, (x, i) -> x)));

			final tm = Core.TryMap([1, 2], x -> new ValueError<Int>(x * 10, null));
			T.eq("[10 20]", str(tm.value));
			T.eq(null, tm.err);
			final err = Errors.New("bad");
			final tm2 = Core.TryMap([1, 2], x -> new ValueError<Int>(x, x == 2 ? err : null));
			T.eq(null, tm2.value);
			T.eq(err, tm2.err);
			final tm3 = Core.TryMap(empty, x -> new ValueError<Int>(x, null));
			T.eq(null, tm3.value);

			// Go: [1 2] nil
			T.eq("[1 2]", str(Core.MapNonNil([0, 1, 0, 2], x -> x)));
			T.eq("nil", str(Core.MapNonNil(["", ""], x -> x)));
			final o = {};
			T.eq(1, Core.MapNonNil([1, 2], x -> x == 1 ? o : null).length);

			T.eq("[2 6]", str(Core.MapFiltered([1, 2, 3], x -> new ValueOk<Int>(x * 2, x != 2))));
			T.eq("nil", str(Core.MapFiltered([1], x -> new ValueOk<Int>(x, false))));

			T.eq("nil", str(Core.FlatMap([1, 2], x -> (null : Array<Int>))));
			T.eq("[1 1 2 2]", str(Core.FlatMap([1, 2], x -> [x, x])));

			final s = ["a", "b", "c"];
			T.isTrue(Core.Same(Core.SameMap(s, x -> x), s));
			final sm = Core.SameMap(s, x -> x == "b" ? "B" : x);
			T.isTrue(sm != s);
			T.eq("[a B c]", str(sm));
			T.isTrue(Core.Same(Core.SameMapIndex(s, (x, i) -> x), s));
			T.eq("[a b C]", str(Core.SameMapIndex(s, (x, i) -> i == 2 ? "C" : x)));

			T.isTrue(Core.Same(s, s));
			T.isTrue(sameInGeneric([1, 2], x -> true));
			T.isTrue(sameInGeneric(["a"], x -> true));
			T.isTrue(sameInGeneric([new Stack<Int>()], x -> true));
			T.isTrue(!sameInGeneric([1, 2], x -> x == 1));
			final objs = [new Stack<Int>(), new Stack<Int>()];
			T.isTrue(Core.Same(Core.Filter(objs, x -> true), objs));
			T.isTrue(!Core.Same(Core.Filter(objs, x -> x == objs[0]), objs));
			T.isTrue(!Core.Same(Core.Map(objs, x -> x), objs));
			T.isTrue(!Core.Same(Core.Map([1, 2], x -> x), [1, 2]));
			T.isTrue(!Core.Same(s, s.copy()));
			T.isTrue(Core.Same(nilInts, empty));
			T.isTrue(!Core.Same([1], [1, 2]));
		});

		T.run("Find family (extra)", () -> {
			final nilInts:Null<Array<Int>> = null;
			final xs = [1, 2, 3, 4];
			T.isTrue(Core.Some(xs, x -> x == 3));
			T.isTrue(!Core.Some(nilInts, x -> true));
			T.isTrue(Core.Every(xs, x -> x > 0));
			T.isTrue(!Core.Every(xs, x -> x > 1));
			T.isTrue(Core.Every(nilInts, x -> false));
			final or = Core.Or((x:Int) -> x == 1, (x:Int) -> x == 3);
			T.isTrue(or(1) && or(3) && !or(2));
			T.isTrue(!Core.Or()(1));

			T.eq(2, Core.Find(xs, x -> x % 2 == 0));
			T.eq(null, Core.Find(["a"], x -> x == "b"));
			T.eq("", Core.Find(["a"], x -> x == "b", ""));
			T.eq(4, Core.FindLast(xs, x -> x % 2 == 0));
			T.eq(0, Core.FindLast(nilInts, x -> true, 0));
			T.eq(1, Core.FindIndex(xs, x -> x % 2 == 0));
			T.eq(-1, Core.FindIndex(nilInts, x -> true));
			T.eq(3, Core.FindLastIndex(xs, x -> x % 2 == 0));
			T.eq(-1, Core.FindLastIndex(xs, x -> x > 9));

			T.eq(1, Core.FirstOrNil(xs));
			T.eq(null, Core.FirstOrNil(([] : Array<String>)));
			T.eq("", Core.FirstOrNil(([] : Array<String>), ""));
			T.eq(4, Core.LastOrNil(xs));
			T.eq(0, Core.LastOrNil(nilInts, 0));
			T.eq(null, Core.LastOrNil(([] : Array<String>)));
			T.eq(3, Core.ElementOrNil(xs, 2));
			T.eq(0, Core.ElementOrNil(xs, 4, 0));
			T.eq(null, Core.ElementOrNil(["a"], 4));
			T.eq(1, Core.FirstOrNilSeq(seq(xs)));
			T.eq(null, Core.FirstOrNilSeq(seq(([] : Array<String>))));
			T.eq("z", Core.FirstOrNilSeq(null, "z"));

			T.eq("b", Core.FirstNonNil(["", "b", "c"], x -> x));
			T.eq(null, Core.FirstNonNil(["", ""], x -> x));
			T.eq(3, Core.FirstNonNil([0, 3], x -> x));
			T.eq(2, Core.FirstNonZero(0, 2, 3));
			T.eq(0, Core.FirstNonZero(0, 0));
			T.eq("x", Core.FirstNonZero("", "x"));
			T.eq(null, Core.FirstNonZero((null : String), null));

			T.eq(4, Core.CountWhere([1, 2, 3, 4, 5], x -> x < 5));
			T.eq(0, Core.CountWhere(nilInts, x -> true));
		});

		T.run("Slice building (extra)", () -> {
			final nilInts:Null<Array<Int>> = null;
			final a = [1, 2];
			final empty:Array<Int> = [];
			T.isTrue(Core.Same(Core.Concatenate(a, empty), a));
			T.isTrue(Core.Same(Core.Concatenate(nilInts, a), a));
			T.isTrue(Core.Same(Core.Concatenate(a, nilInts), a));
			T.eq(null, Core.Concatenate(nilInts, nilInts));
			final c = Core.Concatenate(a, [3]);
			T.eq("[1 2 3]", str(c));
			T.eq("[1 2]", str(a));

			// Go: [1 3] nil [1 2 9 8 3] [1 2 3 7] nil
			T.eq("[1 3]", str(Core.Splice([1, 2, 3], 1, 1)));
			T.eq("nil", str(Core.Splice([1, 2, 3], 0, 3)));
			T.eq("[1 2 9 8 3]", str(Core.Splice([1, 2, 3], -1, 0, 9, 8)));
			T.eq("[1 2 3 7]", str(Core.Splice([1, 2, 3], 5, 2, 7)));
			T.eq("nil", str(Core.Splice(nilInts, 0, 0)));
			final s3 = [1, 2, 3];
			T.isTrue(Core.Same(Core.Splice(s3, 1, 0), s3));

			final re = Core.ReplaceElement(a, 0, 9);
			T.eq("[9 2]", str(re));
			T.eq("[1 2]", str(a));

			// Go: [1 3 4 5] [1 3 3 5]
			T.eq("[1 3 4 5]", str(Core.InsertSorted([1, 3, 5], 4, (x, y) -> x - y)));
			T.eq("[1 3 3 5]", str(Core.InsertSorted([1, 3, 5], 3, (x, y) -> x - y)));
			T.eq("[7]", str(Core.InsertSorted(nilInts, 7, (x, y) -> x - y)));

			// Go: [1 1]
			T.eq("[1 1]", str(Core.MinAllFunc([3, 1, 2, 1], (x, y) -> x - y)));
			T.eq("nil", str(Core.MinAllFunc(nilInts, (x, y) -> x - y)));

			final u = [1, 2];
			T.isTrue(Core.Same(Core.AppendIfUnique(u, 2), u));
			T.eq("[1 2 3]", str(Core.AppendIfUnique(u, 3)));
			T.eq("[5]", str(Core.AppendIfUnique(nilInts, 5)));

			// Go: nil [1 2 3]
			T.eq("nil", str(Core.Flatten([null, []])));
			T.eq("[1 2 3]", str(Core.Flatten([[1], null, [2, 3]])));

			// Go: [1 2 3 4] [1 2]
			T.eq("[1 2 3 4]", str(Core.Deduplicate([1, 2, 1, 3, 2, 4])));
			final d = [1, 2];
			T.isTrue(Core.Same(Core.Deduplicate(d), d));
			T.eq("[a b]", str(Core.Deduplicate(["a", "b", "a"])));
			// Go: [1 2 3 4]
			T.eq("[1 2 3 4]", str(Core.DeduplicateSorted([1, 1, 2, 3, 3, 3, 4], (x, y) -> x == y)));
			T.eq("nil", str(Core.DeduplicateSorted(nilInts, (x, y) -> x == y)));

			T.eq("nil", str(Core.SingleElementSlice((null : String))));
			T.eq("[x]", str(Core.SingleElementSlice("x")));

			final cd = ["a", "b"];
			T.isTrue(Core.Same(Core.CheckEachDefined(cd, "msg"), cd));
			var threw = "";
			try
				Core.CheckEachDefined(["a", null], "undefined!")
			catch (e:String)
				threw = e;
			T.eq("undefined!", threw);

			T.isTrue(Core.UnorderedEqual([1, 2, 2, 3], [2, 3, 1, 2]));
			T.isTrue(!Core.UnorderedEqual([1, 2, 2], [1, 1, 2]));
			T.isTrue(!Core.UnorderedEqual([1], [1, 1]));
			T.isTrue(Core.UnorderedEqual(nilInts, []));
			T.isTrue(Core.UnorderedEqual(["a", "b"], ["b", "a"]));

			T.eq(3, Core.len([1, 2, 3]));
			T.eq(0, Core.len(nilInts));
		});

		T.run("Small helpers (extra)", () -> {
			var calls = 0;
			final m = Core.Memoize(() -> {
				calls++;
				return "v";
			});
			T.eq("v", m());
			T.eq("v", m());
			T.eq(1, calls);

			T.eq(1, Core.IfElse(true, 1, 2));
			T.eq("b", Core.IfElse(false, "a", "b"));
			T.eq(5, Core.OrElse(0, 5));
			T.eq(3, Core.OrElse(3, 5));
			T.eq("|]", Core.OrElse("", "|]"));
			T.eq("x", Core.OrElse("x", "|]"));
			final o1 = new Stack<Int>(), o2 = new Stack<Int>();
			T.eq(o2, Core.OrElse((null : Stack<Int>), o2));
			T.eq(o1, Core.OrElse(o1, o2));
			T.eq(TSTrue, Core.OrElse(TSUnknown, TSTrue));
			T.eq(o2, Core.Coalesce(null, o2));
			T.eq(o1, Core.Coalesce(o1, o2));

			T.eq(7, Core.Must(7, null));
			final err = Errors.New("must");
			var threw:Dynamic = null;
			try
				Core.Must(7, err)
			catch (e:Dynamic)
				threw = e;
			T.eq(err, threw);
			T.eq("a", Core.FirstResult("a", 1, true));
			T.eq(9, Core.Identity(9));

			final js = Core.StringifyJson([1, 2], "", "");
			T.eq("[1,2]", js.value);
			T.eq(null, js.err);
			T.isTrue(Core.StringifyJson([1], "p", " ").err != null);

			// Go: 4 3 -1
			T.eq(4, Core.IndexAfter("abcabc", "bc", 2));
			T.eq(3, Core.IndexAfter("abc", "", 3));
			T.eq(-1, Core.IndexAfter("abc", "x", 0));

			T.eq(1, Core.CompareBooleans(true, false));
			T.eq(-1, Core.CompareBooleans(false, true));
			T.eq(0, Core.CompareBooleans(true, true));

			T.eq(5, Core.UTF16Len("a\u{1F600}bc"));

			// Go: ScriptKindTS ScriptKindJS ScriptKindUnknown ScriptKindJSON
			T.eq(ScriptKindTS, Core.GetScriptKindFromFileName("a.D.TS"));
			T.eq(ScriptKindJS, Core.GetScriptKindFromFileName("a.mjs"));
			T.eq(ScriptKindJSX, Core.GetScriptKindFromFileName("a.jsx"));
			T.eq(ScriptKindTSX, Core.GetScriptKindFromFileName("a.tsx"));
			T.eq(ScriptKindUnknown, Core.GetScriptKindFromFileName("noext"));
			T.eq(ScriptKindJSON, Core.GetScriptKindFromFileName("x.json"));

			final opts = new CompilerOptions();
			T.isTrue(!Core.ShouldRewriteModuleSpecifier("./a.ts", opts));
			opts.RewriteRelativeImportExtensions = TSTrue;
			T.isTrue(Core.ShouldRewriteModuleSpecifier("./a.ts", opts));
			T.isTrue(!Core.ShouldRewriteModuleSpecifier("./a.d.ts", opts));
			T.isTrue(!Core.ShouldRewriteModuleSpecifier("a.ts", opts));
			T.isTrue(!Core.ShouldRewriteModuleSpecifier("./a.js", opts));

			Core.ApplyDebugStackLimit(); // no-op
			T.isTrue(true);
		});

		T.run("Seq helpers (extra)", () -> {
			T.eq("[1 2 3]", str([for (x in Core.ConcatenateSeq(seq([1]), null, seq(([] : Array<Int>)), seq([2, 3]))) x]));
			final pairs = [];
			for (i => v in Core.Enumerate(seq(["a", "b"])))
				pairs.push('$i$v');
			T.eq("[0a 1b]", str(pairs));
			// early stop (Go: yield returns false)
			var n = 0;
			for (x in Core.ConcatenateSeq(seq([1, 2]), seq([3]))) {
				n++;
				if (x == 2)
					break;
			}
			T.eq(2, n);
		});

		T.run("Maps (extra)", () -> {
			final m1 = new GoMap<String, Int>();
			m1.set("a", 1);
			m1.set("b", 2);
			m1.set("c", 3);
			final m2 = new GoMap<String, Int>();
			m2.set("b", 2);
			m2.set("c", 4);
			m2.set("d", 5);
			final log:Array<String> = [];
			Core.DiffMaps(m1, m2, (k, v) -> log.push('+$k$v'), (k, v) -> log.push('-$k$v'), (k, a, b) -> log.push('~$k$a$b'));
			T.eq("[+d5 -a1 ~c34]", str(sortedStrings(log)));
			final log2:Array<String> = [];
			Core.DiffMapsFunc(null, m2, (a:Int, b:Int) -> a == b, (k, v) -> log2.push('+$k'), null, null);
			T.eq("[+b +c +d]", str(sortedStrings(log2)));

			final cp = Core.CopyMapInto(null, m1);
			T.isTrue(cp != m1);
			T.eq(3, cp.length());
			final dst = new GoMap<String, Int>();
			dst.set("z", 0);
			T.isTrue(Core.CopyMapInto(dst, m2) == dst);
			T.eq(4, dst.length());
			T.eq(null, Core.CopyMapInto((null : GoMap<String, Int>), null));
		});

		T.run("ECMALineStarts (extra)", () -> {
			// Go (bytes): [0 3 5 7 11 16] → UTF-16 offsets: U+2028 is 1 unit, U+0085 is not a line break.
			final text = "a\r\nb\rc\nd e\u0085f\r";
			final ls = Core.ComputeECMALineStarts(text);
			T.eq("[0 3 5 7 9 13]", str(ls));
			T.eq("[0]", str(Core.ComputeECMALineStarts("")));
			T.eq("[0 3]", str(Core.ComputeECMALineStarts("\u{1F600}\n")));
			// Go: 2 0 (byte position 5); UTF-16 position 5 is the same place here.
			final p = Core.PositionToLineAndByteOffset(5, ls);
			T.eq(2, p.a);
			T.eq(0, p.b);
			final p2 = Core.PositionToLineAndByteOffset(10, ls);
			T.eq(4, p2.a);
			T.eq(1, p2.b);
			// early stop of the Seq
			final it = Core.ComputeECMALineStartsSeq(text);
			T.eq(0, it.next());
			T.eq(3, it.next());
		});

		T.run("GetSpellingSuggestion (extra)", () -> {
			final cands = [
				"length", "lenght", "width", "Length", "len", "lengthy", "ab", "AB", "string", "strng", "stirng", "toString", "tostring"
			];
			// Go results:
			final expected = [
				"lenth" => "length", "Lenght" => "lenght", "ab" => "AB", "strin" => "string", "tostrin" => "tostring", "xyz" => "", "length" => "Length",
				"ToString" => "toString", "a" => ""
			];
			for (name => want in expected) {
				T.eq(want, Core.GetSpellingSuggestionForStrings(name, seq(cands)));
			}
			// Go: hallo (candidate length is in UTF-8 bytes)
			T.eq("hallo", Core.GetSpellingSuggestionForStrings("héllo", seq(["hello", "héllö", "hallo"])));
		});

		T.run("BinarySearchUniqueFunc (extra)", () -> {
			// Go: 2 true 2 false
			final r = Core.BinarySearchUniqueFunc([1, 3, 5, 7], (i, e) -> e - 5);
			T.eq(2, r.value);
			T.eq(true, r.ok);
			final r2 = Core.BinarySearchUniqueFunc([1, 3, 5, 7], (i, e) -> e - 4);
			T.eq(2, r2.value);
			T.eq(false, r2.ok);
			final r3 = Core.BinarySearchUniqueFunc(([] : Array<Int>), (i, e) -> 0);
			T.eq(0, r3.value);
			T.eq(false, r3.ok);
		});

		// --- extra: other files ---

		T.run("Stringers (extra)", () -> {
			// Go: ScriptTarget(13) ESNext ModuleKind(8) Preserve Tristate(3) ScriptKind(-1) LanguageVariantJSX
			T.eq("ScriptTarget(13)", (13 : ScriptTarget).String());
			T.eq("ESNext", ScriptTarget.ScriptTargetLatest.String());
			T.eq("ES2025", ScriptTarget.ScriptTargetLatestStandard.String());
			T.eq("None", ScriptTarget.ScriptTargetNone.String());
			T.eq("JSON", ScriptTarget.ScriptTargetJSON.String());
			T.eq("ModuleKind(8)", (8 : ModuleKind).String());
			T.eq("Preserve", ModuleKind.ModuleKindPreserve.String());
			T.eq("Node20", ModuleKind.ModuleKindNode20.String());
			T.eq("ES2022", ModuleKind.ModuleKindES2022.String());
			T.eq("NodeNext", ModuleKind.ModuleKindNodeNext.String());
			T.eq("Tristate(3)", (3 : Tristate).String());
			T.eq("TSUnknown", Tristate.TSUnknown.String());
			T.eq("TSFalse", Tristate.TSFalse.String());
			T.eq("ScriptKind(-1)", (-1 : ScriptKind).String());
			T.eq("ScriptKindDeferred", ScriptKind.ScriptKindDeferred.String());
			T.eq("LanguageVariantJSX", LanguageVariant.LanguageVariantJSX.String());
			T.eq("LanguageVariant(2)", (2 : LanguageVariant).String());
			T.eq("Bundler", ModuleResolutionKind.ModuleResolutionKindBundler.String());
			T.eq("react-jsxdev", JsxEmit.JsxEmitReactJSXDev.String());
			var threw = false;
			try
				ModuleResolutionKind.ModuleResolutionKindUnknown.String()
			catch (e:Dynamic)
				threw = true;
			T.isTrue(threw);
		});

		T.run("Tristate (extra)", () -> {
			T.isTrue(TSTrue.IsTrue() && TSTrue.IsTrueOrUnknown() && TSUnknown.IsTrueOrUnknown() && !TSFalse.IsTrueOrUnknown());
			T.isTrue(TSFalse.IsFalse() && TSFalse.IsFalseOrUnknown() && TSUnknown.IsFalseOrUnknown() && TSUnknown.IsUnknown());
			T.eq(TSTrue, TSUnknown.DefaultIfUnknown(TSTrue));
			T.eq(TSFalse, TSFalse.DefaultIfUnknown(TSTrue));
			T.eq(TSTrue, Tristate.UnmarshalJSON("true"));
			T.eq(TSFalse, Tristate.UnmarshalJSON("false"));
			T.eq(TSUnknown, Tristate.UnmarshalJSON("null"));
			T.eq("true", TSTrue.MarshalJSON());
			T.eq("null", TSUnknown.MarshalJSON());
			T.eq(TSTrue, Core.BoolToTristate(true));
			T.eq(TSFalse, Core.BoolToTristate(false));
		});

		T.run("CompilerOptions (extra)", () -> {
			final opts = new CompilerOptions();
			// Go: ES2022 Bundler 1 true
			T.eq(ModuleKindES2022, opts.GetEmitModuleKind());
			T.eq(ModuleResolutionKindBundler, opts.GetModuleResolutionKind());
			T.eq(ModuleDetectionKindAuto, opts.GetEmitModuleDetectionKind());
			T.isTrue(opts.GetResolveJsonModule());
			T.eq(ScriptTargetES2025, opts.GetEmitScriptTarget());
			T.isTrue(opts.GetEmitStandardClassFields());
			T.isTrue(opts.GetUseDefineForClassFields());
			T.isTrue(opts.GetStrictOptionValue(TSUnknown));
			T.isTrue(!opts.GetAllowJS());
			T.eq("", opts.GetPathsBasePath("/cwd"));
			T.isTrue(opts.HasJsonModuleEmitEnabled());

			// Go: [/a/b/node_modules/@types /a/node_modules/@types /node_modules/@types] false
			final tr = opts.GetEffectiveTypeRoots("/a/b");
			T.eq("[/a/b/node_modules/@types /a/node_modules/@types /node_modules/@types]", str(tr.value));
			T.eq(false, tr.ok);

			opts.Module = ModuleKindNodeNext;
			opts.Target = ScriptTargetES2015;
			opts.Types = ["*"];
			opts.MaxNodeModuleJsDepth = 2;
			opts.TypeRoots = ["/t"];
			T.eq(ModuleResolutionKindNodeNext, opts.GetModuleResolutionKind());
			T.eq(ModuleDetectionKindForce, opts.GetEmitModuleDetectionKind());
			T.isTrue(opts.UsesWildcardTypes());
			T.isTrue(opts.GetEffectiveTypeRoots("").ok);
			T.isTrue(!opts.GetEmitStandardClassFields());
			T.isTrue(ModuleKindES2020.IsNonNodeESM() && !ModuleKindNode16.IsNonNodeESM());
			T.isTrue(ModuleKindNode18.SupportsImportAttributes() && !ModuleKindNode16.SupportsImportAttributes());

			final c = opts.Clone();
			T.isTrue(c != opts);
			T.eq(ModuleKindNodeNext, c.Module);
			T.eq(ScriptTargetES2015, c.Target);
			T.eq(opts.Types, c.Types);
			T.eq(2, c.MaxNodeModuleJsDepth);
			T.eq(TSUnknown, c.Strict);
			// every field is copied: compare all fields with Reflect
			opts.Checkers = 4;
			opts.Quiet = TSTrue;
			opts.AllowJs = TSFalse;
			final c2 = opts.Clone();
			var fields = 0;
			for (f in Type.getInstanceFields(CompilerOptions)) {
				final v = Reflect.field(opts, f);
				if (Reflect.isFunction(v))
					continue;
				fields++;
				T.isTrue(v == Reflect.field(c2, f), "Clone field " + f);
			}
			T.eq(130, fields);

			T.eq(NewLineKindCRLF, Core.GetNewLineKind("\r\n"));
			T.eq(NewLineKindLF, Core.GetNewLineKind("\n"));
			T.eq(NewLineKindNone, Core.GetNewLineKind("x"));
			T.eq("\r\n", NewLineKindCRLF.GetNewLineCharacter());
			T.eq("\n", NewLineKindNone.GetNewLineCharacter());
			T.eq(ModuleResolutionKindNodeNext, Core.ModuleKindToModuleResolutionKind.get(ModuleKindNodeNext));
			T.eq(ModuleKindESNext, Core.ResolutionModeESM);
			T.eq(TSUnknown, Core.EmptyCompilerOptions.AllowJs);
		});

		T.run("Context (extra)", () -> {
			final ctx = Context.Background();
			T.eq("", Core.GetRequestID(ctx));
			T.eq(CheckerLifetimeTemporary, Core.GetCheckerLifetime(ctx));
			final c1 = Core.WithRequestID(ctx, "req-1");
			final c2 = Core.WithCheckerLifetime(c1, CheckerLifetimeAPI);
			T.eq("req-1", Core.GetRequestID(c2));
			T.eq(CheckerLifetimeAPI, Core.GetCheckerLifetime(c2));
			// an Int key 0 of another "package" must not match
			T.eq("", Core.GetRequestID(Context.WithValue(ctx, 0, "x")));
		});

		T.run("Arena/LinkStore/Stack (extra)", () -> {
			final arena = new Arena<TextChange>(() -> new TextChange());
			final x = arena.New();
			T.eq("", x.NewText);
			T.isTrue(arena.New() != x);
			T.eq(null, arena.NewSlice(0));
			final sl = arena.NewSlice(3);
			T.eq(3, sl.length);
			T.isTrue(sl[0] != sl[1]);
			T.eq(x, arena.NewSlice1(x)[0]);
			T.eq(null, arena.Clone([]));
			final cl = arena.Clone([x]);
			T.eq(x, cl[0]);
			T.eq(256, Core.nextArenaSize(200));
			T.eq(2, Core.nextArenaSize(0));

			// (keys are pointers in the compiler: nodes and symbols, which hold their links)
			final store = new LinkStore<ts.ast.Symbol, Stack<Int>>(() -> new Stack<Int>());
			final store2 = new LinkStore<ts.ast.Symbol, Stack<Int>>(() -> new Stack<Int>());
			final a = new ts.ast.Symbol();
			T.isTrue(!store.Has(a));
			T.eq(null, store.TryGet(a));
			final s = store.Get(a);
			T.isTrue(store.Has(a));
			T.eq(s, store.Get(a));
			T.eq(s, store.TryGet(a));
			T.isTrue(!store2.Has(a));
			T.isTrue(store2.Get(a) != s);
			T.eq(s, store.Get(a));

			final st = new Stack<String>();
			T.eq(0, st.Len());
			st.Push("a");
			st.Push("b");
			T.eq("b", st.Peek());
			T.eq("b", st.Pop());
			T.eq(1, st.Len());
			T.eq("a", st.Pop());
			var threw = false;
			try
				st.Pop()
			catch (e:Dynamic)
				threw = true;
			T.isTrue(threw);
		});

		T.run("TextRange (extra)", () -> {
			final r = Core.NewTextRange(2, 5);
			T.eq(2, r.Pos());
			T.eq(5, r.End());
			T.eq(3, r.Len());
			T.isTrue(r.IsValid() && !Core.UndefinedTextRange().IsValid());
			T.isTrue(r.Contains(2) && !r.Contains(5));
			T.isTrue(r.ContainsInclusive(5) && !r.ContainsExclusive(2) && r.ContainsExclusive(3));
			T.eq(0, r.WithPos(0).Pos());
			T.eq(9, r.WithEnd(9).End());
			T.isTrue(r.ContainedBy(Core.NewTextRange(0, 5)) && !r.ContainedBy(Core.NewTextRange(3, 5)));
			T.isTrue(!r.Overlaps(Core.NewTextRange(5, 10)) && r.Intersects(Core.NewTextRange(5, 10)));
			T.isTrue(r.Overlaps(Core.NewTextRange(4, 10)));
			T.isTrue(r.Equals(Core.NewTextRange(2, 5)));
			T.isTrue(Core.CompareTextRanges(r, Core.NewTextRange(2, 6)) < 0);
			T.isTrue(Core.CompareTextRanges(r, Core.NewTextRange(1, 6)) > 0);
			T.eq(0, Core.CompareTextRanges(r, Core.NewTextRange(2, 5)));

			// TextPos arithmetic
			var p:TextPos = 3;
			p++;
			final q:TextPos = p + 2;
			T.isTrue(q > p && p < q && p >= 4 && q <= 6);
			T.eq(6, (q : Int));

			// Lead check: TextRange through an inline property (see LocNode); the JS output must
			// not allocate a TextRange on this path (checked in bin/core/test.js).
			final n = new LocNode();
			n.Loc = Core.NewTextRange(10, 20);
			T.eq(10, n.Loc.Pos());
			T.eq(20, n.Loc.End());
			T.eq(10, n.Loc.Len());
			n.Loc = n.Loc.WithPos(12);
			T.eq(12, n.pos);
			T.isTrue(n.Loc.ContainsInclusive(20));

			// TextChange / ApplyBulkEdits — Go: "HEY big world"
			final tc = new TextChange(Core.NewTextRange(0, 5), "HEY");
			T.eq("HEY world", tc.ApplyTo("hello world"));
			T.eq(0, tc.Pos());
			T.eq(5, tc.End());
			T.eq("HEY big world", Core.ApplyBulkEdits("hello world", [tc, new TextChange(Core.NewTextRange(6, 6), "big ")]));
			T.eq("x", Core.ApplyBulkEdits("x", null));
			final tc2 = tc.copy();
			T.isTrue(tc2 != tc && tc2.TextRange.Equals(tc.TextRange));
		});

		T.run("WorkGroup/Semaphore (extra)", () -> {
			// Go: [2 1 0 10] (singleThreadedWorkGroup pops the last queued function first)
			final order:Array<Int> = [];
			final wg = Core.NewWorkGroup(true);
			for (i in 0...3) {
				wg.Queue(() -> {
					order.push(i);
					if (i == 0) {
						wg.Queue(() -> order.push(10));
					}
				});
			}
			wg.RunAndWait();
			T.eq("[2 1 0 10]", str(order));
			var threw = false;
			try
				wg.Queue(() -> {})
			catch (e:Dynamic)
				threw = true;
			T.isTrue(threw);

			final tg = Core.NewThrottleGroup(Context.Background(), null);
			final e1 = Errors.New("e1");
			final ran:Array<Int> = [];
			tg.Go(() -> {
				ran.push(1);
				return e1;
			});
			tg.Go(() -> {
				ran.push(2);
				return null;
			});
			T.eq(e1, tg.Wait());
			T.eq(2, ran.length);

			final u = new UnlimitedSemaphore();
			u.Acquire()();
			T.isTrue(u.TryAcquire(Context.Background()).ok);
			final ls = Core.NewLimitedSemaphore(1);
			final rel = ls.Acquire();
			var full = false;
			try
				ls.Acquire()
			catch (e:Dynamic)
				full = true;
			T.isTrue(full);
			rel();
			final t = ls.TryAcquire(Context.Background());
			T.isTrue(t.ok);
			t.value();
			var bad = false;
			try
				Core.NewLimitedSemaphore(0)
			catch (e:Dynamic)
				bad = true;
			T.isTrue(bad);
		});

		T.run("Options structs (extra)", () -> {
			final w = new WatchOptions();
			T.eq(2000 * 1e6, w.WatchInterval());
			w.Interval = 500;
			T.eq(500 * 1e6, w.WatchInterval());
			final nw:WatchOptions = null;
			T.eq(2000 * 1e6, nw.WatchInterval());

			final ta = new TypeAcquisition();
			final tb = new TypeAcquisition();
			tb.Include = [];
			T.isTrue(ta.Equals(tb)); // nil and empty slices are equal (slices.Equal)
			tb.Exclude = ["x"];
			T.isTrue(!ta.Equals(tb));
			final nta:TypeAcquisition = null;
			T.isTrue(nta.Equals(null));
			T.isTrue(!nta.Equals(ta));
			T.isTrue(!ta.Equals(null));

			final b = new BuildOptions();
			T.eq(TSUnknown, b.Dry);
			T.eq(null, b.Builders);
			final po = new ParsedOptions();
			T.eq(null, po.CompilerOptions);
			final pr = new ProjectReference();
			pr.Path = "/p";
			T.eq("/p/tsconfig.json", Core.ResolveProjectReferencePath(pr));
			T.eq("/p/x.json", Core.ResolveConfigFileNameOfProjectReference("/p/x.json"));
		});

		T.run("NodeModules/Version (extra)", () -> {
			T.eq("node", Core.NonRelativeModuleNameForTypingCache("fs"));
			T.eq("node", Core.NonRelativeModuleNameForTypingCache("node:fs"));
			T.eq("node", Core.NonRelativeModuleNameForTypingCache("node:test"));
			T.eq("test", Core.NonRelativeModuleNameForTypingCache("test"));
			T.eq("lodash", Core.NonRelativeModuleNameForTypingCache("lodash"));
			var n = 0;
			for (_ in Core.NodeCoreModules().keys())
				n++;
			T.eq(54 * 2 + 5, n);
			// Go: 7.0.2 7.0
			T.eq("7.0.2", Core.Version());
			T.eq("7.0", Core.VersionMajorMinor());
		});
	}
}
