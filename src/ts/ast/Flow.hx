package ts.ast;

// Port of flow.go (types and methods; NewFlowSwitchClauseData / NewFlowReduceLabelData are in
// Ast.hx).

// FlowFlags
enum abstract FlowFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:FlowFlags, b:FlowFlags):FlowFlags;
	@:op(A & B) static function and(a:FlowFlags, b:FlowFlags):FlowFlags;
	@:op(~A) static function not(a:FlowFlags):FlowFlags;

	var FlowFlagsUnreachable = 1 << 0; // Unreachable code
	var FlowFlagsStart = 1 << 1; // Start of flow graph
	var FlowFlagsBranchLabel = 1 << 2; // Non-looping junction
	var FlowFlagsLoopLabel = 1 << 3; // Looping junction
	var FlowFlagsAssignment = 1 << 4; // Assignment
	var FlowFlagsTrueCondition = 1 << 5; // Condition known to be true
	var FlowFlagsFalseCondition = 1 << 6; // Condition known to be false
	var FlowFlagsSwitchClause = 1 << 7; // Switch statement clause
	var FlowFlagsArrayMutation = 1 << 8; // Potential array mutation
	var FlowFlagsCall = 1 << 9; // Potential assertion call
	var FlowFlagsReduceLabel = 1 << 10; // Temporarily reduce antecedents of label
	var FlowFlagsReferenced = 1 << 11; // Referenced as antecedent once
	var FlowFlagsShared = 1 << 12; // Referenced as antecedent more than once
	var FlowFlagsLabel = FlowFlagsBranchLabel | FlowFlagsLoopLabel;
	var FlowFlagsCondition = FlowFlagsTrueCondition | FlowFlagsFalseCondition;
}

// FlowNode
class FlowNode {
	public var Flags:FlowFlags = 0;
	public var Node:Node = null; // Associated AST node
	public var Antecedent:FlowNode = null; // Antecedent for all but FlowLabel
	public var Antecedents:FlowList = null; // Linked list of antecedents for FlowLabel

	public function new() {}
}

class FlowList {
	public var Flow:FlowNode = null;
	public var Next:FlowList = null;

	public function new() {}
}

typedef FlowLabel = FlowNode;

// FlowSwitchClauseData (synthetic AST node for FlowFlagsSwitchClause)
class FlowSwitchClauseData extends NodeDefault {
	public var SwitchStatement:Node = null;
	public var ClauseStart:Int = 0; // Start index of case/default clause range
	public var ClauseEnd:Int = 0; // End index of case/default clause range

	public function new() {
		super();
	}

	public function IsEmpty():Bool {
		return ClauseStart == ClauseEnd;
	}
}

// FlowReduceLabelData (synthetic AST node for FlowFlagsReduceLabel)
class FlowReduceLabelData extends NodeDefault {
	public var Target:FlowLabel = null; // Target label
	public var Antecedents:FlowList = null; // Temporary antecedent list

	public function new() {
		super();
	}
}
