package ts.vfs.wrapvfs;

import go.Errors.Error;
import go.Time;
import go.Tuple.ValueOk;
import ts.vfs.Vfs;

// Port of wrapvfs.go.
class Replacements {
	public var UseCaseSensitiveFileNames:Null<() -> Bool> = null;
	public var FileExists:Null<(String) -> Bool> = null;
	public var ReadFile:Null<(String) -> ValueOk<String>> = null;
	public var WriteFile:Null<(String, String) -> Null<Error>> = null;
	public var AppendFile:Null<(String, String) -> Null<Error>> = null;
	public var Remove:Null<(String) -> Null<Error>> = null;
	public var Chtimes:Null<(String, Time, Time) -> Null<Error>> = null;
	public var DirectoryExists:Null<(String) -> Bool> = null;
	public var GetAccessibleEntries:Null<(String) -> Entries> = null;
	public var Stat:Null<(String) -> Null<FileInfo>> = null;
	public var WalkDir:Null<(String, WalkDirFunc) -> Null<Error>> = null;
	public var Realpath:Null<(String) -> String> = null;

	public function new() {}
}

class Wrapvfs {
	public static function Wrap(fs:FS, replacements:Replacements):FS {
		return new WrappedFS(fs, replacements);
	}
}

class WrappedFS implements FS {
	final fs:FS;
	final replacements:Replacements;

	public function new(fs:FS, replacements:Replacements) {
		this.fs = fs;
		this.replacements = replacements;
	}

	// UseCaseSensitiveFileNames implements [vfs.FS].
	public function UseCaseSensitiveFileNames():Bool {
		if (this.replacements.UseCaseSensitiveFileNames != null) {
			return this.replacements.UseCaseSensitiveFileNames();
		}
		return this.fs.UseCaseSensitiveFileNames();
	}

	// FileExists implements [vfs.FS].
	public function FileExists(path:String):Bool {
		if (this.replacements.FileExists != null) {
			return this.replacements.FileExists(path);
		}
		return this.fs.FileExists(path);
	}

	// ReadFile implements [vfs.FS].
	public function ReadFile(path:String):ValueOk<String> {
		if (this.replacements.ReadFile != null) {
			return this.replacements.ReadFile(path);
		}
		return this.fs.ReadFile(path);
	}

	// WriteFile implements [vfs.FS].
	public function WriteFile(path:String, data:String):Null<Error> {
		if (this.replacements.WriteFile != null) {
			return this.replacements.WriteFile(path, data);
		}
		return this.fs.WriteFile(path, data);
	}

	// AppendFile implements [vfs.FS].
	public function AppendFile(path:String, data:String):Null<Error> {
		if (this.replacements.AppendFile != null) {
			return this.replacements.AppendFile(path, data);
		}
		return this.fs.AppendFile(path, data);
	}

	// Remove implements [vfs.FS].
	public function Remove(path:String):Null<Error> {
		if (this.replacements.Remove != null) {
			return this.replacements.Remove(path);
		}
		return this.fs.Remove(path);
	}

	// Chtimes implements [vfs.FS].
	public function Chtimes(path:String, aTime:Time, mTime:Time):Null<Error> {
		if (this.replacements.Chtimes != null) {
			return this.replacements.Chtimes(path, aTime, mTime);
		}
		return this.fs.Chtimes(path, aTime, mTime);
	}

	// DirectoryExists implements [vfs.FS].
	public function DirectoryExists(path:String):Bool {
		if (this.replacements.DirectoryExists != null) {
			return this.replacements.DirectoryExists(path);
		}
		return this.fs.DirectoryExists(path);
	}

	// GetAccessibleEntries implements [vfs.FS].
	public function GetAccessibleEntries(path:String):Entries {
		if (this.replacements.GetAccessibleEntries != null) {
			return this.replacements.GetAccessibleEntries(path);
		}
		return this.fs.GetAccessibleEntries(path);
	}

	// Stat implements [vfs.FS].
	public function Stat(path:String):Null<FileInfo> {
		if (this.replacements.Stat != null) {
			return this.replacements.Stat(path);
		}
		return this.fs.Stat(path);
	}

	// WalkDir implements [vfs.FS].
	public function WalkDir(root:String, walkFn:WalkDirFunc):Null<Error> {
		if (this.replacements.WalkDir != null) {
			return this.replacements.WalkDir(root, walkFn);
		}
		return this.fs.WalkDir(root, walkFn);
	}

	// Realpath implements [vfs.FS].
	public function Realpath(path:String):String {
		if (this.replacements.Realpath != null) {
			return this.replacements.Realpath(path);
		}
		return this.fs.Realpath(path);
	}

}
