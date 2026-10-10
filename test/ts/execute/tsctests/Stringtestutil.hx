package ts.execute.tsctests;

import ts.stringutil.Stringutil;

// Port of internal/testutil/stringtestutil/stringtestutil.go.
// PORT: lives next to its only user (tsctests) instead of test/ts/testutil/stringtestutil.
class Stringtestutil {
	public static function Dedent(text:String):String {
		var lines = go.Strings.Split(text, "\n");
		// Remove blank lines in the beginning and end
		// and convert all tabs in the beginning of line to spaces
		var startLine = -1;
		var lastLine = 0;
		for (i in 0...lines.length) {
			var line = lines[i];
			// strings.IndexFunc(line, !IsWhiteSpaceLike)
			var firstNonWhite = -1;
			var k = 0;
			while (k < line.length) {
				final r = go.Utf16.CodePointAt(line, k);
				if (!Stringutil.IsWhiteSpaceLike(r)) {
					firstNonWhite = k;
					break;
				}
				k += go.Utf16.RuneLen(r);
			}
			if (firstNonWhite > 0) {
				line = go.Strings.ReplaceAll(line.substring(0, firstNonWhite), "\t", "    ") + line.substring(firstNonWhite);
				lines[i] = line;
			}
			line = go.Strings.TrimSpace(line);
			if (line != "") {
				if (startLine == -1) {
					startLine = i;
				}
				lastLine = i;
			}
		}
		// PORT: Go panics on lines[-1:...] when every line is blank; same here.
		if (startLine == -1)
			throw "slice bounds out of range [-1:]";
		lines = lines.slice(startLine, lastLine + 1);
		final mappedLines = [for (_ in 0...lines.length) ""];
		for (i in 0...lines.length) {
			final line = lines[i];
			if (go.Strings.TrimSpace(line) == "") {
				mappedLines[i] = "";
			} else {
				mappedLines[i] = line;
			}
		}
		final indentation = Stringutil.GuessIndentation(mappedLines);
		if (indentation > 0) {
			for (i in 0...lines.length) {
				if (lines[i].length > indentation) {
					lines[i] = lines[i].substring(indentation);
				} else {
					lines[i] = "";
				}
			}
		}
		return lines.join("\n");
	}
}
