package ts.symlinks;

// Port of knownsymlinks.go (types and methods; NewKnownSymlinks is in Symlinks.hx).

class KnownDirectoryLink {
	// Matches the spelling used to reach the symlink. Used to preserve the
	// spelling of child paths when substituting the real directory.
	public var Symlink:RootedDirectoryPath = cast "";
	// Matches the casing returned by `realpath`. Used to compute the `realpath` of children.
	public var Real:RootedDirectoryPath = cast "";
	// Canonical key for Real, stored to avoid repeated recomputation.
	public var RealPath:PathKey = cast "";

	public function new(Real:RootedDirectoryPath, RealPath:PathKey, ?Symlink:RootedDirectoryPath) {
		this.Real = Real;
		this.RealPath = RealPath;
		if (Symlink != null) {
			this.Symlink = Symlink;
		}
	}

	// PORT: (RootedFilePath, bool) -> null when !ok.
	public function ResolveFilePath(fileName:RootedFilePath, caseSensitivity:CaseSensitivity):Null<RootedFilePath> {
		final relative = caseSensitivity.RelativeFilePathFromDirectory(this.Symlink, fileName);
		if (relative == null) {
			return null;
		}
		return this.Real.ResolveRelativeFile(relative);
	}
}

@:allow(ts.symlinks)
class KnownSymlinks {
	var directories:SyncMap<PathKey, KnownDirectoryLink> = new SyncMap<PathKey, KnownDirectoryLink>();
	var directoriesByRealpath:SyncMap<PathKey, SyncSet<RootedDirectoryPath>> = new SyncMap<PathKey, SyncSet<RootedDirectoryPath>>();
	var files:SyncMap<PathKey, RootedFilePath> = new SyncMap<PathKey, RootedFilePath>(cast "");
	var filesByRealpath:SyncMap<PathKey, SyncSet<RootedFilePath>> = new SyncMap<PathKey, SyncSet<RootedFilePath>>();
	var caseSensitivity:CaseSensitivity = CaseInsensitive;

	public function new(caseSensitivity:CaseSensitivity = CaseInsensitive) {
		this.caseSensitivity = caseSensitivity;
	}

	public function HasDirectory(symlinkPath:PathKey):Bool {
		final ok = this.directories.Load(symlinkPath).ok;
		return ok;
	}

	// Gets a map from symlink to realpath.
	public function Directories():SyncMap<PathKey, KnownDirectoryLink> {
		return this.directories;
	}

	public function DirectoriesByRealpath():SyncMap<PathKey, SyncSet<RootedDirectoryPath>> {
		return this.directoriesByRealpath;
	}

	// Gets a map from symlink to realpath
	public function Files():SyncMap<PathKey, RootedFilePath> {
		return this.files;
	}

	// Gets a map from realpath to symlinks
	public function FilesByRealpath():SyncMap<PathKey, SyncSet<RootedFilePath>> {
		return this.filesByRealpath;
	}

	public function SetDirectory(symlink:RootedDirectoryPath, symlinkPath:PathKey, realDirectory:Null<KnownDirectoryLink>):Void {
		if (realDirectory != null) {
			// PORT: Go copies the struct value (link := *realDirectory).
			realDirectory = new KnownDirectoryLink(realDirectory.Real, realDirectory.RealPath, symlink);
			if (!this.directories.Load(symlinkPath).ok) {
				final set = this.directoriesByRealpath.LoadOrStore(realDirectory.RealPath, new SyncSet<RootedDirectoryPath>()).value;
				set.Add(symlink);
			}
		}
		this.directories.Store(symlinkPath, realDirectory);
	}

	public function SetFile(symlink:RootedFilePath, symlinkPath:PathKey, realpath:RootedFilePath):Void {
		if (!this.files.Load(symlinkPath).ok) {
			final realpathPath = this.caseSensitivity.PathKey(realpath.AsPath());
			final set = this.filesByRealpath.LoadOrStore(realpathPath, new SyncSet<RootedFilePath>()).value;
			set.Add(symlink);
		}
		this.files.Store(symlinkPath, realpath);
	}

	public function SetSymlinksFromResolutions(forEachResolvedModule:(callback:(resolution:ResolvedModule, moduleName:String, mode:ResolutionMode,
		filePath:PathKey) -> Void, file:Null<SourceFile>) -> Void,
			forEachResolvedTypeReferenceDirective:(callback:(resolution:ResolvedTypeReferenceDirective, moduleName:String, mode:ResolutionMode,
				filePath:PathKey) -> Void, file:Null<SourceFile>) -> Void):Void {
		forEachResolvedModule(function(resolution:ResolvedModule, moduleName:String, mode:ResolutionMode, filePath:PathKey):Void {
			this.ProcessResolution(resolution.OriginalPath, resolution.ResolvedFileName);
		}, null);
		forEachResolvedTypeReferenceDirective(function(resolution:ResolvedTypeReferenceDirective, moduleName:String, mode:ResolutionMode,
				filePath:PathKey):Void {
			this.ProcessResolution(resolution.OriginalPath, resolution.ResolvedFileName);
		}, null);
	}

	public function ProcessResolution(originalFileName:RootedFilePath, resolvedFileName:RootedFilePath):Void {
		if (originalFileName == "" || resolvedFileName == "") {
			return;
		}
		this.SetFile(originalFileName, this.caseSensitivity.PathKey(originalFileName.AsPath()), resolvedFileName);
		final r = this.guessDirectorySymlinkFromFilePaths(resolvedFileName, originalFileName);
		final commonResolved = r.a, commonOriginal = r.b;
		if (commonResolved != "" && commonOriginal != "") {
			final symlinkPath = this.caseSensitivity.PathKey(commonOriginal.AsPath());
			if (!Tspath.ContainsIgnoredPathKey(symlinkPath)) {
				this.SetDirectory(commonOriginal, symlinkPath, new KnownDirectoryLink(commonResolved, this.caseSensitivity.PathKey(commonResolved.AsPath())));
			}
		}
	}

	// PORT: (RootedDirectoryPath, RootedDirectoryPath) → Pair(a = commonResolved, b = commonOriginal).
	function guessDirectorySymlinkFromFilePaths(a:RootedFilePath, b:RootedFilePath):Pair<RootedDirectoryPath, RootedDirectoryPath> {
		var isDirectory = false;
		while (true) {
			final aParent = a.Directory();
			final bParent = b.Directory();
			if (aParent.AsPath() == a.AsPath()
				|| bParent.AsPath() == b.AsPath()
				|| this.isNodeModulesOrScopedPackageDirectory(aParent.AsPath().BaseName())
				|| this.isNodeModulesOrScopedPackageDirectory(bParent.AsPath().BaseName())
				|| this.caseSensitivity.Canonicalize(a.BaseName()) != this.caseSensitivity.Canonicalize(b.BaseName())) {
				break;
			}
			a = Tspath.RootedFilePathFromPath(aParent.AsPath());
			b = Tspath.RootedFilePathFromPath(bParent.AsPath());
			isDirectory = true;
		}
		if (isDirectory) {
			return new Pair(Tspath.RootedDirectoryPathFromPath(a.AsPath()), Tspath.RootedDirectoryPathFromPath(b.AsPath()));
		}
		return new Pair(cast "", cast "");
	}

	function isNodeModulesOrScopedPackageDirectory(s:String):Bool {
		return s != "" && (this.caseSensitivity.Canonicalize(s) == "node_modules" || StringTools.startsWith(s, "@"));
	}
}
