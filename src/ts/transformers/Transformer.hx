package ts.transformers;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/transformer.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers)
class Transformer {
	var emitContext:EmitContext = null;
	var factory:ts.printer.Factory.NodeFactory = null;
	var visitor:NodeVisitor = null;

	public function new() {}

	public function NewTransformer(visit:(node:Node) -> Node, emitContext:EmitContext):Transformer {
		if (this.emitContext != null) {
			throw "Transformer already initialized";
		}
		if (emitContext == null) {
			emitContext = Printer.NewEmitContext();
		}
		this.emitContext = emitContext;
		this.factory = emitContext.Factory;
		this.visitor = emitContext.NewNodeVisitor(visit);
		return this;
	}

	public function EmitContext():EmitContext {
		return emitContext;
	}

	public function Visitor():NodeVisitor {
		return visitor;
	}

	public function Factory():ts.printer.Factory.NodeFactory {
		return factory;
	}

	public function TransformSourceFile(file:SourceFile):SourceFile {
		return visitor.VisitSourceFile(file);
	}
}
