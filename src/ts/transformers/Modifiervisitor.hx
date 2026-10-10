package ts.transformers;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/modifiervisitor.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers)
class ModifierVisitor extends Transformer {
	public var AllowedModifiers:ModifierFlags = 0;

	public function new() {
		super();
	}

	function visit(node:Node):Node {
		final flags = Ast.ModifierToFlag(node.Kind);
		if (flags != ModifierFlagsNone && (flags & AllowedModifiers) == 0) {
			return null;
		}
		return node;
	}
}

