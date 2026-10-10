package ts.packagejson;

import haxe.ds.StringMap;

// Port of expected_test.go, exportsorimports_test.go, jsonvalue_test.go, packagejson_test.go.
// Not ported: BenchmarkPackageJSON (benchmark).
class PackagejsonTest {
	// PORT: Go json.Unmarshal into a test-local struct uses reflection; here the members of the
	// top-level object go to the unmarshaler registered for their name.
	static function unmarshalStruct(text:String, fields:StringMap<(v:Value) -> Null<Error>>):Null<Error> {
		final r = Jsontext.Parse(text);
		if (r.err != null)
			return r.err;
		final dec = r.value;
		if (dec.Kind != "{".code)
			return Errors.New("not an object");
		final seen = new StringMap<Bool>();
		for (i in 0...dec.Names.length) {
			final name = dec.Names[i];
			// Go json.Unmarshal (default options) rejects duplicate names.
			if (seen.exists(name))
				return Errors.New("duplicate name " + name);
			seen.set(name, true);
			final f = fields.get(name);
			if (f != null) {
				final err = f(dec.Members[i]);
				if (err != null)
					return err;
			}
		}
		return null;
	}

	public static function run() {
		// --- expected_test.go ---

		T.run("TestExpected", () -> {
			final Name = new Expected<String>(KindString, "");
			final Version = new Expected<String>(KindString, "");
			final Exports = new Expected<Dynamic>(KindInterface);
			final Main = new Expected<String>(KindString, "");

			final jsonString = '{
		"name": "test",
		"version": 2,
		"exports": null
	}';

			final err = unmarshalStruct(jsonString, [
				"name" => Name.UnmarshalJSON,
				"version" => Version.UnmarshalJSON,
				"exports" => Exports.UnmarshalJSON,
				"main" => Main.UnmarshalJSON
			]);
			T.isTrue(err == null);

			T.eq(true, Name.Valid);
			T.eq("test", Name.Value);

			T.eq(false, Version.Valid);
			T.eq("", Version.Value);

			T.isTrue(Exports.Null);
			T.eq(false, Exports.Valid);

			T.eq(false, Main.Valid);
			T.eq(false, Main.Null);
			T.eq("", Main.Value);
		});

		// --- exportsorimports_test.go ---

		T.run("TestExports", () -> {
			// t.Run("UnmarshalJSONV2", ...)
			testExports(text -> {
				final Imports = new ExportsOrImports();
				final Exports = new ExportsOrImports();
				final err = unmarshalStruct(text, ["imports" => Imports.UnmarshalJSONFrom, "exports" => Exports.UnmarshalJSONFrom]);
				return new Triple(Imports, Exports, err);
			});
		});

		// --- jsonvalue_test.go ---

		T.run("TestJSONValue", () -> {
			// t.Run("UnmarshalJSONV2", ...)
			testJSONValue();
		});

		// --- packagejson_test.go ---

		// PORT: skipped, BenchmarkPackageJSON is a benchmark (also needs parser).

		T.run("TestParse", () -> {
			final tests:Array<{name:String, content:String, want:Fields}> = [
				{
					name: "duplicate names",
					content: '{
				"name": "test-package",
				"name": "test-package",
				"version": "1.0.0"
			}',
					want: {
						final f = new Fields();
						f.HeaderFields.Name = Packagejson.ExpectedOf("test-package", KindString, "");
						f.HeaderFields.Version = Packagejson.ExpectedOf("1.0.0", KindString, "");
						f;
					}
				},
			];
			for (tt in tests) {
				final r = Packagejson.Parse(tt.content);
				T.isTrue(r.err == null, tt.name);
				fieldsEqual(tt.want, r.value, tt.name);
			}
		});

		// PORT: extra (not upstream): key order of exports/imports must equal the file order on
		// every target, including integer-like keys, which haxe.Json moves first on JS and
		// which hxcpp's haxe.Json does not keep in order at all.
		T.run("TestParseKeyOrder", () -> {
			final r = Packagejson.Parse('{
				"name": "order",
				"exports": {
					"./b": "./b.js",
					"10": "./ten.js",
					".": {
						"types": "./index.d.ts",
						"require": "./index.cjs",
						"import": {"node": "./node.mjs", "2": "./two.mjs", "default": "./index.mjs"},
						"1": "./one.js",
						"default": "./index.js"
					},
					"./a": null,
					"0": "./zero.js"
				},
				"imports": {"#z": "./z.js", "#1": "./one.js", "#a": "./a.js"},
				"typesVersions": {">=9": {"*": ["x"]}, "*": {"*": ["ts/*"]}, "3": {}}
			}');
			T.isTrue(r.err == null);
			final f = r.value;
			T.eq("./b,10,.,./a,0", [for (k in f.Exports.AsObject().Keys()) k].join(","));
			T.eq(JSONValueTypeNull, f.Exports.AsObject().GetOrZero("./a").Type);
			final dot = f.Exports.AsObject().GetOrZero(".");
			T.isTrue(dot.IsConditions());
			T.eq("types,require,import,1,default", [for (k in dot.AsObject().Keys()) k].join(","));
			T.eq("node,2,default", [for (k in dot.AsObject().GetOrZero("import").AsObject().Keys()) k].join(","));
			T.eq("./two.mjs", (dot.AsObject().GetOrZero("import").AsObject().GetOrZero("2").Value : String));
			T.isTrue(!f.Exports.IsSubpaths()); // mixed "." and other keys
			T.isTrue(f.Imports.IsImports());
			T.eq("#z,#1,#a", [for (k in f.Imports.AsObject().Keys()) k].join(","));
			T.eq(">=9,*,3", [for (k in f.TypesVersions.AsObject().Keys()) k].join(","));
		});

		// PORT: extra (not upstream): duplicate names inside an object keep the first position and
		// the last value (OrderedMap.Set); invalid JSON fails the whole parse like Go.
		T.run("TestParseDuplicatesAndErrors", () -> {
			final r = Packagejson.Parse('{"exports": {"./x": "1", "./y": "2", "./x": "3"}, "dependencies": {"a": "1", "a": "2"}, "peerDependencies": {"p": "1", "q": 2}}');
			T.isTrue(r.err == null);
			T.eq("./x,./y", [for (k in r.value.Exports.AsObject().Keys()) k].join(","));
			T.eq("3", (r.value.Exports.AsObject().GetOrZero("./x").Value : String));
			T.eq(false, r.value.Dependencies.Valid);
			T.eq("object", r.value.Dependencies.ActualJSONType());
			T.eq(false, r.value.PeerDependencies.Valid);
			T.eq(true, r.value.PeerDependencies.Value.exists("q"));
			for (bad in ['{"name": "x",}', '{"name": "x"} x', "{'name': 1}", '{"a": 01}', '{"a": "\\ud800"}', '[1]', '{"a": tru}']) {
				final r2 = Packagejson.Parse(bad);
				T.isTrue(r2.err != null, bad);
				T.eq(false, r2.value.Name.IsPresent());
			}
			final r3 = Packagejson.Parse('{"name": "\\ud83d\\ude00\\u00e9\\n"}');
			T.isTrue(r3.err == null);
			T.eq("\u{1F600}é\n", r3.value.Name.Value);
		});
	}

	static function testExports(unmarshal:(text:String) -> Triple<ExportsOrImports, ExportsOrImports, Null<Error>>) {
		final jsonString = '{
		"imports": {
			"#foo": {
				"import": "./foo.ts"
			}
		},
		"exports": {
			".": {
				"import": "./test.ts",
				"default": "./test.ts"
			},
			"./test": [
				"./test1.ts",
				"./test2.ts",
				null
			],
			"./null": null
		}
	}';

		final r = unmarshal(jsonString);
		final Imports = r.a;
		final Exports = r.b;
		T.isTrue(r.c == null);

		T.isTrue(Exports.IsSubpaths());
		T.eq(3, Exports.AsObject().Size());
		T.isTrue(Exports.AsObject().GetOrZero(".").IsConditions());
		T.isTrue(Exports.AsObject().GetOrZero(".").AsObject().GetOrZero("import").Type == JSONValueTypeString);
		T.eq(JSONValueTypeNull, Exports.AsObject().GetOrZero("./test").AsArray()[2].Type);
		T.isTrue(Exports.AsObject().GetOrZero("./null").Type == JSONValueTypeNull);

		T.isTrue(Imports.IsImports());
		T.eq(1, Imports.AsObject().Size());
		T.isTrue(Imports.AsObject().GetOrZero("#foo").IsConditions());
		T.isTrue(Imports.AsObject().GetOrZero("#foo").AsObject().GetOrZero("import").Type == JSONValueTypeString);
	}

	static function testJSONValue() {
		final Private = new JSONValue();
		final False = new JSONValue();
		final Name = new JSONValue();
		final Version = new JSONValue();
		final Exports = new JSONValue();
		final Imports = new JSONValue();
		final NotPresent = new JSONValue();

		final jsonString = '{
		"private": true,
		"false": false,
		"name": "test",
		"version": 2,
		"exports": {
			".": {
				"import": "./test.ts",
				"default": "./test.ts"
			},
			"./test": [
				"./test1.ts",
				"./test2.ts",
				null
			],
			"./null": null
		},
		"imports": null
	}';

		final err = unmarshalStruct(jsonString, [
			"private" => Private.UnmarshalJSONFrom,
			"false" => False.UnmarshalJSONFrom,
			"name" => Name.UnmarshalJSONFrom,
			"version" => Version.UnmarshalJSONFrom,
			"exports" => Exports.UnmarshalJSONFrom,
			"imports" => Imports.UnmarshalJSONFrom,
			"notPresent" => NotPresent.UnmarshalJSONFrom
		]);
		T.isTrue(err == null);

		T.eq(JSONValueTypeBoolean, Private.Type);
		T.eq(true, (Private.Value : Bool));

		T.eq(JSONValueTypeString, Name.Type);
		T.eq("test", (Name.Value : String));

		T.eq(JSONValueTypeNumber, Version.Type);
		T.eq(2.0, (Version.Value : Float));

		T.eq(JSONValueTypeObject, Exports.Type);
		T.eq(3, Exports.AsObject().Size());
		T.eq(JSONValueTypeObject, Exports.AsObject().GetOrZero(".").Type);
		T.eq("./test.ts", (Exports.AsObject().GetOrZero(".").AsObject().GetOrZero("import").Value : String));

		T.eq(JSONValueTypeArray, Exports.AsObject().GetOrZero("./test").Type);
		T.eq(3, Exports.AsObject().GetOrZero("./test").AsArray().length);
		T.eq("./test1.ts", (Exports.AsObject().GetOrZero("./test").AsArray()[0].Value : String));
		T.eq("./test2.ts", (Exports.AsObject().GetOrZero("./test").AsArray()[1].Value : String));
		T.eq(JSONValueTypeNull, Exports.AsObject().GetOrZero("./test").AsArray()[2].Type);

		T.eq(JSONValueTypeNull, Exports.AsObject().GetOrZero("./null").Type);

		T.eq(JSONValueTypeNull, Imports.Type);
		T.isTrue(Imports.Value == null);

		T.eq(JSONValueTypeNotPresent, NotPresent.Type);
		T.isTrue(NotPresent.Value == null);
	}

	// PORT: assert.DeepEqual with cmpopts.IgnoreUnexported → compare the exported fields.
	static function fieldsEqual(want:Fields, got:Fields, name:String) {
		function expected<V>(a:Expected<V>, b:Expected<V>, field:String) {
			T.isTrue(a.Null == b.Null && a.Valid == b.Valid && a.Value == b.Value, name + ": " + field);
		}
		function mapExpected(a:Expected<StringMap<String>>, b:Expected<StringMap<String>>, field:String) {
			T.isTrue(a.Null == b.Null && a.Valid == b.Valid && mapString(a.Value) == mapString(b.Value), name + ": " + field);
		}
		function jsonValue(a:JSONValue, b:JSONValue, field:String) {
			T.isTrue(a.Type == b.Type && a.Value == b.Value, name + ": " + field);
		}
		expected(want.Name, got.Name, "Name");
		expected(want.Version, got.Version, "Version");
		expected(want.Type, got.Type, "Type");
		expected(want.TSConfig, got.TSConfig, "TSConfig");
		expected(want.Main, got.Main, "Main");
		expected(want.Types, got.Types, "Types");
		expected(want.Typings, got.Typings, "Typings");
		jsonValue(want.TypesVersions, got.TypesVersions, "TypesVersions");
		jsonValue(want.Imports.JSONValue, got.Imports.JSONValue, "Imports");
		jsonValue(want.Exports.JSONValue, got.Exports.JSONValue, "Exports");
		mapExpected(want.Dependencies, got.Dependencies, "Dependencies");
		mapExpected(want.DevDependencies, got.DevDependencies, "DevDependencies");
		mapExpected(want.PeerDependencies, got.PeerDependencies, "PeerDependencies");
		mapExpected(want.OptionalDependencies, got.OptionalDependencies, "OptionalDependencies");
	}

	static function mapString(m:Null<StringMap<String>>):String {
		if (m == null)
			return "<nil>";
		final keys = [for (k in m.keys()) k];
		keys.sort(Reflect.compare);
		return [for (k in keys) k + "=" + m.get(k)].join(",");
	}
}
