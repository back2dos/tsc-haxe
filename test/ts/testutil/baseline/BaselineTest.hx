package ts.testutil.baseline;

import ts.repo.Repo;

// Port of baseline_test.go.
// PORT: submoduleAcceptedFileNames / submoduleTriagedFileNames (readFileNameSet) are inlined here:
// the .diff baselines are not compared by the port (see Baseline.hx).
class BaselineTest {
	static function readFileNameSet(path:String):Array<String> {
		final set:Array<String> = [];
		for (line0 in sys.io.File.getContent(path).split("\n")) {
			final line = StringTools.trim(line0);
			if (line == "" || line.charAt(0) == "#")
				continue;
			set.push(line);
		}
		return set;
	}

	public static function run() {
		final referenceRoot = Repo.TestDataPath() + "/baselines/reference";
		T.run("TestSubmoduleAcceptedFilesExist", () -> {
			for (name in readFileNameSet(Repo.TestDataPath() + "/submoduleAccepted.txt")) {
				T.isTrue(sys.FileSystem.exists(referenceRoot + "/submoduleAccepted/" + name),
					'submoduleAccepted.txt references "$name", but the baseline file does not exist');
			}
		});
		T.run("TestSubmoduleTriagedFilesExist", () -> {
			for (name in readFileNameSet(Repo.TestDataPath() + "/submoduleTriaged.txt")) {
				T.isTrue(sys.FileSystem.exists(referenceRoot + "/submoduleTriaged/" + name),
					'submoduleTriaged.txt references "$name", but the baseline file does not exist');
			}
		});
	}
}
