package ts.vfs.vfsmatch;

import go.Slices;
import ts.core.Core;
import ts.vfs.Vfs;
import ts.vfs.VfsTestUtil.*;
import ts.vfs.vfsmatch.Vfsmatch;
import ts.vfs.vfstest.Vfstest;

// Port of vfsmatch_test.go. bench_test.go (benchmarks) is not ported.
// Test cases modeled after TypeScript's matchFiles tests in
// _submodules/TypeScript/src/testRunner/unittests/config/matchFiles.ts
typedef ReadDirTestCase = {
	name:String,
	host:() -> FS,
	?currentDir:String,
	?path:String,
	?extensions:Array<String>,
	?excludes:Array<String>,
	?includes:Array<String>,
	?depth:Int,
	expect:(got:Null<Array<String>>) -> Void,
}

class VfsmatchTest {
	// caseInsensitiveHost simulates a Windows-like file system
	static function caseInsensitiveHost():FS {
		return Vfstest.FromMap([
			"/dev/a.ts" => "",
			"/dev/a.d.ts" => "",
			"/dev/a.js" => "",
			"/dev/b.ts" => "",
			"/dev/b.js" => "",
			"/dev/c.d.ts" => "",
			"/dev/z/a.ts" => "",
			"/dev/z/abz.ts" => "",
			"/dev/z/aba.ts" => "",
			"/dev/z/b.ts" => "",
			"/dev/z/bbz.ts" => "",
			"/dev/z/bba.ts" => "",
			"/dev/x/a.ts" => "",
			"/dev/x/aa.ts" => "",
			"/dev/x/b.ts" => "",
			"/dev/x/y/a.ts" => "",
			"/dev/x/y/b.ts" => "",
			"/dev/js/a.js" => "",
			"/dev/js/b.js" => "",
			"/dev/js/d.min.js" => "",
			"/dev/js/ab.min.js" => "",
			"/ext/ext.ts" => "",
			"/ext/b/a..b.ts" => "",
		], false);
	}

	// caseSensitiveHost simulates a Unix-like case-sensitive file system
	static function caseSensitiveHost():FS {
		return Vfstest.FromMap([
			"/dev/a.ts" => "",
			"/dev/a.d.ts" => "",
			"/dev/a.js" => "",
			"/dev/b.ts" => "",
			"/dev/b.js" => "",
			"/dev/A.ts" => "",
			"/dev/B.ts" => "",
			"/dev/c.d.ts" => "",
			"/dev/z/a.ts" => "",
			"/dev/z/abz.ts" => "",
			"/dev/z/aba.ts" => "",
			"/dev/z/b.ts" => "",
			"/dev/z/bbz.ts" => "",
			"/dev/z/bba.ts" => "",
			"/dev/x/a.ts" => "",
			"/dev/x/b.ts" => "",
			"/dev/x/y/a.ts" => "",
			"/dev/x/y/b.ts" => "",
			"/dev/q/a/c/b/d.ts" => "",
			"/dev/js/a.js" => "",
			"/dev/js/b.js" => "",
			"/dev/js/d.MIN.js" => "",
		], true);
	}

	// commonFoldersHost includes node_modules, bower_components, jspm_packages
	static function commonFoldersHost():FS {
		return Vfstest.FromMap([
			"/dev/a.ts" => "",
			"/dev/a.d.ts" => "",
			"/dev/a.js" => "",
			"/dev/b.ts" => "",
			"/dev/x/a.ts" => "",
			"/dev/node_modules/a.ts" => "",
			"/dev/bower_components/a.ts" => "",
			"/dev/jspm_packages/a.ts" => "",
		], false);
	}

	// dottedFoldersHost includes files and folders starting with a dot
	static function dottedFoldersHost():FS {
		return Vfstest.FromMap([
			"/dev/x/d.ts" => "",
			"/dev/x/y/d.ts" => "",
			"/dev/x/y/.e.ts" => "",
			"/dev/x/.y/a.ts" => "",
			"/dev/.z/.b.ts" => "",
			"/dev/.z/c.ts" => "",
			"/dev/w/.u/e.ts" => "",
			"/dev/g.min.js/.g/g.ts" => "",
		], false);
	}

	// mixedExtensionHost has various file extensions
	static function mixedExtensionHost():FS {
		return Vfstest.FromMap([
			"/dev/a.ts" => "",
			"/dev/a.d.ts" => "",
			"/dev/a.js" => "",
			"/dev/b.tsx" => "",
			"/dev/b.d.ts" => "",
			"/dev/b.jsx" => "",
			"/dev/c.tsx" => "",
			"/dev/c.js" => "",
			"/dev/d.js" => "",
			"/dev/e.jsx" => "",
			"/dev/f.other" => "",
		], false);
	}

	// sameNamedDeclarationsHost has files with same names but different extensions
	static function sameNamedDeclarationsHost():FS {
		return Vfstest.FromMap([
			"/dev/a.tsx" => "",
			"/dev/a.d.ts" => "",
			"/dev/b.tsx" => "",
			"/dev/b.ts" => "",
			"/dev/c.tsx" => "",
			"/dev/m.ts" => "",
			"/dev/m.d.ts" => "",
			"/dev/n.tsx" => "",
			"/dev/n.ts" => "",
			"/dev/n.d.ts" => "",
			"/dev/o.ts" => "",
			"/dev/x.d.ts" => "",
		], false);
	}

	static function runReadDirectoryCase(tc:ReadDirTestCase) {
		var currentDir = tc.currentDir;
		if (currentDir == null || currentDir == "") {
			currentDir = "/";
		}
		var path = tc.path;
		if (path == null || path == "") {
			path = "/dev";
		}
		var depth:Null<Int> = tc.depth;
		if (depth == null || depth == 0) {
			depth = Vfsmatch.UnlimitedDepth;
		}
		final host = tc.host();
		final got = Vfsmatch.matchFiles(path, tc.extensions, tc.excludes, tc.includes, host.UseCaseSensitiveFileNames(), currentDir, depth, host);
		tc.expect(got);
	}

	// Helper functions
	static function contains(s:String, substr:String):Bool {
		return s.length >= substr.length && (s == substr || substr.length == 0 || (s.length > substr.length && containsAt(s, substr)));
	}

	static function containsAt(s:String, substr:String):Bool {
		var i = 0;
		while (i <= s.length - substr.length) {
			if (s.substring(i, i + substr.length) == substr) {
				return true;
			}
			i++;
		}
		return false;
	}

	static function hasSuffix(s:String, suffix:String):Bool {
		return s.length >= suffix.length && s.substring(s.length - suffix.length) == suffix;
	}

	public static function run() {
		{
			final cases:Array<ReadDirTestCase> = [
				{
					name: "defaults include common package folders",
					host: commonFoldersHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/b.ts"));
						T.isTrue(Slices.Contains(got, "/dev/x/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/node_modules/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/bower_components/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/jspm_packages/a.ts"));
					}
				},
				{
					name: "literal includes without exclusions",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["a.ts", "b.ts"],
					expect: (got) -> {
						eqStrings(["/dev/a.ts", "/dev/b.ts"], got);
					}
				},
				{
					name: "literal includes with non ts extensions excluded",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["a.js", "b.js"],
					expect: (got) -> {
						T.eq(0, Core.len(got));
					}
				},
				{
					name: "literal includes missing files excluded",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["z.ts", "x.ts"],
					expect: (got) -> {
						T.eq(0, Core.len(got));
					}
				},
				{
					name: "literal includes with literal excludes",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["b.ts"],
					includes: ["a.ts", "b.ts"],
					expect: (got) -> {
						eqStrings(["/dev/a.ts"], got);
					}
				},
				{
					name: "literal includes with wildcard excludes",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["*.ts", "z/??z.ts", "*/b.ts"],
					includes: ["a.ts", "b.ts", "z/a.ts", "z/abz.ts", "z/aba.ts", "x/b.ts"],
					expect: (got) -> {
						eqStrings(["/dev/z/a.ts", "/dev/z/aba.ts"], got);
					}
				},
				{
					name: "literal includes with recursive excludes",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["**/b.ts"],
					includes: ["a.ts", "b.ts", "x/a.ts", "x/b.ts", "x/y/a.ts", "x/y/b.ts"],
					expect: (got) -> {
						eqStrings(["/dev/a.ts", "/dev/x/a.ts", "/dev/x/y/a.ts"], got);
					}
				},
				{
					name: "case sensitive exclude is respected",
					host: caseSensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["**/b.ts"],
					includes: ["B.ts"],
					expect: (got) -> {
						eqStrings(["/dev/B.ts"], got);
					}
				},
				{
					name: "explicit includes keep common package folders",
					host: commonFoldersHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["a.ts", "b.ts", "node_modules/a.ts", "bower_components/a.ts", "jspm_packages/a.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/b.ts"));
						T.isTrue(Slices.Contains(got, "/dev/node_modules/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/bower_components/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/jspm_packages/a.ts"));
					}
				},
				{
					name: "wildcard include sorted order",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["z/*.ts", "x/*.ts"],
					expect: (got) -> {
						final expected = ["/dev/z/a.ts", "/dev/z/aba.ts", "/dev/z/abz.ts", "/dev/z/b.ts", "/dev/z/bba.ts", "/dev/z/bbz.ts", "/dev/x/a.ts", "/dev/x/aa.ts", "/dev/x/b.ts"];
						eqStrings(expected, got);
					}
				},
				{
					name: "wildcard include same named declarations excluded",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["*.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/b.ts"));
						T.isTrue(Slices.Contains(got, "/dev/a.d.ts"));
						T.isTrue(Slices.Contains(got, "/dev/c.d.ts"));
					}
				},
				{
					name: "wildcard star matches only ts files",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["*"],
					expect: (got) -> {
						if (got != null) for (f in got) {
							T.isTrue(contains(f, ".ts") || contains(f, ".tsx") || contains(f, ".d.ts"), 'unexpected file: ${f}');
						}
						T.isTrue(!Slices.Contains(got, "/dev/a.js"));
						T.isTrue(!Slices.Contains(got, "/dev/b.js"));
					}
				},
				{
					name: "wildcard question mark single character",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["x/?.ts"],
					expect: (got) -> {
						eqStrings(["/dev/x/a.ts", "/dev/x/b.ts"], got);
					}
				},
				{
					name: "wildcard recursive directory",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**/a.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/z/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/x/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/x/y/a.ts"));
					}
				},
				{
					name: "double asterisk matches zero-or-more directories",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["x/**/a.ts"],
					expect: (got) -> {
						T.eq(2, Core.len(got));
						T.isTrue(Slices.Contains(got, "/dev/x/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/x/y/a.ts"));
					}
				},
				{
					name: "wildcard multiple recursive directories",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["x/y/**/a.ts", "x/**/a.ts", "z/**/a.ts"],
					expect: (got) -> {
						T.isTrue(Core.len(got) > 0);
					}
				},
				{
					name: "wildcard case sensitive matching",
					host: caseSensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**/A.ts"],
					expect: (got) -> {
						eqStrings(["/dev/A.ts"], got);
					}
				},
				{
					name: "wildcard missing files excluded",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["*/z.ts"],
					expect: (got) -> {
						T.eq(0, Core.len(got));
					}
				},
				{
					name: "exclude folders with wildcards",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["z", "x"],
					includes: ["**/*"],
					expect: (got) -> {
						if (got != null) for (f in got) {
							T.isTrue(!contains(f, "/z/") && !contains(f, "/x/"), 'should not contain z or x: ${f}');
						}
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/b.ts"));
					}
				},
				{
					name: "include paths outside project absolute",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["*", "/ext/*"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/ext/ext.ts"));
					}
				},
				{
					name: "include paths outside project relative",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["**"],
					includes: ["*", "../ext/*"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/ext/ext.ts"));
					}
				},
				{
					name: "include files containing double dots",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["**"],
					includes: ["/ext/b/a..b.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/ext/b/a..b.ts"));
					}
				},
				{
					name: "exclude files containing double dots",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["/ext/b/a..b.ts"],
					includes: ["/ext/**/*"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/ext/ext.ts"));
						T.isTrue(!Slices.Contains(got, "/ext/b/a..b.ts"));
					}
				},
				{
					name: "common package folders implicitly excluded",
					host: commonFoldersHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**/a.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/x/a.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/node_modules/a.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/bower_components/a.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/jspm_packages/a.ts"));
					}
				},
				{
					name: "common package folders explicit recursive include",
					host: commonFoldersHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**/a.ts", "**/node_modules/a.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/node_modules/a.ts"));
					}
				},
				{
					name: "common package folders wildcard include",
					host: commonFoldersHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["*/a.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/x/a.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/node_modules/a.ts"));
					}
				},
				{
					name: "common package folders explicit wildcard include",
					host: commonFoldersHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["*/a.ts", "node_modules/a.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/x/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/node_modules/a.ts"));
					}
				},
				{
					name: "dotted folders not implicitly included",
					host: dottedFoldersHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["x/**/*", "w/*/*"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/x/d.ts"));
						T.isTrue(Slices.Contains(got, "/dev/x/y/d.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/x/.y/a.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/x/y/.e.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/w/.u/e.ts"));
					}
				},
				{
					name: "dotted folders explicitly included",
					host: dottedFoldersHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["x/.y/a.ts", "/dev/.z/.b.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/x/.y/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/.z/.b.ts"));
					}
				},
				{
					name: "dotted folders recursive wildcard matches directories",
					host: dottedFoldersHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**/.*/*"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/x/.y/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/.z/c.ts"));
						T.isTrue(Slices.Contains(got, "/dev/w/.u/e.ts"));
					}
				},
				{
					name: "trailing recursive include returns empty",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**"],
					expect: (got) -> {
						T.eq(0, Core.len(got));
					}
				},
				{
					name: "trailing recursive exclude removes everything",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["**"],
					includes: ["**/*"],
					expect: (got) -> {
						T.eq(0, Core.len(got));
					}
				},
				{
					name: "multiple recursive directory patterns in includes",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**/x/**/*"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/x/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/x/y/a.ts"));
					}
				},
				{
					name: "multiple recursive directory patterns in excludes",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["**/x/**"],
					includes: ["**/a.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/z/a.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/x/a.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/x/y/a.ts"));
					}
				},
				{
					name: "implicit globbification expands directory",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["z"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/z/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/z/aba.ts"));
						T.isTrue(Slices.Contains(got, "/dev/z/b.ts"));
					}
				},
				{
					name: "exclude patterns starting with starstar",
					host: caseSensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["**/x"],
					expect: (got) -> {
						if (got != null) for (f in got) {
							T.isTrue(!contains(f, "/x/"), 'should not contain /x/: ${f}');
						}
					}
				},
				{
					name: "include patterns starting with starstar",
					host: caseSensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**/x", "**/a/**/b"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/x/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/q/a/c/b/d.ts"));
					}
				},
				{
					name: "depth limit one",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					depth: 1,
					expect: (got) -> {
						if (got != null) for (f in got) {
							final suffix = f.substring("/dev/".length);
							T.isTrue(!contains(suffix, "/"), 'depth 1 should not include nested files: ${f}');
						}
					}
				},
				{
					name: "depth limit two",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					depth: 2,
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/z/a.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/x/y/a.ts"));
					}
				},
				{
					name: "mixed extensions only ts",
					host: mixedExtensionHost,
					extensions: [".ts"],
					expect: (got) -> {
						if (got != null) for (f in got) {
							T.isTrue(hasSuffix(f, ".ts"), 'should only have .ts files: ${f}');
						}
					}
				},
				{
					name: "mixed extensions ts and tsx",
					host: mixedExtensionHost,
					extensions: [".ts", ".tsx"],
					expect: (got) -> {
						if (got != null) for (f in got) {
							T.isTrue(hasSuffix(f, ".ts") || hasSuffix(f, ".tsx"), 'should only have .ts or .tsx files: ${f}');
						}
					}
				},
				{
					name: "mixed extensions js and jsx",
					host: mixedExtensionHost,
					extensions: [".js", ".jsx"],
					expect: (got) -> {
						if (got != null) for (f in got) {
							T.isTrue(hasSuffix(f, ".js") || hasSuffix(f, ".jsx"), 'should only have .js or .jsx files: ${f}');
						}
					}
				},
				{
					name: "min js files excluded by wildcard",
					host: caseInsensitiveHost,
					extensions: [".js"],
					includes: ["js/*"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/js/a.js"));
						T.isTrue(Slices.Contains(got, "/dev/js/b.js"));
						T.isTrue(!Slices.Contains(got, "/dev/js/d.min.js"));
						T.isTrue(!Slices.Contains(got, "/dev/js/ab.min.js"));
					}
				},
				{
					name: "min js exclusion is case-sensitive on case-sensitive FS",
					host: caseSensitiveHost,
					extensions: [".js"],
					includes: ["js/*"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/js/a.js"));
						T.isTrue(Slices.Contains(got, "/dev/js/b.js"));
						// Legacy behavior: only lowercase ".min.js" is excluded by default when matching is case-sensitive.
						T.isTrue(Slices.Contains(got, "/dev/js/d.MIN.js"));
					}
				},
				{
					name: "min js files explicitly included",
					host: caseInsensitiveHost,
					extensions: [".js"],
					includes: ["js/*.min.js"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/js/d.min.js"));
						T.isTrue(Slices.Contains(got, "/dev/js/ab.min.js"));
					}
				},
				{
					name: "min js files included when pattern mentions .min.",
					host: caseInsensitiveHost,
					extensions: [".js"],
					includes: ["js/*.min.*"],
					expect: (got) -> {
						T.eq(2, Core.len(got));
						T.isTrue(Slices.Contains(got, "/dev/js/d.min.js"));
						T.isTrue(Slices.Contains(got, "/dev/js/ab.min.js"));
					}
				},
				{
					name: "exclude literal node_modules folder",
					host: commonFoldersHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["node_modules"],
					includes: ["**/*"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/node_modules/a.ts"));
					}
				},
				{
					name: "same named declarations include ts",
					host: sameNamedDeclarationsHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["*.ts"],
					expect: (got) -> {
						T.isTrue(Core.len(got) > 0);
					}
				},
				{
					name: "same named declarations include tsx",
					host: sameNamedDeclarationsHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["*.tsx"],
					expect: (got) -> {
						if (got != null) for (f in got) {
							T.isTrue(hasSuffix(f, ".tsx"), 'should only have .tsx files: ${f}');
						}
					}
				},
				{
					name: "empty includes returns all matching files",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					expect: (got) -> {
						T.isTrue(Core.len(got) > 0);
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
					}
				},
				{
					name: "nil extensions returns all files",
					host: caseInsensitiveHost,
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/a.js"));
					}
				},
				{
					name: "empty extensions slice returns all files",
					host: caseInsensitiveHost,
					extensions: [],
					expect: (got) -> {
						T.isTrue(Core.len(got) > 0, 'expected files to be returned');
					}
				},
			];

			for (tc in cases) {
				T.run("TestReadDirectory/" + tc.name, () -> {
					runReadDirectoryCase(tc);
				});
			}
		}

		{
			final tests:Array<{name:String, input:String, expected:Bool}> = [
				{name: "simple", input: "foo", expected: true},
				{name: "folder", input: "src", expected: true},
				{name: "with extension", input: "foo.ts", expected: false},
				{name: "trailing dot", input: "foo.", expected: false},
				{name: "star", input: "*", expected: false},
				{name: "question", input: "?", expected: false},
				{name: "star suffix", input: "foo*", expected: false},
				{name: "question suffix", input: "foo?", expected: false},
				{name: "dot name", input: "foo.bar", expected: false},
				{name: "empty", input: "", expected: true},
			];

			for (tt in tests) {
				final tc = tt;
				T.run("TestIsImplicitGlob/" + tc.name, () -> {
					final result = Vfsmatch.IsImplicitGlob(tc.input);
					T.eq(tc.expected, result);
				});
			}
		}

		{
			final cases:Array<ReadDirTestCase> = [
				{
					name: "rooted include path",
					host: caseInsensitiveHost,
					extensions: [".ts"],
					includes: ["/dev/a.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
					}
				},
				{
					name: "include with extension in path",
					host: caseInsensitiveHost,
					extensions: [".ts"],
					includes: ["a.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
					}
				},
				{
					name: "special regex characters in path",
					host: () -> Vfstest.FromMap([
						"/dev/file+test.ts" => "",
						"/dev/file[0].ts" => "",
						"/dev/file(1).ts" => "",
						"/dev/file$money.ts" => "",
						"/dev/file^start.ts" => "",
						"/dev/file|pipe.ts" => "",
						"/dev/file#hash.ts" => "",
					], false),
					extensions: [".ts"],
					includes: ["file+test.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/file+test.ts"));
					}
				},
				{
					name: "include pattern starting with question mark",
					host: caseInsensitiveHost,
					extensions: [".ts"],
					includes: ["?.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/b.ts"));
					}
				},
				{
					name: "include pattern starting with star",
					host: caseInsensitiveHost,
					extensions: [".ts"],
					includes: ["*b.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/b.ts"));
					}
				},
				{
					name: "case insensitive file matching",
					host: () -> Vfstest.FromMap([
						"/dev/File.ts" => "",
						"/dev/FILE.ts" => "",
					], true),
					extensions: [".ts"],
					includes: ["*.ts"],
					expect: (got) -> {
						T.isTrue(Core.len(got) == 2);
					}
				},
				{
					name: "nested subdirectory base path",
					host: caseSensitiveHost,
					extensions: [".ts"],
					includes: ["q/a/c/b/d.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/q/a/c/b/d.ts"));
					}
				},
				{
					name: "current directory differs from path",
					host: caseInsensitiveHost,
					extensions: [".ts"],
					includes: ["z/*.ts"],
					expect: (got) -> {
						T.isTrue(Core.len(got) > 0);
					}
				},
			];

			for (tc in cases) {
				T.run("TestReadDirectoryEdgeCases/" + tc.name, () -> {
					runReadDirectoryCase(tc);
				});
			}
		}

		{
			final cases:Array<ReadDirTestCase> = [
				{
					name: "empty includes slice behavior",
					host: () -> Vfstest.FromMap([
						"/root/a.ts" => "",
					], true),
					path: "/root",
					currentDir: "/",
					extensions: [".ts"],
					includes: [],
					expect: (got) -> {
						if (Core.len(got) == 0) {
							return;
						}
						T.isTrue(Slices.Contains(got, "/root/a.ts"));
					}
				},
			];

			for (tc in cases) {
				T.run("TestReadDirectoryEmptyIncludes/" + tc.name, () -> {
					runReadDirectoryCase(tc);
				});
			}
		}

		{
			final cases:Array<ReadDirTestCase> = [
				{
					name: "detects and skips symlink cycles",
					host: () -> {
						final m:Map<String, Any> = [
							"/root/file.ts" => "",
							"/root/a/file.ts" => "",
							"/root/a/b" => Vfstest.Symlink("/root/a"),
						];
						return Vfstest.FromMap(m, true);
					},
					path: "/root",
					currentDir: "/",
					extensions: [".ts"],
					includes: ["**/*"],
					expect: (got) -> {
						final expected = ["/root/file.ts", "/root/a/file.ts"];
						eqStrings(expected, got);
					}
				},
			];

			for (tc in cases) {
				T.run("TestReadDirectorySymlinkCycle/" + tc.name, () -> {
					runReadDirectoryCase(tc);
				});
			}
		}

		{
			final cases:Array<ReadDirTestCase> = [
				{
					name: "sorted in include order then alphabetical",
					host: () -> Vfstest.FromMap([
						"/dev/z/a.ts" => "",
						"/dev/z/aba.ts" => "",
						"/dev/z/abz.ts" => "",
						"/dev/z/b.ts" => "",
						"/dev/z/bba.ts" => "",
						"/dev/z/bbz.ts" => "",
						"/dev/x/a.ts" => "",
						"/dev/x/aa.ts" => "",
						"/dev/x/b.ts" => "",
					], false),
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["z/*.ts", "x/*.ts"],
					expect: (got) -> {
						final expected = ["/dev/z/a.ts", "/dev/z/aba.ts", "/dev/z/abz.ts", "/dev/z/b.ts", "/dev/z/bba.ts", "/dev/z/bbz.ts", "/dev/x/a.ts", "/dev/x/aa.ts", "/dev/x/b.ts"];
						eqStrings(expected, got);
					}
				},
				{
					name: "recursive wildcards match dotted directories",
					host: () -> Vfstest.FromMap([
						"/dev/x/d.ts" => "",
						"/dev/x/y/d.ts" => "",
						"/dev/x/y/.e.ts" => "",
						"/dev/x/.y/a.ts" => "",
						"/dev/.z/.b.ts" => "",
						"/dev/.z/c.ts" => "",
						"/dev/w/.u/e.ts" => "",
						"/dev/g.min.js/.g/g.ts" => "",
					], false),
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**/.*/*"],
					expect: (got) -> {
						final expected = ["/dev/.z/c.ts", "/dev/g.min.js/.g/g.ts", "/dev/w/.u/e.ts", "/dev/x/.y/a.ts"];
						T.eq(Core.len(expected), Core.len(got));
						if (expected != null) for (want in expected) {
							T.isTrue(Slices.Contains(got, want));
						}
					}
				},
				{
					name: "common package folders implicitly excluded with wildcard",
					host: () -> Vfstest.FromMap([
						"/dev/a.ts" => "",
						"/dev/a.d.ts" => "",
						"/dev/a.js" => "",
						"/dev/b.ts" => "",
						"/dev/x/a.ts" => "",
						"/dev/node_modules/a.ts" => "",
						"/dev/bower_components/a.ts" => "",
						"/dev/jspm_packages/a.ts" => "",
					], false),
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**/a.ts"],
					expect: (got) -> {
						eqStrings(["/dev/a.ts", "/dev/x/a.ts"], got);
					}
				},
				{
					name: "js wildcard excludes min js files",
					host: () -> Vfstest.FromMap([
						"/dev/js/a.js" => "",
						"/dev/js/b.js" => "",
						"/dev/js/d.min.js" => "",
						"/dev/js/ab.min.js" => "",
					], false),
					extensions: [".js"],
					includes: ["js/*"],
					expect: (got) -> {
						eqStrings(["/dev/js/a.js", "/dev/js/b.js"], got);
					}
				},
				{
					name: "explicit min js pattern includes min files",
					host: () -> Vfstest.FromMap([
						"/dev/js/a.js" => "",
						"/dev/js/b.js" => "",
						"/dev/js/d.min.js" => "",
						"/dev/js/ab.min.js" => "",
					], false),
					extensions: [".js"],
					includes: ["js/*.min.js"],
					expect: (got) -> {
						final expected = ["/dev/js/ab.min.js", "/dev/js/d.min.js"];
						T.eq(Core.len(expected), Core.len(got));
						if (expected != null) for (want in expected) {
							T.isTrue(Slices.Contains(got, want));
						}
					}
				},
				{
					name: "literal excludes baseline",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["b.ts"],
					includes: ["a.ts", "b.ts"],
					expect: (got) -> {
						eqStrings(["/dev/a.ts"], got);
					}
				},
				{
					name: "wildcard excludes baseline",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["*.ts", "z/??z.ts", "*/b.ts"],
					includes: ["a.ts", "b.ts", "z/a.ts", "z/abz.ts", "z/aba.ts", "x/b.ts"],
					expect: (got) -> {
						eqStrings(["/dev/z/a.ts", "/dev/z/aba.ts"], got);
					}
				},
				{
					name: "recursive excludes baseline",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["**/b.ts"],
					includes: ["a.ts", "b.ts", "x/a.ts", "x/b.ts", "x/y/a.ts", "x/y/b.ts"],
					expect: (got) -> {
						eqStrings(["/dev/a.ts", "/dev/x/a.ts", "/dev/x/y/a.ts"], got);
					}
				},
				{
					name: "question mark baseline",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["x/?.ts"],
					expect: (got) -> {
						eqStrings(["/dev/x/a.ts", "/dev/x/b.ts"], got);
					}
				},
				{
					name: "recursive directory pattern baseline",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**/a.ts"],
					expect: (got) -> {
						eqStrings(["/dev/a.ts", "/dev/x/a.ts", "/dev/x/y/a.ts", "/dev/z/a.ts"], got);
					}
				},
				{
					name: "case sensitive baseline",
					host: caseSensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**/A.ts"],
					expect: (got) -> {
						eqStrings(["/dev/A.ts"], got);
					}
				},
				{
					name: "exclude folders baseline",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["z", "x"],
					includes: ["**/*"],
					expect: (got) -> {
						if (got != null) for (f in got) {
							T.isTrue(!contains(f, "/z/") && !contains(f, "/x/"), 'should not contain z or x: ${f}');
						}
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/b.ts"));
					}
				},
				{
					name: "implicit glob expansion baseline",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["z"],
					expect: (got) -> {
						eqStrings(["/dev/z/a.ts", "/dev/z/aba.ts", "/dev/z/abz.ts", "/dev/z/b.ts", "/dev/z/bba.ts", "/dev/z/bbz.ts"], got);
					}
				},
				{
					name: "trailing recursive directory baseline",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**"],
					expect: (got) -> {
						T.eq(0, Core.len(got));
					}
				},
				{
					name: "exclude trailing recursive directory baseline",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["**"],
					includes: ["**/*"],
					expect: (got) -> {
						T.eq(0, Core.len(got));
					}
				},
				{
					name: "multiple recursive directory patterns baseline",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**/x/**/*"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/x/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/x/aa.ts"));
						T.isTrue(Slices.Contains(got, "/dev/x/b.ts"));
						T.isTrue(Slices.Contains(got, "/dev/x/y/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/x/y/b.ts"));
					}
				},
				{
					name: "include dirs with starstar prefix baseline",
					host: caseSensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["**/x", "**/a/**/b"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/x/a.ts"));
						T.isTrue(Slices.Contains(got, "/dev/x/b.ts"));
						T.isTrue(Slices.Contains(got, "/dev/q/a/c/b/d.ts"));
					}
				},
				{
					name: "dotted folders not implicitly included baseline",
					host: dottedFoldersHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["x/**/*", "w/*/*"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/x/d.ts"));
						T.isTrue(Slices.Contains(got, "/dev/x/y/d.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/x/.y/a.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/x/y/.e.ts"));
						T.isTrue(!Slices.Contains(got, "/dev/w/.u/e.ts"));
					}
				},
				{
					name: "include paths outside project baseline",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					includes: ["*", "/ext/*"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/dev/a.ts"));
						T.isTrue(Slices.Contains(got, "/ext/ext.ts"));
					}
				},
				{
					name: "include files with double dots baseline",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["**"],
					includes: ["/ext/b/a..b.ts"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/ext/b/a..b.ts"));
					}
				},
				{
					name: "exclude files with double dots baseline",
					host: caseInsensitiveHost,
					extensions: [".ts", ".tsx", ".d.ts"],
					excludes: ["/ext/b/a..b.ts"],
					includes: ["/ext/**/*"],
					expect: (got) -> {
						T.isTrue(Slices.Contains(got, "/ext/ext.ts"));
						T.isTrue(!Slices.Contains(got, "/ext/b/a..b.ts"));
					}
				},
			];

			for (tc in cases) {
				T.run("TestReadDirectoryMatchesTypeScriptBaselines/" + tc.name, () -> {
					runReadDirectoryCase(tc);
				});
			}
		}

		// TestSpecMatcher tests the SpecMatcher API
		{
			final cases:Array<{
				name:String,
				specs:Array<String>,
				basePath:String,
				usage:Usage,
				useCaseSensitiveFileNames:Bool,
				matchingPaths:Array<String>,
				nonMatchingPaths:Array<String>
			}> = [
				{
					name: "simple wildcard",
					specs: ["*.ts"],
					basePath: "/project",
					usage: UsageFiles,
					useCaseSensitiveFileNames: true,
					matchingPaths: ["/project/a.ts", "/project/b.ts", "/project/foo.ts"],
					nonMatchingPaths: ["/project/a.js", "/project/sub/a.ts"],
				},
				{
					name: "recursive wildcard",
					specs: ["**/*.ts"],
					basePath: "/project",
					usage: UsageFiles,
					useCaseSensitiveFileNames: true,
					matchingPaths: ["/project/a.ts", "/project/sub/a.ts", "/project/sub/deep/a.ts"],
					nonMatchingPaths: ["/project/a.js"],
				},
				{
					name: "exclude pattern",
					specs: ["node_modules"],
					basePath: "/project",
					usage: UsageExclude,
					useCaseSensitiveFileNames: true,
					matchingPaths: ["/project/node_modules/foo"],
					nonMatchingPaths: ["/project/node_modules", "/project/src"],
				},
				{
					name: "case insensitive",
					specs: ["*.ts"],
					basePath: "/project",
					usage: UsageFiles,
					useCaseSensitiveFileNames: false,
					matchingPaths: ["/project/A.TS", "/project/B.Ts"],
					nonMatchingPaths: ["/project/a.js"],
				},
				{
					name: "multiple specs",
					specs: ["*.ts", "*.tsx"],
					basePath: "/project",
					usage: UsageFiles,
					useCaseSensitiveFileNames: true,
					matchingPaths: ["/project/a.ts", "/project/b.tsx"],
					nonMatchingPaths: ["/project/a.js"],
				},
			];

			for (tc in cases) {
				T.run("TestSpecMatcher/" + tc.name, () -> {
					final matcher = Vfsmatch.NewSpecMatcher(tc.specs, tc.basePath, tc.usage, tc.useCaseSensitiveFileNames);
					if (matcher == null) {
						T.fail("matcher should not be nil");
						return;
					}
					for (path in tc.matchingPaths) {
						T.isTrue(matcher.MatchString(path), 'should match: ${path}');
					}
					for (path in tc.nonMatchingPaths) {
						T.isTrue(!matcher.MatchString(path), 'should not match: ${path}');
					}
				});
			}
		}

		{
			final cases:Array<{
				name:String,
				specs:Array<String>,
				basePath:String,
				usage:Usage,
				useCaseSensitiveFileNames:Bool,
				paths:Array<String>,
				expected:Array<Bool>
			}> = [
				{
					name: "simple wildcard files",
					specs: ["*.ts"],
					basePath: "/project",
					usage: UsageFiles,
					useCaseSensitiveFileNames: true,
					paths: ["/project/a.ts", "/project/sub/a.ts", "/project/a.js"],
					expected: [true, false, false],
				},
				{
					name: "recursive wildcard files",
					specs: ["**/*.ts"],
					basePath: "/project",
					usage: UsageFiles,
					useCaseSensitiveFileNames: true,
					paths: ["/project/a.ts", "/project/sub/a.ts", "/project/a.js"],
					expected: [true, true, false],
				},
				{
					name: "exclude pattern matches prefix",
					specs: ["node_modules"],
					basePath: "/project",
					usage: UsageExclude,
					useCaseSensitiveFileNames: true,
					paths: ["/project/node_modules", "/project/node_modules/foo", "/project/src"],
					expected: [false, true, false],
				},
			];

			for (tc in cases) {
				T.run("TestSpecMatcher_MatchString/" + tc.name, () -> {
					T.eq(tc.expected.length, tc.paths.length);
					final m = Vfsmatch.NewSpecMatcher(tc.specs, tc.basePath, tc.usage, tc.useCaseSensitiveFileNames);
					T.isTrue(m != null);
					for (i in 0...tc.paths.length) {
						final path = tc.paths[i];
						T.eq(tc.expected[i], m.MatchString(path));
					}
				});
			}
		}

		{
			final cases:Array<{
				name:String,
				spec:String,
				basePath:String,
				usage:Usage,
				useCaseSensitiveFileNames:Bool,
				paths:Array<String>,
				expected:Array<Bool>
			}> = [
				{
					name: "single spec wildcard",
					spec: "*.ts",
					basePath: "/project",
					usage: UsageFiles,
					useCaseSensitiveFileNames: true,
					paths: ["/project/a.ts", "/project/sub/a.ts", "/project/a.js"],
					expected: [true, false, false],
				},
				{
					name: "single spec trailing starstar exclude allowed",
					spec: "**",
					basePath: "/project",
					usage: UsageExclude,
					useCaseSensitiveFileNames: true,
					paths: ["/project/a.ts", "/project/sub/a.ts"],
					expected: [true, true],
				},
			];

			for (tc in cases) {
				T.run("TestSingleSpecMatcher_MatchString/" + tc.name, () -> {
					T.eq(tc.expected.length, tc.paths.length);
					final m = Vfsmatch.NewSpecMatcher([tc.spec], tc.basePath, tc.usage, tc.useCaseSensitiveFileNames);
					T.isTrue(m != null);
					for (i in 0...tc.paths.length) {
						final path = tc.paths[i];
						T.eq(tc.expected[i], m.MatchString(path));
					}
				});
			}
		}

		{
			final cases:Array<{
				name:String,
				specs:Array<String>,
				basePath:String,
				usage:Usage,
				useCaseSensitiveFileNames:Bool,
				paths:Array<String>,
				expected:Array<Int>
			}> = [
				{
					name: "index lookup prefers first match",
					specs: ["*.ts", "*.tsx"],
					basePath: "/project",
					usage: UsageFiles,
					useCaseSensitiveFileNames: true,
					paths: ["/project/a.ts", "/project/a.tsx", "/project/a.js"],
					expected: [0, 1, -1],
				},
				{
					name: "exclude index lookup",
					specs: ["node_modules", "bower_components"],
					basePath: "/project",
					usage: UsageExclude,
					useCaseSensitiveFileNames: true,
					paths: [
						"/project/node_modules",
						"/project/node_modules/foo",
						"/project/bower_components",
						"/project/bower_components/bar",
						"/project/src"
					],
					expected: [-1, 0, -1, 1, -1],
				},
			];

			for (tc in cases) {
				T.run("TestSpecMatchers_MatchIndex/" + tc.name, () -> {
					T.eq(tc.expected.length, tc.paths.length);
					final m = Vfsmatch.NewSpecMatcher(tc.specs, tc.basePath, tc.usage, tc.useCaseSensitiveFileNames);
					T.isTrue(m != null);
					for (i in 0...tc.paths.length) {
						final path = tc.paths[i];
						T.eq(tc.expected[i], m.MatchIndex(path));
					}
				});
			}
		}

		{
			final cases:Array<{
				name:String,
				spec:String,
				basePath:String,
				usage:Usage,
				useCaseSensitiveFileNames:Bool,
				?expectNil:Bool,
				?matchingPaths:Array<String>,
				?nonMatchingPaths:Array<String>
			}> = [
				{
					name: "simple spec",
					spec: "*.ts",
					basePath: "/project",
					usage: UsageFiles,
					useCaseSensitiveFileNames: true,
					matchingPaths: ["/project/a.ts"],
					nonMatchingPaths: ["/project/a.js"],
				},
				{
					name: "trailing ** non-exclude returns nil",
					spec: "**",
					basePath: "/project",
					usage: UsageFiles,
					useCaseSensitiveFileNames: true,
					expectNil: true,
				},
				{
					name: "trailing ** exclude works",
					spec: "**",
					basePath: "/project",
					usage: UsageExclude,
					useCaseSensitiveFileNames: true,
					matchingPaths: ["/project/anything", "/project/deep/path"],
				},
			];

			for (tc in cases) {
				T.run("TestSingleSpecMatcher/" + tc.name, () -> {
					final matcher = Vfsmatch.NewSpecMatcher([tc.spec], tc.basePath, tc.usage, tc.useCaseSensitiveFileNames);
					if (tc.expectNil == true) {
						T.isTrue(matcher == null, "should be nil");
						return;
					}
					if (matcher == null) {
						T.fail("matcher should not be nil");
						return;
					}
					if (tc.matchingPaths != null)
						for (path in tc.matchingPaths) {
							T.isTrue(matcher.MatchString(path), 'should match: ${path}');
						}
					if (tc.nonMatchingPaths != null)
						for (path in tc.nonMatchingPaths) {
							T.isTrue(!matcher.MatchString(path), 'should not match: ${path}');
						}
				});
			}
		}

		{
			final cases:Array<{
				name:String,
				specs:Array<String>,
				basePath:String,
				usage:Usage,
				useCaseSensitiveFileNames:Bool,
				?expectNil:Bool,
				?pathToIndex:Map<String, Int>
			}> = [
				{
					name: "multiple specs return correct index",
					specs: ["*.ts", "*.tsx", "*.js"],
					basePath: "/project",
					usage: UsageFiles,
					useCaseSensitiveFileNames: true,
					pathToIndex: [
						"/project/a.ts" => 0,
						"/project/b.tsx" => 1,
						"/project/c.js" => 2,
						"/project/d.css" => -1, // no match
					],
				},
				{
					name: "empty specs returns nil",
					specs: [],
					basePath: "/project",
					usage: UsageFiles,
					useCaseSensitiveFileNames: true,
					expectNil: true,
				},
			];

			for (tc in cases) {
				T.run("TestSpecMatchers/" + tc.name, () -> {
					final matchers = Vfsmatch.NewSpecMatcher(tc.specs, tc.basePath, tc.usage, tc.useCaseSensitiveFileNames);
					if (tc.expectNil == true) {
						T.isTrue(matchers == null, "should be nil");
						return;
					}
					if (matchers == null) {
						T.fail("matchers should not be nil");
						return;
					}
					for (path => expectedIndex in tc.pathToIndex) {
						final gotIndex = matchers.MatchIndex(path);
						T.eq(expectedIndex, gotIndex);
					}
				});
			}
		}

		// TestGlobPatternInternals tests internal glob pattern matching logic
		// to ensure edge cases are covered that may not be hit by ReadDirectory tests
		T.run("TestGlobPatternInternals/nextPathPart handles consecutive slashes", () -> {
			// Test path with consecutive slashes
			final path = "/dev//foo///bar";

			// First call - returns empty for root
			var r = Vfsmatch.nextPathPartParts(path, "", 0);
			T.isTrue(r.c);
			T.eq("", r.a);
			T.eq(1, r.b);

			// Second call - should skip consecutive slashes after /dev
			r = Vfsmatch.nextPathPartParts(path, "", 1);
			T.isTrue(r.c);
			T.eq("dev", r.a);

			// Third call - should skip the double slashes before foo
			r = Vfsmatch.nextPathPartParts(path, "", r.b);
			T.isTrue(r.c);
			T.eq("foo", r.a);

			// Fourth call - should skip the triple slashes before bar
			r = Vfsmatch.nextPathPartParts(path, "", r.b);
			T.isTrue(r.c);
			T.eq("bar", r.a);
		});

		T.run("TestGlobPatternInternals/nextPathPart handles path ending with slashes", () -> {
			final path = "/dev/";

			// Skip to after "dev"
			var r = Vfsmatch.nextPathPartParts(path, "", 0); // root
			T.isTrue(r.c);
			r = Vfsmatch.nextPathPartParts(path, "", r.b); // dev
			T.isTrue(r.c);
			// Now at trailing slash, should return not ok
			r = Vfsmatch.nextPathPartParts(path, "", r.b);
			T.isTrue(!r.c);
		});

		T.run("TestGlobPatternInternals/nextPathPartParts handles empty prefix", () -> {
			final path = "/dev//foo";

			var r = Vfsmatch.nextPathPartParts("", path, 0);
			T.isTrue(r.c);
			T.eq("", r.a);
			T.eq(1, r.b);

			r = Vfsmatch.nextPathPartParts("", path, r.b);
			T.isTrue(r.c);
			T.eq("dev", r.a);

			r = Vfsmatch.nextPathPartParts("", path, r.b);
			T.isTrue(r.c);
			T.eq("foo", r.a);
		});

		T.run("TestGlobPatternInternals/nextPathPartParts returns not ok when only slashes remain", () -> {
			final prefix = "/dev/";
			final suffix = "foo";

			var r = Vfsmatch.nextPathPartParts(prefix, suffix, 0); // root
			T.isTrue(r.c);

			r = Vfsmatch.nextPathPartParts(prefix, suffix, r.b); // dev
			T.isTrue(r.c);
			T.eq("dev", r.a);

			r = Vfsmatch.nextPathPartParts(prefix, suffix, r.b); // foo
			T.isTrue(r.c);
			T.eq("foo", r.a);
			T.eq(prefix.length + suffix.length, r.b);

			r = Vfsmatch.nextPathPartParts(prefix, suffix, r.b);
			T.isTrue(!r.c);
		});

		T.run("TestGlobPatternInternals/nextPathPartParts parses from suffix region", () -> {
			final prefix = "/";
			final suffix = "a";

			var r = Vfsmatch.nextPathPartParts(prefix, suffix, 0); // root
			T.isTrue(r.c);
			T.eq("", r.a);
			T.eq(1, r.b);

			r = Vfsmatch.nextPathPartParts(prefix, suffix, r.b);
			T.isTrue(r.c);
			T.eq("a", r.a);
		});

		T.run("TestGlobPatternInternals/question mark segment at end of string", () -> {
			// Create pattern with question mark that should fail when string is exhausted
			final p = Vfsmatch.compileGlobPattern("a?", "/", UsageFiles, true);
			T.isTrue(p != null);

			// Should match "ab"
			T.isTrue(p.matches("/ab"));

			// Should NOT match "a" (question mark requires a character)
			T.isTrue(!p.matches("/a"));
		});

		T.run("TestGlobPatternInternals/star segment with complex pattern", () -> {
			// Pattern like "a*b*c" requires backtracking in star matching
			final p = Vfsmatch.compileGlobPattern("a*b*c", "/", UsageFiles, true);
			T.isTrue(p != null);

			// Should match "abc"
			T.isTrue(p.matches("/abc"));

			// Should match "aXbYc"
			T.isTrue(p.matches("/aXbYc"));

			// Should match "aXXXbYYYc"
			T.isTrue(p.matches("/aXXXbYYYc"));

			// Should NOT match "aXbY" (no trailing c)
			T.isTrue(!p.matches("/aXbY"));
		});

		T.run("TestGlobPatternInternals/ensureTrailingSlash with existing slash", () -> {
			// Test that ensureTrailingSlash doesn't double-add slashes
			var result = Vfsmatch.ensureTrailingSlash("/dev/");
			T.eq("/dev/", result);

			result = Vfsmatch.ensureTrailingSlash("/");
			T.eq("/", result);
		});

		T.run("TestGlobPatternInternals/ensureTrailingSlash with empty string", () -> {
			final result = Vfsmatch.ensureTrailingSlash("");
			T.eq("", result);
		});

		T.run("TestGlobPatternInternals/literal component with package folder in include", () -> {
			// When a literal include path goes through a package folder,
			// the skipPackageFolders flag on literal components should not block it
			// because literal components in includes don't have skipPackageFolders=true
			final host = Vfstest.FromMap(["/dev/node_modules/pkg/index.ts" => ""], false);

			// Explicit literal path should work
			final got = Vfsmatch.matchFiles("/dev", [".ts"], null, ["node_modules/pkg/index.ts"], false, "/", Vfsmatch.UnlimitedDepth, host);
			T.isTrue(Slices.Contains(got, "/dev/node_modules/pkg/index.ts"));
		});

		// TestMatchSegmentsEdgeCases tests edge cases in the matchSegments function
		T.run("TestMatchSegmentsEdgeCases/question mark before slash in string", () -> {
			// This tests the case where question mark encounters a slash character
			// which should fail since ? doesn't match /
			final p = Vfsmatch.compileGlobPattern("a?b", "/", UsageFiles, true);
			T.isTrue(p != null);

			// "a/b" should not match "a?b" pattern since ? shouldn't match /
			// But this is a single component pattern, so / wouldn't be in the component
			// We need to test this within the segment matching

			// Create a pattern that will exercise question mark matching edge cases
			T.isTrue(p.matches("/aXb")); // X matches ?
			T.isTrue(!p.matches("/ab")); // nothing to match ?
			T.isTrue(!p.matches("/aXYb")); // XY is too many chars for ?
		});

		T.run("TestMatchSegmentsEdgeCases/star with no trailing content", () -> {
			// Test that star can match to end of string
			final p = Vfsmatch.compileGlobPattern("a*", "/", UsageFiles, true);
			T.isTrue(p != null);

			T.isTrue(p.matches("/a"));
			T.isTrue(p.matches("/abc"));
			T.isTrue(p.matches("/aXYZ"));
		});

		T.run("TestMatchSegmentsEdgeCases/multiple stars in pattern", () -> {
			// Test patterns with multiple stars that require backtracking
			final p = Vfsmatch.compileGlobPattern("*a*", "/", UsageFiles, true);
			T.isTrue(p != null);

			T.isTrue(p.matches("/a"));
			T.isTrue(p.matches("/Xa"));
			T.isTrue(p.matches("/aX"));
			T.isTrue(p.matches("/XaY"));
			T.isTrue(!p.matches("/XYZ")); // no 'a'
		});

		T.run("TestMatchSegmentsEdgeCases/multiple stars requiring backtracking", () -> {
			// These patterns require proper backtracking to match correctly.
			// A naive greedy algorithm would fail on these.

			// Pattern: *a*a - must find two 'a' characters
			final p1 = Vfsmatch.compileGlobPattern("*a*a", "/", UsageFiles, true);
			T.isTrue(p1 != null);
			T.isTrue(p1.matches("/aa")); // minimal: first * matches "", second * matches ""
			T.isTrue(p1.matches("/Xaa")); // first * matches "X"
			T.isTrue(p1.matches("/aXa")); // second * matches "X"
			T.isTrue(p1.matches("/XaYa")); // both * match chars
			T.isTrue(p1.matches("/aaaa")); // multiple a's
			T.isTrue(!p1.matches("/a")); // only one 'a'
			T.isTrue(!p1.matches("/Xa")); // only one 'a'
			T.isTrue(!p1.matches("/aX")); // only one 'a', doesn't end with 'a'
			T.isTrue(!p1.matches("/XaYaZ")); // doesn't end with 'a'

			// Pattern: *a*b*c - must find a, then b, then c in order
			final p2 = Vfsmatch.compileGlobPattern("*a*b*c", "/", UsageFiles, true);
			T.isTrue(p2 != null);
			T.isTrue(p2.matches("/abc")); // minimal
			T.isTrue(p2.matches("/XaYbZc")); // chars between
			T.isTrue(p2.matches("/aXbYc")); // chars between
			T.isTrue(p2.matches("/aaabbbccc")); // repeated chars
			T.isTrue(!p2.matches("/ab")); // missing c
			T.isTrue(!p2.matches("/ac")); // missing b
			T.isTrue(!p2.matches("/cba")); // wrong order
			T.isTrue(!p2.matches("/abcX")); // doesn't end with c

			// Pattern: *a*a*a - must find three 'a' characters
			final p3 = Vfsmatch.compileGlobPattern("*a*a*a", "/", UsageFiles, true);
			T.isTrue(p3 != null);
			T.isTrue(p3.matches("/aaa"));
			T.isTrue(p3.matches("/aXaYa"));
			T.isTrue(p3.matches("/XaYaZa"));
			T.isTrue(!p3.matches("/aa")); // only two 'a's
			T.isTrue(!p3.matches("/aaX")); // doesn't end with 'a'

			// Pattern: a*b*a - starts with a, ends with a, has b in middle
			final p4 = Vfsmatch.compileGlobPattern("a*b*a", "/", UsageFiles, true);
			T.isTrue(p4 != null);
			T.isTrue(p4.matches("/aba"));
			T.isTrue(p4.matches("/aXbYa"));
			T.isTrue(p4.matches("/abba")); // b appears, ends with a
			T.isTrue(!p4.matches("/ab")); // doesn't end with a
			T.isTrue(!p4.matches("/aba ")); // trailing space
			T.isTrue(!p4.matches("/Xaba")); // doesn't start with a (hidden file rule may affect)
		});

		T.run("TestMatchSegmentsEdgeCases/pathological pattern performance", () -> {
			// This pattern could cause exponential backtracking in naive implementations.
			// Pattern: *a*a*a*a*b against "aaaaaaaaaaaaaaaa" (no b)
			// Should return false quickly, not hang.
			final p = Vfsmatch.compileGlobPattern("*a*a*a*a*b", "/", UsageFiles, true);
			T.isTrue(p != null);

			// These should complete quickly (not hang)
			T.isTrue(!p.matches("/aaaaaaaaaaaaaaaa")); // no 'b' at end
			T.isTrue(!p.matches("/aaaaaaaaaaaaaaaaX")); // ends with X not b
			T.isTrue(p.matches("/aaaab")); // minimal match
			T.isTrue(p.matches("/XaYaZaWab")); // complex match
		});

		T.run("TestMatchSegmentsEdgeCases/literal segment not matching", () -> {
			// Test literal segment that's longer than remaining string
			final p = Vfsmatch.compileGlobPattern("abcdefgh.ts", "/", UsageFiles, true);
			T.isTrue(p != null);

			T.isTrue(!p.matches("/abc.ts")); // different literal
			T.isTrue(p.matches("/abcdefgh.ts")); // exact match
		});

		T.run("TestMatchSegmentsEdgeCases/question mark matches multi-byte unicode rune", () -> {
			// ? should match one full Unicode codepoint, not one byte.
			// 'é' is 2 bytes in UTF-8, '🎉' is 4 bytes, '中' is 3 bytes.

			final p1 = Vfsmatch.compileGlobPattern("?.ts", "/", UsageFiles, true);
			T.isTrue(p1 != null);

			T.isTrue(p1.matches("/a.ts")); // single ASCII char
			T.isTrue(p1.matches("/é.ts")); // 2-byte rune
			T.isTrue(p1.matches("/中.ts")); // 3-byte rune
			T.isTrue(p1.matches("/🎉.ts")); // 4-byte rune (surrogate pair in UTF-16)
			T.isTrue(!p1.matches("/.ts")); // empty - no char for ? to match
			T.isTrue(!p1.matches("/ab.ts")); // two chars

			// Two question marks should match exactly two runes
			final p2 = Vfsmatch.compileGlobPattern("??.ts", "/", UsageFiles, true);
			T.isTrue(p2 != null);

			T.isTrue(p2.matches("/ab.ts")); // two ASCII chars
			T.isTrue(p2.matches("/é中.ts")); // two multi-byte runes
			T.isTrue(p2.matches("/🎉é.ts")); // 4-byte + 2-byte runes
			T.isTrue(!p2.matches("/a.ts")); // only one char
			T.isTrue(!p2.matches("/abc.ts")); // three chars
		});

		T.run("TestMatchSegmentsEdgeCases/star matches multi-byte unicode runes correctly", () -> {
			// * should advance by full runes during backtracking.

			// Pattern: *é.ts - anything ending in é.ts
			final p = Vfsmatch.compileGlobPattern("*é.ts", "/", UsageFiles, true);
			T.isTrue(p != null);

			T.isTrue(p.matches("/é.ts"));
			T.isTrue(p.matches("/café.ts"));
			T.isTrue(!p.matches("/cafe.ts")); // 'e' != 'é'

			// Pattern: *🎉* - contains 🎉 somewhere
			final p2 = Vfsmatch.compileGlobPattern("*🎉*", "/", UsageFiles, true);
			T.isTrue(p2 != null);

			T.isTrue(p2.matches("/🎉"));
			T.isTrue(p2.matches("/a🎉b"));
			T.isTrue(!p2.matches("/abc"));
		});

		// TestReadDirectoryConsecutiveSlashes tests handling of paths with consecutive slashes
		T.run("TestReadDirectoryConsecutiveSlashes", () -> {
			final host = Vfstest.FromMap([
				"/dev/a.ts" => "",
				"/dev/x/b.ts" => "",
			], false);

			// The matchFilesNoRegex function normalizes paths, but we can test internal handling
			final got = Vfsmatch.matchFiles("/dev", [".ts"], null, ["**/*.ts"], false, "/", Vfsmatch.UnlimitedDepth, host);
			T.isTrue(Core.len(got) >= 2, "should find files");
			T.isTrue(Slices.Contains(got, "/dev/a.ts"));
			T.isTrue(Slices.Contains(got, "/dev/x/b.ts"));
		});

		// TestGlobPatternLiteralWithPackageFolders tests literal component behavior with package folders
		T.run("TestGlobPatternLiteralWithPackageFolders/wildcard skips package folders", () -> {
			// Wildcard patterns should skip node_modules
			final host = Vfstest.FromMap([
				"/dev/a.ts" => "",
				"/dev/node_modules/b.ts" => "",
			], false);

			final got = Vfsmatch.matchFiles("/dev", [".ts"], null, ["*/*.ts"], false, "/", Vfsmatch.UnlimitedDepth, host);
			T.isTrue(!Slices.Contains(got, "/dev/node_modules/b.ts"), "should skip node_modules with wildcard");
		});

		T.run("TestGlobPatternLiteralWithPackageFolders/explicit literal includes package folder", () -> {
			// Explicit literal paths should include package folders
			final host = Vfstest.FromMap(["/dev/node_modules/b.ts" => ""], false);

			final got = Vfsmatch.matchFiles("/dev", [".ts"], null, ["node_modules/b.ts"], false, "/", Vfsmatch.UnlimitedDepth, host);
			T.isTrue(Slices.Contains(got, "/dev/node_modules/b.ts"), "should include explicit node_modules path");
		});

		// TestGetBasePathsCaseSensitivity verifies that getBasePaths uses the correct
		// case-sensitivity when deduplicating base paths. On a case-sensitive file system,
		// paths that differ only by case (e.g., "/Dev/src" and "/dev/src") are distinct
		// and should not be deduplicated.
		T.run("TestGetBasePathsCaseSensitivity/case-sensitive does not dedup differently-cased paths", () -> {
			// On a case-sensitive file system, /root/src/Dev and /root/src/dev are distinct directories.
			// When they're both included as base paths, they should not be deduplicated.
			// Use include patterns that point to directories outside the root path so the root
			// path doesn't subsume them via containsPath.
			final basePaths = Vfsmatch.getBasePaths("/root", ["../Other/**/*.ts", "../other/**/*.ts"], true /*caseSensitive*/);
			// Both /Other and /other should appear because they differ by case on a case-sensitive FS.
			T.isTrue(Slices.Contains(basePaths, "/Other"), 'expected /Other in base paths: ${strs(basePaths)}');
			T.isTrue(Slices.Contains(basePaths, "/other"), 'expected /other in base paths: ${strs(basePaths)}');
		});

		T.run("TestGetBasePathsCaseSensitivity/case-insensitive dedups differently-cased paths", () -> {
			// On a case-insensitive file system, /Other and /other refer to the same directory;
			// only one should appear.
			final basePaths = Vfsmatch.getBasePaths("/root", ["../Other/**/*.ts", "../other/**/*.ts"], false /*caseSensitive*/);
			var count = 0;
			for (bp in basePaths) {
				if (bp == "/Other" || bp == "/other") {
					count++;
				}
			}
			T.isTrue(count <= 1, 'expected at most one of /Other or /other in base paths: ${strs(basePaths)}');
		});

		// stringer_generated.go (not a Go test; checks the hand-written toString).
		T.run("Usage.String (extra)", () -> {
			T.eq("Files", UsageFiles.toString());
			T.eq("Directories", UsageDirectories.toString());
			T.eq("Exclude", UsageExclude.toString());
		});
	}
}
