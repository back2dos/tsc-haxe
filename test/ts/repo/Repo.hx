package ts.repo;

// Port of internal/repo (test helper): paths of the upstream checkout.
// PORT: Go finds the root from runtime.Caller (the go.mod directory = upstream/tsc). Here the root is
// <project>/upstream/tsc, with <project> the current directory unless set with SetProjectRoot.
class Repo {
	static var rootPath_:Null<String> = null;

	// PORT: the checkout is upstream/ (tsgo 7.0.2), or another one named by TSHX_UPSTREAM (the checker gate's oracle:
	// upstream-main/, TypeScript main, see tools/gate/checker.sh)
	public static function SetProjectRoot(projectRoot:String):Void {
		final dir = Sys.getEnv("TSHX_UPSTREAM");
		rootPath_ = ts.tspath.Tspath.NormalizePath(projectRoot + "/" + (dir == null || dir == "" ? "upstream" : dir) + "/tsc");
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
