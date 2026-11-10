package ts.contentmapper;

import go.Errors;
import go.Errors.Error;
import go.Slices;
import go.Strings;
import go.Tuple;
import haxe.ds.StringMap;
import ts.collections.OrderedMap;
import ts.core.Compileroptions;
import ts.json.Json;
import ts.tspath.Tspath;
import ts.tspath.RootedPath;

// Port of internal/contentmapper (TypeScript main: content mappers, typescript-go #4712, #63936, #64581
// and follow-ups).
//
// Package contentmapper defines the types describing an external content mapper: a plugin that
// transforms otherwise unsupported file content (e.g. .vue) into virtual TypeScript during program
// construction. The package also drives the configured content mappers at build time (Host).
// PORT: the port runs no external processes: see Hostimpl.hx (in-process connections only).
//
// --- contentmapper.go ---
class Contentmapper {
	public static final ErrProjectUnavailable:Error = Errors.New("content mapper project is unavailable");

	// --- host.go ---

	// NewTransformError creates a transform error for the given stage and underlying error.
	public static function NewTransformError(kind:ts.contentmapper.Host.TransformErrorKind, err:Null<Error>):ts.contentmapper.Host.TransformError {
		return new ts.contentmapper.Host.TransformError(kind, err);
	}

	// --- contentmapper.go ---

	public static function IsSupportedVirtualExtension(extension:String):Bool {
		switch (extension) {
			case ".js", ".jsx", ".mjs", ".cjs", ".ts", ".tsx", ".mts", ".cts", ".json":
				return true;
		}
		return false;
	}

	public static function IsValidExtension(extension:String):Bool {
		return extension.length > 1 && StringTools.fastCodeAt(extension, 0) == ".".code && !containsPathSeparator(extension);
	}

	// strings.ContainsAny(extension, "/\\")
	public static function containsPathSeparator(s:String):Bool {
		return s.indexOf("/") >= 0 || s.indexOf("\\") >= 0;
	}

	public static function HasReservedSourceExtension(extension:String):Bool {
		for (extensions in Tspath.AllSupportedExtensionsWithJson) {
			for (nativeExtension in extensions) {
				if (extension.length >= nativeExtension.length
					&& Strings.EqualFold(extension.substring(extension.length - nativeExtension.length), nativeExtension)) {
					return true;
				}
			}
		}
		return false;
	}

	// --- PORT: helpers for the reflection-based option marshalling of Go ---

	// marshalCompilerOptionValue is Go's json.Marshal of one CompilerOptions field value.
	public static function marshalCompilerOptionValue(field:ts.tsoptions.Tsoptions.CompilerOptionsField, value:Dynamic):String {
		switch (field.Kind) {
			case FieldTristate:
				return (cast value : ts.core.Tristate).MarshalJSON();
			case FieldString:
				return Json.Quote(value);
			case FieldStrings:
				final a:Array<String> = value;
				return Json.MarshalOrdered(a == null ? null : [for (s in a) (s : Dynamic)]);
			case FieldEnum, FieldIntPtr:
				return Std.string((value : Int));
			case FieldPaths:
				final m:OrderedMap<String, Slice<String>> = value;
				if (m == null)
					return "null";
				final o = new OrderedMap<String, Dynamic>();
				for (k => v in m.Entries())
					o.Set(k, v == null ? null : [for (s in v) (s : Dynamic)]);
				return Json.MarshalOrdered(o);
			default:
				return "null";
		}
	}

	// MarshalCompilerOptions is Go's json.Marshal(*core.CompilerOptions): every non-zero field (omitzero)
	// under its json name, in field order.
	public static function MarshalCompilerOptions(options:Null<CompilerOptions>):String {
		if (options == null)
			return "null";
		final b = new StringBuf();
		b.add("{");
		var first = true;
		for (field in @:privateAccess ts.tsoptions.Tsoptions.compilerOptionsFields) {
			final value = field.Get(options);
			if (field.IsZero(value))
				continue;
			if (!first)
				b.add(",");
			first = false;
			b.add(Json.Quote(field.JsonName));
			b.add(":");
			b.add(marshalCompilerOptionValue(field, value));
		}
		b.add("}");
		return b.toString();
	}

	// Go json.Marshal(map[string]string, json.Deterministic(true)): keys sorted.
	public static function marshalStringMap(m:StringMap<String>):String {
		final keys = [for (k in m.keys()) k];
		Slices.SortStrings(keys);
		final b = new StringBuf();
		b.add("{");
		for (i in 0...keys.length) {
			if (i > 0)
				b.add(",");
			b.add(Json.Quote(keys[i]));
			b.add(":");
			b.add(Json.Quote(m.get(keys[i])));
		}
		b.add("}");
		return b.toString();
	}

	static function stringMapEquals(a:Null<StringMap<String>>, b:Null<StringMap<String>>):Bool {
		if (a == null || b == null)
			return a == b;
		var n = 0;
		for (k => v in a) {
			n++;
			if (!b.exists(k) || b.get(k) != v)
				return false;
		}
		for (_ in b.keys())
			n--;
		return n == 0;
	}

	static function stringsEqual(a:Slice<String>, b:Slice<String>):Bool {
		if ((a == null) != (b == null))
			return false;
		return Slices.Equal(a, b);
	}
}

// Definition is a content mapper as declared in a tsconfig's "contentMappers": the npm package that
// implements the mapper and the otherwise unsupported file extensions it registers.
class Definition {
	public var Package:String = "";
	public var Extensions:Slice<String> = null;
	// OutputExtensions contains the resolved mapping after applying manifest defaults and project overrides.
	public var OutputExtensions:StringMap<String> = null;
	// PORT: json.Value (raw JSON text); "" is Go's nil.
	public var Options:String = "";

	public function new() {}
}

// Manifest is the content-mapper information read from a package's package.json.
class Manifest {
	public var Name:String = "";
	public var Version:String = "";
	public var Exec:Slice<String> = null;
	public var CompilerOptions:Slice<String> = null;
	public var DynamicConfig:Bool = false;
	public var DefaultOutputExtensions:StringMap<String> = null;

	public function new() {}
}

// Mapper is a resolved content mapper: its tsconfig Definition combined with the Manifest resolved from
// the package's package.json, plus the package directory used as the mapper's working directory.
// PORT: the embedded Definition and Manifest are composition fields; promoted fields are reached through them.
class Mapper {
	public var Definition:Definition = new Definition();
	public var Manifest:Manifest = new Manifest();
	// PackageDirectory is the real path directory returned by package resolution for package-based mappers.
	public var PackageDirectory:RootedDirectoryPath = cast "";
	// ContributionID is provided by an LSP client extension for inferred project content mappers.
	public var ContributionID:String = "";

	public function new() {}

	// DiagnosticName returns the best available user-facing name, including when manifest resolution failed.
	public function DiagnosticName():String {
		if (Manifest.Name != "") {
			return Manifest.Name;
		} else if (Definition.Package != "") {
			return Definition.Package;
		} else {
			return ContributionID;
		}
	}

	// Identity returns the mapper's "name@version" identity, or just the name when it declares no version,
	// or an empty string when the mapper has not been resolved to a name.
	public function Identity():String {
		if (ContributionID != "") {
			return ContributionID + " (" + manifestIdentity() + ")";
		}
		return manifestIdentity();
	}

	function manifestIdentity():String {
		if (Manifest.Name == "") {
			return "";
		} else if (Manifest.Version == "") {
			return Manifest.Name;
		} else {
			return Manifest.Name + "@" + Manifest.Version;
		}
	}

	// Equals compares the complete mapper configuration, not just its advertised identity.
	public function Equals(other:Mapper):Bool {
		if (this == other) {
			return true;
		}
		if (other == null) {
			return false;
		}
		return Definition.Package == other.Definition.Package
			&& @:privateAccess Contentmapper.stringsEqual(Definition.Extensions, other.Definition.Extensions)
			&& @:privateAccess Contentmapper.stringMapEquals(Definition.OutputExtensions, other.Definition.OutputExtensions)
			&& Definition.Options == other.Definition.Options && Manifest.Name == other.Manifest.Name && Manifest.Version == other.Manifest.Version
			&& @:privateAccess Contentmapper.stringsEqual(Manifest.Exec, other.Manifest.Exec)
			&& @:privateAccess Contentmapper.stringsEqual(Manifest.CompilerOptions, other.Manifest.CompilerOptions)
			&& Manifest.DynamicConfig == other.Manifest.DynamicConfig
			&& @:privateAccess Contentmapper.stringMapEquals(Manifest.DefaultOutputExtensions, other.Manifest.DefaultOutputExtensions)
			&& PackageDirectory == other.PackageDirectory && ContributionID == other.ContributionID;
	}

	// TransformIdentity fingerprints the mapper's identity, declared compiler options, and runtime output
	// contract so both transformed-file caches and incremental emit are invalidated when these change.
	// PORT: returns the hex string of the xxh3 128-bit hash (Go returns the xxh3.Uint128; callers hex-encode it).
	public function TransformIdentity(options:Null<CompilerOptions>):String {
		final declared = MarshalDeclaredOptions(options);
		final optionsJSON = Json.MarshalOrdered(declared);
		var outputExtensionsJSON = "";
		if (Definition.OutputExtensions != null && Definition.OutputExtensions.keys().hasNext()) {
			outputExtensionsJSON = Contentmapper.marshalStringMap(Definition.OutputExtensions);
		}
		final buf = new StringBuf();
		buf.add(Identity());
		buf.addChar(0);
		buf.add(Definition.Options);
		buf.addChar(0);
		buf.add(optionsJSON);
		if (outputExtensionsJSON.length > 0) {
			buf.addChar(0);
			buf.add(outputExtensionsJSON);
		}
		return hexOf(go.Xxh3.HashString128(buf.toString()).Bytes());
	}

	public static function hexOf(b:haxe.io.Bytes):String {
		return b.toHex();
	}

	// MarshalDeclaredOptions marshals just the compiler options this mapper declared it depends on, in the
	// declared order, skipping any that are unset.
	// PORT: values are raw JSON texts wrapped as RawJson for Json.MarshalOrdered.
	public function MarshalDeclaredOptions(options:Null<CompilerOptions>):OrderedMap<String, Dynamic> {
		final out = new OrderedMap<String, Dynamic>();
		if (options == null || Core_len(Manifest.CompilerOptions) == 0) {
			return out;
		}
		final fields = @:privateAccess ts.tsoptions.Tsoptions.compilerOptionsFields;
		for (name in Manifest.CompilerOptions) {
			final field = Lambda.find(fields.nilable(), f -> f.JsonName == name);
			if (field == null) {
				continue;
			}
			final value = field.Get(options);
			if (field.IsZero(value)) {
				continue;
			}
			out.Set(name, new RawJson(Contentmapper.marshalCompilerOptionValue(field, value)));
		}
		return out;
	}

	static inline function Core_len(a:Slice<String>):Int {
		return a == null ? 0 : a.length;
	}
}

// PORT: a json.Value inside an ordered value tree: marshalled as its raw text.
class RawJson implements ts.json.Json.OrderedMarshaler {
	public final raw:String;

	public function new(raw:String) {
		this.raw = raw;
	}

	public function MarshalJSONValue():Dynamic {
		// re-decode so that Json.MarshalOrdered writes it back in canonical form
		return Json.UnmarshalOrdered(raw);
	}
}
