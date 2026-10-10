package ts.vfs.osvfs;

import ts.core.Core;
import ts.core.Semaphore;
import ts.tspath.Tspath;
import ts.vfs.Vfs;
import ts.vfs.internal.Internal;
import ts.vfs.osvfs.Os.OsFS;
import ts.vfs.osvfs.Os.LimitedWalkDirFunc;

// Port of osvfs (os.go): package-level funcs and vars. The types are in Os.hx.
class Osvfs {
	// --- os.go ---

	// Semaphore for operations that are effectively blocking syscalls.
	@:allow(ts.vfs.osvfs)
	static final blockingOpSema = Core.NewLimitedSemaphore(128);
	// Semaphore for file reads.
	@:allow(ts.vfs.osvfs)
	static final readSema = Core.NewLimitedSemaphore(128);
	// Semaphore for file writes.
	@:allow(ts.vfs.osvfs)
	static final writeSema = Core.NewLimitedSemaphore(32);

	// FS creates a new FS from the OS file system.
	public static function FS():ts.vfs.Vfs.FS {
		return osVFS;
	}

	static final osVFS:ts.vfs.Vfs.FS = new OsFS(new Common(go.Os.DirFS, isReparsePoint));

	// We do this right at startup to minimize the chance that executable gets moved or deleted.
	// PORT: computed on first use (Haxe static init order across classes is not defined).
	static var isFileSystemCaseSensitiveValue:Null<Bool> = null;

	@:allow(ts.vfs.osvfs)
	static function isFileSystemCaseSensitive():Bool {
		if (isFileSystemCaseSensitiveValue == null) {
			isFileSystemCaseSensitiveValue = computeIsFileSystemCaseSensitive();
		}
		return isFileSystemCaseSensitiveValue;
	}

	static function computeIsFileSystemCaseSensitive():Bool {
		// win32/win64 are case insensitive platforms
		if (Sys.systemName() == "Windows") {
			return false;
		}

		// PORT: runtime.GOARCH == "wasm" has no Haxe equivalent.

		// As a proxy for case-insensitivity, we check if the current executable exists under a different case.
		// This is not entirely correct, since different OSs can have differing case sensitivity in different paths,
		// but this is largely good enough for our purposes (and what sys.ts used to do with __filename).
		final exe = go.Os.Executable();
		if (exe.err != null) {
			throw 'vfs: failed to get executable path: ${exe.err.Error()}';
		}

		// If the current executable exists under a different case, we must be case-insensitive.
		final swapped = swapCase(exe.value);
		final st = go.Os.Stat(swapped);
		if (st.err != null) {
			if (go.Os.IsNotExist(st.err)) {
				return true;
			}
			throw 'vfs: failed to stat ${go.Strconv.Quote(swapped)}: ${st.err.Error()}';
		}
		return false;
	}

	// Convert all lowercase chars to uppercase, and vice-versa
	static function swapCase(str:String):String {
		return go.Strings.Map((r:Int) -> {
			final upper = go.Unicode.ToUpper(r);
			if (upper == r) {
				return go.Unicode.ToLower(r);
			} else {
				return upper;
			}
		}, str);
	}

	@:allow(ts.vfs.osvfs)
	static function getLimitedWalkDirFunc(walkFn:WalkDirFunc):LimitedWalkDirFunc {
		// PORT: sync.Pool → a new object per call.
		final w = new LimitedWalkDirFunc();
		w.walk = w.walker;
		w.inner = walkFn;
		return w;
	}

	@:allow(ts.vfs.osvfs)
	static function putLimitedWalkDirFunc(w:LimitedWalkDirFunc):Void {
		w.inner = null;
	}

	@:allow(ts.vfs.osvfs)
	static function osFSRealpath(path:String):String {
		Internal.RootLength(path); // Assert path is rooted

		final orig = path;
		path = go.Filepath.FromSlash(path);
		final rp = ts.nativepath.Nativepath.Realpath(path);
		if (rp.err != null) {
			return orig;
		}
		final abs = go.Filepath.Abs(rp.value);
		if (abs.err != null) {
			return orig;
		}
		return Tspath.NormalizeSlashes(abs.value);
	}

	static function isReparsePoint(path:String):Bool {
		return ts.nativepath.Nativepath.IsSymlinkOrReparsePoint(go.Filepath.FromSlash(path));
	}

	public static function GetGlobalTypingsCacheLocation():String {
		final r = go.Os.UserCacheDir();
		var cacheDir = r.value;
		if (r.err != null) {
			cacheDir = go.Os.TempDir();
		}

		var subdir:String;
		if (Sys.systemName() == "Windows") {
			subdir = "Microsoft/TypeScript";
		} else {
			subdir = "typescript";
		}
		return Tspath.CombinePaths(cacheDir, subdir, Core.VersionMajorMinor());
	}
}
