package ts.scanner;

import haxe.ds.IntMap;
import haxe.ds.StringMap;

// Port of internal/scanner (scanner.go, regexp.go, unicodeproperties.go, utilities.go).
// The types and the Scanner methods of regexp.go are in Regexp.hx (PORTING.md §2).
//
// PORT: utf16 — positions are UTF-16 code-unit offsets (PORTING.md §5). Go reads `s.text[i]` as a
// byte; here it is the UTF-16 code unit. For ASCII the two are the same. Go's
// utf8.DecodeRuneInString becomes a UTF-16 decode that returns the rune only; its size is
// Utf16.RuneLen(r) (charSize below for charAndSize). Places where Go applies a non-ASCII-aware
// test to a single byte keep Go's byte semantics and are marked `PORT: byte`.
enum abstract EscapeSequenceScanningFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:EscapeSequenceScanningFlags, b:EscapeSequenceScanningFlags):EscapeSequenceScanningFlags;
	@:op(A & B) static function and(a:EscapeSequenceScanningFlags, b:EscapeSequenceScanningFlags):EscapeSequenceScanningFlags;
	@:op(~A) static function not(a:EscapeSequenceScanningFlags):EscapeSequenceScanningFlags;

	var EscapeSequenceScanningFlagsString = 1 << 0;
	var EscapeSequenceScanningFlagsReportErrors = 1 << 1;
	var EscapeSequenceScanningFlagsRegularExpression = 1 << 2;
	var EscapeSequenceScanningFlagsAnnexB = 1 << 3;
	var EscapeSequenceScanningFlagsAnyUnicodeMode = 1 << 4;
	var EscapeSequenceScanningFlagsAtomEscape = 1 << 5;
	var EscapeSequenceScanningFlagsReportInvalidEscapeErrors = EscapeSequenceScanningFlagsRegularExpression | EscapeSequenceScanningFlagsReportErrors;
	var EscapeSequenceScanningFlagsAllowExtendedUnicodeEscape = EscapeSequenceScanningFlagsString | EscapeSequenceScanningFlagsAnyUnicodeMode;
}

typedef ErrorCallback = (diagnostic:Message, start:Int, length:Int, ...args:Any) -> Void;

// PORT: Go value struct; Mark() returns a copy and Rewind() copies back (PORTING.md §3).
class ScannerState {
	public var pos:Int = 0; // Current position in text (and ending position of current token)
	public var fullStartPos:Int = 0; // Starting position of current token including preceding whitespace
	public var tokenStart:Int = 0; // Starting position of non-whitespace part of current token
	public var token:Kind = KindUnknown; // Kind of current token
	public var tokenValue:String = ""; // Parsed value of current token
	public var tokenFlags:TokenFlags = TokenFlagsNone; // Flags for current token
	public var commentDirectives:Array<CommentDirective> = null;
	public var skipJSDocLeadingAsterisks:Int = 0; // Leading asterisks to skip when scanning types inside JSDoc. Should be 0 outside JSDoc

	public function new() {}

	public function copy():ScannerState {
		final r = new ScannerState();
		r.pos = pos;
		r.fullStartPos = fullStartPos;
		r.tokenStart = tokenStart;
		r.token = token;
		r.tokenValue = tokenValue;
		r.tokenFlags = tokenFlags;
		r.commentDirectives = commentDirectives;
		r.skipJSDocLeadingAsterisks = skipJSDocLeadingAsterisks;
		return r;
	}
}

class SkipTriviaOptions {
	public var StopAfterLineBreak:Bool = false;
	public var StopAtComments:Bool = false;
	public var InJSDoc:Bool = false;

	public function new() {}
}

@:allow(ts.scanner)
class Scanner {
	// --- scanner.go ---

	static final textToKeyword:StringMap<Kind> = [
		"abstract" => KindAbstractKeyword,
		"accessor" => KindAccessorKeyword,
		"any" => KindAnyKeyword,
		"as" => KindAsKeyword,
		"asserts" => KindAssertsKeyword,
		"assert" => KindAssertKeyword,
		"bigint" => KindBigIntKeyword,
		"boolean" => KindBooleanKeyword,
		"break" => KindBreakKeyword,
		"case" => KindCaseKeyword,
		"catch" => KindCatchKeyword,
		"class" => KindClassKeyword,
		"continue" => KindContinueKeyword,
		"const" => KindConstKeyword,
		"constructor" => KindConstructorKeyword,
		"debugger" => KindDebuggerKeyword,
		"declare" => KindDeclareKeyword,
		"default" => KindDefaultKeyword,
		"defer" => KindDeferKeyword,
		"delete" => KindDeleteKeyword,
		"do" => KindDoKeyword,
		"else" => KindElseKeyword,
		"enum" => KindEnumKeyword,
		"export" => KindExportKeyword,
		"extends" => KindExtendsKeyword,
		"false" => KindFalseKeyword,
		"finally" => KindFinallyKeyword,
		"for" => KindForKeyword,
		"from" => KindFromKeyword,
		"function" => KindFunctionKeyword,
		"get" => KindGetKeyword,
		"if" => KindIfKeyword,
		"immediate" => KindImmediateKeyword,
		"implements" => KindImplementsKeyword,
		"import" => KindImportKeyword,
		"in" => KindInKeyword,
		"infer" => KindInferKeyword,
		"instanceof" => KindInstanceOfKeyword,
		"interface" => KindInterfaceKeyword,
		"intrinsic" => KindIntrinsicKeyword,
		"is" => KindIsKeyword,
		"keyof" => KindKeyOfKeyword,
		"let" => KindLetKeyword,
		"module" => KindModuleKeyword,
		"namespace" => KindNamespaceKeyword,
		"never" => KindNeverKeyword,
		"new" => KindNewKeyword,
		"null" => KindNullKeyword,
		"number" => KindNumberKeyword,
		"object" => KindObjectKeyword,
		"package" => KindPackageKeyword,
		"private" => KindPrivateKeyword,
		"protected" => KindProtectedKeyword,
		"public" => KindPublicKeyword,
		"override" => KindOverrideKeyword,
		"out" => KindOutKeyword,
		"readonly" => KindReadonlyKeyword,
		"require" => KindRequireKeyword,
		"global" => KindGlobalKeyword,
		"return" => KindReturnKeyword,
		"satisfies" => KindSatisfiesKeyword,
		"set" => KindSetKeyword,
		"static" => KindStaticKeyword,
		"string" => KindStringKeyword,
		"super" => KindSuperKeyword,
		"switch" => KindSwitchKeyword,
		"symbol" => KindSymbolKeyword,
		"this" => KindThisKeyword,
		"throw" => KindThrowKeyword,
		"true" => KindTrueKeyword,
		"try" => KindTryKeyword,
		"type" => KindTypeKeyword,
		"typeof" => KindTypeOfKeyword,
		"undefined" => KindUndefinedKeyword,
		"unique" => KindUniqueKeyword,
		"unknown" => KindUnknownKeyword,
		"using" => KindUsingKeyword,
		"var" => KindVarKeyword,
		"void" => KindVoidKeyword,
		"while" => KindWhileKeyword,
		"with" => KindWithKeyword,
		"yield" => KindYieldKeyword,
		"async" => KindAsyncKeyword,
		"await" => KindAwaitKeyword,
		"of" => KindOfKeyword,
	];

	static final textToToken:StringMap<Kind> = (function() {
		final m:StringMap<Kind> = [
			"{" => KindOpenBraceToken,
			"}" => KindCloseBraceToken,
			"(" => KindOpenParenToken,
			")" => KindCloseParenToken,
			"[" => KindOpenBracketToken,
			"]" => KindCloseBracketToken,
			"." => KindDotToken,
			"..." => KindDotDotDotToken,
			";" => KindSemicolonToken,
			"," => KindCommaToken,
			"<" => KindLessThanToken,
			">" => KindGreaterThanToken,
			"<=" => KindLessThanEqualsToken,
			">=" => KindGreaterThanEqualsToken,
			"==" => KindEqualsEqualsToken,
			"!=" => KindExclamationEqualsToken,
			"===" => KindEqualsEqualsEqualsToken,
			"!==" => KindExclamationEqualsEqualsToken,
			"=>" => KindEqualsGreaterThanToken,
			"+" => KindPlusToken,
			"-" => KindMinusToken,
			"**" => KindAsteriskAsteriskToken,
			"*" => KindAsteriskToken,
			"/" => KindSlashToken,
			"%" => KindPercentToken,
			"++" => KindPlusPlusToken,
			"--" => KindMinusMinusToken,
			"<<" => KindLessThanLessThanToken,
			"</" => KindLessThanSlashToken,
			">>" => KindGreaterThanGreaterThanToken,
			">>>" => KindGreaterThanGreaterThanGreaterThanToken,
			"&" => KindAmpersandToken,
			"|" => KindBarToken,
			"^" => KindCaretToken,
			"!" => KindExclamationToken,
			"~" => KindTildeToken,
			"&&" => KindAmpersandAmpersandToken,
			"||" => KindBarBarToken,
			"?" => KindQuestionToken,
			"??" => KindQuestionQuestionToken,
			"?." => KindQuestionDotToken,
			":" => KindColonToken,
			"=" => KindEqualsToken,
			"+=" => KindPlusEqualsToken,
			"-=" => KindMinusEqualsToken,
			"*=" => KindAsteriskEqualsToken,
			"**=" => KindAsteriskAsteriskEqualsToken,
			"/=" => KindSlashEqualsToken,
			"%=" => KindPercentEqualsToken,
			"<<=" => KindLessThanLessThanEqualsToken,
			">>=" => KindGreaterThanGreaterThanEqualsToken,
			">>>=" => KindGreaterThanGreaterThanGreaterThanEqualsToken,
			"&=" => KindAmpersandEqualsToken,
			"|=" => KindBarEqualsToken,
			"^=" => KindCaretEqualsToken,
			"||=" => KindBarBarEqualsToken,
			"&&=" => KindAmpersandAmpersandEqualsToken,
			"??=" => KindQuestionQuestionEqualsToken,
			"@" => KindAtToken,
			"#" => KindHashToken,
			"`" => KindBacktickToken,
		];
		// maps.Copy(m, textToKeyword)
		for (k => v in textToKeyword) {
			m.set(k, v);
		}
		return m;
	})();

	var text:String = "";
	var end:Int = 0;
	var languageVariant:LanguageVariant = LanguageVariantStandard;
	var scriptTarget:ScriptTarget = ScriptTargetNone;
	var onError:ErrorCallback = null;
	var skipTrivia:Bool = false;

	// PORT: Go embeds ScannerState. Its fields are flattened into Scanner (s.pos is the hottest
	// access of the port); Mark()/Rewind() copy them to/from a ScannerState value.
	var pos:Int = 0; // Current position in text (and ending position of current token)
	var fullStartPos:Int = 0; // Starting position of current token including preceding whitespace
	var tokenStart:Int = 0; // Starting position of non-whitespace part of current token
	var token:Kind = KindUnknown; // Kind of current token
	var tokenValue:String = ""; // Parsed value of current token
	var tokenFlags:TokenFlags = TokenFlagsNone; // Flags for current token
	var commentDirectives:Array<CommentDirective> = null;
	var skipJSDocLeadingAsterisks:Int = 0; // Leading asterisks to skip when scanning types inside JSDoc. Should be 0 outside JSDoc

	var numberCache:StringMap<String> = null;
	var hexNumberCache:StringMap<String> = null;
	var hexDigitCache:StringMap<String> = null;

	// PORT: Go `defaultScanner()` returns Scanner{skipTrivia: true}; the constructor does that.
	function new() {
		skipTrivia = true;
	}

	public static function NewScanner():Scanner {
		return new Scanner();
	}

	public function Reset():Void {
		final numberCache = cleared(this.numberCache);
		final hexNumberCache = cleared(this.hexNumberCache);
		final hexDigitCache = cleared(this.hexDigitCache);
		// *s = defaultScanner()
		text = "";
		end = 0;
		languageVariant = LanguageVariantStandard;
		scriptTarget = ScriptTargetNone;
		onError = null;
		skipTrivia = true;
		setScannerState(new ScannerState());
		this.numberCache = numberCache;
		this.hexNumberCache = hexNumberCache;
		this.hexDigitCache = hexDigitCache;
	}

	static function cleared(m:StringMap<String>):StringMap<String> {
		if (m != null) {
			m.clear();
		}
		return m;
	}

	public function Text():String {
		return text;
	}

	public function Token():Kind {
		return token;
	}

	public function TokenFlags():TokenFlags {
		return tokenFlags;
	}

	public function TokenFullStart():Int {
		return fullStartPos;
	}

	public function TokenStart():Int {
		return tokenStart;
	}

	public function TokenEnd():Int {
		return pos;
	}

	public function TokenText():String {
		return text.substring(tokenStart, pos);
	}

	public function TokenValue():String {
		return tokenValue;
	}

	public function TokenRange():TextRange {
		return Core.NewTextRange(tokenStart, pos);
	}

	public function CommentDirectives():Array<CommentDirective> {
		return commentDirectives;
	}

	public function Mark():ScannerState {
		final r = new ScannerState();
		r.pos = pos;
		r.fullStartPos = fullStartPos;
		r.tokenStart = tokenStart;
		r.token = token;
		r.tokenValue = tokenValue;
		r.tokenFlags = tokenFlags;
		r.commentDirectives = commentDirectives;
		r.skipJSDocLeadingAsterisks = skipJSDocLeadingAsterisks;
		return r;
	}

	public function Rewind(state:ScannerState):Void {
		setScannerState(state);
	}

	// PORT: Go `s.ScannerState = state` (flattened fields, see above).
	inline function setScannerState(state:ScannerState):Void {
		pos = state.pos;
		fullStartPos = state.fullStartPos;
		tokenStart = state.tokenStart;
		token = state.token;
		tokenValue = state.tokenValue;
		tokenFlags = state.tokenFlags;
		commentDirectives = state.commentDirectives;
		skipJSDocLeadingAsterisks = state.skipJSDocLeadingAsterisks;
	}

	public function ResetPos(pos:Int):Void {
		if (pos < 0) {
			throw "Cannot reset token state to negative position";
		}
		this.pos = pos;
		fullStartPos = pos;
		tokenStart = pos;
	}

	public function ResetTokenState(pos:Int):Void {
		ResetPos(pos);
		token = KindUnknown;
		tokenValue = "";
		tokenFlags = TokenFlagsNone;
	}

	public function SetSkipJSDocLeadingAsterisks(skip:Bool):Void {
		if (skip) {
			skipJSDocLeadingAsterisks += 1;
		} else {
			skipJSDocLeadingAsterisks += -1;
		}
	}

	public function SetSkipTrivia(skip:Bool):Void {
		skipTrivia = skip;
	}

	public function HasUnicodeEscape():Bool {
		return (tokenFlags & TokenFlagsUnicodeEscape) != 0;
	}

	public function HasExtendedUnicodeEscape():Bool {
		return (tokenFlags & TokenFlagsExtendedUnicodeEscape) != 0;
	}

	public function HasPrecedingLineBreak():Bool {
		return (tokenFlags & TokenFlagsPrecedingLineBreak) != 0;
	}

	public function HasPrecedingJSDocComment():Bool {
		return (tokenFlags & TokenFlagsPrecedingJSDocComment) != 0;
	}

	public function HasPrecedingJSDocLeadingAsterisks():Bool {
		return (tokenFlags & TokenFlagsPrecedingJSDocLeadingAsterisks) != 0;
	}

	public function HasPrecedingJSDocWithDeprecatedTag():Bool {
		return (tokenFlags & TokenFlagsPrecedingJSDocWithDeprecated) != 0;
	}

	public function HasPrecedingJSDocWithSeeOrLink():Bool {
		return (tokenFlags & TokenFlagsPrecedingJSDocWithSeeOrLink) != 0;
	}

	// scanJSDocCommentForTags scans a JSDoc comment for @deprecated, @see, and @link tags,
	// setting the appropriate token flags. Called during scanning when a JSDoc comment is detected.
	// PORT: Go reslices commentText after each '@'; here `start` is the offset of that slice, so
	// no substring is made per '@' (hasJSDocTag takes the offset).
	function scanJSDocCommentForTags(commentText:String):Void {
		var start = 0;
		while (true) {
			final i = commentText.indexOf("@", start);
			if (i < 0) {
				return;
			}
			start = i + 1;
			if ((tokenFlags & TokenFlagsPrecedingJSDocWithDeprecated) == 0 && hasJSDocTag(commentText, start, "deprecated")) {
				tokenFlags |= TokenFlagsPrecedingJSDocWithDeprecated;
			}
			if ((tokenFlags & TokenFlagsPrecedingJSDocWithSeeOrLink) == 0 && hasJSDocTag(commentText, start, "see", "link", "linkcode", "linkplain")) {
				tokenFlags |= TokenFlagsPrecedingJSDocWithSeeOrLink;
			}
			if ((tokenFlags & (TokenFlagsPrecedingJSDocWithDeprecated | TokenFlagsPrecedingJSDocWithSeeOrLink)) == (TokenFlagsPrecedingJSDocWithDeprecated | TokenFlagsPrecedingJSDocWithSeeOrLink)) {
				return;
			}
		}
	}

	// hasJSDocTag reports whether text starts with one of the given tag names followed
	// by a valid JSDoc tag terminator (whitespace, '}', '*', or end-of-string).
	// PORT: `text` is Go's text[start:] (see scanJSDocCommentForTags).
	static function hasJSDocTag(text:String, start:Int, ...tags:String):Bool {
		for (tag in tags) {
			if (!hasPrefixAt(text, start, tag)) {
				continue;
			}
			if (text.length - start == tag.length) {
				return true;
			}
			final ch = StringTools.fastCodeAt(text, start + tag.length);
			if (ch == ' '.code || ch == '\t'.code || ch == '\n'.code || ch == '\r'.code || ch == '}'.code || ch == '*'.code) {
				return true;
			}
		}
		return false;
	}

	// PORT: strings.HasPrefix(text[start:], prefix) without the slice.
	static function hasPrefixAt(text:String, start:Int, prefix:String):Bool {
		if (text.length - start < prefix.length) {
			return false;
		}
		for (i in 0...prefix.length) {
			if (StringTools.fastCodeAt(text, start + i) != StringTools.fastCodeAt(prefix, i)) {
				return false;
			}
		}
		return true;
	}

	public function SetText(text:String):Void {
		this.text = text;
		end = text.length;
		setScannerState(new ScannerState());
	}

	public function SetOnError(errorCallback:ErrorCallback):Void {
		onError = errorCallback;
	}

	public function SetLanguageVariant(languageVariant:LanguageVariant):Void {
		this.languageVariant = languageVariant;
	}

	public function SetScriptTarget(scriptTarget:ScriptTarget):Void {
		this.scriptTarget = scriptTarget;
	}

	function languageVersion():ScriptTarget {
		if (scriptTarget == ScriptTargetNone) {
			return ScriptTargetLatest;
		}
		return scriptTarget;
	}

	function error(diagnostic:Message):Void {
		errorAt(diagnostic, pos, 0);
	}

	function errorAt(diagnostic:Message, pos:Int, length:Int, ...args:Any):Void {
		if (onError != null) {
			onError(diagnostic, pos, length, ...args);
		}
	}

	// NOTE: even though this returns a rune, it only decodes the current byte.
	// It must be checked against utf8.RuneSelf to verify that a call to charAndSize
	// is not needed.
	// PORT: utf16 — the current UTF-16 code unit.
	inline function char():Int {
		return pos < end ? StringTools.fastCodeAt(text, pos) : -1;
	}

	// NOTE: this returns a rune, but only decodes the byte at the offset.
	inline function charAt(offset:Int):Int {
		return pos + offset < end ? StringTools.fastCodeAt(text, pos + offset) : -1;
	}

	// PORT: utf16 — Go returns (rune, size); here the rune only, the size is charSize(rune).
	// Like Go, the slow path decodes text[pos:] up to the end of the text (not s.end).
	inline function charAndSize():Int {
		// Fast path: a single ASCII byte. The vast majority of source bytes are
		// ASCII; handling them here avoids constructing a string slice header and
		// calling the non-inlined utf8.DecodeRuneInString on every byte.
		var r = -1;
		if (pos < end) {
			final b = StringTools.fastCodeAt(text, pos);
			if (b < Utf16.RuneSelf) {
				r = b;
			}
		}
		return r >= 0 ? r : Utf16.DecodeRuneInString(text, pos);
	}

	// PORT: utf16 — the size Go's charAndSize returns with `ch` at the current position: the
	// UTF-16 length of ch, or 0 at the end of the text.
	inline function charSize(ch:Int):Int {
		return pos < text.length ? Utf16.RuneLen(ch) : 0;
	}

	// scanASCIIWhile advances s.pos over the longest run of ASCII bytes for which
	// pred returns true. It stops at end-of-text, the first non-ASCII byte, or the
	// first byte where pred is false.
	// PORT: inline; with -D analyzer-optimize Haxe inlines the lambda literal at each call site
	// (no function value per call), like Go's compiler does.
	inline function scanASCIIWhile(pred:Int->Bool):Void {
		final text = this.text;
		final end = this.end;
		var i = pos;
		while (i < end) {
			final b = StringTools.fastCodeAt(text, i);
			if (b >= Utf16.RuneSelf || !pred(b)) {
				break;
			}
			i++;
		}
		pos = i;
	}

	public function Scan():Kind {
		fullStartPos = pos;
		tokenFlags = TokenFlagsNone;
		while (true) {
			final ch = char();
			tokenStart = pos;

			switch (ch) {
				case '\t'.code | 0x0B | 0x0C | ' '.code:
					pos++;
					if (skipTrivia) {
						continue;
					}
					while (true) {
						final ch = charAndSize();
						final size = charSize(ch);
						if (!Stringutil.IsWhiteSpaceSingleLine(ch)) {
							break;
						}
						pos += size;
					}
					token = KindWhitespaceTrivia;
				case '\n'.code | '\r'.code:
					tokenFlags |= TokenFlagsPrecedingLineBreak;
					if (skipTrivia) {
						pos++;
						scanASCIIWhile(b -> b == ' '.code || (b >= '\t'.code && b <= '\r'.code));
						continue;
					}
					if (ch == '\r'.code && charAt(1) == '\n'.code) {
						pos += 2;
					} else {
						pos++;
					}
					token = KindNewLineTrivia;
				case '!'.code:
					if (charAt(1) == '='.code) {
						if (charAt(2) == '='.code) {
							pos += 3;
							token = KindExclamationEqualsEqualsToken;
						} else {
							pos += 2;
							token = KindExclamationEqualsToken;
						}
					} else {
						pos++;
						token = KindExclamationToken;
					}
				case '"'.code | "'".code:
					tokenValue = scanString(false /*jsxAttributeString*/);
					token = KindStringLiteral;
				case '`'.code:
					token = scanTemplateAndSetTokenValue(false /*shouldEmitInvalidEscapeError*/);
				case '%'.code:
					if (charAt(1) == '='.code) {
						pos += 2;
						token = KindPercentEqualsToken;
					} else {
						pos++;
						token = KindPercentToken;
					}
				case '&'.code:
					final next = charAt(1);
					if (next == '&'.code) {
						if (charAt(2) == '='.code) {
							pos += 3;
							token = KindAmpersandAmpersandEqualsToken;
						} else {
							pos += 2;
							token = KindAmpersandAmpersandToken;
						}
					} else if (next == '='.code) {
						pos += 2;
						token = KindAmpersandEqualsToken;
					} else {
						pos++;
						token = KindAmpersandToken;
					}
				case '('.code:
					pos++;
					token = KindOpenParenToken;
				case ')'.code:
					pos++;
					token = KindCloseParenToken;
				case '*'.code:
					final next = charAt(1);
					if (next == '='.code) {
						pos += 2;
						token = KindAsteriskEqualsToken;
					} else if (next == '*'.code) {
						if (charAt(2) == '='.code) {
							pos += 3;
							token = KindAsteriskAsteriskEqualsToken;
						} else {
							pos += 2;
							token = KindAsteriskAsteriskToken;
						}
					} else {
						pos++;
						if (skipJSDocLeadingAsterisks != 0
							&& (tokenFlags & TokenFlagsPrecedingJSDocLeadingAsterisks) == 0
							&& (tokenFlags & TokenFlagsPrecedingLineBreak) != 0) {
							tokenFlags |= TokenFlagsPrecedingJSDocLeadingAsterisks;
							continue;
						}
						token = KindAsteriskToken;
					}
				case '+'.code:
					final next = charAt(1);
					if (next == '='.code) {
						pos += 2;
						token = KindPlusEqualsToken;
					} else if (next == '+'.code) {
						pos += 2;
						token = KindPlusPlusToken;
					} else {
						pos++;
						token = KindPlusToken;
					}
				case ','.code:
					pos++;
					token = KindCommaToken;
				case '-'.code:
					final next = charAt(1);
					if (next == '='.code) {
						pos += 2;
						token = KindMinusEqualsToken;
					} else if (next == '-'.code) {
						pos += 2;
						token = KindMinusMinusToken;
					} else {
						pos++;
						token = KindMinusToken;
					}
				case '.'.code:
					final next = charAt(1);
					if (Stringutil.IsDigit(next)) {
						token = scanNumber();
					} else if (next == '.'.code && charAt(2) == '.'.code) {
						pos += 3;
						token = KindDotDotDotToken;
					} else {
						pos++;
						token = KindDotToken;
					}
				case '/'.code:
					// Single-line comment
					if (charAt(1) == '/'.code) {
						pos += 2;

						while (true) {
							scanASCIIWhile(b -> b != '\n'.code && b != '\r'.code);
							final ch1 = charAndSize();
							final size = charSize(ch1);
							if (size == 0 || Stringutil.IsLineBreak(ch1)) {
								break;
							}
							pos += size;
						}

						processCommentDirective(tokenStart, pos, false);

						if (skipTrivia) {
							continue;
						}
						token = KindSingleLineCommentTrivia;
						return token;
					}
					// Multi-line comment
					if (charAt(1) == '*'.code) {
						pos += 2;
						final isJSDoc = char() == '*'.code && charAt(1) != '/'.code;

						var commentClosed = false;
						var lastLineStart = tokenStart;
						while (true) {
							scanASCIIWhile(b -> b != '*'.code && b != '\n'.code && b != '\r'.code);
							final ch1 = charAndSize();
							final size = charSize(ch1);
							if (size == 0) {
								break;
							}

							if (ch1 == '*'.code && charAt(1) == '/'.code) {
								pos += 2;
								commentClosed = true;
								break;
							}

							pos += size;

							if (Stringutil.IsLineBreak(ch1)) {
								lastLineStart = pos;
								tokenFlags |= TokenFlagsPrecedingLineBreak;
							}
						}

						if (isJSDoc) {
							tokenFlags |= TokenFlagsPrecedingJSDocComment;
							scanJSDocCommentForTags(text.substring(tokenStart, pos));
						}

						processCommentDirective(lastLineStart, pos, true);

						if (!commentClosed) {
							error(Diagnostics.Asterisk_Slash_expected);
						}

						if (skipTrivia) {
							continue;
						}

						if (!commentClosed) {
							tokenFlags |= TokenFlagsUnterminated;
						}
						token = KindMultiLineCommentTrivia;
						return token;
					}
					if (charAt(1) == '='.code) {
						pos += 2;
						token = KindSlashEqualsToken;
					} else {
						pos++;
						token = KindSlashToken;
					}
				case '0'.code:
					if (charAt(1) == 'X'.code || charAt(1) == 'x'.code) {
						final start = pos;
						pos += 2;
						var digits = scanHexDigits(1, true, true);
						if (digits == "") {
							error(Diagnostics.Hexadecimal_digit_expected);
							digits = "0";
						}
						if (hexNumberCache == null) {
							hexNumberCache = new StringMap<String>();
						}
						final cachedValue = hexNumberCache.get(digits);
						if (cachedValue != null) {
							tokenValue = cachedValue;
						} else {
							final rawText = text.substring(start, pos);
							if (StringTools.startsWith(rawText, "0x") && rawText.substring(2) == digits) {
								tokenValue = rawText;
							} else {
								tokenValue = "0x" + digits;
							}
							hexNumberCache.set(digits, tokenValue);
						}
						tokenFlags |= TokenFlagsHexSpecifier;
						token = scanBigIntSuffix();
						return token;
					}
					if (charAt(1) == 'B'.code || charAt(1) == 'b'.code) {
						pos += 2;
						var digits = scanBinaryOrOctalDigits(2);
						if (digits == "") {
							error(Diagnostics.Binary_digit_expected);
							digits = "0";
						}
						tokenValue = "0b" + digits;
						tokenFlags |= TokenFlagsBinarySpecifier;
						token = scanBigIntSuffix();
						return token;
					}
					if (charAt(1) == 'O'.code || charAt(1) == 'o'.code) {
						pos += 2;
						var digits = scanBinaryOrOctalDigits(8);
						if (digits == "") {
							error(Diagnostics.Octal_digit_expected);
							digits = "0";
						}
						tokenValue = "0o" + digits;
						tokenFlags |= TokenFlagsOctalSpecifier;
						token = scanBigIntSuffix();
						return token;
					}
					// fallthrough
					token = scanNumber();
				case '1'.code | '2'.code | '3'.code | '4'.code | '5'.code | '6'.code | '7'.code | '8'.code | '9'.code:
					token = scanNumber();
				case ':'.code:
					pos++;
					token = KindColonToken;
				case ';'.code:
					pos++;
					token = KindSemicolonToken;
				case '<'.code:
					if (charAt(1) == '<'.code && isConflictMarkerTrivia(text, pos)) {
						pos = scanConflictMarkerTrivia(text, pos, errorAt);
						if (skipTrivia) {
							continue;
						} else {
							token = KindConflictMarkerTrivia;
							return token;
						}
					}
					if (charAt(1) == '<'.code) {
						if (charAt(2) == '='.code) {
							pos += 3;
							token = KindLessThanLessThanEqualsToken;
						} else {
							pos += 2;
							token = KindLessThanLessThanToken;
						}
					} else if (charAt(1) == '='.code) {
						pos += 2;
						token = KindLessThanEqualsToken;
					} else if (languageVariant == LanguageVariantJSX && charAt(1) == '/'.code && charAt(2) != '*'.code) {
						pos += 2;
						token = KindLessThanSlashToken;
					} else {
						pos++;
						token = KindLessThanToken;
					}
				case '='.code:
					if (charAt(1) == '='.code && isConflictMarkerTrivia(text, pos)) {
						pos = scanConflictMarkerTrivia(text, pos, errorAt);
						if (skipTrivia) {
							continue;
						} else {
							token = KindConflictMarkerTrivia;
							return token;
						}
					}
					if (charAt(1) == '='.code) {
						if (charAt(2) == '='.code) {
							pos += 3;
							token = KindEqualsEqualsEqualsToken;
						} else {
							pos += 2;
							token = KindEqualsEqualsToken;
						}
					} else if (charAt(1) == '>'.code) {
						pos += 2;
						token = KindEqualsGreaterThanToken;
					} else {
						pos++;
						token = KindEqualsToken;
					}
				case '>'.code:
					if (charAt(1) == '>'.code && isConflictMarkerTrivia(text, pos)) {
						pos = scanConflictMarkerTrivia(text, pos, errorAt);
						if (skipTrivia) {
							continue;
						} else {
							token = KindConflictMarkerTrivia;
							return token;
						}
					}
					pos++;
					token = KindGreaterThanToken;
				case '?'.code:
					if (charAt(1) == '.'.code && !Stringutil.IsDigit(charAt(2))) {
						pos += 2;
						token = KindQuestionDotToken;
					} else if (charAt(1) == '?'.code) {
						if (charAt(2) == '='.code) {
							pos += 3;
							token = KindQuestionQuestionEqualsToken;
						} else {
							pos += 2;
							token = KindQuestionQuestionToken;
						}
					} else {
						pos++;
						token = KindQuestionToken;
					}
				case '['.code:
					pos++;
					token = KindOpenBracketToken;
				case ']'.code:
					pos++;
					token = KindCloseBracketToken;
				case '^'.code:
					if (charAt(1) == '='.code) {
						pos += 2;
						token = KindCaretEqualsToken;
					} else {
						pos++;
						token = KindCaretToken;
					}
				case '{'.code:
					pos++;
					token = KindOpenBraceToken;
				case '|'.code:
					if (charAt(1) == '|'.code && isConflictMarkerTrivia(text, pos)) {
						pos = scanConflictMarkerTrivia(text, pos, errorAt);
						if (skipTrivia) {
							continue;
						} else {
							token = KindConflictMarkerTrivia;
							return token;
						}
					}
					if (charAt(1) == '|'.code) {
						if (charAt(2) == '='.code) {
							pos += 3;
							token = KindBarBarEqualsToken;
						} else {
							pos += 2;
							token = KindBarBarToken;
						}
					} else if (charAt(1) == '='.code) {
						pos += 2;
						token = KindBarEqualsToken;
					} else {
						pos++;
						token = KindBarToken;
					}
				case '}'.code:
					pos++;
					token = KindCloseBraceToken;
				case '~'.code:
					pos++;
					token = KindTildeToken;
				case '@'.code:
					pos++;
					token = KindAtToken;
				case '\\'.code:
					final cp = peekUnicodeEscape();
					if (cp >= 0 && IsIdentifierStart(cp)) {
						tokenValue = Utf16.RuneString(scanUnicodeEscape(true)) + scanIdentifierParts();
						token = GetIdentifierToken(tokenValue);
					} else {
						scanInvalidCharacter();
					}
				case '#'.code:
					if (charAt(1) == '!'.code) {
						if (pos == 0) {
							pos += 2;
							var ch = charAndSize();
							var size = charSize(ch);
							while (size > 0 && !Stringutil.IsLineBreak(ch)) {
								pos += size;
								ch = charAndSize();
								size = charSize(ch);
							}
							continue;
						}
						errorAt(Diagnostics.X_can_only_be_used_at_the_start_of_a_file, pos, 2);
						pos++;
						token = KindUnknown;
						return token;
					}
					if (charAt(1) == '\\'.code) {
						pos++;
						final cp = peekUnicodeEscape();
						if (cp >= 0 && IsIdentifierStart(cp)) {
							tokenValue = "#" + Utf16.RuneString(scanUnicodeEscape(true)) + scanIdentifierParts();
							token = KindPrivateIdentifier;
							return token;
						}
						pos--;
					}
					if (!scanIdentifier(1)) {
						errorAt(Diagnostics.Invalid_character, pos - 1, 1);
						tokenValue = "#";
					}
					token = KindPrivateIdentifier;
				default:
					if (ch < 0) {
						token = KindEndOfFile;
						return token;
					}
					if (scanIdentifier(0)) {
						token = GetIdentifierToken(tokenValue);
						return token;
					}
					var ch = charAndSize();
					var size = charSize(ch);
					if (ch == Utf16.RuneError) {
						errorAt(Diagnostics.File_appears_to_be_binary, 0, 0);
						pos = text.length;
						token = KindNonTextFileMarkerTrivia;
						return token;
					}
					if (Stringutil.IsWhiteSpaceSingleLine(ch)) {
						pos += size;

						// If we get here and it's not 0x0085 (nextLine), then we're handling non-ASCII whitespace.
						// Handle skipTrivia like we do in the space case above.
						if (ch == 0x0085 || skipTrivia) {
							continue;
						}

						while (true) {
							ch = charAndSize();
							size = charSize(ch);
							if (!Stringutil.IsWhiteSpaceSingleLine(ch)) {
								break;
							}
							pos += size;
						}
						token = KindWhitespaceTrivia;
						return token;
					}
					if (Stringutil.IsLineBreak(ch)) {
						tokenFlags |= TokenFlagsPrecedingLineBreak;
						pos += size;
						continue;
					}
					scanInvalidCharacter();
			}
			return token;
		}
	}

	function processCommentDirective(start:Int, end:Int, multiline:Bool):Void {
		final text = this.text;
		// Skip starting slashes and whitespace
		var pos = start;
		if (multiline) {
			// Skip whitespace
			while (pos < end && (StringTools.fastCodeAt(text, pos) == ' '.code || StringTools.fastCodeAt(text, pos) == '\t'.code)) {
				pos++;
			}
			// Skip combinations of / and *
			while (pos < end && (StringTools.fastCodeAt(text, pos) == '/'.code || StringTools.fastCodeAt(text, pos) == '*'.code)) {
				pos++;
			}
		} else {
			// Skip opening //
			pos += 2;
			// Skip another / if present
			while (pos < end && StringTools.fastCodeAt(text, pos) == '/'.code) {
				pos++;
			}
		}
		// Skip whitespace
		while (pos < end && (StringTools.fastCodeAt(text, pos) == ' '.code || StringTools.fastCodeAt(text, pos) == '\t'.code)) {
			pos++;
		}
		// Directive must start with '@'
		if (!(pos < end && StringTools.fastCodeAt(text, pos) == '@'.code)) {
			return;
		}
		pos++;
		var kind:CommentDirectiveKind;
		if (hasPrefixAt(text, pos, "ts-expect-error")) {
			kind = CommentDirectiveKindExpectError;
		} else if (hasPrefixAt(text, pos, "ts-ignore")) {
			kind = CommentDirectiveKindIgnore;
		} else {
			return;
		}
		final d = new CommentDirective();
		d.Loc = Core.NewTextRange(start, end);
		d.Kind = kind;
		// PORT: Go `append` on a slice value. Mark()/Rewind() share the array, and Go's rewound
		// slice header hides elements appended after the mark; a copy keeps that behaviour.
		commentDirectives = commentDirectives == null ? [d] : commentDirectives.concat([d]);
	}

	public function ReScanLessThanToken():Kind {
		if (token == KindLessThanLessThanToken) {
			pos = tokenStart + 1;
			token = KindLessThanToken;
		}
		return token;
	}

	public function ReScanGreaterThanToken():Kind {
		if (token == KindGreaterThanToken) {
			reScanGreaterThanTokenInner();
		}
		return token;
	}

	function reScanGreaterThanTokenInner():Void {
		pos = tokenStart + 1;
		if (char() == '>'.code) {
			if (charAt(1) == '>'.code) {
				if (charAt(2) == '='.code) {
					pos += 3;
					token = KindGreaterThanGreaterThanGreaterThanEqualsToken;
				} else {
					pos += 2;
					token = KindGreaterThanGreaterThanGreaterThanToken;
				}
			} else if (charAt(1) == '='.code) {
				pos += 2;
				token = KindGreaterThanGreaterThanEqualsToken;
			} else {
				pos++;
				token = KindGreaterThanGreaterThanToken;
			}
		} else if (char() == '='.code) {
			pos++;
			token = KindGreaterThanEqualsToken;
		}
	}

	public function ReScanTemplateToken(isTaggedTemplate:Bool):Kind {
		pos = tokenStart;
		token = scanTemplateAndSetTokenValue(!isTaggedTemplate);
		return token;
	}

	public function ReScanAsteriskEqualsToken():Kind {
		if (token != KindAsteriskEqualsToken) {
			throw "'ReScanAsteriskEqualsToken' should only be called on a '*='";
		}
		pos = tokenStart + 1;
		token = KindEqualsToken;
		return token;
	}

	public function ReScanSlashToken(...reportErrors:Bool):Kind {
		final shouldReportErrors = reportErrors.length > 0 && reportErrors[0];
		if (token == KindSlashToken || token == KindSlashEqualsToken) {
			// Quickly get to the end of regex such that we know the flags
			final startOfRegExpBody = tokenStart + 1;
			var p = startOfRegExpBody;
			var inEscape = false;
			var namedCaptureGroups = false;
			// Although nested character classes are allowed in Unicode Sets mode,
			// an unescaped slash is nevertheless invalid even in a character class in any Unicode mode.
			// This is indicated by Section 12.9.5 Regular Expression Literals of the specification,
			// where nested character classes are not considered at all. (A `[` RegularExpressionClassChar
			// does nothing in a RegularExpressionClass, and a `]` always closes the class.)
			// Additionally, parsing nested character classes will misinterpret regexes like `/[[]/`
			// as unterminated, consuming characters beyond the slash. (This even applies to `/[[]/v`,
			// which should be parsed as a well-terminated regex with an incomplete character class.)
			// Thus we must not handle nested character classes in the first pass.
			var inCharacterClass = false;
			// PORT: label — Go `break loop` from inside the switch; the switch is an if chain here,
			// so `break` leaves the loop.
			while (true) {
				// If we reach the end of a file, or hit a newline, then this is an unterminated
				// regex. Report error and return what we have so far.
				if (p >= end) {
					tokenFlags |= TokenFlagsUnterminated;
					break;
				}
				final ch = StringTools.fastCodeAt(text, p);
				// PORT: byte — Go tests the byte text[p], which is never U+2028/U+2029.
				if (ch < Utf16.RuneSelf && Stringutil.IsLineBreak(ch)) {
					tokenFlags |= TokenFlagsUnterminated;
					break;
				} else if (inEscape) {
					// Parsing an escape character;
					// reset the flag and just advance to the next char.
					inEscape = false;
				} else if (ch == '/'.code && !inCharacterClass) {
					// A slash within a character class is permissible,
					// but in general it signals the end of the regexp literal.
					break;
				} else if (ch == '['.code) {
					inCharacterClass = true;
				} else if (ch == '\\'.code) {
					inEscape = true;
				} else if (ch == ']'.code) {
					inCharacterClass = false;
				} else if (!inCharacterClass
					&& ch == '('.code
					&& p + 1 < end
					&& StringTools.fastCodeAt(text, p + 1) == '?'.code
					&& p + 2 < end
					&& StringTools.fastCodeAt(text, p + 2) == '<'.code
					&& (p + 3 >= end || (StringTools.fastCodeAt(text, p + 3) != '='.code && StringTools.fastCodeAt(text, p + 3) != '!'.code))) {
					namedCaptureGroups = true;
				}
				p++;
			}

			final endOfRegExpBody = p;
			if ((tokenFlags & TokenFlagsUnterminated) != 0) {
				// Search for the nearest unbalanced bracket for better recovery. Since the expression is
				// invalid anyways, we take nested square brackets into consideration for the best guess.
				p = startOfRegExpBody;
				inEscape = false;
				var characterClassDepth = 0;
				var inDecimalQuantifier = false;
				var groupDepth = 0;
				while (p < endOfRegExpBody) {
					final ch = StringTools.fastCodeAt(text, p);
					if (inEscape) {
						inEscape = false;
					} else if (ch == '\\'.code) {
						inEscape = true;
					} else if (ch == '['.code) {
						characterClassDepth++;
					} else if (ch == ']'.code && characterClassDepth != 0) {
						characterClassDepth--;
					} else if (characterClassDepth == 0) {
						if (ch == '{'.code) {
							inDecimalQuantifier = true;
						} else if (ch == '}'.code && inDecimalQuantifier) {
							inDecimalQuantifier = false;
						} else if (!inDecimalQuantifier) {
							if (ch == '('.code) {
								groupDepth++;
							} else if (ch == ')'.code && groupDepth != 0) {
								groupDepth--;
							} else if (ch == ')'.code || ch == ']'.code || ch == '}'.code) {
								// We encountered an unbalanced bracket outside a character class. Treat this position as the end of regex.
								break;
							}
						}
					}
					p++;
				}
				// Whitespaces and semicolons at the end are not likely to be part of the regex
				while (p > startOfRegExpBody) {
					final ch = Utf16.DecodeLastRuneBefore(text, p);
					final size = Utf16.RuneLen(ch);
					if (Stringutil.IsWhiteSpaceLike(ch) || ch == ';'.code) {
						p -= size;
					} else {
						break;
					}
				}
				errorAt(Diagnostics.Unterminated_regular_expression_literal, tokenStart, p - tokenStart);
			} else {
				// Consume the slash character
				p++;
				var regExpFlags:RegularExpressionFlags = RegularExpressionFlagsNone;
				while (p < end) {
					final ch = Utf16.DecodeRuneInString(text, p);
					final size = Utf16.RuneLen(ch);
					if (ch == Utf16.RuneError || !IsIdentifierPart(ch)) {
						break;
					}
					if (shouldReportErrors) {
						if (!charCodeToRegExpFlag.exists(ch)) {
							errorAt(Diagnostics.Unknown_regular_expression_flag, p, size);
						} else {
							final flag:RegularExpressionFlags = charCodeToRegExpFlag.get(ch);
							if ((regExpFlags & flag) != 0) {
								errorAt(Diagnostics.Duplicate_regular_expression_flag, p, size);
							} else if (((regExpFlags | flag) & RegularExpressionFlagsAnyUnicodeMode) == RegularExpressionFlagsAnyUnicodeMode) {
								errorAt(Diagnostics.The_Unicode_u_flag_and_the_Unicode_Sets_v_flag_cannot_be_set_simultaneously, p, size);
							} else {
								regExpFlags |= flag;
								this.checkRegularExpressionFlagAvailability(flag, p, size);
							}
						}
					}
					p += size;
				}
				if (shouldReportErrors) {
					pos = startOfRegExpBody;
					final saveEnd = end;
					final saveTokenPos = tokenStart;
					final saveTokenFlags = tokenFlags;
					end = endOfRegExpBody;
					final parser = new RegExpParser();
					parser.scanner = this;
					parser.end = endOfRegExpBody;
					parser.regExpFlags = regExpFlags;
					parser.anyUnicodeMode = (regExpFlags & RegularExpressionFlagsAnyUnicodeMode) != 0;
					parser.unicodeSetsMode = (regExpFlags & RegularExpressionFlagsUnicodeSets) != 0;
					parser.annexB = true;
					parser.namedCaptureGroups = namedCaptureGroups;
					parser.groupSpecifiers = new StringMap<Bool>();
					parser.run();
					end = saveEnd;
					pos = p;
					tokenStart = saveTokenPos;
					tokenFlags = saveTokenFlags;
				} else {
					pos = p;
				}
			}

			pos = p;
			tokenValue = text.substring(tokenStart, pos);
			token = KindRegularExpressionLiteral;
		}
		return token;
	}

	public function ReScanJsxToken(allowMultilineJsxText:Bool):Kind {
		pos = fullStartPos;
		tokenStart = fullStartPos;
		token = ScanJsxTokenEx(allowMultilineJsxText);
		return token;
	}

	public function ReScanHashToken():Kind {
		if (token == KindPrivateIdentifier) {
			pos = tokenStart + 1;
			token = KindHashToken;
		}
		return token;
	}

	public function ReScanQuestionToken():Kind {
		if (token != KindQuestionQuestionToken) {
			throw "'reScanQuestionToken' should only be called on a '??'";
		}
		pos = tokenStart + 1;
		token = KindQuestionToken;
		return token;
	}

	public function ScanJsxToken():Kind {
		return ScanJsxTokenEx(true /*allowMultilineJsxText*/);
	}

	public function ScanJsxTokenEx(allowMultilineJsxText:Bool):Kind {
		fullStartPos = pos;
		tokenStart = pos;
		final ch = char();
		if (ch < 0) {
			token = KindEndOfFile;
		} else if (ch == '<'.code) {
			if (charAt(1) == '/'.code) {
				pos += 2;
				token = KindLessThanSlashToken;
			} else {
				pos++;
				token = KindLessThanToken;
			}
		} else if (ch == '{'.code) {
			pos++;
			token = KindOpenBraceToken;
		} else {
			// First non-whitespace character on this line.
			var firstNonWhitespace = 0;
			// These initial values are special because the first line is:
			// firstNonWhitespace = 0 to indicate that we want leading whitespace
			while (true) {
				final ch = charAndSize();
				final size = charSize(ch);
				if (size == 0 || ch == '{'.code) {
					break;
				}
				if (ch == '<'.code) {
					if (isConflictMarkerTrivia(text, pos)) {
						pos = scanConflictMarkerTrivia(text, pos, errorAt);
						token = KindConflictMarkerTrivia;
						return token;
					}
					break;
				}
				if (ch == '>'.code) {
					errorAt(Diagnostics.Unexpected_token_Did_you_mean_or_gt, pos, 1);
				} else if (ch == '}'.code) {
					errorAt(Diagnostics.Unexpected_token_Did_you_mean_or_rbrace, pos, 1);
				}
				// FirstNonWhitespace is 0, then we only see whitespaces so far. If we see a linebreak, we want to ignore that whitespaces.
				// i.e (- : whitespace)
				//      <div>----
				//      </div> becomes <div></div>
				//
				//      <div>----</div> becomes <div>----</div>
				if (Stringutil.IsLineBreak(ch) && firstNonWhitespace == 0) {
					firstNonWhitespace = -1;
				} else if (!allowMultilineJsxText && Stringutil.IsLineBreak(ch) && firstNonWhitespace > 0) {
					// Stop JsxText on each line during formatting. This allows the formatter to
					// indent each line correctly.
					break;
				} else if (!Stringutil.IsWhiteSpaceLike(ch)) {
					firstNonWhitespace = pos;
				}
				pos += size;
			}
			tokenValue = text.substring(fullStartPos, pos);
			token = KindJsxText;
			if (firstNonWhitespace == -1) {
				token = KindJsxTextAllWhiteSpaces;
			}
		}
		return token;
	}

	// Scans a JSX identifier; these differ from normal identifiers in that they allow dashes
	public function ScanJsxIdentifier():Kind {
		if (tokenIsIdentifierOrKeyword(token)) {
			// An identifier or keyword has already been parsed - check for a `-` or a single instance of `:` and then append it and
			// everything after it to the token
			// Do note that this means that `scanJsxIdentifier` effectively _mutates_ the visible token without advancing to a new token
			// Any caller should be expecting this behavior and should only read the pos or token value after calling it.
			while (true) {
				final ch = char();
				if (ch < 0) {
					break;
				}
				if (ch == '-'.code) {
					tokenValue += "-";
					pos++;
					continue;
				}
				final oldPos = pos;
				tokenValue += scanIdentifierParts(); // reuse `scanIdentifierParts` so unicode escapes are handled
				if (pos == oldPos) {
					break;
				}
			}
			token = GetIdentifierToken(tokenValue);
		}
		return token;
	}

	public function ScanJsxAttributeValue():Kind {
		fullStartPos = pos;
		// Skip whitespace between '=' and the value so tokenStart lands on the
		// opening quote, not on trivia.
		var ch = charAndSize();
		var size = charSize(ch);
		while (size > 0 && Stringutil.IsWhiteSpaceLike(ch)) {
			pos += size;
			ch = charAndSize();
			size = charSize(ch);
		}
		tokenStart = pos;
		switch (char()) {
			case '"'.code | "'".code:
				tokenValue = scanString(true /*jsxAttributeString*/);
				token = KindStringLiteral;
				return token;
			default:
				// If this scans anything other than `{`, it's a parse error.
				return Scan();
		}
	}

	public function ReScanJsxAttributeValue():Kind {
		pos = fullStartPos;
		tokenStart = fullStartPos;
		return ScanJsxAttributeValue();
	}

	/** In addition to the usual JSDoc ast.Kinds, can also return ast.KindJSDocCommentTextToken */
	public function ScanJSDocCommentTextToken(inBackticks:Bool):Kind {
		fullStartPos = pos;
		tokenFlags = TokenFlagsNone;
		if (pos >= text.length) {
			token = KindEndOfFile;
			return token;
		}
		tokenStart = pos;
		var ch = charAndSize();
		var size = charSize(ch);
		while (pos < text.length && !Stringutil.IsLineBreak(ch) && ch != '`'.code) {
			if (!inBackticks) {
				if (ch == '{'.code) {
					break;
				} else if (ch == '@'.code && pos >= 0) {
					// @ doesn't start a new tag inside ``, and elsewhere, only after whitespace and before identifier
					final previous = Utf16.DecodeLastRuneBefore(text, pos);
					if (Stringutil.IsWhiteSpaceSingleLine(previous)) {
						final next = Utf16.DecodeRuneInString(text, pos + size);
						if (IsIdentifierStart(next)) {
							break;
						}
					}
				}
			}
			pos += size;
			ch = charAndSize();
			size = charSize(ch);
		}
		if (pos == tokenStart) {
			return ScanJSDocToken();
		}
		tokenValue = text.substring(tokenStart, pos);
		token = KindJSDocCommentTextToken;
		return token;
	}

	// Peek at the character at the current scanner position (expected to be right after '@')
	// and return true if a JSDoc tag can follow. Identifier starts indicate a tag name.
	// Whitespace, newlines, and EOF are also accepted to support incomplete tags for code completion.
	public function CanFollowJSDocAt():Bool {
		if (pos >= text.length) {
			return true;
		}
		final ch = Utf16.DecodeRuneInString(text, pos);
		return IsIdentifierStart(ch) || Stringutil.IsWhiteSpaceSingleLine(ch) || Stringutil.IsLineBreak(ch);
	}

	public function ScanJSDocToken():Kind {
		fullStartPos = pos;
		tokenFlags = TokenFlagsNone;
		if (pos >= text.length) {
			token = KindEndOfFile;
			return token;
		}

		tokenStart = pos;
		final ch = charAndSize();
		var size = charSize(ch);
		pos += size;
		switch (ch) {
			case '\t'.code | 0x0B | 0x0C | ' '.code:
				var ch2 = charAndSize();
				var size2 = charSize(ch2);
				while (size2 > 0 && Stringutil.IsWhiteSpaceSingleLine(ch2)) {
					pos += size2;
					ch2 = charAndSize();
					size2 = charSize(ch2);
				}
				token = KindWhitespaceTrivia;
				return token;
			case '@'.code:
				token = KindAtToken;
				return token;
			case '\r'.code:
				if (char() == '\n'.code) {
					pos++;
				}
				// fallthrough
				tokenFlags |= TokenFlagsPrecedingLineBreak;
				token = KindNewLineTrivia;
				return token;
			case '\n'.code:
				tokenFlags |= TokenFlagsPrecedingLineBreak;
				token = KindNewLineTrivia;
				return token;
			case '*'.code:
				token = KindAsteriskToken;
				return token;
			case '{'.code:
				token = KindOpenBraceToken;
				return token;
			case '}'.code:
				token = KindCloseBraceToken;
				return token;
			case '['.code:
				token = KindOpenBracketToken;
				return token;
			case ']'.code:
				token = KindCloseBracketToken;
				return token;
			case '('.code:
				token = KindOpenParenToken;
				return token;
			case ')'.code:
				token = KindCloseParenToken;
				return token;
			case '<'.code:
				token = KindLessThanToken;
				return token;
			case '>'.code:
				token = KindGreaterThanToken;
				return token;
			case '='.code:
				token = KindEqualsToken;
				return token;
			case ','.code:
				token = KindCommaToken;
				return token;
			case '.'.code:
				token = KindDotToken;
				return token;
			case '`'.code:
				token = KindBacktickToken;
				return token;
			case '#'.code:
				token = KindHashToken;
				return token;
			case '\\'.code:
				pos--;
				final cp = peekUnicodeEscape();
				if (cp >= 0 && IsIdentifierStart(cp)) {
					tokenValue = Utf16.RuneString(scanUnicodeEscape(true)) + scanIdentifierParts();
					token = GetIdentifierToken(tokenValue);
				} else {
					pos++;
					token = KindUnknown;
				}
				return token;
			default:
		}

		if (IsIdentifierStart(ch)) {
			var char = ch;
			while (true) {
				if (pos >= text.length) {
					break;
				}
				char = charAndSize();
				size = charSize(char);
				if (!IsIdentifierPart(char) && char != '-'.code) {
					break;
				}
				pos += size;
			}
			tokenValue = text.substring(tokenStart, pos);
			if (char == '\\'.code) {
				tokenValue += scanIdentifierParts();
			}
			token = GetIdentifierToken(tokenValue);
			return token;
		} else {
			token = KindUnknown;
			return token;
		}
	}

	function scanIdentifier(prefixLength:Int):Bool {
		final start = pos;
		pos += prefixLength;
		var ch = char();
		// Fast path for simple ASCII identifiers
		if (Stringutil.IsASCIILetter(ch) || ch == '_'.code || ch == '$'.code) {
			pos++;
			scanASCIIWhile(b -> (b >= 'a'.code && b <= 'z'.code) || (b >= 'A'.code && b <= 'Z'.code) || (b >= '0'.code && b <= '9'.code) || b == '_'.code
				|| b == '$'.code);
			ch = char();
			if (ch < Utf16.RuneSelf && ch != '\\'.code) {
				tokenValue = text.substring(start, pos);
				return true;
			}
			pos = start + prefixLength;
		}
		ch = charAndSize();
		var size = charSize(ch);
		if (IsIdentifierStart(ch)) {
			while (true) {
				pos += size;
				ch = charAndSize();
				size = charSize(ch);
				if (!IsIdentifierPart(ch)) {
					break;
				}
			}
			tokenValue = text.substring(start, pos);
			if (ch == '\\'.code) {
				tokenValue += scanIdentifierParts();
			}
			return true;
		}
		return false;
	}

	function scanIdentifierParts():String {
		final sb = new StringBuf();
		var start = pos;
		while (true) {
			final ch = charAndSize();
			final size = charSize(ch);
			if (IsIdentifierPart(ch)) {
				pos += size;
				continue;
			}
			if (ch == '\\'.code) {
				final escaped = peekUnicodeEscape();
				if (escaped >= 0 && IsIdentifierPart(escaped)) {
					sb.addSub(text, start, pos - start);
					Utf16.WriteRune(sb, scanUnicodeEscape(true));
					start = pos;
					continue;
				}
			}
			break;
		}
		sb.addSub(text, start, pos - start);
		return sb.toString();
	}

	function scanString(jsxAttributeString:Bool):String {
		final quote = char();
		if (quote == "'".code) {
			tokenFlags |= TokenFlagsSingleQuote;
		}
		pos++;
		// Fast path for simple strings without escape sequences.
		// PORT: strings.IndexByte(s.text[s.pos:], byte(quote)) without the slice.
		var strLen = text.indexOf(quote == "'".code ? "'" : '"', pos);
		if (strLen >= 0) {
			strLen -= pos;
		}
		if (strLen == 0) {
			pos++;
			return "";
		}
		if (strLen > 0) {
			final str = text.substring(pos, pos + strLen);
			if (jsxAttributeString || str.indexOf("\\") < 0 && str.indexOf("\r") < 0 && str.indexOf("\n") < 0) {
				pos += strLen + 1;
				return str;
			}
		}
		final sb = new StringBuf();
		var start = pos;
		while (true) {
			final ch = char();
			if (ch < 0) {
				sb.addSub(text, start, pos - start);
				tokenFlags |= TokenFlagsUnterminated;
				error(Diagnostics.Unterminated_string_literal);
				break;
			}
			if (ch == quote) {
				sb.addSub(text, start, pos - start);
				pos++;
				break;
			}
			if (ch == '\\'.code && !jsxAttributeString) {
				sb.addSub(text, start, pos - start);
				sb.add(scanEscapeSequence(EscapeSequenceScanningFlagsString | EscapeSequenceScanningFlagsReportErrors));
				start = pos;
				continue;
			}
			if ((ch == '\n'.code || ch == '\r'.code) && !jsxAttributeString) {
				sb.addSub(text, start, pos - start);
				tokenFlags |= TokenFlagsUnterminated;
				error(Diagnostics.Unterminated_string_literal);
				break;
			}
			pos++;
		}
		return sb.toString();
	}

	function scanTemplateAndSetTokenValue(shouldEmitInvalidEscapeError:Bool):Kind {
		final startedWithBacktick = char() == '`'.code;
		pos++;
		var start = pos;
		final parts = new Array<String>();
		var token:Kind = KindUnknown;
		while (true) {
			scanASCIIWhile(b -> b != '`'.code && b != '$'.code && b != '\\'.code && b != '\r'.code);
			final ch = char();
			if (ch < 0 || ch == '`'.code) {
				parts.push(text.substring(start, pos));
				if (ch == '`'.code) {
					pos++;
				} else {
					tokenFlags |= TokenFlagsUnterminated;
					error(Diagnostics.Unterminated_template_literal);
				}
				token = Core.IfElse(startedWithBacktick, KindNoSubstitutionTemplateLiteral, KindTemplateTail);
				break;
			}
			if (ch == '$'.code && charAt(1) == '{'.code) {
				parts.push(text.substring(start, pos));
				pos += 2;
				token = Core.IfElse(startedWithBacktick, KindTemplateHead, KindTemplateMiddle);
				break;
			}
			if (ch == '\\'.code) {
				parts.push(text.substring(start, pos));
				parts.push(scanEscapeSequence(EscapeSequenceScanningFlagsString | Core.IfElse(shouldEmitInvalidEscapeError, EscapeSequenceScanningFlagsReportErrors, 0)));
				start = pos;
				continue;
			}
			// Speculated ECMAScript 6 Spec 11.8.6.1:
			// <CR><LF> and <CR> LineTerminatorSequences are normalized to <LF> for Template Values
			if (ch == '\r'.code) {
				parts.push(text.substring(start, pos));
				pos++;
				if (char() == '\n'.code) {
					pos++;
				}
				parts.push("\n");
				start = pos;
				continue;
			}
			pos++;
		}
		tokenValue = parts.join("");
		return token;
	}

	function scanEscapeSequence(flags:EscapeSequenceScanningFlags):String {
		final start = pos;
		pos++;
		var ch = char();
		if (ch < 0) {
			error(Diagnostics.Unexpected_end_of_text);
			return "";
		}
		pos++;
		switch (ch) {
			case '0'.code | '1'.code | '2'.code | '3'.code | '4'.code | '5'.code | '6'.code | '7'.code:
				// PORT: Go `case '0'` falls through to `case '1','2','3'`, which falls through to `case '4'..'7'`.
				if (ch == '0'.code) {
					// Although '0' preceding any digit is treated as LegacyOctalEscapeSequence,
					// '\08' should separately be interpreted as '\0' + '8'.
					if (!Stringutil.IsDigit(char())) {
						return "\x00";
					}
					// '\01', '\011'
				}
				if (ch <= '3'.code) {
					// '\1', '\17', '\177'
					if (Stringutil.IsOctalDigit(char())) {
						pos++;
					}
					// '\17', '\177'
				}
				// '\4', '\47' but not '\477'
				if (Stringutil.IsOctalDigit(char())) {
					pos++;
				}
				// '\47'
				tokenFlags |= TokenFlagsContainsInvalidEscape;
				if ((flags & EscapeSequenceScanningFlagsReportInvalidEscapeErrors) != 0) {
					final code = parseInt32(text.substring(start + 1, pos), 8);
					if ((flags & EscapeSequenceScanningFlagsRegularExpression) != 0 && (flags & EscapeSequenceScanningFlagsAtomEscape) == 0 && ch != '0'.code) {
						errorAt(Diagnostics.Octal_escape_sequences_and_backreferences_are_not_allowed_in_a_character_class_If_this_was_intended_as_an_escape_sequence_use_the_syntax_0_instead,
							start, pos - start, "\\x" + StringTools.hex(code, 2).toLowerCase());
					} else {
						errorAt(Diagnostics.Octal_escape_sequences_are_not_allowed_Use_the_syntax_0, start, pos - start, "\\x" + StringTools.hex(code, 2).toLowerCase());
					}
					return Utf16.RuneString(code);
				}
				return text.substring(start, pos);
			case '8'.code | '9'.code:
				// the invalid '\8' and '\9'
				tokenFlags |= TokenFlagsContainsInvalidEscape;
				if ((flags & EscapeSequenceScanningFlagsReportInvalidEscapeErrors) != 0) {
					if ((flags & EscapeSequenceScanningFlagsRegularExpression) != 0 && (flags & EscapeSequenceScanningFlagsAtomEscape) == 0) {
						errorAt(Diagnostics.Decimal_escape_sequences_and_backreferences_are_not_allowed_in_a_character_class, start, pos - start);
					} else {
						errorAt(Diagnostics.Escape_sequence_0_is_not_allowed, start, pos - start, text.substring(start, pos));
					}
					return Utf16.RuneString(ch);
				}
				return text.substring(start, pos);
			case 'b'.code:
				return "\x08";
			case 't'.code:
				return "\t";
			case 'n'.code:
				return "\n";
			case 'v'.code:
				return "\x0B";
			case 'f'.code:
				return "\x0C";
			case 'r'.code:
				return "\r";
			case "'".code:
				return "'";
			case '"'.code:
				return "\"";
			case 'u'.code:
				// '\uDDDD' and '\u{DDDDDD}'
				final extended = char() == '{'.code;
				pos -= 2;
				final codePoint = scanUnicodeEscape((flags & EscapeSequenceScanningFlagsReportInvalidEscapeErrors) != 0);
				if (extended) {
					if ((flags & EscapeSequenceScanningFlagsAllowExtendedUnicodeEscape) == 0) {
						tokenFlags |= TokenFlagsContainsInvalidEscape;
						if ((flags & EscapeSequenceScanningFlagsReportInvalidEscapeErrors) != 0) {
							errorAt(Diagnostics.Unicode_escape_sequences_are_only_available_when_the_Unicode_u_flag_or_the_Unicode_Sets_v_flag_is_set, start, pos - start);
						}
					}
					if (codePoint < 0) {
						return text.substring(start, pos);
					}
					// In string literals, a high surrogate \u{...} followed by a low
					// surrogate escape forms a single code point, exactly as adjacent
					// UTF-16 code units would in a JavaScript string.
					if ((flags & EscapeSequenceScanningFlagsRegularExpression) == 0 && Stringutil.IsHighSurrogate(codePoint)) {
						final combined = scanLowSurrogateEscape(codePoint);
						if (combined >= 0) {
							return Utf16.RuneString(combined);
						}
					}
					return Stringutil.EncodeJSStringRune(codePoint);
				}
				if (codePoint < 0) {
					return text.substring(start, pos);
				} else if (Stringutil.IsHighSurrogate(codePoint)) {
					if ((flags & EscapeSequenceScanningFlagsRegularExpression) == 0) {
						// Combine \uHigh followed by any low surrogate escape (\uLow or
						// \u{Low}) into a single code point in string literals, matching
						// how adjacent UTF-16 code units pair in a JavaScript string.
						final combined = scanLowSurrogateEscape(codePoint);
						if (combined >= 0) {
							return Utf16.RuneString(combined);
						}
					} else if ((flags & EscapeSequenceScanningFlagsAnyUnicodeMode) != 0
						&& char() == '\\'.code
						&& charAt(1) == 'u'.code
						&& charAt(2) != '{'.code) {
						// In regex AnyUnicodeMode, combine \uHigh\uLow so scanClassRanges
						// can compare the pair numerically. In non-unicode regex mode they
						// are separate atoms, and extended \u{...} escapes never combine.
						final savedPos = pos;
						final nextCodePoint = scanUnicodeEscape((flags & EscapeSequenceScanningFlagsReportInvalidEscapeErrors) != 0);
						if (Stringutil.IsLowSurrogate(nextCodePoint)) {
							return Utf16.RuneString(Stringutil.SurrogatePairToCodePoint(codePoint, nextCodePoint));
						}
						pos = savedPos;
					}
				}
				// Lone surrogate: encode as CESU-8 so it survives losslessly. In a
				// non-unicode regex this also lets scanClassRanges compare it numerically.
				return Stringutil.EncodeJSStringRune(codePoint);
			case 'x'.code:
				// '\xDD'
				while (pos < start + 4) {
					if (!Stringutil.IsHexDigit(char())) {
						tokenFlags |= TokenFlagsContainsInvalidEscape;
						if ((flags & EscapeSequenceScanningFlagsReportInvalidEscapeErrors) != 0) {
							error(Diagnostics.Hexadecimal_digit_expected);
						}
						return text.substring(start, pos);
					}
					pos++;
				}
				tokenFlags |= TokenFlagsHexEscape;
				final escapedValue = parseInt32(text.substring(start + 2, pos), 16);
				return Utf16.RuneString(escapedValue);
			case '\r'.code:
				// when encountering a LineContinuation (i.e. a backslash and a line terminator sequence),
				// the line terminator is interpreted to be "the empty code unit sequence".
				if (char() == '\n'.code) {
					pos++;
				}
				// fallthrough
				return "";
			case '\n'.code:
				return "";
			default:
				// ch was read as a single byte; for multi-byte UTF-8 characters,
				// we need to decode the full rune and advance past all its bytes.
				if (ch >= Utf16.RuneSelf) {
					pos--; // back up past the single-byte advance
					ch = Utf16.DecodeRuneInString(text, pos);
					pos += Utf16.RuneLen(ch);
				}
				// LineContinuation: a backslash followed by a line terminator is "the empty code unit sequence".
				if (ch == 0x2028 || ch == 0x2029) {
					return "";
				}
				if ((flags & EscapeSequenceScanningFlagsAnyUnicodeMode) != 0
					|| ((flags & EscapeSequenceScanningFlagsRegularExpression) != 0
						&& (flags & EscapeSequenceScanningFlagsAnnexB) == 0
						&& IsIdentifierPart(ch))) {
					errorAt(Diagnostics.This_character_cannot_be_escaped_in_a_regular_expression, start, pos - start);
				}
				return Utf16.RuneString(ch);
		}
	}

	// PORT: strconv.ParseInt(s, base, 32) on digits that were already validated, without the
	// Int64 round trip (it runs per escape). On overflow Go returns the int32 maximum.
	static function parseInt32(s:String, base:Int):Int {
		var n = 0;
		for (i in 0...s.length) {
			final c = StringTools.fastCodeAt(s, i);
			final d = c <= '9'.code ? c - '0'.code : (c | 0x20) - 'a'.code + 10;
			if (n > Std.int((0x7FFFFFFF - d) / base)) {
				return 0x7FFFFFFF;
			}
			n = n * base + d;
		}
		return n;
	}

	// Known to be at \u
	function scanUnicodeEscape(shouldEmitInvalidEscapeError:Bool):Int {
		pos += 2;
		final start = pos;
		final extended = char() == '{'.code;
		var hexDigits:String;
		if (extended) {
			pos++;
			hexDigits = scanHexDigits(1, true, false);
		} else {
			tokenFlags |= TokenFlagsUnicodeEscape;
			hexDigits = scanHexDigits(4, false, false);
		}
		if (hexDigits == "") {
			tokenFlags |= TokenFlagsContainsInvalidEscape;
			if (shouldEmitInvalidEscapeError) {
				error(Diagnostics.Hexadecimal_digit_expected);
			}
			return -1;
		}
		final hexValue = parseInt32(hexDigits, 16);
		if (extended) {
			var isInvalidExtendedEscape = false;
			if (hexValue > 0x10FFFF) {
				if (shouldEmitInvalidEscapeError) {
					errorAt(Diagnostics.An_extended_Unicode_escape_value_must_be_between_0x0_and_0x10FFFF_inclusive, start + 1, pos - start - 1);
				}
				isInvalidExtendedEscape = true;
			}
			if (pos >= end) {
				if (shouldEmitInvalidEscapeError) {
					error(Diagnostics.Unexpected_end_of_text);
				}
				isInvalidExtendedEscape = true;
			} else if (char() == '}'.code) {
				pos++;
			} else {
				if (shouldEmitInvalidEscapeError) {
					error(Diagnostics.Unterminated_Unicode_escape_sequence);
				}
				isInvalidExtendedEscape = true;
			}
			if (isInvalidExtendedEscape) {
				tokenFlags |= TokenFlagsContainsInvalidEscape;
				return -1;
			}
			tokenFlags |= TokenFlagsExtendedUnicodeEscape;
		}
		return hexValue;
	}

	// scanLowSurrogateEscape attempts to consume a low-surrogate Unicode escape
	// (either '\uLow' or '\u{Low}') immediately following an already-scanned high
	// surrogate and combine them into a single supplementary code point. This
	// mirrors how adjacent UTF-16 code units form a surrogate pair in a JavaScript
	// string, regardless of which escape syntax produced each half. On success it
	// returns the combined code point and true; otherwise it restores the scanner
	// position and returns false.
	// PORT: Go returns (rune, bool); here the combined code point, or -1 for false.
	function scanLowSurrogateEscape(high:Int):Int {
		if (char() != '\\'.code || charAt(1) != 'u'.code) {
			return -1;
		}
		final savedPos = pos;
		final savedTokenFlags = tokenFlags;
		// Speculatively scan the escape with diagnostics suppressed: if it isn't a
		// low surrogate we rewind below, and the caller re-scans the same escape and
		// reports any error then, so reporting here would duplicate diagnostics.
		final low = scanUnicodeEscape(false);
		if (Stringutil.IsLowSurrogate(low)) {
			return Stringutil.SurrogatePairToCodePoint(high, low);
		}
		pos = savedPos;
		tokenFlags = savedTokenFlags;
		return -1;
	}

	// Current character is known to be a backslash. Check for Unicode escape of the form '\uXXXX'
	// or '\u{XXXXXX}' and return code point value if valid Unicode escape is found. Otherwise return -1.
	function peekUnicodeEscape():Int {
		if (charAt(1) == 'u'.code) {
			final savePos = pos;
			final saveTokenFlags = tokenFlags;
			final codePoint = scanUnicodeEscape(false);
			pos = savePos;
			tokenFlags = saveTokenFlags;
			return codePoint;
		}
		return -1;
	}

	function scanNumber():Kind {
		var start = pos;
		var fixedPart:String;
		if (char() == '0'.code) {
			pos++;
			if (char() == '_'.code) {
				tokenFlags |= TokenFlagsContainsSeparator | TokenFlagsContainsInvalidSeparator;
				errorAt(Diagnostics.Numeric_separators_are_not_allowed_here, pos, 1);
				pos = start;
				fixedPart = scanNumberFragment();
			} else {
				final r = scanDigits();
				final digits = r.value;
				final isOctal = r.ok;
				if (digits == "") {
					fixedPart = "0";
				} else if (!isOctal) {
					tokenFlags |= TokenFlagsContainsLeadingZero;
					fixedPart = digits;
				} else {
					final val = Strconv.ParseInt(digits, 8, 64).value;
					tokenValue = Strconv.FormatInt(val, 10);
					tokenFlags |= TokenFlagsOctal;
					final withMinus = token == KindMinusToken;
					final literal = Core.IfElse(withMinus, "-", "") + "0o" + formatOctalDigits(digits);
					if (withMinus) {
						start--;
					}
					errorAt(Diagnostics.Octal_literals_are_not_allowed_Use_the_syntax_0, start, pos - start, literal);
					return KindNumericLiteral;
				}
			}
		} else {
			fixedPart = scanNumberFragment();
		}
		final fixedPartEnd = pos;
		var fractionalPart = "";
		var exponentPreamble = "";
		var exponentPart = "";
		if (char() == '.'.code) {
			pos++;
			fractionalPart = scanNumberFragment();
		}
		var end = pos;
		if (char() == 'E'.code || char() == 'e'.code) {
			pos++;
			tokenFlags |= TokenFlagsScientific;
			if (char() == '+'.code || char() == '-'.code) {
				pos++;
			}
			final startNumericPart = pos;
			exponentPart = scanNumberFragment();
			if (exponentPart == "") {
				error(Diagnostics.Digit_expected);
			} else {
				exponentPreamble = text.substring(end, startNumericPart);
				end = pos;
			}
		}
		if ((tokenFlags & TokenFlagsContainsSeparator) != 0) {
			tokenValue = fixedPart;
			if (fractionalPart != "") {
				tokenValue += "." + fractionalPart;
			}
			if (exponentPart != "") {
				tokenValue += exponentPreamble + exponentPart;
			}
		} else {
			tokenValue = text.substring(start, end);
		}
		if ((tokenFlags & TokenFlagsContainsLeadingZero) != 0) {
			errorAt(Diagnostics.Decimals_with_leading_zeros_are_not_allowed, start, pos - start);
			tokenValue = Jsnum.FromString(tokenValue).String();
			return KindNumericLiteral;
		}
		var result:Kind;
		if (fixedPartEnd == pos) {
			result = scanBigIntSuffix();
		} else {
			tokenValue = Jsnum.FromString(tokenValue).String();
			result = KindNumericLiteral;
		}
		final ch = charAndSize();
		if (IsIdentifierStart(ch)) {
			final idStart = pos;
			final id = scanIdentifierParts();
			if (result != KindBigIntLiteral && id.length == 1 && StringTools.fastCodeAt(text, idStart) == 'n'.code) {
				if ((tokenFlags & TokenFlagsScientific) != 0) {
					errorAt(Diagnostics.A_bigint_literal_cannot_use_exponential_notation, start, pos - start);
					return result;
				}
				if (fixedPartEnd < idStart) {
					errorAt(Diagnostics.A_bigint_literal_must_be_an_integer, start, pos - start);
					return result;
				}
			}
			errorAt(Diagnostics.An_identifier_or_keyword_cannot_immediately_follow_a_numeric_literal, idStart, pos - idStart);
			pos = idStart;
		}
		return result;
	}

	// PORT: strconv.FormatInt(strconv.ParseInt(digits, 8, 64), 8) computed on the digit string (the
	// go.Strconv shim formats base 10 only): the digits without leading zeros, or the int64 maximum
	// 0o777777777777777777777 when ParseInt overflows (more than 21 significant octal digits).
	static function formatOctalDigits(digits:String):String {
		var i = 0;
		while (i < digits.length - 1 && StringTools.fastCodeAt(digits, i) == '0'.code) {
			i++;
		}
		final s = digits.substring(i);
		if (s.length > 21) {
			return "777777777777777777777";
		}
		return s;
	}

	function scanNumberFragment():String {
		var start = pos;
		var allowSeparator = false;
		var isPreviousTokenSeparator = false;
		final result = new StringBuf();
		while (true) {
			final before = pos;
			scanASCIIWhile(b -> b >= '0'.code && b <= '9'.code);
			if (pos > before) {
				allowSeparator = true;
				isPreviousTokenSeparator = false;
			}
			final ch = char();
			if (ch == '_'.code) {
				tokenFlags |= TokenFlagsContainsSeparator;
				if (allowSeparator) {
					allowSeparator = false;
					isPreviousTokenSeparator = true;
					result.addSub(text, start, pos - start);
				} else {
					tokenFlags |= TokenFlagsContainsInvalidSeparator;
					if (isPreviousTokenSeparator) {
						errorAt(Diagnostics.Multiple_consecutive_numeric_separators_are_not_permitted, pos, 1);
					} else {
						errorAt(Diagnostics.Numeric_separators_are_not_allowed_here, pos, 1);
					}
				}
				pos++;
				start = pos;
				continue;
			}
			break;
		}
		if (isPreviousTokenSeparator) {
			tokenFlags |= TokenFlagsContainsInvalidSeparator;
			errorAt(Diagnostics.Numeric_separators_are_not_allowed_here, pos - 1, 1);
		}
		if (result.length == 0) {
			return text.substring(start, pos);
		}
		result.addSub(text, start, pos - start);
		return result.toString();
	}

	// PORT: Go returns (string, bool); here a ValueOk (value = digits, ok = isOctal).
	function scanDigits():ValueOk<String> {
		final start = pos;
		var isOctal = true;
		while (Stringutil.IsDigit(char())) {
			if (!Stringutil.IsOctalDigit(char())) {
				isOctal = false;
			}
			pos++;
		}
		return new ValueOk(text.substring(start, pos), isOctal);
	}

	function scanHexDigits(minCount:Int, scanAsManyAsPossible:Bool, canHaveSeparators:Bool):String {
		var digitCount = 0;
		final start = pos;
		var allowSeparator = false;
		var isPreviousTokenSeparator = false;
		while (digitCount < minCount || scanAsManyAsPossible) {
			final ch = char();
			if (Stringutil.IsHexDigit(ch)) {
				allowSeparator = canHaveSeparators;
				isPreviousTokenSeparator = false;
				digitCount++;
			} else if (canHaveSeparators && ch == '_'.code) {
				tokenFlags |= TokenFlagsContainsSeparator;
				if (allowSeparator) {
					allowSeparator = false;
					isPreviousTokenSeparator = true;
				} else if (isPreviousTokenSeparator) {
					errorAt(Diagnostics.Multiple_consecutive_numeric_separators_are_not_permitted, pos, 1);
				} else {
					errorAt(Diagnostics.Numeric_separators_are_not_allowed_here, pos, 1);
				}
			} else {
				break;
			}
			pos++;
		}
		if (isPreviousTokenSeparator) {
			errorAt(Diagnostics.Numeric_separators_are_not_allowed_here, pos - 1, 1);
		}
		if (digitCount < minCount) {
			return "";
		}
		var digits = text.substring(start, pos);
		if (hexDigitCache == null) {
			hexDigitCache = new StringMap<String>();
		}
		final cached = hexDigitCache.get(digits);
		if (cached != null) {
			return cached;
		} else {
			final original = digits;
			if ((tokenFlags & TokenFlagsContainsSeparator) != 0) {
				digits = Strings.ReplaceAll(digits, "_", "");
			}
			digits = digits.toLowerCase(); // standardize hex literals to lowercase
			hexDigitCache.set(original, digits);
			return digits;
		}
	}

	function scanBinaryOrOctalDigits(base:Int):String {
		final sb = new StringBuf();
		var allowSeparator = false;
		var isPreviousTokenSeparator = false;
		while (true) {
			final ch = char();
			if (Stringutil.IsDigit(ch) && ch - '0'.code < base) {
				sb.addChar(ch);
				allowSeparator = true;
				isPreviousTokenSeparator = false;
			} else if (ch == '_'.code) {
				tokenFlags |= TokenFlagsContainsSeparator;
				if (allowSeparator) {
					allowSeparator = false;
					isPreviousTokenSeparator = true;
				} else if (isPreviousTokenSeparator) {
					errorAt(Diagnostics.Multiple_consecutive_numeric_separators_are_not_permitted, pos, 1);
				} else {
					errorAt(Diagnostics.Numeric_separators_are_not_allowed_here, pos, 1);
				}
			} else {
				break;
			}
			pos++;
		}
		if (isPreviousTokenSeparator) {
			errorAt(Diagnostics.Numeric_separators_are_not_allowed_here, pos - 1, 1);
		}
		return sb.toString();
	}

	function scanBigIntSuffix():Kind {
		if (char() == 'n'.code) {
			tokenValue += "n";
			if ((tokenFlags & TokenFlagsBinaryOrOctalSpecifier) != 0) {
				tokenValue = Jsnum.ParsePseudoBigInt(tokenValue) + "n";
			}
			pos++;
			return KindBigIntLiteral;
		}
		if (numberCache == null) {
			numberCache = new StringMap<String>();
		}
		final cached = numberCache.get(tokenValue);
		if (cached != null) {
			tokenValue = cached;
		} else {
			var tokenValue = Jsnum.FromString(this.tokenValue).String();
			if (tokenValue == this.tokenValue) {
				tokenValue = this.tokenValue;
			}
			numberCache.set(this.tokenValue, tokenValue);
			this.tokenValue = tokenValue;
		}
		return KindNumericLiteral;
	}

	function scanInvalidCharacter():Void {
		final size = charSize(charAndSize());
		errorAt(Diagnostics.Invalid_character, pos, size);
		pos += size;
		token = KindUnknown;
	}

	public static function GetIdentifierToken(str:String):Kind {
		if (str.length >= 2 && str.length <= 12 && StringTools.fastCodeAt(str, 0) >= 'a'.code && StringTools.fastCodeAt(str, 0) <= 'z'.code) {
			final keyword = textToKeyword.get(str);
			if (keyword != null && keyword != KindUnknown) {
				return keyword;
			}
		}
		return KindIdentifier;
	}

	public static function IsValidIdentifier(s:String):Bool {
		if (s.length == 0) {
			return false;
		}
		var i = 0;
		while (i < s.length) {
			final ch = Utf16.DecodeRuneInString(s, i);
			if (i == 0 && !IsIdentifierStart(ch) || i != 0 && !IsIdentifierPart(ch)) {
				return false;
			}
			i += Utf16.RuneLen(ch);
		}
		return true;
	}

	// Section 6.1.4
	static inline function isWordCharacter(ch:Int):Bool {
		return Stringutil.IsASCIILetter(ch) || Stringutil.IsDigit(ch) || ch == '_'.code;
	}

	public static function IsIdentifierStart(ch:Int):Bool {
		return Stringutil.IsASCIILetter(ch) || ch == '_'.code || ch == '$'.code || ch >= Utf16.RuneSelf && Stringutil.IsUnicodeIdentifierStart(ch);
	}

	public static function IsIdentifierPart(ch:Int):Bool {
		return IsIdentifierPartEx(ch, LanguageVariantStandard);
	}

	public static function IsIdentifierPartEx(ch:Int, languageVariant:LanguageVariant):Bool {
		return isWordCharacter(ch)
			|| ch == '$'.code
			|| ch >= Utf16.RuneSelf && Stringutil.IsUnicodeIdentifierPart(ch)
			|| languageVariant == LanguageVariantJSX && (ch == '-'.code || ch == ':'.code); // "-" and ":" are valid in JSX Identifiers
	}

	static final tokenToText:Array<String> = (function() {
		final result = [for (_ in 0...KindCount) ""];
		for (text => kind in textToToken) {
			result[kind] = text;
		}
		return result;
	})();

	public static function TokenToString(token:Kind):String {
		return tokenToText[token];
	}

	public static function StringToToken(s:String):Kind {
		final kind = textToToken.get(s);
		if (kind != null) {
			return kind;
		}
		return KindUnknown;
	}

	public static function GetViableKeywordSuggestions():Array<String> {
		final result = new Array<String>();
		for (text in textToKeyword.keys()) {
			if (text.length > 2) {
				result.push(text);
			}
		}
		return result;
	}

	static function couldStartTrivia(text:String, pos:Int):Bool {
		// Keep in sync with skipTrivia
		final ch = StringTools.fastCodeAt(text, pos);
		switch (ch) {
			// Characters that could start normal trivia
			case '\r'.code | '\n'.code | '\t'.code | 0x0B | 0x0C | ' '.code | '/'.code |
				// Characters that could start conflict marker trivia
				'<'.code | '|'.code | '='.code | '>'.code:
				return true;
			case '#'.code:
				// Only if its the beginning can we have #! trivia
				return pos == 0;
			default:
				return ch > maxAsciiCharacter;
		}
	}

	public static function SkipTrivia(text:String, pos:Int):Int {
		return SkipTriviaEx(text, pos, null);
	}

	public static function SkipTriviaEx(text:String, pos:Int, options:SkipTriviaOptions):Int {
		if (Ast.PositionIsSynthesized(pos)) {
			return pos;
		}
		if (options == null) {
			options = new SkipTriviaOptions();
		}

		final textLen = text.length;
		var canConsumeStar = false;
		// Keep in sync with couldStartTrivia
		// PORT: Go `break` out of the switch reaches `return pos`; it is written as `return pos`.
		while (true) {
			if (pos >= textLen) {
				return pos;
			}
			final ch = Utf16.DecodeRuneInString(text, pos);
			final size = Utf16.RuneLen(ch);
			switch (ch) {
				case '\r'.code | '\n'.code:
					if (ch == '\r'.code) {
						if (pos + 1 < textLen && StringTools.fastCodeAt(text, pos + 1) == '\n'.code) {
							pos++;
						}
						// fallthrough
					}
					pos++;
					if (options.StopAfterLineBreak) {
						return pos;
					}
					canConsumeStar = options.InJSDoc;
					continue;
				case '\t'.code | 0x0B | 0x0C | ' '.code:
					pos++;
					continue;
				case '/'.code:
					if (options.StopAtComments) {
						return pos;
					}
					if (pos + 1 < textLen) {
						if (StringTools.fastCodeAt(text, pos + 1) == '/'.code) {
							pos += 2;
							while (pos < textLen) {
								final ch = Utf16.DecodeRuneInString(text, pos);
								if (Stringutil.IsLineBreak(ch)) {
									break;
								}
								pos += Utf16.RuneLen(ch);
							}
							canConsumeStar = false;
							continue;
						}
						if (StringTools.fastCodeAt(text, pos + 1) == '*'.code) {
							pos += 2;
							while (pos < textLen) {
								if (StringTools.fastCodeAt(text, pos) == '*'.code
									&& (pos + 1 < textLen)
									&& StringTools.fastCodeAt(text, pos + 1) == '/'.code) {
									pos += 2;
									break;
								}
								pos += Utf16.RuneLen(Utf16.DecodeRuneInString(text, pos));
							}
							canConsumeStar = false;
							continue;
						}
					}
				case '<'.code | '|'.code | '='.code | '>'.code:
					if (isConflictMarkerTrivia(text, pos)) {
						pos = scanConflictMarkerTrivia(text, pos, null);
						canConsumeStar = false;
						continue;
					}
				case '#'.code:
					if (pos == 0 && isShebangTrivia(text, pos)) {
						pos = scanShebangTrivia(text, pos);
						canConsumeStar = false;
						continue;
					}
				case '*'.code:
					if (canConsumeStar) {
						pos++;
						canConsumeStar = false;
						continue;
					}
				default:
					if (ch > maxAsciiCharacter && Stringutil.IsWhiteSpaceLike(ch)) {
						pos += size;
						continue;
					}
			}
			return pos;
		}
	}

	// All conflict markers consist of the same character repeated seven times.  If it is
	// a <<<<<<< or >>>>>>> marker then it is also followed by a space.
	static inline final mergeConflictMarkerLength = 7; // len("<<<<<<<")
	static inline final maxAsciiCharacter = 127;

	static function isConflictMarkerTrivia(text:String, pos:Int):Bool {
		if (pos < 0) {
			throw "pos < 0";
		}

		// Fast reject: a conflict marker is the same byte repeated seven times. If the
		// second byte differs (the overwhelmingly common case for `<`, `>`, `=`, `|`
		// tokens), it cannot be a marker, so skip the line-start check entirely.
		if (pos + 1 >= text.length || StringTools.fastCodeAt(text, pos + 1) != StringTools.fastCodeAt(text, pos)) {
			return false;
		}

		// Conflict markers must be at the start of a line.
		final atLineStart = conflictMarkerAtLineStart(text, pos);
		if (atLineStart) {
			final ch = StringTools.fastCodeAt(text, pos);

			if ((pos + mergeConflictMarkerLength) < text.length) {
				for (i in 0...mergeConflictMarkerLength) {
					if (StringTools.fastCodeAt(text, pos + i) != ch) {
						return false;
					}
				}

				return ch == '='.code || StringTools.fastCodeAt(text, pos + mergeConflictMarkerLength) == ' '.code;
			}
		}

		return false;
	}

	// PORT: byte — Go's line-start test on UTF-8 bytes:
	//   atLineStart := pos == 0 || IsLineBreak(rune(text[pos-1]))
	//   if !atLineStart && pos >= 2 { prev, _ := utf8.DecodeLastRuneInString(text[:pos-2]); atLineStart = IsLineBreak(prev) }
	// text[pos-1] is the last byte of the preceding character (a line break only for '\n'/'\r'),
	// and text[:pos-2] drops two bytes, which can cut a character in two (then RuneError). This
	// reproduces the byte arithmetic on the UTF-16 text, using the UTF-8 length of each character.
	static function conflictMarkerAtLineStart(text:String, pos:Int):Bool {
		if (pos == 0) {
			return true;
		}
		final c1 = Utf16.DecodeLastRuneBefore(text, pos);
		if (c1 == '\n'.code || c1 == '\r'.code) {
			return true;
		}
		final p1 = pos - Utf16.RuneLen(c1); // start of c1
		final b1 = utf8RuneLen(c1);
		if (b1 >= 3) {
			// text[:pos-2] ends inside c1
			return false;
		}
		if (b1 == 2) {
			// text[:pos-2] ends right before c1 (Go: pos >= 2 holds)
			return p1 > 0 && Stringutil.IsLineBreak(Utf16.DecodeLastRuneBefore(text, p1));
		}
		// b1 == 1: the cut removes one more byte, the last byte of c2
		if (p1 == 0) {
			return false; // Go: pos == 1, so pos >= 2 is false
		}
		final c2 = Utf16.DecodeLastRuneBefore(text, p1);
		if (utf8RuneLen(c2) != 1) {
			return false; // text[:pos-2] ends inside c2
		}
		final p2 = p1 - Utf16.RuneLen(c2);
		return p2 > 0 && Stringutil.IsLineBreak(Utf16.DecodeLastRuneBefore(text, p2));
	}

	static inline function utf8RuneLen(r:Int):Int {
		return r < 0x80 ? 1 : (r < 0x800 ? 2 : (r < 0x10000 ? 3 : 4));
	}

	static function scanConflictMarkerTrivia(text:String, pos:Int, reportError:(diag:Message, pos:Int, length:Int, ...args:Any) -> Void):Int {
		if (reportError != null) {
			reportError(Diagnostics.Merge_conflict_marker_encountered, pos, mergeConflictMarkerLength);
		}
		var ch = Utf16.DecodeRuneInString(text, pos);
		var size = Utf16.RuneLen(ch);
		final length = text.length;

		if (ch == '<'.code || ch == '>'.code) {
			while (pos < length && !Stringutil.IsLineBreak(ch)) {
				pos += size;
				ch = Utf16.DecodeRuneInString(text, pos);
				size = Utf16.RuneLen(ch);
			}
		} else {
			if (ch != '|'.code && ch != '='.code) {
				throw "Assertion failed: ch must be either '|' or '='";
			}
			// Consume everything from the start of a ||||||| or ======= marker to the start
			// of the next ======= or >>>>>>> marker.
			while (pos < length) {
				final currentChar = StringTools.fastCodeAt(text, pos);
				if ((currentChar == '='.code || currentChar == '>'.code) && currentChar != ch && isConflictMarkerTrivia(text, pos)) {
					break;
				}

				pos++;
			}
		}

		return pos;
	}

	static function isShebangTrivia(text:String, pos:Int):Bool {
		if (text.length < 2) {
			return false;
		}
		if (pos != 0) {
			throw "Shebangs check must only be done at the start of the file";
		}
		return StringTools.fastCodeAt(text, 0) == '#'.code && StringTools.fastCodeAt(text, 1) == '!'.code;
	}

	static function scanShebangTrivia(text:String, pos:Int):Int {
		pos += 2;
		while (pos < text.length) {
			final ch = Utf16.DecodeRuneInString(text, pos);
			if (Stringutil.IsLineBreak(ch)) {
				break;
			}
			pos += Utf16.RuneLen(ch);
		}
		return pos;
	}

	public static function GetShebang(text:String):String {
		if (!isShebangTrivia(text, 0)) {
			return "";
		}

		final end = scanShebangTrivia(text, 0);
		return text.substring(0, end);
	}

	public static function GetScannerForSourceFile(sourceFile:SourceFile, pos:Int):Scanner {
		final s = NewScanner();
		s.text = sourceFile.Text();
		s.pos = pos;
		s.end = s.text.length;
		s.languageVariant = sourceFile.LanguageVariant;
		s.Scan();
		return s;
	}

	public static function ScanTokenAtPosition(sourceFile:SourceFile, pos:Int):Kind {
		final s = GetScannerForSourceFile(sourceFile, pos);
		return s.token;
	}

	public static function GetRangeOfTokenAtPosition(sourceFile:SourceFile, pos:Int):TextRange {
		final s = GetScannerForSourceFile(sourceFile, pos);
		return Core.NewTextRange(s.tokenStart, s.pos);
	}

	public static function GetTokenPosOfNode(node:Node, sourceFile:SourceFile, includeJSDoc:Bool):Int {
		// With nodes that have no width (i.e. 'Missing' nodes), we actually *don't*
		// want to skip trivia because this will launch us forward to the next token.
		if (Ast.NodeIsMissing(node)) {
			return node.Pos();
		}
		if (Ast.IsJSDocNode(node) || node.Kind == KindJsxText) {
			// JsxText cannot actually contain comments, even though the scanner will think it sees comments
			final options = new SkipTriviaOptions();
			options.StopAtComments = true;
			return SkipTriviaEx(sourceFile.Text(), node.Pos(), options);
		}
		if (includeJSDoc && Core.len(node.JSDoc(sourceFile)) > 0) {
			return GetTokenPosOfNode(node.JSDoc(sourceFile)[0], sourceFile, false /*includeJSDoc*/);
		}
		final options = new SkipTriviaOptions();
		options.InJSDoc = (node.Flags & NodeFlagsJSDoc) != 0;
		return SkipTriviaEx(sourceFile.Text(), node.Pos(), options);
	}

	static function getErrorRangeForArrowFunction(sourceFile:SourceFile, node:Node):TextRange {
		final pos = SkipTrivia(sourceFile.Text(), node.Pos());
		final body = node.Body();
		if (body != null && body.Kind == KindBlock) {
			final startLine = GetECMALineOfPosition(sourceFile, body.Pos());
			final endLine = GetECMALineOfPosition(sourceFile, body.End());
			if (startLine < endLine) {
				// The arrow function spans multiple lines, make the error span be the first line, inclusive.
				return Core.NewTextRange(pos, GetECMAEndLinePosition(sourceFile, startLine) + 1);
			}
		}
		return Core.NewTextRange(pos, node.End());
	}

	static function findOriginatingJSDocSatisfiesTag(sourceFile:SourceFile, node:Node):Node {
		final targetType = node.AsSatisfiesExpression().Type;
		if ((targetType.Flags & NodeFlagsReparsed) == 0) {
			return null;
		}
		var current = node.Parent;
		while (current != null) {
			if ((current.Flags & NodeFlagsHasJSDoc) == 0) {
				current = current.Parent;
				continue;
			}
			var firstSatisfiesTag:Node = null;
			final jsDocs = current.EagerJSDoc(sourceFile);
			if (jsDocs != null) {
				for (jsDoc in jsDocs) {
					final tags = jsDoc.AsJSDoc().Tags;
					if (tags != null) {
						for (tag in tags.Nodes) {
							if (!Ast.IsJSDocSatisfiesTag(tag)) {
								continue;
							}
							if (firstSatisfiesTag == null) {
								firstSatisfiesTag = tag;
							}
							final typeExpr = tag.AsJSDocSatisfiesTag().TypeExpression;
							if (typeExpr != null) {
								final t = typeExpr.Type();
								if (t != null && t.Loc.Equals(targetType.Loc)) {
									return tag;
								}
							}
						}
					}
				}
			}
			return firstSatisfiesTag;
		}
		return null;
	}

	public static function GetErrorRangeForNode(sourceFile:SourceFile, node:Node):TextRange {
		var errorNode = node;
		switch (node.Kind) {
			case KindSourceFile:
				final pos = SkipTrivia(sourceFile.Text(), 0);
				if (pos == sourceFile.Text().length) {
					return Core.NewTextRange(0, 0);
				}
				return GetRangeOfTokenAtPosition(sourceFile, pos);
			// This list is a work in progress. Add missing node kinds to improve their error spans
			case KindFunctionDeclaration | KindMethodDeclaration | KindVariableDeclaration | KindBindingElement | KindClassDeclaration |
				KindInterfaceDeclaration | KindModuleDeclaration | KindEnumDeclaration | KindEnumMember | KindFunctionExpression | KindGetAccessor |
				KindSetAccessor | KindTypeAliasDeclaration | KindJSTypeAliasDeclaration | KindPropertyDeclaration | KindPropertySignature |
				KindNamespaceImport:
				// PORT: Go `case KindFunctionDeclaration, KindMethodDeclaration` falls through to this list
				// unless the node is reparsed.
				if ((node.Kind == KindFunctionDeclaration || node.Kind == KindMethodDeclaration) && (node.Flags & NodeFlagsReparsed) != 0) {
					errorNode = node;
				} else {
					errorNode = Ast.GetNameOfDeclaration(node);
				}
			case KindClassExpression:
				errorNode = node.Name();

			case KindArrowFunction:
				return getErrorRangeForArrowFunction(sourceFile, node);
			case KindCaseClause | KindDefaultClause:
				final start = SkipTrivia(sourceFile.Text(), node.Pos());
				var end = node.End();
				final statements = node.Statements();
				if (Core.len(statements) != 0) {
					end = statements[0].Pos();
				}
				return Core.NewTextRange(start, end);
			case KindReturnStatement | KindYieldExpression:
				final pos = SkipTrivia(sourceFile.Text(), node.Pos());
				return GetRangeOfTokenAtPosition(sourceFile, pos);
			case KindSatisfiesExpression:
				final jsDocSatisfiesTag = findOriginatingJSDocSatisfiesTag(sourceFile, node);
				if (jsDocSatisfiesTag != null) {
					final pos = SkipTrivia(sourceFile.Text(), jsDocSatisfiesTag.TagName().Pos());
					return GetRangeOfTokenAtPosition(sourceFile, pos);
				}
				final pos = SkipTrivia(sourceFile.Text(), node.AsSatisfiesExpression().Expression.End());
				return GetRangeOfTokenAtPosition(sourceFile, pos);
			case KindConstructor:
				if ((node.Flags & NodeFlagsReparsed) != 0) {
					errorNode = node;
				} else {
					final scanner = GetScannerForSourceFile(sourceFile, node.Pos());
					final start = scanner.TokenStart();
					while (scanner.Token() != KindConstructorKeyword && scanner.Token() != KindStringLiteral && scanner.Token() != KindEndOfFile) {
						scanner.Scan();
					}
					return Core.NewTextRange(start, scanner.TokenEnd());
				}
			default:
		}
		if (errorNode == null) {
			// If we don't have a better node, then just set the error on the first token of
			// construct.
			return GetRangeOfTokenAtPosition(sourceFile, node.Pos());
		}
		var pos = errorNode.Pos();
		if (!Ast.NodeIsMissing(errorNode) && !Ast.IsJsxText(errorNode)) {
			pos = SkipTrivia(sourceFile.Text(), pos);
		}
		return Core.NewTextRange(pos, errorNode.End());
	}

	public static function ComputeLineOfPosition(lineStarts:Array<TextPos>, pos:Int):Int {
		var low = 0;
		var high = lineStarts.length - 1;
		while (low <= high) {
			final middle = low + ((high - low) >> 1);
			final value:Int = lineStarts[middle];
			if (value < pos) {
				low = middle + 1;
			} else if (value > pos) {
				high = middle - 1;
			} else {
				return middle;
			}
		}
		return low - 1;
	}

	public static function GetECMALineStarts(sourceFile:SourceFileLike):Array<TextPos> {
		return sourceFile.ECMALineMap();
	}

	public static function GetECMALineOfPosition(sourceFile:SourceFileLike, pos:Int):Int {
		final lineMap = GetECMALineStarts(sourceFile);
		return ComputeLineOfPosition(lineMap, pos);
	}

	// GetECMALineAndUTF16CharacterOfPosition returns the 0-based line number and the
	// UTF-16 code unit offset from the start of that line for the given byte position.
	// Uses ECMAScript line separators (LF, CR, CRLF, LS, PS).
	// PORT: Go returns (line, character); here a Pair (a = line, b = character). Positions are
	// UTF-16 offsets, so UTF16Len(text[lineStart:pos]) is pos - lineStart (PORTING.md §5).
	public static function GetECMALineAndUTF16CharacterOfPosition(sourceFile:SourceFileLike, pos:Int):Pair<Int, UTF16Offset> {
		final lineMap = GetECMALineStarts(sourceFile);
		final line = ComputeLineOfPosition(lineMap, pos);
		final character:UTF16Offset = pos - lineMap[line];
		return new Pair(line, character);
	}

	// GetECMALineAndByteOffsetOfPosition returns the 0-based line number and the
	// raw UTF-8 byte offset from the start of that line for the given byte position.
	// Uses ECMAScript line separators (LF, CR, CRLF, LS, PS).
	// Unlike GetECMALineAndUTF16CharacterOfPosition, the offset is in bytes, not UTF-16 code units.
	// PORT: Go returns (line, byteOffset); here a Pair. Positions are UTF-16 offsets, so the
	// "byte offset" is a UTF-16 offset too (as everywhere in the port).
	public static function GetECMALineAndByteOffsetOfPosition(sourceFile:SourceFileLike, pos:Int):Pair<Int, Int> {
		final lineMap = GetECMALineStarts(sourceFile);
		final line = ComputeLineOfPosition(lineMap, pos);
		final byteOffset = pos - lineMap[line];
		return new Pair(line, byteOffset);
	}

	public static function GetECMAEndLinePosition(sourceFile:SourceFile, line:Int):Int {
		var pos:Int = GetECMALineStarts(sourceFile)[line];
		final text = sourceFile.Text();
		while (true) {
			final ch = Utf16.DecodeRuneInString(text, pos);
			if (pos >= text.length || Stringutil.IsLineBreak(ch)) {
				return pos - 1;
			}
			pos += Utf16.RuneLen(ch);
		}
	}

	// GetECMAPositionOfLineAndUTF16Character converts a 0-based line number and UTF-16
	// code unit character offset back to an absolute byte position in the source text.
	// Uses ECMAScript line separators.
	public static function GetECMAPositionOfLineAndUTF16Character(sourceFile:SourceFileLike, line:Int, character:UTF16Offset):Int {
		final lineStarts = GetECMALineStarts(sourceFile);
		return ComputePositionOfLineAndUTF16Character(lineStarts, line, character, sourceFile.Text(), false);
	}

	// GetECMAPositionOfLineAndByteOffset converts a 0-based line number and byte offset
	// from line start back to an absolute byte position in the source text.
	// Uses ECMAScript line separators.
	public static function GetECMAPositionOfLineAndByteOffset(sourceFile:SourceFileLike, line:Int, byteOffset:Int):Int {
		return ComputePositionOfLineAndByteOffset(GetECMALineStarts(sourceFile), line, byteOffset);
	}

	// ComputePositionOfLineAndByteOffset computes a byte position from a line and
	// raw byte offset from the line start. This is a simple addition with validation.
	public static function ComputePositionOfLineAndByteOffset(lineStarts:Array<TextPos>, line:Int, byteOffset:Int):Int {
		if (line < 0 || line >= lineStarts.length) {
			throw 'Bad line number. Line: ${line}, lineStarts.length: ${lineStarts.length}.';
		}
		return lineStarts[line] + byteOffset;
	}

	// ComputePositionOfLineAndUTF16Character converts a line and UTF-16 character offset
	// back to a byte position. The character parameter is measured in UTF-16 code units.
	// It scans from the line start to correctly handle multi-byte characters.
	// When allowEdits is true, out-of-range values are clamped instead of panicking.
	public static function ComputePositionOfLineAndUTF16Character(lineStarts:Array<TextPos>, line:Int, character:UTF16Offset, text:String,
			allowEdits:Bool):Int {
		if (line < 0 || line >= lineStarts.length) {
			if (allowEdits) {
				// Clamp line to nearest allowable value
				if (line < 0) {
					line = 0;
				} else if (line >= lineStarts.length) {
					line = lineStarts.length - 1;
				}
			} else {
				throw 'Bad line number. Line: ${line}, lineStarts.length: ${lineStarts.length}.';
			}
		}

		final lineStart:Int = lineStarts[line];

		if (character > 0) {
			// UTF-16 character offset: scan from line start counting UTF-16 code units.
			var lineEnd = text.length;
			if (line + 1 < lineStarts.length) {
				lineEnd = lineStarts[line + 1];
			}
			var utf16Count:UTF16Offset = 0;
			var pos = lineStart;
			while (pos < lineEnd) {
				if (utf16Count >= character) {
					break;
				}
				final r = Utf16.DecodeRuneInString(text, pos);
				final size = Utf16.RuneLen(r);
				utf16Count += size;
				pos += size;
			}
			if (!allowEdits) {
				if (pos == lineEnd && utf16Count < character) {
					throw 'Bad UTF-16 character offset. Line: ${line}, character: ${character}.';
				}
				Debug.Assert(pos <= text.length);
				return pos;
			}
			if (pos > text.length) {
				return text.length;
			}
			return pos;
		}

		// Character is 0: line start position.
		final res = lineStart;

		if (allowEdits) {
			if (res > text.length) {
				return text.length;
			}
			return res;
		}
		Debug.Assert(res <= text.length); // Allow single character overflow for trailing newline
		return res;
	}

	public static function GetLeadingCommentRanges(f:NodeFactory, text:String, pos:Int):haxe.iterators.ArrayIterator<CommentRange> {
		return iterateCommentRanges(f, text, pos, false);
	}

	public static function GetTrailingCommentRanges(f:NodeFactory, text:String, pos:Int):haxe.iterators.ArrayIterator<CommentRange> {
		return iterateCommentRanges(f, text, pos, true);
	}

	/*
		Returns an iterator over each comment range following the provided position.
		Single-line comment ranges include the leading double-slash characters but not the ending
		line break. Multi-line comment ranges include the leading slash-asterisk and trailing
		asterisk-slash characters.
	 */
	// PORT: Go returns iter.Seq (a push iterator); here the ranges are collected first and an
	// Iterator over them is returned (a consumer that stops early observes the same ranges).
	// PORT: perf — the concrete ArrayIterator type: through the `Iterator<T>` structure type hxcpp
	// calls hasNext/next by name (a closure allocation per call).
	static function iterateCommentRanges(f:NodeFactory, text:String, pos:Int, trailing:Bool):haxe.iterators.ArrayIterator<CommentRange> {
		final result = new Array<CommentRange>();
		var pendingPos = 0;
		var pendingEnd = 0;
		var pendingKind:Kind = KindUnknown;
		var pendingHasTrailingNewLine = false;
		var hasPendingCommentRange = false;
		var collecting = trailing;
		if (pos == 0) {
			collecting = true;
			if (isShebangTrivia(text, pos)) {
				pos = scanShebangTrivia(text, pos);
			}
		}
		// PORT: label — `break scan` leaves the loop via the `scan` flag.
		var scan = true;
		while (scan && pos >= 0 && pos < text.length) {
			final ch = Utf16.DecodeRuneInString(text, pos);
			final size = Utf16.RuneLen(ch);
			switch (ch) {
				case '\r'.code | '\n'.code:
					if (ch == '\r'.code) {
						if (pos + 1 < text.length && StringTools.fastCodeAt(text, pos + 1) == '\n'.code) {
							pos++;
						}
						// fallthrough
					}
					pos++;
					if (trailing) {
						scan = false;
						continue;
					}

					collecting = true;
					if (hasPendingCommentRange) {
						pendingHasTrailingNewLine = true;
					}

					continue;
				case '\t'.code | 0x0B | 0x0C | ' '.code:
					pos++;
					continue;
				case '/'.code:
					var nextChar = 0;
					if (pos + 1 < text.length) {
						nextChar = StringTools.fastCodeAt(text, pos + 1);
					}
					var hasTrailingNewLine = false;
					if (nextChar == '/'.code || nextChar == '*'.code) {
						var kind:Kind;
						if (nextChar == '/'.code) {
							kind = KindSingleLineCommentTrivia;
						} else {
							kind = KindMultiLineCommentTrivia;
						}

						final startPos = pos;
						pos += 2;
						if (nextChar == '/'.code) {
							while (pos < text.length) {
								final c = Utf16.DecodeRuneInString(text, pos);
								if (Stringutil.IsLineBreak(c)) {
									hasTrailingNewLine = true;
									break;
								}
								pos += Utf16.RuneLen(c);
							}
						} else {
							final i = text.indexOf("*/", pos);
							if (i >= 0) {
								pos = i + 2;
							} else {
								pos = text.length;
							}
						}

						if (collecting) {
							if (hasPendingCommentRange) {
								result.push(f.NewCommentRange(pendingKind, pendingPos, pendingEnd, pendingHasTrailingNewLine));
							}

							pendingPos = startPos;
							pendingEnd = pos;
							pendingKind = kind;
							pendingHasTrailingNewLine = hasTrailingNewLine;
							hasPendingCommentRange = true;
						}

						continue;
					}
					scan = false;
				default:
					if (ch > Unicode.MaxASCII && Stringutil.IsWhiteSpaceLike(ch)) {
						if (hasPendingCommentRange && Stringutil.IsLineBreak(ch)) {
							pendingHasTrailingNewLine = true;
						}
						pos += size;
						continue;
					}
					scan = false;
			}
		}

		if (hasPendingCommentRange) {
			result.push(f.NewCommentRange(pendingKind, pendingPos, pendingEnd, pendingHasTrailingNewLine));
		}
		return result.iterator();
	}

	// --- regexp.go ---

	static final charCodeToRegExpFlag:IntMap<RegularExpressionFlags> = [
		'd'.code => RegularExpressionFlagsHasIndices,
		'g'.code => RegularExpressionFlagsGlobal,
		'i'.code => RegularExpressionFlagsIgnoreCase,
		'm'.code => RegularExpressionFlagsMultiline,
		's'.code => RegularExpressionFlagsDotAll,
		'u'.code => RegularExpressionFlagsUnicode,
		'v'.code => RegularExpressionFlagsUnicodeSets,
		'y'.code => RegularExpressionFlagsSticky,
	];

	static final regExpFlagToFirstAvailableLanguageVersion:IntMap<ScriptTarget> = [
		(RegularExpressionFlagsHasIndices : Int) => ScriptTargetES2022,
		(RegularExpressionFlagsDotAll : Int) => ScriptTargetES2018,
		(RegularExpressionFlagsUnicodeSets : Int) => ScriptTargetES2024,
	];

	static function compareDecimalStrings(a:String, b:String):Int {
		a = Strings.TrimLeft(a, "0");
		b = Strings.TrimLeft(b, "0");
		if (a == "") {
			a = "0";
		}
		if (b == "") {
			b = "0";
		}
		if (a.length != b.length) {
			if (a.length < b.length) {
				return -1;
			}
			return 1;
		}
		return Strings.Compare(a, b);
	}

	// --- unicodeproperties.go ---
	// PORT: package-level vars whose initializers call ts.collections are lazy (PORTING.md §7a).

	// Table 66: Non-binary Unicode property aliases and their canonical property names
	// https://tc39.es/ecma262/#table-nonbinary-unicode-properties
	static final nonBinaryUnicodeProperties:StringMap<String> = [
		"General_Category" => "General_Category",
		"gc" => "General_Category",
		"Script" => "Script",
		"sc" => "Script",
		"Script_Extensions" => "Script_Extensions",
		"scx" => "Script_Extensions",
	];

	// Table 67: Binary Unicode property aliases and their canonical property names
	// https://tc39.es/ecma262/#table-binary-unicode-properties
	static var binaryUnicodeProperties(get, never):Set<String>;
	static var binaryUnicodeProperties_:Set<String> = null;

	static function get_binaryUnicodeProperties():Set<String> {
		if (binaryUnicodeProperties_ == null) {
			binaryUnicodeProperties_ = Collections.NewSetFromItems(
				"ASCII", "ASCII_Hex_Digit", "AHex", "Alphabetic", "Alpha", "Any", "Assigned", "Bidi_Control", "Bidi_C",
				"Bidi_Mirrored", "Bidi_M", "Case_Ignorable", "CI", "Cased", "Changes_When_Casefolded", "CWCF",
				"Changes_When_Casemapped", "CWCM", "Changes_When_Lowercased", "CWL", "Changes_When_NFKC_Casefolded", "CWKCF",
				"Changes_When_Titlecased", "CWT", "Changes_When_Uppercased", "CWU", "Dash", "Default_Ignorable_Code_Point",
				"DI", "Deprecated", "Dep", "Diacritic", "Dia", "Emoji", "Emoji_Component", "EComp", "Emoji_Modifier", "EMod",
				"Emoji_Modifier_Base", "EBase", "Emoji_Presentation", "EPres", "Extended_Pictographic", "ExtPict",
				"Extender", "Ext", "Grapheme_Base", "Gr_Base", "Grapheme_Extend", "Gr_Ext", "Hex_Digit", "Hex",
				"IDS_Binary_Operator", "IDSB", "IDS_Trinary_Operator", "IDST", "ID_Continue", "IDC", "ID_Start", "IDS",
				"Ideographic", "Ideo", "Join_Control", "Join_C", "Logical_Order_Exception", "LOE", "Lowercase", "Lower",
				"Math", "Noncharacter_Code_Point", "NChar", "Pattern_Syntax", "Pat_Syn", "Pattern_White_Space", "Pat_WS",
				"Quotation_Mark", "QMark", "Radical", "Regional_Indicator", "RI", "Sentence_Terminal", "STerm",
				"Soft_Dotted", "SD", "Terminal_Punctuation", "Term", "Unified_Ideograph", "UIdeo", "Uppercase", "Upper",
				"Variation_Selector", "VS", "White_Space", "space", "XID_Continue", "XIDC", "XID_Start", "XIDS"
			);
		}
		return binaryUnicodeProperties_;
	}

	// Table 68: Binary Unicode properties of strings
	// https://tc39.es/ecma262/#table-binary-unicode-properties-of-strings
	static var binaryUnicodePropertiesOfStrings(get, never):Set<String>;
	static var binaryUnicodePropertiesOfStrings_:Set<String> = null;

	static function get_binaryUnicodePropertiesOfStrings():Set<String> {
		if (binaryUnicodePropertiesOfStrings_ == null) {
			binaryUnicodePropertiesOfStrings_ = Collections.NewSetFromItems(
				"Basic_Emoji", "Emoji_Keycap_Sequence", "RGI_Emoji_Modifier_Sequence", "RGI_Emoji_Flag_Sequence",
				"RGI_Emoji_Tag_Sequence", "RGI_Emoji_ZWJ_Sequence", "RGI_Emoji"
			);
		}
		return binaryUnicodePropertiesOfStrings_;
	}

	// Unicode 15.1
	static var scriptValues(get, never):Set<String>;
	static var scriptValues_:Set<String> = null;

	static function get_scriptValues():Set<String> {
		if (scriptValues_ == null) {
			scriptValues_ = Collections.NewSetFromItems(
				"Adlm", "Adlam", "Aghb", "Caucasian_Albanian", "Ahom", "Arab", "Arabic", "Armi", "Imperial_Aramaic", "Armn",
				"Armenian", "Avst", "Avestan", "Bali", "Balinese", "Bamu", "Bamum", "Bass", "Bassa_Vah", "Batk", "Batak",
				"Beng", "Bengali", "Bhks", "Bhaiksuki", "Bopo", "Bopomofo", "Brah", "Brahmi", "Brai", "Braille", "Bugi",
				"Buginese", "Buhd", "Buhid", "Cakm", "Chakma", "Cans", "Canadian_Aboriginal", "Cari", "Carian", "Cham",
				"Cher", "Cherokee", "Chrs", "Chorasmian", "Copt", "Coptic", "Qaac", "Cpmn", "Cypro_Minoan", "Cprt",
				"Cypriot", "Cyrl", "Cyrillic", "Deva", "Devanagari", "Diak", "Dives_Akuru", "Dogr", "Dogra", "Dsrt",
				"Deseret", "Dupl", "Duployan", "Egyp", "Egyptian_Hieroglyphs", "Elba", "Elbasan", "Elym", "Elymaic", "Ethi",
				"Ethiopic", "Geor", "Georgian", "Glag", "Glagolitic", "Gong", "Gunjala_Gondi", "Gonm", "Masaram_Gondi",
				"Goth", "Gothic", "Gran", "Grantha", "Grek", "Greek", "Gujr", "Gujarati", "Guru", "Gurmukhi", "Hang",
				"Hangul", "Hani", "Han", "Hano", "Hanunoo", "Hatr", "Hatran", "Hebr", "Hebrew", "Hira", "Hiragana", "Hluw",
				"Anatolian_Hieroglyphs", "Hmng", "Pahawh_Hmong", "Hmnp", "Nyiakeng_Puachue_Hmong", "Hrkt",
				"Katakana_Or_Hiragana", "Hung", "Old_Hungarian", "Ital", "Old_Italic", "Java", "Javanese", "Kali",
				"Kayah_Li", "Kana", "Katakana", "Kawi", "Khar", "Kharoshthi", "Khmr", "Khmer", "Khoj", "Khojki", "Kits",
				"Khitan_Small_Script", "Knda", "Kannada", "Kthi", "Kaithi", "Lana", "Tai_Tham", "Laoo", "Lao", "Latn",
				"Latin", "Lepc", "Lepcha", "Limb", "Limbu", "Lina", "Linear_A", "Linb", "Linear_B", "Lisu", "Lyci", "Lycian",
				"Lydi", "Lydian", "Mahj", "Mahajani", "Maka", "Makasar", "Mand", "Mandaic", "Mani", "Manichaean", "Marc",
				"Marchen", "Medf", "Medefaidrin", "Mend", "Mende_Kikakui", "Merc", "Meroitic_Cursive", "Mero",
				"Meroitic_Hieroglyphs", "Mlym", "Malayalam", "Modi", "Mong", "Mongolian", "Mroo", "Mro", "Mtei",
				"Meetei_Mayek", "Mult", "Multani", "Mymr", "Myanmar", "Nagm", "Nag_Mundari", "Nand", "Nandinagari", "Narb",
				"Old_North_Arabian", "Nbat", "Nabataean", "Newa", "Nkoo", "Nko", "Nshu", "Nushu", "Ogam", "Ogham", "Olck",
				"Ol_Chiki", "Orkh", "Old_Turkic", "Orya", "Oriya", "Osge", "Osage", "Osma", "Osmanya", "Ougr", "Old_Uyghur",
				"Palm", "Palmyrene", "Pauc", "Pau_Cin_Hau", "Perm", "Old_Permic", "Phag", "Phags_Pa", "Phli",
				"Inscriptional_Pahlavi", "Phlp", "Psalter_Pahlavi", "Phnx", "Phoenician", "Plrd", "Miao", "Prti",
				"Inscriptional_Parthian", "Rjng", "Rejang", "Rohg", "Hanifi_Rohingya", "Runr", "Runic", "Samr", "Samaritan",
				"Sarb", "Old_South_Arabian", "Saur", "Saurashtra", "Sgnw", "SignWriting", "Shaw", "Shavian", "Shrd",
				"Sharada", "Sidd", "Siddham", "Sind", "Khudawadi", "Sinh", "Sinhala", "Sogd", "Sogdian", "Sogo",
				"Old_Sogdian", "Sora", "Sora_Sompeng", "Soyo", "Soyombo", "Sund", "Sundanese", "Sylo", "Syloti_Nagri",
				"Syrc", "Syriac", "Tagb", "Tagbanwa", "Takr", "Takri", "Tale", "Tai_Le", "Talu", "New_Tai_Lue", "Taml",
				"Tamil", "Tang", "Tangut", "Tavt", "Tai_Viet", "Telu", "Telugu", "Tfng", "Tifinagh", "Tglg", "Tagalog",
				"Thaa", "Thaana", "Thai", "Tibt", "Tibetan", "Tirh", "Tirhuta", "Tnsa", "Tangsa", "Toto", "Ugar", "Ugaritic",
				"Vaii", "Vai", "Vith", "Vithkuqi", "Wara", "Warang_Citi", "Wcho", "Wancho", "Xpeo", "Old_Persian", "Xsux",
				"Cuneiform", "Yezi", "Yezidi", "Yiii", "Yi", "Zanb", "Zanabazar_Square", "Zinh", "Inherited", "Qaai", "Zyyy",
				"Common", "Zzzz", "Unknown"
			);
		}
		return scriptValues_;
	}

	static var valuesOfNonBinaryUnicodeProperties(get, never):StringMap<Set<String>>;
	static var valuesOfNonBinaryUnicodeProperties_:StringMap<Set<String>> = null;

	static function get_valuesOfNonBinaryUnicodeProperties():StringMap<Set<String>> {
		if (valuesOfNonBinaryUnicodeProperties_ == null) {
			final m = new StringMap<Set<String>>();
			m.set("General_Category", Collections.NewSetFromItems(
				"C", "Other", "Cc", "Control", "cntrl", "Cf", "Format", "Cn", "Unassigned", "Co", "Private_Use", "Cs",
				"Surrogate", "L", "Letter", "LC", "Cased_Letter", "Ll", "Lowercase_Letter", "Lm", "Modifier_Letter", "Lo",
				"Other_Letter", "Lt", "Titlecase_Letter", "Lu", "Uppercase_Letter", "M", "Mark", "Combining_Mark", "Mc",
				"Spacing_Mark", "Me", "Enclosing_Mark", "Mn", "Nonspacing_Mark", "N", "Number", "Nd", "Decimal_Number",
				"digit", "Nl", "Letter_Number", "No", "Other_Number", "P", "Punctuation", "punct", "Pc",
				"Connector_Punctuation", "Pd", "Dash_Punctuation", "Pe", "Close_Punctuation", "Pf", "Final_Punctuation",
				"Pi", "Initial_Punctuation", "Po", "Other_Punctuation", "Ps", "Open_Punctuation", "S", "Symbol", "Sc",
				"Currency_Symbol", "Sk", "Modifier_Symbol", "Sm", "Math_Symbol", "So", "Other_Symbol", "Z", "Separator",
				"Zl", "Line_Separator", "Zp", "Paragraph_Separator", "Zs", "Space_Separator"
			));
			m.set("Script", scriptValues);
			// The Script_Extensions property of a character contains one or more Script values.
			// See https://www.unicode.org/reports/tr24/#Script_Extensions
			// Here, since each Unicode property value expression only allows a single value,
			// its values can be considered the same as those of the Script property.
			m.set("Script_Extensions", scriptValues);
			valuesOfNonBinaryUnicodeProperties_ = m;
		}
		return valuesOfNonBinaryUnicodeProperties_;
	}

	// --- utilities.go ---

	static inline function tokenIsIdentifierOrKeyword(token:Kind):Bool {
		return token >= KindIdentifier;
	}

	public static function IdentifierToKeywordKind(node:Identifier):Kind {
		final kind = textToKeyword.get(node.Text);
		return kind == null ? KindUnknown : kind;
	}

	public static function GetSourceTextOfNodeFromSourceFile(sourceFile:SourceFile, node:Node, includeTrivia:Bool):String {
		return GetTextOfNodeFromSourceText(sourceFile.Text(), node, includeTrivia);
	}

	public static function GetTextOfNodeFromSourceText(sourceText:String, node:Node, includeTrivia:Bool):String {
		if (Ast.NodeIsMissing(node)) {
			return "";
		}
		var pos = node.Pos();
		if (!includeTrivia) {
			pos = SkipTrivia(sourceText, pos);
		}
		final text = sourceText.substring(pos, node.End());
		if ((node.Flags & NodeFlagsReparserTransformedLiteral) != 0) {
			// This is similar to `getLiteralTextOfNode` in the printer, but without the context of an `emitContext` to provide overrides
			if (Ast.IsStringLiteral(node)) {
				if ((node.AsStringLiteral().TokenFlags & TokenFlagsSingleQuote) != 0) {
					return "'" + text + "'";
				}
				return "\"" + text + "\"";
			} else if (Ast.IsIdentifier(node)) {
				return node.Text();
			}
			// Only the above node kinds are currently transformed into one another by the reparser, requiring the textual remapping.
			// (Any reamppings done by emit transforms are handled by `getLiteralTextOfNode` in the printer)
			// Fail on any other kinds.
			Debug.FailBadSyntaxKind({KindString: () -> node.KindString()}, "Unexpected reparser-transformed node kind");
		}
		// if (isJSDocTypeExpressionOrChild(node)) {
		//     // strip space + asterisk at line start
		//     text = text.split(/\r\n|\n|\r/).map(line => line.replace(/^\s*\*/, "").trimStart()).join("\n");
		// }
		return text;
	}

	public static function GetTextOfNode(node:Node):String {
		return GetSourceTextOfNodeFromSourceFile(Ast.GetSourceFileOfNode(node), node, false /*includeTrivia*/);
	}

	public static function GetTextOfJSDocComment(comment:NodeList):String {
		if (comment == null) {
			return "";
		}
		final b = new StringBuf();
		for (n in comment.Nodes) {
			switch (n.Kind) {
				case KindJSDocText:
					b.add(n.Text());
				case KindJSDocLink | KindJSDocLinkCode | KindJSDocLinkPlain:
					b.add(GetTextOfNode(n));
				default:
			}
		}
		return Strings.TrimRightFunc(b.toString(), Unicode.IsSpace);
	}

	public static function DeclarationNameToString(name:Node):String {
		if (name == null || name.Pos() == name.End()) {
			return "(Missing)";
		}
		return GetTextOfNode(name);
	}

	public static function IsIdentifierText(name:String, languageVariant:LanguageVariant):Bool {
		var ch = Utf16.DecodeRuneInString(name, 0);
		var size = name.length == 0 ? 0 : Utf16.RuneLen(ch);
		if (!IsIdentifierStart(ch)) {
			return false;
		}
		var i = size;
		while (i < name.length) {
			ch = Utf16.DecodeRuneInString(name, i);
			size = Utf16.RuneLen(ch);
			if (!IsIdentifierPartEx(ch, languageVariant)) {
				return false;
			}
			i += size;
		}
		return true;
	}

	public static function IsIntrinsicJsxName(name:String):Bool {
		return name.length != 0
			&& (StringTools.fastCodeAt(name, 0) >= 'a'.code && StringTools.fastCodeAt(name, 0) <= 'z'.code || name.indexOf("-") >= 0);
	}
}
