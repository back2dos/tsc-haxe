package ts.vfs.iovfs;

import go.Fstest.MapFile;
import ts.vfs.Vfs;
import ts.vfs.VfsTestUtil.*;
import ts.vfs.iovfs.Iovfs;
import ts.tspath.Tspath;

// Port of iofs_test.go.
class IovfsTest {
	public static function run() {
		final testfs = new go.Fstest.MapFS();
		testfs.set("foo.ts", new MapFile(go.Utf8.StringToBytes("hello, world")));
		testfs.set("dir1/file1.ts", new MapFile(go.Utf8.StringToBytes("export const foo = 42;")));
		testfs.set("dir1/file2.ts", new MapFile(go.Utf8.StringToBytes("export const foo = 42;")));
		testfs.set("dir2/file1.ts", new MapFile(go.Utf8.StringToBytes("export const foo = 42;")));

		final fs = Iovfs.From(testfs, CaseSensitive);

		T.run("TestIOFS/ReadFile", () -> {
			var content = fs.ReadFile(rf("/foo.ts"));
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);

			content = fs.ReadFile(rf("/does/not/exist.ts"));
			T.isTrue(!content.ok);
			T.eq("", content.value);
		});

		// PORT: TypeScript main (ed4807212c) dropped ReadFileUnrooted: ReadFile takes a RootedFilePath, an unrooted
		// name no longer type checks.

		T.run("TestIOFS/FileExists", () -> {
			T.isTrue(fs.FileExists(rf("/foo.ts")));
			T.isTrue(!fs.FileExists(rf("/bar")));
		});

		T.run("TestIOFS/DirectoryExists", () -> {
			T.isTrue(fs.DirectoryExists(rd("/")));
			T.isTrue(fs.DirectoryExists(rd("/dir1")));
			T.isTrue(fs.DirectoryExists(Tspath.RootedDirectoryPathFromAbsolute("/dir1/")));
			T.isTrue(fs.DirectoryExists(Tspath.RootedDirectoryPathFromAbsolute("/dir1/./")));
			T.isTrue(!fs.DirectoryExists(rd("/bar")));
		});

		T.run("TestIOFS/GetAccessibleEntries", () -> {
			final entries = fs.GetAccessibleEntries(rd("/"));
			eqStrings(["dir1", "dir2"], entries.Directories);
			eqStrings(["foo.ts"], entries.Files);
		});

		T.run("TestIOFS/WalkDir", () -> {
			var files:Slice<String> = null;
			final err = fs.WalkDir("/", (path, d, err) -> {
				if (err != null) {
					return err;
				}
				if (!d.IsDir()) {
					if (files == null)
						files = [];
					files.push(path);
				}
				return null;
			});
			nilError(err);

			files.sort(go.Strings.Compare);

			eqStrings(["/dir1/file1.ts", "/dir1/file2.ts", "/dir2/file1.ts", "/foo.ts"], files);
		});

		T.run("TestIOFS/WalkDirSkip", () -> {
			var files:Slice<String> = null;
			final err = fs.WalkDir("/", (path, d, err) -> {
				if (err != null) {
					return err;
				}
				if (!d.IsDir()) {
					if (files == null)
						files = [];
					files.push(path);
				}

				if (path == "/") {
					return null;
				}

				return Vfs.SkipDir;
			});
			nilError(err);

			files.sort(go.Strings.Compare);

			eqStrings(["/foo.ts"], files);
		});

		T.run("TestIOFS/Realpath", () -> {
			final realpath = fs.Realpath(rp("/foo.ts"));
			T.eq("/foo.ts", realpath.AsString());
		});

		T.run("TestIOFS/CaseSensitivity", () -> {
			T.isTrue(fs.CaseSensitivity().IsCaseSensitive());
		});
	}
}
