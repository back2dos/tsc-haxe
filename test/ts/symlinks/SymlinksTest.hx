package ts.symlinks;

// Port of knownsymlinks_test.go.
// Not ported (benchmarks, knownsymlinks_bench_test.go): BenchmarkPopulateSymlinksFromResolutions,
// BenchmarkSetFile, BenchmarkSetDirectory, BenchmarkGuessDirectorySymlink, BenchmarkConcurrentAccess.
class SymlinksTest {
	public static function run() {
		T.run("TestNewKnownSymlink", () -> {
			final cache = Symlinks.NewKnownSymlink("/test/dir", true);
			if (cache == null) {
				T.fail("Expected non-nil cache");
				return;
			}
			T.eq("/test/dir", cache.cwd);
			T.isTrue(cache.useCaseSensitiveFileNames, "Expected useCaseSensitiveFileNames to be true");
		});

		T.run("TestSetDirectory", () -> {
			final cache = Symlinks.NewKnownSymlink("/test/dir", true);
			final symlinkPath = Tspath.ToPath("/test/symlink", "/test/dir", true).EnsureTrailingDirectorySeparator();
			final realDirectory = new KnownDirectoryLink("/real/path/", Tspath.ToPath("/real/path", "/test/dir", true).EnsureTrailingDirectorySeparator());

			cache.SetDirectory("/test/symlink", symlinkPath, realDirectory);

			// Check that directory was stored
			final stored = cache.Directories().Load(symlinkPath);
			if (!stored.ok) {
				T.fail("Expected directory to be stored");
				return;
			}
			T.eq(realDirectory.Real, stored.value.Real);
			T.eq((realDirectory.RealPath : String), (stored.value.RealPath : String));

			// Check that realpath mapping was created
			final set = cache.DirectoriesByRealpath().Load(realDirectory.RealPath);
			if (!set.ok || set.value.Size() == 0) {
				T.fail("Expected realpath mapping to be created");
				return;
			}
			T.isTrue(set.value.Has("/test/symlink"), "Expected symlink '/test/symlink' to be in set");
		});

		T.run("TestSetFile", () -> {
			final cache = Symlinks.NewKnownSymlink("/test/dir", true);
			final symlink = "/test/symlink/file.ts";
			final symlinkPath = Tspath.ToPath(symlink, "/test/dir", true);
			final realpath = "/real/path/file.ts";

			cache.SetFile(symlink, symlinkPath, realpath);

			final stored = cache.Files().Load(symlinkPath);
			if (!stored.ok) {
				T.fail("Expected file to be stored");
				return;
			}
			T.eq(realpath, stored.value);
		});

		T.run("TestProcessResolution", () -> {
			final cache = Symlinks.NewKnownSymlink("/test/dir", true);

			// Test with empty paths
			cache.ProcessResolution("", "");
			cache.ProcessResolution("original", "");
			cache.ProcessResolution("", "resolved");

			// Test with valid paths
			final originalPath = "/test/original/file.ts";
			final resolvedPath = "/test/resolved/file.ts";
			cache.ProcessResolution(originalPath, resolvedPath);

			// Check that file was stored
			final symlinkPath = Tspath.ToPath(originalPath, "/test/dir", true);
			final stored = cache.Files().Load(symlinkPath);
			if (!stored.ok) {
				T.fail("Expected file to be stored");
				return;
			}
			T.eq(resolvedPath, stored.value);
		});

		T.run("TestGuessDirectorySymlink", () -> {
			final cache = Symlinks.NewKnownSymlink("/test/dir", true);

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
				final r = cache.guessDirectorySymlink(tt.a, tt.b, tt.cwd);
				T.isTrue(r.a == tt.expected[0], '${tt.name}: Expected commonResolved to be \'${tt.expected[0]}\', got \'${r.a}\'');
				T.isTrue(r.b == tt.expected[1], '${tt.name}: Expected commonOriginal to be \'${tt.expected[1]}\', got \'${r.b}\'');
			}
		});

		T.run("TestIsNodeModulesOrScopedPackageDirectory", () -> {
			final cache = Symlinks.NewKnownSymlink("/test/dir", true);

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
			final cache = Symlinks.NewKnownSymlink("/test/dir", true);

			// Mock resolution data
			final resolvedModules:Array<{originalPath:String, resolvedPath:String, moduleName:String, mode:ResolutionMode, filePath:Path}> = [
				{
					originalPath: "/test/original/file1.ts",
					resolvedPath: "/test/resolved/file1.ts",
					moduleName: "module1",
					mode: Core.ResolutionModeNone,
					filePath: Tspath.ToPath("/test/source.ts", "/test/dir", true),
				},
				{
					originalPath: "/test/original/file2.ts",
					resolvedPath: "/test/resolved/file2.ts",
					moduleName: "module2",
					mode: Core.ResolutionModeNone,
					filePath: Tspath.ToPath("/test/source.ts", "/test/dir", true),
				},
			];

			// Mock callbacks
			final forEachResolvedModule = function(callback:(resolution:ResolvedModule, moduleName:String, mode:ResolutionMode, filePath:Path) -> Void,
					file:Null<SourceFile>) {
				for (res in resolvedModules) {
					final resolution = new ResolvedModule();
					resolution.OriginalPath = res.originalPath;
					resolution.ResolvedFileName = res.resolvedPath;
					callback(resolution, res.moduleName, res.mode, res.filePath);
				}
			};

			final forEachResolvedTypeReferenceDirective = function(callback:(resolution:ResolvedTypeReferenceDirective, moduleName:String,
					mode:ResolutionMode, filePath:Path) -> Void, file:Null<SourceFile>) {
				// No type reference directives for this test
			};

			cache.SetSymlinksFromResolutions(forEachResolvedModule, forEachResolvedTypeReferenceDirective);

			// Check that files were stored
			for (res in resolvedModules) {
				final symlinkPath = Tspath.ToPath(res.originalPath, "/test/dir", true);
				final stored = cache.Files().Load(symlinkPath);
				if (!stored.ok) {
					T.fail('Expected file \'${res.originalPath}\' to be stored');
					continue;
				}
				T.eq(res.resolvedPath, stored.value);
			}
		});

		// PORT: goroutines → sequential loop (single-threaded port).
		T.run("TestKnownSymlinksThreadSafety", () -> {
			final cache = Symlinks.NewKnownSymlink("/test/dir", true);

			for (id in 0...10) {
				final r = Utf16.RuneString(id); // Go string(rune(id))
				final symlinkPath = Tspath.ToPath("/test/symlink" + r, "/test/dir", true).EnsureTrailingDirectorySeparator();
				final realDirectory = new KnownDirectoryLink("/real/path" + r + "/",
					Tspath.ToPath("/real/path" + r, "/test/dir", true).EnsureTrailingDirectorySeparator());

				cache.SetDirectory("/test/symlink" + r, symlinkPath, realDirectory);

				// Read back
				final stored = cache.Directories().Load(symlinkPath);
				if (!stored.ok) {
					T.fail('Goroutine $id: Expected directory to be stored');
					continue;
				}
				T.eq(realDirectory.Real, stored.value.Real);
			}

			// Verify all directories were stored
			T.eq(10, cache.Directories().Size());
		});
	}
}
