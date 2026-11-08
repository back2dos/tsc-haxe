package ts.outputpaths;

// Upstream has no outputpaths tests. Smoke checks of the port only (not upstream tests).
// PORT: typed paths (TypeScript main after ed4807212c): the common source directory has no trailing
// separator (CaseSensitivity.CommonDirectoryOfFiles); GetSourceFilePathInNewDir(Worker) became
// GetSourceFileNameInNewDir; GetBuildInfoFileName takes the case sensitivity.
class OutputpathsTest {
	static inline function f(s:String):RootedFilePath {
		return Tspath.RootedFilePathFromNormalized(s);
	}

	static inline function d(s:String):RootedDirectoryPath {
		return Tspath.RootedDirectoryPathFromNormalized(s);
	}

	public static function run() {
		T.run("SmokeOutputpaths", () -> {
			T.eq(".jsx", Outputpaths.GetOutputExtension("/a/b.tsx", JsxEmitPreserve));
			T.eq(".js", Outputpaths.GetOutputExtension("/a/b.tsx", JsxEmitReact));
			T.eq(".mjs", Outputpaths.GetOutputExtension("/a/b.mts", JsxEmitNone));
			T.eq(".cjs", Outputpaths.GetOutputExtension("/a/b.cts", JsxEmitNone));
			T.eq(".json", Outputpaths.GetOutputExtension("/a/b.json", JsxEmitNone));
			T.eq("/src", Outputpaths.GetComputedCommonSourceDirectory([f("/src/a.ts"), f("/src/b.ts")], d("/"), CaseSensitive).AsString());
			T.eq("/src", Outputpaths.GetComputedCommonSourceDirectory([f("/src/a.ts"), f("/src/sub/b.ts")], d("/"), CaseSensitive).AsString());
			T.eq("", Outputpaths.GetComputedCommonSourceDirectory([f("/src/a.ts"), f("c:/b.ts")], d("/"), CaseSensitive).AsString());
			T.eq("/cwd", Outputpaths.GetComputedCommonSourceDirectory([], d("/cwd"), CaseSensitive).AsString());
			T.eq("/out/sub/b.ts", Outputpaths.GetSourceFileNameInNewDir(f("/src/sub/b.ts"), d("/out"), d("/src"), CaseSensitive).AsString());
			T.eq("/out/sub/b.ts", Outputpaths.GetSourceFileNameInNewDir(f("/SRC/sub/b.ts"), d("/out"), d("/src"), CaseInsensitive).AsString());
			final options = new CompilerOptions();
			options.SourceMap = TSTrue;
			T.eq("/a.js.map", Outputpaths.GetSourceMapFilePath(f("/a.js"), options).AsString());
			options.InlineSourceMap = TSTrue;
			T.eq("", Outputpaths.GetSourceMapFilePath(f("/a.js"), options).AsString());
			T.eq("", Outputpaths.GetBuildInfoFileName(options, CaseSensitive).AsString());
			options.Build = TSTrue;
			options.ConfigFilePath = f("/p/tsconfig.json");
			options.OutDir = d("/p/out");
			T.eq("/p/out/tsconfig.tsbuildinfo", Outputpaths.GetBuildInfoFileName(options, CaseSensitive).AsString());
			options.RootDir = d("/p");
			T.eq("/p/out/tsconfig.tsbuildinfo", Outputpaths.GetBuildInfoFileName(options, CaseSensitive).AsString());
			T.eq("/r", Outputpaths.GetCommonSourceDirectory(withRoot("/r"), () -> [], d("/"), CaseSensitive, null).AsString());
		});
	}

	static function withRoot(root:String):CompilerOptions {
		final o = new CompilerOptions();
		o.RootDir = d(root);
		return o;
	}
}
