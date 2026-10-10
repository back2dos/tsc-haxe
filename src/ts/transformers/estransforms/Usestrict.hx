package ts.transformers.estransforms;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/estransforms/usestrict.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.estransforms)
class UseStrictTransformer {
	public var Transformer:Transformer = new Transformer(); // Go: embedded
	var compilerOptions:CompilerOptions = null;
	var getEmitModuleFormatOfFile:(file:HasFileName) -> ModuleKind = null;

	public function new() {}

	// PORT: promoted methods of the embedded transformers.Transformer.
	inline function Visitor():NodeVisitor return Transformer.Visitor();
	inline function Factory():ts.printer.Factory.NodeFactory return Transformer.Factory();
	inline function EmitContext():EmitContext return Transformer.EmitContext();

	function visit(node:Node):Node {
		if (node.Kind != KindSourceFile) {
			return node;
		}
		return visitSourceFile(node.AsSourceFile());
	}

	function visitSourceFile(node:SourceFile):Node {
		if (node.ScriptKind == ScriptKindJSON) {
			return node.AsNode();
		}

		final isExternalModule = Ast.IsExternalModule(node);
		final moduleKind = compilerOptions.GetEmitModuleKind();
		final format = getEmitModuleFormatOfFile(ts.modulespecifiers.Types.SourceFileAdapter.Of(node)); // PORT: SourceFile as ast.HasFileName via the cached adapter

		// ESM is always strict. If the file is ESM, and CJS emit
		// has not been requested, then skip adding "use strict".
		if (isExternalModule && moduleKind >= ModuleKindES2015 && (moduleKind == ModuleKindPreserve || format >= ModuleKindES2015)) {
			return node.AsNode();
		}

		final statements = Factory().EnsureUseStrict(node.Statements.Nodes);
		final statementList = Factory().NewNodeList(statements);
		statementList.Loc = node.Statements.Loc;
		return Factory().UpdateSourceFile(node, statementList, node.EndOfFileToken).AsSourceFile().AsNode();
	}
}
