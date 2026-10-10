package ts.core;

// Port of projectreference.go (types; the funcs are in Core.hx).
class ProjectReference {
	public var Path:String = "";
	public var OriginalPath:String = "";
	public var Circular:Bool = false;

	public function new() {}
}
