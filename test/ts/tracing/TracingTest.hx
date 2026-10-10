package ts.tracing;

// Port of tracing_test.go.
// PORT: json.Unmarshal into []traceEvent → haxe.Json.parse + parseEvents (numbers stay Dynamic).
// TestGoldenOutput and TestXxh3Golden are not upstream tests: they compare the hand-written JSON
// output and the xxh3 shim byte for byte with Go (tracing.golden.txt, xxh3.golden.txt; the Go
// generators are next to them as *_golden.go.txt).
class TracingTest {
	public static function run() {
		T.run("TestConcurrentDurationEventsUseSeparateThreadIDs", TestConcurrentDurationEventsUseSeparateThreadIDs);
		T.run("TestThreadIDsAreStableAcrossFirstSeenOrder", TestThreadIDsAreStableAcrossFirstSeenOrder);
		T.run("TestGoldenOutput", TestGoldenOutput);
		T.run("TestXxh3Golden", TestXxh3Golden);
	}

	static function args(kv:Array<Any>):StringMap<Any> {
		final m = new StringMap<Any>();
		var i = 0;
		while (i < kv.length) {
			m.set((kv[i] : String), kv[i + 1]);
			i += 2;
		}
		return m;
	}

	static function newFS():FS {
		final m = new Map<String, MapFile>();
		m.set("/trace", new MapFile(null, ModeDir));
		return Vfstest.FromMap(m, true);
	}

	static function TestConcurrentDurationEventsUseSeparateThreadIDs() {
		final fsys = newFS();

		final r = Tracing.StartTracing(fsys, "/trace", "", true /*deterministic*/);
		T.isTrue(r.err == null);
		final tr = r.value;

		final endA = tr.Push(PhaseParse, "createSourceFile", args(["path", "/a.ts"]), true);
		final endB = tr.Push(PhaseParse, "createSourceFile", args(["path", "/b.ts"]), true);
		endA();
		endB();

		final endCheck = tr.Push(PhaseCheck, "checkSourceFile", args(["checkerId", 0, "path", "/a.ts"]), true);
		final endVariance = tr.Push(PhaseCheckTypes, "getVariancesWorker", args(["checkerId", 0, "id", 1]), true);
		endVariance();
		endCheck();

		T.isTrue(tr.StopTracing() == null);

		final traceText = fsys.ReadFile("/trace/trace.json");
		T.isTrue(traceText.ok);

		final events = parseEvents(traceText.value);

		final aBegin = findEvent(events, "B", "createSourceFile", "path", "/a.ts");
		final aEnd = findEvent(events, "E", "createSourceFile", "path", "/a.ts");
		final bBegin = findEvent(events, "B", "createSourceFile", "path", "/b.ts");
		final bEnd = findEvent(events, "E", "createSourceFile", "path", "/b.ts");
		T.eq(aBegin.TID, aEnd.TID);
		T.eq(bBegin.TID, bEnd.TID);
		T.isTrue(aBegin.TID != bBegin.TID);
		assertThreadName(events, aBegin.TID, "file:/a.ts");
		assertThreadName(events, bBegin.TID, "file:/b.ts");

		final checkBegin = findEvent(events, "B", "checkSourceFile", "path", "/a.ts");
		final varianceBegin = findEvent(events, "B", "getVariancesWorker", "id", 1.0 /*float64(1)*/);
		T.eq(checkBegin.TID, varianceBegin.TID);
		assertThreadName(events, checkBegin.TID, "checker:0");

		assertDurationEventsAreWellNestedByThread(events);
	}

	static function TestThreadIDsAreStableAcrossFirstSeenOrder() {
		final first = traceThreadIDsForPaths(["/a.ts", "/b.ts"]);
		final second = traceThreadIDsForPaths(["/b.ts", "/a.ts"]);

		// assert.DeepEqual(t, first, second)
		var n1 = 0, n2 = 0;
		for (k => v in first) {
			n1++;
			T.isTrue(second.exists(k) && second.get(k) == v, 'thread id of $k differs');
		}
		for (_ in second)
			n2++;
		T.eq(n1, n2);
	}

	static function traceThreadIDsForPaths(paths:Array<String>):StringMap<Int> {
		final fsys = newFS();

		final r = Tracing.StartTracing(fsys, "/trace", "", true /*deterministic*/);
		T.isTrue(r.err == null);
		final tr = r.value;

		for (path in paths) {
			final end = tr.Push(PhaseParse, "createSourceFile", args(["path", path]), true);
			end();
		}

		T.isTrue(tr.StopTracing() == null);

		final traceText = fsys.ReadFile("/trace/trace.json");
		T.isTrue(traceText.ok);

		final events = parseEvents(traceText.value);

		final threadIDs = new StringMap<Int>();
		for (path in paths) {
			threadIDs.set(path, findEvent(events, "B", "createSourceFile", "path", path).TID);
		}
		return threadIDs;
	}

	static function parseEvents(text:String):Array<TraceEvent> {
		final raw:Array<Dynamic> = haxe.Json.parse(text);
		final events:Array<TraceEvent> = [];
		for (o in raw) {
			var a:StringMap<Any> = null;
			final ra:Dynamic = Reflect.field(o, "args");
			if (ra != null) {
				a = new StringMap<Any>();
				for (f in Reflect.fields(ra)) {
					a.set(f, Reflect.field(ra, f));
				}
			}
			final name:Dynamic = Reflect.field(o, "name");
			final s:Dynamic = Reflect.field(o, "s");
			events.push(new TraceEvent(Reflect.field(o, "pid"), Reflect.field(o, "tid"), Reflect.field(o, "ph"), Reflect.field(o, "cat"),
				Reflect.field(o, "ts"), name == null ? "" : name, s == null ? "" : s, Reflect.field(o, "dur"), a));
		}
		return events;
	}

	static function argEquals(a:Dynamic, b:Dynamic):Bool {
		if (Std.isOfType(a, Float) && Std.isOfType(b, Float)) {
			return (a : Float) == (b : Float);
		}
		return a == b;
	}

	static function findEvent(events:Array<TraceEvent>, phase:String, name:String, argName:String, argValue:Any):TraceEvent {
		for (event in events) {
			if (event.PH == phase && event.Name == name && event.Args != null && argEquals(event.Args.get(argName), argValue)) {
				return event;
			}
		}
		T.fail('failed to find $phase event "$name" with $argName=$argValue');
		throw "fatal";
	}

	static function assertThreadName(events:Array<TraceEvent>, tid:Int, name:String) {
		for (event in events) {
			if (event.PH == "M" && event.Name == "thread_name" && event.TID == tid && event.Args.get("name") == name) {
				T.checks++;
				return;
			}
		}
		T.fail('failed to find thread_name metadata for thread $tid named "$name"');
		throw "fatal";
	}

	static function assertDurationEventsAreWellNestedByThread(events:Array<TraceEvent>) {
		final stacks = new IntMap<Array<TraceEvent>>();
		for (event in events) {
			if (event.PH == "B") {
				if (!stacks.exists(event.TID))
					stacks.set(event.TID, []);
				stacks.get(event.TID).push(event);
			} else if (event.PH == "E") {
				final stack = stacks.exists(event.TID) ? stacks.get(event.TID) : [];
				T.isTrue(stack.length > 0, 'unmatched end event "${event.Name}" on thread ${event.TID}');
				final begin = stack[stack.length - 1];
				T.eq(begin.Cat, event.Cat);
				T.eq(begin.Name, event.Name);
				stack.pop();
			}
		}

		for (tid => stack in stacks) {
			T.isTrue(stack.length == 0, 'thread $tid has ${stack.length} unterminated events');
		}
	}

	// Mirror of tracing_golden.go.txt.
	static function TestGoldenOutput() {
		final fsys = newFS();
		final r = Tracing.StartTracing(fsys, "/trace", "/p/tsconfig.json", true);
		T.isTrue(r.err == null);
		final tr = r.value;
		final endA = tr.Push(PhaseParse, "createSourceFile", args(["path", "/a.ts"]), true);
		tr.Instant(PhaseCheck, "inst", args([
			"b", true, "a", 1, "f", 1.5, "s", "q\"\\\n\t\x01\x1f\x7f<>&é 😀", "n", null, "e", 1e-7, "big", 1e21, "neg", -2.25, "arr",
			([1, "x", false] : Array<Any>), "m", args(["z", 1, "y", 2, "Z", 3])
		]));
		endA();
		tr.Push(PhaseBind, "sampled", null, false)();
		final long = "/" + StringTools.rpad("", "dir/", 4 * 70) + "file.ts";
		final endL = tr.Push(PhaseParse, "createSourceFile", args(["fileName", long]), true);
		endL();
		final endC = tr.Push(PhaseCheck, "checkSourceFile", args(["checkerId", 3, "path", "/a.ts"]), true);
		endC();
		final endE = tr.Push(PhaseEmit, "emit", args(["fileName", "", "declarationFilePath", "/x/y.d.ts"]), true);
		endE();
		tr.Instant(PhaseProgram, "noargs", null);
		tr.Instant(PhaseSession, "emptyargs", new StringMap<Any>());
		tr.Instant(PhaseProgram, "p1", args(["path", "/"]));
		tr.Instant(PhaseProgram, "p2", args([
			"path",
			"/abcdefghijklmnopqrstuvwxyz/0123456789/abcdefghijklmnopqrstuvwxyz/0123456789/abcdefghijklmnopqrstuvwxyz/0123456789/abcdefghij.ts"
		]));

		final opts = new SourceFileParseOptions();
		opts.FileName = "/src/a.ts";
		opts.Path = "/src/a.ts";
		final file = Parser.ParseSourceFile(opts, "let x = 1;\n  let y: string = 'é😀';\n", ScriptKindTS);
		final s0 = file.Statements.Nodes[0];
		final s1 = file.Statements.Nodes[1];
		final sym = new Symbol();
		sym.Name = "Foo";
		sym.Declarations = [s1];
		final alias = new Symbol();
		alias.Name = "Bar";

		final t1 = new FakeType(1);
		t1.flags = ["Any"];
		t1.intrinsic = "any";
		final t2 = new FakeType(2);
		t2.sym = sym;
		t2.rid = sym;
		t2.display = "Foo<\"x\">";
		t2.union = [t1, null];
		t2.refNode = s0;
		t2.pattern = s1;
		final t3 = new FakeType(3);
		t3.flags = ["Conditional", "Object"];
		t3.cond = true;
		t3.check = t1;
		t3.ext = t2;
		t3.alias = alias;
		t3.aliasArgs = [t2];
		t3.rid = sym;
		t3.tuple = true;
		final t4 = new FakeType(4);
		t4.flags = [];
		t4.cond = true;
		t4.tru = t2;
		t4.fls = t3;
		t4.index = t1;
		t4.objT = t2;
		t4.idxT = t3;
		t4.subBase = t1;
		t4.subCons = t2;
		t4.refTarget = t3;
		t4.refArgs = [t1, t2];
		t4.revS = t1;
		t4.revM = t2;
		t4.revC = t3;
		t4.evE = t1;
		t4.evF = t2;
		t4.inter = [t3];
		t4.rid = alias;

		final tt1 = tr.NewTypeTracer(1);
		final tt0 = tr.NewTypeTracer(0);
		tt1.RecordType(t1);
		tt1.RecordType(t2);
		tt1.RecordType(t3);
		tt1.RecordType(t4);

		T.isTrue(tr.StopTracing() == null);
		final sb = new StringBuf();
		for (p in ["/trace/trace.json", "/trace/legend.json", "/trace/types_1.json"]) {
			final text = fsys.ReadFile(p);
			final ok0 = fsys.ReadFile("/trace/types_0.json").ok;
			sb.add('=== $p ${text.ok} ${ok0}\n${text.value}<<<\n');
		}
		final expected = sys.io.File.getContent("test/ts/tracing/tracing.golden.txt");
		final actual = sb.toString();
		if (expected != actual) {
			final el = expected.split("\n"), al = actual.split("\n");
			for (i in 0...el.length) {
				if (i >= al.length || el[i] != al[i]) {
					T.fail('golden line ${i + 1}:\n  expected: ${el[i]}\n  actual:   ${i < al.length ? al[i] : "<eof>"}');
					return;
				}
			}
			T.fail("golden: actual has extra lines");
		} else {
			T.checks++;
		}
	}

	static function gen(n:Int):String {
		final b = new StringBuf();
		for (i in 0...n) {
			b.addChar('a'.code + (i * 7 + Std.int(i / 13)) % 26);
		}
		return b.toString();
	}

	static function hex(x:haxe.Int64):String {
		return StringTools.hex(x.high, 8).toLowerCase() + StringTools.hex(x.low, 8).toLowerCase();
	}

	static function TestXxh3Golden() {
		final lines = sys.io.File.getContent("test/ts/tracing/xxh3.golden.txt").split("\n");
		for (line in lines) {
			if (line == "")
				continue;
			final parts = line.split(" ");
			if (parts[0] == "u") {
				T.eq(parts[1], hex(Xxh3.HashString("file:/ä/日本/😀.ts")));
				continue;
			}
			final n = Std.parseInt(parts[0]);
			final s = gen(n);
			T.eq(parts[1], hex(Xxh3.HashString(s)));
			final h = Xxh3.New();
			h.WriteString("file");
			h.WriteString(":");
			h.WriteString(s);
			T.eq(parts[2], hex(h.Sum64()));
		}
	}
}

class FakeType implements TracedType {
	public var id:Int;
	public var flags:Array<String> = null;
	public var cond = false;
	public var sym:Symbol = null;
	public var alias:Symbol = null;
	public var aliasArgs:Array<TracedType> = null;
	public var union:Array<TracedType> = null;
	public var inter:Array<TracedType> = null;
	public var refArgs:Array<TracedType> = null;
	public var intrinsic = "";
	public var display = "";
	public var index:TracedType = null;
	public var objT:TracedType = null;
	public var idxT:TracedType = null;
	public var check:TracedType = null;
	public var ext:TracedType = null;
	public var tru:TracedType = null;
	public var fls:TracedType = null;
	public var subBase:TracedType = null;
	public var subCons:TracedType = null;
	public var refTarget:TracedType = null;
	public var revS:TracedType = null;
	public var revM:TracedType = null;
	public var revC:TracedType = null;
	public var evE:TracedType = null;
	public var evF:TracedType = null;
	public var refNode:Node = null;
	public var pattern:Node = null;
	public var tuple = false;
	public var rid:Any = null;

	public function new(id:Int) {
		this.id = id;
	}

	public function Id():Int
		return id;

	public function FormatFlags():Array<String>
		return flags;

	public function IsConditional():Bool
		return cond;

	public function Symbol():Symbol
		return sym;

	public function AliasSymbol():Symbol
		return alias;

	public function AliasTypeArguments():Array<TracedType>
		return aliasArgs;

	public function IntrinsicName():String
		return intrinsic;

	public function UnionTypes():Array<TracedType>
		return union;

	public function IntersectionTypes():Array<TracedType>
		return inter;

	public function IndexType():TracedType
		return index;

	public function IndexedAccessObjectType():TracedType
		return objT;

	public function IndexedAccessIndexType():TracedType
		return idxT;

	public function ConditionalCheckType():TracedType
		return check;

	public function ConditionalExtendsType():TracedType
		return ext;

	public function ConditionalTrueType():TracedType
		return tru;

	public function ConditionalFalseType():TracedType
		return fls;

	public function SubstitutionBaseType():TracedType
		return subBase;

	public function SubstitutionConstraintType():TracedType
		return subCons;

	public function ReferenceTarget():TracedType
		return refTarget;

	public function ReferenceTypeArguments():Array<TracedType>
		return refArgs;

	public function ReferenceNode():Node
		return refNode;

	public function ReverseMappedSourceType():TracedType
		return revS;

	public function ReverseMappedMappedType():TracedType
		return revM;

	public function ReverseMappedConstraintType():TracedType
		return revC;

	public function EvolvingArrayElementType():TracedType
		return evE;

	public function EvolvingArrayFinalType():TracedType
		return evF;

	public function IsTuple():Bool
		return tuple;

	public function Pattern():Node
		return pattern;

	public function RecursionIdentity():Any
		return rid;

	public function Display():String
		return display;
}
