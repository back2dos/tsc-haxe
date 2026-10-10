package ts.printer;

// Port of internal/printer/utilities_test.go (package printer: reaches unexported functions through
// @:allow(ts.printer) on class Printer).
class UtilitiesTest {
	public static function run() {
		T.run("TestEscapeString", TestEscapeString);
		T.run("TestEscapeNonAsciiString", TestEscapeNonAsciiString);
		T.run("TestEscapeJsxAttributeString", TestEscapeJsxAttributeString);
		T.run("TestIsRecognizedTripleSlashComment", TestIsRecognizedTripleSlashComment);
	}

	// Go `%v` of a QuoteChar (a rune): its integer value.
	static function name(fn:std.String, i:Int, s:std.String, q:QuoteChar):std.String {
		return '[${i}] ${fn}("${s}", ${(q : Int)})';
	}

	static function TestEscapeString() {
		final data:Array<EscapeRow> = [
			new EscapeRow("", QuoteCharDoubleQuote, ""),
			new EscapeRow("abc", QuoteCharDoubleQuote, "abc"),
			new EscapeRow("ab\"c", QuoteCharDoubleQuote, "ab\\\"c"),
			new EscapeRow("ab\tc", QuoteCharDoubleQuote, "ab\\tc"),
			new EscapeRow("ab\nc", QuoteCharDoubleQuote, "ab\\nc"),
			new EscapeRow("ab'c", QuoteCharDoubleQuote, "ab'c"),
			new EscapeRow("ab'c", QuoteCharSingleQuote, "ab\\'c"),
			new EscapeRow("ab\"c", QuoteCharSingleQuote, "ab\"c"),
			new EscapeRow("ab`c", QuoteCharBacktick, "ab\\`c"),
			new EscapeRow("\u001f", QuoteCharBacktick, "\\u001F"),
		];
		for (i in 0...data.length) {
			final rec = data[i];
			T.run("TestEscapeString/" + name("escapeString", i, rec.s, rec.quoteChar), function() {
				final actual = Printer.EscapeString(rec.s, rec.quoteChar);
				T.eq(actual, rec.expected);
			});
		}
	}

	static function TestEscapeNonAsciiString() {
		final data:Array<EscapeRow> = [
			new EscapeRow("", QuoteCharDoubleQuote, ""),
			new EscapeRow("abc", QuoteCharDoubleQuote, "abc"),
			new EscapeRow("ab\"c", QuoteCharDoubleQuote, "ab\\\"c"),
			new EscapeRow("ab\tc", QuoteCharDoubleQuote, "ab\\tc"),
			new EscapeRow("ab\nc", QuoteCharDoubleQuote, "ab\\nc"),
			new EscapeRow("ab'c", QuoteCharDoubleQuote, "ab'c"),
			new EscapeRow("ab'c", QuoteCharSingleQuote, "ab\\'c"),
			new EscapeRow("ab\"c", QuoteCharSingleQuote, "ab\"c"),
			new EscapeRow("ab`c", QuoteCharBacktick, "ab\\`c"),
			new EscapeRow("ab\u008fc", QuoteCharDoubleQuote, "ab\\u008Fc"),
			new EscapeRow("𝟘𝟙", QuoteCharDoubleQuote, "\\uD835\\uDFD8\\uD835\\uDFD9"),
		];
		for (i in 0...data.length) {
			final rec = data[i];
			T.run("TestEscapeNonAsciiString/" + name("escapeNonAsciiString", i, rec.s, rec.quoteChar), function() {
				final actual = Printer.escapeNonAsciiString(rec.s, rec.quoteChar);
				T.eq(actual, rec.expected);
			});
		}
	}

	static function TestEscapeJsxAttributeString() {
		final data:Array<EscapeRow> = [
			new EscapeRow("", QuoteCharDoubleQuote, ""),
			new EscapeRow("abc", QuoteCharDoubleQuote, "abc"),
			new EscapeRow("ab\"c", QuoteCharDoubleQuote, "ab&quot;c"),
			new EscapeRow("ab\tc", QuoteCharDoubleQuote, "ab&#x9;c"),
			new EscapeRow("ab\nc", QuoteCharDoubleQuote, "ab&#xA;c"),
			new EscapeRow("ab'c", QuoteCharDoubleQuote, "ab'c"),
			new EscapeRow("ab'c", QuoteCharSingleQuote, "ab&apos;c"),
			new EscapeRow("ab\"c", QuoteCharSingleQuote, "ab\"c"),
			new EscapeRow("ab\u008fc", QuoteCharDoubleQuote, "ab\u008Fc"),
			new EscapeRow("𝟘𝟙", QuoteCharDoubleQuote, "𝟘𝟙"),
		];
		for (i in 0...data.length) {
			final rec = data[i];
			T.run("TestEscapeJsxAttributeString/" + name("escapeJsxAttributeString", i, rec.s, rec.quoteChar), function() {
				final actual = Printer.escapeJsxAttributeString(rec.s, rec.quoteChar);
				T.eq(actual, rec.expected);
			});
		}
	}

	static function TestIsRecognizedTripleSlashComment() {
		// Go zero value ast.CommentRange{} → null here (Kind KindUnknown, filled in below).
		final data:Array<TripleSlashRow> = [
			new TripleSlashRow("", new CommentRange(Core.NewTextRange(0, 0), KindMultiLineCommentTrivia, false), false),
			new TripleSlashRow("", new CommentRange(Core.NewTextRange(0, 0), KindSingleLineCommentTrivia, false), false),
			new TripleSlashRow("/a", null, false),
			new TripleSlashRow("//", null, false),
			new TripleSlashRow("//a", null, false),
			new TripleSlashRow("///", null, false),
			new TripleSlashRow("///a", null, false),
			new TripleSlashRow("///<reference path=\"foo\" />", null, true),
			new TripleSlashRow("///<reference types=\"foo\" />", null, true),
			new TripleSlashRow("///<reference lib=\"foo\" />", null, true),
			new TripleSlashRow("///<reference no-default-lib=\"foo\" />", null, true),
			new TripleSlashRow("///<amd-dependency path=\"foo\" />", null, true),
			new TripleSlashRow("///<amd-module />", null, true),
			new TripleSlashRow("/// <reference path=\"foo\" />", null, true),
			new TripleSlashRow("/// <reference types=\"foo\" />", null, true),
			new TripleSlashRow("/// <reference lib=\"foo\" />", null, true),
			new TripleSlashRow("/// <reference no-default-lib=\"foo\" />", null, true),
			new TripleSlashRow("/// <amd-dependency path=\"foo\" />", null, true),
			new TripleSlashRow("/// <amd-module />", null, true),
			new TripleSlashRow("/// <reference path=\"foo\"/>", null, true),
			new TripleSlashRow("/// <reference types=\"foo\"/>", null, true),
			new TripleSlashRow("/// <reference lib=\"foo\"/>", null, true),
			new TripleSlashRow("/// <reference no-default-lib=\"foo\"/>", null, true),
			new TripleSlashRow("/// <amd-dependency path=\"foo\"/>", null, true),
			new TripleSlashRow("/// <amd-module/>", null, true),
			new TripleSlashRow("/// <reference path='foo' />", null, true),
			new TripleSlashRow("/// <reference types='foo' />", null, true),
			new TripleSlashRow("/// <reference lib='foo' />", null, true),
			new TripleSlashRow("/// <reference no-default-lib='foo' />", null, true),
			new TripleSlashRow("/// <amd-dependency path='foo' />", null, true),
			new TripleSlashRow("/// <reference path=\"foo\" />  ", null, true),
			new TripleSlashRow("/// <reference types=\"foo\" />  ", null, true),
			new TripleSlashRow("/// <reference lib=\"foo\" />  ", null, true),
			new TripleSlashRow("/// <reference no-default-lib=\"foo\" />  ", null, true),
			new TripleSlashRow("/// <amd-dependency path=\"foo\" />  ", null, true),
			new TripleSlashRow("/// <amd-module />  ", null, true),
			new TripleSlashRow("/// <foo />", null, false),
			new TripleSlashRow("/// <reference />", null, false),
			new TripleSlashRow("/// <amd-dependency />", null, false),
		];
		for (i in 0...data.length) {
			final rec = data[i];
			T.run('TestIsRecognizedTripleSlashComment/[${i}] isRecognizedTripleSlashComment()', function() {
				var commentRange = rec.commentRange == null ? new CommentRange(Core.NewTextRange(0, 0), KindUnknown, false) : rec.commentRange.copy();
				if (commentRange.Kind == KindUnknown) {
					commentRange.Kind = KindSingleLineCommentTrivia;
					commentRange.TextRange = Core.NewTextRange(0, rec.s.length);
				}
				final actual = Printer.IsRecognizedTripleSlashComment(rec.s, commentRange);
				T.eq(actual, rec.expected);
			});
		}
	}
}

private class EscapeRow {
	public final s:std.String;
	public final quoteChar:QuoteChar;
	public final expected:std.String;

	public function new(s:std.String, quoteChar:QuoteChar, expected:std.String) {
		this.s = s;
		this.quoteChar = quoteChar;
		this.expected = expected;
	}
}

private class TripleSlashRow {
	public final s:std.String;
	public final commentRange:CommentRange;
	public final expected:Bool;

	public function new(s:std.String, commentRange:CommentRange, expected:Bool) {
		this.s = s;
		this.commentRange = commentRange;
		this.expected = expected;
	}
}
