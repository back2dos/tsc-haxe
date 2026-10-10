package ts.transformers.moduletransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/moduletransforms/impliedmodule.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.moduletransforms)
class ImpliedModuleTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var opts:TransformOptions = null;
	var resolver:ReferenceResolver = null;
	var getEmitModuleFormatOfFile:(file:HasFileName) -> ModuleKind = null;
	var cjsTransformer:Transformer = null;
	var esmTransformer:Transformer = null;

	public function new() {}

	function visit(node:Node):Node {
		switch (node.Kind) {
			case KindSourceFile:
				node = visitSourceFile(node.AsSourceFile());
			default:
		}
		return node;
	}

	function visitSourceFile(node:SourceFile):Node {
		if (node.IsDeclarationFile) {
			return node.AsNode();
		}

		final format = getEmitModuleFormatOfFile(ts.modulespecifiers.Types.SourceFileAdapter.Of(node)); // PORT: SourceFile as ast.HasFileName (adapter)

		var transformer:ts.transformers.Transformer = null;
		if (format >= ModuleKindES2015) {
			if (esmTransformer == null) {
				esmTransformer = Moduletransforms.NewESModuleTransformer(opts);
			}
			transformer = esmTransformer;
		} else {
			if (cjsTransformer == null) {
				cjsTransformer = Moduletransforms.NewCommonJSModuleTransformer(opts);
			}
			transformer = cjsTransformer;
		}

		return transformer.TransformSourceFile(node).AsNode();
	}
}
