package ts.core;

// Port of typeacquisition.go.
class TypeAcquisition {
	public var Enable:Tristate = TSUnknown; // json:"enable,omitzero"
	public var Include:Null<Array<String>> = null; // json:"include,omitzero"
	public var Exclude:Null<Array<String>> = null; // json:"exclude,omitzero"
	public var DisableFilenameBasedTypeAcquisition:Tristate = TSUnknown; // json:"disableFilenameBasedTypeAcquisition,omitzero"

	public function new() {}

	// PORT: nil receiver — `inline` with a `this == null` check like the Go `ta == nil` check
	// (see src/ts/collections/Set.hx). Call it directly, not as a closure.
	public inline function Equals(other:Null<TypeAcquisition>):Bool {
		return this == other ? true : (this == null || other == null ? false : equals(other));
	}

	function equals(other:TypeAcquisition):Bool {
		return (this.Enable == other.Enable
			&& Slices.Equal(this.Include, other.Include)
			&& Slices.Equal(this.Exclude, other.Exclude)
			&& this.DisableFilenameBasedTypeAcquisition == other.DisableFilenameBasedTypeAcquisition);
	}
}
