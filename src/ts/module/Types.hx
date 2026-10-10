package ts.module;

// Port of types.go.

interface ResolutionHost {
	function FS():FS;
	function GetCurrentDirectory():String;
}

// PORT: Go struct used as a map key (ModeAwareCache). Immutable value type.
class ModeAwareCacheKey {
	public final Name:String;
	public final Mode:ResolutionMode;

	public function new(Name:String = "", Mode:ResolutionMode = ModuleKindNone) {
		this.Name = Name;
		this.Mode = Mode;
	}

	// PORT: struct map key → String (PORTING.md §4a). Inverse: ModeAwareCacheKeyFromKey.
	public function Key():String {
		return (this.Mode : Int) + "\x00" + this.Name;
	}

	public static function ModeAwareCacheKeyFromKey(key:String):ModeAwareCacheKey {
		final i = key.indexOf("\x00");
		return new ModeAwareCacheKey(key.substring(i + 1), (Std.parseInt(key.substring(0, i)) : ResolutionMode));
	}
}

interface ResolvedProjectReference {
	function ConfigName():String;
	function CompilerOptions():CompilerOptions;
}

enum abstract NodeResolutionFeatures(Int) from Int to Int {
	var NodeResolutionFeaturesImports = 1;
	var NodeResolutionFeaturesSelfName = 2;
	var NodeResolutionFeaturesExports = 4;
	var NodeResolutionFeaturesExportsPatternTrailers = 8;
	// allowing `#/` root imports in package.json imports field
	// not supported until mass adoption - https://github.com/nodejs/node/pull/60864
	var NodeResolutionFeaturesImportsPatternRoot = 16;

	var NodeResolutionFeaturesNone = 0;
	// Imports | SelfName | Exports | ExportsPatternTrailers | ImportsPatternRoot
	var NodeResolutionFeaturesAll = 31;
	// Imports | SelfName | Exports | ExportsPatternTrailers
	var NodeResolutionFeaturesNode16Default = 15;
	// All
	var NodeResolutionFeaturesNodeNextDefault = 31;
	// Imports | SelfName | Exports | ExportsPatternTrailers | ImportsPatternRoot
	var NodeResolutionFeaturesBundlerDefault = 31;

	@:op(A | B) static function or(a:NodeResolutionFeatures, b:NodeResolutionFeatures):NodeResolutionFeatures;

	@:op(A & B) static function and(a:NodeResolutionFeatures, b:NodeResolutionFeatures):NodeResolutionFeatures;

	@:op(~A) static function not(a:NodeResolutionFeatures):NodeResolutionFeatures;
}

// PORT: Go value type; never mutated after construction, so copies share it.
class PackageId {
	public var Name:String = "";
	public var SubModuleName:String = "";
	public var Version:String = "";
	public var PeerDependencies:String = "";

	public function new(Name:String = "", SubModuleName:String = "", Version:String = "", PeerDependencies:String = "") {
		this.Name = Name;
		this.SubModuleName = SubModuleName;
		this.Version = Version;
		this.PeerDependencies = PeerDependencies;
	}

	public function String():String {
		return this.PackageName() + "@" + this.Version + this.PeerDependencies;
	}

	public function PackageName():String {
		if (this.SubModuleName != "") {
			return this.Name + "/" + this.SubModuleName;
		}
		return this.Name;
	}
}

class ResolvedModule {
	public var ResolutionDiagnostics:Null<Array<Diagnostic>> = null;
	public var ResolvedFileName:String = "";
	public var OriginalPath:String = "";
	public var Extension:String = "";
	public var ResolvedUsingTsExtension:Bool = false;
	public var PackageId:PackageId = new PackageId();
	public var IsExternalLibraryImport:Bool = false;
	public var AlternateResult:String = "";

	public function new() {}

	// PORT: nil receiver — inline so a null module works like Go's nil *ResolvedModule.
	public inline function IsResolved():Bool {
		return this != null && this.ResolvedFileName != "";
	}
}

class ResolvedTypeReferenceDirective {
	public var ResolutionDiagnostics:Null<Array<Diagnostic>> = null;
	public var Primary:Bool = false;
	public var ResolvedFileName:String = "";
	public var OriginalPath:String = "";
	public var PackageId:PackageId = new PackageId();
	public var IsExternalLibraryImport:Bool = false;

	public function new() {}

	public function IsResolved():Bool {
		return this.ResolvedFileName != "";
	}
}

// Go unexported type `extensions`.
enum abstract Extensions(Int) from Int to Int {
	var extensionsTypeScript = 1;
	var extensionsJavaScript = 2;
	var extensionsDeclaration = 4;
	var extensionsJson = 8;

	// extensionsTypeScript | extensionsJavaScript
	var extensionsImplementationFiles = 3;

	@:op(A | B) static function or(a:Extensions, b:Extensions):Extensions;

	@:op(A & B) static function and(a:Extensions, b:Extensions):Extensions;

	@:op(~A) static function not(a:Extensions):Extensions;

	public function String():String {
		final e:Extensions = cast this;
		final result:Array<String> = [];
		if ((e & extensionsTypeScript) != 0) {
			result.push("TypeScript");
		}
		if ((e & extensionsJavaScript) != 0) {
			result.push("JavaScript");
		}
		if ((e & extensionsDeclaration) != 0) {
			result.push("Declaration");
		}
		if ((e & extensionsJson) != 0) {
			result.push("JSON");
		}
		return result.join(", ");
	}

	public function Array():Array<String> {
		final e:Extensions = cast this;
		var result:Array<String> = [];
		if ((e & extensionsTypeScript) != 0) {
			result = result.concat(Tspath.SupportedTSImplementationExtensions);
		}
		if ((e & extensionsJavaScript) != 0) {
			result = result.concat(Tspath.SupportedJSExtensionsFlat);
		}
		if ((e & extensionsDeclaration) != 0) {
			result = result.concat(Tspath.SupportedDeclarationExtensions);
		}
		if ((e & extensionsJson) != 0) {
			result.push(Tspath.ExtensionJson);
		}
		return result;
	}
}
