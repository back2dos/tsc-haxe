package go;

// Shims for Go package fmt.
class Fmt {
	// fmt.Sprint: adds a space between operands when neither side is a string.
	public static function Sprint(args:Array<Any>):String {
		final b = new StringBuf();
		for (i in 0...args.length) {
			if (i > 0 && !(args[i] is String) && !(args[i - 1] is String))
				b.add(" ");
			b.add(Sprintv(args[i]));
		}
		return b.toString();
	}

	// fmt.Sprintf("%v", x)
	public static function Sprintv(x:Any):String {
		if (x == null)
			return "<nil>";
		return Std.string(x);
	}

	// fmt.Fprint: Sprint(args) written to w.
	public static function Fprint(w:Io.Writer, args:Array<Any>):Void {
		w.Write(Sprint(args));
	}

	// fmt.Fprintf: Sprintf(format, args) written to w.
	public static function Fprintf(w:Io.Writer, format:String, args:Array<Any>):Void {
		w.Write(Sprintf(format, args));
	}

	// fmt.Sprintf. PORT: subset — verbs %s %d %v and %%, flag '-', width as digits or '*'.
	// Anything else throws.
	public static function Sprintf(format:String, args:Array<Any>):String {
		final b = new StringBuf();
		var argi = 0;
		var i = 0;
		final n = format.length;
		while (i < n) {
			final c = StringTools.fastCodeAt(format, i);
			if (c != "%".code) {
				final j = format.indexOf("%", i);
				final end = j < 0 ? n : j;
				b.add(format.substring(i, end));
				i = end;
				continue;
			}
			i++;
			if (i >= n)
				throw "Fmt.Sprintf: trailing %";
			var minus = false;
			while (i < n && StringTools.fastCodeAt(format, i) == "-".code) {
				minus = true;
				i++;
			}
			var width = -1;
			if (i < n && StringTools.fastCodeAt(format, i) == "*".code) {
				width = args[argi++];
				if (width < 0) {
					minus = true;
					width = -width;
				}
				i++;
			} else {
				while (i < n && StringTools.fastCodeAt(format, i) >= "0".code && StringTools.fastCodeAt(format, i) <= "9".code) {
					width = (width < 0 ? 0 : width * 10) + (StringTools.fastCodeAt(format, i) - "0".code);
					i++;
				}
			}
			if (i >= n)
				throw "Fmt.Sprintf: missing verb";
			final verb = StringTools.fastCodeAt(format, i);
			i++;
			var s:String;
			switch (verb) {
				case "%".code:
					b.add("%");
					continue;
				case "s".code, "v".code:
					s = Sprintv(args[argi++]);
				case "d".code:
					final v:Int = args[argi++];
					s = Std.string(v);
				default:
					throw "Fmt.Sprintf: unsupported verb %" + String.fromCharCode(verb);
			}
			// Go pads to the width in runes.
			var runes = 0;
			var k = 0;
			while (k < s.length) {
				k += Utf16.RuneLen(Utf16.CodePointAt(s, k));
				runes++;
			}
			if (width > runes && !minus)
				b.add(StringTools.lpad("", " ", width - runes));
			b.add(s);
			if (width > runes && minus)
				b.add(StringTools.lpad("", " ", width - runes));
		}
		return b.toString();
	}
}
