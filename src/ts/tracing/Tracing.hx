package ts.tracing;

// Port of internal/tracing (tracing.go).
// PORT: sync.Mutex / atomic.Bool are dropped (single-threaded port); traceStarted is a Bool.
// PORT: Go marshals with go-json-experiment (json.MarshalWrite / MarshalIndent). ts.json.Json has
// no Go-compatible ordered marshaller (PORTING.md §7), so the output is written by hand in the
// "json output" section at the end of this class: struct fields in declaration order with
// `omitzero`, map keys sorted (Deterministic), strings escaped like jsonwire.AppendQuote, floats
// formatted like jsonwire.AppendFloat.

// Tracer is an interface for recording types during type checking.
// Each checker should have its own Tracer instance to avoid sharing types between checkers.
interface Tracer {
	// RecordType records a type for later dumping.
	function RecordType(t:TracedType):Void;
	// DumpTypes writes all recorded types to disk.
	function DumpTypes():Null<Error>;
}

// TracedType is an interface that represents a type that can be traced.
// This allows the tracing package to work with types from the checker package
// without creating a circular dependency.
// PORT: `uint32` ids → Int.
interface TracedType {
	function Id():Int;
	function FormatFlags():Array<String>;
	function IsConditional():Bool;
	function Symbol():Symbol;
	function AliasSymbol():Symbol;
	function AliasTypeArguments():Array<TracedType>;

	// Type-specific data accessors
	function IntrinsicName():String;
	function UnionTypes():Array<TracedType>;
	function IntersectionTypes():Array<TracedType>;
	function IndexType():TracedType;
	function IndexedAccessObjectType():TracedType;
	function IndexedAccessIndexType():TracedType;
	function ConditionalCheckType():TracedType;
	function ConditionalExtendsType():TracedType;
	function ConditionalTrueType():TracedType;
	function ConditionalFalseType():TracedType;
	function SubstitutionBaseType():TracedType;
	function SubstitutionConstraintType():TracedType;
	function ReferenceTarget():TracedType;
	function ReferenceTypeArguments():Array<TracedType>;
	function ReferenceNode():Node;
	function ReverseMappedSourceType():TracedType;
	function ReverseMappedMappedType():TracedType;
	function ReverseMappedConstraintType():TracedType;
	function EvolvingArrayElementType():TracedType;
	function EvolvingArrayFinalType():TracedType;
	function IsTuple():Bool;
	function Pattern():Node;
	function RecursionIdentity():Any;

	// Display is an optional string representation of the type
	function Display():String;
}

// TraceRecord represents metadata about a single trace file
class TraceRecord {
	public var ConfigFilePath:String = ""; // json:"configFilePath,omitzero"
	public var TracePath:String = ""; // json:"tracePath,omitzero"
	public var TypesPath:String = ""; // json:"typesPath,omitzero"
	public var CheckerID:Int = 0; // json:"checkerId"

	public function new() {}
}

// traceEvent
class TraceEvent {
	public var PID:Int = 0; // json:"pid"
	public var TID:Int = 0; // json:"tid"
	public var PH:String = ""; // json:"ph"
	public var Cat:String = ""; // json:"cat"
	public var TS:Float = 0.0; // json:"ts"
	public var Name:String = ""; // json:"name,omitzero"
	public var S:String = ""; // json:"s,omitzero" scope, only set for instant events ("g" = global)
	public var Dur:Null<Float> = null; // json:"dur,omitzero" PORT: pointer → Null<Float>
	public var Args:StringMap<Any> = null; // json:"args,omitzero"

	public function new(PID:Int, TID:Int, PH:String, Cat:String, TS:Float, ?Name:String = "", ?S:String = "", ?Dur:Null<Float>,
			?Args:StringMap<Any>) {
		this.PID = PID;
		this.TID = TID;
		this.PH = PH;
		this.Cat = Cat;
		this.TS = TS;
		this.Name = Name;
		this.S = S;
		this.Dur = Dur;
		this.Args = Args;
	}
}

// Phase represents a tracing phase
enum abstract Phase(String) to String {
	var PhaseParse = "parse";
	var PhaseProgram = "program";
	var PhaseBind = "bind";
	var PhaseCheck = "check";
	var PhaseCheckTypes = "checkTypes";
	var PhaseEmit = "emit";
	var PhaseSession = "session";
}

enum abstract TraceThreadKind(String) to String {
	var traceThreadKindChecker = "checker";
	var traceThreadKindFile = "file";
}

// traceThreadKey
// PORT: a Go struct used as a map key and compared with ==; mapKey() encodes it as a String
// (PORTING.md §4a).
class TraceThreadKey {
	public var kind:TraceThreadKind = cast "";
	public var text:String = "";
	public var index:Int = 0;
	public var hasIndex:Bool = false;

	public function new() {}

	public function mapKey():String {
		return (kind : String) + "\x00" + text + "\x00" + index + "\x00" + (hasIndex ? "1" : "0");
	}

	public function defaultThreadID():Int {
		if (kind == traceThreadKindChecker && hasIndex && index >= 0) {
			return Tracing.firstSyntheticThreadID + index;
		}
		return Tracing.stableTraceThreadID(this);
	}

	public function displayName():String {
		if (hasIndex) {
			return (kind : String) + ":" + Std.string(index);
		}
		return (kind : String) + ":" + text;
	}
}

// fmt.Errorf("...: %w", err)
// PORT: the message is formatted by the caller.
private class WrapError implements Error implements go.Errors.Wrapper {
	final msg:String;
	final err:Error;

	public function new(msg:String, err:Error) {
		this.msg = msg;
		this.err = err;
	}

	public function Error():String {
		return msg;
	}

	public function Unwrap():Null<Error> {
		return err;
	}

	public function toString():String {
		return msg;
	}
}

// Tracing manages the overall tracing session including all checkers
@:allow(ts.tracing)
class Tracing {
	// sampleInterval matches TypeScript's 10ms sampling interval.
	// Events with separateBeginAndEnd=false are only recorded if their
	// duration crosses a 10ms sampling boundary.
	static var sampleInterval(get, never):Duration; // 10 * time.Millisecond

	static function get_sampleInterval():Duration {
		return Int64.ofInt(10 * 1000000);
	}

	static inline final traceFileName = "trace.json";

	static inline final mainThreadID = 1;
	static inline final firstSyntheticThreadID = 2;
	static inline final firstFileThreadID = 1000000;
	static inline final fileThreadIDHashRange = 1000000000;

	static final traceThreadArgKeys = ["path", "fileName", "containingFileName", "jsFilePath", "declarationFilePath"];

	// flushThreshold is the size at which buffered trace content is flushed to disk
	// via AppendFile. Keeps peak memory bounded for long-running compilations while
	// avoiding a syscall per event.
	// PORT: compared with the StringBuf length in UTF-16 units (Go: bytes); only the flush points
	// move, the file content is the same.
	static inline final flushThreshold = 256 * 1024;

	var fs:FS = null;
	var traceDir:String = "";
	var tracePath:String = "";
	var configFilePath:String = "";
	var legend:Array<TraceRecord> = null;
	var tracers:Array<TypeTracer> = null;
	var traceContent:StringBuf = new StringBuf();
	var traceStarted:Bool = false;
	var threadIDs:StringMap<Int> = null; // PORT: map[traceThreadKey]int keyed by TraceThreadKey.mapKey()
	var threadKeys:IntMap<TraceThreadKey> = null;
	var metadataTS:Float = 0.0;
	var deterministic:Bool = false; // when true, use monotonic counter instead of real time
	var timestampCounter:Int = 0; // only used in deterministic mode. PORT: uint64 → Int (an event counter)
	var startTime:Time = Time.Zero();
	// flushErr holds the first error encountered while appending the trace buffer
	// to disk. Once set, subsequent flushes become no-ops and the error is
	// surfaced from StopTracing so that transient I/O failures (disk full,
	// permission denied, etc.) don't crash the compiler.
	var flushErr:Error = null;

	function new() {}

	// StartTracing creates a new tracing session.
	// When deterministic is true, timestamps use a monotonic counter instead of
	// real wall-clock time, producing stable output for test baselines.
	// PORT: (*Tracing, error) → ValueError.
	public static function StartTracing(fs:FS, traceDir:String, configFilePath:String, deterministic:Bool):ValueError<Tracing> {
		final tr = new Tracing();
		tr.fs = fs;
		tr.traceDir = traceDir;
		tr.tracePath = Tspath.CombinePaths(traceDir, traceFileName);
		tr.configFilePath = configFilePath;
		tr.legend = [];
		tr.tracers = [];
		tr.threadIDs = new StringMap<Int>();
		tr.threadKeys = new IntMap<TraceThreadKey>();
		tr.deterministic = deterministic;
		tr.startTime = Time.Now();
		tr.traceStarted = true;

		// Write the trace file header with metadata events
		tr.traceContent.add("[\n");

		// Write metadata events (matching TypeScript's format)
		final metaTs = tr.timestamp();
		tr.metadataTS = metaTs;
		tr.writeEvent(new TraceEvent(1, mainThreadID, "M", "__metadata", metaTs, "process_name", null, null, stringMap(["name" => "tsgo"])));
		tr.traceContent.add(",\n");
		tr.writeEvent(new TraceEvent(1, mainThreadID, "M", "__metadata", metaTs, "thread_name", null, null, stringMap(["name" => "Main"])));
		tr.traceContent.add(",\n");
		tr.writeEvent(new TraceEvent(1, mainThreadID, "M", "disabled-by-default-devtools.timeline", metaTs, "TracingStartedInBrowser"));

		// Truncate any existing trace file with the header so subsequent AppendFile
		// calls extend a clean file.
		final err = tr.fs.WriteFile(tr.tracePath, tr.traceContent.toString());
		if (err != null) {
			return new ValueError<Tracing>(null, new WrapError("failed to write trace file header: " + err.Error(), err));
		}
		tr.traceContent = new StringBuf();

		return new ValueError<Tracing>(tr, null);
	}

	// PORT: map[string]any{...} literal helper.
	static function stringMap(m:Map<String, Any>):StringMap<Any> {
		final r = new StringMap<Any>();
		for (k => v in m) {
			r.set(k, v);
		}
		return r;
	}

	// timestamp returns the current timestamp in microseconds.
	// In deterministic mode it returns a monotonically increasing counter;
	// otherwise it returns the real elapsed wall-clock time since tracing started,
	// matching TypeScript's 1000 * timestamp() (microseconds).
	function timestamp():Float {
		if (deterministic) {
			timestampCounter++;
			return timestampCounter;
		}
		return Time.DurationFloat64(Time.Since(startTime)) / 1000.0;
	}

	static function writeEventTo(buf:StringBuf, event:TraceEvent):Void {
		marshalTraceEvent(buf, event);
	}

	function writeEvent(event:TraceEvent):Void {
		writeEventTo(traceContent, event);
	}

	// maybeFlushLocked appends the buffered trace content to disk if it has grown
	// past the flush threshold. Caller must hold tr.mu. If a previous flush failed,
	// or this flush fails, the error is recorded in tr.flushErr and subsequent
	// writes become no-ops; the error is surfaced from StopTracing.
	function maybeFlushLocked():Void {
		if (flushErr != null) {
			traceContent = new StringBuf();
			return;
		}
		if (traceContent.length < flushThreshold) {
			return;
		}
		final err = fs.AppendFile(tracePath, traceContent.toString());
		if (err != null) {
			flushErr = new WrapError("failed to flush trace file: " + err.Error(), err);
		}
		traceContent = new StringBuf();
	}

	// Instant records an instant event in the trace.
	// Safe to call on nil receiver.
	// PORT: nil receiver — inline with a `this == null` check; the body is in instant.
	public inline function Instant(phase:Phase, name:String, args:StringMap<Any>):Void {
		if (this != null) {
			instant(phase, name, args);
		}
	}

	function instant(phase:Phase, name:String, args:StringMap<Any>):Void {
		if (!traceStarted) {
			return;
		}

		// Re-check under the lock: StopTracing may have run between the load above
		// and acquiring the lock. Once stopped, further writes would land in a buffer
		// that has already been flushed and the closing "]" written.
		if (!traceStarted) {
			return;
		}

		final ts = timestamp();
		final tid = threadIDLocked(args);
		traceContent.add(",\n");
		writeEvent(new TraceEvent(1, tid, "I", phase, ts, name, "g", null, args));
		maybeFlushLocked();
	}

	// Push starts a trace event block on the shared trace buffer.
	// Safe to call on nil receiver. Safe to call from multiple goroutines.
	//
	// When separateBeginAndEnd is true, a "B" (begin) event is written immediately and
	// the returned function writes a matching "E" (end) event. This is used for events
	// that must always appear in the trace (e.g. checkSourceFile, createProgram, emit).
	//
	// When separateBeginAndEnd is false (the default in TypeScript), the event is only
	// recorded if its duration crosses a 10ms sampling boundary, matching TypeScript's
	// behavior of sampling short-lived events to avoid trace bloat.
	//
	// Returns a function that should be called (typically deferred) to end the event.
	// Each returned function is self-contained and does not depend on a shared stack,
	// making it safe for concurrent use across goroutines.
	// PORT: nil receiver — inline with a `this == null` check; the body is in push.
	public inline function Push(phase:Phase, name:String, args:StringMap<Any>, separateBeginAndEnd:Bool):() -> Void {
		return this == null ? noop : push(phase, name, args, separateBeginAndEnd);
	}

	static function noop():Void {}

	function push(phase:Phase, name:String, args:StringMap<Any>, separateBeginAndEnd:Bool):() -> Void {
		if (!traceStarted) {
			return function() {};
		}

		if (separateBeginAndEnd) {
			if (!traceStarted) {
				return function() {};
			}
			final ts = timestamp();
			final tid = threadIDLocked(args);
			traceContent.add(",\n");
			writeEvent(new TraceEvent(1, tid, "B", phase, ts, name, null, null, args));
			maybeFlushLocked();

			return function() {
				if (!traceStarted) {
					return;
				}
				final endTs = timestamp();
				traceContent.add(",\n");
				writeEvent(new TraceEvent(1, tid, "E", phase, endTs, name, null, null, args));
				maybeFlushLocked();
			};
		}

		// Sampled event: only record if duration crosses a sampling boundary.
		// In deterministic mode, sampled events are skipped entirely to avoid flaky baselines,
		// so avoid the cost of cloning args / capturing the start time.
		if (deterministic) {
			return function() {};
		}
		final startTime = Time.Now();
		args = args == null ? null : args.copy(); // maps.Clone
		return function() {
			final dur:Float = Time.DurationFloat64(Time.Since(startTime)) / 1000.0;
			final startMicros:Float = Time.DurationFloat64(startTime.Sub(this.startTime)) / 1000.0;
			final intervalMicros:Float = Time.DurationFloat64(sampleInterval) / 1000.0;
			if (intervalMicros - go.Math.Mod(startMicros, intervalMicros) > dur) {
				return;
			}
			if (!traceStarted) {
				return;
			}
			final tid = threadIDLocked(args);
			traceContent.add(",\n");
			writeEvent(new TraceEvent(1, tid, "X", phase, startMicros, name, null, dur, args));
			maybeFlushLocked();
		};
	}

	function threadIDLocked(args:StringMap<Any>):Int {
		final r = traceThreadKeyFromArgs(args);
		final key = r.value;
		if (!r.ok) {
			return mainThreadID;
		}

		if (threadIDs.exists(key.mapKey())) {
			return threadIDs.get(key.mapKey());
		}

		var tid = key.defaultThreadID();
		while (true) {
			final existingKey = threadKeys.get(tid);
			if (existingKey == null || existingKey.mapKey() == key.mapKey()) {
				break;
			}
			tid++;
		}
		threadIDs.set(key.mapKey(), tid);
		threadKeys.set(tid, key);
		writeThreadNameEventLocked(tid, key.displayName());
		return tid;
	}

	function writeThreadNameEventLocked(tid:Int, name:String):Void {
		traceContent.add(",\n");
		writeEvent(new TraceEvent(1, tid, "M", "__metadata", metadataTS, "thread_name", null, null, stringMap(["name" => name])));
	}

	// PORT: (traceThreadKey, bool) → ValueOk.
	static function traceThreadKeyFromArgs(args:StringMap<Any>):ValueOk<TraceThreadKey> {
		if (args == null || !args.keys().hasNext()) {
			return new ValueOk(new TraceThreadKey(), false);
		}

		// PORT: `.(int)` → Std.isOfType(v, Int); on JS an integral float64 also passes.
		final checkerID:Dynamic = args.get("checkerId");
		if (checkerID != null && Std.isOfType(checkerID, Int)) {
			final key = new TraceThreadKey();
			key.kind = traceThreadKindChecker;
			key.index = checkerID;
			key.hasIndex = true;
			return new ValueOk(key, true);
		}

		for (key in traceThreadArgKeys) {
			if (args.exists(key)) {
				final value:Dynamic = args.get(key);
				if (Std.isOfType(value, std.String) && (value : std.String) != "") {
					final k = new TraceThreadKey();
					k.kind = traceThreadKindFile;
					k.text = value;
					return new ValueOk(k, true);
				}
			}
		}

		return new ValueOk(new TraceThreadKey(), false);
	}

	static function stableTraceThreadID(key:TraceThreadKey):Int {
		final hash = Xxh3.New();
		hash.WriteString(key.kind);
		hash.WriteString(":");
		if (key.hasIndex) {
			hash.WriteString(Std.string(key.index));
		} else {
			hash.WriteString(key.text);
		}
		return firstFileThreadID + umod64(hash.Sum64(), fileThreadIDHashRange);
	}

	// PORT: 64-bit — uint64 % m for 0 < m < 2^31, via the two 32-bit halves (every partial
	// value is < 2^63, so signed Int64 arithmetic is exact).
	static function umod64(x:Int64, m:Int):Int {
		final mm = Int64.ofInt(m);
		final hi = Int64.make(0, x.high) % mm;
		final lo = Int64.make(0, x.low) % mm;
		final two32 = Int64.make(1, 0) % mm;
		return Int64.toInt((hi * two32 + lo) % mm);
	}

	// NewTypeTracer creates a new tracer for a specific checker.
	// The checkerIndex is used to create unique filenames for each checker's output.
	public function NewTypeTracer(checkerIndex:Int):Tracer {
		final typesPath = Tspath.CombinePaths(traceDir, 'types_${checkerIndex}.json');
		final tracer = new TypeTracer();
		tracer.fs = fs;
		tracer.checkerIndex = checkerIndex;
		tracer.typesPath = typesPath;
		tracer.types = [];
		tracers.push(tracer);
		final record = new TraceRecord();
		record.ConfigFilePath = configFilePath;
		record.TracePath = tracePath;
		record.TypesPath = typesPath;
		record.CheckerID = checkerIndex;
		legend.push(record);
		return tracer;
	}

	// StopTracing finalizes the tracing session and writes all output files
	public function StopTracing():Null<Error> {
		// Dump types from all tracers BEFORE acquiring the lock, because
		// DumpTypes → buildTypeDescriptor → Display() → TypeToString can
		// re-enter the checker which calls Push/Pop (which need tr.mu).
		for (tracer in tracers) {
			final err = tracer.DumpTypes();
			if (err != null) {
				return new WrapError('failed to dump types for checker ${tracer.checkerIndex}: ' + err.Error(), err);
			}
		}

		// Close the trace file(s)
		if (traceStarted) {
			// Surface any buffered flush failure before attempting the final write.
			if (flushErr != null) {
				traceContent = new StringBuf();
				traceStarted = false;
				return flushErr;
			}
			// Flush any remaining buffered content and close the JSON array.
			final err = fs.AppendFile(tracePath, traceContent.toString() + "\n]\n");
			if (err != null) {
				return new WrapError("failed to write trace file: " + err.Error(), err);
			}
			traceContent = new StringBuf();
			traceStarted = false;
		}

		// Sort legend entries by typesPath for deterministic output
		Slices.SortFunc(legend, function(a:TraceRecord, b:TraceRecord):Int {
			return Strings.Compare(a.TypesPath, b.TypesPath);
		});

		// Write the legend file
		final legendPath = Tspath.CombinePaths(traceDir, "legend.json");
		final legendData = marshalIndentTraceRecords(legend, "  ");
		final err = fs.WriteFile(legendPath, legendData);
		if (err != null) {
			return new WrapError("failed to write legend file: " + err.Error(), err);
		}

		return null;
	}

	static function mapTypeIds(types:Array<TracedType>):Array<Int> {
		if (Core.len(types) == 0) {
			return null;
		}
		final ids = [for (_ in 0...types.length) 0];
		for (i in 0...types.length) {
			final t = types[i];
			if (t != null) {
				ids[i] = t.Id();
			}
		}
		return ids;
	}

	static function getLocation(node:Node):Location {
		if (node == null) {
			return null;
		}
		final file = Ast.GetSourceFileOfNode(node);
		if (file == null) {
			return null;
		}

		final startPos = Scanner.GetTokenPosOfNode(node, file, false);
		final start = Scanner.GetECMALineAndUTF16CharacterOfPosition(file, startPos);
		final end = Scanner.GetECMALineAndUTF16CharacterOfPosition(file, node.End());

		final loc = new Location();
		loc.Path = Tspath.ToPath(file.FileName(), "", false);
		loc.Start = new LineAndChar(start.a + 1, (start.b : Int) + 1);
		loc.End = new LineAndChar(end.a + 1, (end.b : Int) + 1);
		return loc;
	}

	// --- json output ---
	// PORT: hand-written equivalent of the go-json-experiment encoding used above (see header).

	// jsonwire.AppendQuote (AllowInvalidUTF8; no HTML/JS escaping). PORT: a lone surrogate plays
	// the role of Go's invalid UTF-8 and becomes U+FFFD.
	static function appendQuote(buf:StringBuf, s:String):Void {
		buf.addChar('"'.code);
		var i = 0;
		final n = s.length;
		while (i < n) {
			final c = StringTools.fastCodeAt(s, i);
			if (c < 0x80) {
				switch (c) {
					case '"'.code:
						buf.add('\\"');
					case '\\'.code:
						buf.add("\\\\");
					case 0x08:
						buf.add("\\b");
					case 0x0C:
						buf.add("\\f");
					case 0x0A:
						buf.add("\\n");
					case 0x0D:
						buf.add("\\r");
					case 0x09:
						buf.add("\\t");
					default:
						if (c < 0x20) {
							buf.add("\\u00");
							buf.add(StringTools.hex(c, 2).toLowerCase());
						} else {
							buf.addChar(c);
						}
				}
				i++;
			} else if (c >= 0xD800 && c < 0xDC00 && i + 1 < n && StringTools.fastCodeAt(s, i + 1) >= 0xDC00
				&& StringTools.fastCodeAt(s, i + 1) < 0xE000) {
				buf.addChar(((c - 0xD800) << 10) + (StringTools.fastCodeAt(s, i + 1) - 0xDC00) + 0x10000);
				i += 2;
			} else if (c >= 0xD800 && c < 0xE000) {
				buf.addChar(0xFFFD);
				i++;
			} else {
				buf.addChar(c);
				i++;
			}
		}
		buf.addChar('"'.code);
	}

	// jsonwire.AppendFloat(dst, src, 64)
	static function appendFloat(buf:StringBuf, src:Float):Void {
		final abs = std.Math.abs(src);
		var fmt = 'f'.code;
		if (abs != 0) {
			if (abs < 1e-6 || abs >= 1e21) {
				fmt = 'e'.code;
			}
		}
		var s = Strconv.FormatFloat(src, fmt, -1, 64);
		if (fmt == 'e'.code) {
			// Clean up e-09 to e-9.
			final n = s.length;
			if (n >= 4 && s.charAt(n - 4) == "e" && s.charAt(n - 3) == "-" && s.charAt(n - 2) == "0") {
				s = s.substring(0, n - 2) + s.charAt(n - 1);
			}
		}
		buf.add(s);
	}

	// Go uint32 as a JSON number.
	static function appendUint32(buf:StringBuf, v:Int):Void {
		if (v < 0) {
			buf.add(Strconv.FormatInt(Int64.make(0, v), 10));
		} else {
			buf.add(v);
		}
	}

	// A Go `any` value as produced by the callers of Push/Instant (map[string]any args).
	// PORT: Haxe cannot tell Go `int` from an integral `float64` on JS; both encode the same.
	static function appendAny(buf:StringBuf, v:Dynamic):Void {
		if (v == null) {
			buf.add("null");
		} else if (Std.isOfType(v, Bool)) {
			buf.add((v : Bool) ? "true" : "false");
		} else if (Std.isOfType(v, std.String)) {
			appendQuote(buf, v);
		} else if (Std.isOfType(v, Int)) {
			buf.add((v : Int));
		} else if (Std.isOfType(v, Float)) {
			appendFloat(buf, v);
		} else if (Std.isOfType(v, Array)) {
			final a:Array<Dynamic> = v;
			buf.addChar('['.code);
			for (i in 0...a.length) {
				if (i > 0)
					buf.addChar(','.code);
				appendAny(buf, a[i]);
			}
			buf.addChar(']'.code);
		} else if (Std.isOfType(v, StringMap)) {
			appendObjectAny(buf, (v : StringMap<Dynamic>));
		} else {
			throw "failed to marshal trace event: unsupported value " + Std.string(v);
		}
	}

	// map[string]any with json.Deterministic(true): names sorted (slices.Sort on Go strings).
	static function appendObjectAny(buf:StringBuf, m:StringMap<Dynamic>):Void {
		final names = [for (k in m.keys()) k];
		Slices.SortFunc(names, Strings.Compare);
		buf.addChar('{'.code);
		for (i in 0...names.length) {
			if (i > 0)
				buf.addChar(','.code);
			appendQuote(buf, names[i]);
			buf.addChar(':'.code);
			appendAny(buf, m.get(names[i]));
		}
		buf.addChar('}'.code);
	}

	static function marshalTraceEvent(buf:StringBuf, e:TraceEvent):Void {
		buf.add('{"pid":');
		buf.add(e.PID);
		buf.add(',"tid":');
		buf.add(e.TID);
		buf.add(',"ph":');
		appendQuote(buf, e.PH);
		buf.add(',"cat":');
		appendQuote(buf, e.Cat);
		buf.add(',"ts":');
		appendFloat(buf, e.TS);
		if (e.Name != "") {
			buf.add(',"name":');
			appendQuote(buf, e.Name);
		}
		if (e.S != "") {
			buf.add(',"s":');
			appendQuote(buf, e.S);
		}
		if (e.Dur != null) {
			buf.add(',"dur":');
			appendFloat(buf, e.Dur);
		}
		if (e.Args != null) {
			buf.add(',"args":');
			appendObjectAny(buf, e.Args);
		}
		buf.addChar('}'.code);
	}

	// json.MarshalIndent(legend, "", indent)
	static function marshalIndentTraceRecords(records:Array<TraceRecord>, indent:String):String {
		if (records == null) {
			return "null"; // PORT: unreachable (legend is never nil)
		}
		if (records.length == 0) {
			return "[]";
		}
		final buf = new StringBuf();
		buf.add("[\n");
		for (i in 0...records.length) {
			final r = records[i];
			buf.add(indent + "{\n");
			final fields:Array<String> = [];
			if (r.ConfigFilePath != "")
				fields.push('"configFilePath": ' + quote(r.ConfigFilePath));
			if (r.TracePath != "")
				fields.push('"tracePath": ' + quote(r.TracePath));
			if (r.TypesPath != "")
				fields.push('"typesPath": ' + quote(r.TypesPath));
			fields.push('"checkerId": ' + r.CheckerID);
			for (j in 0...fields.length) {
				buf.add(indent + indent + fields[j] + (j < fields.length - 1 ? ",\n" : "\n"));
			}
			buf.add(indent + "}" + (i < records.length - 1 ? ",\n" : "\n"));
		}
		buf.add("]");
		return buf.toString();
	}

	static function quote(s:String):String {
		final b = new StringBuf();
		appendQuote(b, s);
		return b.toString();
	}

	static function appendUint32s(buf:StringBuf, name:String, a:Array<Int>):Void {
		buf.add(',"' + name + '":[');
		for (i in 0...a.length) {
			if (i > 0)
				buf.addChar(','.code);
			appendUint32(buf, a[i]);
		}
		buf.addChar(']'.code);
	}

	static function appendOptUint32(buf:StringBuf, name:String, v:Null<Int>):Void {
		if (v != null) {
			buf.add(',"' + name + '":');
			appendUint32(buf, v);
		}
	}

	static function appendLineAndChar(buf:StringBuf, l:LineAndChar):Void {
		buf.add('{"line":');
		buf.add(l.Line);
		buf.add(',"character":');
		buf.add(l.Character);
		buf.addChar('}'.code);
	}

	static function appendLocation(buf:StringBuf, name:String, l:Location):Void {
		if (l == null) {
			return;
		}
		buf.add(',"' + name + '":{"path":');
		appendQuote(buf, l.Path);
		if (l.Start != null) {
			buf.add(',"start":');
			appendLineAndChar(buf, l.Start);
		}
		if (l.End != null) {
			buf.add(',"end":');
			appendLineAndChar(buf, l.End);
		}
		buf.addChar('}'.code);
	}

	// json.MarshalWrite(&sb, descriptor)
	static function marshalTypeDescriptor(buf:StringBuf, d:TypeDescriptor):Void {
		buf.add('{"id":');
		appendUint32(buf, d.ID);
		if (d.IntrinsicName != "") {
			buf.add(',"intrinsicName":');
			appendQuote(buf, d.IntrinsicName);
		}
		if (d.SymbolName != "") {
			buf.add(',"symbolName":');
			appendQuote(buf, d.SymbolName);
		}
		if (d.RecursionID != null) {
			buf.add(',"recursionId":');
			buf.add((d.RecursionID : Int));
		}
		if (d.IsTuple) {
			buf.add(',"isTuple":true');
		}
		if (d.UnionTypes != null)
			appendUint32s(buf, "unionTypes", d.UnionTypes);
		if (d.IntersectionTypes != null)
			appendUint32s(buf, "intersectionTypes", d.IntersectionTypes);
		if (d.AliasTypeArguments != null)
			appendUint32s(buf, "aliasTypeArguments", d.AliasTypeArguments);
		appendOptUint32(buf, "keyofType", d.KeyofType);
		appendOptUint32(buf, "indexedAccessObjectType", d.IndexedAccessObjectType);
		appendOptUint32(buf, "indexedAccessIndexType", d.IndexedAccessIndexType);
		appendOptUint32(buf, "conditionalCheckType", d.ConditionalCheckType);
		appendOptUint32(buf, "conditionalExtendsType", d.ConditionalExtendsType);
		if (d.ConditionalTrueType != null) {
			buf.add(',"conditionalTrueType":');
			buf.add((d.ConditionalTrueType : Int));
		}
		if (d.ConditionalFalseType != null) {
			buf.add(',"conditionalFalseType":');
			buf.add((d.ConditionalFalseType : Int));
		}
		appendOptUint32(buf, "substitutionBaseType", d.SubstitutionBaseType);
		appendOptUint32(buf, "constraintType", d.ConstraintType);
		appendOptUint32(buf, "instantiatedType", d.InstantiatedType);
		if (d.TypeArguments != null)
			appendUint32s(buf, "typeArguments", d.TypeArguments);
		appendLocation(buf, "referenceLocation", d.ReferenceLocation);
		appendOptUint32(buf, "reverseMappedSourceType", d.ReverseMappedSourceType);
		appendOptUint32(buf, "reverseMappedMappedType", d.ReverseMappedMappedType);
		appendOptUint32(buf, "reverseMappedConstraintType", d.ReverseMappedConstraintType);
		appendOptUint32(buf, "evolvingArrayElementType", d.EvolvingArrayElementType);
		appendOptUint32(buf, "evolvingArrayFinalType", d.EvolvingArrayFinalType);
		appendLocation(buf, "destructuringPattern", d.DestructuringPattern);
		appendLocation(buf, "firstDeclaration", d.FirstDeclaration);
		// `json:"flags"` without omitzero: a nil slice encodes as [] (go-json-experiment default).
		buf.add(',"flags":[');
		if (d.Flags != null) {
			for (i in 0...d.Flags.length) {
				if (i > 0)
					buf.addChar(','.code);
				appendQuote(buf, d.Flags[i]);
			}
		}
		buf.addChar(']'.code);
		if (d.Display != "") {
			buf.add(',"display":');
			appendQuote(buf, d.Display);
		}
		buf.addChar('}'.code);
	}
}

// typeTracer is the per-checker tracer implementation
@:allow(ts.tracing)
class TypeTracer implements Tracer {
	var fs:FS = null;
	var checkerIndex:Int = 0;
	var typesPath:String = "";
	var types:Array<TracedType> = null;

	public function new() {}

	public function RecordType(typ:TracedType):Void {
		types.push(typ);
	}

	public function DumpTypes():Null<Error> {
		// Copy the types slice under lock, then release so Display() calls during
		// buildTypeDescriptor don't deadlock when they create new types
		final types = Slices.Clone(this.types);

		if (Core.len(types) == 0) {
			return null;
		}

		final sb = new StringBuf();
		// Write opening bracket (no newline so type ID matches line number)
		sb.add("[");

		final recursionIdentityMap = new go.GoMap<Any, Int>();

		for (i in 0...types.length) {
			final typ = types[i];
			final descriptor = buildTypeDescriptor(typ, recursionIdentityMap);

			Tracing.marshalTypeDescriptor(sb, descriptor);

			if (i < types.length - 1) {
				sb.add(",\n");
			}
		}

		sb.add("]\n");

		return fs.WriteFile(typesPath, sb.toString());
	}

	function buildTypeDescriptor(typ:TracedType, recursionIdentityMap:go.GoMap<Any, Int>):TypeDescriptor {
		final symbol = typ.Symbol();
		final aliasSymbol = typ.AliasSymbol();

		final desc = new TypeDescriptor();
		desc.ID = typ.Id();
		desc.Flags = typ.FormatFlags();

		// Assign a unique integer token per recursion identity, matching TypeScript's behavior.
		// This lets trace analysis tools detect which types share the same recursion identity.
		final identity = typ.RecursionIdentity();
		if (identity != null) {
			var token:Null<Int> = recursionIdentityMap.get(identity);
			if (!recursionIdentityMap.exists(identity)) {
				token = recursionIdentityMap.length();
				recursionIdentityMap.set(identity, token);
			}
			desc.RecursionID = token;
		}

		// Intrinsic name
		final name = typ.IntrinsicName();
		if (name != "") {
			desc.IntrinsicName = name;
		}

		// Symbol name - escape the internal symbol name prefix for valid JSON
		if (aliasSymbol != null) {
			desc.SymbolName = Ast.EscapeAllInternalSymbolNames(aliasSymbol.Name);
		} else if (symbol != null) {
			desc.SymbolName = Ast.EscapeAllInternalSymbolNames(symbol.Name);
		}

		// Tuple flag
		if (typ.IsTuple()) {
			desc.IsTuple = true;
		}

		// Union types
		final unionTypes = typ.UnionTypes();
		if (Core.len(unionTypes) > 0) {
			desc.UnionTypes = Tracing.mapTypeIds(unionTypes);
		}

		// Intersection types
		final intersectionTypes = typ.IntersectionTypes();
		if (Core.len(intersectionTypes) > 0) {
			desc.IntersectionTypes = Tracing.mapTypeIds(intersectionTypes);
		}

		// Alias type arguments
		final args = typ.AliasTypeArguments();
		if (Core.len(args) > 0) {
			desc.AliasTypeArguments = Tracing.mapTypeIds(args);
		}

		// Index type (keyof)
		final indexType = typ.IndexType();
		if (indexType != null) {
			desc.KeyofType = indexType.Id();
		}

		// Indexed access type
		final objType = typ.IndexedAccessObjectType();
		if (objType != null) {
			desc.IndexedAccessObjectType = objType.Id();
		}
		final idxType = typ.IndexedAccessIndexType();
		if (idxType != null) {
			desc.IndexedAccessIndexType = idxType.Id();
		}

		// Conditional type
		if (typ.IsConditional()) {
			final checkType = typ.ConditionalCheckType();
			if (checkType != null) {
				desc.ConditionalCheckType = checkType.Id();
			}
			final extendsType = typ.ConditionalExtendsType();
			if (extendsType != null) {
				desc.ConditionalExtendsType = extendsType.Id();
			}
			final trueType = typ.ConditionalTrueType();
			if (trueType != null) {
				desc.ConditionalTrueType = trueType.Id(); // int32(trueType.Id())
			} else {
				desc.ConditionalTrueType = -1;
			}
			final falseType = typ.ConditionalFalseType();
			if (falseType != null) {
				desc.ConditionalFalseType = falseType.Id();
			} else {
				desc.ConditionalFalseType = -1;
			}
		}

		// Substitution type
		final baseType = typ.SubstitutionBaseType();
		if (baseType != null) {
			desc.SubstitutionBaseType = baseType.Id();
		}
		final constraint = typ.SubstitutionConstraintType();
		if (constraint != null) {
			desc.ConstraintType = constraint.Id();
		}

		// Reference type
		final target = typ.ReferenceTarget();
		if (target != null) {
			desc.InstantiatedType = target.Id();
		}
		final refArgs = typ.ReferenceTypeArguments();
		if (Core.len(refArgs) > 0) {
			desc.TypeArguments = Tracing.mapTypeIds(refArgs);
		}
		final node = typ.ReferenceNode();
		if (node != null) {
			desc.ReferenceLocation = Tracing.getLocation(node);
		}

		// Reverse mapped type
		final sourceType = typ.ReverseMappedSourceType();
		if (sourceType != null) {
			desc.ReverseMappedSourceType = sourceType.Id();
		}
		final mappedType = typ.ReverseMappedMappedType();
		if (mappedType != null) {
			desc.ReverseMappedMappedType = mappedType.Id();
		}
		final constraintType = typ.ReverseMappedConstraintType();
		if (constraintType != null) {
			desc.ReverseMappedConstraintType = constraintType.Id();
		}

		// Evolving array type
		final elemType = typ.EvolvingArrayElementType();
		if (elemType != null) {
			desc.EvolvingArrayElementType = elemType.Id();
		}
		final finalType = typ.EvolvingArrayFinalType();
		if (finalType != null) {
			desc.EvolvingArrayFinalType = finalType.Id();
		}

		// Pattern (destructuring)
		final pattern = typ.Pattern();
		if (pattern != null) {
			desc.DestructuringPattern = Tracing.getLocation(pattern);
		}

		// First declaration - prefer aliasSymbol, matching TypeScript's `aliasSymbol ?? symbol`
		var firstDeclSymbol = aliasSymbol;
		if (firstDeclSymbol == null) {
			firstDeclSymbol = symbol;
		}
		if (firstDeclSymbol != null && Core.len(firstDeclSymbol.Declarations) > 0) {
			desc.FirstDeclaration = Tracing.getLocation(firstDeclSymbol.Declarations[0]);
		}

		// Display text
		final display = typ.Display();
		if (display != "") {
			desc.Display = display;
		}

		return desc;
	}
}

// TypeDescriptor represents a type in the output JSON
// PORT: `*uint32` / `*int` / `*int32` → Null<Int>; `uint32` → Int.
class TypeDescriptor {
	public var ID:Int = 0; // json:"id"
	public var IntrinsicName:String = ""; // json:"intrinsicName,omitzero"
	public var SymbolName:String = ""; // json:"symbolName,omitzero"
	public var RecursionID:Null<Int> = null; // json:"recursionId,omitzero"
	public var IsTuple:Bool = false; // json:"isTuple,omitzero"
	public var UnionTypes:Array<Int> = null; // json:"unionTypes,omitzero"
	public var IntersectionTypes:Array<Int> = null; // json:"intersectionTypes,omitzero"
	public var AliasTypeArguments:Array<Int> = null; // json:"aliasTypeArguments,omitzero"
	public var KeyofType:Null<Int> = null; // json:"keyofType,omitzero"
	public var IndexedAccessObjectType:Null<Int> = null; // json:"indexedAccessObjectType,omitzero"
	public var IndexedAccessIndexType:Null<Int> = null; // json:"indexedAccessIndexType,omitzero"
	public var ConditionalCheckType:Null<Int> = null; // json:"conditionalCheckType,omitzero"
	public var ConditionalExtendsType:Null<Int> = null; // json:"conditionalExtendsType,omitzero"
	// ConditionalTrueType and ConditionalFalseType are *int32 (not *uint32) because
	// unresolved conditional branches are serialized as -1, matching TypeScript's behavior.
	public var ConditionalTrueType:Null<Int> = null; // json:"conditionalTrueType,omitzero"
	public var ConditionalFalseType:Null<Int> = null; // json:"conditionalFalseType,omitzero"
	public var SubstitutionBaseType:Null<Int> = null; // json:"substitutionBaseType,omitzero"
	public var ConstraintType:Null<Int> = null; // json:"constraintType,omitzero"
	public var InstantiatedType:Null<Int> = null; // json:"instantiatedType,omitzero"
	public var TypeArguments:Array<Int> = null; // json:"typeArguments,omitzero"
	public var ReferenceLocation:Location = null; // json:"referenceLocation,omitzero"
	public var ReverseMappedSourceType:Null<Int> = null; // json:"reverseMappedSourceType,omitzero"
	public var ReverseMappedMappedType:Null<Int> = null; // json:"reverseMappedMappedType,omitzero"
	public var ReverseMappedConstraintType:Null<Int> = null; // json:"reverseMappedConstraintType,omitzero"
	public var EvolvingArrayElementType:Null<Int> = null; // json:"evolvingArrayElementType,omitzero"
	public var EvolvingArrayFinalType:Null<Int> = null; // json:"evolvingArrayFinalType,omitzero"
	public var DestructuringPattern:Location = null; // json:"destructuringPattern,omitzero"
	public var FirstDeclaration:Location = null; // json:"firstDeclaration,omitzero"
	public var Flags:Array<String> = null; // json:"flags"
	public var Display:String = ""; // json:"display,omitzero"

	public function new() {}
}

// Location represents a source code location
class Location {
	public var Path:String = ""; // json:"path"
	public var Start:LineAndChar = null; // json:"start,omitzero"
	public var End:LineAndChar = null; // json:"end,omitzero"

	public function new() {}
}

// LineAndChar represents a line and character position (1-indexed)
class LineAndChar {
	public var Line:Int = 0; // json:"line"
	public var Character:Int = 0; // json:"character"

	public function new(Line:Int, Character:Int) {
		this.Line = Line;
		this.Character = Character;
	}
}
