package ts.execute.tsctests;

import sys.FileSystem;
import sys.io.File;

// Gate main (not in Go): runs the ported tsc scenarios (TscTest, ShowconfigTest, TscbuildTest) and compares
// each baseline byte for byte with upstream/tsc/testdata/baselines/reference/<tsc|tsbuild/...>.
// Usage: TscGate [--case <substring>] [--sample N] [--local <dir>]
// --sample N: only every N-th scenario (scenarios 0, N, 2N, ... in run order, after --case).
// Prints one line per scenario: `PASS|FAIL|CRASH <tsc/scenario/file.js>` and writes the actual
// baselines to <local>/<path> (default bin/execute/local).
class TscGate {
	static var local = "bin/execute/local";
	static final reference = T.UPSTREAM + "/testdata/baselines/reference";

	static function main() {
		final args = Sys.args();
		var i = 0;
		var caseFilter:Null<String> = null;
		var sample = 1;
		while (i < args.length) {
			switch (args[i]) {
				case "--case":
					caseFilter = args[++i];
				case "--sample":
					sample = Std.parseInt(args[++i]);
				case "--local":
					local = args[++i];
				default:
					Sys.println("unknown argument " + args[i]);
					Sys.exit(2);
			}
			i++;
		}
		if (caseFilter != null || sample > 1) {
			final f = caseFilter;
			var k = 0;
			Gate.Filter = function(name:String):Bool {
				if (f != null) {
					final file = Strings.ReplaceAll(name, " ", "-");
					if (name.indexOf(f) < 0 && file.indexOf(f) < 0)
						return false;
				}
				return k++ % sample == 0;
			};
		}
		var pass = 0, fail = 0, crash = 0;
		final errored = new StringMap<Bool>();
		Gate.OnBaseline = function(path:String, actual:String) {
			final localPath = local + "/" + path;
			ensureDirectory(haxe.io.Path.directory(localPath));
			File.saveContent(localPath, actual);
			final refPath = reference + "/" + path;
			final expected = FileSystem.exists(refPath) ? File.getContent(refPath) : null;
			if (expected == actual) {
				pass++;
				Sys.println("PASS " + path);
			} else {
				fail++;
				Sys.println("FAIL " + path + (expected == null ? " (no reference)" : ""));
			}
		};
		Gate.OnError = function(path:String, msg:String) {
			errored.set(path, true);
			Sys.println("ERROR " + path + ": " + msg.split("\n")[0]);
		};
		Gate.OnCrash = function(name:String, path:String, err:String, partial:String) {
			crash++;
			final localPath = local + "/" + path;
			ensureDirectory(haxe.io.Path.directory(localPath));
			File.saveContent(localPath, partial + "\n\n!!! CRASH: " + err);
			final firstLine = err.split("\n")[0];
			Sys.println("CRASH " + path + ": " + (firstLine.length > 200 ? firstLine.substr(0, 200) : firstLine));
		};
		TscTest.run();
		ShowconfigTest.run();
		TscbuildTest.run();
		Sys.println('SUMMARY pass=$pass fail=$fail crash=$crash');
		Sys.exit(fail == 0 && crash == 0 ? 0 : 1);
	}

	static function ensureDirectory(dir:String):Void {
		if (dir != "" && !FileSystem.exists(dir))
			FileSystem.createDirectory(dir);
	}
}
