package ts.parser;

import ts.ast.Parseoptions.SourceFileParseOptions;
import ts.collections.Set;
import ts.tspath.Tspath;

// Port of internal/parser/parser_test.go.
//
// Not ported: BenchmarkParse (benchmark; needs testutil/fixtures).
class ParserTest {
	public static function run() {
		T.run("FuzzParser", FuzzParser);
		T.run("TestJSDocImportTypeParentChain", TestJSDocImportTypeParentChain);
		T.run("TestSourceFileContainsNonASCIIInStringLiteralFastPath", TestSourceFileContainsNonASCIIInStringLiteralFastPath);
	}

	// PORT: Go repo.TypeScriptSubmodulePath().
	static inline final typeScriptSubmodulePath = T.UPSTREAM + "/_submodules/TypeScript";

	// Go allParsableFiles: every file below root that has a supported extension.
	// PORT: filepath.WalkDir → sys.FileSystem (lexical order, like WalkDir).
	static function allParsableFiles(root:String, yield_:(path:String, name:String) -> Void) {
		function walk(dir:String, rel:String) {
			if (!sys.FileSystem.isDirectory(dir)) {
				if (Tspath.TryGetExtensionFromPath(dir) != "") {
					yield_(dir, rel);
				}
				return;
			}
			final entries = sys.FileSystem.readDirectory(dir);
			entries.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
			for (e in entries) {
				walk(dir + "/" + e, rel == "" ? e : rel + "/" + e);
			}
		}
		walk(root, "");
	}

	// Fuzz* functions run over their seed inputs (what `go test` does without -fuzz).
	static function FuzzParser() {
		if (!sys.FileSystem.exists(typeScriptSubmodulePath + "/src")) {
			// repo.SkipIfNoTypeScriptSubmodule
			return;
		}

		final tests = ["src", "scripts", "Herebyfile.mjs"];

		final extensions = new Set<String>();
		for (es in Tspath.AllSupportedExtensionsWithJson) {
			for (e in es) {
				extensions.Add(e);
			}
		}

		// f.Add(extension, sourceText, jsx, force)
		final seeds:Array<Seed> = [];
		for (test in tests) {
			final root = typeScriptSubmodulePath + "/" + test;
			allParsableFiles(root, function(path, name) {
				final sourceText = sys.io.File.getContent(path);
				final extension = Tspath.TryGetExtensionFromPath(path);
				seeds.push(new Seed(extension, sourceText, false, false));
			});
		}

		// PORT: skipped, needs testrunner — the seeds from tests/cases/{compiler,conformance} are the
		// test units of each file (testrunner.ParseTestFilesAndSymlinks). The parser gate
		// (tools/gate/parser.sh) parses every one of those files against the Go reference.

		T.isTrue(seeds.length > 0, "no seeds");
		var parsed = 0;
		for (seed in seeds) {
			if (!extensions.Has(seed.extension)) {
				continue; // t.Skip()
			}

			final fileName = "/index" + seed.extension;
			final path = fileName;

			final opts = new SourceFileParseOptions();
			opts.FileName = fileName;
			opts.Path = path;
			opts.ExternalModuleIndicatorOptions.JSX = seed.jsx;
			opts.ExternalModuleIndicatorOptions.Force = seed.force;

			Parser.ParseSourceFile(opts, seed.sourceText, Core.GetScriptKindFromFileName(fileName));
			parsed++;
		}
		T.isTrue(parsed > 0, "no seed parsed");
	}

	static function TestJSDocImportTypeParentChain() {
		final sourceText = 'test("", async function () {
  ;(/** @type {typeof import("a")} */ ({}))
})

test("", async function () {
  ;(/** @type {typeof import("a")} */ a)
})

test("", async function () {
  (/** @type {typeof import("a")} */ ({}))
  ;(/** @type {typeof import("a")} */ ({}))
})

test("", async function () {
  (/** @type {typeof import("a")} */ a)
  ;(/** @type {typeof import("a")} */ a)
})

test("", async function () {
  (/** @type {typeof import("a")} */ ({}))
  ;(/** @type {typeof import("a")} */ ({}))
})
';
		final opts = new SourceFileParseOptions();
		opts.FileName = "/index.js";
		opts.Path = "/index.js";

		final file = Parser.ParseSourceFile(opts, sourceText, ScriptKindJS);

		T.isTrue(Core.len(file.ReparsedClones) > 0, "expected reparsed clones");
		for (i in 1...Core.len(file.ReparsedClones)) {
			final a = file.ReparsedClones[i - 1];
			final b = file.ReparsedClones[i];
			T.isTrue(!(a.Pos() == b.Pos() && a.End() == b.End() && a.Kind == b.Kind),
				'duplicate ReparsedClones at [${i - 1}] and [$i]: ${a.Kind.String()} pos=${a.Pos()} end=${a.End()}');
		}

		final imports = file.Imports();
		T.isTrue(Core.len(imports) > 0, "expected imports");
		if (imports != null) {
			for (imp in imports) {
				final reparsed = Ast.GetReparsedNodeForNode(imp);
				T.isTrue(Ast.GetSourceFileOfNode(reparsed) != null, 'reparsed import at pos=${imp.Pos()} has broken parent chain');
			}
		}
	}

	static function TestSourceFileContainsNonASCIIInStringLiteralFastPath() {
		final sourceText = 'const x = "─";

namespace N {
  export const y = x;
}
';
		final opts = new SourceFileParseOptions();
		opts.FileName = "/index.ts";
		opts.Path = "/index.ts";

		final file = Parser.ParseSourceFile(opts, sourceText, ScriptKindTS);

		T.isTrue(file.ContainsNonASCII);
		final positionMap = file.GetPositionMap();
		T.isTrue(!positionMap.IsAsciiOnly());
		// PORT: Go offsets are UTF-8 byte offsets: strings.Index(sourceText, "─") + len("─").
		final afterBoxDrawingCharacter = utf8Len(sourceText.substring(0, sourceText.indexOf("─"))) + utf8Len("─");
		T.eq(positionMap.UTF8ToUTF16(afterBoxDrawingCharacter), afterBoxDrawingCharacter - 2);
		T.eq(positionMap.UTF8ToUTF16(utf8Len(sourceText)), utf8Len(sourceText) - 2);
	}

	// Go len(s) of a string: its UTF-8 byte length.
	static function utf8Len(s:String):Int {
		return haxe.io.Bytes.ofString(s).length;
	}
}

// PORT: the arguments of one f.Add(extension, sourceText, jsx, force) call.
class Seed {
	public final extension:String;
	public final sourceText:String;
	public final jsx:Bool;
	public final force:Bool;

	public function new(extension:String, sourceText:String, jsx:Bool, force:Bool) {
		this.extension = extension;
		this.sourceText = sourceText;
		this.jsx = jsx;
		this.force = force;
	}
}
