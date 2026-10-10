package ts.vfs.iovfs;

import go.Fstest.MapFile;
import ts.vfs.Vfs;
import ts.vfs.VfsTestUtil.*;
import ts.vfs.iovfs.Iovfs;

// Port of iofs_test.go.
class IovfsTest {
	public static function run() {
		final testfs = new go.Fstest.MapFS();
		testfs.set("foo.ts", new MapFile(go.Utf8.StringToBytes("hello, world")));
		testfs.set("dir1/file1.ts", new MapFile(go.Utf8.StringToBytes("export const foo = 42;")));
		testfs.set("dir1/file2.ts", new MapFile(go.Utf8.StringToBytes("export const foo = 42;")));
		testfs.set("dir2/file1.ts", new MapFile(go.Utf8.StringToBytes("export const foo = 42;")));

		final fs = Iovfs.From(testfs, true);

		T.run("TestIOFS/ReadFile", () -> {
			var content = fs.ReadFile("/foo.ts");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);

			content = fs.ReadFile("/does/not/exist.ts");
			T.isTrue(!content.ok);
			T.eq("", content.value);
		});

		T.run("TestIOFS/ReadFileUnrooted", () -> {
			assertPanics(() -> {
				fs.ReadFile("bar");
			}, 'vfs: path "bar" is not absolute');
		});

		T.run("TestIOFS/FileExists", () -> {
			T.isTrue(fs.FileExists("/foo.ts"));
			T.isTrue(!fs.FileExists("/bar"));
		});

		T.run("TestIOFS/DirectoryExists", () -> {
			T.isTrue(fs.DirectoryExists("/"));
			T.isTrue(fs.DirectoryExists("/dir1"));
			T.isTrue(fs.DirectoryExists("/dir1/"));
			T.isTrue(fs.DirectoryExists("/dir1/./"));
			T.isTrue(!fs.DirectoryExists("/bar"));
		});

		T.run("TestIOFS/GetAccessibleEntries", () -> {
			final entries = fs.GetAccessibleEntries("/");
			eqStrings(["dir1", "dir2"], entries.Directories);
			eqStrings(["foo.ts"], entries.Files);
		});

		T.run("TestIOFS/WalkDir", () -> {
			var files:Null<Array<String>> = null;
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
			var files:Null<Array<String>> = null;
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
			final realpath = fs.Realpath("/foo.ts");
			T.eq("/foo.ts", realpath);
		});

		T.run("TestIOFS/UseCaseSensitiveFileNames", () -> {
			T.isTrue(fs.UseCaseSensitiveFileNames());
		});
	}
}
