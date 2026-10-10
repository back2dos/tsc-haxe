package ts.printer;

// Port of emitflags.go.

enum abstract EmitFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:EmitFlags, b:EmitFlags):EmitFlags;
	@:op(A & B) static function and(a:EmitFlags, b:EmitFlags):EmitFlags;
	@:op(~A) static function not(a:EmitFlags):EmitFlags;

	var EFSingleLine = 1 << 0; // The contents of this node should be emitted on a single line.
	var EFMultiLine = 1 << 1; // The contents of this node should be emitted on multiple lines.
	var EFNoLeadingSourceMap = 1 << 2; // Do not emit a leading source map location for this node.
	var EFNoTrailingSourceMap = 1 << 3; // Do not emit a trailing source map location for this node.
	var EFNoNestedSourceMaps = 1 << 4; // Do not emit source map locations for children of this node.
	var EFNoTokenLeadingSourceMaps = 1 << 5; // Do not emit leading source map location for token nodes.
	var EFNoTokenTrailingSourceMaps = 1 << 6; // Do not emit trailing source map location for token nodes.
	var EFNoLeadingComments = 1 << 7; // Do not emit leading comments for this node.
	var EFNoTrailingComments = 1 << 8; // Do not emit trailing comments for this node.
	var EFNoNestedComments = 1 << 9; // Do not emit nested comments for children of this node.
	var EFHelperName = 1 << 10; // The Identifier refers to an *unscoped* emit helper (one that is emitted at the top of the file)
	var EFExportName = 1 << 11; // Ensure an export prefix is added for an identifier that points to an exported declaration with a local name (see SymbolFlags.ExportHasLocal).
	var EFLocalName = 1 << 12; // Ensure an export prefix is not added for an identifier that points to an exported declaration.
	var EFIndented = 1 << 13; // Adds an explicit extra indentation level for class and function bodies when printing (used to match old emitter).
	var EFNoIndentation = 1 << 14; // Do not indent the node.
	var EFReuseTempVariableScope = 1 << 15; // Reuse the existing temp variable scope during emit.
	var EFCustomPrologue = 1 << 16; // Treat the statement as if it were a prologue directive (NOTE: Prologue directives are *not* transformed).
	var EFNoAsciiEscaping = 1 << 17; // When synthesizing nodes that lack an original node or textSourceNode, we want to write the text on the node with ASCII escaping substitutions.
	var EFExternalHelpers = 1 << 18; // This source file has external helpers
	var EFStartOnNewLine = 1 << 19; // Start this node on a new line
	var EFIndirectCall = 1 << 20; // Emit CallExpression as an indirect call: `(0, f)()`
	var EFAsyncFunctionBody = 1 << 21; // The node was originally an async function body.
	var EFNoLexicalArguments = 1 << 22; // Do not capture `arguments` for this arrow function. Set on arrows lowered from class static blocks, where `arguments` is an error; preserves Strada's emit behavior.
	var EFTransformPrivateStaticElements = 1 << 23; // Indicates static private elements in a file or class should be transformed regardless of --target (used by esDecorators transform).
	var EFNoLexicalThis = 1 << 24; // Do not capture `this` for this node's subtree. Set on relocated static initializers, where `this` is handled by the class fields transform.

	var EFNone = 0;
	var EFNoSourceMap = EFNoLeadingSourceMap | EFNoTrailingSourceMap; // Do not emit a source map location for this node.
	var EFNoTokenSourceMaps = EFNoTokenLeadingSourceMaps | EFNoTokenTrailingSourceMaps; // Do not emit source map locations for tokens of this node.
	var EFNoComments = EFNoLeadingComments | EFNoTrailingComments; // Do not emit comments for this node.
}
