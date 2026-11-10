package ts.transformers.declarations;

// Port of supplementalreferences.go (TypeScript main, content mappers).

// SupplementalReferencesTransformer adds triple-slash path references from a content mapper's
// canonical declaration output to the declaration files emitted for its supplemental files.
// This ensures that consumers loading the canonical declaration also include the supplemental types.
class Supplementalreferences implements ts.compiler.Emitter.DeclarationTransformerLike {
	final host:ts.compiler.EmitHost.EmitHost;
	final supplementalFiles:Slice<SourceFile>;
	final declarationFilePath:RootedFilePath;
	final forceDeclarationPaths:Bool;

	function new(host, supplementalFiles, declarationFilePath, forceDeclarationPaths) {
		this.host = host;
		this.supplementalFiles = supplementalFiles;
		this.declarationFilePath = declarationFilePath;
		this.forceDeclarationPaths = forceDeclarationPaths;
	}

	// PORT: Go's DeclarationEmitHost provides SourceFileMayBeEmitted; the port's compiler EmitHost does.
	public static function NewSupplementalReferencesTransformer(host:ts.compiler.EmitHost.EmitHost, sourceFile:SourceFile, declarationFilePath:RootedFilePath,
			forceDeclarationPaths:Bool):Supplementalreferences {
		return new Supplementalreferences(host, sourceFile.SupplementalSourceFiles(), declarationFilePath, forceDeclarationPaths);
	}

	public function TransformSourceFile(sourceFile:SourceFile):SourceFile {
		if (supplementalFiles != null) {
			for (supplemental in supplementalFiles) {
				if (!host.SourceFileMayBeEmitted(supplemental, forceDeclarationPaths)) {
					continue;
				}
				final declarationPath = host.GetOutputPathsFor(supplemental, forceDeclarationPaths).DeclarationFilePath();
				if (declarationPath == "") {
					continue;
				}
				final relativePath = host.CaseSensitivity().RelativePathFromFile(declarationFilePath, declarationPath);
				if (relativePath == null) {
					throw "supplemental declaration output must share a root with the primary declaration";
				}
				final ref = new FileReference();
				ref.TextRange = Core.NewTextRange(-1, -1);
				ref.FileName = relativePath.AsModuleSpecifier().AsString();
				// PORT: Go append (the transformed file owns its slice)
				sourceFile.ReferencedFiles = sourceFile.ReferencedFiles == null ? [ref] : sourceFile.ReferencedFiles.concat([ref]);
			}
		}
		return sourceFile;
	}

	public function GetDiagnostics():Slice<Diagnostic> {
		return null;
	}
}
