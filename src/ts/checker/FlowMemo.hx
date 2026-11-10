package ts.checker;

// PORT: perf — (from tsrs) persistent memo of control flow analysis results (tsrs crates/tsrs_checker/src/flowmemo.rs,
// notes/flow-memo.md). Not in Go.
//
// Go walks the flow graph backwards from each reference (getFlowTypeOfReference) and caches only inside one walk
// (sharedFlows) and, per reference key, at loop labels (flowLoopCache). So R references to the same variable or
// property path in a long function each walk the common chain again. This memo keeps the result of a sub-walk, the
// type at a flow node for one reference key, across walks.
//
// Every getTypeAtFlowNode call of a walk with a memo key is a frame. A frame's result is stored only if Go, walking
// the same sub-graph for the same key at any later time, computes the same type and changes nothing observable:
// - no transient taint: no in-process loop label (incomplete types), circular or in-progress resolution, reduce
//   label (try/finally), depth or inline-level limit, re-entered getResolvedSignature, and no sharedFlows value
//   cached while one of those was active;
// - no reference taint: nothing read from the reference node beyond its key (its position, for constraint
//   substitution; the property symbol a property access resolved to);
// - the result is complete, the frame created no type, symbol or signature and did not touch the instantiation
//   counters; a frame that read flowTypeCache is used only while the same cache is current.
//
// Taint is tracked with serial numbers. Every frame, walk, loop-stack entry and type resolution takes one; a taint
// event carries the serial of its source and taints the active frames younger than the source (they consumed it).
// A loop label's frame is older than its stack entry, so the loop result (which Go caches for good) is not tainted
// by its own back edges, while every frame computed under them is; likewise a resolution's final result.
//
// TSHX_FLOW_MEMO=0 (or off) turns it off; TSHX_FLOW_MEMO=shadow walks every hit again and aborts the process on a
// different answer.
//
// The reference key is exact (no hash collisions): the root symbol (null for `this`), the reference node (its
// property-name chain is compared), the declared and initial types and the flow container. Only identifiers, `this`
// and chains of plain property accesses on them get one.
@:allow(ts.checker)
class FlowMemoSlot {
	var flow:FlowNode = null;
	var hash:Int = 0;
	var root:ts.ast.Symbol = null;
	var ref:Node = null;
	var declared:Type = null;
	var initial:Type = null;
	var container:Node = null;
	var t:Type = null;
	var height:Int = 0;
	// typeCacheEpoch when the value was computed, if the frame read flowTypeCache; else 0.
	var epoch:Int = 0;
	var countReset:Bool = false;
	// Shadow mode: the walk the value came from.
	var originRef:Node = null;
	var originDepth:Int = 0;

	public function new() {}
}

// Shadow mode: a memo answer as found, waiting for the frame that found it to end.
@:allow(ts.checker)
class FlowMemoShadowHit {
	var flow:FlowNode = null;
	var t:Type = null;
	var height:Int = 0;
	var originRef:Node = null;
	var originDepth:Int = 0;

	public function new() {}
}

@:allow(ts.checker)
class FlowMemo {
	// Go's limit on nested getTypeAtFlowNode calls in one walk (TS2563 when reached).
	static inline final DEPTH_LIMIT = 2000;
	// No taint source.
	static inline final UNTAINTED = 0x7fffffff;
	// The frame instantiated a type, ran inside an instantiation, or created a type, symbol or signature.
	static inline final FLAG_EFFECTS = 1;
	// The frame read flowTypeCache.
	static inline final FLAG_TYPE_CACHE = 2;
	// The frame may have reset the instantiation count (checkExpression): a later walk of it leaves the count where
	// this one did only if the count is already 0.
	static inline final FLAG_COUNT_RESET = 4;

	static inline final MODE_OFF = 0;
	static inline final MODE_ON = 1;
	static inline final MODE_SHADOW = 2;

	static var envMode:Int = -1;
	static var nextFlowId:Int = 0;

	static function modeFromEnv():Int {
		if (envMode < 0) {
			final v = Sys.getEnv("TSHX_FLOW_MEMO");
			envMode = v == "0" || v == "off" ? MODE_OFF : v == "shadow" ? MODE_SHADOW : MODE_ON;
		}
		return envMode;
	}

	var mode:Int;
	var slots:Slice<FlowMemoSlot> = null;
	var mask:Int = 0;
	var serial:Int = 1;
	// The registers of the innermost active frame: the oldest source of each kind it consumed so far, the largest
	// `child height + 1` so far (an upper bound on the depth its sub-walk can reach in any walk), FLAG_*.
	var rTransient:Int = UNTAINTED;
	var rReference:Int = UNTAINTED;
	var rHeight:Int = 0;
	var rFlags:Int = 0;
	// What the last endFrame found: the oldest source of each kind that the frame consumed (UNTAINTED if none was
	// older than the frame), and its flags.
	var lastTransient:Int = UNTAINTED;
	var lastReference:Int = UNTAINTED;
	var lastFlags:Int = 0;
	// Identifies the current Checker.flowTypeCache (a new one per reset, and when an entry changes); saved and
	// restored with it. Starts at a value serials never take.
	var typeCacheEpoch:Int = UNTAINTED;
	// Checkpoints that the active frames of keyed walks iterated past.
	var checkpoints:Array<FlowNode> = [];
	var checkpointsLen:Int = 0;
	// Shadow mode: memo answers waiting for the frame that found them to end.
	var shadowHits:Array<FlowMemoShadowHit> = [];

	public function new() {
		mode = modeFromEnv();
	}

	// A taint source for something that starts now, without taking a serial.
	inline function sourceNow():Int {
		return serial - 1;
	}

	// A fresh serial: the taint source of a walk or loop-stack entry, or a frame's start.
	inline function nextSerial():Int {
		final s = serial++;
		if (serial == UNTAINTED) {
			// Serials would wrap: stop memoizing, keep the rest exact.
			mode = MODE_OFF;
			serial = 1;
		}
		return s;
	}

	inline function taint(source:Int):Void {
		if (source < rTransient) {
			rTransient = source;
		}
	}

	inline function taintReference(source:Int):Void {
		if (source < rReference) {
			rReference = source;
		}
	}

	// Ends a frame whose sub-walk has height `height`; the parent's registers (saved at the frame's start) take on
	// its taint, flags and height. The frame's taint is left in last*.
	inline function endFrame(start:Int, pTransient:Int, pReference:Int, pHeight:Int, pFlags:Int, height:Int):Void {
		final t = rTransient;
		final r = rReference;
		final fl = rFlags;
		lastTransient = t < start ? t : UNTAINTED;
		lastReference = r < start ? r : UNTAINTED;
		lastFlags = fl;
		rTransient = t < pTransient ? t : pTransient;
		rReference = r < pReference ? r : pReference;
		rHeight = pHeight > height + 1 ? pHeight : height + 1;
		rFlags = fl | pFlags;
	}

	// About one in four flow nodes, chosen by the node: a checkpoint on long linear chains.
	static inline function isCheckpoint(flow:FlowNode):Bool {
		return ((flowId(flow) * 0x9E3779B1) >>> 30) == 0;
	}

	static inline function flowId(flow:FlowNode):Int {
		var id = flow.memoId;
		if (id == 0) {
			id = newFlowId(flow);
		}
		return id;
	}

	static function newFlowId(flow:FlowNode):Int {
		// (Racy under -D tshx-parallel: a duplicate id is only a hash collision.)
		final id = ++nextFlowId;
		flow.memoId = id;
		return id;
	}

	inline function slotIndex(flow:FlowNode, hash:Int):Int {
		final h = (flowId(flow) * 0x9E3779B1) ^ hash;
		return ((h * 0x85EBCA6B) >>> 12) & mask;
	}

	function lookup(flow:FlowNode, f:FlowState):FlowMemoSlot {
		if (slots == null) {
			return null;
		}
		final slot = slots[slotIndex(flow, f.memoHash)];
		if (slot.flow == flow && slot.hash == f.memoHash && slot.root == f.memoRoot && slot.declared == f.declaredType
			&& slot.initial == f.initialType && slot.container == f.flowContainer && sameChain(slot.ref, f.reference)) {
			return slot;
		}
		return null;
	}

	// The property-name chains of two keyed references are the same (their roots' symbols are compared apart).
	static function sameChain(a:Node, b:Node):Bool {
		while (a != b) {
			if (a.Kind != b.Kind) {
				return false;
			}
			if (a.Kind != KindPropertyAccessExpression) {
				return true;
			}
			if (a.Name().Text() != b.Name().Text()) {
				return false;
			}
			a = a.Expression();
			b = b.Expression();
		}
		return true;
	}

	function store(flow:FlowNode, f:FlowState, t:Type, height:Int, epoch:Int, countReset:Bool, originDepth:Int):Void {
		if (slots == null) {
			var bits = 12;
			final v = Sys.getEnv("TSHX_FLOW_MEMO_BITS");
			if (v != null) {
				final b = Std.parseInt(v);
				if (b != null && b >= 8 && b <= 24) {
					bits = b;
				}
			}
			slots = [for (_ in 0...1 << bits) new FlowMemoSlot()];
			mask = (1 << bits) - 1;
		}
		final slot = slots[slotIndex(flow, f.memoHash)];
		slot.flow = flow;
		slot.hash = f.memoHash;
		slot.root = f.memoRoot;
		slot.ref = f.reference;
		slot.declared = f.declaredType;
		slot.initial = f.initialType;
		slot.container = f.flowContainer;
		slot.t = t;
		slot.height = height;
		slot.epoch = epoch;
		slot.countReset = countReset;
		if (mode == MODE_SHADOW) {
			slot.originRef = f.reference;
			slot.originDepth = originDepth;
		}
	}
}
