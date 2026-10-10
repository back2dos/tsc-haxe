package ts.semver;

import ts.semver.Semver;
import ts.semver.Version;
import ts.semver.VersionRange;

// Port of version_test.go and version_range_test.go.
@:access(ts.semver)
class SemverTest {
	public static function run() {
		// --- version_test.go ---
		T.run("TestTryParseSemver", TestTryParseSemver);
		T.run("TestVersionString", TestVersionString);
		T.run("TestVersionCompare", TestVersionCompare);
		// --- version_range_test.go ---
		T.run("TestWildcardsHaveSameString", TestWildcardsHaveSameString);
		T.run("TestVersionRanges", TestVersionRanges);
		T.run("TestComparatorsOfVersionRanges", TestComparatorsOfVersionRanges);
		T.run("TestConjunctionsOfVersionRanges", TestConjunctionsOfVersionRanges);
		T.run("TestDisjunctionsOfVersionRanges", TestDisjunctionsOfVersionRanges);
		T.run("TestHyphensOfVersionRanges", TestHyphensOfVersionRanges);
		T.run("TestTildesOfVersionRanges", TestTildesOfVersionRanges);
		T.run("TestCaretsOfVersionRanges", TestCaretsOfVersionRanges);
	}

	// Go composite literal Version{major: ..., minor: ..., patch: ..., prerelease: ..., build: ...}.
	static function V(major:Int, minor:Int, patch:Int, ?prerelease:Array<String>, ?build:Array<String>):Version {
		final v = new Version();
		v.major = major;
		v.minor = minor;
		v.patch = patch;
		v.prerelease = prerelease;
		v.build = build;
		return v;
	}

	// --- version_test.go ---

	static function TestTryParseSemver() {
		final tests:Array<{inp:String, out:Version}> = [
			{inp: "1.2.3-pre.4+build.5", out: V(1, 2, 3, ["pre", "4"], ["build", "5"])},
			{inp: "1.2.3-pre.4", out: V(1, 2, 3, ["pre", "4"])},
			{inp: "1.2.3+build.4", out: V(1, 2, 3, null, ["build", "4"])},
			{inp: "1.2.3", out: V(1, 2, 3)},
		];

		for (test in tests) {
			final r = Semver.TryParseVersion(test.inp);
			T.isTrue(r.err == null, test.inp + ": " + (r.err == null ? "" : r.err.Error()));
			assertVersion(r.value, test.out, test.inp);
		}
	}

	static function TestVersionString() {
		final tests:Array<{inp:Version, out:String}> = [
			{inp: V(1, 2, 3, ["pre", "4"], ["build", "5"]), out: "1.2.3-pre.4+build.5"},
			{inp: V(1, 2, 3, ["pre", "4"], ["build"]), out: "1.2.3-pre.4+build"},
			{inp: V(1, 2, 3, null, ["build"]), out: "1.2.3+build"},
			{inp: V(1, 2, 3, ["pre", "4"]), out: "1.2.3-pre.4"},
			{inp: V(1, 2, 3, null, ["build", "4"]), out: "1.2.3+build.4"},
			{inp: V(1, 2, 3), out: "1.2.3"},
		];

		for (test in tests)
			T.eq(test.out, test.inp.String());
	}

	static function TestVersionCompare() {
		final tests:Array<{v1:String, v2:String, want:Int}> = [
			// https://semver.org/#spec-item-11
			// > Precedence is determined by the first difference when comparing each of these
			// > identifiers from left to right as follows: Major, minor, and patch versions are
			// > always compared numerically.
			{v1: "1.0.0", v2: "2.0.0", want: Semver.comparisonLessThan},
			{v1: "1.0.0", v2: "1.1.0", want: Semver.comparisonLessThan},
			{v1: "1.0.0", v2: "1.0.1", want: Semver.comparisonLessThan},
			{v1: "2.0.0", v2: "1.0.0", want: Semver.comparisonGreaterThan},
			{v1: "1.1.0", v2: "1.0.0", want: Semver.comparisonGreaterThan},
			{v1: "1.0.1", v2: "1.0.0", want: Semver.comparisonGreaterThan},
			{v1: "1.0.0", v2: "1.0.0", want: Semver.comparisonEqualTo},

			// https://semver.org/#spec-item-11
			// > When major, minor, and patch are equal, a pre-release version has lower
			// > precedence than a normal version.
			{v1: "1.0.0", v2: "1.0.0-pre", want: Semver.comparisonGreaterThan},
			{v1: "1.0.1-pre", v2: "1.0.0", want: Semver.comparisonGreaterThan},
			{v1: "1.0.0-pre", v2: "1.0.0", want: Semver.comparisonLessThan},

			// https://semver.org/#spec-item-11
			// > identifiers consisting of only digits are compared numerically
			{v1: "1.0.0-0", v2: "1.0.0-1", want: Semver.comparisonLessThan},
			{v1: "1.0.0-1", v2: "1.0.0-0", want: Semver.comparisonGreaterThan},
			{v1: "1.0.0-2", v2: "1.0.0-10", want: Semver.comparisonLessThan},
			{v1: "1.0.0-10", v2: "1.0.0-2", want: Semver.comparisonGreaterThan},
			{v1: "1.0.0-0", v2: "1.0.0-0", want: Semver.comparisonEqualTo},

			// https://semver.org/#spec-item-11
			// > identifiers with letters or hyphens are compared lexically in ASCII sort order.
			{v1: "1.0.0-a", v2: "1.0.0-b", want: Semver.comparisonLessThan},
			{v1: "1.0.0-a-2", v2: "1.0.0-a-10", want: Semver.comparisonGreaterThan},
			{v1: "1.0.0-b", v2: "1.0.0-a", want: Semver.comparisonGreaterThan},
			{v1: "1.0.0-a", v2: "1.0.0-a", want: Semver.comparisonEqualTo},
			{v1: "1.0.0-A", v2: "1.0.0-a", want: Semver.comparisonLessThan},

			// https://semver.org/#spec-item-11
			// > Numeric identifiers always have lower precedence than non-numeric identifiers.
			{v1: "1.0.0-0", v2: "1.0.0-alpha", want: Semver.comparisonLessThan},
			{v1: "1.0.0-alpha", v2: "1.0.0-0", want: Semver.comparisonGreaterThan},
			{v1: "1.0.0-0", v2: "1.0.0-0", want: Semver.comparisonEqualTo},
			{v1: "1.0.0-alpha", v2: "1.0.0-alpha", want: Semver.comparisonEqualTo},

			// https://semver.org/#spec-item-11
			// > A larger set of pre-release fields has a higher precedence than a smaller set, if all
			// > of the preceding identifiers are equal.
			{v1: "1.0.0-alpha", v2: "1.0.0-alpha.0", want: Semver.comparisonLessThan},
			{v1: "1.0.0-alpha.0", v2: "1.0.0-alpha", want: Semver.comparisonGreaterThan},

			// https://semver.org/#spec-item-11
			// > Precedence for two pre-release versions with the same major, minor, and patch version
			// > MUST be determined by comparing each dot separated identifier from left to right until
			// > a difference is found [...]
			{v1: "1.0.0-a.0.b.1", v2: "1.0.0-a.0.b.2", want: Semver.comparisonLessThan},
			{v1: "1.0.0-a.0.b.1", v2: "1.0.0-b.0.a.1", want: Semver.comparisonLessThan},
			{v1: "1.0.0-a.0.b.2", v2: "1.0.0-a.0.b.1", want: Semver.comparisonGreaterThan},
			{v1: "1.0.0-b.0.a.1", v2: "1.0.0-a.0.b.1", want: Semver.comparisonGreaterThan},

			// https://semver.org/#spec-item-11
			// > Build metadata does not figure into precedence
			{v1: "1.0.0+build", v2: "1.0.0", want: Semver.comparisonEqualTo},
			{v1: "1.0.0+build.stuff", v2: "1.0.0", want: Semver.comparisonEqualTo},
			{v1: "1.0.0", v2: "1.0.0+build", want: Semver.comparisonEqualTo},
			{v1: "1.0.0+build", v2: "1.0.0+stuff", want: Semver.comparisonEqualTo},

			// https://semver.org/#spec-item-11
			// Edge cases for numeric and lexical comparison of prerelease identifiers.
			{v1: "1.0.0-alpha.99999", v2: "1.0.0-alpha.100000", want: Semver.comparisonLessThan},
			{v1: "1.0.0-alpha.beta", v2: "1.0.0-alpha.alpha", want: Semver.comparisonGreaterThan},
		];

		for (test in tests) {
			final r1 = Semver.TryParseVersion(test.v1);
			T.isTrue(r1.err == null, test.v1);
			final r2 = Semver.TryParseVersion(test.v2);
			T.isTrue(r2.err == null, test.v2);
			final got = r1.value.Compare(r2.value);
			if (got != test.want)
				T.fail('${test.v1} <=> ${test.v2}: expected <${test.want}> got <$got>');
			else
				T.eq(test.want, got);
		}
	}

	static function assertVersion(a:Version, b:Version, name:String) {
		T.eq(b.major, a.major);
		T.eq(b.minor, a.minor);
		T.eq(b.patch, a.patch);
		T.isTrue(deepEqual(a.prerelease, b.prerelease), name + ": prerelease");
		T.isTrue(deepEqual(a.build, b.build), name + ": build");
	}

	// assert.DeepEqual on []string: nil and empty differ.
	static function deepEqual(a:Array<String>, b:Array<String>):Bool {
		if (a == null || b == null)
			return a == b;
		if (a.length != b.length)
			return false;
		for (i in 0...a.length)
			if (a[i] != b[i])
				return false;
		return true;
	}

	// --- version_range_test.go ---

	static function TestWildcardsHaveSameString() {
		final majorWildcardStrings = [
			"",
			"*",
			"*.*",
			"*.*.*",
			"x",
			"x.x",
			"x.x.x",
			"X",
			"X.X",
			"X.X.X",
		];

		final minorWildcardStrings = [
			"1",
			"1.*",
			"1.*.*",
			"1.x",
			"1.x.x",
			"1.X",
			"1.X.X",
		];

		final patchWildcardStrings = [
			"1.2",
			"1.2.*",
			"1.2.x",
			"1.2.X",
		];

		final mixedCaseWildcardStrings = [
			"x",
			"X",
			"*",
			"x.X.x",
			"X.x.*",
		];

		assertAllVersionRangesHaveIdenticalStrings("majorWildcardStrings", majorWildcardStrings);
		assertAllVersionRangesHaveIdenticalStrings("minorWildcardStrings", minorWildcardStrings);
		assertAllVersionRangesHaveIdenticalStrings("patchWildcardStrings", patchWildcardStrings);
		assertAllVersionRangesHaveIdenticalStrings("mixedCaseWildcardStrings", mixedCaseWildcardStrings);
	}

	static function assertAllVersionRangesHaveIdenticalStrings(name:String, strs:Array<String>) {
		for (s1 in strs) {
			for (s2 in strs) {
				final r1 = Semver.TryParseVersionRange(s1);
				T.isTrue(r1.ok, '$name: $s1 == $s2');
				final r2 = Semver.TryParseVersionRange(s2);
				T.isTrue(r2.ok, '$name: $s1 == $s2');
				T.eq(r1.value.String(), r2.value.String());
			}
		}
	}

	static function TestVersionRanges() {
		assertRangesGoodBad("1", new TestGoodBad(
			["1.0.0", "1.9.9", "1.0.0-pre", "1.0.0+build"],
			["0.0.0", "2.0.0", "0.0.0-pre", "0.0.0+build"]
		));
		assertRangesGoodBad("1.2", new TestGoodBad(
			["1.2.0", "1.2.9", "1.2.0-pre", "1.2.0+build"],
			["1.1.0", "1.3.0", "1.1.0-pre", "1.1.0+build"]
		));

		assertRangesGoodBad("1.2.3", new TestGoodBad(
			["1.2.3", "1.2.3+build"],
			["1.2.2", "1.2.4", "1.2.2-pre", "1.2.2+build", "1.2.3-pre"]
		));

		assertRangesGoodBad("1.2.3-pre", new TestGoodBad(
			["1.2.3-pre", "1.2.3-pre+build.stuff"],
			["1.2.3", "1.2.3-pre.0", "1.2.3-pre.9", "1.2.3-pre.0+build", "1.2.3-pre.9+build", "1.2.3+build", "1.2.4"]
		));

		assertRangesGoodBad("<3.8.0", new TestGoodBad(
			["3.6", "3.7"],
			["3.8", "3.9", "4.0"]
		));

		assertRangesGoodBad("<=3.8.0", new TestGoodBad(
			["3.6", "3.7", "3.8"],
			["3.9", "4.0"]
		));
		assertRangesGoodBad(">3.8.0", new TestGoodBad(
			["3.9", "4.0"],
			["3.6", "3.7", "3.8"]
		));
		assertRangesGoodBad(">=3.8.0", new TestGoodBad(
			["3.8", "3.9", "4.0"],
			["3.6", "3.7"]
		));

		assertRangesGoodBad("<3.8.0-0", new TestGoodBad(
			["3.6", "3.7"],
			["3.8", "3.9", "4.0"]
		));

		assertRangesGoodBad("<=3.8.0-0", new TestGoodBad(
			["3.6", "3.7"],
			["3.8", "3.9", "4.0"]
		));

		// Big numbers in prerelease strings.
		final lotsaOnes = StringTools.lpad("", "1", 320);
		assertRangesGoodBad(">=1.2.3-1" + lotsaOnes, new TestGoodBad(
			["1.2.3-1" + lotsaOnes, "1.2.3-11" + lotsaOnes + ".1", "1.2.3-1" + lotsaOnes + ".1+build"],
			["1.2.3-" + lotsaOnes + ".1+build"]
		));
	}

	static function TestComparatorsOfVersionRanges() {
		for (test in TestComparatorsOfVersionRangesRows)
			assertRangeTest("comparators", test.rangeText, test.versionText, test.expected);
	}

	static function TestConjunctionsOfVersionRanges() {
		for (test in TestConjunctionsOfVersionRangesRows)
			assertRangeTest("conjunctions", test.rangeText, test.versionText, test.expected);
	}

	static function TestDisjunctionsOfVersionRanges() {
		for (test in TestDisjunctionsOfVersionRangesRows)
			assertRangeTest("disjunctions", test.rangeText, test.versionText, test.expected);
	}

	static function TestHyphensOfVersionRanges() {
		for (test in TestHyphensOfVersionRangesRows)
			assertRangeTest("hyphens", test.rangeText, test.versionText, test.expected);
	}

	static function TestTildesOfVersionRanges() {
		for (test in TestTildesOfVersionRangesRows)
			assertRangeTest("tilde", test.rangeText, test.versionText, test.expected);
	}

	static function TestCaretsOfVersionRanges() {
		for (test in TestCaretsOfVersionRangesRows)
			assertRangeTest("caret", test.rangeText, test.versionText, test.expected);
	}

	static function assertRangesGoodBad(versionRangeString:String, tests:TestGoodBad) {
		final r = Semver.TryParseVersionRange(versionRangeString);
		T.isTrue(r.ok, versionRangeString);
		final versionRange = r.value;
		for (good in tests.good) {
			final v = Semver.TryParseVersion(good);
			T.isTrue(v.err == null, good);
			T.isTrue(versionRange.Test(v.value), '$good should be matched by range $versionRangeString');
		}

		for (bad in tests.bad) {
			final v = Semver.TryParseVersion(bad);
			T.isTrue(v.err == null, bad);
			T.isTrue(!versionRange.Test(v.value), '$bad should not be matched by range $versionRangeString');
		}
	}

	static function assertRangeTest(name:String, rangeText:String, versionText:String, inRange:Bool) {
		final testName = '$name (version $versionText in range $rangeText) == $inRange';
		final r = Semver.TryParseVersionRange(rangeText);
		T.isTrue(r.ok, testName);
		final version = Semver.TryParseVersion(versionText);
		T.isTrue(version.err == null, testName);
		T.isTrue(r.value.Test(version.value) == inRange, testName);
	}

	static final TestComparatorsOfVersionRangesRows:Array<TestForRangeOnVersion> = [
		// empty (matches everything)
		new TestForRangeOnVersion("", "2.0.0", true),
		new TestForRangeOnVersion("", "2.0.0-0", true),
		new TestForRangeOnVersion("", "1.1.0", true),
		new TestForRangeOnVersion("", "1.1.0-0", true),
		new TestForRangeOnVersion("", "1.0.1", true),
		new TestForRangeOnVersion("", "1.0.1-0", true),
		new TestForRangeOnVersion("", "1.0.0", true),
		new TestForRangeOnVersion("", "1.0.0-0", true),
		new TestForRangeOnVersion("", "0.0.0", true),
		new TestForRangeOnVersion("", "0.0.0-0", true),

		// wildcard major (matches everything)
		new TestForRangeOnVersion("*", "2.0.0", true),
		new TestForRangeOnVersion("*", "2.0.0-0", true),
		new TestForRangeOnVersion("*", "1.1.0", true),
		new TestForRangeOnVersion("*", "1.1.0-0", true),
		new TestForRangeOnVersion("*", "1.0.1", true),
		new TestForRangeOnVersion("*", "1.0.1-0", true),
		new TestForRangeOnVersion("*", "1.0.0", true),
		new TestForRangeOnVersion("*", "1.0.0-0", true),
		new TestForRangeOnVersion("*", "0.0.0", true),
		new TestForRangeOnVersion("*", "0.0.0-0", true),

		// wildcard minor
		new TestForRangeOnVersion("1", "2.0.0", false),
		new TestForRangeOnVersion("1", "2.0.0-0", false),
		new TestForRangeOnVersion("1", "1.1.0", true),
		new TestForRangeOnVersion("1", "1.1.0-0", true),
		new TestForRangeOnVersion("1", "1.0.1", true),
		new TestForRangeOnVersion("1", "1.0.1-0", true),
		new TestForRangeOnVersion("1", "1.0.0", true),
		new TestForRangeOnVersion("1", "1.0.0-0", true),
		new TestForRangeOnVersion("1", "0.0.0", false),
		new TestForRangeOnVersion("1", "0.0.0-0", false),

		// wildcard patch
		new TestForRangeOnVersion("1.1", "2.0.0", false),
		new TestForRangeOnVersion("1.1", "2.0.0-0", false),
		new TestForRangeOnVersion("1.1", "1.1.0", true),
		new TestForRangeOnVersion("1.1", "1.1.0-0", true),
		new TestForRangeOnVersion("1.1", "1.0.1", false),
		new TestForRangeOnVersion("1.1", "1.0.1-0", false),
		new TestForRangeOnVersion("1.1", "1.0.0", false),
		new TestForRangeOnVersion("1.1", "1.0.0-0", false),
		new TestForRangeOnVersion("1.1", "0.0.0", false),
		new TestForRangeOnVersion("1.1", "0.0.0-0", false),
		new TestForRangeOnVersion("1.0", "2.0.0", false),
		new TestForRangeOnVersion("1.0", "2.0.0-0", false),
		new TestForRangeOnVersion("1.0", "1.1.0", false),
		new TestForRangeOnVersion("1.0", "1.1.0-0", false),
		new TestForRangeOnVersion("1.0", "1.0.1", true),
		new TestForRangeOnVersion("1.0", "1.0.1-0", true),
		new TestForRangeOnVersion("1.0", "1.0.0", true),
		new TestForRangeOnVersion("1.0", "1.0.0-0", true),
		new TestForRangeOnVersion("1.0", "0.0.0", false),
		new TestForRangeOnVersion("1.0", "0.0.0-0", false),

		// exact
		new TestForRangeOnVersion("1.1.0", "2.0.0", false),
		new TestForRangeOnVersion("1.1.0", "2.0.0-0", false),
		new TestForRangeOnVersion("1.1.0", "1.1.0", true),
		new TestForRangeOnVersion("1.1.0", "1.1.0-0", false),
		new TestForRangeOnVersion("1.1.0", "1.0.1", false),
		new TestForRangeOnVersion("1.1.0", "1.0.1-0", false),
		new TestForRangeOnVersion("1.1.0", "1.0.0-0", false),
		new TestForRangeOnVersion("1.1.0", "1.0.0", false),
		new TestForRangeOnVersion("1.1.0", "0.0.0", false),
		new TestForRangeOnVersion("1.1.0", "0.0.0-0", false),
		new TestForRangeOnVersion("1.1.0-0", "2.0.0", false),
		new TestForRangeOnVersion("1.1.0-0", "2.0.0-0", false),
		new TestForRangeOnVersion("1.1.0-0", "1.1.0", false),
		new TestForRangeOnVersion("1.1.0-0", "1.1.0-0", true),
		new TestForRangeOnVersion("1.1.0-0", "1.0.1", false),
		new TestForRangeOnVersion("1.1.0-0", "1.0.1-0", false),
		new TestForRangeOnVersion("1.1.0-0", "1.0.0-0", false),
		new TestForRangeOnVersion("1.1.0-0", "1.0.0", false),
		new TestForRangeOnVersion("1.1.0-0", "0.0.0", false),
		new TestForRangeOnVersion("1.1.0-0", "0.0.0-0", false),
		new TestForRangeOnVersion("1.0.1", "2.0.0", false),
		new TestForRangeOnVersion("1.0.1", "2.0.0-0", false),
		new TestForRangeOnVersion("1.0.1", "1.1.0", false),
		new TestForRangeOnVersion("1.0.1", "1.1.0-0", false),
		new TestForRangeOnVersion("1.0.1", "1.0.1", true),
		new TestForRangeOnVersion("1.0.1", "1.0.1-0", false),
		new TestForRangeOnVersion("1.0.1", "1.0.0-0", false),
		new TestForRangeOnVersion("1.0.1", "1.0.0", false),
		new TestForRangeOnVersion("1.0.1", "0.0.0", false),
		new TestForRangeOnVersion("1.0.1", "0.0.0-0", false),
		new TestForRangeOnVersion("1.0.1-0", "2.0.0", false),
		new TestForRangeOnVersion("1.0.1-0", "2.0.0-0", false),
		new TestForRangeOnVersion("1.0.1-0", "1.1.0", false),
		new TestForRangeOnVersion("1.0.1-0", "1.1.0-0", false),
		new TestForRangeOnVersion("1.0.1-0", "1.0.1", false),
		new TestForRangeOnVersion("1.0.1-0", "1.0.1-0", true),
		new TestForRangeOnVersion("1.0.1-0", "1.0.0-0", false),
		new TestForRangeOnVersion("1.0.1-0", "1.0.0", false),
		new TestForRangeOnVersion("1.0.1-0", "0.0.0", false),
		new TestForRangeOnVersion("1.0.1-0", "0.0.0-0", false),
		new TestForRangeOnVersion("1.0.0", "2.0.0", false),
		new TestForRangeOnVersion("1.0.0", "2.0.0-0", false),
		new TestForRangeOnVersion("1.0.0", "1.1.0", false),
		new TestForRangeOnVersion("1.0.0", "1.1.0-0", false),
		new TestForRangeOnVersion("1.0.0", "1.0.1", false),
		new TestForRangeOnVersion("1.0.0", "1.0.1-0", false),
		new TestForRangeOnVersion("1.0.0", "1.0.0-0", false),
		new TestForRangeOnVersion("1.0.0", "1.0.0", true),
		new TestForRangeOnVersion("1.0.0", "0.0.0", false),
		new TestForRangeOnVersion("1.0.0", "0.0.0-0", false),
		new TestForRangeOnVersion("1.0.0-0", "2.0.0", false),
		new TestForRangeOnVersion("1.0.0-0", "2.0.0-0", false),
		new TestForRangeOnVersion("1.0.0-0", "1.1.0", false),
		new TestForRangeOnVersion("1.0.0-0", "1.1.0-0", false),
		new TestForRangeOnVersion("1.0.0-0", "1.0.1", false),
		new TestForRangeOnVersion("1.0.0-0", "1.0.1-0", false),
		new TestForRangeOnVersion("1.0.0-0", "1.0.0", false),
		new TestForRangeOnVersion("1.0.0-0", "1.0.0-0", true),

		// = wildcard major (matches everything)
		new TestForRangeOnVersion("=*", "2.0.0", true),
		new TestForRangeOnVersion("=*", "2.0.0-0", true),
		new TestForRangeOnVersion("=*", "1.1.0", true),
		new TestForRangeOnVersion("=*", "1.1.0-0", true),
		new TestForRangeOnVersion("=*", "1.0.1", true),
		new TestForRangeOnVersion("=*", "1.0.1-0", true),
		new TestForRangeOnVersion("=*", "1.0.0", true),
		new TestForRangeOnVersion("=*", "1.0.0-0", true),
		new TestForRangeOnVersion("=*", "0.0.0", true),
		new TestForRangeOnVersion("=*", "0.0.0-0", true),

		// = wildcard minor
		new TestForRangeOnVersion("=1", "2.0.0", false),
		new TestForRangeOnVersion("=1", "2.0.0-0", false),
		new TestForRangeOnVersion("=1", "1.1.0", true),
		new TestForRangeOnVersion("=1", "1.1.0-0", true),
		new TestForRangeOnVersion("=1", "1.0.1", true),
		new TestForRangeOnVersion("=1", "1.0.1-0", true),
		new TestForRangeOnVersion("=1", "1.0.0", true),
		new TestForRangeOnVersion("=1", "1.0.0-0", true),
		new TestForRangeOnVersion("=1", "0.0.0", false),
		new TestForRangeOnVersion("=1", "0.0.0-0", false),

		// = wildcard patch
		new TestForRangeOnVersion("=1.1", "2.0.0", false),
		new TestForRangeOnVersion("=1.1", "2.0.0-0", false),
		new TestForRangeOnVersion("=1.1", "1.1.0", true),
		new TestForRangeOnVersion("=1.1", "1.1.0-0", true),
		new TestForRangeOnVersion("=1.1", "1.0.1", false),
		new TestForRangeOnVersion("=1.1", "1.0.1-0", false),
		new TestForRangeOnVersion("=1.1", "1.0.0", false),
		new TestForRangeOnVersion("=1.1", "1.0.0-0", false),
		new TestForRangeOnVersion("=1.1", "0.0.0", false),
		new TestForRangeOnVersion("=1.1", "0.0.0-0", false),
		new TestForRangeOnVersion("=1.0", "2.0.0", false),
		new TestForRangeOnVersion("=1.0", "2.0.0-0", false),
		new TestForRangeOnVersion("=1.0", "1.1.0", false),
		new TestForRangeOnVersion("=1.0", "1.1.0-0", false),
		new TestForRangeOnVersion("=1.0", "1.0.1", true),
		new TestForRangeOnVersion("=1.0", "1.0.1-0", true),
		new TestForRangeOnVersion("=1.0", "1.0.0", true),
		new TestForRangeOnVersion("=1.0", "1.0.0-0", true),
		new TestForRangeOnVersion("=1.0", "0.0.0", false),
		new TestForRangeOnVersion("=1.0", "0.0.0-0", false),

		// = exact
		new TestForRangeOnVersion("=1.1.0", "2.0.0", false),
		new TestForRangeOnVersion("=1.1.0", "2.0.0-0", false),
		new TestForRangeOnVersion("=1.1.0", "1.1.0", true),
		new TestForRangeOnVersion("=1.1.0", "1.1.0-0", false),
		new TestForRangeOnVersion("=1.1.0", "1.0.1", false),
		new TestForRangeOnVersion("=1.1.0", "1.0.1-0", false),
		new TestForRangeOnVersion("=1.1.0", "1.0.0-0", false),
		new TestForRangeOnVersion("=1.1.0", "1.0.0", false),
		new TestForRangeOnVersion("=1.1.0", "0.0.0", false),
		new TestForRangeOnVersion("=1.1.0", "0.0.0-0", false),
		new TestForRangeOnVersion("=1.1.0-0", "2.0.0", false),
		new TestForRangeOnVersion("=1.1.0-0", "2.0.0-0", false),
		new TestForRangeOnVersion("=1.1.0-0", "1.1.0", false),
		new TestForRangeOnVersion("=1.1.0-0", "1.1.0-0", true),
		new TestForRangeOnVersion("=1.1.0-0", "1.0.1", false),
		new TestForRangeOnVersion("=1.1.0-0", "1.0.1-0", false),
		new TestForRangeOnVersion("=1.1.0-0", "1.0.0-0", false),
		new TestForRangeOnVersion("=1.1.0-0", "1.0.0", false),
		new TestForRangeOnVersion("=1.1.0-0", "0.0.0", false),
		new TestForRangeOnVersion("=1.1.0-0", "0.0.0-0", false),
		new TestForRangeOnVersion("=1.0.1", "2.0.0", false),
		new TestForRangeOnVersion("=1.0.1", "2.0.0-0", false),
		new TestForRangeOnVersion("=1.0.1", "1.1.0", false),
		new TestForRangeOnVersion("=1.0.1", "1.1.0-0", false),
		new TestForRangeOnVersion("=1.0.1", "1.0.1", true),
		new TestForRangeOnVersion("=1.0.1", "1.0.1-0", false),
		new TestForRangeOnVersion("=1.0.1", "1.0.0-0", false),
		new TestForRangeOnVersion("=1.0.1", "1.0.0", false),
		new TestForRangeOnVersion("=1.0.1", "0.0.0", false),
		new TestForRangeOnVersion("=1.0.1", "0.0.0-0", false),
		new TestForRangeOnVersion("=1.0.1-0", "2.0.0", false),
		new TestForRangeOnVersion("=1.0.1-0", "2.0.0-0", false),
		new TestForRangeOnVersion("=1.0.1-0", "1.1.0", false),
		new TestForRangeOnVersion("=1.0.1-0", "1.1.0-0", false),
		new TestForRangeOnVersion("=1.0.1-0", "1.0.1", false),
		new TestForRangeOnVersion("=1.0.1-0", "1.0.1-0", true),
		new TestForRangeOnVersion("=1.0.1-0", "1.0.0-0", false),
		new TestForRangeOnVersion("=1.0.1-0", "1.0.0", false),
		new TestForRangeOnVersion("=1.0.1-0", "0.0.0", false),
		new TestForRangeOnVersion("=1.0.1-0", "0.0.0-0", false),
		new TestForRangeOnVersion("=1.0.0", "2.0.0", false),
		new TestForRangeOnVersion("=1.0.0", "2.0.0-0", false),
		new TestForRangeOnVersion("=1.0.0", "1.1.0", false),
		new TestForRangeOnVersion("=1.0.0", "1.1.0-0", false),
		new TestForRangeOnVersion("=1.0.0", "1.0.1", false),
		new TestForRangeOnVersion("=1.0.0", "1.0.1-0", false),
		new TestForRangeOnVersion("=1.0.0", "1.0.0-0", false),
		new TestForRangeOnVersion("=1.0.0", "1.0.0", true),
		new TestForRangeOnVersion("=1.0.0", "0.0.0", false),
		new TestForRangeOnVersion("=1.0.0", "0.0.0-0", false),
		new TestForRangeOnVersion("=1.0.0-0", "2.0.0", false),
		new TestForRangeOnVersion("=1.0.0-0", "2.0.0-0", false),
		new TestForRangeOnVersion("=1.0.0-0", "1.1.0", false),
		new TestForRangeOnVersion("=1.0.0-0", "1.1.0-0", false),
		new TestForRangeOnVersion("=1.0.0-0", "1.0.1", false),
		new TestForRangeOnVersion("=1.0.0-0", "1.0.1-0", false),
		new TestForRangeOnVersion("=1.0.0-0", "1.0.0", false),
		new TestForRangeOnVersion("=1.0.0-0", "1.0.0-0", true),

		// > wildcard major (matches nothing)
		new TestForRangeOnVersion(">*", "2.0.0", false),
		new TestForRangeOnVersion(">*", "2.0.0-0", false),
		new TestForRangeOnVersion(">*", "1.1.0", false),
		new TestForRangeOnVersion(">*", "1.1.0-0", false),
		new TestForRangeOnVersion(">*", "1.0.1", false),
		new TestForRangeOnVersion(">*", "1.0.1-0", false),
		new TestForRangeOnVersion(">*", "1.0.0", false),
		new TestForRangeOnVersion(">*", "1.0.0-0", false),
		new TestForRangeOnVersion(">*", "0.0.0", false),
		new TestForRangeOnVersion(">*", "0.0.0-0", false),

		// > wildcard minor
		new TestForRangeOnVersion(">1", "2.0.0", true),
		new TestForRangeOnVersion(">1", "2.0.0-0", true),
		new TestForRangeOnVersion(">1", "1.1.0", false),
		new TestForRangeOnVersion(">1", "1.1.0-0", false),
		new TestForRangeOnVersion(">1", "1.0.1", false),
		new TestForRangeOnVersion(">1", "1.0.1-0", false),
		new TestForRangeOnVersion(">1", "1.0.0", false),
		new TestForRangeOnVersion(">1", "1.0.0-0", false),
		new TestForRangeOnVersion(">1", "0.0.0", false),
		new TestForRangeOnVersion(">1", "0.0.0-0", false),

		// > wildcard patch
		new TestForRangeOnVersion(">1.1", "2.0.0", true),
		new TestForRangeOnVersion(">1.1", "2.0.0-0", true),
		new TestForRangeOnVersion(">1.1", "1.1.0", false),
		new TestForRangeOnVersion(">1.1", "1.1.0-0", false),
		new TestForRangeOnVersion(">1.1", "1.0.1", false),
		new TestForRangeOnVersion(">1.1", "1.0.1-0", false),
		new TestForRangeOnVersion(">1.1", "1.0.0", false),
		new TestForRangeOnVersion(">1.1", "1.0.0-0", false),
		new TestForRangeOnVersion(">1.1", "0.0.0", false),
		new TestForRangeOnVersion(">1.1", "0.0.0-0", false),
		new TestForRangeOnVersion(">1.0", "2.0.0", true),
		new TestForRangeOnVersion(">1.0", "2.0.0-0", true),
		new TestForRangeOnVersion(">1.0", "1.1.0", true),
		new TestForRangeOnVersion(">1.0", "1.1.0-0", true),
		new TestForRangeOnVersion(">1.0", "1.0.1", false),
		new TestForRangeOnVersion(">1.0", "1.0.1-0", false),
		new TestForRangeOnVersion(">1.0", "1.0.0", false),
		new TestForRangeOnVersion(">1.0", "1.0.0-0", false),
		new TestForRangeOnVersion(">1.0", "0.0.0", false),
		new TestForRangeOnVersion(">1.0", "0.0.0-0", false),

		// > exact
		new TestForRangeOnVersion(">1.1.0", "2.0.0", true),
		new TestForRangeOnVersion(">1.1.0", "2.0.0-0", true),
		new TestForRangeOnVersion(">1.1.0", "1.1.0", false),
		new TestForRangeOnVersion(">1.1.0", "1.1.0-0", false),
		new TestForRangeOnVersion(">1.1.0", "1.0.1", false),
		new TestForRangeOnVersion(">1.1.0", "1.0.1-0", false),
		new TestForRangeOnVersion(">1.1.0", "1.0.0", false),
		new TestForRangeOnVersion(">1.1.0", "1.0.0-0", false),
		new TestForRangeOnVersion(">1.1.0", "0.0.0", false),
		new TestForRangeOnVersion(">1.1.0", "0.0.0-0", false),
		new TestForRangeOnVersion(">1.1.0-0", "2.0.0", true),
		new TestForRangeOnVersion(">1.1.0-0", "2.0.0-0", true),
		new TestForRangeOnVersion(">1.1.0-0", "1.1.0", true),
		new TestForRangeOnVersion(">1.1.0-0", "1.1.0-0", false),
		new TestForRangeOnVersion(">1.1.0-0", "1.0.1", false),
		new TestForRangeOnVersion(">1.1.0-0", "1.0.1-0", false),
		new TestForRangeOnVersion(">1.1.0-0", "1.0.0", false),
		new TestForRangeOnVersion(">1.1.0-0", "1.0.0-0", false),
		new TestForRangeOnVersion(">1.1.0-0", "0.0.0", false),
		new TestForRangeOnVersion(">1.1.0-0", "0.0.0-0", false),
		new TestForRangeOnVersion(">1.0.1", "2.0.0", true),
		new TestForRangeOnVersion(">1.0.1", "2.0.0-0", true),
		new TestForRangeOnVersion(">1.0.1", "1.1.0", true),
		new TestForRangeOnVersion(">1.0.1", "1.1.0-0", true),
		new TestForRangeOnVersion(">1.0.1", "1.0.1", false),
		new TestForRangeOnVersion(">1.0.1", "1.0.1-0", false),
		new TestForRangeOnVersion(">1.0.1", "1.0.0", false),
		new TestForRangeOnVersion(">1.0.1", "1.0.0-0", false),
		new TestForRangeOnVersion(">1.0.1", "0.0.0", false),
		new TestForRangeOnVersion(">1.0.1", "0.0.0-0", false),
		new TestForRangeOnVersion(">1.0.1-0", "2.0.0", true),
		new TestForRangeOnVersion(">1.0.1-0", "2.0.0-0", true),
		new TestForRangeOnVersion(">1.0.1-0", "1.1.0", true),
		new TestForRangeOnVersion(">1.0.1-0", "1.1.0-0", true),
		new TestForRangeOnVersion(">1.0.1-0", "1.0.1", true),
		new TestForRangeOnVersion(">1.0.1-0", "1.0.1-0", false),
		new TestForRangeOnVersion(">1.0.1-0", "1.0.0", false),
		new TestForRangeOnVersion(">1.0.1-0", "1.0.0-0", false),
		new TestForRangeOnVersion(">1.0.1-0", "0.0.0", false),
		new TestForRangeOnVersion(">1.0.1-0", "0.0.0-0", false),
		new TestForRangeOnVersion(">1.0.0", "2.0.0", true),
		new TestForRangeOnVersion(">1.0.0", "2.0.0-0", true),
		new TestForRangeOnVersion(">1.0.0", "1.1.0", true),
		new TestForRangeOnVersion(">1.0.0", "1.1.0-0", true),
		new TestForRangeOnVersion(">1.0.0", "1.0.1", true),
		new TestForRangeOnVersion(">1.0.0", "1.0.1-0", true),
		new TestForRangeOnVersion(">1.0.0", "1.0.0", false),
		new TestForRangeOnVersion(">1.0.0", "1.0.0-0", false),
		new TestForRangeOnVersion(">1.0.0", "0.0.0", false),
		new TestForRangeOnVersion(">1.0.0", "0.0.0-0", false),
		new TestForRangeOnVersion(">1.0.0-0", "2.0.0", true),
		new TestForRangeOnVersion(">1.0.0-0", "2.0.0-0", true),
		new TestForRangeOnVersion(">1.0.0-0", "1.1.0", true),
		new TestForRangeOnVersion(">1.0.0-0", "1.1.0-0", true),
		new TestForRangeOnVersion(">1.0.0-0", "1.0.1", true),
		new TestForRangeOnVersion(">1.0.0-0", "1.0.1-0", true),
		new TestForRangeOnVersion(">1.0.0-0", "1.0.0", true),
		new TestForRangeOnVersion(">1.0.0-0", "1.0.0-0", false),
		new TestForRangeOnVersion(">1.0.0-0", "0.0.0", false),
		new TestForRangeOnVersion(">1.0.0-0", "0.0.0-0", false),

		// >= wildcard major (matches everything)
		new TestForRangeOnVersion(">=*", "2.0.0", true),
		new TestForRangeOnVersion(">=*", "2.0.0-0", true),
		new TestForRangeOnVersion(">=*", "1.1.0", true),
		new TestForRangeOnVersion(">=*", "1.1.0-0", true),
		new TestForRangeOnVersion(">=*", "1.0.1", true),
		new TestForRangeOnVersion(">=*", "1.0.1-0", true),
		new TestForRangeOnVersion(">=*", "1.0.0", true),
		new TestForRangeOnVersion(">=*", "1.0.0-0", true),
		new TestForRangeOnVersion(">=*", "0.0.0", true),
		new TestForRangeOnVersion(">=*", "0.0.0-0", true),

		// >= wildcard minor
		new TestForRangeOnVersion(">=1", "2.0.0", true),
		new TestForRangeOnVersion(">=1", "2.0.0-0", true),
		new TestForRangeOnVersion(">=1", "1.1.0", true),
		new TestForRangeOnVersion(">=1", "1.1.0-0", true),
		new TestForRangeOnVersion(">=1", "1.0.1", true),
		new TestForRangeOnVersion(">=1", "1.0.1-0", true),
		new TestForRangeOnVersion(">=1", "1.0.0", true),
		new TestForRangeOnVersion(">=1", "1.0.0-0", true),
		new TestForRangeOnVersion(">=1", "0.0.0", false),
		new TestForRangeOnVersion(">=1", "0.0.0-0", false),

		// >= wildcard patch
		new TestForRangeOnVersion(">=1.1", "2.0.0", true),
		new TestForRangeOnVersion(">=1.1", "2.0.0-0", true),
		new TestForRangeOnVersion(">=1.1", "1.1.0", true),
		new TestForRangeOnVersion(">=1.1", "1.1.0-0", true),
		new TestForRangeOnVersion(">=1.1", "1.0.1", false),
		new TestForRangeOnVersion(">=1.1", "1.0.1-0", false),
		new TestForRangeOnVersion(">=1.1", "1.0.0", false),
		new TestForRangeOnVersion(">=1.1", "1.0.0-0", false),
		new TestForRangeOnVersion(">=1.1", "0.0.0", false),
		new TestForRangeOnVersion(">=1.1", "0.0.0-0", false),
		new TestForRangeOnVersion(">=1.0", "2.0.0", true),
		new TestForRangeOnVersion(">=1.0", "2.0.0-0", true),
		new TestForRangeOnVersion(">=1.0", "1.1.0", true),
		new TestForRangeOnVersion(">=1.0", "1.1.0-0", true),
		new TestForRangeOnVersion(">=1.0", "1.0.1", true),
		new TestForRangeOnVersion(">=1.0", "1.0.1-0", true),
		new TestForRangeOnVersion(">=1.0", "1.0.0", true),
		new TestForRangeOnVersion(">=1.0", "1.0.0-0", true),
		new TestForRangeOnVersion(">=1.0", "0.0.0", false),
		new TestForRangeOnVersion(">=1.0", "0.0.0-0", false),

		// >= exact
		new TestForRangeOnVersion(">=1.1.0", "2.0.0", true),
		new TestForRangeOnVersion(">=1.1.0", "2.0.0-0", true),
		new TestForRangeOnVersion(">=1.1.0", "1.1.0", true),
		new TestForRangeOnVersion(">=1.1.0", "1.1.0-0", false),
		new TestForRangeOnVersion(">=1.1.0", "1.0.1", false),
		new TestForRangeOnVersion(">=1.1.0", "1.0.1-0", false),
		new TestForRangeOnVersion(">=1.1.0", "1.0.0", false),
		new TestForRangeOnVersion(">=1.1.0", "1.0.0-0", false),
		new TestForRangeOnVersion(">=1.1.0", "0.0.0", false),
		new TestForRangeOnVersion(">=1.1.0", "0.0.0-0", false),
		new TestForRangeOnVersion(">=1.1.0-0", "2.0.0", true),
		new TestForRangeOnVersion(">=1.1.0-0", "2.0.0-0", true),
		new TestForRangeOnVersion(">=1.1.0-0", "1.1.0", true),
		new TestForRangeOnVersion(">=1.1.0-0", "1.1.0-0", true),
		new TestForRangeOnVersion(">=1.1.0-0", "1.0.1", false),
		new TestForRangeOnVersion(">=1.1.0-0", "1.0.1-0", false),
		new TestForRangeOnVersion(">=1.1.0-0", "1.0.0", false),
		new TestForRangeOnVersion(">=1.1.0-0", "1.0.0-0", false),
		new TestForRangeOnVersion(">=1.1.0-0", "0.0.0", false),
		new TestForRangeOnVersion(">=1.1.0-0", "0.0.0-0", false),
		new TestForRangeOnVersion(">=1.0.1", "2.0.0", true),
		new TestForRangeOnVersion(">=1.0.1", "2.0.0-0", true),
		new TestForRangeOnVersion(">=1.0.1", "1.1.0", true),
		new TestForRangeOnVersion(">=1.0.1", "1.1.0-0", true),
		new TestForRangeOnVersion(">=1.0.1", "1.0.1", true),
		new TestForRangeOnVersion(">=1.0.1", "1.0.1-0", false),
		new TestForRangeOnVersion(">=1.0.1", "1.0.0", false),
		new TestForRangeOnVersion(">=1.0.1", "1.0.0-0", false),
		new TestForRangeOnVersion(">=1.0.1", "0.0.0", false),
		new TestForRangeOnVersion(">=1.0.1", "0.0.0-0", false),
		new TestForRangeOnVersion(">=1.0.1-0", "2.0.0", true),
		new TestForRangeOnVersion(">=1.0.1-0", "2.0.0-0", true),
		new TestForRangeOnVersion(">=1.0.1-0", "1.1.0", true),
		new TestForRangeOnVersion(">=1.0.1-0", "1.1.0-0", true),
		new TestForRangeOnVersion(">=1.0.1-0", "1.0.1", true),
		new TestForRangeOnVersion(">=1.0.1-0", "1.0.1-0", true),
		new TestForRangeOnVersion(">=1.0.1-0", "1.0.0", false),
		new TestForRangeOnVersion(">=1.0.1-0", "1.0.0-0", false),
		new TestForRangeOnVersion(">=1.0.1-0", "0.0.0", false),
		new TestForRangeOnVersion(">=1.0.1-0", "0.0.0-0", false),
		new TestForRangeOnVersion(">=1.0.0", "2.0.0", true),
		new TestForRangeOnVersion(">=1.0.0", "2.0.0-0", true),
		new TestForRangeOnVersion(">=1.0.0", "1.1.0", true),
		new TestForRangeOnVersion(">=1.0.0", "1.1.0-0", true),
		new TestForRangeOnVersion(">=1.0.0", "1.0.1", true),
		new TestForRangeOnVersion(">=1.0.0", "1.0.1-0", true),
		new TestForRangeOnVersion(">=1.0.0", "1.0.0", true),
		new TestForRangeOnVersion(">=1.0.0", "1.0.0-0", false),
		new TestForRangeOnVersion(">=1.0.0", "0.0.0", false),
		new TestForRangeOnVersion(">=1.0.0", "0.0.0-0", false),
		new TestForRangeOnVersion(">=1.0.0-0", "2.0.0", true),
		new TestForRangeOnVersion(">=1.0.0-0", "2.0.0-0", true),
		new TestForRangeOnVersion(">=1.0.0-0", "1.1.0", true),
		new TestForRangeOnVersion(">=1.0.0-0", "1.1.0-0", true),
		new TestForRangeOnVersion(">=1.0.0-0", "1.0.1", true),
		new TestForRangeOnVersion(">=1.0.0-0", "1.0.1-0", true),
		new TestForRangeOnVersion(">=1.0.0-0", "1.0.0", true),
		new TestForRangeOnVersion(">=1.0.0-0", "1.0.0-0", true),
		new TestForRangeOnVersion(">=1.0.0-0", "0.0.0", false),
		new TestForRangeOnVersion(">=1.0.0-0", "0.0.0-0", false),

		// < wildcard major (matches nothing)
		new TestForRangeOnVersion("<*", "2.0.0", false),
		new TestForRangeOnVersion("<*", "2.0.0-0", false),
		new TestForRangeOnVersion("<*", "1.1.0", false),
		new TestForRangeOnVersion("<*", "1.1.0-0", false),
		new TestForRangeOnVersion("<*", "1.0.1", false),
		new TestForRangeOnVersion("<*", "1.0.1-0", false),
		new TestForRangeOnVersion("<*", "1.0.0", false),
		new TestForRangeOnVersion("<*", "1.0.0-0", false),
		new TestForRangeOnVersion("<*", "0.0.0", false),
		new TestForRangeOnVersion("<*", "0.0.0-0", false),

		// < wildcard minor
		new TestForRangeOnVersion("<1", "2.0.0", false),
		new TestForRangeOnVersion("<1", "2.0.0-0", false),
		new TestForRangeOnVersion("<1", "1.1.0", false),
		new TestForRangeOnVersion("<1", "1.1.0-0", false),
		new TestForRangeOnVersion("<1", "1.0.1", false),
		new TestForRangeOnVersion("<1", "1.0.1-0", false),
		new TestForRangeOnVersion("<1", "1.0.0", false),
		new TestForRangeOnVersion("<1", "1.0.0-0", false),
		new TestForRangeOnVersion("<1", "0.0.0", true),
		new TestForRangeOnVersion("<1", "0.0.0-0", true),

		// < wildcard patch
		new TestForRangeOnVersion("<1.1", "2.0.0", false),
		new TestForRangeOnVersion("<1.1", "2.0.0-0", false),
		new TestForRangeOnVersion("<1.1", "1.1.0", false),
		new TestForRangeOnVersion("<1.1", "1.1.0-0", false),
		new TestForRangeOnVersion("<1.1", "1.0.1", true),
		new TestForRangeOnVersion("<1.1", "1.0.1-0", true),
		new TestForRangeOnVersion("<1.1", "1.0.0", true),
		new TestForRangeOnVersion("<1.1", "1.0.0-0", true),
		new TestForRangeOnVersion("<1.1", "0.0.0", true),
		new TestForRangeOnVersion("<1.1", "0.0.0-0", true),
		new TestForRangeOnVersion("<1.0", "2.0.0", false),
		new TestForRangeOnVersion("<1.0", "2.0.0-0", false),
		new TestForRangeOnVersion("<1.0", "1.1.0", false),
		new TestForRangeOnVersion("<1.0", "1.1.0-0", false),
		new TestForRangeOnVersion("<1.0", "1.0.1", false),
		new TestForRangeOnVersion("<1.0", "1.0.1-0", false),
		new TestForRangeOnVersion("<1.0", "1.0.0", false),
		new TestForRangeOnVersion("<1.0", "1.0.0-0", false),
		new TestForRangeOnVersion("<1.0", "0.0.0", true),
		new TestForRangeOnVersion("<1.0", "0.0.0-0", true),

		// < exact
		new TestForRangeOnVersion("<1.1.0", "2.0.0", false),
		new TestForRangeOnVersion("<1.1.0", "2.0.0-0", false),
		new TestForRangeOnVersion("<1.1.0", "1.1.0", false),
		new TestForRangeOnVersion("<1.1.0", "1.1.0-0", true),
		new TestForRangeOnVersion("<1.1.0", "1.0.1", true),
		new TestForRangeOnVersion("<1.1.0", "1.0.1-0", true),
		new TestForRangeOnVersion("<1.1.0", "1.0.0", true),
		new TestForRangeOnVersion("<1.1.0", "1.0.0-0", true),
		new TestForRangeOnVersion("<1.1.0", "0.0.0", true),
		new TestForRangeOnVersion("<1.1.0", "0.0.0-0", true),
		new TestForRangeOnVersion("<1.1.0-0", "2.0.0", false),
		new TestForRangeOnVersion("<1.1.0-0", "2.0.0-0", false),
		new TestForRangeOnVersion("<1.1.0-0", "1.1.0", false),
		new TestForRangeOnVersion("<1.1.0-0", "1.1.0-0", false),
		new TestForRangeOnVersion("<1.1.0-0", "1.0.1", true),
		new TestForRangeOnVersion("<1.1.0-0", "1.0.1-0", true),
		new TestForRangeOnVersion("<1.1.0-0", "1.0.0", true),
		new TestForRangeOnVersion("<1.1.0-0", "1.0.0-0", true),
		new TestForRangeOnVersion("<1.1.0-0", "0.0.0", true),
		new TestForRangeOnVersion("<1.1.0-0", "0.0.0-0", true),
		new TestForRangeOnVersion("<1.0.1", "2.0.0", false),
		new TestForRangeOnVersion("<1.0.1", "2.0.0-0", false),
		new TestForRangeOnVersion("<1.0.1", "1.1.0", false),
		new TestForRangeOnVersion("<1.0.1", "1.1.0-0", false),
		new TestForRangeOnVersion("<1.0.1", "1.0.1", false),
		new TestForRangeOnVersion("<1.0.1", "1.0.1-0", true),
		new TestForRangeOnVersion("<1.0.1", "1.0.0", true),
		new TestForRangeOnVersion("<1.0.1", "1.0.0-0", true),
		new TestForRangeOnVersion("<1.0.1", "0.0.0", true),
		new TestForRangeOnVersion("<1.0.1", "0.0.0-0", true),
		new TestForRangeOnVersion("<1.0.1-0", "2.0.0", false),
		new TestForRangeOnVersion("<1.0.1-0", "2.0.0-0", false),
		new TestForRangeOnVersion("<1.0.1-0", "1.1.0", false),
		new TestForRangeOnVersion("<1.0.1-0", "1.1.0-0", false),
		new TestForRangeOnVersion("<1.0.1-0", "1.0.1", false),
		new TestForRangeOnVersion("<1.0.1-0", "1.0.1-0", false),
		new TestForRangeOnVersion("<1.0.1-0", "1.0.0", true),
		new TestForRangeOnVersion("<1.0.1-0", "1.0.0-0", true),
		new TestForRangeOnVersion("<1.0.1-0", "0.0.0", true),
		new TestForRangeOnVersion("<1.0.1-0", "0.0.0-0", true),
		new TestForRangeOnVersion("<1.0.0", "2.0.0", false),
		new TestForRangeOnVersion("<1.0.0", "2.0.0-0", false),
		new TestForRangeOnVersion("<1.0.0", "1.1.0", false),
		new TestForRangeOnVersion("<1.0.0", "1.1.0-0", false),
		new TestForRangeOnVersion("<1.0.0", "1.0.1", false),
		new TestForRangeOnVersion("<1.0.0", "1.0.1-0", false),
		new TestForRangeOnVersion("<1.0.0", "1.0.0", false),
		new TestForRangeOnVersion("<1.0.0", "1.0.0-0", true),
		new TestForRangeOnVersion("<1.0.0", "0.0.0", true),
		new TestForRangeOnVersion("<1.0.0", "0.0.0-0", true),
		new TestForRangeOnVersion("<1.0.0-0", "2.0.0", false),
		new TestForRangeOnVersion("<1.0.0-0", "2.0.0-0", false),
		new TestForRangeOnVersion("<1.0.0-0", "1.1.0", false),
		new TestForRangeOnVersion("<1.0.0-0", "1.1.0-0", false),
		new TestForRangeOnVersion("<1.0.0-0", "1.0.1", false),
		new TestForRangeOnVersion("<1.0.0-0", "1.0.1-0", false),
		new TestForRangeOnVersion("<1.0.0-0", "1.0.0", false),
		new TestForRangeOnVersion("<1.0.0-0", "1.0.0-0", false),
		new TestForRangeOnVersion("<1.0.0-0", "0.0.0", true),
		new TestForRangeOnVersion("<1.0.0-0", "0.0.0-0", true),

		// <= wildcard major (matches everything)
		new TestForRangeOnVersion("<=*", "2.0.0", true),
		new TestForRangeOnVersion("<=*", "2.0.0-0", true),
		new TestForRangeOnVersion("<=*", "1.1.0", true),
		new TestForRangeOnVersion("<=*", "1.1.0-0", true),
		new TestForRangeOnVersion("<=*", "1.0.1", true),
		new TestForRangeOnVersion("<=*", "1.0.1-0", true),
		new TestForRangeOnVersion("<=*", "1.0.0", true),
		new TestForRangeOnVersion("<=*", "1.0.0-0", true),
		new TestForRangeOnVersion("<=*", "0.0.0", true),
		new TestForRangeOnVersion("<=*", "0.0.0-0", true),

		// <= wildcard minor
		new TestForRangeOnVersion("<=1", "2.0.0", false),
		new TestForRangeOnVersion("<=1", "2.0.0-0", false),
		new TestForRangeOnVersion("<=1", "1.1.0", true),
		new TestForRangeOnVersion("<=1", "1.1.0-0", true),
		new TestForRangeOnVersion("<=1", "1.0.1", true),
		new TestForRangeOnVersion("<=1", "1.0.1-0", true),
		new TestForRangeOnVersion("<=1", "1.0.0", true),
		new TestForRangeOnVersion("<=1", "1.0.0-0", true),
		new TestForRangeOnVersion("<=1", "0.0.0", true),
		new TestForRangeOnVersion("<=1", "0.0.0-0", true),

		// <= wildcard patch
		new TestForRangeOnVersion("<=1.1", "2.0.0", false),
		new TestForRangeOnVersion("<=1.1", "2.0.0-0", false),
		new TestForRangeOnVersion("<=1.1", "1.1.0", true),
		new TestForRangeOnVersion("<=1.1", "1.1.0-0", true),
		new TestForRangeOnVersion("<=1.1", "1.0.1", true),
		new TestForRangeOnVersion("<=1.1", "1.0.1-0", true),
		new TestForRangeOnVersion("<=1.1", "1.0.0", true),
		new TestForRangeOnVersion("<=1.1", "1.0.0-0", true),
		new TestForRangeOnVersion("<=1.1", "0.0.0", true),
		new TestForRangeOnVersion("<=1.1", "0.0.0-0", true),
		new TestForRangeOnVersion("<=1.0", "2.0.0", false),
		new TestForRangeOnVersion("<=1.0", "2.0.0-0", false),
		new TestForRangeOnVersion("<=1.0", "1.1.0", false),
		new TestForRangeOnVersion("<=1.0", "1.1.0-0", false),
		new TestForRangeOnVersion("<=1.0", "1.0.1", true),
		new TestForRangeOnVersion("<=1.0", "1.0.1-0", true),
		new TestForRangeOnVersion("<=1.0", "1.0.0", true),
		new TestForRangeOnVersion("<=1.0", "1.0.0-0", true),
		new TestForRangeOnVersion("<=1.0", "0.0.0", true),
		new TestForRangeOnVersion("<=1.0", "0.0.0-0", true),

		// <= exact
		new TestForRangeOnVersion("<=1.1.0", "2.0.0", false),
		new TestForRangeOnVersion("<=1.1.0", "2.0.0-0", false),
		new TestForRangeOnVersion("<=1.1.0", "1.1.0", true),
		new TestForRangeOnVersion("<=1.1.0", "1.1.0-0", true),
		new TestForRangeOnVersion("<=1.1.0", "1.0.1", true),
		new TestForRangeOnVersion("<=1.1.0", "1.0.1-0", true),
		new TestForRangeOnVersion("<=1.1.0", "1.0.0", true),
		new TestForRangeOnVersion("<=1.1.0", "1.0.0-0", true),
		new TestForRangeOnVersion("<=1.1.0", "0.0.0", true),
		new TestForRangeOnVersion("<=1.1.0", "0.0.0-0", true),
		new TestForRangeOnVersion("<=1.1.0-0", "2.0.0", false),
		new TestForRangeOnVersion("<=1.1.0-0", "2.0.0-0", false),
		new TestForRangeOnVersion("<=1.1.0-0", "1.1.0", false),
		new TestForRangeOnVersion("<=1.1.0-0", "1.1.0-0", true),
		new TestForRangeOnVersion("<=1.1.0-0", "1.0.1", true),
		new TestForRangeOnVersion("<=1.1.0-0", "1.0.1-0", true),
		new TestForRangeOnVersion("<=1.1.0-0", "1.0.0", true),
		new TestForRangeOnVersion("<=1.1.0-0", "1.0.0-0", true),
		new TestForRangeOnVersion("<=1.1.0-0", "0.0.0", true),
		new TestForRangeOnVersion("<=1.1.0-0", "0.0.0-0", true),
		new TestForRangeOnVersion("<=1.0.1", "2.0.0", false),
		new TestForRangeOnVersion("<=1.0.1", "2.0.0-0", false),
		new TestForRangeOnVersion("<=1.0.1", "1.1.0", false),
		new TestForRangeOnVersion("<=1.0.1", "1.1.0-0", false),
		new TestForRangeOnVersion("<=1.0.1", "1.0.1", true),
		new TestForRangeOnVersion("<=1.0.1", "1.0.1-0", true),
		new TestForRangeOnVersion("<=1.0.1", "1.0.0", true),
		new TestForRangeOnVersion("<=1.0.1", "1.0.0-0", true),
		new TestForRangeOnVersion("<=1.0.1", "0.0.0", true),
		new TestForRangeOnVersion("<=1.0.1", "0.0.0-0", true),
		new TestForRangeOnVersion("<=1.0.1-0", "2.0.0", false),
		new TestForRangeOnVersion("<=1.0.1-0", "2.0.0-0", false),
		new TestForRangeOnVersion("<=1.0.1-0", "1.1.0", false),
		new TestForRangeOnVersion("<=1.0.1-0", "1.1.0-0", false),
		new TestForRangeOnVersion("<=1.0.1-0", "1.0.1", false),
		new TestForRangeOnVersion("<=1.0.1-0", "1.0.1-0", true),
		new TestForRangeOnVersion("<=1.0.1-0", "1.0.0", true),
		new TestForRangeOnVersion("<=1.0.1-0", "1.0.0-0", true),
		new TestForRangeOnVersion("<=1.0.1-0", "0.0.0", true),
		new TestForRangeOnVersion("<=1.0.1-0", "0.0.0-0", true),
		new TestForRangeOnVersion("<=1.0.0", "2.0.0", false),
		new TestForRangeOnVersion("<=1.0.0", "2.0.0-0", false),
		new TestForRangeOnVersion("<=1.0.0", "1.1.0", false),
		new TestForRangeOnVersion("<=1.0.0", "1.1.0-0", false),
		new TestForRangeOnVersion("<=1.0.0", "1.0.1", false),
		new TestForRangeOnVersion("<=1.0.0", "1.0.1-0", false),
		new TestForRangeOnVersion("<=1.0.0", "1.0.0", true),
		new TestForRangeOnVersion("<=1.0.0", "1.0.0-0", true),
		new TestForRangeOnVersion("<=1.0.0", "0.0.0", true),
		new TestForRangeOnVersion("<=1.0.0", "0.0.0-0", true),
		new TestForRangeOnVersion("<=1.0.0-0", "2.0.0", false),
		new TestForRangeOnVersion("<=1.0.0-0", "2.0.0-0", false),
		new TestForRangeOnVersion("<=1.0.0-0", "1.1.0", false),
		new TestForRangeOnVersion("<=1.0.0-0", "1.1.0-0", false),
		new TestForRangeOnVersion("<=1.0.0-0", "1.0.1", false),
		new TestForRangeOnVersion("<=1.0.0-0", "1.0.1-0", false),
		new TestForRangeOnVersion("<=1.0.0-0", "1.0.0", false),
		new TestForRangeOnVersion("<=1.0.0-0", "1.0.0-0", true),
		new TestForRangeOnVersion("<=1.0.0-0", "0.0.0", true),
		new TestForRangeOnVersion("<=1.0.0-0", "0.0.0-0", true),

		// https://github.com/microsoft/TypeScript/issues/50909
		new TestForRangeOnVersion(">4.8", "4.9.0-beta", true),
		new TestForRangeOnVersion(">=4.9", "4.9.0-beta", true),
		new TestForRangeOnVersion("<4.9", "4.9.0-beta", false),
		new TestForRangeOnVersion("<=4.8", "4.9.0-beta", false),
	];

	static final TestConjunctionsOfVersionRangesRows:Array<TestForRangeOnVersion> = [
		new TestForRangeOnVersion(">1.0.0 <2.0.0", "1.0.1", true),
		new TestForRangeOnVersion(">1.0.0 <2.0.0", "2.0.0", false),
		new TestForRangeOnVersion(">1.0.0 <2.0.0", "1.0.0", false),
		new TestForRangeOnVersion(">1 >2", "3.0.0", true),
	];

	static final TestDisjunctionsOfVersionRangesRows:Array<TestForRangeOnVersion> = [
		new TestForRangeOnVersion(">1.0.0 || <1.0.0", "1.0.1", true),
		new TestForRangeOnVersion(">1.0.0 || <1.0.0", "0.0.1", true),
		new TestForRangeOnVersion(">1.0.0 || <1.0.0", "1.0.0", false),
		new TestForRangeOnVersion(">1.0.0 || <1.0.0", "0.0.0", true),
		new TestForRangeOnVersion(">=1.0.0 <2.0.0 || >=3.0.0 <4.0.0", "1.0.0", true),
		new TestForRangeOnVersion(">=1.0.0 <2.0.0 || >=3.0.0 <4.0.0", "2.0.0", false),
		new TestForRangeOnVersion(">=1.0.0 <2.0.0 || >=3.0.0 <4.0.0", "3.0.0", true),
	];

	static final TestHyphensOfVersionRangesRows:Array<TestForRangeOnVersion> = [
		new TestForRangeOnVersion("1.0.0 - 2.0.0", "1.0.0", true),
		new TestForRangeOnVersion("1.0.0 - 2.0.0", "1.0.1", true),
		new TestForRangeOnVersion("1.0.0 - 2.0.0", "2.0.0", true),
		new TestForRangeOnVersion("1.0.0 - 2.0.0", "2.0.1", false),
		new TestForRangeOnVersion("1.0.0 - 2.0.0", "0.9.9", false),
		new TestForRangeOnVersion("1.0.0 - 2.0.0", "3.0.0", false),
	];

	static final TestTildesOfVersionRangesRows:Array<TestForRangeOnVersion> = [
		new TestForRangeOnVersion("~0", "0.0.0", true),
		new TestForRangeOnVersion("~0", "0.1.0", true),
		new TestForRangeOnVersion("~0", "0.1.2", true),
		new TestForRangeOnVersion("~0", "0.1.9", true),
		new TestForRangeOnVersion("~0", "1.0.0", false),
		new TestForRangeOnVersion("~0.1", "0.1.0", true),
		new TestForRangeOnVersion("~0.1", "0.1.2", true),
		new TestForRangeOnVersion("~0.1", "0.1.9", true),
		new TestForRangeOnVersion("~0.1", "0.2.0", false),
		new TestForRangeOnVersion("~0.1.2", "0.1.2", true),
		new TestForRangeOnVersion("~0.1.2", "0.1.9", true),
		new TestForRangeOnVersion("~0.1.2", "0.2.0", false),
		new TestForRangeOnVersion("~1.0.0", "1.0.0", true),
		new TestForRangeOnVersion("~1.0.0", "1.0.1", true),
		new TestForRangeOnVersion("~1", "1.0.0", true),
		new TestForRangeOnVersion("~1", "1.2.0", true),
		new TestForRangeOnVersion("~1", "1.2.3", true),
		new TestForRangeOnVersion("~1", "0.0.0", false),
		new TestForRangeOnVersion("~1", "2.0.0", false),
		new TestForRangeOnVersion("~1.2", "1.2.0", true),
		new TestForRangeOnVersion("~1.2", "1.2.3", true),
		new TestForRangeOnVersion("~1.2", "1.1.0", false),
		new TestForRangeOnVersion("~1.2", "1.3.0", false),
		new TestForRangeOnVersion("~1.2.3", "1.2.3", true),
		new TestForRangeOnVersion("~1.2.3", "1.2.9", true),
		new TestForRangeOnVersion("~1.2.3", "1.1.0", false),
		new TestForRangeOnVersion("~1.2.3", "1.3.0", false),
	];

	static final TestCaretsOfVersionRangesRows:Array<TestForRangeOnVersion> = [
		new TestForRangeOnVersion("^0", "0.0.0", true),
		new TestForRangeOnVersion("^0", "0.1.0", true),
		new TestForRangeOnVersion("^0", "0.9.0", true),
		new TestForRangeOnVersion("^0", "0.1.2", true),
		new TestForRangeOnVersion("^0", "0.1.9", true),
		new TestForRangeOnVersion("^0", "1.0.0", false),
		new TestForRangeOnVersion("^0.1", "0.1.0", true),
		new TestForRangeOnVersion("^0.1", "0.1.2", true),
		new TestForRangeOnVersion("^0.1", "0.1.9", true),
		new TestForRangeOnVersion("^0.1.2", "0.1.2", true),
		new TestForRangeOnVersion("^0.1.2", "0.1.9", true),
		new TestForRangeOnVersion("^0.1.2", "0.0.0", false),
		new TestForRangeOnVersion("^0.1.2", "0.2.0", false),
		new TestForRangeOnVersion("^0.1.2", "1.0.0", false),
		new TestForRangeOnVersion("^1", "1.0.0", true),
		new TestForRangeOnVersion("^1", "1.2.0", true),
		new TestForRangeOnVersion("^1", "1.2.3", true),
		new TestForRangeOnVersion("^1", "1.9.0", true),
		new TestForRangeOnVersion("^1", "0.0.0", false),
		new TestForRangeOnVersion("^1", "2.0.0", false),
		new TestForRangeOnVersion("^1.2", "1.2.0", true),
		new TestForRangeOnVersion("^1.2", "1.2.3", true),
		new TestForRangeOnVersion("^1.2", "1.9.0", true),
		new TestForRangeOnVersion("^1.2", "1.1.0", false),
		new TestForRangeOnVersion("^1.2", "2.0.0", false),
		new TestForRangeOnVersion("^1.2.3", "1.2.3", true),
		new TestForRangeOnVersion("^1.2.3", "1.9.0", true),
		new TestForRangeOnVersion("^1.2.3", "1.2.2", false),
		new TestForRangeOnVersion("^1.2.3", "2.0.0", false),
	];

}

private class TestGoodBad {
	public final good:Array<String>;
	public final bad:Array<String>;

	public function new(good:Array<String>, bad:Array<String>) {
		this.good = good;
		this.bad = bad;
	}
}

private class TestForRangeOnVersion {
	public final rangeText:String;
	public final versionText:String;
	public final expected:Bool;

	public function new(rangeText:String, versionText:String, expected:Bool) {
		this.rangeText = rangeText;
		this.versionText = versionText;
		this.expected = expected;
	}
}
