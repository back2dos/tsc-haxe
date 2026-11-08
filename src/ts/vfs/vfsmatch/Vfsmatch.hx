package ts.vfs.vfsmatch;

import go.Strings;
import go.Tuple;
import haxe.ds.StringMap;
import ts.collections.Set;
import ts.core.Core;
import ts.tspath.Path;
import ts.tspath.Tspath;
import ts.vfs.Vfs;

// Port of vfsmatch.go (and stringer_generated.go: Usage.toString).
// This file implements the glob matching algorithm specified in MATCHING_ALGORITHM.md.
enum abstract Usage(Int) to Int {
	var UsageFiles = 0;
	var UsageDirectories = 1;
	var UsageExclude = 2;

	// stringer_generated.go
	public function toString():String {
		return switch (cast this : Usage) {
			case UsageFiles: "Files";
			case UsageDirectories: "Directories";
			case UsageExclude: "Exclude";
			default: "Usage(" + this + ")";
		}
	}
}

class Vfsmatch {
	// UnlimitedDepth can be passed as the depth argument to indicate there is no depth limit.
	// PORT: math.MaxInt → 2^31-1 (Int).
	public static inline final UnlimitedDepth = 2147483647;

	public static function ReadDirectory(host:FS, currentDir:String, path:String, extensions:Null<Array<String>>, excludes:Null<Array<String>>,
			includes:Null<Array<String>>, depth:Int):Null<Array<String>> {
		return matchFiles(path, extensions, excludes, includes, host.UseCaseSensitiveFileNames(), currentDir, depth, host);
	}

	// IsImplicitGlob checks if a path component is implicitly a glob.
	// An "includes" path "foo" is implicitly a glob "foo/** /*" (without the space) if its last component has no extension,
	// and does not contain any glob characters itself.
	public static function IsImplicitGlob(lastPathComponent:String):Bool {
		return Strings.IndexAny(lastPathComponent, ".*?") < 0;
	}

	static final wildcardCharCodes = ['*'.code, '?'.code];

	static function getIncludeBasePath(absolute:String):String {
		final wildcardOffset = Strings.IndexAny(absolute, "*?");
		if (wildcardOffset < 0) {
			// No "*" or "?" in the path
			if (!Tspath.HasExtension(absolute)) {
				return absolute;
			} else {
				return Tspath.RemoveTrailingDirectorySeparator(Tspath.GetDirectoryPath(absolute));
			}
		}
		final i = absolute.substring(0, wildcardOffset).lastIndexOf(String.fromCharCode(Tspath.DirectorySeparator));
		return absolute.substring(0, i > 0 ? i : 0);
	}

	// getBasePaths computes the unique non-wildcard base paths amongst the provided include patterns.
	@:allow(ts.vfs.vfsmatch)
	static function getBasePaths(path:String, includes:Null<Array<String>>, useCaseSensitiveFileNames:Bool):Array<String> {
		// Storage for our results in the form of literal paths (e.g. the paths as written by the user).
		final basePaths = [path];

		if (Core.len(includes) > 0) {
			final comparePathsOptions = new ComparePathsOptions(useCaseSensitiveFileNames, path);
			final stringComparer = comparePathsOptions.GetComparer();

			// Storage for literal base paths amongst the include patterns.
			final includeBasePaths:Array<String> = [];
			for (include in includes) {
				// We also need to check the relative paths by converting them to absolute and normalizing
				// in case they escape the base path (e.g "..\somedirectory")
				var absolute:String;
				if (Tspath.IsRootedDiskPath(include)) {
					absolute = include;
				} else {
					absolute = Tspath.NormalizePath(Tspath.CombinePaths(path, include));
				}
				// Append the literal and canonical candidate base paths.
				includeBasePaths.push(getIncludeBasePath(absolute));
			}

			// Sort the offsets array using either the literal or canonical path representations.
			haxe.ds.ArraySort.sort(includeBasePaths, stringComparer);

			// Iterate over each include base path and include unique base paths that are not a
			// subpath of an existing base path
			for (includeBasePath in includeBasePaths) {
				if (Core.Every(basePaths, (basepath:String) -> {
					return !Tspath.ContainsPath_legacy(basepath, includeBasePath, comparePathsOptions);
				})) {
					basePaths.push(includeBasePath);
				}
			}
		}

		return basePaths;
	}

	// compileGlobPattern compiles a glob spec (e.g., "src/**/*.ts") into a pattern.
	// Returns (pattern, false) if the pattern would match nothing.
	// PORT: (globPattern, bool) → GlobPattern or null.
	@:allow(ts.vfs.vfsmatch)
	static function compileGlobPattern(spec:String, basePath:String, usage:Usage, caseSensitive:Bool):Null<GlobPattern> {
		var parts = Tspath.GetNormalizedPathComponents(spec, basePath);

		// "src/**" without a filename matches nothing (for include patterns)
		if (usage != UsageExclude && Core.LastOrNil(parts, "") == "**") {
			return null;
		}

		// Normalize root: "/home/" -> "/home"
		parts[0] = Tspath.RemoveTrailingDirectorySeparator(parts[0]);

		// Directories implicitly match all files: "src" -> "src/**/*"
		if (IsImplicitGlob(Core.LastOrNil(parts, ""))) {
			parts.push("**");
			parts.push("*");
		}

		final p = new GlobPattern();
		p.isExclude = usage == UsageExclude;
		p.caseSensitive = caseSensitive;
		p.excludeMinJs = usage == UsageFiles;
		// Avoid slice growth during compilation.
		p.components = [];

		for (part in parts) {
			p.components.push(parseComponent(part, usage != UsageExclude));
		}
		return p;
	}

	// parseComponent converts a path segment string into a component.
	@:allow(ts.vfs.vfsmatch)
	static function parseComponent(s:String, isInclude:Bool):Component {
		if (s == "**") {
			return new Component(KindDoubleAsterisk, "", null, false);
		}
		if (Strings.IndexAny(s, "*?") < 0) {
			return new Component(KindLiteral, s, null, false);
		}
		return new Component(KindWildcard, "", parseSegments(s), isInclude);
	}

	// parseSegments breaks "*.ts" into [segStar, segLiteral(".ts")]
	@:allow(ts.vfs.vfsmatch)
	static function parseSegments(s:String):Array<Segment> {
		// Preallocate based on wildcard count: each wildcard contributes 1 segment,
		// and each wildcard can split literals into at most one extra literal segment.
		final result:Array<Segment> = [];
		var start = 0;
		for (i in 0...s.length) {
			final c = StringTools.fastCodeAt(s, i);
			if (c == '*'.code || c == '?'.code) {
				if (i > start) {
					result.push(new Segment(SegLiteral, s.substring(start, i)));
				}
				if (c == '*'.code) {
					result.push(new Segment(SegStar, ""));
				} else {
					result.push(new Segment(SegQuestion, ""));
				}
				start = i + 1;
			}
		}
		if (start < s.length) {
			result.push(new Segment(SegLiteral, s.substring(start)));
		}
		return result;
	}

	// nextPathPart extracts the next path component from path starting at offset.
	// PORT: (part, nextOffset, ok) → Triple.
	@:allow(ts.vfs.vfsmatch)
	static function nextPathPartSingle(s:String, offset:Int):Triple<String, Int, Bool> {
		if (offset >= s.length) {
			return new Triple("", offset, false);
		}
		if (offset == 0 && s.length > 0 && StringTools.fastCodeAt(s, 0) == '/'.code) {
			return new Triple("", 1, true);
		}
		while (offset < s.length && StringTools.fastCodeAt(s, offset) == '/'.code) {
			offset++;
		}
		if (offset >= s.length) {
			return new Triple("", offset, false);
		}
		final idx = s.indexOf("/", offset);
		if (idx >= 0) {
			return new Triple(s.substring(offset, idx), idx, true);
		}
		return new Triple(s.substring(offset), s.length, true);
	}

	@:allow(ts.vfs.vfsmatch)
	static function nextPathPartParts(prefix:String, suffix:String, offset:Int):Triple<String, Int, Bool> {
		// Fast paths: keep the hot single-string scan tight.
		if (suffix.length == 0) {
			return nextPathPartSingle(prefix, offset);
		}
		if (prefix.length == 0) {
			return nextPathPartSingle(suffix, offset);
		}

		// For matchFilesNoRegex call sites, prefix is a directory path ending in '/',
		// and suffix is a single entry name (no '/'). That makes this significantly
		// simpler than a general-purpose "virtual concatenation" scanner.

		final totalLen = prefix.length + suffix.length;
		if (offset >= totalLen) {
			return new Triple("", offset, false);
		}

		// Handle leading slash (root of absolute path)
		if (offset == 0 && StringTools.fastCodeAt(prefix, 0) == '/'.code) {
			return new Triple("", 1, true);
		}

		// Scan within prefix.
		if (offset < prefix.length) {
			while (offset < prefix.length && StringTools.fastCodeAt(prefix, offset) == '/'.code) {
				offset++;
			}
			if (offset < prefix.length) {
				final idx = prefix.indexOf("/", offset);
				// idx is guaranteed >= 0 for the call sites we care about because prefix ends in '/'.
				// PORT: Go slices rest[:idx] with idx == -1 would panic; same here via an invalid substring is not possible, so throw.
				if (idx < 0) {
					throw "slice bounds out of range";
				}
				return new Triple(prefix.substring(offset, idx), idx, true);
			}
			// Fall through into suffix region.
		}

		// Scan suffix: it's a single component.
		final sOff = offset - prefix.length;
		if (sOff >= suffix.length) {
			return new Triple("", offset, false);
		}
		return new Triple(suffix.substring(sOff), totalLen, true);
	}

	// isHiddenPath checks if a path component is hidden (starts with dot).
	@:allow(ts.vfs.vfsmatch)
	static function isHiddenPath(name:String):Bool {
		return name.length > 0 && StringTools.fastCodeAt(name, 0) == '.'.code;
	}

	// isPackageFolder checks if name is a common package folder (node_modules, etc.)
	@:allow(ts.vfs.vfsmatch)
	static function isPackageFolder(name:String):Bool {
		switch (name.length) {
			case 12: // len("node_modules")
				return Strings.EqualFold(name, "node_modules");
			case 13: // len("jspm_packages")
				return Strings.EqualFold(name, "jspm_packages");
			case 16: // len("bower_components")
				return Strings.EqualFold(name, "bower_components");
		}
		return false;
	}

	@:allow(ts.vfs.vfsmatch)
	static function ensureTrailingSlash(s:String):String {
		if (s.length > 0 && StringTools.fastCodeAt(s, s.length - 1) != '/'.code) {
			return s + "/";
		}
		return s;
	}

	@:allow(ts.vfs.vfsmatch)
	static function newGlobMatcher(includeSpecs:Null<Array<String>>, excludeSpecs:Null<Array<String>>, basePath:String, caseSensitive:Bool,
			usage:Usage):GlobMatcher {
		final m = new GlobMatcher();
		m.hadIncludes = Core.len(includeSpecs) > 0;
		m.includes = [];
		m.excludes = [];

		if (includeSpecs != null) {
			for (spec in includeSpecs) {
				final p = compileGlobPattern(spec, basePath, usage, caseSensitive);
				if (p != null) {
					m.includes.push(p);
				}
			}
		}
		if (excludeSpecs != null) {
			for (spec in excludeSpecs) {
				final p = compileGlobPattern(spec, basePath, UsageExclude, caseSensitive);
				if (p != null) {
					m.excludes.push(p);
				}
			}
		}
		return m;
	}

	@:allow(ts.vfs.vfsmatch)
	static function matchFiles(path:String, extensions:Null<Array<String>>, excludes:Null<Array<String>>, includes:Null<Array<String>>,
			useCaseSensitiveFileNames:Bool, currentDirectory:String, depth:Int, host:FS):Null<Array<String>> {
		path = Tspath.NormalizePath(path);
		currentDirectory = Tspath.NormalizePath(currentDirectory);
		final absolutePath = Tspath.CombinePaths(currentDirectory, path);

		final fileMatcher = newGlobMatcher(includes, excludes, absolutePath, useCaseSensitiveFileNames, UsageFiles);
		final directoryMatcher = newGlobMatcher(includes, excludes, absolutePath, useCaseSensitiveFileNames, UsageDirectories);

		final n = fileMatcher.includes.length > 1 ? fileMatcher.includes.length : 1;
		final v = new GlobVisitor(host, fileMatcher, directoryMatcher, extensions, useCaseSensitiveFileNames, [for (_ in 0...n) null]);

		final basePaths = getBasePaths(path, includes, useCaseSensitiveFileNames);
		#if tshx_parallel
		// PORT: hxmc (-D tshx-parallel) — TypeScript main's prefetchDirectories (#64877, prefetch.go): the
		// directories the walk is expected to visit are read on the pool's threads first (Go: GOMAXPROCS readers)
		v.prefetched = DirectoryPrefetcher.prefetchDirectories(host, directoryMatcher, useCaseSensitiveFileNames,
			[for (basePath in basePaths) Tspath.CombinePaths(currentDirectory, basePath)], depth);
		#end
		for (basePath in basePaths) {
			v.visit(basePath, Tspath.CombinePaths(currentDirectory, basePath), depth, "");
		}

		// Fast path: a single include bucket (or no includes) doesn't need flattening.
		if (v.results.length == 1) {
			return v.results[0];
		}
		return Core.Flatten(v.results);
	}

	// NewSpecMatcher creates a matcher for one or more glob specs.
	// It returns a matcher that can test if paths match any of the patterns.
	public static function NewSpecMatcher(specs:Null<Array<String>>, basePath:String, usage:Usage, useCaseSensitiveFileNames:Bool):Null<SpecMatcher> {
		if (Core.len(specs) == 0) {
			return null;
		}
		final patterns:Array<GlobPattern> = [];
		for (spec in specs) {
			final p = compileGlobPattern(spec, basePath, usage, useCaseSensitiveFileNames);
			if (p != null) {
				patterns.push(p);
			}
		}
		if (patterns.length == 0) {
			return null;
		}
		final m = new SpecMatcher();
		m.patterns = patterns;
		return m;
	}
}

enum abstract ComponentKind(Int) to Int {
	var KindLiteral = 0; // exact match (e.g., "src")
	var KindWildcard = 1; // contains * or ? (e.g., "*.ts")
	var KindDoubleAsterisk = 2; // ** matches zero or more directories
}

enum abstract SegmentKind(Int) to Int {
	var SegLiteral = 0; // exact text
	var SegStar = 1; // * matches any chars except /
	var SegQuestion = 2; // ? matches single char except /
}

// component is a single path segment in a glob pattern.
// Examples: "src" (literal), "*" (wildcard), "*.ts" (wildcard), "**" (recursive)
// PORT: Go names kindLiteral/segLiteral etc. are capitalized as enum abstract values.
class Component {
	public final kind:ComponentKind;
	public final literal:String; // for kindLiteral: the exact string to match
	public final segments:Null<Array<Segment>>; // for kindWildcard: parsed wildcard pattern
	// Include patterns with wildcards skip common package folders (node_modules, etc.)
	public final skipPackageFolders:Bool;

	public function new(kind:ComponentKind, literal:String, segments:Null<Array<Segment>>, skipPackageFolders:Bool) {
		this.kind = kind;
		this.literal = literal;
		this.segments = segments;
		this.skipPackageFolders = skipPackageFolders;
	}
}

// segment is a piece of a wildcard component.
// Example: "*.ts" becomes [segStar, segLiteral(".ts")]
class Segment {
	public final kind:SegmentKind;
	public final literal:String; // only for segLiteral

	public function new(kind:SegmentKind, literal:String) {
		this.kind = kind;
		this.literal = literal;
	}
}

// globPattern is a compiled glob pattern for matching file paths without regex.
class GlobPattern {
	public var components:Null<Array<Component>> = null; // path segments to match (e.g., ["src", "**", "*.ts"])
	public var isExclude:Bool = false; // exclude patterns have different matching rules
	public var caseSensitive:Bool = false;
	public var excludeMinJs:Bool = false; // for "files" patterns, exclude .min.js by default

	public function new() {}

	// matches returns true if path matches this pattern.
	public function matches(path:String):Bool {
		return this.matchPathParts(path, "", 0, 0, false);
	}

	// matchesParts returns true if prefix+suffix matches this pattern.
	// This avoids allocating a combined string for common call sites where prefix ends with '/'.
	public function matchesParts(prefix:String, suffix:String):Bool {
		return this.matchPathParts(prefix, suffix, 0, 0, false);
	}

	// matchesPrefixParts returns true if files under prefix+suffix could match.
	public function matchesPrefixParts(prefix:String, suffix:String):Bool {
		return this.matchPathParts(prefix, suffix, 0, 0, true);
	}

	// matchPathParts is like matchPath, but operates on a virtual path formed by prefix+suffix.
	// Offsets are in the combined string.
	// PORT: perf — the parts are read in place through a PathPartCursor (nextPathPartParts' result without
	// its substring and result object; Go slices for free): every call walks the whole absolute path again.
	public function matchPathParts(prefix:String, suffix:String, pathOffset:Int, compIdx:Int, prefixOnly:Bool):Bool {
		final part = new PathPartCursor();
		while (true) {
			if (!part.advance(prefix, suffix, pathOffset)) {
				if (prefixOnly) {
					return true;
				}
				return this.patternSatisfied(compIdx);
			}
			final nextOffset = part.next;

			if (compIdx >= this.components.length) {
				return this.isExclude && !prefixOnly;
			}

			final comp = this.components[compIdx];
			switch (comp.kind) {
				case KindDoubleAsterisk:
					if (this.matchPathParts(prefix, suffix, pathOffset, compIdx + 1, prefixOnly)) {
						return true;
					}
					if (!this.isExclude && (part.isHidden() || part.isPackageFolder())) {
						return false;
					}
					pathOffset = nextOffset;
					continue;
				case KindLiteral:
					if (comp.skipPackageFolders && part.isPackageFolder()) {
						throw "unreachable: literal components never have skipPackageFolders";
					}
					if (!part.equals(comp.literal, this.caseSensitive)) {
						return false;
					}
				case KindWildcard:
					if (comp.skipPackageFolders && part.isPackageFolder()) {
						return false;
					}
					if (!this.matchWildcard(comp.segments, part.toString())) {
						return false;
					}
			}

			pathOffset = nextOffset;
			compIdx++;
		}
	}

	// patternSatisfied checks if remaining pattern components can match empty input.
	function patternSatisfied(compIdx:Int):Bool {
		// A pattern is satisfied when remaining components can match empty input.
		// For both include and exclude patterns, only trailing "**" components may match nothing.
		for (i in compIdx...this.components.length) {
			if (this.components[i].kind != KindDoubleAsterisk) {
				return false;
			}
		}
		return true;
	}

	// matchWildcard matches a path component against wildcard segments.
	public function matchWildcard(segs:Array<Segment>, s:String):Bool {
		// Include patterns: wildcards at start cannot match hidden files
		if (!this.isExclude && segs.length > 0 && Vfsmatch.isHiddenPath(s) && (segs[0].kind == SegStar || segs[0].kind == SegQuestion)) {
			return false;
		}

		// Fast path: single * followed by literal suffix (e.g., "*.ts")
		if (segs.length == 2 && segs[0].kind == SegStar && segs[1].kind == SegLiteral) {
			final suffix = segs[1].literal;
			if (s.length < suffix.length || !this.stringsEqual(suffix, s.substring(s.length - suffix.length))) {
				return false;
			}
			return this.shouldIncludeMinJs(s, segs);
		}

		return this.matchSegments(segs, s) && this.shouldIncludeMinJs(s, segs);
	}

	// matchSegments matches segments against string s using an iterative algorithm.
	// This avoids exponential backtracking by tracking only the last star position.
	// The algorithm is O(n*m) where n is the string length and m is pattern length.
	// PORT: utf8.DecodeRuneInString size → UTF-16 rune length (go.Utf16, PORTING.md §5).
	public function matchSegments(segs:Array<Segment>, s:String):Bool {
		var segIdx = 0;
		var sIdx = 0;
		var starSegIdx = -1;
		var starSIdx = 0;

		while (sIdx < s.length) {
			if (segIdx < segs.length) {
				final seg = segs[segIdx];
				switch (seg.kind) {
					case SegLiteral:
						final end = sIdx + seg.literal.length;
						if (end <= s.length && this.stringsEqual(seg.literal, s.substring(sIdx, end))) {
							sIdx = end;
							segIdx++;
							continue;
						}
					case SegQuestion:
						if (StringTools.fastCodeAt(s, sIdx) != '/'.code) {
							final size = go.Utf16.RuneLen(go.Utf16.CodePointAt(s, sIdx));
							sIdx += size;
							segIdx++;
							continue;
						}
					case SegStar:
						// Record star position for backtracking, then try matching zero chars.
						starSegIdx = segIdx;
						starSIdx = sIdx;
						segIdx++;
						continue;
				}
			}

			// Current segment didn't match. Backtrack to last star if possible.
			if (starSegIdx >= 0 && starSIdx < s.length && StringTools.fastCodeAt(s, starSIdx) != '/'.code) {
				// Star consumes one more character (rune), retry from segment after star.
				final size = go.Utf16.RuneLen(go.Utf16.CodePointAt(s, starSIdx));
				starSIdx += size;
				sIdx = starSIdx;
				segIdx = starSegIdx + 1;
				continue;
			}

			return false;
		}

		// Consume any trailing stars.
		while (segIdx < segs.length && segs[segIdx].kind == SegStar) {
			segIdx++;
		}
		return segIdx >= segs.length;
	}

	function shouldIncludeMinJs(filename:String, segs:Array<Segment>):Bool {
		if (!this.excludeMinJs) {
			return true;
		}

		// Preserve legacy behavior:
		// - When matching is case-sensitive, only the exact ".min.js" suffix is excluded by default.
		// - When matching is case-insensitive, any casing variant is excluded by default.
		if (!this.hasMinJsSuffix(filename)) {
			return true;
		}
		// Allow when the user's pattern explicitly references the .min. suffix.
		if (this.patternMentionsMinSuffix(segs)) {
			return true;
		}
		return false;
	}

	function hasMinJsSuffix(filename:String):Bool {
		if (this.caseSensitive) {
			return StringTools.endsWith(filename, ".min.js");
		}
		final minJs = ".min.js";
		if (filename.length < minJs.length) {
			return false;
		}
		// Avoid allocating via strings.ToLower; compare suffix case-insensitively.
		return Strings.EqualFold(filename.substring(filename.length - minJs.length), minJs);
	}

	function patternMentionsMinSuffix(segs:Array<Segment>):Bool {
		for (seg in segs) {
			if (seg.kind != SegLiteral) {
				continue;
			}
			var lit = seg.literal;
			if (!this.caseSensitive) {
				lit = Strings.ToLower(lit);
			}
			if (lit.indexOf(".min.js") >= 0 || lit.indexOf(".min.") >= 0) {
				return true;
			}
		}
		return false;
	}

	// stringsEqual compares strings with appropriate case sensitivity.
	function stringsEqual(a:String, b:String):Bool {
		if (this.caseSensitive) {
			return a == b;
		}
		return Strings.EqualFold(a, b);
	}
}

// globMatcher combines include and exclude patterns for file matching.
class GlobMatcher {
	public var includes:Null<Array<GlobPattern>> = null;
	public var excludes:Null<Array<GlobPattern>> = null;
	public var hadIncludes:Bool = false; // true if include specs were provided (even if none compiled)

	public function new() {}

	// matchesFileParts checks if prefix+suffix matches against the glob patterns.
	// Returns the index of the matching include pattern and true if matched, or (0, false) if not.
	// PORT: (int, bool) → index, or -1 for "not matched".
	public function matchesFileParts(prefix:String, suffix:String):Int {
		for (i in 0...this.excludes.length) {
			if (this.excludes[i].matchesParts(prefix, suffix)) {
				return -1;
			}
		}
		if (this.includes.length == 0) {
			if (this.hadIncludes) {
				return -1;
			}
			return 0;
		}
		for (i in 0...this.includes.length) {
			if (this.includes[i].matchesParts(prefix, suffix)) {
				return i;
			}
		}
		return -1;
	}

	// matchesDirectoryParts checks if files under the directory prefix+suffix could match any pattern.
	public function matchesDirectoryParts(prefix:String, suffix:String):Bool {
		for (i in 0...this.excludes.length) {
			if (this.excludes[i].matchesParts(prefix, suffix)) {
				return false;
			}
		}
		if (this.includes.length == 0) {
			return !this.hadIncludes;
		}
		for (i in 0...this.includes.length) {
			if (this.includes[i].matchesPrefixParts(prefix, suffix)) {
				return true;
			}
		}
		return false;
	}
}

// globVisitor traverses directories matching files against glob patterns.
class GlobVisitor {
	final host:FS;
	final fileMatcher:GlobMatcher;
	final directoryMatcher:GlobMatcher;
	final extensions:Null<Array<String>>;
	final useCaseSensitiveFileNames:Bool;
	final visited = new Set<String>();

	public final results:Array<Null<Array<String>>>;
	#if tshx_parallel
	public var prefetched:Null<StringMap<PrefetchedDirectory>> = null;
	#end

	public function new(host:FS, fileMatcher:GlobMatcher, directoryMatcher:GlobMatcher, extensions:Null<Array<String>>, useCaseSensitiveFileNames:Bool,
			results:Array<Null<Array<String>>>) {
		this.host = host;
		this.fileMatcher = fileMatcher;
		this.directoryMatcher = directoryMatcher;
		this.extensions = extensions;
		this.useCaseSensitiveFileNames = useCaseSensitiveFileNames;
		this.results = results;
	}

	// visit walks a directory tree, collecting files that match the glob patterns.
	// resolvedRealPath, when non-empty, is the already-resolved real path for this
	// directory (computed incrementally from the parent). When empty, Realpath is
	// called to resolve symlinks.
	public function visit(path:String, absolutePath:String, depth:Int, resolvedRealPath:String):Void {
		// Detect symlink cycles
		#if tshx_parallel
		final prefetched = this.prefetched != null ? this.prefetched.get(absolutePath) : null;
		#end
		var realPath:String;
		if (resolvedRealPath != "") {
			realPath = resolvedRealPath;
		#if tshx_parallel
		} else if (prefetched != null) {
			realPath = prefetched.realPath;
		#end
		} else {
			realPath = this.host.Realpath(absolutePath);
		}
		final canonicalPath = Tspath.GetCanonicalFileName(realPath, this.useCaseSensitiveFileNames);
		if (this.visited.Has(canonicalPath)) {
			return;
		}
		this.visited.Add(canonicalPath);

		#if tshx_parallel
		final entries = prefetched != null ? prefetched.entries : this.host.GetAccessibleEntries(absolutePath);
		#else
		final entries = this.host.GetAccessibleEntries(absolutePath);
		#end

		final pathPrefix = Vfsmatch.ensureTrailingSlash(path);
		final absPrefix = Vfsmatch.ensureTrailingSlash(absolutePath);

		if (entries.Files != null) {
			for (file in entries.Files) {
				if (Core.len(this.extensions) > 0 && !Tspath.FileExtensionIsOneOf(file, this.extensions)) {
					continue;
				}
				final idx = this.fileMatcher.matchesFileParts(absPrefix, file);
				if (idx >= 0) {
					if (this.results[idx] == null)
						this.results[idx] = [];
					this.results[idx].push(pathPrefix + file);
				}
			}
		}

		if (depth != Vfsmatch.UnlimitedDepth) {
			depth--;
			if (depth == 0) {
				return;
			}
		}

		if (entries.Directories != null) {
			for (dir in entries.Directories) {
				if (!this.directoryMatcher.matchesDirectoryParts(absPrefix, dir)) {
					continue;
				}
				final absDir = absPrefix + dir;
				var childRealPath = "";
				if (entries.Symlinks != null) {
					if (!entries.Symlinks.exists(dir)) {
						// Non-symlink directory: compute realpath incrementally.
						childRealPath = Tspath.CombinePaths(realPath, dir);
					}
					// else: symlink directory; leave childRealPath empty to force Realpath call.
				}
				// If Symlinks is nil, the FS doesn't track symlinks;
				// leave childRealPath empty to call Realpath (preserving old behavior).
				this.visit(pathPrefix + dir, absDir, depth, childRealPath);
			}
		}
	}
}

// SpecMatcher wraps multiple glob patterns for matching paths.
class SpecMatcher {
	@:allow(ts.vfs.vfsmatch)
	var patterns:Null<Array<GlobPattern>> = null;

	@:allow(ts.vfs.vfsmatch)
	function new() {}

	// MatchString returns true if any pattern matches the path.
	public function MatchString(path:String):Bool {
		for (i in 0...this.patterns.length) {
			if (this.patterns[i].matches(path)) {
				return true;
			}
		}
		return false;
	}

	// MatchIndex returns the index of the first matching pattern, or -1.
	public function MatchIndex(path:String):Int {
		for (i in 0...this.patterns.length) {
			if (this.patterns[i].matches(path)) {
				return i;
			}
		}
		return -1;
	}
}

#if tshx_parallel
// --- prefetch.go (TypeScript main #64877) ---
@:allow(ts.vfs.vfsmatch)
class PrefetchedDirectory {
	final realPath:String;
	final entries:Entries;

	function new(realPath:String, entries:Entries) {
		this.realPath = realPath;
		this.entries = entries;
	}
}

private class PrefetchItem {
	public final path:String;
	// realPath is empty when it must be resolved with the host.
	public final realPath:String;
	public final depth:Int;

	public function new(path:String, realPath:String, depth:Int) {
		this.path = path;
		this.realPath = realPath;
		this.depth = depth;
	}
}

// prefetchDirectories reads the directories that GlobVisitor.visit is expected to walk on the pool's threads, so
// the subsequent ordered walk does not wait on sequential directory reads. The walk remains the source of truth and
// reads anything missing from the result itself.
//
// Each directory is queued at most once. Base paths are all marked as queued before any is read, so a walk from an
// ancestor base path stops at a descendant base path rather than reading its subtree again.
//
// Symlinked directories are not followed. Every prefetched directory is then reached through its only non-aliased
// spelling below a base path, so the prefetch cannot cycle and its result does not depend on scheduling. The walk
// reads symlinked subtrees itself, exactly as it would without a prefetch.
// PORT: keys are the walk's absolute path strings (Go: RootedDirectoryPath); a host exception is rethrown by
// the work group (Go: recovered, then re-raised on the calling goroutine).
@:allow(ts.vfs.vfsmatch)
class DirectoryPrefetcher {
	final host:FS;
	final directoryMatcher:GlobMatcher;
	final useCaseSensitiveFileNames:Bool;
	final wg = new ts.core.Workgroup.ParallelWorkGroup();
	final mutex = new sys.thread.Mutex();
	final scheduled = new StringMap<Bool>();
	final results = new StringMap<PrefetchedDirectory>();

	function new(host:FS, directoryMatcher:GlobMatcher, useCaseSensitiveFileNames:Bool) {
		this.host = host;
		this.directoryMatcher = directoryMatcher;
		this.useCaseSensitiveFileNames = useCaseSensitiveFileNames;
	}

	static function prefetchDirectories(host:FS, directoryMatcher:GlobMatcher, useCaseSensitiveFileNames:Bool, basePaths:Array<String>,
			depth:Int):StringMap<PrefetchedDirectory> {
		final p = new DirectoryPrefetcher(host, directoryMatcher, useCaseSensitiveFileNames);
		final items:Array<PrefetchItem> = [];
		for (basePath in basePaths) {
			if (!p.scheduled.exists(basePath)) {
				p.scheduled.set(basePath, true);
				items.push(new PrefetchItem(basePath, "", depth));
			}
		}
		for (item in items)
			p.queue(item);
		p.wg.RunAndWait();
		return p.results;
	}

	function queue(item:PrefetchItem):Void {
		this.wg.Queue(() -> this.run(item));
	}

	function run(item:PrefetchItem):Void {
		final children:Array<PrefetchItem> = [];
		final dir = this.fetch(item, children);
		final unscheduled:Array<PrefetchItem> = [];
		this.mutex.acquire();
		this.results.set(item.path, dir);
		for (child in children) {
			if (!this.scheduled.exists(child.path)) {
				this.scheduled.set(child.path, true);
				unscheduled.push(child);
			}
		}
		this.mutex.release();
		for (child in unscheduled)
			this.queue(child);
	}

	function fetch(item:PrefetchItem, children:Array<PrefetchItem>):PrefetchedDirectory {
		var realPath = item.realPath;
		if (realPath == "") {
			realPath = this.host.Realpath(item.path);
		}
		final entries = this.host.GetAccessibleEntries(item.path);
		final dir = new PrefetchedDirectory(realPath, entries);

		var depth = item.depth;
		if (depth != Vfsmatch.UnlimitedDepth) {
			depth--;
			if (depth == 0) {
				return dir;
			}
		}

		// the same spellings as GlobVisitor.visit: its absPrefix + dir and Tspath.CombinePaths(realPath, dir)
		final absPrefix = Vfsmatch.ensureTrailingSlash(item.path);
		if (entries.Directories != null) {
			for (name in entries.Directories) {
				if (!this.directoryMatcher.matchesDirectoryParts(absPrefix, name)) {
					continue;
				}
				final childPath = absPrefix + name;
				var childRealPath = Tspath.CombinePaths(realPath, name);
				if (entries.Symlinks != null) {
					if (entries.Symlinks.exists(name)) {
						continue;
					}
				} else {
					// The host does not report symlinks; resolve the child to find out.
					final resolved = this.host.Realpath(childPath);
					if (Tspath.GetCanonicalFileName(resolved, this.useCaseSensitiveFileNames)
						!= Tspath.GetCanonicalFileName(childRealPath, this.useCaseSensitiveFileNames)) {
						continue;
					}
					childRealPath = resolved;
				}
				children.push(new PrefetchItem(childPath, childRealPath, depth));
			}
		}
		return dir;
	}
}
#end

// PORT: perf — Vfsmatch.nextPathPartParts as a cursor: advance(prefix, suffix, offset) is its ok, the part is
// str[start, end) and next its next offset (the same cases; for GlobPattern.matchPathParts).
private class PathPartCursor {
	public var str:String = "";
	public var start:Int = 0;
	public var end:Int = 0;
	public var next:Int = 0;

	public function new() {}

	inline function set(str:String, start:Int, end:Int, next:Int):Bool {
		this.str = str;
		this.start = start;
		this.end = end;
		this.next = next;
		return true;
	}

	public function advance(prefix:String, suffix:String, offset:Int):Bool {
		if (suffix.length == 0) {
			return this.single(prefix, offset);
		}
		if (prefix.length == 0) {
			return this.single(suffix, offset);
		}
		final totalLen = prefix.length + suffix.length;
		if (offset >= totalLen) {
			return false;
		}
		if (offset == 0 && StringTools.fastCodeAt(prefix, 0) == '/'.code) {
			return this.set(prefix, 0, 0, 1);
		}
		if (offset < prefix.length) {
			while (offset < prefix.length && StringTools.fastCodeAt(prefix, offset) == '/'.code) {
				offset++;
			}
			if (offset < prefix.length) {
				final idx = prefix.indexOf("/", offset);
				if (idx < 0) {
					throw "slice bounds out of range";
				}
				return this.set(prefix, offset, idx, idx);
			}
		}
		final sOff = offset - prefix.length;
		if (sOff >= suffix.length) {
			return false;
		}
		return this.set(suffix, sOff, suffix.length, totalLen);
	}

	function single(s:String, offset:Int):Bool {
		if (offset >= s.length) {
			return false;
		}
		if (offset == 0 && StringTools.fastCodeAt(s, 0) == '/'.code) {
			return this.set(s, 0, 0, 1);
		}
		while (offset < s.length && StringTools.fastCodeAt(s, offset) == '/'.code) {
			offset++;
		}
		if (offset >= s.length) {
			return false;
		}
		final idx = s.indexOf("/", offset);
		if (idx >= 0) {
			return this.set(s, offset, idx, idx);
		}
		return this.set(s, offset, s.length, s.length);
	}

	public inline function toString():String {
		return this.str.substring(this.start, this.end);
	}

	// Vfsmatch.isHiddenPath
	public inline function isHidden():Bool {
		return this.end > this.start && StringTools.fastCodeAt(this.str, this.start) == '.'.code;
	}

	// Vfsmatch.isPackageFolder (its lengths first)
	public function isPackageFolder():Bool {
		final n = this.end - this.start;
		return (n == 12 || n == 13 || n == 16) && Vfsmatch.isPackageFolder(this.toString());
	}

	// GlobPattern.stringsEqual(literal, part)
	public function equals(literal:String, caseSensitive:Bool):Bool {
		if (!caseSensitive) {
			return Strings.EqualFold(literal, this.toString());
		}
		final n = this.end - this.start;
		if (literal.length != n) {
			return false;
		}
		for (i in 0...n) {
			if (StringTools.fastCodeAt(literal, i) != StringTools.fastCodeAt(this.str, this.start + i)) {
				return false;
			}
		}
		return true;
	}
}
