package ts.vfs.vfsmock;

import ts.vfs.vfsmock.MockGenerated;
import ts.vfs.vfsmock.Vfsmock;
import ts.vfs.vfstest.Vfstest;

// Port of wrapper_test.go.
// PORT: Go reflects over the exported fields of FSMock; Haxe uses Reflect over the *Func fields.
class VfsmockTest {
	public static function run() {
		T.run("TestWrap", () -> {
			final wrapper = Vfsmock.Wrap(Vfstest.FromMap(new Map<String, String>(), true));

			final names = ["AppendFileFunc", "ChtimesFunc", "DirectoryExistsFunc", "FileExistsFunc", "GetAccessibleEntriesFunc", "ReadFileFunc",
				"RealpathFunc", "RemoveFunc", "StatFunc", "UseCaseSensitiveFileNamesFunc", "WalkDirFunc", "WriteFileFunc"];
			for (name in names) {
				final fieldValue = Reflect.getProperty(wrapper, name);
				T.isTrue(fieldValue != null, 'field $name should not be zero; update Wrap');
			}
		});
	}
}
