package ts.packagejson;

import haxe.ds.StringMap;

// Port of internal/packagejson: package-level funcs and vars of all files, plus the types of
// packagejson.go.
@:allow(ts.packagejson)
class Packagejson {
	// --- cache.go ---

	// PORT: lazy getter (static init order, PORTING.md §7a).
	public static var typeScriptVersion(get, never):Version;
	static var typeScriptVersion_:Null<Version> = null;

	static function get_typeScriptVersion():Version {
		if (typeScriptVersion_ == null)
			typeScriptVersion_ = Semver.MustParse(Core.Version());
		return typeScriptVersion_;
	}

	public static function NewInfoCache(currentDirectory:String, useCaseSensitiveFileNames:Bool):InfoCache {
		return new InfoCache(currentDirectory, useCaseSensitiveFileNames);
	}

	// --- expected.go ---

	// PORT: reflect — the kind of T is passed explicitly (see ExpectedKind).
	public static function ExpectedOf<T>(value:T, kind:ExpectedKind, ?zero:T):Expected<T> {
		final e = new Expected<T>(kind, zero);
		e.Value = value;
		e.Valid = true;
		e.setActualJSONType(e.ExpectedJSONType());
		return e;
	}

	// --- jsonvalue.go ---

	// PORT: Go `unmarshalJSONValue[T](v, data []byte)` (encoding/json v1 path, unused upstream).
	// `data` is the decoded Jsontext.Value; T values are created with `newT` and filled
	// through their UnmarshalJSONFrom.
	static function unmarshalJSONValue<T:UnmarshalerFrom>(v:JSONValue, data:Value, newT:() -> T):Null<Error> {
		if (data.Kind == "n".code) {
			v.Type = JSONValueTypeNull;
			v.Value = null;
		} else if (data.Kind == '"'.code) {
			v.Type = JSONValueTypeString;
			v.Value = data.Str;
			return null;
		} else if (data.Kind == "[".code) {
			final elements:Array<T> = [];
			for (item in data.Items) {
				final element = newT();
				final err = element.UnmarshalJSONFrom(item);
				if (err != null) {
					return err;
				}
				elements.push(element);
			}
			v.Type = JSONValueTypeArray;
			v.Value = elements;
		} else if (data.Kind == "{".code) {
			final object = new OrderedMap<String, T>(newT());
			final err = unmarshalOrderedMap(object, data, newT);
			if (err != null) {
				return err;
			}
			v.Type = JSONValueTypeObject;
			v.Value = object;
		} else if (data.Kind == "t".code) {
			v.Type = JSONValueTypeBoolean;
			v.Value = true;
		} else if (data.Kind == "f".code) {
			v.Type = JSONValueTypeBoolean;
			v.Value = false;
		} else {
			v.Type = JSONValueTypeNumber;
			v.Value = data.Num;
			return null;
		}
		return null;
	}

	// PORT: `dec` is the decoded Jsontext.Value at the decoder position (see Jsontext.hx).
	// Go leaves `elements` nil for `[]`; here it is an empty array (callers only use len/range).
	static function unmarshalJSONValueV2<T:UnmarshalerFrom>(v:JSONValue, dec:Value, newT:() -> T):Null<Error> {
		switch (dec.Kind) {
			case "n".code: // json.Null.Kind()
				v.Value = null;
				v.Type = JSONValueTypeNull;
				return null;
			case '"'.code:
				v.Type = JSONValueTypeString;
				v.Value = dec.Str;
			case "[".code:
				final elements:Array<T> = [];
				for (item in dec.Items) {
					final element = newT();
					final err = element.UnmarshalJSONFrom(item);
					if (err != null) {
						return err;
					}
					elements.push(element);
				}
				v.Type = JSONValueTypeArray;
				v.Value = elements;
			case "{".code:
				final object = new OrderedMap<String, T>(newT());
				final err = unmarshalOrderedMap(object, dec, newT);
				if (err != null) {
					return err;
				}
				v.Type = JSONValueTypeObject;
				v.Value = object;
			case "t".code, "f".code: // json.True.Kind(), json.False.Kind()
				v.Type = JSONValueTypeBoolean;
				v.Value = dec.Kind == "t".code;
			default:
				v.Type = JSONValueTypeNumber;
				v.Value = dec.Num;
		}
		return null;
	}

	// PORT: collections.OrderedMap[string, T].UnmarshalJSONFrom (ordered_map.go) over a decoded
	// Jsontext.Value: members are Set in document order; a duplicate name keeps its first
	// position and takes the last value (OrderedMap.Set).
	static function unmarshalOrderedMap<T:UnmarshalerFrom>(m:OrderedMap<String, T>, dec:Value, newT:() -> T):Null<Error> {
		if (dec.Kind == "n".code) { // json.Null.Kind()
			return null;
		}
		if (dec.Kind != "{".code) { // json.ObjectStart.Kind()
			return Errors.New("cannot unmarshal non-object JSON value into Map");
		}
		for (i in 0...dec.Names.length) {
			final key = dec.Names[i];
			final value = newT();
			final err = value.UnmarshalJSONFrom(dec.Members[i]);
			if (err != null) {
				return err;
			}
			m.Set(key, value);
		}
		return null;
	}

	// --- packagejson.go ---

	// PORT: (Fields, error) → ValueError. Go json.Unmarshal(data, &f, AllowDuplicateNames(true))
	// with reflection → Jsontext.Parse + unmarshalFields.
	public static function Parse(data:String):ValueError<Fields> {
		final f = new Fields();
		final err = unmarshalFields(data, f);
		if (err != null) {
			return new ValueError<Fields>(new Fields(), err);
		}
		return new ValueError<Fields>(f, null);
	}

	// PORT: json.Unmarshal into Fields (embedded structs are inlined; names match exactly;
	// unknown members are skipped; with AllowDuplicateNames a repeated member is unmarshaled
	// again into the same field).
	static function unmarshalFields(data:String, f:Fields):Null<Error> {
		final r = Jsontext.Parse(data);
		if (r.err != null) {
			return r.err;
		}
		final dec = r.value;
		if (dec.Kind == "n".code) {
			return null;
		}
		if (dec.Kind != "{".code) {
			return Errors.New("json: cannot unmarshal JSON value into Go packagejson.Fields");
		}
		for (i in 0...dec.Names.length) {
			final v = dec.Members[i];
			final err:Null<Error> = switch (dec.Names[i]) {
				case "name": f.HeaderFields.Name.UnmarshalJSON(v);
				case "version": f.HeaderFields.Version.UnmarshalJSON(v);
				case "type": f.HeaderFields.Type.UnmarshalJSON(v);
				case "tsconfig": f.PathFields.TSConfig.UnmarshalJSON(v);
				case "main": f.PathFields.Main.UnmarshalJSON(v);
				case "types": f.PathFields.Types.UnmarshalJSON(v);
				case "typings": f.PathFields.Typings.UnmarshalJSON(v);
				case "typesVersions": f.PathFields.TypesVersions.UnmarshalJSONFrom(v);
				case "imports": f.PathFields.Imports.UnmarshalJSONFrom(v);
				case "exports": f.PathFields.Exports.UnmarshalJSONFrom(v);
				case "dependencies": f.DependencyFields.Dependencies.UnmarshalJSON(v);
				case "devDependencies": f.DependencyFields.DevDependencies.UnmarshalJSON(v);
				case "peerDependencies": f.DependencyFields.PeerDependencies.UnmarshalJSON(v);
				case "optionalDependencies": f.DependencyFields.OptionalDependencies.UnmarshalJSON(v);
				default: null;
			}
			if (err != null) {
				return err;
			}
		}
		return null;
	}
}

class HeaderFields {
	public var Name:Expected<String> = new Expected<String>(KindString, ""); // json:"name"
	public var Version:Expected<String> = new Expected<String>(KindString, ""); // json:"version"
	public var Type:Expected<String> = new Expected<String>(KindString, ""); // json:"type"

	public function new() {}
}

class PathFields {
	public var TSConfig:Expected<String> = new Expected<String>(KindString, ""); // json:"tsconfig"
	public var Main:Expected<String> = new Expected<String>(KindString, ""); // json:"main"
	public var Types:Expected<String> = new Expected<String>(KindString, ""); // json:"types"
	public var Typings:Expected<String> = new Expected<String>(KindString, ""); // json:"typings"
	public var TypesVersions:JSONValue = new JSONValue(); // json:"typesVersions"
	public var Imports:ExportsOrImports = new ExportsOrImports(); // json:"imports"
	public var Exports:ExportsOrImports = new ExportsOrImports(); // json:"exports"

	public function new() {}
}

class DependencyFields {
	public var Dependencies:Expected<StringMap<String>> = new Expected<StringMap<String>>(KindMap); // json:"dependencies"
	public var DevDependencies:Expected<StringMap<String>> = new Expected<StringMap<String>>(KindMap); // json:"devDependencies"
	public var PeerDependencies:Expected<StringMap<String>> = new Expected<StringMap<String>>(KindMap); // json:"peerDependencies"
	public var OptionalDependencies:Expected<StringMap<String>> = new Expected<StringMap<String>>(KindMap); // json:"optionalDependencies"

	public function new() {}

	// HasDependency returns true if the package.json has a dependency with the given name
	// under any of the dependency fields (dependencies, devDependencies, peerDependencies,
	// optionalDependencies).
	public function HasDependency(name:String):Bool {
		final deps = this.Dependencies.GetValue();
		if (deps.ok) {
			if (deps.value.exists(name)) {
				return true;
			}
		}
		final devDeps = this.DevDependencies.GetValue();
		if (devDeps.ok) {
			if (devDeps.value.exists(name)) {
				return true;
			}
		}
		final peerDeps = this.PeerDependencies.GetValue();
		if (peerDeps.ok) {
			if (peerDeps.value.exists(name)) {
				return true;
			}
		}
		final optDeps = this.OptionalDependencies.GetValue();
		if (optDeps.ok) {
			if (optDeps.value.exists(name)) {
				return true;
			}
		}
		return false;
	}

	public function RangeDependencies(f:(name:String, version:String, dependencyField:String) -> Bool):Void {
		final deps = this.Dependencies.GetValue();
		if (deps.ok) {
			for (name => version in deps.value) {
				if (!f(name, version, "dependencies")) {
					return;
				}
			}
		}
		final devDeps = this.DevDependencies.GetValue();
		if (devDeps.ok) {
			for (name => version in devDeps.value) {
				if (!f(name, version, "devDependencies")) {
					return;
				}
			}
		}
		final peerDeps = this.PeerDependencies.GetValue();
		if (peerDeps.ok) {
			for (name => version in peerDeps.value) {
				if (!f(name, version, "peerDependencies")) {
					return;
				}
			}
		}
		final optDeps = this.OptionalDependencies.GetValue();
		if (optDeps.ok) {
			for (name => version in optDeps.value) {
				if (!f(name, version, "optionalDependencies")) {
					return;
				}
			}
		}
	}

	public function GetRuntimeDependencyNames():Set<String> {
		var count = 0;
		final deps = this.Dependencies.GetValue().value;
		count += mapLen(deps);
		final peerDeps = this.PeerDependencies.GetValue().value;
		count += mapLen(peerDeps);
		final optDeps = this.OptionalDependencies.GetValue().value;
		count += mapLen(optDeps);
		final names:Set<String> = Collections.NewSetWithSizeHint(count);
		if (deps != null)
			for (name in deps.keys()) {
				names.Add(name);
			}
		if (peerDeps != null)
			for (name in peerDeps.keys()) {
				names.Add(name);
			}
		if (optDeps != null)
			for (name in optDeps.keys()) {
				names.Add(name);
			}
		return names;
	}

	// PORT: len() of a possibly-nil map.
	static function mapLen(m:Null<StringMap<String>>):Int {
		if (m == null)
			return 0;
		var n = 0;
		for (_ in m.keys())
			n++;
		return n;
	}
}

// PORT: embedded structs → composition fields named after their types; the promoted fields
// are forwarded by properties (read like Go: `f.Name`, `f.Exports`).
class Fields {
	public var HeaderFields:HeaderFields = new HeaderFields();
	public var PathFields:PathFields = new PathFields();
	public var DependencyFields:DependencyFields = new DependencyFields();

	public function new() {}

	public var Name(get, never):Expected<String>;
	public var Version(get, never):Expected<String>;
	public var Type(get, never):Expected<String>;
	public var TSConfig(get, never):Expected<String>;
	public var Main(get, never):Expected<String>;
	public var Types(get, never):Expected<String>;
	public var Typings(get, never):Expected<String>;
	public var TypesVersions(get, never):JSONValue;
	public var Imports(get, never):ExportsOrImports;
	public var Exports(get, never):ExportsOrImports;
	public var Dependencies(get, never):Expected<StringMap<String>>;
	public var DevDependencies(get, never):Expected<StringMap<String>>;
	public var PeerDependencies(get, never):Expected<StringMap<String>>;
	public var OptionalDependencies(get, never):Expected<StringMap<String>>;

	inline function get_Name()
		return HeaderFields.Name;

	inline function get_Version()
		return HeaderFields.Version;

	inline function get_Type()
		return HeaderFields.Type;

	inline function get_TSConfig()
		return PathFields.TSConfig;

	inline function get_Main()
		return PathFields.Main;

	inline function get_Types()
		return PathFields.Types;

	inline function get_Typings()
		return PathFields.Typings;

	inline function get_TypesVersions()
		return PathFields.TypesVersions;

	inline function get_Imports()
		return PathFields.Imports;

	inline function get_Exports()
		return PathFields.Exports;

	inline function get_Dependencies()
		return DependencyFields.Dependencies;

	inline function get_DevDependencies()
		return DependencyFields.DevDependencies;

	inline function get_PeerDependencies()
		return DependencyFields.PeerDependencies;

	inline function get_OptionalDependencies()
		return DependencyFields.OptionalDependencies;
}
