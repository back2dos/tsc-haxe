package ts.printer;

import go.Utf8;
import ts.ast.Ast;
import ts.ast.Parseoptions.SourceFileParseOptions;
import ts.core.Core;
import ts.core.Compileroptions.NewLineKind;
import ts.parser.Parser;
import ts.printer.Printer;
import ts.printer.Printer.PrinterOptions;
import ts.printer.Printer.PrintHandlers;

// Haxe counterpart of tools/dump/print/main.go (printer gate, tools/gate/printer.sh): prints every
// file with the ported printer in exactly the same format.
//
// Usage: PrintDump FILE... | @LISTFILE (one path per line)
// Each file is parsed (FileName and Path = the argument, script kind from the extension) and
// printed with Printer.NewPrinter({NewLine: LF}, new PrintHandlers(), Printer.NewEmitContext())
// and EmitSourceFile (one fresh EmitContext + Printer per file; no binder, no transforms).
// Output per file: "## <file>", then the printed text split on "\n" (a trailing newline yields a
// final empty piece), each piece as "| " + escape(piece). escape works per UTF-16 code unit:
// `\` -> `\\`, CR -> `\r`, TAB -> `\t`, other units < 0x20 or > 0x7E -> `\uXXXX` (upper-case
// hex), else the character. If EmitSourceFile throws: "!panic " + message for a thrown String
// (a ported Go panic(string)), "!panic" for any other exception (null access = Go runtime error;
// hxcpp reports it as the String "Null Object Reference", treated the same).
// At exit "print-ms <ms>" (time spent in EmitSourceFile only) is written to stderr.
class PrintDump {
	static var out:StringBuf = new StringBuf();
	static var pending = 0;
	static var printTime = 0.0;

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
		Sys.stderr().writeString("print-ms " + Std.int(printTime * 1000) + "\n");
	}

	static function flush() {
		pending = 0;
		Sys.stdout().writeString(out.toString());
		out = new StringBuf();
	}

	static function dump(file:String, text:String) {
		out.add("## ");
		out.add(file);
		out.addChar("\n".code);
		final popts = new SourceFileParseOptions();
		popts.FileName = file;
		popts.Path = file;
		final sf = Parser.ParseSourceFile(popts, text, Core.GetScriptKindFromFileName(file));
		final opts = new PrinterOptions();
		opts.NewLine = NewLineKind.NewLineKindLF;
		final p = Printer.NewPrinter(opts, new PrintHandlers(), Printer.NewEmitContext());
		var printed:String = null;
		var panicked:String = null;
		final t0 = haxe.Timer.stamp();
		try {
			printed = p.EmitSourceFile(sf);
		} catch (e:Dynamic) {
			// hxcpp (HXCPP_CHECK_POINTER) reports a null access as the String "Null Object Reference": a runtime error.
			panicked = (e is String && e != "Null Object Reference") ? "!panic " + escapeString(e) : "!panic";
		}
		printTime += haxe.Timer.stamp() - t0;
		if (panicked != null) {
			out.add(panicked);
			out.addChar("\n".code);
		} else {
			for (piece in printed.split("\n")) {
				out.add("| ");
				escape(out, piece);
				out.addChar("\n".code);
			}
			pending += printed.length;
		}
		pending += 64;
		if (pending > (1 << 16))
			flush();
	}

	static function escapeString(v:String):String {
		final b = new StringBuf();
		escape(b, v);
		return b.toString();
	}

	static inline final hexDigits = "0123456789ABCDEF";

	static function escape(b:StringBuf, v:String) {
		for (i in 0...v.length) {
			final c = StringTools.fastCodeAt(v, i);
			if (c == "\r".code) {
				b.add("\\r");
			} else if (c == "\t".code) {
				b.add("\\t");
			} else if (c == "\\".code) {
				b.add("\\\\");
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
	}
}
