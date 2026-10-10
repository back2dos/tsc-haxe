package ts.tsoptions;

// Port of wildcarddirectories_test.go.
class WildcarddirectoriesTest {
	public static function run() {
		T.run("TestGetWildcardDirectories_DotPrefixedIncludeWithDotDirExclude", () -> {
			// https://github.com/microsoft/typescript-go/issues/3733
			// "./"-prefixed include specs must be fully normalized before being tested
			// against exclude patterns; otherwise the leftover literal "." path segment
			// matches dot-directory excludes like "**/.*/", silently dropping every
			// wildcard directory (and with them, root file watching for the config).
			final result = Tsoptions.getWildcardDirectories(["./app/**/*.ts", "./app/**/*.tsx"], ["**/node_modules", "**/.*/", "./build"],
				new ComparePathsOptions(true, "/home/projects/monorepo/apps/web"));
			final keys = [for (k in result.keys()) k];
			T.eq(1, keys.length);
			T.eq(true, result.get("/home/projects/monorepo/apps/web/app"));
		});

		T.run("TestGetWildcardDirectories_NonASCIICharacters", () -> {
			final tests:Array<{
				name:String,
				include:Array<String>,
				exclude:Array<String>,
				currentDirectory:String,
				useCaseSensitiveFileNames:Bool
			}> = [
				{
					name: "Norwegian character æ in path",
					include: ["src/**/*.test.ts", "src/**/*.stories.ts", "src/**/*.mdx"],
					exclude: ["node_modules"],
					currentDirectory: "C:/Users/TobiasLægreid/dev/app/frontend/packages/react",
					useCaseSensitiveFileNames: false,
				},
				{
					name: "Japanese characters in path",
					include: ["src/**/*.ts"],
					exclude: ["テスト"],
					currentDirectory: "/Users/ユーザー/プロジェクト",
					useCaseSensitiveFileNames: true,
				},
				{
					name: "Chinese characters in path",
					include: ["源代码/**/*.js"],
					exclude: ["节点模块"],
					currentDirectory: "/home/用户/项目",
					useCaseSensitiveFileNames: true,
				},
				{
					name: "Various Unicode characters",
					include: ["src/**/*.ts"],
					exclude: ["node_modules"],
					currentDirectory: "/Users/Müller/café/naïve/résumé",
					useCaseSensitiveFileNames: false,
				},
			];

			for (tt in tests) {
				T.run("TestGetWildcardDirectories_NonASCIICharacters/" + tt.name, () -> {
					final comparePathsOptions = new ComparePathsOptions(tt.useCaseSensitiveFileNames, tt.currentDirectory);

					final result = Tsoptions.getWildcardDirectories(tt.include, tt.exclude, comparePathsOptions);

					T.isTrue(result != null, "expected non-nil result");
				});
			}
		});
	}
}
