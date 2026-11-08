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
	var writeFile:WriteFile = null;
	var tr:Tracing = null;
	var part:Int = 0; // PORT: hxmc (-D tshx-parallel) — 0: both outputs, 1: the .js only, 2: the .d.ts only
	var prints:Array<() -> Void> = null;

	public function new() {}

	// transform runs the JS and declaration transformers for the file, the part of emit that uses the checker. print
	// prints and writes what transform produced.
	function transform():Void {
		var done:() -> Void = null;
		if (this.tr != null) {
			final args = new StringMap<Any>();
			args.set("path", (this.sourceFile.Path() : std.String));
			done = this.tr.Push(PhaseEmit, "emit", args, true);
		}
		try {
			if (this.part != 2)
				this.emitJSFile(this.sourceFile, this.paths.JsFilePath(), this.paths.SourceMapFilePath());
			if (this.part != 1)
				this.emitDeclarationFile(this.sourceFile, this.paths.DeclarationFilePath(), this.paths.DeclarationMapPath());
		} catch (e:Dynamic) {
			if (done != null)
				done();
			throw e;
		}
		if (done != null)
			done();
	}

	// print prints and writes the outputs transformed by transform. It must not use the checker, which may be in use by
	// another file by then.
	function print():Void {
		var done:() -> Void = null;
		if (this.tr != null) {
			final args = new StringMap<Any>();
			args.set("path", (this.sourceFile.Path() : std.String));
			done = this.tr.Push(PhaseEmit, "emitPrint", args, true);
		}
		try {
			for (print in this.prints) {
				print();
			}
			this.prints = null;
			this.emitResult.Diagnostics = this.emitterDiagnostics.GetDiagnostics();
		} catch (e:Dynamic) {
			if (done != null)
				done();
			throw e;
		}
		if (done != null)
			done();
	}

	function addPrint(print:() -> Void):Void {
		if (this.prints == null)
			this.prints = [];
		this.prints.push(print);
	}

	// PORT: Go's declarationTransformer interface; the DeclarationTransformer is wrapped (nominal interfaces).
	function getDeclarationTransformers(emitContext:EmitContext, sourceFile:SourceFile, declarationFilePath:RootedFilePath):Array<DeclarationTransformerLike> {
		final forceDtsEmit = this.emitOnly == EmitOnlyForcedDts;
		return [
			new DeclarationTransformerAdapter(Declarations.NewDeclarationTransformer(this.host, emitContext, this.host.Options(), declarationFilePath)),
			ts.transformers.declarations.Supplementalreferences.NewSupplementalReferencesTransformer(this.host, sourceFile, declarationFilePath,
				forceDtsEmit)
		];
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
	function runDeclarationTransformers(emitContext:EmitContext, sourceFile:SourceFile, declarationFilePath:RootedFilePath,
			declarationMapPath:RootedFilePath):Pair<SourceFile, Array<Diagnostic>> {
		var done:() -> Void = null;
		if (this.tr != null) {
			final args = new StringMap<Any>();
			args.set("path", (sourceFile.Path() : std.String));
			done = this.tr.Push(PhaseEmit, "transformNodes", args, false);
		}
		var diags:Array<Diagnostic> = null;
		try {
			for (transformer in this.getDeclarationTransformers(emitContext, sourceFile, declarationFilePath)) {
				sourceFile = transformer.TransformSourceFile(sourceFile);
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

	function emitJSFile(sourceFile:SourceFile, jsFilePath:RootedFilePath, sourceMapFilePath:RootedFilePath):Void {
		final options = this.host.Options();

		if (sourceFile == null || this.emitOnly != EmitAll && this.emitOnly != EmitOnlyJs || jsFilePath == "") {
			return;
		}

		if (options.NoEmit == TSTrue || this.host.IsEmitBlocked(jsFilePath)) {
			this.emitResult.EmitSkipped = true;
			return;
		}

		var done:() -> Void = null;
		if (this.tr != null) {
			final args = new StringMap<Any>();
			args.set("jsFilePath", jsFilePath.AsString());
			done = this.tr.Push(PhaseEmit, "emitJsFileOrBundle", args, true);
		}

		// PORT: TypeScript main (#64649) dropped the pool of emit contexts (Go 7.0.2's GetEmitContext): the context
		// lives until the deferred print (#64922)
		final emitContext = Printer.NewEmitContext();
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

			final transformed = sourceFile;
			this.addPrint(function() {
				this.printSourceFile(jsFilePath, sourceMapFilePath, transformed, printer, options, Compiler.shouldEmitSourceMaps(options, transformed));
			});
		} catch (e:Dynamic) {
			if (done != null)
				done();
			throw e;
		}
		if (done != null)
			done();
	}

	function emitDeclarationFile(sourceFile:SourceFile, declarationFilePath:RootedFilePath, declarationMapPath:RootedFilePath):Void {
		final options = this.host.Options();

		if (sourceFile == null || this.emitOnly == EmitOnlyJs || declarationFilePath == "") {
			return;
		}

		var done:() -> Void = null;
		if (this.tr != null) {
			final args = new StringMap<Any>();
			args.set("declarationFilePath", declarationFilePath.AsString());
			done = this.tr.Push(PhaseEmit, "emitDeclarationFileOrBundle", args, true);
		}

		final emitContext = Printer.NewEmitContext();
		try {
			this.emitDeclarationFileWorker(emitContext, sourceFile, declarationFilePath, declarationMapPath, options);
		} catch (e:Dynamic) {
			if (done != null)
				done();
			throw e;
		}
		if (done != null)
			done();
	}

	// PORT: body of emitDeclarationFile after its defers (split off because of the early returns).
	function emitDeclarationFileWorker(emitContext:EmitContext, sourceFile:SourceFile, declarationFilePath:RootedFilePath, declarationMapPath:RootedFilePath,
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
		final emitDeclarationMap = this.emitOnly != EmitOnlyForcedDts && options.DeclarationMap.IsTrue();
		final contentMappedSource = sourceFile;
		printerOptions.SourceMap = emitDeclarationMap;
		printerOptions.InlineSourceMap = options.InlineSourceMap.IsTrue();
		// InlineSources:       options.InlineSources.IsTrue(), // ignored, per strada
		// ExtendedDiagnostics: options.ExtendedDiagnostics.IsTrue(), // NYI
		printerOptions.OnlyPrintJSDocStyle = true;
		printerOptions.OmitBraceSourceMapPositions = true;

		// create a printer to print the nodes
		final printHandlers = new PrintHandlers();
		final spanMap = contentMappedSource.SpanMap();
		if (emitDeclarationMap && spanMap != null) {
			final originalSource = new DeclarationMapSource(contentMappedSource);
			printHandlers.MapSourcePosition = function(source:ts.sourcemap.Source.Source, pos:Int):Null<ts.printer.Printer.MappedSourcePosition> {
				if (source.FileName() != contentMappedSource.FileName()) {
					return new ts.printer.Printer.MappedSourcePosition(source, pos);
				}
				final mapped = ts.spanmap.Spanmap.VirtualToOriginalPositionExact(spanMap, pos);
				if (!mapped.ok) {
					return null;
				}
				return new ts.printer.Printer.MappedSourcePosition(originalSource, mapped.value);
			};
		}
		final printer = Printer.NewPrinter(printerOptions, printHandlers, emitContext);

		final declarationMapOptions = new CompilerOptions();
		declarationMapOptions.SourceMap = Core.IfElse(emitDeclarationMap, TSTrue, TSFalse);
		declarationMapOptions.SourceRoot = options.SourceRoot;
		declarationMapOptions.MapRoot = options.MapRoot;
		// Explicitly do not pass through either inline option.
		this.addPrint(function() {
			this.printSourceFile(declarationFilePath, declarationMapPath, sourceFile, printer, declarationMapOptions,
				Compiler.shouldEmitSourceMaps(declarationMapOptions, sourceFile));
		});
	}

	function printSourceFile(jsFilePath:RootedFilePath, sourceMapFilePath:RootedFilePath, sourceFile:SourceFile, printer_:Printer, mapOptions:CompilerOptions,
			shouldEmitSourceMaps:Bool):Void {
		// !!! sourceMapGenerator
		final options = this.host.Options();
		var sourceMapGenerator:Generator = null;
		if (shouldEmitSourceMaps) {
			sourceMapGenerator = Sourcemap.NewGenerator(jsFilePath.BaseName(), Compiler.getSourceRoot(mapOptions),
				this.getSourceMapDirectory(mapOptions, jsFilePath, sourceFile), this.host.CaseSensitivity());
		}

		printer_.Write(sourceFile.AsNode(), sourceFile, this.writer, sourceMapGenerator);

		var sourceMapUrlPos = -1;
		if (sourceMapGenerator != null) {
			if (mapOptions.SourceMap.IsTrue() || mapOptions.InlineSourceMap.IsTrue()) {
				final r = new SourceMapEmitResult();
				r.InputSourceFileNames = sourceMapGenerator.Sources();
				r.SourceMap = sourceMapGenerator.RawSourceMap();
				r.GeneratedFile = jsFilePath.AsString();
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
			if (sourceMapFilePath != "") {
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

	function writeText(fileName:RootedFilePath, text:std.String, data:WriteFileData):Null<Error> {
		if (this.writeFile != null) {
			return this.writeFile(fileName, text, data);
		}
		return this.host.WriteFile(fileName, text);
	}

	function getMapRootDirectory(mapRoot:SourceMapLocation, sourceFile:SourceFile):RootedDirectoryPath {
		var sourceMapDirectory = mapRoot.ResolveDirectory(this.host.CommonSourceDirectory(), this.host.BaseDirectory());
		if (sourceFile != null) {
			sourceMapDirectory = Outputpaths.GetSourceFileNameInNewDir(sourceFile.FileName(), sourceMapDirectory, this.host.CommonSourceDirectory(),
				this.host.CaseSensitivity())
				.Directory();
		}
		return sourceMapDirectory;
	}

	function getSourceMapDirectory(mapOptions:CompilerOptions, filePath:RootedFilePath, sourceFile:SourceFile):RootedDirectoryPath {
		if (mapOptions.SourceRoot.length > 0) {
			return this.host.CommonSourceDirectory();
		}
		if (mapOptions.MapRoot.length > 0) {
			return this.getMapRootDirectory(mapOptions.MapRoot, sourceFile);
		}
		return filePath.Directory();
	}

	function getSourceMappingURL(mapOptions:CompilerOptions, sourceMapGenerator:Generator, filePath:RootedFilePath, sourceMapFilePath:RootedFilePath,
			sourceFile:SourceFile):std.String {
		if (mapOptions.InlineSourceMap.IsTrue()) {
			// Encode the sourceMap into the sourceMap url
			return sourceMapGenerator.Base64DataURL();
		}

		final sourceMapFile = sourceMapFilePath.BaseName();
		if (mapOptions.MapRoot.length > 0) {
			final sourceMapDirectory = this.getMapRootDirectory(mapOptions.MapRoot, sourceFile);
			final sourceMapFilePath = sourceMapDirectory.ResolveFile(sourceMapFile);
			if (mapOptions.MapRoot.IsRelative()) {
				return Stringutil.EncodeURI(Tspath.GetRelativePathToDirectoryOrUrl(filePath.Directory().AsString(), sourceMapFilePath.AsString(), true,
					this.host.CaseSensitivity()));
			}
			return Stringutil.EncodeURI(sourceMapFilePath.AsString());
		}
		return Stringutil.EncodeURI(sourceMapFile);
	}
}

interface SourceFileMayBeEmittedHost {
	function Options():CompilerOptions;
	function GetProjectReferenceFromSource(path:Path):SourceOutputAndProjectReference;
	function IsSourceFileFromExternalLibrary(file:SourceFile):Bool;
	function BaseDirectory():RootedDirectoryPath;
	function CaseSensitivity():CaseSensitivity;
	function SourceFiles():Array<SourceFile>;
}

// PORT: Go's declarationTransformer interface (TransformSourceFile, GetDiagnostics).
interface DeclarationTransformerLike {
	function TransformSourceFile(sourceFile:SourceFile):SourceFile;
	function GetDiagnostics():Array<Diagnostic>;
}

private class DeclarationTransformerAdapter implements DeclarationTransformerLike {
	final tx:DeclarationTransformer;

	public function new(tx:DeclarationTransformer) {
		this.tx = tx;
	}

	public function TransformSourceFile(sourceFile:SourceFile):SourceFile {
		return tx.Transformer.TransformSourceFile(sourceFile);
	}

	public function GetDiagnostics():Array<Diagnostic> {
		return tx.GetDiagnostics();
	}
}

// declarationMapSource: the original text of a content-mapped file as a source map source.
class DeclarationMapSource implements ts.sourcemap.Source.Source {
	final fileName:RootedFilePath;
	final text:std.String;
	final lineMap:Array<TextPos>;

	public function new(sourceFile:SourceFile) {
		this.text = sourceFile.OriginalText();
		this.fileName = sourceFile.OriginalFileName();
		this.lineMap = Core.ComputeECMALineStarts(this.text);
	}

	public function FileName():RootedFilePath {
		return fileName;
	}

	public function Text():std.String {
		return text;
	}

	public function ECMALineMap():Array<TextPos> {
		return lineMap;
	}
}
