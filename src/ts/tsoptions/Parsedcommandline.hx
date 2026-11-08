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
	public var Errors:Null<Array<Diagnostic>> = null; // json:"errors"
	public var Raw:Dynamic = null; // json:"raw"
	public var CompileOnSave:Null<Bool> = null; // json:"compileOnSave"

	var comparePathsOptions:ComparePathsOptions = new ComparePathsOptions();
	var wildcardDirectoriesOnce:Bool = false;
	var wildcardDirectories:Null<StringMap<Bool>> = null;
	var includeGlobsOnce:Bool = false;
	var includeGlobs:Null<Array<Glob>> = null;
	var contentMapperExtensionRewrites:Null<Array<ExtensionRewrite>> = null;
	var contentMapperExtensionRewritesOnce:Bool = false;

	var sourceAndOutputMapsOnce:Bool = false;
	var sourceToProjectReference:Null<StringMap<SourceOutputAndProjectReference>> = null;
	var outputDtsToProjectReference:Null<StringMap<SourceOutputAndProjectReference>> = null;

	var commonSourceDirectory:std.String = "";
	var commonSourceDirectoryOnce:Bool = false;

	var resolvedProjectReferencePaths:Null<Array<RootedFilePath>> = null;
	var resolvedProjectReferencePathsOnce:Bool = false;

	var literalFileNamesLen:Int = 0;
	var fileNamesByPath:Null<StringMap<std.String>> = null; // maps file names to their paths, used for quick lookups
	var fileNamesByPathOnce:Bool = false;

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

	public function ConfigName():std.String {
		if (this == null || this.ConfigFile == null) {
			return "";
		}
		return this.ConfigFile.SourceFile.FileName();
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

			this.getOutputDeclarationAndSourceFileNames()(function(outputDts:std.String, source:std.String):Bool {
				final path = Tspath.ToPath(source, this.GetCurrentDirectory(), this.UseCaseSensitiveFileNames());
				final projectReference = new SourceOutputAndProjectReference();
				projectReference.Source = source;
				projectReference.OutputDts = outputDts;
				projectReference.Resolved = this;
				if (outputDts != "") {
					outputDtsToSource.set(Tspath.ToPath(outputDts, this.GetCurrentDirectory(), this.UseCaseSensitiveFileNames()), projectReference);
				}
				sourceToOutput.set(path, projectReference);
				return true;
			});
			this.outputDtsToProjectReference = outputDtsToSource;
			this.sourceToProjectReference = sourceToOutput;
		}
	}

	public function CommonSourceDirectory():std.String {
		if (!this.commonSourceDirectoryOnce) {
			this.commonSourceDirectoryOnce = true;
			final files = function():Array<std.String> {
				return Core.Filter(this.ParsedConfig.FileNames, function(file:std.String):Bool {
					return !(this.ParsedConfig.CompilerOptions.NoEmitForJsFiles.IsTrue() && Tspath.HasJSFileExtension(file))
						&& !Tspath.IsDeclarationFileName(file);
				});
			};

			this.commonSourceDirectory = Outputpaths.GetCommonSourceDirectory(this.ParsedConfig.CompilerOptions, files, this.GetCurrentDirectory(),
				this.UseCaseSensitiveFileNames(), null);
		}
		return this.commonSourceDirectory;
	}

	public function GetCurrentDirectory():RootedDirectoryPath {
		return /* PORT: transitional, unchecked */ cast this.comparePathsOptions.CurrentDirectory;
	}

	public function UseCaseSensitiveFileNames():Bool {
		return this.comparePathsOptions.UseCaseSensitiveFileNames;
	}

	// PORT: iter.Seq2[string, string] → a function that takes the yield callback.
	function getOutputDeclarationAndSourceFileNames():(yield_:(dtsName:std.String, inputName:std.String) -> Bool) -> Void {
		return function(yield_:(dtsName:std.String, inputName:std.String) -> Bool):Void {
			if (this.ParsedConfig.FileNames == null)
				return;
			for (fileName in this.ParsedConfig.FileNames) {
				var outputDts = "";
				if (!Tspath.IsDeclarationFileName(fileName) && !Tspath.FileExtensionIs(fileName, Tspath.ExtensionJson)) {
					outputDts = Outputpaths.GetOutputDeclarationFileNameWorker(fileName, this.CompilerOptions(), this);
				}
				if (!yield_(outputDts, fileName)) {
					return;
				}
			}
		};
	}

	// PORT: iter.Seq[string] → Iterator<String>; the outputs are collected eagerly (the Go
	// generator has no side effects).
	public function GetOutputFileNames():Iterator<std.String> {
		final result:Array<std.String> = [];
		final yield_ = function(outputName:std.String):Bool {
			result.push(outputName);
			return true;
		};
		(function():Void {
			if (this.ParsedConfig.FileNames == null)
				return;
			for (fileName in this.ParsedConfig.FileNames) {
				if (Tspath.IsDeclarationFileName(fileName)) {
					continue;
				}
				final jsFileName = Outputpaths.GetOutputJSFileName(fileName, this.CompilerOptions(), this);
				final isJson = Tspath.FileExtensionIs(fileName, Tspath.ExtensionJson);
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
					if (dtsFileName != "") {
						if (!yield_(dtsFileName)) {
							return;
						}
						if (this.GetContentMapperForFileName(fileName) == null && this.CompilerOptions().GetAreDeclarationMapsEnabled()) {
							final declarationMap = dtsFileName + ".map";
							if (!yield_(declarationMap)) {
								return;
							}
						}
					}
				}
			}
		})();
		return result.iterator();
	}

	public function GetBuildInfoFileName():std.String {
		return Outputpaths.GetBuildInfoFileName(this.CompilerOptions(), this.comparePathsOptions);
	}

	// WildcardDirectories returns the cached wildcard directories, initializing them if needed
	public function WildcardDirectories():Null<StringMap<Bool>> {
		if (this == null) {
			return null;
		}

		if (!this.wildcardDirectoriesOnce) {
			this.wildcardDirectoriesOnce = true;
			if (this.wildcardDirectories == null) {
				this.wildcardDirectories = Tsoptions.getWildcardDirectories(this.ConfigFile.configFileSpecs.validatedIncludeSpecs,
					this.ConfigFile.configFileSpecs.validatedExcludeSpecs, this.comparePathsOptions);
			}
		}

		return this.wildcardDirectories;
	}

	public function WildcardDirectoryGlobs():Null<Array<Glob>> {
		final wildcardDirectories = this.WildcardDirectories();
		if (wildcardDirectories == null) {
			return null;
		}

		if (!this.includeGlobsOnce) {
			this.includeGlobsOnce = true;
			if (this.includeGlobs == null) {
				final patterns = this.fileGlobPatterns();
				final globs:Array<Glob> = [];
				for (dir => recursive in wildcardDirectories) {
					final parsed = Glob.Parse(Tspath.NormalizePath(dir) + "/" + Core.IfElse(recursive, patterns.b, patterns.a));
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
	public function LiteralFileNames():Null<Array<std.String>> {
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
	public function FileNames():Null<Array<std.String>> {
		return this.ParsedConfig.FileNames;
	}

	public function FileNamesByPath():StringMap<std.String> {
		if (!this.fileNamesByPathOnce) {
			this.fileNamesByPathOnce = true;
			this.fileNamesByPath = new StringMap<std.String>();
			if (this.ParsedConfig.FileNames != null) {
				for (fileName in this.ParsedConfig.FileNames) {
					final path = Tspath.ToPath(fileName, this.GetCurrentDirectory(), this.UseCaseSensitiveFileNames());
					this.fileNamesByPath.set(path, fileName);
				}
			}
		}
		return this.fileNamesByPath;
	}

	public function ProjectReferences():Null<Array<ProjectReference>> {
		return this.ParsedConfig.ProjectReferences;
	}

	public function ContentMappers():Null<Array<Mapper>> {
		if (this == null || this.ParsedConfig == null) {
			return null;
		}
		return this.ParsedConfig.ContentMappers;
	}

	// ContentMapperExtensions returns the flattened list of file extensions registered by the
	// config's content mappers.
	public function ContentMapperExtensions():Null<Array<std.String>> {
		return Core.FlatMap(this.ContentMappers(), function(m:Mapper):Array<std.String> {
			return m.Definition.Extensions;
		});
	}

	public function ContentMapperExtensionRewrites():Null<Array<ExtensionRewrite>> {
		if (!this.contentMapperExtensionRewritesOnce) {
			this.contentMapperExtensionRewritesOnce = true;
			this.contentMapperExtensionRewrites = this.computeContentMapperExtensionRewrites();
		}
		return this.contentMapperExtensionRewrites;
	}

	function computeContentMapperExtensionRewrites():Null<Array<ExtensionRewrite>> {
		final result:Array<ExtensionRewrite> = [];
		var hasNonIdentityMapping = false;
		final ignoreCase = !this.UseCaseSensitiveFileNames();
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
	public function GetContentMapperForFileName(fileName:std.String):Null<Mapper> {
		final ignoreCase = !this.UseCaseSensitiveFileNames();
		final extension = Tspath.GetLongestExtensionFromPath(fileName, this.ContentMapperExtensions(), Tspath.caseSensitivityOf(!ignoreCase));
		final mappers = this.ContentMappers();
		if (mappers != null) {
			for (mapper in mappers) {
				if (mapper.Definition.Extensions != null && Lambda.exists(mapper.Definition.Extensions, function(mapperExtension:std.String):Bool {
					return extension == mapperExtension || ignoreCase && Strings.EqualFold(extension, mapperExtension);
				})) {
					return mapper;
				}
			}
		}
		return null;
	}

	public function ResolvedProjectReferencePaths():Null<Array<RootedFilePath>> {
		if (!this.resolvedProjectReferencePathsOnce) {
			this.resolvedProjectReferencePathsOnce = true;
			this.resolvedProjectReferencePaths = Core.Map(this.ParsedConfig.ProjectReferences, Core.ResolveProjectReferencePath);
		}
		return this.resolvedProjectReferencePaths;
	}

	public function ExtendedSourceFiles():Null<Array<std.String>> {
		if (this == null || this.ConfigFile == null) {
			return null;
		}
		return this.ConfigFile.ExtendedSourceFiles;
	}

	public function GetConfigFileParsingDiagnostics():Null<Array<Diagnostic>> {
		if (this.ConfigFile != null) {
			// todo: !!! should be ConfigFile.ParseDiagnostics, check if they are the same
			return Slices.Concat(this.ConfigFile.SourceFile.Diagnostics(), this.Errors);
		}
		return this.Errors;
	}

	// PossiblyMatchesFileName is a fast check to see if a file is currently included by a config
	// or would be included if the file were to be created. It may return false positives.
	public function PossiblyMatchesFileName(fileName:std.String):Bool {
		final path = Tspath.ToPath(fileName, this.GetCurrentDirectory(), this.UseCaseSensitiveFileNames());
		if (this.FileNamesByPath().exists(path)) {
			return true;
		}

		if (this.ConfigFile.configFileSpecs.validatedIncludeSpecs != null) {
			for (include in this.ConfigFile.configFileSpecs.validatedIncludeSpecs) {
				if (!(Strings.IndexAny(include, "*?") >= 0) && !Vfsmatch.IsImplicitGlob(include)) {
					final includePath = Tspath.ToPath(include, this.GetCurrentDirectory(), this.UseCaseSensitiveFileNames());
					if (includePath == path) {
						return true;
					}
				}
			}
		}
		if (this.GetContentMapperForFileName(fileName) != null) {
			final directoryPath = Tspath.GetDirectoryPath(path);
			if (this.PossiblyMatchesDirectoryName(directoryPath)) {
				return true;
			}
		}
		final wildcardDirectoryGlobs = this.WildcardDirectoryGlobs();
		if (Core.len(wildcardDirectoryGlobs) > 0) {
			for (glob in wildcardDirectoryGlobs) {
				if (glob.Match(fileName)) {
					return true;
				}
			}
		}
		return false;
	}

	public function PossiblyMatchesDirectoryName(directoryPath:Path):Bool {
		final wildcardDirectories = this.WildcardDirectories();
		if (wildcardDirectories != null) {
			for (wildcardDir => recursive in wildcardDirectories) {
				final wildcardDirPath = Tspath.ToPath(wildcardDir, this.GetCurrentDirectory(), this.UseCaseSensitiveFileNames());
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

	public function GetMatchedFileSpec(fileName:std.String):std.String {
		return this.ConfigFile.configFileSpecs.getMatchedFileSpec(fileName, this.comparePathsOptions);
	}

	// PORT: (string, bool) → ValueOk.
	public function GetMatchedIncludeSpec(fileName:std.String):ValueOk<std.String> {
		if (Core.len(this.ConfigFile.configFileSpecs.validatedIncludeSpecs) == 0) {
			return new ValueOk<std.String>("", false);
		}

		if (this.ConfigFile.configFileSpecs.isDefaultIncludeSpec) {
			return new ValueOk<std.String>(this.ConfigFile.configFileSpecs.validatedIncludeSpecs[0], true);
		}

		return new ValueOk<std.String>(this.ConfigFile.configFileSpecs.getMatchedIncludeSpec(fileName, this.comparePathsOptions), false);
	}

	public function ReloadFileNamesOfParsedCommandLine(fs:FS):ParsedCommandLine {
		// Go struct value copy of *p.ParsedConfig.
		final parsedConfig = new ParsedOptions();
		parsedConfig.CompilerOptions = this.ParsedConfig.CompilerOptions;
		parsedConfig.WatchOptions = this.ParsedConfig.WatchOptions;
		parsedConfig.TypeAcquisition = this.ParsedConfig.TypeAcquisition;
		parsedConfig.FileNames = this.ParsedConfig.FileNames;
		parsedConfig.ProjectReferences = this.ParsedConfig.ProjectReferences;
		parsedConfig.ContentMappers = this.ParsedConfig.ContentMappers;
		final r = Tsoptions.getFileNamesFromConfigSpecs(this.ConfigFile.configFileSpecs, this.GetCurrentDirectory(), this.CompilerOptions(), fs,
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
		parsedCommandLine.comparePathsOptions = this.comparePathsOptions;
		parsedCommandLine.wildcardDirectories = this.wildcardDirectories;
		parsedCommandLine.includeGlobs = this.includeGlobs;
		parsedCommandLine.literalFileNamesLen = literalFileNamesLen;
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
	public var Source:std.String = "";
	public var OutputDts:std.String = "";
	public var Resolved:ParsedCommandLine = null;

	public function new() {}
}
