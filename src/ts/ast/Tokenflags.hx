package ts.ast;

// Port of tokenflags.go.

enum abstract TokenFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:TokenFlags, b:TokenFlags):TokenFlags;
	@:op(A & B) static function and(a:TokenFlags, b:TokenFlags):TokenFlags;
	@:op(A ^ B) static function xor(a:TokenFlags, b:TokenFlags):TokenFlags;
	@:op(~A) static function not(a:TokenFlags):TokenFlags;

	var TokenFlagsNone = 0;
	var TokenFlagsPrecedingLineBreak = 1 << 0;
	var TokenFlagsPrecedingJSDocComment = 1 << 1;
	var TokenFlagsUnterminated = 1 << 2;
	var TokenFlagsExtendedUnicodeEscape = 1 << 3; // e.g. `\u{10ffff}`
	var TokenFlagsScientific = 1 << 4; // e.g. `10e2`
	var TokenFlagsOctal = 1 << 5; // e.g. `0777`
	var TokenFlagsHexSpecifier = 1 << 6; // e.g. `0x00000000`
	var TokenFlagsBinarySpecifier = 1 << 7; // e.g. `0b0110010000000000`
	var TokenFlagsOctalSpecifier = 1 << 8; // e.g. `0o777`
	var TokenFlagsContainsSeparator = 1 << 9; // e.g. `0b1100_0101`
	var TokenFlagsUnicodeEscape = 1 << 10; // e.g. `\u00a0`
	var TokenFlagsContainsInvalidEscape = 1 << 11; // e.g. `\uhello`
	var TokenFlagsHexEscape = 1 << 12; // e.g. `\xa0`
	var TokenFlagsContainsLeadingZero = 1 << 13; // e.g. `0888`
	var TokenFlagsContainsInvalidSeparator = 1 << 14; // e.g. `0_1`
	var TokenFlagsPrecedingJSDocLeadingAsterisks = 1 << 15;
	var TokenFlagsSingleQuote = 1 << 16; // e.g. `'abc'`
	var TokenFlagsPrecedingJSDocWithDeprecated = 1 << 17; // Preceding JSDoc comment contains @deprecated
	var TokenFlagsPrecedingJSDocWithSeeOrLink = 1 << 18; // Preceding JSDoc comment contains @see or @link
	var TokenFlagsBinaryOrOctalSpecifier = TokenFlagsBinarySpecifier | TokenFlagsOctalSpecifier;
	var TokenFlagsWithSpecifier = TokenFlagsHexSpecifier | TokenFlagsBinaryOrOctalSpecifier;
	var TokenFlagsStringLiteralFlags = TokenFlagsUnterminated | TokenFlagsHexEscape | TokenFlagsUnicodeEscape | TokenFlagsExtendedUnicodeEscape | TokenFlagsContainsInvalidEscape | TokenFlagsSingleQuote;
	var TokenFlagsNumericLiteralFlags = TokenFlagsScientific | TokenFlagsOctal | TokenFlagsContainsLeadingZero | TokenFlagsWithSpecifier | TokenFlagsContainsSeparator | TokenFlagsContainsInvalidSeparator;
	var TokenFlagsTemplateLiteralLikeFlags = TokenFlagsUnterminated | TokenFlagsHexEscape | TokenFlagsUnicodeEscape | TokenFlagsExtendedUnicodeEscape | TokenFlagsContainsInvalidEscape;
	var TokenFlagsRegularExpressionLiteralFlags = TokenFlagsUnterminated;
	var TokenFlagsIsInvalid = TokenFlagsOctal | TokenFlagsContainsLeadingZero | TokenFlagsContainsInvalidSeparator | TokenFlagsContainsInvalidEscape;
}
