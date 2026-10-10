package ts.testutil.baseline;

import go.Testing.T;
import ts.repo.Repo;

// Port of internal/testutil/baseline/baseline.go (the comparison against the reference baselines).
// PORT: the submodule `.diff` baselines (getBaselineDiff, patience diff) are not ported. When the
// main baseline equals the reference, its diff against the TypeScript submodule baseline equals the
// reference .diff as well, so the comparison of the main baseline decides the result. The lists
// submoduleAccepted.txt / submoduleTriaged.txt only choose the folder of that .diff file.
// PORT: testmain.go (baseline tracking via TSGO_BASELINE_TRACKING_DIR) is not ported.
class Baseline {
	public static inline final NoContent = "<no content>";

	// PORT: Go writes local baselines to testdata/baselines/local; here to LocalRoot (never into upstream/).
	public static var LocalRoot:String = "bin/gate-checker/local";

	// PORT: gate hook (not in Go): called for every compared baseline with (referencePath, localPath, matched).
	public static var OnCompare:Null<(reference:String, local:String, actual:String, matched:Bool) -> Void> = null;

	public static function Run(t:T, fileName:String, actual:String, opts:Options):Void {
		final origSubfolder = opts.Subfolder;

		{
			var subfolder = opts.Subfolder;
			if (opts.IsSubmodule) {
				subfolder = "submodule/" + subfolder;
			}

			final localPath = LocalRoot + "/" + subfolder + "/" + fileName;
			final referencePath = referenceRoot() + "/" + subfolder + "/" + fileName;

			writeComparison(t, actual, localPath, referencePath, false);
		}

		if (!opts.IsSubmodule || opts.SkipDiffWithOld) {
			// Not a submodule, no diffs.
			return;
		}
		// PORT: the .diff comparison is not ported (see the header).
	}

	static function readFileOrNoContent(fileName:String):String {
		if (!sys.FileSystem.exists(fileName))
			return NoContent;
		return sys.io.File.getContent(fileName);
	}

	public static function RunAgainstSubmodule(t:T, fileName:String, actual:String, opts:Options):Void {
		final local = LocalRoot + "/" + opts.Subfolder + "/" + fileName;
		final reference = submoduleReferenceRoot() + "/" + opts.Subfolder + "/" + fileName;
		writeComparison(t, actual, local, reference, true);
	}

	static function writeComparison(t:T, actualContent:String, local:String, reference:String, comparingAgainstSubmodule:Bool):Void {
		if (actualContent == "") {
			throw "the generated content was \"\". Return 'baseline.NoContent' if no baselining is required.";
		}

		if (sys.FileSystem.exists(local)) {
			sys.FileSystem.deleteFile(local);
		}
		if (sys.FileSystem.exists(local + ".delete")) {
			sys.FileSystem.deleteFile(local + ".delete");
		}

		var expected = NoContent;
		var foundExpected = false;
		if (sys.FileSystem.exists(reference) && !sys.FileSystem.isDirectory(reference)) {
			expected = sys.io.File.getContent(reference);
			foundExpected = true;
		}

		final mismatch = expected != actualContent || actualContent == NoContent && foundExpected;
		if (OnCompare != null) {
			OnCompare(reference, local, actualContent, !mismatch);
		}
		if (mismatch) {
			ensureDirectory(haxe.io.Path.directory(local));
			if (actualContent == NoContent) {
				sys.io.File.saveContent(local + ".delete", "");
			} else {
				sys.io.File.saveContent(local, actualContent);
			}

			if (!foundExpected) {
				if (comparingAgainstSubmodule) {
					t.Errorf("the baseline file %s does not exist in the TypeScript submodule", reference);
				} else {
					t.Errorf("new baseline created at %s.", local);
				}
			} else if (comparingAgainstSubmodule) {
				t.Errorf("the baseline file %s does not match the reference in the TypeScript submodule", reference);
			} else {
				t.Errorf("the baseline file %s has changed. (Run `hereby baseline-accept` if the new baseline is correct.)", reference);
			}
		}
	}

	static function ensureDirectory(dir:String):Void {
		if (dir != "" && !sys.FileSystem.exists(dir)) {
			sys.FileSystem.createDirectory(dir);
		}
	}

	static function referenceRoot():String {
		return Repo.TestDataPath() + "/baselines/reference";
	}

	static function submoduleReferenceRoot():String {
		return Repo.TypeScriptSubmodulePath() + "/tests/baselines/reference";
	}
}

class Options {
	public var Subfolder:String = "";
	public var IsSubmodule:Bool = false;
	public var IsSubmoduleAccepted:Bool = false;
	public var IsSubmoduleTriaged:Bool = false;
	public var DiffFixupOld:(String) -> String = null;
	public var DiffFixupNew:(String) -> String = null;
	public var SkipDiffWithOld:Bool = false;

	public function new(Subfolder:String = "", IsSubmodule:Bool = false) {
		this.Subfolder = Subfolder;
		this.IsSubmodule = IsSubmodule;
	}

	// PORT: Go value struct; copy before mutating a copy (PORTING.md §3).
	public function copy():Options {
		final r = new Options(Subfolder, IsSubmodule);
		r.IsSubmoduleAccepted = IsSubmoduleAccepted;
		r.IsSubmoduleTriaged = IsSubmoduleTriaged;
		r.DiffFixupOld = DiffFixupOld;
		r.DiffFixupNew = DiffFixupNew;
		r.SkipDiffWithOld = SkipDiffWithOld;
		return r;
	}
}
