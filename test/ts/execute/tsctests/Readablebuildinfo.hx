package ts.execute.tsctests;

import go.Strings.Builder;
import ts.collections.OrderedMap;
import ts.core.Core;
import ts.execute.incremental.BuildInfo;
import ts.execute.incremental.Incremental;
import ts.execute.incremental.Snapshot.FileEmitKind;
import ts.execute.incremental.Snapshot.FileEmitKind.*;
import ts.json.Json;

// Port of internal/execute/tsctests/readablebuildinfo.go.
// PORT: the package-level func toReadableBuildInfo and toReadableFileEmitKind live in class
// Readablebuildinfo (not in the tsctests package class) to keep this file separate from the rest
// of the harness. JSON: each type implements Json.OrderedMarshaler (see incremental/BuildInfo.hx);
// the UnmarshalJSON methods of the readable types are not used by the harness and not ported.
class Readablebuildinfo {
	public static function toReadableBuildInfo(buildInfo:BuildInfo, buildInfoText:String):String {
		final readable = new ReadableBuildInfo();
		readable.buildInfo = buildInfo;
		readable.Version = buildInfo.Version;
		readable.Errors = buildInfo.Errors;
		readable.CheckPending = buildInfo.CheckPending;
		readable.FileNames = buildInfo.FileNames;
		readable.Options = buildInfo.Options;
		readable.LatestChangedDtsFile = buildInfo.LatestChangedDtsFile;
		readable.SemanticErrors = buildInfo.SemanticErrors;
		readable.PackageJsons = buildInfo.PackageJsons;
		readable.MissingPackageJsons = buildInfo.MissingPackageJsons;
		readable.Size = go.Utf8.ByteLen(buildInfoText); // PORT: byte — Go len() of the UTF-8 text
		readable.setFileInfos();
		readable.setRoot();
		readable.setFileIdsList();
		readable.setReferencedMap();
		readable.setChangeFileSet();
		readable.setSemanticDiagnostics();
		readable.setEmitDiagnostics();
		readable.setAffectedFilesPendingEmit();
		readable.setEmitSignatures();
		readable.setResolvedRoot();
		return Json.MarshalIndentOrdered(readable, "", "  ");
	}

	public static function toReadableFileEmitKind(fileEmitKind:FileEmitKind):String {
		final builder = new Builder();
		final addFlags = function(flags:String) {
			if (builder.Len() == 0) {
				builder.WriteString(flags);
			} else {
				builder.WriteString("|");
				builder.WriteString(flags);
			}
		};
		if (fileEmitKind != 0) {
			if ((fileEmitKind & FileEmitKindJs) != 0) {
				addFlags("Js");
			}
			if ((fileEmitKind & FileEmitKindJsMap) != 0) {
				addFlags("JsMap");
			}
			if ((fileEmitKind & FileEmitKindJsInlineMap) != 0) {
				addFlags("JsInlineMap");
			}
			if ((fileEmitKind & FileEmitKindDts) == FileEmitKindDts) {
				addFlags("Dts");
			} else {
				if ((fileEmitKind & FileEmitKindDtsEmit) != 0) {
					addFlags("DtsEmit");
				}
				if ((fileEmitKind & FileEmitKindDtsErrors) != 0) {
					addFlags("DtsErrors");
				}
			}
			if ((fileEmitKind & FileEmitKindDtsMap) != 0) {
				addFlags("DtsMap");
			}
		}
		if (builder.Len() != 0) {
			return builder.String();
		}
		return "None";
	}
}

// Go type readableBuildInfo.
class ReadableBuildInfo implements OrderedMarshaler {
	public var buildInfo:BuildInfo = null;
	public var Version:String = ""; // json:"version,omitzero"

	// Common between incremental and tsc -b buildinfo for non incremental programs
	public var Errors:Bool = false; // json:"errors,omitzero"
	public var CheckPending:Bool = false; // json:"checkPending,omitzero"
	public var Root:Array<ReadableBuildInfoRoot> = null; // json:"root,omitzero"
	public var PackageJsons:Array<String> = null; // json:"packageJsons,omitzero"
	public var MissingPackageJsons:Array<String> = null; // json:"missingPackageJsons,omitzero"

	// IncrementalProgram info
	public var FileNames:Array<String> = null; // json:"fileNames,omitzero"
	public var FileInfos:Array<ReadableBuildInfoFileInfo> = null; // json:"fileInfos,omitzero"
	public var FileIdsList:Array<Array<String>> = null; // json:"fileIdsList,omitzero"
	public var Options:OrderedMap<String, Dynamic> = null; // json:"options,omitzero"
	public var ReferencedMap:OrderedMap<String, Array<String>> = null; // json:"referencedMap,omitzero"
	public var SemanticDiagnosticsPerFile:Array<ReadableBuildInfoSemanticDiagnostic> = null; // json:"semanticDiagnosticsPerFile,omitzero"
	public var EmitDiagnosticsPerFile:Array<ReadableBuildInfoDiagnosticsOfFile> = null; // json:"emitDiagnosticsPerFile,omitzero"
	public var ChangeFileSet:Array<String> = null; // json:"changeFileSet,omitzero" // List of changed files in the program, not the whole set of files
	public var AffectedFilesPendingEmit:Array<ReadableBuildInfoFilePendingEmit> = null; // json:"affectedFilesPendingEmit,omitzero"
	public var LatestChangedDtsFile:String = ""; // json:"latestChangedDtsFile,omitzero" // Because this is only output file in the program, we dont need fileId to deduplicate name
	public var EmitSignatures:Array<ReadableBuildInfoEmitSignature> = null; // json:"emitSignatures,omitzero"
	public var ResolvedRoot:Array<ReadableBuildInfoResolvedRoot> = null; // json:"resolvedRoot,omitzero"
	public var Size:Int = 0; // json:"size,omitzero" // Size of the build info file

	// NonIncrementalProgram info
	public var SemanticErrors:Bool = false; // json:"semanticErrors,omitzero"

	public function new() {}

	public function MarshalJSONValue():Dynamic {
		final m = new OrderedMap<String, Dynamic>();
		if (this.Version != "")
			m.Set("version", this.Version);
		if (this.Errors)
			m.Set("errors", true);
		if (this.CheckPending)
			m.Set("checkPending", true);
		if (this.Root != null)
			m.Set("root", this.Root);
		if (this.PackageJsons != null)
			m.Set("packageJsons", this.PackageJsons);
		if (this.MissingPackageJsons != null)
			m.Set("missingPackageJsons", this.MissingPackageJsons);
		if (this.FileNames != null)
			m.Set("fileNames", this.FileNames);
		if (this.FileInfos != null)
			m.Set("fileInfos", this.FileInfos);
		if (this.FileIdsList != null)
			m.Set("fileIdsList", [for (ids in this.FileIdsList) ids == null ? [] : ids]);
		if (this.Options != null)
			m.Set("options", this.Options);
		if (this.ReferencedMap != null) {
			// PORT: nil []string values marshal as [] (json v2)
			final rm = new OrderedMap<String, Dynamic>();
			for (k => v in this.ReferencedMap.Entries())
				rm.Set(k, v == null ? [] : v);
			m.Set("referencedMap", rm);
		}
		if (this.SemanticDiagnosticsPerFile != null)
			m.Set("semanticDiagnosticsPerFile", this.SemanticDiagnosticsPerFile);
		if (this.EmitDiagnosticsPerFile != null)
			m.Set("emitDiagnosticsPerFile", this.EmitDiagnosticsPerFile);
		if (this.ChangeFileSet != null)
			m.Set("changeFileSet", this.ChangeFileSet);
		if (this.AffectedFilesPendingEmit != null)
			m.Set("affectedFilesPendingEmit", this.AffectedFilesPendingEmit);
		if (this.LatestChangedDtsFile != "")
			m.Set("latestChangedDtsFile", this.LatestChangedDtsFile);
		if (this.EmitSignatures != null)
			m.Set("emitSignatures", this.EmitSignatures);
		if (this.ResolvedRoot != null)
			m.Set("resolvedRoot", this.ResolvedRoot);
		if (this.Size != 0)
			m.Set("size", this.Size);
		if (this.SemanticErrors)
			m.Set("semanticErrors", true);
		return m;
	}

	function toFilePath(fileId:BuildInfoFileId):String {
		return this.buildInfo.FileNames[fileId - 1];
	}

	function toFilePathSet(fileIdListId:BuildInfoFileIdListId):Array<String> {
		return this.FileIdsList[fileIdListId - 1];
	}

	function toReadableBuildInfoDiagnostic(diagnostics:Array<BuildInfoDiagnostic>):Array<ReadableBuildInfoDiagnostic> {
		return Core.Map(diagnostics, function(d:BuildInfoDiagnostic):ReadableBuildInfoDiagnostic {
			var file = "";
			if (d.File != 0) {
				file = this.toFilePath(d.File);
			}
			final r = new ReadableBuildInfoDiagnostic();
			r.File = file;
			r.NoFile = d.NoFile;
			r.Pos = d.Pos;
			r.End = d.End;
			r.Code = d.Code;
			r.Category = (cast d.Category : Int);
			r.MessageKey = d.MessageKey;
			r.MessageArgs = d.MessageArgs;
			r.MessageChain = this.toReadableBuildInfoDiagnostic(d.MessageChain);
			r.RelatedInformation = this.toReadableBuildInfoDiagnostic(d.RelatedInformation);
			r.ReportsUnnecessary = d.ReportsUnnecessary;
			r.ReportsDeprecated = d.ReportsDeprecated;
			r.SkippedOnNoEmit = d.SkippedOnNoEmit;
			return r;
		});
	}

	function toReadableBuildInfoDiagnosticsOfFile(diagnostics:BuildInfoDiagnosticsOfFile):ReadableBuildInfoDiagnosticsOfFile {
		return new ReadableBuildInfoDiagnosticsOfFile(this.toFilePath(diagnostics.FileId), this.toReadableBuildInfoDiagnostic(diagnostics.Diagnostics));
	}

	public function setFileInfos():Void {
		this.FileInfos = Core.MapIndex(this.buildInfo.FileInfos, function(original:BuildInfoFileInfo, index:Int):ReadableBuildInfoFileInfo {
			final fileInfo = original.GetFileInfo();
			// Dont set original for string encoding
			if (original.HasSignature()) {
				original = null;
			}
			final r = new ReadableBuildInfoFileInfo();
			r.FileName = this.toFilePath(index + 1);
			r.Version = fileInfo.Version();
			r.Signature = fileInfo.Signature();
			r.AffectsGlobalScope = fileInfo.AffectsGlobalScope();
			r.ImpliedNodeFormat = fileInfo.ImpliedNodeFormat().String();
			r.Original = original;
			return r;
		});
	}

	public function setRoot():Void {
		this.Root = Core.Map(this.buildInfo.Root, function(original:BuildInfoRoot):ReadableBuildInfoRoot {
			var files:Array<String>;
			if (original.NonIncremental != "") {
				files = [original.NonIncremental];
			} else if (original.End == 0) {
				files = [this.toFilePath(original.Start)];
			} else {
				files = [];
				var i = original.Start;
				while (i <= original.End) {
					files.push(this.toFilePath(i));
					i++;
				}
			}
			return new ReadableBuildInfoRoot(files, original);
		});
	}

	public function setFileIdsList():Void {
		this.FileIdsList = Core.Map(this.buildInfo.FileIdsList, function(ids:Array<BuildInfoFileId>):Array<String> {
			return Core.Map(ids, this.toFilePath);
		});
	}

	public function setReferencedMap():Void {
		if (this.buildInfo.ReferencedMap != null) {
			this.ReferencedMap = new OrderedMap<String, Array<String>>();
			for (entry in this.buildInfo.ReferencedMap) {
				this.ReferencedMap.Set(this.toFilePath(entry.FileId), this.toFilePathSet(entry.FileIdListId));
			}
		}
	}

	public function setChangeFileSet():Void {
		this.ChangeFileSet = Core.Map(this.buildInfo.ChangeFileSet, this.toFilePath);
	}

	public function setSemanticDiagnostics():Void {
		this.SemanticDiagnosticsPerFile = Core.Map(this.buildInfo.SemanticDiagnosticsPerFile,
			function(diagnostics:BuildInfoSemanticDiagnostic):ReadableBuildInfoSemanticDiagnostic {
				if (diagnostics.FileId != 0) {
					return new ReadableBuildInfoSemanticDiagnostic(this.toFilePath(diagnostics.FileId), null);
				}
				return new ReadableBuildInfoSemanticDiagnostic("", this.toReadableBuildInfoDiagnosticsOfFile(diagnostics.Diagnostics));
			});
	}

	public function setEmitDiagnostics():Void {
		this.EmitDiagnosticsPerFile = Core.Map(this.buildInfo.EmitDiagnosticsPerFile, this.toReadableBuildInfoDiagnosticsOfFile);
	}

	public function setAffectedFilesPendingEmit():Void {
		if (this.buildInfo.AffectedFilesPendingEmit == null) {
			return;
		}
		final fullEmitKind = Incremental.GetFileEmitKind(this.buildInfo.GetCompilerOptions(""));
		this.AffectedFilesPendingEmit = Core.Map(this.buildInfo.AffectedFilesPendingEmit,
			function(pendingEmit:BuildInfoFilePendingEmit):ReadableBuildInfoFilePendingEmit {
				final emitKind = Core.IfElse(pendingEmit.EmitKind == 0, fullEmitKind, pendingEmit.EmitKind);
				return new ReadableBuildInfoFilePendingEmit(this.toFilePath(pendingEmit.FileId), Readablebuildinfo.toReadableFileEmitKind(emitKind),
					pendingEmit);
			});
	}

	public function setEmitSignatures():Void {
		this.EmitSignatures = Core.Map(this.buildInfo.EmitSignatures, function(signature:BuildInfoEmitSignature):ReadableBuildInfoEmitSignature {
			final r = new ReadableBuildInfoEmitSignature();
			r.File = this.toFilePath(signature.FileId);
			r.Signature = signature.Signature;
			r.DiffersOnlyInDtsMap = signature.DiffersOnlyInDtsMap;
			r.DiffersInOptions = signature.DiffersInOptions;
			r.Original = signature;
			return r;
		});
	}

	public function setResolvedRoot():Void {
		this.ResolvedRoot = Core.Map(this.buildInfo.ResolvedRoot, function(original:BuildInfoResolvedRoot):ReadableBuildInfoResolvedRoot {
			return new ReadableBuildInfoResolvedRoot(this.toFilePath(original.Resolved), this.toFilePath(original.Root));
		});
	}
}

// Go type readableBuildInfoRoot.
class ReadableBuildInfoRoot implements OrderedMarshaler {
	public var Files:Array<String> = null; // json:"files,omitzero"
	public var Original:BuildInfoRoot = null; // json:"original,omitzero"

	public function new(Files:Array<String>, Original:BuildInfoRoot) {
		this.Files = Files;
		this.Original = Original;
	}

	public function MarshalJSONValue():Dynamic {
		final m = new OrderedMap<String, Dynamic>();
		if (this.Files != null)
			m.Set("files", this.Files);
		if (this.Original != null)
			m.Set("original", this.Original);
		return m;
	}
}

// Go type readableBuildInfoFileInfo.
class ReadableBuildInfoFileInfo implements OrderedMarshaler {
	public var FileName:String = ""; // json:"fileName,omitzero"
	public var Version:String = ""; // json:"version,omitzero"
	public var Signature:String = ""; // json:"signature,omitzero"
	public var AffectsGlobalScope:Bool = false; // json:"affectsGlobalScope,omitzero"
	public var ImpliedNodeFormat:String = ""; // json:"impliedNodeFormat,omitzero"
	public var Original:BuildInfoFileInfo = null; // json:"original,omitzero" // Original file path, if available

	public function new() {}

	public function MarshalJSONValue():Dynamic {
		final m = new OrderedMap<String, Dynamic>();
		if (this.FileName != "")
			m.Set("fileName", this.FileName);
		if (this.Version != "")
			m.Set("version", this.Version);
		if (this.Signature != "")
			m.Set("signature", this.Signature);
		if (this.AffectsGlobalScope)
			m.Set("affectsGlobalScope", true);
		if (this.ImpliedNodeFormat != "")
			m.Set("impliedNodeFormat", this.ImpliedNodeFormat);
		if (this.Original != null)
			m.Set("original", this.Original);
		return m;
	}
}

// Go type readableBuildInfoDiagnostic.
class ReadableBuildInfoDiagnostic implements OrderedMarshaler {
	// incrementalBuildInfoFileId if it is for a File thats other than its stored for
	public var File:String = ""; // json:"file,omitzero"
	public var NoFile:Bool = false; // json:"noFile,omitzero"
	public var Pos:Int = 0; // json:"pos,omitzero"
	public var End:Int = 0; // json:"end,omitzero"
	public var Code:Int = 0; // json:"code,omitzero"
	public var Category:Int = 0; // json:"category,omitzero" (diagnostics.Category)
	public var MessageKey:String = ""; // json:"messageKey,omitzero"
	public var MessageArgs:Array<String> = null; // json:"messageArgs,omitzero"
	public var MessageChain:Array<ReadableBuildInfoDiagnostic> = null; // json:"messageChain,omitzero"
	public var RelatedInformation:Array<ReadableBuildInfoDiagnostic> = null; // json:"relatedInformation,omitzero"
	public var ReportsUnnecessary:Bool = false; // json:"reportsUnnecessary,omitzero"
	public var ReportsDeprecated:Bool = false; // json:"reportsDeprecated,omitzero"
	public var SkippedOnNoEmit:Bool = false; // json:"skippedOnNoEmit,omitzero"

	public function new() {}

	public function MarshalJSONValue():Dynamic {
		final m = new OrderedMap<String, Dynamic>();
		if (this.File != "")
			m.Set("file", this.File);
		if (this.NoFile)
			m.Set("noFile", true);
		if (this.Pos != 0)
			m.Set("pos", this.Pos);
		if (this.End != 0)
			m.Set("end", this.End);
		if (this.Code != 0)
			m.Set("code", this.Code);
		if (this.Category != 0)
			m.Set("category", this.Category);
		if (this.MessageKey != "")
			m.Set("messageKey", this.MessageKey);
		if (this.MessageArgs != null)
			m.Set("messageArgs", this.MessageArgs);
		if (this.MessageChain != null)
			m.Set("messageChain", this.MessageChain);
		if (this.RelatedInformation != null)
			m.Set("relatedInformation", this.RelatedInformation);
		if (this.ReportsUnnecessary)
			m.Set("reportsUnnecessary", true);
		if (this.ReportsDeprecated)
			m.Set("reportsDeprecated", true);
		if (this.SkippedOnNoEmit)
			m.Set("skippedOnNoEmit", true);
		return m;
	}
}

// Go type readableBuildInfoDiagnosticsOfFile.
class ReadableBuildInfoDiagnosticsOfFile implements OrderedMarshaler {
	public var file:String = "";
	public var diagnostics:Array<ReadableBuildInfoDiagnostic> = null;

	public function new(file:String, diagnostics:Array<ReadableBuildInfoDiagnostic>) {
		this.file = file;
		this.diagnostics = diagnostics;
	}

	public function MarshalJSONValue():Dynamic {
		final fileIdAndDiagnostics:Array<Dynamic> = [];
		fileIdAndDiagnostics.push(this.file);
		fileIdAndDiagnostics.push(this.diagnostics == null ? [] : this.diagnostics); // PORT: nil slice → [] (json v2)
		return fileIdAndDiagnostics;
	}
}

// Go type readableBuildInfoSemanticDiagnostic.
class ReadableBuildInfoSemanticDiagnostic implements OrderedMarshaler {
	public var file:String = ""; // File is not in changedSet and still doesnt have cached diagnostics
	public var diagnostics:ReadableBuildInfoDiagnosticsOfFile = null; // Diagnostics for file

	public function new(file:String, diagnostics:ReadableBuildInfoDiagnosticsOfFile) {
		this.file = file;
		this.diagnostics = diagnostics;
	}

	public function MarshalJSONValue():Dynamic {
		if (this.file != "") {
			return this.file;
		}
		return this.diagnostics;
	}
}

// Go type readableBuildInfoFilePendingEmit.
class ReadableBuildInfoFilePendingEmit implements OrderedMarshaler {
	public var file:String = "";
	public var emitKind:String = "";
	public var original:BuildInfoFilePendingEmit = null;

	public function new(file:String, emitKind:String, original:BuildInfoFilePendingEmit) {
		this.file = file;
		this.emitKind = emitKind;
		this.original = original;
	}

	public function MarshalJSONValue():Dynamic {
		final a:Array<Dynamic> = [this.file, this.emitKind, this.original];
		return a;
	}
}

// Go type readableBuildInfoEmitSignature.
class ReadableBuildInfoEmitSignature implements OrderedMarshaler {
	public var File:String = ""; // json:"file,omitzero"
	public var Signature:String = ""; // json:"signature,omitzero"
	public var DiffersOnlyInDtsMap:Bool = false; // json:"differsOnlyInDtsMap,omitzero"
	public var DiffersInOptions:Bool = false; // json:"differsInOptions,omitzero"
	public var Original:BuildInfoEmitSignature = null; // json:"original,omitzero"

	public function new() {}

	public function MarshalJSONValue():Dynamic {
		final m = new OrderedMap<String, Dynamic>();
		if (this.File != "")
			m.Set("file", this.File);
		if (this.Signature != "")
			m.Set("signature", this.Signature);
		if (this.DiffersOnlyInDtsMap)
			m.Set("differsOnlyInDtsMap", true);
		if (this.DiffersInOptions)
			m.Set("differsInOptions", true);
		if (this.Original != null)
			m.Set("original", this.Original);
		return m;
	}
}

// Go type readableBuildInfoResolvedRoot.
class ReadableBuildInfoResolvedRoot implements OrderedMarshaler {
	public var Resolved:String = "";
	public var Root:String = "";

	public function new(Resolved:String, Root:String) {
		this.Resolved = Resolved;
		this.Root = Root;
	}

	public function MarshalJSONValue():Dynamic {
		final a:Array<String> = [this.Resolved, this.Root];
		return a;
	}
}
