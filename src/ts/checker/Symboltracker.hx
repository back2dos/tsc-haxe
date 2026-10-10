package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/symboltracker.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.checker)
class SymbolTrackerImpl implements SymbolTracker {
	var context:NodeBuilderContext = null;
	var inner:SymbolTracker = null;
	public var DisableTrackSymbol:Bool = false;

	public function new() {}

	public function TrackSymbol(symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags):Bool {
		if (!this.DisableTrackSymbol) {
			if (this.inner != null && this.inner.TrackSymbol(symbol, enclosingDeclaration, meaning)) {
				this.onDiagnosticReported();
				return true;
			}
			// Skip recording type parameters as they dont contribute to late painted statements
			if (symbol.Flags & SymbolFlagsTypeParameter == 0) {
				final a = new TrackedSymbolArgs();
				a.symbol = symbol;
				a.enclosingDeclaration = enclosingDeclaration;
				a.meaning = meaning;
				if (this.context.trackedSymbols == null) {
					this.context.trackedSymbols = [];
				}
				this.context.trackedSymbols.push(a);
			}
		}
		return false;
	}

	public function ReportInaccessibleThisError():Void {
		this.onDiagnosticReported();
		if (this.inner == null) {
			return;
		}
		this.inner.ReportInaccessibleThisError();
	}

	public function ReportPrivateInBaseOfClassExpression(propertyName:std.String):Void {
		this.onDiagnosticReported();
		if (this.inner == null) {
			return;
		}
		this.inner.ReportPrivateInBaseOfClassExpression(propertyName);
	}

	public function ReportInaccessibleUniqueSymbolError():Void {
		this.onDiagnosticReported();
		if (this.inner == null) {
			return;
		}
		this.inner.ReportInaccessibleUniqueSymbolError();
	}

	public function ReportCyclicStructureError():Void {
		this.onDiagnosticReported();
		if (this.inner == null) {
			return;
		}
		this.inner.ReportCyclicStructureError();
	}

	public function ReportLikelyUnsafeImportRequiredError(specifier:std.String, symbolName:std.String):Void {
		this.onDiagnosticReported();
		if (this.inner == null) {
			return;
		}
		this.inner.ReportLikelyUnsafeImportRequiredError(specifier, symbolName);
	}

	public function ReportTruncationError():Void {
		this.onDiagnosticReported();
		if (this.inner == null) {
			return;
		}
		this.inner.ReportTruncationError();
	}

	public function ReportNonlocalAugmentation(containingFile:SourceFile, parentSymbol:Symbol, augmentingSymbol:Symbol):Void {
		this.onDiagnosticReported();
		if (this.inner == null) {
			return;
		}
		this.inner.ReportNonlocalAugmentation(containingFile, parentSymbol, augmentingSymbol);
	}

	public function ReportNonSerializableProperty(propertyName:std.String):Void {
		this.onDiagnosticReported();
		if (this.inner == null) {
			return;
		}
		this.inner.ReportNonSerializableProperty(propertyName);
	}

	function onDiagnosticReported():Void {
		this.context.reportedDiagnostic = true;
	}

	public function ReportInferenceFallback(node:Node):Void {
		if (this.inner == null) {
			return;
		}
		this.inner.ReportInferenceFallback(node);
	}

	public function PushErrorFallbackNode(node:Node):Void {
		if (this.inner == null) {
			return;
		}
		this.inner.PushErrorFallbackNode(node);
	}

	public function PopErrorFallbackNode():Void {
		if (this.inner == null) {
			return;
		}
		this.inner.PopErrorFallbackNode();
	}
}

