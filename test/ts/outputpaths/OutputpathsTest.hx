package ts.outputpaths;

// Upstream has no outputpaths tests. Smoke checks of the port only (not upstream tests).
class OutputpathsTest {
	public static function run() {
		T.run("SmokeOutputpaths", () -> {
			T.eq(".jsx", Outputpaths.GetOutputExtension("/a/b.tsx", JsxEmitPreserve));
			T.eq(".js", Outputpaths.GetOutputExtension("/a/b.tsx", JsxEmitReact));
			T.eq(".mjs", Outputpaths.GetOutputExtension("/a/b.mts", JsxEmitNone));
			T.eq(".cjs", Outputpaths.GetOutputExtension("/a/b.cts", JsxEmitNone));
			T.eq(".json", Outputpaths.GetOutputExtension("/a/b.json", JsxEmitNone));
			T.eq("/src/", Outputpaths.GetComputedCommonSourceDirectory(["/src/a.ts", "/src/b.ts"], "/", true));
			T.eq("/src/", Outputpaths.GetComputedCommonSourceDirectory(["/src/a.ts", "/src/sub/b.ts"], "/", true));
			T.eq("", Outputpaths.GetComputedCommonSourceDirectory(["/src/a.ts", "c:/b.ts"], "/", true));
			T.eq("/cwd/", Outputpaths.GetComputedCommonSourceDirectory([], "/cwd", true));
			T.eq("/out/sub/b.ts", Outputpaths.GetSourceFilePathInNewDir("/src/sub/b.ts", "/out", "/", "/src", true));
			T.eq("/out/sub/b.ts", Outputpaths.GetSourceFilePathInNewDirWorker("/SRC/sub/b.ts", "/out", "/", "/src/", false));
			final options = new CompilerOptions();
			options.SourceMap = TSTrue;
			T.eq("/a.js.map", Outputpaths.GetSourceMapFilePath("/a.js", options));
			options.InlineSourceMap = TSTrue;
			T.eq("", Outputpaths.GetSourceMapFilePath("/a.js", options));
			T.eq("", Outputpaths.GetBuildInfoFileName(options, new ComparePathsOptions(true, "/")));
			options.Build = TSTrue;
			options.ConfigFilePath = "/p/tsconfig.json";
			options.OutDir = "/p/out";
			T.eq("/p/out/tsconfig.tsbuildinfo", Outputpaths.GetBuildInfoFileName(options, new ComparePathsOptions(true, "/")));
			options.RootDir = "/p";
			T.eq("/p/out/tsconfig.tsbuildinfo", Outputpaths.GetBuildInfoFileName(options, new ComparePathsOptions(true, "/")));
			T.eq("/r/", Outputpaths.GetCommonSourceDirectory(withRoot("/r"), () -> [], "/", true, null));
		});
	}

	static function withRoot(root:String):CompilerOptions {
		final o = new CompilerOptions();
		o.RootDir = root;
		return o;
	}
}
