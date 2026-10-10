package ts.modulespecifiers;

import ts.ast.Ast.HasFileName;
import ts.ast.Ast.StringLiteralLike;
import ts.module.Types.ResolvedModule;
import ts.packagejson.Cache.InfoCacheEntry;
import ts.packagejson.Exportsorimports.ExportsOrImports;
import ts.symlinks.Knownsymlinks.KnownSymlinks;
import ts.symlinks.Knownsymlinks.KnownDirectoryLink;
import ts.tsoptions.Parsedcommandline.SourceOutputAndProjectReference;

// Port of specifiers_test.go.

// Mock host for testing
class MockModuleSpecifierGenerationHost implements ModuleSpecifierGenerationHost {
	public var currentDir:String = "";
	public var useCaseSensitiveFileNames:Bool = false;
	public var symlinkCache:KnownSymlinks = null;

	public function new(currentDir:String = "", useCaseSensitiveFileNames:Bool = false, ?symlinkCache:KnownSymlinks) {
		this.currentDir = currentDir;
		this.useCaseSensitiveFileNames = useCaseSensitiveFileNames;
		this.symlinkCache = symlinkCache;
	}

	public function GetCurrentDirectory():String {
		return this.currentDir;
	}

	public function UseCaseSensitiveFileNames():Bool {
		return this.useCaseSensitiveFileNames;
	}

	public function GetSymlinkCache():KnownSymlinks {
		return this.symlinkCache;
	}

	public function ResolveModuleName(moduleName:String, containingFile:String, resolutionMode:ResolutionMode):ResolvedModule {
		return null;
	}

	public function GetGlobalTypingsCacheLocation():String {
		return "";
	}

	public function CommonSourceDirectory():String {
		return this.currentDir;
	}

	public function GetProjectReferenceFromSource(path:Path):SourceOutputAndProjectReference {
		return null;
	}

	public function GetRedirectTargets(path:Path):Array<String> {
		return null;
	}

	public function GetSourceOfProjectReferenceIfOutputIncluded(file:HasFileName):String {
		return file.FileName();
	}

	public function FileExists(path:String):Bool {
		return true; // Mock implementation
	}

	public function GetNearestAncestorDirectoryWithPackageJson(dirname:String):String {
		return "";
	}

	public function GetPackageJsonInfo(pkgJsonPath:String):InfoCacheEntry {
		return null;
	}

	public function GetDefaultResolutionModeForFile(file:HasFileName):ResolutionMode {
		return Core.ResolutionModeNone;
	}

	public function GetResolvedModuleFromModuleSpecifier(file:HasFileName, moduleSpecifier:StringLiteralLike):ResolvedModule {
		return null;
	}

	public function GetModeForUsageLocation(file:HasFileName, moduleSpecifier:StringLiteralLike):ResolutionMode {
		return Core.ResolutionModeNone;
	}
}

private class EachFileNameCase {
	public final name:String;
	public final importingFile:String;
	public final importedFile:String;
	public final preferSymlinks:Bool;
	public final expectedCount:Int;
	public final expectedPaths:Null<Array<String>>;

	public function new(name, importingFile, importedFile, preferSymlinks, expectedCount, ?expectedPaths) {
		this.name = name;
		this.importingFile = importingFile;
		this.importedFile = importedFile;
		this.preferSymlinks = preferSymlinks;
		this.expectedCount = expectedCount;
		this.expectedPaths = expectedPaths;
	}
}

class ModulespecifiersTest {
	public static function run() {
		T.run("TestGetEachFileNameOfModule", () -> {
			final tests = [
				new EachFileNameCase("basic file path", "/project/src/main.ts", "/project/lib/utils.ts", false, 1, ["/project/lib/utils.ts"]),
				new EachFileNameCase("symlink preference false", "/project/src/main.ts", "/project/lib/utils.ts", false, 1),
				new EachFileNameCase("symlink preference true", "/project/src/main.ts", "/project/lib/utils.ts", true, 1),
				// Should return 1 because there's no better option (all paths are ignored)
				new EachFileNameCase("ignored path with no alternatives", "/project/src/main.ts", "/project/node_modules/.pnpm/file.ts", false, 1),
			];

			for (tt in tests) {
				final host = new MockModuleSpecifierGenerationHost("/project", true, Symlinks.NewKnownSymlink("/project", true));

				final result = Modulespecifiers.GetEachFileNameOfModule(tt.importingFile, tt.importedFile, host, tt.preferSymlinks);

				T.isTrue(result.length == tt.expectedCount, '${tt.name}: Expected ${tt.expectedCount} paths, got ${result.length}');

				if (tt.expectedPaths != null) {
					for (i in 0...tt.expectedPaths.length) {
						final expectedPath = tt.expectedPaths[i];
						if (i >= result.length) {
							T.fail('${tt.name}: Expected path $i: $expectedPath, but result has only ${result.length} paths');
							continue;
						}
						T.isTrue(result[i].FileName == expectedPath, '${tt.name}: Expected path $i to be $expectedPath, got ${result[i].FileName}');
					}
				}

				for (i in 0...result.length) {
					T.isTrue(result[i].FileName != "", '${tt.name}: Path $i has empty FileName');
				}
			}
		});

		T.run("TestGetEachFileNameOfModuleWithSymlinks", () -> {
			final host = new MockModuleSpecifierGenerationHost("/project", true, Symlinks.NewKnownSymlink("/project", true));

			final symlinkPath = Tspath.ToPath("/project/symlink", "/project", true).EnsureTrailingDirectorySeparator();
			final realDirectory = new KnownDirectoryLink("/real/path/", Tspath.ToPath("/real/path", "/project", true).EnsureTrailingDirectorySeparator());
			host.symlinkCache.SetDirectory("/project/symlink", symlinkPath, realDirectory);

			final result = Modulespecifiers.GetEachFileNameOfModule("/project/src/main.ts", "/real/path/file.ts", host, true);

			// Should find the symlink path
			var found = false;
			for (path in result) {
				if (path.FileName == "/project/symlink/file.ts") {
					found = true;
					break;
				}
			}

			T.isTrue(found, "Expected to find symlink path /project/symlink/file.ts");
		});

		T.run("TestContainsNodeModules", () -> {
			final tests:Array<Array<Dynamic>> = [
				["contains node_modules", "/project/node_modules/lodash/index.js", true],
				["does not contain node_modules", "/project/src/utils.ts", false],
				["node_modules in middle", "/project/packages/node_modules/pkg/file.js", true],
				["empty path", "", false],
			];
			for (tt in tests) {
				final path:String = tt[1];
				final expected:Bool = tt[2];
				final result = Modulespecifiers.ContainsNodeModules(path);
				T.isTrue(result == expected, 'ContainsNodeModules("$path") = $result, expected $expected');
			}
		});

		T.run("TestContainsIgnoredPath", () -> {
			final tests:Array<Array<Dynamic>> = [
				["ignored path", "/project/node_modules/.pnpm/file.ts", true],
				["not ignored path", "/project/src/file.ts", false],
			];
			for (tt in tests) {
				final path:String = tt[1];
				final expected:Bool = tt[2];
				final result = Modulespecifiers.containsIgnoredPath(path);
				T.isTrue(result == expected, 'containsIgnoredPath("$path") = $result, expected $expected');
			}
		});

		T.run("TestTryGetRealFileNameForNonJSDeclarationFileName", () -> {
			final tests:Array<Array<String>> = [
				["json declaration file", "/project/foo.d.json.ts", "/project/foo.json"],
				["multi-dot source extension declaration file", "/project/foo.module.d.css.ts", "/project/foo.module.css"],
				["plain dts file ignored", "/project/foo.d.ts", ""],
			];
			for (tt in tests) {
				final got = Modulespecifiers.TryGetRealFileNameForNonJSDeclarationFileName(tt[1]);
				T.isTrue(got == tt[2], 'TryGetRealFileNameForNonJSDeclarationFileName("${tt[1]}") = "$got", expected "${tt[2]}"');
			}
		});

		T.run("TestTryGetModuleNameFromExportsOrImports", () -> {
			// with exports pattern
			final tests:Array<Array<String>> = [
				["match", "/pkg/src/things/thing1/index.ts", "./src/things/thing1"],
				["mismatch with matching leading and trailing strings", "/pkg/src/things/index.ts", ""],
			];
			for (tt in tests) {
				final exports = new ExportsOrImports();
				exports.JSONValue.Type = JSONValueTypeString;
				exports.JSONValue.Value = "./src/things/*/index.js";
				final result = Modulespecifiers.tryGetModuleNameFromExportsOrImports(new CompilerOptions(), new MockModuleSpecifierGenerationHost(), tt[1],
					"/pkg", "./src/things/*", exports, [], MatchingModePattern, false, false);
				T.isTrue(result == tt[2], 'tryGetModuleNameFromExportsOrImports(targetFilePath = "${tt[1]}") = $result, expected ${tt[2]}');
			}
		});
	}
}
