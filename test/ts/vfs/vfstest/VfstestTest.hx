package ts.vfs.vfstest;

import go.Fs;
import go.Fstest.MapFile;
import haxe.io.Bytes;
import ts.vfs.Vfs;
import ts.vfs.VfsTestUtil.*;
import ts.vfs.vfstest.Vfstest;

// Port of vfstest_test.go.
// PORT: `assert.NilError(t, fstest.TestFS(vfs, ...))` lines are skipped: fstest.TestFS (the Go
// standard library's fs.FS conformance checker) is not ported.
// PORT: TestStress runs its operations sequentially (single-threaded port, one worker).
class VfstestTest {
	static function mapFS(entries:Map<String, MapFile>):go.Fstest.MapFS {
		final m = new go.Fstest.MapFS();
		for (k => v in entries) {
			m.set(k, v);
		}
		return m;
	}

	static function b(s:String):Bytes {
		return go.Utf8.StringToBytes(s);
	}

	static function dirEntriesToNames(entries:Array<DirEntry>):Array<String> {
		final names = [];
		for (entry in entries) {
			names.push(entry.Name());
		}
		return names;
	}

	public static function run() {
		T.run("TestInsensitive", () -> {
			final contents = b("bar");

			final vfs = Vfstest.convertMapFS(mapFS([
				"foo/bar/baz" => new MapFile(contents, null, null, 1234),
				"foo/bar2/baz2" => new MapFile(contents, null, null, 1234),
				"foo/bar3/baz3" => new MapFile(contents, null, null, 1234),
			]), false /*useCaseSensitiveFileNames*/, null);

			final sensitive = Fs.ReadFile(vfs, "foo/bar/baz");
			nilError(sensitive.err);
			T.eq("bar", bytesStr(sensitive.value));
			final sensitiveInfo = Fs.Stat(vfs, "foo/bar/baz");
			nilError(sensitiveInfo.err);
			T.eq(1234, (sensitiveInfo.value.Sys() : Int));
			final sensitiveRealPath = vfs.Realpath("foo/bar/baz");
			nilError(sensitiveRealPath.err);
			T.eq("foo/bar/baz", sensitiveRealPath.value);
			var entries = Fs.ReadDir(vfs, "foo");
			nilError(entries.err);
			eqStrings(["bar", "bar2", "bar3"], dirEntriesToNames(entries.value));

			errorContains(vfs.Realpath("does/not/exist").err, "file does not exist");
			errorContains(Fs.Stat(vfs, "does/not/exist").err, "file does not exist");

			// PORT: skipped assert.NilError(t, fstest.TestFS(vfs, "foo/bar/baz"))

			final insensitive = Fs.ReadFile(vfs, "Foo/Bar/Baz");
			nilError(insensitive.err);
			T.eq("bar", bytesStr(insensitive.value));
			final insensitiveInfo = Fs.Stat(vfs, "Foo/Bar/Baz");
			nilError(insensitiveInfo.err);
			T.eq(1234, (insensitiveInfo.value.Sys() : Int));
			final insensitiveRealPath = vfs.Realpath("Foo/Bar/Baz");
			nilError(insensitiveRealPath.err);
			T.eq("foo/bar/baz", insensitiveRealPath.value);
			entries = Fs.ReadDir(vfs, "Foo");
			nilError(entries.err);
			eqStrings(["bar", "bar2", "bar3"], dirEntriesToNames(entries.value));

			errorContains(vfs.Realpath("Does/Not/Exist").err, "file does not exist");
			errorContains(Fs.Stat(vfs, "Does/Not/Exist").err, "file does not exist");
		});

		T.run("TestInsensitiveUpper", () -> {
			final contents = b("bar");

			final vfs = Vfstest.convertMapFS(mapFS([
				"Foo/Bar/Baz" => new MapFile(contents, null, null, 1234),
				"Foo/Bar2/Baz2" => new MapFile(contents, null, null, 1234),
				"Foo/Bar3/Baz3" => new MapFile(contents, null, null, 1234),
			]), false /*useCaseSensitiveFileNames*/, null);

			final sensitive = Fs.ReadFile(vfs, "foo/bar/baz");
			nilError(sensitive.err);
			T.eq("bar", bytesStr(sensitive.value));
			final sensitiveInfo = Fs.Stat(vfs, "foo/bar/baz");
			nilError(sensitiveInfo.err);
			T.eq(1234, (sensitiveInfo.value.Sys() : Int));
			var entries = Fs.ReadDir(vfs, "foo");
			nilError(entries.err);
			eqStrings(["Bar", "Bar2", "Bar3"], dirEntriesToNames(entries.value));

			final insensitive = Fs.ReadFile(vfs, "Foo/Bar/Baz");
			nilError(insensitive.err);
			T.eq("bar", bytesStr(insensitive.value));
			final insensitiveInfo = Fs.Stat(vfs, "Foo/Bar/Baz");
			nilError(insensitiveInfo.err);
			T.eq(1234, (insensitiveInfo.value.Sys() : Int));
			entries = Fs.ReadDir(vfs, "Foo");
			nilError(entries.err);
			eqStrings(["Bar", "Bar2", "Bar3"], dirEntriesToNames(entries.value));

			// PORT: skipped assert.NilError(t, fstest.TestFS(vfs, "Foo/Bar/Baz"))
		});

		T.run("TestSensitive", () -> {
			final contents = b("bar");

			final vfs = Vfstest.convertMapFS(mapFS([
				"foo/bar/baz" => new MapFile(contents, null, null, 1234),
				"foo/bar2/baz2" => new MapFile(contents, null, null, 1234),
				"foo/bar3/baz3" => new MapFile(contents, null, null, 1234),
			]), true /*useCaseSensitiveFileNames*/, null);

			final sensitive = Fs.ReadFile(vfs, "foo/bar/baz");
			nilError(sensitive.err);
			T.eq("bar", bytesStr(sensitive.value));
			final sensitiveInfo = Fs.Stat(vfs, "foo/bar/baz");
			nilError(sensitiveInfo.err);
			T.eq(1234, (sensitiveInfo.value.Sys() : Int));

			// PORT: skipped assert.NilError(t, fstest.TestFS(vfs, "foo/bar/baz"))

			errorContains(Fs.ReadFile(vfs, "Foo/Bar/Baz").err, "file does not exist");
		});

		T.run("TestSensitiveDuplicatePath", () -> {
			final testfs = mapFS([
				"foo" => new MapFile(b("bar")),
				"Foo" => new MapFile(b("baz")),
			]);

			assertPanics(() -> {
				Vfstest.convertMapFS(testfs, false /*useCaseSensitiveFileNames*/, null);
			}, 'duplicate path: "Foo" and "foo" have the same canonical path');
		});

		T.run("TestInsensitiveDuplicatePath", () -> {
			final testfs = mapFS([
				"foo" => new MapFile(b("bar")),
				"Foo" => new MapFile(b("baz")),
			]);

			Vfstest.convertMapFS(testfs, true /*useCaseSensitiveFileNames*/, null);
		});

		T.run("TestWritableFS", () -> {
			final fs = Vfstest.FromMap((null : Map<String, Any>), false);

			var err = fs.WriteFile("/foo/bar/baz", "hello, world");
			nilError(err);

			var content = fs.ReadFile("/foo/bar/baz");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);

			err = fs.WriteFile("/foo/bar/baz", "goodbye, world");
			nilError(err);

			content = fs.ReadFile("/foo/bar/baz");
			T.isTrue(content.ok);
			T.eq("goodbye, world", content.value);

			err = fs.WriteFile("/foo/bar/baz/oops", "goodbye, world");
			errorContains(err, 'mkdir "foo/bar/baz": path exists but is not a directory');
		});

		T.run("TestWritableFSDelete", () -> {
			final fs = Vfstest.FromMap((null : Map<String, Any>), false);

			fs.WriteFile("/foo/bar/file.ts", "remove");
			T.isTrue(fs.FileExists("/foo/bar/file.ts"));
			var err = fs.Remove("/foo/bar/file.ts");
			nilError(err);
			T.isTrue(!fs.FileExists("/foo/bar/file.ts"));

			fs.WriteFile("/foo/bar/test/remove2.ts", "remove2");
			T.isTrue(fs.DirectoryExists("/foo/bar/test"));
			err = fs.Remove("/foo/bar/test");
			nilError(err);
			T.isTrue(!fs.FileExists("/foo/bar/test/remove2.ts"));
			T.isTrue(!fs.DirectoryExists("/foo/bar/test"));

			// no errors when removing file/dir that does not exist
			err = fs.Remove("/foo/bar/test");
			nilError(err);
			err = fs.Remove("/foo/bar/file.ts");
			nilError(err);

			fs.WriteFile("/foo/barbar", "remove2");
			fs.Remove("/foo/bar");
			T.isTrue(fs.FileExists("/foo/barbar"));
		});

		T.run("TestStress", () -> {
			final fs = Vfstest.FromMap((null : Map<String, Any>), false);

			final ops:Array<() -> Void> = [
				() -> {
					fs.WriteFile("/foo/bar/baz.txt", "hello, world");
				},
				() -> {
					fs.ReadFile("/foo/bar/baz.txt");
				},
				() -> {
					fs.DirectoryExists("/foo/bar");
				},
				() -> {
					fs.FileExists("/foo/bar");
				},
				() -> {
					fs.FileExists("/foo/bar/baz.txt");
				},
				() -> {
					fs.GetAccessibleEntries("/foo/bar");
				},
				() -> {
					fs.Realpath("/foo/bar/baz.txt");
				},
				() -> {
					fs.WalkDir("/", (path, d, err) -> {
						if (err != null) {
							return err;
						}
						return d.Info().err;
					});
				},
			];

			// PORT: runtime.GOMAXPROCS(0) goroutines → one sequential worker; rand.Shuffle → a
			// fixed Fisher-Yates shuffle with a small LCG.
			final randomOps = ops.copy();
			var seed = 12345;
			var i = randomOps.length - 1;
			while (i > 0) {
				seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
				final j = seed % (i + 1);
				final t = randomOps[i];
				randomOps[i] = randomOps[j];
				randomOps[j] = t;
				i--;
			}

			for (i in 0...10000) {
				randomOps[i % randomOps.length]();
			}
		});

		T.run("TestParentDirFile", () -> {
			final testfs = mapFS([
				"foo" => new MapFile(b("bar")),
				"foo/oops" => new MapFile(b("baz")),
			]);

			assertPanics(() -> {
				Vfstest.convertMapFS(testfs, false /*useCaseSensitiveFileNames*/, null);
			}, 'failed to create intermediate directories for "foo/oops": mkdir "foo": path exists but is not a directory');
		});

		T.run("TestFromMap/POSIX", () -> {
			final m:Map<String, Any> = [
				"/string" => "hello, world",
				"/bytes" => b("hello, world"),
				"/mapfile" => new MapFile(b("hello, world")),
			];
			final fs = Vfstest.FromMap(m, false);

			var content = fs.ReadFile("/string");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);

			content = fs.ReadFile("/bytes");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);

			content = fs.ReadFile("/mapfile");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);
		});

		T.run("TestFromMap/Windows", () -> {
			final m:Map<String, Any> = [
				"c:/string" => "hello, world",
				"d:/bytes" => b("hello, world"),
				"e:/mapfile" => new MapFile(b("hello, world")),
			];
			final fs = Vfstest.FromMap(m, false);

			var content = fs.ReadFile("c:/string");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);

			content = fs.ReadFile("d:/bytes");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);

			content = fs.ReadFile("e:/mapfile");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);
		});

		T.run("TestFromMap/Mixed", () -> {
			assertPanics(() -> {
				final m:Map<String, Any> = [
					"/string" => "hello, world",
					"c:/bytes" => b("hello, world"),
				];
				Vfstest.FromMap(m, false);
			}, "mixed posix and windows paths");
		});

		T.run("TestFromMap/NonRooted", () -> {
			assertPanics(() -> {
				final m:Map<String, Any> = ["string" => "hello, world"];
				Vfstest.FromMap(m, false);
			}, 'non-rooted path "string"');
		});

		T.run("TestFromMap/NonNormalized", () -> {
			assertPanics(() -> {
				final m:Map<String, Any> = ["/string/" => "hello, world"];
				Vfstest.FromMap(m, false);
			}, 'non-normalized path "/string/"');
		});

		T.run("TestFromMap/NonNormalized2", () -> {
			assertPanics(() -> {
				final m:Map<String, Any> = ["/string/../foo" => "hello, world"];
				Vfstest.FromMap(m, false);
			}, 'non-normalized path "/string/../foo"');
		});

		T.run("TestFromMap/InvalidFile", () -> {
			assertPanics(() -> {
				final m:Map<String, Any> = ["/string" => 1234];
				Vfstest.FromMap(m, false);
			}, "invalid file type int");
		});

		{
			final fs = Vfstest.FromMap([
				"/foo.ts" => "hello, world",
				"/dir1/file1.ts" => "export const foo = 42;",
				"/dir1/file2.ts" => "export const foo = 42;",
				"/dir2/file1.ts" => "export const foo = 42;",
			], false /*useCaseSensitiveFileNames*/);

			T.run("TestVFSTestMapFS/ReadFile", () -> {
				var content = fs.ReadFile("/foo.ts");
				T.isTrue(content.ok);
				T.eq("hello, world", content.value);

				content = fs.ReadFile("/does/not/exist.ts");
				T.isTrue(!content.ok);
				T.eq("", content.value);
			});

			T.run("TestVFSTestMapFS/Realpath", () -> {
				var realpath = fs.Realpath("/foo.ts");
				T.eq("/foo.ts", realpath);

				realpath = fs.Realpath("/Foo.ts");
				T.eq("/foo.ts", realpath);

				realpath = fs.Realpath("/does/not/exist.ts");
				T.eq("/does/not/exist.ts", realpath);
			});

			T.run("TestVFSTestMapFS/UseCaseSensitiveFileNames", () -> {
				T.isTrue(!fs.UseCaseSensitiveFileNames());
			});
		}

		{
			final fs = Vfstest.FromMap([
				"c:/foo.ts" => "hello, world",
				"c:/dir1/file1.ts" => "export const foo = 42;",
				"c:/dir1/file2.ts" => "export const foo = 42;",
				"c:/dir2/file1.ts" => "export const foo = 42;",
			], false);

			T.run("TestVFSTestMapFSWindows/ReadFile", () -> {
				var content = fs.ReadFile("c:/foo.ts");
				T.isTrue(content.ok);
				T.eq("hello, world", content.value);

				content = fs.ReadFile("c:/does/not/exist.ts");
				T.isTrue(!content.ok);
				T.eq("", content.value);
			});

			T.run("TestVFSTestMapFSWindows/Realpath", () -> {
				var realpath = fs.Realpath("c:/foo.ts");
				T.eq("c:/foo.ts", realpath);

				realpath = fs.Realpath("c:/Foo.ts");
				T.eq("c:/foo.ts", realpath);

				realpath = fs.Realpath("c:/does/not/exist.ts");
				T.eq("c:/does/not/exist.ts", realpath);
			});
		}

		{
			final expected = "hello, world";

			final tests:Array<{name:String, bigEndian:Bool, bom:Array<Int>}> = [
				{name: "BigEndian", bigEndian: true, bom: [0xFE, 0xFF]},
				{name: "LittleEndian", bigEndian: false, bom: [0xFF, 0xFE]},
			];

			for (tt in tests) {
				T.run("TestBOM/" + tt.name, () -> {
					final codePoints:Array<Int> = [];

					for (i in 0...expected.length) {
						codePoints.push(StringTools.fastCodeAt(expected, i));
					}

					final buf = new haxe.io.BytesBuffer();
					for (x in tt.bom) {
						buf.addByte(x);
					}

					for (r in codePoints) {
						if (tt.bigEndian) {
							buf.addByte((r >> 8) & 0xFF);
							buf.addByte(r & 0xFF);
						} else {
							buf.addByte(r & 0xFF);
							buf.addByte((r >> 8) & 0xFF);
						}
					}

					final fs = Vfstest.FromMap(["/foo.ts" => buf.getBytes()], true);

					final content = fs.ReadFile("/foo.ts");
					T.isTrue(content.ok);
					T.eq(expected, content.value);
				});
			}

			T.run("TestBOM/UTF8", () -> {
				final buf = new haxe.io.BytesBuffer();
				buf.addByte(0xEF);
				buf.addByte(0xBB);
				buf.addByte(0xBF);
				buf.add(b(expected));
				final fs = Vfstest.FromMap(["/foo.ts" => buf.getBytes()], true);

				final content = fs.ReadFile("/foo.ts");
				T.isTrue(content.ok);
				T.eq(expected, content.value);
			});
		}

		{
			final m:Map<String, Any> = [
				"/foo.ts" => "hello, world",
				"/symlink.ts" => Vfstest.Symlink("/foo.ts"),
				"/some/dir/file.ts" => "hello, world",
				"/some/dirlink" => Vfstest.Symlink("/some/dir"),
				"/a" => Vfstest.Symlink("/b"),
				"/b" => Vfstest.Symlink("/c"),
				"/c" => Vfstest.Symlink("/d"),
				"/d/existing.ts" => "this is existing.ts",
			];
			final fs = Vfstest.FromMap(m, false);

			T.run("TestSymlink/ReadFile", () -> {
				var content = fs.ReadFile("/symlink.ts");
				T.isTrue(content.ok);
				T.eq("hello, world", content.value);

				content = fs.ReadFile("/some/dirlink/file.ts");
				T.isTrue(content.ok);
				T.eq("hello, world", content.value);

				content = fs.ReadFile("/a/existing.ts");
				T.isTrue(content.ok);
				T.eq("this is existing.ts", content.value);
			});

			T.run("TestSymlink/Realpath", () -> {
				var realpath = fs.Realpath("/symlink.ts");
				T.eq("/foo.ts", realpath);

				realpath = fs.Realpath("/some/dirlink");
				T.eq("/some/dir", realpath);

				realpath = fs.Realpath("/some/dirlink/file.ts");
				T.eq("/some/dir/file.ts", realpath);
			});

			T.run("TestSymlink/FileExists", () -> {
				T.isTrue(fs.FileExists("/symlink.ts"));
				T.isTrue(fs.FileExists("/some/dirlink/file.ts"));
				T.isTrue(fs.FileExists("/a/existing.ts"));
			});

			T.run("TestSymlink/DirectoryExists", () -> {
				T.isTrue(fs.DirectoryExists("/some/dirlink"));
				T.isTrue(fs.DirectoryExists("/d"));
				T.isTrue(fs.DirectoryExists("/c"));
				T.isTrue(fs.DirectoryExists("/b"));
				T.isTrue(fs.DirectoryExists("/a"));
			});
		}

		T.run("TestWritableFSSymlink", () -> {
			final m:Map<String, Any> = [
				"/some/dir/other.ts" => "NOTHING",
				"/other.ts" => Vfstest.Symlink("/some/dir/other.ts"),
				"/some/dirlink" => Vfstest.Symlink("/some/dir"),
				"/brokenlink" => Vfstest.Symlink("/does/not/exist"),
				"/a" => Vfstest.Symlink("/b"),
				"/b" => Vfstest.Symlink("/c"),
				"/c" => Vfstest.Symlink("/d"),
				"/d/existing.ts" => "hello, world",
			];
			final fs = Vfstest.FromMap(m, false);

			var err = fs.WriteFile("/some/dirlink/file.ts", "hello, world");
			nilError(err);

			var content = fs.ReadFile("/some/dirlink/file.ts");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);

			content = fs.ReadFile("/some/dir/file.ts");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);

			err = fs.WriteFile("/some/dirlink/file.ts", "goodbye, world");
			nilError(err);

			content = fs.ReadFile("/some/dirlink/file.ts");
			T.isTrue(content.ok);
			T.eq("goodbye, world", content.value);

			err = fs.WriteFile("/other.ts", "hello, world");
			nilError(err);

			content = fs.ReadFile("/other.ts");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);

			content = fs.ReadFile("/some/dir/other.ts");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);

			err = fs.WriteFile("/some/dirlink", "hello, world");
			error(err, 'write "some/dirlink": path exists but is not a regular file');

			// Can't write inside a broken dir symlink
			err = fs.WriteFile("/brokenlink/file.ts", "hello, world");
			error(err, 'broken symlink "brokenlink" -> "does/not/exist"');

			err = fs.WriteFile("/brokenlink/also/wrong/file.ts", "hello, world");
			error(err, 'broken symlink "brokenlink" -> "does/not/exist"');

			// But we can write to a broken file symlink
			err = fs.WriteFile("/brokenlink", "hello, world");
			nilError(err);
			content = fs.ReadFile("/brokenlink");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);
			content = fs.ReadFile("/does/not/exist");
			T.isTrue(content.ok);
			T.eq("hello, world", content.value);
		});

		T.run("TestWritableFSSymlinkChain", () -> {
			final m:Map<String, Any> = [
				"/a" => Vfstest.Symlink("/b"),
				"/b" => Vfstest.Symlink("/c"),
				"/c" => Vfstest.Symlink("/d"),
				"/d/existing.ts" => "hello, world",
			];
			final fs = Vfstest.FromMap(m, false);

			final err = fs.WriteFile("/a/foo/bar/new.ts", "this is new.ts");
			nilError(err);
			var content = fs.ReadFile("/a/foo/bar/new.ts");
			T.isTrue(content.ok);
			T.eq("this is new.ts", content.value);
			content = fs.ReadFile("/b/foo/bar/new.ts");
			T.isTrue(content.ok);
			T.eq("this is new.ts", content.value);
			content = fs.ReadFile("/d/foo/bar/new.ts");
			T.isTrue(content.ok);
			T.eq("this is new.ts", content.value);
		});

		T.run("TestWritableFSSymlinkChainNotDir", () -> {
			final m:Map<String, Any> = [
				"/a" => Vfstest.Symlink("/b"),
				"/b" => Vfstest.Symlink("/c"),
				"/c" => Vfstest.Symlink("/d"),
				"/d" => "hello, world",
			];
			final fs = Vfstest.FromMap(m, false);

			final err = fs.WriteFile("/a/foo/bar/new.ts", "this is new.ts");
			error(err, 'mkdir "d": path exists but is not a directory');
		});

		T.run("TestWritableFSSymlinkDelete", () -> {
			final m:Map<String, Any> = [
				"/some/dir/other.ts" => "NOTHING",
				"/other.ts" => Vfstest.Symlink("/some/dir/other.ts"),
				"/some/dirlink" => Vfstest.Symlink("/some/dir"),
				"/brokenlink" => Vfstest.Symlink("/does/not/exist"),
				"/a" => Vfstest.Symlink("/b"),
				"/b" => Vfstest.Symlink("/c"),
				"/c" => Vfstest.Symlink("/d"),
				"/d/existing.ts" => "hello, world",
			];
			final fs = Vfstest.FromMap(m, false);

			var err = fs.Remove("/a");
			nilError(err);
			T.isTrue(!fs.DirectoryExists("/a"));
			T.isTrue(fs.DirectoryExists("/b"));
			T.isTrue(fs.DirectoryExists("/c"));
			T.isTrue(fs.FileExists("/d/existing.ts"));

			// symlinks should still exist even if underlying file/dir is deleted
			err = fs.Remove("/d");
			nilError(err);
			T.isTrue(!fs.DirectoryExists("/b"));
			T.isTrue(!fs.DirectoryExists("/c"));
			T.isTrue(!fs.DirectoryExists("/d"));
			T.isTrue(!fs.FileExists("/d/again.ts"));
			err = fs.WriteFile("/d/again.ts", "d exists again");
			nilError(err);
			T.isTrue(fs.DirectoryExists("/b"));
			T.isTrue(fs.DirectoryExists("/c"));
			final content = fs.ReadFile("/b/again.ts");
			T.eq("d exists again", content.value);

			T.isTrue(!fs.FileExists("/brokenlink"));
			T.isTrue(!fs.DirectoryExists("/brokenlink"));
			err = fs.Remove("/does/not/exist"); // should do nothing
			nilError(err);
			T.isTrue(!fs.FileExists("/brokenlink"));
			T.isTrue(!fs.DirectoryExists("/brokenlink"));
			err = fs.WriteFile("/does/not/exist", "hello, world");
			nilError(err);
			T.isTrue(fs.FileExists("/brokenlink"));
		});
	}
}
