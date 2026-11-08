package ts.tsoptions.tsoptionstest;

// Port of internal/tsoptions/tsoptionstest: package-level funcs of all files, in Go file order.
class Tsoptionstest {
	// --- parsedcommandline.go ---

	// PORT: the Go `t assert.TestingT` parameter is not used; it is dropped.
	public static function GetParsedCommandLine(jsonText:String, files:Map<String, String>, currentDirectory:RootedDirectoryPath,
			caseSensitivity:CaseSensitivity):ParsedCommandLine {
		final fs = NewVFS(files, caseSensitivity);
		final configFileName = currentDirectory.ResolveFile("tsconfig.json");
		final tsconfigSourceFile = Tsoptions.NewTsconfigSourceFileFromFilePath(configFileName, caseSensitivity.PathKey(configFileName.AsPath()), jsonText);
		return Tsoptions.ParseJsonSourceFileConfigFileContent(tsconfigSourceFile, Tsoptions.NewDefaultParseConfigHost(fs), currentDirectory, null, null, null,
			null);
	}

	// --- vfs.go ---

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

	public static function NewVFS(files:Map<String, String>, caseSensitivity:CaseSensitivity):FS {
		return Vfstest.FromMap(files, caseSensitivity);
	}

	// NewVFSWithSymlinks builds a VFS that contains the given symlinks (link path -> target path).
	public static function NewVFSWithSymlinks(files:Map<String, String>, symlinks:Null<haxe.ds.StringMap<String>>, currentDirectory:RootedDirectoryPath,
			caseSensitivity:CaseSensitivity):FS {
		if (symlinks == null || !symlinks.keys().hasNext()) {
			return NewVFS(files, caseSensitivity);
		}
		final entries = new Map<String, Dynamic>();
		for (name => content in files) {
			entries.set(name, content);
		}
		for (link => target in symlinks) {
			entries.set(Tspath.GetNormalizedAbsolutePath(link, currentDirectory), Vfstest.Symlink(Tspath.GetNormalizedAbsolutePath(target, currentDirectory)));
		}
		return Vfstest.FromMap(entries, caseSensitivity);
	}
}
