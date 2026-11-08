package ts.execute.incremental;

// Port of host.go (types). Package-level funcs (CreateHost, GetMTime) are in Incremental.hx.

interface Host {
	function GetMTime(fileName:RootedFilePath):Time;
	function SetMTime(fileName:RootedFilePath, mTime:Time):Null<Error>;
}

// Go type `host` (renamed: the exported interface is Host).
@:allow(ts.execute.incremental)
class Host_ implements Host {
	var host:CompilerHost = null;

	public function new(host:CompilerHost) {
		this.host = host;
	}

	public function GetMTime(fileName:RootedFilePath):Time {
		return Incremental.GetMTime(this.host, fileName);
	}

	public function SetMTime(fileName:RootedFilePath, mTime:Time):Null<Error> {
		return this.host.FS().Chtimes(fileName.AsPath(), Time.Zero(), mTime);
	}
}
