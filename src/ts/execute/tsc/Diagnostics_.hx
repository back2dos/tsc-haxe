package ts.execute.tsc;

// Port of diagnostics.go (types; package-level funcs are in Tsc.hx).

// Go type `colors` (unexported).
class Colors {
	public var showColors:Bool = false;

	public var isWindows:Bool = false;
	public var isWindowsTerminal:Bool = false;
	public var isVSCode:Bool = false;
	public var supportsRicherColors:Bool = false;

	public function new() {}

	public function bold(str:std.String):std.String {
		if (!this.showColors) {
			return str;
		}
		return "\x1b[1m" + str + "\x1b[22m";
	}

	public function blue(str:std.String):std.String {
		if (!this.showColors) {
			return str;
		}

		// Effectively Powershell and Command prompt users use cyan instead
		// of blue because the default theme doesn't show blue with enough contrast.
		if (this.isWindows && !this.isWindowsTerminal && !this.isVSCode) {
			return this.brightWhite(str);
		}
		return "\x1b[94m" + str + "\x1b[39m";
	}

	public function blueBackground(str:std.String):std.String {
		if (!this.showColors) {
			return str;
		}
		if (this.supportsRicherColors) {
			return "\x1B[48;5;68m" + str + "\x1B[39;49m";
		} else {
			return "\x1b[44m" + str + "\x1B[39;49m";
		}
	}

	public function brightWhite(str:std.String):std.String {
		if (!this.showColors) {
			return str;
		}
		return "\x1b[97m" + str + "\x1b[39m";
	}
}

typedef DiagnosticReporter = (Diagnostic) -> Void;

typedef DiagnosticsReporter = (diagnostics:Null<Array<Diagnostic>>) -> Void;
