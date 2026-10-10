package ts.glob;

import ts.glob.Glob;

// No upstream glob_test.go. Tests derived from the documented behaviour in glob.go.
// Expected values were produced by running upstream glob.go (Go 1.26) on the same inputs.
class GlobTest {
	public static function run() {
		T.run("TestParse", TestParse);
		T.run("TestMatch", TestMatch);
	}

	static function TestParse() {
		final tests:Array<{p:String, s:Null<String>, err:Null<String>}> = [
			{p: "", s: "", err: null},
			{p: "a/b", s: "a/b", err: null},
			{p: "**/*.{ts,js}", s: "**/*.{ts,js}", err: null},
			{p: "a**", s: null, err: "** may only be adjacent to '/'"},
			{p: "**b", s: null, err: "** may only be adjacent to '/'"},
			{p: "a/**/b", s: "a/**/b", err: null},
			{p: "{a,b", s: null, err: "unmatched '{'"},
			{p: "{a,{b,c}}", s: "{a,{b,c}}", err: null},
			{p: "x[a-z]y", s: "x[a-z]y", err: null},
			{p: "[!0-9]", s: "[0-9]", err: null},
			{p: "[a]", s: null, err: "'[' patterns must be of the form [x-y]"},
			{p: "[", s: null, err: "'[' patterns must be of the form [x-y]"},
			{p: "[a-", s: null, err: "'[' patterns must be of the form [x-y]"},
			{p: "[a-b", s: null, err: "'[' patterns must be of the form [x-y]"},
			{p: "a}b,c", s: "a}b,c", err: null},
			{p: "{}", s: "{}", err: null},
			{p: "a//b", s: "a//b", err: null},
			{p: "*?", s: "*?", err: null},
			{p: "[é-😀]", s: "[é-😀]", err: null},
		];
		for (test in tests) {
			final r = Glob.Parse(test.p);
			if (test.err != null) {
				T.isTrue(r.err != null, test.p + ": expected error");
				if (r.err != null)
					T.eq(test.err, r.err.Error());
			} else {
				T.isTrue(r.err == null, test.p + ": unexpected error " + (r.err == null ? "" : r.err.Error()));
				if (r.err == null)
					T.eq(test.s, r.value.String());
			}
		}
	}

	static function TestMatch() {
		// "panic: ..." is the Go runtime panic of upstream (index out of range in the slash case).
		final tests:Array<{p:String, i:String, want:String}> = [
			{p: "**/*.ts", i: "a/b/c.ts", want: "true"},
			{p: "**/*.ts", i: "c.ts", want: "true"},
			{p: "**/*.ts", i: "a/b/c.js", want: "false"},
			{p: "**/", i: "anything/here", want: "true"},
			{p: "**", i: "x/y", want: "true"},
			{p: "src/**/*.{ts,js}", i: "src/a/b.js", want: "true"},
			{p: "src/**/*.{ts,js}", i: "src/b.ts", want: "true"},
			{p: "src/**/*.{ts,js}", i: "src/b.tsx", want: "false"},
			{p: "a/*", i: "a/b", want: "true"},
			{p: "a/*", i: "a/b/c", want: "false"},
			{p: "a/*", i: "a", want: "false"},
			{p: "a/*", i: "a/", want: "panic: runtime error: index out of range [0] with length 0"},
			{p: "a/b", i: "a//b", want: "true"},
			{p: "a/b", i: "a/b/", want: "false"},
			{p: "*.ts", i: "foo.ts", want: "true"},
			{p: "*.ts", i: ".ts", want: "true"},
			{p: "*.ts", i: "dir/foo.ts", want: "false"},
			{p: "*", i: "", want: "true"},
			{p: "*", i: "abc", want: "true"},
			{p: "?", i: "a", want: "true"},
			{p: "?", i: "/", want: "false"},
			{p: "?", i: "", want: "false"},
			{p: "a?c", i: "abc", want: "true"},
			{p: "a?c", i: "ac", want: "false"},
			{p: "x[0-9]", i: "x5", want: "true"},
			{p: "x[0-9]", i: "xa", want: "false"},
			{p: "x[!0-9]", i: "x5", want: "true"},
			{p: "x[!0-9]", i: "xa", want: "false"},
			{p: "[a-c]", i: "/", want: "false"},
			{p: "{a,b}/c", i: "a/c", want: "true"},
			{p: "{a,b}/c", i: "b/c", want: "true"},
			{p: "{a,b}/c", i: "d/c", want: "false"},
			{p: "{a,{b,c}}", i: "c", want: "true"},
			{p: "/a", i: "//a", want: "true"},
			{p: "a/**/b", i: "a/b", want: "true"},
			{p: "a/**/b", i: "a/x/y/b", want: "true"},
			{p: "a/**/b", i: "a/x/y/c", want: "false"},
		];
		for (test in tests) {
			final r = Glob.Parse(test.p);
			T.isTrue(r.err == null, test.p);
			var got:String;
			try {
				got = Std.string(r.value.Match(test.i));
			} catch (e:Dynamic) {
				got = "panic: " + Std.string(e);
			}
			if (got != test.want)
				T.fail('Match(${test.p}, ${test.i}): expected <${test.want}> got <$got>');
			else
				T.eq(test.want, got);
		}
	}
}
