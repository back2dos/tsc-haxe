package ts.execute.tsc;

import ts.execute.tsc.Extendedconfigcache.ExtendedConfigCache;
import ts.tsoptions.Parsedcommandline.ParsedCommandLine;
import ts.tsoptions.Tsoptions;
import ts.tspath.Tspath;
import ts.vfs.Vfs.FS;
import ts.vfs.vfstest.Vfstest.Vfstest;

// Port of internal/execute/tsc/extendedconfigcache_test.go.

class ExtendedconfigcacheTest {
	public static function run() {
		TestExtendedConfigCacheExtendsCircularity();
		TestExtendedConfigCacheNullExtendsDoesNotPanic();
	}

	// PORT: the setup each Go subtest repeats (as in TypeScript main: NewDefaultParseConfigHost, no test host).
	static function parse(files:Map<String, Any>):ParsedCommandLine {
		final fs = Vfstest.FromMap(files, CaseInsensitive);
		final cache = new ExtendedConfigCache();
		return Tsoptions.GetParsedCommandLineOfConfigFile(Tspath.RootedFilePathFromNormalized("/project/tsconfig.json"), null, null,
			Tsoptions.NewDefaultParseConfigHost(fs), cache).a;
	}

	static function TestExtendedConfigCacheExtendsCircularity() {
		T.run("TestExtendedConfigCacheExtendsCircularity/self-referencing extends", function() {
			// Regression test: a tsconfig extends cycle should produce an error,
			// not a deadlock when using the tsc ExtendedConfigCache.
			final cmd = parse([
				"/project/tsconfig.json" => "{\"extends\": \"./base.json\"}",
				"/project/base.json" => "{\"extends\": \"./base.json\"}",
				"/project/main.ts" => "// Hello World!",
			]);
			T.isTrue(cmd != null, "expected non-nil ParsedCommandLine");
			assertHasCircularityDiagnostic(cmd);
		});

		T.run("TestExtendedConfigCacheExtendsCircularity/mutual extends cycle", function() {
			// Two config files that extend each other.
			final cmd = parse([
				"/project/tsconfig.json" => "{\"extends\": \"./other.json\"}",
				"/project/other.json" => "{\"extends\": \"./tsconfig.json\"}",
				"/project/main.ts" => "// Hello World!",
			]);
			T.isTrue(cmd != null, "expected non-nil ParsedCommandLine");
			assertHasCircularityDiagnostic(cmd);
		});

		T.run("TestExtendedConfigCacheExtendsCircularity/case-insensitive self-referencing extends", function() {
			// On a case-insensitive FS, ./Base.json and ./base.json resolve to the same
			// cache entry. The cycle check must use canonical paths to avoid deadlock.
			final cmd = parse([
				"/project/tsconfig.json" => "{\"extends\": \"./Base.json\"}",
				"/project/base.json" => "{\"extends\": \"./base.json\"}",
				"/project/main.ts" => "// Hello World!",
			]);
			T.isTrue(cmd != null, "expected non-nil ParsedCommandLine");
			assertHasCircularityDiagnostic(cmd);
		});
	}

	static function TestExtendedConfigCacheNullExtendsDoesNotPanic() {
		T.run("TestExtendedConfigCacheNullExtendsDoesNotPanic", function() {
			final cmd = parse([
				"/project/tsconfig.json" => "{\"extends\": null}",
				"/project/main.ts" => "// Hello World!",
			]);
			T.isTrue(cmd != null, "expected non-nil ParsedCommandLine");
			T.isTrue(cmd.Errors != null && cmd.Errors.length != 0, "expected diagnostics for invalid null extends");
		});
	}

	static function assertHasCircularityDiagnostic(cmd:ParsedCommandLine) {
		if (cmd == null)
			return;
		if (cmd.Errors != null) {
			for (d in cmd.Errors) {
				if (d != null && d.Code() == 18000) {
					T.isTrue(true);
					return;
				}
			}
		}
		T.fail("expected circularity diagnostic (code 18000), but none was found");
	}
}
