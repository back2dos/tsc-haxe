package ts.outputpaths;

// Port of internal/outputpaths.
// Package-level functions of all files (Go file order); the types of outputpaths.go follow the
// package class in this module.
@:allow(ts.outputpaths)
class Outputpaths {
	// --- commonsourcedirectory.go ---

	static function computeCommonSourceDirectoryOfFilenames(fileNames:Array<String>, currentDirectory:String, useCaseSensitiveFileNames:Bool):String {
		var commonPathComponents:Array<String> = null;
		if (fileNames != null) {
			for (sourceFile in fileNames) {
				// Each file contributes into common source file path
				var sourcePathComponents = Tspath.GetNormalizedPathComponents(sourceFile, currentDirectory);

				// The base file name is not part of the common directory path
				sourcePathComponents = sourcePathComponents.slice(0, sourcePathComponents.length - 1);

				if (commonPathComponents == null) {
					// first file
					commonPathComponents = sourcePathComponents;
					continue;
				}

				final n = commonPathComponents.length < sourcePathComponents.length ? commonPathComponents.length : sourcePathComponents.length; // min
				for (i in 0...n) {
					if (Tspath.GetCanonicalFileName(commonPathComponents[i], useCaseSensitiveFileNames) != Tspath.GetCanonicalFileName(sourcePathComponents[i],
						useCaseSensitiveFileNames)) {
						if (i == 0) {
							// Failed to find any common path component
							return "";
						}

						// New common path found that is 0 -> i-1
						commonPathComponents = commonPathComponents.slice(0, i);
						break;
					}
				}

				// If the sourcePathComponents was shorter than the commonPathComponents, truncate to the sourcePathComponents
				if (sourcePathComponents.length < commonPathComponents.length) {
					commonPathComponents = commonPathComponents.slice(0, sourcePathComponents.length);
				}
			}
		}

		if (Core.len(commonPathComponents) == 0) {
			// Can happen when all input files are .d.ts files
			return currentDirectory;
		}

		return Tspath.GetPathFromPathComponents(commonPathComponents);
	}

	public static function GetComputedCommonSourceDirectory(emittedFiles:Array<String>, currentDirectory:String, useCaseSensitiveFileNames:Bool):String {
		var commonSourceDirectory = computeCommonSourceDirectoryOfFilenames(emittedFiles, currentDirectory, useCaseSensitiveFileNames);
		if (commonSourceDirectory.length > 0) {
			commonSourceDirectory = Tspath.EnsureTrailingDirectorySeparator(commonSourceDirectory);
		}
		return commonSourceDirectory;
	}

	public static function GetCommonSourceDirectory(options:CompilerOptions, files:() -> Array<String>, currentDirectory:String,
			useCaseSensitiveFileNames:Bool, checkSourceFilesBelongToPath:(Array<String>, String) -> Bool):String {
		var commonSourceDirectory:String;
		if (options.RootDir != "") {
			// If a rootDir is specified use it as the commonSourceDirectory
			commonSourceDirectory = options.RootDir;
			if (checkSourceFilesBelongToPath != null) {
				checkSourceFilesBelongToPath(files(), options.RootDir);
			}
		} else if (options.ConfigFilePath != "") {
			// If the rootDir is not specified, then the common source directory is the directory of the config file.
			commonSourceDirectory = Tspath.GetDirectoryPath(options.ConfigFilePath);
			if (checkSourceFilesBelongToPath != null) {
				checkSourceFilesBelongToPath(files(), commonSourceDirectory);
			}
		} else {
			commonSourceDirectory = computeCommonSourceDirectoryOfFilenames(files(), currentDirectory, useCaseSensitiveFileNames);
		}

		if (commonSourceDirectory.length > 0) {
			// Make sure directory path ends with directory separator so this string can directly
			// used to replace with "" to get the relative path of the source file and the relative path doesn't
			// start with / making it rooted path
			commonSourceDirectory = Tspath.EnsureTrailingDirectorySeparator(commonSourceDirectory);
		}

		return commonSourceDirectory;
	}

	// --- outputpaths.go ---

	public static function GetOutputPathsFor(sourceFile:SourceFile, options:CompilerOptions, host:OutputPathsHost, forceDtsEmit:Bool):OutputPaths {
		final ownOutputFilePath = getOwnEmitOutputFilePath(sourceFile.FileName(), options, host, GetOutputExtension(sourceFile.FileName(), options.Jsx));
		final isJsonFile = Ast.IsJsonSourceFile(sourceFile);
		// If json file emits to the same location skip writing it, if emitDeclarationOnly skip writing it
		final isJsonEmittedToSameLocation = isJsonFile
			&& Tspath.ComparePaths(sourceFile.FileName(), ownOutputFilePath,
				new ComparePathsOptions(host.UseCaseSensitiveFileNames(), host.GetCurrentDirectory())) == 0;
		final paths = new OutputPaths();
		if (options.EmitDeclarationOnly != TSTrue && !isJsonEmittedToSameLocation) {
			paths.jsFilePath = ownOutputFilePath;
			if (!Ast.IsJsonSourceFile(sourceFile)) {
				paths.sourceMapFilePath = GetSourceMapFilePath(paths.jsFilePath, options);
			}
		}
		if (forceDtsEmit || options.GetEmitDeclarations() && !isJsonFile) {
			paths.declarationFilePath = GetDeclarationEmitOutputFilePath(sourceFile.FileName(), options, host);
			if (options.GetAreDeclarationMapsEnabled()) {
				paths.declarationMapPath = paths.declarationFilePath + ".map";
			}
		}
		return paths;
	}

	public static function ForEachEmittedFile(host:OutputPathsHost, options:CompilerOptions, action:(emitFileNames:OutputPaths, sourceFile:SourceFile) -> Bool,
			sourceFiles:Array<SourceFile>, forceDtsEmit:Bool):Bool {
		if (sourceFiles != null) {
			for (sourceFile in sourceFiles) {
				if (action(GetOutputPathsFor(sourceFile, options, host, forceDtsEmit), sourceFile)) {
					return true;
				}
			}
		}
		return false;
	}

	public static function GetOutputJSFileName(inputFileName:String, options:CompilerOptions, host:OutputPathsHost):String {
		if (options.EmitDeclarationOnly.IsTrue()) {
			return "";
		}
		final outputFileName = GetOutputJSFileNameWorker(inputFileName, options, host);
		if (!Tspath.FileExtensionIs(outputFileName, Tspath.ExtensionJson)
			|| Tspath.ComparePaths(inputFileName, outputFileName,
				new ComparePathsOptions(host.UseCaseSensitiveFileNames(), host.GetCurrentDirectory())) != 0) {
			return outputFileName;
		}
		return "";
	}

	public static function GetOutputJSFileNameWorker(inputFileName:String, options:CompilerOptions, host:OutputPathsHost):String {
		return Tspath.ChangeExtension(getOutputPathWithoutChangingExtension(inputFileName, options.OutDir, host),
			GetOutputExtension(inputFileName, options.Jsx));
	}

	public static function GetOutputDeclarationFileNameWorker(inputFileName:String, options:CompilerOptions, host:OutputPathsHost):String {
		var dir = options.DeclarationDir;
		if (dir.length == 0) {
			dir = options.OutDir;
		}
		return Tspath.ChangeExtension(getOutputPathWithoutChangingExtension(inputFileName, dir, host),
			Tspath.GetDeclarationEmitExtensionForPath(inputFileName));
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

	public static function GetDeclarationEmitOutputFilePath(file:String, options:CompilerOptions, host:OutputPathsHost):String {
		// PORT: pointer — Go `outputDir *string` → the string, null for nil.
		var outputDir:Null<String> = null;
		if (options.DeclarationDir.length > 0) {
			outputDir = options.DeclarationDir;
		} else if (options.OutDir.length > 0) {
			outputDir = options.OutDir;
		}

		var path:String;
		if (outputDir != null) {
			path = GetSourceFilePathInNewDirWorker(file, outputDir, host.GetCurrentDirectory(), host.CommonSourceDirectory(), host.UseCaseSensitiveFileNames());
		} else {
			path = file;
		}
		final declarationExtension = Tspath.GetDeclarationEmitExtensionForPath(path);
		return Tspath.RemoveFileExtension(path) + declarationExtension;
	}

	public static function GetSourceFilePathInNewDir(fileName:String, newDirPath:String, currentDirectory:String, commonSourceDirectory:String,
			useCaseSensitiveFileNames:Bool):String {
		var sourceFilePath = Tspath.GetNormalizedAbsolutePath(fileName, currentDirectory);
		commonSourceDirectory = Tspath.EnsureTrailingDirectorySeparator(commonSourceDirectory);
		final isSourceFileInCommonSourceDirectory = Tspath.ContainsPath(commonSourceDirectory, sourceFilePath,
			new ComparePathsOptions(useCaseSensitiveFileNames, currentDirectory));
		if (isSourceFileInCommonSourceDirectory) {
			sourceFilePath = sourceFilePath.substring(commonSourceDirectory.length);
		}
		return Tspath.CombinePaths(newDirPath, sourceFilePath);
	}

	static function getOutputPathWithoutChangingExtension(inputFileName:String, outputDirectory:String, host:OutputPathsHost):String {
		if (outputDirectory.length > 0) {
			return Tspath.ResolvePath(outputDirectory,
				Tspath.GetRelativePathFromDirectory(host.CommonSourceDirectory(), inputFileName,
					new ComparePathsOptions(host.UseCaseSensitiveFileNames(), host.GetCurrentDirectory())));
		}
		return inputFileName;
	}

	public static function GetSourceFilePathInNewDirWorker(fileName:String, newDirPath:String, currentDirectory:String, commonSourceDirectory:String,
			useCaseSensitiveFileNames:Bool):String {
		var sourceFilePath = Tspath.GetNormalizedAbsolutePath(fileName, currentDirectory);
		final commonDir = Tspath.GetCanonicalFileName(commonSourceDirectory, useCaseSensitiveFileNames);
		final canonFile = Tspath.GetCanonicalFileName(sourceFilePath, useCaseSensitiveFileNames);
		final isSourceFileInCommonSourceDirectory = StringTools.startsWith(canonFile, commonDir);
		if (isSourceFileInCommonSourceDirectory) {
			sourceFilePath = sourceFilePath.substring(commonSourceDirectory.length);
		}
		return Tspath.CombinePaths(newDirPath, sourceFilePath);
	}

	static function getOwnEmitOutputFilePath(fileName:String, options:CompilerOptions, host:OutputPathsHost, extension:String):String {
		var emitOutputFilePathWithoutExtension:String;
		if (options.OutDir.length > 0) {
			final currentDirectory = host.GetCurrentDirectory();
			emitOutputFilePathWithoutExtension = Tspath.RemoveFileExtension(GetSourceFilePathInNewDir(fileName, options.OutDir, currentDirectory,
				host.CommonSourceDirectory(), host.UseCaseSensitiveFileNames()));
		} else {
			emitOutputFilePathWithoutExtension = Tspath.RemoveFileExtension(fileName);
		}
		return emitOutputFilePathWithoutExtension + extension;
	}

	public static function GetSourceMapFilePath(jsFilePath:String, options:CompilerOptions):String {
		if (options.SourceMap.IsTrue() && !options.InlineSourceMap.IsTrue()) {
			return jsFilePath + ".map";
		}
		return "";
	}

	public static function GetBuildInfoFileName(options:CompilerOptions, opts:ComparePathsOptions):String {
		if (!options.IsIncremental() && !options.Build.IsTrue()) {
			return "";
		}
		if (options.TsBuildInfoFile != "") {
			return options.TsBuildInfoFile;
		}
		if (options.ConfigFilePath == "") {
			return "";
		}
		final configFileExtensionLess = Tspath.RemoveFileExtension(options.ConfigFilePath);
		var buildInfoExtensionLess:String;
		if (options.OutDir != "") {
			if (options.RootDir != "") {
				buildInfoExtensionLess = Tspath.ResolvePath(options.OutDir, Tspath.GetRelativePathFromDirectory(options.RootDir, configFileExtensionLess, opts));
			} else {
				buildInfoExtensionLess = Tspath.CombinePaths(options.OutDir, Tspath.GetBaseFileName(configFileExtensionLess));
			}
		} else {
			buildInfoExtensionLess = configFileExtensionLess;
		}
		return buildInfoExtensionLess + Tspath.ExtensionTsBuildInfo;
	}
}

interface OutputPathsHost {
	function CommonSourceDirectory():String;
	function GetCurrentDirectory():String;
	function UseCaseSensitiveFileNames():Bool;
}

@:allow(ts.outputpaths)
class OutputPaths {
	var jsFilePath:String = "";
	var sourceMapFilePath:String = "";
	var declarationFilePath:String = "";
	var declarationMapPath:String = "";

	public function new() {}

	// DeclarationFilePath implements declarations.OutputPaths.
	public function DeclarationFilePath():String {
		return declarationFilePath;
	}

	// JsFilePath implements declarations.OutputPaths.
	public function JsFilePath():String {
		return jsFilePath;
	}

	public function SourceMapFilePath():String {
		return sourceMapFilePath;
	}

	public function DeclarationMapPath():String {
		return declarationMapPath;
	}
}
