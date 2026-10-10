package ts.printer;

// Port of internal/testutil/emittestutil (test helper; lives with the printer tests).
class Emittestutil {
	// Checks that pretty-printing the given file matches the expected output.
	public static function CheckEmit(emitContext:EmitContext, file:SourceFile, expected:std.String, ?pos:haxe.PosInfos):Void {
		final opts = new PrinterOptions();
		opts.NewLine = NewLineKindLF;
		final printer = Printer.NewPrinter(opts, new PrintHandlers(), emitContext);
		final text = printer.EmitSourceFile(file);
		final actual = StringTools.endsWith(text, "\n") ? text.substring(0, text.length - 1) : text;
		T.eq(expected, actual, pos);
		final file2 = Parsetestutil.ParseTypeScript(text, file.LanguageVariant == LanguageVariantJSX);
		Parsetestutil.CheckDiagnosticsMessage(file2, "error on reparse: ");
	}
}
