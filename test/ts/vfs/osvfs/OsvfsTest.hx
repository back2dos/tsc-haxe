package ts.vfs.osvfs;

import go.Filepath;
import ts.tspath.Tspath;
import ts.vfs.VfsTestUtil.*;
import ts.vfs.osvfs.Osvfs;

// Port of os_test.go, realpath_test.go and helpers_test.go.
// PORT: t.TempDir() → a fresh directory under bin/vfs/tmp/ (removed first, left for inspection).
// PORT: repo.RootPath() → the upstream checkout (T.UPSTREAM).
// BenchmarkRealpath is not ported.
class OsvfsTest {
	static var tempCount = 0;

	static function tempDir(name:String):String {
		final wd = go.Os.Getwd().value;
		tempCount++;
		final dir = Filepath.Join([wd, "bin", "vfs", "tmp", name + tempCount]);
		nilError(go.Os.RemoveAll(dir));
		nilError(go.Os.MkdirAll(dir, 511 /* 0o777 */));
		return dir;
	}

	// --- helpers_test.go ---

	static function mklink(target:String, link:String, isDir:Bool) {
		// PORT: Windows junctions (mklink /J) are not supported.
		final err = go.Os.Symlink(target, link);
		nilError(err);
	}

	// realpath_test.go setupSymlinks: (targetFile, linkFile)
	static function setupSymlinks():go.Tuple.Pair<String, String> {
		final tmp = tempDir("setupSymlinks");

		final target = Filepath.Join([tmp, "target"]);
		final targetFile = Filepath.Join([target, "file"]);

		final link = Filepath.Join([tmp, "link"]);
		final linkFile = Filepath.Join([link, "file"]);

		nilError(go.Os.MkdirAll(target, 511));
		nilError(go.Os.WriteFile(targetFile, go.Utf8.StringToBytes("hello"), 438));

		mklink(target, link, true);

		return new go.Tuple.Pair(targetFile, linkFile);
	}

	public static function run() {
		// --- os_test.go ---
		final fs = Osvfs.FS();

		T.run("TestOS/ReadFile", () -> {
			final goMod = Filepath.Join([go.Os.Getwd().value, T.UPSTREAM, "go.mod"]);
			final goModPath = Tspath.NormalizePath(goMod);

			final expectedRaw = go.Os.ReadFile(goMod);
			nilError(expectedRaw.err);
			final expected = bytesStr(expectedRaw.value);

			final contents = fs.ReadFile(goModPath);
			T.isTrue(contents.ok);
			T.eq(expected, contents.value);
		});

		T.run("TestOS/Realpath", () -> {
			final h = go.Os.UserHomeDir();
			if (h.err != null) {
				return; // t.Skip(err)
			}
			final home = Tspath.NormalizePath(h.value);

			final expected = home;
			// PORT: the Windows drive-letter case is not applicable (POSIX only).
			final realpath = fs.Realpath(home);
			T.eq(expected, realpath);
		});

		T.run("TestOS/UseCaseSensitiveFileNames", () -> {
			// Just check that it works.
			fs.UseCaseSensitiveFileNames();

			switch (Sys.systemName()) {
				case "Windows":
					T.isTrue(!fs.UseCaseSensitiveFileNames());
				case "Linux":
					T.isTrue(fs.UseCaseSensitiveFileNames());
			}
		});

		// --- realpath_test.go ---

		T.run("TestSymlinkRealpath", () -> {
			final p = setupSymlinks();
			final targetFile = p.a;
			final linkFile = p.b;

			final gotContents = go.Os.ReadFile(linkFile);
			nilError(gotContents.err);
			T.eq("hello", bytesStr(gotContents.value));

			final fs = Osvfs.FS();

			final targetRealpath = fs.Realpath(Tspath.NormalizePath(targetFile));
			final linkRealpath = fs.Realpath(Tspath.NormalizePath(linkFile));

			if (targetRealpath != linkRealpath) {
				T.fail('expected realpath of target and link to be equal, got ${go.Strconv.Quote(targetRealpath)} and ${go.Strconv.Quote(linkRealpath)}');
			}
		});

		T.run("TestGetAccessibleEntries", () -> {
			final tmp = tempDir("TestGetAccessibleEntries");
			final target = Filepath.Join([tmp, "target"]);
			final link = Filepath.Join([tmp, "link"]);

			nilError(go.Os.MkdirAll(target, 511));
			nilError(go.Os.MkdirAll(link, 511));

			final targetFile1 = Filepath.Join([target, "file1"]);
			final targetFile2 = Filepath.Join([target, "file2"]);

			nilError(go.Os.WriteFile(targetFile1, go.Utf8.StringToBytes("hello"), 438));
			nilError(go.Os.WriteFile(targetFile2, go.Utf8.StringToBytes("world"), 438));

			final targetDir1 = Filepath.Join([target, "dir1"]);
			final targetDir2 = Filepath.Join([target, "dir2"]);

			nilError(go.Os.MkdirAll(targetDir1, 511));
			nilError(go.Os.MkdirAll(targetDir2, 511));

			mklink(targetFile1, Filepath.Join([link, "file1"]), false);
			mklink(targetFile2, Filepath.Join([link, "file2"]), false);
			mklink(targetDir1, Filepath.Join([link, "dir1"]), true);
			mklink(targetDir2, Filepath.Join([link, "dir2"]), true);

			final fs = Osvfs.FS();

			var entries = fs.GetAccessibleEntries(Tspath.NormalizePath(link));

			eqStrings(["dir1", "dir2"], entries.Directories);
			eqStrings(["file1", "file2"], entries.Files);
			T.isTrue(entries.Symlinks != null, "expected Symlinks to be set for directory with symlinks");
			T.eq(4, [for (_ in entries.Symlinks.keys()) 1].length);
			for (name in ["file1", "file2", "dir1", "dir2"]) {
				final ok = entries.Symlinks.exists(name);
				T.isTrue(ok, 'expected ${go.Strconv.Quote(name)} to be in Symlinks');
			}

			// Non-symlink directory should have empty Symlinks.
			entries = fs.GetAccessibleEntries(Tspath.NormalizePath(target));
			eqStrings(["dir1", "dir2"], entries.Directories);
			eqStrings(["file1", "file2"], entries.Files);
			T.isTrue(entries.Symlinks != null, "expected Symlinks to be non-nil for directory without symlinks");
			T.eq(0, [for (_ in entries.Symlinks.keys()) 1].length);
		});
	}
}
