package ts.semver;

// Port of internal/semver/version_range.go (types and methods).
@:allow(ts.semver)
class VersionRange {
	var alternatives:Array<Array<VersionComparator>> = null;

	public function new() {}

	public function String():String {
		final sb = new StringBuf();
		Semver.formatDisjunction(sb, alternatives);
		return sb.toString();
	}

	public function Test(version:Version):Bool {
		return Semver.testDisjunction(alternatives, version);
	}
}

// PORT: Go type versionComparator; Haxe type names must start upper case.
// Immutable after construction; no copy needed.
@:allow(ts.semver)
class VersionComparator {
	final operator_:ComparatorOperator;
	final operand:Version;

	public function new(operator_:ComparatorOperator, operand:Version) {
		this.operator_ = operator_;
		this.operand = operand;
	}
}

// PORT: Go type comparatorOperator; Haxe type names must start upper case.
enum abstract ComparatorOperator(String) from String to String {
	var rangeLessThan = "<";
	var rangeLessThanEqual = "<=";
	var rangeEqual = "=";
	var rangeGreaterThanEqual = ">=";
	var rangeGreaterThan = ">";
}

// PORT: Go type partialVersion; Haxe type names must start upper case.
@:allow(ts.semver)
class PartialVersion {
	var version:Version = new Version(); // Go zero value of a struct field is a zero struct
	var majorStr:String = "";
	var minorStr:String = "";
	var patchStr:String = "";

	public function new() {}
}
