package ts.sourcemap;

// --- lineinfo.go --- (types and methods; CreateECMALineInfo is in Sourcemap.hx)

@:allow(ts.sourcemap)
class ECMALineInfo {
	var text:String = "";
	var lineStarts:ECMALineStarts = null;

	public function new() {}

	public function LineCount():Int {
		return Core.len(lineStarts);
	}

	public function LineText(line:Int):String {
		final pos:Int = lineStarts[line];
		var end:TextPos = 0;
		if (line + 1 < lineStarts.length) {
			end = lineStarts[line + 1];
		} else {
			end = text.length;
		}
		return text.substring(pos, end);
	}
}
