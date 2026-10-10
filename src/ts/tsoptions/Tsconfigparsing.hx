package ts.tsoptions;

// Port of tsconfigparsing.go (types and methods; package-level vars and funcs are in Tsoptions.hx).

@:allow(ts.tsoptions)
class ExtendsResult {
	var options:CompilerOptions = null;
	// watchOptions        compiler.WatchOptions
	var watchOptionsCopied:Bool = false;
	var include:Null<Array<Dynamic>> = null;
	var exclude:Null<Array<Dynamic>> = null;
	var files:Null<Array<Dynamic>> = null;
	var compileOnSave:Bool = false;
	var extendedSourceFiles:Set<std.String> = new Set<std.String>();

	public function new() {}
}

// PORT: Go uses configFileSpecs both by value and by pointer; it is never mutated after it is
// built, so the value copies share one object.
@:allow(ts.tsoptions)
class ConfigFileSpecs {
	var filesSpecs:Dynamic = null;
	// Present to report errors (user specified specs), validatedIncludeSpecs are used for file name matching
	var includeSpecs:Dynamic = null;
	// Present to report errors (user specified specs), validatedExcludeSpecs are used for file name matching
	var excludeSpecs:Dynamic = null;
	var validatedFilesSpec:Null<Array<std.String>> = null;
	var validatedIncludeSpecs:Null<Array<std.String>> = null;
	var validatedExcludeSpecs:Null<Array<std.String>> = null;
	var validatedFilesSpecBeforeSubstitution:Null<Array<std.String>> = null;
	var validatedIncludeSpecsBeforeSubstitution:Null<Array<std.String>> = null;
	var isDefaultIncludeSpec:Bool = false;

	public function new(filesSpecs:Dynamic, includeSpecs:Dynamic, excludeSpecs:Dynamic, validatedFilesSpec:Null<Array<std.String>>,
			validatedIncludeSpecs:Null<Array<std.String>>, validatedExcludeSpecs:Null<Array<std.String>>,
			validatedFilesSpecBeforeSubstitution:Null<Array<std.String>>, validatedIncludeSpecsBeforeSubstitution:Null<Array<std.String>>,
			isDefaultIncludeSpec:Bool) {
		this.filesSpecs = filesSpecs;
		this.includeSpecs = includeSpecs;
		this.excludeSpecs = excludeSpecs;
		this.validatedFilesSpec = validatedFilesSpec;
		this.validatedIncludeSpecs = validatedIncludeSpecs;
		this.validatedExcludeSpecs = validatedExcludeSpecs;
		this.validatedFilesSpecBeforeSubstitution = validatedFilesSpecBeforeSubstitution;
		this.validatedIncludeSpecsBeforeSubstitution = validatedIncludeSpecsBeforeSubstitution;
		this.isDefaultIncludeSpec = isDefaultIncludeSpec;
	}

	function matchesExclude(fileName:std.String, comparePathsOptions:ComparePathsOptions):Bool {
		if (Core.len(this.validatedExcludeSpecs) == 0) {
			return false;
		}
		final excludeMatcher = Vfsmatch.NewSpecMatcher(this.validatedExcludeSpecs, comparePathsOptions.CurrentDirectory, UsageExclude,
			comparePathsOptions.UseCaseSensitiveFileNames);
		if (excludeMatcher == null) {
			return false;
		}
		if (excludeMatcher.MatchString(fileName)) {
			return true;
		}
		if (!Tspath.HasExtension(fileName)) {
			if (excludeMatcher.MatchString(Tspath.EnsureTrailingDirectorySeparator(fileName))) {
				return true;
			}
		}
		return false;
	}

	function getMatchedIncludeSpec(fileName:std.String, comparePathsOptions:ComparePathsOptions):std.String {
		if (Core.len(this.validatedIncludeSpecs) == 0) {
			return "";
		}
		for (index in 0...this.validatedIncludeSpecs.length) {
			final spec = this.validatedIncludeSpecs[index];
			final includeMatcher = Vfsmatch.NewSpecMatcher([spec], comparePathsOptions.CurrentDirectory, UsageFiles,
				comparePathsOptions.UseCaseSensitiveFileNames);
			if (includeMatcher != null && includeMatcher.MatchString(fileName)) {
				return this.validatedIncludeSpecsBeforeSubstitution[index];
			}
		}
		return "";
	}

	function getMatchedFileSpec(fileName:std.String, comparePathsOptions:ComparePathsOptions):std.String {
		if (Core.len(this.validatedFilesSpec) == 0) {
			return "";
		}
		final filePath = Tspath.ToPath(fileName, comparePathsOptions.CurrentDirectory, comparePathsOptions.UseCaseSensitiveFileNames);
		for (index in 0...this.validatedFilesSpec.length) {
			final spec = this.validatedFilesSpec[index];
			if (Tspath.ToPath(spec, comparePathsOptions.CurrentDirectory, comparePathsOptions.UseCaseSensitiveFileNames) == filePath) {
				return this.validatedFilesSpecBeforeSubstitution[index];
			}
		}
		return "";
	}
}

class FileExtensionInfo {
	public var Extension:std.String = "";
	public var IsMixedContent:Bool = false;
	public var ScriptKind:ScriptKind = ScriptKindUnknown;

	public function new(Extension:std.String = "", IsMixedContent:Bool = false, ScriptKind:ScriptKind = ScriptKindUnknown) {
		this.Extension = Extension;
		this.IsMixedContent = IsMixedContent;
		this.ScriptKind = ScriptKind;
	}
}

interface ExtendedConfigCache {
	function GetExtendedConfig(fileName:std.String, path:Path, resolutionStack:Null<Array<Path>>, host:ParseConfigHost):ExtendedConfigCacheEntry;
}

@:allow(ts.tsoptions)
class ExtendedConfigCacheEntry {
	var extendedResult:Null<TsConfigSourceFile> = null;
	var extendedConfig:Null<ParsedTsconfig> = null;
	var errors:Null<Array<Diagnostic>> = null;

	public function new() {}

	public function ExtendedFileNames():Null<Array<std.String>> {
		if (this.extendedResult != null) {
			return this.extendedResult.ExtendedSourceFiles;
		}
		return null;
	}
}

@:allow(ts.tsoptions)
class ParsedTsconfig {
	var raw:Dynamic = null;
	var options:Null<CompilerOptions> = null;
	// watchOptions *core.WatchOptions
	var typeAcquisition:Null<TypeAcquisition> = null;
	// Note that the case of the config path has not yet been normalized, as no files have been imported into the project yet
	var extendedConfigPath:Dynamic = null;

	public function new() {}
}

@:allow(ts.tsoptions)
class TsConfigSourceFile {
	public var ExtendedSourceFiles:Null<Array<std.String>> = null;
	var configFileSpecs:Null<ConfigFileSpecs> = null;
	public var SourceFile:Null<SourceFile> = null;

	public function new(?SourceFile:SourceFile) {
		this.SourceFile = SourceFile;
	}
}

// PORT: Go struct with a func field; the callback returns (any, []*ast.Diagnostic) as a Pair.
@:allow(ts.tsoptions)
class JsonConversionNotifier {
	var rootOptions:Null<CommandLineOption> = null;
	var onPropertySet:(keyText:std.String, value:Dynamic, propertyAssignment:PropertyAssignment, parentOption:Null<CommandLineOption>,
		option:Null<CommandLineOption>) -> Pair<Dynamic, Null<Array<Diagnostic>>> = null;

	public function new(rootOptions:Null<CommandLineOption>,
			onPropertySet:(keyText:std.String, value:Dynamic, propertyAssignment:PropertyAssignment, parentOption:Null<CommandLineOption>,
				option:Null<CommandLineOption>) -> Pair<Dynamic, Null<Array<Diagnostic>>>) {
		this.rootOptions = rootOptions;
		this.onPropertySet = onPropertySet;
	}
}

@:allow(ts.tsoptions)
class TsConfigOptions {
	var prop:Null<StringMap<Array<std.String>>> = null;
	var references:Null<Array<ProjectReference>> = null;
	var notDefined:std.String = "";

	public function new() {}
}

// PORT: Go `map[string]*CommandLineOption` with a Get method. A nil map is null; Get on it
// returns null like a Go nil map lookup.
abstract CommandLineOptionNameMap(StringMap<CommandLineOption>) from StringMap<CommandLineOption> to StringMap<CommandLineOption> {
	public inline function new() {
		this = new StringMap<CommandLineOption>();
	}

	public function Get(name:std.String):Null<CommandLineOption> {
		if (this == null) {
			return null;
		}
		var opt = this.get(name);
		if (opt == null) {
			opt = this.get(Strings.ToLower(name));
		}
		return opt;
	}
}

interface ParseConfigHost {
	function FS():FS;
	function GetCurrentDirectory():std.String;
}

// PORT: Go embeds ParseConfigHost; the two methods are forwarded.
class ResolverHost implements ParseConfigHost implements ts.module.Types.ResolutionHost {
	var ParseConfigHost:ParseConfigHost;

	public function new(ParseConfigHost:ParseConfigHost) {
		this.ParseConfigHost = ParseConfigHost;
	}

	public function FS():FS {
		return this.ParseConfigHost.FS();
	}

	public function GetCurrentDirectory():std.String {
		return this.ParseConfigHost.GetCurrentDirectory();
	}

	public function Trace(msg:std.String):Void {}
}

@:allow(ts.tsoptions)
class PropOfRaw {
	var sliceValue:Null<Array<Dynamic>> = null;
	var wrongValue:std.String = "";

	public function new(sliceValue:Null<Array<Dynamic>>, wrongValue:std.String = "") {
		this.sliceValue = sliceValue;
		this.wrongValue = wrongValue;
	}
}
