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
	public function GetCurrentDirectory():std.String {
		return this.host.GetCurrentDirectory();
	}
}

@:allow(ts.compiler)
class ProjectReferenceDtsFakingVfs implements ts.vfs.Vfs.FS {
	var projectReferenceFileMapper:ProjectReferenceFileMapper = null;
	var dtsDirectories:Set<Path> = new Set<Path>();
	var knownSymlinks:KnownSymlinks = new KnownSymlinks();

	public function new() {}

	// UseCaseSensitiveFileNames implements vfs.FS.
	public function UseCaseSensitiveFileNames():Bool {
		return this.projectReferenceFileMapper.opts.Host.FS().UseCaseSensitiveFileNames();
	}

	// FileExists implements vfs.FS.
	public function FileExists(path:std.String):Bool {
		if (this.projectReferenceFileMapper.opts.Host.FS().FileExists(path)) {
			return true;
		}
		if (!Tspath.IsDeclarationFileName(path)) {
			return false;
		}
		// Project references go to source file instead of .d.ts file
		return this.fileOrDirectoryExistsUsingSource(path /*isFile*/, true);
	}

	// ReadFile implements vfs.FS.
	public function ReadFile(path:std.String):ValueOk<std.String> {
		// Dont need to override as we cannot mimick read file
		return this.projectReferenceFileMapper.opts.Host.FS().ReadFile(path);
	}

	// WriteFile implements vfs.FS.
	public function WriteFile(path:std.String, data:std.String):Null<Error> {
		throw "should not be called by resolver";
	}

	// AppendFile implements vfs.FS.
	public function AppendFile(path:std.String, data:std.String):Null<Error> {
		throw "should not be called by resolver";
	}

	// Remove implements vfs.FS.
	public function Remove(path:std.String):Null<Error> {
		throw "should not be called by resolver";
	}

	// Chtimes implements vfs.FS.
	public function Chtimes(path:std.String, aTime:Time, mTime:Time):Null<Error> {
		throw "should not be called by resolver";
	}

	// DirectoryExists implements vfs.FS.
	public function DirectoryExists(path:std.String):Bool {
		if (this.projectReferenceFileMapper.opts.Host.FS().DirectoryExists(path)) {
			this.handleDirectoryCouldBeSymlink(path);
			return true;
		}
		return this.fileOrDirectoryExistsUsingSource(path /*isFile*/, false);
	}

	// GetAccessibleEntries implements vfs.FS.
	public function GetAccessibleEntries(path:std.String):Entries {
		throw "should not be called by resolver";
	}

	// Stat implements vfs.FS.
	public function Stat(path:std.String):Null<FileInfo> {
		throw "should not be called by resolver";
	}

	// WalkDir implements vfs.FS.
	public function WalkDir(root:std.String, walkFn:WalkDirFunc):Null<Error> {
		throw "should not be called by resolver";
	}

	// Realpath implements vfs.FS.
	public function Realpath(path:std.String):std.String {
		final result = this.knownSymlinks.Files().Load(this.toPath(path));
		if (result.ok) {
			return result.value;
		}
		return this.projectReferenceFileMapper.opts.Host.FS().Realpath(path);
	}

	function toPath(path:std.String):Path {
		return Tspath.ToPath(path, this.projectReferenceFileMapper.opts.Host.GetCurrentDirectory(), this.UseCaseSensitiveFileNames());
	}

	function handleDirectoryCouldBeSymlink(directory:std.String):Void {
		if (Tspath.ContainsIgnoredPath(directory)) {
			return;
		}

		// Because we already watch node_modules, handle symlinks in there
		if (directory.indexOf("/node_modules/") < 0) {
			return;
		}

		final directoryPath:Path = Tspath.EnsureTrailingDirectorySeparator(this.toPath(directory));
		if (this.knownSymlinks.Directories().Load(directoryPath).ok) {
			return;
		}

		final realDirectory = this.Realpath(directory);
		var realPath:Path;
		if (realDirectory == directory) {
			// not symlinked
			return;
		}
		realPath = Tspath.EnsureTrailingDirectorySeparator(this.toPath(realDirectory));
		if (realPath == directoryPath) {
			// not symlinked
			return;
		}
		this.knownSymlinks.SetDirectory(directory, directoryPath, new KnownDirectoryLink(Tspath.EnsureTrailingDirectorySeparator(realDirectory), realPath));
	}

	function fileOrDirectoryExistsUsingSource(fileOrDirectory:std.String, isFile:Bool):Bool {
		final fileOrDirectoryExistsUsingSource = Core.IfElse(isFile, this.fileExistsIfProjectReferenceDts, this.directoryExistsIfProjectReferenceDeclDir);
		// Check current directory or file
		final result = fileOrDirectoryExistsUsingSource(fileOrDirectory);
		if (result != TSUnknown) {
			return result == TSTrue;
		}

		final fileOrDirectoryPath = this.toPath(fileOrDirectory);
		if ((fileOrDirectoryPath : std.String).indexOf("/node_modules/") < 0) {
			return false;
		}
		// Check if the directory or file is a symlinked package
		final packageRoot = Module.ParseNodeModuleFromPath(fileOrDirectory, true /*isFolder*/);
		if (packageRoot != "") {
			this.handleDirectoryCouldBeSymlink(packageRoot);
		}
		final knownDirectoryLinks = this.knownSymlinks.Directories();
		if (knownDirectoryLinks.Size() == 0) {
			return false;
		}
		if (isFile) {
			if (this.knownSymlinks.Files().Load(fileOrDirectoryPath).ok) {
				return true;
			}
		}

		// If it contains node_modules check if its one of the symlinked path we know of
		var exists = false;
		knownDirectoryLinks.Range(function(directoryPath:Path, knownDirectoryLink:KnownDirectoryLink):Bool {
			final hasPrefix = StringTools.startsWith(fileOrDirectoryPath, directoryPath);
			if (!hasPrefix) {
				return true;
			}
			final relative = (fileOrDirectoryPath : std.String).substring((directoryPath : std.String).length);
			exists = fileOrDirectoryExistsUsingSource((knownDirectoryLink.RealPath : std.String) + relative).IsTrue();
			if (exists) {
				if (isFile) {
					// Store the real path for the file
					final absolutePath = Tspath.GetNormalizedAbsolutePath(fileOrDirectory, this.projectReferenceFileMapper.opts.Host.GetCurrentDirectory());
					this.knownSymlinks.SetFile(absolutePath, fileOrDirectoryPath,
						knownDirectoryLink.Real + absolutePath.substring((directoryPath : std.String).length));
				}
				return false;
			}
			return true;
		});
		return exists;
	}

	function fileExistsIfProjectReferenceDts(file:std.String):Tristate {
		final source = this.projectReferenceFileMapper.getProjectReferenceFromOutputDts(this.toPath(file));
		if (source != null) {
			return Core.IfElse(this.projectReferenceFileMapper.opts.Host.FS().FileExists(source.Source), TSTrue, TSFalse);
		}
		return TSUnknown;
	}

	function directoryExistsIfProjectReferenceDeclDir(dir:std.String):Tristate {
		final dirPath = this.toPath(dir);
		final dirPathWithTrailingDirectorySeparator = (dirPath : std.String) + "/";
		// PORT: Go map iteration order is random; the result does not depend on it.
		for (declDirPath in this.dtsDirectories.Keys().keys()) {
			if (dirPath == declDirPath
				|| // Any parent directory of declaration dir
				StringTools.startsWith(declDirPath, dirPathWithTrailingDirectorySeparator)
				|| // Any directory inside declaration dir
				StringTools.startsWith(dirPath, (declDirPath : std.String) + "/")) {
				return TSTrue;
			}
		}
		return TSUnknown;
	}
}
