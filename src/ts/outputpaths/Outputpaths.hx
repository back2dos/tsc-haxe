package ts.outputpaths;

// Port of internal/outputpaths.
// Package-level functions of all files (Go file order); the types of outputpaths.go follow the
// package class in this module.
@:allow(ts.outputpaths)
class Outputpaths {
	// --- commonsourcedirectory.go ---

	static function computeCommonSourceDirectoryOfFilenames(fileNames:Null<Array<RootedFilePath>>, currentDirectory:RootedDirectoryPath,
			caseSensitivity:CaseSensitivity):RootedDirectoryPath {
		if (Core.len(fileNames) == 0) {
			// Can happen when all input files are .d.ts files.
			return currentDirectory;
		}
		return caseSensitivity.CommonDirectoryOfFiles(fileNames);
	}

	public static function GetComputedCommonSourceDirectory(emittedFiles:Null<Array<RootedFilePath>>, currentDirectory:RootedDirectoryPath,
			caseSensitivity:CaseSensitivity):RootedDirectoryPath {
		return computeCommonSourceDirectoryOfFilenames(emittedFiles, currentDirectory, caseSensitivity);
	}

	public static function GetCommonSourceDirectory(options:CompilerOptions, files:() -> Null<Array<RootedFilePath>>, currentDirectory:RootedDirectoryPath,
			caseSensitivity:CaseSensitivity, checkSourceFilesBelongToPath:Null<(Null<Array<RootedFilePath>>, RootedDirectoryPath) -> Bool>):RootedDirectoryPath {
		var commonSourceDirectory:RootedDirectoryPath;
		if (options.RootDir != "") {
			// If a rootDir is specified use it as the commonSourceDirectory
			commonSourceDirectory = options.RootDir;
			if (checkSourceFilesBelongToPath != null) {
				checkSourceFilesBelongToPath(files(), commonSourceDirectory);
			}
		} else if (options.ConfigFilePath != "") {
			// If the rootDir is not specified, then the common source directory is the directory of the config file.
			commonSourceDirectory = options.ConfigFilePath.Directory();
			if (checkSourceFilesBelongToPath != null) {
				checkSourceFilesBelongToPath(files(), commonSourceDirectory);
			}
		} else {
			commonSourceDirectory = computeCommonSourceDirectoryOfFilenames(files(), currentDirectory, caseSensitivity);
		}

		return commonSourceDirectory;
	}

	// --- outputpaths.go ---

	public static function GetOutputPathsFor(sourceFile:SourceFile, options:CompilerOptions, host:OutputPathsHost, force:ForceEmitPaths):OutputPaths {
		final fileName = sourceFile.FileName();
		final ownOutputFilePath = getOwnEmitOutputFilePathForFileName(fileName, options, host, GetOutputExtensionForFileName(fileName, options.Jsx));
		final isJsonFile = Ast.IsJsonSourceFile(sourceFile);
		// If json file emits to the same location skip writing it, if emitDeclarationOnly skip writing it
		final isJsonEmittedToSameLocation = isJsonFile && host.CaseSensitivity().CompareFilePaths(fileName, ownOutputFilePath) == 0;
		final paths = new OutputPaths();
		if (sourceFile.ContentMapper() != "") {
			paths.externalOutputFilePath = GetExternalOutputFileName(sourceFile.FileName(), options, host);
		}
		if (sourceFile.ContentMapper() == "" && (force.Js || options.EmitDeclarationOnly != TSTrue) && !isJsonEmittedToSameLocation) {
			paths.jsFilePath = ownOutputFilePath;
			if (!Ast.IsJsonSourceFile(sourceFile)) {
				paths.sourceMapFilePath = GetSourceMapFilePath(paths.jsFilePath, options);
			}
		}
		if (force.Dts || options.GetEmitDeclarations() && !isJsonFile) {
			paths.declarationFilePath = getDeclarationEmitOutputFilePathForFileName(fileName, options, host);
			if (options.GetAreDeclarationMapsEnabled() || force.DeclarationMap && options.DeclarationMap.IsTrue()) {
				paths.declarationMapPath = paths.declarationFilePath.AppendSuffix(".map");
			}
		}
		return paths;
	}

	public static function ForEachEmittedFile(host:OutputPathsHost, options:CompilerOptions, action:(emitFileNames:OutputPaths, sourceFile:SourceFile) -> Bool,
			sourceFiles:Array<SourceFile>, externalOutputSourceFiles:Null<Array<SourceFile>>, forceDtsEmit:Bool):Bool {
		final seen = new go.IdentityMap<SourceFile, Bool>();
		if (sourceFiles != null) {
			for (sourceFile in sourceFiles) {
				seen.set(sourceFile, true);
				if (action(GetOutputPathsFor(sourceFile, options, host, new ForceEmitPaths(forceDtsEmit)), sourceFile)) {
					return true;
				}
			}
		}
		if (externalOutputSourceFiles != null) {
			for (sourceFile in externalOutputSourceFiles) {
				if (seen.exists(sourceFile)) {
					continue;
				}
				final paths = new OutputPaths();
				paths.externalOutputFilePath = GetExternalOutputFileName(sourceFile.FileName(), options, host);
				if (action(paths, sourceFile)) {
					return true;
				}
			}
		}
		return false;
	}

	public static function GetOutputJSFileName(inputFileName:RootedFilePath, options:CompilerOptions, host:OutputPathsHost):RootedFilePath {
		if (options.EmitDeclarationOnly.IsTrue() || isContentMappedFileName(inputFileName, host)) {
			return cast "";
		}
		final outputFileName = GetOutputJSFileNameWorker(inputFileName, options, host);
		if (!outputFileName.ExtensionIs(Tspath.ExtensionJson) || host.CaseSensitivity().CompareFilePaths(inputFileName, outputFileName) != 0) {
			return outputFileName;
		}
		return cast "";
	}

	static function isContentMappedFileName(fileName:RootedFilePath, host:OutputPathsHost):Bool {
		return fileName.LongestExtension(host.ContentMapperExtensions(), host.CaseSensitivity()) != "";
	}

	public static function GetOutputJSFileNameWorker(inputFileName:RootedFilePath, options:CompilerOptions, host:OutputPathsHost):RootedFilePath {
		return getOutputFileNameWithoutChangingExtension(inputFileName, options.OutDir, host)
			.ChangeExtension(GetOutputExtensionForFileName(inputFileName, options.Jsx));
	}

	public static function GetOutputDeclarationFileNameWorker(inputFileName:RootedFilePath, options:CompilerOptions, host:OutputPathsHost):RootedFilePath {
		var dir = options.DeclarationDir;
		if (dir.length == 0) {
			dir = options.OutDir;
		}
		final path = getOutputFileNameWithoutChangingExtension(inputFileName, dir, host);
		return ChangeToDeclarationExtension(path, host);
	}

	public static function GetExternalOutputFileName(inputFileName:RootedFilePath, options:CompilerOptions, host:OutputPathsHost):RootedFilePath {
		final outputPath = getOutputFileNameWithoutChangingExtension(inputFileName, options.OutDir, host);
		final rewritten = outputPath.RewriteExtension(host.ContentMapperExtensionRewrites(), host.CaseSensitivity());
		if (!rewritten.ok) {
			return cast "";
		}
		return rewritten.value;
	}

	public static function GetOutputExtension(fileName:String, jsx:JsxEmit):String {
		if (Tspath.FileExtensionIs(fileName, Tspath.ExtensionJson)) {
			return Tspath.ExtensionJson;
		} else if (jsx == JsxEmitPreserve && Tspath.FileExtensionIsOneOf(fileName, [Tspath.ExtensionJsx, Tspath.ExtensionTsx])) {
			return Tspath.ExtensionJsx;
		} else if (Tspath.FileExtensionIsOneOf(fileName, [Tspath.ExtensionMts, Tspath.ExtensionMjs])) {
			return Tspath.ExtensionMjs;
		} else if (Tspath.FileExtensionIsOneOf(fileName, [Tspath.ExtensionCts, Tspath.ExtensionCjs])) {
			return Tspath.ExtensionCjs;
		} else {
			return Tspath.ExtensionJs;
		}
	}

	public static inline function GetOutputExtensionForFileName(fileName:RootedFilePath, jsx:JsxEmit):String {
		return GetOutputExtension(fileName.AsString(), jsx);
	}

	static function getDeclarationEmitOutputFilePathForFileName(file:RootedFilePath, options:CompilerOptions, host:OutputPathsHost):RootedFilePath {
		var outputDir:RootedDirectoryPath = cast "";
		if (options.DeclarationDir.length > 0) {
			outputDir = options.DeclarationDir;
		} else if (options.OutDir.length > 0) {
			outputDir = options.OutDir;
		}

		if (outputDir != "") {
			return ChangeToDeclarationExtension(GetSourceFileNameInNewDir(file, outputDir, host.CommonSourceDirectory(), host.CaseSensitivity()), host);
		}
		return ChangeToDeclarationExtension(file, host);
	}

	public static function ChangeToDeclarationExtension(path:RootedFilePath, host:OutputPathsHost):RootedFilePath {
		final rewritten = path.RewriteExtension(host.ContentMapperExtensionRewrites(), host.CaseSensitivity());
		if (rewritten.ok) {
			return changeToDeclarationExtension(rewritten.value);
		}
		final extension = path.LongestExtension(host.ContentMapperExtensions(), CaseSensitive);
		if (extension != "") {
			return path.RemoveExtension(extension).AppendSuffix(".d" + extension + ".ts");
		}
		return changeToDeclarationExtension(path);
	}

	static function changeToDeclarationExtension(path:RootedFilePath):RootedFilePath {
		var pathWithoutExtension = path.RemoveFileExtension();
		if (pathWithoutExtension.AsString() == path.AsString()) {
			final extension = path.AnyExtension(null, CaseSensitive);
			if (extension != "") {
				pathWithoutExtension = path.RemoveExtension(extension);
			}
		}
		return pathWithoutExtension.AppendSuffix(path.DeclarationEmitExtension());
	}

	static function getOutputFileNameWithoutChangingExtension(inputFileName:RootedFilePath, outputDirectory:RootedDirectoryPath,
			host:OutputPathsHost):RootedFilePath {
		if (outputDirectory != "") {
			final relativePath = host.CaseSensitivity().RelativePathFromDirectory(host.CommonSourceDirectory(), inputFileName);
			if (relativePath == null) {
				return inputFileName;
			}

			return outputDirectory.ResolveRelativeFile(relativePath);
		}
		return inputFileName;
	}

	public static function GetSourceFileNameInNewDir(fileName:RootedFilePath, newDirPath:RootedDirectoryPath, commonSourceDirectory:RootedDirectoryPath,
			caseSensitivity:CaseSensitivity):RootedFilePath {
		if (fileName.AsString() == commonSourceDirectory.AsString()) {
			return fileName;
		}
		final relativePath = caseSensitivity.RelativeFilePathFromDirectory(commonSourceDirectory, fileName);
		if (relativePath != null) {
			return newDirPath.ResolveRelativeFile(relativePath);
		}
		return fileName;
	}

	static function getOwnEmitOutputFilePathForFileName(fileName:RootedFilePath, options:CompilerOptions, host:OutputPathsHost,
			extension:String):RootedFilePath {
		var emitOutputFilePath:RootedFilePath;
		if (options.OutDir.length > 0) {
			emitOutputFilePath = GetSourceFileNameInNewDir(fileName, options.OutDir, host.CommonSourceDirectory(), host.CaseSensitivity());
		} else {
			emitOutputFilePath = fileName;
		}
		return emitOutputFilePath.RemoveFileExtension().AppendSuffix(extension);
	}

	public static function GetSourceMapFilePath(jsFilePath:RootedFilePath, options:CompilerOptions):RootedFilePath {
		if (options.SourceMap.IsTrue() && !options.InlineSourceMap.IsTrue()) {
			return jsFilePath.AppendSuffix(".map");
		}
		return cast "";
	}

	public static function GetBuildInfoFileName(options:CompilerOptions, caseSensitivity:CaseSensitivity):RootedFilePath {
		if (!options.IsIncremental() && !options.Build.IsTrue()) {
			return cast "";
		}
		if (options.TsBuildInfoFile != "") {
			return options.TsBuildInfoFile;
		}
		if (options.ConfigFilePath == "") {
			return cast "";
		}
		final configFileName = options.ConfigFilePath;
		var buildInfoFileName:RootedFilePath;
		if (options.OutDir != "") {
			if (options.RootDir != "") {
				final relativePath = caseSensitivity.RelativePathFromDirectory(options.RootDir, configFileName);
				if (relativePath != null) {
					buildInfoFileName = options.OutDir.ResolveRelativeFile(relativePath);
				} else {
					buildInfoFileName = configFileName;
				}
			} else {
				buildInfoFileName = options.OutDir.ResolveFile(configFileName.BaseName());
			}
		} else {
			buildInfoFileName = configFileName;
		}
		return buildInfoFileName.RemoveFileExtension().AppendSuffix(Tspath.ExtensionTsBuildInfo);
	}
}

interface OutputPathsHost {
	function CommonSourceDirectory():RootedDirectoryPath;
	function ContentMapperExtensions():Null<Array<String>>;
	function ContentMapperExtensionRewrites():Null<Array<ts.tspath.Tspath.ExtensionRewrite>>;
	function CaseSensitivity():CaseSensitivity;
}

@:allow(ts.outputpaths)
class OutputPaths {
	var jsFilePath:RootedFilePath = cast "";
	var sourceMapFilePath:RootedFilePath = cast "";
	var declarationFilePath:RootedFilePath = cast "";
	var declarationMapPath:RootedFilePath = cast "";
	var externalOutputFilePath:RootedFilePath = cast "";

	public function new() {}

	// DeclarationFilePath implements declarations.OutputPaths.
	public function DeclarationFilePath():RootedFilePath {
		return declarationFilePath;
	}

	// JsFilePath implements declarations.OutputPaths.
	public function JsFilePath():RootedFilePath {
		return jsFilePath;
	}

	public function SourceMapFilePath():RootedFilePath {
		return sourceMapFilePath;
	}

	public function DeclarationMapPath():RootedFilePath {
		return declarationMapPath;
	}

	public function ExternalOutputFilePath():RootedFilePath {
		return externalOutputFilePath;
	}
}

class ForceEmitPaths {
	public var Dts:Bool;
	public var Js:Bool;
	public var DeclarationMap:Bool;

	public function new(Dts:Bool = false, Js:Bool = false, DeclarationMap:Bool = false) {
		this.Dts = Dts;
		this.Js = Js;
		this.DeclarationMap = DeclarationMap;
	}
}
