package ts.ast;

// Port of deepclone.go: NodeFactory methods (PORTING.md §2: statics with the receiver first,
// `using ts.ast.Deepclone` in import.hx). getDeepCloneVisitor is in Ast.hx.
class Deepclone {
	public static function DeepCloneNode(f:NodeFactory, node:Node):Node {
		return Ast.getDeepCloneVisitor(f, true /*syntheticLocation*/).VisitNode(node);
	}

	public static function DeepCloneReparse(f:NodeFactory, node:Node):Node {
		if (node != null) {
			node = Ast.getDeepCloneVisitor(f, false /*syntheticLocation*/).VisitNode(node);
			Ast.SetParentInChildren(node);
			node.Flags |= NodeFlagsReparsed;
		}
		return node;
	}

	public static function DeepCloneReparseModifiers(f:NodeFactory, modifiers:ModifierList):ModifierList {
		return Ast.getDeepCloneVisitor(f, false /*syntheticLocation*/).VisitModifiers(modifiers);
	}
}
