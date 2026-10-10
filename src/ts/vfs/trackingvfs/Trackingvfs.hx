package ts.vfs.trackingvfs;

import go.Errors.Error;
import go.Time;
import go.Tuple.ValueOk;
import ts.collections.Syncset;
import ts.vfs.Vfs;

// Port of trackingvfs.go.
// Package trackingvfs provides a VFS wrapper that records every file path
// accessed during compilation. This allows watch mode to know exactly which
// files and directories the compiler depended on, including non-existent
// paths from failed module resolution.

// FS wraps a vfs.FS and records every path accessed via read-like operations.
// Write operations (WriteFile, Remove, Chtimes) are not tracked since they
// represent outputs, not dependencies.
class FS implements ts.vfs.Vfs.FS {
	public var Inner:Null<ts.vfs.Vfs.FS> = null;
	public var SeenFiles:SyncSet<String> = new SyncSet<String>();

	public function new(?inner:ts.vfs.Vfs.FS) {
		this.Inner = inner;
	}

	public function ReadFile(path:String):ValueOk<String> {
		this.SeenFiles.Add(path);
		return this.Inner.ReadFile(path);
	}

	public function FileExists(path:String):Bool {
		this.SeenFiles.Add(path);
		return this.Inner.FileExists(path);
	}

	public function UseCaseSensitiveFileNames():Bool {
		return this.Inner.UseCaseSensitiveFileNames();
	}

	public function WriteFile(path:String, data:String):Null<Error> {
		return this.Inner.WriteFile(path, data);
	}

	public function AppendFile(path:String, data:String):Null<Error> {
		return this.Inner.AppendFile(path, data);
	}

	public function Remove(path:String):Null<Error> {
		return this.Inner.Remove(path);
	}

	public function Chtimes(path:String, aTime:Time, mTime:Time):Null<Error> {
		return this.Inner.Chtimes(path, aTime, mTime);
	}

	public function DirectoryExists(path:String):Bool {
		this.SeenFiles.Add(path);
		return this.Inner.DirectoryExists(path);
	}

	public function GetAccessibleEntries(path:String):Entries {
		this.SeenFiles.Add(path);
		return this.Inner.GetAccessibleEntries(path);
	}

	public function Stat(path:String):Null<FileInfo> {
		this.SeenFiles.Add(path);
		return this.Inner.Stat(path);
	}

	public function WalkDir(root:String, walkFn:WalkDirFunc):Null<Error> {
		this.SeenFiles.Add(root);
		return this.Inner.WalkDir(root, (path:String, d:Null<DirEntry>, err:Null<Error>) -> {
			this.SeenFiles.Add(path);
			return walkFn(path, d, err);
		});
	}

	public function Realpath(path:String):String {
		this.SeenFiles.Add(path);
		return this.Inner.Realpath(path);
	}
}
