package ts.module;

import ts.locale.Locale;
import ts.packagejson.Jsontext;
import ts.vfs.vfstest.Vfstest;
import ts.module.ModuleTest.ResolutionHostStub;

// PORT: extra (not upstream). Golden test against the Go resolver: the scenarios in
// golden/scenarios.json (file systems, options, resolution requests) are run here and by a Go
// dump (zz_golden_test.go, run with `go test -overlay` in upstream/tsc/internal/module); the
// traces (--traceResolution messages, in order) and results must match golden/expected.txt
// line by line. Regenerate expected.txt (from upstream/tsc):
//   echo '{"Replace":{"'$PWD'/internal/module/zz_golden_test.go":"<repo>/test/ts/module/golden/zz_golden_test.go.txt"}}' > /tmp/ov.json
//   GOLDEN_IN=<repo>/test/ts/module/golden/scenarios.json GOLDEN_OUT=<repo>/test/ts/module/golden/expected.txt \
//     GOTOOLCHAIN=go1.26.9 go test ./internal/module -run TestGoldenDump -overlay /tmp/ov.json -count=1
class ModuleGoldenTest {
	static inline final DIR = "test/ts/module/golden/";

	public static function run() {
		T.run("TestGoldenTraces", () -> {
			final text = sys.io.File.getContent(DIR + "scenarios.json");
			final expected = sys.io.File.getContent(DIR + "expected.txt");
			final actual = dump(text);
			final e = expected.split("\n");
			final a = actual.split("\n");
			var mismatches = 0;
			var header = "";
			for (i in 0...(e.length > a.length ? e.length : a.length)) {
				final el = i < e.length ? e[i] : "<eof>";
				final al = i < a.length ? a[i] : "<eof>";
				if (StringTools.startsWith(el, "###"))
					header = el;
				T.checks++;
				if (el != al) {
					mismatches++;
					if (mismatches <= 5)
						T.fail('line ${i + 1} ($header):\n  want: $el\n  got:  $al');
				}
			}
			if (mismatches > 5)
				T.fail('$mismatches mismatching lines');
		});
	}

	static function str(v:Null<Value>):String {
		return v == null ? "" : v.Str;
	}

	static function strings(v:Null<Value>):Null<Array<String>> {
		return v == null || v.Kind != "[".code ? null : [for (i in v.Items) i.Str];
	}

	static function tri(v:Null<Value>):Tristate {
		if (v == null)
			return TSUnknown;
		return v.Kind == "t".code ? TSTrue : TSFalse;
	}

	static function get(obj:Value, name:String):Null<Value> {
		final i = obj.Names.indexOf(name);
		return i < 0 ? null : obj.Members[i];
	}

	// Go %q for the ASCII strings used here.
	static function q(s:String):String {
		return '"' + StringTools.replace(StringTools.replace(s, "\\", "\\\\"), '"', '\\"') + '"';
	}

	static function b(v:Bool):String {
		return v ? "true" : "false";
	}

	static function setStr(s:Null<Set<String>>):String {
		if (s == null)
			return "<nil>";
		final keys:Array<String> = [];
		if (s.M != null)
			for (k in s.M.keys())
				keys.push(k);
		keys.sort(Strings.Compare);
		return "[" + keys.join(",") + "]";
	}

	static function dump(text:String):String {
		final parsed = Jsontext.Parse(text);
		if (parsed.err != null)
			throw parsed.err.Error();
		final out = new StringBuf();
		for (s in parsed.value.Items) {
			final name = str(get(s, "name"));
			final files = new Map<String, Any>();
			final f = get(s, "files");
			for (i in 0...f.Names.length) {
				final v = f.Members[i];
				files.set(f.Names[i], v.Kind == '"'.code ? v.Str : text.substring(v.Start, v.End));
			}
			final links = get(s, "symlinks");
			if (links != null)
				for (i in 0...links.Names.length)
					files.set(links.Names[i], Vfstest.Symlink(links.Members[i].Str));
			final cs = get(s, "caseSensitive");
			final fs = Vfstest.FromMap(files, cs == null || cs.Kind == "t".code);
			final host = new ResolutionHostStub(fs, "/");

			final ov = get(s, "options");
			final o = new CompilerOptions();
			switch (str(get(ov, "moduleResolution"))) {
				case "bundler":
					o.ModuleResolution = ModuleResolutionKindBundler;
				case "node16":
					o.ModuleResolution = ModuleResolutionKindNode16;
				case "nodenext":
					o.ModuleResolution = ModuleResolutionKindNodeNext;
				default:
			}
			switch (str(get(ov, "module"))) {
				case "esnext":
					o.Module = ModuleKindESNext;
				case "commonjs":
					o.Module = ModuleKindCommonJS;
				case "node16":
					o.Module = ModuleKindNode16;
				case "nodenext":
					o.Module = ModuleKindNodeNext;
				default:
			}
			final trace = get(s, "trace");
			if (trace == null || trace.Kind == "t".code)
				o.TraceResolution = TSTrue;
			final paths = get(ov, "paths");
			if (paths != null) {
				o.Paths = new OrderedMap<String, Array<String>>();
				for (i in 0...paths.Names.length)
					o.Paths.Set(paths.Names[i], strings(paths.Members[i]));
			}
			o.PathsBasePath = str(get(ov, "pathsBasePath"));
			o.RootDirs = strings(get(ov, "rootDirs"));
			o.TypeRoots = strings(get(ov, "typeRoots"));
			o.Types = strings(get(ov, "types"));
			o.CustomConditions = strings(get(ov, "customConditions"));
			o.ModuleSuffixes = strings(get(ov, "moduleSuffixes"));
			o.ResolveJsonModule = tri(get(ov, "resolveJsonModule"));
			o.AllowJs = tri(get(ov, "allowJs"));
			o.NoDtsResolution = tri(get(ov, "noDtsResolution"));
			o.ResolvePackageJsonExports = tri(get(ov, "resolvePackageJsonExports"));
			o.ResolvePackageJsonImports = tri(get(ov, "resolvePackageJsonImports"));
			o.PreserveSymlinks = tri(get(ov, "preserveSymlinks"));
			o.OutDir = str(get(ov, "outDir"));
			o.DeclarationDir = str(get(ov, "declarationDir"));
			o.RootDir = str(get(ov, "rootDir"));
			o.ConfigFilePath = str(get(ov, "configFilePath"));

			final resolver = Module.NewResolver(host, o, str(get(s, "typingsLocation")), str(get(s, "projectName")));
			for (op in get(s, "ops").Items) {
				final kind = str(get(op, "op"));
				final opName = str(get(op, "name"));
				final from = str(get(op, "from"));
				final modeText = str(get(op, "mode"));
				final dir = str(get(op, "dir"));
				final mode:ResolutionMode = switch (modeText) {
					case "esm": ModuleKindESNext;
					case "cjs": ModuleKindCommonJS;
					default: ModuleKindNone;
				}
				out.add('### $name: $kind $opName $from $modeText $dir\n');
				final writeTraces = function(traces:Null<Array<DiagAndArgs>>) {
					if (traces != null)
						for (tr in traces)
							out.add("trace: " + tr.Message.Localize(Locale.Default, tr.Args) + "\n");
				};
				final writeModule = function(r:Null<ResolvedModule>) {
					if (r == null) {
						out.add("result: <nil>\n");
						return;
					}
					out.add('resolved: ${q(r.ResolvedFileName)} original: ${q(r.OriginalPath)} ext: ${q(r.Extension)} external: ${b(r.IsExternalLibraryImport)} tsext: ${b(r.ResolvedUsingTsExtension)} alt: ${q(r.AlternateResult)} pkg: ${q(r.PackageId.String())}\n');
					if (r.ResolutionDiagnostics != null)
						for (d in r.ResolutionDiagnostics)
							out.add('diagnostic: ${d.Code()} ${d.Localize(Locale.Default)}\n');
				};
				switch (kind) {
					case "module":
						final r = resolver.ResolveModuleName(opName, from, mode, null);
						writeTraces(r.b);
						writeModule(r.a);
					case "typeRef":
						final r = resolver.ResolveTypeReferenceDirective(opName, from, mode, null);
						writeTraces(r.b);
						final t = r.a;
						out.add('resolved: ${q(t.ResolvedFileName)} original: ${q(t.OriginalPath)} primary: ${b(t.Primary)} external: ${b(t.IsExternalLibraryImport)} pkg: ${q(t.PackageId.String())}\n');
					case "packageDir":
						writeModule(resolver.ResolvePackageDirectory(opName, from, mode, null));
					case "config":
						writeModule(Module.ResolveConfig(opName, from, host));
					case "packageScope":
						final scope = resolver.GetPackageScopeForPath(dir);
						out.add('scope: ${q(scope.GetDirectory())} exists: ${b(scope.Exists())}\n');
					case "automaticTypes":
						final types = Module.GetAutomaticTypeDirectiveNames(o, host);
						out.add("types: " + (types == null ? "" : types.join(",")) + "\n");
					case "entrypoints":
						final scope = resolver.GetPackageScopeForPath(dir);
						final ds = get(op, "dirSearch");
						final eps = resolver.GetEntrypointsFromPackageJsonInfo(scope, str(get(op, "packageName")), ds != null && ds.Kind == "t".code);
						if (eps != null)
							for (e in eps)
								out.add('entrypoint: ${q(e.OriginalFileName)} ${q(e.ResolvedFileName)} ${q(e.ModuleSpecifier)} ending: ${(e.Ending : Int)} include: ${setStr(e.IncludeConditions)} exclude: ${setStr(e.ExcludeConditions)}\n');
					default:
						throw "unknown op " + kind;
				}
			}
		}
		return out.toString();
	}
}
