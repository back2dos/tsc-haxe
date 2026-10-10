package ts.printer;

// Port of emitresolver.go.

enum abstract SymbolAccessibility(Int) from Int to Int {
	var SymbolAccessibilityAccessible = 0;
	var SymbolAccessibilityNotAccessible = 1;
	var SymbolAccessibilityCannotBeNamed = 2;
	var SymbolAccessibilityNotResolved = 3;
}

class SymbolAccessibilityResult {
	public var Accessibility:SymbolAccessibility = SymbolAccessibilityAccessible;
	public var AliasesToMakeVisible:Array<Node> = null; // aliases that need to have this symbol visible
	public var ErrorSymbolName:std.String = ""; // Optional - symbol name that results in error
	public var ErrorNode:Node = null; // Optional - node that results in error
	public var ErrorModuleName:std.String = ""; // Optional - If the symbol is not visible from module, module's name

	public function new() {}

	public function copy():SymbolAccessibilityResult {
		final r = new SymbolAccessibilityResult();
		r.Accessibility = Accessibility;
		r.AliasesToMakeVisible = AliasesToMakeVisible;
		r.ErrorSymbolName = ErrorSymbolName;
		r.ErrorNode = ErrorNode;
		r.ErrorModuleName = ErrorModuleName;
		return r;
	}
}

/**
 * Indicates how to serialize the name for a TypeReferenceNode when emitting decorator metadata
 *
 * @internal
 */
enum abstract TypeReferenceSerializationKind(Int) from Int to Int {
	// The TypeReferenceNode could not be resolved.
	// The type name should be emitted using a safe fallback.
	var TypeReferenceSerializationKindUnknown = 0;

	// The TypeReferenceNode resolves to a type with a constructor
	// function that can be reached at runtime (e.g. a `class`
	// declaration or a `var` declaration for the static side
	// of a type, such as the global `Promise` type in lib.d.ts).
	var TypeReferenceSerializationKindTypeWithConstructSignatureAndValue = 1;

	// The TypeReferenceNode resolves to a Void-like, Nullable, or Never type.
	var TypeReferenceSerializationKindVoidNullableOrNeverType = 2;

	// The TypeReferenceNode resolves to a Number-like type.
	var TypeReferenceSerializationKindNumberLikeType = 3;

	// The TypeReferenceNode resolves to a BigInt-like type.
	var TypeReferenceSerializationKindBigIntLikeType = 4;

	// The TypeReferenceNode resolves to a String-like type.
	var TypeReferenceSerializationKindStringLikeType = 5;

	// The TypeReferenceNode resolves to a Boolean-like type.
	var TypeReferenceSerializationKindBooleanType = 6;

	// The TypeReferenceNode resolves to an Array-like type.
	var TypeReferenceSerializationKindArrayLikeType = 7;

	// The TypeReferenceNode resolves to the ESSymbol type.
	var TypeReferenceSerializationKindESSymbolType = 8;

	// The TypeReferenceNode resolved to the global Promise constructor symbol.
	var TypeReferenceSerializationKindPromise = 9;

	// The TypeReferenceNode resolves to a Function type or a type with call signatures.
	var TypeReferenceSerializationKindTypeWithCallSignature = 10;

	// The TypeReferenceNode resolves to any other type.
	var TypeReferenceSerializationKindObjectType = 11;
}

interface EmitResolver extends ReferenceResolver {
	function IsReferencedAliasDeclaration(node:Node):Bool;
	function IsValueAliasDeclaration(node:Node):Bool;
	function IsTopLevelValueImportEqualsWithEntityName(node:Node):Bool;
	function MarkLinkedReferencesRecursively(file:SourceFile):Void;
	function GetExternalModuleFileFromDeclaration(node:Node):SourceFile;
	function GetEffectiveDeclarationFlags(node:Node, flags:ModifierFlags):ModifierFlags;
	function GetResolutionModeOverride(node:Node):ResolutionMode;

	// decorator metadata
	function GetTypeReferenceSerializationKind(name:EntityName, serialScope:Node):TypeReferenceSerializationKind;

	// const enum inlining
	function GetConstantValue(node:Node):Any;

	// JSX Emit
	function GetJsxFactoryEntity(location:Node):Node;
	function GetJsxFragmentFactoryEntity(location:Node):Node;
	function SetReferencedImportDeclaration(node:IdentifierNode, ref:Declaration):Void; // for overriding the reference resolver behavior for generated identifiers

	// declaration emit checker functionality projections
	function PrecalculateDeclarationEmitVisibility(file:SourceFile):Void;
	function IsSymbolAccessible(symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags, shouldComputeAliasToMarkVisible:Bool):SymbolAccessibilityResult;
	function IsEntityNameVisible(entityName:Node, enclosingDeclaration:Node):SymbolAccessibilityResult; // previously SymbolVisibilityResult in strada - ErrorModuleName never set
	function IsExpandoFunctionDeclaration(node:Node):Bool;
	function IsExpandoFunctionDeclarationUnsafe(node:Node):Bool;
	function IsLiteralConstDeclaration(node:Node):Bool;
	function RequiresAddingImplicitUndefined(node:Node, symbol:Symbol, enclosingDeclaration:Node):Bool;
	function IsDeclarationVisible(node:Node):Bool;
	function IsNameResolvable(location:Node, name:std.String):Bool;
	function IsImportRequiredByAugmentation(decl:ImportDeclaration):Bool;
	function IsDefinitelyReferenceToGlobalSymbolObject(node:Node):Bool;
	function IsImplementationOfOverload(node:SignatureDeclaration):Bool;
	function GetEnumMemberValue(node:Node):Result;
	function IsLateBound(node:Node):Bool;
	function IsOptionalParameter(node:Node):Bool;
	function IsThisPropertyAssignmentDeclarationRedundant(node:Node):Bool;

	// isolatedDeclarations-specific declaration emit
	function GetPropertiesOfContainerFunction(node:Node):Array<Symbol>;
	function RequiresAddingImplicitUndefinedUnsafe(node:Node, symbol:Symbol, enclosingDeclaration:Node):Bool;
	function GetReferencedValueDeclarationUnsafe(node:IdentifierNode):Declaration;

	// Node construction for declaration emit
	function CreateTypeOfDeclaration(emitContext:EmitContext, declaration:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags,
		tracker:SymbolTracker):Node;
	function CreateReturnTypeOfSignatureDeclaration(emitContext:EmitContext, signatureDeclaration:Node, enclosingDeclaration:Node, flags:Flags,
		internalFlags:InternalFlags, tracker:SymbolTracker):Node;
	function CreateTypeParametersOfSignatureDeclaration(emitContext:EmitContext, signatureDeclaration:Node, enclosingDeclaration:Node, flags:Flags,
		internalFlags:InternalFlags, tracker:SymbolTracker):Array<Node>;
	function CreateLiteralConstValue(emitContext:EmitContext, node:Node, tracker:SymbolTracker):Node;
	function CreateTypeOfExpression(emitContext:EmitContext, expression:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags,
		tracker:SymbolTracker):Node;
	function CreateLateBoundIndexSignatures(emitContext:EmitContext, container:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags,
		tracker:SymbolTracker):Array<Node>;
	function TryJSTypeNodeToTypeNode(emitContext:EmitContext, typeNode:Node, enclosingDeclaration:Node, flags:Flags, internalFlags:InternalFlags,
		tracker:SymbolTracker):Node;
}
