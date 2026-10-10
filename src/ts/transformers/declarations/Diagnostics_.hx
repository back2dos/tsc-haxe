package ts.transformers.declarations;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/declarations/diagnostics.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

typedef GetSymbolAccessibilityDiagnostic = (symbolAccessibilityResult:SymbolAccessibilityResult) -> SymbolAccessibilityDiagnostic;

@:allow(ts.transformers.declarations)
class SymbolAccessibilityDiagnostic {
	var errorNode:Node = null;
	var diagnosticMessage:Message = null;
	var typeName:Node = null;

	public function new() {}
}

