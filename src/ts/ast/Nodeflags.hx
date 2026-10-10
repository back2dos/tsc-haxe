package ts.ast;

// Port of nodeflags.go.

enum abstract NodeFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:NodeFlags, b:NodeFlags):NodeFlags;
	@:op(A & B) static function and(a:NodeFlags, b:NodeFlags):NodeFlags;
	@:op(A ^ B) static function xor(a:NodeFlags, b:NodeFlags):NodeFlags;
	@:op(~A) static function not(a:NodeFlags):NodeFlags;

	var NodeFlagsNone = 0;
	var NodeFlagsLet = 1 << 0; // Variable declaration
	var NodeFlagsConst = 1 << 1; // Variable declaration
	var NodeFlagsUsing = 1 << 2; // Variable declaration
	var NodeFlagsReparsed = 1 << 3; // Node was synthesized during parsing
	var NodeFlagsSynthesized = 1 << 4; // Node was synthesized during transformation
	var NodeFlagsOptionalChain = 1 << 5; // Chained MemberExpression rooted to a pseudo-OptionalExpression
	var NodeFlagsExportContext = 1 << 6; // Export context (initialized by binding)
	var NodeFlagsContainsThis = 1 << 7; // Interface contains references to "this"
	var NodeFlagsHasImplicitReturn = 1 << 8; // If function implicitly returns on one of codepaths (initialized by binding)
	var NodeFlagsHasExplicitReturn = 1 << 9; // If function has explicit reachable return on one of codepaths (initialized by binding)
	var NodeFlagsDisallowInContext = 1 << 10; // If node was parsed in a context where 'in-expressions' are not allowed
	var NodeFlagsYieldContext = 1 << 11; // If node was parsed in the 'yield' context created when parsing a generator
	var NodeFlagsDecoratorContext = 1 << 12; // If node was parsed as part of a decorator
	var NodeFlagsAwaitContext = 1 << 13; // If node was parsed in the 'await' context created when parsing an async function
	var NodeFlagsDisallowConditionalTypesContext = 1 << 14; // If node was parsed in a context where conditional types are not allowed
	var NodeFlagsThisNodeHasError = 1 << 15; // If the parser encountered an error when parsing the code that created this node
	var NodeFlagsJavaScriptFile = 1 << 16; // If node was parsed in a JavaScript
	var NodeFlagsThisNodeOrAnySubNodesHasError = 1 << 17; // If this node or any of its children had an error
	var NodeFlagsHasAsyncFunctions = 1 << 18; // If the file has async functions (initialized by binding)
	// NodeFlagsHasAggregatedChildData is deprecated. Use `subtreeFacts` instead.

	// These flags will be set when the parser encounters a dynamic import expression or 'import.meta' to avoid
	// walking the tree if the flags are not set. However, these flags are just a approximation
	// (hence why it's named "PossiblyContainsDynamicImport") because once set, the flags never get cleared.
	// During editing, if a dynamic import is removed, incremental parsing will *NOT* clear this flag.
	// This means that the tree will always be traversed during module resolution, or when looking for external module indicators.
	// However, the removal operation should not occur often and in the case of the
	// removal, it is likely that users will add the import anyway.
	// The advantage of this approach is its simplicity. For the case of batch compilation,
	// we guarantee that users won't have to pay the price of walking the tree if a dynamic import isn't used.
	var NodeFlagsPossiblyContainsDynamicImport = 1 << 19;
	var NodeFlagsPossiblyContainsImportMeta = 1 << 20;

	var NodeFlagsHasJSDoc = 1 << 21; // If node has preceding JSDoc comment(s)
	var NodeFlagsJSDoc = 1 << 22; // If node was parsed inside jsdoc
	var NodeFlagsAmbient = 1 << 23; // If node was inside an ambient context -- a declaration file, or inside something with the `declare` modifier.
	var NodeFlagsInWithStatement = 1 << 24; // If any ancestor of node was the `statement` of a WithStatement (not the `expression`)
	var NodeFlagsJsonFile = 1 << 25; // If node was parsed in a Json
	var NodeFlagsPossiblyContainsDeprecatedTag = 1 << 26; // Set during parse if comment text contains '@deprecated'; must confirm via JSDoc lookup
	var NodeFlagsUnreachable = 1 << 27; // If node is unreachable according to the binder
	var NodeFlagsReparserTransformedLiteral = 1 << 28; // If node was transformed during parsing, making its' naive text source not match the AST

	var NodeFlagsBlockScoped = NodeFlagsLet | NodeFlagsConst | NodeFlagsUsing;
	var NodeFlagsConstant = NodeFlagsConst | NodeFlagsUsing;
	var NodeFlagsAwaitUsing = NodeFlagsConst | NodeFlagsUsing; // Variable declaration (NOTE: on a single node these flags would otherwise be mutually exclusive)

	var NodeFlagsReachabilityCheckFlags = NodeFlagsHasImplicitReturn | NodeFlagsHasExplicitReturn;
	var NodeFlagsReachabilityAndEmitFlags = NodeFlagsReachabilityCheckFlags | NodeFlagsHasAsyncFunctions;

	// Parsing context flags
	var NodeFlagsContextFlags = NodeFlagsDisallowInContext | NodeFlagsDisallowConditionalTypesContext | NodeFlagsYieldContext | NodeFlagsDecoratorContext | NodeFlagsAwaitContext | NodeFlagsJavaScriptFile | NodeFlagsInWithStatement | NodeFlagsAmbient;

	// Exclude these flags when parsing a Type
	var NodeFlagsTypeExcludesFlags = NodeFlagsYieldContext | NodeFlagsAwaitContext;

	// Represents all flags that are potentially set once and
	// never cleared on SourceFiles which get re-used in between incremental parses.
	// See the comment above on `PossiblyContainsDynamicImport` and `PossiblyContainsImportMeta`.
	var NodeFlagsPermanentlySetIncrementalFlags = NodeFlagsPossiblyContainsDynamicImport | NodeFlagsPossiblyContainsImportMeta;

	// The following flags repurpose other NodeFlags as different meanings for Identifier nodes
	var NodeFlagsIdentifierHasExtendedUnicodeEscape = NodeFlagsContainsThis; // Indicates whether the identifier contains an extended unicode escape sequence
	var NodeFlagsIdentifierIsInJSDocNamespace = NodeFlagsHasAsyncFunctions; // Indicates the identifier is the innermost name of a JSDoc namespace declaration

	// The following flag repurposes other NodeFlags for ModuleDeclaration nodes
	var NodeFlagsNestedNamespace = NodeFlagsOptionalChain; // If ModuleDeclaration is a nested namespace (e.g. inner part of A.B.C)
}
