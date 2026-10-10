package ts.tsoptions;

import ts.packagejson.Jsontext.Value;

// PORT: extra (not upstream). Test support that Go gets from its libraries:
//   - baseline.Run / baseline.RunAgainstSubmodule (internal/testutil/baseline): compare with the
//     reference files in upstream/ (never copied); on a mismatch the actual text is written to
//     bin/tsoptions/local/<subfolder>/<name> for diffing.
//   - json.Marshal of the option structs (Go reflection + `json:",omitzero"` tags) → an ordered
//     tree for ts.json.Json.MarshalOrdered.
//   - json.Unmarshal into core.CompilerOptions / core.BuildOptions (go-json-experiment defaults:
//     case-sensitive names, unknown names ignored).
//   - go-cmp DeepEqual of the option structs (exported fields only).
class TsoptionsTestUtil {
	static inline final LOCAL = "bin/tsoptions/local/";

	public static function readFile(path:String):Null<String> {
		return sys.FileSystem.exists(path) ? sys.io.File.getContent(path) : null;
	}

	static function compare(reference:String, localName:String, actual:String, ?pos:haxe.PosInfos):Void {
		final expected = readFile(reference);
		T.checks++;
		if (expected != actual) {
			final local = LOCAL + localName;
			final dir = haxe.io.Path.directory(local);
			if (!sys.FileSystem.exists(dir))
				sys.FileSystem.createDirectory(dir);
			sys.io.File.saveContent(local, actual);
			if (expected == null) {
				T.fail('reference baseline missing: $reference (actual written to $local)', pos);
			} else {
				T.fail('baseline differs: $reference (actual written to $local)', pos);
			}
		}
	}

	// baseline.Run (no submodule diff)
	public static function baselineRun(fileName:String, actual:String, subfolder:String, ?pos:haxe.PosInfos):Void {
		compare(T.UPSTREAM + "/testdata/baselines/reference/" + subfolder + "/" + fileName, subfolder + "/" + fileName, actual, pos);
	}

	// baseline.RunAgainstSubmodule
	public static function baselineRunAgainstSubmodule(fileName:String, actual:String, subfolder:String, ?pos:haxe.PosInfos):Void {
		compare(TypeScriptSubmodulePath() + "/tests/baselines/reference/" + subfolder + "/" + fileName, subfolder + "/" + fileName, actual, pos);
	}

	// repo.TypeScriptSubmodulePath (absolute, like Go)
	public static function TypeScriptSubmodulePath():String {
		return Tspath.NormalizeSlashes(Sys.getCwd()) + T.UPSTREAM + "/_submodules/TypeScript";
	}

	// Go strings.Cut
	public static function cut(s:String, sep:String):Triple<String, String, Bool> {
		final i = s.indexOf(sep);
		if (i >= 0) {
			return new Triple<String, String, Bool>(s.substring(0, i), s.substring(i + sep.length), true);
		}
		return new Triple<String, String, Bool>(s, "", false);
	}

	// --- json.Marshal of option structs ---

	static function tristate(m:OrderedMap<String, Dynamic>, name:String, t:Tristate):Void {
		if (t != TSUnknown)
			m.Set(name, t == TSTrue);
	}

	public static function compilerOptionsJson(o:Null<CompilerOptions>):Dynamic {
		if (o == null)
			return null;
		final m = new OrderedMap<String, Dynamic>();
		for (f in Tsoptions.compilerOptionsFields) {
			final v:Dynamic = f.Get(o);
			if (f.IsZero(v))
				continue;
			switch (f.Kind) {
				case FieldTristate:
					m.Set(f.JsonName, (v : Int) == (TSTrue : Int));
				case FieldPaths:
					final paths:OrderedMap<String, Array<String>> = v;
					final pm = new OrderedMap<String, Dynamic>();
					for (k => a in paths.Entries())
						pm.Set(k, a == null ? [] : a);
					m.Set(f.JsonName, pm);
				default:
					m.Set(f.JsonName, v);
			}
		}
		return m;
	}

	public static function buildOptionsJson(o:BuildOptions):Dynamic {
		final m = new OrderedMap<String, Dynamic>();
		tristate(m, "dry", o.Dry);
		tristate(m, "force", o.Force);
		tristate(m, "verbose", o.Verbose);
		if (o.Builders != null)
			m.Set("builders", (o.Builders : Int));
		tristate(m, "stopBuildOnErrors", o.StopBuildOnErrors);
		tristate(m, "clean", o.Clean);
		return m;
	}

	public static function typeAcquisitionJson(o:TypeAcquisition):Dynamic {
		final m = new OrderedMap<String, Dynamic>();
		tristate(m, "enable", o.Enable);
		if (o.Include != null)
			m.Set("include", o.Include);
		if (o.Exclude != null)
			m.Set("exclude", o.Exclude);
		tristate(m, "disableFilenameBasedTypeAcquisition", o.DisableFilenameBasedTypeAcquisition);
		return m;
	}

	// --- json.Unmarshal into option structs ---

	static function rawText(text:String, v:Value):String {
		return text.substring(v.Start, v.End);
	}

	static function strings(v:Value):Null<Array<String>> {
		if (v.Kind == "n".code)
			return null;
		if (v.Kind != "[".code)
			throw "json: cannot unmarshal into []string";
		return [
			for (item in v.Items) {
				if (item.Kind != '"'.code)
					throw "json: cannot unmarshal into string";
				item.Str;
			}
		];
	}

	public static function unmarshalCompilerOptions(text:String):ValueError<CompilerOptions> {
		final o = new CompilerOptions();
		final p = Jsontext.Parse(text);
		if (p.err != null)
			return new ValueError<CompilerOptions>(o, p.err);
		final root = p.value;
		if (root.Kind == "n".code)
			return new ValueError<CompilerOptions>(o, null);
		if (root.Kind != "{".code)
			return new ValueError<CompilerOptions>(o, Errors.New("json: cannot unmarshal into CompilerOptions"));
		try {
			for (i in 0...root.Names.length) {
				final name = root.Names[i];
				final v = root.Members[i];
				var field:CompilerOptionsField = null;
				for (f in Tsoptions.compilerOptionsFields)
					if (f.JsonName == name)
						field = f;
				if (field == null)
					continue;
				switch (field.Kind) {
					case FieldTristate:
						field.Set(o, Tristate.UnmarshalJSON(rawText(text, v)));
					case FieldString:
						field.Set(o, v.Kind == "n".code ? "" : v.Str);
					case FieldStrings:
						field.Set(o, strings(v));
					case FieldEnum:
						field.Set(o, v.Kind == "n".code ? 0 : Std.int(v.Num));
					case FieldIntPtr:
						field.Set(o, v.Kind == "n".code ? null : Std.int(v.Num));
					case FieldPaths:
						if (v.Kind == "n".code) {
							field.Set(o, null);
						} else {
							final pm = new OrderedMap<String, Array<String>>();
							for (j in 0...v.Names.length)
								pm.Set(v.Names[j], strings(v.Members[j]));
							field.Set(o, pm);
						}
				}
			}
		} catch (e:Dynamic) {
			return new ValueError<CompilerOptions>(o, Errors.New(Std.string(e)));
		}
		return new ValueError<CompilerOptions>(o, null);
	}

	public static function unmarshalBuildOptions(text:String):ValueError<BuildOptions> {
		final o = new BuildOptions();
		final p = Jsontext.Parse(text);
		if (p.err != null)
			return new ValueError<BuildOptions>(o, p.err);
		final root = p.value;
		if (root.Kind != "{".code)
			return new ValueError<BuildOptions>(o, root.Kind == "n".code ? null : Errors.New("json: cannot unmarshal into BuildOptions"));
		for (i in 0...root.Names.length) {
			final v = root.Members[i];
			switch (root.Names[i]) {
				case "dry":
					o.Dry = Tristate.UnmarshalJSON(rawText(text, v));
				case "force":
					o.Force = Tristate.UnmarshalJSON(rawText(text, v));
				case "verbose":
					o.Verbose = Tristate.UnmarshalJSON(rawText(text, v));
				case "builders":
					o.Builders = v.Kind == "n".code ? null : Std.int(v.Num);
				case "stopBuildOnErrors":
					o.StopBuildOnErrors = Tristate.UnmarshalJSON(rawText(text, v));
				case "clean":
					o.Clean = Tristate.UnmarshalJSON(rawText(text, v));
				default:
			}
		}
		return new ValueError<BuildOptions>(o, null);
	}

	// --- go-cmp DeepEqual (exported fields) ---

	// Returns "" when equal, else the first differing field.
	public static function compilerOptionsDiff(a:CompilerOptions, b:CompilerOptions):String {
		for (f in Tsoptions.compilerOptionsFields) {
			if (!f.DeepEqual(f.Get(a), f.Get(b)))
				return f.Name + ": " + Std.string(f.Get(a)) + " != " + Std.string(f.Get(b));
		}
		return "";
	}

	public static function buildOptionsDiff(a:BuildOptions, b:BuildOptions):String {
		if (a.Dry != b.Dry)
			return "Dry";
		if (a.Force != b.Force)
			return "Force";
		if (a.Verbose != b.Verbose)
			return "Verbose";
		if (a.Builders != b.Builders)
			return "Builders";
		if (a.StopBuildOnErrors != b.StopBuildOnErrors)
			return "StopBuildOnErrors";
		if (a.Clean != b.Clean)
			return "Clean";
		return "";
	}
}

class StringWriter implements Writer {
	final b = new StringBuf();

	public function new() {}

	public function Write(p:String):ValueError<Int> {
		b.add(p);
		return new ValueError<Int>(p.length, null);
	}

	public function WriteString(s:String):Void {
		b.add(s);
	}

	public function toString():String {
		return b.toString();
	}
}
