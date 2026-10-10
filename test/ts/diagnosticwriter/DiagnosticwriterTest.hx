package ts.diagnosticwriter;

import ts.diagnosticwriter.DiagnosticwriterGolden as G;

// Upstream has no diagnosticwriter tests. Golden checks against a Go reference run of the pinned
// upstream (DiagnosticwriterGolden.hx): same files and diagnostics (positions given as line and
// UTF-16 character), output compared byte for byte.
class DiagnosticwriterTest {
	public static function run() {
		T.run("GoldenDiagnosticwriter", () -> {
			final a = new TestFile("/proj/src/a.ts", "let \u{1F600} = 1;\n\tconst x:\tnumber = \"s\";   \nfoo();\n");
			final lines = [for (i in 0...12) 'line$i \u{1F600} x'];
			final b = new TestFile("/proj/src/b.ts", lines.join("\r\n"));
			final c = new TestFile("/other/c.ts", "x");

			final d1 = mk(a, 1, 7, 1, 8, 2322, CategoryError, "Type 'string' is not assignable to type 'number'.");
			final chain1 = mk(null, 0, 0, 0, 0, 1, CategoryMessage, "chain level 1");
			chain1.chain = [mk(null, 0, 0, 0, 0, 1, CategoryMessage, "chain level 2")];
			d1.chain = [chain1];
			d1.related = [
				mk(a, 0, 4, 0, 6, 6500, CategoryMessage, "The expected type comes from here."),
				mk(null, 0, 0, 0, 0, 1, CategoryMessage, "no file"),
			];
			final d2 = mk(b, 1, 3, 9, 4, 1005, CategoryWarning, "Long span.");
			final d3 = mk(a, 2, 0, 2, 0, 1109, CategorySuggestion, "Zero length.");
			final d4 = mk(null, 0, 0, 0, 0, 5023, CategoryError, "Global error.");
			final d5 = mk(c, 0, 0, 0, 1, 2304, CategoryError, "Cannot find name 'x'.");
			final d6 = mk(b, 0, 0, 3, 2, 1, CategoryError, "Four lines.");
			final d7 = mk(b, 2, 9, 2, 9, 1, CategoryError, "Emoji col.");
			final d8 = mk(a, 0, 0, 0, 3, Diagnostics.File_appears_to_be_binary.Code(), CategoryError, "binary");

			final all:Array<Diagnostic> = [d1, d2, d3, d4, d5, d6, d7, d8];
			final opts = new FormattingOptions();
			opts.Locale = ts.locale.Locale.Default;
			opts.ComparePathsOptions = new ComparePathsOptions(true, "/proj");
			opts.NewLine = "\n";

			var sb = new TestWriter();
			Diagnosticwriter.FormatDiagnosticsWithColorAndContext(sb, all, opts);
			T.eq(G.PRETTY, sb.toString());
			sb = new TestWriter();
			Diagnosticwriter.WriteFormatDiagnostics(sb, all, opts);
			T.eq(G.PLAIN, sb.toString());
			final sets:Array<Array<Diagnostic>> = [all, [d1], [d4], [d1, d6], [d1, d2], [d3]];
			final many:Array<Diagnostic> = [for (_ in 0...12) d5];
			many.push(d1);
			sets.push(many);
			for (i in 0...sets.length) {
				sb = new TestWriter();
				Diagnosticwriter.WriteErrorSummaryText(sb, sets[i], opts);
				T.eq(G.SUMMARY[i], sb.toString());
			}
			T.eq(G.FLAT, Diagnosticwriter.FlattenDiagnosticMessage(d1, "\r\n", ts.locale.Locale.Default));
			sb = new TestWriter();
			Diagnosticwriter.FormatDiagnosticsStatusWithColorAndTime(sb, "12:00:00 AM", d4, opts);
			Diagnosticwriter.FormatDiagnosticsStatusAndTime(sb, "12:00:00 AM", d4, opts);
			T.eq(G.STATUS, sb.toString());
			sb = new TestWriter();
			final w = mk(null, 0, 0, 0, 0, Diagnostics.Starting_compilation_in_watch_mode.Code(), CategoryMessage, "Starting");
			final r1 = Diagnosticwriter.TryClearScreen(sb, w, new CompilerOptions());
			final o2 = new CompilerOptions();
			o2.PreserveWatchOutput = TSTrue;
			final r2 = Diagnosticwriter.TryClearScreen(sb, w, o2);
			final r3 = Diagnosticwriter.TryClearScreen(sb, d4, new CompilerOptions());
			T.eq(G.CLEAR_RESULTS[0], r1);
			T.eq(G.CLEAR_RESULTS[1], r2);
			T.eq(G.CLEAR_RESULTS[2], r3);
			T.eq(G.CLEAR, sb.toString());
		});
		runAST();
	}

	static function runAST() {
		T.run("ASTDiagnosticWrapper", () -> {
			final f = Ast.NewNodeFactory(new NodeFactoryHooks());
			final opts = new SourceFileParseOptions();
			opts.FileName = "/other/c.ts";
			opts.Path = "/other/c.ts";
			final file = f.NewSourceFile(opts, "x", f.NewNodeList([]), f.NewToken(KindEndOfFile)).AsSourceFile();
			final d1 = Ast.NewDiagnostic(file, new TextRange(0, 1), Diagnostics.Cannot_find_name_0, "x");
			final d2 = Ast.NewDiagnostic(file, new TextRange(0, 1), Diagnostics.Cannot_find_name_0, "y");
			final fo = new FormattingOptions();
			fo.ComparePathsOptions = new ComparePathsOptions(true, "/proj");
			fo.NewLine = "\n";
			var sb = new TestWriter();
			Diagnosticwriter.WriteFormatDiagnostics(sb, Diagnosticwriter.FromASTDiagnostics([d1]), fo);
			T.eq("../other/c.ts(1,1): error TS2304: Cannot find name 'x'.\n", sb.toString());
			sb = new TestWriter();
			Diagnosticwriter.WriteErrorSummaryText(sb, Diagnosticwriter.FromASTDiagnostics([d1, d2]), fo);
			T.eq("\nFound 2 errors in the same file, starting at: ../other/c.ts\x1b[90m:1\x1b[0m\n\n", sb.toString());
		});
	}

	// position from (line, UTF-16 character)
	static function at(f:TestFile, line:Int, ch:Int):Int {
		return Scanner.GetECMAPositionOfLineAndUTF16Character(f, line, ch);
	}

	static function mk(f:TestFile, l1:Int, c1:Int, l2:Int, c2:Int, code:Int, cat:Category, msg:String):TestDiag {
		final d = new TestDiag(f, code, cat, msg);
		if (f != null) {
			d.pos = at(f, l1, c1);
			d.end = at(f, l2, c2);
		}
		return d;
	}
}

private class TestFile implements FileLike {
	final name:String;
	final text:String;
	final lines:Array<TextPos>;

	public function new(name:String, text:String) {
		this.name = name;
		this.text = text;
		this.lines = Core.ComputeECMALineStarts(text);
	}

	public function FileName():String {
		return name;
	}

	public function Text():String {
		return text;
	}

	public function ECMALineMap():Array<TextPos> {
		return lines;
	}
}

private class TestDiag implements Diagnostic {
	public final file:TestFile;
	public var pos = 0;
	public var end = 0;
	public final code:Int;
	public final cat:Category;
	public final msg:String;
	public var chain:Array<Diagnostic> = null;
	public var related:Array<Diagnostic> = null;

	public function new(file:TestFile, code:Int, cat:Category, msg:String) {
		this.file = file;
		this.code = code;
		this.cat = cat;
		this.msg = msg;
	}

	public function File():FileLike {
		return file;
	}

	public function Pos():Int {
		return pos;
	}

	public function End():Int {
		return end;
	}

	public function Len():Int {
		return end - pos;
	}

	public function Code():Int {
		return code;
	}

	public function Category():Category {
		return cat;
	}

	public function Localize(l:ts.locale.Locale):String {
		return msg;
	}

	public function MessageChain():Array<Diagnostic> {
		return chain;
	}

	public function RelatedInformation():Array<Diagnostic> {
		return related;
	}
}

private class TestWriter implements Writer {
	final b = new StringBuf();

	public function new() {}

	public function Write(p:String):ValueError<Int> {
		b.add(p);
		return new ValueError<Int>(p.length, null);
	}

	public function toString():String {
		return b.toString();
	}
}
