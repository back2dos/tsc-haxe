package ts.compiler;

import go.Time;

// Port of projectreferencedtsfakinghost.go (types and methods; newProjectReferenceDtsFakingHost is in Compiler.hx).

@:allow(ts.compiler)
class ProjectReferenceDtsFakingHost implements ResolutionHost {
	var host:CompilerHost = null;
	var fs:ts.vfs.cachedvfs.Cachedvfs.FS = null;

	public function new() {}

	// FS implements module.ResolutionHost.
	public function FS():ts.vfs.Vfs.FS {
		return this.fs;
	}

	// GetCurrentDirectory implements module.ResolutionHost.
	public function GetCurrentDirectory():RootedDirectoryPath {
		return this.host.GetCurrentDirectory();
	}
}

@:allow(ts.compiler)
class ProjectReferenceDtsFakingVfs implements ts.vfs.Vfs.FS {
	var projectReferenceFileMapper:ProjectReferenceFileMapper = null;
	var dtsDirectories:Set<PathKey> = new Set<PathKey>();
	var knownSymlinks:KnownSymlinks = new KnownSymlinks();

	public function new() {}

	// CaseSensitivity implements vfs.FS.
	public function CaseSensitivity():ts.tspath.CaseSensitivity {
		return this.projectReferenceFileMapper.opts.Host.FS().CaseSensitivity();
	}

	// FileExists implements vfs.FS.
	public function FileExists(path:RootedFilePath):Bool {
		if (this.projectReferenceFileMapper.opts.Host.FS().FileExists(path)) {
			return true;
		}
		if (!path.IsDeclarationFile()) {
			return false;
		}
		// Project references go to source file instead of .d.ts file
		return this.fileExistsUsingSource(path);
	}

	// ReadFile implements vfs.FS.
	public function ReadFile(path:RootedFilePath):ValueOk<std.String> {
		// Dont need to override as we cannot mimick read file
		return this.projectReferenceFileMapper.opts.Host.FS().ReadFile(path);
	}

	// WriteFile implements vfs.FS.
	public function WriteFile(path:RootedFilePath, data:std.String):Null<Error> {
		throw "should not be called by resolver";
	}

	// AppendFile implements vfs.FS.
	public function AppendFile(path:RootedFilePath, data:std.String):Null<Error> {
		throw "should not be called by resolver";
	}

	// Remove implements vfs.FS.
	public function Remove(path:RootedPath):Null<Error> {
		throw "should not be called by resolver";
	}

	// Chtimes implements vfs.FS.
	public function Chtimes(path:RootedPath, aTime:Time, mTime:Time):Null<Error> {
		throw "should not be called by resolver";
	}

	// DirectoryExists implements vfs.FS.
	public function DirectoryExists(path:RootedDirectoryPath):Bool {
		if (this.projectReferenceFileMapper.opts.Host.FS().DirectoryExists(path)) {
			this.handleDirectoryCouldBeSymlink(path);
			return true;
		}
		return this.directoryExistsUsingSource(path);
	}

	// GetAccessibleEntries implements vfs.FS.
	public function GetAccessibleEntries(path:RootedDirectoryPath):Entries {
		throw "should not be called by resolver";
	}

	// Stat implements vfs.FS.
	public function Stat(path:RootedPath):Null<FileInfo> {
		throw "should not be called by resolver";
	}

	// WalkDir implements vfs.FS.
	public function WalkDir(root:std.String, walkFn:WalkDirFunc):Null<Error> {
		throw "should not be called by resolver";
	}

	// Realpath implements vfs.FS.
	public function Realpath(path:RootedPath):RootedPath {
		final result = this.knownSymlinks.Files().Load(this.pathKey(path));
		if (result.ok) {
			return result.value.AsPath();
		}
		return this.projectReferenceFileMapper.opts.Host.FS().Realpath(path);
	}

	function pathKey(path:RootedPath):PathKey {
		return this.CaseSensitivity().PathKey(path);
	}

	function handleDirectoryCouldBeSymlink(directory:RootedDirectoryPath):Void {
		if (Tspath.ContainsIgnoredDirectory(directory)) {
			return;
		}

		// Because we already watch node_modules, handle symlinks in there
		if (!directory.ContainsLowercaseDirectorySequence("/node_modules/")) {
			return;
		}

		final directoryPath = this.pathKey(directory.AsPath());
		if (this.knownSymlinks.Directories().Load(directoryPath).ok) {
			return;
		}

		final realDirectory = Tspath.RootedDirectoryPathFromPath(this.Realpath(directory.AsPath()));
		if (realDirectory == directory) {
			// not symlinked
			return;
		}
		final realPath = this.pathKey(realDirectory.AsPath());
		if (realPath == directoryPath) {
			// not symlinked
			return;
		}
		this.knownSymlinks.SetDirectory(directory, directoryPath, new KnownDirectoryLink(realDirectory, realPath));
	}

	function fileExistsUsingSource(file:RootedFilePath):Bool {
		final fileOrDirectory = file.AsPath();
		final filePath = this.pathKey(file.AsPath());
		return this.fileOrDirectoryExistsUsingSource(fileOrDirectory, function(path:RootedPath):Tristate {
			return this.fileExistsIfProjectReferenceDts(Tspath.RootedFilePathFromPath(path));
		}, Module.NodeModulePackageRootForFile(file), function(realFile:RootedFilePath):Void {
			this.knownSymlinks.SetFile(file, filePath, realFile);
		});
	}

	function directoryExistsUsingSource(directory:RootedDirectoryPath):Bool {
		return this.fileOrDirectoryExistsUsingSource(directory.AsPath(), function(path:RootedPath):Tristate {
			return this.directoryExistsIfProjectReferenceDeclDir(Tspath.RootedDirectoryPathFromPath(path));
		}, Module.NodeModulePackageRootForDirectory(directory), null);
	}

	function fileOrDirectoryExistsUsingSource(fileOrDirectory:RootedPath, existsUsingSource:(path:RootedPath) -> Tristate,
			packageRoot:RootedDirectoryPath, onFileExists:Null<(realFile:RootedFilePath) -> Void>):Bool {
		// Check current directory or file
		final result = existsUsingSource(fileOrDirectory);
		if (result != TSUnknown) {
			return result == TSTrue;
		}

		final fileOrDirectoryPath = this.pathKey(fileOrDirectory);
		if (!fileOrDirectoryPath.ContainsLowercaseDirectorySequence("/node_modules/")) {
			return false;
		}
		// Check if the directory or file is a symlinked package
		if (packageRoot != "") {
			this.handleDirectoryCouldBeSymlink(packageRoot);
		}
		final knownDirectoryLinks = this.knownSymlinks.Directories();
		if (knownDirectoryLinks.Size() == 0) {
			return false;
		}
		if (onFileExists != null) {
			if (this.knownSymlinks.Files().Load(fileOrDirectoryPath).ok) {
				return true;
			}
		}

		// If it contains node_modules check if its one of the symlinked path we know of
		var exists = false;
		knownDirectoryLinks.Range(function(directoryPath:PathKey, knownDirectoryLink:KnownDirectoryLink):Bool {
			if (directoryPath == fileOrDirectoryPath || !directoryPath.ContainsPath(fileOrDirectoryPath)) {
				return true;
			}
			final realFileOrDirectory = knownDirectoryLink.ResolveFilePath(Tspath.RootedFilePathFromPath(fileOrDirectory), this.CaseSensitivity());
			if (realFileOrDirectory == null) {
				throw "canonical symlink path did not match its presentation path";
			}
			exists = existsUsingSource(realFileOrDirectory.AsPath()).IsTrue();
			if (exists) {
				if (onFileExists != null) {
					onFileExists(realFileOrDirectory);
				}
				return false;
			}
			return true;
		});
		return exists;
	}

	function fileExistsIfProjectReferenceDts(file:RootedFilePath):Tristate {
		final source = this.projectReferenceFileMapper.getProjectReferenceFromOutputDts(this.pathKey(file.AsPath()));
		if (source != null) {
			return Core.IfElse(this.projectReferenceFileMapper.opts.Host.FS().FileExists(source.Source), TSTrue, TSFalse);
		}
		return TSUnknown;
	}

	function directoryExistsIfProjectReferenceDeclDir(dir:RootedDirectoryPath):Tristate {
		final dirPath = this.pathKey(dir.AsPath());
		// PORT: Go map iteration order is random; the result does not depend on it.
		for (declDirPath in this.dtsDirectories.Keys().keys()) {
			if (dirPath.ContainsPath(declDirPath) || declDirPath.ContainsPath(dirPath)) {
				return TSTrue;
			}
		}
		return TSUnknown;
	}
}
