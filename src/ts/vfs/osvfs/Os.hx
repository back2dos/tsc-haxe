package ts.vfs.osvfs;

import go.Errors.Error;
import go.Time;
import go.Tuple.ValueOk;
import ts.tspath.Tspath;
import ts.vfs.Vfs;
import ts.vfs.internal.Internal;

// Port of os.go (types). Package-level funcs and vars are in Osvfs.hx.
// PORT: `defer sema.Acquire()()` → acquire, run, release (also when the body throws).
class OsFS implements FS {
	final common:Common;

	public function new(common:Common) {
		this.common = common;
	}

	public function UseCaseSensitiveFileNames():Bool {
		return Osvfs.isFileSystemCaseSensitive();
	}

	public function ReadFile(path:String):ValueOk<String> {
		final release = Osvfs.readSema.Acquire();
		final r = try this.common.ReadFile(path) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	public function DirectoryExists(path:String):Bool {
		final release = Osvfs.blockingOpSema.Acquire();
		final r = try this.common.DirectoryExists(path) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	public function FileExists(path:String):Bool {
		final release = Osvfs.blockingOpSema.Acquire();
		final r = try this.common.FileExists(path) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	public function GetAccessibleEntries(path:String):Entries {
		final release = Osvfs.blockingOpSema.Acquire();
		final r = try this.common.GetAccessibleEntries(path) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	public function Stat(path:String):Null<FileInfo> {
		final release = Osvfs.blockingOpSema.Acquire();
		final r = try this.common.Stat(path) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	public function WalkDir(root:String, walkFn:WalkDirFunc):Null<Error> {
		final walker = Osvfs.getLimitedWalkDirFunc(walkFn);
		final r = try this.common.WalkDir(root, walker.walk) catch (e:Dynamic) {
			Osvfs.putLimitedWalkDirFunc(walker);
			throw e;
		}
		Osvfs.putLimitedWalkDirFunc(walker);
		return r;
	}

	public function Realpath(path:String):String {
		final release = Osvfs.blockingOpSema.Acquire();
		final r = try Osvfs.osFSRealpath(path) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	function writeFileWithFlag(path:String, content:String, flag:Int):Null<Error> {
		final release = Osvfs.writeSema.Acquire();
		final r = try {
			final file = go.Os.OpenFile(path, flag, 438 /* 0o666 */);
			if (file.err != null) {
				file.err;
			} else {
				final w = file.value.WriteString(content);
				file.value.Close();
				w.err;
			}
		} catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	function ensureDirectoryExists(directoryPath:String):Null<Error> {
		final release = Osvfs.blockingOpSema.Acquire();
		final r = try go.Os.MkdirAll(directoryPath, 511 /* 0o777 */) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	function writeFileEnsuringDir(path:String, content:String, flag:Int):Null<Error> {
		Internal.RootLength(path); // Assert path is rooted
		if (this.writeFileWithFlag(path, content, flag) == null) {
			return null;
		}
		final err = this.ensureDirectoryExists(Tspath.GetDirectoryPath(Tspath.NormalizePath(path)));
		if (err != null) {
			return err;
		}
		return this.writeFileWithFlag(path, content, flag);
	}

	public function WriteFile(path:String, content:String):Null<Error> {
		return this.writeFileEnsuringDir(path, content, go.Os.O_WRONLY | go.Os.O_CREATE | go.Os.O_TRUNC);
	}

	public function AppendFile(path:String, content:String):Null<Error> {
		return this.writeFileEnsuringDir(path, content, go.Os.O_WRONLY | go.Os.O_CREATE | go.Os.O_APPEND);
	}

	public function Remove(path:String):Null<Error> {
		final release = Osvfs.blockingOpSema.Acquire();
		// todo: #701 add retry mechanism?
		final r = try go.Os.RemoveAll(path) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	public function Chtimes(path:String, aTime:Time, mTime:Time):Null<Error> {
		final release = Osvfs.blockingOpSema.Acquire();
		final r = try go.Os.Chtimes(path, aTime, mTime) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}
}

class LimitedWalkDirFunc {
	public var inner:Null<WalkDirFunc> = null;
	public var walk:Null<WalkDirFunc> = null;

	public function new() {}

	public function walker(path:String, d:Null<DirEntry>, err:Null<Error>):Null<Error> {
		final release = Osvfs.blockingOpSema.Acquire();
		final r = try this.inner(path, d, err) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}
}
