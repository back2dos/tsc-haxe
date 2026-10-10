package ts.scanner;

import go.Utf8;
import ts.ast.KindGenerated.Kind;
import ts.core.Compileroptions.ScriptTarget;
import ts.core.Languagevariant.LanguageVariant;
import ts.diagnostics.Diagnostics.Message;

// Haxe counterpart of tools/dump/tokens/main.go (Phase 2 gate): prints the raw token stream
// of the scanner in exactly the same format.
//
// Usage: TokenDump [-trivia] FILE... | @LISTFILE (one path per line)
// Output per file: "## <file>", then one line per token:
//   <Kind> <pos> <end> <flags> <value>
// and one line per scanner error:
//   E <code> <pos> <len>
// Positions are UTF-16 code-unit offsets (the port's native positions). <value> is escaped per
// UTF-16 code unit: \n \r \t \\ \" stay, any unit outside 0x20..0x7E is \uXXXX.
class TokenDump {
	static var out:StringBuf = new StringBuf();

	static function main() {
		var trivia = false;
		final files:Array<String> = [];
		for (arg in Sys.args()) {
			if (arg == "-trivia") {
				trivia = true;
			} else if (StringTools.startsWith(arg, "@")) {
				for (line in sys.io.File.getContent(arg.substring(1)).split("\n")) {
					final l = StringTools.trim(line);
					if (l != "")
						files.push(l);
				}
			} else {
				files.push(arg);
			}
		}
		final stdout = Sys.stdout();
		for (file in files) {
			final data = sys.io.File.getBytes(file);
			dump(file, Utf8.BytesToString(data, 0, data.length), trivia);
			if (out.length > (1 << 20)) {
				stdout.writeString(out.toString());
				out = new StringBuf();
			}
		}
		stdout.writeString(out.toString());
	}

	static function dump(file:String, text:String, trivia:Bool) {
		final o = out;
		o.add("## ");
		o.add(file);
		o.addChar("\n".code);
		final s = Scanner.NewScanner();
		s.SetSkipTrivia(!trivia);
		if (StringTools.endsWith(file, ".tsx") || StringTools.endsWith(file, ".jsx")) {
			s.SetLanguageVariant(LanguageVariantJSX);
		}
		s.SetScriptTarget(ScriptTargetLatest);
		s.SetOnError(function(message:Message, start:Int, length:Int, ...args:Any) {
			out.add("E " + message.Code() + " " + start + " " + length + "\n");
		});
		s.SetText(text);
		while (true) {
			final kind = s.Scan();
			final b = out;
			b.add(kind.String());
			b.addChar(" ".code);
			b.add(s.TokenFullStart());
			b.addChar(" ".code);
			b.add(s.TokenEnd());
			b.addChar(" ".code);
			b.add((s.TokenFlags() : Int));
			b.addChar(" ".code);
			escape(b, s.TokenValue());
			b.addChar("\n".code);
			if (kind == KindEndOfFile) {
				break;
			}
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
