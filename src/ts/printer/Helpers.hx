package ts.printer;

// Port of helpers.go (types; compareEmitHelpers and the helper vars are statics in class Printer).

class Priority {
	public var Value:Int = 0;

	public function new(Value:Int = 0) {
		this.Value = Value;
	}
}

class EmitHelper {
	public var Name:std.String = ""; // A unique name for this helper.
	public var Scoped:Bool = false; // Indicates whether the helper MUST be emitted in the current scope.
	public var Text:std.String = ""; // ES3-compatible raw script text
	public var TextCallback:(makeUniqueName:(std.String) -> std.String) -> std.String = null; // A function yielding an ES3-compatible raw script text.
	public var Priority:Priority = null; // Helpers with a higher priority are emitted earlier than other helpers on the node.
	public var Dependencies:Array<EmitHelper> = null; // Emit helpers this helper depends on
	public var ImportName:std.String = ""; // The name of the helper to use when importing via `--importHelpers`.

	public function new() {}
}
