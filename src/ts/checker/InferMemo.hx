package ts.checker;

// PORT: perf — (from tsrs) memo of top-level inference walks (tsrs crates/tsrs_checker/src/infermemo.rs,
// notes/perf-heavy-files-infer-memo.md). Not in Go.
//
// `inferTypes` walks a source type against a target type and adds candidates to the inference infos of the type
// parameters it reaches. Some walks are long and are made again and again with the same inputs: inferring from a
// contextual union of N object types to a return type `Extract<Union, { type: K }>` takes about 4·N² inferFromTypes
// steps, and a generic call checked M times against the same contextual type repeats it 2·M times with infos that
// start empty each time, so every repeat ends in the same candidates.
//
// The memo maps the inputs of a top-level walk to its outcome. A walk starts from a fresh InferenceState (empty
// `visited`, no propagation type, not bivariant), so its inputs are the source, the target, the priority, the
// contravariance, and for each inference info (at most MAX_INFOS) what the walk reads from it: the type parameter,
// the candidate and contravariant candidate lists, the priority, `topLevel`, `isFixed` and the implied arity. Its
// outcome is what it writes: each info's two lists (and whether it appended to the same array or replaced it),
// priority and `topLevel`, and whether it cleared the infos' cached inferred types (the walk never reads them).
// A walk is stored only when
// - it created no type, symbol or signature, left the instantiation counters where they were and added no
//   diagnostic: it read only values that were already computed and computed nothing new (a mapper that reads the
//   infos' inferred types runs only inside an instantiation, so such a walk is never stored);
// - it checked no expression if it started with the instantiation count at 0 (checkExpression resets the count, and
//   a reset from 0 to 0 cannot be seen in it);
// - it did not start inside an instantiation (it could take instantiations from the active mappers' caches without
//   counting them);
// - it read no transient state: the flow memo's taint registers (FlowMemo.hx) saw no in-progress or circular
//   resolution older than the walk, no re-entered getResolvedSignature, no in-process loop label, and no
//   flowTypeCache entry was read;
// - the language service is not blocking inference from some nodes (skipDirectInferenceNodes is empty);
// - it took at least MIN_STEPS inferFromTypes steps, and an earlier walk to the same target did too (the first long
//   walk to a target only marks it, so the many short walks pay one map lookup).
//
// Such a walk read only finished values besides its inputs, so the same inputs walked again take the same path and
// write the same outcome. A hit writes the outcome without the walk and replays what the walk reported to the
// enclosing flow memo frame (height and flags, plus FLAG_COUNT_RESET when it did flow work). A hit for a walk that
// did flow work is not used while a loop analysis is in progress (tsc-haxe: its flow sub-walks could then read the
// loop's incomplete types). Types are never freed while their checker lives, so a type id in a key names one type.
//
// TSHX_INFER_MEMO=0 (or off) turns it off; =shadow walks every hit again and exits (99) unless that walk has no
// effects and ends in the stored outcome. TSHX_INFER_MEMO_STATS=1 prints totals on stderr at exit;
// TSHX_INFER_MEMO_MIN_STEPS=<n> sets the shortest walk that is stored.
@:allow(ts.checker)
class InferMemoInfo {
	var candidates:Slice<Type> = null;
	var contraCandidates:Slice<Type> = null;
	// The walk appended to the info's arrays (or left them alone) rather than replacing them.
	var sameCandidates:Bool = false;
	var sameContraCandidates:Bool = false;
	var priority:InferencePriority = 0;
	var topLevel:Bool = false;

	public function new() {}

	function equals(o:InferMemoInfo):Bool {
		return sameList(candidates, o.candidates) && sameList(contraCandidates, o.contraCandidates) && sameCandidates == o.sameCandidates
			&& sameContraCandidates == o.sameContraCandidates && priority == o.priority && topLevel == o.topLevel;
	}

	static function sameList(a:Slice<Type>, b:Slice<Type>):Bool {
		if (a == null || b == null) {
			return a == b;
		}
		if (a.length != b.length) {
			return false;
		}
		for (i in 0...a.length) {
			if (a[i] != b[i]) {
				return false;
			}
		}
		return true;
	}

	function toString():std.String {
		inline function list(l:Slice<Type>):std.String
			return l == null ? "null" : "[" + [for (t in l) t.id].join(",") + "]";
		return "{" + list(candidates) + (sameCandidates ? "=" : "") + " / " + list(contraCandidates) + (sameContraCandidates ? "=" : "") + " p"
			+ (priority : Int) + (topLevel ? " top" : "") + "}";
	}
}

@:allow(ts.checker)
class InferMemoEntry {
	var hash:Int = 0;
	var key:Slice<Int> = null;
	var next:InferMemoEntry = null;
	var infos:Slice<InferMemoInfo> = null;
	var cleared:Bool = false;
	var height:Int = 0;
	var flags:Int = 0;
	var flowed:Bool = false;
	var steps:Int = 0;

	public function new() {}
}

@:allow(ts.checker)
class InferMemo {
	// Calls with more inference infos than this are not memoized.
	static inline final MAX_INFOS = 8;

	static inline final MODE_OFF = 0;
	static inline final MODE_ON = 1;
	static inline final MODE_SHADOW = 2;

	static var envMode:Int = -1;
	static var envMinSteps:Int = -1;
	static var stats:Bool = false;
	// (Statistics only: racy under -D tshx-parallel.)
	static var lookups:Int = 0;
	static var hits:Int = 0;
	static var stores:Int = 0;
	static var skippedSteps:Float = 0;
	static var notStoredEffects:Int = 0;
	static var notStoredTaint:Int = 0;

	static function modeFromEnv():Int {
		if (envMode < 0) {
			final v = Sys.getEnv("TSHX_INFER_MEMO");
			final s = Sys.getEnv("TSHX_INFER_MEMO_STATS");
			stats = s != null && s != "" && s != "0";
			var minSteps = 16;
			final ms = Sys.getEnv("TSHX_INFER_MEMO_MIN_STEPS");
			if (ms != null) {
				final p = Std.parseInt(ms);
				if (p != null && p >= 1) {
					minSteps = p;
				}
			}
			envMinSteps = minSteps;
			envMode = v == "0" || v == "off" ? MODE_OFF : v == "shadow" ? MODE_SHADOW : MODE_ON;
		}
		return envMode;
	}

	var mode:Int;
	var minSteps:Int;
	var entries:haxe.ds.IntMap<InferMemoEntry> = new haxe.ds.IntMap();
	// Targets of walks that took at least minSteps steps: only walks to these are keyed, looked up and measured.
	var longTargets:haxe.ds.IntMap<Bool> = new haxe.ds.IntMap();
	// Key buffers, one per nesting level of memoized walks.
	var keyPool:Array<Slice<Int>> = [];

	public function new() {
		mode = modeFromEnv();
		minSteps = envMinSteps;
	}

	// Prints the process totals when TSHX_INFER_MEMO_STATS is set (call at exit).
	public static function finish():Void {
		modeFromEnv();
		if (!stats) {
			return;
		}
		Sys.stderr().writeString("tshx: inference memo: " + lookups + " lookups, " + hits + " hits skipping " + skippedSteps + " steps, " + stores
			+ " stores; walks of " + envMinSteps + "+ steps not stored: " + notStoredEffects + " had effects, " + notStoredTaint + " tainted\n");
	}

	// `inferFromTypes(n, source, target)` for the walk at the top of inferTypes, through the memo.
	static function inferFromTypesMemo(c:Checker, n:InferenceState, source:Type, target:Type):Void {
		final memo = c.inferMemo;
		if (memo.mode == MODE_OFF) {
			c.inferFromTypes(n, source, target);
			return;
		}
		if (!memo.longTargets.exists(target.id)) {
			// The first long walk to a target only marks it: most walks are short, and keying and measuring them would
			// cost more than the memo saves.
			final stepsBefore = c.inferMemoSteps;
			c.inferFromTypes(n, source, target);
			if (c.inferMemoSteps - stepsBefore >= memo.minSteps) {
				memo.longTargets.set(target.id, true);
			}
			return;
		}
		final key = memo.keyPool.length != 0 ? memo.keyPool.pop() : [];
		final hash = buildKey(c, key, n, source, target);
		if (hash < 0) {
			memo.keyPool.push(key);
			c.inferFromTypes(n, source, target);
			return;
		}
		if (stats) {
			lookups++;
		}
		final entry = memo.find(hash, key);
		if (entry != null && (!entry.flowed || c.flowLoopStack == null || c.flowLoopStack.length == 0)) {
			if (stats) {
				hits++;
				skippedSteps += entry.steps;
			}
			if (memo.mode == MODE_SHADOW) {
				shadow(c, n, source, target, entry);
			} else {
				final inferences = n.inferences;
				for (i in 0...inferences.length) {
					final info = inferences[i];
					final outcome = entry.infos[i];
					info.candidates = replay(info.candidates, outcome.candidates, outcome.sameCandidates);
					info.contraCandidates = replay(info.contraCandidates, outcome.contraCandidates, outcome.sameContraCandidates);
					info.priority = outcome.priority;
					info.topLevel = outcome.topLevel;
				}
				if (entry.cleared) {
					Checker.clearCachedInferences(inferences);
				}
			}
			memo.keyPool.push(key);
			final m = c.flowMemo;
			if (entry.height > m.rHeight) {
				m.rHeight = entry.height;
			}
			m.rFlags |= entry.flags;
			return;
		}
		// A reset of the instantiation count (checkExpression) at 0 cannot be seen in the count; the same walk made
		// later at another count would reset it.
		final countZero = c.instantiationCount == 0;
		final expressionChecks = c.expressionChecks;
		final m = c.flowMemo;
		n.clearedInferences = false;
		// Inside an instantiation the walk can take instantiations from the active mappers' caches without counting
		// them; walked again outside it, it would count them.
		final inInstantiation = c.activeMappers != null && c.activeMappers.length != 0;
		final created = c.TypeCount + c.SymbolCount + c.SignatureCount;
		final instantiationCount = c.instantiationCount;
		final totalInstantiationCount = c.TotalInstantiationCount;
		final diagnostics = c.diagnosticAdds;
		final before = snapshotLists(n.inferences);
		final stepsBefore = c.inferMemoSteps;
		// A frame of the flow memo's taint registers around the walk that leaves the parent's registers as if it had
		// not been begun (tsrs FlowMemo::end_transparent).
		final start = m.nextSerial();
		final pTransient = m.rTransient;
		final pReference = m.rReference;
		final pHeight = m.rHeight;
		final pFlags = m.rFlags;
		m.rTransient = FlowMemo.UNTAINTED;
		m.rReference = FlowMemo.UNTAINTED;
		m.rHeight = 0;
		m.rFlags = 0;
		c.inferFromTypes(n, source, target);
		final rT = m.rTransient;
		final rR = m.rReference;
		final height = m.rHeight;
		var flags = m.rFlags;
		m.rTransient = rT < pTransient ? rT : pTransient;
		m.rReference = rR < pReference ? rR : pReference;
		m.rHeight = pHeight > height ? pHeight : height;
		m.rFlags = flags | pFlags;
		final steps = c.inferMemoSteps - stepsBefore;
		final effects = inInstantiation || countZero && c.expressionChecks != expressionChecks
			|| c.TypeCount + c.SymbolCount + c.SignatureCount != created || c.instantiationCount != instantiationCount
			|| c.TotalInstantiationCount != totalInstantiationCount || c.diagnosticAdds != diagnostics
			|| (flags & (FlowMemo.FLAG_EFFECTS | FlowMemo.FLAG_TYPE_CACHE)) != 0;
		final tainted = rT < start || rR < start || c.skipDirectInferenceNodes.Len() != 0;
		if (steps < memo.minSteps || effects || tainted) {
			if (stats && steps >= memo.minSteps) {
				if (effects) {
					notStoredEffects++;
				}
				if (tainted) {
					notStoredTaint++;
				}
			}
			memo.keyPool.push(key);
			return;
		}
		if (stats) {
			stores++;
		}
		// Flow frames inside the walk add FLAG_COUNT_RESET when the count is 0 at their start, which depends on when the
		// walk is made, not on its inputs; the flag only restricts the flow memo, so a hit replays it whenever the walk
		// did flow work.
		final flowed = m.sourceNow() != start;
		if (flowed) {
			flags |= FlowMemo.FLAG_COUNT_RESET;
		}
		final e = new InferMemoEntry();
		e.hash = hash;
		e.key = key.copy();
		e.infos = outcomes(n.inferences, before);
		e.cleared = n.clearedInferences;
		e.height = height;
		e.flags = flags;
		e.flowed = flowed;
		e.steps = steps;
		e.next = memo.entries.get(hash);
		memo.entries.set(hash, e);
		memo.keyPool.push(key);
	}

	function find(hash:Int, key:Slice<Int>):InferMemoEntry {
		var e = entries.get(hash);
		while (e != null) {
			if (e.hash == hash && sameKey(e.key, key)) {
				return e;
			}
			e = e.next;
		}
		return null;
	}

	static function sameKey(a:Slice<Int>, b:Slice<Int>):Bool {
		if (a.length != b.length) {
			return false;
		}
		for (i in 0...a.length) {
			if (a[i] != b[i]) {
				return false;
			}
		}
		return true;
	}

	static inline function mix(h:Int, v:Int):Int {
		return ((h ^ v) * 0x01000193) & 0x3FFFFFFF; // (bounded on Python's integers)
	}

	// Builds the walk's key in `key` and returns its hash (non-negative); -1 when the call is not memoized.
	static function buildKey(c:Checker, key:Slice<Int>, n:InferenceState, source:Type, target:Type):Int {
		if (c.skipDirectInferenceNodes.Len() != 0) {
			return -1;
		}
		final inferences = n.inferences;
		if (inferences == null || inferences.length > MAX_INFOS) {
			return -1;
		}
		key.resize(0);
		key.push(source.id);
		key.push(target.id);
		key.push((n.priority : Int));
		key.push(n.contravariant ? 1 : 0);
		key.push(inferences.length);
		for (info in inferences) {
			key.push(info.typeParameter != null ? info.typeParameter.id : 0);
			key.push((info.priority : Int));
			key.push((info.topLevel ? 1 : 0) | (info.isFixed ? 2 : 0));
			key.push(info.impliedArity);
			pushList(key, info.candidates);
			pushList(key, info.contraCandidates);
		}
		var h = 0x2545F491;
		for (v in key) {
			h = mix(h, v);
		}
		return h;
	}

	// A list's length (-1: null) and type ids.
	static inline function pushList(key:Slice<Int>, list:Slice<Type>):Void {
		if (list == null) {
			key.push(-1);
		} else {
			key.push(list.length);
			for (t in list) {
				key.push(t.id);
			}
		}
	}

	// The infos' list arrays before a walk (two per info), to tell appending from replacing.
	static function snapshotLists(inferences:Slice<InferenceInfo>):Array<Slice<Type>> {
		final r:Array<Slice<Type>> = [];
		for (info in inferences) {
			r.push(info.candidates);
			r.push(info.contraCandidates);
		}
		return r;
	}

	static function outcomes(inferences:Slice<InferenceInfo>, before:Array<Slice<Type>>):Array<InferMemoInfo> {
		final r:Array<InferMemoInfo> = [];
		for (i in 0...inferences.length) {
			final info = inferences[i];
			final o = new InferMemoInfo();
			o.candidates = info.candidates != null ? info.candidates.copy() : null;
			o.contraCandidates = info.contraCandidates != null ? info.contraCandidates.copy() : null;
			o.sameCandidates = info.candidates == before[2 * i];
			o.sameContraCandidates = info.contraCandidates == before[2 * i + 1];
			o.priority = info.priority;
			o.topLevel = info.topLevel;
			r.push(o);
		}
		return r;
	}

	// What the walk did to one list: appended to the same array (the current one holds the stored list's prefix, as
	// the key says), or put a new one (or null) in its place.
	static inline function replay(current:Slice<Type>, stored:Slice<Type>, same:Bool):Slice<Type> {
		if (same) {
			if (current != null) {
				for (i in current.length...stored.length) {
					current.push(stored[i]);
				}
			}
			return current;
		}
		return stored != null ? stored.copy() : null;
	}

	// Shadow mode: walks a hit for real and exits unless the walk has no effects and ends in the stored outcome.
	static function shadow(c:Checker, n:InferenceState, source:Type, target:Type, entry:InferMemoEntry):Void {
		final m = c.flowMemo;
		n.clearedInferences = false;
		final created = c.TypeCount + c.SymbolCount + c.SignatureCount;
		final instantiationCount = c.instantiationCount;
		final totalInstantiationCount = c.TotalInstantiationCount;
		final diagnostics = c.diagnosticAdds;
		final before = snapshotLists(n.inferences);
		final start = m.nextSerial();
		final pTransient = m.rTransient;
		final pReference = m.rReference;
		final pHeight = m.rHeight;
		final pFlags = m.rFlags;
		m.rTransient = FlowMemo.UNTAINTED;
		m.rReference = FlowMemo.UNTAINTED;
		m.rHeight = 0;
		m.rFlags = 0;
		c.inferFromTypes(n, source, target);
		final rT = m.rTransient;
		final rR = m.rReference;
		final height = m.rHeight;
		final flags = m.rFlags;
		m.rTransient = rT < pTransient ? rT : pTransient;
		m.rReference = rR < pReference ? rR : pReference;
		m.rHeight = pHeight > height ? pHeight : height;
		m.rFlags = flags | pFlags;
		final effects = c.TypeCount + c.SymbolCount + c.SignatureCount != created || c.instantiationCount != instantiationCount
			|| c.TotalInstantiationCount != totalInstantiationCount || c.diagnosticAdds != diagnostics;
		final pure = rT >= start && rR >= start;
		final outcome = outcomes(n.inferences, before);
		var same = outcome.length == entry.infos.length;
		if (same) {
			for (i in 0...outcome.length) {
				if (!outcome[i].equals(entry.infos[i])) {
					same = false;
				}
			}
		}
		final flagsCovered = (flags & ~entry.flags) == 0 && ((flags ^ entry.flags) & ~FlowMemo.FLAG_COUNT_RESET) == 0;
		if (effects || !pure || !same || n.clearedInferences != entry.cleared || height != entry.height || !flagsCovered) {
			Sys.stderr().writeString("TSHX_INFER_MEMO=shadow: inferring from type " + source.id + " to type " + target.id + " (priority "
				+ (n.priority : Int) + "): the walk again has effects " + effects + ", pure " + pure + ", outcome " + Std.string(outcome) + " (stored "
				+ Std.string(entry.infos) + "), cleared " + n.clearedInferences + " (stored " + entry.cleared + "), height " + height + " (stored "
				+ entry.height + "), flags " + flags + " (stored " + entry.flags + ")\n");
			Sys.stderr().flush();
			Sys.exit(99);
		}
	}
}
