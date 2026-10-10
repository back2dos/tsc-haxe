package ts.tsoptions.tsoptionstest;

// Port of internal/tsoptions/tsoptionstest: package-level funcs of all files, in Go file order.
class Tsoptionstest {
	// --- parsedcommandline.go ---

	// PORT: the Go `t assert.TestingT` parameter is not used; it is dropped.
	public static function GetParsedCommandLine(jsonText:String, files:Map<String, String>, currentDirectory:String,
			useCaseSensitiveFileNames:Bool):ParsedCommandLine {
		final host = NewVFSParseConfigHost(files, currentDirectory, useCaseSensitiveFileNames);
		final configFileName = Tspath.CombinePaths(currentDirectory, "tsconfig.json");
		final tsconfigSourceFile = Tsoptions.NewTsconfigSourceFileFromFilePath(configFileName,
			Tspath.ToPath(configFileName, currentDirectory, useCaseSensitiveFileNames), jsonText);
		return Tsoptions.ParseJsonSourceFileConfigFileContent(tsconfigSourceFile, host, currentDirectory, null, null, configFileName, null, null, null);
	}

	// --- vfsparseconfighost.go ---

	static function fixRoot(path:String):String {
		final rootLength = Tspath.GetRootLength(path);
		if (rootLength == 0) {
			return path;
		}
		if (path.length == rootLength) {
			return ".";
		}
		return path.substring(rootLength);
	}

	public static function NewVFSParseConfigHost(files:Map<String, String>, currentDirectory:String, useCaseSensitiveFileNames:Bool):VfsParseConfigHost {
		return new VfsParseConfigHost(Vfstest.FromMap(files, useCaseSensitiveFileNames), currentDirectory);
	}
}
