package ts.tsoptions;

import ts.glob.Glob;
import ts.locale.Locale;
import ts.outputpaths.Outputpaths;

// Port of parsedcommandline.go (types and methods; the consts are in Tsoptions.hx).
// PORT: sync.Once fields → Bool flags (single-threaded).
@:allow(ts.tsoptions)
class ParsedCommandLine implements ts.module.Types.ResolvedProjectReference implements OutputPathsHost {
	public var ParsedConfig:Null<ParsedOptions> = null; // json:"parsedConfig"

	public var ConfigFile:Null<TsConfigSourceFile> = null; // json:"configFile" // TsConfigSourceFile, used in Program and ExecuteCommandLine
	public var Errors:Slice<Diagnostic> = null; // json:"errors"
	public var Raw:Dynamic = null; // json:"raw"
	public var CompileOnSave:Null<Bool> = null; // json:"compileOnSave"

	var configFileSpecs:Null<ConfigFileSpecs> = null;
	var baseDirectory:RootedDirectoryPath = cast "";
	var caseSensitivity:CaseSensitivity = CaseInsensitive;
	var wildcardDirectoriesOnce:Bool = false;
	// PORT: map[tspath.RootedDirectoryPath]bool → an OrderedMap (deterministic iteration).
	var wildcardDirectories:Null<OrderedMap<RootedDirectoryPath, Bool>> = null;
	var includeGlobsOnce:Bool = false;
	var includeGlobs:Slice<Glob> = null;
	var contentMapperExtensionRewrites:Slice<ExtensionRewrite> = null;
	var contentMapperExtensionRewritesOnce:Bool = false;
	#if tshx_parallel
	var contentMapperExtensionRewritesDone:Bool = false; // PORT: hxmc (-D tshx-parallel) — see ContentMapperExtensionRewrites
	#end

	var sourceAndOutputMapsOnce:Bool = false;
	// PORT: map[tspath.PathKey]... → StringMap keyed by the PathKey text.
	var sourceToProjectReference:Null<StringMap<SourceOutputAndProjectReference>> = null;
	var outputDtsToProjectReference:Null<StringMap<SourceOutputAndProjectReference>> = null;

	var commonSourceDirectory:RootedDirectoryPath = cast "";
	var commonSourceDirectoryOnce:Bool = false;

	var resolvedProjectReferencePaths:Slice<RootedFilePath> = null;
	var resolvedProjectReferencePathsOnce:Bool = false;

	var literalFileNamesLen:Int = 0;
	var rootFileNamesForDiagnostics:Slice<std.String> = null;
	var filePaths:Null<Set<PathKey>> = null;
	var filePathsOnce:Bool = false;

	var locale:Locale = ts.locale.Locale.Default;
	var localeOnce:Bool = false;

	public function new() {}

	// fileGlobPatterns returns the include file glob patterns for this command line, augmenting the
	// built-in patterns with the extensions registered by its content mappers so that created
	// content-mapped files are recognized as possible root files.
	function fileGlobPatterns():Pair<std.String, std.String> {
		final mapperExtensions = this.ContentMapperExtensions();
		if (Core.len(mapperExtensions) == 0) {
			return new Pair(Tsoptions.fileGlobPattern, Tsoptions.recursiveFileGlobPattern);
		}
		final extensions = ["js", "jsx", "mjs", "cjs", "ts", "tsx", "mts", "cts", "json"];
		for (extension in mapperExtensions) {
			extensions.push(StringTools.startsWith(extension, ".") ? extension.substring(1) : extension);
		}
		final fileGlob = "*.{" + extensions.join(",") + "}";
		return new Pair(fileGlob, "**/" + fileGlob);
	}

	public function WithFileNames(fileNames:Slice<RootedFilePath>):ParsedCommandLine {
		final parsedConfig = this.ParsedConfig.copy();
		parsedConfig.FileNames = fileNames;
		final p = new ParsedCommandLine();
		p.ParsedConfig = parsedConfig;
		p.ConfigFile = this.ConfigFile;
		p.Errors = this.Errors;
		p.Raw = this.Raw;
		p.CompileOnSave = this.CompileOnSave;
		p.configFileSpecs = this.configFileSpecs;
		p.baseDirectory = this.baseDirectory;
		p.caseSensitivity = this.caseSensitivity;
		p.wildcardDirectories = this.wildcardDirectories;
		p.includeGlobs = this.includeGlobs;
		p.literalFileNamesLen = this.literalFileNamesLen;
		p.rootFileNamesForDiagnostics = this.rootFileNamesForDiagnostics;
		return p;
	}

	function getConfigFileSpecs():Null<ConfigFileSpecs> {
		if (this.configFileSpecs != null) {
			return this.configFileSpecs;
		}
		if (this.ConfigFile != null) {
			return this.ConfigFile.configFileSpecs;
		}
		return null;
	}

	public function ConfigName():RootedFilePath {
		if (this == null || this.ConfigFile == null) {
			return cast "";
		}
		return this.ConfigFile.SourceFile.FileName();
	}

	public function ConfigFileName():RootedFilePath {
		final configName = this.ConfigName();
		if (configName != "") {
			return configName;
		}
		return this.CompilerOptions().ConfigFilePath;
	}

	public function SourceToProjectReference():Null<StringMap<SourceOutputAndProjectReference>> {
		return this.sourceToProjectReference;
	}

	public function OutputDtsToProjectReference():Null<StringMap<SourceOutputAndProjectReference>> {
		return this.outputDtsToProjectReference;
	}

	public function ParseInputOutputNames():Void {
		if (!this.sourceAndOutputMapsOnce) {
			this.sourceAndOutputMapsOnce = true;
			final sourceToOutput = new StringMap<SourceOutputAndProjectReference>();
			final outputDtsToSource = new StringMap<SourceOutputAndProjectReference>();

			this.getOutputDeclarationAndSourceFileNames()(function(outputDtsFileName:RootedFilePath, sourceFileName:RootedFilePath):Bool {
				final projectReference = new SourceOutputAndProjectReference();
				projectReference.Source = sourceFileName;
				projectReference.SourcePath = this.caseSensitivity.PathKey(sourceFileName.AsPath());
				projectReference.OutputDts = outputDtsFileName;
				projectReference.Resolved = this;
				if (outputDtsFileName != "") {
					projectReference.OutputDtsPath = this.caseSensitivity.PathKey(outputDtsFileName.AsPath());
					outputDtsToSource.set(projectReference.OutputDtsPath, projectReference);
				}
				sourceToOutput.set(projectReference.SourcePath, projectReference);
				return true;
			});
			this.outputDtsToProjectReference = outputDtsToSource;
			this.sourceToProjectReference = sourceToOutput;
		}
	}

	public function CommonSourceDirectory():RootedDirectoryPath {
		#if tshx_parallel
		// PORT: hxmc (-D tshx-parallel) — sync.Once: a checker thread asks a referenced project's config
		// (resolveExternalModule, rewritten relative import extensions)
		go.Par.onceMutex.acquire();
		#end
		if (!this.commonSourceDirectoryOnce) {
			this.commonSourceDirectoryOnce = true;
			final files = function():Slice<RootedFilePath> {
				return Core.Filter(this.ParsedConfig.FileNames, function(file:RootedFilePath):Bool {
					return !(this.ParsedConfig.CompilerOptions.NoEmitForJsFiles.IsTrue() && file.HasJSFileExtension()) && !file.IsDeclarationFile();
				});
			};

			this.commonSourceDirectory = Outputpaths.GetCommonSourceDirectory(this.ParsedConfig.CompilerOptions, files, this.BaseDirectory(),
				this.CaseSensitivity(), null);
		}
		#if tshx_parallel
		go.Par.onceMutex.release();
		#end
		return this.commonSourceDirectory;
	}

	public function BaseDirectory():RootedDirectoryPath {
		return this.baseDirectory;
	}

	public function CaseSensitivity():CaseSensitivity {
		return this.caseSensitivity;
	}

	// PORT: iter.Seq2[tspath.RootedFilePath, tspath.RootedFilePath] → a function that takes the yield callback.
	function getOutputDeclarationAndSourceFileNames():(yield_:(dtsName:RootedFilePath, inputName:RootedFilePath) -> Bool) -> Void {
		return function(yield_:(dtsName:RootedFilePath, inputName:RootedFilePath) -> Bool):Void {
			if (this.ParsedConfig.FileNames == null)
				return;
			for (fileName in this.ParsedConfig.FileNames) {
				var outputDts:RootedFilePath = cast "";
				if (!fileName.IsDeclarationFile() && !fileName.ExtensionIs(Tspath.ExtensionJson)) {
					outputDts = Outputpaths.GetOutputDeclarationFileNameWorker(fileName, this.CompilerOptions(), this);
				}
				if (!yield_(outputDts, fileName)) {
					return;
				}
			}
		};
	}

	// PORT: iter.Seq[tspath.RootedFilePath] → Iterator; the outputs are collected eagerly (the Go
	// generator has no side effects).
	public function GetOutputFileNames():Iterator<RootedFilePath> {
		final result:Array<RootedFilePath> = [];
		final yield_ = function(outputName:RootedFilePath):Bool {
			result.push(outputName);
			return true;
		};
		(function():Void {
			if (this.ParsedConfig.FileNames == null)
				return;
			for (fileName in this.ParsedConfig.FileNames) {
				if (fileName.IsDeclarationFile()) {
					continue;
				}
				final jsFileName = Outputpaths.GetOutputJSFileName(fileName, this.CompilerOptions(), this);
				final isJson = fileName.ExtensionIs(Tspath.ExtensionJson);
				if (jsFileName != "") {
					if (!yield_(jsFileName)) {
						return;
					}
					if (!isJson) {
						final sourceMap = Outputpaths.GetSourceMapFilePath(jsFileName, this.CompilerOptions());
						if (sourceMap != "") {
							if (!yield_(sourceMap)) {
								return;
							}
						}
					}
				}
				if (isJson) {
					continue;
				}
				if (this.CompilerOptions().GetEmitDeclarations()) {
					final dtsFileName = Outputpaths.GetOutputDeclarationFileNameWorker(fileName, this.CompilerOptions(), this);
					if (!yield_(dtsFileName)) {
						return;
					}
					if (this.GetContentMapperForFileName(fileName) == null && this.CompilerOptions().GetAreDeclarationMapsEnabled()) {
						final declarationMap = dtsFileName.AppendSuffix(".map");
						if (!yield_(declarationMap)) {
							return;
						}
					}
				}
			}
		})();
		return result.iterator();
	}

	public function GetBuildInfoFileName():RootedFilePath {
		return Outputpaths.GetBuildInfoFileName(this.CompilerOptions(), this.caseSensitivity);
	}

	// WildcardDirectories returns the cached wildcard directories, initializing them if needed
	public function WildcardDirectories():Null<OrderedMap<RootedDirectoryPath, Bool>> {
		if (this == null) {
			return null;
		}

		if (!this.wildcardDirectoriesOnce) {
			this.wildcardDirectoriesOnce = true;
			if (this.wildcardDirectories == null) {
				final specs = this.getConfigFileSpecs();
				this.wildcardDirectories = Tsoptions.getWildcardDirectories(specs.validatedIncludeSpecs, specs.validatedExcludeSpecs, this.baseDirectory,
					this.caseSensitivity);
			}
		}

		return this.wildcardDirectories;
	}

	public function WildcardDirectoryGlobs():Slice<Glob> {
		final wildcardDirectories = this.WildcardDirectories();
		if (wildcardDirectories == null) {
			return null;
		}

		if (!this.includeGlobsOnce) {
			this.includeGlobsOnce = true;
			if (this.includeGlobs == null) {
				final patterns = this.fileGlobPatterns();
				final globs:Array<Glob> = [];
				for (dir => recursive in wildcardDirectories.Entries()) {
					final pattern = Tspath.CombinePaths(dir.AsString(), Core.IfElse(recursive, patterns.b, patterns.a));
					final parsed = Glob.Parse(pattern);
					if (parsed.err == null) {
						globs.push(parsed.value);
					}
				}
				this.includeGlobs = globs;
			}
		}

		return this.includeGlobs;
	}

	// Normalized file names explicitly specified in `files`
	public function LiteralFileNames():Slice<RootedFilePath> {
		if (this != null && this.ConfigFile != null) {
			return this.FileNames().slice(0, this.literalFileNamesLen);
		}
		return null;
	}

	public function SetParsedOptions(o:ParsedOptions):Void {
		this.ParsedConfig = o;
	}

	public function SetCompilerOptions(o:CompilerOptions):Void {
		this.ParsedConfig.CompilerOptions = o;
	}

	public function CompilerOptions():Null<CompilerOptions> {
		if (this == null) {
			return null;
		}
		return this.ParsedConfig.CompilerOptions;
	}

	public function SetTypeAcquisition(o:TypeAcquisition):Void {
		this.ParsedConfig.TypeAcquisition = o;
	}

	public function TypeAcquisition():Null<TypeAcquisition> {
		return this.ParsedConfig.TypeAcquisition;
	}

	// All file names matched by files, include, and exclude patterns
	public function FileNames():Slice<RootedFilePath> {
		return this.ParsedConfig.FileNames;
	}

	public function RootFileNameForDiagnostic(index:Int):std.String {
		if (index < Core.len(this.rootFileNamesForDiagnostics)) {
			return this.rootFileNamesForDiagnostics[index];
		}
		return this.ParsedConfig.FileNames[index].AsString();
	}

	public function FilePaths():Set<PathKey> {
		if (!this.filePathsOnce) {
			this.filePathsOnce = true;
			this.filePaths = new Set<PathKey>();
			if (this.ParsedConfig.FileNames != null) {
				for (fileName in this.ParsedConfig.FileNames) {
					final path = this.caseSensitivity.PathKey(fileName.AsPath());
					this.filePaths.Add(path);
				}
			}
		}
		return this.filePaths;
	}

	public function ProjectReferences():Slice<ProjectReference> {
		return this.ParsedConfig.ProjectReferences;
	}

	public function ContentMappers():Slice<Mapper> {
		if (this == null || this.ParsedConfig == null) {
			return null;
		}
		return this.ParsedConfig.ContentMappers;
	}

	// ContentMapperExtensions returns the flattened list of file extensions registered by the
	// config's content mappers.
	public function ContentMapperExtensions():Slice<std.String> {
		return Core.FlatMap(this.ContentMappers(), function(m:Mapper):Array<std.String> {
			return m.Definition.Extensions.nilable();
		});
	}

	public function ContentMapperExtensionRewrites():Slice<ExtensionRewrite> {
		#if tshx_parallel
		// PORT: hxmc (-D tshx-parallel) — sync.Once: the checker threads ask first (resolveExternalModule, per import);
		// contentMapperExtensionRewritesDone is set after the value, outside the lock, for the lock-free fast path
		if (this.contentMapperExtensionRewritesDone) {
			return this.contentMapperExtensionRewrites;
		}
		go.Par.onceMutex.acquire();
		#end
		if (!this.contentMapperExtensionRewritesOnce) {
			this.contentMapperExtensionRewritesOnce = true;
			this.contentMapperExtensionRewrites = this.computeContentMapperExtensionRewrites();
		}
		#if tshx_parallel
		go.Par.onceMutex.release();
		this.contentMapperExtensionRewritesDone = true;
		#end
		return this.contentMapperExtensionRewrites;
	}

	function computeContentMapperExtensionRewrites():Slice<ExtensionRewrite> {
		final result:Array<ExtensionRewrite> = [];
		var hasNonIdentityMapping = false;
		final ignoreCase = this.CaseSensitivity().IsCaseInsensitive();
		final mappers = this.ContentMappers();
		if (mappers != null) {
			for (mapper in mappers) {
				final outputExtensions = mapper.Definition.OutputExtensions;
				for (source in (mapper.Definition.Extensions == null ? [] : mapper.Definition.Extensions)) {
					final o = getContentMapperOutputExtension(outputExtensions, source, ignoreCase);
					var target = o.value;
					if (!o.ok || target == source || ignoreCase && Strings.EqualFold(target, source)) {
						target = source;
					} else {
						hasNonIdentityMapping = true;
					}
					result.push(new ExtensionRewrite(source, target));
				}
			}
		}
		if (!hasNonIdentityMapping) {
			return null;
		}
		// Identity entries prevent shorter mappings from claiming a longer registered extension.
		// The runtime helper uses the first match, so emit the longest extensions first.
		haxe.ds.ArraySort.sort(result, (a, b) -> b.Source.length - a.Source.length); // PORT: slices.SortStableFunc
		return result;
	}

	public static function getContentMapperOutputExtension(outputExtensions:Null<StringMap<std.String>>, sourceExtension:std.String,
			ignoreCase:Bool):ValueOk<std.String> {
		if (outputExtensions == null) {
			return new ValueOk("", false);
		}
		if (outputExtensions.exists(sourceExtension)) {
			return new ValueOk(outputExtensions.get(sourceExtension), true);
		}
		if (ignoreCase) {
			// PORT: Go iterates the map in random order; iterate the sorted keys.
			final keys = [for (k in outputExtensions.keys()) k];
			Slices.SortStrings(keys);
			for (source in keys) {
				if (Strings.EqualFold(source, sourceExtension)) {
					return new ValueOk(outputExtensions.get(source), true);
				}
			}
		}
		return new ValueOk("", false);
	}

	// GetContentMapperForFileName returns the configured content mapper whose extensions include fileName,
	// or nil if no content mapper is registered for the file's extension.
	public function GetContentMapperForFileName(fileName:RootedFilePath):Null<Mapper> {
		final caseSensitivity = this.CaseSensitivity();
		final extension = fileName.LongestExtension(this.ContentMapperExtensions(), caseSensitivity);
		final mappers = this.ContentMappers();
		if (mappers != null) {
			for (mapper in mappers) {
				if (mapper.Definition.Extensions != null && Lambda.exists(mapper.Definition.Extensions.nilable(), function(mapperExtension:std.String):Bool {
					return extension == mapperExtension || caseSensitivity.IsCaseInsensitive() && Strings.EqualFold(extension, mapperExtension);
				})) {
					return mapper;
				}
			}
		}
		return null;
	}

	public function ResolvedProjectReferencePaths():Slice<RootedFilePath> {
		if (!this.resolvedProjectReferencePathsOnce) {
			this.resolvedProjectReferencePathsOnce = true;
			this.resolvedProjectReferencePaths = Core.Map(this.ParsedConfig.ProjectReferences, Core.ResolveProjectReferencePath);
		}
		return this.resolvedProjectReferencePaths;
	}

	public function ExtendedSourceFiles():Slice<RootedFilePath> {
		if (this == null || this.ConfigFile == null) {
			return null;
		}
		return this.ConfigFile.ExtendedSourceFiles;
	}

	public function GetConfigFileParsingDiagnostics():Slice<Diagnostic> {
		if (this.ConfigFile != null) {
			// todo: !!! should be ConfigFile.ParseDiagnostics, check if they are the same
			return Slices.Concat(this.ConfigFile.SourceFile.Diagnostics(), this.Errors);
		}
		return this.Errors;
	}

	// PossiblyMatchesFileName is a fast check to see if a file is currently included by a config
	// or would be included if the file were to be created. It may return false positives.
	public function PossiblyMatchesFileName(fileName:RootedFilePath):Bool {
		final path = this.caseSensitivity.PathKey(fileName.AsPath());
		if (this.FilePaths().Has(path)) {
			return true;
		}

		final specs = this.getConfigFileSpecs();
		if (specs.validatedIncludeSpecs != null) {
			for (include in specs.validatedIncludeSpecs) {
				final text = include.AsString();
				if (!(Strings.IndexAny(text, "*?") >= 0) && !Vfsmatch.IsImplicitGlob(text)) {
					final includePath = this.CaseSensitivity().PathKey(Tspath.ToRootedPath(text, this.BaseDirectory()));
					if (includePath == path) {
						return true;
					}
				}
			}
		}
		if (this.GetContentMapperForFileName(fileName) != null) {
			final directoryPath = path.Parent();
			if (this.PossiblyMatchesDirectoryName(directoryPath)) {
				return true;
			}
		}
		final wildcardDirectoryGlobs = this.WildcardDirectoryGlobs();
		if (Core.len(wildcardDirectoryGlobs) > 0) {
			for (glob in wildcardDirectoryGlobs) {
				if (glob.Match(fileName.AsString())) {
					return true;
				}
			}
		}
		return false;
	}

	public function PossiblyMatchesDirectoryName(directoryPath:PathKey):Bool {
		final wildcardDirectories = this.WildcardDirectories();
		if (wildcardDirectories != null) {
			for (wildcardDir => recursive in wildcardDirectories.Entries()) {
				final wildcardDirPath = this.caseSensitivity.PathKey(wildcardDir.AsPath());
				if (recursive) {
					if (wildcardDirPath.ContainsPath(directoryPath)) {
						return true;
					}
				} else {
					if (wildcardDirPath == directoryPath) {
						return true;
					}
				}
			}
		}
		return false;
	}

	public function GetMatchedFileSpec(fileName:RootedFilePath):std.String {
		return this.getConfigFileSpecs().getMatchedFileSpec(this.caseSensitivity.PathKey(fileName.AsPath())).AsString();
	}

	// PORT: (string, bool) → ValueOk.
	public function GetMatchedIncludeSpec(fileName:RootedFilePath):ValueOk<std.String> {
		final specs = this.getConfigFileSpecs();
		if (Core.len(specs.validatedIncludeSpecs) == 0) {
			return new ValueOk<std.String>("", false);
		}

		if (specs.isDefaultIncludeSpec) {
			return new ValueOk<std.String>(specs.validatedIncludeSpecs[0].AsString(), true);
		}

		return new ValueOk<std.String>(specs.getMatchedIncludeSpec(fileName, this.baseDirectory, this.caseSensitivity).AsString(), false);
	}

	public function ReloadFileNamesOfParsedCommandLine(fs:FS):ParsedCommandLine {
		final parsedConfig = this.ParsedConfig.copy();
		final r = Tsoptions.getFileNamesFromConfigSpecs(this.getConfigFileSpecs(), this.BaseDirectory(), this.CompilerOptions(), fs,
			this.ContentMapperExtensions());
		final fileNames = r.a;
		final literalFileNamesLen = r.b;
		parsedConfig.FileNames = fileNames;
		final parsedCommandLine = new ParsedCommandLine();
		parsedCommandLine.ParsedConfig = parsedConfig;
		parsedCommandLine.ConfigFile = this.ConfigFile;
		parsedCommandLine.Errors = this.Errors;
		parsedCommandLine.Raw = this.Raw;
		parsedCommandLine.CompileOnSave = this.CompileOnSave;
		parsedCommandLine.configFileSpecs = this.configFileSpecs;
		parsedCommandLine.baseDirectory = this.baseDirectory;
		parsedCommandLine.caseSensitivity = this.caseSensitivity;
		parsedCommandLine.wildcardDirectories = this.wildcardDirectories;
		parsedCommandLine.includeGlobs = this.includeGlobs;
		parsedCommandLine.literalFileNamesLen = literalFileNamesLen;
		parsedCommandLine.rootFileNamesForDiagnostics = this.rootFileNamesForDiagnostics;
		return parsedCommandLine;
	}

	public function Locale():Locale {
		if (!this.localeOnce) {
			this.localeOnce = true;
			// Go: `p.locale, _ = locale.Parse(...)` keeps the (partly) parsed tag even when parsing fails.
			this.locale = ts.locale.Locale.ParseOk(this.CompilerOptions().Locale).value;
		}
		return this.locale;
	}
}

class SourceOutputAndProjectReference {
	public var Source:RootedFilePath = cast "";
	public var SourcePath:PathKey = cast "";
	public var OutputDts:RootedFilePath = cast "";
	public var OutputDtsPath:PathKey = cast "";
	public var Resolved:ParsedCommandLine = null;

	public function new() {}
}
