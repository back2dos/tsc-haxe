package ts.vfs;

// Runs the tests of package vfs and its sub-packages, and of bundled.
// vfs_test.go has only BenchmarkReadFile (not ported).
class VfsTestMain {
	static function pkg(name:String, run:() -> Void) {
		final c = T.checks;
		final f = T.failures;
		run();
		Sys.println('  $name: ${T.checks - c} checks, ${T.failures - f} failures');
	}

	static function main() {
		pkg("vfs/internal", ts.vfs.internal.InternalTest.run);
		pkg("vfs/vfstest", ts.vfs.vfstest.VfstestTest.run);
		pkg("vfs/iovfs", ts.vfs.iovfs.IovfsTest.run);
		pkg("vfs/cachedvfs", ts.vfs.cachedvfs.CachedvfsTest.run);
		pkg("vfs/vfsmock", ts.vfs.vfsmock.VfsmockTest.run);
		pkg("vfs/osvfs", ts.vfs.osvfs.OsvfsTest.run);
		pkg("vfs/vfsmatch", ts.vfs.vfsmatch.VfsmatchTest.run);
		pkg("bundled", ts.bundled.BundledTest.run);
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
