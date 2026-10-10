package ts.tsoptions;

// Port of decls_test.go.
class DeclsTest {
	public static function run() {
		T.run("TestCompilerOptionsDeclaration", () -> {
			final decls = new haxe.ds.StringMap<CommandLineOption>();

			for (decl in Tsoptions.OptionsDeclarations) {
				decls.set(Strings.ToLower(decl.Name), decl);
			}

			final internalOptions = [
				"allowNonTsExtensions",
				"build",
				"configFilePath",
				"noDtsResolution",
				"noEmitForJsFiles",
				"pathsBasePath",
				"suppressOutputPathCheck",
				"build",
			];

			final internalOptionsMap = new haxe.ds.StringMap<String>();
			for (opt in internalOptions) {
				internalOptionsMap.set(Strings.ToLower(opt), opt);
			}

			// PORT: reflect.TypeFor[core.CompilerOptions]().Fields() → Tsoptions.compilerOptionsFields
			// (field name + json tag name).
			for (field in Tsoptions.compilerOptionsFields) {
				final lowerName = Strings.ToLower(field.Name);

				final decl = decls.get(lowerName);
				if (decl == null) {
					if (internalOptionsMap.exists(lowerName)) {
						checkCompilerOptionJsonTagName(field, internalOptionsMap.get(lowerName));
						continue;
					}
					T.fail('CompilerOptions.${field.Name} has no options declaration');
					continue;
				}
				decls.remove(lowerName);

				checkCompilerOptionJsonTagName(field, decl.Name);
			}

			final skippedOptions = ["plugins"];

			for (opt in skippedOptions) {
				decls.remove(Strings.ToLower(opt));
			}

			for (decl in decls) {
				T.fail('Option declaration ${decl.Name} is not present in CompilerOptions');
			}
		});
	}

	static function checkCompilerOptionJsonTagName(field:CompilerOptionsField, name:String) {
		// PORT: Go compares the whole tag (`name,omitzero`); every field tag has `,omitzero`
		// (see src/ts/core/Compileroptions.hx), so the name is compared.
		final want = name;
		final got = field.JsonName;
		T.checks++;
		if (got != want) {
			T.fail('Field ${field.Name} has json tag $got, but the option declaration has name $name');
		}
	}
}
