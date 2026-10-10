package ts.tspath;

import haxe.ds.StringMap;

// Go anonymous struct value of newGroups in getCommonParentsWorker.
private class CommonParentsGroup {
	public var head:Array<String> = null;
	public var tails:Array<Array<String>> = null;

	public function new(head:Array<String>, tails:Array<Array<String>>) {
		this.head = head;
		this.tails = tails;
	}
}

// Port of internal/tspath (package-level funcs, vars, consts).
@:allow(ts.tspath)
class Tspath {
	// Go builtins min/max.
	static inline function max(a:Int, b:Int):Int {
		return a > b ? a : b;
	}

	static inline function min(a:Int, b:Int):Int {
		return a < b ? a : b;
	}

	// --- extension.go ---

	public static inline final ExtensionTs = ".ts";
	public static inline final ExtensionTsx = ".tsx";
	public static inline final ExtensionDts = ".d.ts";
	public static inline final ExtensionJs = ".js";
	public static inline final ExtensionJsx = ".jsx";
	public static inline final ExtensionJson = ".json";
	public static inline final ExtensionTsBuildInfo = ".tsbuildinfo";
	public static inline final ExtensionMjs = ".mjs";
	public static inline final ExtensionMts = ".mts";
	public static inline final ExtensionDmts = ".d.mts";
	public static inline final ExtensionCjs = ".cjs";
	public static inline final ExtensionCts = ".cts";
	public static inline final ExtensionDcts = ".d.cts";

	public static final SupportedDeclarationExtensions:Array<String> = [ExtensionDts, ExtensionDcts, ExtensionDmts];
	public static final SupportedTSImplementationExtensions:Array<String> = [ExtensionTs, ExtensionTsx, ExtensionMts, ExtensionCts];
	static final supportedTSExtensionsForExtractExtension:Array<String> = [
		ExtensionDts, ExtensionDcts, ExtensionDmts, ExtensionTs, ExtensionTsx, ExtensionMts, ExtensionCts
	];
	public static final AllSupportedExtensions:Array<Array<String>> = [
		[ExtensionTs, ExtensionTsx, ExtensionDts, ExtensionJs, ExtensionJsx],
		[ExtensionCts, ExtensionDcts, ExtensionCjs],
		[ExtensionMts, ExtensionDmts, ExtensionMjs]
	];
	public static final SupportedTSExtensions:Array<Array<String>> = [
		[ExtensionTs, ExtensionTsx, ExtensionDts],
		[ExtensionCts, ExtensionDcts],
		[ExtensionMts, ExtensionDmts]
	];
	public static final SupportedTSExtensionsFlat:Array<String> = [
		ExtensionTs, ExtensionTsx, ExtensionDts, ExtensionCts, ExtensionDcts, ExtensionMts, ExtensionDmts
	];
	public static final SupportedJSExtensions:Array<Array<String>> = [[ExtensionJs, ExtensionJsx], [ExtensionMjs], [ExtensionCjs]];
	public static final SupportedJSExtensionsFlat:Array<String> = [ExtensionJs, ExtensionJsx, ExtensionMjs, ExtensionCjs];
	public static final AllSupportedExtensionsWithJson:Array<Array<String>> = AllSupportedExtensions.concat([[ExtensionJson]]);
	public static final SupportedTSExtensionsWithJson:Array<Array<String>> = SupportedTSExtensions.concat([[ExtensionJson]]);
	public static final SupportedTSExtensionsWithJsonFlat:Array<String> = SupportedTSExtensionsFlat.concat([ExtensionJson]);
	public static final ExtensionsNotSupportingExtensionlessResolution:Array<String> = [
		ExtensionMts, ExtensionDmts, ExtensionMjs, ExtensionCts, ExtensionDcts, ExtensionCjs
	];

	public static function ExtensionIsTs(ext:String):Bool {
		return ext == ExtensionTs || ext == ExtensionTsx || ext == ExtensionDts || ext == ExtensionMts || ext == ExtensionDmts || ext == ExtensionCts
			|| ext == ExtensionDcts || ext.length >= 7 && StringTools.startsWith(ext, ".d.") && StringTools.endsWith(ext, ".ts");
	}

	static final extensionsToRemove:Array<String> = [
		ExtensionDts, ExtensionDmts, ExtensionDcts, ExtensionMjs, ExtensionMts, ExtensionCjs, ExtensionCts, ExtensionTs, ExtensionJs, ExtensionTsx, ExtensionJsx,
		ExtensionJson
	];

	public static function RemoveFileExtension(path:String):String {
		// Remove any known extension even if it has more than one dot
		for (ext in extensionsToRemove) {
			if (StringTools.endsWith(path, ext)) {
				return path.substring(0, path.length - ext.length);
			}
		}

		return path;
	}

	public static function TryGetExtensionFromPath(p:String):String {
		for (ext in extensionsToRemove) {
			if (FileExtensionIs(p, ext)) {
				return ext;
			}
		}
		return "";
	}

	public static function RemoveExtension(path:String, extension:String):String {
		return path.substring(0, path.length - extension.length);
	}

	public static function FileExtensionIsOneOf(path:String, extensions:Array<String>):Bool {
		if (extensions == null)
			return false;
		for (ext in extensions) {
			if (FileExtensionIs(path, ext)) {
				return true;
			}
		}
		return false;
	}

	public static function TryExtractTSExtension(fileName:String):String {
		for (ext in supportedTSExtensionsForExtractExtension) {
			if (FileExtensionIs(fileName, ext)) {
				return ext;
			}
		}
		return "";
	}

	public static function HasTSFileExtension(path:String):Bool {
		return FileExtensionIsOneOf(path, SupportedTSExtensionsFlat);
	}

	public static function HasImplementationTSFileExtension(path:String):Bool {
		return FileExtensionIsOneOf(path, SupportedTSImplementationExtensions) && !IsDeclarationFileName(path);
	}

	public static function HasJSFileExtension(path:String):Bool {
		return FileExtensionIsOneOf(path, SupportedJSExtensionsFlat);
	}

	public static function HasJSONFileExtension(path:String):Bool {
		return FileExtensionIs(path, ExtensionJson);
	}

	public static function IsDeclarationFileName(fileName:String):Bool {
		return GetDeclarationFileExtension(fileName) != "";
	}

	public static function ExtensionIsOneOf(ext:String, extensions:Array<String>):Bool {
		return Slices.Contains(extensions, ext);
	}

	public static function GetDeclarationFileExtension(fileName:String):String {
		final base = GetBaseFileName(fileName);
		for (ext in SupportedDeclarationExtensions) {
			if (StringTools.endsWith(base, ext)) {
				return ext;
			}
		}
		if (StringTools.endsWith(base, ExtensionTs)) {
			final index = base.indexOf(".d.");
			if (index >= 0) {
				return base.substring(index);
			}
		}
		return "";
	}

	public static function GetDeclarationEmitExtensionForPath(path:String):String {
		if (FileExtensionIsOneOf(path, [ExtensionMjs, ExtensionMts])) {
			return ExtensionDmts;
		} else if (FileExtensionIsOneOf(path, [ExtensionCjs, ExtensionCts])) {
			return ExtensionDcts;
		} else if (FileExtensionIsOneOf(path, [ExtensionTs, ExtensionTsx, ExtensionJs, ExtensionJsx])) {
			return ExtensionDts;
		} else {
			final ext = GetAnyExtensionFromPath(path, null, false);
			if (ext != "") {
				return ".d" + ext + ".ts";
			}
			return ExtensionDts;
		}
	}

	// ChangeAnyExtension changes the extension of a path to the provided extension if it has one of the provided extensions.
	//
	// ChangeAnyExtension("/path/to/file.ext", ".js", ".ext") === "/path/to/file.js"
	// ChangeAnyExtension("/path/to/file.ext", ".js", ".ts") === "/path/to/file.ext"
	// ChangeAnyExtension("/path/to/file.ext", ".js", [".ext", ".ts"]) === "/path/to/file.js"
	public static function ChangeAnyExtension(path:String, ext:String, extensions:Array<String>, ignoreCase:Bool):String {
		final pathext = GetAnyExtensionFromPath(path, extensions, ignoreCase);
		if (pathext != "") {
			final result = path.substring(0, path.length - pathext.length);
			if (ext == "") {
				return result;
			}
			if (StringTools.startsWith(ext, ".")) {
				return result + ext;
			}
			return result + "." + ext;
		}
		return path;
	}

	public static function ChangeExtension(path:String, newExtension:String):String {
		return ChangeAnyExtension(path, newExtension, extensionsToRemove, false /*ignoreCase*/);
	}

	// Like `changeAnyExtension`, but declaration file extensions are recognized
	// and replaced starting from the `.d`.
	//
	//	changeAnyExtension("file.d.ts", ".js") === "file.d.js"
	//	changeFullExtension("file.d.ts", ".js") === "file.js"
	public static function ChangeFullExtension(path:String, newExtension:String):String {
		final declarationExtension = GetDeclarationFileExtension(path);
		if (declarationExtension != "") {
			var ext = newExtension;
			if (!StringTools.startsWith(ext, ".")) {
				ext = "." + ext;
			}
			return path.substring(0, path.length - declarationExtension.length) + ext;
		}
		return ChangeExtension(path, newExtension);
	}

	public static function GetPossibleOriginalInputExtensionForExtension(path:String):Array<String> {
		if (FileExtensionIsOneOf(path, [ExtensionDmts, ExtensionMjs, ExtensionMts])) {
			return [ExtensionMts, ExtensionMjs];
		}
		if (FileExtensionIsOneOf(path, [ExtensionDcts, ExtensionCjs, ExtensionCts])) {
			return [ExtensionCts, ExtensionCjs];
		}
		// Handle any custom .d.x.ts extension (e.g., .d.json.ts -> .json, .d.css.ts -> .css)
		final ext = GetDeclarationFileExtension(path);
		if (ext != "" && ext != ExtensionDts) {
			final inner = ext.substring(".d.".length, ext.length - ".ts".length);
			return ["." + inner];
		}
		return [ExtensionTsx, ExtensionTs, ExtensionJsx, ExtensionJs];
	}

	// --- ignoredpaths.go ---

	static final ignoredPaths:Array<String> = ["/node_modules/.", "/.git", ".#"];

	public static function ContainsIgnoredPath(path:String):Bool {
		for (pattern in ignoredPaths) {
			if (path.indexOf(pattern) >= 0) {
				return true;
			}
		}
		return false;
	}

	// --- path.go ---

	// Internally, we represent paths as strings with '/' as the directory separator.
	// When we make system calls (eg: LanguageServiceHost.getDirectory()),
	// we expect the host to correctly handle paths in our specified format.
	public static inline final DirectorySeparator = '/'.code;
	static inline final urlSchemeSeparator = "://";

	//// Path Tests

	// Determines whether a byte corresponds to `/` or `\`.
	static inline function isAnyDirectorySeparator(char:Int):Bool {
		return char == '/'.code || char == '\\'.code;
	}

	// Determines whether a path starts with a URL scheme (e.g. starts with `http://`, `ftp://`, `file://`, etc.).
	public static function IsUrl(path:String):Bool {
		return GetEncodedRootLength(path) < 0;
	}

	// Determines whether a path is an absolute disk path (e.g. starts with `/`, or a dos path
	// like `c:`, `c:\` or `c:/`).
	public static function IsRootedDiskPath(path:String):Bool {
		return GetEncodedRootLength(path) > 0;
	}

	// Determines whether a path consists only of a path root.
	public static function IsDiskPathRoot(path:String):Bool {
		final rootLength = GetEncodedRootLength(path);
		return rootLength > 0 && rootLength == path.length;
	}

	// IsDynamicFileName returns true if the file name represents a dynamic/virtual file
	// that doesn't exist on disk (e.g., untitled files with paths like "^/untitled/...").
	public static function IsDynamicFileName(fileName:String):Bool {
		return StringTools.startsWith(fileName, "^/");
	}

	// Determines whether a path starts with an absolute path component (i.e. `/`, `c:/`, `file://`, etc.).
	//
	//	```
	//	// POSIX
	//	PathIsAbsolute("/path/to/file.ext") === true
	//	// DOS
	//	PathIsAbsolute("c:/path/to/file.ext") === true
	//	// URL
	//	PathIsAbsolute("file:///path/to/file.ext") === true
	//	// Non-absolute
	//	PathIsAbsolute("path/to/file.ext") === false
	//	PathIsAbsolute("./path/to/file.ext") === false
	//	```
	public static function PathIsAbsolute(path:String):Bool {
		return GetEncodedRootLength(path) != 0;
	}

	public static function HasTrailingDirectorySeparator(path:String):Bool {
		return path.length > 0 && isAnyDirectorySeparator(StringTools.fastCodeAt(path, path.length - 1));
	}

	// Combines paths. If a path is absolute, it replaces any previous path. Relative paths are not simplified.
	//
	//	```
	//	// Non-rooted
	//	CombinePaths("path", "to", "file.ext") === "path/to/file.ext"
	//	CombinePaths("path", "dir", "..", "to", "file.ext") === "path/dir/../to/file.ext"
	//	// POSIX
	//	CombinePaths("/path", "to", "file.ext") === "/path/to/file.ext"
	//	CombinePaths("/path", "/to", "file.ext") === "/to/file.ext"
	//	// DOS
	//	CombinePaths("c:/path", "to", "file.ext") === "c:/path/to/file.ext"
	//	CombinePaths("c:/path", "c:/to", "file.ext") === "c:/to/file.ext"
	//	// URL
	//	CombinePaths("file:///path", "to", "file.ext") === "file:///path/to/file.ext"
	//	CombinePaths("file:///path", "file:///to", "file.ext") === "file:///to/file.ext"
	//	```
	public static function CombinePaths(firstPath:String, ...paths:String):String {
		// TODO (drosen): There is potential for a fast path here.
		// In the case where we find the last absolute path and just path.Join from there.
		firstPath = NormalizeSlashes(firstPath);

		// PORT: Go grows a strings.Builder and "sets" the result by moving a start offset
		// (a memory trick); here `result` is the current string itself. Same output.
		var result = firstPath;

		for (trailingPath in paths) {
			if (trailingPath == "") {
				continue;
			}
			trailingPath = NormalizeSlashes(trailingPath);
			if (result == "" || GetRootLength(trailingPath) != 0) {
				// `trailingPath` is absolute.
				result = trailingPath;
			} else {
				if (!HasTrailingDirectorySeparator(result)) {
					result += "/";
				}
				result += trailingPath;
			}
		}
		return result;
	}

	public static function GetPathComponents(path:String, currentDirectory:String):Array<String> {
		path = CombinePaths(currentDirectory, path);
		return pathComponents(path, GetRootLength(path));
	}

	static function pathComponents(path:String, rootLength:Int):Array<String> {
		final root = path.substring(0, rootLength);
		final rest = Strings.Split(path.substring(rootLength), "/");
		if (rest.length > 0 && rest[rest.length - 1] == "") {
			rest.pop();
		}
		rest.unshift(root);
		return rest;
	}

	public static inline function IsVolumeCharacter(char:Int):Bool {
		return char >= 'a'.code && char <= 'z'.code || char >= 'A'.code && char <= 'Z'.code;
	}

	static function getFileUrlVolumeSeparatorEnd(url:String, start:Int):Int {
		if (url.length <= start) {
			return -1;
		}
		final ch0 = StringTools.fastCodeAt(url, start);
		if (ch0 == ':'.code) {
			return start + 1;
		}
		if (ch0 == '%'.code && url.length > start + 2 && StringTools.fastCodeAt(url, start + 1) == '3'.code) {
			final ch2 = StringTools.fastCodeAt(url, start + 2);
			if (ch2 == 'a'.code || ch2 == 'A'.code) {
				return start + 3;
			}
		}
		return -1;
	}

	public static function GetEncodedRootLength(path:String):Int {
		final ln = path.length;
		if (ln == 0) {
			return 0;
		}
		final ch0 = StringTools.fastCodeAt(path, 0);

		// POSIX or UNC
		if (ch0 == '/'.code || ch0 == '\\'.code) {
			if (ln == 1 || StringTools.fastCodeAt(path, 1) != ch0) {
				return 1; // POSIX: "/" (or non-normalized "\")
			}

			final offset = 2;
			var p1 = path.indexOf(ch0 == '/'.code ? "/" : "\\", offset);
			if (p1 < 0) {
				return ln; // UNC: "//server" or "\\server"
			}
			p1 -= offset; // PORT: indexOf is absolute; Go indexes path[offset:]

			return p1 + offset + 1; // UNC: "//server/" or "\\server\"
		}

		// DOS
		if (IsVolumeCharacter(ch0) && ln > 1 && StringTools.fastCodeAt(path, 1) == ':'.code) {
			if (ln == 2) {
				return 2; // DOS: "c:" (but not "c:d")
			}
			final ch2 = StringTools.fastCodeAt(path, 2);
			if (ch2 == '/'.code || ch2 == '\\'.code) {
				return 3; // DOS: "c:/" or "c:\"
			}
		}

		// Untitled paths (e.g., "^/untitled/ts-nul-authority/Untitled-1")
		if (ch0 == '^'.code && ln > 1 && StringTools.fastCodeAt(path, 1) == '/'.code) {
			return 2; // Untitled: "^/"
		}

		// URL
		final schemeEnd = path.indexOf(urlSchemeSeparator);
		if (schemeEnd != -1) {
			final authorityStart = schemeEnd + urlSchemeSeparator.length;
			var authorityLength = path.indexOf("/", authorityStart);
			if (authorityLength != -1) { // URL: "file:///", "file://server/", "file://server/path"
				authorityLength -= authorityStart; // PORT: indexOf is absolute; Go indexes path[authorityStart:]
				final authorityEnd = authorityStart + authorityLength;

				// For local "file" URLs, include the leading DOS volume (if present).
				// Per https://www.ietf.org/rfc/rfc1738.txt, a host of "" or "localhost" is a
				// special case interpreted as "the machine from which the URL is being interpreted".
				final scheme = path.substring(0, schemeEnd);
				final authority = path.substring(authorityStart, authorityEnd);
				if (scheme == "file"
					&& (authority == "" || authority == "localhost")
					&& (path.length > authorityEnd + 2)
					&& IsVolumeCharacter(StringTools.fastCodeAt(path, authorityEnd + 1))) {
					final volumeSeparatorEnd = getFileUrlVolumeSeparatorEnd(path, authorityEnd + 2);
					if (volumeSeparatorEnd != -1) {
						if (volumeSeparatorEnd == path.length) {
							// URL: "file:///c:", "file://localhost/c:", "file:///c$3a", "file://localhost/c%3a"
							// but not "file:///c:d" or "file:///c%3ad"
							return ~volumeSeparatorEnd;
						}
						if (StringTools.fastCodeAt(path, volumeSeparatorEnd) == '/'.code) {
							// URL: "file:///c:/", "file://localhost/c:/", "file:///c%3a/", "file://localhost/c%3a/"
							return ~(volumeSeparatorEnd + 1);
						}
					}
				}
				return ~(authorityEnd + 1); // URL: "file://server/", "http://server/"
			}
			return ~ln; // URL: "file://server", "http://server"
		}

		// relative
		return 0;
	}

	public static function GetRootLength(path:String):Int {
		final rootLength = GetEncodedRootLength(path);
		if (rootLength < 0) {
			return ~rootLength;
		}
		return rootLength;
	}

	public static function GetDirectoryPath(path:String):String {
		path = NormalizeSlashes(path);

		// If the path provided is itself a root, then return it.
		final rootLength = GetRootLength(path);
		if (rootLength == path.length) {
			return path;
		}

		// return the leading portion of the path up to the last (non-terminal) directory separator
		// but not including any trailing directory separator.
		path = RemoveTrailingDirectorySeparator(path);
		return path.substring(0, max(rootLength, path.lastIndexOf("/")));
	}

	public static function GetPathFromPathComponents(pathComponents:Array<String>):String {
		if (pathComponents == null || pathComponents.length == 0) {
			return "";
		}

		var root = pathComponents[0];
		if (root != "") {
			root = EnsureTrailingDirectorySeparator(root);
		}

		// PORT: strings.Join(pathComponents[1:], "/") without the slice copy.
		final b = new StringBuf();
		b.add(root);
		for (i in 1...pathComponents.length) {
			if (i > 1)
				b.add("/");
			b.add(pathComponents[i]);
		}
		return b.toString();
	}

	public static inline function NormalizeSlashes(path:String):String {
		return Strings.ReplaceAll(path, "\\", "/");
	}

	static function reducePathComponents(components:Array<String>):Array<String> {
		if (components == null || components.length == 0) {
			return [];
		}
		final reduced = [components[0]];
		var i = 1;
		while (i < components.length) {
			final component = components[i];
			i++;
			if (component == "") {
				continue;
			}
			if (component == ".") {
				continue;
			}
			if (component == "..") {
				if (reduced.length > 1) {
					if (reduced[reduced.length - 1] != "..") {
						reduced.pop();
						continue;
					}
				} else if (reduced[0] != "") {
					continue;
				}
			}
			reduced.push(component);
		}
		return reduced;
	}

	// Combines and resolves paths. If a path is absolute, it replaces any previous path. Any
	// `.` and `..` path components are resolved. Trailing directory separators are preserved.
	//
	// ```go
	// resolvePath("/path", "to", "file.ext") == "path/to/file.ext"
	// resolvePath("/path", "to", "file.ext/") == "path/to/file.ext/"
	// resolvePath("/path", "dir", "..", "to", "file.ext") == "path/to/file.ext"
	// ```
	public static function ResolvePath(path:String, ...paths:String):String {
		var combinedPath:String;
		if (paths.length > 0) {
			combinedPath = CombinePaths(path, ...paths);
		} else {
			combinedPath = NormalizeSlashes(path);
		}
		return NormalizePath(combinedPath);
	}

	public static function ResolveTripleslashReference(moduleName:String, containingFile:String):String {
		final basePath = GetDirectoryPath(containingFile);
		if (IsRootedDiskPath(moduleName)) {
			return NormalizePath(moduleName);
		}
		return NormalizePath(CombinePaths(basePath, moduleName));
	}

	public static function GetNormalizedPathComponents(path:String, currentDirectory:String):Array<String> {
		final combined = CombinePaths(currentDirectory, path);
		return getNormalizedPathComponentsFromCombined(combined);
	}

	static function getNormalizedPathComponentsFromCombined(path:String):Array<String> {
		final rootLength = GetRootLength(path);
		// Always include the root component (empty string for relative paths).
		final components = [path.substring(0, rootLength)];

		var i = rootLength;
		while (i < path.length) {
			// Skip directory separators (handles consecutive separators and trailing '/').
			while (i < path.length && StringTools.fastCodeAt(path, i) == '/'.code) {
				i++;
			}
			if (i >= path.length) {
				break;
			}

			final start = i;
			while (i < path.length && StringTools.fastCodeAt(path, i) != '/'.code) {
				i++;
			}
			final component = path.substring(start, i);

			if (component == "" || component == ".") {
				continue;
			}
			if (component == "..") {
				if (components.length > 1) {
					if (components[components.length - 1] != "..") {
						components.pop();
						continue;
					}
				} else if (components[0] != "") {
					// If this is an absolute path, we can't go above the root.
					continue;
				}
			}

			components.push(component);
		}

		return components;
	}

	public static function GetNormalizedAbsolutePathWithoutRoot(fileName:String, currentDirectory:String):String {
		final absolutePath = GetNormalizedAbsolutePath(fileName, currentDirectory);
		final rootLength = GetRootLength(absolutePath);
		return absolutePath.substring(rootLength);
	}

	// PORT: strings.LastIndexByte(s[:end], '/') without the slice (end may be 0).
	static inline function lastIndexOfSlash(s:String, end:Int):Int {
		var i = end - 1;
		while (i >= 0 && StringTools.fastCodeAt(s, i) != '/'.code)
			i--;
		return i;
	}

	public static function GetNormalizedAbsolutePath(fileName:String, currentDirectory:String):String {
		var rootLength = GetRootLength(fileName);
		if (rootLength == 0 && currentDirectory != "") {
			fileName = CombinePaths(currentDirectory, fileName);
		} else {
			// CombinePaths normalizes slashes, so not necessary in other branch
			fileName = NormalizeSlashes(fileName);
		}
		rootLength = GetRootLength(fileName);

		final simpleNormalized = simpleNormalizePath(fileName);
		if (simpleNormalized != null) {
			final length = simpleNormalized.length;
			if (length > rootLength) {
				return RemoveTrailingDirectorySeparator(simpleNormalized);
			}
			if (length == rootLength && rootLength != 0) {
				return EnsureTrailingDirectorySeparator(simpleNormalized);
			}
			return simpleNormalized;
		}

		final length = fileName.length;
		final root = fileName.substring(0, rootLength);
		// `normalized` is only initialized once `fileName` is determined to be non-normalized.
		// `changed` is set at the same time.
		var changed = false;
		var normalized = "";
		var segmentStart = 0;
		var index = rootLength;
		var normalizedUpTo = index;
		var seenNonDotDotSegment = rootLength != 0;
		while (index < length) {
			// At beginning of segment
			segmentStart = index;
			var ch = StringTools.fastCodeAt(fileName, index);
			while (ch == '/'.code) {
				index++;
				if (index < length) {
					ch = StringTools.fastCodeAt(fileName, index);
				} else {
					break;
				}
			}
			if (index > segmentStart) {
				// Seen superfluous separator
				if (!changed) {
					normalized = fileName.substring(0, max(rootLength, segmentStart - 1));
					changed = true;
				}
				if (index == length) {
					break;
				}
				segmentStart = index;
			}
			// Past any superfluous separators
			var segmentEnd = fileName.indexOf("/", index + 1);
			if (segmentEnd == -1) {
				segmentEnd = length;
			} // PORT: else branch dropped, indexOf is already absolute (Go: segmentEnd += index + 1)
			final segmentLength = segmentEnd - segmentStart;
			if (segmentLength == 1 && StringTools.fastCodeAt(fileName, index) == '.'.code) {
				// "." segment (skip)
				if (!changed) {
					normalized = fileName.substring(0, normalizedUpTo);
					changed = true;
				}
			} else if (segmentLength == 2
				&& StringTools.fastCodeAt(fileName, index) == '.'.code
				&& StringTools.fastCodeAt(fileName, index + 1) == '.'.code) {
				// ".." segment
				if (!seenNonDotDotSegment) {
					if (changed) {
						if (normalized.length == rootLength) {
							normalized += "..";
						} else {
							normalized += "/..";
						}
					} else {
						normalizedUpTo = index + 2;
					}
				} else if (!changed) {
					if (normalizedUpTo - 1 >= 0) {
						normalized = fileName.substring(0, max(rootLength, lastIndexOfSlash(fileName, normalizedUpTo - 1)));
					} else {
						normalized = fileName.substring(0, normalizedUpTo);
					}
					changed = true;
					seenNonDotDotSegment = (normalized.length != rootLength || rootLength != 0)
						&& normalized != ".."
						&& !StringTools.endsWith(normalized, "/..");
				} else {
					final lastSlash = normalized.lastIndexOf("/");
					if (lastSlash != -1) {
						normalized = normalized.substring(0, max(rootLength, lastSlash));
					} else {
						normalized = root;
					}
					seenNonDotDotSegment = (normalized.length != rootLength || rootLength != 0)
						&& normalized != ".."
						&& !StringTools.endsWith(normalized, "/..");
				}
			} else if (changed) {
				if (normalized.length != rootLength) {
					normalized += "/";
				}
				seenNonDotDotSegment = true;
				normalized += fileName.substring(segmentStart, segmentEnd);
			} else {
				seenNonDotDotSegment = true;
				normalizedUpTo = segmentEnd;
			}
			index = segmentEnd + 1;
		}
		if (changed) {
			return normalized;
		}
		if (length > rootLength) {
			return RemoveTrailingDirectorySeparators(fileName);
		}
		if (length == rootLength) {
			return EnsureTrailingDirectorySeparator(fileName);
		}
		return fileName;
	}

	// PORT: Go returns (string, bool); here null means !ok (hot path, no result object).
	static function simpleNormalizePath(path:String):Null<String> {
		// Most paths don't require normalization
		if (!hasRelativePathSegment(path)) {
			return path;
		}
		// Some paths only require cleanup of `/./` or leading `./`
		final simplified = Strings.ReplaceAll(path, "/./", "/");
		final trimmed = Strings.TrimPrefix(simplified, "./");
		if (trimmed != path && !hasRelativePathSegment(trimmed) && !(trimmed != simplified && StringTools.startsWith(trimmed, "/"))) {
			// If we trimmed a leading "./" and the path now starts with "/", we changed the meaning
			path = trimmed;
			return path;
		}
		return null;
	}

	// hasRelativePathSegment reports whether p contains ".", "..", "./", "../", "/.", "/..", "//", "/./", or "/../".
	static function hasRelativePathSegment(p:String):Bool {
		final n = p.length;
		if (n == 0) {
			return false;
		}

		if (p == "." || p == "..") {
			return true;
		}

		// Leading "./" OR "../"
		if (StringTools.fastCodeAt(p, 0) == '.'.code) {
			if (n >= 2 && StringTools.fastCodeAt(p, 1) == '/'.code) {
				return true;
			}
			// Leading "../"
			if (n >= 3 && StringTools.fastCodeAt(p, 1) == '.'.code && StringTools.fastCodeAt(p, 2) == '/'.code) {
				return true;
			}
		}
		// Trailing "/." OR "/.."
		if (StringTools.fastCodeAt(p, n - 1) == '.'.code) {
			if (n >= 2 && StringTools.fastCodeAt(p, n - 2) == '/'.code) {
				return true;
			}
			if (n >= 3 && StringTools.fastCodeAt(p, n - 2) == '.'.code && StringTools.fastCodeAt(p, n - 3) == '/'.code) {
				return true;
			}
		}

		// Now look for any `//` or `/./` or `/../`

		var prevSlash = false;
		var segLen = 0; // length of current segment since last slash
		var dotCount = 0; // consecutive dots at start of the current segment; -1 => not only dots

		for (i in 0...n) {
			final c = StringTools.fastCodeAt(p, i);
			if (c == '/'.code) {
				// "//"
				if (prevSlash) {
					return true;
				}
				// "/./" or "/../"
				if ((segLen == 1 && dotCount == 1) || (segLen == 2 && dotCount == 2)) {
					return true;
				}
				prevSlash = true;
				segLen = 0;
				dotCount = 0;
				continue;
			}

			if (c == '.'.code) {
				if (dotCount >= 0) {
					dotCount++;
				}
			} else {
				dotCount = -1;
			}
			segLen++;
			prevSlash = false;
		}

		// Trailing "/." or "/.."
		return (segLen == 1 && dotCount == 1) || (segLen == 2 && dotCount == 2);
	}

	public static function NormalizePath(path:String):String {
		path = NormalizeSlashes(path);
		final simple = simpleNormalizePath(path);
		if (simple != null) {
			return simple;
		}
		var normalized = GetNormalizedAbsolutePath(path, "");
		if (normalized != "" && HasTrailingDirectorySeparator(path)) {
			normalized = EnsureTrailingDirectorySeparator(normalized);
		}
		return normalized;
	}

	public static function GetCanonicalFileName(fileName:String, useCaseSensitiveFileNames:Bool):String {
		if (useCaseSensitiveFileNames) {
			return fileName;
		}
		return ToFileNameLowerCase(fileName);
	}

	// We convert the file names to lower case as key for file name on case insensitive file system
	// While doing so we need to handle special characters (eg \u0130) to ensure that we dont convert
	// it to lower case, fileName with its lowercase form can exist along side it.
	// Handle special characters and make those case sensitive instead
	//
	// |-#--|-Unicode--|-Char code-|-Desc-------------------------------------------------------------------|
	// | 1. | i        | 105       | Ascii i                                                                |
	// | 2. | I        | 73        | Ascii I                                                                |
	// |-------- Special characters ------------------------------------------------------------------------|
	// | 3. | \u0130   | 304       | Upper case I with dot above                                            |
	// | 4. | i,\u0307 | 105,775   | i, followed by 775: Lower case of (3rd item)                           |
	// | 5. | I,\u0307 | 73,775    | I, followed by 775: Upper case of (4th item), lower case is (4th item) |
	// | 6. | \u0131   | 305       | Lower case i without dot, upper case is I (2nd item)                   |
	// | 7. | \u00DF   | 223       | Lower case sharp s                                                     |
	//
	// Because item 3 is special where in its lowercase character has its own
	// upper case form we cant convert its case.
	// Rest special characters are either already in lower case format or
	// they have corresponding upper case character so they dont need special handling

	public static function ToFileNameLowerCase(fileName:String):String {
		final IWithDot = 0x0130;

		var ascii = true;
		var needsLower = false;
		final fileNameLen = fileName.length;
		for (i in 0...fileNameLen) {
			final c = StringTools.fastCodeAt(fileName, i);
			if (c >= 0x80) {
				ascii = false;
				break;
			}
			if ('A'.code <= c && c <= 'Z'.code) {
				needsLower = true;
			}
		}
		if (ascii) {
			if (!needsLower) {
				return fileName;
			}
			// PORT: Go lowers A-Z in a byte buffer and aliases it (unsafe.String); the string is
			// ASCII-only here, so String.toLowerCase gives the same result.
			return fileName.toLowerCase();
		}

		return Strings.Map(function(r:Int):Int {
			if (r == IWithDot) {
				return r;
			}
			return Unicode.ToLower(r);
		}, fileName);
	}

	public static function ToPath(fileName:String, basePath:String, useCaseSensitiveFileNames:Bool):Path {
		var nonCanonicalizedPath:String;
		if (IsRootedDiskPath(fileName)) {
			nonCanonicalizedPath = NormalizePath(fileName);
		} else {
			nonCanonicalizedPath = GetNormalizedAbsolutePath(fileName, basePath);
		}
		return GetCanonicalFileName(nonCanonicalizedPath, useCaseSensitiveFileNames);
	}

	public static function RemoveTrailingDirectorySeparator(path:String):String {
		if (HasTrailingDirectorySeparator(path)) {
			return path.substring(0, path.length - 1);
		}
		return path;
	}

	public static function RemoveTrailingDirectorySeparators(path:String):String {
		while (HasTrailingDirectorySeparator(path)) {
			path = RemoveTrailingDirectorySeparator(path);
		}
		return path;
	}

	public static function EnsureTrailingDirectorySeparator(path:String):String {
		if (!HasTrailingDirectorySeparator(path)) {
			return path + "/";
		}

		return path;
	}

	//// Relative Paths

	public static function GetPathComponentsRelativeTo(from:String, to:String, options:ComparePathsOptions):Array<String> {
		final fromComponents = reducePathComponents(GetPathComponents(from, options.CurrentDirectory));
		final toComponents = reducePathComponents(GetPathComponents(to, options.CurrentDirectory));

		var start = 0;
		final maxCommonComponents = min(fromComponents.length, toComponents.length);
		final stringEqualer = options.getEqualityComparer();
		while (start < maxCommonComponents) {
			final fromComponent = fromComponents[start];
			final toComponent = toComponents[start];
			if (start == 0) {
				if (!Stringutil.EquateStringCaseInsensitive(fromComponent, toComponent)) {
					break;
				}
			} else {
				if (!stringEqualer(fromComponent, toComponent)) {
					break;
				}
			}
			start++;
		}

		if (start == 0) {
			return toComponents;
		}

		final numDotDotSlashes = fromComponents.length - start;
		final result = new Array<String>();
		result.resize(1 + numDotDotSlashes + toComponents.length - start);

		result[0] = "";
		var i = 1;
		// Add all the relative components until we hit a common directory.
		for (_ in 0...numDotDotSlashes) {
			result[i] = "..";
			i++;
		}
		// Now add all the remaining components of the "to" path.
		for (j in start...toComponents.length) {
			result[i] = toComponents[j];
			i++;
		}

		return result;
	}

	public static function GetRelativePathFromDirectory(fromDirectory:String, to:String, options:ComparePathsOptions):String {
		if ((GetRootLength(fromDirectory) > 0) != (GetRootLength(to) > 0)) {
			throw "paths must either both be absolute or both be relative";
		}
		final pathComponents = GetPathComponentsRelativeTo(fromDirectory, to, options);
		return GetPathFromPathComponents(pathComponents);
	}

	public static function GetRelativePathFromFile(from:String, to:String, options:ComparePathsOptions):String {
		return EnsurePathIsNonModuleName(GetRelativePathFromDirectory(GetDirectoryPath(from), to, options));
	}

	public static function ConvertToRelativePath(absoluteOrRelativePath:String, options:ComparePathsOptions):String {
		if (!IsRootedDiskPath(absoluteOrRelativePath)) {
			return absoluteOrRelativePath;
		}

		return GetRelativePathToDirectoryOrUrl(options.CurrentDirectory, absoluteOrRelativePath, false /*isAbsolutePathAnUrl*/, options);
	}

	public static function GetRelativePathToDirectoryOrUrl(directoryPathOrUrl:String, relativeOrAbsolutePath:String, isAbsolutePathAnUrl:Bool,
			options:ComparePathsOptions):String {
		final pathComponents = GetPathComponentsRelativeTo(directoryPathOrUrl, relativeOrAbsolutePath, options);

		final firstComponent = pathComponents[0];
		if (isAbsolutePathAnUrl && IsRootedDiskPath(firstComponent)) {
			var prefix:String;
			if (StringTools.fastCodeAt(firstComponent, 0) == DirectorySeparator) {
				prefix = "file://";
			} else {
				prefix = "file:///";
			}
			pathComponents[0] = prefix + firstComponent;
		}

		return GetPathFromPathComponents(pathComponents);
	}

	// Gets the portion of a path following the last (non-terminal) separator (`/`).
	// Semantics align with NodeJS's `path.basename` except that we support URL's as well.
	// If the base name has any one of the provided extensions, it is removed.
	//
	//	// POSIX
	//	GetBaseFileName("/path/to/file.ext") == "file.ext"
	//	GetBaseFileName("/path/to/") == "to"
	//	GetBaseFileName("/") == ""
	//	// DOS
	//	GetBaseFileName("c:/path/to/file.ext") == "file.ext"
	//	GetBaseFileName("c:/path/to/") == "to"
	//	GetBaseFileName("c:/") == ""
	//	GetBaseFileName("c:") == ""
	//	// URL
	//	GetBaseFileName("http://typescriptlang.org/path/to/file.ext") == "file.ext"
	//	GetBaseFileName("http://typescriptlang.org/path/to/") == "to"
	//	GetBaseFileName("http://typescriptlang.org/") == ""
	//	GetBaseFileName("http://typescriptlang.org") == ""
	//	GetBaseFileName("file://server/path/to/file.ext") == "file.ext"
	//	GetBaseFileName("file://server/path/to/") == "to"
	//	GetBaseFileName("file://server/") == ""
	//	GetBaseFileName("file://server") == ""
	//	GetBaseFileName("file:///path/to/file.ext") == "file.ext"
	//	GetBaseFileName("file:///path/to/") == "to"
	//	GetBaseFileName("file:///") == ""
	//	GetBaseFileName("file://") == ""
	public static function GetBaseFileName(path:String):String {
		path = NormalizeSlashes(path);

		// if the path provided is itself the root, then it has no file name.
		final rootLength = GetRootLength(path);
		if (rootLength == path.length) {
			return "";
		}

		// return the trailing portion of the path starting after the last (non-terminal) directory
		// separator but not including any trailing directory separator.
		path = RemoveTrailingDirectorySeparator(path);
		return path.substring(max(GetRootLength(path), path.lastIndexOf("/") + 1));
	}

	// Gets the file extension for a path.
	// If extensions are provided, gets the file extension for a path, provided it is one of the provided extensions.
	//
	//	GetAnyExtensionFromPath("/path/to/file.ext", nil, false) == ".ext"
	//	GetAnyExtensionFromPath("/path/to/file.ext/", nil, false) == ".ext"
	//	GetAnyExtensionFromPath("/path/to/file", nil, false) == ""
	//	GetAnyExtensionFromPath("/path/to.ext/file", nil, false) == ""
	//	GetAnyExtensionFromPath("/path/to/file.ext", ".ext", true) === ".ext"
	//	GetAnyExtensionFromPath("/path/to/file.js", ".ext", true) === ""
	//	GetAnyExtensionFromPath("/path/to/file.js", [".ext", ".js"], true) === ".js"
	//	GetAnyExtensionFromPath("/path/to/file.ext", ".EXT", false) === ""
	public static function GetAnyExtensionFromPath(path:String, extensions:Array<String>, ignoreCase:Bool):String {
		// Retrieves any string from the final "." onwards from a base file name.
		// Unlike extensionFromPath, which throws an exception on unrecognized extensions.
		if (extensions != null && extensions.length > 0) {
			return getAnyExtensionFromPathWorker(RemoveTrailingDirectorySeparator(path), extensions, Stringutil.GetStringEqualityComparer(ignoreCase));
		}

		final baseFileName = GetBaseFileName(path);
		final extensionIndex = baseFileName.lastIndexOf(".");
		if (extensionIndex >= 0) {
			return baseFileName.substring(extensionIndex);
		}
		return "";
	}

	static function getAnyExtensionFromPathWorker(path:String, extensions:Array<String>, stringEqualityComparer:(a:String, b:String) -> Bool):String {
		for (extension in extensions) {
			final result = tryGetExtensionFromPath(path, extension, stringEqualityComparer);
			if (result != "") {
				return result;
			}
		}
		return "";
	}

	static function tryGetExtensionFromPath(path:String, extension:String, stringEqualityComparer:(a:String, b:String) -> Bool):String {
		if (!StringTools.startsWith(extension, ".")) {
			extension = "." + extension;
		}
		if (path.length >= extension.length && StringTools.fastCodeAt(path, path.length - extension.length) == '.'.code) {
			final pathExtension = path.substring(path.length - extension.length);
			if (stringEqualityComparer(pathExtension, extension)) {
				return pathExtension;
			}
		}
		return "";
	}

	public static function PathIsRelative(path:String):Bool {
		// True if path is ".", "..", or starts with "./", "../", ".\\", or "..\\".

		if (path == "." || path == "..") {
			return true;
		}

		if (path.length >= 2
			&& StringTools.fastCodeAt(path, 0) == '.'.code
			&& (StringTools.fastCodeAt(path, 1) == '/'.code || StringTools.fastCodeAt(path, 1) == '\\'.code)) {
			return true;
		}

		if (path.length >= 3
			&& StringTools.fastCodeAt(path, 0) == '.'.code
			&& StringTools.fastCodeAt(path, 1) == '.'.code
			&& (StringTools.fastCodeAt(path, 2) == '/'.code || StringTools.fastCodeAt(path, 2) == '\\'.code)) {
			return true;
		}

		return false;
	}

	// EnsurePathIsNonModuleName ensures a path is either absolute (prefixed with `/` or `c:`) or dot-relative (prefixed
	// with `./` or `../`) so as not to be confused with an unprefixed module name.
	public static function EnsurePathIsNonModuleName(path:String):String {
		if (!PathIsAbsolute(path) && !PathIsRelative(path)) {
			return "./" + path;
		}
		return path;
	}

	public static function IsExternalModuleNameRelative(moduleName:String):Bool {
		// TypeScript 1.0 spec (April 2014): 11.2.1
		// An external module name is "relative" if the first term is "." or "..".
		// Update: We also consider a path like `C:\foo.ts` "relative" because we do not search for it in `node_modules` or treat it as an ambient module.
		return PathIsRelative(moduleName) || IsRootedDiskPath(moduleName);
	}

	public static function ComparePaths(a:String, b:String, options:ComparePathsOptions):Int {
		a = CombinePaths(options.CurrentDirectory, a);
		b = CombinePaths(options.CurrentDirectory, b);

		if (a == b) {
			return 0;
		}
		if (a == "") {
			return -1;
		}
		if (b == "") {
			return 1;
		}

		// NOTE: Performance optimization - shortcut if the root segments differ as there would be no
		//       need to perform path reduction.
		final aRoot = a.substring(0, GetRootLength(a));
		final bRoot = b.substring(0, GetRootLength(b));
		final result = Stringutil.CompareStringsCaseInsensitive(aRoot, bRoot);
		if (result != 0) {
			return result;
		}

		// NOTE: Performance optimization - shortcut if there are no relative path segments in
		//       the non-root portion of the path
		final aRest = a.substring(aRoot.length);
		final bRest = b.substring(bRoot.length);
		if (!hasRelativePathSegment(aRest) && !hasRelativePathSegment(bRest)) {
			return options.GetComparer()(aRest, bRest);
		}

		// The path contains a relative path segment. Normalize the paths and perform a slower component
		// by component comparison.
		final aComponents = reducePathComponents(GetPathComponents(a, ""));
		final bComponents = reducePathComponents(GetPathComponents(b, ""));
		final sharedLength = min(aComponents.length, bComponents.length);
		for (i in 1...sharedLength) {
			final result = options.GetComparer()(aComponents[i], bComponents[i]);
			if (result != 0) {
				return result;
			}
		}
		return Cmp.Compare(aComponents.length, bComponents.length);
	}

	public static function ComparePathsCaseSensitive(a:String, b:String, currentDirectory:String):Int {
		return ComparePaths(a, b, new ComparePathsOptions(true, currentDirectory));
	}

	public static function ComparePathsCaseInsensitive(a:String, b:String, currentDirectory:String):Int {
		return ComparePaths(a, b, new ComparePathsOptions(false, currentDirectory));
	}

	public static function ContainsPath(parent:String, child:String, options:ComparePathsOptions):Bool {
		parent = CombinePaths(options.CurrentDirectory, parent);
		child = CombinePaths(options.CurrentDirectory, child);
		if (parent == "" || child == "") {
			return false;
		}
		if (parent == child) {
			return true;
		}
		final parentComponents = reducePathComponents(GetPathComponents(parent, ""));
		final childComponents = reducePathComponents(GetPathComponents(child, ""));
		if (childComponents.length < parentComponents.length) {
			return false;
		}

		final componentComparer = options.getEqualityComparer();
		for (i in 0...parentComponents.length) {
			final parentComponent = parentComponents[i];
			var comparer:(a:String, b:String) -> Bool;
			if (i == 0) {
				comparer = Stringutil.EquateStringCaseInsensitive;
			} else {
				comparer = componentComparer;
			}
			if (!comparer(parentComponent, childComponents[i])) {
				return false;
			}
		}

		return true;
	}

	public static function FileExtensionIs(path:String, extension:String):Bool {
		return path.length > extension.length && StringTools.endsWith(path, extension);
	}

	// Calls `callback` on `directory` and every ancestor directory it has, returning the first defined result.
	// Stops at global cache location
	// PORT: callback returns Go (result T, stop bool) as go.ValueOk<T> (ok = stop).
	public static function ForEachAncestorDirectoryStoppingAtGlobalCache<T>(globalCacheLocation:String, directory:String,
			callback:(directory:String) -> ValueOk<T>):T {
		final r = ForEachAncestorDirectory(directory, function(ancestorDirectory:String):ValueOk<T> {
			final r = callback(ancestorDirectory);
			final result = r.value;
			final stop = r.ok;
			if (stop || ancestorDirectory == globalCacheLocation) {
				return new ValueOk<T>(result, true);
			}
			return new ValueOk<T>(result, false);
		});
		return r.value;
	}

	// PORT: callback returns Go (result T, stop bool) as go.ValueOk<T> (ok = stop); zero T is null.
	public static function ForEachAncestorDirectory<T>(directory:String, callback:(directory:String) -> ValueOk<T>):ValueOk<T> {
		while (true) {
			final r = callback(directory);
			if (r.ok) {
				return new ValueOk<T>(r.value, true);
			}

			final parentPath = GetDirectoryPath(directory);
			if (parentPath == directory) {
				final zero:T = null;
				return new ValueOk<T>(zero, false);
			}

			directory = parentPath;
		}
	}

	public static function ForEachAncestorDirectoryPath<T>(directory:Path, callback:(directory:Path) -> ValueOk<T>):ValueOk<T> {
		return ForEachAncestorDirectory(directory, function(directory:String):ValueOk<T> {
			return callback(directory);
		});
	}

	public static function HasExtension(fileName:String):Bool {
		return GetBaseFileName(fileName).indexOf(".") >= 0;
	}

	// Go returns (volume string, rest string, ok bool).
	public static function SplitVolumePath(path:String):Triple<String, String, Bool> {
		if (path.length >= 2 && IsVolumeCharacter(StringTools.fastCodeAt(path, 0)) && StringTools.fastCodeAt(path, 1) == ':'.code) {
			return new Triple(Strings.ToLower(path.substring(0, 2)), path.substring(2), true);
		}
		return new Triple("", path, false);
	}

	// GetCommonParents returns the smallest set of directories that are parents of all paths with
	// at least `minComponents` directory components. Any path that has fewer than `minComponents` directory components
	// will be returned in the second return value. Examples:
	//
	//	/a/b/c/d, /a/b/c/e, /a/b/f/g  =>  /a/b
	//	/a/b/c/d, /a/b/c/e, /a/b/f/g, /x/y  =>  /
	//	/a/b/c/d, /a/b/c/e, /a/b/f/g, /x/y  (minComponents: 2)	=>  /a/b, /x/y
	//	c:/a/b/c/d, d:/a/b/c/d =>	c:/a/b/c/d, d:/a/b/c/d
	// PORT: Go returns (parents []string, ignored map[string]struct{}); the set is a StringMap<Bool>.
	public static function GetCommonParents(paths:Array<String>, minComponents:Int, getPathComponents:(path:String, currentDirectory:String) -> Array<String>,
			options:ComparePathsOptions):Pair<Array<String>, StringMap<Bool>> {
		if (minComponents < 1) {
			throw "minComponents must be at least 1";
		}
		if (paths == null || paths.length == 0) {
			return new Pair<Array<String>, StringMap<Bool>>(null, null);
		}
		if (paths.length == 1) {
			if (reducePathComponents(getPathComponents(paths[0], options.CurrentDirectory)).length < minComponents) {
				final ignored = new StringMap<Bool>();
				ignored.set(paths[0], true);
				return new Pair<Array<String>, StringMap<Bool>>(null, ignored);
			}
			return new Pair<Array<String>, StringMap<Bool>>(paths, null);
		}

		final ignored = new StringMap<Bool>();
		final pathComponents:Array<Array<String>> = [];
		for (path in paths) {
			final components = reducePathComponents(getPathComponents(path, options.CurrentDirectory));
			if (components.length < minComponents) {
				ignored.set(path, true);
			} else {
				pathComponents.push(components);
			}
		}

		final results = getCommonParentsWorker(pathComponents, minComponents, options);
		final n = results == null ? 0 : results.length;
		final resultPaths = new Array<String>();
		resultPaths.resize(n);
		for (i in 0...n) {
			resultPaths[i] = GetPathFromPathComponents(results[i]);
		}

		return new Pair<Array<String>, StringMap<Bool>>(resultPaths, ignored);
	}

	static function getCommonParentsWorker(componentGroups:Array<Array<String>>, minComponents:Int, options:ComparePathsOptions):Array<Array<String>> {
		if (componentGroups == null || componentGroups.length == 0) {
			return null;
		}
		// Determine the maximum depth we can consider
		var maxDepth = componentGroups[0].length;
		for (k in 1...componentGroups.length) {
			final l = componentGroups[k].length;
			if (l < maxDepth) {
				maxDepth = l;
			}
		}

		final equality = options.getEqualityComparer();
		for (lastCommonIndex in 0...maxDepth) {
			final candidate = componentGroups[0][lastCommonIndex];
			for (k in 1...componentGroups.length) {
				final comps = componentGroups[k];
				if (!equality(candidate, comps[lastCommonIndex])) { // divergence
					if (lastCommonIndex < minComponents) {
						// Not enough components, we need to fan out
						final orderedGroups:Array<Path> = [];
						final newGroups = new StringMap<CommonParentsGroup>();
						for (g in componentGroups) {
							final key = ToPath(g[lastCommonIndex], options.CurrentDirectory, options.UseCaseSensitiveFileNames);
							final existing = newGroups.get(key);
							if (existing == null) {
								orderedGroups.push(key);
							}
							final tails = existing == null ? [] : existing.tails;
							tails.push(g.slice(lastCommonIndex + 1));
							newGroups.set(key, new CommonParentsGroup(g.slice(0, lastCommonIndex + 1), tails));
						}
						orderedGroups.sort((x, y) -> Strings.Compare(x, y));
						final result:Array<Array<String>> = [];
						for (key in orderedGroups) {
							final group = newGroups.get(key);
							final subResults = getCommonParentsWorker(group.tails, minComponents - (lastCommonIndex + 1), options);
							if (subResults != null) {
								for (sr in subResults) {
									// PORT: copy; Go's append(group.head, sr...) may write into head's backing array.
									result.push(group.head.concat(sr));
								}
							}
						}
						return result;
					}
					return [componentGroups[0].slice(0, lastCommonIndex)];
				}
			}
		}

		return [componentGroups[0].slice(0, maxDepth)];
	}

	public static function StartsWithDirectory(fileName:String, directoryName:String, useCaseSensitiveFileNames:Bool):Bool {
		if (directoryName == "") {
			return false;
		}

		final canonicalFileName = GetCanonicalFileName(fileName, useCaseSensitiveFileNames);
		var canonicalDirectoryName = GetCanonicalFileName(directoryName, useCaseSensitiveFileNames);
		canonicalDirectoryName = Strings.TrimSuffix(canonicalDirectoryName, "/");
		canonicalDirectoryName = Strings.TrimSuffix(canonicalDirectoryName, "\\");

		return StringTools.startsWith(canonicalFileName, canonicalDirectoryName + "/")
			|| StringTools.startsWith(canonicalFileName, canonicalDirectoryName + "\\");
	}

	public static function CompareNumberOfDirectorySeparators(path1:String, path2:String):Int {
		return Cmp.Compare(Strings.Count(path1, "/"), Strings.Count(path2, "/"));
	}
}
