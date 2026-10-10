package ts.symlinks;

// Port of internal/symlinks: package-level funcs.
class Symlinks {
	// --- knownsymlinks.go ---

	public static function NewKnownSymlink(currentDirectory:String, useCaseSensitiveFileNames:Bool):KnownSymlinks {
		return new KnownSymlinks(currentDirectory, useCaseSensitiveFileNames);
	}
}
