package ts.parser;

import go.Utf8;
import ts.ast.Ast;
import ts.ast.KindGenerated.Kind;
import ts.ast.Nodeflags.NodeFlags;
import ts.ast.Parseoptions.SourceFileParseOptions;
import ts.core.Core;
import ts.locale.Locale;

// Haxe counterpart of tools/dump/ast/main.go (Phase 3 gate): prints the AST and the parse
// diagnostics of the parser in exactly the same format.
//
// Usage: AstDump FILE... | @LISTFILE (one path per line)
// Output per file: "## <file>", then one line per node in ForEachChild pre-order:
//   <2*depth spaces><Kind> <pos> <end> <NodeFlags> [<text>]
// JSDoc nodes attached to a node (NodeFlagsHasJSDoc) follow its line, marked "@jsdoc ", before
// its children. Then the parse diagnostics (file.Diagnostics(), then file.JSDiagnostics()):
//   D <code> <pos> <len> <message text, escaped>
// Positions are UTF-16 code-unit offsets (the port's native positions). The script kind comes
// from the file extension; FileName and Path are the argument.
class AstDump {
	static var out:StringBuf = new StringBuf();

	static function main() {
		final files:Array<String> = [];
		for (arg in Sys.args()) {
			if (StringTools.startsWith(arg, "@")) {
				for (line in sys.io.File.getContent(arg.substring(1)).split("\n")) {
					final l = StringTools.trim(line);
					if (l != "")
						files.push(l);
				}
			} else {
				files.push(arg);
			}
		}
		for (file in files) {
			final data = sys.io.File.getBytes(file);
			dump(file, Utf8.BytesToString(data, 0, data.length));
		}
		flush();
	}

	// Writes the buffered output (like Go's bufio.Writer) about every 64 KiB, so a deeply nested
	// file (output quadratic in the depth) does not sit in memory as a whole.
	static var pending = 0;

	static function flush() {
		pending = 0;
		Sys.stdout().writeString(out.toString());
		out = new StringBuf();
	}

	static var sf:SourceFile = null;
	static var depth = 0;
	static var walkChild:(node:Node) -> Bool = null;

	static function dump(file:String, text:String) {
		out.add("## ");
		out.add(file);
		out.addChar("\n".code);
		final opts = new SourceFileParseOptions();
		opts.FileName = file;
		opts.Path = file;
		sf = Parser.ParseSourceFile(opts, text, Core.GetScriptKindFromFileName(file));
		if (walkChild == null) {
			walkChild = function(child:Node):Bool {
				depth++;
				walk(child, "");
				depth--;
				return false;
			};
		}
		depth = 0;
		walk(sf.AsNode(), "");
		final diags = [];
		if (sf.Diagnostics() != null)
			for (d in sf.Diagnostics())
				diags.push(d);
		if (sf.JSDiagnostics() != null)
			for (d in sf.JSDiagnostics())
				diags.push(d);
		for (d in diags) {
			final b = out;
			b.add("D ");
			b.add(d.Code());
			b.addChar(" ".code);
			b.add(d.Pos());
			b.addChar(" ".code);
			b.add(d.End() - d.Pos());
			b.addChar(" ".code);
			escape(b, d.Localize(Locale.Default));
			b.addChar("\n".code);
		}
		sf = null;
	}

	// Appends 2*depth spaces (Go strings.Repeat("  ", depth)) from one shared string of spaces.
	static var spaces = "  ";

	static function indent(b:StringBuf, depth:Int):Void {
		while (spaces.length < 2 * depth) {
			spaces += spaces;
		}
		b.addSub(spaces, 0, 2 * depth);
	}

	static function walk(node:Node, mark:String):Void {
		final b = out;
		indent(b, depth);
		b.add(mark);
		b.add(node.Kind.String());
		b.addChar(" ".code);
		b.add(node.Pos());
		b.addChar(" ".code);
		b.add(node.End());
		b.addChar(" ".code);
		b.add((node.Flags : Int));
		nodeText(b, node);
		b.addChar("\n".code);
		pending += 2 * depth + 64;
		if (pending > (1 << 16)) {
			flush();
		}
		if (node.Flags & NodeFlagsHasJSDoc != 0) {
			final jsdocs = node.AsNode().JSDoc(sf);
			if (jsdocs != null) {
				for (jsdoc in jsdocs) {
					depth++;
					walk(jsdoc, "@jsdoc ");
					depth--;
				}
			}
		}
		node.ForEachChild(walkChild);
	}

	static function nodeText(b:StringBuf, node:Node):Void {
		switch (node.Kind) {
			case KindIdentifier | KindPrivateIdentifier | KindStringLiteral | KindNumericLiteral | KindBigIntLiteral | KindNoSubstitutionTemplateLiteral |
				KindTemplateHead | KindTemplateMiddle | KindTemplateTail | KindRegularExpressionLiteral:
				b.addChar(" ".code);
				escape(b, node.Text());
			case KindJsxText:
				b.addChar(" ".code);
				escape(b, node.AsJsxText().Text);
			default:
		}
	}

	static inline final hexDigits = "0123456789ABCDEF";

	static function escape(b:StringBuf, v:String) {
		b.addChar('"'.code);
		for (i in 0...v.length) {
			final c = StringTools.fastCodeAt(v, i);
			if (c == "\n".code) {
				b.add("\\n");
			} else if (c == "\r".code) {
				b.add("\\r");
			} else if (c == "\t".code) {
				b.add("\\t");
			} else if (c == "\\".code) {
				b.add("\\\\");
			} else if (c == '"'.code) {
				b.add('\\"');
			} else if (c < 0x20 || c > 0x7E) {
				b.add("\\u");
				b.addChar(StringTools.fastCodeAt(hexDigits, (c >> 12) & 15));
				b.addChar(StringTools.fastCodeAt(hexDigits, (c >> 8) & 15));
				b.addChar(StringTools.fastCodeAt(hexDigits, (c >> 4) & 15));
				b.addChar(StringTools.fastCodeAt(hexDigits, c & 15));
			} else {
				b.addChar(c);
			}
		}
		b.addChar('"'.code);
	}
}
