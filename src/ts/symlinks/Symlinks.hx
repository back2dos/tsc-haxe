package ts.symlinks;

// Port of internal/symlinks: package-level funcs.
class Symlinks {
	// --- knownsymlinks.go ---

	public static function NewKnownSymlinks(caseSensitivity:CaseSensitivity):KnownSymlinks {
		return new KnownSymlinks(caseSensitivity);
	}
}
