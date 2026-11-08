package ts.vfs.iovfs;

import ts.tspath.RootedPath;
import go.Errors.Error;
import go.Fs.FileMode;
import go.Time;
import go.Tuple;
import ts.tspath.Tspath;
import ts.vfs.Vfs;
import ts.vfs.internal.Internal;

// Port of iofs.go (types). From is in Iovfs.hx.

interface RealpathFS extends go.Fs.FS {
	function Realpath(path:String):ValueError<String>;
}

interface WritableFS extends go.Fs.FS {
	function WriteFile(path:String, data:String, perm:FileMode):Null<Error>;
	function AppendFile(path:String, data:String, perm:FileMode):Null<Error>;
	function MkdirAll(path:String, perm:FileMode):Null<Error>;
	// Removes `path` and all its contents. Will return the first error it encounters.
	function Remove(path:String):Null<Error>;
	function Chtimes(path:String, aTime:Time, mTime:Time):Null<Error>;
}

interface FsWithSys extends ts.vfs.Vfs.FS {
	function FSys():go.Fs.FS;
}

class IoFS implements FsWithSys {
	final common:Common;

	final useCaseSensitiveFileNames:Bool;
	final realpath:(path:String) -> ValueError<String>;
	final writeFile:(path:String, content:String) -> Null<Error>;
	final appendFile:(path:String, content:String) -> Null<Error>;
	final mkdirAll:(path:String) -> Null<Error>;
	final remove:(path:String) -> Null<Error>;
	final chtimes:(path:String, aTime:Time, mTime:Time) -> Null<Error>;
	final fsys:go.Fs.FS;

	public function new(common:Common, useCaseSensitiveFileNames:Bool, realpath:(path:String) -> ValueError<String>,
			writeFile:(path:String, content:String) -> Null<Error>, appendFile:(path:String, content:String) -> Null<Error>,
			mkdirAll:(path:String) -> Null<Error>, remove:(path:String) -> Null<Error>, chtimes:(path:String, aTime:Time, mTime:Time) -> Null<Error>,
			fsys:go.Fs.FS) {
		this.common = common;
		this.useCaseSensitiveFileNames = useCaseSensitiveFileNames;
		this.realpath = realpath;
		this.writeFile = writeFile;
		this.appendFile = appendFile;
		this.mkdirAll = mkdirAll;
		this.remove = remove;
		this.chtimes = chtimes;
		this.fsys = fsys;
	}

	public function UseCaseSensitiveFileNames():Bool {
		return this.useCaseSensitiveFileNames;
	}

	public function DirectoryExists(path:RootedDirectoryPath):Bool {
		return this.common.DirectoryExists(path);
	}

	public function FileExists(path:RootedFilePath):Bool {
		return this.common.FileExists(path);
	}

	public function GetAccessibleEntries(path:RootedDirectoryPath):Entries {
		return this.common.GetAccessibleEntries(path);
	}

	public function Stat(path:RootedPath):Null<FileInfo> {
		return this.common.Stat(path);
	}

	public function ReadFile(path:RootedFilePath):ValueOk<String> {
		return this.common.ReadFile(path);
	}

	public function WalkDir(root:String, walkFn:WalkDirFunc):Null<Error> {
		return this.common.WalkDir(root, walkFn);
	}

	public function Remove(path:RootedPath):Null<Error> {
		return this.remove(path.AsString());
	}

	public function Chtimes(path:RootedPath, aTime:Time, mTime:Time):Null<Error> {
		return this.chtimes(path.AsString(), aTime, mTime);
	}

	public function Realpath(path:RootedPath):RootedPath {
		final split = path.RootAndRelativePath();
		final realpath = this.realpath(split.a.AsString() + split.b);
		if (realpath.err != null) {
			return path;
		}
		return Tspath.RootedPathFromAbsolute(realpath.value);
	}

	function writeFileEnsuringDir(path:RootedFilePath, content:String, write:(path:String, content:String) -> Null<Error>):Null<Error> {
		final pathString = path.AsString();
		if (write(pathString, content) == null) {
			return null;
		}
		final err = this.mkdirAll(path.Directory().AsString());
		if (err != null) {
			return err;
		}
		return write(pathString, content);
	}

	public function WriteFile(path:RootedFilePath, content:String):Null<Error> {
		return this.writeFileEnsuringDir(path, content, this.writeFile);
	}

	public function AppendFile(path:RootedFilePath, content:String):Null<Error> {
		return this.writeFileEnsuringDir(path, content, this.appendFile);
	}

	public function FSys():go.Fs.FS {
		return this.fsys;
	}
}
