package ts.semver;

import haxe.Int64;

// Port of internal/semver.
//
// PORT: regexp. Go RE2 patterns are rewritten for EReg so that JS and hxcpp (PCRE2, Unicode
// aware) behave like Go (see go.Regexp): `\d` → `[0-9]`, `\s` → `[\t\n\f\r ]`, `$` → `(?![\s\S])`,
// and `(?i)` is spelled out. Go `(?i)[a-z]` also matches U+017F (ſ) and U+212A (Kelvin sign),
// so letter classes are `[a-zA-ZſK]`.
@:allow(ts.semver)
class Semver {
	// --- version.go ---

	// https://semver.org/#spec-item-2
	// > A normal version number MUST take the form X.Y.Z where X, Y, and Z are non-negative
	// > integers, and MUST NOT contain leading zeroes. X is the major version, Y is the minor
	// > version, and Z is the patch version. Each element MUST increase numerically.
	//
	// NOTE: We differ here in that we allow X and X.Y, with missing parts having the default
	// value of `0`.
	// Go: (?i)^(0|[1-9]\d*)(?:\.(0|[1-9]\d*)(?:\.(0|[1-9]\d*)(?:-([a-z0-9-.]+))?(?:\+([a-z0-9-.]+))?)?)?$
	static final versionRegexp = Regexp.MustCompile("^(0|[1-9][0-9]*)(?:\\.(0|[1-9][0-9]*)(?:\\.(0|[1-9][0-9]*)(?:-([a-zA-ZſK0-9\\-.]+))?(?:\\+([a-zA-ZſK0-9\\-.]+))?)?)?(?![\\s\\S])");

	// https://semver.org/#spec-item-9
	// > A pre-release version MAY be denoted by appending a hyphen and a series of dot separated
	// > identifiers immediately following the patch version. Identifiers MUST comprise only ASCII
	// > alphanumerics and hyphen [0-9A-Za-z-]. Identifiers MUST NOT be empty. Numeric identifiers
	// > MUST NOT include leading zeroes.
	// Go: (?i)^(?:0|[1-9]\d*|[a-z-][a-z0-9-]*)(?:\.(?:0|[1-9]\d*|[a-zA-Z-][a-zA-Z0-9-]*))*$
	static final prereleaseRegexp = Regexp.MustCompile("^(?:0|[1-9][0-9]*|[a-zA-ZſK\\-][a-zA-ZſK0-9\\-]*)(?:\\.(?:0|[1-9][0-9]*|[a-zA-ZſK\\-][a-zA-ZſK0-9\\-]*))*(?![\\s\\S])");
	// Go: (?i)^(?:0|[1-9]\d*|[a-z-][a-z0-9-]*)$
	static final prereleasePartRegexp = Regexp.MustCompile("^(?:0|[1-9][0-9]*|[a-zA-ZſK\\-][a-zA-ZſK0-9\\-]*)(?![\\s\\S])");

	// https://semver.org/#spec-item-10
	// > Build metadata MAY be denoted by appending a plus sign and a series of dot separated
	// > identifiers immediately following the patch or pre-release version. Identifiers MUST
	// > comprise only ASCII alphanumerics and hyphen [0-9A-Za-z-]. Identifiers MUST NOT be empty.
	// Go: (?i)^[a-z0-9-]+(?:\.[a-z0-9-]+)*$
	static final buildRegExp = Regexp.MustCompile("^[a-zA-ZſK0-9\\-]+(?:\\.[a-zA-ZſK0-9\\-]+)*(?![\\s\\S])");
	// Go: (?i)^[a-z0-9-]+$
	static final buildPartRegExp = Regexp.MustCompile("^[a-zA-ZſK0-9\\-]+(?![\\s\\S])");

	// https://semver.org/#spec-item-9
	// > Numeric identifiers MUST NOT include leading zeroes.
	// Go: ^(?:0|[1-9]\d*)$
	static final numericIdentifierRegExp = Regexp.MustCompile("^(?:0|[1-9][0-9]*)(?![\\s\\S])");

	static final versionZero:Version = {
		final v = new Version();
		v.prerelease = ["0"];
		v;
	};

	static inline final comparisonLessThan = -1;
	static inline final comparisonEqualTo = 0;
	static inline final comparisonGreaterThan = 1;

	// PORT: uint32. cmp.Compare on uint32 values stored as Int bit patterns.
	static function compareUint32(a:Int, b:Int):Int {
		final x = a ^ 0x80000000;
		final y = b ^ 0x80000000;
		return x < y ? -1 : (x > y ? 1 : 0);
	}

	// PORT: uint32. fmt "%d" of a uint32 stored as an Int bit pattern.
	static function formatUint32(a:Int):String {
		return a >= 0 ? Std.string(a) : Int64.toStr(Int64.make(0, a));
	}

	static function comparePreReleaseIdentifiers(left:Array<String>, right:Array<String>):Int {
		// https://semver.org/#spec-item-11
		// > When major, minor, and patch are equal, a pre-release version has lower precedence
		// > than a normal version.
		if (left == null || left.length == 0) {
			if (right == null || right.length == 0)
				return comparisonEqualTo;
			return comparisonGreaterThan;
		} else if (right == null || right.length == 0) {
			return comparisonLessThan;
		}

		// https://semver.org/#spec-item-11
		// > Precedence for two pre-release versions with the same major, minor, and patch version
		// > MUST be determined by comparing each dot separated identifier from left to right until
		// > a difference is found [...]
		return Slices.CompareFunc(left, right, comparePreReleaseIdentifier);
	}

	static function comparePreReleaseIdentifier(left:String, right:String):Int {
		// https://semver.org/#spec-item-11
		// > Precedence for two pre-release versions with the same major, minor, and patch version
		// > MUST be determined by comparing each dot separated identifier from left to right until
		// > a difference is found [...]
		final compareResult = Strings.Compare(left, right);
		if (compareResult == 0)
			return compareResult;

		final leftIsNumeric = numericIdentifierRegExp.MatchString(left);
		final rightIsNumeric = numericIdentifierRegExp.MatchString(right);

		if (leftIsNumeric || rightIsNumeric) {
			// https://semver.org/#spec-item-11
			// > Numeric identifiers always have lower precedence than non-numeric identifiers.
			if (!rightIsNumeric)
				return comparisonLessThan;
			if (!leftIsNumeric)
				return comparisonGreaterThan;

			// https://semver.org/#spec-item-11
			// > identifiers consisting of only digits are compared numerically
			final leftAsNumber = getUintComponent(left);
			final rightAsNumber = getUintComponent(right);
			if (leftAsNumber.err != null || rightAsNumber.err != null) {
				// This should only happen in the event of an overflow.
				// If so, use the lengths or fall back to string comparison.
				final leftLen = left.length;
				final rightLen = right.length;
				final lenCompare = Cmp.Compare(leftLen, rightLen);
				if (lenCompare == 0)
					return compareResult;
				else
					return lenCompare;
			}
			return compareUint32(leftAsNumber.value, rightAsNumber.value);
		}

		// https://semver.org/#spec-item-11
		// > identifiers with letters or hyphens are compared lexically in ASCII sort order.
		return compareResult;
	}

	public static function TryParseVersion(text:String):ValueError<Version> {
		final result = new Version();

		final match = versionRegexp.FindStringSubmatch(text);
		if (match == null)
			return new ValueError(result, new SemverParseError(text));

		final majorStr = match[1];
		final minorStr = match[2];
		final patchStr = match[3];
		final prereleaseStr = match[4];
		final buildStr = match[5];

		var u = getUintComponent(majorStr);
		result.major = u.value;
		if (u.err != null)
			return new ValueError(result, u.err);

		if (minorStr != "") {
			u = getUintComponent(minorStr);
			result.minor = u.value;
			if (u.err != null)
				return new ValueError(result, u.err);
		}

		if (patchStr != "") {
			u = getUintComponent(patchStr);
			result.patch = u.value;
			if (u.err != null)
				return new ValueError(result, u.err);
		}

		if (prereleaseStr != "") {
			if (!prereleaseRegexp.MatchString(prereleaseStr))
				return new ValueError(result, new SemverParseError(text));

			result.prerelease = prereleaseStr.split(".");
		}
		if (buildStr != "") {
			if (!buildRegExp.MatchString(buildStr))
				return new ValueError(result, new SemverParseError(text));

			result.build = buildStr.split(".");
		}

		return new ValueError(result, null);
	}

	public static function MustParse(text:String):Version {
		final r = TryParseVersion(text);
		if (r.err != null)
			throw r.err;
		return r.value;
	}

	static function getUintComponent(text:String):ValueError<Int> {
		final r = Strconv.ParseUint(text, 10, 32);
		return new ValueError(r.value.low, r.err);
	}

	// --- version_range.go ---

	// https://github.com/npm/node-semver#range-grammar
	//
	// range-set    ::= range ( logical-or range ) *
	// range        ::= hyphen | simple ( ' ' simple ) * | ”
	// logical-or   ::= ( ' ' ) * '||' ( ' ' ) *
	static final logicalOrRegExp = Regexp.MustCompile("\\|\\|");
	// Go: \s+
	static final whitespaceRegExp = Regexp.MustCompile("[\\t\\n\\f\\r ]+");

	// https://github.com/npm/node-semver#range-grammar
	//
	// partial      ::= xr ( '.' xr ( '.' xr qualifier ? )? )?
	// xr           ::= 'x' | 'X' | '*' | nr
	// nr           ::= '0' | ['1'-'9'] ( ['0'-'9'] ) *
	// qualifier    ::= ( '-' pre )? ( '+' build )?
	// pre          ::= parts
	// build        ::= parts
	// parts        ::= part ( '.' part ) *
	// part         ::= nr | [-0-9A-Za-z]+
	// Go: (?i)^([x*0]|[1-9]\d*)(?:\.([x*0]|[1-9]\d*)(?:\.([x*0]|[1-9]\d*)(?:-([a-z0-9-.]+))?(?:\+([a-z0-9-.]+))?)?)?$
	static final partialRegExp = Regexp.MustCompile("^([xX*0]|[1-9][0-9]*)(?:\\.([xX*0]|[1-9][0-9]*)(?:\\.([xX*0]|[1-9][0-9]*)(?:-([a-zA-ZſK0-9\\-.]+))?(?:\\+([a-zA-ZſK0-9\\-.]+))?)?)?(?![\\s\\S])");

	// https://github.com/npm/node-semver#range-grammar
	//
	// hyphen       ::= partial ' - ' partial
	// Go: (?i)^\s*([a-z0-9-+.*]+)\s+-\s+([a-z0-9-+.*]+)\s*$
	static final hyphenRegExp = Regexp.MustCompile("^[\\t\\n\\f\\r ]*([a-zA-ZſK0-9\\-+.*]+)[\\t\\n\\f\\r ]+-[\\t\\n\\f\\r ]+([a-zA-ZſK0-9\\-+.*]+)[\\t\\n\\f\\r ]*(?![\\s\\S])");

	// https://github.com/npm/node-semver#range-grammar
	//
	// simple       ::= primitive | partial | tilde | caret
	// primitive    ::= ( '<' | '>' | '>=' | '<=' | '=' ) partial
	// tilde        ::= '~' partial
	// caret        ::= '^' partial
	// Go: (?i)^([~^<>=]|<=|>=)?\s*([a-z0-9-+.*]+)$
	static final rangeRegExp = Regexp.MustCompile("^([~\\^<>=]|<=|>=)?[\\t\\n\\f\\r ]*([a-zA-ZſK0-9\\-+.*]+)(?![\\s\\S])");

	static function formatDisjunction(sb:StringBuf, alternatives:Array<Array<VersionComparator>>):Void {
		final origLen = sb.length;

		if (alternatives != null) {
			for (i in 0...alternatives.length) {
				final alternative = alternatives[i];
				if (i > 0)
					sb.add(" || ");
				formatAlternative(sb, alternative);
			}
		}

		if (sb.length == origLen)
			sb.add("*");
	}

	static function formatAlternative(sb:StringBuf, comparators:Array<VersionComparator>):Void {
		if (comparators != null) {
			for (i in 0...comparators.length) {
				final comparator = comparators[i];
				if (i > 0)
					sb.addChar(' '.code);
				formatComparator(sb, comparator);
			}
		}
	}

	static function formatComparator(sb:StringBuf, comparator:VersionComparator):Void {
		sb.add((comparator.operator_ : String));
		sb.add(comparator.operand.String());
	}

	static function testDisjunction(alternatives:Array<Array<VersionComparator>>, version:Version):Bool {
		// an empty disjunction is treated as "*" (all versions)
		if (alternatives == null || alternatives.length == 0)
			return true;

		for (alternative in alternatives) {
			if (testAlternative(alternative, version))
				return true;
		}

		return false;
	}

	static function testAlternative(alternative:Array<VersionComparator>, version:Version):Bool {
		if (alternative != null) {
			for (comparator in alternative) {
				if (!testComparator(comparator, version))
					return false;
			}
		}
		return true;
	}

	static function testComparator(comparator:VersionComparator, version:Version):Bool {
		final cmp = version.Compare(comparator.operand);
		return switch (comparator.operator_) {
			case rangeLessThan:
				cmp < 0;
			case rangeLessThanEqual:
				cmp <= 0;
			case rangeEqual:
				cmp == 0;
			case rangeGreaterThanEqual:
				cmp >= 0;
			case rangeGreaterThan:
				cmp > 0;
			default:
				throw "Unexpected operator: " + comparator.operator_;
		}
	}

	public static function TryParseVersionRange(text:String):ValueOk<VersionRange> {
		final r = parseAlternatives(text);
		final range = new VersionRange();
		range.alternatives = r.value;
		return new ValueOk(range, r.ok);
	}

	static function parseAlternatives(text:String):ValueOk<Array<Array<VersionComparator>>> {
		var alternatives:Array<Array<VersionComparator>> = null;

		text = Strings.TrimSpace(text);
		final ranges = logicalOrRegExp.Split(text, -1);
		for (r0 in ranges) {
			final r = Strings.TrimSpace(r0);
			if (r == "")
				continue;

			var comparators:Array<VersionComparator> = null;

			final hyphenMatch = hyphenRegExp.FindStringSubmatch(r);
			if (hyphenMatch != null) {
				final parsedComparators = parseHyphen(hyphenMatch[1], hyphenMatch[2]);
				if (parsedComparators.ok)
					comparators = appendAll(comparators, parsedComparators.value);
				else
					return new ValueOk(null, false);
			} else {
				for (simple in whitespaceRegExp.Split(r, -1)) {
					final match = rangeRegExp.FindStringSubmatch(Strings.TrimSpace(simple));
					if (match == null)
						return new ValueOk(null, false);

					final parsedComparators = parseComparator(match[1], match[2]);
					if (parsedComparators.ok)
						comparators = appendAll(comparators, parsedComparators.value);
					else
						return new ValueOk(null, false);
				}
			}

			if (alternatives == null)
				alternatives = [];
			alternatives.push(comparators);
		}

		return new ValueOk(alternatives, true);
	}

	// Go `append(dst, src...)`: appending nothing keeps dst (possibly nil).
	static function appendAll<T>(dst:Array<T>, src:Array<T>):Array<T> {
		if (src == null || src.length == 0)
			return dst;
		if (dst == null)
			dst = [];
		for (x in src)
			dst.push(x);
		return dst;
	}

	static function parseHyphen(left:String, right:String):ValueOk<Array<VersionComparator>> {
		final leftResult = parsePartial(left);
		if (!leftResult.ok)
			return new ValueOk(null, false);

		final rightResult = parsePartial(right);
		if (!rightResult.ok)
			return new ValueOk(null, false);

		var comparators:Array<VersionComparator> = null;
		if (!isWildcard(leftResult.value.majorStr)) {
			// `MAJOR.*.*-...` gives us `>=MAJOR.0.0 ...`
			if (comparators == null)
				comparators = [];
			comparators.push(new VersionComparator(rangeGreaterThanEqual, leftResult.value.version));
		}

		if (!isWildcard(rightResult.value.majorStr)) {
			var operator_:ComparatorOperator;
			var operand = rightResult.value.version;

			if (isWildcard(rightResult.value.minorStr)) {
				// `...-MAJOR.*.*` gives us `... <(MAJOR+1).0.0`
				operand = operand.incrementMajor();
				operator_ = rangeLessThan;
			} else if (isWildcard(rightResult.value.patchStr)) {
				// `...-MAJOR.MINOR.*` gives us `... <MAJOR.(MINOR+1).0`
				operand = operand.incrementMinor();
				operator_ = rangeLessThan;
			} else {
				// `...-MAJOR.MINOR.PATCH` gives us `... <=MAJOR.MINOR.PATCH`
				operator_ = rangeLessThanEqual;
			}

			if (comparators == null)
				comparators = [];
			comparators.push(new VersionComparator(operator_, operand));
		}

		return new ValueOk(comparators, true);
	}

	// Produces a "partial" version
	static function parsePartial(text:String):ValueOk<PartialVersion> {
		final match = partialRegExp.FindStringSubmatch(text);
		if (match == null)
			return new ValueOk(new PartialVersion(), false);

		final majorStr = match[1];
		var minorStr = match[2];
		var patchStr = match[3];
		final prereleaseStr = match[4];
		final buildStr = match[5];

		if (minorStr == "")
			minorStr = "*";
		if (patchStr == "")
			patchStr = "*";

		var majorNumeric = 0, minorNumeric = 0, patchNumeric = 0;

		if (isWildcard(majorStr)) {
			majorNumeric = 0;
			minorNumeric = 0;
			patchNumeric = 0;
		} else {
			var u = getUintComponent(majorStr);
			majorNumeric = u.value;
			if (u.err != null)
				return new ValueOk(new PartialVersion(), false);

			if (isWildcard(minorStr)) {
				minorNumeric = 0;
				patchNumeric = 0;
			} else {
				u = getUintComponent(minorStr);
				minorNumeric = u.value;
				if (u.err != null)
					return new ValueOk(new PartialVersion(), false);

				if (isWildcard(patchStr)) {
					patchNumeric = 0;
				} else {
					u = getUintComponent(patchStr);
					patchNumeric = u.value;
					if (u.err != null)
						return new ValueOk(new PartialVersion(), false);
				}
			}
		}

		var prerelease:Array<String> = null;
		if (prereleaseStr != "")
			prerelease = prereleaseStr.split(".");

		var build:Array<String> = null;
		if (buildStr != "")
			build = buildStr.split(".");

		final version = new Version();
		version.major = majorNumeric;
		version.minor = minorNumeric;
		version.patch = patchNumeric;
		version.prerelease = prerelease;
		version.build = build;
		final result = new PartialVersion();
		result.version = version;
		result.majorStr = majorStr;
		result.minorStr = minorStr;
		result.patchStr = patchStr;

		return new ValueOk(result, true);
	}

	static function parseComparator(op:String, text:String):ValueOk<Array<VersionComparator>> {
		var operator_:ComparatorOperator = op;

		final r = parsePartial(text);
		if (!r.ok)
			return new ValueOk(null, false);
		final result = r.value;

		var comparatorsResult:Array<VersionComparator> = null;

		if (!isWildcard(result.majorStr)) {
			switch ((operator_ : String)) {
				case "~":
					final first = new VersionComparator(rangeGreaterThanEqual, result.version);

					var secondVersion:Version;
					if (isWildcard(result.minorStr))
						secondVersion = result.version.incrementMajor();
					else
						secondVersion = result.version.incrementMinor();

					final second = new VersionComparator(rangeLessThan, secondVersion);
					comparatorsResult = [first, second];

				case "^":
					final first = new VersionComparator(rangeGreaterThanEqual, result.version);

					var secondVersion:Version;
					// PORT: uint32 `x > 0` written as `x != 0` (Int holds the uint32 bit pattern).
					if (result.version.major != 0 || isWildcard(result.minorStr))
						secondVersion = result.version.incrementMajor();
					else if (result.version.minor != 0 || isWildcard(result.patchStr))
						secondVersion = result.version.incrementMinor();
					else
						secondVersion = result.version.incrementPatch();
					final second = new VersionComparator(rangeLessThan, secondVersion);
					comparatorsResult = [first, second];

				case "<" | ">=":
					var version = result.version;
					if (isWildcard(result.minorStr) || isWildcard(result.patchStr)) {
						version = version.copy();
						version.prerelease = ["0"];
					}
					comparatorsResult = [new VersionComparator(operator_, version)];

				case "<=" | ">":
					var version = result.version;
					if (isWildcard(result.minorStr)) {
						if (operator_ == rangeLessThanEqual)
							operator_ = rangeLessThan;
						else
							operator_ = rangeGreaterThanEqual;

						version = version.incrementMajor();
						version.prerelease = ["0"];
					} else if (isWildcard(result.patchStr)) {
						if (operator_ == rangeLessThanEqual)
							operator_ = rangeLessThan;
						else
							operator_ = rangeGreaterThanEqual;

						version = version.incrementMinor();
						version.prerelease = ["0"];
					}

					comparatorsResult = [new VersionComparator(operator_, version)];
				case "=" | "":
					// normalize empty string to `=`
					operator_ = rangeEqual;

					if (isWildcard(result.minorStr) || isWildcard(result.patchStr)) {
						final originalVersion = result.version;

						final firstVersion = originalVersion.copy();
						firstVersion.prerelease = ["0"];

						var secondVersion:Version;
						if (isWildcard(result.minorStr))
							secondVersion = originalVersion.incrementMajor();
						else
							secondVersion = originalVersion.incrementMinor();
						secondVersion.prerelease = ["0"];

						comparatorsResult = [
							new VersionComparator(rangeGreaterThanEqual, firstVersion),
							new VersionComparator(rangeLessThan, secondVersion)
						];
					} else {
						comparatorsResult = [new VersionComparator(operator_, result.version)];
					}
				default:
					throw "Unexpected operator: " + operator_;
			}
		} else {
			if (operator_ == "<" || operator_ == ">") {
				comparatorsResult = [
					// < 0.0.0-0
					new VersionComparator(rangeLessThan, versionZero)
				];
			}
		}

		return new ValueOk(comparatorsResult, true);
	}

	static function isWildcard(text:String):Bool {
		return text == "*" || text == "x" || text == "X";
	}
}
