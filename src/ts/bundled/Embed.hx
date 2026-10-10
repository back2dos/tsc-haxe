package ts.bundled;

import go.Errors.Error;
import go.Fs.FileMode;
import go.Time;
import go.Tuple;
import ts.vfs.Vfs;

// Port of embed.go (types). Package-level funcs and vars are in Bundled.hx.

// wrappedFS is implemented directly rather than going through [io/fs.FS].
// Our vfs.FS works with file contents in terms of strings, and that's
// what go:embed does under the hood, but going through fs.FS will cause
// copying to []byte and back.
class WrappedFS implements FS {
	final fs:FS;

	public function new(fs:FS) {
		this.fs = fs;
	}

	public function UseCaseSensitiveFileNames():Bool {
		return this.fs.UseCaseSensitiveFileNames();
	}

	public function FileExists(path:String):Bool {
		final r = Bundled.splitPath(path);
		if (r.ok) {
			return Bundled.embeddedContents.exists(r.value);
		}
		return this.fs.FileExists(path);
	}

	public function ReadFile(path:String):ValueOk<String> {
		final r = Bundled.splitPath(path);
		if (r.ok) {
			final contents = Bundled.embeddedContents.get(r.value);
			return new ValueOk(contents == null ? "" : contents, contents != null);
		}
		return this.fs.ReadFile(path);
	}

	public function DirectoryExists(path:String):Bool {
		final r = Bundled.splitPath(path);
		if (r.ok) {
			return r.value == "libs";
		}
		return this.fs.DirectoryExists(path);
	}

	public function GetAccessibleEntries(path:String):Entries {
		final r = Bundled.splitPath(path);
		if (r.ok) {
			final result = new Entries();
			final rest = r.value;
			if (rest == "") {
				result.Directories = ["libs"];
			} else if (rest == "libs") {
				result.Files = Bundled.LibNames;
			}
			return result;
		}
		return this.fs.GetAccessibleEntries(path);
	}

	public function Stat(path:String):Null<go.Fs.FileInfo> {
		final r = Bundled.splitPath(path);
		if (r.ok) {
			final rest = r.value;
			if (rest == "" || rest == "libs") {
				return new ts.bundled.Embed.FileInfo(ModeDir, rest, 0);
			}
			final lib = Bundled.embeddedContents.get(rest);
			if (lib != null) {
				final libName = StringTools.startsWith(rest, "libs/") ? rest.substring(5) : rest;
				return new ts.bundled.Embed.FileInfo(ModeNone, libName, go.Utf8.ByteLen(lib));
			}
			return null;
		}
		return this.fs.Stat(path);
	}

	public function WalkDir(root:String, walkFn:WalkDirFunc):Null<Error> {
		final r = Bundled.splitPath(root);
		if (r.ok) {
			final err = this.walkDir(r.value, walkFn);
			if (err != null) {
				if (err == go.Fs.Fs.SkipAll) {
					return null;
				}
				return err;
			}
			return null;
		}
		return this.fs.WalkDir(root, walkFn);
	}

	function walkDir(rest:String, walkFn:WalkDirFunc):Null<Error> {
		var entries:Array<go.Fs.DirEntry>;
		switch (rest) {
			case "":
				entries = Bundled.rootEntries;
			case "libs":
				entries = Bundled.libsEntries;
			default:
				return null;
		}

		for (entry in entries) {
			final name = rest + "/" + entry.Name();

			final err = walkFn(Bundled.scheme + name, entry, null);
			if (err != null) {
				if (err == go.Fs.Fs.SkipAll) {
					return go.Fs.Fs.SkipAll;
				}
				if (err == go.Fs.Fs.SkipDir) {
					continue;
				}
				return err;
			}
			if (entry.IsDir()) {
				final err = this.walkDir(StringTools.startsWith(name, "/") ? name.substring(1) : name, walkFn);
				if (err != null) {
					return err;
				}
			}
		}

		return null;
	}

	public function Realpath(path:String):String {
		if (Bundled.splitPath(path).ok) {
			return path;
		}
		return this.fs.Realpath(path);
	}

	public function WriteFile(path:String, data:String):Null<Error> {
		if (Bundled.splitPath(path).ok) {
			throw "cannot write to embedded file system";
		}
		return this.fs.WriteFile(path, data);
	}

	public function AppendFile(path:String, data:String):Null<Error> {
		if (Bundled.splitPath(path).ok) {
			throw "cannot write to embedded file system";
		}
		return this.fs.AppendFile(path, data);
	}

	public function Remove(path:String):Null<Error> {
		if (Bundled.splitPath(path).ok) {
			throw "cannot remove from embedded file system";
		}
		return this.fs.Remove(path);
	}

	public function Chtimes(path:String, aTime:Time, mTime:Time):Null<Error> {
		if (Bundled.splitPath(path).ok) {
			throw "cannot change times on embedded file system";
		}
		return this.fs.Chtimes(path, aTime, mTime);
	}
}

// Go `fileInfo` (implements fs.FileInfo and fs.DirEntry).
// PORT: size is Int (Go int64).
class FileInfo implements go.Fs.FileInfo implements go.Fs.DirEntry {
	final mode:FileMode;
	final name:String;
	final size:Int;

	public function new(mode:FileMode, name:String, size:Int) {
		this.mode = mode;
		this.name = name;
		this.size = size;
	}

	public function IsDir():Bool {
		return this.mode.IsDir();
	}

	public function ModTime():Time {
		return Time.Zero();
	}

	public function Mode():FileMode {
		return this.mode;
	}

	public function Name():String {
		return this.name;
	}

	public function Size():Int {
		return this.size;
	}

	public function Sys():Any {
		return null;
	}

	public function Info():ValueError<go.Fs.FileInfo> {
		return new ValueError<go.Fs.FileInfo>(this, null);
	}

	public function Type():FileMode {
		return this.mode.Type();
	}
}
