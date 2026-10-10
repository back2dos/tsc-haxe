package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/nodebuilder.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.checker)
class NodeBuilder {
	var ctxStack:Array<NodeBuilderContext> = null;
	var host:Host = null;
	var impl:NodeBuilderImpl = null;
	var verbosity:VerbosityContext = null; // nil for non-hover callers

	public function new() {}

	// EmitContext implements NodeBuilderInterface.
	public function EmitContext():EmitContext {
		return this.impl.e;
	}

	function enterContext(enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Void {
		var verbosityLevel = -1;
		var maxTruncationLength = 0;
		if (this.verbosity != null) {
			verbosityLevel = this.verbosity.Level;
			maxTruncationLength = this.verbosity.MaxTruncationLength;
		}
		this.ctxStack.push(this.impl.ctx);
		final ctx = new NodeBuilderContext();
		ctx.host = this.host;
		ctx.tracker = tracker;
		ctx.flags = flags;
		ctx.internalFlags = internalFlags;
		ctx.maxExpansionDepth = verbosityLevel;
		ctx.maxTruncationLength = maxTruncationLength;
		ctx.enclosingDeclaration = enclosingDeclaration;
		ctx.enclosingFile = Ast.GetSourceFileOfNode(enclosingDeclaration);
		ctx.inferTypeParameters = [];
		ctx.symbolDepth = new StringMap<Int>();
		ctx.trackedSymbols = [];
		ctx.reverseMappedStack = [];
		ctx.enclosingSymbolTypes = new IntMap<Type>();
		ctx.remappedSymbolReferences = new IntMap<Symbol>();
		this.impl.ctx = ctx;
		tracker = Checker.NewSymbolTrackerImpl(this.impl.ctx, tracker);
		this.impl.ctx.tracker = tracker;
	}

	// propagateVerbosityOut copies expansion signals from the context to the VerbosityContext output.
	function propagateVerbosityOut():Void {
		if (this.verbosity != null) {
			// Only set to true, never clear — multiple calls share the same VerbosityContext
			if (this.impl.ctx.canIncreaseExpansionDepth) {
				this.verbosity.CanIncreaseVerbosity = true;
			}
			if (this.impl.ctx.expansionTruncated) {
				this.verbosity.Truncated = true;
			}
		}
	}

	function popContext():Void {
		final stackSize = this.ctxStack.length;
		if (stackSize == 0) {
			this.impl.ctx = null;
		} else {
			this.impl.ctx = this.ctxStack[stackSize - 1];
			this.ctxStack.resize(stackSize - 1);
		}
	}

	function exitContext(result:Node):Node {
		this.propagateVerbosityOut();
		this.exitContextCheck();
		// PORT: defer b.popContext() written at each return
		if (this.impl.ctx.encounteredError) {
			this.popContext();
			return null;
		}
		this.popContext();
		return result;
	}

	function exitContextSlice(result:Array<Node>):Array<Node> {
		this.propagateVerbosityOut();
		this.exitContextCheck();
		// PORT: defer b.popContext() written at each return
		if (this.impl.ctx.encounteredError) {
			this.popContext();
			return null;
		}
		this.popContext();
		return result;
	}

	function exitContextCheck():Void {
		if (this.impl.ctx.truncating && this.impl.ctx.flags & FlagsNoTruncation != 0) {
			this.impl.ctx.tracker.ReportTruncationError();
		}
	}

	// IndexInfoToIndexSignatureDeclaration implements NodeBuilderInterface.
	public function IndexInfoToIndexSignatureDeclaration(info:IndexInfo, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContext(this.impl.indexInfoToIndexSignatureDeclarationHelper(info, null));
	}

	// SerializeReturnTypeForSignature implements NodeBuilderInterface.
	public function SerializeReturnTypeForSignature(signatureDeclaration:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		final signature = this.impl.ch.getSignatureFromDeclaration(signatureDeclaration);
		final cleanup = this.impl.enterSignatureScope(signature).b;
		final result = this.impl.serializeReturnTypeForSignature(signature, true);
		cleanup();
		return this.exitContext(result);
	}

	public function SerializeTypeParametersForSignature(signatureDeclaration:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Array<Node> {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		final symbol = this.impl.ch.getSymbolOfDeclaration(signatureDeclaration);
		final typeParams = this.SymbolToTypeParameterDeclarations(symbol, enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContextSlice(typeParams);
	}

	// SerializeTypeForDeclaration implements NodeBuilderInterface.
	public function SerializeTypeForDeclaration(declaration:Node, symbol:Symbol, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContext(this.impl.serializeTypeForDeclaration(declaration, null, symbol, true));
	}

	// SerializeTypeForExpression implements NodeBuilderInterface.
	public function SerializeTypeForExpression(expr:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContext(this.impl.serializeTypeForExpression(expr));
	}

	// SignatureToSignatureDeclaration implements NodeBuilderInterface.
	public function SignatureToSignatureDeclaration(signature:Signature, kind:Kind, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContext(this.impl.signatureToSignatureDeclarationHelper(signature, kind, null));
	}

	// ExpandSymbolForHover produces declaration nodes for a symbol with verbosity level support.
	public function ExpandSymbolForHover(symbol:Symbol, meaning:SymbolFlags):Array<Node> {
		this.enterContext(null, FlagsIgnoreErrors | FlagsMultilineObjectLiterals | FlagsUseAliasDefinedOutsideCurrentScope, InternalFlagsNone, null);

		// Push the declared type onto the type stack to prevent re-expansion.
		// We push a nil sentinel after the real type so that isTypeOnStack
		// (which skips the last element) still checks declaredType.
		final declaredType = this.impl.ch.getDeclaredTypeOfSymbol(symbol);
		if (this.impl.ctx.typeStack == null) {
			this.impl.ctx.typeStack = [];
		}
		this.impl.ctx.typeStack.push(declaredType);
		this.impl.ctx.typeStack.push(null);

		final nodes = this.impl.expandSymbolForHover(symbol);

		this.impl.ctx.typeStack.resize(this.impl.ctx.typeStack.length - 2);

		this.propagateVerbosityOut();

		// Simplify declarations by applying original modifiers
		final result:Array<Node> = [];
		if (nodes != null) {
			for (node in nodes) {
				switch (node.Kind) {
					case KindClassDeclaration:
						result.push(Checker.simplifyClassDeclaration(this.impl.f, node, symbol));
					case KindEnumDeclaration:
						result.push(Checker.simplifyModifiers(this.impl.f, node, n -> Ast.IsEnumDeclaration(n), symbol));
					case KindInterfaceDeclaration:
						if (meaning & SymbolFlagsInterface != 0) {
							result.push(Checker.simplifyModifiers(this.impl.f, node, n -> Ast.IsInterfaceDeclaration(n), symbol));
						}
					case KindModuleDeclaration:
						result.push(Checker.simplifyModifiers(this.impl.f, node, n -> Ast.IsModuleDeclaration(n), symbol));
					default:
				}
			}
		}

		return this.exitContextSlice(result);
	}

	// SymbolToEntityName implements NodeBuilderInterface.
	public function SymbolToEntityName(symbol:Symbol, meaning:SymbolFlags, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContext(this.impl.symbolToName(symbol, meaning, false));
	}

	// SymbolToExpression implements NodeBuilderInterface.
	public function SymbolToExpression(symbol:Symbol, meaning:SymbolFlags, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContext(this.impl.symbolToExpression(symbol, meaning));
	}

	// SymbolToNode implements NodeBuilderInterface.
	public function SymbolToNode(symbol:Symbol, meaning:SymbolFlags, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContext(this.impl.symbolToNode(symbol, meaning));
	}

	// SymbolToParameterDeclaration implements NodeBuilderInterface.
	public function SymbolToParameterDeclaration(symbol:Symbol, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContext(this.impl.symbolToParameterDeclaration(symbol, false));
	}

	// SymbolToTypeParameterDeclarations implements NodeBuilderInterface.
	public function SymbolToTypeParameterDeclarations(symbol:Symbol, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Array<Node> {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContextSlice(this.impl.symbolToTypeParameterDeclarations(symbol));
	}

	// TypeParameterToDeclaration implements NodeBuilderInterface.
	public function TypeParameterToDeclaration(parameter:Type, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContext(this.impl.typeParameterToDeclaration(parameter));
	}

	// TypePredicateToTypePredicateNode implements NodeBuilderInterface.
	public function TypePredicateToTypePredicateNode(predicate:TypePredicate, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContext(this.impl.typePredicateToTypePredicateNode(predicate));
	}

	// TypeToTypeNode implements NodeBuilderInterface.
	public function TypeToTypeNode(typ:Type, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContext(this.impl.typeToTypeNode(typ));
	}

	public function TryJSTypeNodeToTypeNode(node:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags, tracker:SymbolTracker):Node {
		this.enterContext(enclosingDeclaration, flags, internalFlags, tracker);
		return this.exitContext(this.impl.tryJSTypeNodeToTypeNode(node));
	}
}

// VerbosityContext controls hover-expansion behavior in the node builder.
// A nil VerbosityContext means no expansion (non-hover callers).
// Level 0 = default hover (maxExpansionDepth = 0; detects expandability without expanding).
// Level 1+ = expansion enabled (maxExpansionDepth = Level).
class VerbosityContext {
	public var Level:Int = 0; // 0 = default (no expansion), 1+ = expansion depth
	public var MaxTruncationLength:Int = 0; // 0 = use default
	public var CanIncreaseVerbosity:Bool = false; // output: whether increasing Level would reveal more
	public var Truncated:Bool = false; // output: whether output was truncated

	public function new() {}
}

// Methods of nodebuilder.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Nodebuilder_ {

	static function getNodeBuilder(c:Checker):Pair<NodeBuilder, () -> Void> {
		final releaseNodes = () -> {
			c.typeToStringNodebuilder.EmitContext().Factory.ReleaseArenas(); // Allow any allocated nodes to be freed if they're no longer in a cache
		};
		if (c.typeToStringNodebuilder != null) {
			return new Pair<NodeBuilder, () -> Void>(c.typeToStringNodebuilder, releaseNodes);
		}
		c.typeToStringNodebuilder = c.getNodeBuilderEx(null /*idToSymbol*/);
		return new Pair<NodeBuilder, () -> Void>(c.typeToStringNodebuilder, releaseNodes);
	}

	static function getNodeBuilderEx(c:Checker, idToSymbol:IdentityMap<IdentifierNode, Symbol>):NodeBuilder {
		final b = Checker.NewNodeBuilderEx(c, Printer.NewEmitContext(), idToSymbol);
		return b;
	}
}
