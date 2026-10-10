package ts.sourcemap;

import ts.sourcemap.Generator.RawSourceMap;

// Port of generator_test.go.
class GeneratorTest {
	public static function run() {
		T.run("TestSourceMapGenerator_Empty", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceMap = gen.RawSourceMap();
			deepEqual(rawSourceMap(3, "main.js", "/", [], [], "", null), sourceMap);
		});
		T.run("TestSourceMapGenerator_Empty_Serialized", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final actual = gen.String();
			final expected = '{"version":3,"file":"main.js","sourceRoot":"/","sources":[],"names":[],"mappings":""}';
			T.eq(expected, actual);
		});
		T.run("TestSourceMapGenerator_AddSource", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			final sourceMap = gen.RawSourceMap();
			T.eq(0, sourceIndex);
			deepEqual(rawSourceMap(3, "main.js", "/", ["main.ts"], [], "", null), sourceMap);
		});
		T.run("TestSourceMapGenerator_SetSourceContent", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			final sourceContent = "foo";
			T.eq(null, gen.SetSourceContent(sourceIndex, sourceContent));
			final sourceMap = gen.RawSourceMap();
			T.eq(0, sourceIndex);
			deepEqual(rawSourceMap(3, "main.js", "/", ["main.ts"], [], "", [sourceContent]), sourceMap);
		});
		T.run("TestSourceMapGenerator_SetSourceContent_ForSecondSourceOnly", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			gen.AddSource("/skipped.ts");
			final sourceIndex = gen.AddSource("/main.ts");
			final sourceContent = "foo";
			T.eq(null, gen.SetSourceContent(sourceIndex, sourceContent));
			final sourceMap = gen.RawSourceMap();
			T.eq(1, sourceIndex);
			deepEqual(rawSourceMap(3, "main.js", "/", ["skipped.ts", "main.ts"], [], "", [null, sourceContent]), sourceMap);
		});
		T.run("TestSourceMapGenerator_SetSourceContent_SourceIndexOutOfRange", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			T.eq("sourceIndex is out of range", errString(gen.SetSourceContent(-1, "")));
			T.eq("sourceIndex is out of range", errString(gen.SetSourceContent(0, "")));
		});
		T.run("TestSourceMapGenerator_SetSourceContent_ForSecondSourceOnly_Serialized", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			gen.AddSource("/skipped.ts");
			final sourceIndex = gen.AddSource("/main.ts");
			final sourceContent = "foo";
			T.eq(null, gen.SetSourceContent(sourceIndex, sourceContent));
			final actual = gen.String();
			final expected = '{"version":3,"file":"main.js","sourceRoot":"/","sources":["skipped.ts","main.ts"],"names":[],"mappings":"","sourcesContent":[null,"foo"]}';
			T.eq(expected, actual);
		});
		T.run("TestSourceMapGenerator_AddName", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final nameIndex = gen.AddName("foo");
			final sourceMap = gen.RawSourceMap();
			T.eq(0, nameIndex);
			deepEqual(rawSourceMap(3, "main.js", "/", [], ["foo"], "", null), sourceMap);
		});
		T.run("TestSourceMapGenerator_AddGeneratedMapping", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			T.eq(null, gen.AddGeneratedMapping(0, 0));
			final sourceMap = gen.RawSourceMap();
			deepEqual(rawSourceMap(3, "main.js", "/", [], [], "A", null), sourceMap);
		});
		T.run("TestSourceMapGenerator_AddGeneratedMapping_OnSecondLineOnly", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			T.eq(null, gen.AddGeneratedMapping(1, 0));
			final sourceMap = gen.RawSourceMap();
			deepEqual(rawSourceMap(3, "main.js", "/", [], [], ";A", null), sourceMap);
		});
		T.run("TestSourceMapGenerator_AddSourceMapping", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			T.eq(null, gen.AddSourceMapping(0, 0, sourceIndex, 0, 0));
			final sourceMap = gen.RawSourceMap();
			deepEqual(rawSourceMap(3, "main.js", "/", ["main.ts"], [], "AAAA", null), sourceMap);
		});
		T.run("TestSourceMapGenerator_AddSourceMapping_NextGeneratedCharacter", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			T.eq(null, gen.AddSourceMapping(0, 0, sourceIndex, 0, 0));
			T.eq(null, gen.AddSourceMapping(0, 1, sourceIndex, 0, 0));
			final sourceMap = gen.RawSourceMap();
			deepEqual(rawSourceMap(3, "main.js", "/", ["main.ts"], [], "AAAA,CAAA", null), sourceMap);
		});
		T.run("TestSourceMapGenerator_AddSourceMapping_NextGeneratedAndSourceCharacter", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			T.eq(null, gen.AddSourceMapping(0, 0, sourceIndex, 0, 0));
			T.eq(null, gen.AddSourceMapping(0, 1, sourceIndex, 0, 1));
			final sourceMap = gen.RawSourceMap();
			deepEqual(rawSourceMap(3, "main.js", "/", ["main.ts"], [], "AAAA,CAAC", null), sourceMap);
		});
		T.run("TestSourceMapGenerator_AddSourceMapping_NextGeneratedLine", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			T.eq(null, gen.AddSourceMapping(0, 0, sourceIndex, 0, 0));
			T.eq(null, gen.AddSourceMapping(1, 0, sourceIndex, 0, 0));
			final sourceMap = gen.RawSourceMap();
			deepEqual(rawSourceMap(3, "main.js", "/", ["main.ts"], [], "AAAA;AAAA", null), sourceMap);
		});
		T.run("TestSourceMapGenerator_AddSourceMapping_PreviousSourceCharacter", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			T.eq(null, gen.AddSourceMapping(0, 0, sourceIndex, 0, 1));
			T.eq(null, gen.AddSourceMapping(0, 1, sourceIndex, 0, 0));
			final sourceMap = gen.RawSourceMap();
			deepEqual(rawSourceMap(3, "main.js", "/", ["main.ts"], [], "AAAC,CAAD", null), sourceMap);
		});
		T.run("TestSourceMapGenerator_AddNamedSourceMapping", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			final nameIndex = gen.AddName("foo");
			T.eq(null, gen.AddNamedSourceMapping(0, 0, sourceIndex, 0, 0, nameIndex));
			final sourceMap = gen.RawSourceMap();
			deepEqual(rawSourceMap(3, "main.js", "/", ["main.ts"], ["foo"], "AAAAA", null), sourceMap);
		});
		T.run("TestSourceMapGenerator_AddNamedSourceMapping_WithPreviousName", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			final nameIndex1 = gen.AddName("foo");
			final nameIndex2 = gen.AddName("bar");
			T.eq(null, gen.AddNamedSourceMapping(0, 0, sourceIndex, 0, 0, nameIndex2));
			T.eq(null, gen.AddNamedSourceMapping(0, 1, sourceIndex, 0, 0, nameIndex1));
			final sourceMap = gen.RawSourceMap();
			deepEqual(rawSourceMap(3, "main.js", "/", ["main.ts"], ["foo", "bar"], "AAAAC,CAAAD", null), sourceMap);
		});
		T.run("TestSourceMapGenerator_AddGeneratedMapping_GeneratedLineCannotBacktrack", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			T.eq(null, gen.AddGeneratedMapping(1, 0));
			T.eq("generatedLine cannot backtrack", errString(gen.AddGeneratedMapping(0, 0)));
		});
		T.run("TestSourceMapGenerator_AddGeneratedMapping_GeneratedCharacterCannotBeNegative", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			T.eq(null, gen.AddGeneratedMapping(0, 0));
			T.eq("generatedCharacter cannot be negative", errString(gen.AddGeneratedMapping(0, -1)));
		});
		T.run("TestSourceMapGenerator_AddSourceMapping_GeneratedLineCannotBacktrack", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			T.eq(null, gen.AddSourceMapping(1, 0, sourceIndex, 0, 0));
			T.eq("generatedLine cannot backtrack", errString(gen.AddSourceMapping(0, 0, sourceIndex, 0, 0)));
		});
		T.run("TestSourceMapGenerator_AddSourceMapping_GeneratedCharacterCannotBeNegative", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			T.eq(null, gen.AddSourceMapping(0, 0, sourceIndex, 0, 0));
			T.eq("generatedCharacter cannot be negative", errString(gen.AddSourceMapping(0, -1, sourceIndex, 0, 0)));
		});
		T.run("TestSourceMapGenerator_AddSourceMapping_SourceIndexIsOutOfRange", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			T.eq("sourceIndex is out of range", errString(gen.AddSourceMapping(0, 0, -1, 0, 0)));
			T.eq("sourceIndex is out of range", errString(gen.AddSourceMapping(0, 0, 0, 0, 0)));
		});
		T.run("TestSourceMapGenerator_AddSourceMapping_SourceLineCannotBeNegative", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			T.eq("sourceLine cannot be negative", errString(gen.AddSourceMapping(0, 0, sourceIndex, -1, 0)));
		});
		T.run("TestSourceMapGenerator_AddSourceMapping_SourceCharacterCannotBeNegative", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			T.eq("sourceCharacter cannot be negative", errString(gen.AddSourceMapping(0, 0, sourceIndex, 0, -1)));
		});
		T.run("TestSourceMapGenerator_AddNamedSourceMapping_GeneratedLineCannotBacktrack", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			final nameIndex = gen.AddName("foo");
			T.eq(null, gen.AddNamedSourceMapping(1, 0, sourceIndex, 0, 0, nameIndex));
			T.eq("generatedLine cannot backtrack", errString(gen.AddNamedSourceMapping(0, 0, sourceIndex, 0, 0, nameIndex)));
		});
		T.run("TestSourceMapGenerator_AddNamedSourceMapping_GeneratedCharacterCannotBeNegative", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			final nameIndex = gen.AddName("foo");
			T.eq(null, gen.AddNamedSourceMapping(0, 0, sourceIndex, 0, 0, nameIndex));
			T.eq("generatedCharacter cannot be negative", errString(gen.AddNamedSourceMapping(0, -1, sourceIndex, 0, 0, nameIndex)));
		});
		T.run("TestSourceMapGenerator_AddNamedSourceMapping_SourceIndexIsOutOfRange", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final nameIndex = gen.AddName("foo");
			T.eq("sourceIndex is out of range", errString(gen.AddNamedSourceMapping(0, 0, -1, 0, 0, nameIndex)));
			T.eq("sourceIndex is out of range", errString(gen.AddNamedSourceMapping(0, 0, 0, 0, 0, nameIndex)));
		});
		T.run("TestSourceMapGenerator_AddNamedSourceMapping_SourceLineCannotBeNegative", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final nameIndex = gen.AddName("foo");
			final sourceIndex = gen.AddSource("/main.ts");
			T.eq("sourceLine cannot be negative", errString(gen.AddNamedSourceMapping(0, 0, sourceIndex, -1, 0, nameIndex)));
		});
		T.run("TestSourceMapGenerator_AddNamedSourceMapping_SourceCharacterCannotBeNegative", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final nameIndex = gen.AddName("foo");
			final sourceIndex = gen.AddSource("/main.ts");
			T.eq("sourceCharacter cannot be negative", errString(gen.AddNamedSourceMapping(0, 0, sourceIndex, 0, -1, nameIndex)));
		});
		T.run("TestSourceMapGenerator_AddNamedSourceMapping_NameIndexIsOutOfRange", () -> {
			final gen = Sourcemap.NewGenerator("main.js", "/", "/", new ComparePathsOptions());
			final sourceIndex = gen.AddSource("/main.ts");
			T.eq("nameIndex is out of range", errString(gen.AddNamedSourceMapping(0, 0, sourceIndex, 0, 0, -1)));
			T.eq("nameIndex is out of range", errString(gen.AddNamedSourceMapping(0, 0, sourceIndex, 0, 0, 0)));
		});
	}

	static function errString(err:Null<Error>):String {
		return err == null ? "<nil>" : err.Error();
	}

	static function rawSourceMap(version:Int, file:String, sourceRoot:String, sources:Array<String>, names:Array<String>, mappings:String,
			sourcesContent:Array<Null<String>>):RawSourceMap {
		final m = new RawSourceMap();
		m.Version = version;
		m.File = file;
		m.SourceRoot = sourceRoot;
		m.Sources = sources;
		m.Names = names;
		m.Mappings = mappings;
		m.SourcesContent = sourcesContent;
		return m;
	}

	// assert.DeepEqual for *RawSourceMap (nil and empty slices differ, like go-cmp).
	static function deepEqual(expected:RawSourceMap, actual:RawSourceMap, ?pos:haxe.PosInfos) {
		T.eq(expected.Version, actual.Version, pos);
		T.eq(expected.File, actual.File, pos);
		T.eq(expected.SourceRoot, actual.SourceRoot, pos);
		T.eq(show(expected.Sources), show(actual.Sources), pos);
		T.eq(show(expected.Names), show(actual.Names), pos);
		T.eq(expected.Mappings, actual.Mappings, pos);
		T.eq(show(expected.SourcesContent), show(actual.SourcesContent), pos);
	}

	static function show(a:Array<Null<String>>):String {
		if (a == null)
			return "nil";
		return "[" + [for (s in a) s == null ? "nil" : '"' + s + '"'].join(",") + "]";
	}
}
