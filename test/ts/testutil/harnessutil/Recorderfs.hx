package ts.testutil.harnessutil;

import ts.tspath.RootedPath;
import go.Time;

// Port of recorderfs.go (type OutputRecorderFS; NewOutputRecorderFS is in Harnessutil.hx).
// PORT: Go embeds vfs.FS; the methods are forwarded. outputsMut dropped (single-threaded).
class OutputRecorderFS implements FS {
	public var FS_:FS;
	var outputsMap:StringMap<Int> = null;
	var outputs:Slice<TestFile> = null;

	public function new(fs:FS) {
		this.FS_ = fs;
	}

	public function WriteFile(path:RootedFilePath, data:String):Null<Error> {
		final err = this.FS_.WriteFile(path, data);
		if (err != null) {
			return err;
		}
		path = Tspath.RootedFilePathFromPath(this.Realpath(path.AsPath()));
		if (this.outputsMap != null && this.outputsMap.exists(path)) {
			this.outputs[this.outputsMap.get(path)] = new TestFile(path, data);
		} else {
			if (this.outputs == null)
				this.outputs = [];
			final index = this.outputs.length;
			if (this.outputsMap == null) {
				this.outputsMap = new StringMap();
			}
			this.outputsMap.set(path, index);
			this.outputs.push(new TestFile(path, data));
		}
		return null;
	}

	public function Outputs():Slice<TestFile> {
		return Slices.Clone(this.outputs);
	}

	// --- forwarded vfs.FS methods ---

	public function CaseSensitivity():ts.tspath.CaseSensitivity
		return FS_.CaseSensitivity();

	public function FileExists(path:RootedFilePath):Bool
		return FS_.FileExists(path);

	public function ReadFile(path:RootedFilePath):ValueOk<String>
		return FS_.ReadFile(path);

	public function AppendFile(path:RootedFilePath, data:String):Null<Error>
		return FS_.AppendFile(path, data);

	public function Remove(path:RootedPath):Null<Error>
		return FS_.Remove(path);

	public function Chtimes(path:RootedPath, aTime:Time, mTime:Time):Null<Error>
		return FS_.Chtimes(path, aTime, mTime);

	public function DirectoryExists(path:RootedDirectoryPath):Bool
		return FS_.DirectoryExists(path);

	public function GetAccessibleEntries(path:RootedDirectoryPath):Entries
		return FS_.GetAccessibleEntries(path);

	public function Stat(path:RootedPath):Null<FileInfo>
		return FS_.Stat(path);

	public function WalkDir(root:String, walkFn:WalkDirFunc):Null<Error>
		return FS_.WalkDir(root, walkFn);

	public function Realpath(path:RootedPath):RootedPath
		return FS_.Realpath(path);
}
