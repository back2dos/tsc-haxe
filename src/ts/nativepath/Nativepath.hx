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

	// --- symlink_other.go ---

	public static function IsSymlinkOrReparsePoint(path:String):Bool {
		final info = go.Os.Lstat(path);
		return info.err == null && info.value.Mode() & ModeSymlink != 0;
	}
}
