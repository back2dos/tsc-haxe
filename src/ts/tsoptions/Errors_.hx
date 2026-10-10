package ts.tsoptions;

// Port of the commandLineParser method of errors.go (package-level funcs are in Tsoptions.hx).
// PORT: module named Errors_ so it does not shadow go.Errors. Used with `using` (PORTING §2).
class Errors_ {
	public static function createUnknownOptionError(parser:CommandLineParser, unknownOption:std.String, unknownOptionErrorText:std.String, node:Null<Node>,
			sourceFile:Null<SourceFile>):Diagnostic {
		return Tsoptions.createUnknownOptionError(unknownOption, parser.UnknownOptionDiagnostic(), unknownOptionErrorText, node, sourceFile,
			parser.AlternateMode());
	}
}
