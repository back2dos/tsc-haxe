package ts.repo;

// Port of internal/repo (test helper): paths of the upstream checkout.
// PORT: Go finds the root from runtime.Caller (the go.mod directory = upstream/tsc). Here the root is
// <project>/upstream/tsc, with <project> the current directory unless set with SetProjectRoot.
class Repo {
	static var rootPath_:Null<String> = null;

	public static function SetProjectRoot(projectRoot:String):Void {
		rootPath_ = ts.tspath.Tspath.NormalizePath(projectRoot + "/upstream/tsc");
	}

	public static function RootPath():String {
		if (rootPath_ == null) {
			SetProjectRoot(ts.tspath.Tspath.NormalizeSlashes(Sys.getCwd()));
		}
		return rootPath_;
	}

	public static function TypeScriptSubmodulePath():String {
		return RootPath() + "/_submodules/TypeScript";
	}

	public static function TestDataPath():String {
		return RootPath() + "/testdata";
	}
}
