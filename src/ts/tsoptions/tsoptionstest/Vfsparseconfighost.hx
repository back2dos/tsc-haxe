package ts.tsoptions.tsoptionstest;

// Port of vfsparseconfighost.go (type VfsParseConfigHost; the funcs are in Tsoptionstest.hx).
class VfsParseConfigHost implements ParseConfigHost {
	public var Vfs:FS = null;
	public var CurrentDirectory:String = "";

	public function new(Vfs:FS, CurrentDirectory:String) {
		this.Vfs = Vfs;
		this.CurrentDirectory = CurrentDirectory;
	}

	public function FS():FS {
		return this.Vfs;
	}

	public function GetCurrentDirectory():String {
		return this.CurrentDirectory;
	}
}
