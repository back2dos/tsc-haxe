package ts.bundled;

import ts.bundled.Bundled;
import ts.tspath.Tspath;
import ts.vfs.VfsTestUtil.*;

// Port of bundled_test.go.
class BundledTest {
	public static function run() {
		T.run("TestTestingLibPath", () -> {
			final p = Bundled.TestingLibPath();

			nilError(go.Os.Stat(p).err);

			final libdts = go.Filepath.Join([p, "lib.d.ts"]);

			nilError(go.Os.Stat(libdts).err);
		});

		T.run("TestEmbeddedLibs", () -> {
			final fs = Bundled.WrapFS(ts.vfs.osvfs.Osvfs.FS());

			var files:Null<Array<String>> = null;

			final err = fs.WalkDir(Bundled.LibPath(), (path, d, err) -> {
				if (err != null) {
					return err;
				}
				if (!d.IsDir()) {
					if (files == null)
						files = [];
					files.push(Tspath.GetBaseFileName(path));
				}
				return null;
			});
			nilError(err);

			eqStrings(Bundled.LibNames, files);
		});
	
		// Not in Go: embedded contents and sizes equal the files on disk (non-ASCII libs included).
		T.run("EmbeddedContents (extra)", () -> {
			final fs = Bundled.WrapFS(ts.vfs.osvfs.Osvfs.FS());
			// PORT: typed FS paths (TypeScript main ed4807212c): the bundled lib directory as a RootedDirectoryPath.
			final libDir = Tspath.RootedDirectoryPathFromNormalized(Bundled.LibPath());
			for (name in ["lib.d.ts", "lib.dom.d.ts", "lib.es2015.core.d.ts", "lib.es5.d.ts"]) {
				final path = libDir.ResolveFile(name);
				final got = fs.ReadFile(path);
				T.isTrue(got.ok);
				final disk = go.Os.ReadFile(go.Filepath.Join([Bundled.TestingLibPath(), name]));
				nilError(disk.err);
				T.eq(bytesStr(disk.value), got.value);
				T.eq(disk.value.length, fs.Stat(path.AsPath()).Size());
				T.isTrue(fs.FileExists(path));
			}
			T.isTrue(fs.DirectoryExists(libDir));
			T.isTrue(!fs.FileExists(libDir.ResolveFile("nope.d.ts")));
			T.isTrue(Bundled.IsBundled(Bundled.LibPath()));
			eqStrings(["libs"], fs.GetAccessibleEntries(Tspath.RootedDirectoryPathFromNormalized("bundled:///")).Directories);
			T.eq(Bundled.LibNames.length, fs.GetAccessibleEntries(libDir).Files.length);
		});
	}
}
