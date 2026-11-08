package ts.symlinks;

// Port of knownsymlinks_test.go.
// Not ported (benchmarks, knownsymlinks_bench_test.go): BenchmarkPopulateSymlinksFromResolutions,
// BenchmarkSetFile, BenchmarkSetDirectory, BenchmarkGuessDirectorySymlink, BenchmarkConcurrentAccess.
class SymlinksTest {
	public static function run() {
		T.run("TestNewKnownSymlink", () -> {
			final cache = Symlinks.NewKnownSymlinks(CaseSensitive);
			if (cache == null) {
				T.fail("Expected non-nil cache");
				return;
			}
			T.isTrue(cache.caseSensitivity == CaseSensitive, "expected CaseSensitivity to be CaseSensitive");
		});

		T.run("TestSetDirectory", () -> {
			final cache = Symlinks.NewKnownSymlinks(CaseSensitive);
			final symlinkPath = CaseSensitive.PathKey(Tspath.RootedPathFromNormalized("/test/symlink"));
			final realDirectory = new KnownDirectoryLink(Tspath.RootedDirectoryPathFromNormalized("/real/path"),
				CaseSensitive.PathKey(Tspath.RootedPathFromNormalized("/real/path")));

			cache.SetDirectory(Tspath.RootedDirectoryPathFromNormalized("/test/symlink"), symlinkPath, realDirectory);

			// Check that directory was stored
			final stored = cache.Directories().Load(symlinkPath);
			if (!stored.ok) {
				T.fail("Expected directory to be stored");
				return;
			}
			T.eq((realDirectory.Real : String), (stored.value.Real : String));
			T.eq((realDirectory.RealPath : String), (stored.value.RealPath : String));
			T.eq("/test/symlink", (stored.value.Symlink : String));

			// Check that realpath mapping was created
			final set = cache.DirectoriesByRealpath().Load(realDirectory.RealPath);
			if (!set.ok || set.value.Size() == 0) {
				T.fail("Expected realpath mapping to be created");
				return;
			}
			T.isTrue(set.value.Has(Tspath.RootedDirectoryPathFromNormalized("/test/symlink")), "Expected symlink '/test/symlink' to be in set");
		});

		T.run("TestKnownDirectoryLinkPreservesChildSpelling", () -> {
			final cache = Symlinks.NewKnownSymlinks(CaseInsensitive);
			final symlink = Tspath.RootedDirectoryPathFromNormalized("/Project/Node_Modules/pkg");
			final symlinkPath = CaseInsensitive.PathKey(symlink.AsPath());
			cache.SetDirectory(symlink, symlinkPath,
				new KnownDirectoryLink(Tspath.RootedDirectoryPathFromNormalized("/Real/Package"), Tspath.PathKeyFromCanonical("/real/package")));

			final link = cache.Directories().Load(symlinkPath);
			if (!link.ok) {
				T.fail("Expected directory link");
				return;
			}
			final resolved = link.value.ResolveFilePath(Tspath.RootedFilePathFromNormalized("/PROJECT/node_modules/pkg/Src/File.ts"), CaseInsensitive);
			if (resolved == null) {
				T.fail("Expected child path to resolve through directory link");
				return;
			}
			T.eq("/Real/Package/Src/File.ts", (resolved : String));
		});

		T.run("TestSetFile", () -> {
			final cache = Symlinks.NewKnownSymlinks(CaseSensitive);
			final symlink = Tspath.RootedFilePathFromNormalized("/test/symlink/file.ts");
			final symlinkPath = CaseSensitive.PathKey(symlink.AsPath());
			final realpath = Tspath.RootedFilePathFromNormalized("/real/path/file.ts");

			cache.SetFile(symlink, symlinkPath, realpath);

			final stored = cache.Files().Load(symlinkPath);
			if (!stored.ok) {
				T.fail("Expected file to be stored");
				return;
			}
			T.eq((realpath : String), (stored.value : String));
		});

		T.run("TestProcessResolution", () -> {
			final cache = Symlinks.NewKnownSymlinks(CaseSensitive);

			// Test with empty paths
			cache.ProcessResolution(cast "", cast "");
			cache.ProcessResolution(Tspath.RootedFilePathFromNormalized("/original"), cast "");
			cache.ProcessResolution(cast "", Tspath.RootedFilePathFromNormalized("/resolved"));

			// Test with valid paths
			final originalPath = Tspath.RootedFilePathFromNormalized("/test/original/file.ts");
			final resolvedPath = Tspath.RootedFilePathFromNormalized("/test/resolved/file.ts");
			cache.ProcessResolution(originalPath, resolvedPath);

			// Check that file was stored
			final symlinkPath = CaseSensitive.PathKey(originalPath.AsPath());
			final stored = cache.Files().Load(symlinkPath);
			if (!stored.ok) {
				T.fail("Expected file to be stored");
				return;
			}
			T.eq((resolvedPath : String), (stored.value : String));
		});

		T.run("TestGuessDirectorySymlink", () -> {
			final cache = Symlinks.NewKnownSymlinks(CaseSensitive);

			final tests:Array<{name:String, a:String, b:String, cwd:String, expected:Array<String>}> = [
				{name: "identical paths", a: "/test/path/file.ts", b: "/test/path/file.ts", cwd: "/test/dir", expected: ["/", "/"]},
				{name: "different files same directory", a: "/test/path/file1.ts", b: "/test/path/file2.ts", cwd: "/test/dir", expected: ["", ""]},
				{name: "different directories", a: "/test/path1/file.ts", b: "/test/path2/file.ts", cwd: "/test/dir", expected: ["/test/path1", "/test/path2"]},
				{
					name: "node_modules paths",
					a: "/test/node_modules/pkg/file.ts",
					b: "/test/node_modules/pkg/file.ts",
					cwd: "/test/dir",
					expected: ["/test/node_modules/pkg", "/test/node_modules/pkg"]
				},
				{
					name: "scoped package paths",
					a: "/test/node_modules/@scope/pkg/file.ts",
					b: "/test/node_modules/@scope/pkg/file.ts",
					cwd: "/test/dir",
					expected: ["/test/node_modules/@scope/pkg", "/test/node_modules/@scope/pkg"]
				},
			];

			for (tt in tests) {
				final currentDirectory = Tspath.RootedDirectoryPathFromNormalized(tt.cwd);
				final r = cache.guessDirectorySymlinkFromFilePaths(Tspath.ToRootedFilePath(tt.a, currentDirectory),
					Tspath.ToRootedFilePath(tt.b, currentDirectory));
				T.isTrue(r.a.AsString() == tt.expected[0], '${tt.name}: Expected commonResolved to be \'${tt.expected[0]}\', got \'${r.a}\'');
				T.isTrue(r.b.AsString() == tt.expected[1], '${tt.name}: Expected commonOriginal to be \'${tt.expected[1]}\', got \'${r.b}\'');
			}
		});

		T.run("TestIsNodeModulesOrScopedPackageDirectory", () -> {
			final cache = Symlinks.NewKnownSymlinks(CaseSensitive);

			final tests:Array<{name:String, dir:String, expected:Bool}> = [
				{name: "node_modules", dir: "node_modules", expected: true},
				{name: "scoped package", dir: "@scope", expected: true},
				{name: "regular directory", dir: "src", expected: false},
				{name: "empty string", dir: "", expected: false},
				{name: "case insensitive node_modules", dir: "NODE_MODULES", expected: false}, // The function is case sensitive
				{name: "case insensitive scoped", dir: "@SCOPE", expected: true},
			];

			for (tt in tests) {
				final result = cache.isNodeModulesOrScopedPackageDirectory(tt.dir);
				T.isTrue(result == tt.expected, '${tt.name}: Expected ${tt.expected}, got $result for directory \'${tt.dir}\'');
			}
		});

		T.run("TestSetSymlinksFromResolutions", () -> {
			final cache = Symlinks.NewKnownSymlinks(CaseSensitive);

			// Mock resolution data
			final resolvedModules:Array<{originalPath:String, resolvedPath:String, moduleName:String, mode:ResolutionMode, filePath:PathKey}> = [
				{
					originalPath: "/test/original/file1.ts",
					resolvedPath: "/test/resolved/file1.ts",
					moduleName: "module1",
					mode: Core.ResolutionModeNone,
					filePath: CaseSensitive.PathKey(Tspath.RootedPathFromNormalized("/test/source.ts")),
				},
				{
					originalPath: "/test/original/file2.ts",
					resolvedPath: "/test/resolved/file2.ts",
					moduleName: "module2",
					mode: Core.ResolutionModeNone,
					filePath: CaseSensitive.PathKey(Tspath.RootedPathFromNormalized("/test/source.ts")),
				},
			];

			// Mock callbacks
			final forEachResolvedModule = function(callback:(resolution:ResolvedModule, moduleName:String, mode:ResolutionMode, filePath:PathKey) -> Void,
					file:Null<SourceFile>) {
				for (res in resolvedModules) {
					final resolution = new ResolvedModule();
					resolution.OriginalPath = Tspath.RootedFilePathFromAbsolute(res.originalPath);
					resolution.ResolvedFileName = Tspath.RootedFilePathFromAbsolute(res.resolvedPath);
					callback(resolution, res.moduleName, res.mode, res.filePath);
				}
			};

			final forEachResolvedTypeReferenceDirective = function(callback:(resolution:ResolvedTypeReferenceDirective, moduleName:String,
					mode:ResolutionMode, filePath:PathKey) -> Void, file:Null<SourceFile>) {
				// No type reference directives for this test
			};

			cache.SetSymlinksFromResolutions(forEachResolvedModule, forEachResolvedTypeReferenceDirective);

			// Check that files were stored
			for (res in resolvedModules) {
				final symlinkPath = CaseSensitive.PathKey(Tspath.RootedPathFromNormalized(res.originalPath));
				final stored = cache.Files().Load(symlinkPath);
				if (!stored.ok) {
					T.fail('Expected file \'${res.originalPath}\' to be stored');
					continue;
				}
				T.eq(res.resolvedPath, stored.value.AsString());
			}
		});

		// PORT: goroutines → sequential loop (single-threaded port).
		T.run("TestKnownSymlinksThreadSafety", () -> {
			final cache = Symlinks.NewKnownSymlinks(CaseSensitive);

			for (id in 0...10) {
				final r = Utf16.RuneString(id); // Go string(rune(id))
				final symlinkPath = CaseSensitive.PathKey(Tspath.RootedPathFromNormalized("/test/symlink" + r));
				final realDirectory = new KnownDirectoryLink(Tspath.RootedDirectoryPathFromAbsolute("/real/path" + r),
					CaseSensitive.PathKey(Tspath.RootedPathFromNormalized("/real/path" + r)));

				cache.SetDirectory(Tspath.RootedDirectoryPathFromNormalized("/test/symlink" + r), symlinkPath, realDirectory);

				// Read back
				final stored = cache.Directories().Load(symlinkPath);
				if (!stored.ok) {
					T.fail('Goroutine $id: Expected directory to be stored');
					continue;
				}
				T.eq((realDirectory.Real : String), (stored.value.Real : String));
			}

			// Verify all directories were stored
			T.eq(10, cache.Directories().Size());
		});
	}
}
