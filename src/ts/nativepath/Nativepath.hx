package ts.nativepath;

import go.Fs;
import go.Tuple.ValueError;

// Port of internal/nativepath for non-Windows systems.
// PORT: realpath_linux.go (open O_PATH + readlink /proc/self/fd) and realpath_darwin.go
// (fcntl F_GETPATH) are raw-syscall fast paths. The port uses realpath_other.go
// (filepath.EvalSymlinks; the go.Filepath shim calls the OS realpath). symlink_windows.go,
// realpath_windows.go and eintr_unix.go are not ported (no Windows / raw syscalls).
class Nativepath {
	// --- realpath_other.go ---

	public static function Realpath(path:String):ValueError<String> {
		return go.Filepath.EvalSymlinks(path);
	}

	// --- network.go ---

	// IsNetworkPath reports whether Windows may resolve path over the network.
	// This includes UNC paths (`//server/share`), Win32 device paths (`//?/...`,
	// `//./...`), and NT object paths (`/??/...`), with either separator. Device
	// and object paths are included even when they name local volumes, because
	// their `UNC` and `GLOBALROOT` forms reach the network redirector.
	//
	// Accessing such a path can make Windows authenticate to an arbitrary host,
	// leaking credentials, so these paths are never accessed on any platform.
	public static function IsNetworkPath(path:String):Bool {
		if (path.length < 2 || !isAnyDirectorySeparator(StringTools.fastCodeAt(path, 0))) {
			return false;
		}
		if (isAnyDirectorySeparator(StringTools.fastCodeAt(path, 1))) {
			return true;
		}
		return path.length >= 3 && StringTools.fastCodeAt(path, 1) == '?'.code && StringTools.fastCodeAt(path, 2) == '?'.code
			&& (path.length == 3 || isAnyDirectorySeparator(StringTools.fastCodeAt(path, 3)));
	}

	static function isAnyDirectorySeparator(char:Int):Bool {
		return char == '/'.code || char == '\\'.code;
	}

	// --- symlink_other.go ---

	public static function IsSymlinkOrReparsePoint(path:String):Bool {
		final info = go.Os.Lstat(path);
		return info.err == null && info.value.Mode() & ModeSymlink != 0;
	}
}
