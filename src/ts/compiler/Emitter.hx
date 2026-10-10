package ts.compiler;

// Port of emitter.go (types and methods; the package-level funcs are in Compiler.hx).

enum abstract EmitOnly(Int) from Int to Int {
	var EmitAll = 0;
	var EmitOnlyJs = 1;
	var EmitOnlyDts = 2;
	var EmitOnlyForcedDts = 3;
}

@:allow(ts.compiler)
class Emitter {
	var host:EmitHost = null;
	var emitOnly:EmitOnly = EmitAll;
	var emitterDiagnostics:DiagnosticsCollection = new DiagnosticsCollection();
	var writer:EmitTextWriter = null;
	var paths:ts.outputpaths.Outputpaths.OutputPaths = null;
	var sourceFile:SourceFile = null;
	var emitResult:EmitResult = new EmitResult();
	var writeFile:(fileName:std.String, text:std.String, data:WriteFileData) -> Null<Error> = null;
	var tr:Tracing = null;

	public function new() {}

	function emit():Void {
		var done:() -> Void = null;
		if (this.tr != null) {
			final args = new StringMap<Any>();
			args.set("path", (this.sourceFile.Path() : std.String));
			done = this.tr.Push(PhaseEmit, "emit", args, true);
		}
		try {
			this.emitJSFile(this.sourceFile, this.paths.JsFilePath(), this.paths.SourceMapFilePath());
			this.emitDeclarationFile(this.sourceFile, this.paths.DeclarationFilePath(), this.paths.DeclarationMapPath());
			this.emitResult.Diagnostics = this.emitterDiagnostics.GetDiagnostics();
		} catch (e:Dynamic) {
			if (done != null)
				done();
			throw e;
		}
		if (done != null)
			done();
	}

	function getDeclarationTransformers(emitContext:EmitContext, declarationFilePath:std.String, declarationMapPath:std.String):Array<DeclarationTransformer> {
		final transform = Declarations.NewDeclarationTransformer(this.host, emitContext, this.host.Options(), declarationFilePath, declarationMapPath);
		return [transform];
	}

	function runScriptTransformers(emitContext:EmitContext, sourceFile:SourceFile):SourceFile {
		var done:() -> Void = null;
		if (this.tr != null) {
			final args = new StringMap<Any>();
			args.set("path", (sourceFile.Path() : std.String));
			done = this.tr.Push(PhaseEmit, "transformNodes", args, false);
		}
		try {
			for (transformer in Compiler.getScriptTransformers(emitContext, this.host, sourceFile)) {
				sourceFile = transformer.TransformSourceFile(sourceFile);
			}
		} catch (e:Dynamic) {
			if (done != null)
				done();
			throw e;
		}
		if (done != null)
			done();
		return sourceFile;
	}

	// PORT: (*ast.SourceFile, []*ast.Diagnostic) → Pair
	function runDeclarationTransformers(emitContext:EmitContext, sourceFile:SourceFile, declarationFilePath:std.String,
			declarationMapPath:std.String):Pair<SourceFile, Array<Diagnostic>> {
		var done:() -> Void = null;
		if (this.tr != null) {
			final args = new StringMap<Any>();
			args.set("path", (sourceFile.Path() : std.String));
			done = this.tr.Push(PhaseEmit, "transformNodes", args, false);
		}
		var diags:Array<Diagnostic> = null;
		try {
			for (transformer in this.getDeclarationTransformers(emitContext, declarationFilePath, declarationMapPath)) {
				sourceFile = transformer.Transformer.TransformSourceFile(sourceFile);
				final d = transformer.GetDiagnostics();
				if (d != null && d.length > 0) {
					if (diags == null)
						diags = [];
					for (x in d)
						diags.push(x);
				}
			}
		} catch (e:Dynamic) {
			if (done != null)
				done();
			throw e;
		}
		if (done != null)
			done();
		return new Pair(sourceFile, diags);
	}

	function emitJSFile(sourceFile:SourceFile, jsFilePath:std.String, sourceMapFilePath:std.String):Void {
		final options = this.host.Options();

		if (sourceFile == null || this.emitOnly != EmitAll && this.emitOnly != EmitOnlyJs || jsFilePath.length == 0) {
			return;
		}

		if (options.NoEmit == TSTrue || this.host.IsEmitBlocked(jsFilePath)) {
			this.emitResult.EmitSkipped = true;
			return;
		}

		var done:() -> Void = null;
		if (this.tr != null) {
			final args = new StringMap<Any>();
			args.set("jsFilePath", jsFilePath);
			done = this.tr.Push(PhaseEmit, "emitJsFileOrBundle", args, true);
		}

		final ec = Printer.GetEmitContext();
		final emitContext = ec.a, putEmitContext = ec.b;
		try {
			sourceFile = this.runScriptTransformers(emitContext, sourceFile);

			final printerOptions = new PrinterOptions();
			printerOptions.RemoveComments = options.RemoveComments.IsTrue();
			printerOptions.NewLine = options.NewLine;
			printerOptions.NoEmitHelpers = options.NoEmitHelpers.IsTrue();
			printerOptions.SourceMap = options.SourceMap.IsTrue();
			printerOptions.InlineSourceMap = options.InlineSourceMap.IsTrue();
			printerOptions.InlineSources = options.InlineSources.IsTrue();
			printerOptions.Target = options.Target;
			// !!!

			// create a printer to print the nodes
			final printer = Printer.NewPrinter(printerOptions, new PrintHandlers(/* !!! */), emitContext);

			this.printSourceFile(jsFilePath, sourceMapFilePath, sourceFile, printer, options, Compiler.shouldEmitSourceMaps(options, sourceFile));
		} catch (e:Dynamic) {
			putEmitContext();
			if (done != null)
				done();
			throw e;
		}
		putEmitContext();
		if (done != null)
			done();
	}

	function emitDeclarationFile(sourceFile:SourceFile, declarationFilePath:std.String, declarationMapPath:std.String):Void {
		final options = this.host.Options();

		if (sourceFile == null || this.emitOnly == EmitOnlyJs || declarationFilePath.length == 0) {
			return;
		}

		var done:() -> Void = null;
		if (this.tr != null) {
			final args = new StringMap<Any>();
			args.set("declarationFilePath", declarationFilePath);
			done = this.tr.Push(PhaseEmit, "emitDeclarationFileOrBundle", args, true);
		}

		final ec = Printer.GetEmitContext();
		final emitContext = ec.a, putEmitContext = ec.b;
		try {
			this.emitDeclarationFileWorker(emitContext, sourceFile, declarationFilePath, declarationMapPath, options);
		} catch (e:Dynamic) {
			putEmitContext();
			if (done != null)
				done();
			throw e;
		}
		putEmitContext();
		if (done != null)
			done();
	}

	// PORT: body of emitDeclarationFile after its defers (split off because of the early returns).
	function emitDeclarationFileWorker(emitContext:EmitContext, sourceFile:SourceFile, declarationFilePath:std.String, declarationMapPath:std.String,
			options:CompilerOptions):Void {
		final r = this.runDeclarationTransformers(emitContext, sourceFile, declarationFilePath, declarationMapPath);
		sourceFile = r.a;
		final diags = r.b;

		if (diags != null) {
			for (elem in diags) {
				// Add declaration transform diagnostics to emit diagnostics
				this.emitterDiagnostics.Add(elem);
			}
		}

		if (this.emitOnly != EmitOnlyForcedDts && (options.NoEmit == TSTrue || this.host.IsEmitBlocked(declarationFilePath))) {
			this.emitResult.EmitSkipped = true;
			return;
		}

		final declBlocked = Core.len(diags) > 0 && this.emitOnly != EmitOnlyForcedDts;
		if (declBlocked) {
			this.emitResult.EmitSkipped = true;
			return;
		}

		final printerOptions = new PrinterOptions();
		printerOptions.RemoveComments = options.RemoveComments.IsTrue();
		printerOptions.NewLine = options.NewLine;
		printerOptions.NoEmitHelpers = true;
		// Module: 			   options.Module, // NYI
		// ModuleResolution:   options.ModuleResolution, // NYI
		printerOptions.Target = options.GetEmitScriptTarget();
		printerOptions.SourceMap = this.emitOnly != EmitOnlyForcedDts && options.DeclarationMap.IsTrue();
		printerOptions.InlineSourceMap = options.InlineSourceMap.IsTrue();
		// InlineSources:       options.InlineSources.IsTrue(), // ignored, per strada
		// ExtendedDiagnostics: options.ExtendedDiagnostics.IsTrue(), // NYI
		printerOptions.OnlyPrintJSDocStyle = true;
		printerOptions.OmitBraceSourceMapPositions = true;

		// create a printer to print the nodes
		final printer = Printer.NewPrinter(printerOptions, new PrintHandlers(/* !!! */), emitContext);

		final declarationMapOptions = new CompilerOptions();
		declarationMapOptions.SourceMap = Core.IfElse(this.emitOnly != EmitOnlyForcedDts && options.DeclarationMap.IsTrue(), TSTrue, TSFalse);
		declarationMapOptions.SourceRoot = options.SourceRoot;
		declarationMapOptions.MapRoot = options.MapRoot;
		// Explicitly do not pass through either inline option.
		this.printSourceFile(declarationFilePath, declarationMapPath, sourceFile, printer, declarationMapOptions,
			Compiler.shouldEmitSourceMaps(declarationMapOptions, sourceFile));
	}

	function printSourceFile(jsFilePath:std.String, sourceMapFilePath:std.String, sourceFile:SourceFile, printer_:Printer, mapOptions:CompilerOptions,
			shouldEmitSourceMaps:Bool):Void {
		// !!! sourceMapGenerator
		final options = this.host.Options();
		var sourceMapGenerator:Generator = null;
		if (shouldEmitSourceMaps) {
			sourceMapGenerator = Sourcemap.NewGenerator(Tspath.GetBaseFileName(Tspath.NormalizeSlashes(jsFilePath)), Compiler.getSourceRoot(mapOptions),
				this.getSourceMapDirectory(mapOptions, jsFilePath, sourceFile),
				new ComparePathsOptions(this.host.UseCaseSensitiveFileNames(), this.host.GetCurrentDirectory()));
		}

		printer_.Write(sourceFile.AsNode(), sourceFile, this.writer, sourceMapGenerator);

		var sourceMapUrlPos = -1;
		if (sourceMapGenerator != null) {
			if (mapOptions.SourceMap.IsTrue() || mapOptions.InlineSourceMap.IsTrue()) {
				final r = new SourceMapEmitResult();
				r.InputSourceFileNames = sourceMapGenerator.Sources();
				r.SourceMap = sourceMapGenerator.RawSourceMap();
				r.GeneratedFile = jsFilePath;
				if (this.emitResult.SourceMaps == null)
					this.emitResult.SourceMaps = [];
				this.emitResult.SourceMaps.push(r);
			}

			final sourceMappingURL = this.getSourceMappingURL(mapOptions, sourceMapGenerator, jsFilePath, sourceMapFilePath, sourceFile);

			if (sourceMappingURL.length > 0) {
				if (!this.writer.IsAtStartOfLine()) {
					this.writer.RawWrite(Core.IfElse(options.NewLine == NewLineKindCRLF, "\r\n", "\n"));
				}
				sourceMapUrlPos = this.writer.GetTextPos();
				this.writer.WriteComment("//# sourceMappingURL=");
				this.writer.WriteComment(sourceMappingURL);
			}

			// Write the source map
			if (sourceMapFilePath.length > 0) {
				final sourceMap = sourceMapGenerator.String();
				final err = this.writeText(sourceMapFilePath, sourceMap, null);
				if (err != null) {
					this.emitterDiagnostics.Add(Ast.NewCompilerDiagnostic(Diagnostics.Could_not_write_file_0_Colon_1, jsFilePath, err.Error()));
				} else {
					if (this.emitResult.EmittedFiles == null)
						this.emitResult.EmittedFiles = [];
					this.emitResult.EmittedFiles.push(sourceMapFilePath);
				}
			}
		} else {
			this.writer.WriteLine();
		}

		// Write the output file
		var text = this.writer.String();
		if (options.EmitBOM.IsTrue()) {
			text = Stringutil.AddUTF8ByteOrderMark(text);
		}
		final data = new WriteFileData();
		data.SourceMapUrlPos = sourceMapUrlPos;
		data.Diagnostics = this.emitterDiagnostics.GetDiagnostics();
		final err = this.writeText(jsFilePath, text, data);
		final skippedDtsWrite = data.SkippedDtsWrite;
		if (err != null) {
			this.emitterDiagnostics.Add(Ast.NewCompilerDiagnostic(Diagnostics.Could_not_write_file_0_Colon_1, jsFilePath, err.Error()));
		} else if (!skippedDtsWrite) {
			if (this.emitResult.EmittedFiles == null)
				this.emitResult.EmittedFiles = [];
			this.emitResult.EmittedFiles.push(jsFilePath);
		}

		// Reset state
		this.writer.Clear();
	}

	function writeText(fileName:std.String, text:std.String, data:WriteFileData):Null<Error> {
		if (this.writeFile != null) {
			return this.writeFile(fileName, text, data);
		}
		return this.host.WriteFile(fileName, text);
	}

	function getSourceMapDirectory(mapOptions:CompilerOptions, filePath:std.String, sourceFile:SourceFile):std.String {
		if (mapOptions.SourceRoot.length > 0) {
			return this.host.CommonSourceDirectory();
		}
		if (mapOptions.MapRoot.length > 0) {
			var sourceMapDir = Tspath.NormalizeSlashes(mapOptions.MapRoot);
			if (sourceFile != null) {
				// For modules or multiple emit files the mapRoot will have directory structure like the sources
				// So if src\a.ts and src\lib\b.ts are compiled together user would be moving the maps into mapRoot\a.js.map and mapRoot\lib\b.js.map
				sourceMapDir = Tspath.GetDirectoryPath(Outputpaths.GetSourceFilePathInNewDir(sourceFile.FileName(), sourceMapDir, this.host.GetCurrentDirectory(),
					this.host.CommonSourceDirectory(), this.host.UseCaseSensitiveFileNames()));
			}
			if (Tspath.GetRootLength(sourceMapDir) == 0) {
				// The relative paths are relative to the common directory
				sourceMapDir = Tspath.CombinePaths(this.host.CommonSourceDirectory(), sourceMapDir);
			}
			return sourceMapDir;
		}
		return Tspath.GetDirectoryPath(Tspath.NormalizePath(filePath));
	}

	function getSourceMappingURL(mapOptions:CompilerOptions, sourceMapGenerator:Generator, filePath:std.String, sourceMapFilePath:std.String,
			sourceFile:SourceFile):std.String {
		if (mapOptions.InlineSourceMap.IsTrue()) {
			// Encode the sourceMap into the sourceMap url
			return sourceMapGenerator.Base64DataURL();
		}

		final sourceMapFile = Tspath.GetBaseFileName(Tspath.NormalizeSlashes(sourceMapFilePath));
		if (mapOptions.MapRoot.length > 0) {
			var sourceMapDir = Tspath.NormalizeSlashes(mapOptions.MapRoot);
			if (sourceFile != null) {
				// For modules or multiple emit files the mapRoot will have directory structure like the sources
				// So if src\a.ts and src\lib\b.ts are compiled together user would be moving the maps into mapRoot\a.js.map and mapRoot\lib\b.js.map
				sourceMapDir = Tspath.GetDirectoryPath(Outputpaths.GetSourceFilePathInNewDir(sourceFile.FileName(), sourceMapDir, this.host.GetCurrentDirectory(),
					this.host.CommonSourceDirectory(), this.host.UseCaseSensitiveFileNames()));
			}
			if (Tspath.GetRootLength(sourceMapDir) == 0) {
				// The relative paths are relative to the common directory
				sourceMapDir = Tspath.CombinePaths(this.host.CommonSourceDirectory(), sourceMapDir);
				return Stringutil.EncodeURI(Tspath.GetRelativePathToDirectoryOrUrl(Tspath.GetDirectoryPath(Tspath.NormalizePath(filePath)), // get the relative sourceMapDir path based on jsFilePath
					Tspath.CombinePaths(sourceMapDir, sourceMapFile), // this is where user expects to see sourceMap
					/*isAbsolutePathAnUrl*/ true, new ComparePathsOptions(this.host.UseCaseSensitiveFileNames(), this.host.GetCurrentDirectory())));
			} else {
				return Stringutil.EncodeURI(Tspath.CombinePaths(sourceMapDir, sourceMapFile));
			}
		}
		return Stringutil.EncodeURI(sourceMapFile);
	}
}

interface SourceFileMayBeEmittedHost {
	function Options():CompilerOptions;
	function GetProjectReferenceFromSource(path:Path):SourceOutputAndProjectReference;
	function IsSourceFileFromExternalLibrary(file:SourceFile):Bool;
	function GetCurrentDirectory():std.String;
	function UseCaseSensitiveFileNames():Bool;
	function SourceFiles():Array<SourceFile>;
}
