package ts.symlinks;

// Port of knownsymlinks.go (types and methods; NewKnownSymlink is in Symlinks.hx).

class KnownDirectoryLink {
	// Matches the casing returned by `realpath`. Used to compute the `realpath` of children.
	// Always has trailing directory separator
	public var Real:String = "";
	// toPath(real). Stored to avoid repeated recomputation.
	// Always has trailing directory separator
	public var RealPath:Path = "";

	public function new(Real:String = "", RealPath:Path = "") {
		this.Real = Real;
		this.RealPath = RealPath;
	}
}

@:allow(ts.symlinks)
class KnownSymlinks {
	var directories:SyncMap<Path, KnownDirectoryLink> = new SyncMap<Path, KnownDirectoryLink>();
	var directoriesByRealpath:SyncMap<Path, SyncSet<String>> = new SyncMap<Path, SyncSet<String>>();
	var files:SyncMap<Path, String> = new SyncMap<Path, String>("");
	var filesByRealpath:SyncMap<Path, SyncSet<String>> = new SyncMap<Path, SyncSet<String>>();
	var cwd:String = "";
	var useCaseSensitiveFileNames:Bool = false;

	public function new(cwd:String = "", useCaseSensitiveFileNames:Bool = false) {
		this.cwd = cwd;
		this.useCaseSensitiveFileNames = useCaseSensitiveFileNames;
	}

	public function HasDirectory(symlinkPath:Path):Bool {
		final ok = this.directories.Load(symlinkPath.EnsureTrailingDirectorySeparator()).ok;
		return ok;
	}

	// Gets a map from symlink to realpath. Keys have trailing directory separators.
	public function Directories():SyncMap<Path, KnownDirectoryLink> {
		return this.directories;
	}

	public function DirectoriesByRealpath():SyncMap<Path, SyncSet<String>> {
		return this.directoriesByRealpath;
	}

	// Gets a map from symlink to realpath
	public function Files():SyncMap<Path, String> {
		return this.files;
	}

	// Gets a map from realpath to symlinks
	public function FilesByRealpath():SyncMap<Path, SyncSet<String>> {
		return this.filesByRealpath;
	}

	public function SetDirectory(symlink:String, symlinkPath:Path, realDirectory:Null<KnownDirectoryLink>):Void {
		if (realDirectory != null) {
			if (!this.directories.Load(symlinkPath).ok) {
				final set = this.directoriesByRealpath.LoadOrStore(realDirectory.RealPath, new SyncSet<String>()).value;
				set.Add(symlink);
			}
		}
		this.directories.Store(symlinkPath, realDirectory);
	}

	public function SetFile(symlink:String, symlinkPath:Path, realpath:String):Void {
		if (!this.files.Load(symlinkPath).ok) {
			final realpathPath = Tspath.ToPath(realpath, this.cwd, this.useCaseSensitiveFileNames);
			final set = this.filesByRealpath.LoadOrStore(realpathPath, new SyncSet<String>()).value;
			set.Add(symlink);
		}
		this.files.Store(symlinkPath, realpath);
	}

	public function SetSymlinksFromResolutions(forEachResolvedModule:(callback:(resolution:ResolvedModule, moduleName:String, mode:ResolutionMode,
		filePath:Path) -> Void, file:Null<SourceFile>) -> Void,
			forEachResolvedTypeReferenceDirective:(callback:(resolution:ResolvedTypeReferenceDirective, moduleName:String, mode:ResolutionMode,
				filePath:Path) -> Void, file:Null<SourceFile>) -> Void):Void {
		forEachResolvedModule(function(resolution:ResolvedModule, moduleName:String, mode:ResolutionMode, filePath:Path):Void {
			this.ProcessResolution(resolution.OriginalPath, resolution.ResolvedFileName);
		}, null);
		forEachResolvedTypeReferenceDirective(function(resolution:ResolvedTypeReferenceDirective, moduleName:String, mode:ResolutionMode,
				filePath:Path):Void {
			this.ProcessResolution(resolution.OriginalPath, resolution.ResolvedFileName);
		}, null);
	}

	public function ProcessResolution(originalPath:String, resolvedFileName:String):Void {
		if (originalPath == "" || resolvedFileName == "") {
			return;
		}
		this.SetFile(originalPath, Tspath.ToPath(originalPath, this.cwd, this.useCaseSensitiveFileNames), resolvedFileName);
		final r = this.guessDirectorySymlink(resolvedFileName, originalPath, this.cwd);
		final commonResolved = r.a, commonOriginal = r.b;
		if (commonResolved != "" && commonOriginal != "") {
			final symlinkPath = Tspath.ToPath(commonOriginal, this.cwd, this.useCaseSensitiveFileNames);
			if (!Tspath.ContainsIgnoredPath(symlinkPath)) {
				this.SetDirectory(commonOriginal, symlinkPath.EnsureTrailingDirectorySeparator(),
					new KnownDirectoryLink(Tspath.EnsureTrailingDirectorySeparator(commonResolved),
						Tspath.ToPath(commonResolved, this.cwd, this.useCaseSensitiveFileNames).EnsureTrailingDirectorySeparator()));
			}
		}
	}

	// PORT: (string, string) → Pair(a = commonResolved, b = commonOriginal).
	function guessDirectorySymlink(a:String, b:String, cwd:String):Pair<String, String> {
		var aParts = Tspath.GetPathComponents(Tspath.GetNormalizedAbsolutePath(a, cwd), "");
		var bParts = Tspath.GetPathComponents(Tspath.GetNormalizedAbsolutePath(b, cwd), "");
		var isDirectory = false;
		while (aParts.length >= 2
			&& bParts.length >= 2
			&& !this.isNodeModulesOrScopedPackageDirectory(aParts[aParts.length - 2])
			&& !this.isNodeModulesOrScopedPackageDirectory(bParts[bParts.length - 2])
			&& Tspath.GetCanonicalFileName(aParts[aParts.length - 1], this.useCaseSensitiveFileNames) == Tspath.GetCanonicalFileName(bParts[bParts.length - 1],
				this.useCaseSensitiveFileNames)) {
			aParts = aParts.slice(0, aParts.length - 1);
			bParts = bParts.slice(0, bParts.length - 1);
			isDirectory = true;
		}
		if (isDirectory) {
			return new Pair(Tspath.GetPathFromPathComponents(aParts), Tspath.GetPathFromPathComponents(bParts));
		}
		return new Pair("", "");
	}

	function isNodeModulesOrScopedPackageDirectory(s:String):Bool {
		return s != "" && (Tspath.GetCanonicalFileName(s, this.useCaseSensitiveFileNames) == "node_modules" || StringTools.startsWith(s, "@"));
	}
}
