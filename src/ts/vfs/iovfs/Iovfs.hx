package ts.vfs.iovfs;

import go.Errors.Error;
import go.Fs.FileMode;
import go.Time;
import go.Tuple;
import ts.tspath.Tspath;
import ts.vfs.internal.Internal;
import ts.vfs.iovfs.Iofs;

// Port of iofs.go: package-level funcs. The types are in Iofs.hx.
class Iovfs {
	// From creates a new FS from an [fs.FS].
	//
	// For paths like `c:/foo/bar`, fsys will be used as though it's rooted at `/` and the path is `/c:/foo/bar`.
	//
	// If the provided [fs.FS] implements [RealpathFS], it will be used to implement the Realpath method.
	// If the provided [fs.FS] implements [WritableFS], it will be used to implement the WriteFile method.
	//
	// From does not actually handle case-insensitivity; ensure the passed in [fs.FS]
	// respects case-insensitive file names if needed. Consider using [vfstest.FromMap] for testing.
	public static function From(fsys:go.Fs.FS, useCaseSensitiveFileNames:Bool):FsWithSys {
		var realpath:(path:String) -> ValueError<String>;
		if (Std.isOfType(fsys, RealpathFS)) {
			final fsys:RealpathFS = cast fsys;
			realpath = (path:String) -> {
				final hadSlash = StringTools.startsWith(path, "/");
				final rest = hadSlash ? path.substring(1) : path;
				final rp = fsys.Realpath(rest);
				if (rp.err != null) {
					return new ValueError<String>("", rp.err);
				}
				if (hadSlash) {
					return new ValueError<String>("/" + rp.value, null);
				}
				return new ValueError<String>(rp.value, null);
			};
		} else {
			realpath = (path:String) -> {
				return new ValueError<String>(path, null);
			};
		}

		var writeFile:(path:String, content:String) -> Null<Error>;
		var appendFile:(path:String, content:String) -> Null<Error>;
		var mkdirAll:(path:String) -> Null<Error>;
		var remove:(path:String) -> Null<Error>;
		var chtimes:(path:String, aTime:Time, mTime:Time) -> Null<Error>;
		if (Std.isOfType(fsys, WritableFS)) {
			final fsys:WritableFS = cast fsys;
			writeFile = (path:String, content:String) -> {
				final rest = StringTools.startsWith(path, "/") ? path.substring(1) : path;
				return fsys.WriteFile(rest, content, 438 /* 0o666 */);
			};
			appendFile = (path:String, content:String) -> {
				final rest = StringTools.startsWith(path, "/") ? path.substring(1) : path;
				return fsys.AppendFile(rest, content, 438 /* 0o666 */);
			};
			mkdirAll = (path:String) -> {
				final rest = StringTools.startsWith(path, "/") ? path.substring(1) : path;
				return fsys.MkdirAll(rest, 511 /* 0o777 */);
			};
			remove = (path:String) -> {
				final rest = StringTools.startsWith(path, "/") ? path.substring(1) : path;
				return fsys.Remove(rest);
			};
			chtimes = (path:String, aTime:Time, mTime:Time) -> {
				final rest = StringTools.startsWith(path, "/") ? path.substring(1) : path;
				return fsys.Chtimes(rest, aTime, mTime);
			};
		} else {
			writeFile = (_:String, _:String) -> {
				throw "writeFile not supported";
			};
			appendFile = (_:String, _:String) -> {
				throw "appendFile not supported";
			};
			mkdirAll = (_:String) -> {
				throw "mkdirAll not supported";
			};
			remove = (_:String) -> {
				throw "remove not supported";
			};
			chtimes = (_:String, _:Time, _:Time) -> {
				throw "chtimes not supported";
			};
		}

		return new IoFS(new Common((root:String) -> {
			if (root == "/") {
				return fsys;
			}

			final p = Tspath.RemoveTrailingDirectorySeparator(root);
			final sub = go.Fs.Fs.Sub(fsys, p);
			if (sub.err != null) {
				if (Tspath.IsUrl(root)) {
					return null;
				}
				throw 'vfs: failed to create sub file system for ${go.Strconv.Quote(p)}: ${sub.err.Error()}';
			}
			return sub.value;
		}), useCaseSensitiveFileNames, realpath, writeFile, appendFile, mkdirAll, remove, chtimes, fsys);
	}
}
