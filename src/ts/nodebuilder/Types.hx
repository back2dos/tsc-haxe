package ts.nodebuilder;

// --- types.go ---

// TODO: previously all symboltracker methods were optional, but now they're required.
interface SymbolTracker {
	function TrackSymbol(symbol:Symbol, enclosingDeclaration:Node, meaning:SymbolFlags):Bool;
	function ReportInaccessibleThisError():Void;
	function ReportPrivateInBaseOfClassExpression(propertyName:String):Void;
	function ReportInaccessibleUniqueSymbolError():Void;
	function ReportCyclicStructureError():Void;
	function ReportLikelyUnsafeImportRequiredError(specifier:String, symbolName:String):Void;
	function ReportTruncationError():Void;
	function ReportNonlocalAugmentation(containingFile:SourceFile, parentSymbol:Symbol, augmentingSymbol:Symbol):Void;
	function ReportNonSerializableProperty(propertyName:String):Void;

	function ReportInferenceFallback(node:Node):Void;
	function PushErrorFallbackNode(node:Node):Void;
	function PopErrorFallbackNode():Void;
}

// NOTE: If modifying this enum, must modify `TypeFormatFlags` too!
enum abstract Flags(Int) from Int to Int {
	@:op(A | B) static function or(a:Flags, b:Flags):Flags;
	@:op(A & B) static function and(a:Flags, b:Flags):Flags;
	@:op(~A) static function not(a:Flags):Flags;

	var FlagsNone = 0;
	// Options
	var FlagsNoTruncation = 1 << 0;
	var FlagsWriteArrayAsGenericType = 1 << 1;
	var FlagsGenerateNamesForShadowedTypeParams = 1 << 2;
	var FlagsUseStructuralFallback = 1 << 3;
	var FlagsForbidIndexedAccessSymbolReferences = 1 << 4;
	var FlagsWriteTypeArgumentsOfSignature = 1 << 5;
	var FlagsUseFullyQualifiedType = 1 << 6;
	var FlagsUseOnlyExternalAliasing = 1 << 7;
	var FlagsSuppressAnyReturnType = 1 << 8;
	var FlagsWriteTypeParametersInQualifiedName = 1 << 9;
	var FlagsMultilineObjectLiterals = 1 << 10;
	var FlagsWriteClassExpressionAsTypeLiteral = 1 << 11;
	var FlagsUseTypeOfFunction = 1 << 12;
	var FlagsOmitParameterModifiers = 1 << 13;
	var FlagsUseAliasDefinedOutsideCurrentScope = 1 << 14;
	var FlagsUseSingleQuotesForStringLiteralType = 1 << 28;
	var FlagsNoTypeReduction = 1 << 29;
	var FlagsUseInstantiationExpressions = 1 << 30;
	var FlagsOmitThisParameter = 1 << 25;
	var FlagsWriteCallStyleSignature = 1 << 27;
	// Error handling
	var FlagsAllowThisInObjectLiteral = 1 << 15;
	var FlagsAllowQualifiedNameInPlaceOfIdentifier = 1 << 16;
	var FlagsAllowAnonymousIdentifier = 1 << 17;
	var FlagsAllowEmptyUnionOrIntersection = 1 << 18;
	var FlagsAllowEmptyTuple = 1 << 19;
	var FlagsAllowUniqueESSymbolType = 1 << 20;
	var FlagsAllowEmptyIndexInfoType = 1 << 21;
	// Errors (cont.)
	var FlagsAllowNodeModulesRelativePaths = 1 << 26;
	var FlagsIgnoreErrors = FlagsAllowThisInObjectLiteral | FlagsAllowQualifiedNameInPlaceOfIdentifier | FlagsAllowAnonymousIdentifier
		| FlagsAllowEmptyUnionOrIntersection | FlagsAllowEmptyTuple | FlagsAllowEmptyIndexInfoType | FlagsAllowNodeModulesRelativePaths;
	// State
	var FlagsInObjectTypeLiteral = 1 << 22;
	var FlagsInTypeAlias = 1 << 23;
	var FlagsInInitialEntityName = 1 << 24;
}

/** @internal */
enum abstract InternalFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:InternalFlags, b:InternalFlags):InternalFlags;
	@:op(A & B) static function and(a:InternalFlags, b:InternalFlags):InternalFlags;
	@:op(~A) static function not(a:InternalFlags):InternalFlags;

	var InternalFlagsNone = 0;
	var InternalFlagsWriteComputedProps = 1 << 0;
	var InternalFlagsNoSyntacticPrinter = 1 << 1;
	var InternalFlagsDoNotIncludeSymbolChain = 1 << 2;
	var InternalFlagsAllowUnresolvedNames = 1 << 3;
}
