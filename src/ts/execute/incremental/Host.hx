package ts.execute.incremental;

// Port of host.go (types). Package-level funcs (CreateHost, GetMTime) are in Incremental.hx.

interface Host {
	function FS():FS;
	function GetMTime(fileName:std.String):Time;
	function SetMTime(fileName:std.String, mTime:Time):Null<Error>;
}

// Go type `host` (renamed: the exported interface is Host).
@:allow(ts.execute.incremental)
class Host_ implements Host {
	var host:CompilerHost = null;

	public function new(host:CompilerHost) {
		this.host = host;
	}

	public function FS():FS {
		return this.host.FS();
	}

	public function GetMTime(fileName:std.String):Time {
		return Incremental.GetMTime(this.host, fileName);
	}

	public function SetMTime(fileName:std.String, mTime:Time):Null<Error> {
		return this.host.FS().Chtimes(fileName, Time.Zero(), mTime);
	}
}
