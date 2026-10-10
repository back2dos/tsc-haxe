package ts.transformers.declarations;

// GENERATED SKELETON by tools/gen/skeleton from internal/transformers/declarations/tracker.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.transformers.declarations)
class SymbolTrackerImpl implements ts.nodebuilder.Types.SymbolTracker { // PORT: Go satisfies checker.SymbolTracker structurally
	var resolver:EmitResolver = null;
	var state:SymbolTrackerSharedState = null;
	var host:DeclarationEmitHost = null;
	var fallbackStack:Array<Node> = null;
	// For detecting class expression self-references during member serialization.
	// When set, TrackSymbol will record usage without reporting accessibility errors.
	var watchedClassSymbol:Symbol = null;
	var classSymbolTracked:Bool = false;
	var getIsolatedDeclarationError:(node:Node) -> Diagnostic = null;

	public function new() {}

	// PopErrorFallbackNode implements checker.SymbolTracker.
	public function PopErrorFallbackNode():Void {
		fallbackStack.resize(fallbackStack.length - 1); // PORT: Go reslice s[:len(s)-1]
	}

	// PushErrorFallbackNode implements checker.SymbolTracker.
	public function PushErrorFallbackNode(node:Node):Void {
		if (fallbackStack == null) { // PORT: Go append to a nil slice
			fallbackStack = [];
		}
		fallbackStack.push(node);
	}

	// ReportCyclicStructureError implements checker.SymbolTracker.
	public function ReportCyclicStructureError():Void {
		final location = errorLocation();
		if (location != null) {
			state.addDiagnostic(Declarations.createDiagnosticForNode(location, Diagnostics.The_inferred_type_of_0_references_a_type_with_a_cyclic_structure_which_cannot_be_trivially_serialized_A_type_annotation_is_necessary, errorDeclarationNameWithFallback()));
		}
	}

	// ReportInaccessibleThisError implements checker.SymbolTracker.
	public function ReportInaccessibleThisError():Void {
		final location = errorLocation();
		if (location != null) {
			state.addDiagnostic(Declarations.createDiagnosticForNode(location, Diagnostics.The_inferred_type_of_0_references_an_inaccessible_1_type_A_type_annotation_is_necessary, errorDeclarationNameWithFallback(), "this"));
		}
	}

	// ReportInaccessibleUniqueSymbolError implements checker.SymbolTracker.
	public function ReportInaccessibleUniqueSymbolError():Void {
		final location = errorLocation();
		if (location != null) {
			state.addDiagnostic(Declarations.createDiagnosticForNode(location, Diagnostics.The_inferred_type_of_0_references_an_inaccessible_1_type_A_type_annotation_is_necessary, errorDeclarationNameWithFallback(), "unique symbol"));
		}
	}

	function isBoundExpando(node:Node):Bool {
		if (!(Ast.IsExpandoPropertyDeclaration(node) && Ast.IsPropertyAccessExpression(node.AsBinaryExpression().Left))) {
			return false;
		}
		final ref = resolver.GetReferencedValueDeclarationUnsafe(Ast.GetLeftmostExpression(node.AsBinaryExpression().Left, true));
		if (ref == null) {
			return false;
		}
		return resolver.IsExpandoFunctionDeclarationUnsafe(ref);
	}

	function isChildOfBoundExpando(node:Node):Bool {
		return Ast.FindAncestorOrQuit(node, function(n:Node):FindAncestorResult {
			if (Ast.IsSourceFile(n) || Ast.IsBlock(n)) {
				return FindAncestorQuit;
			}
			return Ast.ToFindAncestorResult(isBoundExpando(n));
		}) != null;
	}

	// ReportInferenceFallback implements checker.SymbolTracker.
	public function ReportInferenceFallback(node:Node):Void {
		if (!state.isolatedDeclarations) {
			return;
		}
		if (Ast.GetSourceFileOfNode(node) != state.currentSourceFile) {
			return; // Nested error on a declaration in another file - ignore, will be reemitted if file is in the output file set
		}
		if (state.resolver.IsExpandoFunctionDeclarationUnsafe(node)) { // within a node builder call that should already lock the checker, use the unsafe call
			state.reportExpandoFunctionErrors(node);
		}
		if (!isChildOfBoundExpando(node)) { // expando props get an error when their host is visited by the above, this prevents a follow-on error on a non-inferrable expression
			state.addDiagnostic(getIsolatedDeclarationError(node));
		}
	}

	// ReportLikelyUnsafeImportRequiredError implements checker.SymbolTracker.
	public function ReportLikelyUnsafeImportRequiredError(specifier:std.String, symbolName:std.String):Void {
		final location = errorLocation();
		if (location != null) {
			if (symbolName != "") {
				state.addDiagnostic(Declarations.createDiagnosticForNode(location, Diagnostics.The_inferred_type_of_0_cannot_be_named_without_a_reference_to_2_from_1_This_is_likely_not_portable_A_type_annotation_is_necessary, errorDeclarationNameWithFallback(), specifier, symbolName));
			} else {
				state.addDiagnostic(Declarations.createDiagnosticForNode(location, Diagnostics.The_inferred_type_of_0_cannot_be_named_without_a_reference_to_1_This_is_likely_not_portable_A_type_annotation_is_necessary, errorDeclarationNameWithFallback(), specifier));
			}
		}
	}

	// ReportNonSerializableProperty implements checker.SymbolTracker.
	public function ReportNonSerializableProperty(propertyName:std.String):Void {
		final location = errorLocation();
		if (location != null) {
			state.addDiagnostic(Declarations.createDiagnosticForNode(location, Diagnostics.The_type_of_this_node_cannot_be_serialized_because_its_property_0_cannot_be_serialized, propertyName));
		}
	}

	// ReportNonlocalAugmentation implements checker.SymbolTracker.
	public function ReportNonlocalAugmentation(containingFile:SourceFile, parentSymbol:Symbol, augmentingSymbol:Symbol):Void {
		final primaryDeclaration = Core.Find(parentSymbol.Declarations, function(d:Node):Bool {
			return Ast.GetSourceFileOfNode(d) == containingFile;
		});
		final augmentingDeclarations = Core.Filter(augmentingSymbol.Declarations, function(d:Node):Bool {
			return Ast.GetSourceFileOfNode(d) != containingFile;
		});
		if (primaryDeclaration != null && Core.len(augmentingDeclarations) > 0) {
			for (augmentations in augmentingDeclarations) {
				final diag = Declarations.createDiagnosticForNode(augmentations, Diagnostics.Declaration_augments_declaration_in_another_file_This_cannot_be_serialized);
				final related = Declarations.createDiagnosticForNode(primaryDeclaration, Diagnostics.This_is_the_declaration_being_augmented_Consider_moving_the_augmenting_declaration_into_the_same_file);
				diag.AddRelatedInfo(related);
				state.addDiagnostic(diag);
			}
		}
	}

	// ReportPrivateInBaseOfClassExpression implements checker.SymbolTracker.
	public function ReportPrivateInBaseOfClassExpression(propertyName:std.String):Void {
		final location = errorLocation();
		if (location != null) {
			final diag = Declarations.createDiagnosticForNode(location, Diagnostics.Property_0_of_exported_anonymous_class_type_may_not_be_private_or_protected, propertyName);
			if (Ast.IsVariableDeclaration(location.Parent)) {
				final related = Declarations.createDiagnosticForNode(location, Diagnostics.Add_a_type_annotation_to_the_variable_0, errorDeclarationNameWithFallback());
				diag.AddRelatedInfo(related);
			}
			state.addDiagnostic(diag);
		}
	}

	// ReportTruncationError implements checker.SymbolTracker.
	public function ReportTruncationError():Void {
		final location = errorLocation();
		if (location != null) {
			state.addDiagnostic(Declarations.createDiagnosticForNode(location, Diagnostics.The_inferred_type_of_this_node_exceeds_the_maximum_length_the_compiler_will_serialize_An_explicit_type_annotation_is_needed));
		}
	}

	function errorFallbackNode():Node {
		if (Core.len(fallbackStack) >= 1) {
			return fallbackStack[fallbackStack.length - 1];
		}
		return null;
	}

	function errorLocation():Node {
		var location = state.errorNameNode;
		if (location == null) {
			location = errorFallbackNode();
		}
		return location;
	}

	function errorDeclarationNameWithFallback():std.String {
		if (state.errorNameNode != null) {
			return Scanner.DeclarationNameToString(state.errorNameNode);
		}
		if (errorFallbackNode() != null && Ast.GetNameOfDeclaration(errorFallbackNode()) != null) {
			return Scanner.DeclarationNameToString(Ast.GetNameOfDeclaration(errorFallbackNode()));
		}
		if (errorFallbackNode() != null && Ast.IsExportAssignment(errorFallbackNode())) {
			if (errorFallbackNode().AsExportAssignment().IsExportEquals) {
				return "export=";
			}
			return "default";
		}
		return "(Missing)"; // same fallback declarationNameToString uses when node is zero-width (ie, nameless)
	}

	// TrackSymbol implements checker.SymbolTracker.
	public function TrackSymbol(symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags):Bool {
		if ((symbol.Flags & SymbolFlagsTypeParameter) != 0) {
			return false;
		}
		// When watching for a class expression symbol, record its usage without
		// reporting accessibility errors — the caller will handle visibility by
		// wrapping the class in a namespace.
		if (watchedClassSymbol != null && symbol == watchedClassSymbol) {
			classSymbolTracked = true;
			return false;
		}
		final issuedDiagnostic = handleSymbolAccessibilityError(resolver.IsSymbolAccessible(symbol, enclosingDeclaration, meaning /*shouldComputeAliasToMarkVisible*/, true));
		return issuedDiagnostic;
	}

	function handleSymbolAccessibilityError(symbolAccessibilityResult:SymbolAccessibilityResult):Bool {
		if (symbolAccessibilityResult.Accessibility == SymbolAccessibilityAccessible) {
			// Add aliases back onto the possible imports list if they're not there so we can try them again with updated visibility info
			if (Core.len(symbolAccessibilityResult.AliasesToMakeVisible) > 0) {
				for (ref in symbolAccessibilityResult.AliasesToMakeVisible) {
					state.lateMarkedStatements = Core.AppendIfUnique(state.lateMarkedStatements, ref);
				}
			}
			// TODO: Do all these accessibility checks inside/after the first pass in the checker when declarations are enabled, if possible

			// The checker should issue errors on unresolvable names, skip the declaration emit error for using a private/unreachable name for those
		} else if (symbolAccessibilityResult.Accessibility != SymbolAccessibilityNotResolved) {
			// Report error
			final errorInfo = state.getSymbolAccessibilityDiagnostic(symbolAccessibilityResult);
			if (errorInfo != null) {
				final info = errorInfo; // PORT: Go copies the struct (*errorInfo); it is only read here
				var diagNode = symbolAccessibilityResult.ErrorNode;
				if (diagNode == null) {
					diagNode = errorInfo.errorNode;
				}
				if (info.typeName != null) {
					state.addDiagnostic(Declarations.createDiagnosticForNode(diagNode, info.diagnosticMessage, Scanner.GetTextOfNode(info.typeName), symbolAccessibilityResult.ErrorSymbolName, symbolAccessibilityResult.ErrorModuleName));
				} else {
					state.addDiagnostic(Declarations.createDiagnosticForNode(diagNode, info.diagnosticMessage, symbolAccessibilityResult.ErrorSymbolName, symbolAccessibilityResult.ErrorModuleName));
				}
				return true;
			}
		}
		return false;
	}
}

@:allow(ts.transformers.declarations)
class SymbolTrackerSharedState {
	var lateMarkedStatements:Array<Node> = null;
	var diagnostics:Array<Diagnostic> = null;
	var getSymbolAccessibilityDiagnostic:GetSymbolAccessibilityDiagnostic = null;
	var errorNameNode:Node = null;
	var isolatedDeclarations:Bool = false;
	var stripInternal:Bool = false;
	var currentSourceFile:SourceFile = null;
	var resolver:EmitResolver = null;
	var reportExpandoFunctionErrors:(node:Node) -> Void = null;

	public function new() {}

	function addDiagnostic(diag:Diagnostic):Void {
		if (diagnostics == null) { // PORT: Go append to a nil slice
			diagnostics = [];
		}
		diagnostics.push(diag);
	}
}

