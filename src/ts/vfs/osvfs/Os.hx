package ts.vfs.osvfs;

import ts.tspath.RootedPath;
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

	public function CaseSensitivity():ts.tspath.CaseSensitivity {
		return Osvfs.fileSystemCaseSensitivity();
	}

	public function ReadFile(path:RootedFilePath):ValueOk<String> {
		final release = Osvfs.readSema.Acquire();
		final r = try this.common.ReadFile(path) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	public function DirectoryExists(path:RootedDirectoryPath):Bool {
		final release = Osvfs.blockingOpSema.Acquire();
		final r = try this.common.DirectoryExists(path) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	public function FileExists(path:RootedFilePath):Bool {
		final release = Osvfs.blockingOpSema.Acquire();
		final r = try this.common.FileExists(path) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	public function GetAccessibleEntries(path:RootedDirectoryPath):Entries {
		final release = Osvfs.blockingOpSema.Acquire();
		final r = try this.common.GetAccessibleEntries(path) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	public function Stat(path:RootedPath):Null<FileInfo> {
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

	public function Realpath(path:RootedPath):RootedPath {
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

	function writeFileEnsuringDir(path:RootedFilePath, content:String, flag:Int):Null<Error> {
		final pathString = path.AsString();
		if (this.writeFileWithFlag(pathString, content, flag) == null) {
			return null;
		}
		final err = this.ensureDirectoryExists(path.Directory().AsString());
		if (err != null) {
			return err;
		}
		return this.writeFileWithFlag(pathString, content, flag);
	}

	public function WriteFile(path:RootedFilePath, content:String):Null<Error> {
		return this.writeFileEnsuringDir(path, content, go.Os.O_WRONLY | go.Os.O_CREATE | go.Os.O_TRUNC);
	}

	public function AppendFile(path:RootedFilePath, content:String):Null<Error> {
		return this.writeFileEnsuringDir(path, content, go.Os.O_WRONLY | go.Os.O_CREATE | go.Os.O_APPEND);
	}

	public function Remove(path:RootedPath):Null<Error> {
		final release = Osvfs.blockingOpSema.Acquire();
		// todo: #701 add retry mechanism?
		final r = try go.Os.RemoveAll(path.AsString()) catch (e:Dynamic) {
			release();
			throw e;
		}
		release();
		return r;
	}

	public function Chtimes(path:RootedPath, aTime:Time, mTime:Time):Null<Error> {
		final release = Osvfs.blockingOpSema.Acquire();
		final r = try go.Os.Chtimes(path.AsString(), aTime, mTime) catch (e:Dynamic) {
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
