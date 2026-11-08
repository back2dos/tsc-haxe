package ts.tspath;

import go.Strings;
import ts.stringutil.Stringutil;

// Port of internal/tspath CaseSensitivity (path.go) and its methods from pathkey.go, rooted_path.go and
// relative_path.go.
//
// CaseSensitivity controls canonical path identity and comparison.
// Its zero value is CaseInsensitive.
// PORT: Go `uint8` with iota values; here an enum abstract over Bool (false = CaseInsensitive, the Go zero
// value). No implicit conversion to or from Bool: Go's old `ignoreCase bool` parameters had the opposite
// meaning.
enum abstract CaseSensitivity(Bool) {
	var CaseInsensitive = false;
	var CaseSensitive = true;

	// --- path.go ---

	public inline function IsCaseSensitive():Bool {
		return this;
	}

	public inline function IsCaseInsensitive():Bool {
		return !this;
	}

	// Canonicalize applies c to text used for path comparison or keys.
	public inline function Canonicalize(text:String):String {
		return this ? text : Tspath.ToFileNameLowerCase(text);
	}

	// TrimPrefix removes prefix from text according to c. It
	// returns text unchanged and false when the prefix does not match.
	//
	// This must not slice text using len(prefix): canonicalization can change a
	// string's UTF-8 byte length without changing its rune count.
	// PORT: (string, bool) -> null when !ok.
	public function TrimPrefix(text:String, prefix:String):Null<String> {
		if (IsCaseSensitive()) {
			return StringTools.startsWith(text, prefix) ? text.substring(prefix.length) : null;
		}
		final canonicalPrefix = Canonicalize(prefix);
		if (!StringTools.startsWith(Canonicalize(text), canonicalPrefix)) {
			return null;
		}
		return Tspath.trimRuneCount(text, Tspath.runeCount(canonicalPrefix));
	}

	// PORT: Go String() (fmt.Stringer).
	public function toString():String {
		return this ? "true" : "false";
	}

	public inline function GetComparer():(a:String, b:String) -> Int {
		return Stringutil.GetStringComparer(!IsCaseSensitive());
	}

	@:allow(ts.tspath)
	inline function getEqualityComparer():(a:String, b:String) -> Bool {
		return Stringutil.GetStringEqualityComparer(!IsCaseSensitive());
	}

	// --- pathkey.go ---

	// PathKey returns the canonical key for an already rooted, normalized path
	// under c.
	public inline function PathKey(path:RootedPath):PathKey {
		return Tspath.pathKeyOf(path.AsString(), abstract);
	}

	// --- rooted_path.go ---

	// PORT: (before, through, ok) -> null when !ok.
	public function SplitFilePathAtComponent(fileName:RootedFilePath, component:String):Null<SplitDirectories> {
		if (component == "" || Strings.IndexAny(component, "/\\") >= 0 || component == "." || component == "..") {
			throw "invalid path component";
		}
		final components = Tspath.GetPathComponents(fileName.AsString());
		var c = abstract;
		if (Tspath.IsEncodedDynamicFileName(fileName.AsString())) {
			c = CaseSensitive;
		}
		final comparer = c.GetComparer();
		for (i in 1...components.length) {
			if (comparer(components[i], component) == 0) {
				return new SplitDirectories(new RootedDirectoryPath(Tspath.GetPathFromPathComponents(components.slice(0, i))),
					new RootedDirectoryPath(Tspath.GetPathFromPathComponents(components.slice(0, i + 1))));
			}
		}
		return null;
	}

	// CompareFilePaths compares already rooted and normalized file names without
	// combining or reducing their path components.
	public inline function CompareFilePaths(a:RootedFilePath, b:RootedFilePath):Int {
		return ComparePaths(a.AsPath(), b.AsPath());
	}

	// ComparePaths compares already rooted and normalized paths without combining
	// or reducing their path components.
	public inline function ComparePaths(a:RootedPath, b:RootedPath):Int {
		return compareRootedText(a.AsString(), b.AsString());
	}

	// CompareFileNameStems compares filename prefixes without interpreting dot
	// components produced by extension removal as directory traversal.
	public inline function CompareFileNameStems(a:FileNameStem, b:FileNameStem):Int {
		return compareRootedText(a.AsString(), b.AsString());
	}

	function compareRootedText(aString:String, bString:String):Int {
		if (aString == bString) {
			return 0;
		}
		if (aString == "") {
			return -1;
		}
		if (bString == "") {
			return 1;
		}

		if (Tspath.IsEncodedDynamicFileName(aString) || Tspath.IsEncodedDynamicFileName(bString)) {
			return Stringutil.CompareStringsCaseSensitive(Tspath.canonicalDynamicURIPath(aString), Tspath.canonicalDynamicURIPath(bString));
		}
		final aRootLength = Tspath.GetRootLength(aString);
		final bRootLength = Tspath.GetRootLength(bString);
		final result = Stringutil.CompareStringsCaseInsensitive(aString.substring(0, aRootLength), bString.substring(0, bRootLength));
		if (result != 0) {
			return result;
		}
		return GetComparer()(aString.substring(aRootLength), bString.substring(bRootLength));
	}

	public inline function ContainsFilePath(parent:RootedDirectoryPath, child:RootedFilePath):Bool {
		return ContainsPath(parent, child.AsPath());
	}

	public inline function ContainsPath(parent:RootedDirectoryPath, child:RootedPath):Bool {
		return trimContainedPath(parent.AsString(), child.AsString()) != null;
	}

	public function StartsWithDirectory(fileName:RootedFilePath, directory:RootedDirectoryPath):Bool {
		final relative = trimContainedPath(directory.AsString(), fileName.AsString());
		return relative != null && relative != "";
	}

	// PORT: (RelativePath, bool) -> null when !ok.
	public inline function RelativeFilePathFromDirectory(directory:RootedDirectoryPath, fileName:RootedFilePath):Null<RelativePath> {
		return RelativePathWithinDirectory(directory, fileName.AsPath());
	}

	// PORT: (RelativePath, bool) -> null when !ok.
	public inline function RelativePathWithinDirectory(directory:RootedDirectoryPath, path:RootedPath):Null<RelativePath> {
		return cast trimContainedPath(directory.AsString(), path.AsString());
	}

	// PORT: (string, bool) -> null when !ok.
	@:allow(ts.tspath)
	function trimContainedPath(parent:String, child:String):Null<String> {
		if (parent == "" || child == "") {
			return null;
		}
		final parentRootLength = Tspath.GetRootLength(parent);
		final childRootLength = Tspath.GetRootLength(child);
		var c = abstract;
		final dynamic_ = Tspath.IsEncodedDynamicFileName(parent) || Tspath.IsEncodedDynamicFileName(child);
		var rootsEqual:Bool;
		if (dynamic_) {
			final parentRoot = Strings.TrimSuffix(parent.substring(0, parentRootLength), "/");
			final childRoot = Strings.TrimSuffix(child.substring(0, childRootLength), "/");
			c = CaseSensitive;
			rootsEqual = parentRoot == childRoot;
		} else {
			// PORT: perf — the roots compared in place (usually "/" against "/")
			rootsEqual = (parentRootLength == childRootLength && Tspath.regionEquals(parent, child, 0, parentRootLength))
				|| Stringutil.EquateStringCaseInsensitive(parent.substring(0, parentRootLength), child.substring(0, childRootLength));
		}
		if (!rootsEqual) {
			return null;
		}
		final relative = c.TrimPrefix(child.substring(childRootLength), parent.substring(parentRootLength));
		if (relative == null
			|| relative != ""
			&& !Tspath.HasTrailingDirectorySeparator(parent)
			&& parent.length != parentRootLength
			&& StringTools.fastCodeAt(relative, 0) != Tspath.DirectorySeparator) {
			return null;
		}
		return Strings.TrimPrefix(relative, "/");
	}

	// CommonDirectoryOfFiles returns the deepest directory containing every file.
	// It preserves the spelling of the first file name.
	public function CommonDirectoryOfFiles(fileNames:Array<RootedFilePath>):RootedDirectoryPath {
		var commonPathComponents:Array<String> = null;
		for (fileName in fileNames) {
			var pathComponents = Tspath.GetPathComponents(fileName.AsString());
			pathComponents.pop();
			if (commonPathComponents == null) {
				commonPathComponents = pathComponents;
				continue;
			}

			final n = commonPathComponents.length < pathComponents.length ? commonPathComponents.length : pathComponents.length;
			var effectiveCaseSensitivity = abstract;
			if (Tspath.IsEncodedDynamicFileName(fileName.AsString())
				|| Tspath.IsEncodedDynamicFileName(Tspath.GetPathFromPathComponents(commonPathComponents))) {
				effectiveCaseSensitivity = CaseSensitive;
				commonPathComponents[0] = Strings.TrimSuffix(commonPathComponents[0], "/");
				pathComponents[0] = Strings.TrimSuffix(pathComponents[0], "/");
			}
			for (i in 0...n) {
				if (effectiveCaseSensitivity.Canonicalize(commonPathComponents[i]) != effectiveCaseSensitivity.Canonicalize(pathComponents[i])) {
					if (i == 0) {
						return new RootedDirectoryPath("");
					}
					commonPathComponents.resize(i);
					break;
				}
			}
			if (pathComponents.length < commonPathComponents.length) {
				commonPathComponents.resize(pathComponents.length);
			}
		}
		if (commonPathComponents == null || commonPathComponents.length == 0) {
			return new RootedDirectoryPath("");
		}
		return new RootedDirectoryPath(Tspath.GetPathFromPathComponents(commonPathComponents));
	}

	// --- relative_path.go ---

	public inline function CanonicalRelativePath(path:RelativePath):RelativePath {
		return new RelativePath(Canonicalize(path.AsString()));
	}

	// RelativePathFromDirectory returns the normalized path from directory to
	// fileName. It returns false when the paths have different roots.
	// PORT: (RelativePath, bool) -> null when !ok.
	public inline function RelativePathFromDirectory(directory:RootedDirectoryPath, fileName:RootedFilePath):Null<RelativePath> {
		return RelativePathFromPath(directory, fileName.AsPath());
	}

	// RelativePathFromPath returns the normalized path from directory to path.
	// It returns false when the paths have different roots.
	// PORT: (RelativePath, bool) -> null when !ok.
	public function RelativePathFromPath(directory:RootedDirectoryPath, rootedPath:RootedPath):Null<RelativePath> {
		final path = Tspath.relativePathFromNormalizedPaths(directory.AsString(), rootedPath.AsString(), abstract);
		if (Tspath.GetEncodedRootLength(path) != 0) {
			return null;
		}
		return new RelativePath(path);
	}

	// PORT: (RelativePath, bool) -> null when !ok.
	public inline function RelativePathFromFile(from:RootedFilePath, to:RootedFilePath):Null<RelativePath> {
		return RelativePathFromFileToPath(from, to.AsPath());
	}

	// PORT: (RelativePath, bool) -> null when !ok.
	public inline function RelativePathFromFileToPath(from:RootedFilePath, to:RootedPath):Null<RelativePath> {
		return RelativePathFromPath(from.Directory(), to);
	}

	public inline function RelativePathFromRelativeDirectory(directory:RelativePath, fileName:RelativePath):RelativePath {
		return new RelativePath(Tspath.relativePathFromNormalizedPaths(directory.AsString(), fileName.AsString(), abstract));
	}
}

// Go's (before, through RootedDirectoryPath, ok bool) results of the SplitAt* functions; null stands for !ok.
final class SplitDirectories {
	public final before:RootedDirectoryPath;
	public final through:RootedDirectoryPath;

	public inline function new(before:RootedDirectoryPath, through:RootedDirectoryPath) {
		this.before = before;
		this.through = through;
	}
}
