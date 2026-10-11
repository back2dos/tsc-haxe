package go;

// Shim for golang.org/x/term (IsTerminal, GetSize) — used by cmd/tsgo sys.go.
// PORT: only the file descriptors 0-2 are supported (the callers pass os.Stdout.Fd()).
#if cpp
@:cppFileCode("#include <unistd.h>\n#include <sys/ioctl.h>")
#end
class Term {
	// term.IsTerminal(fd)
	public static function IsTerminal(fd:Int):Bool {
		#if js
		final stream:Dynamic = fd == 2 ? js.Syntax.code("process.stderr") : fd == 0 ? js.Syntax.code("process.stdin") : js.Syntax.code("process.stdout");
		return stream.isTTY == true;
		#elseif cpp
		return untyped __cpp__("::isatty({0}) != 0", fd);
		#elseif jvm
		// PORT: jvm — JDK 21 has no isatty: System.console() is non-null when stdin and stdout
		// are both terminals (an approximation of isatty(fd) for fd 0-2).
		return fd >= 0 && fd <= 2 && java.lang.System.console() != null;
		#else
		return false;
		#end
	}

	// term.GetSize(fd) → width (Go returns (width, height, err); the callers use the width only,
	// and Go returns 0 on error).
	public static function GetWidth(fd:Int):Int {
		#if js
		final stream:Dynamic = fd == 2 ? js.Syntax.code("process.stderr") : js.Syntax.code("process.stdout");
		if (stream.isTTY != true || stream.columns == null)
			return 0;
		return stream.columns;
		#elseif cpp
		return untyped __cpp__("([&]{ struct winsize ws; if (::ioctl({0}, TIOCGWINSZ, &ws) != 0) return 0; return (int)ws.ws_col; })()", fd);
		#else
		return 0;
		#end
	}
}
