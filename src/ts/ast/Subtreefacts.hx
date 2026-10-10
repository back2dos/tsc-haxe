package ts.ast;

// Port of subtreefacts.go (types; the propagate* functions are in Ast.hx).

enum abstract SubtreeFacts(Int) from Int to Int {
	@:op(A | B) static function or(a:SubtreeFacts, b:SubtreeFacts):SubtreeFacts;
	@:op(A & B) static function and(a:SubtreeFacts, b:SubtreeFacts):SubtreeFacts;
	@:op(~A) static function not(a:SubtreeFacts):SubtreeFacts;

	// Facts
	// - Flags used to indicate that a node or subtree contains syntax relevant to a specific transform

	var SubtreeContainsTypeScript = 1 << 0;
	var SubtreeContainsJsx = 1 << 1;
	var SubtreeContainsESDecorators = 1 << 2;
	var SubtreeContainsUsing = 1 << 3;
	var SubtreeContainsClassStaticBlocks = 1 << 4;
	var SubtreeContainsESClassFields = 1 << 5;
	var SubtreeContainsLogicalAssignments = 1 << 6;
	var SubtreeContainsNullishCoalescing = 1 << 7;
	var SubtreeContainsOptionalChaining = 1 << 8;
	var SubtreeContainsMissingCatchClauseVariable = 1 << 9;
	var SubtreeContainsESObjectRestOrSpread = 1 << 10; // subtree has a `...` somewhere inside it, never cleared
	var SubtreeContainsForAwaitOrAsyncGenerator = 1 << 11;
	var SubtreeContainsAnyAwait = 1 << 12;
	var SubtreeContainsExponentiationOperator = 1 << 13;

	// Markers
	// - Flags used to indicate that a node or subtree contains a particular kind of syntax.

	var SubtreeContainsLexicalThis = 1 << 14;
	var SubtreeContainsLexicalSuper = 1 << 15;
	var SubtreeContainsRestOrSpread = 1 << 16; // marker on any `...` - cleared on binding pattern exit
	var SubtreeContainsObjectRestOrSpread = 1 << 17; // marker on any `{...x}` - cleared on most scope exits
	var SubtreeContainsAwait = 1 << 18;
	var SubtreeContainsDynamicImport = 1 << 19;
	var SubtreeContainsClassFields = 1 << 20;
	var SubtreeContainsDecorators = 1 << 21;
	var SubtreeContainsIdentifier = 1 << 22;
	var SubtreeContainsPrivateIdentifierInExpression = 1 << 23;
	var SubtreeContainsInvalidTemplateEscape = 1 << 24;

	var SubtreeFactsComputed = 1 << 25; // NOTE: This should always be last
	var SubtreeFactsNone = 0;

	// Aliases (unused, for documentation purposes only - correspond to combinations in transformers/estransforms/definitions.go)

	var SubtreeContainsESNext = SubtreeContainsESDecorators | SubtreeContainsUsing;
	var SubtreeContainsES2022 = SubtreeContainsClassStaticBlocks | SubtreeContainsESClassFields;
	var SubtreeContainsES2021 = SubtreeContainsLogicalAssignments;
	var SubtreeContainsES2020 = SubtreeContainsNullishCoalescing | SubtreeContainsOptionalChaining;
	var SubtreeContainsES2019 = SubtreeContainsMissingCatchClauseVariable;
	var SubtreeContainsES2018 = SubtreeContainsESObjectRestOrSpread | SubtreeContainsForAwaitOrAsyncGenerator | SubtreeContainsInvalidTemplateEscape;
	var SubtreeContainsES2017 = SubtreeContainsAnyAwait;
	var SubtreeContainsES2016 = SubtreeContainsExponentiationOperator;

	// Scope Exclusions
	// - Bitmasks that exclude flags from propagating out of a specific context
	//   into the subtree flags of their container.

	var SubtreeExclusionsNode = SubtreeFactsComputed;
	var SubtreeExclusionsEraseable = ~SubtreeContainsTypeScript;
	var SubtreeExclusionsOuterExpression = SubtreeExclusionsNode;
	var SubtreeExclusionsPropertyAccess = SubtreeExclusionsNode;
	var SubtreeExclusionsElementAccess = SubtreeExclusionsNode;
	var SubtreeExclusionsArrowFunction = SubtreeExclusionsNode | SubtreeContainsAwait | SubtreeContainsObjectRestOrSpread;
	var SubtreeExclusionsFunction = SubtreeExclusionsNode | SubtreeContainsLexicalThis | SubtreeContainsLexicalSuper | SubtreeContainsAwait | SubtreeContainsObjectRestOrSpread;
	var SubtreeExclusionsConstructor = SubtreeExclusionsNode | SubtreeContainsLexicalThis | SubtreeContainsLexicalSuper | SubtreeContainsAwait | SubtreeContainsObjectRestOrSpread;
	var SubtreeExclusionsMethod = SubtreeExclusionsNode | SubtreeContainsLexicalThis | SubtreeContainsLexicalSuper | SubtreeContainsAwait | SubtreeContainsObjectRestOrSpread;
	var SubtreeExclusionsAccessor = SubtreeExclusionsNode | SubtreeContainsLexicalThis | SubtreeContainsLexicalSuper | SubtreeContainsAwait | SubtreeContainsObjectRestOrSpread;
	var SubtreeExclusionsProperty = SubtreeExclusionsNode | SubtreeContainsLexicalThis | SubtreeContainsLexicalSuper;
	var SubtreeExclusionsClass = SubtreeExclusionsNode;
	var SubtreeExclusionsModule = SubtreeExclusionsNode | SubtreeContainsLexicalThis | SubtreeContainsLexicalSuper;
	var SubtreeExclusionsObjectLiteral = SubtreeExclusionsNode | SubtreeContainsObjectRestOrSpread;
	var SubtreeExclusionsArrayLiteral = SubtreeExclusionsNode;
	var SubtreeExclusionsCall = SubtreeExclusionsNode;
	var SubtreeExclusionsNew = SubtreeExclusionsNode;
	var SubtreeExclusionsVariableDeclarationList = SubtreeExclusionsNode | SubtreeContainsObjectRestOrSpread;
	var SubtreeExclusionsParameter = SubtreeExclusionsNode;
	var SubtreeExclusionsCatchClause = SubtreeExclusionsNode | SubtreeContainsObjectRestOrSpread;
	var SubtreeExclusionsBindingPattern = SubtreeExclusionsNode | SubtreeContainsRestOrSpread;

	// Masks
	// - Additional bitmasks

	var SubtreeContainsLexicalThisOrSuper = SubtreeContainsLexicalThis | SubtreeContainsLexicalSuper;
}
