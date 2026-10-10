package ts.printer;

import haxe.ds.ObjectMap;

// Port of changetrackerwriter.go (types and methods; NewChangeTrackerWriter is a package static in
// class Printer).

// PORT: Go embeds textWriter by value; here a composition field `textWriter` with explicit
// forwarding methods (Go's promoted methods), so calls on the embedded writer stay non-virtual.
@:allow(ts.printer)
class ChangeTrackerWriter implements EmitTextWriter implements Grower {
	public var textWriter:TextWriter = new TextWriter();
	var lastNonTriviaPosition:Int = 0;
	// PORT: Go `map[triviaPositionKey]int` with *ast.Node / *ast.NodeList keys → identity maps.
	var pos:ObjectMap<{}, Int> = null;
	var end:ObjectMap<{}, Int> = null;

	public function new() {}

	public function GetPrintHandlers():PrintHandlers {
		final h = new PrintHandlers();
		h.OnBeforeEmitNode = function(nodeOpt:Node) {
			if (nodeOpt != null) {
				setPos(nodeOpt);
			}
		};
		h.OnAfterEmitNode = function(nodeOpt:Node) {
			if (nodeOpt != null) {
				setEnd(nodeOpt);
			}
		};
		h.OnBeforeEmitNodeList = function(nodesOpt:NodeList) {
			if (nodesOpt != null) {
				setPos(nodesOpt);
			}
		};
		h.OnAfterEmitNodeList = function(nodesOpt:NodeList) {
			if (nodesOpt != null) {
				setEnd(nodesOpt);
			}
		};
		h.OnBeforeEmitToken = function(nodeOpt:TokenNode) {
			if (nodeOpt != null) {
				setPos(nodeOpt);
			}
		};
		h.OnAfterEmitToken = function(nodeOpt:TokenNode) {
			if (nodeOpt != null) {
				setEnd(nodeOpt);
			}
		};
		return h;
	}

	function setPos(node:TriviaPositionKey):Void {
		pos.set(node, lastNonTriviaPosition);
	}

	function setEnd(node:TriviaPositionKey):Void {
		end.set(node, lastNonTriviaPosition);
	}

	function getPos(node:TriviaPositionKey):Int {
		final v = pos.get(node);
		return v == null ? 0 : v;
	}

	function getEnd(node:TriviaPositionKey):Int {
		final v = end.get(node);
		return v == null ? 0 : v;
	}

	function setLastNonTriviaPosition(s:std.String, force:Bool):Void {
		if (force || Scanner.SkipTrivia(s, 0) != s.length) {
			lastNonTriviaPosition = textWriter.GetTextPos();
			// trim trailing whitespaces
			var pos = s.length;
			while (pos > 0) {
				final r = Utf16.DecodeLastRuneBefore(s, pos);
				if (Stringutil.IsWhiteSpaceLike(r)) {
					pos -= Utf16.RuneLen(r);
				} else {
					break;
				}
			}
			lastNonTriviaPosition -= s.length - pos;
		}
	}

	public function AssignPositionsToNode(node:Node, factory:ts.ast.Ast.NodeFactory):Node {
		var visitor:NodeVisitor = null;
		visitor = new NodeVisitor();
		visitor.Visit = function(n:Node):Node {
			return assignPositionsToNodeWorker(n, visitor);
		};
		visitor.Factory = factory;
		final hooks = new NodeVisitorHooks();
		hooks.VisitNode = assignPositionsToNodeWorker;
		hooks.VisitNodes = assignPositionsToNodeArray;
		hooks.VisitToken = assignPositionsToNodeWorker;
		hooks.VisitModifiers = function(modifiers:ModifierList, v:NodeVisitor):ModifierList {
			if (modifiers != null) {
				final newNodeList = assignPositionsToNodeArray(modifiers, v);
				// Return a new ModifierList so that VisitEachChild/Update detects the
				// change and creates a new node with reassigned child positions.
				return factory.NewModifierList(newNodeList.Nodes);
			}
			return modifiers;
		};
		visitor.Hooks = hooks;
		return assignPositionsToNodeWorker(node, visitor);
	}

	function assignPositionsToNodeWorker(node:Node, v:NodeVisitor):Node {
		if (node == null) {
			return node;
		}
		final visited = node.VisitEachChild(v);
		// create proxy node for non synthesized nodes
		var newNode = visited;
		if (!Ast.NodeIsSynthesized(visited)) {
			newNode = visited.Clone(v.Factory);
		}
		final parent = newNode;
		newNode.ForEachChild(function(child:Node):Bool {
			child.Parent = parent;
			return true;
		});
		newNode.Loc = Core.NewTextRange(getPos(node), getEnd(node));
		return newNode;
	}

	function assignPositionsToNodeArray(nodes:NodeList, v:NodeVisitor):NodeList {
		final visited = v.VisitNodes(nodes);
		if (visited == null) {
			return visited;
		}
		if (nodes == null) {
			// Debug.assert(nodes);
			throw "if nodes is nil, visited should not be nil";
		}
		// clone nodearray if necessary
		var nodeArray = visited;
		if (visited == nodes) {
			nodeArray = visited.Clone(v.Factory);
		}

		nodeArray.Loc = Core.NewTextRange(getPos(nodes), getEnd(nodes));
		return nodeArray;
	}

	public function Grow(n:Int):Void {
		textWriter.Grow(n);
	}

	public function Write(text:std.String):Void {
		textWriter.Write(text);
		setLastNonTriviaPosition(text, false);
	}

	public function WriteTrailingSemicolon(text:std.String):Void {
		textWriter.WriteTrailingSemicolon(text);
		setLastNonTriviaPosition(text, false);
	}

	public function WriteComment(text:std.String):Void {
		textWriter.WriteComment(text);
	}

	public function WriteKeyword(text:std.String):Void {
		textWriter.WriteKeyword(text);
		setLastNonTriviaPosition(text, false);
	}

	public function WriteOperator(text:std.String):Void {
		textWriter.WriteOperator(text);
		setLastNonTriviaPosition(text, false);
	}

	public function WritePunctuation(text:std.String):Void {
		textWriter.WritePunctuation(text);
		setLastNonTriviaPosition(text, false);
	}

	public function WriteSpace(text:std.String):Void {
		textWriter.WriteSpace(text);
		setLastNonTriviaPosition(text, false);
	}

	public function WriteStringLiteral(text:std.String):Void {
		textWriter.WriteStringLiteral(text);
		setLastNonTriviaPosition(text, false);
	}

	public function WriteParameter(text:std.String):Void {
		textWriter.WriteParameter(text);
		setLastNonTriviaPosition(text, false);
	}

	public function WriteProperty(text:std.String):Void {
		textWriter.WriteProperty(text);
		setLastNonTriviaPosition(text, false);
	}

	public function WriteSymbol(text:std.String, symbol:Symbol):Void {
		textWriter.WriteSymbol(text, symbol);
		setLastNonTriviaPosition(text, false);
	}

	public function WriteLine():Void {
		textWriter.WriteLine();
	}

	public function WriteLineForce(force:Bool):Void {
		textWriter.WriteLineForce(force);
	}

	public function IncreaseIndent():Void {
		textWriter.IncreaseIndent();
	}

	public function DecreaseIndent():Void {
		textWriter.DecreaseIndent();
	}

	public function Clear():Void {
		textWriter.Clear();
		lastNonTriviaPosition = 0;
	}

	public function String():std.String {
		return textWriter.String();
	}

	public function RawWrite(s:std.String):Void {
		textWriter.RawWrite(s);
		setLastNonTriviaPosition(s, false);
	}

	public function WriteLiteral(s:std.String):Void {
		textWriter.WriteLiteral(s);
		setLastNonTriviaPosition(s, true);
	}

	public function GetTextPos():Int {
		return textWriter.GetTextPos();
	}

	public function GetLine():Int {
		return textWriter.GetLine();
	}

	public function GetColumn():UTF16Offset {
		return textWriter.GetColumn();
	}

	public function GetIndent():Int {
		return textWriter.GetIndent();
	}

	public function IsAtStartOfLine():Bool {
		return textWriter.IsAtStartOfLine();
	}

	public function HasTrailingComment():Bool {
		return textWriter.HasTrailingComment();
	}

	public function HasTrailingWhitespace():Bool {
		return textWriter.HasTrailingWhitespace();
	}
}

// PORT: Go `interface { Pos() int; End() int }` holding *ast.Node or *ast.NodeList → an abstract over
// Dynamic used only as an identity map key (both are class instances).
abstract TriviaPositionKey({}) to {} {
	@:from static inline function fromNode(n:Node):TriviaPositionKey {
		return cast (n : NodeDefault);
	}

	@:from static inline function fromNodeList(l:NodeList):TriviaPositionKey {
		return cast l;
	}
}
