package ts.execute.tsctests;

import go.Errors.Error;
import go.Time;
import ts.collections.Syncset;
import ts.vfs.Vfs;
import ts.tspath.Tspath;
import ts.execute.incremental.Incremental;
import ts.testutil.harnessutil.Harnessutil;

// Port of internal/execute/tsctests/fs.go.
// Go type `testFs` (unexported). PORT: embedded vfs.FS → field `FS` with forwarding methods.
class TestFs implements FS {
	public var FS:FS = null;
	public var defaultLibs:Null<SyncSet<String>> = null;
	public var writtenFiles:SyncSet<String> = new SyncSet<String>();

	public function new(fs:FS) {
		this.FS = fs;
	}

	function removeIgnoreLibPath(path:String):Void {
		if (this.defaultLibs != null && this.defaultLibs.Has(path)) {
			this.defaultLibs.Delete(path);
		}
	}

	// ReadFile reads the file specified by path and returns the content.
	// If the file fails to be read, ok will be false.
	public function ReadFile(path:String):ValueOk<String> {
		this.removeIgnoreLibPath(path);
		return this.readFileHandlingBuildInfo(path);
	}

	function readFileHandlingBuildInfo(path:String):ValueOk<String> {
		final r = this.FS.ReadFile(path);
		var contents = r.value;
		final ok = r.ok;
		if (ok && Tspath.FileExtensionIs(path, Tspath.ExtensionTsBuildInfo)) {
			// read buildinfo and modify version
			final buildInfo = Incremental.UnmarshalBuildInfo(contents);
			if (buildInfo != null && buildInfo.Version == Harnessutil.FakeTSVersion) {
				buildInfo.Version = Core.Version();
				final newContents = ts.json.Json.MarshalOrdered(buildInfo);
				contents = newContents;
			}
		}
		return new ValueOk(contents, ok);
	}

	public function WriteFile(path:String, data:String):Null<Error> {
		this.removeIgnoreLibPath(path);
		this.writtenFiles.Add(path);
		return this.writeFileHandlingBuildInfo(path, data);
	}

	function writeFileHandlingBuildInfo(path:String, data:String):Null<Error> {
		if (Tspath.FileExtensionIs(path, Tspath.ExtensionTsBuildInfo)) {
			final buildInfo = Incremental.UnmarshalBuildInfo(data);
			if (buildInfo != null) {
				if (buildInfo.Version == Core.Version()) {
					// Change it to harnessutil.FakeTSVersion
					buildInfo.Version = Harnessutil.FakeTSVersion;
					data = ts.json.Json.MarshalOrdered(buildInfo);
				}
				// Write readable build info version
				final err = this.WriteFile(path + ".readable.baseline.txt",
					Readablebuildinfo.toReadableBuildInfo(buildInfo, Fsbaselineutil.SanitizeInternalSymbolName(data)));
				if (err != null) {
					return go.Errors.New("testFs.WriteFile: failed to write readable build info: " + err.Error());
				}
			} else {
				throw "testFs.WriteFile: failed to unmarshal build info: - use underlying FS's write method if this is intended use for testcase";
			}
		}
		return this.FS.WriteFile(path, data);
	}

	// Removes `path` and all its contents. Will return the first error it encounters.
	public function Remove(path:String):Null<Error> {
		this.removeIgnoreLibPath(path);
		return this.FS.Remove(path);
	}

	// --- forwarded methods of the embedded vfs.FS ---

	public function UseCaseSensitiveFileNames():Bool {
		return this.FS.UseCaseSensitiveFileNames();
	}

	public function FileExists(path:String):Bool {
		return this.FS.FileExists(path);
	}

	public function AppendFile(path:String, data:String):Null<Error> {
		return this.FS.AppendFile(path, data);
	}

	public function Chtimes(path:String, aTime:Time, mTime:Time):Null<Error> {
		return this.FS.Chtimes(path, aTime, mTime);
	}

	public function DirectoryExists(path:String):Bool {
		return this.FS.DirectoryExists(path);
	}

	public function GetAccessibleEntries(path:String):Entries {
		return this.FS.GetAccessibleEntries(path);
	}

	public function Stat(path:String):Null<FileInfo> {
		return this.FS.Stat(path);
	}

	public function WalkDir(root:String, walkFn:WalkDirFunc):Null<Error> {
		return this.FS.WalkDir(root, walkFn);
	}

	public function Realpath(path:String):String {
		return this.FS.Realpath(path);
	}
}
