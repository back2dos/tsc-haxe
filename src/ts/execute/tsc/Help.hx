package ts.execute.tsc;

// Port of help.go (types; package-level funcs are in Tsc.hx).

// Go type `valueCandidate` (unexported).
class ValueCandidate {
	// "one or more" or "any of"
	public var valueType:std.String = "";
	public var possibleValues:std.String = "";

	public function new() {}
}
