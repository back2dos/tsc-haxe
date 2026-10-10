package ts.printer;

// Port of internal/testutil/parsetestutil (test helper; lives with the printer tests).
class Parsetestutil {
	// Simplifies parsing an input string into a SourceFile for testing purposes.
	public static function ParseTypeScript(text:std.String, jsx:Bool):SourceFile {
		final fileName = Core.IfElse(jsx, "/main.tsx", "/main.ts");
		final opts = new SourceFileParseOptions();
		opts.FileName = fileName;
		opts.Path = fileName;
		final file = Parser.ParseSourceFile(opts, text, Core.GetScriptKindFromFileName(fileName));
		return file;
	}

	// Asserts that the given file has no parse diagnostics.
	public static function CheckDiagnostics(file:SourceFile):Void {
		if (Core.len(file.Diagnostics()) > 0) {
			final b = new BuilderWriter();
			final opts = new FormattingOptions();
			opts.NewLine = "\n";
			Diagnosticwriter.WriteFormatDiagnostics(b, Diagnosticwriter.FromASTDiagnostics(file.Diagnostics()), opts);
			T.fail(b.b.toString());
		}
	}

	// Asserts that the given file has no parse diagnostics and asserts the given message.
	public static function CheckDiagnosticsMessage(file:SourceFile, message:std.String):Void {
		if (Core.len(file.Diagnostics()) > 0) {
			final b = new BuilderWriter();
			final opts = new FormattingOptions();
			opts.NewLine = "\n";
			Diagnosticwriter.WriteFormatDiagnostics(b, Diagnosticwriter.FromASTDiagnostics(file.Diagnostics()), opts);
			T.fail(message + b.b.toString());
		}
	}

	static function newSyntheticRecursiveVisitor():NodeVisitor {
		var v:NodeVisitor = null;
		final hooks = new NodeVisitorHooks();
		hooks.VisitNode = function(node:Node, v:NodeVisitor):Node {
			if (node != null) {
				node.Loc = Core.UndefinedTextRange();
			}
			return v.VisitNode(node);
		};
		hooks.VisitToken = function(node:Node, v:NodeVisitor):Node {
			if (node != null) {
				node.Loc = Core.UndefinedTextRange();
			}
			return v.VisitNode(node);
		};
		hooks.VisitNodes = function(nodes:NodeList, v:NodeVisitor):NodeList {
			if (nodes != null) {
				nodes.Loc = Core.UndefinedTextRange();
			}
			return v.VisitNodes(nodes);
		};
		hooks.VisitModifiers = function(nodes:ModifierList, v:NodeVisitor):ModifierList {
			if (nodes != null) {
				nodes.Loc = Core.UndefinedTextRange();
			}
			return v.VisitModifiers(nodes);
		};
		v = Ast.NewNodeVisitor(function(node:Node):Node {
			return v.VisitEachChild(node);
		}, new ts.ast.Ast.NodeFactory(), hooks);
		return v;
	}

	// Sets the Loc of the given node and every Node in its subtree to an undefined TextRange (-1,-1).
	public static function MarkSyntheticRecursive(node:Node):Void {
		newSyntheticRecursiveVisitor().VisitNode(node);
	}
}

// strings.Builder as an io.Writer.
class BuilderWriter implements Writer {
	public final b:StringBuf = new StringBuf();

	public function new() {}

	public function Write(p:std.String):ValueError<Int> {
		b.add(p);
		return new ValueError<Int>(p.length, null);
	}
}
