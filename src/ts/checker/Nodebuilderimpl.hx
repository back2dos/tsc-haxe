package ts.checker;

// GENERATED SKELETON by tools/gen/skeleton from internal/checker/nodebuilderimpl.go (upstream v7.0.2).
// Types, fields and signatures only: port the bodies by hand (docs/PORTING.md).

@:allow(ts.checker)
class CompositeSymbolIdentity {
	var isConstructorNode:Bool = false;
	var symbolId:SymbolId = 0;
	var nodeId:NodeId = 0;

	public function new() {}
}

@:allow(ts.checker)
class TrackedSymbolArgs {
	var symbol:Symbol = null;
	var enclosingDeclaration:Node = null;
	var meaning:SymbolFlags = 0;

	public function new() {}
}

@:allow(ts.checker)
class SerializedTypeEntry {
	var node:Node = null;
	var truncating:Bool = false;
	var addedLength:Int = 0;
	var trackedSymbols:Array<TrackedSymbolArgs> = null;

	public function new() {}
}

@:allow(ts.checker)
class CompositeTypeCacheIdentity {
	var typeId:TypeId = 0;
	var flags:Flags = 0;
	var internalFlags:InternalFlags = 0;

	public function new() {}
}

@:allow(ts.checker)
class NodeBuilderLinks {
	var serializedTypes:StringMap<SerializedTypeEntry> /* key: checker.CompositeTypeCacheIdentity */ = null; // Collection of types serialized at this location
	var fakeScopeForSignatureDeclaration:Null<std.String> /* PORT: pointer */ = null; // If present, this is a fake scope injected into an enclosing declaration chain.

	public function new() {}
}

@:allow(ts.checker)
class NodeBuilderSymbolLinks {
	var specifierCache:ModeAwareCache<std.String> = null;

	public function new() {}
}

@:allow(ts.checker)
class NodeBuilderContext {
	var host:Host = null;
	var tracker:SymbolTracker = null;
	var approximateLength:Int = 0;
	var maxTruncationLength:Int = 0;
	var encounteredError:Bool = false;
	var truncating:Bool = false;
	var reportedDiagnostic:Bool = false;
	var flags:Flags = 0;
	var internalFlags:InternalFlags = 0;
	var depth:Int = 0;
	var maxExpansionDepth:Int = 0; // -1 means no expansion, 0+ = verbosity levels
	var typeStack:Array<Type> = null;
	var canIncreaseExpansionDepth:Bool = false;
	var expansionTruncated:Bool = false;
	var enclosingDeclaration:Node = null;
	var enclosingFile:SourceFile = null;
	var inferTypeParameters:Array<Type> = null;
	var visitedTypes:Set<TypeId> = new Set<TypeId>();
	var symbolDepth:StringMap<Int> /* key: checker.CompositeSymbolIdentity */ = null;
	var trackedSymbols:Array<TrackedSymbolArgs> = null;
	var mapper:TypeMapper = null;
	var reverseMappedStack:Array<Symbol> = null;
	var enclosingSymbolTypes:IntMap<Type> = null;
	var suppressReportInferenceFallback:Bool = false;
	var remappedSymbolReferences:IntMap<Symbol> = null;
	// per signature scope state
	var typeParameterNames:CopyOnWriteMap<TypeId, Identifier> = new CopyOnWriteMap<TypeId, Identifier>();
	var typeParameterNamesByText:CopyOnWriteSet<std.String> = new CopyOnWriteSet<std.String>();
	var typeParameterNamesByTextNextNameCount:CopyOnWriteMap<std.String, Int> = new CopyOnWriteMap<std.String, Int>();
	var typeParameterSymbolList:CopyOnWriteSet<SymbolId> = new CopyOnWriteSet<SymbolId>();

	public function new() {}
}

@:allow(ts.checker)
class NodeBuilderImpl {
	// host members
	var f:NodeFactory = null;
	var ch:Checker = null;
	var e:EmitContext = null;
	var pc:PseudoChecker = null;
	// cache
	var links:LinkStore<Node, NodeBuilderLinks> = new LinkStore<Node, NodeBuilderLinks>(() -> new NodeBuilderLinks());
	var symbolLinks:LinkStore<Symbol, NodeBuilderSymbolLinks> = new LinkStore<Symbol, NodeBuilderSymbolLinks>(() -> new NodeBuilderSymbolLinks());
	// state
	var ctx:NodeBuilderContext = null;
	// reusable visitor
	var cloneBindingNameVisitor:NodeVisitor = null;
	// symbols for synthesized identifiers, needed for e.g. inlay hints
	var idToSymbol:ObjectMap<IdentifierNode, Symbol> = null;

	public function new() {}

	function saveRestoreFlags():() -> Void {
		final flags = this.ctx.flags;
		final internalFlags = this.ctx.internalFlags;
		final depth = this.ctx.depth;

		return () -> {
			this.ctx.flags = flags;
			this.ctx.internalFlags = internalFlags;
			this.ctx.depth = depth;
		};
	}

	function checkTruncationLength():Bool {
		if (this.ctx.truncating) {
			return this.ctx.truncating;
		}
		var maxLength:Int = 0;
		if (this.ctx.flags & FlagsNoTruncation != 0) {
			maxLength = Checker.noTruncationMaximumTruncationLength;
		} else if (this.ctx.maxTruncationLength > 0) {
			maxLength = this.ctx.maxTruncationLength;
		} else {
			maxLength = Checker.defaultMaximumTruncationLength;
		}
		this.ctx.truncating = this.ctx.approximateLength > maxLength;
		return this.ctx.truncating;
	}

	// checkTruncationLengthIfExpanding returns true if maxExpansionDepth >= 0 and truncation length exceeded.
	// When expanding, we need to mark the output as truncated so we know not to offer further expansion.
	function checkTruncationLengthIfExpanding():Bool {
		if (this.ctx.maxExpansionDepth >= 0 && this.checkTruncationLength()) {
			this.ctx.expansionTruncated = true;
			return true;
		}
		return false;
	}

	// isExpandableType reports whether t has a named representation that could be inlined
	// as its structural form during hover expansion. Filters out lib types.
	// When isAlias is true, checks whether t's alias symbol is from user code (not lib).
	function isExpandableType(t:Type, isAlias:Bool):Bool {
		if (isAlias) {
			return !this.ch.IsLibSymbolForHoverVerbosity(t.alias.Symbol());
		}
		if (this.ch.IsLibTypeForHoverVerbosity(t)) {
			return false;
		}
		final objectFlags = t.objectFlags;
		if (t.flags & TypeFlagsEnumLike != 0 || objectFlags & ObjectFlagsReference != 0 || objectFlags & ObjectFlagsClassOrInterface != 0) {
			return true;
		}
		if (objectFlags & ObjectFlagsAnonymous != 0 && t.symbol != null
			&& t.symbol.Flags & (SymbolFlagsClass | SymbolFlagsEnum | SymbolFlagsValueModule | SymbolFlagsFunction | SymbolFlagsMethod) != 0) {
			return true;
		}
		return false;
	}

	// isTypeOnStack reports whether t is already being processed in the current expansion,
	// excluding the last element (which is the type currently being serialized by typeToTypeNode).
	function isTypeOnStack(t:Type):Bool {
		for (i in 0...(Core.len(this.ctx.typeStack) - 1)) {
			if (this.ctx.typeStack[i] == t) {
				return true;
			}
		}
		return false;
	}

	// shouldExpandType decides whether to expand this type at the current depth.
	// Returns true when depth < maxExpansionDepth (expand now).
	// At the boundary (depth == maxExpansionDepth), sets canIncreaseExpansionDepth
	// to signal that a higher verbosity level would reveal more detail.
	// Returns false when expansion is disabled (maxExpansionDepth < 0), the type
	// is not expandable, or the type is cyclic.
	function shouldExpandType(t:Type, isAlias:Bool):Bool {
		if (this.ctx.maxExpansionDepth < 0) {
			return false;
		}
		if (!this.isExpandableType(t, isAlias)) {
			return false;
		}
		if (this.isTypeOnStack(t)) {
			return false;
		}
		if (this.ctx.depth < this.ctx.maxExpansionDepth) {
			return true;
		}
		this.ctx.canIncreaseExpansionDepth = true;
		return false;
	}

	// isActivelyExpanding reports whether the current depth is below maxExpansionDepth,
	// meaning type-node reuse should be skipped so typeToTypeNode can expand named types.
	function isActivelyExpanding():Bool {
		return this.ctx.maxExpansionDepth > 0 && this.ctx.depth < this.ctx.maxExpansionDepth;
	}

	// checkTypeExpandability probes whether a type (or its type arguments) could be expanded,
	// for use after type-node reuse where shouldExpandType was never called.
	// Delegates to shouldExpandType for the actual check, then recurses into type arguments
	// of reference types (e.g., Apple inside Promise<Apple>).
	function checkTypeExpandability(t:Type):Void {
		if (this.ctx.maxExpansionDepth < 0 || t == null || this.ctx.canIncreaseExpansionDepth) {
			return;
		}
		// Push t onto the type stack so shouldExpandType's cycle detection works correctly.
		if (this.ctx.typeStack == null) {
			this.ctx.typeStack = [];
		}
		this.ctx.typeStack.push(t);
		if (t.alias != null) {
			this.shouldExpandType(t, true);
		}
		if (!this.ctx.canIncreaseExpansionDepth) {
			this.shouldExpandType(t, false);
		}
		this.ctx.typeStack.pop();
		if (this.ctx.canIncreaseExpansionDepth) {
			return;
		}
		// Recurse into type arguments (e.g., check Apple in Promise<Apple>).
		if (t.objectFlags & ObjectFlagsReference != 0) {
			final args = this.ch.getTypeArguments(t);
			if (args != null) {
				for (arg in args) {
					this.checkTypeExpandability(arg);
					if (this.ctx.canIncreaseExpansionDepth) {
						return;
					}
				}
			}
		}
	}

	function appendReferenceToType(root:TypeNode, ref:TypeNode):TypeNode {
		if (Ast.IsImportTypeNode(root)) {
			// first shift type arguments

			// !!! In the old emitter, an Identifier could have type arguments for use with quickinfo:
			// (see nodebuilderimpl.go)
			// !!! Without the above, nested type args are silently elided
			final imprt = root.AsImportTypeNode();
			// then move qualifiers
			final ids = Checker.getAccessStack(ref);
			var qualifier:Node = root.AsImportTypeNode().Qualifier;
			for (id in ids) {
				if (qualifier != null) {
					qualifier = this.f.NewQualifiedName(qualifier, id);
				} else {
					qualifier = id;
				}
			}
			return this.f.UpdateImportTypeNode(imprt, imprt.IsTypeOf, imprt.Argument, imprt.Attributes, qualifier, ref.TypeArgumentList());
		} else if (Ast.IsTypeReferenceNode(root)) {
			final typeRef = root.AsTypeReferenceNode();
			if (this.ctx.flags & FlagsUseInstantiationExpressions != 0 && typeRef.TypeArguments != null && typeRef.TypeArguments.Nodes.length != 0) {
				var expr = this.createExpressionWithTypeArguments(this.createAccessExpression(typeRef.TypeName), typeRef.TypeArguments);
				for (id in Checker.getAccessStack(ref)) {
					expr = this.f.NewPropertyAccessExpression(expr, null, id, NodeFlagsNone);
				}
				return expr;
			}
			var typeName:Node = typeRef.TypeName;
			for (id in Checker.getAccessStack(ref)) {
				typeName = this.f.NewQualifiedName(typeName, id);
			}
			return this.f.UpdateTypeReferenceNode(root.AsTypeReferenceNode(), typeName, ref.TypeArgumentList());
		}
		var expr = this.createAccessExpression(root);
		for (id in Checker.getAccessStack(ref)) {
			expr = this.f.NewPropertyAccessExpression(expr, null, id, NodeFlagsNone);
		}
		return expr;
	}

	function createElidedInformationPlaceholder():TypeNode {
		this.ctx.approximateLength += 3;
		if (this.ctx.flags & FlagsNoTruncation == 0) {
			return this.f.NewTypeReferenceNode(this.f.NewIdentifier("..."), null /*typeArguments*/);
		}
		return this.e.AddSyntheticLeadingComment(this.f.NewKeywordTypeNode(KindAnyKeyword), KindMultiLineCommentTrivia, "elided", false /*hasTrailingNewLine*/);
	}

	function mapToTypeNodes(list:Array<Type>, isBareList:Bool):NodeList {
		if (Core.len(list) == 0) {
			return null;
		}

		if (this.checkTruncationLength()) {
			if (!isBareList) {
				var node:Node = null;
				if (this.ctx.flags & FlagsNoTruncation != 0) {
					node = this.e.AddSyntheticLeadingComment(this.f.NewKeywordTypeNode(KindAnyKeyword), KindMultiLineCommentTrivia, "elided", false /*hasTrailingNewLine*/);
				} else {
					node = this.f.NewTypeReferenceNode(this.f.NewIdentifier("..."), null /*typeArguments*/);
				}
				return this.f.NewNodeList([node]);
			} else if (list.length > 2) {
				final nodes:Array<Node> = [this.typeToTypeNode(list[0]), null, this.typeToTypeNode(list[list.length - 1]),];

				if (this.ctx.flags & FlagsNoTruncation != 0) {
					nodes[1] = this.e.AddSyntheticLeadingComment(this.f.NewKeywordTypeNode(KindAnyKeyword), KindMultiLineCommentTrivia,
						"... " + (list.length - 2) + " more elided ...", false /*hasTrailingNewLine*/);
				} else {
					final text = "... " + (list.length - 2) + " more ...";
					nodes[1] = this.f.NewTypeReferenceNode(this.f.NewIdentifier(text), null /*typeArguments*/);
				}
				return this.f.NewNodeList(nodes);
			}
		}

		final mayHaveNameCollisions = this.ctx.flags & FlagsUseFullyQualifiedType == 0;
		// PORT: Go local struct `seenName{t, i}` → Pair<Type, Int>.
		var seenNames:ts.collections.Multimap.MultiMap<std.String, Pair<Type, Int>> = null;
		if (mayHaveNameCollisions) {
			seenNames = new ts.collections.Multimap.MultiMap<std.String, Pair<Type, Int>>();
		}

		final result:Array<Node> = [];

		for (i in 0...list.length) {
			final t = list[i];
			final displayIndex = i + 1;
			if (this.checkTruncationLength() && (displayIndex + 2 < list.length - 1)) {
				if (this.ctx.flags & FlagsNoTruncation != 0) {
					result.push(this.e.AddSyntheticLeadingComment(this.f.NewKeywordTypeNode(KindAnyKeyword), KindMultiLineCommentTrivia,
						"... " + (list.length - displayIndex) + " more elided ...", false /*hasTrailingNewLine*/));
				} else {
					final text = "... " + (list.length - displayIndex) + " more ...";
					result.push(this.f.NewTypeReferenceNode(this.f.NewIdentifier(text), null /*typeArguments*/));
				}
				final typeNode = this.typeToTypeNode(list[list.length - 1]);
				if (typeNode != null) {
					result.push(typeNode);
				}
				break;
			}
			this.ctx.approximateLength += 2; // Account for whitespace + separator
			final typeNode = this.typeToTypeNode(t);
			if (typeNode != null) {
				result.push(typeNode);
				if (seenNames != null && Checker.isIdentifierTypeReference(typeNode)) {
					seenNames.Add(typeNode.AsTypeReferenceNode().TypeName.Text(), new Pair<Type, Int>(t, result.length - 1));
				}
			}
		}

		if (seenNames != null) {
			// To avoid printing types like `[Foo, Foo]` or `Bar & Bar` where
			// occurrences of the same name actually come from different
			// namespaces, go through the single-identifier type reference nodes
			// we just generated, and see if any names were generated more than
			// once while referring to different types. If so, regenerate the
			// type node for each entry by that name with the
			// `UseFullyQualifiedType` flag enabled.
			final restoreFlags = this.saveRestoreFlags();
			this.ctx.flags |= FlagsUseFullyQualifiedType;
			for (types in seenNames.Values()) {
				if (!Checker.arrayIsHomogeneous(types, (a:Pair<Type, Int>, b:Pair<Type, Int>) -> {
					return Checker.typesAreSameReference(a.a, b.a);
				})) {
					for (seen in types) {
						result[seen.b] = this.typeToTypeNode(seen.a);
					}
				}
			}
			restoreFlags();
		}

		return this.f.NewNodeList(result);
	}

	function serializeTypeName(node:Node, isTypeOf:Bool, typeArguments:NodeList):Node {
		var meaning = SymbolFlagsType;
		if (isTypeOf) {
			meaning = SymbolFlagsValue;
		}
		final symbol = this.ch.resolveEntityName(node, meaning, true, false, node);
		if (symbol == null) {
			return null;
		}

		var resolvedSymbol = symbol;
		if (symbol.Flags & SymbolFlagsAlias != 0) {
			resolvedSymbol = this.ch.resolveAlias(symbol);
		}

		if (this.ch.IsSymbolAccessible(symbol, this.ctx.enclosingDeclaration, meaning, false).Accessibility != SymbolAccessibilityAccessible) {
			return null;
		}
		return this.symbolToTypeNode(resolvedSymbol, meaning, typeArguments);
	}

	function setCommentRange(node:Node, range_:Node):Void {
		if (range_ != null && this.ctx.enclosingFile != null && this.ctx.enclosingFile == Ast.GetSourceFileOfNode(range_)) {
			// Copy comments to node for declaration emit
			this.e.AssignCommentRange(node, range_);
		}
	}

	function typeNodeIsEquivalentToType(annotatedDeclaration:Node, t:Type, typeFromTypeNode:Type):Bool {
		if (typeFromTypeNode == t) {
			return true;
		}
		if (annotatedDeclaration == null) {
			return false;
		}
		// !!!
		// used to be hasEffectiveQuestionToken for JSDoc
		if (Checker.isOptionalDeclaration(annotatedDeclaration)) {
			return this.ch.getTypeWithFacts(t, TypeFactsNEUndefined) == typeFromTypeNode;
		}
		return false;
	}

	function canReuseExistingJSTypeNode(existing:TypeNode, t:Type):Bool {
		return this.ch.getIntendedTypeFromJSDocTypeReference(existing) == null
			&& this.existingTypeNodeIsNotReferenceOrIsReferenceWithCompatibleTypeArgumentCount(existing, t);
	}

	function tryGetResolvedSymbolFromTypeNode(node:Node):Symbol {
		if (node == null) {
			return null;
		}
		this.ch.getTypeFromTypeNode(node);
		// call to ensure symbol is resolved
		final links = this.ch.symbolNodeLinks.TryGet(node);
		if (links == null) {
			return null;
		}
		return links.resolvedSymbol;
	}

	function existingTypeNodeIsNotReferenceOrIsReferenceWithCompatibleTypeArgumentCount(existing:TypeNode, t:Type):Bool {
		// In JS, you can say something like `Foo` and get a `Foo<any>` implicitly - we don't want to preserve that original `Foo` in these cases, though.
		if (t.objectFlags & ObjectFlagsReference == 0) {
			return true;
		}
		if (!Ast.IsTypeReferenceNode(existing)) {
			return true;
		}

		final symbol = this.tryGetResolvedSymbolFromTypeNode(existing);
		if (symbol == null) {
			return true;
		}

		// `type` is a reference type, and `existing` is a type reference node, but we still need to make sure they refer to the _same_ target type
		// before we go comparing their type argument counts.

		final existingTarget = this.ch.getDeclaredTypeOfSymbol(symbol);
		if (existingTarget == null || existingTarget != t.AsTypeReference().target) {
			return true;
		}
		return Core.len(existing.TypeArguments()) >= this.ch.getMinTypeArgumentCount(t.AsTypeReference().target.AsInterfaceType().TypeParameters());
	}

	function tryReuseExistingNonParameterTypeNode(existing:TypeNode, t:Type, host:Node, annotationType:Type):TypeNode {
		if (host == null) {
			host = this.ctx.enclosingDeclaration;
		}
		if (annotationType == null) {
			annotationType = this.getTypeFromTypeNode(existing, true);
		}
		if (annotationType != null && this.typeNodeIsEquivalentToType(host, t, annotationType) && this.canReuseExistingJSTypeNode(existing, t)) {
			final result = this.tryReuseExistingNodeHelper(existing);
			if (result != null) {
				return result;
			}
		}
		return null;
	}

	function getResolvedTypeWithoutAbstractConstructSignatures(t:StructuredType):Type {
		if (Core.len(t.ConstructSignatures()) == 0) {
			return t.AsType();
		}
		if (t.objectTypeWithoutAbstractConstructSignatures != null) {
			return t.objectTypeWithoutAbstractConstructSignatures;
		}
		final constructSignatures = Core.Filter(t.ConstructSignatures(), (signature:Signature) -> {
			return signature.flags & SignatureFlagsAbstract == 0;
		});
		if (Core.len(constructSignatures) == Core.len(t.ConstructSignatures())) {
			t.objectTypeWithoutAbstractConstructSignatures = t.AsType();
			return t.AsType();
		}
		final typeCopy = this.ch.newAnonymousType(t.symbol, t.members, t.CallSignatures(),
			Core.IfElse(Core.len(constructSignatures) > 0, constructSignatures, ([] : Array<Signature>)), t.indexInfos);
		t.objectTypeWithoutAbstractConstructSignatures = typeCopy;
		typeCopy.AsStructuredType().objectTypeWithoutAbstractConstructSignatures = typeCopy;
		return typeCopy;
	}

	function symbolToNode(symbol:Symbol, meaning:SymbolFlags):Node {
		if (this.ctx.internalFlags & InternalFlagsWriteComputedProps != 0) {
			if (symbol.ValueDeclaration != null) {
				final name = Ast.GetNameOfDeclaration(symbol.ValueDeclaration);
				if (name != null && Ast.IsComputedPropertyName(name)) {
					return name;
				}
			}
			if (this.ch.valueSymbolLinks.Has(symbol)) {
				final nameType = this.ch.valueSymbolLinks.Get(symbol).nameType;
				if (nameType != null && nameType.flags & (TypeFlagsEnumLiteral | TypeFlagsUniqueESSymbol) != 0) {
					final oldEnclosing = this.ctx.enclosingDeclaration;
					this.ctx.enclosingDeclaration = nameType.symbol.ValueDeclaration;
					final result = this.f.NewComputedPropertyName(this.symbolToExpression(nameType.symbol, meaning));
					this.ctx.enclosingDeclaration = oldEnclosing;
					return result;
				}
			}
		}
		return this.symbolToExpression(symbol, meaning);
	}

	function symbolToName(symbol:Symbol, meaning:SymbolFlags, expectsIdentifier:Bool):Node {
		final chain = this.lookupSymbolChain(symbol, meaning, false);
		if (expectsIdentifier && Core.len(chain) != 1 && !this.ctx.encounteredError && (this.ctx.flags & FlagsAllowQualifiedNameInPlaceOfIdentifier != 0)) {
			this.ctx.encounteredError = true;
		}
		return this.createEntityNameFromSymbolChain(chain, Core.len(chain) - 1);
	}

	function createEntityNameFromSymbolChain(chain:Array<Symbol>, index:Int):Node {
		// typeParameterNodes := b.lookupTypeParameterNodes(chain, index)
		final symbol = chain[index];

		if (index == 0) {
			this.ctx.flags |= FlagsInInitialEntityName;
		}
		final symbolName = this.getNameOfSymbolAsWritten(symbol);
		if (index == 0) {
			// PORT: Go `^=` (Flags has no xor operator).
			this.ctx.flags = ((this.ctx.flags : Int) ^ (FlagsInInitialEntityName : Int) : Flags);
		}

		final identifier = this.newIdentifier(symbolName, symbol);
		this.e.AddEmitFlags(identifier, EFNoAsciiEscaping);
		// !!! TODO: smuggle type arguments out
		// if (typeParameterNodes) setIdentifierTypeArguments(identifier, factory.createNodeArray<TypeNode | TypeParameterDeclaration>(typeParameterNodes));
		// identifier.symbol = symbol;
		// expression = identifier;
		if (index > 0) {
			return this.f.NewQualifiedName(this.createEntityNameFromSymbolChain(chain, index - 1), identifier);
		}
		return identifier;
	}

	// TODO: Audit usages of symbolToEntityNameNode - they should probably all be symbolToName
	function symbolToEntityNameNode(symbol:Symbol):EntityName {
		final identifier = this.newIdentifier(symbol.Name, symbol);
		if (symbol.Parent != null) {
			return this.f.NewQualifiedName(this.symbolToEntityNameNode(symbol.Parent), identifier);
		}
		return identifier;
	}

	function symbolToTypeNode(symbol:Symbol, mask:SymbolFlags, typeArguments:NodeList):TypeNode {
		final chain = this.lookupSymbolChain(symbol, mask, (this.ctx.flags & FlagsUseAliasDefinedOutsideCurrentScope == 0)); // If we're using aliases outside the current scope, dont bother with the module
		if (Core.len(chain) == 0) {
			return null; // TODO: shouldn't be possible, `lookupSymbolChain` should always at least return the input symbol and issue an error
		}
		final isTypeOf = mask == SymbolFlagsValue;
		if (Core.Some(chain[0].Declarations, Checker.hasNonGlobalAugmentationExternalModuleSymbol)) {
			// module is root, must use `ImportTypeNode`
			var nonRootParts:Node = null;
			if (chain.length > 1) {
				nonRootParts = this.createAccessFromSymbolChain(chain, chain.length - 1, 1, typeArguments);
			}
			var typeParameterNodes = typeArguments;
			if (typeParameterNodes == null) {
				typeParameterNodes = this.lookupTypeParameterNodes(chain, 0);
			}
			final contextFile = Ast.GetSourceFileOfNode(this.e.MostOriginal(this.ctx.enclosingDeclaration)); // TODO: Just use b.ctx.enclosingFile ? Or is the delayed lookup important for context moves?
			final targetFile = Ast.GetSourceFileOfModule(chain[0]);
			var specifier:std.String = "";
			var attributes:Node = null;
			if (this.ch.compilerOptions.GetModuleResolutionKind() == ModuleResolutionKindNode16
				|| this.ch.compilerOptions.GetModuleResolutionKind() == ModuleResolutionKindNodeNext) {
				// An `import` type directed at an esm format file is only going to resolve in esm mode - set the esm mode assertion
				if (targetFile != null && contextFile != null && this.ch.program.GetEmitModuleFormatOfFile(ts.modulespecifiers.Types.SourceFileAdapter.Of(targetFile)) == ModuleKindESNext
					&& this.ch.program.GetEmitModuleFormatOfFile(ts.modulespecifiers.Types.SourceFileAdapter.Of(targetFile)) != this.ch.program.GetEmitModuleFormatOfFile(ts.modulespecifiers.Types.SourceFileAdapter.Of(contextFile))) {
					specifier = this.getSpecifierForModuleSymbol(chain[0], ModuleKindESNext);
					attributes = this.f.NewImportAttributes(KindWithKeyword,
						this.f.NewNodeList([this.f.NewImportAttribute(this.newStringLiteral("resolution-mode"), this.newStringLiteral("import"))]), false);
				}
			}
			if (specifier.length == 0) {
				specifier = this.getSpecifierForModuleSymbol(chain[0], Core.ResolutionModeNone);
			}
			if ((this.ctx.flags & FlagsAllowNodeModulesRelativePaths == 0) /* && b.ch.compilerOptions.GetModuleResolutionKind() != core.ModuleResolutionKindClassic */
				&& specifier.indexOf("/node_modules/") >= 0) {
				final oldSpecifier = specifier;

				if (this.ch.compilerOptions.GetModuleResolutionKind() == ModuleResolutionKindNode16
					|| this.ch.compilerOptions.GetModuleResolutionKind() == ModuleResolutionKindNodeNext) {
					// We might be able to write a portable import type using a mode override; try specifier generation again, but with a different mode set
					var swappedMode = ModuleKindESNext;
					if (this.ch.program.GetEmitModuleFormatOfFile(ts.modulespecifiers.Types.SourceFileAdapter.Of(contextFile)) == ModuleKindESNext) {
						swappedMode = ModuleKindCommonJS;
					}
					specifier = this.getSpecifierForModuleSymbol(chain[0], swappedMode);

					if (specifier.indexOf("/node_modules/") >= 0) {
						// Still unreachable :(
						specifier = oldSpecifier;
					} else {
						var modeStr = "require";
						if (swappedMode == ModuleKindESNext) {
							modeStr = "import";
						}
						attributes = this.f.NewImportAttributes(KindWithKeyword,
							this.f.NewNodeList([this.f.NewImportAttribute(this.newStringLiteral("resolution-mode"), this.newStringLiteral(modeStr))]), false);
					}
				}

				if (attributes == null) {
					// If ultimately we can only name the symbol with a reference that dives into a `node_modules` folder, we should error
					// since declaration files with these kinds of references are liable to fail when published :(
					this.ctx.encounteredError = true;
					this.ctx.tracker.ReportLikelyUnsafeImportRequiredError(oldSpecifier, symbol.Name);
				}
			}

			final lit = this.f.NewLiteralTypeNode(this.newStringLiteral(specifier));
			this.ctx.approximateLength += Utf8.ByteLen(specifier) + 10; // specifier + import("")
			if (nonRootParts == null || Ast.IsEntityName(nonRootParts)) {
				if (nonRootParts != null) {
					// !!! TODO: smuggle type arguments out
					// const lastId = isIdentifier(nonRootParts) ? nonRootParts : nonRootParts.right;
					// setIdentifierTypeArguments(lastId, /*typeArguments*/ undefined);
				}
				return this.f.NewImportTypeNode(isTypeOf, lit, attributes, nonRootParts, typeParameterNodes);
			}

			final splitNode = Checker.getTopmostIndexedAccessType(nonRootParts.AsIndexedAccessTypeNode());
			final qualifier = splitNode.ObjectType.AsTypeReferenceNode().TypeName;
			return this.f.NewIndexedAccessTypeNode(this.f.NewImportTypeNode(isTypeOf, lit, attributes, qualifier, typeParameterNodes), splitNode.IndexType);
		}

		final entityName = this.createAccessFromSymbolChain(chain, chain.length - 1, 0, typeArguments);
		if (Ast.IsIndexedAccessTypeNode(entityName)) {
			return entityName; // Indexed accesses can never be `typeof`
		}
		if (Ast.IsEntityName(entityName)) {
			if (isTypeOf) {
				return this.f.NewTypeQueryNode(entityName, null);
			}
			return this.f.NewTypeReferenceNode(entityName, typeArguments);
		}
		if (isTypeOf && Ast.IsExpressionWithTypeArguments(entityName)) {
			final expr = entityName.AsExpressionWithTypeArguments();
			return this.f.NewTypeQueryNode(this.f.DeepCloneNode(expr.Expression), expr.TypeArguments);
		}
		return entityName;
	}

	function createAccessFromSymbolChain(chain:Array<Symbol>, index:Int, stopper:Int, overrideTypeArguments:NodeList):Node {
		var typeParameterNodes = overrideTypeArguments;
		if (index != (chain.length - 1)) {
			typeParameterNodes = this.lookupTypeParameterNodes(chain, index);
		}
		final symbol = chain[index];
		var parent:Symbol = null;
		if (index > 0) {
			parent = chain[index - 1];
		}

		var symbolName:std.String = "";
		if (index == 0) {
			this.ctx.flags |= FlagsInInitialEntityName;
			symbolName = this.getNameOfSymbolAsWritten(symbol);
			this.ctx.approximateLength += Utf8.ByteLen(symbolName) + 1; // PORT: byte (Go len of a UTF-8 string)
			// PORT: Go `^=` (Flags has no xor operator).
			this.ctx.flags = ((this.ctx.flags : Int) ^ (FlagsInInitialEntityName : Int) : Flags);
		} else {
			// lookup a ref to symbol within parent to handle export aliases
			if (parent != null) {
				final exports = this.ch.getExportsOfSymbol(parent);
				if (exports != null) {
					// avoid exhaustive iteration in the common case
					final ok = exports.exists(symbol.Name);
					final res = exports.get(symbol.Name);
					if (symbol.Name != Ast.InternalSymbolNameExportEquals && !Checker.isLateBoundName(symbol.Name) && ok && res != null
						&& this.ch.getSymbolIfSameReference(res, symbol) != null) {
						symbolName = symbol.Name;
					} else {
						final results = new ObjectMap<Symbol, std.String>();
						// PORT: Go collects the map keys (random order) and sorts them; collect in an array as we go.
						final resultSymbols:Array<Symbol> = [];
						for (name => ex in exports) {
							if (this.ch.getSymbolIfSameReference(ex, symbol) != null && !Checker.isLateBoundName(name) && name != Ast.InternalSymbolNameExportEquals) {
								if (!results.exists(ex)) {
									resultSymbols.push(ex);
								}
								results.set(ex, name);
								// break // must collect all results and sort them - exports are randomly iterated
							}
						}
						if (resultSymbols.length > 0) {
							this.ch.sortSymbols(resultSymbols);
							symbolName = results.get(resultSymbols[0]);
						}
					}
				}
			}
		}

		if (symbolName.length == 0) {
			var name:Node = null;
			if (symbol.Declarations != null) {
				for (d in symbol.Declarations) {
					name = Ast.GetNameOfDeclaration(d);
					if (name != null) {
						break;
					}
				}
			}
			if (name != null && Ast.IsComputedPropertyName(name) && Ast.IsEntityName(name.Expression())) {
				final lhs = this.createAccessFromSymbolChain(chain, index - 1, stopper, overrideTypeArguments);
				if (Ast.IsEntityName(lhs)) {
					return this.f.NewIndexedAccessTypeNode(this.f.NewParenthesizedTypeNode(this.f.NewTypeQueryNode(lhs, null)),
						this.f.NewTypeQueryNode(name.Expression(), null));
				}
				return lhs;
			}
			symbolName = this.getNameOfSymbolAsWritten(symbol);
		}
		this.ctx.approximateLength += Utf8.ByteLen(symbolName) + 1; // PORT: byte (Go len of a UTF-8 string)

		if ((this.ctx.flags & FlagsForbidIndexedAccessSymbolReferences == 0) && parent != null && this.ch.getMembersOfSymbol(parent) != null
			&& this.ch.getMembersOfSymbol(parent).get(symbol.Name) != null
			&& this.ch.getSymbolIfSameReference(this.ch.getMembersOfSymbol(parent).get(symbol.Name), symbol) != null) {
			// Should use an indexed access
			final lhs = this.createAccessFromSymbolChain(chain, index - 1, stopper, overrideTypeArguments);
			if (Ast.IsIndexedAccessTypeNode(lhs)) {
				return this.f.NewIndexedAccessTypeNode(lhs, this.f.NewLiteralTypeNode(this.newStringLiteral(symbolName)));
			}
			return this.f.NewIndexedAccessTypeNode(this.f.NewTypeReferenceNode(lhs, typeParameterNodes), this.f.NewLiteralTypeNode(this.newStringLiteral(symbolName)));
		}

		final identifier = this.newIdentifier(symbolName, symbol);
		this.e.AddEmitFlags(identifier, EFNoAsciiEscaping);

		if (index > stopper) {
			final lhs = this.createAccessFromSymbolChain(chain, index - 1, stopper, overrideTypeArguments);
			if (this.ctx.flags & FlagsUseInstantiationExpressions == 0
				|| Ast.IsEntityName(lhs) && (typeParameterNodes == null || typeParameterNodes.Nodes.length == 0)) {
				return this.f.NewQualifiedName(lhs, identifier);
			}
			return this.createExpressionWithTypeArguments(this.f.NewPropertyAccessExpression(this.createAccessExpression(lhs), null, identifier, NodeFlagsNone),
				typeParameterNodes);
		}
		return identifier;
	}

	function symbolToExpression(symbol:Symbol, mask:SymbolFlags):Expression {
		final chain = this.lookupSymbolChain(symbol, mask, false);
		return this.createExpressionFromSymbolChain(chain, Core.len(chain) - 1);
	}

	function createExpressionFromSymbolChain(chain:Array<Symbol>, index:Int):Expression {
		final typeParameterNodes = this.lookupExpressionChainTypeArgumentNodes(chain, index);
		final symbol = chain[index];

		if (index == 0) {
			this.ctx.flags |= FlagsInInitialEntityName;
		}
		var symbolName = this.getNameOfSymbolAsWritten(symbol);
		if (index == 0) {
			// PORT: Go `^=` (Flags has no xor operator).
			this.ctx.flags = ((this.ctx.flags : Int) ^ (FlagsInInitialEntityName : Int) : Flags);
		}

		if (Checker.startsWithSingleOrDoubleQuote(symbolName) && Core.Some(symbol.Declarations, Checker.hasNonGlobalAugmentationExternalModuleSymbol)) {
			final specifier = this.getSpecifierForModuleSymbol(symbol, Core.ResolutionModeNone);
			this.ctx.approximateLength += 2 + Utf8.ByteLen(specifier); // PORT: byte (Go len of a UTF-8 string)
			return this.newStringLiteral(specifier);
		}

		if (index == 0 || Checker.canUsePropertyAccess(symbolName)) {
			final identifier = this.newIdentifier(symbolName, symbol);
			this.e.AddEmitFlags(identifier, EFNoAsciiEscaping);
			this.ctx.approximateLength += 1 + Utf8.ByteLen(symbolName); // PORT: byte (Go len of a UTF-8 string)
			if (index > 0) {
				final result = this.f.NewPropertyAccessExpression(this.createExpressionFromSymbolChain(chain, index - 1), null, identifier, NodeFlagsNone);
				this.e.AddEmitFlags(result, EFNoIndentation);
				return this.createExpressionWithTypeArguments(result, typeParameterNodes);
			}
			return this.createExpressionWithTypeArguments(identifier, typeParameterNodes);
		}

		if (Checker.startsWithSquareBracket(symbolName)) {
			symbolName = symbolName.substring(1, symbolName.length - 1);
		}

		var expression:Expression = null;
		if (Checker.startsWithSingleOrDoubleQuote(symbolName) && symbol.Flags & SymbolFlagsEnumMember == 0) {
			final literalText = Stringutil.UnquoteString(symbolName);
			this.ctx.approximateLength += Utf8.ByteLen(literalText) + 2; // PORT: byte (Go len of a UTF-8 string)
			expression = this.newStringLiteralEx(literalText, StringTools.fastCodeAt(symbolName, 0) == "'".code);
		} else if (ts.jsnum.String_.String(Jsnum.FromString(symbolName)) == symbolName) {
			// TODO: the follwing in strada would assert if the number is negative, but no such assertion exists here
			// Moreover, what's even guaranteeing the name *isn't* -1 here anyway? Needs double-checking.
			this.ctx.approximateLength += Utf8.ByteLen(symbolName); // PORT: byte (Go len of a UTF-8 string)
			expression = this.f.NewNumericLiteral(symbolName, TokenFlagsNone);
		}
		if (expression == null) {
			this.ctx.approximateLength += Utf8.ByteLen(symbolName); // PORT: byte (Go len of a UTF-8 string)
			expression = this.newIdentifier(symbolName, symbol);
			this.e.AddEmitFlags(expression, EFNoAsciiEscaping);
		}
		this.ctx.approximateLength += 2; // []
		return this.createExpressionWithTypeArguments(this.f.NewElementAccessExpression(this.createExpressionFromSymbolChain(chain, index - 1), null, expression,
			NodeFlagsNone), typeParameterNodes);
	}

	function getNameOfSymbolFromNameType(symbol:Symbol):std.String {
		if (this.ch.valueSymbolLinks.Has(symbol)) {
			final nameType = this.ch.valueSymbolLinks.Get(symbol).nameType;
			if (nameType == null) {
				return "";
			}
			if (nameType.flags & TypeFlagsStringOrNumberLiteral != 0) {
				var name:std.String = "";
				final v:Any = nameType.AsLiteralType().value;
				if (Std.isOfType(v, std.String)) {
					name = (v : std.String);
				} else if (Std.isOfType(v, Float)) {
					name = ts.jsnum.String_.String((v : Float));
				}
				if (!Scanner.IsIdentifierText(name, LanguageVariantStandard) && !Checker.isNumericLiteralName(name)) {
					return this.ch.valueToString(nameType.AsLiteralType().value);
				}
				if (Checker.isNumericLiteralName(name) && StringTools.startsWith(name, "-")) {
					return "[" + name + "]";
				}
				return name;
			}
			if (nameType.flags & TypeFlagsUniqueESSymbol != 0) {
				final text = this.getNameOfSymbolAsWritten(nameType.AsUniqueESSymbolType().symbol);
				return "[" + text + "]";
			}
		}
		return "";
	}

	/**
	* Gets a human-readable name for a symbol.
	* Should *not* be used for the right-hand side of a `.` -- use `symbolName(symbol)` for that instead.
	*
	* Unlike `symbolName(symbol)`, this will include quotes if the name is from a string literal.
	* It will also use a representation of a number as written instead of a decimal form, e.g. `0o11` instead of `9`.
	 */
	function getNameOfSymbolAsWritten(symbol:Symbol):std.String {
		final remapped = this.ctx.remappedSymbolReferences;
		final symbolId:Int = Ast.GetSymbolId(symbol);
		if (remapped != null && remapped.exists(symbolId)) {
			symbol = remapped.get(symbolId);
		}
		if (symbol.Name == Ast.InternalSymbolNameDefault && (this.ctx.flags & FlagsUseAliasDefinedOutsideCurrentScope == 0)
			&& ( // If it's not the first part of an entity name, it must print as `default`
				(this.ctx.flags & FlagsInInitialEntityName == 0)
				|| // if the symbol is synthesized, it will only be referenced externally it must print as `default`
				Core.len(symbol.Declarations) == 0
				|| // if not in the same binding context (source file, module declaration), it must print as `default`
				(this.ctx.enclosingDeclaration != null
					&& Ast.FindAncestor(symbol.Declarations[0], Checker.isDefaultBindingContext) != Ast.FindAncestor(this.ctx.enclosingDeclaration,
						Checker.isDefaultBindingContext)))) {
			return "default";
		}
		if (Core.len(symbol.Declarations) > 0) {
			final name = Core.FirstNonNil(symbol.Declarations, Ast.GetNameOfDeclaration); // Try using a declaration with a name, first
			if (name != null) {
				// !!! TODO: JS Object.defineProperty declarations
				// if ast.IsCallExpression(declaration) && ast.IsBindableObjectDefinePropertyCall(declaration) {
				// 	return symbol.Name
				// }
				if (Ast.IsComputedPropertyName(name) && symbol.CheckFlags & CheckFlagsLate == 0) {
					if (this.ch.valueSymbolLinks.Has(symbol) && this.ch.valueSymbolLinks.Get(symbol).nameType != null
						&& this.ch.valueSymbolLinks.Get(symbol).nameType.flags & TypeFlagsStringOrNumberLiteral != 0) {
						final result = this.getNameOfSymbolFromNameType(symbol);
						if (result.length > 0) {
							return result;
						}
					}
				}
				return Scanner.DeclarationNameToString(name);
			}
			final declaration = symbol.Declarations[0]; // Declaration may be nameless, but we'll try anyway
			if (declaration.Parent != null && declaration.Parent.Kind == KindVariableDeclaration) {
				return Scanner.DeclarationNameToString(declaration.Parent.AsVariableDeclaration().Name());
			}
			if (Ast.IsClassExpression(declaration) || Ast.IsFunctionExpression(declaration) || Ast.IsArrowFunction(declaration)) {
				if (this.ctx != null && !this.ctx.encounteredError && this.ctx.flags & FlagsAllowAnonymousIdentifier == 0) {
					this.ctx.encounteredError = true;
				}
				switch (declaration.Kind) {
					case KindClassExpression:
						return "(Anonymous class)";
					case KindFunctionExpression | KindArrowFunction:
						return "(Anonymous function)";
					default:
				}
			}
		}
		final name = this.getNameOfSymbolFromNameType(symbol);
		if (name.length > 0) {
			return name;
		}
		return Ast.EscapeInternalSymbolName(symbol.Name);
	}

	// The full set of type parameters for a generic class or interface type consists of its outer type parameters plus
	// its locally declared type parameters.
	function getTypeParametersOfClassOrInterface(symbol:Symbol):Array<Type> {
		final result:Array<Type> = [];
		final outer = this.ch.getOuterTypeParametersOfClassOrInterface(symbol);
		if (outer != null) {
			for (t in outer) {
				result.push(t);
			}
		}
		final local = this.ch.getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(symbol);
		if (local != null) {
			for (t in local) {
				result.push(t);
			}
		}
		return result;
	}

	function lookupTypeParameterNodes(chain:Array<Symbol>, index:Int):TypeParameterList {
		Debug.Assert(chain != null && 0 <= index && index < chain.length);
		final symbol = chain[index];
		final symbolId = Ast.GetSymbolId(symbol);
		if (this.ctx.typeParameterSymbolList.Has(symbolId)) {
			return null;
		}
		this.ctx.typeParameterSymbolList.Add(symbolId);

		if (this.ctx.flags & FlagsWriteTypeParametersInQualifiedName != 0 && index < (chain.length - 1)) {
			final typeArgumentNodes = this.lookupInstantiatedTypeArgumentNodes(chain, index);
			if (typeArgumentNodes != null) {
				return typeArgumentNodes;
			} else {
				final typeParameterNodes = this.typeParametersToTypeParameterDeclarations(symbol);
				if (Core.len(typeParameterNodes) > 0) {
					return this.f.NewNodeList(typeParameterNodes);
				}
				return null;
			}
		}

		return null;
	}

	// TODO: move `lookupSymbolChain` and co to `symbolaccessibility.go` (but getSpecifierForModuleSymbol uses much context which makes that hard?)
	function lookupSymbolChain(symbol:Symbol, meaning:SymbolFlags, yieldModuleSymbol:Bool):Array<Symbol> {
		this.ctx.tracker.TrackSymbol(symbol, this.ctx.enclosingDeclaration, meaning);
		return this.lookupSymbolChainWorker(symbol, meaning, yieldModuleSymbol);
	}

	function lookupSymbolChainWorker(symbol:Symbol, meaning:SymbolFlags, yieldModuleSymbol:Bool):Array<Symbol> {
		// Try to get qualified name if the symbol is not a type parameter and there is an enclosing declaration.
		var chain:Array<Symbol> = null;
		final isTypeParameter = symbol.Flags & SymbolFlagsTypeParameter != 0;
		if (!isTypeParameter && (this.ctx.enclosingDeclaration != null || this.ctx.flags & FlagsUseFullyQualifiedType != 0)
			&& (this.ctx.internalFlags & InternalFlagsDoNotIncludeSymbolChain == 0)) {
			final res = this.getSymbolChain(symbol, meaning /*endOfChain*/, true, yieldModuleSymbol);
			chain = res;
			Debug.Assert(chain != null);
			Debug.Assert(chain.length > 0);
		} else {
			chain = [symbol];
		}
		return chain;
	}

	/** @param endOfChain Set to false for recursive calls; non-recursive calls should always output something. */
	function getSymbolChain(symbol:Symbol, meaning:SymbolFlags, endOfChain:Bool, yieldModuleSymbol:Bool):Array<Symbol> {
		var accessibleSymbolChain = this.ch.getAccessibleSymbolChain(symbol, this.ctx.enclosingDeclaration, meaning,
			this.ctx.flags & FlagsUseOnlyExternalAliasing != 0);
		var qualifierMeaning = meaning;
		if (Core.len(accessibleSymbolChain) > 1) {
			qualifierMeaning = Checker.getQualifiedLeftMeaning(meaning);
		}
		if (Core.len(accessibleSymbolChain) == 0 || this.ch.needsQualification(accessibleSymbolChain[0], this.ctx.enclosingDeclaration, qualifierMeaning)) {
			// Go up and add our parent.
			var root = symbol;
			if (Core.len(accessibleSymbolChain) > 0) {
				root = accessibleSymbolChain[0];
			}
			final parents = this.ch.getContainersOfSymbol(root, this.ctx.enclosingDeclaration, meaning);
			if (Core.len(parents) > 0) {
				final parentSpecifiers = Core.Map(parents, (symbol:Symbol) -> {
					final p = new SortedSymbolNamePair();
					p.sym = symbol;
					if (Core.Some(symbol.Declarations, Checker.hasNonGlobalAugmentationExternalModuleSymbol)) {
						p.name = this.getSpecifierForModuleSymbol(symbol, Core.ResolutionModeNone);
					} else {
						p.name = "";
					}
					return p;
				});
				Slices.SortStableFunc(parentSpecifiers, (a, b) -> this.sortByBestName(a, b));
				for (pair in parentSpecifiers) {
					final parent = pair.sym;
					final parentChain = this.getSymbolChain(parent, Checker.getQualifiedLeftMeaning(meaning), false, yieldModuleSymbol);
					if (Core.len(parentChain) > 0) {
						if (parent.Exports != null) {
							final ok = parent.Exports.exists(Ast.InternalSymbolNameExportEquals);
							final exported = parent.Exports.get(Ast.InternalSymbolNameExportEquals);
							if (ok && this.ch.getSymbolIfSameReference(exported, symbol) != null) {
								// parentChain root _is_ symbol - symbol is a module export=, so it kinda looks like it's own parent
								// No need to lookup an alias for the symbol in itself
								accessibleSymbolChain = parentChain;
								break;
							}
						}
						var nextSyms = accessibleSymbolChain;
						if (Core.len(nextSyms) == 0) {
							var fallback = this.ch.getAliasForSymbolInContainer(parent, symbol);
							if (fallback == null) {
								fallback = symbol;
							}
							nextSyms = [fallback];
						}
						// PORT: Go `append(parentChain, nextSyms...)` → concat (never writes into parentChain).
						accessibleSymbolChain = parentChain.concat(nextSyms);
						break;
					}
				}
			}
		}
		if (Core.len(accessibleSymbolChain) > 0) {
			return accessibleSymbolChain;
		}
		if ( // If this is the last part of outputting the symbol, always output. The cases apply only to parent symbols.
			endOfChain || // If a parent symbol is an anonymous type, don't write it.
			(symbol.Flags & (SymbolFlagsTypeLiteral | SymbolFlagsObjectLiteral) == 0)) {
			// If a parent symbol is an external module, don't write it. (We prefer just `x` vs `"foo/bar".x`.)
			if (!endOfChain && !yieldModuleSymbol && Core.Some(symbol.Declarations, Checker.hasNonGlobalAugmentationExternalModuleSymbol)) {
				return null;
			}
			return [symbol];
		}
		return null;
	}

	function sortByBestName(a:SortedSymbolNamePair, b:SortedSymbolNamePair):Int {
		final specifierA = a.name;
		final specifierB = b.name;
		if (specifierA.length > 0 && specifierB.length > 0) {
			final isBRelative = Tspath.PathIsRelative(specifierB);
			if (Tspath.PathIsRelative(specifierA) == isBRelative) {
				// Both relative or both non-relative, sort by number of parts
				return Modulespecifiers.CountPathComponents(specifierA) - Modulespecifiers.CountPathComponents(specifierB);
			}
			if (isBRelative) {
				// A is non-relative, B is relative: prefer A
				return -1;
			}
			// A is relative, B is non-relative: prefer B
			return 1;
		}
		return this.ch.compareSymbols(a.sym, b.sym); // must sort symbols for stable ordering
	}

	function getSpecifierForModuleSymbol(symbol:Symbol, overrideImportMode:ResolutionMode):std.String {
		var file = Ast.GetDeclarationOfKind(symbol, KindSourceFile);
		if (file == null) {
			final equivalentSymbol = Core.FirstNonNil(symbol.Declarations, (d:Node) -> {
				return this.ch.getFileSymbolIfFileSymbolExportEqualsContainer(d, symbol);
			});
			if (equivalentSymbol != null) {
				file = Ast.GetDeclarationOfKind(equivalentSymbol, KindSourceFile);
			}
		}

		if (file == null) {
			if (Ast.IsAmbientModuleSymbolName(symbol.Name)) {
				return Stringutil.StripQuotes(symbol.Name);
			}
		}
		if (this.ctx.enclosingFile == null) {
			if (Ast.IsAmbientModuleSymbolName(symbol.Name)) {
				return Stringutil.StripQuotes(symbol.Name);
			}
			return Ast.GetSourceFileOfModule(symbol).FileName();
		}

		final enclosingDeclaration = this.e.MostOriginal(this.ctx.enclosingDeclaration);
		var originalModuleSpecifier:Node = null;
		if (Checker.canHaveModuleSpecifier(enclosingDeclaration)) {
			originalModuleSpecifier = Checker.TryGetModuleSpecifierFromDeclaration(enclosingDeclaration);
		}
		final contextFile = this.ctx.enclosingFile;
		var resolutionMode = overrideImportMode;
		if (resolutionMode == Core.ResolutionModeNone && originalModuleSpecifier != null) {
			resolutionMode = this.ch.program.GetModeForUsageLocation(ts.modulespecifiers.Types.SourceFileAdapter.Of(contextFile), originalModuleSpecifier);
		} else if (resolutionMode == Core.ResolutionModeNone && contextFile != null) {
			resolutionMode = this.ch.program.GetDefaultResolutionModeForFile(ts.modulespecifiers.Types.SourceFileAdapter.Of(contextFile));
		}
		final cacheKey = new ts.module.Types.ModeAwareCacheKey((contextFile.Path() : std.String), resolutionMode).Key();
		final links = this.symbolLinks.Get(symbol);
		if (links.specifierCache == null) {
			links.specifierCache = new ModeAwareCache<std.String>();
		}
		if (links.specifierCache.exists(cacheKey)) {
			return links.specifierCache.get(cacheKey);
		}
		// For declaration bundles, we need to generate absolute paths relative to the common source dir for imports,
		// just like how the declaration emitter does for the ambient module declarations - we can easily accomplish this
		// using the `baseUrl` compiler option (which we would otherwise never use in declaration emit) and a non-relative
		// specifier preference
		final host = this.ctx.host;
		final specifierCompilerOptions = this.ch.compilerOptions;
		final specifierPref = ImportModuleSpecifierPreferenceProjectRelative;
		var endingPref = ImportModuleSpecifierEndingPreferenceNone;
		if (resolutionMode == Core.ResolutionModeESM) {
			endingPref = ImportModuleSpecifierEndingPreferenceJs;
		}

		final prefs = new ts.modulespecifiers.Types.UserPreferences();
		prefs.ImportModuleSpecifierPreference = specifierPref;
		prefs.ImportModuleSpecifierEnding = endingPref;
		// PORT: Go passes *Checker and Host where structural interfaces are expected; Haxe needs adapters (PORTING.md §3).
		final allSpecifiers = Modulespecifiers.GetModuleSpecifiers(symbol, new NodeBuilderCheckerShapeAdapter(this.ch), specifierCompilerOptions,
			ts.modulespecifiers.Types.SourceFileAdapter.Of(contextFile), new NodeBuilderSpecifierHostAdapter(host), prefs,
			new ts.modulespecifiers.Types.ModuleSpecifierOptions(overrideImportMode), false /*forAutoImports*/);
		if (Core.len(allSpecifiers) == 0) {
			links.specifierCache.set(cacheKey, "");
			return "";
		}
		final specifier = allSpecifiers[0];
		links.specifierCache.set(cacheKey, specifier);
		return specifier;
	}

	function typeParameterToDeclarationWithConstraint(typeParameter:Type, constraintNode:TypeNode):TypeParameterDeclarationNode {
		final restoreFlags = this.saveRestoreFlags();
		this.ctx.flags = this.ctx.flags & ~FlagsWriteTypeParametersInQualifiedName; // Avoids potential infinite loop when building for a claimspace with a generic
		final modifiers = Ast.CreateModifiersFromModifierFlags(this.ch.getTypeParameterModifiers(typeParameter), kind -> this.f.NewModifier(kind));
		var modifiersList:ModifierList = null;
		if (Core.len(modifiers) > 0) {
			modifiersList = this.f.NewModifierList(modifiers);
		}
		final name = this.typeParameterToName(typeParameter);
		final defaultParameter = this.ch.getDefaultFromTypeParameter(typeParameter);
		var defaultParameterDeclarationNode:Node = null;
		if (defaultParameter != null) {
			defaultParameterDeclarationNode = this.typeToTypeNode(defaultParameter);
		}
		restoreFlags();
		return this.f.NewTypeParameterDeclaration(modifiersList, name.AsNode(), constraintNode, null, // expression
			defaultParameterDeclarationNode);
	}

	/**
	* Unlike the utilities `setTextRange`, this checks if the `location` we're trying to set on `range` is within the
	* same file as the active context. If not, the range is not applied. This prevents us from copying ranges across files,
	* which will confuse the node printer (as it assumes all node ranges are within the current file).
	* Additionally, if `range` _isn't synthetic_, or isn't in the current file, it will _copy_ it to _remove_ its' position
	* information.
	*
	* It also calls `setOriginalNode` to setup a `.original` pointer, since you basically *always* want these in the node builder.
	 */
	function setTextRange(range_:Node, location:Node):Node {
		if (range_ == null) {
			return range_;
		}
		if (!Ast.NodeIsSynthesized(range_) || (range_.Flags & NodeFlagsSynthesized == 0) || this.ctx.enclosingFile == null
			|| this.ctx.enclosingFile != Ast.GetSourceFileOfNode(this.e.MostOriginal(range_))) {
			final original = range_;
			range_ = range_.Clone(this.f); // if `range` is synthesized or originates in another file, copy it so it definitely has synthetic positions
			range_.Loc = Core.NewTextRange(-1, -1);
			if (this.idToSymbol.exists(original)) {
				this.idToSymbol.set(range_, this.idToSymbol.get(original));
			}
		}
		if (range_ == location || location == null) {
			return range_;
		}
		// Don't overwrite the original node if `range` has an `original` node that points either directly or indirectly to `location`
		var original = this.e.Original(range_);
		while (original != null && original != location) {
			original = this.e.Original(original);
		}
		if (original == null) {
			this.e.SetOriginalEx(range_, location, true);
		}

		// only set positions if range comes from the same file since copying text across files isn't supported by the emitter
		if (this.ctx.enclosingFile != null && this.ctx.enclosingFile == Ast.GetSourceFileOfNode(this.e.MostOriginal(location))) {
			range_.Loc = location.Loc;
			return range_;
		} else {
			range_.Loc = Core.NewTextRange(-1, -1);
		}
		return range_;
	}

	function typeParameterShadowsOtherTypeParameterInScope(name:std.String, typeParameter:Type):Bool {
		final result = this.ch.resolveName(this.ctx.enclosingDeclaration, name, SymbolFlagsType, null, false, false);
		if (result != null && result.Flags & SymbolFlagsTypeParameter != 0) {
			return result != typeParameter.symbol;
		}
		return false;
	}

	function typeParameterToName(typeParameter:Type):Identifier {
		if (this.ctx.flags & FlagsGenerateNamesForShadowedTypeParams != 0) {
			final cached = this.ctx.typeParameterNames.Get(typeParameter.id);
			if (cached.ok) {
				return cached.value;
			}
		}
		var result = this.symbolToName(typeParameter.symbol, SymbolFlagsType /*expectsIdentifier*/, true);
		if (!Ast.IsIdentifier(result)) {
			return this.f.NewIdentifier("(Missing type parameter)").AsIdentifier();
		}
		if (typeParameter.symbol != null && Core.len(typeParameter.symbol.Declarations) > 0) {
			final decl = typeParameter.symbol.Declarations[0];
			if (decl != null && Ast.IsTypeParameterDeclaration(decl)) {
				result = this.setTextRange(result, decl.Name());
			}
		}
		if (this.ctx.flags & FlagsGenerateNamesForShadowedTypeParams != 0) {
			final rawText = result.Text();
			// PORT: the map is created without a zero value; Go's missing-key result is 0.
			final r = this.ctx.typeParameterNamesByTextNextNameCount.Get(rawText);
			var i:Int = r.ok ? r.value : 0;
			var text = rawText;

			while (true) {
				if (!this.ctx.typeParameterNamesByText.Has(text) && !this.typeParameterShadowsOtherTypeParameterInScope(text, typeParameter)) {
					break;
				}
				i++;
				text = rawText + "_" + i;
			}

			if (text != rawText) {
				// !!! TODO: smuggle type arguments out
				// const typeArguments = getIdentifierTypeArguments(result);
				result = this.newIdentifier(text, typeParameter.symbol);
				// setIdentifierTypeArguments(result, typeArguments);
			}

			// avoiding iterations of the above loop turns out to be worth it when `i` starts to get large, so we cache the max
			// `i` we've used thus far, to save work later
			this.ctx.typeParameterNamesByTextNextNameCount.Set(rawText, i);
			this.ctx.typeParameterNames.Set(typeParameter.id, result.AsIdentifier());
			this.ctx.typeParameterNamesByText.Add(text);
		}

		return result.AsIdentifier();
	}

	function isMappedTypeHomomorphic(mapped:Type):Bool {
		return this.ch.getHomomorphicTypeVariable(mapped) != null;
	}

	function isHomomorphicMappedTypeWithNonHomomorphicInstantiation(mapped:MappedType):Bool {
		return mapped.target != null && !this.isMappedTypeHomomorphic(mapped.AsType()) && this.isMappedTypeHomomorphic(mapped.target);
	}

	function createMappedTypeNodeFromType(t:Type):TypeNode {
		final b = this;
		Debug.Assert(t.Flags() & TypeFlagsObject != 0);
		final mapped = t.AsMappedType();
		var readonlyToken:Node = null;
		if (mapped.declaration.ReadonlyToken != null) {
			readonlyToken = b.f.NewToken(mapped.declaration.ReadonlyToken.Kind);
		}
		var questionToken:Node = null;
		if (mapped.declaration.QuestionToken != null) {
			questionToken = b.f.NewToken(mapped.declaration.QuestionToken.Kind);
		}
		var appropriateConstraintTypeNode:Node = null;
		var newTypeVariable:Node = null;
		var templateType = b.ch.getTemplateTypeFromMappedType(t);
		final typeParameter = b.ch.getTypeParameterFromMappedType(t);

		// If the mapped type isn't `keyof` constraint-declared, _but_ still has modifiers preserved, and its naive instantiation won't preserve modifiers because its constraint isn't `keyof` constrained, we have work to do
		final needsModifierPreservingWrapper = !b.ch.isMappedTypeWithKeyofConstraintDeclaration(t)
			&& b.ch.getModifiersTypeFromMappedType(t).flags & TypeFlagsUnknown == 0
			&& b.ctx.flags & FlagsGenerateNamesForShadowedTypeParams != 0
			&& !(b.ch.getConstraintTypeFromMappedType(t).flags & TypeFlagsTypeParameter != 0
				&& b.ch.getConstraintOfTypeParameter(b.ch.getConstraintTypeFromMappedType(t)).flags & TypeFlagsIndex != 0);

		if (b.ch.isMappedTypeWithKeyofConstraintDeclaration(t)) {
			// We have a { [P in keyof T]: X }
			// We do this to ensure we retain the toplevel keyof-ness of the type which may be lost due to keyof distribution during `getConstraintTypeFromMappedType`
			if (b.ctx.flags & FlagsGenerateNamesForShadowedTypeParams != 0 && b.isHomomorphicMappedTypeWithNonHomomorphicInstantiation(mapped)) {
				final newConstraintParam = b.ch.newTypeParameter(b.ch.newSymbol(SymbolFlagsTypeParameter, "T"));
				final name = b.typeParameterToName(newConstraintParam);
				final target = t.Target();
				newTypeVariable = b.f.NewTypeReferenceNode(name.AsNode(), null);
				templateType = b.ch.instantiateType(b.ch.getTemplateTypeFromMappedType(target),
					Checker.newTypeMapper([b.ch.getTypeParameterFromMappedType(target), b.ch.getModifiersTypeFromMappedType(target)], [typeParameter, newConstraintParam]));
			}
			var indexTarget = newTypeVariable;
			if (indexTarget == null) {
				indexTarget = b.typeToTypeNode(b.ch.getModifiersTypeFromMappedType(t));
			}
			appropriateConstraintTypeNode = b.f.NewTypeOperatorNode(KindKeyOfKeyword, indexTarget);
		} else if (needsModifierPreservingWrapper) {
			// So, step 1: new type variable
			final newParam = b.ch.newTypeParameter(b.ch.newSymbol(SymbolFlagsTypeParameter, "T"));
			final name = b.typeParameterToName(newParam);
			newTypeVariable = b.f.NewTypeReferenceNode(name.AsNode(), null);
			// step 2: make that new type variable itself the constraint node, making the mapped type `{[K in T_1]: Template}`
			appropriateConstraintTypeNode = newTypeVariable;
		} else {
			appropriateConstraintTypeNode = b.typeToTypeNode(b.ch.getConstraintTypeFromMappedType(t));
		}

		// nameType and templateType nodes have to be in the new scope
		final cleanup = b.enterNewScope(mapped.declaration.AsNode(), null, [b.ch.getTypeParameterFromMappedType(t)], null, null);
		final typeParameterDeclarationNode = b.typeParameterToDeclarationWithConstraint(typeParameter, appropriateConstraintTypeNode);
		var nameTypeNode:Node = null;
		if (mapped.declaration.NameType != null) {
			nameTypeNode = b.typeToTypeNode(b.ch.getNameTypeFromMappedType(t));
		}
		final templateTypeNode = b.typeToTypeNode(b.ch.removeMissingType(templateType, Checker.getMappedTypeModifiers(t) & MappedTypeModifiersIncludeOptional != 0));
		cleanup();
		final result = b.f.NewMappedTypeNode(readonlyToken, typeParameterDeclarationNode, nameTypeNode, questionToken, templateTypeNode, null);
		b.ctx.approximateLength += 10;
		b.e.AddEmitFlags(result, EFSingleLine);

		if (b.ctx.flags & FlagsGenerateNamesForShadowedTypeParams != 0 && b.isHomomorphicMappedTypeWithNonHomomorphicInstantiation(mapped)) {
			// homomorphic mapped type with a non-homomorphic naive inlining
			// wrap it with a conditional like `SomeModifiersType extends infer U ? {..the mapped type...} : never` to ensure the resulting
			// type stays homomorphic

			var rawConstraintTypeFromDeclaration = b.getTypeFromTypeNode(mapped.declaration.TypeParameter.AsTypeParameterDeclaration().Constraint.Type(), false);
			if (rawConstraintTypeFromDeclaration != null) {
				rawConstraintTypeFromDeclaration = b.ch.getConstraintOfTypeParameter(rawConstraintTypeFromDeclaration);
			}
			if (rawConstraintTypeFromDeclaration == null) {
				rawConstraintTypeFromDeclaration = b.ch.unknownType;
			}
			final originalConstraint = b.ch.instantiateType(rawConstraintTypeFromDeclaration, mapped.mapper);

			var originalConstraintNode:Node = null;
			if (originalConstraint.flags & TypeFlagsUnknown == 0) {
				originalConstraintNode = b.typeToTypeNode(originalConstraint);
			}

			return b.f.NewConditionalTypeNode(b.typeToTypeNode(b.ch.getModifiersTypeFromMappedType(t)),
				b.f.NewInferTypeNode(b.f.NewTypeParameterDeclaration(null, newTypeVariable.AsTypeReferenceNode().TypeName.Clone(b.f), originalConstraintNode, null, null)),
				result, b.f.NewKeywordTypeNode(KindNeverKeyword));
		} else if (needsModifierPreservingWrapper) {
			// and step 3: once the mapped type is reconstructed, create a `ConstraintType extends infer T_1 extends keyof ModifiersType ? {[K in T_1]: Template} : never`
			// subtly different from the `keyof` constraint case, by including the `keyof` constraint on the `infer` type parameter, it doesn't rely on the constraint type being itself
			// constrained to a `keyof` type to preserve its modifier-preserving behavior. This is all basically because we preserve modifiers for a wider set of mapped types than
			// just homomorphic ones.
			return b.f.NewConditionalTypeNode(b.typeToTypeNode(b.ch.getConstraintTypeFromMappedType(t)),
				b.f.NewInferTypeNode(b.f.NewTypeParameterDeclaration(null, newTypeVariable.AsTypeReferenceNode().TypeName.Clone(b.f),
					b.f.NewTypeOperatorNode(KindKeyOfKeyword, b.typeToTypeNode(b.ch.getModifiersTypeFromMappedType(t))), null, null)),
				result, b.f.NewKeywordTypeNode(KindNeverKeyword));
		}

		return result;
	}

	function typePredicateToTypePredicateNode(predicate:TypePredicate):Node {
		var assertsModifier:Node = null;
		if (predicate.kind == TypePredicateKindAssertsIdentifier || predicate.kind == TypePredicateKindAssertsThis) {
			assertsModifier = this.f.NewToken(KindAssertsKeyword);
		}
		var parameterName:Node = null;
		if (predicate.kind == TypePredicateKindIdentifier || predicate.kind == TypePredicateKindAssertsIdentifier) {
			parameterName = this.f.NewIdentifier(predicate.parameterName);
			this.e.AddEmitFlags(parameterName, EFNoAsciiEscaping);
		} else {
			parameterName = this.f.NewThisTypeNode();
		}
		var typeNode:Node = null;
		if (predicate.t != null) {
			typeNode = this.typeToTypeNode(predicate.t);
		}
		return this.f.NewTypePredicateNode(assertsModifier, parameterName, typeNode);
	}

	function typeToTypeNodeHelperWithPossibleReusableTypeNode(t:Type, typeNode:TypeNode):TypeNode {
		if (t == null) {
			return this.f.NewKeywordTypeNode(KindAnyKeyword);
		}
		if (!this.isActivelyExpanding() && typeNode != null && this.getTypeFromTypeNode(typeNode, false) == t) {
			final reused = this.tryReuseExistingNodeHelper(typeNode);
			if (reused != null) {
				this.checkTypeExpandability(t);
				return reused;
			}
		}
		return this.typeToTypeNode(t);
	}

	function typeParameterToDeclaration(parameter:Type):Node {
		final constraint = this.ch.getConstraintOfTypeParameter(parameter);
		var constraintNode:Node = null;
		if (constraint != null) {
			constraintNode = this.typeToTypeNodeHelperWithPossibleReusableTypeNode(constraint, this.ch.getConstraintDeclaration(parameter));
		}
		return this.typeParameterToDeclarationWithConstraint(parameter, constraintNode);
	}

	function symbolToTypeParameterDeclarations(symbol:Symbol):Array<Node> {
		return this.typeParametersToTypeParameterDeclarations(symbol);
	}

	function typeParametersToTypeParameterDeclarations(symbol:Symbol):Array<Node> {
		final targetSymbol = this.ch.getTargetSymbol(symbol);
		if (targetSymbol.Flags & (SymbolFlagsClass | SymbolFlagsInterface | SymbolFlagsAlias) != 0) {
			var results:Array<Node> = null;
			final params = this.ch.getLocalTypeParametersOfClassOrInterfaceOrTypeAlias(symbol);
			if (params != null) {
				for (param in params) {
					if (results == null) {
						results = [];
					}
					results.push(this.typeParameterToDeclaration(param));
				}
			}
			return results;
		} else if (targetSymbol.Flags & SymbolFlagsFunction != 0) {
			var results:Array<Node> = null;
			final params = this.ch.getTypeParametersFromDeclaration(symbol.ValueDeclaration);
			if (params != null) {
				for (param in params) {
					if (results == null) {
						results = [];
					}
					results.push(this.typeParameterToDeclaration(param));
				}
			}
			return results;
		}
		return null;
	}

	function symbolToParameterDeclaration(parameterSymbol:Symbol, preserveModifierFlags:Bool):Node {
		final b = this;
		final parameterDeclaration = Checker.getEffectiveParameterDeclaration(parameterSymbol);

		final parameterType = b.ch.getTypeOfSymbol(parameterSymbol);
		final parameterTypeNode = b.serializeTypeForDeclaration(parameterDeclaration, parameterType, parameterSymbol, true);
		var modifiers:ModifierList = null;
		if (b.ctx.flags & FlagsOmitParameterModifiers == 0 && preserveModifierFlags && parameterDeclaration != null && Ast.CanHaveModifiers(parameterDeclaration)) {
			final originals = Core.Filter(parameterDeclaration.ModifierNodes(), n -> Ast.IsModifier(n));
			final clones = Core.Map(originals, (node:Node) -> node.Clone(b.f));
			if (Core.len(clones) > 0) {
				modifiers = b.f.NewModifierList(clones);
			}
		}
		final isRest = parameterDeclaration != null && Checker.isRestParameter(parameterDeclaration) || parameterSymbol.CheckFlags & CheckFlagsRestParameter != 0;
		var dotDotDotToken:Node = null;
		if (isRest) {
			dotDotDotToken = b.f.NewToken(KindDotDotDotToken);
		}
		final name = b.parameterToParameterDeclarationName(parameterSymbol, parameterDeclaration);
		final isOptional = parameterDeclaration != null && b.ch.isOptionalParameter(parameterDeclaration) || parameterSymbol.CheckFlags & CheckFlagsOptionalParameter != 0;
		var questionToken:Node = null;
		if (isOptional) {
			questionToken = b.f.NewToken(KindQuestionToken);
		}

		final parameterNode = b.f.NewParameterDeclaration(modifiers, dotDotDotToken, name, questionToken, parameterTypeNode, /*initializer*/ null);
		b.ctx.approximateLength += Utf8.ByteLen(parameterSymbol.Name) + 3; // PORT: byte (Go len of a UTF-8 string)
		return parameterNode;
	}

	function parameterToParameterDeclarationName(parameterSymbol:Symbol, parameterDeclaration:Node):Node {
		if (parameterDeclaration == null || parameterDeclaration.Name() == null) {
			return this.newIdentifier(parameterSymbol.Name, parameterSymbol);
		}

		final name = parameterDeclaration.Name();
		switch (name.Kind) {
			case KindIdentifier:
				final cloned = this.f.DeepCloneNode(name);
				this.e.SetEmitFlags(cloned, EFNoAsciiEscaping);
				this.idToSymbol.set(cloned, parameterSymbol);
				return cloned;
			case KindQualifiedName:
				final cloned = this.f.DeepCloneNode(name.AsQualifiedName().Right);
				this.e.SetEmitFlags(cloned, EFNoAsciiEscaping);
				this.idToSymbol.set(cloned, parameterSymbol);
				return cloned;
			default:
				return this.cloneBindingName(name);
		}
	}

	function cloneBindingName(node:Node):Node {
		if (Ast.IsComputedPropertyName(node) && this.ch.isLateBindableName(node)) {
			this.trackComputedName(node.Expression(), this.ctx.enclosingDeclaration);
		}

		var visited = this.cloneBindingNameVisitor.VisitEachChild(node);

		if (Ast.IsBindingElement(visited)) {
			final bindingElement = visited.AsBindingElement();
			visited = this.f.UpdateBindingElement(bindingElement, bindingElement.DotDotDotToken, bindingElement.PropertyName, bindingElement.Name(), null /* remove initializer */);
		}

		if (!Ast.NodeIsSynthesized(visited)) {
			visited = this.f.DeepCloneNode(visited);
		}

		this.e.SetEmitFlags(visited, EFSingleLine | EFNoAsciiEscaping);
		return visited;
	}

	function serializeTypeForExpression(expr:Node):Node {
		// !!! TODO: shim, add node reuse
		final t = this.ch.instantiateType(this.ch.getWidenedType(this.ch.getRegularTypeOfExpression(expr)), this.ctx.mapper);
		return this.typeToTypeNode(t);
	}

	function serializeInferredReturnTypeForSignature(signature:Signature, returnType:Type):Node {
		final oldSuppressReportInferenceFallback = this.ctx.suppressReportInferenceFallback;
		this.ctx.suppressReportInferenceFallback = true;
		final typePredicate = this.ch.getTypePredicateOfSignature(signature);
		var returnTypeNode:Node = null;
		if (typePredicate != null) {
			var predicate:TypePredicate = null;
			if (this.ctx.mapper != null) {
				predicate = this.ch.instantiateTypePredicate(typePredicate, this.ctx.mapper);
			} else {
				predicate = typePredicate;
			}
			returnTypeNode = this.typePredicateToTypePredicateNodeHelper(predicate);
		} else {
			returnTypeNode = this.typeToTypeNode(returnType);
		}
		this.ctx.suppressReportInferenceFallback = oldSuppressReportInferenceFallback;
		return returnTypeNode;
	}

	function typePredicateToTypePredicateNodeHelper(typePredicate:TypePredicate):Node {
		var assertsModifier:Node = null;
		if (typePredicate.kind == TypePredicateKindAssertsThis || typePredicate.kind == TypePredicateKindAssertsIdentifier) {
			assertsModifier = this.f.NewToken(KindAssertsKeyword);
		} else {
			assertsModifier = null;
		}
		var parameterName:Node = null;
		if (typePredicate.kind == TypePredicateKindIdentifier || typePredicate.kind == TypePredicateKindAssertsIdentifier) {
			parameterName = this.newIdentifier(typePredicate.parameterName, null /*symbol*/);
			this.e.SetEmitFlags(parameterName, EFNoAsciiEscaping);
		} else {
			parameterName = this.f.NewThisTypeNode();
		}
		var typeNode:Node = null;
		if (typePredicate.t != null) {
			typeNode = this.typeToTypeNode(typePredicate.t);
		}
		return this.f.NewTypePredicateNode(assertsModifier, parameterName, typeNode);
	}

	function signatureToSignatureDeclarationHelper(signature:Signature, kind:Kind, options:SignatureToSignatureDeclarationOptions):Node {
		final b = this;
		var typeParameters:Array<Node> = null;

		final scope = b.enterSignatureScope(signature);
		final expandedParams = scope.a;
		final cleanup = scope.b;
		b.ctx.approximateLength += 3;
		// Usually a signature contributes a few more characters than this, but 3 is the minimum

		if (b.ctx.flags & FlagsWriteTypeArgumentsOfSignature != 0 && signature.target != null && signature.mapper != null && Core.len(signature.target.typeParameters) != 0) {
			for (parameter in signature.target.typeParameters) {
				if (typeParameters == null) {
					typeParameters = [];
				}
				typeParameters.push(b.typeToTypeNode(b.ch.instantiateType(parameter, signature.mapper)));
			}
		} else {
			if (signature.typeParameters != null) {
				for (parameter in signature.typeParameters) {
					if (typeParameters == null) {
						typeParameters = [];
					}
					typeParameters.push(b.typeParameterToDeclaration(parameter));
				}
			}
		}

		final restoreFlags = b.saveRestoreFlags();
		b.ctx.flags = b.ctx.flags & ~FlagsSuppressAnyReturnType;
		// If the expanded parameter list had a variadic in a non-trailing position, don't expand it
		var parameters = Core.Map(Core.IfElse(Core.Some(expandedParams, (p:Symbol) -> {
			return p != expandedParams[expandedParams.length - 1] && p.CheckFlags & CheckFlagsRestParameter != 0;
		}), signature.parameters, expandedParams), (parameter:Symbol) -> {
			return b.symbolToParameterDeclaration(parameter, kind == KindConstructor);
		});
		var thisParameter:Node = null;
		if (b.ctx.flags & FlagsOmitThisParameter != 0) {
			thisParameter = null;
		} else {
			thisParameter = b.tryGetThisParameterDeclaration(signature);
		}
		if (thisParameter != null) {
			final withThis:Array<Node> = [thisParameter];
			parameters = parameters == null ? withThis : withThis.concat(parameters);
		}
		restoreFlags();

		var returnTypeNode = b.serializeReturnTypeForSignature(signature, true);

		var modifiers:Array<Node> = null;
		if (options != null) {
			modifiers = options.modifiers;
		}
		if ((kind == KindConstructorType) && signature.flags & SignatureFlagsAbstract != 0) {
			final flags = Ast.ModifiersToFlags(modifiers);
			modifiers = Ast.CreateModifiersFromModifierFlags(flags | ModifierFlagsAbstract, k -> b.f.NewModifier(k));
		}

		final paramList = b.f.NewNodeList(parameters);
		var typeParamList:NodeList = null;
		if (Core.len(typeParameters) != 0) {
			typeParamList = b.f.NewNodeList(typeParameters);
		}
		var modifierList:ModifierList = null;
		if (Core.len(modifiers) > 0) {
			modifierList = b.f.NewModifierList(modifiers);
		}
		var name:Node = null;
		if (options != null) {
			name = options.name;
		}
		if (name == null) {
			name = b.f.NewIdentifier("");
		}

		var node:Node = null;
		switch (kind) {
			case KindCallSignature:
				node = b.f.NewCallSignatureDeclaration(typeParamList, paramList, returnTypeNode);
			case KindConstructSignature:
				node = b.f.NewConstructSignatureDeclaration(typeParamList, paramList, returnTypeNode);
			case KindMethodSignature:
				var questionToken:Node = null;
				if (options != null) {
					questionToken = options.questionToken;
				}
				node = b.f.NewMethodSignatureDeclaration(modifierList, name, questionToken, typeParamList, paramList, returnTypeNode);
			case KindMethodDeclaration:
				node = b.f.NewMethodDeclaration(modifierList, null /*asteriskToken*/, name, null /*questionToken*/, typeParamList, paramList, returnTypeNode, null /*fullSignature*/, null /*body*/);
			case KindConstructor:
				node = b.f.NewConstructorDeclaration(modifierList, null /*typeParamList*/, paramList, null /*returnTypeNode*/, null /*fullSignature*/, null /*body*/);
			case KindGetAccessor:
				node = b.f.NewGetAccessorDeclaration(modifierList, name, null /*typeParamList*/, paramList, returnTypeNode, null /*fullSignature*/, null /*body*/);
			case KindSetAccessor:
				node = b.f.NewSetAccessorDeclaration(modifierList, name, null /*typeParamList*/, paramList, null /*returnTypeNode*/, null /*fullSignature*/, null /*body*/);
			case KindIndexSignature:
				node = b.f.NewIndexSignatureDeclaration(modifierList, paramList, returnTypeNode);
			// !!! JSDoc Support
			// case kind == ast.KindJSDocFunctionType:
			// 	node = b.f.NewJSDocFunctionType(parameters, returnTypeNode)
			case KindFunctionType:
				if (returnTypeNode == null) {
					returnTypeNode = b.f.NewTypeReferenceNode(b.f.NewIdentifier(""), null);
				}
				node = b.f.NewFunctionTypeNode(typeParamList, paramList, returnTypeNode);
			case KindConstructorType:
				if (returnTypeNode == null) {
					returnTypeNode = b.f.NewTypeReferenceNode(b.f.NewIdentifier(""), null);
				}
				node = b.f.NewConstructorTypeNode(modifierList, typeParamList, paramList, returnTypeNode);
			case KindFunctionDeclaration:
				// TODO: assert name is Identifier
				node = b.f.NewFunctionDeclaration(modifierList, null /*asteriskToken*/, name, typeParamList, paramList, returnTypeNode, null /*fullSignature*/, null /*body*/);
			case KindFunctionExpression:
				// TODO: assert name is Identifier
				node = b.f.NewFunctionExpression(modifierList, null /*asteriskToken*/, name, typeParamList, paramList, returnTypeNode, null /*fullSignature*/,
					b.f.NewBlock(b.f.NewNodeList([]), false));
			case KindArrowFunction:
				node = b.f.NewArrowFunction(modifierList, typeParamList, paramList, returnTypeNode, null /*fullSignature*/, null /*equalsGreaterThanToken*/,
					b.f.NewBlock(b.f.NewNodeList([]), false));
			default:
				throw "Unhandled kind in signatureToSignatureDeclarationHelper";
		}

		// !!! TODO: Smuggle type arguments of signatures out for quickinfo
		// if typeArguments != nil {
		// 	node.TypeArguments = b.f.NewNodeList(typeArguments)
		// }

		cleanup();
		return node;
	}

	function tryGetThisParameterDeclaration(signature:Signature):Node {
		if (signature.thisParameter != null) {
			return this.symbolToParameterDeclaration(signature.thisParameter, false);
		}
		if (signature.declaration != null && Ast.IsInJSFile(signature.declaration)) {
			// !!! JSDoc Support
			// thisTag := getJSDocThisTag(signature.declaration)
			// if (thisTag && thisTag.typeExpression) {
			// 	return factory.createParameterDeclaration(
			// 		/*modifiers*/ undefined,
			// 		/*dotDotDotToken*/ undefined,
			// 		"this",
			// 		/*questionToken*/ undefined,
			// 		typeToTypeNodeHelper(getTypeFromTypeNode(context, thisTag.typeExpression), context),
			// 	);
			// }
		}
		return null;
	}

	/**
	* Serializes the return type of the signature by first trying to use the syntactic printer if possible and falling back to the checker type if not.
	 */
	function serializeReturnTypeForSignature(signature:Signature, tryReuse:Bool):Node {
		final b = this;
		final suppressAny = b.ctx.flags & FlagsSuppressAnyReturnType != 0;
		final restoreFlags = b.saveRestoreFlags();
		if (suppressAny) {
			b.ctx.flags = b.ctx.flags & ~FlagsSuppressAnyReturnType; // suppress only toplevel `any`s
		}
		var returnTypeNode:Node = null;

		var returnType:Type = null;
		if (signature.declaration != null && !Ast.NodeIsSynthesized(signature.declaration)) {
			final symbol = b.ch.getSymbolOfDeclaration(signature.declaration);
			returnType = b.ctx.enclosingSymbolTypes.get(Ast.GetSymbolId(symbol));
			if (returnType == null) {
				returnType = b.ch.instantiateType(b.ch.getReturnTypeOfSignature(signature), b.ctx.mapper);
			}
		} else {
			returnType = b.ch.getReturnTypeOfSignature(signature);
		}
		if (!(suppressAny && Checker.IsTypeAny(returnType))) {
			if (!b.isActivelyExpanding() && tryReuse && b.ctx.enclosingDeclaration != null && signature.declaration != null && !Ast.NodeIsSynthesized(signature.declaration)) {
				final declarationSymbol = b.ch.getSymbolOfDeclaration(signature.declaration);
				final restore = b.addSymbolTypeToContext(declarationSymbol, returnType);
				var pt = ts.pseudochecker.Lookup.GetReturnTypeOfSignature(b.pc, signature.declaration);
				if (b.pseudoTypeEquivalentToType(pt, returnType, false, !b.ctx.suppressReportInferenceFallback)) {
					// Also verify the pseudo type captures any inferred type predicate, not just the boolean return type.
					// The pseudochecker is unaware of inferred type predicates, so it produces boolean where
					// the checker infers e.g. `x is string`.
					final typePredicate = b.ch.getTypePredicateOfSignature(signature);
					if (typePredicate != null && !b.pseudoReturnTypeMatchesPredicate(pt, typePredicate)) {
						if (!b.ctx.suppressReportInferenceFallback) {
							b.ctx.tracker.ReportInferenceFallback(signature.declaration);
						}
						pt = null;
					}
					if (pt != null) {
						// !!! TODO: If annotated type node is a reference with insufficient type arguments, we should still fall back to type serialization
						// see: canReuseTypeNodeAnnotation in strada for context
						returnTypeNode = b.pseudoTypeToNodeWithCheckerFallback(pt, returnType);
					}
				}
				restore();
			}
			if (returnTypeNode == null) {
				returnTypeNode = b.serializeInferredReturnTypeForSignature(signature, returnType);
			}
		}

		if (returnTypeNode == null && !suppressAny) {
			returnTypeNode = b.f.NewKeywordTypeNode(KindAnyKeyword);
		}
		restoreFlags();
		return returnTypeNode;
	}

	function isTriviallySerializableComputedName(e:Node):Bool {
		final shapeGood = e != null && e.Name() != null && Ast.IsComputedPropertyName(e.Name()) && Ast.IsEntityNameExpression(e.Name().Expression());
		if (!shapeGood) {
			return false;
		}
		// TODO: going through emit resolver here is weird. Relayer these APIs.
		return this.ch.GetEmitResolver().isEntityNameVisible(e.Name().Expression(), this.ctx.enclosingDeclaration, false).Accessibility == SymbolAccessibilityAccessible;
	}

	function indexInfoToObjectComputedNamesOrSignatureDeclaration(indexInfo:IndexInfo, typeNode:TypeNode):Array<Node> {
		final b = this;
		if (Core.len(indexInfo.components) > 0) {
			// Index info is derived from object or class computed property names (plus explicit named members) - we can clone those instead of writing out the result computed index signature
			final allComponentComputedNamesSerializable = b.ctx.enclosingDeclaration != null
				&& Core.Every(indexInfo.components, (e:Node) -> b.isTriviallySerializableComputedName(e));
			if (allComponentComputedNamesSerializable) {
				// Only use computed name serialization form if all components are visible and take the `a.b.c` form
				final newComponents = Core.Filter(indexInfo.components, (c:Node) -> {
					// skip late bound props that contribute to the index signature - they'll be created by property creation anyway
					return !b.ch.hasLateBindableName(c);
				});
				var bailed = false;
				final results = Core.Map(newComponents, (e:Node) -> {
					final name = b.reuseNode(e.Name());
					if (name != null) {
						// Still need to track visibility even if we've already checked it to paint references as used
						b.trackComputedName(e.Name().Expression(), b.ctx.enclosingDeclaration);
						var mods:ModifierList = null;
						if (indexInfo.isReadonly) {
							mods = b.f.NewModifierList([b.f.NewModifier(KindReadonlyKeyword)]);
						}
						var postfixToken:Node = null;
						if (e.PostfixToken() != null) {
							postfixToken = e.PostfixToken().Clone(b.f);
						}
						var currentTypeNode:Node = null;
						if (typeNode != null) {
							currentTypeNode = b.f.DeepCloneNode(typeNode);
						} else {
							currentTypeNode = b.typeToTypeNode(b.ch.getTypeOfSymbol(e.Symbol()));
						}
						final sig = b.f.NewPropertySignatureDeclaration(mods, name, postfixToken, currentTypeNode, null);
						sig.Loc = e.Loc;
						return sig;
					}
					bailed = true;
					return (null : Node);
				});
				if (!bailed) {
					return results;
				}
			}
		}
		return [b.indexInfoToIndexSignatureDeclarationHelper(indexInfo, typeNode)];
	}

	function indexInfoToIndexSignatureDeclarationHelper(indexInfo:IndexInfo, typeNode:TypeNode):Node {
		final name = Checker.getNameFromIndexInfo(indexInfo);
		final indexerTypeNode = this.typeToTypeNode(indexInfo.keyType);

		final indexingParameter = this.f.NewParameterDeclaration(null, null, this.newIdentifier(name, null /*symbol*/), null, indexerTypeNode, null);
		if (typeNode == null) {
			if (indexInfo.valueType == null) {
				typeNode = this.f.NewKeywordTypeNode(KindAnyKeyword);
			} else {
				typeNode = this.typeToTypeNode(indexInfo.valueType);
			}
		}
		if (indexInfo.valueType == null && this.ctx.flags & FlagsAllowEmptyIndexInfoType == 0) {
			this.ctx.encounteredError = true;
		}
		this.ctx.approximateLength += Utf8.ByteLen(name) + 4; // PORT: byte (Go len of a UTF-8 string)
		var modifiers:ModifierList = null;
		if (indexInfo.isReadonly) {
			this.ctx.approximateLength += 9;
			modifiers = this.f.NewModifierList([this.f.NewModifier(KindReadonlyKeyword)]);
		}
		return this.f.NewIndexSignatureDeclaration(modifiers, this.f.NewNodeList([indexingParameter]), typeNode);
	}

	/**
	* Unlike `typeToTypeNodeHelper`, this handles setting up the `AllowUniqueESSymbolType` flag
	* so a `unique symbol` is returned when appropriate for the input symbol, rather than `typeof sym`
	* @param declaration - The preferred declaration to pull existing type nodes from (the symbol will be used as a fallback to find any annotated declaration)
	* @param type - The type to write; an existing annotation must match this type if it's used, otherwise this is the type serialized as a new type node
	* @param symbol - The symbol is used both to find an existing annotation if declaration is not provided, and to determine if `unique symbol` should be printed
	 */
	function serializeTypeForDeclaration(declaration:Declaration, t:Type, symbol:Symbol, tryReuse:Bool):Node {
		final b = this;
		if (declaration == null) {
			if (symbol != null) {
				declaration = symbol.ValueDeclaration;
				if (declaration == null) {
					// TODO: prefer annotated declarations like in strada (but does this ever even matter in practice? All callers should supply a declaration!)
					declaration = Core.FirstOrNil(symbol.Declarations);
				}
			}
		}
		if (symbol == null) {
			symbol = b.ch.getSymbolOfDeclaration(declaration);
		}
		if (t == null) {
			t = b.ctx.enclosingSymbolTypes.get(Ast.GetSymbolId(symbol));
			if (t == null) {
				if (symbol.Flags & SymbolFlagsAccessor != 0 && declaration.Kind == KindSetAccessor) {
					t = b.ch.instantiateType(b.ch.getWriteTypeOfSymbol(symbol), b.ctx.mapper);
				} else if (symbol != null && (symbol.Flags & (SymbolFlagsTypeLiteral | SymbolFlagsSignature) == 0)) {
					t = b.ch.instantiateType(b.ch.getWidenedLiteralType(b.ch.getTypeOfSymbol(symbol)), b.ctx.mapper);
				} else {
					t = b.ch.errorType;
				}
			}
		}

		// !!! TODO: JSDoc, getEmitResolver call is unfortunate layering for the helper - hoist it into checker
		final requiresAddingUndefined = declaration != null
			&& (Ast.IsParameterDeclaration(declaration) || Ast.IsPropertySignatureDeclaration(declaration) || Ast.IsPropertyDeclaration(declaration))
			&& b.ch.GetEmitResolver().requiresAddingImplicitUndefined(declaration, symbol, b.ctx.enclosingDeclaration);
		final addUndefinedForParameter = requiresAddingUndefined && (Ast.IsParameterDeclaration(declaration) /*|| ast.IsJSDocParameterTag(declaration)*/);
		if (addUndefinedForParameter) {
			t = b.ch.getOptionalType(t, false);
		}

		final restoreFlags = b.saveRestoreFlags();
		if (t.flags & TypeFlagsUniqueESSymbol != 0 && t.symbol == symbol && (b.ctx.enclosingDeclaration == null || Core.Some(symbol.Declarations, (d:Declaration) -> {
			return Ast.GetSourceFileOfNode(d) == b.ctx.enclosingFile;
		}))) {
			b.ctx.flags = b.ctx.flags | FlagsAllowUniqueESSymbolType;
		}
		var result:Node = null;
		var reportedInferenceFallback = false;
		// !!! expandable hover support
		if (!b.isActivelyExpanding() && tryReuse && b.ctx.enclosingDeclaration != null && declaration != null
			&& (Ast.IsAccessor(declaration)
				|| (Ast.HasInferredType(declaration) && !Ast.NodeIsSynthesized(declaration) && (t.ObjectFlags() & ObjectFlagsRequiresWidening) == 0))) {
			final remove = b.addSymbolTypeToContext(symbol, t);
			var pt:PseudoType = null;
			if (Ast.IsAccessor(declaration)) {
				pt = ts.pseudochecker.Lookup.GetTypeOfAccessor(b.pc, declaration);
			} else {
				pt = ts.pseudochecker.Lookup.GetTypeOfDeclaration(b.pc, declaration);
			}
			if ((pt == null || pt.Kind == PseudoTypeKindNoResult) && Ast.IsBinaryExpression(declaration)) {
				final decl = Core.Find(symbol.Declarations, d -> Checker.hasTypeAnnotation(d));
				if (decl != null) {
					// Binary expressions have a first-in-wins type annotation system. The first one with an annotation supplies the type for the rest.
					pt = ts.pseudochecker.Lookup.GetTypeOfDeclaration(b.pc, decl);
				}
			}
			final reportErrors = !b.ctx.suppressReportInferenceFallback;
			if (b.pseudoTypeEquivalentToType(pt, t,
				!requiresAddingUndefined
				&& (Ast.IsParameterDeclaration(declaration) || Ast.IsPropertySignatureDeclaration(declaration) || Ast.IsPropertyDeclaration(declaration))
				&& Checker.isOptionalDeclaration(declaration),
				reportErrors)) {
				// !!! TODO: If annotated type node is a reference with insufficient type arguments, we should still fall back to type serialization
				// see: canReuseTypeNodeAnnotation in strada for context
				final ptt = b.pseudoTypeToType(pt);
				if (ptt != null && requiresAddingUndefined && Checker.containsNonMissingUndefinedType(b.ch, t) && !Checker.containsNonMissingUndefinedType(b.ch, ptt)) {
					pt = Pseudochecker.NewPseudoTypeUnion([pt, Pseudochecker.PseudoTypeUndefined]);
				}
				result = b.pseudoTypeToNodeWithCheckerFallback(pt, t);
			} else {
				// Equivalence failed; if errors from inferred-with-errors pseudo types were
				// reported, note it so we can suppress nested errors during the fallback
				// typeToTypeNode serialization (mirroring the suppression that
				// pseudoTypeToNodeWithCheckerFallback provides).
				reportedInferenceFallback = reportErrors && pt.Kind == PseudoTypeKindInferred && Core.len(pt.AsPseudoTypeInferred().ErrorNodes) > 0;
				var shouldAddUndefined = false;
				if (requiresAddingUndefined) {
					final ptt = b.pseudoTypeToType(pt);
					if (ptt != null) {
						shouldAddUndefined = !Checker.containsNonMissingUndefinedType(b.ch, ptt);
					} else {
						shouldAddUndefined = !Pseudochecker.CouldAlreadyReferToUndefinedType(pt);
					}
				}
				if (shouldAddUndefined) {
					pt = Pseudochecker.NewPseudoTypeUnion([pt, Pseudochecker.PseudoTypeUndefined]);
					if (b.pseudoTypeEquivalentToType(pt, t, false, reportErrors)) {
						result = b.pseudoTypeToNodeWithCheckerFallback(pt, t);
						reportedInferenceFallback = false;
					}
				}
			}
			remove();
		}
		if (result == null) {
			if (reportedInferenceFallback) {
				final oldSuppress = b.ctx.suppressReportInferenceFallback;
				b.ctx.suppressReportInferenceFallback = true;
				result = b.typeToTypeNode(t);
				b.ctx.suppressReportInferenceFallback = oldSuppress;
			} else {
				result = b.typeToTypeNode(t);
			}
		}
		restoreFlags();
		if (result == null) {
			return b.f.NewKeywordTypeNode(KindAnyKeyword);
		}
		return result;
	}

	function shouldUsePlaceholderForProperty(propertySymbol:Symbol):Bool {
		// Use placeholders for reverse mapped types we've either
		// (1) already descended into, or
		// (2) are nested reverse mappings within a mapping over a non-anonymous type, or
		// (3) are deeply nested properties that originate from the same mapped type.
		// Condition (2) is a restriction mostly just to
		// reduce the blowup in printback size from doing, eg, a deep reverse mapping over `Window`.
		// Since anonymous types usually come from expressions, this allows us to preserve the output
		// for deep mappings which likely come from expressions, while truncating those parts which
		// come from mappings over library functions.
		// Condition (3) limits printing of possibly infinitely deep reverse mapped types.
		if (propertySymbol.CheckFlags & CheckFlagsReverseMapped == 0) {
			return false;
		}
		// (1)
		if (Slices.Contains(this.ctx.reverseMappedStack, propertySymbol)) {
			return true;
		}
		// (2)
		if (Core.len(this.ctx.reverseMappedStack) > 0) {
			final last = this.ctx.reverseMappedStack[this.ctx.reverseMappedStack.length - 1];
			if (this.ch.ReverseMappedSymbolLinks.Has(last)) {
				final links = this.ch.ReverseMappedSymbolLinks.TryGet(last);
				final propertyType = links.propertyType;
				if (propertyType != null && propertyType.objectFlags & ObjectFlagsAnonymous == 0) {
					return true;
				}
			}
		}
		// (3) - we only inspect the last MAX_REVERSE_MAPPED_NESTING_INSPECTION_DEPTH elements of the
		// stack for approximate matches to catch tight infinite loops
		// TODO: Why? Reasoning lost to time. this could probably stand to be improved?
		if (Core.len(this.ctx.reverseMappedStack) < Checker.MAX_REVERSE_MAPPED_NESTING_INSPECTION_DEPTH) {
			return false;
		}
		if (!this.ch.ReverseMappedSymbolLinks.Has(propertySymbol)) {
			return false;
		}
		final propertyLinks = this.ch.ReverseMappedSymbolLinks.TryGet(propertySymbol);
		final propMappedType = propertyLinks.mappedType;
		if (propMappedType == null || propMappedType.symbol == null) {
			return false;
		}
		for (i in 0...this.ctx.reverseMappedStack.length) {
			if (i > Checker.MAX_REVERSE_MAPPED_NESTING_INSPECTION_DEPTH) {
				break;
			}
			final prop = this.ctx.reverseMappedStack[this.ctx.reverseMappedStack.length - 1 - i];
			if (this.ch.ReverseMappedSymbolLinks.Has(prop)) {
				final links = this.ch.ReverseMappedSymbolLinks.TryGet(prop);
				final mappedType = links.mappedType;
				if (mappedType != null && mappedType.symbol == propMappedType.symbol) {
					return true;
				}
			}
		}
		return false;
	}

	function trackComputedName(accessExpression:Node, enclosingDeclaration:Node):Void {
		// get symbol of the first identifier of the entityName
		final firstIdentifier = Ast.GetFirstIdentifier(accessExpression);
		final name = this.ch.resolveName(enclosingDeclaration, firstIdentifier.Text(), SymbolFlagsValue | SymbolFlagsExportValue, null /*nameNotFoundMessage*/, true /*isUse*/, false);
		if (name != null) {
			this.ctx.tracker.TrackSymbol(name, enclosingDeclaration, SymbolFlagsValue);
		} else {
			// Name does not resolve at target location, track symbol at dest location (should be inaccessible)
			final fallback = this.ch.resolveName(firstIdentifier, firstIdentifier.Text(), SymbolFlagsValue | SymbolFlagsExportValue, null /*nameNotFoundMessage*/, true /*isUse*/, false);
			if (fallback != null) {
				this.ctx.tracker.TrackSymbol(fallback, enclosingDeclaration, SymbolFlagsValue);
			}
		}
	}

	function createPropertyNameNodeForIdentifierOrLiteral(name:std.String, singleQuote:Bool, stringNamed:Bool, isMethod:Bool, symbol:Symbol):Node {
		switch (Checker.classifyPropertyName(name, stringNamed, isMethod)) {
			case propertyNameNodeKindIdentifier:
				return this.newIdentifier(name, symbol);
			case propertyNameNodeKindNumericLiteral:
				return this.f.NewNumericLiteral(name, TokenFlagsNone);
			default:
				return this.f.NewStringLiteral(name, Core.IfElse(singleQuote, TokenFlagsSingleQuote, TokenFlagsNone));
		}
	}

	function isStringNamed(d:Declaration):Bool {
		final name = Ast.GetNameOfDeclaration(d);
		if (name == null) {
			return false;
		}
		if (Ast.IsComputedPropertyName(name)) {
			final t = this.ch.checkExpression(name.Expression());
			return t.flags & TypeFlagsStringLike != 0;
		}
		if (Ast.IsElementAccessExpression(name)) {
			final t = this.ch.checkExpression(name.AsElementAccessExpression().ArgumentExpression);
			return t.flags & TypeFlagsStringLike != 0;
		}
		return Ast.IsStringLiteral(name);
	}

	function isSingleQuotedStringNamed(d:Declaration):Bool {
		final name = Ast.GetNameOfDeclaration(d);
		return name != null && Ast.IsStringLiteral(name) && name.AsStringLiteral().TokenFlags & TokenFlagsSingleQuote != 0;
	}

	function getPropertyNameNodeForSymbol(symbol:Symbol):Node {
		// For hash-private names, clone the original private identifier from the declaration
		if (symbol.ValueDeclaration != null) {
			final declName = symbol.ValueDeclaration.Name();
			if (declName != null && Ast.IsPrivateIdentifier(declName)) {
				return this.f.DeepCloneNode(declName);
			}
		}
		final stringNamed = Core.len(symbol.Declarations) != 0 && Core.Every(symbol.Declarations, (d:Node) -> this.isStringNamed(d));
		final singleQuote = Core.len(symbol.Declarations) != 0 && Core.Every(symbol.Declarations, (d:Node) -> this.isSingleQuotedStringNamed(d));
		final isMethod = symbol.Flags & SymbolFlagsMethod != 0;
		final fromNameType = this.getPropertyNameNodeForSymbolFromNameType(symbol, singleQuote, stringNamed, isMethod);
		if (fromNameType != null) {
			return fromNameType;
		}

		var name = symbol.Name;
		final privateNamePrefix = Ast.InternalSymbolNamePrefix + "#";
		if (StringTools.startsWith(name, privateNamePrefix)) {
			// symbol IDs are unstable - replace #nnn# with #private#
			name = name.substring(privateNamePrefix.length);
			name = Strings.TrimLeftFunc(name, ch -> Stringutil.IsDigit(ch));
			name = "__#private" + name;
		}

		return this.createPropertyNameNodeForIdentifierOrLiteral(name, singleQuote, stringNamed, isMethod, symbol);
	}

	// See getNameForSymbolFromNameType for a stringy equivalent
	function getPropertyNameNodeForSymbolFromNameType(symbol:Symbol, singleQuote:Bool, stringNamed:Bool, isMethod:Bool):Node {
		if (!this.ch.valueSymbolLinks.Has(symbol)) {
			return null;
		}
		final nameType = this.ch.valueSymbolLinks.TryGet(symbol).nameType;
		if (nameType == null) {
			return null;
		}
		if (nameType.flags & TypeFlagsStringOrNumberLiteral != 0) {
			var name = "";
			final value:Any = nameType.AsLiteralType().value;
			if (Std.isOfType(value, Float)) {
				name = ts.jsnum.String_.String((value : Float));
			} else if (Std.isOfType(value, std.String)) {
				name = (value : std.String);
			}
			if (!Scanner.IsIdentifierText(name, LanguageVariantStandard) && (stringNamed || !Checker.isNumericLiteralName(name))) {
				final node = this.f.NewStringLiteral(name, Core.IfElse(singleQuote, TokenFlagsSingleQuote, TokenFlagsNone));
				return node;
			}
			if (Checker.isNumericLiteralName(name) && StringTools.fastCodeAt(name, 0) == '-'.code) {
				return this.f.NewComputedPropertyName(this.f.NewPrefixUnaryExpression(KindMinusToken, this.f.NewNumericLiteral(name.substring(1), TokenFlagsNone)));
			}
			return this.createPropertyNameNodeForIdentifierOrLiteral(name, singleQuote, stringNamed, isMethod, symbol);
		}
		if (nameType.flags & TypeFlagsUniqueESSymbol != 0) {
			return this.f.NewComputedPropertyName(this.symbolToExpression(nameType.AsUniqueESSymbolType().symbol, SymbolFlagsValue));
		}
		return null;
	}

	function addPropertyToElementList(propertySymbol:Symbol, typeElements:Array<TypeElement>):Array<TypeElement> {
		final b = this;
		// PORT: Go append onto a possibly-nil, caller-owned slice; callers reassign the result.
		final append = (n:Node) -> {
			if (typeElements == null) {
				typeElements = [];
			}
			typeElements.push(n);
		};
		final propertyIsReverseMapped = propertySymbol.CheckFlags & CheckFlagsReverseMapped != 0;
		var propertyType:Type = null;
		if (b.shouldUsePlaceholderForProperty(propertySymbol)) {
			propertyType = b.ch.anyType;
		} else {
			propertyType = b.ch.getNonMissingTypeOfSymbol(propertySymbol);
		}
		final saveEnclosingDeclaration = b.ctx.enclosingDeclaration;
		b.ctx.enclosingDeclaration = null;
		if (Checker.isLateBoundName(propertySymbol.Name)) {
			if (Core.len(propertySymbol.Declarations) > 0) {
				final decl = propertySymbol.Declarations[0];
				if (b.ch.hasLateBindableName(decl)) {
					if (Ast.IsBinaryExpression(decl)) {
						final name = Ast.GetNameOfDeclaration(decl);
						if (name != null && Ast.IsElementAccessExpression(name)
							&& Ast.IsPropertyAccessEntityNameExpression(name.AsElementAccessExpression().ArgumentExpression, false /*allowJs*/)) {
							b.trackComputedName(name.AsElementAccessExpression().ArgumentExpression, saveEnclosingDeclaration);
						}
					} else {
						b.trackComputedName(decl.Name().Expression(), saveEnclosingDeclaration);
					}
				}
			} else {
				b.ctx.tracker.ReportNonSerializableProperty(b.ch.symbolToString(propertySymbol));
			}
		}
		if (propertySymbol.ValueDeclaration != null) {
			b.ctx.enclosingDeclaration = propertySymbol.ValueDeclaration;
		} else if (Core.len(propertySymbol.Declarations) > 0 && propertySymbol.Declarations[0] != null) {
			b.ctx.enclosingDeclaration = propertySymbol.Declarations[0];
		} else {
			b.ctx.enclosingDeclaration = saveEnclosingDeclaration;
		}
		final propertyName = b.getPropertyNameNodeForSymbol(propertySymbol);
		b.ctx.enclosingDeclaration = saveEnclosingDeclaration;
		b.ctx.approximateLength += Utf8.ByteLen(Ast.SymbolName(propertySymbol)) + 1; // PORT: byte (Go len of a UTF-8 string)

		if (propertySymbol.Flags & SymbolFlagsAccessor != 0) {
			final writeType = b.ch.getWriteTypeOfSymbol(propertySymbol);
			if (!b.ch.isErrorType(propertyType) && !b.ch.isErrorType(writeType)) {
				final propDeclaration = Ast.GetDeclarationOfKind(propertySymbol, KindPropertyDeclaration);
				if (propertyType != writeType || propertySymbol.Parent != null && propertySymbol.Parent.Flags & SymbolFlagsClass != 0 && propDeclaration == null) {
					final symbolMapper = b.ch.valueSymbolLinks.Get(propertySymbol).mapper;
					final getterDeclaration = Ast.GetDeclarationOfKind(propertySymbol, KindGetAccessor);
					if (getterDeclaration != null) {
						var getterSignature = b.ch.getSignatureFromDeclaration(getterDeclaration);
						if (symbolMapper != null) {
							getterSignature = b.ch.instantiateSignature(getterSignature, symbolMapper);
						}
						final opts = new SignatureToSignatureDeclarationOptions();
						opts.name = propertyName;
						final getter = b.signatureToSignatureDeclarationHelper(getterSignature, KindGetAccessor, opts);
						b.setCommentRange(getter, getterDeclaration);
						append(getter);
					}
					final setterDeclaration = Ast.GetDeclarationOfKind(propertySymbol, KindSetAccessor);
					if (setterDeclaration != null) {
						var setterSignature = b.ch.getSignatureFromDeclaration(setterDeclaration);
						if (symbolMapper != null) {
							setterSignature = b.ch.instantiateSignature(setterSignature, symbolMapper);
						}
						final opts = new SignatureToSignatureDeclarationOptions();
						opts.name = propertyName;
						final setter = b.signatureToSignatureDeclarationHelper(setterSignature, KindSetAccessor, opts);
						b.setCommentRange(setter, setterDeclaration);
						append(setter);
					}
					return typeElements;
				} else if (propertySymbol.Parent != null && propertySymbol.Parent.Flags & SymbolFlagsClass != 0 && propDeclaration != null
					&& Core.Find(propDeclaration.ModifierNodes(), (m:Node) -> {
						return m.Kind == KindAccessorKeyword;
					}) != null) {
					final fakeGetterSignature = b.ch.newSignature(SignatureFlagsNone, null, null, null, null, propertyType, null, 0);
					final getterOpts = new SignatureToSignatureDeclarationOptions();
					getterOpts.name = propertyName;
					final fakeGetterDeclaration = b.signatureToSignatureDeclarationHelper(fakeGetterSignature, KindGetAccessor, getterOpts);
					b.setCommentRange(fakeGetterDeclaration, propDeclaration);
					append(fakeGetterDeclaration);

					final setterParam = b.ch.newSymbol(SymbolFlagsFunctionScopedVariable, "arg");
					b.ch.valueSymbolLinks.Get(setterParam).resolvedType = writeType;
					final fakeSetterSignature = b.ch.newSignature(SignatureFlagsNone, null, null, null, [setterParam], b.ch.voidType, null, 0);
					final setterOpts = new SignatureToSignatureDeclarationOptions();
					setterOpts.name = propertyName;
					final fakeSetterDeclaration = b.signatureToSignatureDeclarationHelper(fakeSetterSignature, KindSetAccessor, setterOpts);
					append(fakeSetterDeclaration);
					return typeElements;
				}
			}
		}

		var optionalToken:Node = null;
		if (propertySymbol.Flags & SymbolFlagsOptional != 0) {
			optionalToken = b.f.NewToken(KindQuestionToken);
		} else {
			optionalToken = null;
		}
		if (propertySymbol.Flags & (SymbolFlagsFunction | SymbolFlagsMethod) != 0 && Core.len(b.ch.getPropertiesOfObjectType(propertyType)) == 0
			&& !b.ch.isReadonlySymbol(propertySymbol)) {
			final signatures = b.ch.getSignaturesOfType(b.ch.filterType(propertyType, (t:Type) -> {
				return t.flags & TypeFlagsUndefined == 0;
			}), SignatureKindCall);
			if (signatures != null) {
				for (signature in signatures) {
					final opts = new SignatureToSignatureDeclarationOptions();
					opts.name = propertyName;
					opts.questionToken = optionalToken;
					final methodDeclaration = b.signatureToSignatureDeclarationHelper(signature, KindMethodSignature, opts);
					b.setCommentRange(methodDeclaration, Core.Coalesce(signature.declaration, propertySymbol.ValueDeclaration));
					append(methodDeclaration);
				}
			}
			if (Core.len(signatures) != 0 || optionalToken == null) {
				return typeElements;
			}
		}
		var propertyTypeNode:Node = null;
		if (b.shouldUsePlaceholderForProperty(propertySymbol)) {
			propertyTypeNode = b.createElidedInformationPlaceholder();
		} else {
			if (propertyIsReverseMapped) {
				if (b.ctx.reverseMappedStack == null) {
					b.ctx.reverseMappedStack = [];
				}
				b.ctx.reverseMappedStack.push(propertySymbol);
			}
			if (propertyType != null) {
				propertyTypeNode = b.serializeTypeForDeclaration(null /*declaration*/, propertyType, propertySymbol, true);
			} else {
				propertyTypeNode = b.f.NewKeywordTypeNode(KindAnyKeyword);
			}
			if (propertyIsReverseMapped) {
				b.ctx.reverseMappedStack.pop();
			}
		}

		var modifiers:ModifierList = null;
		if (b.ch.isReadonlySymbol(propertySymbol)) {
			modifiers = b.f.NewModifierList([b.f.NewModifier(KindReadonlyKeyword)]);
			b.ctx.approximateLength += 9;
		}
		final propertySignature = b.f.NewPropertySignatureDeclaration(modifiers, propertyName, optionalToken, propertyTypeNode, null);

		b.setCommentRange(propertySignature, propertySymbol.ValueDeclaration);
		append(propertySignature);

		return typeElements;
	}

	function createTypeNodesFromResolvedType(resolvedType:StructuredType):NodeList {
		if (this.checkTruncationLength()) {
			if (this.ctx.flags & FlagsNoTruncation != 0) {
				final elem = this.f.NewNotEmittedTypeElement();
				return this.f.NewNodeList([this.e.AddSyntheticTrailingComment(elem, KindMultiLineCommentTrivia, "elided", false /*hasTrailingNewLine*/)]);
			}
			return this.f.NewNodeList([this.f.NewPropertySignatureDeclaration(null, this.f.NewIdentifier("..."), null, null, null)]);
		}
		var typeElements:Array<TypeElement> = null;
		final callSignatures = resolvedType.CallSignatures();
		if (callSignatures != null) {
			for (signature in callSignatures) {
				if (typeElements == null) {
					typeElements = [];
				}
				typeElements.push(this.signatureToSignatureDeclarationHelper(signature, KindCallSignature, null));
			}
		}
		final constructSignatures = resolvedType.ConstructSignatures();
		if (constructSignatures != null) {
			for (signature in constructSignatures) {
				if (signature.flags & SignatureFlagsAbstract != 0) {
					continue;
				}
				if (typeElements == null) {
					typeElements = [];
				}
				typeElements.push(this.signatureToSignatureDeclarationHelper(signature, KindConstructSignature, null));
			}
		}
		if (resolvedType.indexInfos != null) {
			for (info in resolvedType.indexInfos) {
				typeElements = Slices.Concat(typeElements,
					this.indexInfoToObjectComputedNamesOrSignatureDeclaration(info,
						Core.IfElse(resolvedType.objectFlags & ObjectFlagsReverseMapped != 0, this.createElidedInformationPlaceholder(), null)));
			}
		}

		final properties = resolvedType.properties;
		if (Core.len(properties) == 0) {
			return this.f.NewNodeList(typeElements);
		}

		var i = 0;
		for (propertySymbol in properties) {
			if (Checker.isExpanding(this.ctx) && propertySymbol.Flags & SymbolFlagsPrototype != 0) {
				continue;
			}
			i++;
			if (this.ctx.flags & FlagsWriteClassExpressionAsTypeLiteral != 0) {
				if (propertySymbol.Flags & SymbolFlagsPrototype != 0) {
					continue;
				}
				if (Checker.getDeclarationModifierFlagsFromSymbol(propertySymbol) & (ModifierFlagsPrivate | ModifierFlagsProtected) != 0) {
					this.ctx.tracker.ReportPrivateInBaseOfClassExpression(propertySymbol.Name);
				}
				if (Checker.IsPrivateIdentifierSymbol(propertySymbol)) {
					this.ctx.tracker.ReportPrivateInBaseOfClassExpression(Ast.SymbolName(propertySymbol));
				}
			}
			if (this.checkTruncationLength() && (i + 2 < properties.length - 1)) {
				if (this.ctx.flags & FlagsNoTruncation != 0) {
					typeElements[typeElements.length - 1] = this.e.AddSyntheticTrailingComment(typeElements[typeElements.length - 1], KindMultiLineCommentTrivia,
						Fmt.Sprintf("... %d more elided ...", [properties.length - i]), false /*hasTrailingNewLine*/);
				} else {
					final text = Fmt.Sprintf("... %d more ...", [properties.length - i]);
					if (typeElements == null) {
						typeElements = [];
					}
					typeElements.push(this.f.NewPropertySignatureDeclaration(null, this.f.NewIdentifier(text), null, null, null));
				}
				typeElements = this.addPropertyToElementList(properties[properties.length - 1], typeElements);
				break;
			}
			typeElements = this.addPropertyToElementList(propertySymbol, typeElements);
		}
		if (Core.len(typeElements) != 0) {
			return this.f.NewNodeList(typeElements);
		} else {
			return null;
		}
	}

	function createTypeNodeFromObjectType(t:Type):TypeNode {
		if (this.ch.isGenericMappedType(t) || (t.objectFlags & ObjectFlagsMapped != 0 && t.AsMappedType().containsError)) {
			return this.createMappedTypeNodeFromType(t);
		}

		final resolved = this.ch.resolveStructuredTypeMembers(t);
		final callSigs = resolved.CallSignatures();
		final ctorSigs = resolved.ConstructSignatures();
		if (Core.len(resolved.properties) == 0 && Core.len(resolved.indexInfos) == 0) {
			if (Core.len(callSigs) == 0 && Core.len(ctorSigs) == 0) {
				this.ctx.approximateLength += 2;
				final result = this.f.NewTypeLiteralNode(this.f.NewNodeList([]));
				this.e.SetEmitFlags(result, EFSingleLine);
				return result;
			}

			if (Core.len(callSigs) == 1 && Core.len(ctorSigs) == 0) {
				final signature = callSigs[0];
				final signatureNode = this.signatureToSignatureDeclarationHelper(signature, KindFunctionType, null);
				return signatureNode;
			}

			if (Core.len(ctorSigs) == 1 && Core.len(callSigs) == 0) {
				final signature = ctorSigs[0];
				final signatureNode = this.signatureToSignatureDeclarationHelper(signature, KindConstructorType, null);
				return signatureNode;
			}
		}

		final abstractSignatures = Core.Filter(ctorSigs, (signature:Signature) -> {
			return signature.flags & SignatureFlagsAbstract != 0;
		});
		if (Core.len(abstractSignatures) > 0) {
			var types = Core.Map(abstractSignatures, (s:Signature) -> {
				return this.ch.getOrCreateTypeFromSignature(s);
			});
			// count the number of type elements excluding abstract constructors
			final typeElementCount = Core.len(callSigs) + (Core.len(ctorSigs) - Core.len(abstractSignatures)) + Core.len(resolved.indexInfos)
				+ Core.IfElse(this.ctx.flags & FlagsWriteClassExpressionAsTypeLiteral != 0, Core.CountWhere(resolved.properties, (p:Symbol) -> {
					return p.Flags & SymbolFlagsPrototype == 0;
				}), Core.len(resolved.properties));
			// don't include an empty object literal if there were no other static-side
			// properties to write, i.e. `abstract class C { }` becomes `abstract new () => {}`
			// and not `(abstract new () => {}) & {}`
			if (typeElementCount != 0) {
				// create a copy of the object type without any abstract construct signatures.
				types.push(this.getResolvedTypeWithoutAbstractConstructSignatures(resolved));
			}
			return this.typeToTypeNode(this.ch.getIntersectionType(types));
		}

		final restoreFlags = this.saveRestoreFlags();
		this.ctx.flags = this.ctx.flags | FlagsInObjectTypeLiteral;
		final members = this.createTypeNodesFromResolvedType(resolved);
		restoreFlags();
		final typeLiteralNode = this.f.NewTypeLiteralNode(members);
		this.ctx.approximateLength += 2;
		this.e.SetEmitFlags(typeLiteralNode, Core.IfElse((this.ctx.flags & FlagsMultilineObjectLiterals != 0), (0 : ts.printer.Emitflags.EmitFlags), EFSingleLine));
		return typeLiteralNode;
	}

	function shouldWriteTypeOfFunctionSymbol(symbol:Symbol, typeId:TypeId):Pair<Bool, Symbol> {
		final isStaticMethodSymbol = symbol.Flags & SymbolFlagsMethod != 0 && Core.Some(symbol.Declarations, (declaration:Node) -> {
			return Ast.IsStatic(declaration) && !this.ch.isLateBindableIndexSignature(Ast.GetNameOfDeclaration(declaration));
		});
		var isNonLocalFunctionSymbol = false;
		var isFunctionExpressionSymbol = false;
		if (symbol.Flags & SymbolFlagsFunction != 0) {
			if (symbol.Parent != null) {
				isNonLocalFunctionSymbol = true;
			} else {
				if (symbol.Declarations != null) {
					for (declaration in symbol.Declarations) {
						if (declaration.Parent.Kind == KindSourceFile || declaration.Parent.Kind == KindModuleBlock) {
							isNonLocalFunctionSymbol = true;
							break;
						}
						if (Ast.IsFunctionExpressionOrArrowFunction(declaration) && Ast.IsVariableDeclaration(declaration.Parent)
							&& Ast.IsVariableDeclarationList(declaration.Parent.Parent) && Ast.IsVariableStatement(declaration.Parent.Parent.Parent)
							&& declaration.Parent.Parent.Parent.Parent != null
							&& (declaration.Parent.Parent.Parent.Parent.Kind == KindSourceFile || declaration.Parent.Parent.Parent.Parent.Kind == KindModuleBlock)) {
							isNonLocalFunctionSymbol = true;
							isFunctionExpressionSymbol = true;
							break;
						}
					}
				}
			}
		}
		if (isStaticMethodSymbol || isNonLocalFunctionSymbol) {
			if (isFunctionExpressionSymbol && symbol.ValueDeclaration != null && symbol.ValueDeclaration.Parent != null
				&& symbol.ValueDeclaration.Parent != this.ctx.enclosingDeclaration) {
				symbol = this.ch.getMergedSymbol(symbol.ValueDeclaration.Parent.Symbol());
			}
			// typeof is allowed only for static/non local functions
			return new Pair<Bool, Symbol>((this.ctx.flags & FlagsUseTypeOfFunction != 0 || this.ctx.visitedTypes.Has(typeId)) // it is type of the symbol uses itself recursively
				&& (this.ctx.flags & FlagsUseStructuralFallback == 0 || this.ch.IsValueSymbolAccessible(symbol, this.ctx.enclosingDeclaration)),
				symbol); // And the build is going to succeed without visibility error or there is no structural fallback allowed
		}
		return new Pair<Bool, Symbol>(false, symbol);
	}

	function createAnonymousTypeNode(t:Type):TypeNode {
		return this.createAnonymousTypeNodeEx(t, false, false);
	}

	function shouldEmitTypeOfSymbol(forceExpansion:Bool, forceClassExpansion:Bool, isInstanceType:SymbolFlags, symbol:Symbol, typeId:TypeId):Pair<Bool, Symbol> {
		if (forceExpansion) {
			return new Pair<Bool, Symbol>(false, symbol);
		}
		final nonFunctionResult = symbol.Flags & SymbolFlagsClass != 0 && !forceClassExpansion && this.ch.getBaseTypeVariableOfClass(symbol) == null
			&& !(symbol.ValueDeclaration != null && Ast.IsClassLike(symbol.ValueDeclaration) && this.ctx.flags & FlagsWriteClassExpressionAsTypeLiteral != 0
				&& (!Ast.IsClassDeclaration(symbol.ValueDeclaration)
					|| this.ch.IsSymbolAccessible(symbol, this.ctx.enclosingDeclaration, isInstanceType, false /*shouldComputeAliasesToMakeVisible*/).Accessibility != SymbolAccessibilityAccessible))
			|| symbol.Flags & (SymbolFlagsEnum | SymbolFlagsValueModule) != 0;
		if (nonFunctionResult) {
			return new Pair<Bool, Symbol>(true, symbol);
		}
		return this.shouldWriteTypeOfFunctionSymbol(symbol, typeId);
	}

	function createAnonymousTypeNodeEx(t:Type, forceClassExpansion:Bool, forceExpansion:Bool):TypeNode {
		final typeId = t.id;
		final symbol = t.symbol;
		if (symbol != null) {
			final isInstantiationExpressionType = t.objectFlags & ObjectFlagsInstantiationExpressionType != 0;
			if (isInstantiationExpressionType) {
				final instantiationExpressionType = t.AsInstantiationExpressionType();
				final existing = instantiationExpressionType.node;
				//  instantiationExpressionType.node is unreliable for constituents of unions and intersections.
				// declare const Err: typeof ErrImpl & (<T>() => T);
				// type ErrAlias<U> = typeof Err<U>;
				// declare const e: ErrAlias<number>;
				// ErrAlias<number> = typeof Err<number> = typeof ErrImpl & (<number>() => number)
				// The problem is each constituent of the intersection will be associated with typeof Err<number>
				// And when extracting a type for typeof ErrImpl from typeof Err<number> does not make sense.
				if (Ast.IsTypeQueryNode(existing) && this.getTypeFromTypeNode(existing, false) == t) {
					// Guard against unbounded recursion when the existing typeof node fails to be reused
					// (e.g. its entity name isn't accessible from this scope) and the recovery boundary's
					// fallback re-enters typeToTypeNode with the very same instantiation type, which would
					// in turn try to reuse the same node again. Mark the type as visited around the reuse
					// attempt so the inner recursion bottoms out via the visitedTypes guard below.
					if (this.ctx.visitedTypes.Has(typeId)) {
						return this.createElidedInformationPlaceholder();
					}
					this.ctx.visitedTypes.Add(typeId);
					final typeNode = this.tryReuseExistingNonParameterTypeNode(existing, t, null, null);
					this.ctx.visitedTypes.Delete(typeId);
					if (typeNode != null) {
						return typeNode;
					}
				}
				if (this.ctx.visitedTypes.Has(typeId)) {
					return this.createElidedInformationPlaceholder();
				}
				return this.visitAndTransformType(t, (b:NodeBuilderImpl, t:Type) -> b.createTypeNodeFromObjectType(t));
			}
			var isInstanceType:SymbolFlags = 0;
			if (Checker.isClassInstanceSide(this.ch, t)) {
				isInstanceType = SymbolFlagsType;
			} else {
				isInstanceType = SymbolFlagsValue;
			}

			// !!! JS support
			// if c.isJSConstructor(symbol.ValueDeclaration) {
			// 	// Instance and static types share the same symbol; only add 'typeof' for the static side.
			// 	return b.symbolToTypeNode(symbol, isInstanceType, nil)
			// } else
			final r = this.shouldEmitTypeOfSymbol(forceExpansion, forceClassExpansion, isInstanceType, symbol, typeId);
			if (r.a) {
				final symbol = r.b; // Go: `if ok, symbol := ...; ok` shadows symbol in the if scope only
				if (this.shouldExpandType(t, false /*isAlias*/)) {
					this.ctx.depth++;
				} else {
					return this.symbolToTypeNode(symbol, isInstanceType, null);
				}
			}
			if (this.ctx.visitedTypes.Has(typeId)) {
				// If type is an anonymous type literal in a type alias declaration, use type alias name
				final typeAlias = Checker.getTypeAliasForTypeLiteral(this.ch, t);
				if (typeAlias != null) {
					// The specified symbol flags need to be reinterpreted as type flags
					return this.symbolToTypeNode(typeAlias, SymbolFlagsType, null);
				} else {
					return this.createElidedInformationPlaceholder();
				}
			} else {
				return this.visitAndTransformType(t, (b:NodeBuilderImpl, t:Type) -> b.createTypeNodeFromObjectType(t));
			}
		} else {
			// Anonymous types without a symbol are never circular.
			return this.createTypeNodeFromObjectType(t);
		}
	}

	function getTypeFromTypeNode(node:TypeNode, noMappedTypes:Bool):Type {
		// !!! noMappedTypes optional param support
		final t = this.ch.getTypeFromTypeNode(node);
		if (this.ctx.mapper == null) {
			return t;
		}

		final instantiated = this.ch.instantiateType(t, this.ctx.mapper);
		if (noMappedTypes && instantiated != t) {
			return null;
		}
		return instantiated;
	}

	function typeToTypeNodeOrCircularityElision(t:Type):TypeNode {
		if (t.flags & TypeFlagsUnion != 0) {
			if (this.ctx.visitedTypes.Has(t.id)) {
				if (this.ctx.flags & FlagsAllowAnonymousIdentifier == 0) {
					this.ctx.encounteredError = true;
					this.ctx.tracker.ReportCyclicStructureError();
				}
				return this.createElidedInformationPlaceholder();
			}
			return this.visitAndTransformType(t, (b:NodeBuilderImpl, t:Type) -> b.typeToTypeNode(t));
		}
		return this.typeToTypeNode(t);
	}

	function conditionalTypeToTypeNode(_t:Type):TypeNode {
		if (this.checkTruncationLength()) {
			return this.createElidedInformationPlaceholder();
		}
		final t = _t.AsConditionalType();
		final checkTypeNode = this.typeToTypeNode(t.checkType);
		this.ctx.approximateLength += 15;
		if (this.ctx.flags & FlagsGenerateNamesForShadowedTypeParams != 0 && t.root.isDistributive && t.checkType.flags & TypeFlagsTypeParameter == 0) {
			final newParam = this.ch.newTypeParameter(this.ch.newSymbol(SymbolFlagsTypeParameter, "T" /* as __String */));
			final name = this.typeParameterToName(newParam);
			final newTypeVariable = this.f.NewTypeReferenceNode(name.AsNode(), null);
			this.ctx.approximateLength += 37;
			// 15 each for two added conditionals, 7 for an added infer type
			final newMapper = Checker.prependTypeMapping(t.root.checkType, newParam, t.mapper);
			final saveInferTypeParameters = this.ctx.inferTypeParameters;
			this.ctx.inferTypeParameters = t.root.inferTypeParameters;
			final extendsTypeNode = this.typeToTypeNode(this.ch.instantiateType(t.root.extendsType, newMapper));
			this.ctx.inferTypeParameters = saveInferTypeParameters;
			final trueTypeNode = this.typeToTypeNodeOrCircularityElision(this.ch.instantiateType(this.getTypeFromTypeNode(t.root.node.TrueType, false), newMapper));
			final falseTypeNode = this.typeToTypeNodeOrCircularityElision(this.ch.instantiateType(this.getTypeFromTypeNode(t.root.node.FalseType, false), newMapper));

			// outermost conditional makes `T` a type parameter, allowing the inner conditionals to be distributive
			// second conditional makes `T` have `T & checkType` substitution, so it is correctly usable as the checkType
			// inner conditional runs the check the user provided on the check type (distributively) and returns the result
			// checkType extends infer T ? T extends checkType ? T extends extendsType<T> ? trueType<T> : falseType<T> : never : never;
			// this is potentially simplifiable to
			// checkType extends infer T ? T extends checkType & extendsType<T> ? trueType<T> : falseType<T> : never;
			// but that may confuse users who read the output more.
			// On the other hand,
			// checkType extends infer T extends checkType ? T extends extendsType<T> ? trueType<T> : falseType<T> : never;
			// may also work with `infer ... extends ...` in, but would produce declarations only compatible with the latest TS.
			final newId = newTypeVariable.AsTypeReferenceNode().TypeName.AsIdentifier().Clone(this.f);
			final syntheticExtendsNode = this.f.NewInferTypeNode(this.f.NewTypeParameterDeclaration(null, newId, null, null, null));
			final innerCheckConditionalNode = this.f.NewConditionalTypeNode(newTypeVariable, extendsTypeNode, trueTypeNode, falseTypeNode);
			final syntheticTrueNode = this.f.NewConditionalTypeNode(this.f.NewTypeReferenceNode(name.Clone(this.f), null), this.f.DeepCloneNode(checkTypeNode),
				innerCheckConditionalNode, this.f.NewKeywordTypeNode(KindNeverKeyword));
			return this.f.NewConditionalTypeNode(checkTypeNode, syntheticExtendsNode, syntheticTrueNode, this.f.NewKeywordTypeNode(KindNeverKeyword));
		}
		final saveInferTypeParameters = this.ctx.inferTypeParameters;
		this.ctx.inferTypeParameters = t.root.inferTypeParameters;
		final extendsTypeNode = this.typeToTypeNode(t.extendsType);
		this.ctx.inferTypeParameters = saveInferTypeParameters;
		final trueTypeNode = this.typeToTypeNodeOrCircularityElision(this.ch.getTrueTypeFromConditionalType(_t));
		final falseTypeNode = this.typeToTypeNodeOrCircularityElision(this.ch.getFalseTypeFromConditionalType(_t));
		return this.f.NewConditionalTypeNode(checkTypeNode, extendsTypeNode, trueTypeNode, falseTypeNode);
	}

	function getParentSymbolOfTypeParameter(typeParameter:TypeParameter):Symbol {
		final tp = Ast.GetDeclarationOfKind(typeParameter.symbol, KindTypeParameter);
		var host:Node = null;
		// !!! JSDoc support
		// if ast.IsJSDocTemplateTag(tp.Parent) {
		// 	host = getEffectiveContainerForJSDocTemplateTag(tp.Parent)
		// } else {
		host = tp.Parent;
		// }
		if (host == null) {
			return null;
		}
		return this.ch.getSymbolOfNode(host);
	}

	function typeReferenceToTypeNode(t:Type):TypeNode {
		var typeArguments:Array<Type> = this.ch.getTypeArguments(t);
		if (t.Target() == this.ch.globalArrayType || t.Target() == this.ch.globalReadonlyArrayType) {
			if (this.ctx.flags & FlagsWriteArrayAsGenericType != 0) {
				final typeArgumentNode = this.typeToTypeNode(typeArguments[0]);
				return this.f.NewTypeReferenceNode(this.newIdentifier(Core.IfElse(t.Target() == this.ch.globalArrayType, "Array", "ReadonlyArray"), t.Target().symbol),
					this.f.NewNodeList([typeArgumentNode]));
			}
			final elementType = this.typeToTypeNode(typeArguments[0]);
			final arrayType = this.f.NewArrayTypeNode(elementType);
			if (t.Target() == this.ch.globalArrayType) {
				return arrayType;
			} else {
				return this.f.NewTypeOperatorNode(KindReadonlyKeyword, arrayType);
			}
		} else if (t.Target().objectFlags & ObjectFlagsTuple != 0) {
			typeArguments = Core.SameMapIndex(typeArguments, (arg:Type, i:Int) -> {
				var isOptional = false;
				if (i < Core.len(t.Target().AsTupleType().elementInfos)) {
					isOptional = t.Target().AsTupleType().elementInfos[i].flags & ElementFlagsOptional != 0;
				}
				return this.ch.removeMissingType(arg, isOptional);
			});
			if (Core.len(typeArguments) > 0) {
				final arity = this.ch.getTypeReferenceArity(t);
				final tupleConstituentNodes = this.mapToTypeNodes(typeArguments.slice(0, arity), false /*isBareList*/);
				if (tupleConstituentNodes != null) {
					for (i in 0...Core.len(tupleConstituentNodes.Nodes)) {
						final flags = t.Target().AsTupleType().elementInfos[i].flags;
						final labeledElementDeclaration = t.Target().AsTupleType().elementInfos[i].labeledDeclaration;

						if (labeledElementDeclaration != null) {
							tupleConstituentNodes.Nodes[i] = this.f.NewNamedTupleMember(Core.IfElse(flags & ElementFlagsVariable != 0, this.f.NewToken(KindDotDotDotToken), null),
								this.newIdentifier(this.ch.getTupleElementLabel(t.Target().AsTupleType().elementInfos[i], null, i), null /*symbol*/),
								Core.IfElse(flags & ElementFlagsOptional != 0, this.f.NewToken(KindQuestionToken), null),
								Core.IfElse(flags & ElementFlagsRest != 0, this.f.NewArrayTypeNode(tupleConstituentNodes.Nodes[i]), tupleConstituentNodes.Nodes[i]));
						} else {
							if (flags & ElementFlagsVariable != 0) {
								tupleConstituentNodes.Nodes[i] = this.f.NewRestTypeNode(Core.IfElse(flags & ElementFlagsRest != 0,
									this.f.NewArrayTypeNode(tupleConstituentNodes.Nodes[i]), tupleConstituentNodes.Nodes[i]));
							} else if (flags & ElementFlagsOptional != 0) {
								tupleConstituentNodes.Nodes[i] = this.f.NewOptionalTypeNode(tupleConstituentNodes.Nodes[i]);
							}
						}
					}
					final tupleTypeNode = this.f.NewTupleTypeNode(tupleConstituentNodes);
					this.e.SetEmitFlags(tupleTypeNode, EFSingleLine);
					if (t.Target().AsTupleType().readonly) {
						return this.f.NewTypeOperatorNode(KindReadonlyKeyword, tupleTypeNode);
					} else {
						return tupleTypeNode;
					}
				}
			}
			if (this.ctx.encounteredError || (this.ctx.flags & FlagsAllowEmptyTuple != 0)) {
				final tupleTypeNode = this.f.NewTupleTypeNode(this.f.NewNodeList([]));
				this.e.SetEmitFlags(tupleTypeNode, EFSingleLine);
				if (t.Target().AsTupleType().readonly) {
					return this.f.NewTypeOperatorNode(KindReadonlyKeyword, tupleTypeNode);
				} else {
					return tupleTypeNode;
				}
			}
			this.ctx.encounteredError = true;
			return null;
			// TODO: GH#18217
		} else if (this.ctx.flags & FlagsWriteClassExpressionAsTypeLiteral != 0 && t.symbol.ValueDeclaration != null && Ast.IsClassLike(t.symbol.ValueDeclaration)
			&& !this.ch.IsValueSymbolAccessible(t.symbol, this.ctx.enclosingDeclaration)) {
			return this.createAnonymousTypeNode(t);
		} else {
			final outerTypeParameters = t.Target().AsInterfaceType().OuterTypeParameters();
			var i = 0;
			var resultType:TypeNode = null;
			if (outerTypeParameters != null) {
				final length = outerTypeParameters.length;
				while (i < length) {
					// Find group of type arguments for type parameters with the same declaring container.
					final start = i;
					final parent = this.getParentSymbolOfTypeParameter(outerTypeParameters[i].AsTypeParameter());
					do { // do-while loop
						i++;
					} while (i < length && this.getParentSymbolOfTypeParameter(outerTypeParameters[i].AsTypeParameter()) == parent);
					// When type parameters are their own type arguments for the whole group (i.e. we have
					// the default outer type arguments), we don't show the group.

					if (!Slices.Equal(outerTypeParameters.slice(start, i), typeArguments.slice(start, i))) {
						final typeArgumentSlice = this.mapToTypeNodes(typeArguments.slice(start, i), false /*isBareList*/);
						final restoreFlags = this.saveRestoreFlags();
						this.ctx.flags = this.ctx.flags | FlagsForbidIndexedAccessSymbolReferences;
						final ref = this.symbolToTypeNode(parent, SymbolFlagsType, typeArgumentSlice);
						restoreFlags();
						if (resultType == null) {
							resultType = ref;
						} else {
							resultType = this.appendReferenceToType(resultType, ref);
						}
					}
				}
			}
			var typeArgumentNodes:NodeList = null;
			if (Core.len(typeArguments) > 0) {
				var typeParameterCount = 0;
				final typeParams = t.Target().AsInterfaceType().TypeParameters();
				if (typeParams != null) {
					typeParameterCount = typeParams.length < typeArguments.length ? typeParams.length : typeArguments.length; // Go min()

					// Maybe we should do this for more types, but for now we only elide type arguments that are
					// identical to their associated type parameters' defaults for `Iterable`, `IterableIterator`,
					// `AsyncIterable`, and `AsyncIterableIterator` to provide backwards-compatible .d.ts emit due
					// to each now having three type parameters instead of only one.
					if (this.ch.isReferenceToType(t, this.ch.getGlobalIterableType()) || this.ch.isReferenceToType(t, this.ch.getGlobalIterableIteratorType())
						|| this.ch.isReferenceToType(t, this.ch.getGlobalAsyncIterableType()) || this.ch.isReferenceToType(t, this.ch.getGlobalAsyncIterableIteratorType())) {
						if (t.AsTypeReference().node == null || !Ast.IsTypeReferenceNode(t.AsTypeReference().node) || t.AsTypeReference().node.TypeArguments() == null
							|| t.AsTypeReference().node.TypeArguments().length < typeParameterCount) {
							while (typeParameterCount > 0) {
								final typeArgument = typeArguments[typeParameterCount - 1];
								final typeParameter = t.Target().AsInterfaceType().TypeParameters()[typeParameterCount - 1];
								final defaultType = this.ch.getDefaultFromTypeParameter(typeParameter);
								if (defaultType == null || !this.ch.isTypeIdenticalTo(typeArgument, defaultType)) {
									break;
								}
								typeParameterCount--;
							}
						}
					}
				}

				typeArgumentNodes = this.mapToTypeNodes(typeArguments.slice(i, typeParameterCount), false /*isBareList*/);
			}
			final restoreFlags = this.saveRestoreFlags();
			this.ctx.flags = this.ctx.flags | FlagsForbidIndexedAccessSymbolReferences;
			final finalRef = this.symbolToTypeNode(t.symbol, SymbolFlagsType, typeArgumentNodes);
			restoreFlags();
			if (resultType == null) {
				return finalRef;
			} else {
				return this.appendReferenceToType(resultType, finalRef);
			}
		}
	}

	function visitAndTransformType(t:Type, transform:(b:NodeBuilderImpl, t:Type) -> TypeNode):TypeNode {
		final typeId = t.id;
		final isConstructorObject = t.objectFlags & ObjectFlagsAnonymous != 0 && t.symbol != null && t.symbol.Flags & SymbolFlagsClass != 0;
		// PORT: struct key CompositeSymbolIdentity encoded as "<isConstructorNode 0/1>:<symbolId>:<nodeId>"; null = Go nil *id.
		var id:Null<std.String> = null;
		if (t.objectFlags & ObjectFlagsReference != 0 && t.AsTypeReference().node != null) {
			id = "0:0:" + Ast.GetNodeId(t.AsTypeReference().node);
		} else if (t.flags & TypeFlagsConditional != 0) {
			id = "0:0:" + Ast.GetNodeId(t.AsConditionalType().root.node.AsNode());
		} else if (t.symbol != null) {
			id = (isConstructorObject ? "1" : "0") + ":" + Ast.GetSymbolId(t.symbol) + ":0";
		} else {
			id = null;
		}
		// Since instantiations of the same anonymous type have the same symbol, tracking symbols instead
		// of types allows us to catch circular references to instantiations of the same anonymous type

		// PORT: struct key CompositeTypeCacheIdentity encoded as "<typeId>:<flags>:<internalFlags>".
		final key = typeId + ":" + (this.ctx.flags : Int) + ":" + (this.ctx.internalFlags : Int);
		// Don't rely on type cache if we're expanding a type, because we need to compute `canIncreaseExpansionDepth`.
		final canUseCache = this.ctx.maxExpansionDepth < 0;
		if (canUseCache && this.ctx.enclosingDeclaration != null && this.links.Has(this.ctx.enclosingDeclaration)) {
			final links = this.links.Get(this.ctx.enclosingDeclaration);
			final cachedResult = links.serializedTypes == null ? null : links.serializedTypes.get(key);
			if (cachedResult != null) {
				// TODO:: check if we instead store late painted statements associated with this?
				if (cachedResult.trackedSymbols != null) {
					for (arg in cachedResult.trackedSymbols) {
						this.ctx.tracker.TrackSymbol(arg.symbol, arg.enclosingDeclaration, arg.meaning);
					}
				}
				if (cachedResult.truncating) {
					this.ctx.truncating = true;
				}
				this.ctx.approximateLength += cachedResult.addedLength;
				return this.f.DeepCloneNode(cachedResult.node);
			}
		}

		var depth = 0;
		if (id != null) {
			final d = this.ctx.symbolDepth.get(id);
			depth = d == null ? 0 : d;
			if (depth > 10) {
				return this.createElidedInformationPlaceholder();
			}
			this.ctx.symbolDepth.set(id, depth + 1);
		}
		this.ctx.visitedTypes.Add(typeId);
		final prevTrackedSymbols = this.ctx.trackedSymbols;
		this.ctx.trackedSymbols = null;
		final startLength = this.ctx.approximateLength;
		final result = transform(this, t);
		final addedLength = this.ctx.approximateLength - startLength;
		// PORT: Go stores the entry even when enclosingDeclaration is nil (map key nil); that entry is never read
		// (the lookup above requires a non-nil enclosingDeclaration) and GoMap cannot take a null key, so it is skipped.
		if (canUseCache && !this.ctx.reportedDiagnostic && !this.ctx.encounteredError && this.ctx.enclosingDeclaration != null) {
			final links = this.links.Get(this.ctx.enclosingDeclaration);
			if (links.serializedTypes == null) {
				links.serializedTypes = new StringMap<SerializedTypeEntry>();
			}
			final entry = new SerializedTypeEntry();
			entry.node = result;
			entry.truncating = this.ctx.truncating;
			entry.addedLength = addedLength;
			entry.trackedSymbols = this.ctx.trackedSymbols;
			links.serializedTypes.set(key, entry);
		}
		this.ctx.visitedTypes.Delete(typeId);
		if (id != null) {
			this.ctx.symbolDepth.set(id, depth);
		}
		this.ctx.trackedSymbols = prevTrackedSymbols;
		return result;

		// !!! TODO: Attempt node reuse or parse nodes to minimize copying once text range setting is set up
		// deepCloneOrReuseNode := func(node T) T {
		// 	if !nodeIsSynthesized(node) && getParseTreeNode(node) == node {
		// 		return node
		// 	}
		// 	return setTextRange(b.ctx, b.f.cloneNode(visitEachChildWorker(node, deepCloneOrReuseNode, nil /*b.ctx*/, deepCloneOrReuseNodes, deepCloneOrReuseNode)), node)
		// }

		// deepCloneOrReuseNodes := func(nodes *NodeArray[*ast.Node], visitor Visitor, test func(node *ast.Node) bool, start number, count number) *NodeArray[*ast.Node] {
		// 	if nodes != nil && nodes.length == 0 {
		// 		// Ensure we explicitly make a copy of an empty array; visitNodes will not do this unless the array has elements,
		// 		// which can lead to us reusing the same empty NodeArray more than once within the same AST during type noding.
		// 		return setTextRangeWorker(b.f.NewNodeArray(nil, nodes.hasTrailingComma), nodes)
		// 	}
		// 	return visitNodes(nodes, visitor, test, start, count)
		// }
	}

	function typeToTypeNode(t:Type):TypeNode {
		// Push type onto typeStack for expansion depth tracking
		// PORT: defer — the body runs in a local function; the deferred restores run after it returns or throws.
		var pushedTypeStack = false;
		if (this.ctx.maxExpansionDepth >= 0 && t != null) {
			if (this.ctx.typeStack == null) {
				this.ctx.typeStack = [];
			}
			this.ctx.typeStack.push(t);
			pushedTypeStack = true;
		}
		var deferredDepthDecrement = false;
		final typeArg = t;

		function body():TypeNode {
			var t:Type = typeArg;
			final inTypeAlias = this.ctx.flags & FlagsInTypeAlias;
			this.ctx.flags = this.ctx.flags & ~FlagsInTypeAlias;

			if (t == null) {
				if (this.ctx.flags & FlagsAllowEmptyUnionOrIntersection == 0) {
					this.ctx.encounteredError = true;
					return null;
					// TODO: GH#18217
				}
				this.ctx.approximateLength += 3;
				return this.f.NewKeywordTypeNode(KindAnyKeyword);
			}

			if (this.ctx.flags & FlagsNoTypeReduction == 0) {
				t = this.ch.getReducedType(t);
			}

			if (t.flags & TypeFlagsAny != 0) {
				if (t.alias != null) {
					return Nodebuilderimpl.ToTypeReferenceNode(t.alias, this);
				}
				if (t == this.ch.unresolvedType) {
					return this.e.AddSyntheticLeadingComment(this.f.NewKeywordTypeNode(KindAnyKeyword), KindMultiLineCommentTrivia, "unresolved", false /*hasTrailingNewLine*/);
				}
				this.ctx.approximateLength += 3;
				return this.f.NewKeywordTypeNode(Core.IfElse(t == this.ch.intrinsicMarkerType, KindIntrinsicKeyword, KindAnyKeyword));
			}
			if (t.flags & TypeFlagsUnknown != 0) {
				return this.f.NewKeywordTypeNode(KindUnknownKeyword);
			}
			if (t.flags & TypeFlagsString != 0) {
				this.ctx.approximateLength += 6;
				return this.f.NewKeywordTypeNode(KindStringKeyword);
			}
			if (t.flags & TypeFlagsNumber != 0) {
				this.ctx.approximateLength += 6;
				return this.f.NewKeywordTypeNode(KindNumberKeyword);
			}
			if (t.flags & TypeFlagsBigInt != 0) {
				this.ctx.approximateLength += 6;
				return this.f.NewKeywordTypeNode(KindBigIntKeyword);
			}
			if (t.flags & TypeFlagsBoolean != 0 && t.alias == null) {
				this.ctx.approximateLength += 7;
				return this.f.NewKeywordTypeNode(KindBooleanKeyword);
			}
			var expandingEnum = false;
			if (t.flags & TypeFlagsEnumLike != 0) {
				if (t.symbol.Flags & SymbolFlagsEnumMember != 0) {
					final parentSymbol = this.ch.getParentOfSymbol(t.symbol);
					final parentName = this.symbolToTypeNode(parentSymbol, SymbolFlagsType, null);
					if (this.ch.getDeclaredTypeOfSymbol(parentSymbol) == t) {
						return parentName;
					}
					final memberName = Ast.SymbolName(t.symbol);
					if (Scanner.IsIdentifierText(memberName, LanguageVariantStandard)) {
						return this.appendReferenceToType(parentName /* as TypeReference | ImportTypeNode */,
							this.f.NewTypeReferenceNode(this.f.NewIdentifier(memberName), null /*typeArguments*/));
					}
					if (Ast.IsImportTypeNode(parentName)) {
						parentName.AsImportTypeNode().IsTypeOf = true;
						// mutably update, node is freshly manufactured anyhow
						return this.f.NewIndexedAccessTypeNode(parentName, this.f.NewLiteralTypeNode(this.newStringLiteral(memberName)));
					} else if (Ast.IsTypeReferenceNode(parentName)) {
						return this.f.NewIndexedAccessTypeNode(this.f.NewTypeQueryNode(parentName.AsTypeReferenceNode().TypeName, null),
							this.f.NewLiteralTypeNode(this.newStringLiteral(memberName)));
					} else {
						throw "Unhandled type node kind returned from `symbolToTypeNode`.";
					}
				}
				if (t.flags & TypeFlagsUnion == 0 || !this.shouldExpandType(t, false /*isAlias*/)) {
					return this.symbolToTypeNode(t.symbol, SymbolFlagsType, null);
				}
				expandingEnum = true;
			}
			if (t.flags & TypeFlagsStringLiteral != 0) {
				final value:std.String = cast t.AsLiteralType().value;
				this.ctx.approximateLength += Utf8.ByteLen(value) + 2; // PORT: byte — Go len() counts UTF-8 bytes
				final lit = this.newStringLiteral(value);
				this.e.AddEmitFlags(lit, EFNoAsciiEscaping);
				return this.f.NewLiteralTypeNode(lit);
			}
			if (t.flags & TypeFlagsNumberLiteral != 0) {
				final value:Number = (cast t.AsLiteralType().value : Float);
				final valueString = ts.jsnum.String_.String(value);
				this.ctx.approximateLength += Utf8.ByteLen(valueString); // PORT: byte (Go len of a UTF-8 string)
				if (value < 0) {
					return this.f.NewLiteralTypeNode(this.f.NewPrefixUnaryExpression(KindMinusToken, this.f.NewNumericLiteral(valueString.substring(1), TokenFlagsNone)));
				} else {
					return this.f.NewLiteralTypeNode(this.f.NewNumericLiteral(valueString, TokenFlagsNone));
				}
			}
			if (t.flags & TypeFlagsBigIntLiteral != 0) {
				this.ctx.approximateLength += Utf8.ByteLen(Checker.pseudoBigIntToString(Checker.getBigIntLiteralValue(t))) + 1; // PORT: byte (Go len of a UTF-8 string)
				return this.f.NewLiteralTypeNode(this.f.NewBigIntLiteral(Checker.pseudoBigIntToString(Checker.getBigIntLiteralValue(t)) + "n", TokenFlagsNone));
			}
			if (t.flags & TypeFlagsBooleanLiteral != 0) {
				if ((cast t.AsLiteralType().value : Bool)) {
					this.ctx.approximateLength += 4;
					return this.f.NewLiteralTypeNode(this.f.NewKeywordExpression(KindTrueKeyword));
				} else {
					this.ctx.approximateLength += 5;
					return this.f.NewLiteralTypeNode(this.f.NewKeywordExpression(KindFalseKeyword));
				}
			}
			if (t.flags & TypeFlagsUniqueESSymbol != 0) {
				if (this.ctx.flags & FlagsAllowUniqueESSymbolType == 0) {
					if (this.ch.IsValueSymbolAccessible(t.symbol, this.ctx.enclosingDeclaration)) {
						this.ctx.approximateLength += 6;
						return this.symbolToTypeNode(t.symbol, SymbolFlagsValue, null);
					}
					this.ctx.tracker.ReportInaccessibleUniqueSymbolError();
				}
				this.ctx.approximateLength += 13;
				return this.f.NewTypeOperatorNode(KindUniqueKeyword, this.f.NewKeywordTypeNode(KindSymbolKeyword));
			}
			if (t.flags & TypeFlagsVoid != 0) {
				this.ctx.approximateLength += 4;
				return this.f.NewKeywordTypeNode(KindVoidKeyword);
			}
			if (t.flags & TypeFlagsUndefined != 0) {
				this.ctx.approximateLength += 9;
				return this.f.NewKeywordTypeNode(KindUndefinedKeyword);
			}
			if (t.flags & TypeFlagsNull != 0) {
				this.ctx.approximateLength += 4;
				return this.f.NewLiteralTypeNode(this.f.NewKeywordExpression(KindNullKeyword));
			}
			if (t.flags & TypeFlagsNever != 0) {
				this.ctx.approximateLength += 5;
				return this.f.NewKeywordTypeNode(KindNeverKeyword);
			}
			if (t.flags & TypeFlagsESSymbol != 0) {
				this.ctx.approximateLength += 6;
				return this.f.NewKeywordTypeNode(KindSymbolKeyword);
			}
			if (t.flags & TypeFlagsNonPrimitive != 0) {
				this.ctx.approximateLength += 6;
				return this.f.NewKeywordTypeNode(KindObjectKeyword);
			}
			if (Checker.isThisTypeParameter(t)) {
				if (this.ctx.flags & FlagsInObjectTypeLiteral != 0) {
					if (!this.ctx.encounteredError && this.ctx.flags & FlagsAllowThisInObjectLiteral == 0) {
						this.ctx.encounteredError = true;
					}
					this.ctx.tracker.ReportInaccessibleThisError();
				}
				this.ctx.approximateLength += 4;
				return this.f.NewThisTypeNode();
			}

			if ((inTypeAlias : Int) == 0 && t.alias != null
				&& (this.ctx.flags & FlagsUseAliasDefinedOutsideCurrentScope != 0 || this.ch.IsTypeSymbolAccessible(t.alias.Symbol(), this.ctx.enclosingDeclaration))) {
				// If we should expand this type alias, skip the alias and fall through to expand the underlying type
				if (!this.shouldExpandType(t, true /*isAlias*/)) {
					final sym = t.alias.Symbol();
					final typeArgumentNodes = this.mapToTypeNodes(t.alias.TypeArguments(), false /*isBareList*/);
					if (Checker.isReservedMemberName(sym.Name) && sym.Flags & SymbolFlagsClass == 0) {
						return this.f.NewTypeReferenceNode(this.f.NewIdentifier(""), typeArgumentNodes);
					}
					if (typeArgumentNodes != null && Core.len(typeArgumentNodes.Nodes) == 1 && sym == this.ch.globalArrayType.symbol) {
						return this.f.NewArrayTypeNode(typeArgumentNodes.Nodes[0]);
					}
					return this.symbolToTypeNode(sym, SymbolFlagsType, typeArgumentNodes);
				}
				// Expanding: increment depth and process the underlying type
				this.ctx.depth++;
				deferredDepthDecrement = true;
			}

			final objectFlags = t.objectFlags;

			if (objectFlags & ObjectFlagsReference != 0) {
				Debug.Assert(t.Flags() & TypeFlagsObject != 0);
				// When expanding, expand type references to their structural form
				if (this.shouldExpandType(t, false /*isAlias*/)) {
					this.ctx.depth++;
					final result = this.createAnonymousTypeNodeEx(t, true /*forceClassExpansion*/, true /*forceExpansion*/);
					this.ctx.depth--;
					return result;
				}
				if (t.AsTypeReference().node != null) {
					return this.visitAndTransformType(t, (b:NodeBuilderImpl, t:Type) -> b.typeReferenceToTypeNode(t));
				} else {
					return this.typeReferenceToTypeNode(t);
				}
			}
			if (t.flags & TypeFlagsTypeParameter != 0 || objectFlags & ObjectFlagsClassOrInterface != 0) {
				// When expanding class or interface types, show their structural form
				if (objectFlags & ObjectFlagsClassOrInterface != 0 && this.shouldExpandType(t, false /*isAlias*/)) {
					this.ctx.depth++;
					final result = this.createAnonymousTypeNodeEx(t, true /*forceClassExpansion*/, true /*forceExpansion*/);
					this.ctx.depth--;
					return result;
				}
				if (t.flags & TypeFlagsTypeParameter != 0 && Slices.Contains(this.ctx.inferTypeParameters, t)) {
					this.ctx.approximateLength += Utf8.ByteLen(Ast.SymbolName(t.symbol)) + 6; // PORT: byte — Go len() counts UTF-8 bytes
					var constraintNode:TypeNode = null;
					final constraint = this.ch.getConstraintOfTypeParameter(t);
					if (constraint != null) {
						// If the infer type has a constraint that is not the same as the constraint
						// we would have normally inferred based on b, we emit the constraint
						// using `infer T extends ?`. We omit inferred constraints from type references
						// as they may be elided.
						final inferredConstraint = this.ch.getInferredTypeParameterConstraint(t, true /*omitTypeReferences*/);
						if (!(inferredConstraint != null && this.ch.isTypeIdenticalTo(constraint, inferredConstraint))) {
							this.ctx.approximateLength += 9;
							constraintNode = this.typeToTypeNode(constraint);
						}
					}
					return this.f.NewInferTypeNode(this.typeParameterToDeclarationWithConstraint(t, constraintNode));
				}
				if (this.ctx.flags & FlagsGenerateNamesForShadowedTypeParams != 0 && t.flags & TypeFlagsTypeParameter != 0) {
					final name = this.typeParameterToName(t);
					this.ctx.approximateLength += Utf8.ByteLen(name.Text); // PORT: byte — Go len() counts UTF-8 bytes
					return this.f.NewTypeReferenceNode(this.newIdentifier(name.Text, t.symbol), null /*typeArguments*/);
				}
				// Ignore constraint/default when creating a usage (as opposed to declaration) of a type parameter.
				if (t.symbol != null) {
					return this.symbolToTypeNode(t.symbol, SymbolFlagsType, null);
				}
				var name:std.String = "";
				if ((t == this.ch.markerSuperTypeForCheck || t == this.ch.markerSubTypeForCheck) && this.ch.varianceTypeParameter != null
					&& this.ch.varianceTypeParameter.symbol != null) {
					name = Core.IfElse(t == this.ch.markerSubTypeForCheck, "sub-", "super-") + Ast.SymbolName(this.ch.varianceTypeParameter.symbol);
				} else {
					name = "?";
				}
				return this.f.NewTypeReferenceNode(this.newIdentifier(name, null /*symbol*/), null /*typeArguments*/);
			}
			if (t.flags & TypeFlagsUnion != 0 && t.AsUnionType().origin != null) {
				t = t.AsUnionType().origin;
			}
			if (t.flags & (TypeFlagsUnion | TypeFlagsIntersection) != 0) {
				var types:Array<Type> = null;
				if (t.flags & TypeFlagsUnion != 0) {
					types = this.ch.formatUnionTypes(t.AsUnionType().types, expandingEnum);
				} else {
					types = t.AsIntersectionType().types;
				}
				if (Core.len(types) == 1) {
					return this.typeToTypeNode(types[0]);
				}
				final typeNodes = this.mapToTypeNodes(types, true /*isBareList*/);
				if (typeNodes != null && Core.len(typeNodes.Nodes) > 0) {
					if (t.flags & TypeFlagsUnion != 0) {
						return this.f.NewUnionTypeNode(typeNodes);
					} else {
						return this.f.NewIntersectionTypeNode(typeNodes);
					}
				} else {
					if (!this.ctx.encounteredError && this.ctx.flags & FlagsAllowEmptyUnionOrIntersection == 0) {
						this.ctx.encounteredError = true;
					}
					return null;
					// TODO: GH#18217
				}
			}
			if (objectFlags & (ObjectFlagsAnonymous | ObjectFlagsMapped) != 0) {
				Debug.Assert(t.Flags() & TypeFlagsObject != 0);
				// The type is an object literal type.
				return this.createAnonymousTypeNode(t);
			}
			if (t.flags & TypeFlagsIndex != 0) {
				final indexedType = t.Target();
				this.ctx.approximateLength += 6;
				final indexTypeNode = this.typeToTypeNode(indexedType);
				return this.f.NewTypeOperatorNode(KindKeyOfKeyword, indexTypeNode);
			}
			if (t.flags & TypeFlagsTemplateLiteral != 0) {
				final texts = t.AsTemplateLiteralType().texts;
				final types = t.AsTemplateLiteralType().types;
				final templateHead = this.f.NewTemplateHead(texts[0], "", TokenFlagsNone);
				this.e.AddEmitFlags(templateHead, EFNoAsciiEscaping);
				final templateSpans = this.f.NewNodeList(Core.MapIndex(types, (t:Type, i:Int) -> {
					var res:TemplateMiddleOrTail = null;
					if (i < types.length - 1) {
						res = this.f.NewTemplateMiddle(texts[i + 1], "", TokenFlagsNone);
					} else {
						res = this.f.NewTemplateTail(texts[i + 1], "", TokenFlagsNone);
					}
					this.e.AddEmitFlags(res, EFNoAsciiEscaping);
					return this.f.NewTemplateLiteralTypeSpan(this.typeToTypeNode(t), res);
				}));
				this.ctx.approximateLength += 2;
				return this.f.NewTemplateLiteralTypeNode(templateHead, templateSpans);
			}
			if (t.flags & TypeFlagsStringMapping != 0) {
				final typeNode = this.typeToTypeNode(t.Target());
				return this.symbolToTypeNode(t.AsStringMappingType().symbol, SymbolFlagsType, this.f.NewNodeList([typeNode]));
			}
			if (t.flags & TypeFlagsIndexedAccess != 0) {
				final objectTypeNode = this.typeToTypeNode(t.AsIndexedAccessType().objectType);
				final indexTypeNode = this.typeToTypeNode(t.AsIndexedAccessType().indexType);
				this.ctx.approximateLength += 2;
				return this.f.NewIndexedAccessTypeNode(objectTypeNode, indexTypeNode);
			}
			if (t.flags & TypeFlagsConditional != 0) {
				return this.visitAndTransformType(t, (b:NodeBuilderImpl, t:Type) -> b.conditionalTypeToTypeNode(t));
			}
			if (t.flags & TypeFlagsSubstitution != 0) {
				final typeNode = this.typeToTypeNode(t.AsSubstitutionType().baseType);
				if (!this.ch.isNoInferType(t)) {
					return typeNode;
				}
				final noInferSymbol = this.ch.getGlobalTypeAliasSymbol("NoInfer", 1, false);
				if (noInferSymbol != null) {
					return this.symbolToTypeNode(noInferSymbol, SymbolFlagsType, this.f.NewNodeList([typeNode]));
				} else {
					return typeNode;
				}
			}

			throw "Should be unreachable.";
		}

		var result:TypeNode = null;
		try {
			result = body();
		} catch (ex:Dynamic) {
			if (deferredDepthDecrement) {
				this.ctx.depth--;
			}
			if (pushedTypeStack) {
				this.ctx.typeStack.pop();
			}
			throw ex;
		}
		if (deferredDepthDecrement) {
			this.ctx.depth--;
		}
		if (pushedTypeStack) {
			this.ctx.typeStack.pop();
		}
		return result;
	}

	function newStringLiteral(text:std.String):Node {
		return this.newStringLiteralEx(text, false /*isSingleQuote*/);
	}

	function newStringLiteralEx(text:std.String, isSingleQuote:Bool):Node {
		var flags:ts.ast.Tokenflags.TokenFlags = TokenFlagsNone;
		if (isSingleQuote || this.ctx.flags & FlagsUseSingleQuotesForStringLiteralType != 0) {
			flags = flags | TokenFlagsSingleQuote;
		}
		final node = this.f.NewStringLiteral(text, flags);
		return node;
	}

	function newIdentifier(text:std.String, symbol:Symbol):Node {
		final id = this.f.NewIdentifier(text);
		if (symbol != null) {
			this.idToSymbol.set(id, symbol);
		}
		return id;
	}

	function createAccessExpression(node:Node):Expression {
		if (Ast.IsQualifiedName(node)) {
			return this.f.NewPropertyAccessExpression(this.createAccessExpression(node.AsQualifiedName().Left), null /*questionDotToken*/,
				this.f.DeepCloneNode(node.AsQualifiedName().Right), NodeFlagsNone);
		} else if (Ast.IsIdentifier(node) || Ast.IsPropertyAccessExpression(node) || Ast.IsExpressionWithTypeArguments(node)) {
			return this.f.DeepCloneNode(node);
		} else {
			throw "unexpected access node kind: " + node.Kind.String();
		}
	}

	function createExpressionWithTypeArguments(expr:Expression, typeArguments:NodeList):Expression {
		if (typeArguments == null || Core.len(typeArguments.Nodes) == 0) {
			return expr;
		}
		return this.f.NewExpressionWithTypeArguments(expr, typeArguments);
	}

	function lookupInstantiatedTypeArgumentNodes(chain:Array<Symbol>, index:Int):TypeParameterList {
		if (this.shouldWriteTypeParametersInQualifiedName(chain, index)) {
			final symbol = chain[index];
			final nextSymbol = chain[index + 1];
			if (nextSymbol.CheckFlags & CheckFlagsInstantiated == 0) {
				return null;
			}

			var targetSymbol = symbol;
			if (symbol.Flags & SymbolFlagsAlias != 0) {
				targetSymbol = this.ch.resolveAlias(symbol);
			}

			var params = this.getTypeParametersOfClassOrInterface(targetSymbol);
			final targetMapper = this.ch.valueSymbolLinks.Get(nextSymbol).mapper;
			if (targetMapper != null) {
				params = Core.Map(params, (t:Type) -> targetMapper.Map(t));
			}
			return this.mapToTypeNodes(params, false /*isBareList*/);
		}
		return null;
	}

	function lookupExpressionChainTypeArgumentNodes(chain:Array<Symbol>, index:Int):TypeParameterList {
		if (this.shouldWriteTypeParametersInQualifiedName(chain, index)) {
			final symbol = chain[index];
			final symbolId = Ast.GetSymbolId(symbol);
			if (this.ctx.typeParameterSymbolList.Has(symbolId)) {
				return null;
			}

			this.ctx.typeParameterSymbolList.Add(symbolId);
			final typeArgumentNodes = this.lookupInstantiatedTypeArgumentNodes(chain, index);
			if (typeArgumentNodes != null) {
				return typeArgumentNodes;
			}
			final typeParameterNodes = this.typeParametersToTypeParameterDeclarations(symbol);
			if (Core.len(typeParameterNodes) > 0) {
				return this.f.NewNodeList(typeParameterNodes);
			}
		}
		return null;
	}

	function shouldWriteTypeParametersInQualifiedName(chain:Array<Symbol>, index:Int):Bool {
		return this.ctx.flags & FlagsWriteTypeParametersInQualifiedName != 0 && index < Core.len(chain) - 1;
	}
}

@:allow(ts.checker)
class SortedSymbolNamePair {
	var sym:Symbol = null;
	var name:std.String = "";

	public function new() {}
}

@:allow(ts.checker)
class SignatureToSignatureDeclarationOptions {
	var modifiers:Array<Node> = null;
	var name:PropertyName = null;
	var questionToken:Node = null;

	public function new() {}
}

enum abstract PropertyNameNodeKind(Int) from Int to Int {
	var propertyNameNodeKindIdentifier = 0;
	var propertyNameNodeKindNumericLiteral = 1;
	var propertyNameNodeKindStringLiteral = 2;
}

// Methods of nodebuilderimpl.go on receivers declared in other files: static extension (PORTING.md §2).
@:allow(ts.checker)
class Nodebuilderimpl {

	static function getExpandedParameters(c:Checker, sig:Signature, skipUnionExpanding:Bool):Array<Array<Symbol>> {
		if (Checker.signatureHasRestParameter(sig)) {
			final restIndex = sig.parameters.length - 1;
			final restSymbol = sig.parameters[restIndex];
			final restType = c.getTypeOfSymbol(restSymbol);
			final getUniqAssociatedNamesFromTupleType = (t:Type, restSymbol:Symbol) -> {
				final names = Core.MapIndex(t.Target().AsTupleType().elementInfos, (info:TupleElementInfo, i:Int) -> {
					return c.getTupleElementLabel(info, restSymbol, i);
				});
				if (Core.len(names) > 0) {
					final duplicates:Array<Int> = [];
					final uniqueNames = new StringMap<Bool>();
					for (i in 0...names.length) {
						final name = names[i];
						if (uniqueNames.exists(name)) {
							duplicates.push(i);
						} else {
							uniqueNames.set(name, true);
						}
					}
					final counters = new StringMap<Int>();
					for (i in duplicates) {
						var counter = 0;
						if (counters.exists(names[i])) {
							counter = counters.get(names[i]);
						} else {
							counter = 1;
						}
						var name = "";
						while (true) {
							name = names[i] + "_" + counter;
							if (uniqueNames.exists(name)) {
								counter++;
								continue;
							} else {
								uniqueNames.set(name, true);
								break;
							}
						}
						names[i] = name;
						counters.set(names[i], counter + 1);
					}
				}
				return names;
			};
			final expandSignatureParametersWithTupleMembers = (restType:Type, restIndex:Int, restSymbol:Symbol) -> {
				final elementTypes = c.getTypeArguments(restType);
				final associatedNames = getUniqAssociatedNamesFromTupleType(restType, restSymbol);
				final restParams = Core.MapIndex(elementTypes, (t:Type, i:Int) -> {
					// Lookup the label from the individual tuple passed in before falling back to the signature `rest` parameter name
					// TODO: getTupleElementLabel can no longer fail, investigate if this lack of falliability meaningfully changes output
					// var name *string
					// if associatedNames != nil && associatedNames[i] != nil {
					// 	name = associatedNames[i]
					// } else {
					// 	name = c.getParameterNameAtPosition(sig, restIndex+i, restType)
					// }
					final name = associatedNames[i];
					final flags = restType.Target().AsTupleType().elementInfos[i].flags;
					var checkFlags:CheckFlags = 0;
					if (flags & ElementFlagsVariable != 0) {
						checkFlags = CheckFlagsRestParameter;
					} else if (flags & ElementFlagsOptional != 0) {
						checkFlags = CheckFlagsOptionalParameter;
					}
					final symbol = c.newSymbolEx(SymbolFlagsFunctionScopedVariable, name, checkFlags);
					final links = c.valueSymbolLinks.Get(symbol);
					if (flags & ElementFlagsRest != 0) {
						links.resolvedType = c.createArrayType(t);
					} else {
						links.resolvedType = t;
					}
					return symbol;
				});
				return Core.Concatenate(sig.parameters.slice(0, restIndex), restParams);
			};

			if (Checker.isTupleType(restType)) {
				return [expandSignatureParametersWithTupleMembers(restType, restIndex, restSymbol)];
			} else if (!skipUnionExpanding && restType.flags & TypeFlagsUnion != 0 && Core.Every(restType.AsUnionType().types, t -> Checker.isTupleType(t))) {
				return Core.Map(restType.AsUnionType().types, (t:Type) -> {
					return expandSignatureParametersWithTupleMembers(t, restIndex, restSymbol);
				});
			}
		}
		return [sig.parameters];
	}

	public static function ToTypeReferenceNode(t:TypeAlias, b:NodeBuilderImpl):Node {
		return b.f.NewTypeReferenceNode(b.symbolToEntityNameNode(t.Symbol()), b.mapToTypeNodes(t.TypeArguments(), false /*isBareList*/));
	}
}

// PORT: Go passes *Checker as modulespecifiers.CheckerShape (structural interface); Haxe needs an adapter (PORTING.md §3).
@:allow(ts.checker)
class NodeBuilderCheckerShapeAdapter implements ts.modulespecifiers.Types.CheckerShape {
	final c:Checker;

	public function new(c:Checker) {
		this.c = c;
	}

	public function GetSymbolAtLocation(node:Node):Symbol {
		return c.GetSymbolAtLocation(node);
	}

	public function GetAliasedSymbol(symbol:Symbol):Symbol {
		return c.GetAliasedSymbol(symbol);
	}
}

// PORT: Go passes checker.Host as modulespecifiers.ModuleSpecifierGenerationHost (structural interface); Haxe needs an adapter (PORTING.md §3).
@:allow(ts.checker)
class NodeBuilderSpecifierHostAdapter implements ModuleSpecifierGenerationHost {
	final h:Host;

	public function new(h:Host) {
		this.h = h;
	}

	public function CommonSourceDirectory():std.String {
		return h.CommonSourceDirectory();
	}

	public function GetCurrentDirectory():std.String {
		return h.GetCurrentDirectory();
	}

	public function UseCaseSensitiveFileNames():Bool {
		return h.UseCaseSensitiveFileNames();
	}

	public function GetSymlinkCache():KnownSymlinks {
		return h.GetSymlinkCache();
	}

	public function GetGlobalTypingsCacheLocation():std.String {
		return h.GetGlobalTypingsCacheLocation();
	}

	public function GetProjectReferenceFromSource(path:Path):SourceOutputAndProjectReference {
		return h.GetProjectReferenceFromSource(path);
	}

	public function GetRedirectTargets(path:Path):Array<std.String> {
		return h.GetRedirectTargets(path);
	}

	public function GetSourceOfProjectReferenceIfOutputIncluded(file:HasFileName):std.String {
		return h.GetSourceOfProjectReferenceIfOutputIncluded(file);
	}

	public function FileExists(path:std.String):Bool {
		return h.FileExists(path);
	}

	public function GetNearestAncestorDirectoryWithPackageJson(dirname:std.String):std.String {
		return h.GetNearestAncestorDirectoryWithPackageJson(dirname);
	}

	public function GetPackageJsonInfo(pkgJsonPath:std.String):InfoCacheEntry {
		return h.GetPackageJsonInfo(pkgJsonPath);
	}

	public function GetDefaultResolutionModeForFile(file:HasFileName):ResolutionMode {
		return h.GetDefaultResolutionModeForFile(file);
	}

	public function GetResolvedModuleFromModuleSpecifier(file:HasFileName, moduleSpecifier:StringLiteralLike):ResolvedModule {
		return h.GetResolvedModuleFromModuleSpecifier(file, moduleSpecifier);
	}

	public function GetModeForUsageLocation(file:HasFileName, moduleSpecifier:StringLiteralLike):ResolutionMode {
		return h.GetModeForUsageLocation(file, moduleSpecifier);
	}
}
