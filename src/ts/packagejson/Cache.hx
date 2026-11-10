package ts.packagejson;

// Port of cache.go (types and methods; typeScriptVersion and NewInfoCache are in Packagejson.hx).

// PORT: embedded Fields → composition field `Fields`; its (promoted) fields are forwarded by
// properties so call sites read like Go (`p.Contents.Exports`).
class PackageJson {
	public var Fields:Fields = new Fields();
	public var Parseable:Bool = false;

	var versionPaths:VersionPaths = new VersionPaths();
	var versionTraces:Slice<DiagnosticAndArgs> = null;
	// PORT: sync.Once → flag.
	var once:Bool = false;

	public function new() {}

	// PORT: promoted fields of the embedded Fields (HeaderFields, PathFields, DependencyFields).
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
	public var Dependencies(get, never):Expected<haxe.ds.StringMap<String>>;
	public var DevDependencies(get, never):Expected<haxe.ds.StringMap<String>>;
	public var PeerDependencies(get, never):Expected<haxe.ds.StringMap<String>>;
	public var OptionalDependencies(get, never):Expected<haxe.ds.StringMap<String>>;

	inline function get_Name()
		return Fields.HeaderFields.Name;

	inline function get_Version()
		return Fields.HeaderFields.Version;

	inline function get_Type()
		return Fields.HeaderFields.Type;

	inline function get_TSConfig()
		return Fields.PathFields.TSConfig;

	inline function get_Main()
		return Fields.PathFields.Main;

	inline function get_Types()
		return Fields.PathFields.Types;

	inline function get_Typings()
		return Fields.PathFields.Typings;

	inline function get_TypesVersions()
		return Fields.PathFields.TypesVersions;

	inline function get_Imports()
		return Fields.PathFields.Imports;

	inline function get_Exports()
		return Fields.PathFields.Exports;

	inline function get_Dependencies()
		return Fields.DependencyFields.Dependencies;

	inline function get_DevDependencies()
		return Fields.DependencyFields.DevDependencies;

	inline function get_PeerDependencies()
		return Fields.DependencyFields.PeerDependencies;

	inline function get_OptionalDependencies()
		return Fields.DependencyFields.OptionalDependencies;

	// PORT: promoted methods of the embedded DependencyFields.
	public inline function HasDependency(name:String):Bool
		return Fields.DependencyFields.HasDependency(name);

	public inline function RangeDependencies(f:(name:String, version:String, dependencyField:String) -> Bool):Void
		Fields.DependencyFields.RangeDependencies(f);

	public inline function GetRuntimeDependencyNames():Set<String>
		return Fields.DependencyFields.GetRuntimeDependencyNames();

	// PORT: Go `trace func(m *diagnostics.Message, args ...any)` → args as an array. The parameter
	// is `trace_`: a call `trace(...)` is always haxe.Log.trace in Haxe.
	public function GetVersionPaths(trace_:Null<(m:Message, args:Array<Any>) -> Void>):VersionPaths {
		#if tshx_parallel
		go.Par.onceMutex.acquire();
		#end
		if (!this.once) {
			this.once = true;
			this.computeVersionPaths();
		}
		#if tshx_parallel
		go.Par.onceMutex.release();
		#end
		if (trace_ != null) {
			if (this.versionTraces != null) {
				for (msg in this.versionTraces) {
					trace_(msg.message, msg.args);
				}
			}
		}
		return this.versionPaths;
	}

	// PORT: body of the p.once.Do closure.
	function computeVersionPaths():Void {
		if (this.versionTraces == null)
			this.versionTraces = [];
		if (this.Fields.PathFields.TypesVersions.Type == JSONValueTypeNotPresent) {
			this.versionTraces.push(new DiagnosticAndArgs(Diagnostics.X_package_json_does_not_have_a_0_field, ["typesVersions"]));
			return;
		}
		if (this.Fields.PathFields.TypesVersions.Type != JSONValueTypeObject) {
			this.versionTraces.push(new DiagnosticAndArgs(Diagnostics.Expected_type_of_0_field_in_package_json_to_be_1_got_2,
				["typesVersions", "object", this.Fields.PathFields.TypesVersions.Type.String()]));
			return;
		}

		this.versionTraces.push(new DiagnosticAndArgs(Diagnostics.X_package_json_has_a_typesVersions_field_with_version_specific_path_mappings,
			["typesVersions"]));

		for (key => value in this.Fields.PathFields.TypesVersions.AsObject().Entries()) {
			final r = Semver.TryParseVersionRange(key);
			final keyRange = r.value;
			if (!r.ok) {
				this.versionTraces.push(new DiagnosticAndArgs(Diagnostics.X_package_json_has_a_typesVersions_entry_0_that_is_not_a_valid_semver_range,
					[key]));
				continue;
			}
			if (keyRange.Test(Packagejson.typeScriptVersion)) {
				if (value.Type != JSONValueTypeObject) {
					this.versionTraces.push(new DiagnosticAndArgs(Diagnostics.Expected_type_of_0_field_in_package_json_to_be_1_got_2,
						["typesVersions['" + key + "']", "object", value.Type.String()]));
					return;
				}
				this.versionPaths = new VersionPaths(key, value.AsObject());
				return;
			}
		}

		this.versionTraces.push(new DiagnosticAndArgs(Diagnostics.X_package_json_does_not_have_a_typesVersions_entry_that_matches_version_0,
			[Core.VersionMajorMinor()]));
	}
}

class DiagnosticAndArgs {
	public final message:Message;
	public final args:Array<Any>;

	public function new(message:Message, args:Array<Any>) {
		this.message = message;
		this.args = args;
	}
}

// PORT: Go value type. GetPaths caches `paths` on the receiver; Go calls it on copies,
// caching on the shared object gives the same results.
class VersionPaths {
	public var Version:String = "";

	var pathsJSON:Null<OrderedMap<String, JSONValue>> = null;
	var paths:Null<OrderedMap<String, Array<String>>> = null;

	public function new(Version:String = "", ?pathsJSON:OrderedMap<String, JSONValue>) {
		this.Version = Version;
		this.pathsJSON = pathsJSON;
	}

	public inline function Exists():Bool {
		return this != null && this.Version != "" && this.pathsJSON != null;
	}

	public function GetPaths():Null<OrderedMap<String, Array<String>>> {
		if (!this.Exists()) {
			return null;
		}
		if (this.paths != null) {
			return this.paths;
		}
		final paths:OrderedMap<String, Array<String>> = Collections.NewOrderedMapWithSizeHint(this.pathsJSON.Size());
		for (key => value in this.pathsJSON.Entries()) {
			if (value.Type != JSONValueTypeArray) {
				continue;
			}
			final arr = value.AsArray();
			final slice = [for (_ in 0...arr.length) ""];
			for (i in 0...arr.length) {
				final path = arr[i];
				if (path.Type != JSONValueTypeString) {
					continue;
				}
				slice[i] = (path.Value : String);
			}
			paths.Set(key, slice);
		}
		this.paths = paths;
		return this.paths;
	}
}

// PORT: Go struct value → final class; == on Go values → Equals.
class PackageDirectory {
	final name:RootedDirectoryPath;
	final key:PathKey;

	public function new(name:RootedDirectoryPath, key:PathKey) {
		this.name = name;
		this.key = key;
	}

	public function toString():String {
		return this.name.AsString();
	}

	public inline function String():String {
		return this.name.AsString();
	}

	public inline function AsDirectoryPath():RootedDirectoryPath {
		return this.name;
	}

	public inline function PathKey():PathKey {
		return this.key;
	}

	public inline function Equals(other:PackageDirectory):Bool {
		return this.name == other.name && this.key == other.key;
	}

	public function Parent():PackageDirectory {
		final parentName = this.name.AsPath().Directory();
		if (parentName == this.name) {
			return this;
		}
		return new PackageDirectory(parentName, this.key.Parent());
	}

	public inline function ResolveFile(path:String):RootedFilePath {
		return this.name.ResolveFile(path);
	}
}

class InfoCacheEntry {
	public var PackageDirectory:PackageDirectory = null;
	public var DirectoryExists:Bool = false;
	public var Contents:Null<PackageJson> = null;

	public function new(PackageDirectory:PackageDirectory, DirectoryExists:Bool = false, ?Contents:PackageJson) {
		this.PackageDirectory = PackageDirectory;
		this.DirectoryExists = DirectoryExists;
		this.Contents = Contents;
	}

	// PORT: nil receiver — inline so a null entry works like Go's nil *InfoCacheEntry.
	public inline function Exists():Bool {
		return this != null && this.Contents != null;
	}

	public inline function GetContents():Null<PackageJson> {
		return this == null || this.Contents == null ? null : this.Contents;
	}

	// WithPackageDirectory returns an entry whose PackageDirectory matches the
	// caller's value. The package.json info cache is keyed by the canonical
	// package directory, but multiple callers may use directory paths whose
	// presentation differs while their canonical identity is the same. Because
	// the cache uses first-writer-wins semantics, a later caller may receive an
	// entry whose PackageDirectory doesn't match its own candidate path.
	// Downstream code compares the candidate against PackageDirectory, so return a
	// corrected shallow copy when they diverge.
	// See https://github.com/microsoft/TypeScript/pull/50740.
	public function WithPackageDirectory(packageDirectory:PackageDirectory):InfoCacheEntry {
		if (this.PackageDirectory == packageDirectory || this.PackageDirectory.Equals(packageDirectory)) {
			return this;
		}
		return new InfoCacheEntry(packageDirectory, this.DirectoryExists, this.Contents);
	}
}

class InfoCache {
	var cache:SyncMap<PathKey, InfoCacheEntry> = new SyncMap<PathKey, InfoCacheEntry>();
	var caseSensitivity:CaseSensitivity;

	public function new(caseSensitivity:CaseSensitivity) {
		this.caseSensitivity = caseSensitivity;
	}

	public inline function PackageDirectory(directory:RootedDirectoryPath):PackageDirectory {
		return new ts.packagejson.Cache.PackageDirectory(directory, this.caseSensitivity.PathKey(directory.AsPath()));
	}

	public inline function CaseSensitivity():CaseSensitivity {
		return this.caseSensitivity;
	}

	public function Get(directory:PackageDirectory):Null<InfoCacheEntry> {
		final r = this.cache.Load(directory.PathKey());
		if (r.ok) {
			return r.value;
		}
		return null;
	}

	public function Set(directory:PackageDirectory, info:InfoCacheEntry):InfoCacheEntry {
		final actual = this.cache.LoadOrStore(directory.PathKey(), info).value;
		return actual;
	}

	public function Range(f:(key:PathKey, value:InfoCacheEntry) -> Bool):Void {
		this.cache.Range(f);
	}
}

