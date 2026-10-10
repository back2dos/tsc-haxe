package ts.semver;

// Port of internal/semver/version.go (types and methods).
// PORT: Go uint32 fields are Int holding the uint32 bit pattern; compared and printed unsigned.
@:allow(ts.semver)
class Version {
	var major:Int = 0;
	var minor:Int = 0;
	var patch:Int = 0;
	var prerelease:Array<String> = null;
	var build:Array<String> = null;

	public function new() {}

	// Go struct value copy.
	function copy():Version {
		final v = new Version();
		v.major = major;
		v.minor = minor;
		v.patch = patch;
		v.prerelease = prerelease;
		v.build = build;
		return v;
	}

	function incrementMajor():Version {
		final v = new Version();
		v.major = (this.major + 1) | 0; // PORT: uint32 wraparound
		return v;
	}

	function incrementMinor():Version {
		final v = new Version();
		v.major = this.major;
		v.minor = (this.minor + 1) | 0; // PORT: uint32 wraparound
		return v;
	}

	function incrementPatch():Version {
		final v = new Version();
		v.major = this.major;
		v.minor = this.minor;
		v.patch = (this.patch + 1) | 0; // PORT: uint32 wraparound
		return v;
	}

	public function Compare(b:Version):Int {
		final a = this;
		// https://semver.org/#spec-item-11
		// > Precedence is determined by the first difference when comparing each of these
		// > identifiers from left to right as follows: Major, minor, and patch versions are
		// > always compared numerically.
		//
		// https://semver.org/#spec-item-11
		// > Precedence for two pre-release versions with the same major, minor, and patch version
		// > MUST be determined by comparing each dot separated identifier from left to right until
		// > a difference is found [...]
		//
		// https://semver.org/#spec-item-11
		// > Build metadata does not figure into precedence
		if (a == b)
			return Semver.comparisonEqualTo;
		else if (a == null)
			return Semver.comparisonLessThan;
		else if (b == null)
			return Semver.comparisonGreaterThan;

		var r = Semver.compareUint32(a.major, b.major);
		if (r != 0)
			return r;

		r = Semver.compareUint32(a.minor, b.minor);
		if (r != 0)
			return r;

		r = Semver.compareUint32(a.patch, b.patch);
		if (r != 0)
			return r;

		return Semver.comparePreReleaseIdentifiers(a.prerelease, b.prerelease);
	}

	public function String():String {
		final sb = new StringBuf();
		sb.add(Semver.formatUint32(major) + "." + Semver.formatUint32(minor) + "." + Semver.formatUint32(patch));
		if (prerelease != null && prerelease.length > 0)
			sb.add("-" + prerelease.join("."));
		if (build != null && build.length > 0)
			sb.add("+" + build.join("."));
		return sb.toString();
	}
}

class SemverParseError implements Error {
	var origInput:String = "";

	public function new(origInput:String) {
		this.origInput = origInput;
	}

	public function Error():String {
		return "Could not parse version string from " + Strconv.Quote(origInput);
	}

	public function toString():String {
		return Error();
	}
}
