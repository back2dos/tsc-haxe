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
			// PORT: Go's untyped constant → RootedDirectoryPathFromNormalized.
			final result = Tsoptions.getWildcardDirectories(["./app/**/*.ts", "./app/**/*.tsx"], ["**/node_modules", "**/.*/", "./build"],
				Tspath.RootedDirectoryPathFromNormalized("/home/projects/monorepo/apps/web"), CaseSensitive);
			T.eq(1, result.Size());
			final r = result.Get(Tspath.RootedDirectoryPathFromNormalized("/home/projects/monorepo/apps/web/app"));
			T.isTrue(r.ok && r.value == true, "missing /home/projects/monorepo/apps/web/app");
		});

		// PORT: from TypeScript main (ed4807212c, typed paths).
		T.run("TestGetWildcardDirectories_DriveRoot", () -> {
			final result = Tsoptions.getWildcardDirectories(["*.ts"], null, Tspath.RootedDirectoryPathFromNormalized("c:/"), CaseInsensitive);
			T.eq(1, result.Size());
			final r = result.Get(Tspath.RootedDirectoryPathFromNormalized("c:/"));
			T.isTrue(r.ok && r.value == false, "expected c:/ (not recursive)");
		});

		T.run("TestGetWildcardDirectories_NonASCIICharacters", () -> {
			final tests:Array<{
				name:String,
				include:Array<String>,
				exclude:Array<String>,
				currentDirectory:RootedDirectoryPath,
				caseSensitivity:CaseSensitivity
			}> = [
				{
					name: "Norwegian character æ in path",
					include: ["src/**/*.test.ts", "src/**/*.stories.ts", "src/**/*.mdx"],
					exclude: ["node_modules"],
					currentDirectory: Tspath.RootedDirectoryPathFromNormalized("C:/Users/TobiasLægreid/dev/app/frontend/packages/react"),
					caseSensitivity: CaseInsensitive,
				},
				{
					name: "Japanese characters in path",
					include: ["src/**/*.ts"],
					exclude: ["テスト"],
					currentDirectory: Tspath.RootedDirectoryPathFromNormalized("/Users/ユーザー/プロジェクト"),
					caseSensitivity: CaseSensitive,
				},
				{
					name: "Chinese characters in path",
					include: ["源代码/**/*.js"],
					exclude: ["节点模块"],
					currentDirectory: Tspath.RootedDirectoryPathFromNormalized("/home/用户/项目"),
					caseSensitivity: CaseSensitive,
				},
				{
					name: "Various Unicode characters",
					include: ["src/**/*.ts"],
					exclude: ["node_modules"],
					currentDirectory: Tspath.RootedDirectoryPathFromNormalized("/Users/Müller/café/naïve/résumé"),
					caseSensitivity: CaseInsensitive,
				},
			];

			for (tt in tests) {
				T.run("TestGetWildcardDirectories_NonASCIICharacters/" + tt.name, () -> {
					final result = Tsoptions.getWildcardDirectories(tt.include, tt.exclude, tt.currentDirectory, tt.caseSensitivity);

					T.isTrue(result != null, "expected non-nil result");
				});
			}
		});
	}
}
