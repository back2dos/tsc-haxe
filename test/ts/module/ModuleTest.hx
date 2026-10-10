package ts.module;

import ts.vfs.vfstest.Vfstest;
import ts.vfs.wrapvfs.Wrapvfs;

// Port of resolver_test.go.
//
// PORT: goroutines — the race regression tests run two resolutions concurrently and use
// channels to force one interleaving at the package.json FileExists / ReadFile calls. The port
// is single-threaded, so the FS hook runs the other resolution re-entrantly at the same point:
// both resolutions have missed the package.json info cache before either one stores into it,
// and the stores happen in the order the Go test forces. Which resolution is "first" is
// arbitrary in Go too.
class ModuleTest {
	public static function run() {
		T.run("TestResolveModuleNameTrailingSlash", () -> {
			final fs = Vfstest.FromMap([
				"/repo/node_modules/pkg/package.json" => '{"name":"pkg","main":"main.js","types":"main.d.ts"}',
				"/repo/node_modules/pkg/main.d.ts" => "export const x: number;",
				"/repo/node_modules/pkg/main.js" => "exports.x = 1;",
				"/repo/src/file.ts" => ""
			], true);
			final host = new ResolutionHostStub(fs, "/repo");
			final opts = bundlerOptions();
			final resolver = Module.NewResolver(host, opts, "", "");

			for (name in ["pkg", "pkg/"]) {
				final r = resolver.ResolveModuleName(name, "/repo/src/file.ts", ModuleKindESNext, null).a;
				if (!r.IsResolved()) {
					T.fail('"$name" failed to resolve');
				}
				T.checks++;
			}
		});

		T.run("TestResolveModuleNameTrailingSlashRace", () -> {
			final pkgJSONPath = "/repo/node_modules/pkg/package.json";
			final files = [
				// `types` points at a file that is not discoverable through any
				// fallback path: there is no `index.*` and no `main`. The only way
				// to resolve `pkg` (or `pkg/`) is via the package.json `types` field
				// inside `loadNodeModuleFromDirectoryWorker`, which is exactly the
				// step that the bug skips when `candidate` and
				// `packageInfo.PackageDirectory` mismatch.
				pkgJSONPath => '{"name":"pkg","types":"./typings/index.d.ts"}',
				"/repo/node_modules/pkg/typings/index.d.ts" => "export const x: number;",
				// Distinct containing files so each `ResolveModuleName` call has a
				// unique module-resolution-cache key.
				"/repo/src/a/file.ts" => "",
				"/repo/src/b/file.ts" => ""
			];
			final base = Vfstest.FromMap(files, true);
			var arrived = 0;
			var other:Null<() -> Void> = null;
			final replacements = new Replacements();
			// blockingFS: the first caller to reach the gate runs the other resolution, which
			// arrives second; then both pass the gate.
			replacements.FileExists = function(path:String):Bool {
				if (path == pkgJSONPath) {
					arrived++;
					if (arrived == 1 && other != null) {
						final o = other;
						other = null;
						o();
					}
				}
				return base.FileExists(path);
			};
			final fs = Wrapvfs.Wrap(base, replacements);
			final host = new ResolutionHostStub(fs, "/repo");
			final resolver = Module.NewResolver(host, bundlerOptions(), "", "");

			final results:Array<Pair<String, Bool>> = [];
			final resolve = function(name:String) {
				var containingFile = "/repo/src/a/file.ts";
				if (StringTools.endsWith(name, "/")) {
					containingFile = "/repo/src/b/file.ts";
				}
				final r = resolver.ResolveModuleName(name, containingFile, ModuleKindESNext, null).a;
				results.push(new Pair(name, r.IsResolved()));
			};
			other = () -> resolve("pkg/");
			resolve("pkg");

			T.eq(2, arrived);
			T.eq(2, results.length);
			for (r in results) {
				if (!r.b) {
					T.fail('"${r.a}" failed to resolve');
				}
				T.checks++;
			}
		});

		T.run("TestResolveSubpathNilContentsRace", () -> {
			final rootPkgJSON = "/repo/node_modules/pkg/package.json";
			final files = [
				rootPkgJSON => '{"name":"pkg","version":"1.0.0"}',
				"/repo/node_modules/pkg/sub/index.d.ts" => "export declare const sub: number;",
				"/repo/node_modules/pkg/sub/index.js" => "exports.sub = 1;",
				"/repo/src/a/file.ts" => "",
				"/repo/src/b/file.ts" => ""
			];
			final fs = new FlipFileExistsFS(Vfstest.FromMap(files, true), rootPkgJSON);
			final host = new ResolutionHostStub(fs.fs, "/repo");
			final resolver = Module.NewResolver(host, bundlerOptions(), "", "");

			var panicked = false;
			final results:Array<Pair<String, Bool>> = [];
			// Two resolutions both resolve "pkg/sub". Each calls getPackageJsonInfo
			// for the root package directory, reaching FileExists for rootPkgJSON.
			final resolve = function(containingFile:String) {
				var resolved = false;
				try {
					final r = resolver.ResolveModuleName("pkg/sub", containingFile, ModuleKindESNext, null).a;
					resolved = r.IsResolved();
				} catch (e:Dynamic) {
					panicked = true;
				}
				results.push(new Pair(containingFile, resolved));
			};
			fs.other = () -> resolve("/repo/src/b/file.ts");
			resolve("/repo/src/a/file.ts");

			T.eq(2, fs.callCount);
			T.isTrue(fs.readArrived);
			if (panicked) {
				T.fail("resolver panicked due to nil Contents dereference in loadModuleFromSpecificNodeModulesDirectory");
			}
			for (r in results) {
				if (!r.b) {
					T.fail('"${r.a}" failed to resolve pkg/sub');
				}
				T.checks++;
			}
		});

		T.run("TestParseNodeModuleFromPath", () -> {
			final tests:Array<{name:String, path:String, isFolder:Bool, want:String}> = [
				{name: "file in package", path: "/a/node_modules/b/lib/index.d.ts", isFolder: false, want: "/a/node_modules/b"},
				{name: "file in scoped package", path: "/a/node_modules/@scope/b/lib/index.d.ts", isFolder: false, want: "/a/node_modules/@scope/b"},
				{name: "folder subpath", path: "/a/node_modules/b/lib/File", isFolder: true, want: "/a/node_modules/b"},
				{name: "folder subpath scoped", path: "/a/node_modules/@scope/b/lib/File", isFolder: true, want: "/a/node_modules/@scope/b"},
				{name: "package root folder", path: "/a/node_modules/b", isFolder: true, want: "/a/node_modules/b"},
				{name: "scoped package root folder", path: "/a/node_modules/@scope/b", isFolder: true, want: "/a/node_modules/@scope/b"},
				// A bare scope directory has no package name; must not panic (https://github.com/microsoft/typescript-go/issues/4373).
				{name: "scope-only folder", path: "/a/node_modules/@scope", isFolder: true, want: "/a/node_modules/@scope"},
				{name: "types scope-only folder", path: "/a/node_modules/@types", isFolder: true, want: "/a/node_modules/@types"},
				{name: "not in node_modules", path: "/a/src/index.ts", isFolder: false, want: ""},
			];
			for (tt in tests) {
				final got = Module.ParseNodeModuleFromPath(tt.path, tt.isFolder);
				if (got != tt.want) {
					T.fail('${tt.name}: ParseNodeModuleFromPath("${tt.path}", ${tt.isFolder}) = "$got", want "${tt.want}"');
				}
				T.checks++;
			}
		});

		T.run("TestResolvePeerDependencyNilContentsRace", () -> {
			final peerPkgJSON = "/repo/node_modules/peer/package.json";
			final files = [
				"/repo/node_modules/pkg/package.json" => '{"name":"pkg","version":"1.0.0","types":"index.d.ts","peerDependencies":{"peer":"*"}}',
				"/repo/node_modules/pkg/index.d.ts" => "export declare const x: number;",
				peerPkgJSON => '{"name":"peer","version":"2.0.0"}',
				"/repo/src/a/file.ts" => "",
				"/repo/src/b/file.ts" => ""
			];
			final fs = new FlipFileExistsFS(Vfstest.FromMap(files, true), peerPkgJSON);
			final host = new ResolutionHostStub(fs.fs, "/repo");
			final resolver = Module.NewResolver(host, bundlerOptions(), "", "");

			var panicked = false;
			final results:Array<Pair<String, Bool>> = [];
			final resolve = function(containingFile:String) {
				var resolved = false;
				try {
					final r = resolver.ResolveModuleName("pkg", containingFile, ModuleKindESNext, null).a;
					resolved = r.IsResolved();
				} catch (e:Dynamic) {
					panicked = true;
				}
				results.push(new Pair(containingFile, resolved));
			};
			fs.other = () -> resolve("/repo/src/b/file.ts");
			resolve("/repo/src/a/file.ts");

			T.eq(2, fs.callCount);
			T.isTrue(fs.readArrived);
			if (panicked) {
				T.fail("resolver panicked due to nil Contents dereference in readPackageJsonPeerDependencies");
			}
			// The first result is the resolution whose lookup stored the nil-Contents entry.
			final firstResult = results[0];
			if (!firstResult.b) {
				T.fail('"${firstResult.a}" failed to resolve pkg');
			}
			T.checks++;
			for (r in results) {
				if (!r.b) {
					T.fail('"${r.a}" failed to resolve pkg');
				}
				T.checks++;
			}
		});

		ModuleGoldenTest.run();
	}

	static function bundlerOptions():CompilerOptions {
		final opts = new CompilerOptions();
		opts.ModuleResolution = ModuleResolutionKindBundler;
		opts.Module = ModuleKindESNext;
		opts.Target = ScriptTargetESNext;
		return opts;
	}
}

class ResolutionHostStub implements ResolutionHost {
	final fs:FS;
	final cwd:String;

	public function new(fs:FS, cwd:String) {
		this.fs = fs;
		this.cwd = cwd;
	}

	public function FS():FS {
		return this.fs;
	}

	public function GetCurrentDirectory():String {
		return this.cwd;
	}
}

// flipFileExistsFS: the first FileExists call to `targetPath` (the outer resolution) runs the
// other resolution re-entrantly before it answers; the nested call is the Go "first released"
// caller and returns false, so it stores a nil-Contents cache entry first. Then the outer call
// returns true, reads the file (readArrived) and its Set gets the stale nil-Contents entry.
class FlipFileExistsFS {
	public final fs:FS;
	final base:FS;
	final targetPath:String;

	public var callCount:Int = 0;
	public var readArrived:Bool = false;
	public var other:Null<() -> Void> = null;

	public function new(base:FS, targetPath:String) {
		this.base = base;
		this.targetPath = targetPath;
		final replacements = new Replacements();
		replacements.FileExists = this.fileExists;
		replacements.ReadFile = this.readFile;
		this.fs = Wrapvfs.Wrap(base, replacements);
	}

	function fileExists(path:String):Bool {
		if (path == this.targetPath) {
			this.callCount++;
			final n = this.callCount;
			if (n == 1) {
				if (this.other != null) {
					final o = this.other;
					this.other = null;
					o();
				}
				return this.base.FileExists(path); // outer caller: file is visible
			}
			if (n == 2) {
				return false; // nested caller: simulate "file not yet visible"
			}
		}
		return this.base.FileExists(path);
	}

	function readFile(path:String):ValueOk<String> {
		if (path == this.targetPath) {
			this.readArrived = true;
		}
		return this.base.ReadFile(path);
	}
}
