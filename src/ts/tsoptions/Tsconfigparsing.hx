package ts.tsoptions;

// Port of tsconfigparsing.go (types and methods; package-level vars and funcs are in Tsoptions.hx).

@:allow(ts.tsoptions)
class ExtendsResult {
	var options:ParsedCompilerOptions = null;
	// watchOptions        compiler.WatchOptions
	var watchOptionsCopied:Bool = false;
	var include:Slice<Dynamic> = null;
	var exclude:Slice<Dynamic> = null;
	var files:Slice<Dynamic> = null;
	var contentMappers:Slice<Dynamic> = null;
	var contentMappersConfigFile:RootedFilePath = cast "";
	var compileOnSave:Bool = false;
	var extendedSourceFiles:Set<RootedFilePath> = new Set<RootedFilePath>();

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
	var validatedFilesSpec:Slice<FileSpec> = null;
	var validatedFileNames:Slice<RootedFilePath> = null;
	// PORT: map[tspath.PathKey]tspath.FileSpec → StringMap keyed by the PathKey text.
	var fileSpecByPath:StringMap<FileSpec> = null;
	var validatedIncludeSpecs:Slice<PathPattern> = null;
	var validatedExcludeSpecs:Slice<PathPattern> = null;
	var validatedFilesSpecBeforeSubstitution:Slice<FileSpec> = null;
	var validatedIncludeSpecsBeforeSubstitution:Slice<PathPattern> = null;
	var isDefaultIncludeSpec:Bool = false;

	public function new() {}

	function getMatchedIncludeSpec(fileName:RootedFilePath, currentDirectory:RootedDirectoryPath, caseSensitivity:CaseSensitivity):PathPattern {
		if (Core.len(this.validatedIncludeSpecs) == 0) {
			return cast "";
		}
		for (index in 0...this.validatedIncludeSpecs.length) {
			final spec = this.validatedIncludeSpecs[index];
			final includeMatcher = Vfsmatch.NewSpecMatcher([spec], currentDirectory, UsageFiles, caseSensitivity);
			if (includeMatcher != null && includeMatcher.MatchFileName(fileName)) {
				return this.validatedIncludeSpecsBeforeSubstitution[index];
			}
		}
		return cast "";
	}

	function getMatchedFileSpec(filePath:PathKey):FileSpec {
		final spec = this.fileSpecByPath == null ? null : this.fileSpecByPath.get(filePath);
		return spec == null ? cast "" : spec;
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
	function GetExtendedConfig(fileName:RootedFilePath, path:PathKey, resolutionStack:Slice<PathKey>, fs:FS):ExtendedConfigCacheEntry;
}

@:allow(ts.tsoptions)
class ExtendedConfigCacheEntry {
	var extendedResult:Null<TsConfigSourceFile> = null;
	var extendedConfig:Null<ParsedTsconfig> = null;
	var errors:Slice<Diagnostic> = null;

	public function new() {}

	public function ExtendedFileNames():Slice<RootedFilePath> {
		if (this.extendedResult != null) {
			return this.extendedResult.ExtendedSourceFiles;
		}
		return null;
	}
}

@:allow(ts.tsoptions)
class ParsedTsconfig {
	var raw:Dynamic = null;
	var options:Null<ParsedCompilerOptions> = null;
	// watchOptions *core.WatchOptions
	var typeAcquisition:Null<TypeAcquisition> = null;
	var extendedConfigPaths:Slice<RootedFilePath> = null;
	var contentMappersConfigFile:RootedFilePath = cast "";

	public function new() {}
}

// PORT: Go embeds *core.CompilerOptions; the embedded pointer is the field CompilerOptions.
@:allow(ts.tsoptions)
class ParsedCompilerOptions {
	public var CompilerOptions:CompilerOptions;
	var unresolvedPaths:Null<UnresolvedCompilerOptionPaths>;

	public function new(CompilerOptions:CompilerOptions, unresolvedPaths:Null<UnresolvedCompilerOptionPaths>) {
		this.CompilerOptions = CompilerOptions;
		this.unresolvedPaths = unresolvedPaths;
	}

	public function ParseOption(key:std.String, value:Dynamic):Slice<Diagnostic> {
		return new CompilerOptionsParser(this.CompilerOptions, this.unresolvedPaths).ParseOption(key, value);
	}
}

@:allow(ts.tsoptions)
class TsConfigSourceFile {
	public var ExtendedSourceFiles:Slice<RootedFilePath> = null;
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
		option:Null<CommandLineOption>) -> Pair<Dynamic, Slice<Diagnostic>> = null;

	public function new(rootOptions:Null<CommandLineOption>,
			onPropertySet:(keyText:std.String, value:Dynamic, propertyAssignment:PropertyAssignment, parentOption:Null<CommandLineOption>,
				option:Null<CommandLineOption>) -> Pair<Dynamic, Slice<Diagnostic>>) {
		this.rootOptions = rootOptions;
		this.onPropertySet = onPropertySet;
	}
}

@:allow(ts.tsoptions)
class TsConfigOptions {
	var prop:Null<StringMap<Array<std.String>>> = null;
	var references:Slice<ProjectReference> = null;
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

	public function GetSpellingSuggestion(name:std.String):Null<CommandLineOption> {
		// PORT: Go maps.Values(m) (random order); the comparison breaks ties.
		return ts.core.Core.GetSpellingSuggestion(name, this == null ? [].iterator() : this.iterator(), function(option:CommandLineOption):std.String {
			return option.Name;
		}, function(a:CommandLineOption, b:CommandLineOption):Int {
			return go.Strings.Compare(a.Name, b.Name);
		});
	}
}

// PORT: main's ParseConfigHost also has IsContentMapperPackageAllowed (an LSP workspace restriction), not
// ported: content mapper packages are always allowed.
interface ParseConfigHost {
	function FS():FS;
}

// Go type defaultParseConfigHost.
class DefaultParseConfigHost implements ParseConfigHost {
	final fs:FS;

	public function new(fs:FS) {
		this.fs = fs;
	}

	public function FS():FS {
		return this.fs;
	}
}

@:allow(ts.tsoptions)
class PropOfRaw {
	var sliceValue:Slice<Dynamic> = null;
	var wrongValue:std.String = "";

	public function new(sliceValue:Slice<Dynamic>, wrongValue:std.String = "") {
		this.sliceValue = sliceValue;
		this.wrongValue = wrongValue;
	}
}

// --- contentmappers.go ---
class ContentMapperResolutionHost implements ts.module.Types.ResolutionHost {
	final fs:FS;
	final currentDirectory:RootedDirectoryPath;

	public function new(fs:FS, currentDirectory:RootedDirectoryPath) {
		this.fs = fs;
		this.currentDirectory = currentDirectory;
	}

	public function FS():FS {
		return fs;
	}

	public function GetCurrentDirectory():RootedDirectoryPath {
		return currentDirectory;
	}
}
