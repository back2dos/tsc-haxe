package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/nodecopy.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.checker)
class RecoveryBoundary {
	var ctx:NodeBuilderContext = null;
	var hadError:Bool = false;
	var deferredReports:Array<() -> Void> = null;
	var oldTracker:SymbolTracker = null;
	var oldTrackedSymbols:Array<TrackedSymbolArgs> = null;
	var trackedSymbols:Array<TrackedSymbolArgs> = null;
	var oldEncounteredError:Bool = false;
	var oldApproximateLength:Int = 0;

	public function new() {}

	function markError(f:() -> Void):Void {
		this.hadError = true;
		if (f != null) {
			if (this.deferredReports == null) {
				this.deferredReports = [];
			}
			this.deferredReports.push(f);
		}
	}

	function startRecoveryScope():OriginalRecoveryScopeState {
		final trackedSymbolsTop = Core.len(this.ctx.trackedSymbols);
		final unreportedErrorsTop = Core.len(this.deferredReports);
		final s = new OriginalRecoveryScopeState();
		s.trackedSymbolsTop = trackedSymbolsTop;
		s.unreportedErrorsTop = unreportedErrorsTop;
		s.hadError = this.hadError;
		return s;
	}

	function endRecoveryScope(state:OriginalRecoveryScopeState):Void {
		this.hadError = state.hadError;
		// PORT: Go reslices s[0:top] (shares the backing array); truncating in place is equivalent here since
		// the elements past top are discarded. A nil slice stays nil (top is 0).
		if (this.ctx.trackedSymbols != null) {
			this.ctx.trackedSymbols.resize(state.trackedSymbolsTop);
		}
		if (this.deferredReports != null) {
			this.deferredReports.resize(state.unreportedErrorsTop);
		}
	}
}

@:allow(ts.checker)
class OriginalRecoveryScopeState {
	var trackedSymbolsTop:Int = 0;
	var unreportedErrorsTop:Int = 0;
	var hadError:Bool = false;

	public function new() {}
}

@:allow(ts.checker)
class WrappingTracker implements SymbolTracker {
	var wrapped:SymbolTracker = null;
	var bound:RecoveryBoundary = null;

	public function new() {}

	public function PopErrorFallbackNode():Void {
		this.wrapped.PopErrorFallbackNode();
	}

	public function PushErrorFallbackNode(node:Node):Void {
		this.wrapped.PushErrorFallbackNode(node);
	}

	public function ReportCyclicStructureError():Void {
		final wrapped = this.wrapped;
		this.bound.markError(() -> wrapped.ReportCyclicStructureError());
	}

	public function ReportInaccessibleThisError():Void {
		final wrapped = this.wrapped;
		this.bound.markError(() -> wrapped.ReportInaccessibleThisError());
	}

	public function ReportInaccessibleUniqueSymbolError():Void {
		final wrapped = this.wrapped;
		this.bound.markError(() -> wrapped.ReportInaccessibleUniqueSymbolError());
	}

	public function ReportInferenceFallback(node:Node):Void {
		this.wrapped.ReportInferenceFallback(node); // Should this also be deferred?
	}

	public function ReportLikelyUnsafeImportRequiredError(specifier:std.String, symbolName:std.String):Void {
		this.bound.markError(() -> this.wrapped.ReportLikelyUnsafeImportRequiredError(specifier, symbolName));
	}

	public function ReportNonSerializableProperty(propertyName:std.String):Void {
		this.bound.markError(() -> this.wrapped.ReportNonSerializableProperty(propertyName));
	}

	public function ReportNonlocalAugmentation(containingFile:SourceFile, parentSymbol:Symbol, augmentingSymbol:Symbol):Void {
		this.wrapped.ReportNonlocalAugmentation(containingFile, parentSymbol, augmentingSymbol); // Should this also be deferred?
	}

	public function ReportPrivateInBaseOfClassExpression(propertyName:std.String):Void {
		this.bound.markError(() -> this.wrapped.ReportPrivateInBaseOfClassExpression(propertyName));
	}

	public function ReportTruncationError():Void {
		this.wrapped.ReportTruncationError(); // Should this also be deferred?
	}

	public function TrackSymbol(symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags):Bool {
		final a = new TrackedSymbolArgs();
		a.symbol = symbol;
		a.enclosingDeclaration = enclosingDeclaration;
		a.meaning = meaning;
		if (this.bound.trackedSymbols == null) {
			this.bound.trackedSymbols = [];
		}
		this.bound.trackedSymbols.push(a);
		return false;
	}
}

// Methods of nodecopy.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Nodecopy {

	static function reuseNode(b:NodeBuilderImpl, node:Node):Node {
		if (node == null) {
			return node;
		}

		return b.tryReuseExistingNodeHelper(node);
	}

	static function tryJSTypeNodeToTypeNode(b:NodeBuilderImpl, node:Node):Node {
		return b.reuseNode(node);
	}

	static function reuseName(b:NodeBuilderImpl, node:Node, isMethod:Bool):Node {
		final res = b.reuseNode(node);
		if (res == null) {
			return res;
		}

		final r = Ast.TryGetTextOfPropertyName(res);
		final text = r.value;
		if (!r.ok) {
			return res;
		}

		final kind = Checker.classifyPropertyName(text, Ast.IsStringLiteral(res), isMethod);
		if (Ast.IsIdentifier(res) && kind == propertyNameNodeKindIdentifier) {
			return res;
		}
		if (Ast.IsStringLiteral(res) && kind == propertyNameNodeKindStringLiteral) {
			return res;
		}

		var renamed:Node = null;
		switch (kind) {
			case propertyNameNodeKindIdentifier:
				renamed = b.newIdentifier(text, null);
			case propertyNameNodeKindStringLiteral:
				renamed = b.f.NewStringLiteral(text, TokenFlagsNone);
			default:
				return res;
		}
		b.e.SetOriginal(renamed, res);
		return b.setTextRange(renamed, res);
	}

	static function reuseTypeNode(b:NodeBuilderImpl, node:Node):Node {
		if (node == null) {
			return node;
		}
		final r = b.reuseNode(node);
		if (r != null) {
			// After successful reuse during hover, probe the reused AST for expandable
			// type references so canIncreaseExpansionDepth is set even though
			// typeToTypeNode (and shouldExpandType) were never called.
			if (b.ctx.maxExpansionDepth >= 0 && !b.ctx.canIncreaseExpansionDepth) {
				b.walkNodeForExpandability(node);
			}
			return r;
		}
		b.ctx.tracker.ReportInferenceFallback(node);
		final t = b.getTypeFromTypeNode(node, false);
		return b.typeToTypeNode(t);
	}

	// walkNodeForExpandability walks a reused AST node tree, calling checkTypeExpandability
	// on each type reference, type predicate, or import type node.
	// Short-circuits once canIncreaseExpansionDepth is set.
	static function walkNodeForExpandability(b:NodeBuilderImpl, node:Node):Void {
		if (b.ctx.canIncreaseExpansionDepth || node == null) {
			return;
		}
		// Check these explicitly so we look into type arguments wehther or not they are in the tree or not.
		if (Ast.IsTypeReferenceNode(node) || Ast.IsExpressionWithTypeArguments(node) || Ast.IsTypePredicateNode(node) || Ast.IsImportTypeNode(node)) {
			final t = b.getTypeFromTypeNode(node, false);
			if (t != null) {
				b.checkTypeExpandability(t);
				if (b.ctx.canIncreaseExpansionDepth) {
					return;
				}
			}
		}
		node.ForEachChild((child:Node) -> {
			b.walkNodeForExpandability(child);
			return b.ctx.canIncreaseExpansionDepth;
		});
	}

	static function createRecoveryBoundary(b:NodeBuilderImpl):RecoveryBoundary {
		b.ch.checkNotCanceled();
		final bound = new RecoveryBoundary();
		bound.ctx = b.ctx;
		bound.oldTracker = b.ctx.tracker;
		bound.oldTrackedSymbols = b.ctx.trackedSymbols;
		bound.oldEncounteredError = b.ctx.encounteredError;
		bound.oldApproximateLength = b.ctx.approximateLength;
		final newTracker = Checker.NewSymbolTrackerImpl(b.ctx, Checker.newWrappingTracker(b.ctx.tracker, bound));
		b.ctx.tracker = newTracker;
		b.ctx.trackedSymbols = null;
		return bound;
	}

	static function finalizeBoundary(b:NodeBuilderImpl, bound:RecoveryBoundary):Bool {
		b.ctx.tracker = bound.oldTracker;
		b.ctx.trackedSymbols = bound.oldTrackedSymbols;
		b.ctx.encounteredError = bound.oldEncounteredError;
		b.ctx.approximateLength = bound.oldApproximateLength;

		if (bound.deferredReports != null) {
			for (f in bound.deferredReports) {
				f();
			}
		}
		if (bound.hadError) {
			return false;
		}
		if (bound.trackedSymbols != null) {
			for (a in bound.trackedSymbols) {
				b.ctx.tracker.TrackSymbol(a.symbol, a.enclosingDeclaration, a.meaning);
			}
		}
		return true;
	}

	static function tryReuseExistingNodeHelper(b:NodeBuilderImpl, existing:TypeNode):TypeNode {
		final bound = b.createRecoveryBoundary();
		var transformed:Node = null;
		final v = Checker.getExistingNodeTreeVisitor(b, bound); // !!! TODO: Cache visitor and just reset bound+host builder? We try this for a *lot* of nodes.
		transformed = v.VisitNode(existing);
		if (!b.finalizeBoundary(bound)) {
			return null;
		}
		b.ctx.approximateLength += existing.Loc.End() - existing.Loc.Pos();
		return transformed;
	}

	static function getModuleSpecifierOverride(b:NodeBuilderImpl, parent:Node, lit:Node):std.String {
		if (b.ctx.enclosingFile != Ast.GetSourceFileOfNode(lit)) {
			var mode = Core.ResolutionModeNone;
			if (parent.AsImportTypeNode().Attributes != null) {
				mode = b.ch.getResolutionModeOverride(parent.AsImportTypeNode().Attributes.AsImportAttributes(), false);
			}
			var name = lit.Text();
			final originalName = name;
			final nodeSymbol = b.tryGetResolvedSymbolFromTypeNode(parent);
			var meaning = SymbolFlagsType;
			if (parent.AsImportTypeNode().IsTypeOf) {
				meaning = SymbolFlagsValue;
			}
			var parentSymbol:Symbol = null;
			if (nodeSymbol != null && b.ch.IsSymbolAccessible(nodeSymbol, b.ctx.enclosingDeclaration, meaning, false).Accessibility == SymbolAccessibilityAccessible) {
				parentSymbol = b.lookupSymbolChain(nodeSymbol, meaning, true)[0];
			}
			if (parentSymbol != null && Checker.IsExternalModuleSymbol(parentSymbol)) {
				name = b.getSpecifierForModuleSymbol(parentSymbol, mode);
			} else {
				final targetFile = b.ch.getExternalModuleFileFromDeclaration(parent);
				if (targetFile != null) {
					name = b.getSpecifierForModuleSymbol(targetFile.Symbol, mode);
				}
			}
			if (name.length > 0 && name.indexOf("/node_modules/") >= 0) {
				b.ctx.encounteredError = true;
				b.ctx.tracker.ReportLikelyUnsafeImportRequiredError(name, "");
			}
			if (name != originalName) {
				return name;
			}
		}
		return "";
	}

	static function rewriteModuleSpecifier(b:NodeBuilderImpl, parent:Node, lit:Node):Node {
		final newName = b.getModuleSpecifierOverride(parent, lit);
		if (newName.length == 0) {
			return lit;
		}
		final res = b.f.NewStringLiteral(newName, TokenFlagsNone);
		b.e.SetOriginal(res, lit);
		return res;
	}

	static function getEnclosingDeclarationIgnoringFakeScope(b:NodeBuilderImpl):Node {
		var enc = b.ctx.enclosingDeclaration;
		while (enc != null && b.links.Get(enc).fakeScopeForSignatureDeclaration != null) {
			enc = enc.Parent;
		}
		return enc;
	}
}
