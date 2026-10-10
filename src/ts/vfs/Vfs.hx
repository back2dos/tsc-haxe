package ts.vfs;

import go.Errors.Error;
import go.Time;
import go.Tuple.ValueOk;
import haxe.ds.StringMap;

// Port of vfs.go.

// FS is a file system abstraction.
interface FS {
	// UseCaseSensitiveFileNames returns true if the file system is case-sensitive.
	function UseCaseSensitiveFileNames():Bool;

	// FileExists returns true if the file exists.
	function FileExists(path:String):Bool;

	// ReadFile reads the file specified by path and returns the content.
	// If the file fails to be read, ok will be false.
	function ReadFile(path:String):ValueOk<String>;

	function WriteFile(path:String, data:String):Null<Error>;

	// AppendFile appends data to the file at path, creating it if it does not exist.
	function AppendFile(path:String, data:String):Null<Error>;

	// Removes `path` and all its contents. Will return the first error it encounters.
	function Remove(path:String):Null<Error>;

	// Chtimes changes the access and modification times of the named
	function Chtimes(path:String, aTime:Time, mTime:Time):Null<Error>;

	// DirectoryExists returns true if the path is a directory.
	function DirectoryExists(path:String):Bool;

	// GetAccessibleEntries returns the files/directories in the specified directory.
	// If any entry is a symlink, it will be followed.
	function GetAccessibleEntries(path:String):Entries;

	function Stat(path:String):Null<FileInfo>;

	// WalkDir walks the file tree rooted at root, calling walkFn for each file or directory in the tree.
	// It is has the same behavior as [fs.WalkDir], but with paths as [string].
	function WalkDir(root:String, walkFn:WalkDirFunc):Null<Error>;

	// Realpath returns the "real path" of the specified path,
	// following symlinks and correcting filename casing.
	function Realpath(path:String):String;
}

// PORT: Go `Entries` is a struct returned by value; it is never mutated after it is built,
// so no copy() is needed. `Symlinks map[string]struct{}` → StringMap<Bool> (null = Go nil).
class Entries {
	public var Files:Null<Array<String>> = null;
	public var Directories:Null<Array<String>> = null;
	// Symlinks contains the names of entries in Files or Directories that were
	// originally symbolic links (or reparse points) on disk. The names are the
	// same as those in Files/Directories (i.e., the link name, not the target).
	// nil means symlink information is not available and the entries may need
	// to be re-checked for symlinks.
	public var Symlinks:Null<StringMap<Bool>> = null;

	public function new() {}
}

// DirEntry is [fs.DirEntry].
typedef DirEntry = go.Fs.DirEntry;

// FileInfo is [fs.FileInfo].
typedef FileInfo = go.Fs.FileInfo;

// WalkDirFunc is [fs.WalkDirFunc].
typedef WalkDirFunc = go.Fs.WalkDirFunc;

// PORT: the Go vars alias io/fs values; Haxe getters avoid cross-class static init order.
class Vfs {
	public static var ErrInvalid(get, never):Error; // "invalid argument"

	static inline function get_ErrInvalid():Error {
		return go.Fs.Fs.ErrInvalid;
	}

	public static var ErrPermission(get, never):Error; // "permission denied"

	static inline function get_ErrPermission():Error {
		return go.Fs.Fs.ErrPermission;
	}

	public static var ErrExist(get, never):Error; // "file already exists"

	static inline function get_ErrExist():Error {
		return go.Fs.Fs.ErrExist;
	}

	public static var ErrNotExist(get, never):Error; // "file does not exist"

	static inline function get_ErrNotExist():Error {
		return go.Fs.Fs.ErrNotExist;
	}

	public static var ErrClosed(get, never):Error; // "file already closed"

	static inline function get_ErrClosed():Error {
		return go.Fs.Fs.ErrClosed;
	}

	// SkipAll is [fs.SkipAll].
	public static var SkipAll(get, never):Error;

	static inline function get_SkipAll():Error {
		return go.Fs.Fs.SkipAll;
	}

	// SkipDir is [fs.SkipDir].
	public static var SkipDir(get, never):Error;

	static inline function get_SkipDir():Error {
		return go.Fs.Fs.SkipDir;
	}
}
