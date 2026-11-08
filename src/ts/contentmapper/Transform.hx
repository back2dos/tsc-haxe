package ts.contentmapper;

import go.Errors.Error;
import go.Tuple;
import ts.ast.Ast;
import ts.ast.Parseoptions;
import ts.contentmapper.Contentmapper;
import ts.contentmapper.Host;
import ts.core.Core;
import ts.parser.Parser;
import ts.spanmap.Spanmap;
import ts.tspath.Tspath;
import ts.tspath.RootedPath;

// --- transform.go ---

// SourceFiles is the canonical output and its unnamed supplemental compiler inputs.
class SourceFiles {
	public var Canonical:SourceFile = null;
	public var Supplemental:Array<SourceFile> = null;

	public function new() {}
}

class Transform {
	// TransformAndParse runs the given content mapper's transform for a content-mapped source file and
	// parses the resulting TypeScript, preserving the original file name and retaining the untransformed text
	// on the source file. It is the shared implementation behind CompilerHost.GetContentMappedSourceFiles.
	public static function TransformAndParse(parseOptions:SourceFileParseOptions, content:String, mapper:Mapper, project:Project):ValueError<SourceFiles> {
		final transformIdentity = project.Identity(mapper);
		if (transformIdentity.err != null) {
			return new ValueError(new SourceFiles(), Contentmapper.NewTransformError(TransformErrorKindProject, transformIdentity.err));
		}
		final result = project.Transform(mapper, new Request(parseOptions.FileName, content));
		if (result.err != null) {
			return new ValueError(new SourceFiles(), result.err);
		}
		return ParseResult(parseOptions, content, mapper, transformIdentity.value, result.value);
	}

	// ParseResult validates and parses one mapper result and all its supplemental outputs.
	public static function ParseResult(parseOptions:SourceFileParseOptions, content:String, mapper:Mapper, transformIdentity:String,
			result:Result):ValueError<SourceFiles> {
		if (result.Mappings == null) {
			return new ValueError(new SourceFiles(), Contentmapper.NewTransformError(TransformErrorKindMappings, null));
		}
		final problem = Spanmap.Validate(result.Mappings, result.Text, content);
		if (problem != null) {
			return new ValueError(new SourceFiles(), problem);
		}
		final virtualExtension = result.VirtualExtension;
		if (!Contentmapper.IsSupportedVirtualExtension(virtualExtension)) {
			return new ValueError(new SourceFiles(), Contentmapper.NewTransformError(TransformErrorKindResponse, null));
		}
		final baseParseOptions = parseOptions;
		final virtualFileName = baseParseOptions.FileName.AppendSuffix(virtualExtension);
		parseOptions = baseParseOptions.copy();
		if (isModuleVirtualExtension(virtualExtension)) {
			parseOptions.ExternalModuleIndicatorOptions.Force = true;
		}
		final sourceFile = Parser.ParseSourceFile(parseOptions, result.Text, Core.GetScriptKindFromFileName(virtualFileName));
		if (result.Diagnostics != null && result.Diagnostics.length > 0) {
			// The runner produces diagnostics without a source file (it doesn't have one yet); associate
			// them with the file now so they are reported against it.
			for (diagnostic in result.Diagnostics) {
				diagnostic.SetFile(sourceFile);
			}
			final diags = sourceFile.Diagnostics() == null ? [] : sourceFile.Diagnostics().copy();
			for (d in result.Diagnostics)
				diags.push(d);
			sourceFile.SetDiagnostics(diags);
		}
		final files = new SourceFiles();
		files.Canonical = sourceFile;
		files.Supplemental = [];
		if (result.Supplemental != null) {
			for (i in 0...result.Supplemental.length) {
				final supplemental = result.Supplemental[i];
				if (supplemental.Mappings == null) {
					return new ValueError(new SourceFiles(), Contentmapper.NewTransformError(TransformErrorKindMappings, null));
				}
				final problem = Spanmap.Validate(supplemental.Mappings, supplemental.Text, content);
				if (problem != null) {
					return new ValueError(new SourceFiles(), problem);
				}
				final supplementalOptions = baseParseOptions.copy();
				if (!Contentmapper.IsSupportedVirtualExtension(supplemental.VirtualExtension)) {
					return new ValueError(new SourceFiles(), Contentmapper.NewTransformError(TransformErrorKindResponse, null));
				}
				final suffix = "." + i + supplemental.VirtualExtension;
				supplementalOptions.FileName = supplementalOptions.FileName.AppendSuffix(suffix);
				// PORT: PathKey.AppendCanonicalSuffix: the suffix is ASCII digits and an extension, canonical as is
				// unless the path is case-folded.
				supplementalOptions.Path = cast((parseOptions.Path : String) + appendCanonicalSuffix(parseOptions.Path, parseOptions.FileName, suffix));
				if (isModuleVirtualExtension(supplemental.VirtualExtension)) {
					supplementalOptions.ExternalModuleIndicatorOptions.Force = true;
				}
				final file = Parser.ParseSourceFile(supplementalOptions, supplemental.Text, Core.GetScriptKindFromFileName(supplementalOptions.FileName));
				files.Supplemental.push(file);
			}
		}
		final mapperIdentity = mapper.Identity();
		final info = new ContentMapperSourceFileInfo();
		info.ContentMapper = mapperIdentity;
		info.TransformIdentity = transformIdentity;
		info.ParseOptions = baseParseOptions;
		info.VirtualFileName = virtualFileName;
		info.OriginalText = content;
		info.SpanMap = result.Mappings;
		info.DiagnosticDirectives = result.DiagnosticDirectives;
		info.SupplementalSourceFiles = files.Supplemental;
		sourceFile.SetContentMapperInfo(info);
		for (i in 0...files.Supplemental.length) {
			final file = files.Supplemental[i];
			final supplemental = result.Supplemental[i];
			final sinfo = new ContentMapperSourceFileInfo();
			sinfo.ContentMapper = mapperIdentity;
			sinfo.TransformIdentity = transformIdentity;
			sinfo.ParseOptions = baseParseOptions;
			sinfo.VirtualFileName = file.FileName();
			sinfo.OriginalText = content;
			sinfo.SpanMap = supplemental.Mappings;
			sinfo.DiagnosticDirectives = supplemental.DiagnosticDirectives;
			sinfo.CanonicalSourceFile = sourceFile;
			file.SetContentMapperInfo(sinfo);
		}
		return new ValueError(files, null);
	}

	// PORT: the path key of a case-insensitive file system is lower case; keep the suffix in the same case.
	static function appendCanonicalSuffix(path:String, fileName:String, suffix:String):String {
		if (path != fileName && path == fileName.toLowerCase()) {
			return suffix.toLowerCase();
		}
		return suffix;
	}

	static function isModuleVirtualExtension(extension:String):Bool {
		return extension == Tspath.ExtensionMts || extension == Tspath.ExtensionCts || extension == Tspath.ExtensionMjs
			|| extension == Tspath.ExtensionCjs;
	}

	// CheckSupplementalFileNameCollisions rejects compiler-assigned virtual filenames that name physical files.
	public static function CheckSupplementalFileNameCollisions(files:SourceFiles, fileExists:(RootedFilePath) -> Bool):Null<Error> {
		if (files.Supplemental != null) {
			for (file in files.Supplemental) {
				if (fileExists(file.FileName())) {
					return new SupplementalFileCollisionError(file.FileName());
				}
			}
		}
		return null;
	}
}
