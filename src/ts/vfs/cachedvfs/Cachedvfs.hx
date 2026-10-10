package ts.vfs.cachedvfs;

import go.Errors.Error;
import go.Time;
import go.Tuple.ValueOk;
import ts.collections.Syncmap;
import ts.vfs.Vfs;

// Port of cachedvfs.go.
class Cachedvfs {
	public static function From(fs:ts.vfs.Vfs.FS):FS {
		final fsys = new FS(fs);
		fsys.enabled = true;
		return fsys;
	}
}

// PORT: atomic.Bool → Bool (single-threaded port).
class FS implements ts.vfs.Vfs.FS {
	final fs:ts.vfs.Vfs.FS;

	@:allow(ts.vfs.cachedvfs)
	var enabled:Bool = false;

	final directoryExistsCache = new SyncMap<String, Bool>(false);
	final fileExistsCache = new SyncMap<String, Bool>(false);
	final getAccessibleEntriesCache = new SyncMap<String, Entries>();
	final realpathCache = new SyncMap<String, String>("");
	final statCache = new SyncMap<String, FileInfo>();

	@:allow(ts.vfs.cachedvfs)
	function new(fs:ts.vfs.Vfs.FS) {
		this.fs = fs;
	}

	public function DisableAndClearCache():Void {
		// PORT: CompareAndSwap(true, false)
		if (this.enabled) {
			this.enabled = false;
			this.ClearCache();
		}
	}

	public function Enable():Void {
		this.enabled = true;
	}

	public function ClearCache():Void {
		this.directoryExistsCache.Clear();
		this.fileExistsCache.Clear();
		this.getAccessibleEntriesCache.Clear();
		this.realpathCache.Clear();
		this.statCache.Clear();
	}

	public function DirectoryExists(path:String):Bool {
		if (this.enabled) {
			final r = this.directoryExistsCache.Load(path);
			if (r.ok) {
				return r.value;
			}
		}

		final ret = this.fs.DirectoryExists(path);

		if (this.enabled) {
			this.directoryExistsCache.Store(path, ret);
		}

		return ret;
	}

	public function FileExists(path:String):Bool {
		if (this.enabled) {
			final r = this.fileExistsCache.Load(path);
			if (r.ok) {
				return r.value;
			}
		}

		final ret = this.fs.FileExists(path);

		if (this.enabled) {
			this.fileExistsCache.Store(path, ret);
		}

		return ret;
	}

	public function GetAccessibleEntries(path:String):Entries {
		if (this.enabled) {
			final r = this.getAccessibleEntriesCache.Load(path);
			if (r.ok) {
				return r.value;
			}
		}

		final ret = this.fs.GetAccessibleEntries(path);

		if (this.enabled) {
			this.getAccessibleEntriesCache.Store(path, ret);
		}

		return ret;
	}

	public function ReadFile(path:String):ValueOk<String> {
		return this.fs.ReadFile(path);
	}

	public function Realpath(path:String):String {
		if (this.enabled) {
			final r = this.realpathCache.Load(path);
			if (r.ok) {
				return r.value;
			}
		}

		final ret = this.fs.Realpath(path);

		if (this.enabled) {
			this.realpathCache.Store(path, ret);
		}

		return ret;
	}

	public function Remove(path:String):Null<Error> {
		return this.fs.Remove(path);
	}

	public function Chtimes(path:String, aTime:Time, mTime:Time):Null<Error> {
		return this.fs.Chtimes(path, aTime, mTime);
	}

	public function Stat(path:String):Null<FileInfo> {
		if (this.enabled) {
			final r = this.statCache.Load(path);
			if (r.ok) {
				return r.value;
			}
		}

		final ret = this.fs.Stat(path);

		if (this.enabled) {
			this.statCache.Store(path, ret);
		}

		return ret;
	}

	public function UseCaseSensitiveFileNames():Bool {
		return this.fs.UseCaseSensitiveFileNames();
	}

	public function WalkDir(root:String, walkFn:WalkDirFunc):Null<Error> {
		return this.fs.WalkDir(root, walkFn);
	}

	public function WriteFile(path:String, data:String):Null<Error> {
		return this.fs.WriteFile(path, data);
	}

	public function AppendFile(path:String, data:String):Null<Error> {
		return this.fs.AppendFile(path, data);
	}
}
