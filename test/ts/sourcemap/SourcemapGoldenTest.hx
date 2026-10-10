package ts.sourcemap;

import haxe.ds.StringMap;
import ts.sourcemap.SourceMapper.DocumentPosition;

// Not an upstream test: golden values from a Go reference run of the pinned upstream
// (overlay program, see the report of the sourcemap lane). Checks JSON escaping (byte-identical to
// go-json-experiment), Base64DataURL, the mappings decoder, the document position mapper (positions
// converted from Go's UTF-8 offsets to UTF-16) and TryGetSourceMappingURL.
class SourcemapGoldenTest {
	public static function run() {
		T.run("GoldenGeneratorJSON", () -> {
			final gen = Sourcemap.NewGenerator("ma\"in\\.js", "/r\x01oot\x1f<>&  \x7f", "/", new ComparePathsOptions());
			final i0 = gen.AddSource("/a\tb\nc\rd\x08e\x0Cf.ts");
			final i1 = gen.AddSource("/ü\u{1F600}.ts");
			gen.AddName("n1");
			final n2 = gen.AddName("n\u{1F600}");
			gen.SetSourceContent(i1, "let x = '\u{1F600}';\n\x00");
			gen.AddSourceMapping(0, 0, i0, 0, 0);
			gen.AddNamedSourceMapping(0, 5, i1, 3, 17, n2);
			gen.AddGeneratedMapping(0, 9);
			gen.AddSourceMapping(2, 1000, i0, 100, 70000);
			gen.AddSourceMapping(2, 1001, i0, 99, 3);
			T.eq('{"version":3,"file":"ma\\"in\\\\.js","sourceRoot":"/r\\u0001oot\\u001f<>&  \x7f","sources":["a\\tb\\nc\\rd\\be\\ff.ts","ü\u{1F600}.ts"],"names":["n1","n\u{1F600}"],"mappings":"AAAA,KCGiBC,I;;w+BDiG+1oE,CAD72oE","sourcesContent":[null,"let x = \'\u{1F600}\';\\n\\u0000"]}',
				gen.String());
			T.eq("data:application/json;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoibWFcImluXFwuanMiLCJzb3VyY2VSb290IjoiL3JcdTAwMDFvb3RcdTAwMWY8PibigKjigKl/Iiwic291cmNlcyI6WyJhXHRiXG5jXHJkXGJlXGZmLnRzIiwiw7zwn5iALnRzIl0sIm5hbWVzIjpbIm4xIiwibvCfmIAiXSwibWFwcGluZ3MiOiJBQUFBLEtDR2lCQyxJOzt3K0JEaUcrMW9FLENBRDcyb0UiLCJzb3VyY2VzQ29udGVudCI6W251bGwsImxldCB4ID0gJ/CfmIAnO1xuXHUwMDAwIl19",
				gen.Base64DataURL());
		});
		T.run("GoldenDecodeMappings", () -> {
			T.eq("0 0 0 0 0 -1|0 1 0 0 1 -1|2 0 0 1 1 -1|2 16 0 1 17 -1|2 18 0 1 19 -1|2 20 -1 -1 -1 -1|3 0 -1 -1 -1 -1|<nil> 31",
				decode("AAAA,CAAC;;AACA,gBAAgB,EAAE,E;A"));
			T.eq("Invalid character in VLQ 1", decode("A!"));
			T.eq("Unsupported Format: No entries after sourceIndex 2", decode("AA"));
			T.eq("Unsupported Error Format: Entries after nameIndex 5", decode("AAAAAA"));
			T.eq("Invalid generatedCharacter found 1", decode("D"));
			T.eq("0 0 0 0 0 0|<nil> 5", decode("AAAAB"));
			T.eq("0 0 -1 -1 -1 -1|<nil> 8", decode("gggggggA"));
		});
		T.run("GoldenDocumentPositionMapper", () -> {
			final h = new TestHost();
			h.files.set("/src/a.ts", "const \u{1F600} = 1;\nlet y = 2;\n");
			h.files.set("/out/a.js", "const \u{1F600} = 1;\nlet y = 2;\n//# sourceMappingURL=a.js.map\n");
			h.files.set("/out/a.js.map",
				'{"version":3,"file":"a.js","sourceRoot":"","sources":["../src/a.ts"],"names":[],"mappings":"AAAA,MAAM,EAAE,GAAG;AACX,IAAI"}');
			final gen = Sourcemap.NewGenerator("x.js", "", "/", new ComparePathsOptions());
			gen.AddSource("/x.ts");
			gen.SetSourceContent(0, "x");
			h.files.set("/out/b.js", "x;\n//# sourceMappingURL=" + gen.Base64DataURL());
			final dm = Sourcemap.GetDocumentPositionMapper(h, "/out/a.js");
			final expected = [
				0 => [0, 0], 5 => [6, 6], 6 => [6, 6], 7 => [8, 8], 8 => [8, 8], 10 => [11, 11], 12 => [14, 14], 13 => [14, 14], 15 => [18, 18]
			];
			for (u in [0, 5, 6, 7, 8, 10, 12, 13, 15]) {
				T.eq("/src/a.ts:" + expected[u][0], show(dm.GetSourcePosition(new DocumentPosition("/out/a.js", u))));
				T.eq("/out/a.js:" + expected[u][1], show(dm.GetGeneratedPosition(new DocumentPosition("/src/a.ts", u))));
			}
			T.eq("nil", show(dm.GetSourcePosition(new DocumentPosition("/out/a.js", 100))));
			T.eq("nil", show(dm.GetGeneratedPosition(new DocumentPosition("/src/a.ts", 100))));
			// inlined sources are not supported
			T.isTrue(Sourcemap.GetDocumentPositionMapper(h, "/out/b.js") == null);
			final none:DocumentPositionMapper = null;
			T.eq("nil", show(none.GetSourcePosition(new DocumentPosition("/out/a.js", 0))));
		});
		T.run("GoldenTryGetSourceMappingURL", () -> {
			final cases = [
				"x\n//# sourceMappingURL=foo.map  \n\n" => "foo.map",
				"//@ sourceMappingURL=x" => "x",
				"//# sourceMappingURL=a\n// other" => "",
				"  //# sourceMappingURL=y\r\n" => "y",
				"" => "",
			];
			for (text => url in cases) {
				T.eq(url, Sourcemap.TryGetSourceMappingURL(Sourcemap.CreateECMALineInfo(text, Core.ComputeECMALineStarts(text))));
			}
		});
	}

	static function decode(mappings:String):String {
		final d = Sourcemap.DecodeMappings(mappings);
		final parts = [];
		for (m in d.Values()) {
			parts.push('${m.GeneratedLine} ${m.GeneratedCharacter} ${m.SourceIndex} ${m.SourceLine} ${m.SourceCharacter} ${m.NameIndex}');
		}
		parts.push((d.Error() == null ? "<nil>" : d.Error().Error()) + " " + d.Pos());
		return parts.join("|");
	}

	static function show(p:DocumentPosition):String {
		return p == null ? "nil" : p.FileName + ":" + p.Pos;
	}
}

private class TestHost implements Host {
	public final files = new StringMap<String>();

	public function new() {}

	public function UseCaseSensitiveFileNames():Bool {
		return true;
	}

	public function GetECMALineInfo(fileName:String):ECMALineInfo {
		final text = files.get(fileName);
		if (text == null) {
			return null;
		}
		return Sourcemap.CreateECMALineInfo(text, Core.ComputeECMALineStarts(text));
	}

	public function ReadFile(fileName:String):ValueOk<String> {
		final text = files.get(fileName);
		return new ValueOk(text == null ? "" : text, text != null);
	}
}
