package ts.cmd;

// Port of cmd/tsgo/sys.go.
// Go type `osSys` (unexported).
class OsSys implements System {
	public var writer:Writer = null;
	public var fs:FS = null;
	public var defaultLibraryPath:std.String = "";
	public var cwd:std.String = "";
	public var start:Time = null;

	public function new() {}

	public function SinceStart():Duration {
		return Time.Since(this.start);
	}

	public function Now():Time {
		return Time.Now();
	}

	public function FS():FS {
		return this.fs;
	}

	public function DefaultLibraryPath():std.String {
		return this.defaultLibraryPath;
	}

	public function GetCurrentDirectory():std.String {
		return this.cwd;
	}

	public function Writer():Writer {
		return this.writer;
	}

	public function WriteOutputIsTTY():Bool {
		return Term.IsTerminal(1 /*os.Stdout.Fd()*/);
	}

	public function GetWidthOfTerminal():Int {
		final width = Term.GetWidth(1 /*os.Stdout.Fd()*/);
		return width;
	}

	public function GetEnvironmentVariable(name:std.String):std.String {
		return Os.Getenv(name);
	}
}

// PORT: os.Stdout as an io.Writer (UTF-8 bytes, unbuffered like Go's *os.File).
class StdoutWriter implements Writer {
	final out:haxe.io.Output;

	public function new() {
		this.out = std.Sys.stdout();
	}

	public function Write(p:std.String):ValueError<Int> {
		this.out.writeString(p);
		return new ValueError<Int>(p.length, null);
	}
}

class Sys_ {
	public static function newSystem():OsSys {
		final r = Os.Getwd();
		final cwd = r.value, err = r.err;
		if (err != null) {
			std.Sys.stderr().writeString("Error getting current directory: " + err.Error() + "\n");
			std.Sys.exit((ExitStatusInvalidProject_OutputsSkipped : Int));
		}

		final s = new OsSys();
		s.cwd = Tspath.NormalizePath(cwd);
		s.fs = Bundled.WrapFS(Osvfs.FS());
		s.defaultLibraryPath = Bundled.LibPath();
		s.writer = new StdoutWriter();
		s.start = Time.Now();
		return s;
	}
}
