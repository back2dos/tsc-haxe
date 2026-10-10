package ts.scanner;

import haxe.ds.StringMap;

// Port of regexp.go: its types, and its Scanner method as a static with the receiver first
// (PORTING.md §2; `using ts.scanner.Regexp` in import.hx). Its package-level vars and funcs
// (charCodeToRegExpFlag, regExpFlagToFirstAvailableLanguageVersion, compareDecimalStrings) are
// in Scanner.hx under `// --- regexp.go ---`.
enum abstract RegularExpressionFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:RegularExpressionFlags, b:RegularExpressionFlags):RegularExpressionFlags;
	@:op(A & B) static function and(a:RegularExpressionFlags, b:RegularExpressionFlags):RegularExpressionFlags;
	@:op(~A) static function not(a:RegularExpressionFlags):RegularExpressionFlags;

	var RegularExpressionFlagsNone = 0;
	var RegularExpressionFlagsHasIndices = 1 << 0; // d
	var RegularExpressionFlagsGlobal = 1 << 1; // g
	var RegularExpressionFlagsIgnoreCase = 1 << 2; // i
	var RegularExpressionFlagsMultiline = 1 << 3; // m
	var RegularExpressionFlagsDotAll = 1 << 4; // s
	var RegularExpressionFlagsUnicode = 1 << 5; // u
	var RegularExpressionFlagsUnicodeSets = 1 << 6; // v
	var RegularExpressionFlagsSticky = 1 << 7; // y
	var RegularExpressionFlagsAnyUnicodeMode = RegularExpressionFlagsUnicode | RegularExpressionFlagsUnicodeSets;
	var RegularExpressionFlagsModifiers = RegularExpressionFlagsIgnoreCase | RegularExpressionFlagsMultiline | RegularExpressionFlagsDotAll;
}

@:allow(ts.scanner)
class Regexp {
	static function checkRegularExpressionFlagAvailability(s:Scanner, flag:RegularExpressionFlags, pos:Int, size:Int):Void {
		final availableFrom = Scanner.regExpFlagToFirstAvailableLanguageVersion.get(flag);
		if (availableFrom != null && s.languageVersion() < availableFrom) {
			s.errorAt(Diagnostics.This_regular_expression_flag_is_only_available_when_targeting_0_or_later, pos, size, (availableFrom : ScriptTarget).String()
				.toLowerCase());
		}
	}
}

enum abstract ClassSetExpressionType(Int) from Int to Int {
	var ClassSetExpressionTypeUnknown = 0;
	var ClassSetExpressionTypeClassUnion = 1;
	var ClassSetExpressionTypeClassIntersection = 2;
	var ClassSetExpressionTypeClassSubtraction = 3;
}

class GroupNameReference {
	public var pos:Int = 0;
	public var end:Int = 0;
	public var name:String = "";

	public function new(pos:Int, end:Int, name:String) {
		this.pos = pos;
		this.end = end;
		this.name = name;
	}
}

class DecimalEscapeValue {
	public var pos:Int = 0;
	public var end:Int = 0;
	public var value:Int = 0;

	public function new(pos:Int, end:Int, value:Int) {
		this.pos = pos;
		this.end = end;
		this.value = value;
	}
}

@:allow(ts.scanner)
class RegExpParser {
	var scanner:Scanner = null;
	var end:Int = 0;
	var regExpFlags:RegularExpressionFlags = RegularExpressionFlagsNone;
	var anyUnicodeMode:Bool = false;
	var unicodeSetsMode:Bool = false;
	var annexB:Bool = false;

	var anyUnicodeModeOrNonAnnexB:Bool = false;
	var namedCaptureGroups:Bool = false;

	// See scanClassSetExpression.
	var mayContainStrings:Bool = false;
	// The number of all (named and unnamed) capturing groups defined in the regex.
	var numberOfCapturingGroups:Int = 0;
	// All named capturing groups defined in the regex.
	var groupSpecifiers:StringMap<Bool> = null;
	// All references to named capturing groups in the regex.
	var groupNameReferences:Array<GroupNameReference> = null;
	// All numeric backreferences within the regex.
	var decimalEscapes:Array<DecimalEscapeValue> = null;
	// A stack of scopes for named capturing groups. See scanGroupName.
	var namedCapturingGroups:Array<StringMap<Bool>> = null;

	// pendingLowSurrogate holds the low surrogate to emit on the next
	// scanSourceCharacter call when Corsa has to split a non-BMP rune into
	// UTF-16 surrogate code units in non-unicode mode. Strada did not need
	// this bookkeeping because its source text was already indexed as UTF-16.
	// PORT: utf16 — kept as in Go (the high surrogate call does not advance, the low one advances
	// past the whole character), so positions and error spans match Go's.
	var pendingLowSurrogate:Int = 0;

	function new() {}

	inline function pos():Int {
		return scanner.pos;
	}

	inline function setPos(v:Int):Void {
		scanner.pos = v;
	}

	inline function incPos(n:Int):Void {
		scanner.pos += n;
	}

	inline function char():Int {
		return scanner.char();
	}

	inline function charAt(pos:Int):Int {
		return scanner.charAt(pos - this.pos());
	}

	function error(msg:Message, pos:Int, length:Int, ...args:Any):Void {
		scanner.errorAt(msg, pos, length, ...args);
	}

	inline function text():String {
		return scanner.text;
	}

	// Disjunction ::= Alternative ('|' Alternative)*
	function scanDisjunction(isInGroup:Bool):Void {
		while (true) {
			if (namedCapturingGroups == null) {
				namedCapturingGroups = [];
			}
			namedCapturingGroups.push(new StringMap<Bool>());
			scanAlternative(isInGroup);
			namedCapturingGroups.pop();
			if (char() != '|'.code) {
				return;
			}
			incPos(1);
		}
	}

	// Alternative ::= Term*
	// Term ::=
	//
	//	| Assertion
	//	| Atom Quantifier?
	//
	// Assertion ::=
	//
	//	| '^'
	//	| '$'
	//	| '\b'
	//	| '\B'
	//	| '(?=' Disjunction ')'
	//	| '(?!' Disjunction ')'
	//	| '(?<=' Disjunction ')'
	//	| '(?<!' Disjunction ')'
	//
	// Quantifier ::= QuantifierPrefix '?'?
	// QuantifierPrefix ::=
	//
	//	| '*'
	//	| '+'
	//	| '?'
	//	| '{' DecimalDigits (',' DecimalDigits?)? '}'
	//
	// Atom ::=
	//
	//	| PatternCharacter
	//	| '.'
	//	| '\' AtomEscape
	//	| CharacterClass
	//	| '(?<' RegExpIdentifierName '>' Disjunction ')'
	//	| '(?' RegularExpressionFlags ('-' RegularExpressionFlags)? ':' Disjunction ')'
	//
	// CharacterClass ::= unicodeMode
	//
	//	? '[' ClassRanges ']'
	//	: '[' ClassSetExpression ']'
	function scanAlternative(isInGroup:Bool):Void {
		var isPreviousTermQuantifiable = false;
		while (pos() < end) {
			final start = pos();
			final ch = char();
			switch (ch) {
				case '^'.code | '$'.code:
					incPos(1);
					isPreviousTermQuantifiable = false;
				case '\\'.code:
					incPos(1);
					switch (char()) {
						case 'b'.code | 'B'.code:
							incPos(1);
							isPreviousTermQuantifiable = false;
						default:
							scanAtomEscape();
							isPreviousTermQuantifiable = true;
					}
				case '('.code:
					incPos(1);
					if (char() == '?'.code) {
						incPos(1);
						switch (char()) {
							case '='.code | '!'.code:
								incPos(1);
								// In Annex B, `(?=Disjunction)` and `(?!Disjunction)` are quantifiable
								isPreviousTermQuantifiable = !anyUnicodeModeOrNonAnnexB;
							case '<'.code:
								final groupNameStart = pos();
								incPos(1);
								switch (char()) {
									case '='.code | '!'.code:
										incPos(1);
										isPreviousTermQuantifiable = false;
									default:
										scanGroupName(false /*isReference*/);
										scanExpectedChar('>'.code);
										if (scanner.languageVersion() < ScriptTargetES2018) {
											error(Diagnostics.Named_capturing_groups_are_only_available_when_targeting_ES2018_or_later, groupNameStart, pos() - groupNameStart);
										}
										numberOfCapturingGroups++;
										isPreviousTermQuantifiable = true;
								}
							default:
								final flagsStart = pos();
								final setFlags = scanPatternModifiers(RegularExpressionFlagsNone);
								if (char() == '-'.code) {
									incPos(1);
									scanPatternModifiers(setFlags);
									if (pos() == flagsStart + 1) {
										error(Diagnostics.Subpattern_flags_must_be_present_when_there_is_a_minus_sign, flagsStart, pos() - flagsStart);
									}
								}
								scanExpectedChar(':'.code);
								isPreviousTermQuantifiable = true;
						}
					} else {
						numberOfCapturingGroups++;
						isPreviousTermQuantifiable = true;
					}
					scanDisjunction(true /*isInGroup*/);
					scanExpectedChar(')'.code);
				case '{'.code:
					incPos(1);
					final digitsStart = pos();
					scanDigits();
					final minStr = scanner.tokenValue;
					if (!anyUnicodeModeOrNonAnnexB && minStr == "") {
						isPreviousTermQuantifiable = true;
						continue;
					}
					if (char() == ','.code) {
						incPos(1);
						scanDigits();
						final maxStr = scanner.tokenValue;
						if (minStr == "") {
							if (maxStr != "" || char() == '}'.code) {
								error(Diagnostics.Incomplete_quantifier_Digit_expected, digitsStart, 0);
							} else {
								error(Diagnostics.Unexpected_0_Did_you_mean_to_escape_it_with_backslash, start, 1, Utf16.RuneString(ch));
								isPreviousTermQuantifiable = true;
								continue;
							}
						} else if (maxStr != "") {
							if (Scanner.compareDecimalStrings(minStr, maxStr) > 0 && (anyUnicodeModeOrNonAnnexB || char() == '}'.code)) {
								error(Diagnostics.Numbers_out_of_order_in_quantifier, digitsStart, pos() - digitsStart);
							}
						}
					} else if (minStr == "") {
						if (anyUnicodeModeOrNonAnnexB) {
							error(Diagnostics.Unexpected_0_Did_you_mean_to_escape_it_with_backslash, start, 1, Utf16.RuneString(ch));
						}
						isPreviousTermQuantifiable = true;
						continue;
					}
					if (char() != '}'.code) {
						if (anyUnicodeModeOrNonAnnexB) {
							error(Diagnostics.X_0_expected, pos(), 0, "}");
							incPos(-1);
						} else {
							isPreviousTermQuantifiable = true;
							continue;
						}
					}
					// PORT: fallthrough into `case '*', '+', '?'` (body duplicated).
					incPos(1);
					if (char() == '?'.code) {
						// Non-greedy
						incPos(1);
					}
					if (!isPreviousTermQuantifiable) {
						error(Diagnostics.There_is_nothing_available_for_repetition, start, pos() - start);
					}
					isPreviousTermQuantifiable = false;
				case '*'.code | '+'.code | '?'.code:
					incPos(1);
					if (char() == '?'.code) {
						// Non-greedy
						incPos(1);
					}
					if (!isPreviousTermQuantifiable) {
						error(Diagnostics.There_is_nothing_available_for_repetition, start, pos() - start);
					}
					isPreviousTermQuantifiable = false;
				case '.'.code:
					incPos(1);
					isPreviousTermQuantifiable = true;
				case '['.code:
					incPos(1);
					if (unicodeSetsMode) {
						scanClassSetExpression();
					} else {
						scanClassRanges();
						pendingLowSurrogate = 0;
					}
					scanExpectedChar(']'.code);
					isPreviousTermQuantifiable = true;
				case ')'.code | ']'.code | '}'.code:
					if (ch == ')'.code && isInGroup) {
						return;
					}
					// PORT: `case ')'` falls through into `case ']', '}'`.
					if (anyUnicodeModeOrNonAnnexB || ch == ')'.code) {
						error(Diagnostics.Unexpected_0_Did_you_mean_to_escape_it_with_backslash, pos(), 1, Utf16.RuneString(ch));
					}
					incPos(1);
					isPreviousTermQuantifiable = true;
				case '/'.code | '|'.code:
					return;
				default:
					scanSourceCharacter();
					isPreviousTermQuantifiable = true;
			}
		}
	}

	function scanPatternModifiers(currFlags:RegularExpressionFlags):RegularExpressionFlags {
		while (pos() < end) {
			final ch = Utf16.DecodeRuneInString(text(), pos());
			final size = Utf16.RuneLen(ch);
			if (ch == Utf16.RuneError || !Scanner.IsIdentifierPart(ch)) {
				break;
			}
			if (!Scanner.charCodeToRegExpFlag.exists(ch)) {
				error(Diagnostics.Unknown_regular_expression_flag, pos(), size);
			} else {
				final flag:RegularExpressionFlags = Scanner.charCodeToRegExpFlag.get(ch);
				if ((currFlags & flag) != 0) {
					error(Diagnostics.Duplicate_regular_expression_flag, pos(), size);
				} else if ((flag & RegularExpressionFlagsModifiers) == 0) {
					error(Diagnostics.This_regular_expression_flag_cannot_be_toggled_within_a_subpattern, pos(), size);
				} else {
					currFlags |= flag;
					scanner.checkRegularExpressionFlagAvailability(flag, pos(), size);
				}
			}
			incPos(size);
		}
		return currFlags;
	}

	// AtomEscape ::=
	//
	//	| DecimalEscape
	//	| CharacterClassEscape
	//	| CharacterEscape
	//	| 'k<' RegExpIdentifierName '>'
	function scanAtomEscape():Void {
		Debug.Assert(pos() > 0 && StringTools.fastCodeAt(text(), pos() - 1) == '\\'.code);
		switch (char()) {
			case 'k'.code:
				incPos(1);
				if (char() == '<'.code) {
					incPos(1);
					scanGroupName(true /*isReference*/);
					scanExpectedChar('>'.code);
				} else if (anyUnicodeModeOrNonAnnexB || namedCaptureGroups) {
					error(Diagnostics.X_k_must_be_followed_by_a_capturing_group_name_enclosed_in_angle_brackets, pos() - 2, 2);
				}
			case 'q'.code if (unicodeSetsMode):
				incPos(1);
				error(Diagnostics.X_q_is_only_available_inside_character_class, pos() - 2, 2);
				return;
			default:
				// PORT: `case 'q'` without unicodeSetsMode falls through to here.
				if (!scanCharacterClassEscape() && !scanDecimalEscape()) {
					// Regex literals cannot contain line breaks here, so a character escape must consume something.
					Debug.Assert(scanCharacterEscape(true /*atomEscape*/) != "");
				}
		}
	}

	// DecimalEscape ::= [1-9] [0-9]*
	function scanDecimalEscape():Bool {
		Debug.Assert(pos() > 0 && StringTools.fastCodeAt(text(), pos() - 1) == '\\'.code);
		final ch = char();
		if (ch >= '1'.code && ch <= '9'.code) {
			final start = pos();
			scanDigits();
			// PORT: strconv.Atoi; on error (overflow) Go uses math.MaxInt. Values above the Int
			// range are clamped to the Int maximum, which compares the same against the group count.
			final r = Strconv.ParseInt(scanner.tokenValue, 10, 64);
			var val:Int;
			if (r.err != null || r.value.high != 0 || r.value.low < 0) {
				val = 0x7FFFFFFF;
			} else {
				val = r.value.low;
			}
			if (decimalEscapes == null) {
				decimalEscapes = [];
			}
			decimalEscapes.push(new DecimalEscapeValue(start, pos(), val));
			return true;
		}
		return false;
	}

	// CharacterEscape ::=
	//
	//	| `c` ControlLetter
	//	| IdentityEscape
	//	| (Other sequences handled by `scanEscapeSequence`)
	//
	// IdentityEscape ::=
	//
	//	| '^' | '$' | '/' | '\' | '.' | '*' | '+' | '?' | '(' | ')' | '[' | ']' | '{' | '}' | '|'
	//	| [~AnyUnicodeMode] (any other non-identifier characters)
	function scanCharacterEscape(atomEscape:Bool):String {
		Debug.Assert(pos() > 0 && StringTools.fastCodeAt(text(), pos() - 1) == '\\'.code);
		var ch = char();
		switch (ch) {
			case -1:
				error(Diagnostics.Undetermined_character_escape, pos() - 1, 1);
				return "\\";
			case 'c'.code:
				incPos(1);
				ch = char();
				if (Stringutil.IsASCIILetter(ch)) {
					incPos(1);
					return Utf16.RuneString(ch & 0x1f);
				}
				if (anyUnicodeModeOrNonAnnexB) {
					error(Diagnostics.X_c_must_be_followed_by_an_ASCII_letter, pos() - 2, 2);
				} else if (atomEscape) {
					incPos(-1);
					return "\\";
				}
				return Utf16.RuneString(goByteAt(ch));
			case '^'.code | '$'.code | '/'.code | '\\'.code | '.'.code | '*'.code | '+'.code | '?'.code | '('.code | ')'.code | '['.code | ']'.code |
				'{'.code | '}'.code | '|'.code:
				incPos(1);
				return Utf16.RuneString(ch);
			default:
				incPos(-1); // back up to include the backslash for scanEscapeSequence
				var flags:EscapeSequenceScanningFlags = EscapeSequenceScanningFlagsRegularExpression;
				if (annexB) {
					flags |= EscapeSequenceScanningFlagsAnnexB;
				}
				if (anyUnicodeMode) {
					flags |= EscapeSequenceScanningFlagsAnyUnicodeMode;
				}
				if (atomEscape) {
					flags |= EscapeSequenceScanningFlagsAtomEscape;
				}
				return scanner.scanEscapeSequence(flags);
		}
	}

	// PORT: byte — Go's p.char() is the byte at pos; for a non-ASCII character that is the first
	// UTF-8 byte of the code point at pos. `ch` is the UTF-16 unit at pos (or -1).
	function goByteAt(ch:Int):Int {
		if (ch < Utf16.RuneSelf) {
			return ch;
		}
		final r = Utf16.CodePointAt(text(), pos());
		if (r < 0x800) {
			return 0xC0 | (r >> 6);
		} else if (r < 0x10000) {
			return 0xE0 | (r >> 12);
		}
		return 0xF0 | (r >> 18);
	}

	function scanGroupName(isReference:Bool):Void {
		Debug.Assert(pos() > 0 && StringTools.fastCodeAt(text(), pos() - 1) == '<'.code);
		scanner.tokenStart = pos();
		scanner.scanIdentifier(0);
		if (pos() == scanner.tokenStart) {
			error(Diagnostics.Expected_a_capturing_group_name, pos(), 0);
		} else if (isReference) {
			if (groupNameReferences == null) {
				groupNameReferences = [];
			}
			groupNameReferences.push(new GroupNameReference(scanner.tokenStart, pos(), scanner.tokenValue));
		} else if (namedCapturingGroupsContains(scanner.tokenValue)) {
			error(Diagnostics.Named_capturing_groups_with_the_same_name_must_be_mutually_exclusive_to_each_other, scanner.tokenStart, pos() - scanner.tokenStart);
		} else {
			if (Core.len(namedCapturingGroups) > 0) {
				namedCapturingGroups[namedCapturingGroups.length - 1].set(scanner.tokenValue, true);
			}
			groupSpecifiers.set(scanner.tokenValue, true);
		}
	}

	function namedCapturingGroupsContains(name:String):Bool {
		if (namedCapturingGroups != null) {
			for (group in namedCapturingGroups) {
				if (group.get(name) == true) {
					return true;
				}
			}
		}
		return false;
	}

	function isClassContentExit(ch:Int):Bool {
		return ch == ']'.code || pos() >= end;
	}

	// PORT: Go `stringutil.DecodeJSStringRune(s)` returns (rune, size); the size of the first JS
	// rune of s in UTF-16 units, 0 for "".
	static inline function jsStringRuneSize(s:String, r:Int):Int {
		return s.length == 0 ? 0 : Utf16.RuneLen(r);
	}

	// ClassRanges ::= '^'? (ClassAtom ('-' ClassAtom)?)*
	function scanClassRanges():Void {
		Debug.Assert(pos() > 0 && StringTools.fastCodeAt(text(), pos() - 1) == '['.code);
		pendingLowSurrogate = 0;
		if (char() == '^'.code) {
			incPos(1);
		}
		while (pos() < end) {
			var ch = char();
			if (isClassContentExit(ch)) {
				return;
			}
			final minStart = pos();
			final minCharacter = scanClassAtom();
			if (char() == '-'.code) {
				incPos(1);
				ch = char();
				if (isClassContentExit(ch)) {
					return;
				}
				if (minCharacter == "" && anyUnicodeModeOrNonAnnexB) {
					error(Diagnostics.A_character_class_range_must_not_be_bounded_by_another_character_class, minStart, pos() - 1 - minStart);
				}
				final maxStart = pos();
				final maxCharacter = scanClassAtom();
				if (maxCharacter == "" && anyUnicodeModeOrNonAnnexB) {
					error(Diagnostics.A_character_class_range_must_not_be_bounded_by_another_character_class, maxStart, pos() - maxStart);
					continue;
				}
				if (minCharacter == "") {
					continue;
				}
				final minCharacterValue = Stringutil.DecodeJSStringRune(minCharacter, 0);
				final minSize = jsStringRuneSize(minCharacter, minCharacterValue);
				final maxCharacterValue = Stringutil.DecodeJSStringRune(maxCharacter, 0);
				final maxSize = jsStringRuneSize(maxCharacter, maxCharacterValue);
				if (minCharacter.length == minSize && maxCharacter.length == maxSize && minCharacterValue > maxCharacterValue) {
					error(Diagnostics.Range_out_of_order_in_character_class, minStart, pos() - minStart);
				}
			}
		}
	}

	// Static Semantics: MayContainStrings
	//     ClassUnion: ClassSetOperands.some(ClassSetOperand => ClassSetOperand.MayContainStrings)
	//     ClassIntersection: ClassSetOperands.every(ClassSetOperand => ClassSetOperand.MayContainStrings)
	//     ClassSubtraction: ClassSetOperands[0].MayContainStrings
	//     ClassSetOperand:
	//         || ClassStringDisjunctionContents.MayContainStrings
	//         || CharacterClassEscape.UnicodePropertyValueExpression.LoneUnicodePropertyNameOrValue.MayContainStrings
	//     ClassStringDisjunctionContents: ClassStrings.some(ClassString => ClassString.ClassSetCharacters.length !== 1)
	//     LoneUnicodePropertyNameOrValue: isBinaryUnicodePropertyOfStrings(LoneUnicodePropertyNameOrValue)
	// ClassSetExpression ::= '^'? (ClassUnion | ClassIntersection | ClassSubtraction)
	// ClassUnion ::= (ClassSetRange | ClassSetOperand)*
	// ClassIntersection ::= ClassSetOperand ('&&' ClassSetOperand)+
	// ClassSubtraction ::= ClassSetOperand ('--' ClassSetOperand)+
	// ClassSetRange ::= ClassSetCharacter '-' ClassSetCharacter
	function scanClassSetExpression():Void {
		Debug.Assert(pos() > 0 && StringTools.fastCodeAt(text(), pos() - 1) == '['.code);
		var isCharacterComplement = false;
		if (char() == '^'.code) {
			incPos(1);
			isCharacterComplement = true;
		}
		var expressionMayContainStrings = false;
		var ch = char();
		if (isClassContentExit(ch)) {
			return;
		}
		var start = pos();
		var operand = "";
		var twoChars = "";
		if (pos() + 1 < end) {
			twoChars = text().substring(pos(), pos() + 2);
		}
		switch (twoChars) {
			case "--" | "&&":
				error(Diagnostics.Expected_a_class_set_operand, pos(), 0);
				mayContainStrings = false;
			default:
				operand = scanClassSetOperand();
		}
		switch (char()) {
			case '-'.code:
				if (pos() + 1 < end && charAt(pos() + 1) == '-'.code) {
					if (isCharacterComplement && mayContainStrings) {
						error(Diagnostics.Anything_that_would_possibly_match_more_than_a_single_character_is_invalid_inside_a_negated_character_class, start,
							pos() - start);
					}
					expressionMayContainStrings = mayContainStrings;
					scanClassSetSubExpression(ClassSetExpressionTypeClassSubtraction);
					mayContainStrings = !isCharacterComplement && expressionMayContainStrings;
					return;
				}
			case '&'.code:
				if (pos() + 1 < end && charAt(pos() + 1) == '&'.code) {
					scanClassSetSubExpression(ClassSetExpressionTypeClassIntersection);
					if (isCharacterComplement && mayContainStrings) {
						error(Diagnostics.Anything_that_would_possibly_match_more_than_a_single_character_is_invalid_inside_a_negated_character_class, start,
							pos() - start);
					}
					expressionMayContainStrings = mayContainStrings;
					mayContainStrings = !isCharacterComplement && expressionMayContainStrings;
					return;
				} else {
					error(Diagnostics.Unexpected_0_Did_you_mean_to_escape_it_with_backslash, pos(), 1, Utf16.RuneString(ch));
				}
			default:
				if (isCharacterComplement && mayContainStrings) {
					error(Diagnostics.Anything_that_would_possibly_match_more_than_a_single_character_is_invalid_inside_a_negated_character_class, start,
						pos() - start);
				}
				expressionMayContainStrings = mayContainStrings;
		}
		while (pos() < end) {
			ch = char();
			switch (ch) {
				case '-'.code:
					incPos(1);
					ch = char();
					if (isClassContentExit(ch)) {
						mayContainStrings = !isCharacterComplement && expressionMayContainStrings;
						return;
					}
					if (ch == '-'.code) {
						incPos(1);
						error(Diagnostics.Operators_must_not_be_mixed_within_a_character_class_Wrap_it_in_a_nested_class_instead, pos() - 2, 2);
						start = pos() - 2;
						operand = text().substring(start, pos());
						continue;
					} else {
						if (operand == "") {
							error(Diagnostics.A_character_class_range_must_not_be_bounded_by_another_character_class, start, pos() - 1 - start);
						}
						final secondStart = pos();
						final secondOperand = scanClassSetOperand();
						if (isCharacterComplement && mayContainStrings) {
							error(Diagnostics.Anything_that_would_possibly_match_more_than_a_single_character_is_invalid_inside_a_negated_character_class,
								secondStart, pos() - secondStart);
						}
						expressionMayContainStrings = expressionMayContainStrings || mayContainStrings;
						if (secondOperand == "") {
							error(Diagnostics.A_character_class_range_must_not_be_bounded_by_another_character_class, secondStart, pos() - secondStart);
						} else if (operand != "") {
							final minCharacterValue = Stringutil.DecodeJSStringRune(operand, 0);
							final minSize = jsStringRuneSize(operand, minCharacterValue);
							final maxCharacterValue = Stringutil.DecodeJSStringRune(secondOperand, 0);
							final maxSize = jsStringRuneSize(secondOperand, maxCharacterValue);
							if (operand.length == minSize && secondOperand.length == maxSize && minCharacterValue > maxCharacterValue) {
								error(Diagnostics.Range_out_of_order_in_character_class, start, pos() - start);
							}
						}
					}
				case '&'.code:
					start = pos();
					incPos(1);
					if (char() == '&'.code) {
						incPos(1);
						error(Diagnostics.Operators_must_not_be_mixed_within_a_character_class_Wrap_it_in_a_nested_class_instead, pos() - 2, 2);
						if (char() == '&'.code) {
							error(Diagnostics.Unexpected_0_Did_you_mean_to_escape_it_with_backslash, pos(), 1, Utf16.RuneString(ch));
							incPos(1);
						}
					} else {
						error(Diagnostics.Unexpected_0_Did_you_mean_to_escape_it_with_backslash, pos() - 1, 1, Utf16.RuneString(ch));
					}
					operand = text().substring(start, pos());
					continue;
				default:
			}
			if (isClassContentExit(char())) {
				break;
			}
			start = pos();
			twoChars = "";
			if (pos() + 1 < end) {
				twoChars = text().substring(pos(), pos() + 2);
			}
			switch (twoChars) {
				case "--" | "&&":
					error(Diagnostics.Operators_must_not_be_mixed_within_a_character_class_Wrap_it_in_a_nested_class_instead, pos(), 2);
					incPos(2);
					operand = text().substring(start, pos());
				default:
					operand = scanClassSetOperand();
			}
		}
		mayContainStrings = !isCharacterComplement && expressionMayContainStrings;
	}

	function scanClassSetSubExpression(expressionType:ClassSetExpressionType):Void {
		var expressionMayContainStrings = mayContainStrings;
		while (pos() < end) {
			var ch = char();
			if (isClassContentExit(ch)) {
				break;
			}
			switch (ch) {
				case '-'.code:
					incPos(1);
					if (char() == '-'.code) {
						incPos(1);
						if (expressionType != ClassSetExpressionTypeClassSubtraction) {
							error(Diagnostics.Operators_must_not_be_mixed_within_a_character_class_Wrap_it_in_a_nested_class_instead, pos() - 2, 2);
						}
					} else {
						error(Diagnostics.Operators_must_not_be_mixed_within_a_character_class_Wrap_it_in_a_nested_class_instead, pos() - 1, 1);
					}
				case '&'.code:
					incPos(1);
					if (char() == '&'.code) {
						incPos(1);
						if (expressionType != ClassSetExpressionTypeClassIntersection) {
							error(Diagnostics.Operators_must_not_be_mixed_within_a_character_class_Wrap_it_in_a_nested_class_instead, pos() - 2, 2);
						}
						if (char() == '&'.code) {
							error(Diagnostics.Unexpected_0_Did_you_mean_to_escape_it_with_backslash, pos(), 1, Utf16.RuneString(ch));
							incPos(1);
						}
					} else {
						error(Diagnostics.Unexpected_0_Did_you_mean_to_escape_it_with_backslash, pos() - 1, 1, Utf16.RuneString(ch));
					}
				default:
					switch (expressionType) {
						case ClassSetExpressionTypeClassSubtraction:
							error(Diagnostics.X_0_expected, pos(), 0, "--");
						case ClassSetExpressionTypeClassIntersection:
							error(Diagnostics.X_0_expected, pos(), 0, "&&");
						default:
					}
			}
			ch = char();
			if (isClassContentExit(ch)) {
				error(Diagnostics.Expected_a_class_set_operand, pos(), 0);
				break;
			}
			scanClassSetOperand();
			if (expressionType == ClassSetExpressionTypeClassIntersection) {
				expressionMayContainStrings = expressionMayContainStrings && mayContainStrings;
			}
		}
		mayContainStrings = expressionMayContainStrings;
	}

	// ClassSetOperand ::=
	//
	//	| '[' ClassSetExpression ']'
	//	| '\' CharacterClassEscape
	//	| '\q{' ClassStringDisjunctionContents '}'
	//	| ClassSetCharacter
	function scanClassSetOperand():String {
		mayContainStrings = false;
		switch (char()) {
			case '['.code:
				incPos(1);
				scanClassSetExpression();
				scanExpectedChar(']'.code);
				return "";
			case '\\'.code:
				incPos(1);
				if (scanCharacterClassEscape()) {
					return "";
				} else if (char() == 'q'.code) {
					incPos(1);
					if (char() == '{'.code) {
						incPos(1);
						scanClassStringDisjunctionContents();
						scanExpectedChar('}'.code);
						return "";
					} else {
						error(Diagnostics.X_q_must_be_followed_by_string_alternatives_enclosed_in_braces, pos() - 2, 2);
						return "q";
					}
				}
				incPos(-1);
				// fallthrough
				return scanClassSetCharacter();
			default:
				return scanClassSetCharacter();
		}
	}

	// ClassStringDisjunctionContents ::= ClassSetCharacter* ('|' ClassSetCharacter*)*
	function scanClassStringDisjunctionContents():Void {
		Debug.Assert(pos() > 0 && StringTools.fastCodeAt(text(), pos() - 1) == '{'.code);
		var characterCount = 0;
		while (pos() < end) {
			final ch = char();
			switch (ch) {
				case '}'.code:
					if (characterCount != 1) {
						mayContainStrings = true;
					}
					return;
				case '|'.code:
					if (characterCount != 1) {
						mayContainStrings = true;
					}
					incPos(1);
					characterCount = 0;
				default:
					scanClassSetCharacter();
					characterCount++;
			}
		}
	}

	// ClassSetCharacter ::=
	//
	//	| SourceCharacter -- ClassSetSyntaxCharacter -- ClassSetReservedDoublePunctuator
	//	| '\' (CharacterEscape | ClassSetReservedPunctuator | 'b')
	function scanClassSetCharacter():String {
		final ch = char();
		if (ch == '\\'.code) {
			incPos(1);
			final innerCh = char();
			switch (innerCh) {
				case 'b'.code:
					incPos(1);
					return "\x08";
				case '&'.code | '-'.code | '!'.code | '#'.code | '%'.code | ','.code | ':'.code | ';'.code | '<'.code | '='.code | '>'.code | '@'.code |
					'`'.code | '~'.code:
					incPos(1);
					return Utf16.RuneString(innerCh);
				default:
					return scanCharacterEscape(false /*atomEscape*/);
			}
		} else if (pos() + 1 < end && ch == charAt(pos() + 1)) {
			switch (ch) {
				case '&'.code | '!'.code | '#'.code | '%'.code | '*'.code | '+'.code | ','.code | '.'.code | ':'.code | ';'.code | '<'.code | '='.code |
					'>'.code | '?'.code | '@'.code | '`'.code | '~'.code:
					error(Diagnostics.A_character_class_must_not_contain_a_reserved_double_punctuator_Did_you_mean_to_escape_it_with_backslash, pos(), 2);
					incPos(2);
					return text().substring(pos() - 2, pos());
				default:
			}
		}
		switch (ch) {
			case '/'.code | '('.code | ')'.code | '['.code | ']'.code | '{'.code | '}'.code | '-'.code | '|'.code:
				error(Diagnostics.Unexpected_0_Did_you_mean_to_escape_it_with_backslash, pos(), 1, Utf16.RuneString(ch));
				incPos(1);
				return Utf16.RuneString(ch);
			default:
		}
		return scanSourceCharacter();
	}

	// ClassAtom ::=
	//
	//	| SourceCharacter but not one of '\' or ']'
	//	| '\' ClassEscape
	//
	// ClassEscape ::=
	//
	//	| 'b'
	//	| '-'
	//	| CharacterClassEscape
	//	| CharacterEscape
	function scanClassAtom():String {
		if (char() == '\\'.code) {
			incPos(1);
			final ch = char();
			switch (ch) {
				case 'b'.code:
					incPos(1);
					return "\x08";
				case '-'.code:
					incPos(1);
					return Utf16.RuneString(ch);
				default:
					if (scanCharacterClassEscape()) {
						return "";
					}
					return scanCharacterEscape(false /*atomEscape*/);
			}
		} else {
			return scanSourceCharacter();
		}
	}

	// CharacterClassEscape ::=
	//
	//	| 'd' | 'D' | 's' | 'S' | 'w' | 'W'
	//	| [+AnyUnicodeMode] ('P' | 'p') '{' UnicodePropertyValueExpression '}'
	function scanCharacterClassEscape():Bool {
		Debug.Assert(pos() > 0 && StringTools.fastCodeAt(text(), pos() - 1) == '\\'.code);
		var isCharacterComplement = false;
		final start = pos() - 1;
		final ch = char();
		switch (ch) {
			case 'd'.code | 'D'.code | 's'.code | 'S'.code | 'w'.code | 'W'.code:
				incPos(1);
				return true;
			case 'P'.code | 'p'.code:
				// PORT: `case 'P'` sets isCharacterComplement and falls through to `case 'p'`.
				if (ch == 'P'.code) {
					isCharacterComplement = true;
				}
				incPos(1);
				if (char() == '{'.code) {
					incPos(1);
					final propertyNameOrValueStart = pos();
					final propertyNameOrValue = scanWordCharacters();
					if (char() == '='.code) {
						final pn = Scanner.nonBinaryUnicodeProperties.get(propertyNameOrValue);
						final propertyName = pn == null ? "" : pn;
						if (pos() == propertyNameOrValueStart) {
							error(Diagnostics.Expected_a_Unicode_property_name, pos(), 0);
						} else if (propertyName == "") {
							error(Diagnostics.Unknown_Unicode_property_name, propertyNameOrValueStart, pos() - propertyNameOrValueStart);
							final suggestion = getSpellingSuggestionForUnicodePropertyName(propertyNameOrValue);
							if (suggestion != "") {
								error(Diagnostics.Did_you_mean_0, propertyNameOrValueStart, pos() - propertyNameOrValueStart, suggestion);
							}
						}
						incPos(1);
						final propertyValueStart = pos();
						final propertyValue = scanWordCharacters();
						if (pos() == propertyValueStart) {
							error(Diagnostics.Expected_a_Unicode_property_value, pos(), 0);
						} else if (propertyName != "") {
							final values = Scanner.valuesOfNonBinaryUnicodeProperties.get(propertyName);
							if (values != null && !values.Has(propertyValue)) {
								error(Diagnostics.Unknown_Unicode_property_value, propertyValueStart, pos() - propertyValueStart);
								final suggestion = getSpellingSuggestionForUnicodePropertyValue(propertyName, propertyValue);
								if (suggestion != "") {
									error(Diagnostics.Did_you_mean_0, propertyValueStart, pos() - propertyValueStart, suggestion);
								}
							}
						}
					} else {
						if (pos() == propertyNameOrValueStart) {
							error(Diagnostics.Expected_a_Unicode_property_name_or_value, pos(), 0);
						} else if (Scanner.binaryUnicodePropertiesOfStrings.Has(propertyNameOrValue)) {
							if (!unicodeSetsMode) {
								error(Diagnostics.Any_Unicode_property_that_would_possibly_match_more_than_a_single_character_is_only_available_when_the_Unicode_Sets_v_flag_is_set,
									propertyNameOrValueStart, pos() - propertyNameOrValueStart);
							} else if (isCharacterComplement) {
								error(Diagnostics.Anything_that_would_possibly_match_more_than_a_single_character_is_invalid_inside_a_negated_character_class,
									propertyNameOrValueStart, pos() - propertyNameOrValueStart);
							} else {
								mayContainStrings = true;
							}
						} else if (!Scanner.valuesOfNonBinaryUnicodeProperties.get("General_Category").Has(propertyNameOrValue)
							&& !Scanner.binaryUnicodeProperties.Has(propertyNameOrValue)) {
							error(Diagnostics.Unknown_Unicode_property_name_or_value, propertyNameOrValueStart, pos() - propertyNameOrValueStart);
							final suggestion = getSpellingSuggestionForUnicodePropertyNameOrValue(propertyNameOrValue);
							if (suggestion != "") {
								error(Diagnostics.Did_you_mean_0, propertyNameOrValueStart, pos() - propertyNameOrValueStart, suggestion);
							}
						}
					}
					scanExpectedChar('}'.code);
					if (!anyUnicodeMode) {
						error(Diagnostics.Unicode_property_value_expressions_are_only_available_when_the_Unicode_u_flag_or_the_Unicode_Sets_v_flag_is_set, start,
							pos() - start);
					}
				} else if (anyUnicodeModeOrNonAnnexB) {
					error(Diagnostics.X_0_must_be_followed_by_a_Unicode_property_value_expression_enclosed_in_braces, pos() - 2, 2, Utf16.RuneString(ch));
				} else {
					incPos(-1);
					return false;
				}
				return true;
			default:
		}
		return false;
	}

	function getSpellingSuggestionForUnicodePropertyName(name:String):String {
		return Core.GetSpellingSuggestionForStrings(name, Scanner.nonBinaryUnicodeProperties.keys());
	}

	function getSpellingSuggestionForUnicodePropertyValue(propertyName:String, value:String):String {
		final values = Scanner.valuesOfNonBinaryUnicodeProperties.get(propertyName);
		if (values == null) {
			return "";
		}
		return Core.GetSpellingSuggestionForStrings(value, values.Keys().keys());
	}

	function getSpellingSuggestionForUnicodePropertyNameOrValue(name:String):String {
		return Core.GetSpellingSuggestionForStrings(name, Core.ConcatenateSeq(
			Scanner.valuesOfNonBinaryUnicodeProperties.get("General_Category").Keys().keys(),
			Scanner.binaryUnicodeProperties.Keys().keys(),
			Scanner.binaryUnicodePropertiesOfStrings.Keys().keys()
		));
	}

	function scanWordCharacters():String {
		final start = pos();
		while (pos() < end) {
			final ch = char();
			if (!Scanner.isWordCharacter(ch)) {
				break;
			}
			incPos(1);
		}
		return text().substring(start, pos());
	}

	function scanSourceCharacter():String {
		if (pos() >= end) {
			return "";
		}
		if (!anyUnicodeMode) {
			if (pendingLowSurrogate != 0) {
				// Second of two surrogate code units for the same non-BMP character.
				// Now advance past the full UTF-8 sequence (the high surrogate call did not advance).
				final size = Utf16.RuneLen(Utf16.DecodeRuneInString(text(), pos()));
				incPos(size);
				final low = pendingLowSurrogate;
				pendingLowSurrogate = 0;
				return Stringutil.EncodeJSStringRune(low);
			}
			final ch = Utf16.DecodeRuneInString(text(), pos());
			final size = Utf16.RuneLen(ch);
			if (ch == Utf16.RuneError) {
				// Not a valid rune; consume one raw byte.
				// PORT: utf16 — Go returns string(byte) of the invalid byte; the UTF-16 text holds
				// U+FFFD (or a lone surrogate) there instead.
				incPos(1);
				return Utf16.RuneString(StringTools.fastCodeAt(text(), pos() - 1));
			}
			if (ch >= 0x10000) { // utf16.RuneLen(ch) == 2
				// Non-BMP character: emit the high surrogate first WITHOUT advancing.
				// The low surrogate will be emitted on the next call, which also advances.
				final pair = Stringutil.CodePointToSurrogatePair(ch);
				pendingLowSurrogate = pair.r2;
				return Stringutil.EncodeJSStringRune(pair.r1);
			}
			incPos(size);
			return Utf16.RuneString(ch);
		}
		final ch = Utf16.DecodeRuneInString(text(), pos());
		final size = Utf16.RuneLen(ch);
		if (ch == Utf16.RuneError) {
			// Invalid UTF-8; consume the byte to avoid infinite loops.
			incPos(size);
			return "";
		}
		incPos(size);
		return Utf16.RuneString(ch);
	}

	function scanExpectedChar(ch:Int):Void {
		if (char() == ch) {
			incPos(1);
		} else {
			error(Diagnostics.X_0_expected, pos(), 0, Utf16.RuneString(ch));
		}
	}

	function scanDigits():Void {
		final start = pos();
		while (pos() < end && Stringutil.IsDigit(char())) {
			incPos(1);
		}
		scanner.tokenValue = text().substring(start, pos());
	}

	function run():Void {
		// Regular expressions are checked more strictly when either in 'u' or 'v' mode, or
		// when not using the looser interpretation of the syntax from ECMA-262 Annex B.
		anyUnicodeModeOrNonAnnexB = anyUnicodeMode || !annexB;

		scanDisjunction(false /*isInGroup*/);

		if (groupNameReferences != null) {
			for (reference in groupNameReferences) {
				if (groupSpecifiers.get(reference.name) != true) {
					error(Diagnostics.There_is_no_capturing_group_named_0_in_this_regular_expression, reference.pos, reference.end - reference.pos, reference.name);
					if (groupSpecifiers.keys().hasNext()) {
						final suggestion = Core.GetSpellingSuggestionForStrings(reference.name, groupSpecifiers.keys());
						if (suggestion != "") {
							error(Diagnostics.Did_you_mean_0, reference.pos, reference.end - reference.pos, suggestion);
						}
					}
				}
			}
		}
		if (decimalEscapes != null) {
			for (escape in decimalEscapes) {
				// Although a DecimalEscape with a value greater than the number of capturing groups
				// is treated as either a LegacyOctalEscapeSequence or an IdentityEscape in Annex B,
				// an error is nevertheless reported since it's most likely a mistake.
				if (escape.value > numberOfCapturingGroups) {
					if (numberOfCapturingGroups > 0) {
						error(Diagnostics.This_backreference_refers_to_a_group_that_does_not_exist_There_are_only_0_capturing_groups_in_this_regular_expression,
							escape.pos, escape.end - escape.pos, numberOfCapturingGroups);
					} else {
						error(Diagnostics.This_backreference_refers_to_a_group_that_does_not_exist_There_are_no_capturing_groups_in_this_regular_expression,
							escape.pos, escape.end - escape.pos);
					}
				}
			}
		}
	}
}
