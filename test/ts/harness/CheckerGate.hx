package ts.harness;

import go.Testing.T;
import ts.testrunner.Testrunner;
import ts.testrunner.CompilerRunner;
import ts.testutil.baseline.Baseline;
import ts.testutil.harnessutil.Harnessutil;

// Checker gate (Phase 7): runs the ported compiler-runner logic (internal/testrunner, submodule mode)
// over the TypeScript test corpus (tests/cases/compiler and tests/cases/conformance) and compares the
// .errors.txt, .types and .symbols baselines with upstream/tsc/testdata/baselines/reference/submodule.
//
// Usage: CheckerGate [--out DIR] [--case NAME]... [--filter SUBSTR] [--limit N] [--tolerate-emit-crash]
//   --case NAME     only the test file NAME (basename with or without .ts/.tsx); repeatable
//   --filter S      only test files whose path contains S
//   --limit N       at most N test files
//   --tolerate-emit-crash  an exception in Program.Emit does not fail the case (empty emit result)
//
// Output (stdout): per kind (errors/types/symbols) the number of cases (= test configurations) and
// passed/failed/crashed/skipped. DIR/results.txt has one line per case and kind:
//   <kind> <status> <suite>/<configured name> <detail>
// where detail is the first differing line (fail) or the first line of the panic (crash).
class CheckerGate {
	static final kinds = ["errors", "types", "symbols"];
	static final subtestOfKind = ["errors" => "error", "types" => "type", "symbols" => "symbol"];
	static final extOfKind = ["errors" => ".errors.txt", "types" => ".types", "symbols" => ".symbols"];

	static var compareLog:Array<{reference:String, local:String, actual:String, matched:Bool}> = [];

	static function main() {
		var out = "bin/gate-checker/out";
		final cases:Array<String> = [];
		var filter:Null<String> = null;
		var limit = -1;
		final args = Sys.args();
		var i = 0;
		while (i < args.length) {
			switch (args[i]) {
				case "--out":
					out = args[++i];
				case "--case":
					cases.push(args[++i]);
				case "--filter":
					filter = args[++i];
				case "--limit":
					limit = Std.parseInt(args[++i]);
				case "--tolerate-emit-crash":
					Harnessutil.TolerateEmitCrash = true;
				default:
					Sys.println("unknown argument " + args[i]);
					Sys.exit(2);
			}
			i++;
		}
		mkdirs(out);
		Baseline.LocalRoot = out + "/local";
		Baseline.OnCompare = function(reference, local, actual, matched) {
			compareLog.push({reference: reference, local: local, actual: actual, matched: matched});
		};

		final results = new StringBuf();
		final counts = new Map<String, Map<String, Int>>();
		for (k in kinds)
			counts.set(k, ["pass" => 0, "fail" => 0, "crash" => 0, "skip" => 0]);
		var configCount = 0;
		var fileCount = 0;
		final t0 = haxe.Timer.stamp();

		final runners = [
			Testrunner.NewCompilerBaselineRunner(TestTypeRegression, true),
			Testrunner.NewCompilerBaselineRunner(TestTypeConformance, true)
		];
		for (runner in runners) {
			final suite = runner.TestSuitName();
			for (filename in runner.EnumerateTestFiles()) {
				final base = ts.tspath.Tspath.GetBaseFileName(filename);
				if (Testrunner.skippedTests.indexOf(base) >= 0)
					continue;
				if (cases.length > 0 && !caseMatches(cases, base))
					continue;
				if (filter != null && filename.indexOf(filter) < 0)
					continue;
				if (limit >= 0 && fileCount >= limit)
					break;
				fileCount++;

				final root = new T("");
				try {
					runner.runTest(root, filename);
				} catch (e:Dynamic) {
					// A panic outside the per-configuration recover (e.g. reading the test options).
					final c = new T(base, root);
					root.children.push(c);
					c.panicked = true;
					c.failed = true;
					c.messages.push("panic: " + Std.string(e));
				}
				// Bound memory: keep only the lib files in the source file cache (see ClearSourceFileCache).
				Harnessutil.ClearSourceFileCache(function(f) return StringTools.startsWith(f, "bundled:///") || StringTools.startsWith(f, "/.lib/"));

				// Go map order decides the configuration order; sort for a stable results file.
				final configs = root.children.copy();
				configs.sort((a, b) -> go.Strings.Compare(a.ShortName(), b.ShortName()));
				for (config in configs) {
					configCount++;
					final configuredName = configuredNameOf(base, config.ShortName());
					for (kind in kinds) {
						var status:String;
						var detail = "";
						final sub = Lambda.find(config.children, function(c) return c.ShortName() == subtestOfKind[kind]);
						if (sub == null) {
							if (config.skipped && !config.failed) {
								status = "skip";
								detail = firstLine(config.messages);
							} else if (config.failed) {
								status = "crash";
								detail = firstLine(config.messages);
							} else {
								// e.g. @noTypesAndSymbols: no baseline of this kind
								status = "skip";
								detail = "no baseline";
							}
						} else if (sub.panicked) {
							status = "crash";
							detail = firstLine(sub.messages);
						} else if (sub.failed) {
							status = "fail";
							detail = firstDiff(configuredName, kind, sub);
						} else {
							status = "pass";
						}
						counts.get(kind).set(status, counts.get(kind).get(status) + 1);
						if (cases.length > 0 && status == "crash") {
							final msgs = sub == null ? config.messages : sub.messages;
							Sys.println("---- " + kind + " crash " + configuredName + ":\n" + msgs.join("\n"));
						}
						results.add(kind + " " + status + " " + suite + "/" + configuredName + (detail == "" ? "" : " " + oneLine(detail)) + "\n");
					}
				}
				compareLog = [];
			}
		}

		sys.io.File.saveContent(out + "/results.txt", results.toString());
		final secs = Std.int(haxe.Timer.stamp() - t0);
		Sys.println('test files: $fileCount, cases (configurations): $configCount, ${secs}s');
		Sys.println(pad("kind", 8) + pad("cases", 7) + pad("pass", 7) + pad("fail", 7) + pad("crash", 7) + pad("skip", 7));
		for (k in kinds) {
			final c = counts.get(k);
			Sys.println(pad(k, 8) + pad("" + configCount, 7) + pad("" + c.get("pass"), 7) + pad("" + c.get("fail"), 7) + pad("" + c.get("crash"), 7)
				+ pad("" + c.get("skip"), 7));
		}
	}

	static function caseMatches(cases:Array<String>, base:String):Bool {
		for (c in cases) {
			if (c == base || c + ".ts" == base || c + ".tsx" == base)
				return true;
		}
		return false;
	}

	// The subtest is named "<basename> <config>" (Go t.Run name); the baseline name is "<name>(<config>).<ext>".
	static function configuredNameOf(base:String, testName:String):String {
		if (testName == base)
			return base;
		final config = testName.substring(base.length + 1);
		final dot = base.lastIndexOf(".");
		return base.substring(0, dot) + "(" + config + ")" + base.substring(dot);
	}

	static function firstDiff(configuredName:String, kind:String, sub:T):String {
		final ext = extOfKind[kind];
		for (c in compareLog) {
			if (!c.matched && StringTools.endsWith(c.reference, ext)) {
				final expected = sys.FileSystem.exists(c.reference) ? sys.io.File.getContent(c.reference) : Baseline.NoContent;
				final a = expected.split("\n");
				final b = c.actual.split("\n");
				var n = 0;
				while (n < a.length && n < b.length && a[n] == b[n])
					n++;
				final ea = n < a.length ? a[n] : "<EOF>";
				final eb = n < b.length ? b[n] : "<EOF>";
				return 'line ${n + 1}: expected «${ea}» got «${eb}»';
			}
		}
		return firstLine(sub.messages);
	}

	static function firstLine(msgs:Array<String>):String {
		if (msgs.length == 0)
			return "";
		final m = msgs[0];
		final i = m.indexOf("\n");
		var s = i < 0 ? m : m.substring(0, i);
		// RecoverAndFail: "Panic on ...:\n<value>\n<stack>": report the value
		if (StringTools.startsWith(s, "Panic on") && i >= 0) {
			final rest = m.substring(i + 1);
			final j = rest.indexOf("\n");
			s = j < 0 ? rest : rest.substring(0, j);
			// add the innermost frame of the stack (if any)
			for (l in rest.split("\n")) {
				final k = l.indexOf("Called from ");
				if (k >= 0 && l.indexOf("Called from module") < 0 && l.indexOf("haxe_") < 0 && l.indexOf("haxe.") < 0) {
					var f = l.substring(k + "Called from ".length);
					final p = f.indexOf(" (");
					if (p >= 0)
						f = f.substring(0, p);
					s += " @ " + f;
					break;
				}
			}
		}
		return s;
	}

	static function oneLine(s:String):String {
		s = StringTools.replace(s, "\r", "\\r");
		s = StringTools.replace(s, "\n", "\\n");
		return s.length > 300 ? s.substring(0, 300) + "..." : s;
	}

	static function pad(s:String, n:Int):String {
		while (s.length < n)
			s += " ";
		return s;
	}

	static function mkdirs(dir:String) {
		if (!sys.FileSystem.exists(dir))
			sys.FileSystem.createDirectory(dir);
	}
}
