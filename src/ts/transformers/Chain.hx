package ts.transformers;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/chain.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers)
class ChainedTransformer extends Transformer {
	var components:Array<Transformer> = null;

	public function new() {
		super();
	}

	function visit(node:Node):Node {
		if (node.Kind != KindSourceFile) {
			throw "Chained transform passed non-sourcefile initial node";
		}
		var result = node.AsSourceFile();
		for (t in components) {
			result = t.TransformSourceFile(result);
		}
		return result.AsNode();
	}
}

class TransformOptions {
	public var Context:EmitContext = null;
	public var CompilerOptions:CompilerOptions = null;
	public var Resolver:ReferenceResolver = null;
	public var EmitResolver:EmitResolver = null;
	public var GetEmitModuleFormatOfFile:(file:HasFileName) -> ModuleKind = null;

	public function new() {}
}

typedef TransformerFactory = (opt:TransformOptions) -> Transformer;

