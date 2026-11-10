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
	public var currentDir:RootedDirectoryPath = cast "";
	public var contentMapperExtensions:Slice<String> = null;
	public var caseSensitivity:CaseSensitivity = CaseInsensitive;
	public var symlinkCache:KnownSymlinks = null;
	// PORT: Go map[tspath.RootedFilePath]bool (nil when unset).
	public var existingFiles:Null<Map<String, Bool>> = null;
	public var fileExistsCalls:Array<RootedFilePath> = [];

	// PORT: Go's untyped constant currentDir ("/project") → RootedDirectoryPathFromNormalized ("" stays the zero value).
	public function new(currentDir:String = "", caseSensitivity:CaseSensitivity = CaseInsensitive, ?symlinkCache:KnownSymlinks) {
		this.currentDir = currentDir == "" ? cast "" : Tspath.RootedDirectoryPathFromNormalized(currentDir);
		this.caseSensitivity = caseSensitivity;
		this.symlinkCache = symlinkCache;
	}

	public function BaseDirectory():RootedDirectoryPath {
		return this.currentDir;
	}

	public function CaseSensitivity():CaseSensitivity {
		return this.caseSensitivity;
	}

	public function GetSymlinkCache():KnownSymlinks {
		return this.symlinkCache;
	}

	public function ResolveModuleName(moduleName:String, containingFile:RootedFilePath, resolutionMode:ResolutionMode):ResolvedModule {
		return null;
	}

	public function GetGlobalTypingsCacheLocation():RootedDirectoryPath {
		return cast "";
	}

	public function CommonSourceDirectory():RootedDirectoryPath {
		return this.currentDir;
	}

	public function ContentMapperExtensions():Slice<String> {
		return this.contentMapperExtensions;
	}

	public function ContentMapperExtensionRewrites():Slice<ts.tspath.Tspath.ExtensionRewrite> {
		return null;
	}

	public function GetProjectReferenceFromSource(path:PathKey):SourceOutputAndProjectReference {
		return null;
	}

	public function GetRedirectTargets(path:PathKey):Array<RootedFilePath> {
		return null;
	}

	public function GetSourceOfProjectReferenceIfOutputIncluded(file:HasFileName):RootedFilePath {
		return file.FileName();
	}

	public function FileExists(path:RootedFilePath):Bool {
		this.fileExistsCalls.push(path);
		if (this.existingFiles != null) {
			return this.existingFiles.get(path) == true;
		}
		return true; // Mock implementation
	}

	public function GetNearestAncestorDirectoryWithPackageJson(dirname:RootedDirectoryPath):RootedDirectoryPath {
		return cast "";
	}

	public function GetPackageJsonInfo(pkgJsonPath:RootedFilePath):InfoCacheEntry {
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
	public final expectedPaths:Slice<String>;

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
		T.run("TestGetNodeModulePathParts", () -> {
			final tests:Array<{
				path:String,
				topLevelNodeModulesSearchRoot:String,
				topLevelNodeModulesDirectory:String,
				packageRootDirectory:String,
				packageName:String,
				packageRelativePath:String,
				hasNestedNodeModules:Bool,
				isDirectNodeModulesFile:Bool
			}> = [
				{
					path: "/workspace/node_modules/pkg/lib/index.d.ts",
					topLevelNodeModulesSearchRoot: "/workspace",
					topLevelNodeModulesDirectory: "/workspace/node_modules",
					packageRootDirectory: "/workspace/node_modules/pkg",
					packageName: "pkg",
					packageRelativePath: "lib/index.d.ts",
					hasNestedNodeModules: false,
					isDirectNodeModulesFile: false
				},
				{
					path: "/node_modules/@scope/pkg/index.d.ts",
					topLevelNodeModulesSearchRoot: "/",
					topLevelNodeModulesDirectory: "/node_modules",
					packageRootDirectory: "/node_modules/@scope/pkg",
					packageName: "@scope/pkg",
					packageRelativePath: "index.d.ts",
					hasNestedNodeModules: false,
					isDirectNodeModulesFile: false
				},
				{
					path: "c:/node_modules/pkg/index.d.ts",
					topLevelNodeModulesSearchRoot: "c:/",
					topLevelNodeModulesDirectory: "c:/node_modules",
					packageRootDirectory: "c:/node_modules/pkg",
					packageName: "pkg",
					packageRelativePath: "index.d.ts",
					hasNestedNodeModules: false,
					isDirectNodeModulesFile: false
				},
				{
					path: "/workspace/node_modules/pkg/node_modules/@scope/dep/index.d.ts",
					topLevelNodeModulesSearchRoot: "/workspace",
					topLevelNodeModulesDirectory: "/workspace/node_modules",
					packageRootDirectory: "/workspace/node_modules/pkg/node_modules/@scope/dep",
					packageName: "@scope/dep",
					packageRelativePath: "index.d.ts",
					hasNestedNodeModules: true,
					isDirectNodeModulesFile: false
				},
			];

			for (tt in tests) {
				final parts = Modulespecifiers.GetNodeModulePathParts(Tspath.RootedFilePathFromNormalized(tt.path));
				if (parts == null) {
					T.fail('GetNodeModulePathParts("${tt.path}") returned nil');
					continue;
				}
				T.isTrue(parts.TopLevelNodeModulesSearchRoot.AsString() == tt.topLevelNodeModulesSearchRoot
					&& parts.TopLevelNodeModulesDirectory.AsString() == tt.topLevelNodeModulesDirectory
					&& parts.PackageRootDirectory.AsString() == tt.packageRootDirectory
					&& parts.PackageName == tt.packageName
					&& parts.PackageRelativePath.AsString() == tt.packageRelativePath
					&& parts.HasNestedNodeModules == tt.hasNestedNodeModules
					&& parts.IsDirectNodeModulesFile == tt.isDirectNodeModulesFile,
					'GetNodeModulePathParts("${tt.path}") = ${parts.TopLevelNodeModulesSearchRoot} ${parts.TopLevelNodeModulesDirectory} ${parts.PackageRootDirectory} ${parts.PackageName} ${parts.PackageRelativePath} ${parts.HasNestedNodeModules} ${parts.IsDirectNodeModulesFile}');
			}

			for (path in ["/workspace/src/index.ts"]) {
				final parts = Modulespecifiers.GetNodeModulePathParts(Tspath.RootedFilePathFromNormalized(path));
				T.isTrue(parts == null, 'GetNodeModulePathParts("$path") should be nil');
			}

			final direct = Modulespecifiers.GetNodeModulePathParts(Tspath.RootedFilePathFromNormalized("/workspace/node_modules/pkg"));
			T.isTrue(direct != null && direct.IsDirectNodeModulesFile && direct.PackageName == "pkg", "GetNodeModulePathParts for direct node_modules file");
			final directScoped = Modulespecifiers.GetNodeModulePathParts(Tspath.RootedFilePathFromNormalized("/workspace/node_modules/@scope"));
			T.isTrue(directScoped != null && directScoped.IsDirectNodeModulesFile && directScoped.PackageName == "@scope",
				"GetNodeModulePathParts for direct scoped node_modules file");
		});

		T.run("TestGetEachFileNameOfModule", () -> {
			final tests = [
				new EachFileNameCase("basic file path", "/project/src/main.ts", "/project/lib/utils.ts", false, 1, ["/project/lib/utils.ts"]),
				new EachFileNameCase("symlink preference false", "/project/src/main.ts", "/project/lib/utils.ts", false, 1),
				new EachFileNameCase("symlink preference true", "/project/src/main.ts", "/project/lib/utils.ts", true, 1),
				// Should return 1 because there's no better option (all paths are ignored)
				new EachFileNameCase("ignored path with no alternatives", "/project/src/main.ts", "/project/node_modules/.pnpm/file.ts", false, 1),
			];

			for (tt in tests) {
				final host = new MockModuleSpecifierGenerationHost("/project", CaseSensitive, Symlinks.NewKnownSymlinks(CaseSensitive));

				final result = Modulespecifiers.GetEachFileNameOfModule(Tspath.ToRootedFilePath(tt.importingFile, host.BaseDirectory()),
					Tspath.ToRootedFilePath(tt.importedFile, host.BaseDirectory()), host, tt.preferSymlinks);

				T.isTrue(result.length == tt.expectedCount, '${tt.name}: Expected ${tt.expectedCount} paths, got ${result.length}');

				if (tt.expectedPaths != null) {
					for (i in 0...tt.expectedPaths.length) {
						final expectedPath = tt.expectedPaths[i];
						if (i >= result.length) {
							T.fail('${tt.name}: Expected path $i: $expectedPath, but result has only ${result.length} paths');
							continue;
						}
						T.isTrue(result[i].FileName.AsString() == expectedPath, '${tt.name}: Expected path $i to be $expectedPath, got ${result[i].FileName}');
					}
				}

				for (i in 0...result.length) {
					T.isTrue(result[i].FileName != "", '${tt.name}: Path $i has empty FileName');
				}
			}
		});

		T.run("TestGetEachFileNameOfModuleWithSymlinks", () -> {
			final host = new MockModuleSpecifierGenerationHost("/project", CaseSensitive, Symlinks.NewKnownSymlinks(CaseSensitive));

			final symlinkPath = CaseSensitive.PathKey(Tspath.RootedPathFromNormalized("/project/symlink"));
			final realDirectory = new KnownDirectoryLink(Tspath.RootedDirectoryPathFromNormalized("/real/path"),
				CaseSensitive.PathKey(Tspath.RootedPathFromNormalized("/real/path")));
			host.symlinkCache.SetDirectory(Tspath.RootedDirectoryPathFromNormalized("/project/symlink"), symlinkPath, realDirectory);

			final result = Modulespecifiers.GetEachFileNameOfModule(Tspath.RootedFilePathFromNormalized("/project/src/main.ts"),
				Tspath.RootedFilePathFromNormalized("/real/path/file.ts"), host, true);

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

		T.run("TestModuleSpecifierContainsNodeModules", () -> {
			final tests:Array<Array<Dynamic>> = [
				["contains node_modules", "/project/node_modules/lodash/index.js", true],
				["does not contain node_modules", "/project/src/utils.ts", false],
				["node_modules in middle", "/project/packages/node_modules/pkg/file.js", true],
				["empty path", "", false],
			];
			for (tt in tests) {
				final path:String = tt[1];
				final expected:Bool = tt[2];
				final result = Modulespecifiers.moduleSpecifierContainsNodeModules(Tspath.ToModuleSpecifier(path));
				T.isTrue(result == expected, 'moduleSpecifierContainsNodeModules("$path") = $result, expected $expected');
			}
		});

		T.run("TestIsPackageMainFilePreservesDirectoryIntent", () -> {
			final packageRoot = Tspath.RootedDirectoryPathFromNormalized("/project/node_modules/pkg");

			T.isTrue(!Modulespecifiers.isPackageMainFile(Tspath.RootedFilePathFromNormalized("/project/node_modules/pkg/types.d.ts"), packageRoot,
				"./types/", "", CaseSensitive),
				"slash-terminated package entrypoint must not match the sibling declaration file");
			T.isTrue(Modulespecifiers.isPackageMainFile(Tspath.RootedFilePathFromNormalized("/project/node_modules/pkg/types/index.d.ts"), packageRoot,
				"./types/", "", CaseSensitive),
				"slash-terminated package entrypoint should match its index declaration");
			T.isTrue(Modulespecifiers.isPackageMainFile(Tspath.RootedFilePathFromNormalized("/project/node_modules/pkg/types.d.ts"), packageRoot,
				"./types", "", CaseSensitive),
				"extensionless package entrypoint should match the declaration file");
		});

		T.run("TestContainsIgnoredPath", () -> {
			final tests:Array<Array<Dynamic>> = [
				["ignored path", "/project/node_modules/.pnpm/file.ts", true],
				["not ignored path", "/project/src/file.ts", false],
			];
			for (tt in tests) {
				final path:String = tt[1];
				final expected:Bool = tt[2];
				final result = Modulespecifiers.containsIgnoredPath(Tspath.RootedFilePathFromNormalized(path));
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

		T.run("TestProcessEndingChecksRootedFilePath", () -> {
			final host = new MockModuleSpecifierGenerationHost("/wrong", CaseSensitive);
			host.existingFiles = ["/project/src/lib.ts" => true];

			final result = Modulespecifiers.processEnding(Tspath.ToModuleSpecifier("./lib/index.ts"),
				Tspath.RootedFilePathFromNormalized("/project/src/lib/index.ts"), [ModuleSpecifierEndingMinimal], new CompilerOptions(), host);
			T.isTrue(result == "./lib/index", 'processEnding() = "$result", expected "./lib/index"');
			T.isTrue(host.fileExistsCalls.indexOf(Tspath.RootedFilePathFromNormalized("/project/src/lib.ts")) >= 0,
				'FileExists calls = ${host.fileExistsCalls}, expected a lookup for /project/src/lib.ts');
		});

		T.run("TestIsPathRelativeToParent", () -> {
			final tests:Array<{path:String, expected:Bool}> = [
				{path: "..", expected: true},
				{path: "../sibling.ts", expected: true},
				{path: "..foo.ts", expected: false},
				{path: "child/..foo.ts", expected: false},
			];
			for (test in tests) {
				// PORT: Go's untyped constant RelativePath (unchecked; "../sibling.ts" is not normalized-relative).
				final actual = Modulespecifiers.isPathRelativeToParent(cast test.path);
				T.isTrue(actual == test.expected, 'isPathRelativeToParent("${test.path}") = $actual, expected ${test.expected}');
			}
		});

		T.run("TestTryGetModuleNameFromExportsOrImports", () -> {
			// trailing separator target
			{
				final exports = new ExportsOrImports();
				exports.JSONValue.Type = JSONValueTypeString;
				exports.JSONValue.Value = "./dist/internal/";
				final host = new MockModuleSpecifierGenerationHost("", CaseSensitive);
				var result = Modulespecifiers.tryGetModuleNameFromExportsOrImports(new CompilerOptions(), host,
					Tspath.RootedFilePathFromNormalized("/pkg/dist/internal/file.ts"), Tspath.RootedDirectoryPathFromNormalized("/pkg"), "#internal/",
					exports, null, MatchingModeDirectory, true, false);
				T.isTrue(result != "", "directory target with a trailing separator should match");
				result = Modulespecifiers.tryGetModuleNameFromExportsOrImports(new CompilerOptions(), host,
					Tspath.RootedFilePathFromNormalized("/pkg/dist/internal/file.ts"), Tspath.RootedDirectoryPathFromNormalized("/pkg"), "#internal",
					exports, null, MatchingModeExact, true, false);
				T.isTrue(result == "", 'exact target with a trailing separator matched as "$result"');
			}

			// with exports pattern
			final tests:Array<Array<String>> = [
				["match", "/pkg/src/things/thing1/index.ts", "./src/things/thing1"],
				["mismatch with matching leading and trailing strings", "/pkg/src/things/index.ts", ""],
			];
			for (tt in tests) {
				final exports = new ExportsOrImports();
				exports.JSONValue.Type = JSONValueTypeString;
				exports.JSONValue.Value = "./src/things/*/index.js";
				final result = Modulespecifiers.tryGetModuleNameFromExportsOrImports(new CompilerOptions(), new MockModuleSpecifierGenerationHost(),
					Tspath.RootedFilePathFromNormalized(tt[1]), Tspath.RootedDirectoryPathFromNormalized("/pkg"), "./src/things/*", exports, [],
					MatchingModePattern, false, false);
				T.isTrue(result == tt[2], 'tryGetModuleNameFromExportsOrImports(targetFilePath = "${tt[1]}") = $result, expected ${tt[2]}');
			}
		});
	}
}
