package ts.execute.incremental;

import ts.execute.incremental.Incremental;
import ts.execute.incremental.BuildInfo;
import ts.execute.incremental.Snapshot;
import ts.execute.incremental.Snapshot.FileEmitKind.*;
import ts.execute.tsctests.Readablebuildinfo;
import ts.json.Json;

// Unit tests for the incremental port (no upstream *_test.go exists for this package).
class IncrementalTest {
	// xxh3.HashString128 golden values from github.com/zeebo/xxh3 v1.1.0 (go run, see report):
	// input = n bytes, byte i = 'a' + (i*7 + i/3) % 26.
	static final golden128 = [
		0 => "99aa06d3014798d86001c324468d497f", 1 => "a96faf705af16834e6c632b61e964e1f", 2 => "dda0e5ae435b650a3a6dd033830eea1e",
		3 => "6fef1ddc63a184e27ea47a004f34273c", 4 => "3d948113dd53a43ac5129a991ccae411", 5 => "abc21c2058b7de16993764f825b64f1f",
		8 => "fac71ea8d12a3909c455ce51d916525a", 9 => "523264285c9c7915e404a1696dcdf1a3", 12 => "f6c8e7f35deb3e57100bfe0957c4c67e",
		16 => "5d805a8011a3938af9c1ec065f671bcc", 17 => "4b06d0390bc7bc74226e4bbc4d23f1f6", 31 => "06a08e1e9c97142d5536271be845933b",
		32 => "f61e1b77adbfb05bfb04f9253daace92", 33 => "d118d3b0588bb9ca72752914d9531ab6", 63 => "5aab20e419a9cfd0cbb367f671652f44",
		64 => "bda6844b3e59b999d8b7b7ca723ace19", 65 => "853d6b9931a59e0a55bfb1eb7916c635", 96 => "e8bace4728dc63bc87f8e2bce3a880c1",
		97 => "684a6ddd86036727453397ad072cf697", 127 => "ad29d9d829229e2b39fd75d367d6bf52", 128 => "f0b67ff0b0587d2b1923ee1539e29e78",
		129 => "7c85dc06a7ad29899d94e65a1611a3ef", 150 => "4afdc2446214d427679030bf673ab0bc", 200 => "814520ab611ee5dc183443d0011c8a0e",
		239 => "645a8773513e31dc9222632d20e95a9e", 240 => "3547a1b39ce4a1810f0c8934fe14db83", 241 => "6007a43fbf01b97114516f25ad23c639",
		300 => "8f4b5c37c2c5fc4aad75bd496568891c", 1023 => "77a03911f2dff0c4dbff66e21f8c0bb4", 1024 => "a924d8f4a5639faf12fe5bbc0d280be3",
		1025 => "eabd8183885b1f87c4bfe5e71203fbee", 2000 => "7220dfbd2a5ce4e65e9bbfa7f88425c0", 5000 => "5309ba0ca000869333407a8ce7eb6bc6",
	];

	public static function run() {
		T.run("TestComputeHash", function() {
			final keys = [for (k in golden128.keys()) k];
			keys.sort((a, b) -> a - b);
			for (n in keys) {
				final b = new StringBuf();
				for (i in 0...n)
					b.addChar("a".code + (i * 7 + Std.int(i / 3)) % 26);
				T.eq(golden128.get(n), Incremental.ComputeHash(b.toString(), false));
			}
			T.eq("596fd5f4c84abd5c5f5ed0f3d0ee59fb", Incremental.ComputeHash("héllo wörld ✓ 😀", false));
			T.eq("99aa06d3014798d86001c324468d497f-", Incremental.ComputeHash("", true));
		});

		T.run("TestGetPendingEmitKind", function() {
			T.eq(FileEmitKindNone, Incremental.getPendingEmitKind(FileEmitKindJs, FileEmitKindJs));
			T.eq(FileEmitKindJs | FileEmitKindDts, Incremental.getPendingEmitKind(FileEmitKindJs | FileEmitKindDts, 0));
			T.eq(FileEmitKindJsMap | FileEmitKindJs, Incremental.getPendingEmitKind(FileEmitKindJs | FileEmitKindJsMap, FileEmitKindJs));
			T.eq(FileEmitKindDtsEmit | FileEmitKindDtsMap,
				Incremental.getPendingEmitKind(FileEmitKindJs | FileEmitKindDts | FileEmitKindDtsMap, FileEmitKindJs | FileEmitKindDts));
		});

		T.run("TestReadableFileEmitKind", function() {
			T.eq("None", Readablebuildinfo.toReadableFileEmitKind(FileEmitKindNone));
			T.eq("Js|Dts|DtsMap", Readablebuildinfo.toReadableFileEmitKind(FileEmitKindJs | FileEmitKindAllDts));
			T.eq("DtsEmit|DtsMap", Readablebuildinfo.toReadableFileEmitKind(FileEmitKindAllDtsEmit));
		});

		T.run("TestUnmarshalInvalid", function() {
			T.isTrue(Incremental.UnmarshalBuildInfo("Some random string") == null);
			T.isTrue(Incremental.UnmarshalBuildInfo("{\"version\":1}") == null);
			T.isTrue(Incremental.UnmarshalBuildInfo("{\"version\":\"x\",\"root\":[{}]}") == null);
			final b = Incremental.UnmarshalBuildInfo("{\"version\":\"x\",\"unknown\":[1,2]}");
			T.isTrue(b != null && b.Version == "x");
		});

		T.run("TestIncrementalProgramSmoke", programSmoke);

		// Every .tsbuildinfo text in the upstream tsc/tsbuild baselines: unmarshal + marshal gives the same
		// bytes, and toReadableBuildInfo gives the .readable.baseline.txt that follows it.
		T.run("TestBuildInfoRoundTripBaselines", function() {
			var files = 0, infos = 0, readables = 0;
			for (dir in ["tsc", "tsbuild", "tscWatch", "tsbuildWatch"]) {
				for (path in listFiles(T.UPSTREAM + "/testdata/baselines/reference/" + dir)) {
					files++;
					final entries = parseBaseline(sys.io.File.getContent(path));
					for (i in 0...entries.length) {
						final e = entries[i];
						if (!StringTools.endsWith(e.a, ".tsbuildinfo"))
							continue;
						infos++;
						final b = Incremental.UnmarshalBuildInfo(e.b);
						if (b == null) {
							// Scenarios write invalid buildinfo text on purpose; Go fails to decode them too.
							continue;
						}
						if (e.b.indexOf("\n") < 0) // hand-written inputs are not in Go's compact form
							T.eq(e.b, Json.MarshalOrdered(b), null);
						if (i + 1 < entries.length && entries[i + 1].a == e.a + ".readable.baseline.txt") {
							readables++;
							final actual = Readablebuildinfo.toReadableBuildInfo(b, e.b);
							if (actual != entries[i + 1].b) {
								T.fail('readable differs: $path ${e.a}');
							}
						}
					}
				}
			}
			Sys.println('  baselines: $files files, $infos tsbuildinfo, $readables readable');
			T.isTrue(readables > 100);
		});
	}

	// Smoke test (not upstream): a real compiler program through NewProgram, emit with buildinfo, then
	// ReadBuildInfoProgram + NewProgram on an unchanged and on an edited file system.
	static function programSmoke() {
		final files = new Map<String, Any>();
		files.set("/p/tsconfig.json", "{\"compilerOptions\": {\"incremental\": true, \"declaration\": true}}");
		files.set("/p/a.ts", "export const a: number = 1;");
		files.set("/p/b.ts", "import { a } from \"./a\";\nexport const b = a + 1;\nconst c: string = 1;");
		final fs = ts.bundled.Bundled.WrapFS(ts.vfs.vfstest.Vfstest.Vfstest.FromMap(files, true));
		function compile():Program {
			final host = ts.compiler.Compiler.NewCachedFSCompilerHost("/p", fs, ts.bundled.Bundled.LibPath(), null, null);
			final config = ts.tsoptions.Tsoptions.GetParsedCommandLineOfConfigFile("/p/tsconfig.json", null, null, cast host, null).a;
			final old = Incremental.ReadBuildInfoProgram(config, Incremental.NewBuildInfoReader(host), host);
			final po = new ts.compiler.Program.ProgramOptions();
			po.Config = config;
			po.Host = host;
			final program = ts.compiler.Compiler.NewProgram(po);
			final p = Incremental.NewProgram(program, old, Incremental.CreateHost(host), true);
			final ctx = go.Context.Background();
			final diags = ts.compiler.Compiler.GetDiagnosticsOfAnyProgram(ctx, p, null, false, p.GetBindDiagnostics, p.GetSemanticDiagnostics);
			T.eq(1, diags.length);
			p.Emit(ctx, new ts.compiler.Program.EmitOptions());
			return p;
		}
		final p1 = compile();
		final text1 = fs.ReadFile("/p/tsconfig.tsbuildinfo");
		T.isTrue(text1.ok);
		final b1 = Incremental.UnmarshalBuildInfo(text1.value);
		T.isTrue(b1 != null && b1.IsIncremental());
		T.isTrue(b1.FileNames[b1.FileNames.length - 1] == "./b.ts");
		T.isTrue(p1.GetTestingData().UpdatedSignatureKinds != null);
		// Unchanged: nothing is re-checked, buildinfo not rewritten.
		final p2 = compile();
		var refreshed = 0;
		for (file in p2.GetProgram().GetSourceFiles()) {
			final d = p2.GetTestingData().SemanticDiagnosticsPerFile.Load(file.Path());
			final o = p2.GetTestingData().OldProgramSemanticDiagnosticsPerFile.Load(file.Path());
			if (d.ok && (!o.ok || o.value != d.value))
				refreshed++;
		}
		T.eq(0, refreshed);
		T.eq(text1.value, fs.ReadFile("/p/tsconfig.tsbuildinfo").value);
		// Edit a.ts: its signature changes, b.ts is re-checked.
		fs.WriteFile("/p/a.ts", "export const a: string = \"x\";");
		final p3 = compile();
		final kinds = p3.GetTestingData().UpdatedSignatureKinds;
		T.isTrue(kinds.exists("/p/a.ts"));
		T.isTrue(fs.ReadFile("/p/tsconfig.tsbuildinfo").value != text1.value);
	}

	static function listFiles(dir:String):Array<String> {
		final result = [];
		if (!sys.FileSystem.exists(dir))
			return result;
		final names = sys.FileSystem.readDirectory(dir);
		names.sort(Reflect.compare);
		for (n in names) {
			final p = dir + "/" + n;
			if (sys.FileSystem.isDirectory(p))
				for (x in listFiles(p))
					result.push(x);
			else
				result.push(p);
		}
		return result;
	}

	// Entries `//// [path] *new* | *modified* ` followed by content lines up to an empty line or the next entry.
	static function parseBaseline(text:String):Array<go.Tuple.Pair<String, String>> {
		final result = [];
		final lines = text.split("\n");
		var i = 0;
		while (i < lines.length) {
			final line = lines[i];
			final re = ~/^\/\/\/\/ \[(.*)\] \*(new|modified)\* $/;
			if (re.match(line)) {
				final path = re.matched(1);
				final content = [];
				i++;
				while (i < lines.length && lines[i] != "" && !StringTools.startsWith(lines[i], "//// [")) {
					content.push(lines[i]);
					i++;
				}
				result.push(new go.Tuple.Pair(path, content.join("\n")));
				continue;
			}
			i++;
		}
		return result;
	}
}
