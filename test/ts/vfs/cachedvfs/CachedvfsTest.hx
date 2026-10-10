package ts.vfs.cachedvfs;

import ts.vfs.Vfs;
import ts.vfs.cachedvfs.Cachedvfs;
import ts.vfs.vfsmock.MockGenerated;
import ts.vfs.vfsmock.Vfsmock;
import ts.vfs.vfstest.Vfstest;

// Port of cachedvfs_test.go.
class CachedvfsTest {
	static function createMockFS():FSMock {
		return Vfsmock.Wrap(Vfstest.FromMap(["/some/path/file.txt" => "hello world"], true));
	}

	public static function run() {
		T.run("TestDirectoryExists", () -> {
			final underlying = createMockFS();
			final cached = Cachedvfs.From(underlying);

			cached.DirectoryExists("/some/path");
			T.eq(1, underlying.DirectoryExistsCalls().length);

			cached.DirectoryExists("/some/path");
			T.eq(1, underlying.DirectoryExistsCalls().length);

			cached.ClearCache();
			cached.DirectoryExists("/some/path");
			T.eq(2, underlying.DirectoryExistsCalls().length);

			cached.DirectoryExists("/other/path");
			T.eq(3, underlying.DirectoryExistsCalls().length);

			cached.DisableAndClearCache();
			cached.DirectoryExists("/some/path");
			T.eq(4, underlying.DirectoryExistsCalls().length);

			cached.DirectoryExists("/some/path");
			T.eq(5, underlying.DirectoryExistsCalls().length);

			cached.Enable();
			cached.DirectoryExists("/some/path");
			T.eq(6, underlying.DirectoryExistsCalls().length);

			cached.DirectoryExists("/some/path");
			T.eq(6, underlying.DirectoryExistsCalls().length);
		});

		T.run("TestFileExists", () -> {
			final underlying = createMockFS();
			final cached = Cachedvfs.From(underlying);

			cached.FileExists("/some/path/file.txt");
			T.eq(1, underlying.FileExistsCalls().length);

			cached.FileExists("/some/path/file.txt");
			T.eq(1, underlying.FileExistsCalls().length);

			cached.ClearCache();
			cached.FileExists("/some/path/file.txt");
			T.eq(2, underlying.FileExistsCalls().length);

			cached.FileExists("/other/path/file.txt");
			T.eq(3, underlying.FileExistsCalls().length);

			cached.DisableAndClearCache();
			cached.FileExists("/some/path/file.txt");
			T.eq(4, underlying.FileExistsCalls().length);

			cached.FileExists("/some/path/file.txt");
			T.eq(5, underlying.FileExistsCalls().length);

			cached.Enable();
			cached.FileExists("/some/path/file.txt");
			T.eq(6, underlying.FileExistsCalls().length);

			cached.FileExists("/some/path/file.txt");
			T.eq(6, underlying.FileExistsCalls().length);
		});

		T.run("TestGetAccessibleEntries", () -> {
			final underlying = createMockFS();
			final cached = Cachedvfs.From(underlying);

			cached.GetAccessibleEntries("/some/path");
			T.eq(1, underlying.GetAccessibleEntriesCalls().length);

			cached.GetAccessibleEntries("/some/path");
			T.eq(1, underlying.GetAccessibleEntriesCalls().length);

			cached.ClearCache();
			cached.GetAccessibleEntries("/some/path");
			T.eq(2, underlying.GetAccessibleEntriesCalls().length);

			cached.GetAccessibleEntries("/other/path");
			T.eq(3, underlying.GetAccessibleEntriesCalls().length);

			cached.DisableAndClearCache();
			cached.GetAccessibleEntries("/some/path");
			T.eq(4, underlying.GetAccessibleEntriesCalls().length);

			cached.GetAccessibleEntries("/some/path");
			T.eq(5, underlying.GetAccessibleEntriesCalls().length);

			cached.Enable();
			cached.GetAccessibleEntries("/some/path");
			T.eq(6, underlying.GetAccessibleEntriesCalls().length);

			cached.GetAccessibleEntries("/some/path");
			T.eq(6, underlying.GetAccessibleEntriesCalls().length);
		});

		T.run("TestRealpath", () -> {
			final underlying = createMockFS();
			final cached = Cachedvfs.From(underlying);

			cached.Realpath("/some/path");
			T.eq(1, underlying.RealpathCalls().length);

			cached.Realpath("/some/path");
			T.eq(1, underlying.RealpathCalls().length);

			cached.ClearCache();
			cached.Realpath("/some/path");
			T.eq(2, underlying.RealpathCalls().length);

			cached.Realpath("/other/path");
			T.eq(3, underlying.RealpathCalls().length);

			cached.DisableAndClearCache();
			cached.Realpath("/some/path");
			T.eq(4, underlying.RealpathCalls().length);

			cached.Realpath("/some/path");
			T.eq(5, underlying.RealpathCalls().length);

			cached.Enable();
			cached.Realpath("/some/path");
			T.eq(6, underlying.RealpathCalls().length);

			cached.Realpath("/some/path");
			T.eq(6, underlying.RealpathCalls().length);
		});

		T.run("TestStat", () -> {
			final underlying = createMockFS();
			final cached = Cachedvfs.From(underlying);

			cached.Stat("/some/path");
			T.eq(1, underlying.StatCalls().length);

			cached.Stat("/some/path");
			T.eq(1, underlying.StatCalls().length);

			cached.ClearCache();
			cached.Stat("/some/path");
			T.eq(2, underlying.StatCalls().length);

			cached.Stat("/other/path");
			T.eq(3, underlying.StatCalls().length);

			cached.DisableAndClearCache();
			cached.Stat("/some/path");
			T.eq(4, underlying.StatCalls().length);

			cached.Stat("/some/path");
			T.eq(5, underlying.StatCalls().length);

			cached.Enable();
			cached.Stat("/some/path");
			T.eq(6, underlying.StatCalls().length);

			cached.Stat("/some/path");
			T.eq(6, underlying.StatCalls().length);
		});

		T.run("TestReadFile", () -> {
			final underlying = createMockFS();
			final cached = Cachedvfs.From(underlying);

			cached.ReadFile("/some/path/file.txt");
			T.eq(1, underlying.ReadFileCalls().length);

			cached.ReadFile("/some/path/file.txt");
			T.eq(2, underlying.ReadFileCalls().length);

			cached.ClearCache();
			cached.ReadFile("/some/path/file.txt");
			T.eq(3, underlying.ReadFileCalls().length);

			cached.DisableAndClearCache();
			cached.ReadFile("/some/path/file.txt");
			T.eq(4, underlying.ReadFileCalls().length);

			cached.ReadFile("/some/path/file.txt");
			T.eq(5, underlying.ReadFileCalls().length);

			cached.Enable();
			cached.ReadFile("/some/path/file.txt");
			T.eq(6, underlying.ReadFileCalls().length);

			cached.ReadFile("/some/path/file.txt");
			T.eq(7, underlying.ReadFileCalls().length);
		});

		T.run("TestUseCaseSensitiveFileNames", () -> {
			final underlying = createMockFS();
			final cached = Cachedvfs.From(underlying);

			cached.UseCaseSensitiveFileNames();
			T.eq(1, underlying.UseCaseSensitiveFileNamesCalls().length);

			cached.UseCaseSensitiveFileNames();
			T.eq(2, underlying.UseCaseSensitiveFileNamesCalls().length);

			cached.ClearCache();
			cached.UseCaseSensitiveFileNames();
			T.eq(3, underlying.UseCaseSensitiveFileNamesCalls().length);

			cached.DisableAndClearCache();
			cached.UseCaseSensitiveFileNames();
			T.eq(4, underlying.UseCaseSensitiveFileNamesCalls().length);

			cached.UseCaseSensitiveFileNames();
			T.eq(5, underlying.UseCaseSensitiveFileNamesCalls().length);

			cached.Enable();
			cached.UseCaseSensitiveFileNames();
			T.eq(6, underlying.UseCaseSensitiveFileNamesCalls().length);

			cached.UseCaseSensitiveFileNames();
			T.eq(7, underlying.UseCaseSensitiveFileNamesCalls().length);
		});

		T.run("TestWalkDir", () -> {
			final underlying = createMockFS();
			final cached = Cachedvfs.From(underlying);

			final walkFn:WalkDirFunc = (path, info, err) -> {
				return null;
			};

			cached.WalkDir("/some/path", walkFn);
			T.eq(1, underlying.WalkDirCalls().length);

			cached.WalkDir("/some/path", walkFn);
			T.eq(2, underlying.WalkDirCalls().length);

			cached.ClearCache();
			cached.WalkDir("/some/path", walkFn);
			T.eq(3, underlying.WalkDirCalls().length);

			cached.DisableAndClearCache();
			cached.WalkDir("/some/path", walkFn);
			T.eq(4, underlying.WalkDirCalls().length);

			cached.WalkDir("/some/path", walkFn);
			T.eq(5, underlying.WalkDirCalls().length);

			cached.Enable();
			cached.WalkDir("/some/path", walkFn);
			T.eq(6, underlying.WalkDirCalls().length);

			cached.WalkDir("/some/path", walkFn);
			T.eq(7, underlying.WalkDirCalls().length);
		});

		T.run("TestRemove", () -> {
			final underlying = createMockFS();
			final cached = Cachedvfs.From(underlying);

			cached.Remove("/some/path/file.txt");
			T.eq(1, underlying.RemoveCalls().length);

			cached.Remove("/some/path/file.txt");
			T.eq(2, underlying.RemoveCalls().length);

			cached.ClearCache();
			cached.Remove("/some/path/file.txt");
			T.eq(3, underlying.RemoveCalls().length);

			cached.DisableAndClearCache();
			cached.Remove("/some/path/file.txt");
			T.eq(4, underlying.RemoveCalls().length);

			cached.Remove("/some/path/file.txt");
			T.eq(5, underlying.RemoveCalls().length);

			cached.Enable();
			cached.Remove("/some/path/file.txt");
			T.eq(6, underlying.RemoveCalls().length);

			cached.Remove("/some/path/file.txt");
			T.eq(7, underlying.RemoveCalls().length);
		});

		T.run("TestWriteFile", () -> {
			final underlying = createMockFS();
			final cached = Cachedvfs.From(underlying);

			cached.WriteFile("/some/path/file.txt", "new content");
			T.eq(1, underlying.WriteFileCalls().length);

			cached.WriteFile("/some/path/file.txt", "another content");
			T.eq(2, underlying.WriteFileCalls().length);

			cached.ClearCache();
			cached.WriteFile("/some/path/file.txt", "third content");
			T.eq(3, underlying.WriteFileCalls().length);

			final call = underlying.WriteFileCalls()[2];
			T.eq("/some/path/file.txt", call.Path);
			T.eq("third content", call.Data);

			cached.DisableAndClearCache();
			cached.WriteFile("/some/path/file.txt", "fourth content");
			T.eq(4, underlying.WriteFileCalls().length);

			cached.WriteFile("/some/path/file.txt", "fifth content");
			T.eq(5, underlying.WriteFileCalls().length);

			cached.Enable();
			cached.WriteFile("/some/path/file.txt", "sixth content");
			T.eq(6, underlying.WriteFileCalls().length);

			cached.WriteFile("/some/path/file.txt", "seventh content");
			T.eq(7, underlying.WriteFileCalls().length);
		});
	}
}
