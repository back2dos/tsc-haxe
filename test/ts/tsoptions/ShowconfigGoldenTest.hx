package ts.tsoptions;

// PORT: extra (not upstream). Golden test against Go for code without an upstream test in this
// package: ConvertToTSConfig (--showConfig) marshalled with json.MarshalIndent, WildcardDirectories,
// and the Go-compatible marshaller in ts.json.Json (escaping, float formatting, indentation).
// golden/showconfig.json holds the scenarios; golden/expected.txt is the Go output of
// golden/zz_golden_test.go.txt. Regenerate expected.txt (from upstream/tsc):
//   echo '{"Replace":{"'$PWD'/internal/tsoptions/zz_golden_test.go":"<repo>/test/ts/tsoptions/golden/zz_golden_test.go.txt"}}' > /tmp/ov.json
//   GOLDEN_IN=<repo>/test/ts/tsoptions/golden/showconfig.json GOLDEN_OUT=<repo>/test/ts/tsoptions/golden/expected.txt \
//     GOTOOLCHAIN=go1.26.9 go test ./internal/tsoptions -run TestGoldenDump -overlay /tmp/ov.json -count=1
// Not covered (hxcpp limitation, PORTING §7a): a -0 float reaches the marshaller through Dynamic
// and loses its sign on hxcpp.
class ShowconfigGoldenTest {
	static inline final DIR = "test/ts/tsoptions/golden/";

	public static function run() {
		T.run("TestShowConfigGolden", () -> {
			final expected = sys.io.File.getContent(DIR + "expected.txt");
			final actual = dump(sys.io.File.getContent(DIR + "showconfig.json"));
			final e = expected.split("\n");
			final a = actual.split("\n");
			var mismatches = 0;
			for (i in 0...(e.length > a.length ? e.length : a.length)) {
				final el = i < e.length ? e[i] : "<eof>";
				final al = i < a.length ? a[i] : "<eof>";
				T.checks++;
				if (el != al) {
					mismatches++;
					if (mismatches <= 5)
						T.fail('line ${i + 1}:\n  want: $el\n  got:  $al');
				}
			}
		});
	}

	static function dump(text:String):String {
		final out = new StringBuf();
		final root = Jsontext.Parse(text).value;
		for (s in root.Items) {
			var name = "";
			var cwd = "";
			var config = "";
			final files = new Map<String, String>();
			for (i in 0...s.Names.length) {
				final v = s.Members[i];
				switch (s.Names[i]) {
					case "name":
						name = v.Str;
					case "cwd":
						cwd = v.Str;
					case "config":
						config = v.Str;
					case "files":
						for (j in 0...v.Names.length)
							files[v.Names[j]] = v.Members[j].Str;
				}
			}
			final host = Tsoptionstest.NewVFSParseConfigHost(files, cwd, true);
			final r = Tsoptions.GetParsedCommandLineOfConfigFile(config, null, null, host, null);
			final parsed = r.a;
			out.add("### " + name + "\n");
			if (r.b != null)
				for (e in r.b)
					out.add("error: " + e.Code() + "\n");
			if (parsed.Errors != null)
				for (e in parsed.Errors)
					out.add("error: " + e.Code() + "\n");
			final cfg = Tsoptions.ConvertToTSConfig(parsed, config);
			out.add(Json.MarshalIndentOrdered(cfg, "", "    "));
			out.add("\n");
			final wd = parsed.WildcardDirectories();
			if (wd != null) {
				final keys = [for (k in wd.keys()) k];
				keys.sort(go.Strings.Compare);
				for (k in keys)
					out.add("wildcard: " + k + " " + (wd.get(k) ? "true" : "false") + "\n");
			}
		}
		out.add("### json values\n");
		final m = new OrderedMap<String, Dynamic>();
		m.Set("s", "a\"b\\c\x00\x01\x08\x09\x0a\x0c\x0d\x1f\x7f<>&  é😀/");
		m.Set("f", ([1.0, 1e21, 1e20, 1e-7, 1e-6, 123.456, 0.1, 1.5e300, 5e-324, -2.5, 12345678.0, 0.000123] : Array<Dynamic>));
		m.Set("i", ([0, -7, 2147483647] : Array<Dynamic>));
		m.Set("b", ([true, false, null] : Array<Dynamic>));
		m.Set("e", ([([] : Array<Dynamic>), new OrderedMap<String, Dynamic>(), ([] : Array<String>)] : Array<Dynamic>));
		out.add(Json.MarshalOrdered(m));
		out.add("\n");
		out.add(Json.MarshalIndentOrdered(m, "", "  "));
		out.add("\n");
		out.add(Json.MarshalIndentOrdered(m, " ", "\t"));
		out.add("\n");
		return out.toString();
	}
}
