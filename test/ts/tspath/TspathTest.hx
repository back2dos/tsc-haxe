package ts.tspath;

import haxe.ds.StringMap;
import go.Regexp;
import go.Strings;
import go.Tuple;
import ts.tspath.Path;
import ts.tspath.Tspath.*;

// Port of path_test.go, ignoredpaths_test.go, startsWithDirectory_test.go, untitled_test.go.
// Benchmarks (BenchmarkCombinePaths, BenchmarkGetNormalizedAbsolutePath, BenchmarkToFileNameLowerCase,
// BenchmarkHasRelativePathSegment, BenchmarkPathIsRelative) are not ported.
// Fuzz* functions run their seed corpus only, as `go test` does without -fuzz.
@:access(ts.tspath.Tspath)
class TspathTest {
	// assert.DeepEqual for []string (nil and empty differ, as in Go).
	static function deq(expected:Array<String>, actual:Array<String>, ?pos:haxe.PosInfos) {
		T.eq(expected == null ? "nil" : "[" + expected.join("|") + "]", actual == null ? "nil" : "[" + actual.join("|") + "]", pos);
	}

	// --- path_test.go helpers ---

	static final getNormalizedAbsolutePathTests:Array<Array<Array<String>>> = [
		// "non-normalized inputs"
		[
			["/.", ""], ["/./", ""], ["/../", ""], ["/a/", ""], ["/a/.", ""], ["/a/foo.", ""], ["/a/./", ""], ["/a/./b", ""], ["/a/./b/", ""], ["/a/..", ""],
			["/a/../", ""], ["/a/../", ""], ["/a/../b", ""], ["/a/../b/", ""], ["/a/..", ""], ["/a/..", "/"], ["/a/..", "b/"], ["/a/..", "/b"], ["/a/.", "b"],
			["/a/.", "."]
		],
		// "normalized inputs"
		[["/a/b", ""], ["/one/two/three", ""], ["/users/root/project/src/foo.ts", ""]],
		// "normalized inputs (long)"
		[
			["/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z", ""],
			[
				"/one/two/three/four/five/six/seven/eight/nine/ten/eleven/twelve/thirteen/fourteen/fifteen/sixteen/seventeen/eighteen/nineteen/twenty",
				""
			],
			["/users/root/project/src/foo/bar/baz/qux/quux/corge/grault/garply/waldo/fred/plugh/xyzzy/thud", ""],
			[
				"/lorem/ipsum/dolor/sit/amet/consectetur/adipiscing/elit/sed/do/eiusmod/tempor/incididunt/ut/labore/et/dolore/magna/aliqua/ut/enim/ad/minim/veniam",
				""
			]
		]
	];

	static function repeat(s:String, n:Int):String {
		final b = new StringBuf();
		for (_ in 0...n)
			b.add(s);
		return b.toString();
	}

	static final toFileNameLowerCaseTests:Array<String> = [
		"/path/to/file.ext",
		"/PATH/TO/FILE.EXT",
		"/path/to/FILE.EXT",
		"/user/UserName/projects/Project/file.ts",
		"/user/UserName/projects/projectß/file.ts",
		"/user/UserName/projects/İproject/file.ts",
		"/user/UserName/projects/ı/file.ts",
		repeat("FoO/", 100),
	];

	// See [toFileNameLowerCase] for more info.
	//
	// To avoid having to do string building for most common cases, also ignore
	// a-z, 0-9, \u0131, \u00DF, \, /, ., : and space
	// PORT: Go RE2 `[^\x{0130}\x{0131}\x{00DF}a-z0-9\\/:\-_. ]+` written with literal characters.
	static final fileNameLowerCaseRegExp = Regexp.MustCompile("[^İıßa-z0-9\\\\/:\\-_. ]+");

	static function oldToFileNameLowerCase(fileName:String):String {
		return fileNameLowerCaseRegExp.ReplaceAllStringFunc(fileName, Strings.ToLower);
	}

	// PORT: Go `$` written as `(?![\s\S])` (go.Regexp header).
	static final relativePathSegmentRegExp = Regexp.MustCompile("//|(?:^|/)\\.\\.?(?:(?![\\s\\S])|/)");

	static function oldHasRelativePathSegment(p:String):Bool {
		return relativePathSegmentRegExp.MatchString(p);
	}

	// Go struct {p string; bench bool}: only p is used outside benchmarks.
	static final hasRelativePathSegmentTests:Array<String> = [
		"//",
		"foo/bar/baz",
		"foo/./baz",
		"foo/../baz",
		"foo/bar/baz/.",
		"./some/path",
		"/foo//bar/",
		"/foo/./bar/../../.",
		repeat("foo/", 100) + "..",
	];

	static function shortenName(name:String):String {
		if (name.length > 20) {
			return name.substring(0, 20) + "...etc";
		}
		return name;
	}

	static function normalizePath_old(path:String):String {
		path = NormalizeSlashes(path);
		// Most paths don't require normalization
		if (!hasRelativePathSegment(path)) {
			return path;
		}
		// Some paths only require cleanup of `/./` or leading `./`
		var simplified = Strings.ReplaceAll(path, "/./", "/");
		simplified = Strings.TrimPrefix(simplified, "./");
		if (simplified != path && !hasRelativePathSegment(simplified)) {
			path = simplified;
			return path;
		}
		// Other paths require full normalization
		var normalized = GetPathFromPathComponents(reducePathComponents(GetPathComponents(path, "")));
		if (normalized != "" && HasTrailingDirectorySeparator(path)) {
			normalized = EnsureTrailingDirectorySeparator(normalized);
		}
		return normalized;
	}

	static function getNormalizedAbsolutePath_old(fileName:String, currentDirectory:String):String {
		return GetPathFromPathComponents(GetNormalizedPathComponents(fileName, currentDirectory));
	}

	public static function run() {
		// --- path_test.go ---

		T.run("TestNormalizeSlashes", () -> {
			T.eq("a", NormalizeSlashes("a"));
			T.eq("a/b", NormalizeSlashes("a/b"));
			T.eq("a/b", NormalizeSlashes("a\\b"));
			T.eq("//server/path", NormalizeSlashes("\\\\server\\path"));
		});

		T.run("TestGetRootLength", () -> {
			T.eq(0, GetRootLength("a"));
			T.eq(1, GetRootLength("/"));
			T.eq(1, GetRootLength("/path"));
			T.eq(2, GetRootLength("c:"));
			T.eq(0, GetRootLength("c:d"));
			T.eq(3, GetRootLength("c:/"));
			T.eq(3, GetRootLength("c:\\"));
			T.eq(8, GetRootLength("//server"));
			T.eq(9, GetRootLength("//server/share"));
			T.eq(8, GetRootLength("\\\\server"));
			T.eq(9, GetRootLength("\\\\server\\share"));
			T.eq(8, GetRootLength("file:///"));
			T.eq(8, GetRootLength("file:///path"));
			T.eq(10, GetRootLength("file:///c:"));
			T.eq(8, GetRootLength("file:///c:d"));
			T.eq(11, GetRootLength("file:///c:/path"));
			T.eq(12, GetRootLength("file:///c%3a"));
			T.eq(8, GetRootLength("file:///c%3ad"));
			T.eq(13, GetRootLength("file:///c%3a/path"));
			T.eq(12, GetRootLength("file:///c%3A"));
			T.eq(8, GetRootLength("file:///c%3Ad"));
			T.eq(13, GetRootLength("file:///c%3A/path"));
			T.eq(16, GetRootLength("file://localhost"));
			T.eq(17, GetRootLength("file://localhost/"));
			T.eq(17, GetRootLength("file://localhost/path"));
			T.eq(19, GetRootLength("file://localhost/c:"));
			T.eq(17, GetRootLength("file://localhost/c:d"));
			T.eq(20, GetRootLength("file://localhost/c:/path"));
			T.eq(21, GetRootLength("file://localhost/c%3a"));
			T.eq(17, GetRootLength("file://localhost/c%3ad"));
			T.eq(22, GetRootLength("file://localhost/c%3a/path"));
			T.eq(21, GetRootLength("file://localhost/c%3A"));
			T.eq(17, GetRootLength("file://localhost/c%3Ad"));
			T.eq(22, GetRootLength("file://localhost/c%3A/path"));
			T.eq(13, GetRootLength("file://server"));
			T.eq(14, GetRootLength("file://server/"));
			T.eq(14, GetRootLength("file://server/path"));
			T.eq(14, GetRootLength("file://server/c:"));
			T.eq(14, GetRootLength("file://server/c:d"));
			T.eq(14, GetRootLength("file://server/c:/d"));
			T.eq(14, GetRootLength("file://server/c%3a"));
			T.eq(14, GetRootLength("file://server/c%3ad"));
			T.eq(14, GetRootLength("file://server/c%3a/d"));
			T.eq(14, GetRootLength("file://server/c%3A"));
			T.eq(14, GetRootLength("file://server/c%3Ad"));
			T.eq(14, GetRootLength("file://server/c%3A/d"));
			T.eq(13, GetRootLength("http://server"));
			T.eq(14, GetRootLength("http://server/path"));
		});

		T.run("TestPathIsAbsolute", () -> {
			// POSIX
			T.eq(true, PathIsAbsolute("/path/to/file.ext"));
			// DOS
			T.eq(true, PathIsAbsolute("c:/path/to/file.ext"));
			// URL
			T.eq(true, PathIsAbsolute("file:///path/to/file.ext"));
			// Non-absolute
			T.eq(false, PathIsAbsolute("path/to/file.ext"));
			T.eq(false, PathIsAbsolute("./path/to/file.ext"));
		});

		T.run("TestIsUrl", () -> {
			T.eq(false, IsUrl("a"));
			T.eq(false, IsUrl("/"));
			T.eq(false, IsUrl("c:"));
			T.eq(false, IsUrl("c:d"));
			T.eq(false, IsUrl("c:/"));
			T.eq(false, IsUrl("c:\\"));
			T.eq(false, IsUrl("//server"));
			T.eq(false, IsUrl("//server/share"));
			T.eq(false, IsUrl("\\\\server"));
			T.eq(false, IsUrl("\\\\server\\share"));

			T.eq(true, IsUrl("file:///path"));
			T.eq(true, IsUrl("file:///c:"));
			T.eq(true, IsUrl("file:///c:d"));
			T.eq(true, IsUrl("file:///c:/path"));
			T.eq(true, IsUrl("file://server"));
			T.eq(true, IsUrl("file://server/path"));
			T.eq(true, IsUrl("http://server"));
			T.eq(true, IsUrl("http://server/path"));
		});

		T.run("TestIsRootedDiskPath", () -> {
			T.eq(false, IsRootedDiskPath("a"));
			T.eq(true, IsRootedDiskPath("/"));
			T.eq(true, IsRootedDiskPath("c:"));
			T.eq(false, IsRootedDiskPath("c:d"));
			T.eq(true, IsRootedDiskPath("c:/"));
			T.eq(true, IsRootedDiskPath("c:\\"));
			T.eq(true, IsRootedDiskPath("//server"));
			T.eq(true, IsRootedDiskPath("//server/share"));
			T.eq(true, IsRootedDiskPath("\\\\server"));
			T.eq(true, IsRootedDiskPath("\\\\server\\share"));
			T.eq(false, IsRootedDiskPath("file:///path"));
			T.eq(false, IsRootedDiskPath("file:///c:"));
			T.eq(false, IsRootedDiskPath("file:///c:d"));
			T.eq(false, IsRootedDiskPath("file:///c:/path"));
			T.eq(false, IsRootedDiskPath("file://server"));
			T.eq(false, IsRootedDiskPath("file://server/path"));
			T.eq(false, IsRootedDiskPath("http://server"));
			T.eq(false, IsRootedDiskPath("http://server/path"));
		});

		T.run("TestGetDirectoryPath", () -> {
			T.eq("", GetDirectoryPath(""));
			T.eq("", GetDirectoryPath("a"));
			T.eq("a", GetDirectoryPath("a/b"));
			T.eq("/", GetDirectoryPath("/"));
			T.eq("/", GetDirectoryPath("/a"));
			T.eq("/", GetDirectoryPath("/a/"));
			T.eq("/a", GetDirectoryPath("/a/b"));
			T.eq("/a", GetDirectoryPath("/a/b/"));
			T.eq("c:", GetDirectoryPath("c:"));
			T.eq("", GetDirectoryPath("c:d"));
			T.eq("c:/", GetDirectoryPath("c:/"));
			T.eq("c:/", GetDirectoryPath("c:/path"));
			T.eq("c:/", GetDirectoryPath("c:/path/"));
			T.eq("//server", GetDirectoryPath("//server"));
			T.eq("//server/", GetDirectoryPath("//server/"));
			T.eq("//server/", GetDirectoryPath("//server/share"));
			T.eq("//server/", GetDirectoryPath("//server/share/"));
			T.eq("//server", GetDirectoryPath("\\\\server"));
			T.eq("//server/", GetDirectoryPath("\\\\server\\"));
			T.eq("//server/", GetDirectoryPath("\\\\server\\share"));
			T.eq("//server/", GetDirectoryPath("\\\\server\\share\\"));
			T.eq("file:///", GetDirectoryPath("file:///"));
			T.eq("file:///", GetDirectoryPath("file:///path"));
			T.eq("file:///", GetDirectoryPath("file:///path/"));
			T.eq("file:///c:", GetDirectoryPath("file:///c:"));
			T.eq("file:///", GetDirectoryPath("file:///c:d"));
			T.eq("file:///c:/", GetDirectoryPath("file:///c:/"));
			T.eq("file:///c:/", GetDirectoryPath("file:///c:/path"));
			T.eq("file:///c:/", GetDirectoryPath("file:///c:/path/"));
			T.eq("file://server", GetDirectoryPath("file://server"));
			T.eq("file://server/", GetDirectoryPath("file://server/"));
			T.eq("file://server/", GetDirectoryPath("file://server/path"));
			T.eq("file://server/", GetDirectoryPath("file://server/path/"));
			T.eq("http://server", GetDirectoryPath("http://server"));
			T.eq("http://server/", GetDirectoryPath("http://server/"));
			T.eq("http://server/", GetDirectoryPath("http://server/path"));
			T.eq("http://server/", GetDirectoryPath("http://server/path/"));
		});

			// !!!
			// getBaseFileName
			// getAnyExtensionFromPath

		T.run("TestGetPathComponents", () -> {
			deq([""], GetPathComponents("", ""));
			deq(["", "a"], GetPathComponents("a", ""));
			deq(["", ".", "a"], GetPathComponents("./a", ""));
			deq(["/"], GetPathComponents("/", ""));
			deq(["/", "a"], GetPathComponents("/a", ""));
			deq(["/", "a"], GetPathComponents("/a/", ""));
			deq(["c:"], GetPathComponents("c:", ""));
			deq(["", "c:d"], GetPathComponents("c:d", ""));
			deq(["c:/"], GetPathComponents("c:/", ""));
			deq(["c:/", "path"], GetPathComponents("c:/path", ""));
			deq(["//server"], GetPathComponents("//server", ""));
			deq(["//server/"], GetPathComponents("//server/", ""));
			deq(["//server/", "share"], GetPathComponents("//server/share", ""));
			deq(["file:///"], GetPathComponents("file:///", ""));
			deq(["file:///", "path"], GetPathComponents("file:///path", ""));
			deq(["file:///c:"], GetPathComponents("file:///c:", ""));
			deq(["file:///", "c:d"], GetPathComponents("file:///c:d", ""));
			deq(["file:///c:/"], GetPathComponents("file:///c:/", ""));
			deq(["file:///c:/", "path"], GetPathComponents("file:///c:/path", ""));
			deq(["file://server"], GetPathComponents("file://server", ""));
			deq(["file://server/"], GetPathComponents("file://server/", ""));
			deq(["file://server/", "path"], GetPathComponents("file://server/path", ""));
			deq(["http://server"], GetPathComponents("http://server", ""));
			deq(["http://server/"], GetPathComponents("http://server/", ""));
			deq(["http://server/", "path"], GetPathComponents("http://server/path", ""));
		});

		T.run("TestReducePathComponents", () -> {
			deq([""], reducePathComponents([""]));
			deq([""], reducePathComponents(["", "."]));
			deq(["", "a"], reducePathComponents(["", ".", "a"]));
			deq(["", "a"], reducePathComponents(["", "a", "."]));
			deq(["", ".."], reducePathComponents(["", ".."]));
			deq(["", "..", ".."], reducePathComponents(["", "..", ".."]));
			deq(["", "..", ".."], reducePathComponents(["", "..", ".", ".."]));
			deq([""], reducePathComponents(["", "a", ".."]));
			deq(["", "..", "a"], reducePathComponents(["", "..", "a"]));
			deq(["/"], reducePathComponents(["/"]));
			deq(["/"], reducePathComponents(["/", "."]));
			deq(["/"], reducePathComponents(["/", ".."]));
			deq(["/"], reducePathComponents(["/", "a", ".."]));
		});

		T.run("TestCombinePaths", () -> {
			// Non-rooted
			T.eq("path/to/file.ext", CombinePaths("path", "to", "file.ext"));
			T.eq("path/dir/../to/file.ext", CombinePaths("path", "dir", "..", "to", "file.ext"));
			// POSIX
			T.eq("/path/to/file.ext", CombinePaths("/path", "to", "file.ext"));
			T.eq("/to/file.ext", CombinePaths("/path", "/to", "file.ext"));
			// DOS
			T.eq("c:/path/to/file.ext", CombinePaths("c:/path", "to", "file.ext"));
			T.eq("c:/to/file.ext", CombinePaths("c:/path", "c:/to", "file.ext"));
			// URL
			T.eq("file:///path/to/file.ext", CombinePaths("file:///path", "to", "file.ext"));
			T.eq("file:///to/file.ext", CombinePaths("file:///path", "file:///to", "file.ext"));

			T.eq("/node_modules/@types", CombinePaths("/", "/node_modules/@types"));
			T.eq("/a/..", CombinePaths("/a/..", ""));
			T.eq("/a/../b", CombinePaths("/a/..", "b"));
			T.eq("/a/../b/", CombinePaths("/a/..", "b/"));
			T.eq("/", CombinePaths("/a/..", "/"));
			T.eq("/b", CombinePaths("/a/..", "/b"));
		});


		// BenchmarkCombinePaths: not ported (benchmark).

		T.run("TestResolvePath", () -> {
			T.eq("", ResolvePath(""));
			T.eq("", ResolvePath("."));
			T.eq("", ResolvePath("./"));
			T.eq("..", ResolvePath(".."));
			T.eq("../", ResolvePath("../"));
			T.eq("/", ResolvePath("/"));
			T.eq("/", ResolvePath("/."));
			T.eq("/", ResolvePath("/./"));
			T.eq("/", ResolvePath("/../"));
			T.eq("/a", ResolvePath("/a"));
			T.eq("/a/", ResolvePath("/a/"));
			T.eq("/a", ResolvePath("/a/."));
			T.eq("/a/", ResolvePath("/a/./"));
			T.eq("/a/b", ResolvePath("/a/./b"));
			T.eq("/a/b/", ResolvePath("/a/./b/"));
			T.eq("/", ResolvePath("/a/.."));
			T.eq("/", ResolvePath("/a/../"));
			T.eq("/b", ResolvePath("/a/../b"));
			T.eq("/b/", ResolvePath("/a/../b/"));
			T.eq("/b", ResolvePath("/a/..", "b"));
			T.eq("/", ResolvePath("/a/..", "/"));
			T.eq("/b/", ResolvePath("/a/..", "b/"));
			T.eq("/b", ResolvePath("/a/..", "/b"));
			T.eq("/a/b", ResolvePath("/a/.", "b"));
			T.eq("/a", ResolvePath("/a/.", "."));
			T.eq("a/b/c", ResolvePath("a", "b", "c"));
			T.eq("/c", ResolvePath("a", "b", "/c"));
			T.eq("a/c", ResolvePath("a", "b", "../c"));
		});

		T.run("TestGetNormalizedAbsolutePath", () -> {

			T.eq("/", GetNormalizedAbsolutePath("/", ""));
			T.eq("/", GetNormalizedAbsolutePath("/.", ""));
			T.eq("/", GetNormalizedAbsolutePath("/./", ""));
			T.eq("/", GetNormalizedAbsolutePath("/../", ""));
			T.eq("/a", GetNormalizedAbsolutePath("/a", ""));
			T.eq("/a", GetNormalizedAbsolutePath("/a/", ""));
			T.eq("/a", GetNormalizedAbsolutePath("/a/.", ""));
			T.eq("/a/foo.", GetNormalizedAbsolutePath("/a/foo.", ""));
			T.eq("/a", GetNormalizedAbsolutePath("/a/./", ""));
			T.eq("/a/b", GetNormalizedAbsolutePath("/a/./b", ""));
			T.eq("/a/b", GetNormalizedAbsolutePath("/a/./b/", ""));
			T.eq("/", GetNormalizedAbsolutePath("/a/..", ""));
			T.eq("/", GetNormalizedAbsolutePath("/a/../", ""));
			T.eq("/", GetNormalizedAbsolutePath("/a/../", ""));
			T.eq("/b", GetNormalizedAbsolutePath("/a/../b", ""));
			T.eq("/b", GetNormalizedAbsolutePath("/a/../b/", ""));
			T.eq("/", GetNormalizedAbsolutePath("/a/..", ""));
			T.eq("/", GetNormalizedAbsolutePath("/a/..", "/"));
			T.eq("/", GetNormalizedAbsolutePath("/a/..", "b/"));
			T.eq("/", GetNormalizedAbsolutePath("/a/..", "/b"));
			T.eq("/a", GetNormalizedAbsolutePath("/a/.", "b"));
			T.eq("/a", GetNormalizedAbsolutePath("/a/.", "."));

			// Tests as above, but with backslashes.
			T.eq("/", GetNormalizedAbsolutePath("\\", ""));
			T.eq("/", GetNormalizedAbsolutePath("\\.", ""));
			T.eq("/", GetNormalizedAbsolutePath("\\.\\", ""));
			T.eq("/", GetNormalizedAbsolutePath("\\..\\", ""));
			T.eq("/a", GetNormalizedAbsolutePath("\\a\\.\\", ""));
			T.eq("/a/b", GetNormalizedAbsolutePath("\\a\\.\\b", ""));
			T.eq("/a/b", GetNormalizedAbsolutePath("\\a\\.\\b\\", ""));
			T.eq("/", GetNormalizedAbsolutePath("\\a\\..", ""));
			T.eq("/", GetNormalizedAbsolutePath("\\a\\..\\", ""));
			T.eq("/", GetNormalizedAbsolutePath("\\a\\..\\", ""));
			T.eq("/b", GetNormalizedAbsolutePath("\\a\\..\\b", ""));
			T.eq("/b", GetNormalizedAbsolutePath("\\a\\..\\b\\", ""));
			T.eq("/", GetNormalizedAbsolutePath("\\a\\..", ""));
			T.eq("/", GetNormalizedAbsolutePath("\\a\\..", "\\"));
			T.eq("/", GetNormalizedAbsolutePath("\\a\\..", "b\\"));
			T.eq("/", GetNormalizedAbsolutePath("\\a\\..", "\\b"));
			T.eq("/a", GetNormalizedAbsolutePath("\\a\\.", "b"));
			T.eq("/a", GetNormalizedAbsolutePath("\\a\\.", "."));

			// Relative paths on an empty currentDirectory.
			T.eq("", GetNormalizedAbsolutePath("", ""));
			T.eq("", GetNormalizedAbsolutePath(".", ""));
			T.eq("", GetNormalizedAbsolutePath("./", ""));
			// Strangely, these do not normalize to the empty string.
			T.eq("..", GetNormalizedAbsolutePath("..", ""));
			T.eq("..", GetNormalizedAbsolutePath("../", ""));

			// Interaction between relative paths and currentDirectory.
			T.eq("/home", GetNormalizedAbsolutePath("", "/home"));
			T.eq("/home", GetNormalizedAbsolutePath(".", "/home"));
			T.eq("/home", GetNormalizedAbsolutePath("./", "/home"));
			T.eq("/", GetNormalizedAbsolutePath("..", "/home"));
			T.eq("/", GetNormalizedAbsolutePath("../", "/home"));
			T.eq("b/a", GetNormalizedAbsolutePath("a", "b"));
			T.eq("b/c/a", GetNormalizedAbsolutePath("a", "b/c"));

			// Base names starting or ending with a dot do not affect normalization.
			T.eq(".a", GetNormalizedAbsolutePath(".a", ""));
			T.eq("..a", GetNormalizedAbsolutePath("..a", ""));
			T.eq("a.", GetNormalizedAbsolutePath("a.", ""));
			T.eq("a..", GetNormalizedAbsolutePath("a..", ""));

			T.eq("/base/.a", GetNormalizedAbsolutePath("/base/./.a", ""));
			T.eq("/.a", GetNormalizedAbsolutePath("/base/../.a", ""));
			T.eq("/base/..a", GetNormalizedAbsolutePath("/base/./..a", ""));
			T.eq("/..a", GetNormalizedAbsolutePath("/base/../..a", ""));
			T.eq("/base/..a/b", GetNormalizedAbsolutePath("/base/./..a/b", ""));
			T.eq("/..a/b", GetNormalizedAbsolutePath("/base/../..a/b", ""));

			T.eq("/base/a.", GetNormalizedAbsolutePath("/base/./a.", ""));
			T.eq("/a.", GetNormalizedAbsolutePath("/base/../a.", ""));
			T.eq("/base/a..", GetNormalizedAbsolutePath("/base/./a..", ""));
			T.eq("/a..", GetNormalizedAbsolutePath("/base/../a..", ""));
			T.eq("/base/a../b", GetNormalizedAbsolutePath("/base/./a../b", ""));
			T.eq("/a../b", GetNormalizedAbsolutePath("/base/../a../b", ""));

			T.eq("", GetNormalizedAbsolutePath("a/..", ""));
			T.eq("/a", GetNormalizedAbsolutePath("/a//", ""));
			T.eq("//a/", GetNormalizedAbsolutePath("//a", "a"));
			T.eq("//", GetNormalizedAbsolutePath("/\\", ""));
			T.eq("a/a", GetNormalizedAbsolutePath("a///", "a"));
			T.eq("/", GetNormalizedAbsolutePath("/.//", ""));
			T.eq("///", GetNormalizedAbsolutePath("//\\\\", ""));
			T.eq("a", GetNormalizedAbsolutePath(".//a", "."));
			T.eq("..", GetNormalizedAbsolutePath("a/../..", ""));
			T.eq("/", GetNormalizedAbsolutePath("../..", "\\a"));
			T.eq("a:/", GetNormalizedAbsolutePath("a:", "b"));
			T.eq("../..", GetNormalizedAbsolutePath("a/../..", ".."));
			T.eq("", GetNormalizedAbsolutePath("a/../..", "b"));
			T.eq("../..", GetNormalizedAbsolutePath("a//../..", ".."));

			// Consecutive intermediate slashes are normalized to a single slash.
			T.eq("a/b", GetNormalizedAbsolutePath("a//b", ""));
			T.eq("a/b", GetNormalizedAbsolutePath("a///b", ""));
			T.eq("a/b/c", GetNormalizedAbsolutePath("a/b//c", ""));
			T.eq("/a/b/c", GetNormalizedAbsolutePath("/a/b//c", ""));
			T.eq("//a/b/c", GetNormalizedAbsolutePath("//a/b//c", ""));

			// Backslashes are converted to slashes,
			// and then consecutive intermediate slashes are normalized to a single slash
			T.eq("a/b", GetNormalizedAbsolutePath("a\\\\b", ""));
			T.eq("a/b", GetNormalizedAbsolutePath("a\\\\\\b", ""));
			T.eq("a/b/c", GetNormalizedAbsolutePath("a\\b\\\\c", ""));
			T.eq("/a/b/c", GetNormalizedAbsolutePath("\\a\\b\\\\c", ""));
			T.eq("//a/b/c", GetNormalizedAbsolutePath("\\\\a\\b\\\\c", ""));

			// The same occurs for mixed slashes.
			T.eq("a/b", GetNormalizedAbsolutePath("a/\\b", ""));
			T.eq("a/b", GetNormalizedAbsolutePath("a\\/b", ""));
			T.eq("a/b", GetNormalizedAbsolutePath("a\\/\\b", ""));
			T.eq("a/b/c", GetNormalizedAbsolutePath("a\\b//c", ""));
			T.eq("/a/b/c", GetNormalizedAbsolutePath("\\a\\b\\\\c", ""));
			T.eq("//a/b/c", GetNormalizedAbsolutePath("\\\\a\\b\\\\c", ""));
		});

		T.run("TestGetNormalizedAbsolutePathWithoutRoot", () -> {

			T.eq("a/b/c.txt", GetNormalizedAbsolutePathWithoutRoot("/a/b/c.txt", "/a/b"));
			T.eq("work/hello.txt", GetNormalizedAbsolutePathWithoutRoot("c:/work/hello.txt", "c:/work"));
			T.eq("work/hello.txt", GetNormalizedAbsolutePathWithoutRoot("c:/work/hello.txt", "d:/worspaces"));
		});

		// BenchmarkGetNormalizedAbsolutePath: not ported (benchmark).

		T.run("FuzzGetNormalizedAbsolutePath", () -> {
			for (tests in getNormalizedAbsolutePathTests) {
				for (test in tests) {
					final p = test[0];
					final dir = test[1];
					T.eq(getNormalizedAbsolutePath_old(p, dir), GetNormalizedAbsolutePath(p, dir));
				}
			}
		});

		T.run("TestGetRelativePathToDirectoryOrUrl", () -> {
			// !!!
			// Based on tests for `getRelativePathFromDirectory`.

			T.eq("", GetRelativePathToDirectoryOrUrl("/", "/", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("", GetRelativePathToDirectoryOrUrl("/a", "/a", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("", GetRelativePathToDirectoryOrUrl("/a/", "/a", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("..", GetRelativePathToDirectoryOrUrl("/a", "/", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("../b", GetRelativePathToDirectoryOrUrl("/a", "/b", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("../../b", GetRelativePathToDirectoryOrUrl("/a/b", "/b", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("../../../b", GetRelativePathToDirectoryOrUrl("/a/b/c", "/b", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("../../../b/c", GetRelativePathToDirectoryOrUrl("/a/b/c", "/b/c", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("..", GetRelativePathToDirectoryOrUrl("/a/b/c", "/a/b", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("d:/", GetRelativePathToDirectoryOrUrl("c:", "d:", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("", GetRelativePathToDirectoryOrUrl("file:///", "file:///", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("", GetRelativePathToDirectoryOrUrl("file:///a", "file:///a", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("", GetRelativePathToDirectoryOrUrl("file:///a/", "file:///a", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("..", GetRelativePathToDirectoryOrUrl("file:///a", "file:///", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("../b", GetRelativePathToDirectoryOrUrl("file:///a", "file:///b", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("../../b", GetRelativePathToDirectoryOrUrl("file:///a/b", "file:///b", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("../../../b", GetRelativePathToDirectoryOrUrl("file:///a/b/c", "file:///b", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("../../../b/c", GetRelativePathToDirectoryOrUrl("file:///a/b/c", "file:///b/c", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("..", GetRelativePathToDirectoryOrUrl("file:///a/b/c", "file:///a/b", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
			T.eq("file:///d:/", GetRelativePathToDirectoryOrUrl("file:///c:", "file:///d:", false /*isAbsolutePathAnUrl*/, new ComparePathsOptions()));
		});

		T.run("TestToFileNameLowerCase", () -> {
			T.eq("/user/username/projects/project/file.ts", ToFileNameLowerCase("/user/UserName/projects/Project/file.ts"));
			T.eq("/user/username/projects/projectß/file.ts", ToFileNameLowerCase("/user/UserName/projects/projectß/file.ts"));
			T.eq("/user/username/projects/İproject/file.ts", ToFileNameLowerCase("/user/UserName/projects/İproject/file.ts"));
			T.eq("/user/username/projects/ı/file.ts", ToFileNameLowerCase("/user/UserName/projects/ı/file.ts"));
		});

		// BenchmarkToFileNameLowerCase: not ported (benchmark).

		T.run("FuzzToFileNameLowerCase", () -> {
			for (p in toFileNameLowerCaseTests) {
				T.eq(oldToFileNameLowerCase(p), ToFileNameLowerCase(p));
			}
		});

		T.run("TestToPath", () -> {
			T.eq("path/to/file.ext", (ToPath("file.ext", "path/to", false /*useCaseSensitiveFileNames*/):String));
			T.eq("/path/to/file.ext", (ToPath("file.ext", "/path/to", true /*useCaseSensitiveFileNames*/):String));
			T.eq("/path/file.ext", (ToPath("/path/to/../file.ext", "path/to", true /*useCaseSensitiveFileNames*/):String));
		});


		// BenchmarkHasRelativePathSegment: not ported (benchmark).

		T.run("FuzzHasRelativePathSegment", () -> {
			for (p in hasRelativePathSegmentTests) {
				T.eq(oldHasRelativePathSegment(p), hasRelativePathSegment(p));
			}
		});

		T.run("TestPathIsRelative", () -> {
			// Go struct {p string; isRelative bool; benchmark bool}; benchmark is unused here.
			final pathIsRelativeTests:Array<Pair<String, Bool>> = [
				// relative
				new Pair(".", true),
				new Pair("..", true),
				new Pair("./", true),
				new Pair("../", true),
				new Pair("./foo/bar", true),
				new Pair("../foo/bar", true),
				new Pair("../" + repeat("foo/", 100), true),
				// non-relative
				new Pair("", false),
				new Pair("foo", false),
				new Pair("foo/bar", false),
				new Pair("/foo/bar", false),
				new Pair("c:/foo/bar", false),
			];
			// func init(): append the backslash variants.
			final old = pathIsRelativeTests.copy();
			for (t in old) {
				pathIsRelativeTests.push(new Pair(Strings.ReplaceAll(t.a, "/", "\\"), t.b));
			}
			for (tt in pathIsRelativeTests) {
				final name = shortenName(tt.a);
				T.isTrue(PathIsRelative(tt.a) == tt.b, name);
			}
		});

		// BenchmarkPathIsRelative: not ported (benchmark).

		T.run("TestGetCommonParents", () -> {
			final opts = new ComparePathsOptions();

			// "empty input"
			{
				final paths:Array<String> = null;
				final r = GetCommonParents(paths, 1, GetPathComponents, opts);
				T.eq(0, r.b == null ? 0 : Lambda.count(r.b));
				deq(null, r.a);
			}

			// "single path returns itself"
			{
				final paths = ["/a/b/c/d"];
				final r = GetCommonParents(paths, 1, GetPathComponents, opts);
				T.eq(0, r.b == null ? 0 : Lambda.count(r.b));
				deq([paths[0]], r.a);
			}

			// "paths shorter than minComponents are ignored"
			{
				final paths = ["/a/b/c/d", "/a/b/c/e", "/a/b/f/g", "/x/y"];
				final r = GetCommonParents(paths, 4, GetPathComponents, opts);
				T.eq(1, Lambda.count(r.b));
				T.isTrue(r.b.exists("/x/y"));
				deq(["/a/b/c", "/a/b/f/g"], r.a);
			}

			// "three paths share /a/b"
			{
				final paths = ["/a/b/c/d", "/a/b/c/e", "/a/b/f/g"];
				final r = GetCommonParents(paths, 1, GetPathComponents, opts);
				T.eq(0, r.b == null ? 0 : Lambda.count(r.b));
				deq(["/a/b"], r.a);
			}

			// "mixed with short path collapses to root when minComponents=1"
			{
				final paths = ["/a/b/c/d", "/a/b/c/e", "/a/b/f/g", "/x/y/z"];
				final r = GetCommonParents(paths, 1, GetPathComponents, opts);
				T.eq(0, r.b == null ? 0 : Lambda.count(r.b));
				deq(["/"], r.a);
			}

			// "mixed with short path preserves both when minComponents=3"
			{
				final paths = ["/a/b/c/d", "/a/b/c/e", "/a/b/f/g", "/x/y/z"];
				final r = GetCommonParents(paths, 3, GetPathComponents, opts);
				T.eq(0, r.b == null ? 0 : Lambda.count(r.b));
				deq(["/a/b", "/x/y/z"], r.a);
			}

			// "different volumes are returned individually"
			{
				final paths = ["c:/a/b/c/d", "d:/a/b/c/d"];
				final r = GetCommonParents(paths, 1, GetPathComponents, opts);
				T.eq(0, r.b == null ? 0 : Lambda.count(r.b));
				deq([paths[0], paths[1]], r.a);
			}

			// "duplicate paths deduplicate result"
			{
				final paths = ["/a/b/c/d", "/a/b/c/d"];
				final r = GetCommonParents(paths, 1, GetPathComponents, opts);
				T.eq(0, r.b == null ? 0 : Lambda.count(r.b));
				deq([paths[0]], r.a);
			}

			// "paths with few components are returned as-is when minComponents met"
			{
				final paths = ["/a/b/c/d", "/x/y"];
				final r = GetCommonParents(paths, 2, GetPathComponents, opts);
				T.eq(0, r.b == null ? 0 : Lambda.count(r.b));
				deq(["/a/b/c/d", "/x/y"], r.a);
			}

			// "minComponents=2"
			{
				final paths = ["/a/b/c/d", "/a/z/c/e", "/a/aaa/f/g", "/x/y/z"];
				final r = GetCommonParents(paths, 2, GetPathComponents, opts);
				T.eq(0, r.b == null ? 0 : Lambda.count(r.b));
				deq(["/a", "/x/y/z"], r.a);
			}

			// "trailing separators are handled"
			{
				final paths = ["/a/b/", "/a/b/c"];
				final r = GetCommonParents(paths, 1, GetPathComponents, opts);
				T.eq(0, r.b == null ? 0 : Lambda.count(r.b));
				deq(["/a/b"], r.a);
			}
		});

		// --- ignoredpaths_test.go ---

		T.run("TestContainsIgnoredPath", () -> {
			final tests:Array<Triple<String, String, Bool>> = [
				new Triple("node_modules dot path", "/project/node_modules/.pnpm/file.ts", true),
				new Triple("git directory", "/project/.git/hooks/pre-commit", true),
				new Triple("emacs lock file", "/project/src/file.ts.#", true),
				new Triple("regular file path", "/project/src/file.ts", false),
				new Triple("node_modules without dot", "/project/node_modules/lodash/index.js", false),
				new Triple("empty path", "", false),
				new Triple("path with multiple ignored patterns", "/project/node_modules/.pnpm/.git/.#file.ts", true),
				new Triple("case sensitive test", "/project/NODE_MODULES/.PNPM/file.ts", false), // Should be case sensitive
				new Triple("path with ignored pattern in middle", "/project/src/node_modules/.pnpm/dist/file.js", true),
				new Triple("path with ignored pattern at end", "/project/src/file.ts.#", true),
			];
			for (tt in tests) {
				final result = ContainsIgnoredPath(tt.b);
				T.isTrue(result == tt.c, tt.a);
			}
		});

		T.run("TestIgnoredPathsPatterns", () -> {
			// Test that all expected patterns are present
			final expectedPatterns = ["/node_modules/.", "/.git", ".#"];

			for (pattern in expectedPatterns) {
				final testPath = "/test" + pattern + "/file.ts";
				T.isTrue(ContainsIgnoredPath(testPath), 'Expected pattern \'$pattern\' to be detected in path \'$testPath\'');
			}
		});

		T.run("TestIgnoredPathsEdgeCases", () -> {
			final tests:Array<Triple<String, String, Bool>> = [
				new Triple("pattern at start", "/node_modules./file.ts", false), // Pattern is "/node_modules/." not "/node_modules."
				new Triple("pattern at end", "/project/file.ts.#", true),
				new Triple("multiple occurrences", "/project/.git/node_modules./.git/file.ts", true),
				new Triple("no slashes", "node_modules.file.ts", false),
				new Triple("single slash", "/file.ts", false),
			];
			for (tt in tests) {
				final result = ContainsIgnoredPath(tt.b);
				T.isTrue(result == tt.c, tt.a);
			}
		});

		// --- startsWithDirectory_test.go ---

		T.run("TestStartsWithDirectory", () -> {
			final tests:Array<StartsWithDirectoryTest> = [
				new StartsWithDirectoryTest("exact match case sensitive", "/project/src/file.ts", "/project/src", true, true),
				new StartsWithDirectoryTest("exact match case insensitive", "/project/src/file.ts", "/PROJECT/SRC", false, true),
				new StartsWithDirectoryTest("case sensitive mismatch", "/project/src/file.ts", "/PROJECT/SRC", true, false),
				new StartsWithDirectoryTest("file not in directory", "/project/lib/file.ts", "/project/src", true, false),
				new StartsWithDirectoryTest("file in subdirectory", "/project/src/components/Button.tsx", "/project/src", true, true),
				new StartsWithDirectoryTest("file in parent directory", "/project/file.ts", "/project/src", true, false),
				new StartsWithDirectoryTest("windows style separators", "C:\\project\\src\\file.ts", "C:\\project\\src", true, true),
				new StartsWithDirectoryTest("mixed separators", "/project/src/file.ts", "\\project\\src", true, false),
				new StartsWithDirectoryTest("empty directory name", "/project/src/file.ts", "", true, false),
				new StartsWithDirectoryTest("empty file name", "", "/project/src", true, false),
				// File name doesn't start with directory + separator
				new StartsWithDirectoryTest("identical paths", "/project/src", "/project/src", true, false),
				new StartsWithDirectoryTest("directory with trailing separator", "/project/src/file.ts", "/project/src/", true, true),
				new StartsWithDirectoryTest("unicode characters", "/project/测试/file.ts", "/project/测试", true, true),
				new StartsWithDirectoryTest("unicode case insensitive", "/project/测试/file.ts", "/PROJECT/测试", false, true),
			];
			for (tt in tests) {
				final result = StartsWithDirectory(tt.fileName, tt.directoryName, tt.useCaseSensitiveFileNames);
				T.isTrue(result == tt.expected, tt.name);
			}
		});

		T.run("TestStartsWithDirectoryEdgeCases", () -> {
			final tests:Array<StartsWithDirectoryTest> = [
				new StartsWithDirectoryTest("file name shorter than directory", "/proj", "/project", true, false),
				new StartsWithDirectoryTest("file name starts with directory but no separator", "/projectsrc/file.ts", "/project", true, false),
				new StartsWithDirectoryTest("relative paths", "src/file.ts", "src", true, true),
				new StartsWithDirectoryTest("absolute vs relative", "/project/src/file.ts", "project/src", true, false),
			];
			for (tt in tests) {
				final result = StartsWithDirectory(tt.fileName, tt.directoryName, tt.useCaseSensitiveFileNames);
				T.isTrue(result == tt.expected, tt.name);
			}
		});

		// --- untitled_test.go ---

		T.run("TestUntitledPathHandling", () -> {
			// Test that untitled paths are treated as rooted
			final untitledPath = "^/untitled/ts-nul-authority/Untitled-2";

			// GetEncodedRootLength should return 2 for "^/"
			final rootLength = GetEncodedRootLength(untitledPath);
			T.eq(2, rootLength);

			// IsRootedDiskPath should return true
			final isRooted = IsRootedDiskPath(untitledPath);
			T.isTrue(isRooted, "IsRootedDiskPath should return true for untitled paths");

			// ToPath should not resolve untitled paths against current directory
			final currentDir = "/home/user/project";
			final path = ToPath(untitledPath, currentDir, true);
			// The path should be the original untitled path
			T.eq("^/untitled/ts-nul-authority/Untitled-2", (path:String));

			// Test GetNormalizedAbsolutePath doesn't resolve untitled paths
			final normalized = GetNormalizedAbsolutePath(untitledPath, currentDir);
			T.eq("^/untitled/ts-nul-authority/Untitled-2", normalized);
		});

		T.run("TestUntitledPathEdgeCases", () -> {
			// Test edge cases
			final testCases:Array<Triple<String, Int, Bool>> = [
				new Triple("^/", 2, true), // Minimal untitled path
				new Triple("^/untitled/ts-nul-authority/test", 2, true), // Normal untitled path
				new Triple("^", 0, false), // Just ^ is not rooted
				new Triple("^x", 0, false), // ^x is not untitled
				new Triple("^^/", 0, false), // ^^/ is not untitled
				new Triple("x^/", 0, false), // x^/ is not untitled (doesn't start with ^)
				new Triple("^/untitled/ts-nul-authority/path/with/deeper/structure", 2, true), // Deeper path
			];
			for (tc in testCases) {
				final rootLength = GetEncodedRootLength(tc.a);
				T.eq(tc.b, rootLength);

				final isRooted = IsRootedDiskPath(tc.a);
				T.eq(tc.c, isRooted);
			}
		});
	}
}

// Go anonymous test struct of startsWithDirectory_test.go.
private class StartsWithDirectoryTest {
	public final name:String;
	public final fileName:String;
	public final directoryName:String;
	public final useCaseSensitiveFileNames:Bool;
	public final expected:Bool;

	public function new(name:String, fileName:String, directoryName:String, useCaseSensitiveFileNames:Bool, expected:Bool) {
		this.name = name;
		this.fileName = fileName;
		this.directoryName = directoryName;
		this.useCaseSensitiveFileNames = useCaseSensitiveFileNames;
		this.expected = expected;
	}
}
