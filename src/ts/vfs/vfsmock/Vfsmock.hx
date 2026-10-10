package ts.vfs.vfsmock;

import ts.vfs.Vfs;
import ts.vfs.vfsmock.MockGenerated;

// Port of wrapper.go.
class Vfsmock {
	// Wrap wraps a vfs.FS and returns a FSMock which calls it.
	public static function Wrap(fs:FS):FSMock {
		final m = new FSMock();
		m.DirectoryExistsFunc = fs.DirectoryExists;
		m.FileExistsFunc = fs.FileExists;
		m.GetAccessibleEntriesFunc = fs.GetAccessibleEntries;
		m.ReadFileFunc = fs.ReadFile;
		m.RealpathFunc = fs.Realpath;
		m.RemoveFunc = fs.Remove;
		m.ChtimesFunc = fs.Chtimes;
		m.StatFunc = fs.Stat;
		m.UseCaseSensitiveFileNamesFunc = fs.UseCaseSensitiveFileNames;
		m.WalkDirFunc = fs.WalkDir;
		m.WriteFileFunc = fs.WriteFile;
		m.AppendFileFunc = fs.AppendFile;
		return m;
	}
}
