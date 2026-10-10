package ts.vfs.vfsmock;

import go.Errors.Error;
import go.Time;
import go.Tuple.ValueOk;
import ts.vfs.Vfs;

// Port of mock_generated.go (moq output for vfs.FS), written by hand from the same template.
// PORT: Go's per-method anonymous call structs → one class per method (FSMock<Name>Call);
// the sync.RWMutex locks are dropped (single-threaded port).

class FSMockAppendFileCall {
	public final Path:String;
	public final Data:String;

	public function new(path:String, data:String) {
		this.Path = path;
		this.Data = data;
	}
}

class FSMockChtimesCall {
	public final Path:String;
	public final ATime:Time;
	public final MTime:Time;

	public function new(path:String, aTime:Time, mTime:Time) {
		this.Path = path;
		this.ATime = aTime;
		this.MTime = mTime;
	}
}

class FSMockDirectoryExistsCall {
	public final Path:String;

	public function new(path:String) {
		this.Path = path;
	}
}

class FSMockFileExistsCall {
	public final Path:String;

	public function new(path:String) {
		this.Path = path;
	}
}

class FSMockGetAccessibleEntriesCall {
	public final Path:String;

	public function new(path:String) {
		this.Path = path;
	}
}

class FSMockReadFileCall {
	public final Path:String;

	public function new(path:String) {
		this.Path = path;
	}
}

class FSMockRealpathCall {
	public final Path:String;

	public function new(path:String) {
		this.Path = path;
	}
}

class FSMockRemoveCall {
	public final Path:String;

	public function new(path:String) {
		this.Path = path;
	}
}

class FSMockStatCall {
	public final Path:String;

	public function new(path:String) {
		this.Path = path;
	}
}

class FSMockUseCaseSensitiveFileNamesCall {

	public function new() {
	}
}

class FSMockWalkDirCall {
	public final Root:String;
	public final WalkFn:WalkDirFunc;

	public function new(root:String, walkFn:WalkDirFunc) {
		this.Root = root;
		this.WalkFn = walkFn;
	}
}

class FSMockWriteFileCall {
	public final Path:String;
	public final Data:String;

	public function new(path:String, data:String) {
		this.Path = path;
		this.Data = data;
	}
}

// FSMock is a mock implementation of vfs.FS.
class FSMock implements FS {
	// AppendFileFunc mocks the AppendFile method.
	public var AppendFileFunc:Null<(String, String) -> Null<Error>> = null;

	// ChtimesFunc mocks the Chtimes method.
	public var ChtimesFunc:Null<(String, Time, Time) -> Null<Error>> = null;

	// DirectoryExistsFunc mocks the DirectoryExists method.
	public var DirectoryExistsFunc:Null<(String) -> Bool> = null;

	// FileExistsFunc mocks the FileExists method.
	public var FileExistsFunc:Null<(String) -> Bool> = null;

	// GetAccessibleEntriesFunc mocks the GetAccessibleEntries method.
	public var GetAccessibleEntriesFunc:Null<(String) -> Entries> = null;

	// ReadFileFunc mocks the ReadFile method.
	public var ReadFileFunc:Null<(String) -> ValueOk<String>> = null;

	// RealpathFunc mocks the Realpath method.
	public var RealpathFunc:Null<(String) -> String> = null;

	// RemoveFunc mocks the Remove method.
	public var RemoveFunc:Null<(String) -> Null<Error>> = null;

	// StatFunc mocks the Stat method.
	public var StatFunc:Null<(String) -> Null<FileInfo>> = null;

	// UseCaseSensitiveFileNamesFunc mocks the UseCaseSensitiveFileNames method.
	public var UseCaseSensitiveFileNamesFunc:Null<() -> Bool> = null;

	// WalkDirFunc mocks the WalkDir method.
	public var WalkDirFunc:Null<(String, WalkDirFunc) -> Null<Error>> = null;

	// WriteFileFunc mocks the WriteFile method.
	public var WriteFileFunc:Null<(String, String) -> Null<Error>> = null;

	// calls tracks calls to the methods.
	final callsAppendFile:Array<FSMockAppendFileCall> = [];
	final callsChtimes:Array<FSMockChtimesCall> = [];
	final callsDirectoryExists:Array<FSMockDirectoryExistsCall> = [];
	final callsFileExists:Array<FSMockFileExistsCall> = [];
	final callsGetAccessibleEntries:Array<FSMockGetAccessibleEntriesCall> = [];
	final callsReadFile:Array<FSMockReadFileCall> = [];
	final callsRealpath:Array<FSMockRealpathCall> = [];
	final callsRemove:Array<FSMockRemoveCall> = [];
	final callsStat:Array<FSMockStatCall> = [];
	final callsUseCaseSensitiveFileNames:Array<FSMockUseCaseSensitiveFileNamesCall> = [];
	final callsWalkDir:Array<FSMockWalkDirCall> = [];
	final callsWriteFile:Array<FSMockWriteFileCall> = [];

	public function new() {}

	// AppendFile calls AppendFileFunc.
	public function AppendFile(path:String, data:String):Null<Error> {
		if (this.AppendFileFunc == null) {
			throw "FSMock.AppendFileFunc: method is nil but FS.AppendFile was just called";
		}
		final callInfo = new FSMockAppendFileCall(path, data);
		this.callsAppendFile.push(callInfo);
		return this.AppendFileFunc(path, data);
	}

	// AppendFileCalls gets all the calls that were made to AppendFile.
	public function AppendFileCalls():Array<FSMockAppendFileCall> {
		return this.callsAppendFile.copy();
	}

	// Chtimes calls ChtimesFunc.
	public function Chtimes(path:String, aTime:Time, mTime:Time):Null<Error> {
		if (this.ChtimesFunc == null) {
			throw "FSMock.ChtimesFunc: method is nil but FS.Chtimes was just called";
		}
		final callInfo = new FSMockChtimesCall(path, aTime, mTime);
		this.callsChtimes.push(callInfo);
		return this.ChtimesFunc(path, aTime, mTime);
	}

	// ChtimesCalls gets all the calls that were made to Chtimes.
	public function ChtimesCalls():Array<FSMockChtimesCall> {
		return this.callsChtimes.copy();
	}

	// DirectoryExists calls DirectoryExistsFunc.
	public function DirectoryExists(path:String):Bool {
		if (this.DirectoryExistsFunc == null) {
			throw "FSMock.DirectoryExistsFunc: method is nil but FS.DirectoryExists was just called";
		}
		final callInfo = new FSMockDirectoryExistsCall(path);
		this.callsDirectoryExists.push(callInfo);
		return this.DirectoryExistsFunc(path);
	}

	// DirectoryExistsCalls gets all the calls that were made to DirectoryExists.
	public function DirectoryExistsCalls():Array<FSMockDirectoryExistsCall> {
		return this.callsDirectoryExists.copy();
	}

	// FileExists calls FileExistsFunc.
	public function FileExists(path:String):Bool {
		if (this.FileExistsFunc == null) {
			throw "FSMock.FileExistsFunc: method is nil but FS.FileExists was just called";
		}
		final callInfo = new FSMockFileExistsCall(path);
		this.callsFileExists.push(callInfo);
		return this.FileExistsFunc(path);
	}

	// FileExistsCalls gets all the calls that were made to FileExists.
	public function FileExistsCalls():Array<FSMockFileExistsCall> {
		return this.callsFileExists.copy();
	}

	// GetAccessibleEntries calls GetAccessibleEntriesFunc.
	public function GetAccessibleEntries(path:String):Entries {
		if (this.GetAccessibleEntriesFunc == null) {
			throw "FSMock.GetAccessibleEntriesFunc: method is nil but FS.GetAccessibleEntries was just called";
		}
		final callInfo = new FSMockGetAccessibleEntriesCall(path);
		this.callsGetAccessibleEntries.push(callInfo);
		return this.GetAccessibleEntriesFunc(path);
	}

	// GetAccessibleEntriesCalls gets all the calls that were made to GetAccessibleEntries.
	public function GetAccessibleEntriesCalls():Array<FSMockGetAccessibleEntriesCall> {
		return this.callsGetAccessibleEntries.copy();
	}

	// ReadFile calls ReadFileFunc.
	public function ReadFile(path:String):ValueOk<String> {
		if (this.ReadFileFunc == null) {
			throw "FSMock.ReadFileFunc: method is nil but FS.ReadFile was just called";
		}
		final callInfo = new FSMockReadFileCall(path);
		this.callsReadFile.push(callInfo);
		return this.ReadFileFunc(path);
	}

	// ReadFileCalls gets all the calls that were made to ReadFile.
	public function ReadFileCalls():Array<FSMockReadFileCall> {
		return this.callsReadFile.copy();
	}

	// Realpath calls RealpathFunc.
	public function Realpath(path:String):String {
		if (this.RealpathFunc == null) {
			throw "FSMock.RealpathFunc: method is nil but FS.Realpath was just called";
		}
		final callInfo = new FSMockRealpathCall(path);
		this.callsRealpath.push(callInfo);
		return this.RealpathFunc(path);
	}

	// RealpathCalls gets all the calls that were made to Realpath.
	public function RealpathCalls():Array<FSMockRealpathCall> {
		return this.callsRealpath.copy();
	}

	// Remove calls RemoveFunc.
	public function Remove(path:String):Null<Error> {
		if (this.RemoveFunc == null) {
			throw "FSMock.RemoveFunc: method is nil but FS.Remove was just called";
		}
		final callInfo = new FSMockRemoveCall(path);
		this.callsRemove.push(callInfo);
		return this.RemoveFunc(path);
	}

	// RemoveCalls gets all the calls that were made to Remove.
	public function RemoveCalls():Array<FSMockRemoveCall> {
		return this.callsRemove.copy();
	}

	// Stat calls StatFunc.
	public function Stat(path:String):Null<FileInfo> {
		if (this.StatFunc == null) {
			throw "FSMock.StatFunc: method is nil but FS.Stat was just called";
		}
		final callInfo = new FSMockStatCall(path);
		this.callsStat.push(callInfo);
		return this.StatFunc(path);
	}

	// StatCalls gets all the calls that were made to Stat.
	public function StatCalls():Array<FSMockStatCall> {
		return this.callsStat.copy();
	}

	// UseCaseSensitiveFileNames calls UseCaseSensitiveFileNamesFunc.
	public function UseCaseSensitiveFileNames():Bool {
		if (this.UseCaseSensitiveFileNamesFunc == null) {
			throw "FSMock.UseCaseSensitiveFileNamesFunc: method is nil but FS.UseCaseSensitiveFileNames was just called";
		}
		final callInfo = new FSMockUseCaseSensitiveFileNamesCall();
		this.callsUseCaseSensitiveFileNames.push(callInfo);
		return this.UseCaseSensitiveFileNamesFunc();
	}

	// UseCaseSensitiveFileNamesCalls gets all the calls that were made to UseCaseSensitiveFileNames.
	public function UseCaseSensitiveFileNamesCalls():Array<FSMockUseCaseSensitiveFileNamesCall> {
		return this.callsUseCaseSensitiveFileNames.copy();
	}

	// WalkDir calls WalkDirFunc.
	public function WalkDir(root:String, walkFn:WalkDirFunc):Null<Error> {
		if (this.WalkDirFunc == null) {
			throw "FSMock.WalkDirFunc: method is nil but FS.WalkDir was just called";
		}
		final callInfo = new FSMockWalkDirCall(root, walkFn);
		this.callsWalkDir.push(callInfo);
		return this.WalkDirFunc(root, walkFn);
	}

	// WalkDirCalls gets all the calls that were made to WalkDir.
	public function WalkDirCalls():Array<FSMockWalkDirCall> {
		return this.callsWalkDir.copy();
	}

	// WriteFile calls WriteFileFunc.
	public function WriteFile(path:String, data:String):Null<Error> {
		if (this.WriteFileFunc == null) {
			throw "FSMock.WriteFileFunc: method is nil but FS.WriteFile was just called";
		}
		final callInfo = new FSMockWriteFileCall(path, data);
		this.callsWriteFile.push(callInfo);
		return this.WriteFileFunc(path, data);
	}

	// WriteFileCalls gets all the calls that were made to WriteFile.
	public function WriteFileCalls():Array<FSMockWriteFileCall> {
		return this.callsWriteFile.copy();
	}

}
