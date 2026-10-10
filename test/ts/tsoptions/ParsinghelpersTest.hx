package ts.tsoptions;

// Port of parsinghelpers_test.go.
class ParsinghelpersTest {
	public static function run() {
		T.run("TestParseCompilerOptionNoMissingFields", () -> {
			var missingKeys:Array<String> = [];
			// PORT: reflect.VisibleFields → Tsoptions.compilerOptionsFields; reflect.Zero → field.Zero().
			for (field in Tsoptions.compilerOptionsFields) {
				// use the JSON key from the tag, if present
				// e.g. `json:"dog[,anythingelse]"` --> dog
				final keyName = field.JsonName;
				final val = field.Zero();
				final co = new CompilerOptions();
				final found = Tsoptions.parseCompilerOptions(keyName, val, co);
				if (!found) {
					missingKeys.push(keyName);
				}
			}
			T.checks++;
			if (missingKeys.length > 0) {
				T.fail("The following keys are missing entries in the ParseCompilerOptions switch statement:\n" + Std.string(missingKeys));
			}
		});
	}
}
