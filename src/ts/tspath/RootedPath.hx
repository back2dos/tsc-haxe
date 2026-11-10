package ts.tspath;

import go.Strings;
import go.Tuple;
import ts.tspath.CaseSensitivity;

// Port of internal/tspath/rooted_path.go (types and methods). Package-level funcs are in Tspath.hx.
//
// PORT: Go's distinct string types are abstracts over String (no runtime cost). A typed path converts to
// String implicitly (Go: AsString(), a lossless widening); there is no implicit conversion from String or
// between the path kinds: use the constructors in Tspath (ToRooted*, Rooted*FromAbsolute,
// Rooted*FromNormalized) or AsPath()/RootedFilePathFromPath/RootedDirectoryPathFromPath. The raw
// constructors are package-private, like Go's unchecked conversions inside package tspath.

// RootedPath is a rooted, slash-normalized, lexically normalized path that may
// represent either a file or a directory. It preserves path casing. Its zero
// value is a valid sentinel.
// PORT: read-only String methods forwarded (Go reads the string with AsString()).
@:forward(indexOf, lastIndexOf, substring, substr, charCodeAt, charAt, split, toLowerCase)
abstract RootedPath(String) to String {
	// PORT: Go len(p).
	public var length(get, never):Int;

	inline function get_length():Int {
		return this.length;
	}

	@:allow(ts.tspath)
	inline function new(s:String) {
		this = s;
	}

	public inline function AsString():String {
		return this;
	}

	// Compare returns the case-sensitive lexical ordering of the normalized path text.
	public inline function Compare(other:RootedPath):Int {
		return Strings.Compare(this, other.AsString());
	}

	public function Directory():RootedDirectoryPath {
		var path = this;
		final rootLength = Tspath.GetRootLength(path);
		if (rootLength == path.length) {
			return new RootedDirectoryPath(path);
		}
		path = Tspath.RemoveTrailingDirectorySeparator(path);
		final last = Tspath.lastDirectorySeparator(path);
		return new RootedDirectoryPath(path.substring(0, rootLength > last ? rootLength : last));
	}

	// PORT: (RootedDirectoryPath, string) -> Pair.
	public function RootAndRelativePath():Pair<RootedDirectoryPath, String> {
		final rootLength = Tspath.GetRootLength(this);
		return new Pair(new RootedDirectoryPath(this.substring(0, rootLength)), this.substring(rootLength));
	}

	public inline function BaseName():String {
		return Tspath.getBaseFileNameFromNormalized(this);
	}

	public inline function IsDynamic():Bool {
		return Tspath.IsDynamicFileName(this);
	}

	// PORT: (RelativePath, bool) -> null when !ok.
	public inline function RelativeTo(directory:RootedDirectoryPath):Null<RelativePath> {
		return cast CaseSensitive.trimContainedPath(directory.AsString(), this);
	}
}

// RootedFilePath is a RootedPath intended to be used as a file path. It does
// not assert that the path exists or is a file on a filesystem.
// PORT: read-only String methods forwarded (Go reads the string with AsString()).
@:forward(indexOf, lastIndexOf, substring, substr, charCodeAt, charAt, split, toLowerCase)
abstract RootedFilePath(String) to String {
	// PORT: Go len(p).
	public var length(get, never):Int;

	inline function get_length():Int {
		return this.length;
	}

	@:allow(ts.tspath)
	inline function new(s:String) {
		this = s;
	}

	public inline function AsString():String {
		return this;
	}

	// Compare returns the case-sensitive lexical ordering of the normalized path text.
	public inline function Compare(other:RootedFilePath):Int {
		return Strings.Compare(this, other.AsString());
	}

	public inline function AsPath():RootedPath {
		return new RootedPath(this);
	}

	public inline function AsModuleSpecifier():ModuleSpecifier {
		return new ModuleSpecifier(this);
	}

	public inline function Directory():RootedDirectoryPath {
		return AsPath().Directory();
	}

	public function WithoutRoot():String {
		return this.substring(Tspath.GetRootLength(this));
	}

	public inline function RootAndRelativePath():Pair<RootedDirectoryPath, String> {
		return AsPath().RootAndRelativePath();
	}

	public function DirectoryBefore(index:Int):RootedDirectoryPath {
		final path = this;
		if (index < Tspath.GetRootLength(path)
			|| index > path.length
			|| index < path.length && !Tspath.isAnyDirectorySeparator(StringTools.fastCodeAt(path, index))) {
			throw "directory boundary must be at a path separator";
		}
		return new RootedDirectoryPath(path.substring(0, index));
	}

	public function SuffixAfterSeparator(index:Int):String {
		final path = this;
		if (index < 0 || index >= path.length || !Tspath.isAnyDirectorySeparator(StringTools.fastCodeAt(path, index))) {
			throw "suffix boundary must be at a path separator";
		}
		return path.substring(index + 1);
	}

	// AppendSuffix appends a suffix that cannot change the rooted or normalized
	// path structure.
	public function AppendSuffix(suffix:String):RootedFilePath {
		Tspath.validateFileNameSuffix(this, suffix);
		final result = this + suffix;
		if (result != "") {
			Tspath.RootedPathFromNormalized(result);
		}
		return new RootedFilePath(result);
	}

	public inline function AsStem():FileNameStem {
		return new FileNameStem(this);
	}

	public inline function RemoveFileExtension():FileNameStem {
		return new FileNameStem(Tspath.RemoveFileExtension(this));
	}

	public function RemoveExtension(extension:String):FileNameStem {
		Tspath.validateFileExtension(extension);
		if (!StringTools.endsWith(this, extension)) {
			throw "file name does not have extension: " + extension;
		}
		return new FileNameStem(Tspath.RemoveExtension(this, extension));
	}

	public inline function ChangeExtension(extension:String):RootedFilePath {
		Tspath.validateFileExtension(extension);
		return Tspath.rootedFilePathFromExtensionMutation(Tspath.ChangeExtension(this, extension));
	}

	public inline function ChangeFullExtension(extension:String):RootedFilePath {
		Tspath.validateFileExtension(extension);
		return Tspath.rootedFilePathFromExtensionMutation(Tspath.ChangeFullExtension(this, extension));
	}

	public function ChangeAnyExtension(extension:String, extensions:Array<String>, caseSensitivity:CaseSensitivity):RootedFilePath {
		Tspath.validateFileExtension(extension);
		for (candidate in extensions) {
			Tspath.validateFileExtension(candidate);
		}
		return Tspath.rootedFilePathFromExtensionMutation(Tspath.ChangeAnyExtension(this, extension, extensions, caseSensitivity));
	}

	// --- extensionrewrite.go ---
	// PORT: (RootedFilePath, bool) -> ValueOk.
	public function RewriteExtension(rewrites:Slice<Tspath.ExtensionRewrite>, caseSensitivity:CaseSensitivity):ValueOk<RootedFilePath> {
		final ignoreCase = caseSensitivity.IsCaseInsensitive();
		final rewrite = Tspath.ExtensionRewrites.GetExtensionRewrite(this, rewrites, ignoreCase);
		if (!rewrite.ok || rewrite.value.isIdentity(ignoreCase)) {
			return new ValueOk(abstract, false);
		}
		final suffix = this.substring(this.length - rewrite.value.Source.length);
		return new ValueOk(RemoveExtension(suffix).AppendSuffix(rewrite.value.Target), true);
	}

	public inline function BaseName():String {
		return Tspath.getBaseFileNameFromNormalized(this);
	}

	public inline function ExtensionIs(extension:String):Bool {
		return Tspath.FileExtensionIs(this, extension);
	}

	public inline function ExtensionIsOneOf(extensions:Slice<String>):Bool {
		return Tspath.FileExtensionIsOneOf(this, extensions);
	}

	public inline function Extension():String {
		return Tspath.TryGetExtensionFromPath(this);
	}

	public function AnyExtension(extensions:Slice<String>, caseSensitivity:CaseSensitivity):String {
		if (extensions == null || extensions.length == 0) {
			return Tspath.getAnyExtensionFromNormalizedPath(this);
		}
		return Tspath.GetAnyExtensionFromPath(this, extensions, caseSensitivity);
	}

	public inline function LongestExtension(extensions:Slice<String>, caseSensitivity:CaseSensitivity):String {
		return Tspath.GetLongestExtensionFromPath(this, extensions, caseSensitivity);
	}

	public inline function HasExtension():Bool {
		return Tspath.getBaseFileNameFromNormalized(this).indexOf(".") >= 0;
	}

	public inline function HasImplementationTSFileExtension():Bool {
		return Tspath.HasImplementationTSFileExtension(this);
	}

	public inline function HasTSFileExtension():Bool {
		return Tspath.HasTSFileExtension(this);
	}

	public inline function TryExtractTSExtension():String {
		return Tspath.TryExtractTSExtension(this);
	}

	public inline function HasJSONFileExtension():Bool {
		return Tspath.HasJSONFileExtension(this);
	}

	public inline function DeclarationFileExtension():String {
		return Tspath.getDeclarationFileExtensionFromNormalized(this);
	}

	public inline function DeclarationEmitExtension():String {
		return Tspath.GetDeclarationEmitExtensionForPath(this);
	}

	public inline function PossibleOriginalInputExtensions():Array<String> {
		return Tspath.GetPossibleOriginalInputExtensionForExtension(this);
	}

	public inline function HasJSFileExtension():Bool {
		return Tspath.HasJSFileExtension(this);
	}

	public inline function IsDynamic():Bool {
		return Tspath.IsDynamicFileName(this);
	}

	public inline function IsDeclarationFile():Bool {
		return Tspath.getDeclarationFileExtensionFromNormalized(this) != "";
	}

	public inline function Components():Array<String> {
		return Tspath.GetPathComponents(this);
	}

	public inline function RootLength():Int {
		return Tspath.GetRootLength(this);
	}

	// PORT: (RelativePath, bool) -> null when !ok.
	public inline function RelativeTo(directory:RootedDirectoryPath):Null<RelativePath> {
		return AsPath().RelativeTo(directory);
	}

	// PORT: (before, through, ok) -> null when !ok.
	public function SplitAtComponent(component:String):Null<SplitDirectories> {
		if (component == "" || Strings.IndexAny(component, "/\\") >= 0 || component == "." || component == "..") {
			throw "invalid path component";
		}
		final needle = "/" + component;
		final path = this;
		final rootLength = RootLength();
		if (rootLength == 0) {
			return null;
		}
		var offset = rootLength - 1;
		while (true) {
			final index = path.indexOf(needle, offset);
			if (index == -1) {
				return null;
			}
			final end = index + needle.length;
			if (end == path.length || StringTools.fastCodeAt(path, end) == Tspath.DirectorySeparator) {
				final beforeEnd = index > rootLength ? index : rootLength;
				return new SplitDirectories(new RootedDirectoryPath(path.substring(0, beforeEnd)), new RootedDirectoryPath(path.substring(0, end)));
			}
			offset = end;
		}
	}

	public inline function ContainsLowercaseDirectorySequence(sequence:String):Bool {
		return this.indexOf(sequence) >= 0;
	}

	// PORT: (before, through, ok) -> null when !ok.
	public function SplitAtLastComponent(component:String):Null<SplitDirectories> {
		if (component == "" || Strings.IndexAny(component, "/\\") >= 0 || component == "." || component == "..") {
			throw "invalid path component";
		}
		final needle = "/" + component;
		final path = this;
		var end = path.length;
		while (end > 0) {
			// PORT: strings.LastIndex(path[:end], needle) without the slice
			final index = end >= needle.length ? path.lastIndexOf(needle, end - needle.length) : -1;
			if (index == -1) {
				return null;
			}
			final componentEnd = index + needle.length;
			if (index >= RootLength() - 1 && (componentEnd == path.length || StringTools.fastCodeAt(path, componentEnd) == Tspath.DirectorySeparator)) {
				final beforeEnd = index > RootLength() ? index : RootLength();
				return new SplitDirectories(new RootedDirectoryPath(path.substring(0, beforeEnd)), new RootedDirectoryPath(path.substring(0, componentEnd)));
			}
			end = index;
		}
		return null;
	}

	public inline function DirectorySeparatorCount():Int {
		return Strings.Count(this, "/");
	}
}

// FileNameStem is a rooted filename prefix, not a normalized path. Removing
// an extension can leave a trailing separator or a "." or ".." component.
// Complete the stem with AppendSuffix before using it as a path.
// PORT: read-only String methods forwarded (Go reads the string with AsString()).
@:forward(indexOf, lastIndexOf, substring, substr, charCodeAt, charAt, split, toLowerCase)
abstract FileNameStem(String) to String {
	// PORT: Go len(p).
	public var length(get, never):Int;

	inline function get_length():Int {
		return this.length;
	}

	@:allow(ts.tspath)
	inline function new(s:String) {
		this = s;
	}

	public inline function AsString():String {
		return this;
	}

	public function AppendSuffix(suffix:String):RootedFilePath {
		Tspath.validateFileNameSuffix(this, suffix);
		final result = this + suffix;
		if (result == "") {
			return new RootedFilePath("");
		}
		return Tspath.RootedFilePathFromNormalized(result);
	}
}

// RootedDirectoryPath is a RootedPath intended to be used as a directory path.
// It does not assert that the path exists or is a directory on a filesystem,
// and does not guarantee a trailing directory separator.
// PORT: read-only String methods forwarded (Go reads the string with AsString()).
@:forward(indexOf, lastIndexOf, substring, substr, charCodeAt, charAt, split, toLowerCase)
abstract RootedDirectoryPath(String) to String {
	// PORT: Go len(p).
	public var length(get, never):Int;

	inline function get_length():Int {
		return this.length;
	}

	@:allow(ts.tspath)
	inline function new(s:String) {
		this = s;
	}

	public inline function AsString():String {
		return this;
	}

	// Compare returns the case-sensitive lexical ordering of the normalized path text.
	public inline function Compare(other:RootedDirectoryPath):Int {
		return Strings.Compare(this, other.AsString());
	}

	public inline function AsPath():RootedPath {
		return new RootedPath(this);
	}

	public inline function BaseName():String {
		return AsPath().BaseName();
	}

	public inline function Components():Array<String> {
		return Tspath.GetPathComponents(this);
	}

	public inline function ContainsLowercaseDirectorySequence(sequence:String):Bool {
		return this.indexOf(sequence) >= 0;
	}

	public function ResolveFile(path:String):RootedFilePath {
		if (this == "") {
			throw "cannot resolve from an empty directory name";
		}
		if (path == "") {
			return new RootedFilePath(this);
		}
		if (Tspath.GetEncodedRootLength(path) == 0 && Tspath.hasURLRoot(this) && Strings.IndexAny(path, "?#") >= 0) {
			throw "relative URL path must not contain a query or fragment";
		}
		if (Tspath.canAppendPathWithoutNormalization(path)) {
			return Tspath.rootedFilePathFromResolved(Tspath.appendPathToDirectory(abstract, path));
		}
		if (Tspath.isNormalizedSlashesRelativePath(path)) {
			final resolved = Tspath.appendPathWithLeadingDotSegments(abstract, path);
			if (resolved != null) {
				return Tspath.rootedFilePathFromResolved(resolved);
			}
			return Tspath.rootedFilePathFromResolved(Tspath.getNormalizedAbsolutePathFromNormalizedSlashes(Tspath.appendPathToDirectory(abstract,
				path)));
		}
		return Tspath.ToRootedFilePath(path, abstract);
	}

	public function ResolveRelativeFile(path:RelativePath):RootedFilePath {
		if (this == "") {
			throw "cannot resolve from an empty directory name";
		}
		if (path.AsString() == "") {
			return new RootedFilePath(this);
		}
		if (Tspath.hasURLRoot(this) && Strings.IndexAny(path.AsString(), "?#") >= 0) {
			throw "relative URL path must not contain a query or fragment";
		}
		if (path.requiresResolution()) {
			return Tspath.ToRootedFilePath(path.AsString(), abstract);
		}
		return Tspath.rootedFilePathFromResolved(Tspath.appendPathToDirectory(abstract, path.AsString()));
	}

	// ResolveFileFromNormalizedRelative resolves an already normalized relative
	// path without revalidating the directory or path.
	public function ResolveFileFromNormalizedRelative(path:String):RootedFilePath {
		if (this == "") {
			throw "cannot resolve from an empty directory path";
		}
		if (path == "") {
			throw "path must not be empty";
		}
		if (Tspath.GetEncodedRootLength(path) == 0 && Tspath.hasURLRoot(this) && Strings.IndexAny(path, "?#") >= 0) {
			throw "relative URL path must not contain a query or fragment";
		}
		if (Tspath.isAnyDirectorySeparator(StringTools.fastCodeAt(path, 0))
			|| Tspath.NormalizeSlashes(path) != path
			|| Tspath.hasRelativePathSegment(path)
			|| Tspath.HasTrailingDirectorySeparator(path)) {
			throw "path must be relative and normalized: " + path;
		}
		return Tspath.rootedFilePathFromResolved(Tspath.appendPathToDirectory(abstract, path));
	}

	public inline function ResolveRelativeDirectory(path:RelativePath):RootedDirectoryPath {
		return new RootedDirectoryPath(ResolveRelativeFile(path));
	}

	public function ResolveDirectory(path:String):RootedDirectoryPath {
		if (this == "") {
			throw "cannot resolve from an empty directory name";
		}
		if (path == "") {
			return abstract;
		}
		if (Tspath.GetEncodedRootLength(path) == 0 && Tspath.hasURLRoot(this) && Strings.IndexAny(path, "?#") >= 0) {
			throw "relative URL path must not contain a query or fragment";
		}
		if (Tspath.canAppendPathWithoutNormalization(path)) {
			return new RootedDirectoryPath(Tspath.rootedFilePathFromResolved(Tspath.appendPathToDirectory(abstract, path)));
		}
		if (Tspath.isNormalizedSlashesRelativePath(path)) {
			final resolved = Tspath.appendPathWithLeadingDotSegments(abstract, path);
			if (resolved != null) {
				return new RootedDirectoryPath(Tspath.rootedFilePathFromResolved(resolved));
			}
			return new RootedDirectoryPath(Tspath.rootedFilePathFromResolved(Tspath.getNormalizedAbsolutePathFromNormalizedSlashes(Tspath.appendPathToDirectory(abstract,
				path))));
		}
		return Tspath.ToRootedDirectoryPath(path, abstract);
	}

	// PORT: Go's callback returns (result T, stop bool) and the function (result T, ok bool): ValueOk.
	public function ForEachAncestorDirectory<T>(callback:(directory:RootedDirectoryPath) -> ValueOk<T>):ValueOk<T> {
		var directory:RootedDirectoryPath = abstract;
		while (true) {
			final r = callback(directory);
			if (r.ok) {
				return r;
			}
			final parent = new RootedDirectoryPath(Tspath.getDirectoryPathFromNormalized(directory.AsString()));
			if (parent == directory) {
				return new ValueOk<T>(null, false);
			}
			directory = parent;
		}
	}
}
