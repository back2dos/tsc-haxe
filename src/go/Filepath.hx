package go;

import go.Errors.Error;
import go.Fs.PathError;
import go.Os.Errno;
import go.Tuple.ValueError;

// Shim for Go package path/filepath.
// PORT: Unix semantics only (separator '/'), like Go on Linux and macOS: FromSlash/ToSlash
// are the identity, Clean/Join/Dir/Base are package path's.
class Filepath {
	public static inline final Separator = '/'.code;

	// filepath.FromSlash
	public static function FromSlash(path:String):String {
		return path;
	}

	// filepath.ToSlash
	public static function ToSlash(path:String):String {
		return path;
	}

	// filepath.Clean
	public static inline function Clean(path:String):String {
		return Path.Clean(path);
	}

	// filepath.Join
	public static function Join(elem:Array<String>):String {
		return Path.Join(elem);
	}

	// filepath.Dir
	public static inline function Dir(path:String):String {
		return Path.Dir(path);
	}

	// filepath.Base
	public static inline function Base(path:String):String {
		return Path.Base(path);
	}

	// filepath.IsAbs
	public static inline function IsAbs(path:String):Bool {
		return Path.IsAbs(path);
	}

	// filepath.Abs
	public static function Abs(path:String):ValueError<String> {
		if (IsAbs(path)) {
			return new ValueError<String>(Clean(path), null);
		}
		final wd = Os.Getwd();
		if (wd.err != null) {
			return new ValueError<String>("", wd.err);
		}
		return new ValueError<String>(Join([wd.value, path]), null);
	}

	// filepath.EvalSymlinks
	// PORT: Go resolves one path element at a time with Lstat/Readlink; the shim calls the
	// OS realpath (realpath(3) / fs.realpathSync.native), which gives the same result for an
	// existing absolute path. A relative path is made absolute first.
	public static function EvalSymlinks(path:String):ValueError<String> {
		final r = OsNative.realpath(path);
		if (r == null) {
			return new ValueError<String>("", new PathError("lstat", path, Errno.of(OsNative.realpathErr)));
		}
		return new ValueError<String>(r, null);
	}
}

private typedef OsNative = go.Os.OsNative;
